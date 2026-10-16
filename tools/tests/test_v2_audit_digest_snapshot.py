"""Source reuse must preserve stale-proof rejection, even without mtime changes."""
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_orison_v2_completeness as audit


class DigestSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'game/scripts/fixture.gd'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(b'original')

    def test_repeated_receipts_hash_each_domain_once_then_recheck(self):
        snapshot = audit._InputDigests(self.root)
        with patch.object(snapshot, '_read', side_effect=lambda k: k+'-digest') as read:
            for _ in range(20):
                self.assertEqual(snapshot.get('runtime'), 'runtime-digest')
                self.assertEqual(snapshot.get('surface'), 'surface-digest')
            self.assertEqual(read.call_count, 2)
            snapshot.verify_unchanged()
            self.assertEqual(read.call_count, 4)

    def test_same_size_edit_with_preserved_timestamp_is_rejected(self):
        snapshot = audit._InputDigests(self.root)
        snapshot.get('runtime')
        stat = self.source.stat()
        self.source.write_bytes(b'modified')
        os.utime(self.source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        with self.assertRaisesRegex(audit.AuditError, 'runtime inputs changed'):
            snapshot.verify_unchanged()

    def test_source_addition_is_rejected(self):
        snapshot = audit._InputDigests(self.root)
        snapshot.get('runtime')
        (self.source.parent / 'added.gd').write_bytes(b'new')
        with self.assertRaises(audit.AuditError): snapshot.verify_unchanged()

    def test_source_removal_is_rejected(self):
        snapshot = audit._InputDigests(self.root)
        snapshot.get('runtime')
        self.source.unlink()
        with self.assertRaises(audit.AuditError): snapshot.verify_unchanged()

    def test_next_invocation_reads_changed_sources(self):
        first = audit._InputDigests(self.root).get('runtime')
        self.source.write_bytes(b'changed')
        self.assertNotEqual(first, audit._InputDigests(self.root).get('runtime'))

    def test_changed_surface_content_is_rejected(self):
        snapshot = audit._InputDigests(self.root)
        with patch('v2_surface_evidence.inputs', side_effect=[{'sha256':'before'}, {'sha256':'after'}]):
            self.assertEqual(snapshot.get('surface'), 'before')
            with self.assertRaisesRegex(audit.AuditError, 'surface inputs changed'):
                snapshot.verify_unchanged()

    def test_ledger_cannot_return_after_sources_change(self):
        snapshot = audit._InputDigests(self.root)
        snapshot.get('runtime')
        inputs = SimpleNamespace(v2={}, digests=snapshot)
        def change_during_build(_ledger): self.source.write_bytes(b'changed')
        with patch.object(audit, 'V2Model'), patch.object(audit, 'Evidence'), patch.object(audit.Ledger, '_build', change_during_build):
            with self.assertRaisesRegex(audit.AuditError, 'inputs changed'):
                audit.Ledger(inputs)

    def test_snapshot_cannot_validate_another_checkout(self):
        with self.assertRaisesRegex(audit.AuditError, 'another checkout'):
            audit.runtime_receipt_errors({}, self.root / 'other', audit._InputDigests(self.root))


if __name__ == '__main__': unittest.main()
