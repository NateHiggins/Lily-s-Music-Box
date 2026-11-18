"""Intake refuses changed shipping geometry and malformed physical metadata."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_arcade_door_intake as intake


class ArcadeDoorIntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proof=json.loads((intake.ROOT/intake.PROOF).read_text())
        cls.asset=intake.ROOT/'game'/intake.ASSET[6:]

    def reject(self,proof,message):
        with self.assertRaisesRegex(ValueError,message):intake.build(proof=proof)

    def test_clean_checkout_projection_matches_current_runtime_exactly(self):
        result=intake.render(intake.build())
        self.assertEqual(result,(intake.ROOT/intake.OUTPUT).read_text().replace('\r\n','\n'))
        self.assertEqual(len(json.loads(result)['collider_boxes']),6)
        self.assertTrue(result.endswith('\n'))

    def test_proof_order_does_not_change_output_or_mutate_original(self):
        p=copy.deepcopy(self.proof);before=copy.deepcopy(p)
        expected=intake.build(proof=p)
        self.assertEqual(p,before)
        p['draws'].reverse()
        for rows in p['pull_collision_boxes'].values():rows.reverse()
        self.assertEqual(intake.build(proof=p),expected)

    def test_wrong_asset_hash_path_and_unscaled_dimensions_refuse(self):
        for key,value,message in [('asset','res://assets/props/other.glb','fixed shipping'),
                                  ('asset_sha256','0'*64,'shipping GLB SHA')]:
            p=copy.deepcopy(self.proof);p[key]=value;self.reject(p,message)
        for key,value in [('nominal_width_m',.95),('nominal_height_m',2.1),('nominal_width_m',True)]:
            p=copy.deepcopy(self.proof);p['dimensions'][key]=value;self.reject(p,'1m/2.3m')

    def test_missing_duplicate_draw_material_and_count_refuse(self):
        p=copy.deepcopy(self.proof);p['draws'].pop();self.reject(p,'eight native')
        p=copy.deepcopy(self.proof);p['draws'][-1]=p['draws'][0];self.reject(p,'duplicate')
        p=copy.deepcopy(self.proof);p['draws'][0]['material_key']='concrete';self.reject(p,'material changed')
        for count in [0,-1,True,2.5]:
            p=copy.deepcopy(self.proof);p['draws'][0]['triangles']=count;self.reject(p,'positive triangle')
        p=copy.deepcopy(self.proof);p['draws'][0]['triangles']+=1;self.reject(p,'actual GLB triangle')

    def test_malformed_boxes_and_duplicate_pull_faces_refuse(self):
        for low in [[float('nan'),0,0],[0,1],['0',1,2],[False,1,2]]:
            p=copy.deepcopy(self.proof);p['core_collision_boxes']['Left']['low']=low;self.reject(p,'finite three')
        p=copy.deepcopy(self.proof);p['core_collision_boxes']['Left']['high']=p['core_collision_boxes']['Left']['low'];self.reject(p,'nonpositive')
        p=copy.deepcopy(self.proof);p['core_collision_boxes']['Left']['high'][0]-=.01;self.reject(p,'actual shipping timber')
        p=copy.deepcopy(self.proof);p['pull_collision_boxes']['Left'].pop();self.reject(p,'two pull faces')
        p=copy.deepcopy(self.proof);p['pull_collision_boxes']['Left'][1]['face']=-1;self.reject(p,'duplicate/invalid pull')

    def test_hinge_spanning_brass_collision_and_wrong_face_refuse(self):
        p=copy.deepcopy(self.proof);p['pull_collision_boxes']['Left'][0]['low'][0]=-.01
        self.reject(p,'hinge/keyhole')
        p=copy.deepcopy(self.proof);p['pull_collision_boxes']['Left'][0]['face']=1
        self.reject(p,'wrong sign')

    def test_actual_shipping_glb_transform_and_material_controls(self):
        # Rewrite only glTF metadata in an isolated shipping copy and update its
        # SHA honestly. A hash match must not hide a changed native hinge frame.
        raw=self.asset.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
        original=json.loads(raw[20:20+length]);tail=raw[20+length:]
        for kind in ['transform','material']:
            with self.subTest(kind=kind),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);target=root/'game'/intake.ASSET[6:];target.parent.mkdir(parents=True)
                doc=copy.deepcopy(original)
                if kind=='transform':
                    next(n for n in doc['nodes'] if n.get('name')=='LeftWood')['translation']=[.001,0,0]
                else:
                    next(m for m in doc['materials'] if m['name']=='M_door_oak')['name']='M_concrete'
                data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*((-len(data))%4)
                changed=struct.pack('<III',0x46546c67,2,20+len(data)+len(tail))+struct.pack('<II',len(data),0x4e4f534a)+data+tail
                target.write_bytes(changed);p=copy.deepcopy(self.proof);p['asset_sha256']=hashlib.sha256(changed).hexdigest()
                with self.assertRaisesRegex(ValueError,'identity hinge' if kind=='transform' else 'actual GLB material'):
                    intake.build(root,p)

    def test_optional_original_source_binding_check_is_explicit_and_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);asset=root/'game'/intake.ASSET[6:];asset.parent.mkdir(parents=True)
            shutil.copyfile(self.asset,asset)
            source=root/'author.py';source.write_bytes(b'original\r\n')
            p=copy.deepcopy(self.proof);p['source_bindings']={'author.py':{'kind':'lf','sha256':hashlib.sha256(b'original\n').hexdigest()}}
            intake.build(root,p,True)
            source.write_bytes(b'changed\n')
            with self.assertRaisesRegex(ValueError,'original producer source changed'):intake.build(root,p,True)
            # Historical proof can still compile its unchanged shipping asset;
            # it does not silently claim original producer source renewal.
            intake.build(root,p,False)
            p['source_bindings']={'../outside.py':{'kind':'raw','sha256':'0'*64}}
            with self.assertRaisesRegex(ValueError,'binding path'):intake.build(root,p,True)


if __name__=='__main__':unittest.main()
