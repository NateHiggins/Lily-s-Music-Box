"""Resumable, bounded authoring batches using Omni's installed voice backend."""
from __future__ import annotations
import argparse
from collections import defaultdict
from contextlib import contextmanager
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import wave
import array

import catalog
import intake

HOME = Path.home()
BACKEND = HOME/'local-llm/voice/say.py'
VOICE_PYTHON = Path('C:/devkit/voice/venv/Scripts/python.exe')
PRIORITY = HOME/'homebrew-tools/lane_priority.py'
PRODUCER_SHA256 = intake.fingerprint(Path(__file__))


class GenerationPaused(Exception):
    pass


def now():
    return datetime.now(timezone.utc).isoformat()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix(path.suffix + '.pending')
    pending.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(pending, path)


@contextmanager
def exclusive(case):
    """Kernel-backed lock releases on process death; no stale PID guesswork."""
    handle = (case/'producer.lock').open('a+b')
    handle.seek(0)
    if os.name == 'nt':
        import msvcrt
        try:
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            handle.close()
            raise ValueError('Another producer owns this case')
    else:
        import fcntl
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    try:
        yield
    finally:
        handle.close()


def make_parts(document, registry):
    """Identical words from the same selected voice share one recording."""
    parts, identities = [], {}
    for row in document['lines']:
        for segment in row['segments']:
            voice = registry['profiles'][segment['profile_id']]
            key = (segment['profile_id'], catalog.text_hash(segment['text']), voice['reference']['sha256'])
            if key not in identities:
                identities[key] = segment['part_id']
                parts.append(dict(part_id=segment['part_id'], profile_id=segment['profile_id'],
                    text=segment['text'], text_sha256=key[1], reference_sha256=key[2], seed=voice['seed']))
            segment['part_id'] = identities[key]
    if len({part['part_id'] for part in parts}) != len(parts):
        raise ValueError('Generated part ID collides with another authored line')
    return parts


def inspect_wav(path):
    with wave.open(str(path), 'rb') as audio:
        if (audio.getnchannels(), audio.getsampwidth(), audio.getcomptype()) != (1, 2, 'NONE'):
            raise ValueError(f'Unexpected WAV format: {path}')
        samples = array.array('h', audio.readframes(audio.getnframes()))
        if not samples or not any(samples):
            raise ValueError(f'Silent or empty WAV: {path}')
        clipped = sum(abs(value) >= 32767 for value in samples)
        if clipped:
            raise ValueError(f'Clipped speech ({clipped} samples): {path}')
        return dict(seconds=audio.getnframes()/audio.getframerate(), sample_rate=audio.getframerate(),
                    peak=max(abs(value) for value in samples)/32768)


def validate_part(case, part):
    receipt = case/'parts'/(part['part_id'] + '.record.json')
    if not receipt.exists():
        return False
    record = intake.read_json(receipt)
    path = case/'parts'/(part['part_id'] + '.wav')
    if record['input'] != part or intake.fingerprint(path) != record['wav_sha256']:
        raise ValueError(f'Changed completed part: {part["part_id"]}')
    return True


def reuse_parts(case, source_case):
    """Adopt equivalent recorded takes into a new freeze; preserve origin evidence."""
    with exclusive(case):
        verify_case(case)
        verify_case(source_case)
        original = intake.read_json(source_case/'catalog.json')
        target = intake.read_json(case/'catalog.json')
        def intent(part):
            return tuple(part[key] for key in ('profile_id', 'text', 'text_sha256', 'reference_sha256', 'seed'))
        candidates = {}
        for part in original['parts']:
            if validate_part(source_case, part):
                candidates.setdefault(intent(part), part)
        copied = 0
        for part in target['parts']:
            source_part = candidates.get(intent(part))
            if source_part is None or validate_part(case, part):
                continue
            source_record = source_case/'parts'/(source_part['part_id'] + '.record.json')
            record = intake.read_json(source_record)
            output = case/'parts'/(part['part_id'] + '.wav')
            output.parent.mkdir(exist_ok=True)
            if output.exists():
                raise ValueError(f'Unreceipted reuse output exists: {output}')
            os.link(source_case/'parts'/(source_part['part_id'] + '.wav'), output)
            record = dict(record, input=part, reuse=dict(source_record=str(source_record),
                source_record_sha256=intake.fingerprint(source_record), source_part_id=source_part['part_id'],
                observed_utc=now(), equivalent_voice_text_reference_seed=True))
            write(output.with_suffix('.record.json'), record)
            copied += 1
        return copied


def next_batch(parts, completed, max_parts=6, max_words=260):
    candidates = [p for p in parts if p['part_id'] not in completed]
    if not candidates:
        return []
    voice = candidates[0]['profile_id']
    result, words = [], 0
    for part in candidates:
        if part['profile_id'] != voice:
            continue
        count = len(part['text'].split())
        if result and (len(result) >= max_parts or words + count > max_words):
            break
        result.append(part)
        words += count
    return result


def wait_medium(case=None):
    sys.path.insert(0, str(PRIORITY.parent))
    spec = importlib.util.spec_from_file_location('voice_lane_priority', PRIORITY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.POLL_SECONDS = 3
    while not module.turn('medium'):
        if case is not None and (case/'STOP_AFTER_BATCH').exists():
            raise GenerationPaused()
        time.sleep(3)


def generate_batch(root, case, registry, batch, reference_root):
    folder = case/'attempts'/('batch_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%f'))
    folder.mkdir(parents=True)
    voice = batch[0]['profile_id']
    request = intake.voice_request(registry, voice, batch[0]['text'], reference_root)['args']
    if 'like' not in request:
        raise ValueError('Production requires an approved reference, never redesign')
    outputs = [folder/(part['part_id'] + '.wav') for part in batch]
    job = dict(kind='clone', texts=[part['text'] for part in batch], paths=list(map(str, outputs)),
               voice=None, like=request['like'], ref_text=request['ref_text'], language='English', seed=request['seed'])
    write(folder/'job.json', job)
    write(folder/'runs.json', [dict(gpu=[str(VOICE_PYTHON), '-I', str(BACKEND), '--lane-job', str(folder/'job.json')],
         scene=f'voice production {voice} {len(batch)} clips', log=str(folder/'generation.log'), timeout=1200)])
    observation = dict(kind='voice_authoring_batch', started_utc=now(), producer_pid=os.getpid(),
        producer_sha256=PRODUCER_SHA256,
        backend_sha256=intake.fingerprint(BACKEND), input=batch, reference_sha256=batch[0]['reference_sha256'],
        job_sha256=intake.fingerprint(folder/'job.json'), state='waiting')
    write(folder/'receipt.json', observation)
    try:
        wait_medium(case)
        if (case/'STOP_AFTER_BATCH').exists():
            raise GenerationPaused()
    except GenerationPaused:
        observation.update(state='paused_before_queue', finished_utc=now())
        write(folder/'receipt.json', observation)
        raise
    catalog.verify_sources(root, intake.read_json(case/'catalog.json'))
    intake.voice_request(registry, voice, batch[0]['text'], reference_root)
    observation.update(state='queued', queued_utc=now())
    write(folder/'receipt.json', observation)
    with (folder/'launch.log').open('w', encoding='utf-8') as log:
        command = ['pwsh', '-NoProfile', '-File', str(root/'tools/lane.ps1'), 'batch',
                   '-BatchFile', str(folder/'runs.json'), '-WaitMinutes', '240']
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        observation['lane_process_pid'] = process.pid
        write(folder/'receipt.json', observation)
        code = process.wait()
    observation.update(finished_utc=now(), exit_code=code, state='validating', outputs=[])
    write(folder/'receipt.json', observation)
    try:
        for part, output in zip(batch, outputs):
            if not output.exists() or not output.with_suffix('.json').exists():
                continue
            metadata = intake.read_json(output.with_suffix('.json'))
            if metadata['text'] != part['text'] or metadata['kind'] != 'clone' or metadata['ref_text'] != request['ref_text']:
                raise ValueError(f'Generation words/reference mismatch: {output}')
            if Path(metadata['like']).resolve() != Path(request['like']).resolve() or metadata['seed'] != request['seed']:
                raise ValueError(f'Generation clone reference/seed mismatch: {output}')
            metrics = inspect_wav(output)
            if metadata['sample_rate'] != metrics['sample_rate']:
                raise ValueError(f'Generation sample rate mismatch: {output}')
            if intake.fingerprint(Path(request['like'])) != part['reference_sha256']:
                raise ValueError('Reference changed during speech generation')
            target = case/'parts'/output.name
            target.parent.mkdir(exist_ok=True)
            if target.exists():
                raise ValueError(f'Refusing to overwrite existing speech: {target}')
            os.link(output, target)
            record = dict(input=part, wav_sha256=intake.fingerprint(target), metrics=metrics,
                          generation=metadata, batch_receipt=str(folder/'receipt.json'))
            write(target.with_suffix('.record.json'), record)
            observation['outputs'].append(dict(part_id=part['part_id'], wav_sha256=record['wav_sha256']))
        observation['state'] = 'complete' if not code and len(observation['outputs']) == len(batch) else 'partial'
    except Exception as error:
        observation.update(state='validation_failed', validation_error=str(error))
        raise
    finally:
        observation['validated_utc'] = now()
        write(folder/'receipt.json', observation)
    if code or len(observation['outputs']) != len(batch):
        raise ValueError(f'Partial/failed batch retained at {folder}; resume only missing parts')


def run(root, case, reference_root, max_batches):
    with exclusive(case):
        check_unfinished_attempts(case)
        verify_case(case)
        document = intake.read_json(case/'catalog.json')
        registry = intake.load_profiles(case/'profiles.json')
        parts = document['parts']
        completed = {part['part_id'] for part in parts if validate_part(case, part)}
        count = 0
        while batch := next_batch(parts, completed):
            if (case/'STOP_AFTER_BATCH').exists():
                break
            verify_case(case)
            catalog.verify_sources(root, document)
            write(case/'progress.json', dict(state='generating', updated_utc=now(), producer_pid=os.getpid(),
                  completed=len(completed), total=len(parts), next_profile=batch[0]['profile_id']))
            try:
                generate_batch(root, case, registry, batch, reference_root)
            except GenerationPaused:
                break
            completed.update(part['part_id'] for part in batch)
            count += 1
            print(f'{len(completed)}/{len(parts)} clips complete', flush=True)
            if max_batches and count >= max_batches:
                break
        state = ('generated' if len(completed) == len(parts) else
                 'paused' if (case/'STOP_AFTER_BATCH').exists() else 'bounded_batch_complete')
        write(case/'progress.json', dict(state=state, updated_utc=now(), completed=len(completed), total=len(parts)))


def verify_case(case):
    for name, path in [('catalog', case/'catalog.json'), ('backend', BACKEND)]:
        expected = (case/(name + '.sha256')).read_text(encoding='ascii').strip()
        if intake.fingerprint(path) != expected:
            raise ValueError(f'Frozen {name} changed')


def check_unfinished_attempts(case):
    pending = []
    for path in (case/'attempts').glob('*/receipt.json'):
        receipt = intake.read_json(path)
        if receipt.get('state') in ('waiting', 'queued', 'validating'):
            pending.append(str(path))
    if pending:
        raise ValueError('Unfinished native custody; inspect process identity and preserved outputs before resuming: '
                         + ', '.join(pending))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['plan', 'run', 'status'])
    parser.add_argument('--root', type=Path, default=intake.ROOT)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--reference-root', type=Path, required=True)
    parser.add_argument('--max-batches', type=int, default=0)
    parser.add_argument('--dynamic', action='store_true', help='plan finite dynamic lines and source-backed components')
    parser.add_argument('--reuse-from', type=Path, help='reuse verified equivalent takes in a new freeze')
    args = parser.parse_args()
    if args.command == 'plan':
        inventory = None
        if args.dynamic:
            import dynamic
            inventory = dynamic.build(args.root)
        document = catalog.freeze(args.root, args.case, inventory['supplemental_rows'] if inventory else ())
        if inventory:
            document['lines'] = [row for row in document['lines'] if 'source_bindings' in row]
            document['component_recipes'] = inventory['component_recipes']
            write(args.case/'dynamic_inventory.json', inventory)
        registry = intake.load_profiles(args.case/'profiles.json')
        document['parts'] = make_parts(document, registry)
        for part in document['parts']:
            intake.voice_request(registry, part['profile_id'], part['text'], args.reference_root)
        write(args.case/'catalog.json', document)
        (args.case/'catalog.sha256').write_text(intake.fingerprint(args.case/'catalog.json'), encoding='ascii')
        (args.case/'backend.sha256').write_text(intake.fingerprint(BACKEND), encoding='ascii')
        reused = reuse_parts(args.case, args.reuse_from) if args.reuse_from else 0
        print(json.dumps(dict(lines=len(document['lines']), parts=len(document['parts']), reused=reused)))
    elif args.command == 'run':
        run(args.root, args.case, args.reference_root, args.max_batches)
    else:
        print((args.case/'progress.json').read_text(encoding='utf-8'))


if __name__ == '__main__':
    main()
