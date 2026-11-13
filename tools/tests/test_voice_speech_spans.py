"""Reviewed speech projections preserve dialogue while excluding performed actions."""
from pathlib import Path
import copy
import hashlib
import json
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/voice'))
import catalog
import intake

EXPECTED = {
    'st_coin': "Mind the step going up. It's been loose since Harding.",
    'st_int_open': "Don't make a thing of it. My feet have filed a complaint.",
    'st_rt_cup': "Look at that. Mouth down, all of them. You're hired. The pay's terrible, the dog outranks you, and the cat outranks the dog.",
    'av_e5': 'All right, let me show you. May I?',
    'av_f5': "I framed you out. I did that and didn't see it. I'm sorry. Pick the one you want.",
    'av_o10': "It was. They've inquired back. They want to hear the act. Here. A recording test, if the room is suitable. Two numbers.",
    'av_o12': 'They asked when we could be ready.',
    'av_o18': "It's a useful expression. Saves postage later. Listen. I thought, for the second number. There.",
    'av_o22': 'There. Two bars later.',
    'av_o34': "You haven't tried it.",
    'av_o38': 'I still like it.',
    'av_o4': 'Yes. Lovely.',
    'av_o40': "They'll only hear us once. At first, I mean. They won't know which night it usually comes right.",
    'av_o48': "Yes. I did. I'm sorry. Would you like to do the test?",
    'av_o54': '',
    'av_o58': 'I do still want to try the two bars.',
    'av_o62': 'Together.',
    'av_o66': 'Now let me show you what I meant.',
    'av_o8': 'The little picture concern in Astoria. The one I sent the photograph to.',
    'av_v2': 'You do radiators.',
    'lo_h4': 'A hat is a strong word for this, night man, it has four pins and comes off with one hand and I tested that. She pays in prints. I said no frames. She framed them.',
    'tv_o3': "Well. That's that, then. I'm on Sunday. Go on, you've got pipes.",
    'nq_c5': '',
    'nq_c9': '',
}
# If a future marked aside is spoken, review it and list its source/pointer here;
# do not manufacture a stage projection simply to satisfy the coverage check.
KEPT_MARKED = set()


def resolve(document, pointer):
    result = document
    for token in pointer.lstrip('/').split('/'):
        key = token.replace('~1', '/').replace('~0', '~')
        result = result[int(key)] if isinstance(result, list) else result[key]
    return result


class SpeechSpanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.map = intake.read_json(ROOT/'game/data/voice/speech_spans.json')
        cls.sources = {entry['source']: intake.read_json(ROOT/entry['source']) for entry in cls.map['entries']}
        cls.registry = intake.load_profiles(intake.PROFILES)
        cls.guests = intake.read_json(ROOT/'game/data/voice/guest_turns.json')

    def text(self, entry):
        return resolve(self.sources[entry['source']], entry['pointer'])

    def row(self, entry):
        text = self.text(entry)
        return dict(line_id='fixture__line', profile_id='fixture_voice', text=text,
                    text_sha256=catalog.text_hash(text), state='ready', segments=[])

    def test_exact_source_hashes_and_reviewed_spoken_words(self):
        self.assertEqual(self.map['schema_version'], 1)
        actual = {entry['pointer'].split('/')[2]: entry for entry in self.map['entries']}
        self.assertEqual(len(actual), len(self.map['entries']))
        self.assertEqual(set(actual), set(EXPECTED))
        for node, entry in actual.items():
            with self.subTest(node=node):
                text = self.text(entry)
                self.assertEqual(entry['text_sha256'], hashlib.sha256(text.encode('utf-8')).hexdigest())
                row = self.row(entry)
                catalog.apply_speech_projection(row, entry)
                self.assertEqual(' '.join(part['text'] for part in row['segments']), EXPECTED[node])
                self.assertEqual(row['text'], text)
                self.assertEqual(row['text_sha256'], entry['text_sha256'])
                self.assertEqual(row['state'], 'ready' if EXPECTED[node] else 'silent')

    def test_turns_and_gaps_partition_every_original_character(self):
        for entry in self.map['entries']:
            text = self.text(entry)
            with self.subTest(pointer=entry['pointer']):
                self.assertEqual(entry['length'], len(text))
                pieces = sorted((piece['start'], piece['end']) for piece in entry['turns'] + entry['gaps'])
                cursor = 0
                for start, end in pieces:
                    self.assertIs(type(start), int)
                    self.assertIs(type(end), int)
                    self.assertEqual(start, cursor)
                    self.assertLess(start, end)
                    self.assertLessEqual(end, len(text))
                    cursor = end
                self.assertEqual(cursor, len(text))
                self.assertEqual(''.join(text[start:end] for start, end in pieces), text)
                self.assertEqual(entry['turns'], sorted(entry['turns'], key=lambda turn: turn['start']))

    def test_gaps_are_explicit_actions_or_nonverbal_recognition_not_omitted_speech(self):
        for entry in self.map['entries']:
            text = self.text(entry)
            for gap in entry['gaps']:
                excerpt = text[gap['start']:gap['end']]
                with self.subTest(pointer=entry['pointer'], excerpt=excerpt):
                    self.assertTrue(gap['reason'].strip())
                    if gap['kind'] == 'separator':
                        self.assertFalse(any(character.isalnum() for character in excerpt))
                    else:
                        self.assertEqual(gap['kind'], 'stage_direction')
                        if entry['pointer'] in ('/nodes/nq_c5/line', '/nodes/nq_c9/line'):
                            self.assertIn(excerpt, ('She looks from the capitals to the hand.', 'She keeps the pencil.'))
                        else:
                            self.assertTrue(excerpt.startswith('(') and excerpt.endswith(')'))
                            self.assertEqual(excerpt.count('('), excerpt.count(')'))
            for turn in entry['turns']:
                self.assertNotIn('(', text[turn['start']:turn['end']])
                self.assertNotIn(')', text[turn['start']:turn['end']])

    def test_all_marked_ready_candidates_have_an_explicit_review(self):
        unprojected = catalog.build(ROOT, self.registry, self.guests, performance_map={})
        markers = '()[]{}*<>（）【】'
        candidates = {(row['source'], row['pointer']) for row in unprojected['lines']
                      if row['state'] == 'ready' and any(char in row['text'] for char in markers)}
        mapped = {(entry['source'], entry['pointer']) for entry in self.map['entries']
                  if any(char in self.text(entry) for char in markers)}
        self.assertEqual(candidates, mapped | KEPT_MARKED,
                         'Review new marked speech: spoken asides must be kept, not blanket-stripped.')

    def test_real_spoken_recounting_and_short_beats_stay_spoken(self):
        document = catalog.build(ROOT, self.registry, self.guests)
        rows = {row['line_id']: row for row in document['lines']}
        for identity in ('mae_kessler__mk_nadia', 'nadia_quell__nq_estate',
                         'mystery_adela_voss__av_d1s', 'cal_dwyer__cd_int_beat',
                         'rhea_sato__rs_int_beat', 'stacy__st_int_beat'):
            with self.subTest(identity=identity):
                row = rows[identity]
                self.assertEqual(row['state'], 'ready')
                self.assertEqual([part['text'] for part in row['segments']], [row['text']])
                self.assertNotIn('stage_directions', row)

    def test_unmapped_spoken_parenthetical_is_preserved_automatically(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ('dialogue', 'mystery', 'opinions'):
                (root/'game/data'/name).mkdir(parents=True)
            (root/'game/data/case01_dialogue.json').write_text('{"nodes":{}}', encoding='utf-8')
            text = 'It was (as I told you) deliberate.'
            source = dict(meta=dict(resident_id='cal_dwyer'), nodes=dict(aside=dict(line=text)))
            (root/'game/data/dialogue/cal_dwyer.json').write_text(json.dumps(source), encoding='utf-8')
            row = catalog.build(root, self.registry, performance_map={})['lines'][0]
            self.assertEqual(row['text'], text)
            self.assertEqual([part['text'] for part in row['segments']], [text])
            self.assertNotIn('stage_directions', row)

    def test_stale_text_and_malformed_partitions_fail_closed(self):
        entry = self.map['entries'][0]
        row = self.row(entry)
        row['text'] += ' Changed.'
        row['text_sha256'] = catalog.text_hash(row['text'])
        with self.assertRaisesRegex(ValueError, 'Stale speech projection'):
            catalog.apply_speech_projection(row, entry)
        for change in ('overlap', 'missing', 'unknown_gap'):
            altered = copy.deepcopy(entry)
            if change == 'overlap':
                altered['turns'][0]['start'] = 0
            elif change == 'missing':
                altered['turns'][0]['end'] -= 1
            else:
                altered['gaps'][0]['kind'] = 'ignore_anything'
            with self.subTest(change=change), self.assertRaises(ValueError):
                catalog.apply_speech_projection(self.row(entry), altered)


if __name__ == '__main__':
    unittest.main()
