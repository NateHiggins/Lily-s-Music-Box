"""Real file replacement, Windows sharing retries and publication boundaries."""
from pathlib import Path
import os,sys,tempfile,unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import publish_v2_surface_packet as p
class PublicationTests(unittest.TestCase):
    def test_replace_preserves_old_bytes_until_commit(self):
        with tempfile.TemporaryDirectory() as d:
            target=Path(d)/'inventory.json';target.write_bytes(b'old')
            replace=os.replace;seen=[]
            def inspect(source,destination):
                seen.append(target.read_bytes());self.assertEqual(Path(source).read_bytes(),b'new')
                replace(source,destination)
            with patch.object(p.os,'replace',side_effect=inspect):p.atomic_write(target,b'new')
            self.assertEqual(seen,[b'old']);self.assertEqual(target.read_bytes(),b'new');self.assertEqual(list(Path(d).glob('*.publication')),[])
    def test_transient_sharing_failure_retries_same_staged_file(self):
        with tempfile.TemporaryDirectory() as d:
            target=Path(d)/'inventory.json';target.write_bytes(b'old');replace=os.replace;calls=[]
            def retry(source,destination):
                calls.append(source);self.assertEqual(target.read_bytes(),b'old')
                if len(calls)<3:raise PermissionError('sharing violation')
                replace(source,destination)
            with patch.object(p.os,'replace',side_effect=retry),patch.object(p.time,'sleep'):p.atomic_write(target,b'new')
            self.assertEqual(len(set(calls)),1);self.assertEqual(len(calls),3);self.assertEqual(target.read_bytes(),b'new')
    def test_permanent_failure_keeps_old_bytes_and_cleans_staging(self):
        with tempfile.TemporaryDirectory() as d:
            target=Path(d)/'inventory.json';target.write_bytes(b'old')
            with patch.object(p.os,'replace',side_effect=OSError(22,'invalid argument')),patch.object(p.time,'sleep'):
                with self.assertRaises(OSError):p.atomic_write(target,b'new')
            self.assertEqual(target.read_bytes(),b'old');self.assertEqual(list(Path(d).glob('*.publication')),[])
    def test_unqualified_source_cannot_touch_destination(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);destination=root/'destination';destination.mkdir();(destination/'keep').write_bytes(b'old')
            with patch.object(p,'qualify',return_value={'result':'FAIL','defects':['stale']}):
                with self.assertRaises(ValueError):p.publish(root/'source',root/'archive',destination)
            self.assertEqual([f.name for f in destination.iterdir()],['keep']);self.assertFalse((root/'archive').exists())
    def test_review_path_escape_is_rejected(self):
        import json
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            for name in ['../escape.png','nested/escape.png','nested\\escape.png','..']:
                (root/'visual_review.json').write_text(json.dumps({'images':[{'file':name}]}))
                with self.assertRaises(ValueError):p.image_names(root)
    def test_inconsistent_preserved_inventory_stops_before_publication(self):
        import gzip,json,hashlib
        with tempfile.TemporaryDirectory() as d:
            previous=Path(d)/'previous';previous.mkdir()
            for name in p.CORE:
                if name!='surface-inventory.json':(previous/name).write_bytes(b'{}')
            (previous/'visual_review.json').write_text('{"images":[]}')
            (previous/'runtime_contract.json').write_text(json.dumps({'inventory_sha256':hashlib.sha256(b'expected').hexdigest()}))
            (previous/'surface-inventory.json.gz').write_bytes(gzip.compress(b'corrupted'))
            destination=Path(d)/'destination'
            with self.assertRaisesRegex(ValueError,'Previous inventory'):p.preserve(previous,destination)
            self.assertFalse(destination.exists())
if __name__=='__main__':unittest.main()
