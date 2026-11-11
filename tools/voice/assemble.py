"""CPU-only, resumable assembly of completed voice parts into runtime media."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import traceback
import uuid
import wave

import catalog
import intake
import produce

GAP_SECONDS = 0.13


def stamp():
    return datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%f') + '_' + uuid.uuid4().hex[:8]


def token(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-z0-9_]+', value):
        raise ValueError(f'Unsafe voice identifier: {value!r}')
    return value


def verify_inputs(root, case, document):
    expected = (case/'catalog.sha256').read_text(encoding='ascii').strip()
    if intake.fingerprint(case/'catalog.json') != expected:
        raise ValueError('Frozen catalog changed')
    catalog.verify_sources(root, document)
    profile_hash = document['source_bindings'].get('game/data/voice/voice_profiles.json')
    if profile_hash and intake.fingerprint(case/'profiles.json') != profile_hash:
        raise ValueError('Frozen profile snapshot changed')


def wav_info(path):
    with wave.open(str(path), 'rb') as audio:
        shape = (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getcomptype())
        if shape[0:2] != (1, 2) or shape[3] != 'NONE' or shape[2] <= 0 or audio.getnframes() <= 0:
            raise ValueError(f'Unexpected speech WAV: {path}')
        return dict(shape=shape, frames=audio.getnframes(), path=path)


def layout(segments, parts, infos):
    if not segments:
        raise ValueError('Ready line has no speech parts')
    shape = infos[segments[0]['part_id']]['shape']
    rate, cursor = shape[2], 0
    gap = round(rate * GAP_SECONDS) if len(segments) > 1 else 0
    ordered, speakers = [], []
    for index, segment in enumerate(segments):
        key = token(segment['part_id'])
        part, info = parts[key], infos[key]
        if info['shape'] != shape:
            raise ValueError('Speech parts have different PCM formats')
        if part['profile_id'] != segment['profile_id'] or part['text'] != segment['text']:
            raise ValueError(f'Speech segment does not match its completed part: {key}')
        if index:
            cursor += gap
        start = cursor / rate
        cursor += info['frames']
        speakers.append(dict(profile_id=segment['profile_id'], part_id=key,
                             start=start, end=cursor/rate,
                             start_char=segment['start_char'], end_char=segment['end_char']))
        ordered.append(dict(part_id=key, wav_sha256=info['wav_sha256']))
    payload = dict(schema_version=1, ordered_parts=ordered, gap_frames=gap, sample_rate=rate,
                   channels=shape[0], sample_width=shape[1])
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return 'speech_' + digest, payload, speakers, cursor/rate


def assemble_wav(path, segments, infos, gap_frames):
    if len(segments) == 1:
        os.link(infos[segments[0]['part_id']]['path'], path)
        return
    shape = infos[segments[0]['part_id']]['shape']
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(shape[0])
        output.setsampwidth(shape[1])
        output.setframerate(shape[2])
        for index, segment in enumerate(segments):
            if index:
                output.writeframes(bytes(gap_frames * shape[0] * shape[1]))
            info = infos[segment['part_id']]
            with wave.open(str(info['path']), 'rb') as source:
                data = source.readframes(info['frames'])
                if len(data) != info['frames'] * shape[0] * shape[1]:
                    raise ValueError('Truncated completed speech WAV')
                output.writeframes(data)


def check_cues(document, seconds):
    intake.validate_cues(document)
    if abs(document['metadata']['duration'] - seconds) > 0.011:
        raise ValueError('Mouth cue duration does not match assembled WAV')


def checked_file(case, item):
    path = case/item['path']
    if intake.fingerprint(path) != item['sha256']:
        raise ValueError(f'Changed packed evidence: {path}')
    return path


def check_alignment(case, record, payload, seconds):
    if record['input'] != payload or abs(record['seconds'] - seconds) > 1e-8:
        raise ValueError('Packed media input changed')
    if record['state'] not in ('aligned', 'prepared', 'complete'):
        raise ValueError('Packed media has no validated preparation')
    checked_file(case, record['assembled_wav'])
    for evidence in record['alignment_evidence']:
        checked_file(case, evidence)
    native = checked_file(case, record['native_cues'])
    check_cues(intake.read_json(native), seconds)
    cues = checked_file(case, record['staged_cues'])
    check_cues(intake.read_json(cues), seconds)


def finish_media(case, record_path, record, payload, seconds):
    check_alignment(case, record, payload, seconds)
    if record['state'] == 'aligned':
        raise ValueError('Aligned media has not been encoded')
    audio = checked_file(case, record['staged_audio'])
    cues = checked_file(case, record['staged_cues'])
    for source, name in ((audio, record['media_id'] + '.ogg'), (cues, record['media_id'] + '.cues.json')):
        target = case/'packed'/name
        if target.exists():
            if intake.fingerprint(target) != intake.fingerprint(source):
                raise ValueError(f'Changed packed asset: {target}')
        elif record['state'] == 'complete':
            raise ValueError(f'Missing completed packed asset: {target}')
        else:
            os.link(source, target)
    if record['state'] != 'complete':
        record = dict(record, state='complete', installed_utc=produce.now())
        produce.write(record_path, record)
    return record


def encode(ffmpeg, source, target, folder):
    commands = [[str(ffmpeg), '-nostdin', '-v', 'error', '-n', '-i', str(source),
                 '-vn', '-c:a', 'libvorbis', '-q:a', '5', str(target)],
                [str(ffmpeg), '-nostdin', '-v', 'error', '-i', str(target), '-f', 'null', '-']]
    produce.write(folder/'ffmpeg_commands.json', commands)
    results = []
    for index, command in enumerate(commands):
        with (folder/f'ffmpeg_{index}.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=300)
        results.append(dict(command_index=index, exit_code=result.returncode))
        produce.write(folder/'ffmpeg_results.json', results)
        if result.returncode:
            raise ValueError(f'FFmpeg failed (exit {result.returncode}); retained {folder}')
    if not target.is_file() or target.read_bytes()[:4] != b'OggS':
        raise ValueError('FFmpeg produced no OGG container')


def make_media(root, case, row, media_id, payload, speakers, seconds, parts, infos, rhubarb, ffmpeg, document):
    state = case/'assembly_state'
    record_path = state/'media'/(media_id + '.record.json')
    record = None
    if record_path.exists():
        record = intake.read_json(record_path)
        if record['state'] != 'aligned':
            return finish_media(case, record_path, record, payload, seconds)
        check_alignment(case, record, payload, seconds)
    elif any((case/'packed'/(media_id + suffix)).exists() for suffix in ('.ogg', '.cues.json')):
        raise ValueError(f'Unreceipted packed asset exists: {media_id}')
    folder = state/'attempts'/stamp()
    folder.mkdir(parents=True)
    receipt = dict(kind='voice_cpu_packaging', state='started', started_utc=produce.now(),
                   assembler_sha256=intake.fingerprint(Path(__file__)),
                   media_id=media_id, line_id=row['line_id'], input=payload,
                   text=row['text'], text_sha256=row['text_sha256'],
                   speech_text=row.get('speech_text', row['text']), speaker_segments=speakers,
                   rhubarb=str(rhubarb), ffmpeg=str(ffmpeg))
    produce.write(folder/'receipt.json', receipt)
    try:
        def evidence(path):
            return dict(path=path.relative_to(case).as_posix(), sha256=intake.fingerprint(path))
        if record is None:
            wavs = folder/'wavs'
            wavs.mkdir()
            wav = wavs/(media_id + '.wav')
            assemble_wav(wav, row['segments'], infos, payload['gap_frames'])
            before = intake.fingerprint(wav)
            native = intake.align_wavs(wavs, folder/'native_cues',
                      [dict(line_id=media_id, text=row.get('speech_text', row['text']), delivery='spoken')], str(rhubarb),
                      evidence_dir=folder/'rhubarb_evidence')[0]
            cue_doc = intake.read_json(native)
            check_cues(cue_doc, seconds)
            staged_cues = folder/(media_id + '.cues.json')
            cue_doc['metadata']['soundFile'] = media_id + '.ogg'
            produce.write(staged_cues, cue_doc)
            record = dict(schema_version=1, state='aligned', media_id=media_id, input=payload,
                          seconds=seconds, alignment_text_sha256=row.get('speech_text_sha256', row['text_sha256']),
                          assembled_wav=evidence(wav), native_cues=evidence(native),
                          alignment_evidence=[evidence(path) for path in
                              sorted((folder/'rhubarb_evidence'/media_id).iterdir()) if path.is_file()],
                          staged_cues=evidence(staged_cues), attempt=folder.relative_to(case).as_posix())
            produce.write(record_path, record)
        else:
            wav = checked_file(case, record['assembled_wav'])
            before = record['assembled_wav']['sha256']
            receipt['reused_alignment'] = record['attempt']
        audio = folder/(media_id + '.ogg')
        encode(ffmpeg, wav, audio, folder)
        record = dict(record, state='prepared', staged_audio=evidence(audio))
        produce.write(record_path, record)
        verify_inputs(root, case, document)
        for segment in row['segments']:
            if not produce.validate_part(case, parts[segment['part_id']]):
                raise ValueError('Completed part disappeared during packaging')
        if intake.fingerprint(wav) != before:
            raise ValueError('Assembled WAV changed during packaging')
        result = finish_media(case, record_path, record, payload, seconds)
        receipt.update(state='complete', finished_utc=produce.now(), output=result)
        return result
    except Exception as error:
        receipt.update(state='failed', finished_utc=produce.now(), error=str(error), traceback=traceback.format_exc())
        raise
    finally:
        produce.write(folder/'receipt.json', receipt)


def identity(row):
    result = {key: row[key] for key in ('line_id', 'namespace', 'owner_resident_id', 'profile_id',
                                      'runtime_node_id', 'text_sha256')}
    for key in ('runtime_node_is_pattern', 'speech_text_sha256', 'component_kind', 'component_value', 'carrier'):
        if key in row:
            result[key] = row[key]
    return result


def verify_manifest(case, state):
    target, ledger = case/'runtime_manifest.json', state/'manifest_state.json'
    if not ledger.exists():
        if target.exists():
            raise ValueError('Unreceipted runtime manifest exists')
        return
    record = intake.read_json(ledger)
    if not target.exists():
        if record.get('current_sha256'):
            raise ValueError('Missing completed runtime manifest')
        return
    actual = intake.fingerprint(target)
    if actual == record.get('prepared_sha256'):
        produce.write(ledger, dict(current_sha256=actual, prepared_sha256=None))
    elif actual != record.get('current_sha256'):
        raise ValueError('Changed runtime manifest')


def publish_manifest(case, state, manifest):
    target = case/'runtime_manifest.json'
    if target.exists() and intake.read_json(target) == manifest:
        return
    previous = intake.fingerprint(target) if target.exists() else None
    content = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    expected = hashlib.sha256(content).hexdigest()
    ledger = state/'manifest_state.json'
    produce.write(ledger, dict(current_sha256=previous, prepared_sha256=expected))
    pending = target.with_suffix(target.suffix + '.pending')
    pending.write_bytes(content)
    os.replace(pending, target)
    produce.write(ledger, dict(current_sha256=expected, prepared_sha256=None))


def package_once(root, case, rhubarb, ffmpeg='ffmpeg'):
    root, case = Path(root), Path(case)
    state = case/'assembly_state'
    state.mkdir(parents=True, exist_ok=True)
    started = produce.now()
    try:
        with produce.exclusive(state):
            document = intake.read_json(case/'catalog.json')
            verify_inputs(root, case, document)
            verify_manifest(case, state)
            (state/'media').mkdir(exist_ok=True)
            (case/'packed').mkdir(exist_ok=True)
            parts, infos = {}, {}
            for part in document['parts']:
                key = token(part['part_id'])
                if key in parts:
                    raise ValueError('Duplicate completed part identity')
                parts[key] = part
                if produce.validate_part(case, part):
                    info = wav_info(case/'parts'/(key + '.wav'))
                    info['wav_sha256'] = intake.read_json(case/'parts'/(key + '.record.json'))['wav_sha256']
                    infos[key] = info
            entries, excluded, pending, media = [], [], [], {}
            for row in document['lines']:
                token(row['line_id'])
                if row['state'] != 'ready':
                    excluded.append(dict(identity(row), state=row['state']))
                    continue
                missing = [part['part_id'] for part in row['segments'] if part['part_id'] not in infos]
                if missing:
                    pending.append(dict(identity(row), missing_parts=missing))
                    continue
                media_id, payload, speakers, seconds = layout(row['segments'], parts, infos)
                if media_id not in media:
                    media[media_id] = make_media(root, case, row, media_id, payload, speakers, seconds,
                                               parts, infos, rhubarb, ffmpeg, document)
                entries.append(dict(identity(row), media_id=media_id,
                    audio='res://data/voice/' + media_id + '.ogg',
                    cues='res://data/voice/' + media_id + '.cues.json', seconds=seconds,
                    speaker_segments=speakers))
            verify_inputs(root, case, document)
            manifest = dict(schema_version=1, catalog_sha256=intake.fingerprint(case/'catalog.json'),
                            evidence='authoring_packaging_only', state='packed' if not pending else 'packing',
                            entries=entries, excluded=excluded, pending=pending)
            if 'component_recipes' in document:
                manifest['component_recipes'] = document['component_recipes']
            publish_manifest(case, state, manifest)
            return manifest
    except Exception as error:
        folder = state/'runs'/stamp()
        produce.write(folder/'receipt.json', dict(kind='voice_cpu_packaging_pass', state='failed',
            started_utc=started, finished_utc=produce.now(), error=str(error), traceback=traceback.format_exc()))
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=intake.ROOT)
    parser.add_argument('--rhubarb', required=True)
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg') or 'ffmpeg')
    parser.add_argument('--watch', action='store_true')
    parser.add_argument('--poll-seconds', type=float, default=15)
    args = parser.parse_args()
    if not math.isfinite(args.poll_seconds) or not 0 < args.poll_seconds <= 60:
        parser.error('--poll-seconds must be greater than zero and at most sixty')
    previous = None
    while True:
        result = package_once(args.root, args.case, args.rhubarb, args.ffmpeg)
        status = (len(result['entries']), len(result['pending']), len(result['excluded']))
        if status != previous:
            print(json.dumps(dict(packed=status[0], pending=status[1], excluded=status[2])), flush=True)
            previous = status
        if not args.watch:
            break
        try:
            progress = intake.read_json(args.case/'progress.json') if (args.case/'progress.json').exists() else {}
            if progress.get('state') == 'generated':
                if result['pending']:
                    raise ValueError('Producer reports generated, but completed parts are missing')
                break
        except Exception as error:
            produce.write(args.case/'assembly_state/runs'/stamp()/'receipt.json', dict(
                kind='voice_cpu_packaging_watch', state='failed', finished_utc=produce.now(),
                error=str(error), traceback=traceback.format_exc()))
            raise
        time.sleep(args.poll_seconds)


if __name__ == '__main__':
    main()
