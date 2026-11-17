"""Source-to-concrete-successor identity controls; no runtime/disposal claims."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_arcade_rebuild_succession as gen


class ArcadeRebuildSuccessionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs=gen.load_inputs(gen.ROOT)
        cls.fixture=gen.build()
    def reject(self,data,message):
        with self.assertRaisesRegex(ValueError,message):gen.build(inputs=data)
    def source(self,data):
        return next(r for c in data['native']['cells'] for r in c['rebuild_entries']if r['model']in gen.MODELS)
    def stock(self,data):
        return next(r for r in data['contract']['closed_stocks']if r['name']=='shop_funeral_parlour_stock_partition_borrowed_pane_00')
    def test_actual82_exhaustive_unique_cohort_and_reproducible_fixture(self):
        self.assertEqual(self.fixture['counts'],dict(sources=82,previous_architectural_sources=79,added_darkroom_sources=3,by_model=gen.MODELS))
        actual={(r['cell'],r['model'],r['source_part_id'])for r in self.fixture['mappings']}
        expected={(c['cell'],r['model'],r['part_id'])for c in self.inputs['native']['cells']for r in c['rebuild_entries']if r['model']in gen.MODELS}
        self.assertEqual(actual,expected);self.assertEqual(len(actual),82)
        self.assertEqual((gen.ROOT/gen.FIXTURE).read_text(encoding='utf-8').replace('\r\n','\n'),gen.render(self.fixture))
        self.assertEqual(self.fixture['unmapped'],[])
    def test_two_cobbler_rebuilds_are_excluded_not_retired(self):
        self.assertEqual(set(self.fixture['excluded_models']),{'CobblerFittings'})
        self.assertFalse(any(r['model']in self.fixture['excluded_models']for r in self.fixture['mappings']))
    def test_concrete_receivers_have_no_wildcards_and_keep_owner(self):
        for row in self.fixture['mappings']:
            self.assertTrue(row['successors'])
            for r in row['successors']:
                if r['kind']=='shell_closed_stock':
                    self.assertNotIn('*',r['stock']['name']);self.assertEqual(r['stock']['owner'],row['cell']);self.assertEqual(r['native_draw']['owner'],row['cell']);self.assertEqual(r['stock']['material'],r['native_draw']['material'])
                else:
                    self.assertIn(r['draw']['name'],{'LeftBrass','LeftFixedBrass','LeftWood','LeftDarkroomCurtain'});self.assertEqual(r['door_frame_id'],row['door_frame']['id'])
    def test_source_masks_materials_and_native_payload_remain_verbatim(self):
        for row in self.fixture['mappings']:
            self.assertEqual(row['source_part']['source_part']['key'],row['source_part']['material_key'])
            masks={m['id']:m for m in row['original_family_masks']}
            for m in row['specific_source_masks']:self.assertEqual(m,masks[m['id']])
            for witness in row['original_mask_source_records']:
                self.assertEqual(witness['mask'],masks[witness['source_record']['id']]);self.assertEqual(witness['mask']['key'],witness['source_record']['mat'])
        hinges=[r for r in self.fixture['mappings']if r['role']=='stock_door_fixed_hinge_hardware']
        self.assertEqual(len(hinges),11);self.assertTrue(all(not r['specific_source_masks']and r['native_added_hardware_without_separate_literal_mask']for r in hinges))
    def test_all_borrowed_panes_and_frames_are_explicit(self):
        glass=[r for r in self.fixture['mappings']if r['role']=='borrowed_light_glazing' or r['role']=='photo_borrowed_glazing']
        self.assertEqual(len(glass),11)
        names={s['stock']['name']for r in glass for s in r['successors']}
        expected={s['name']for s in self.inputs['contract']['closed_stocks']if '_stock_partition_borrowed_pane_'in s['name']}
        self.assertEqual(names,expected)
    def test_missing_source_id_refuses(self):
        d=copy.deepcopy(self.inputs);c=next(c for c in d['native']['cells']if any(r['model']in gen.MODELS for r in c['rebuild_entries']));c['rebuild_entries'].remove(next(r for r in c['rebuild_entries']if r['model']in gen.MODELS));self.reject(d,'exact82 architectural/darkroom cohort')
    def test_duplicate_source_id_refuses(self):
        d=copy.deepcopy(self.inputs);c=d['native']['cells'][0];c['rebuild_entries'].append(copy.deepcopy(next(r for r in c['rebuild_entries']if r['model']in gen.MODELS)));self.reject(d,'duplicate source rebuild ID')
    def test_unknown_source_id_refuses(self):
        d=copy.deepcopy(self.inputs);self.source(d)['part_id']='unknown_source__glassish';self.reject(d,'original material/part identity changed')
    def test_original_owner_change_refuses(self):
        d=copy.deepcopy(self.inputs);c=d['native']['cells'][0];next(m for m in c['mounts']if m['name']=='ShopClerestories')['wrapper']='res://scripts/building/orison_v2_photo_glazing.gd';self.reject(d,'altered original wrapper owner')
    def test_original_material_and_frame_changes_refuse(self):
        d=copy.deepcopy(self.inputs);self.source(d)['material_key']='wood_dark';self.reject(d,'original material/part identity changed')
        d=copy.deepcopy(self.inputs);self.source(d)['source_transform'][0][3]+=.01;self.reject(d,'original native frame changed')
    def test_original_attribute_hash_change_refuses(self):
        d=copy.deepcopy(self.inputs);self.source(d)['encoded_source'][0]['attributes']['POSITION']['sha256']='0'*64;self.reject(d,'original native payload changed')
    def test_missing_stock_receiver_refuses_individually(self):
        d=copy.deepcopy(self.inputs);d['contract']['closed_stocks'].remove(self.stock(d));self.reject(d,'missing concrete successor stock')
    def test_duplicate_stock_receiver_refuses(self):
        d=copy.deepcopy(self.inputs);d['contract']['closed_stocks'].append(copy.deepcopy(self.stock(d)));self.reject(d,'duplicate concrete stock receiver')
    def test_receiver_owner_material_and_frame_changes_refuse(self):
        for field,value,msg in [('owner','shop_keys_cut','owner/material'),('material','frame','owner/material')]:
            d=copy.deepcopy(self.inputs);self.stock(d)[field]=value;self.reject(d,msg)
        d=copy.deepcopy(self.inputs);self.stock(d)['plan_rect_m'][0]+=.001;self.reject(d,'successor stock frame changed')
    def test_missing_runtime_draw_refuses(self):
        d=copy.deepcopy(self.inputs);d['shell']['native_parts']=[r for r in d['shell']['native_parts']if r['name']!='ArcadePlaza_shop_funeral_parlour_glazing'];self.reject(d,'successor native material draw missing')
    def test_unknown_native_draw_or_triangle_count_refuses(self):
        d=copy.deepcopy(self.inputs);next(r for r in d['shell']['native_parts']if r['name']=='ArcadePlaza_shop_funeral_parlour_glazing')['name']='unknown_draw';self.reject(d,'actual successor native draw absent')
        d=copy.deepcopy(self.inputs);next(r for r in d['shell']['native_parts']if r['name']=='ArcadePlaza_shop_funeral_parlour_glazing')['triangles']+=1;self.reject(d,'actual successor native draw absent')
    def test_door_frame_and_leaf_material_changes_refuse(self):
        d=copy.deepcopy(self.inputs);d['frames']['frames'][0]['frame_transform'][0][3]+=.01;self.reject(d,'door frame contract altered')
        d=copy.deepcopy(self.inputs);d['leaf_runtime']['parts'][0]['key']='wood_dark';self.reject(d,'leaf runtime/proof differs')
    def test_input_binding_change_refuses(self):
        d=copy.deepcopy(self.inputs);key=next(iter(d['native']['source_bindings']));d['native']['source_bindings'][key]['sha256']='0'*64;self.reject(d,'source binding changed')
    def test_photo_explicit_source_id_mapping_cannot_be_missing(self):
        d=copy.deepcopy(self.inputs);shop=next(s for s in d['plan']['shops']if s['id']=='shop_photo_supplies');shop['frontage']['display_source_ids']=[]
        # The source-plan SHA/door producer is authoritative too: either guard
        # rejects this incoherent copy before any nonempty wildcard fallback.
        self.reject(d,'missing original optical role|explicit Photo optical source successor absent')
    def test_original_leaf_broad_material_drift_is_retained(self):
        drift=self.fixture['original_leaf_producer_source_drift']
        for row in drift:
            self.assertEqual(row['path'],'game/data/runtime_material_sets.json');self.assertNotEqual(row['original_proof_sha256'],row['actual_sha256']);self.assertEqual(self.fixture['original_leaf_producer_bindings'][row['path']]['sha256'],row['original_proof_sha256'])
    def test_actual_stock_receivers_have_twelve_oriented_native_face_witnesses(self):
        owners={}
        for row in self.fixture['mappings']:
            for receiver in row['successors']:
                if receiver['kind']!='shell_closed_stock':continue
                witness=receiver['native_stock_witness']
                self.assertEqual(witness['expected_triangles'],12);self.assertEqual(len(witness['canonical_faces']),12)
                self.assertLessEqual(witness['maximum_native_corner_identity_residual_m'],1e-5)
                for face in witness['canonical_faces']:
                    key=(face['node_index'],face['primitive_index'],face['canonical_triangle_index'])
                    if key in owners:self.assertEqual(owners[key],receiver['stock']['name'])
                    owners[key]=receiver['stock']['name']
    def test_original_three_record_catalog_and_nine_textures_are_scoped_exactly(self):
        scope=self.fixture['leaf_catalog_scope']
        self.assertEqual(scope['original_scope_sha256'],gen.ORIGINAL_LEAF_CATALOG_SCOPE_SHA256)
        self.assertEqual(scope['actual_scope_sha256'],scope['original_scope_sha256'])
        self.assertEqual(scope['original_whole_catalog_sha256_lf'],gen.ORIGINAL_LEAF_CATALOG_SHA256_LF)
        self.assertEqual(len(scope['texture_bindings']),9)
        for path,row in scope['texture_bindings'].items():
            self.assertEqual(row,self.fixture['original_leaf_producer_bindings'][path]);self.assertEqual(gen.sha(gen.ROOT/path),row['sha256'])
    def test_actual_leaf_catalog_record_change_cannot_hide_in_broad_drift(self):
        d=copy.deepcopy(self.inputs);d['catalog']['materials']['door_oak']['meters_per_tile']+=.01
        self.reject(d,'actual three leaf catalog records changed')
    def test_actual_leaf_texture_byte_change_refuses(self):
        real=gen.sha
        def altered(path,lf=False):return '0'*64 if str(path).endswith('T_ai_materials_door_oak_albedo.png') else real(path,lf)
        with patch.object(gen,'sha',altered):self.reject(self.inputs,'original leaf producer source changed')
    def test_previous79_mappings_remain_canonically_exact(self):
        import hashlib
        old=[r for r in self.fixture['mappings']if r['model']in gen.ORIGINAL_MODELS]
        self.assertEqual(len(old),79)
        digest=hashlib.sha256(json.dumps(old,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
        self.assertEqual(digest,gen.ORIGINAL79_MAPPING_SHA256);self.assertEqual(digest,self.fixture['previous79_mapping_sha256'])
    def test_three_darkroom_source_roles_are_explicit_and_not_disposal(self):
        rows={r['source_part_id']:r for r in self.fixture['mappings']if r['model']=='PhotoRadioFittings'}
        prefix='storm_shop_photo_supplies_dr_door__'
        self.assertEqual(set(rows),{prefix+k for k in ('fabric_warm','wood_dark','iron_blackened')})
        for row in rows.values():
            self.assertEqual(row['cell'],'shop_photo_supplies');self.assertEqual(row['cohort'],'ADDED_THREE_DARKROOM_ROLES')
            self.assertEqual(row['door_frame']['id'],'ARCADE_STOCK_DOOR_PHOTO_SUPPLIES');self.assertFalse(row['door_frame']['paired'])
        fabric=rows[prefix+'fabric_warm'];wood=rows[prefix+'wood_dark'];iron=rows[prefix+'iron_blackened']
        self.assertEqual(fabric['specific_source_masks'],[]);self.assertTrue(fabric['no_separate_literal_mask_for_native_attachment'])
        self.assertEqual(iron['specific_source_masks'],[]);self.assertTrue(iron['no_separate_literal_mask_for_native_attachment'])
        self.assertEqual({m['id']for m in wood['specific_source_masks']},{'storm_shop_photo_supplies_dr_door'})
        curtain=next(r for r in fabric['successors']if r['kind']=='darkroom_native_draw')
        self.assertEqual(curtain['draw'],dict(name='LeftDarkroomCurtain',triangles=1288,material_key='fabric_warm'))
        self.assertEqual({s['name']for s in curtain['stocks']},{'PhotoDarkroomCurtain0','PhotoDarkroomCurtain1'})
        self.assertEqual({s['stock']['name']for s in wood['successors']if s['kind']=='shell_closed_stock'},{'shop_photo_supplies_stock_partition_door_'+s for s in ('left','right','head')})
        self.assertEqual({s['draw']['name']for s in iron['successors']},{'LeftBrass','LeftFixedBrass'})
        self.assertIn('ROLE_ONLY',iron['material_boundary'])
    def test_darkroom_selector_is_only_photo_stock_single(self):
        selection=self.fixture['darkroom_selection']
        self.assertEqual(selection['selected_frame_ids'],['ARCADE_STOCK_DOOR_PHOTO_SUPPLIES'])
        self.assertEqual(selection['removed_draw'],'LeftGlass');self.assertEqual(selection['added_draw'],'LeftDarkroomCurtain')
        self.assertEqual(selection['owner'],'shop_photo_supplies');self.assertEqual(selection['frame_kind'],'stock_single')
    def test_missing_curtain_draw_refuses(self):
        d=copy.deepcopy(self.inputs);d['curtain_proof']['parts']=[];self.reject(d,'one registered curtain draw required')
    def test_curtain_payload_and_role_changes_refuse(self):
        d=copy.deepcopy(self.inputs);d['curtain_proof']['asset_sha256']='0'*64;self.reject(d,'native curtain payload changed')
        d=copy.deepcopy(self.inputs);d['curtain_proof']['parts'][0]['material_key']='glassish';self.reject(d,'one registered curtain draw required')
        d=copy.deepcopy(self.inputs);d['curtain_runtime']['source_sha256_lf']='0'*64;self.reject(d,'darkroom curtain runtime/native proof differs')
    def test_missing_closed_curtain_stock_refuses(self):
        d=copy.deepcopy(self.inputs);d['curtain_proof']['stocks'].pop();self.reject(d,'two closed cloth stocks required')
    def test_curtaindoor_wrong_owner_selection_refuses(self):
        real=Path.read_text;door=gen.ROOT/'game/scripts/building/orison_v2_arcade_shop_door.gd'
        def changed(path,*args,**kwargs):
            text=real(path,*args,**kwargs)
            return text.replace('frame.cell == "shop_photo_supplies"','frame.cell == "shop_radio_service"')if path==door else text
        with patch.object(Path,'read_text',changed):self.reject(self.inputs,'darkroom selector owner/role changed')
    def test_curtain_does_not_restore_glass_or_create_second_owner(self):
        real=Path.read_text;door=gen.ROOT/'game/scripts/building/orison_v2_arcade_shop_door.gd'
        def changed(path,*args,**kwargs):
            text=real(path,*args,**kwargs)
            return text.replace('if curtained and identity == "LeftGlass": continue','# glass restored')if path==door else text
        with patch.object(Path,'read_text',changed):self.reject(self.inputs,'darkroom leaf/opaque infill selection seam changed')
    def test_path_hashes_use_declared_byte_conventions(self):
        for path in ('tools/prepare_arcade_rebuild_succession.py',
                     'tools/prepare_arcade_door_frames.py','tools/prepare_arcade_door_intake.py'):
            self.assertIn(path,self.fixture['source_bindings'])
        for name,row in self.fixture['source_bindings'].items():
            self.assertFalse(Path(name).is_absolute());self.assertEqual(gen.sha(gen.ROOT/name,row['kind']=='lf'),row['sha256'])
        self.assertNotIn('C:/',Path(gen.__file__).read_text(encoding='utf-8'))


if __name__=='__main__':unittest.main()
