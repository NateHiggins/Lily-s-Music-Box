"""Exercise artifact custody on scratch files only."""
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
import stat
import sys
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import artifact_retention as retention


class ArtifactRetention(unittest.TestCase):
    def setUp(self):
        scratch = TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.case = self.root / 'finished'
        self.case.mkdir()
        self.image = self.case / 'draft.png'
        self.image.write_bytes(b'preview')
        self.terminal = self.case / 'terminal.json'
        self.terminal.write_bytes(b'{"finished_utc":"2026-11-07T20:00:00Z","exit":0}')
        self.start = datetime(2026, 11, 7, tzinfo=timezone.utc)
        clock = patch.object(retention, 'now', side_effect=lambda: self.start + timedelta(days=self.days))
        clock.start()
        self.addCleanup(clock.stop)
        self.days = 0

    def record(self, *, previews=None, rejected=None, pins=None, producer_records=()):
        return retention.record(self.root, 'finished', 'owner', 'terminal.json',
                                previews or [], rejected or [], pins or [], producer_records)['plan_id']

    def test_restore_uses_the_approved_bytes_and_keeps_evidence(self):
        identity = self.record(previews=['draft.png'])
        with self.assertRaisesRegex(ValueError, 'period'):
            retention.quarantine(self.root, 'finished', identity)
        self.days = 14
        with self.assertRaisesRegex(ValueError, 'Approval'):
            retention.quarantine(self.root, 'finished', '0' * 64)
        retention.quarantine(self.root, 'finished', identity)
        self.assertFalse(self.image.exists())
        self.assertTrue(self.terminal.exists())
        retention.restore(self.root, identity)
        self.assertEqual(self.image.read_bytes(), b'preview')
        with self.assertRaisesRegex(ValueError, 'Restore'):
            retention.purge(self.root, identity)

    def test_purge_requires_both_waits_and_preserves_the_journal(self):
        identity = self.record(rejected=['draft.png'])
        self.days = 30
        retention.quarantine(self.root, 'finished', identity)
        with self.assertRaisesRegex(ValueError, 'Quarantine period'):
            retention.purge(self.root, identity)
        self.days = 44
        retention.purge(self.root, identity)
        retention.purge(self.root, identity)
        journal = self.root / retention.QUARANTINE / identity
        self.assertTrue((journal / 'purged.json').exists())
        self.assertTrue((journal / 'plan.json').exists())
        self.assertFalse((journal / 'files' / 'draft.png').exists())

    def test_failed_preflight_does_not_move_unmodified_siblings(self):
        other = self.case / 'other.png'
        other.write_bytes(b'original')
        identity = self.record(previews=['draft.png', 'other.png'])
        self.days = 14
        other.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'no longer matches'):
            retention.quarantine(self.root, 'finished', identity)
        self.assertEqual(self.image.read_bytes(), b'preview')

    def test_interrupt_can_resume_from_actual_file_locations(self):
        other = self.case / 'other.png'
        other.write_bytes(b'another')
        identity = self.record(previews=['draft.png', 'other.png'])
        self.days = 14
        real_rename = Path.rename

        def rename(path, target):
            if path == other:
                raise OSError('simulated interruption')
            return real_rename(path, target)

        with patch.object(Path, 'rename', rename), self.assertRaisesRegex(OSError, 'interruption'):
            retention.quarantine(self.root, 'finished', identity)
        self.assertFalse(self.image.exists())
        retention.quarantine(self.root, 'finished', identity)
        self.assertFalse(other.exists())
        retention.restore(self.root, identity)
        self.assertEqual(other.read_bytes(), b'another')

    def test_bound_and_hardlinked_files_are_refused(self):
        with self.assertRaisesRegex(ValueError, 'pinned'):
            self.record(previews=['draft.png'], pins=['draft.png'])
        note = self.case / 'review.json'
        note.write_bytes(b'{"image":"DRAFT.PNG"}')
        with self.assertRaisesRegex(ValueError, 'may reference'):
            self.record(previews=['draft.png'])
        note.unlink()
        os.link(self.image, self.case / 'linked.png')
        with self.assertRaisesRegex(ValueError, 'single-link'):
            self.record(previews=['draft.png'])

    def test_later_reference_and_restore_collision_are_refused(self):
        identity = self.record(previews=['draft.png'])
        self.days = 14
        retention.quarantine(self.root, 'finished', identity)
        self.days = 28
        (self.case / 'approval.md').write_text('Review draft.png', encoding='utf-16')
        with self.assertRaisesRegex(ValueError, 'may reference'):
            retention.purge(self.root, identity)
        self.image.write_bytes(b'new output')
        with self.assertRaisesRegex(ValueError, 'colliding'):
            retention.restore(self.root, identity)
        self.assertEqual(self.image.read_bytes(), b'new output')

    def test_producer_log_exemption_keeps_the_exact_original(self):
        log = self.case / 'renderer.log'
        log.write_bytes(b'Wrote draft.png')
        identity = self.record(previews=['draft.png'], producer_records=['renderer.log'])
        self.days = 14
        log.write_bytes(b'Changed output log')
        with self.assertRaisesRegex(ValueError, 'no longer matches'):
            retention.quarantine(self.root, 'finished', identity)
        self.assertTrue(self.image.exists())

    def test_escapes_and_windows_reparse_flag_are_refused(self):
        for name in ('../draft.png', 'C:/draft.png', 'sub\\draft.png', 'NUL.png', 'image.png:stream'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                retention.relative(name)
        junction = SimpleNamespace(st_mode=stat.S_IFDIR, st_file_attributes=stat.FILE_ATTRIBUTE_REPARSE_POINT)
        with patch.object(Path, 'lstat', return_value=junction), self.assertRaisesRegex(ValueError, 'Reparse point'):
            retention.plain(self.case / 'junction')


if __name__ == '__main__':
    unittest.main()
