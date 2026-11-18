from pathlib import Path
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'voice'))
import produce


class ProducerCustodyTests(unittest.TestCase):
    def test_unsettled_native_attempt_blocks_duplicate_resume(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            folder = case/'attempts'/'original'
            folder.mkdir(parents=True)
            receipt = folder/'receipt.json'
            for state in ('waiting', 'queued', 'validating'):
                original = json.dumps(dict(state=state, lane_process_pid=12345))
                receipt.write_text(original, encoding='utf-8')
                with self.subTest(state=state), self.assertRaisesRegex(ValueError, 'custody'):
                    produce.check_unfinished_attempts(case)
                self.assertEqual(receipt.read_text(encoding='utf-8'), original)

    def test_finished_or_partial_receipts_allow_missing_only_resume(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            for state in ('complete', 'partial', 'validation_failed', 'finished'):
                folder = case/'attempts'/state
                folder.mkdir(parents=True)
                (folder/'receipt.json').write_text(json.dumps(dict(state=state)), encoding='utf-8')
            produce.check_unfinished_attempts(case)


if __name__ == '__main__':
    unittest.main()
