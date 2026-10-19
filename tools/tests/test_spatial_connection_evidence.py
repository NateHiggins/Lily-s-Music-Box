"""Original trace, capsule clearance and physical door-input mutation checks."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from spatial_connection_evidence import validate_connections


class ServiceConnectionEvidence(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory in ['game/tests', 'game/data', 'game/scripts/player']:
            (self.root/directory).mkdir(parents=True)
        texts = {'game/tests/access.gd': 'extends "res://tests/driver.gd"\n',
                 'game/tests/driver.gd': 'extends Node\n'}
        for path, text in texts.items():
            (self.root/path).write_text(text, encoding='utf-8', newline='\n')
        bindings = {path: hashlib.sha256(text.encode()).hexdigest() for path, text in texts.items()}
        self.controller = self.root/'game/scripts/player/player_controller.gd'
        self.controller.write_text('const BODY_RADIUS := 0.33\nconst STANDING_HEIGHT := 1.524 # real body\n', encoding='utf-8', newline='\n')
        self.hall, self.core, self.edge = 'F02_SERVICE_HALL', 'F02_SERVICE_CORE', 'F02_SERVICE_HALL_CORE_OPENING'
        self.layout = {'levels': [{'id': 'F02', 'y': 3.2}], 'dimensions': {'partition_wall': .12},
            'spaces': [{'id': self.hall, 'level': 'F02', 'class': 'service', 'purpose': 'maintenance route', 'rect': [0,0,1,6]},
                       {'id': self.core, 'level': 'F02', 'class': 'core', 'purpose': 'service lift and stair', 'rect': [1,0,5,6]}],
            'openings': [{'id': self.edge, 'level': 'F02', 'center': [1,3], 'axis': 'z', 'width': 1.2, 'height': 2.4,
                          'shared_wall_owner': self.core, 'connects': [self.hall,self.core]}]}
        self.save_layout()
        before, after = [1.55,3.2,3], [.45,3.2,3]
        self.data = {'schema_version': 2, 'evidence_kind': 'runtime_contract', 'selector': 'v2', 'production_runtime': True,
            'execution': {'completed': True, 'exit_code': 0, 'timed_out': False}, 'failures': 0, 'checks': [{'ok': True}],
            'source': {'test_path': 'game/tests/access.gd', 'test_sha256': bindings['game/tests/access.gd'],
                       'test_dependencies': bindings, 'repository_head': 'a'*40, 'runtime_inputs_sha256': 'b'*64, 'surface_inputs_sha256': 'c'*64},
            'legs': [{'name': 'A', 'failures': [], 'initial_placement_only': True,
                      'trace': [{'actual': p, 'target': p, 'ok': True} for p in [before,after]]}],
            'contracts': {'production_composition': {'executed': True, 'status': 'PASS'},
                          'teardown': {'executed': True, 'status': 'PASS', 'tracked_nodes': 2, 'retained_nodes': 0},
                          'room_access': {'executed': True, 'status': 'PASS', 'rooms': {
                              self.core: {'actual': before, 'leg': 'A'}, self.hall: {'actual': after, 'leg': 'A'}}},
                          'room_connections': {'executed': True, 'status': 'PASS', 'connections': {self.edge: {
                              'id': self.edge, 'level': 'F02', 'from': self.core, 'to': self.hall, 'leg': 'A',
                              'before_index': 0, 'after_index': 1, 'before': before, 'after': after}}}}}

    def save_layout(self):
        (self.root/'game/data/orison_v2_blockout.json').write_text(json.dumps(self.layout), encoding='utf-8', newline='\n')

    def errors(self, data=None):
        return validate_connections(self.data if data is None else data, self.root, 'b'*64, 'c'*64)

    def claim(self, data):
        return data['contracts']['room_connections']['connections'][self.edge]

    def move(self, before, after):
        self.data['legs'][0]['trace'] = [{'actual': p, 'target': p, 'ok': True} for p in [before,after]]
        self.data['contracts']['room_access']['rooms'][self.core]['actual'] = before
        self.data['contracts']['room_access']['rooms'][self.hall]['actual'] = after
        self.claim(self.data).update(before=before, after=after)

    def test_current_opening_and_controller_comment(self):
        self.assertEqual(self.errors(), [])

    def test_ledger_requires_the_played_typed_crossing_and_expires_on_source_change(self):
        import audit_orison_v2_completeness as audit
        import v2_surface_evidence
        packet=self.root/'art/renders/orison_v2/service_access';packet.mkdir(parents=True)
        path=packet/'runtime_contract.json'
        bogus=self.edge+'_BOGUS'
        text='`'+self.core+'` `'+self.edge+'` `'+bogus+'`; art/renders/orison_v2/service_access/runtime_contract.json'
        inputs=SimpleNamespace(root=self.root,checkpoints=[('design/ORISON_V2_SERVICE_SPATIAL_ACCESS_CHECKPOINT.md',text)],adapter_required=[],receipts=[],acceptance_records=[],manifest={'records':[]})
        model=SimpleNamespace(all_ids={self.core,self.hall,self.edge,bogus})
        with patch.object(audit,'runtime_inputs_sha256',return_value='b'*64),patch.object(v2_surface_evidence,'inputs',return_value={'sha256':'c'*64}):
            for defect in ['none','bad_crossing','no_crossing']:
                data=copy.deepcopy(self.data)
                if defect=='bad_crossing':self.claim(data)['after_index']=0
                if defect=='no_crossing':del data['contracts']['room_connections']
                path.write_text(json.dumps(data),encoding='utf-8')
                evidence=audit.Evidence(inputs,model)
                self.assertEqual(evidence.tier_for(self.core)[0],'SPATIALLY_PROVEN')
                self.assertEqual(evidence.tier_for(self.edge)[0],'SPATIALLY_PROVEN' if defect=='none' else None)
                self.assertIsNone(evidence.tier_for(bogus)[0])
            path.write_text(json.dumps(self.data),encoding='utf-8')
            (self.root/'game/tests/driver.gd').write_text('extends Node\n# route changed\n',encoding='utf-8')
            stale=audit.Evidence(inputs,model)
            self.assertIsNone(stale.tier_for(self.edge)[0])
            self.assertIsNone(stale.tier_for(self.core)[0])

    def test_other_wall_axis_uses_source_plane(self):
        self.layout['spaces'][0]['rect']=[0,0,6,1]
        self.layout['spaces'][1]['rect']=[0,1,6,5]
        self.layout['openings'][0].update(center=[3,1],axis='x')
        self.save_layout();self.move([3,3.2,1.55],[3,3.2,.45])
        self.assertEqual(self.errors(),[])

    def test_invented_threshold_wrong_level_and_unvisited_endpoint(self):
        for field, value in [('id','invented'), ('level','F03'), ('from',self.hall)]:
            data=copy.deepcopy(self.data);self.claim(data)[field]=value;self.assertTrue(self.errors(data))
        del self.data['contracts']['room_access']['rooms'][self.core]
        self.assertTrue(self.errors())

    def test_indices_and_fabricated_crossing_coordinates(self):
        for field, value in [('before_index',True),('before_index',-1),('after_index',0),('after_index',99),('before',[1.7,3.2,3])]:
            data=copy.deepcopy(self.data);self.claim(data)[field]=value;self.assertTrue(self.errors(data))

    def test_capsule_must_fully_clear_both_wall_faces(self):
        self.move([1.2,3.2,3],[.8,3.2,3])
        self.assertTrue(any('full capsule' in e for e in self.errors()))

    def test_nearby_crossing_clips_real_jamb(self):
        self.move([1.55,3.2,3.3],[.45,3.2,3.3])
        self.assertTrue(any('jamb' in e for e in self.errors()))

    def test_detour_cannot_substitute_for_direct_threshold(self):
        self.data['legs'][0]['trace'].insert(1, {'actual':[6,3.2,3], 'target':[6,3.2,3], 'ok':True})
        self.claim(self.data)['after_index']=2
        self.assertTrue(any('detours' in e for e in self.errors()))

    def test_source_aperture_type_size_and_duplicates(self):
        for change in ['private','small','duplicate','nonfinite']:
            layout=copy.deepcopy(self.layout)
            if change=='private': self.layout['spaces'][0]['class']='private'
            if change=='small': self.layout['openings'][0]['width']=.65
            if change=='duplicate': self.layout['openings'].append(copy.deepcopy(self.layout['openings'][0]))
            if change=='nonfinite': self.layout['openings'][0]['center'][0]=float('nan')
            self.save_layout();self.assertTrue(self.errors());self.layout=layout
        self.save_layout()

    def test_production_radius_is_not_a_smaller_test_fixture(self):
        self.controller.write_text('const BODY_RADIUS := 0.5\nconst STANDING_HEIGHT := 1.524\n', encoding='utf-8')
        self.assertTrue(any('full capsule' in e for e in self.errors()))

    def test_production_height_requires_real_headroom(self):
        self.controller.write_text('const BODY_RADIUS := 0.33\nconst STANDING_HEIGHT := 3.0\n',encoding='utf-8')
        self.assertTrue(self.errors())

    def test_door_requires_real_input_and_body_at_stop(self):
        door=self.layout.pop('openings')[0];door.pop('axis');door['yaw']=1.5707963267948966
        self.layout['doors']=[door];self.save_layout()
        self.assertTrue(self.errors())
        hand={'owner':self.edge,'kind':'grab_mouse_release','released':True,'follows_cursor':True,'ready_for_passage':True,'actual_angle':1.57,'stop_angle':1.57}
        self.claim(self.data)['door_input']=hand
        self.assertEqual(self.errors(),[])
        for field,value in [('owner','other'),('kind','toggle'),('released',False),('follows_cursor',False),('ready_for_passage',False),('actual_angle',0),('stop_angle',float('nan'))]:
            data=copy.deepcopy(self.data);self.claim(data)['door_input'][field]=value;self.assertTrue(self.errors(data))

    def test_stale_source_and_failed_contract_never_admitted(self):
        for field in ['runtime_inputs_sha256','surface_inputs_sha256']:
            data=copy.deepcopy(self.data);data['source'][field]='d'*64;self.assertTrue(self.errors(data))
        data=copy.deepcopy(self.data);data['contracts']['room_connections']['executed']=False;self.assertTrue(self.errors(data))
        (self.root/'game/tests/driver.gd').write_text('extends Node\n# changed\n',encoding='utf-8')
        self.assertTrue(self.errors())

    def test_malformed_contracts_fail_closed(self):
        for value in [None,[],{},dict(self.data,contracts=None)]:
            self.assertTrue(validate_connections(value,self.root,'b'*64,'c'*64))


if __name__ == '__main__':
    unittest.main()
