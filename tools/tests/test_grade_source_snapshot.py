import hashlib,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from grade_source_snapshot import validate

class GradeSnapshot(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.dep=self.root/'test.gd';self.dep.write_bytes(b'extends Node\r\n')
        self.data=dict(evidence_class='INERT',failures=0,source=dict(runtime_inputs_sha256='current',test_dependencies={'test.gd':hashlib.sha256(b'extends Node\n').hexdigest()}))
        self.path=self.root/'survey.json';self.save()
    def save(self):
        self.path.write_text(json.dumps(self.data));self.plan=dict(runtime_survey='survey.json',bindings={'survey.json':hashlib.sha256(self.path.read_bytes()).hexdigest()})
    def test_bound_unchanged_discovery(self):
        with patch('grade_source_snapshot.runtime_inputs_sha256',return_value='current'):self.assertEqual(validate(self.plan,self.root),self.data)
    def test_changed_production_or_test_dependency_is_rejected(self):
        with patch('grade_source_snapshot.runtime_inputs_sha256',return_value='different'),self.assertRaisesRegex(ValueError,'production'):validate(self.plan,self.root)
        self.dep.write_text('extends Node3D')
        with patch('grade_source_snapshot.runtime_inputs_sha256',return_value='current'),self.assertRaisesRegex(ValueError,'test dependency'):validate(self.plan,self.root)
    def test_missing_unbound_or_failed_discovery_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'required'):validate({},self.root)
        self.plan['bindings']={}
        with self.assertRaisesRegex(ValueError,'source-bound'):validate(self.plan,self.root)
        self.data['failures']=1;self.save()
        with self.assertRaisesRegex(ValueError,'Failed'):validate(self.plan,self.root)

if __name__=='__main__':unittest.main()
