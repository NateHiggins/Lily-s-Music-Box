"""Synthetic mutation fixtures only; these are never runtime proof."""
import copy,hashlib,json,math,tempfile,unittest,struct
from pathlib import Path
import sys
from types import SimpleNamespace
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from v2_exterior_source import ExteriorSource,apply,add,sub,dot,disc_inside
from spatial_region_evidence import validate_regions,consecutive_motion,controller_step_height
ROOT=Path(__file__).resolve().parents[2]


class RegionProofTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        for name in ['game/data/orison_v2/exterior/regions.json','game/data/orison_v2/world_connection.json','game/data/orison_v2_blockout.json']:
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/name).read_bytes())
        def read(name):return json.loads((self.root/name).read_text())
        source=read('game/data/orison_v2/exterior/regions.json');model=ExteriorSource(source)
        basis,origin=model.interior_transform(read('game/data/orison_v2_blockout.json'),read('game/data/orison_v2/world_connection.json'))
        def inside(p):return [dot(column,sub(p,origin)) for column in basis]
        player=self.root/'game/scripts/player/player_controller.gd';player.parent.mkdir(parents=True);player.write_text('const BODY_RADIUS := 0.33\nconst STANDING_HEIGHT := 1.524\nfunc _try_step_up(delta: float) -> void:\n\tvar lift := Vector3.UP * 0.30\n\tglobal_position.y += 0.30\n')
        entry=self.root/'game/tests/access.gd';entry.parent.mkdir(parents=True);entry.write_text('extends Node\n');digest=hashlib.sha256(entry.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        mode=dict(noclip=False,collision_mask=1,capsule_radius=struct.unpack('<f',struct.pack('<f',.33))[0],capsule_height=struct.unpack('<f',struct.pack('<f',1.524))[0],on_floor=True)
        samples=[];trace=[];routes={};position=None
        for route in source['routes']:
            nodes=[]
            for node in route['nodes']:
                target=model.placement(node['owner_instance_id'],node['placement_id'])
                if position is None:position=target;samples.append(dict(actual=inside(target),physics_frame=0,**mode))
                steps=max(1,math.ceil(math.dist(target,position)/.15))
                before=position
                for i in range(1,steps+1):
                    p=tuple(a+(b-a)*i/steps for a,b in zip(before,target));samples.append(dict(actual=inside(p),physics_frame=len(samples),**mode))
                position=target
                trace.append(dict(actual=samples[-1]['actual'][:],target=inside(target),ok=True,sample_index=len(samples)-1,**mode));nodes.append(dict(id=node['id'],trace_index=len(trace)-1))
            routes[route['id']]=dict(leg='A',nodes=nodes)
        claims={}
        for identity,region in model.regions.items():
            for instance in model.instances.values():
                if instance['region_id']!=identity:continue
                for floor in model.templates[instance['template_id']]['surfaces']:
                    if floor['kind']!='walkable':continue
                    surface=model.surface(instance['id'],floor['id'])
                    for i,sample in enumerate(samples):
                        actual=add(origin,apply(basis,sample['actual']));delta=sub(actual,surface['point'])
                        if not disc_inside(region['boundary'],(actual[0],actual[2]),.33):continue
                        if abs(actual[1]-surface['point'][1])>=.15 or any(abs(dot(delta,surface[axis]))+.335>surface['size_m'][j]/2 for j,axis in enumerate(['u_axis','v_axis'])):continue
                        claims[identity]=dict(id=identity,instance_id=instance['id'],floor_surface_id=floor['id'],leg='A',sample_index=i,actual=sample['actual'][:],geometry_resident=True,on_floor=True,floor_collider_path='/root/SyntheticFloor');break
                    if identity in claims:break
                if identity in claims:break
        self.assertEqual(set(claims),set(model.regions))
        controls={t: [dict(owner_id=model.thresholds[t]['interactive_leaf_id'],kind='grab_mouse_release',released=True,follows_cursor=True,ready_for_passage=True,before_angle=0,actual_angle=1.57,stop_angle=1.57,leg='A',before_sample_index=0,after_sample_index=1)] for route in model.routes.values() for t in route['threshold_ids']}
        self.data=dict(schema_version=2,evidence_kind='runtime_contract',selector='v2',production_runtime=True,execution=dict(completed=True,exit_code=0,timed_out=False),failures=0,checks=[dict(ok=True)],source=dict(test_path='game/tests/access.gd',test_sha256=digest,test_dependencies={'game/tests/access.gd':digest},repository_head='a'*40,runtime_inputs_sha256='b'*64,surface_inputs_sha256='c'*64),legs=[dict(name='A',failures=[],initial_placement_only=True,trace=trace,samples=samples)],contracts=dict(production_composition=dict(executed=True,status='PASS'),room_access=dict(executed=True,status='PASS',rooms={'F01_STREET_APRON':dict(leg='A',actual=trace[0]['actual'])}),teardown=dict(executed=True,status='PASS',tracked_nodes=3,retained_nodes=0),region_access=dict(executed=True,status='PASS',coordinate_frame='orison_blockout_local',regions=claims,routes=routes,threshold_controls=controls)))

    def check(self,data=None):return validate_regions(self.data if data is None else data,self.root,'b'*64,'c'*64)

    def test_synthetic_complete_source_contract_is_structurally_valid(self):self.assertEqual(self.check(),[])

    def test_airborne_or_missing_collider_witness_cannot_claim_a_floor(self):
        for field,value in [('on_floor',False),('floor_collider_path',''),('floor_collider_path',None)]:
            data=copy.deepcopy(self.data);data['contracts']['region_access']['regions']['REGION_STREET'][field]=value
            with self.subTest(field=field):self.assertTrue(self.check(data))
        data=copy.deepcopy(self.data);claim=data['contracts']['region_access']['regions']['REGION_STREET']
        data['legs'][0]['samples'][claim['sample_index']]['on_floor']=False;self.assertTrue(self.check(data))

    def test_stationary_or_unobserved_threshold_motion_is_rejected(self):
        for field,value in [('before_angle',1.57),('before_sample_index',True),('after_sample_index',0),('after_sample_index',999999),('leg','invented')]:
            data=copy.deepcopy(self.data);action=next(iter(data['contracts']['region_access']['threshold_controls'].values()))[0];action[field]=value
            with self.subTest(field=field):self.assertTrue(self.check(data))

    def test_observer_retirement_and_threshold_roster_are_required(self):
        data=copy.deepcopy(self.data);data['contracts']['teardown']['tracked_nodes']=2;self.assertTrue(self.check(data))
        data=copy.deepcopy(self.data);data['contracts']['region_access']['threshold_controls']['invented']=[];self.assertTrue(self.check(data))

    def test_source_or_helper_drift_rejected(self):
        for key in ['runtime_inputs_sha256','surface_inputs_sha256']:
            data=copy.deepcopy(self.data);data['source'][key]='d'*64;self.assertTrue(self.check(data))
        (self.root/'game/tests/access.gd').write_text('extends Node\n# changed\n');self.assertTrue(self.check())

    def test_unknown_or_aliased_region_and_false_residency_rejected(self):
        for field,value in [('id','REGION_MISSING'),('instance_id','SHOP_BODEGA'),('geometry_resident',False)]:
            data=copy.deepcopy(self.data);data['contracts']['region_access']['regions']['REGION_STREET'][field]=value
            with self.subTest(field=field):self.assertTrue(self.check(data))

    def test_invented_or_boolean_sample_index_rejected(self):
        for value in [-1,True,999999]:
            data=copy.deepcopy(self.data);data['contracts']['region_access']['regions']['REGION_STREET']['sample_index']=value;self.assertTrue(self.check(data))
        data=copy.deepcopy(self.data);data['contracts']['region_access']['regions']['REGION_STREET']['actual']=[999,0,999];self.assertTrue(self.check(data))

    def test_noclip_mask_and_small_controller_cannot_prove_access(self):
        for field,value in [('noclip',True),('collision_mask',0),('collision_mask',True),('capsule_radius',.05),('capsule_height',.5)]:
            data=copy.deepcopy(self.data);data['legs'][0]['samples'][1][field]=value
            with self.subTest(field=field,value=value):self.assertTrue(self.check(data))

    def test_dropped_frames_and_position_jumps_rejected(self):
        for field,value in [('physics_frame',9999),('actual',[500,0,500])]:
            data=copy.deepcopy(self.data);data['legs'][0]['samples'][1][field]=value;self.assertTrue(self.check(data))

    def test_multiple_initial_placements_or_a_different_start_rejected(self):
        data=copy.deepcopy(self.data);other=copy.deepcopy(data['legs'][0]);other['name']='B';data['legs'].append(other)
        self.assertTrue(self.check(data))
        data=copy.deepcopy(self.data)
        # Keep every step contiguous while moving the complete leg elsewhere.
        for row in data['legs'][0]['samples']+data['legs'][0]['trace']:
            row['actual'][0]+=10
        self.assertTrue(self.check(data))

    def test_exact_bound_curb_step_preserves_floor_transition_and_jump_rejection(self):
        text=(ROOT/'game/scripts/player/player_controller.gd').read_text()
        height=controller_step_height(text)
        self.assertEqual(height,.3)
        first=dict(actual=[0,0,0],physics_frame=10,on_floor=True)
        second=dict(actual=[.05,.3,0],physics_frame=11,on_floor=False)
        self.assertTrue(consecutive_motion(first,second,height))
        for field,value in [('actual',[.21,.3,0]),('actual',[.05,.31,0]),('actual',[.05,-.3,0]),('on_floor',True),('physics_frame',12)]:
            changed=dict(second);changed[field]=value
            with self.subTest(field=field,value=value):self.assertFalse(consecutive_motion(first,changed,height))
        self.assertFalse(consecutive_motion(dict(first,on_floor=False),second,height))
        with self.assertRaises(ValueError):controller_step_height(text.replace('global_position.y += 0.30','global_position.y += 0.31'))

    def test_actual_engine_shape_decimal_rounding_without_smaller_body_allowance(self):
        data=copy.deepcopy(self.data)
        for row in data['legs'][0]['samples']+data['legs'][0]['trace']:
            row['capsule_radius']=0.330000013113022
            row['capsule_height']=1.52400004863739
        self.assertEqual(self.check(data),[])
        for value in [.33,.329999,True,float('nan')]:
            changed=copy.deepcopy(data);changed['legs'][0]['samples'][1]['capsule_radius']=value
            with self.subTest(radius=value):self.assertTrue(self.check(changed))

    def test_actual_endpoint_cannot_be_detached_from_its_observation(self):
        data=copy.deepcopy(self.data);data['legs'][0]['trace'][1]['sample_index']=0;self.assertTrue(self.check(data))

    def test_missing_reordered_or_invented_authored_targets_rejected(self):
        for change in ['route','node','order','target']:
            data=copy.deepcopy(self.data);routes=data['contracts']['region_access']['routes'];key=next(iter(routes))
            if change=='route':del routes[key]
            elif change=='node':routes[key]['nodes'].pop()
            elif change=='order':routes[key]['nodes'].reverse()
            else:data['legs'][0]['trace'][1]['target'][0]+=.1
            with self.subTest(change=change):self.assertTrue(self.check(data))

    def test_toggle_wrong_leaf_or_short_motion_rejected(self):
        for field,value in [('kind','click_toggle'),('owner_id','UNRELATED_LEAF'),('released',False),('follows_cursor',False),('ready_for_passage',False),('actual_angle',0),('stop_angle',False)]:
            data=copy.deepcopy(self.data);controls=data['contracts']['region_access']['threshold_controls'];next(iter(controls.values()))[0][field]=value
            with self.subTest(field=field):self.assertTrue(self.check(data))

    def test_nonwalkable_source_plane_cannot_supply_floor(self):
        data=copy.deepcopy(self.data);data['contracts']['region_access']['regions']['REGION_SHOPS']['floor_surface_id']='threshold';self.assertTrue(self.check(data))

    def test_malformed_contracts_fail_closed(self):
        for data in [None,[],{},dict(self.data,contracts=None),dict(self.data,legs=[None])]:self.assertTrue(validate_regions(data,self.root,'b'*64,'c'*64))

    def test_ledger_admits_only_original_source_current_regional_channel(self):
        import audit_orison_v2_completeness as audit
        import v2_surface_evidence
        packet=self.root/'art/renders/orison_v2/region_access';packet.mkdir(parents=True)
        path=packet/'runtime_contract.json'
        ids=list(self.data['contracts']['region_access']['regions'])
        text=' '.join('`'+x+'`' for x in ids+['F01_STREET_APRON','REGION_INVENTED'])+'; art/renders/orison_v2/region_access/runtime_contract.json'
        inputs=SimpleNamespace(root=self.root,checkpoints=[('design/ORISON_V2_EXTERIOR_SPATIAL_ACCESS_CHECKPOINT_2026-10-19.md',text)],adapter_required=[],receipts=[],acceptance_records=[],manifest={'records':[]})
        model=SimpleNamespace(all_ids={'F01_STREET_APRON'})
        with patch.object(audit,'runtime_inputs_sha256',return_value='b'*64),patch.object(v2_surface_evidence,'inputs',return_value={'sha256':'c'*64}):
            for defect in ['none','bad_witness','no_regions','jump','wrong_shape','failed','stale']:
                data=copy.deepcopy(self.data)
                if defect=='bad_witness':data['contracts']['region_access']['regions'][ids[0]]['actual']=[999,0,999]
                if defect=='no_regions':del data['contracts']['region_access']
                if defect=='jump':data['legs'][0]['samples'][1]['actual'][0]+=10
                if defect=='wrong_shape':data['legs'][0]['samples'][1]['capsule_radius']=.05
                if defect=='failed':data['execution']['exit_code']=1
                if defect=='stale':data['source']['surface_inputs_sha256']='d'*64
                path.write_text(json.dumps(data),encoding='utf8')
                evidence=audit.Evidence(inputs,model)
                with self.subTest(defect=defect):
                    for identity in ids:self.assertEqual(evidence.tier_for(identity)[0],'SPATIALLY_PROVEN' if defect=='none' else None)
                    self.assertIsNone(evidence.tier_for('REGION_INVENTED')[0])
                    self.assertEqual(evidence.tier_for('F01_STREET_APRON')[0],None if defect in ['failed','stale'] else 'SPATIALLY_PROVEN')
                    ledger=object.__new__(audit.Ledger);ledger.inputs=inputs;ledger.evidence=evidence;ledger.requirements=[]
                    ledger._dim_regions()
                    self.assertEqual({row['status'] for row in ledger.requirements},{'SPATIALLY_PROVEN' if defect=='none' else 'PROGRAMMED'})
            # A legacy mention cannot promote a region even if the model later
            # grows region identities alongside room identities.
            inputs.checkpoints=[('design/ORISON_V2_EXTERIOR_CHECKPOINT.md',text)]
            evidence=audit.Evidence(inputs,SimpleNamespace(all_ids=set(ids)))
            ledger=object.__new__(audit.Ledger);ledger.inputs=inputs;ledger.evidence=evidence;ledger.requirements=[];ledger._dim_regions()
            self.assertEqual({row['status'] for row in ledger.requirements},{'PROGRAMMED'})


if __name__=='__main__':unittest.main()
