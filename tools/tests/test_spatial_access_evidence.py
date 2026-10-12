"""Mutation tests: stale helpers, changed geometry and invented rooms cannot promote."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from spatial_access_evidence import validate


class SpatialAccessEvidence(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        (self.root/'game/tests').mkdir(parents=True)
        (self.root/'game/data').mkdir(parents=True)
        texts={'game/tests/access.gd':'extends "res://tests/driver.gd"\n','game/tests/driver.gd':'extends Node\n'}
        for path,text in texts.items():(self.root/path).write_text(text,encoding='utf-8')
        bindings={path:hashlib.sha256(text.encode()).hexdigest() for path,text in texts.items()}
        (self.root/'game/data/orison_v2_blockout.json').write_text(json.dumps({'levels':[{'id':'F02','y':3.2}],
            'spaces':[{'id':'F02_A_MAIN','level':'F02','rect':[0,0,4,4]},{'id':'F02_A_BATH','level':'F02','rect':[5,0,8,4]}]}),encoding='utf-8')
        self.data={'schema_version':2,'evidence_kind':'runtime_contract','selector':'v2','production_runtime':True,
            'execution':{'completed':True,'exit_code':0,'timed_out':False},'failures':0,'checks':[{'ok':True}],
            'source':{'test_path':'game/tests/access.gd','test_sha256':bindings['game/tests/access.gd'],'test_dependencies':bindings,
                      'repository_head':'a'*40,'runtime_inputs_sha256':'b'*64,'surface_inputs_sha256':'c'*64},
            'contracts':{'production_composition':{'executed':True,'status':'PASS'},
                         'room_access':{'executed':True,'status':'PASS','rooms':{'F02_A_MAIN':{'actual':[2,3.2,2],'leg':'A'}}},
                         'teardown':{'executed':True,'status':'PASS','tracked_nodes':2,'retained_nodes':0}},
            'legs':[{'name':'A','failures':[],'initial_placement_only':True,'trace':[{'actual':[2,3.2,2],'target':[2,3.2,2],'ok':True}]}]}

    def check_receipt(self,data=None):return validate(data or self.data,self.root,'b'*64,'c'*64)

    def test_current_proof_and_crlf_normalization(self):
        self.assertEqual(self.check_receipt(),[])
        (self.root/'game/tests/driver.gd').write_bytes(b'extends Node\r\n')
        self.assertEqual(self.check_receipt(),[])

    def test_helper_edit_and_omitted_helper_rejected(self):
        (self.root/'game/tests/driver.gd').write_text('extends Node\n# changed\n',encoding='utf-8')
        self.assertTrue(any('stale test' in e for e in self.check_receipt()))
        del self.data['source']['test_dependencies']['game/tests/driver.gd']
        self.assertTrue(any('unbound test' in e for e in self.check_receipt()))

    def test_runtime_and_mesh_drift_rejected(self):
        for key in ['runtime_inputs_sha256','surface_inputs_sha256']:
            data=copy.deepcopy(self.data);data['source'][key]='d'*64
            self.assertTrue(self.check_receipt(data))

    def test_invented_or_unvisited_room_rejected(self):
        for identity in ['F02_A_BATH','F02_MISSING']:
            data=copy.deepcopy(self.data);data['contracts']['room_access']['rooms']={identity:{'actual':[2,3.2,2],'leg':'A'}}
            self.assertTrue(self.check_receipt(data))
        self.data['contracts']['room_access']['rooms']['F02_A_MAIN']['actual']=[3,3.2,3]
        self.assertTrue(any('played trace point' in e for e in self.check_receipt()))

    def test_failed_and_short_walk_rejected(self):
        for mutation in ['failed','short','empty']:
            data=copy.deepcopy(self.data)
            if mutation=='failed':data['legs'][0]['failures']=['blocked']
            elif mutation=='short':data['legs'][0]['trace'][0]['target']=[3,3.2,2]
            else:data['legs'][0]['trace']=[]
            self.assertTrue(self.check_receipt(data))

    def test_false_checks_and_retained_root_rejected(self):
        self.data['checks'][0]['ok']=False
        self.assertTrue(self.check_receipt())
        self.data['checks'][0]['ok']=True
        self.data['contracts']['teardown']['retained_nodes']=1
        self.assertTrue(self.check_receipt())

    def test_malformed_receipts_fail_closed(self):
        for data in [None,[],{},dict(self.data,source=None),dict(self.data,legs=[None])]:
            self.assertTrue(validate(data,self.root,'b'*64,'c'*64))

    def test_ledger_grants_only_played_spatial_rooms_and_expires(self):
        import audit_orison_v2_completeness as audit
        import v2_surface_evidence
        packet=self.root/'art/renders/orison_v2/access';packet.mkdir(parents=True)
        (packet/'runtime_contract.json').write_text(json.dumps(self.data),encoding='utf-8')
        inputs=SimpleNamespace(root=self.root,checkpoints=[('design/ORISON_V2_SPATIAL_ACCESS_CHECKPOINT.md',
            '`F02_A_MAIN` and `F02_A_BATH`; art/renders/orison_v2/access/runtime_contract.json')],
            adapter_required=[],receipts=[],acceptance_records=[],manifest={'records':[]})
        model=SimpleNamespace(all_ids={'F02_A_MAIN','F02_A_BATH'})
        with patch.object(audit,'runtime_inputs_sha256',return_value='b'*64), patch.object(v2_surface_evidence,'inputs',return_value={'sha256':'c'*64}):
            evidence=audit.Evidence(inputs,model)
            self.assertEqual(evidence.tier_for('F02_A_MAIN')[0],'SPATIALLY_PROVEN')
            self.assertIsNone(evidence.tier_for('F02_A_BATH')[0])
            self.assertTrue(evidence.conflicts)
            (self.root/'game/tests/driver.gd').write_text('extends Node\n# route changed\n',encoding='utf-8')
            stale=audit.Evidence(inputs,model)
            self.assertIsNone(stale.tier_for('F02_A_MAIN')[0])


if __name__=='__main__':unittest.main()
