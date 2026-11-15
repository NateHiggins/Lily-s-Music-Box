"""Export source seal: isolated temporary copies, never the owner checkout."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_staff_standing_columns as audit

class StaffStandingColumnTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for rel in audit.COMMON + audit.ADELA_COMMON:
            p = self.root / 'game' / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b'fixture source\n')
        rows = []
        for person in ['stacy', 'lily', 'adela_voss']:
            relative = 'cast/adela_voss' if person == 'adela_voss' else person
            folder = self.root / 'game/assets/characters' / relative
            folder.mkdir(parents=True, exist_ok=True)
            for part in ['', '__work_top', '__work_bottom', '__work_feet', '__p_top', '__p_feet', '__p_head']:
                stem = person + part
                (folder / (stem + '.gltf')).write_text(json.dumps({'buffers':[{'uri':stem+'.bin'}]}), encoding='utf-8')
                (folder / (stem + '.bin')).write_bytes(b'\x00\xfffixture bytes')
                (folder / (stem + '.gltf.import')).write_bytes(b'[remap]\npath="cache"\n[params]\nscale=1\n')
                if part:
                    (folder / (stem + '.json')).write_text('{}', encoding='utf-8')
            families = [['p_top','p_feet','p_head']] if person == 'adela_voss' else [['work_top','work_bottom','work_feet'], ['p_top','p_feet','p_head']]
            for parts in families:
                bindings = []
                # Fixture declares its source files independently of closure checking.
                candidates = [(self.root/'game'/rel, 'lf') for rel in audit.COMMON]
                if person == 'adela_voss':
                    candidates += [(self.root/'game'/rel, 'lf') for rel in audit.ADELA_COMMON]
                for suffix in [''] + ['__'+part for part in parts]:
                    stem = folder/(person+suffix)
                    candidates += [(Path(str(stem)+'.gltf'),'lf'), (Path(str(stem)+'.bin'),'raw'), (Path(str(stem)+'.gltf.import'),'params_lf')]
                    if suffix:
                        candidates.append((Path(str(stem)+'.json'),'lf'))
                for path,kind in candidates:
                    data=path.read_bytes()
                    if kind!='raw': data=data.replace(b'\r\n',b'\n')
                    if kind=='params_lf': data=data.split(b'[params]',1)[1]
                    bindings.append({'path':'res://'+path.relative_to(self.root/'game').as_posix(),'kind':kind,'sha256':hashlib.sha256(data).hexdigest()})
                rows.append({'person':person,'parts':parts,'model':'res://assets/characters/'+relative+'/'+person+'.gltf','stand_pose':'at_ease' if person=='stacy' else 'weight_on_one_leg','base_local':[0,-.013,0],'radius':.4,'height':1.6,'source_bindings':bindings})
        self.doc={'schema_version':1,'units':'metres','shape':'standing_column','profiles':rows}
        self.save()
        audit.generate_binding(self.root)

    def save(self):
        path=self.root/audit.PROFILE
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes((json.dumps(self.doc,indent=2)+'\n').encode())

    def test_valid_source_closure_and_exact_stamp(self):
        signature,count=audit.validated_profile(self.root)
        self.assertEqual(count,85)
        self.assertEqual(audit.check(self.root),[])
        self.assertIn('PROFILE_SHA256 := "'+signature+'"',(self.root/audit.BINDING).read_text())

    def test_changed_source_fails_check_and_generation_without_writing_stamp(self):
        stamp=(self.root/audit.BINDING).read_bytes()
        path=self.root/'game/shaders/character_hair.gdshader'
        original=path.read_bytes();path.write_bytes(original+b'changed geometry\n')
        self.assertIn('source hash mismatch',audit.check(self.root)[0])
        with self.assertRaises(audit.Invalid):audit.generate_binding(self.root)
        self.assertEqual((self.root/audit.BINDING).read_bytes(),stamp)
        path.write_bytes(original)
        self.assertEqual(audit.check(self.root),[])

    def test_changed_profile_and_stamp_are_not_quietly_regenerated(self):
        path=self.root/audit.PROFILE;original=path.read_bytes()
        stamp=(self.root/audit.BINDING).read_bytes()
        self.doc['profiles'][0]['radius']=.401;self.save()
        self.assertIn('stale',audit.check(self.root)[0])
        self.assertEqual((self.root/audit.BINDING).read_bytes(),stamp)
        path.write_bytes(original)
        (self.root/audit.BINDING).write_bytes(stamp.replace(b'PROFILE_SHA256',b'WRONG_KEY'))
        self.assertIn('stale',audit.check(self.root)[0])
        (self.root/audit.BINDING).write_bytes(stamp)
        self.assertEqual(audit.check(self.root),[])

    def test_lf_and_import_params_semantics_preserved(self):
        path=self.root/'game/scripts/characters/stand_pose.gd'
        path.write_bytes(path.read_bytes().replace(b'\n',b'\r\n'))
        imp=self.root/'game/assets/characters/stacy/stacy.gltf.import'
        imp.write_bytes(imp.read_bytes().replace(b'cache',b'another-cache'))
        self.assertEqual(audit.check(self.root),[])
        imp.write_bytes(imp.read_bytes().replace(b'scale=1',b'scale=2'))
        self.assertIn('source hash mismatch',audit.check(self.root)[0])

    def test_missing_duplicate_binding_and_wrong_kind_rejected(self):
        original=copy.deepcopy(self.doc)
        for mutation in ['missing','duplicate','kind']:
            self.doc=copy.deepcopy(original);rows=self.doc['profiles'][0]['source_bindings']
            if mutation=='missing': rows.pop()
            elif mutation=='duplicate':rows.append(rows[0].copy())
            else:rows[0]['kind']='raw'
            self.save()
            self.assertTrue(audit.check(self.root),mutation)

    def test_malformed_profile_and_source_escape_rejected(self):
        original=copy.deepcopy(self.doc)
        for mutation in ['nan','family','escape']:
            self.doc=copy.deepcopy(original);row=self.doc['profiles'][0]
            if mutation=='nan':row['height']=float('nan')
            elif mutation=='family':row['parts']=['unmeasured']
            else:row['source_bindings'][0]['path']='res://../outside.gd'
            self.save();self.assertTrue(audit.check(self.root),mutation)

    def test_exact_five_families_preserves_both_existing_staff_and_adela_stage_only(self):
        original=copy.deepcopy(self.doc)
        for mutation in ['remove_adela','duplicate_adela','replace_lily_work','adela_work','adela_path','adela_pose']:
            self.doc=copy.deepcopy(original)
            adela=self.doc['profiles'][-1]
            if mutation=='remove_adela': self.doc['profiles'].pop()
            elif mutation=='duplicate_adela': self.doc['profiles'].append(copy.deepcopy(adela))
            elif mutation=='replace_lily_work': self.doc['profiles'][2]=copy.deepcopy(adela)
            elif mutation=='adela_work': adela['parts']=['work_top','work_bottom','work_feet']
            elif mutation=='adela_path': adela['model']='res://assets/characters/adela_voss/adela_voss.gltf'
            else: adela['stand_pose']='at_ease'
            self.save()
            self.assertTrue(audit.check(self.root),mutation)

    def test_adela_deformation_and_hair_admission_drift_refuses_regeneration(self):
        stamp=(self.root/audit.BINDING).read_bytes()
        for rel in audit.ADELA_COMMON:
            path=self.root/'game'/rel;original=path.read_bytes()
            path.write_bytes(original+b'changed measured input\n')
            with self.assertRaisesRegex(audit.Invalid,'source hash mismatch'):
                audit.generate_binding(self.root)
            self.assertEqual((self.root/audit.BINDING).read_bytes(),stamp)
            path.write_bytes(original)
        self.assertEqual(audit.check(self.root),[])

    def test_adela_buffer_drift_and_unrelated_consumer_binding_rejected(self):
        path=self.root/'game/assets/characters/cast/adela_voss/adela_voss__p_top.bin'
        original=path.read_bytes();path.write_bytes(original+b'changed skin vertices')
        self.assertIn('source hash mismatch',audit.check(self.root)[0])
        path.write_bytes(original)
        self.doc['profiles'][-1]['source_bindings'].append({
            'path':'res://scripts/characters/harukiya_cast.gd','kind':'lf','sha256':'0'*64})
        self.save()
        self.assertIn('source closure mismatch',audit.check(self.root)[0])

    def test_adela_required_face_and_hair_inputs_cannot_be_omitted(self):
        original=copy.deepcopy(self.doc)
        for relative in audit.ADELA_COMMON:
            self.doc=copy.deepcopy(original)
            bindings=self.doc['profiles'][-1]['source_bindings']
            bindings[:]=[b for b in bindings if b['path']!='res://'+relative]
            self.save()
            self.assertIn('source closure mismatch',audit.check(self.root)[0])

if __name__=='__main__':unittest.main()
