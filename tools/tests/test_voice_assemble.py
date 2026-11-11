"""Immutable speech assembly, exact turn timing and failure-safe CPU packaging."""
from pathlib import Path
import array
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/voice'))
import assemble
import catalog
import intake
import produce


class VoiceAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.root, self.case = self.home/'root', self.home/'case'
        self.root.mkdir()
        (self.case/'parts').mkdir(parents=True)
        self.source = self.root/'authored.json'
        self.source.write_text('{"text":"frozen authored source"}', encoding='utf-8')
        self.document = dict(schema_version=1, source_bindings={'authored.json': intake.fingerprint(self.source)},
                             lines=[], parts=[])
        self.calls, self.hints = [], []
        self.failure = None
        self.side_effect = None
        self.patch = patch.object(assemble.subprocess, 'run', side_effect=self.tool)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def tool(self, command, **kwargs):
        self.calls.append(command)
        if command[0] == 'rhubarb':
            hint = Path(command[command.index('-d')+1]).read_text(encoding='utf-8')
            self.hints.append(hint)
            self.assertEqual(command[command.index('--extendedShapes')+1], 'GHX')
            with wave.open(command[-1], 'rb') as audio:
                seconds = audio.getnframes()/audio.getframerate()
            output = Path(command[command.index('-o')+1])
            if self.failure == 'rhubarb':
                output.write_text('{"partial":true}', encoding='utf-8')
                return subprocess.CompletedProcess(command, 7, 'native progress', 'alignment failed')
            duration = seconds + (1 if self.failure == 'duration' else 0)
            output.write_text(json.dumps(dict(metadata=dict(soundFile=command[-1], duration=duration),
                mouthCues=[dict(start=0, end=seconds, value='A')])), encoding='utf-8')
            if self.side_effect:
                self.side_effect()
            return subprocess.CompletedProcess(command, 0, 'native progress', '')
        self.assertEqual(command[0], 'ffmpeg')
        if '-c:a' in command:
            self.assertEqual(command[command.index('-c:a')+1], 'libvorbis')
            self.assertEqual(command[command.index('-q:a')+1], '5')
            if self.failure == 'ffmpeg':
                return subprocess.CompletedProcess(command, 9)
            Path(command[-1]).write_bytes(b'OggS\x00fixture-vorbis')
        return subprocess.CompletedProcess(command, 0)

    def part(self, key, text, frames=200, sample=1000, voice='guest_a', complete=True):
        part = dict(part_id=key, profile_id=voice, text=text, text_sha256=catalog.text_hash(text),
                    reference_sha256='a'*64, seed=1)
        self.document['parts'].append(part)
        path = self.case/'parts'/(key+'.wav')
        with wave.open(str(path), 'wb') as audio:
            audio.setparams((1, 2, 1000, 0, 'NONE', 'not compressed'))
            audio.writeframes(array.array('h', [sample]*frames).tobytes())
        if complete:
            self.complete(part)
        return part

    def complete(self, part):
        path = self.case/'parts'/(part['part_id']+'.wav')
        produce.write(path.with_suffix('.record.json'), dict(input=part, wav_sha256=intake.fingerprint(path)))

    def row(self, key, text, segments, **extra):
        row = dict(line_id=key, namespace='fixture', runtime_node_id=key, profile_id='guest_group',
                   owner_resident_id='cal_dwyer', text=text, text_sha256=catalog.text_hash(text), state='ready',
                   segments=segments)
        row.update(extra)
        self.document['lines'].append(row)
        return row

    def segment(self, part, start=0, end=None):
        return dict(part_id=part['part_id'], profile_id=part['profile_id'], text=part['text'],
                    start_char=start, end_char=end if end is not None else start+len(part['text']))

    def freeze(self):
        produce.write(self.case/'catalog.json', self.document)
        (self.case/'catalog.sha256').write_text(intake.fingerprint(self.case/'catalog.json'), encoding='ascii')

    def run_pack(self):
        return assemble.package_once(self.root, self.case, 'rhubarb', 'ffmpeg')

    def records(self):
        return list((self.case/'assembly_state/media').glob('*.record.json'))

    def test_single_part_is_hardlinked_and_original_text_aligns_to_runtime_ogg(self):
        text = 'A café.\nKeep every word.'
        part = self.part('part_a', text, frames=500)
        self.row('solo__node', text, [self.segment(part)])
        self.freeze()
        manifest = self.run_pack()
        entry = manifest['entries'][0]
        self.assertEqual(entry['seconds'], .5)
        self.assertEqual(self.hints, [text])
        self.assertEqual(entry['owner_resident_id'], 'cal_dwyer')
        self.assertEqual(entry['speaker_segments'][0], dict(profile_id='guest_a', part_id='part_a',
                         start=0, end=.5, start_char=0, end_char=len(text)))
        record = intake.read_json(self.records()[0])
        self.assertTrue(os.path.samefile(self.case/record['assembled_wav']['path'], self.case/'parts/part_a.wav'))
        packaged = intake.read_json(self.case/'packed'/(entry['media_id']+'.cues.json'))
        native = intake.read_json(self.case/record['native_cues']['path'])
        self.assertEqual(packaged['metadata']['soundFile'], entry['media_id']+'.ogg')
        self.assertTrue(native['metadata']['soundFile'].endswith('.wav'))
        self.assertEqual(packaged['mouthCues'], native['mouthCues'])
        self.assertEqual(manifest['evidence'], 'authoring_packaging_only')
        self.assertTrue((self.case/'assembly_state/producer.lock').exists())
        self.assertFalse((self.case/'producer.lock').exists())

    def test_guest_pcm_order_gap_timing_and_character_spans_are_exact(self):
        first = self.part('first', 'Tea.', frames=200, sample=1111)
        second = self.part('second', 'Coffee.', frames=300, sample=2222, voice='guest_b')
        text = 'Tea. — Coffee.'
        self.row('guests__turns', text, [self.segment(first), self.segment(second, text.index('Coffee'))])
        self.freeze()
        manifest = self.run_pack()
        entry = manifest['entries'][0]
        self.assertAlmostEqual(entry['seconds'], .63)
        self.assertEqual([(s['start'], s['end']) for s in entry['speaker_segments']], [(0, .2), (.33, .63)])
        self.assertEqual(entry['speaker_segments'][1]['start_char'], text.index('Coffee'))
        record = intake.read_json(self.records()[0])
        with wave.open(str(self.case/record['assembled_wav']['path']), 'rb') as audio:
            samples = array.array('h', audio.readframes(audio.getnframes()))
        self.assertEqual(list(samples), [1111]*200 + [0]*130 + [2222]*300)
        self.assertEqual(self.hints, [text])

    def test_aliases_and_hash_indexed_variants_share_only_identical_media(self):
        part = self.part('shared', 'Thank you.')
        first = self.row('a__reply', 'Thank you.', [self.segment(part)])
        second = self.row('b__reply', 'Thank you.', [self.segment(part)], runtime_node_id='gift:*',
                          runtime_node_is_pattern=True, owner_resident_id='stacy')
        variant = self.part('variant', 'Thank you.', sample=2000, voice='guest_b')
        self.row('c__reply', 'Thank you.', [self.segment(variant)])
        self.freeze()
        manifest = self.run_pack()
        entries = {e['line_id']: e for e in manifest['entries']}
        self.assertEqual(entries[first['line_id']]['audio'], entries[second['line_id']]['audio'])
        self.assertNotEqual(entries['a__reply']['audio'], entries['c__reply']['audio'])
        self.assertTrue(entries['b__reply']['runtime_node_is_pattern'])
        self.assertEqual(entries['b__reply']['text_sha256'], second['text_sha256'])
        self.assertEqual(len(list((self.case/'packed').glob('*.ogg'))), 2)
        self.assertEqual(len(self.hints), 2)

    def test_incomplete_live_parts_are_not_read_and_exclusions_stay_explicit(self):
        part = self.part('live', 'Not complete.', complete=False)
        (self.case/'parts/live.wav').write_bytes(b'backend still writing')
        self.row('pending__line', 'Not complete.', [self.segment(part)])
        self.row('written__line', 'Read it.', [], state='written')
        self.freeze()
        manifest = self.run_pack()
        self.assertEqual(manifest['entries'], [])
        self.assertEqual(manifest['pending'][0]['missing_parts'], ['live'])
        self.assertEqual(manifest['excluded'][0]['state'], 'written')
        self.assertEqual(self.calls, [])

    def test_resume_reuses_validated_media_without_aligning_or_encoding(self):
        part = self.part('done', 'Already done.')
        self.row('done__line', part['text'], [self.segment(part)])
        self.freeze()
        first = self.run_pack()
        before = (self.case/'runtime_manifest.json').read_bytes()
        self.calls.clear()
        self.assertEqual(self.run_pack(), first)
        self.assertEqual(self.calls, [])
        self.assertEqual((self.case/'runtime_manifest.json').read_bytes(), before)

    def test_changed_manifest_is_rejected_instead_of_silently_replaced(self):
        part = self.part('done', 'Already done.')
        self.row('done__line', part['text'], [self.segment(part)])
        self.freeze()
        self.run_pack()
        self.calls.clear()
        manifest = self.case/'runtime_manifest.json'
        changed = intake.read_json(manifest)
        changed['entries'][0]['audio'] = 'res://wrong.ogg'
        produce.write(manifest, changed)
        corrupted = manifest.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Changed runtime manifest'):
            self.run_pack()
        self.assertEqual(self.calls, [])
        self.assertEqual(manifest.read_bytes(), corrupted)

    def test_changed_source_wav_and_packed_asset_are_rejected(self):
        part = self.part('done', 'Already done.')
        self.row('done__line', part['text'], [self.segment(part)])
        self.freeze()
        result = self.run_pack()
        manifest = (self.case/'runtime_manifest.json').read_bytes()
        self.calls.clear()
        original_source = self.source.read_bytes()
        self.source.write_text('changed', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Frozen speech source changed'):
            self.run_pack()
        self.source.write_bytes(original_source)
        path = self.case/'parts/done.wav'
        original_wav = path.read_bytes()
        path.write_bytes(original_wav[:-2]+b'xx')
        with self.assertRaisesRegex(ValueError, 'Changed completed part'):
            self.run_pack()
        path.write_bytes(original_wav)
        ogg = self.case/'packed'/(result['entries'][0]['media_id']+'.ogg')
        ogg.write_bytes(b'OggSchanged')
        with self.assertRaisesRegex(ValueError, 'Changed packed'):
            self.run_pack()
        self.assertEqual(self.calls, [])
        self.assertEqual((self.case/'runtime_manifest.json').read_bytes(), manifest)

    def test_failed_encoding_keeps_prior_assets_and_reuses_successful_alignment(self):
        a = self.part('a', 'First.')
        b = self.part('b', 'Second.', complete=False)
        self.row('a__line', a['text'], [self.segment(a)])
        self.row('b__line', b['text'], [self.segment(b)])
        self.freeze()
        initial = self.run_pack()
        before = (self.case/'runtime_manifest.json').read_bytes()
        audio = self.case/'packed'/(initial['entries'][0]['media_id']+'.ogg')
        digest = intake.fingerprint(audio)
        self.complete(b)
        self.failure = 'ffmpeg'
        with self.assertRaisesRegex(ValueError, 'FFmpeg failed'):
            self.run_pack()
        self.assertEqual((self.case/'runtime_manifest.json').read_bytes(), before)
        self.assertEqual(intake.fingerprint(audio), digest)
        failed = [(p, p.read_bytes()) for p in (self.case/'assembly_state/attempts').glob('*/receipt.json')
                  if intake.read_json(p)['state'] == 'failed']
        self.assertEqual(len(failed), 1)
        self.calls.clear()
        self.failure = None
        final = self.run_pack()
        self.assertEqual(len(final['entries']), 2)
        self.assertFalse(any(command[0] == 'rhubarb' for command in self.calls))
        self.assertEqual(failed[0][0].read_bytes(), failed[0][1])

    def test_native_failure_retains_raw_partial_and_exact_command_result(self):
        part = self.part('a', 'A failed alignment.')
        self.row('a__line', part['text'], [self.segment(part)])
        self.freeze()
        self.failure = 'rhubarb'
        with self.assertRaisesRegex(ValueError, 'Rhubarb failed'):
            self.run_pack()
        native = next((self.case/'assembly_state/attempts').glob('*/rhubarb_evidence/*'))
        self.assertEqual(intake.read_json(native/'cues.json'), {'partial': True})
        result = intake.read_json(native/'result.json')
        self.assertEqual(result, dict(exit_code=7, stdout='native progress', stderr='alignment failed'))
        command = intake.read_json(native/'command.json')
        self.assertEqual(command[0], 'rhubarb')
        self.assertEqual((native/'dialogue.txt').read_text(encoding='utf-8'), part['text'])
        self.assertFalse((self.case/'runtime_manifest.json').exists())
        self.assertFalse(list((self.case/'packed').glob('*.ogg')))

    def test_interrupted_pair_install_recovers_without_repeating_verified_tools(self):
        part = self.part('a', 'An interrupted install.')
        self.row('a__line', part['text'], [self.segment(part)])
        self.freeze()
        link = os.link
        def interrupt(source, target):
            if Path(target).parent == self.case/'packed' and str(target).endswith('.cues.json'):
                raise OSError('simulated pair-install interruption')
            return link(source, target)
        with patch.object(assemble.os, 'link', side_effect=interrupt):
            with self.assertRaisesRegex(OSError, 'pair-install interruption'):
                self.run_pack()
        self.assertEqual(len(list((self.case/'packed').glob('*.ogg'))), 1)
        self.assertFalse((self.case/'runtime_manifest.json').exists())
        record = intake.read_json(self.records()[0])
        self.assertEqual(record['state'], 'prepared')
        failed_receipt = self.case/record['attempt']/'receipt.json'
        failure_bytes = failed_receipt.read_bytes()
        self.calls.clear()
        final = self.run_pack()
        self.assertEqual(len(final['entries']), 1)
        self.assertEqual(self.calls, [])
        self.assertEqual(failed_receipt.read_bytes(), failure_bytes)

    def test_duration_mismatch_and_mid_alignment_input_change_do_not_install_assets(self):
        part = self.part('a', 'Check duration.')
        self.row('a__line', part['text'], [self.segment(part)])
        self.freeze()
        self.failure = 'duration'
        with self.assertRaisesRegex(ValueError, 'duration'):
            self.run_pack()
        self.failure = None
        self.side_effect = lambda: self.source.write_text('changed during alignment', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Frozen speech source changed'):
            self.run_pack()
        self.assertFalse((self.case/'runtime_manifest.json').exists())
        self.assertFalse(list((self.case/'packed').glob('*.ogg')))

    def test_watch_exits_only_when_generation_and_packaging_are_both_complete(self):
        part = self.part('a', 'One complete line.')
        self.row('a__line', part['text'], [self.segment(part)])
        self.freeze()
        produce.write(self.case/'progress.json', {'state': 'generated'})
        arguments = ['assemble.py', '--root', str(self.root), '--case', str(self.case),
                     '--rhubarb', 'rhubarb', '--ffmpeg', 'ffmpeg', '--watch']
        with patch.object(sys, 'argv', arguments), patch.object(assemble.time, 'sleep') as sleep, redirect_stdout(io.StringIO()):
            assemble.main()
        sleep.assert_not_called()
        self.assertEqual(intake.read_json(self.case/'runtime_manifest.json')['state'], 'packed')


if __name__ == '__main__':
    unittest.main()
