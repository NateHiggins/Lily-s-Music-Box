"""Fail-closed surface/import regressions for RUL-012."""
from pathlib import Path
import copy,gzip,hashlib,importlib.util,json,sys,tempfile,unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from audit_v2_surfaces import evaluate
spec=importlib.util.spec_from_file_location('surface_imports',ROOT/'art/tools/fix_runtime_texture_imports.py');imports=importlib.util.module_from_spec(spec);spec.loader.exec_module(imports)

class Requirements(unittest.TestCase):
    def test_city_and_grade_native_source_changes_expire_surface_proof(self):
        import v2_surface_evidence as evidence
        with patch.object(evidence,'file_hash',return_value='source'):
            before=evidence.inputs()['sha256']
        for relative in [
            'art/data/city_elevations/source_plan.json',
            'art/data/city_ground_apron/source_plan.json',
            'art/blender/city_elevations.blend',
            'art/blender/city_elevations_construction.json',
            'art/blender/city_ground_apron.blend',
            'art/blender/city_ground_apron_construction.json',
            'art/data/city_horizon/source_plan.json',
            'art/blender/city_horizon_near.blend',
            'art/blender/city_horizon_far.blend',
            'art/blender/city_horizon_construction.json',
        ]:
            with self.subTest(relative=relative):
                target=ROOT/relative
                with patch.object(evidence,'file_hash',side_effect=lambda path:
                                  'changed' if path==target else 'source'):
                    self.assertNotEqual(before,evidence.inputs()['sha256'])
    def inventory(self):
        return {'schema':'orison.v2-surface-inventory.v1','passage_state':'RESIDENT',
                'draws':[{'path':'fixture','instances':1,'mesh':'mesh','materials':['material'],'visible':True}],
                'meshes':{'mesh':{'source':'fixture.glb','surfaces':[{'missing_uv':False,'nonfinite_uv':0,'degenerate_uv_triangles':0}]}},
                'materials':{'material':{'type':'StandardMaterial3D','triplanar':False,'normal_enabled':True,'filter':3,'maps':dict(zip(['albedo_texture','roughness_texture','normal_texture'],['albedo','rough','normal']))}},
                'textures':{k:{'type':'CompressedTexture2D','mips':True} for k in ['albedo','rough','normal']}}
    def test_transparent_physical_surface_cannot_hide_missing_maps(self):
        data=self.inventory();data['materials']['material'].update(transparency=1,maps={})
        self.assertIn('incomplete_pbr_maps',evaluate(data)['findings'][0]['reasons'])
    def native_union_vapor(self):
        data=self.inventory()
        data['draws'][0].update(owner='radiator/WorkingAssembly',
            path='radiator/WorkingAssembly/LocalizedUnionVapor/Puff0',
            owner_script='res://scripts/props/radiator_native_assembly.gd',
            surface_role='steam_volume',geometry_transparency=.55)
        data['materials']['material'].update(maps={},normal_enabled=False,color=[.7,.72,.7,.3])
        return data
    def test_native_union_vapor_keeps_uv_and_sampled_map_checks(self):
        data=self.native_union_vapor()
        result=evaluate(data)
        self.assertFalse(result['findings'])
        self.assertEqual(result['separate_effects'][0]['class'],'steam_volume')
        data['meshes']['mesh']['surfaces'][0]['missing_uv']=True
        self.assertIn('missing_uv',evaluate(data)['findings'][0]['reasons'])
        data=self.native_union_vapor()
        data['materials']['material']['maps']={'albedo_texture':'albedo'}
        data['textures']['albedo']['mips']=False
        self.assertIn('missing_loaded_mips:albedo',evaluate(data)['findings'][0]['reasons'])
    def test_native_steam_label_cannot_exempt_physical_radiator_stock(self):
        changes=[{'path':'radiator/WorkingAssembly/SharedCastSections'},
                 {'path':'radiator/WorkingAssembly/Hardware/LocalizedUnionVapor/Puff0'},
                 {'owner':''},{'owner_script':'res://scripts/props/unknown.gd'},
                 {'surface_role':'physical'},{'geometry_transparency':0}]
        for change in changes:
            with self.subTest(change=change):
                data=self.native_union_vapor();data['draws'][0].update(change)
                self.assertIn('incomplete_pbr_maps',evaluate(data)['findings'][0]['reasons'])
        data=self.native_union_vapor()
        data['materials']['material']['color'][3]=1
        self.assertIn('incomplete_pbr_maps',evaluate(data)['findings'][0]['reasons'])
    def surface_run_fixture(self,folder,stderr=''):
        import v2_surface_evidence as evidence
        test='game/tests/orison_v2_surface_inventory.gd'
        target=folder/test;target.parent.mkdir(parents=True);target.write_bytes(b'fixture surface test\n')
        source={'test_path':test,'test_sha256':evidence.file_hash(target),'runtime_inputs_sha256':'runtime-inputs'}
        run={'schema':'orison.run-receipt.v1','schema_version':1,'evidence_kind':'suite_run',
             'scene':'res://tests/OrisonV2SurfaceInventory.tscn','windowed':True,
             'execution':{'completed':True,'exit_code':0,'timed_out':False},'source':source,
             'log':{'script_error_count':0,'fail_count':0}}
        for channel,text in [('stdout','V2 SURFACE QUALIFICATION: PASS\n'),('stderr',stderr)]:
            raw=text.encode();(folder/('suite_run.'+channel+'.log.gz')).write_bytes(gzip.compress(raw))
            run['log'][channel+'_sha256']=hashlib.sha256(raw).hexdigest()
        (folder/'suite_run.receipt.json').write_text(json.dumps(run))
        return {'source':copy.deepcopy(source)},run
    def test_surface_contract_needs_successful_matching_error_free_run(self):
        import v2_surface_evidence as evidence
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory);contract,run=self.surface_run_fixture(folder)
            self.assertFalse(evidence.suite_run_defects(folder,contract,folder))
            variants=[('script errors',lambda r:r['log'].update(script_error_count=1)),
                      ('failed checks',lambda r:r['log'].update(fail_count=1)),
                      ('failed process',lambda r:r['execution'].update(exit_code=1)),
                      ('timeout',lambda r:r['execution'].update(timed_out=True)),
                      ('wrong source',lambda r:r['source'].update(test_sha256='other')),
                      ('wrong digest',lambda r:r['source'].update(runtime_inputs_sha256='other')),
                      ('headless',lambda r:r.update(windowed=False)),
                      ('changed log',lambda r:r['log'].update(stderr_sha256='other'))]
            for name,mutate in variants:
                with self.subTest(case=name):
                    bad=copy.deepcopy(run);mutate(bad)
                    (folder/'suite_run.receipt.json').write_text(json.dumps(bad))
                    self.assertTrue(evidence.suite_run_defects(folder,contract,folder))
    def test_raw_renderer_error_cannot_hide_behind_zero_script_error_count(self):
        import v2_surface_evidence as evidence
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory);contract,_=self.surface_run_fixture(folder,'ERROR: renderer fixture failed\n')
            self.assertIn('Godot errors in surface stderr',evidence.suite_run_defects(folder,contract,folder))
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory);contract,_=self.surface_run_fixture(folder,'WARNING: 7 RIDs of type "Texture" were leaked.\n')
            self.assertFalse(evidence.suite_run_defects(folder,contract,folder))
    def test_hidden_closed_stock_still_requires_uvs(self):
        data=self.inventory();data['draws'][0]['visible']=False;data['meshes']['mesh']['surfaces'][0]['missing_uv']=True
        self.assertIn('missing_uv',evaluate(data)['findings'][0]['reasons'])
    def test_loaded_mips_required_even_when_import_settings_look_correct(self):
        data=self.inventory();data['textures']['normal']['mips']=False
        self.assertIn('missing_loaded_mips:normal',evaluate(data)['findings'][0]['reasons'])
    def test_incomplete_region_never_gets_pass(self):
        data=self.inventory();data['passage_state']='DORMANT'
        with self.assertRaises(ValueError):evaluate(data)
    def test_clean_inventory_has_no_technical_findings(self):
        self.assertFalse(evaluate(self.inventory())['findings'])
    def test_empty_inventory_cannot_pass(self):
        data=self.inventory();data['draws']=[]
        with self.assertRaises(ValueError):evaluate(data)
    def test_valid_unused_uvs_do_not_pass(self):
        data=self.inventory();data['materials']['material']['triplanar']=True
        self.assertIn('uvs_bypassed_by_triplanar',evaluate(data)['findings'][0]['reasons'])
        data['materials']['material'].pop('triplanar')
        self.assertIn('uv_application_unobserved',evaluate(data)['findings'][0]['reasons'])
    def test_surface_shader_must_observe_mesh_uv_mode(self):
        data=self.inventory();material=data['materials']['material']
        material.update(type='ShaderMaterial',shader='res://shaders/orison_surface.gdshader',uv_mode=1)
        self.assertIn('uvs_bypassed_by_triplanar',evaluate(data)['findings'][0]['reasons'])
        material['uv_mode']=0
        self.assertFalse(evaluate(data)['findings'])
    def test_next_pass_is_not_a_missing_map_escape(self):
        data=self.inventory();data['materials']['material']['next_pass']={'type':'StandardMaterial3D','maps':{},'normal_enabled':False,'filter':3}
        self.assertIn('incomplete_pbr_maps',evaluate(data)['findings'][0]['reasons'])
    def test_unknown_geometry_is_not_silently_skipped(self):
        data=self.inventory();data['unhandled_geometry']=[{'path':'physical_sprite','type':'Sprite3D'}]
        self.assertEqual(evaluate(data)['counts']['unhandled_geometry'],1)
    def test_mip_chain_and_filter_both_required(self):
        data=self.inventory();data['materials']['material']['filter']=1
        data['textures']['normal'].update(width=256,height=256,mip_levels=2)
        self.assertIn('non_mipmapped_filter',evaluate(data)['findings'][0]['reasons'])
        self.assertIn('incomplete_loaded_mip_chain:normal',evaluate(data)['findings'][0]['reasons'])
    def test_shader_map_disabled_and_sampler_are_failures(self):
        data=self.inventory();material=data['materials']['material']
        material.update(type='ShaderMaterial',has_normal_tex=False,mip_filters={'albedo_texture':True,'roughness_texture':True,'normal_texture':False})
        reasons=evaluate(data)['findings'][0]['reasons']
        self.assertIn('disabled_shader_map:has_normal_tex',reasons)
        self.assertIn('non_mipmapped_shader_sampler:normal_texture',reasons)
    def test_content_sharing_never_shares_different_channels_or_pixels(self):
        spec=importlib.util.spec_from_file_location('sets',ROOT/'art/tools/generate_runtime_materials.py')
        sets=importlib.util.module_from_spec(spec);spec.loader.exec_module(sets)
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)
            for name,raw in [('a_albedo',b'pigment'),('a_rough',b'height'),('a_normal',b'normal'),
                             ('b_albedo',b'other pigment'),('b_rough',b'height'),('b_normal',b'height')]:
                (folder/(name+'.png')).write_bytes(raw)
            patches={'GODOT_TEXTURES':folder,'RUNTIME_POLICY':{'a':{},'b':{}},'VISUAL_LOCKS':{},
                     '_read_json':lambda path: {'a':{},'b':{}} if path==sets.CATALOG else {'a':'a','b':'b'},
                     '_metadata_for':lambda mapped:{'meters_per_tile':.6},
                     '_canonical_files':lambda key:[key+'_'+c+'.png' for c in ['albedo','rough','normal']]}
            with patch.multiple(sets,**patches):
                result=sets.build_contract()['materials']
                self.assertEqual(result['b']['files'],['b_albedo.png','a_rough.png','b_normal.png'])
                (folder/'b_rough.png').write_bytes(b'changed surface')
                self.assertEqual(sets.build_contract()['materials']['b']['files'][1],'b_rough.png')
    def test_named_halo_requires_real_effect_flags_and_loaded_mips(self):
        data=self.inventory();draw=data['draws'][0]
        draw.update(surface_role='optical_halo',owner_script='res://scripts/props/light_fixture_prop.gd')
        material=data['materials']['material']
        material.update(unshaded=True,additive=True,billboard=True,normal_enabled=False,maps={'albedo_texture':'albedo'})
        self.assertFalse(evaluate(data)['findings'])
        material['additive']=False
        self.assertTrue(evaluate(data)['findings'])
        material['additive']=True;data['textures']['albedo']['mips']=False
        self.assertIn('missing_loaded_mips:albedo',evaluate(data)['findings'][0]['reasons'])
    def test_import_repair_preserves_other_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'normal.png.import';path.write_text('[params]\nprocess/normal_map_invert_y=false\nmipmaps/generate=false\n')
            imports.patch(path,imports.V2_WANT);text=path.read_text()
            self.assertIn('process/normal_map_invert_y=false',text)
            self.assertIn('mipmaps/generate=true',text)
            self.assertIn('compress/normal_map=2',text)
            self.assertFalse(imports.patch(path,imports.V2_WANT))
    def test_flame_classification_cannot_exempt_a_stove_body(self):
        data=self.inventory();data['draws'][0].update(surface_role='gas_flame',owner_script='res://scripts/building/orison_v2_stove.gd')
        data['materials']['material'].update(maps={},normal_enabled=False,unshaded=True,emissive=True,transparency=1)
        self.assertFalse(evaluate(data)['findings'])
        data['materials']['material']['emissive']=False
        self.assertTrue(evaluate(data)['findings'])
    def test_only_registered_clear_glass_has_uniform_albedo(self):
        data=self.inventory();data['materials']['material']={'type':'ShaderMaterial','shader':'res://shaders/lamp_glass_surface.gdshader','maps':{'rough_tex':'res://assets/building/textures/T_glass_rough.png','normal_tex':'res://assets/building/textures/T_glass_normal.png'}}
        data['textures']={k:{'mips':True} for k in data['materials']['material']['maps'].values()}
        self.assertFalse(evaluate(data)['findings'])
        data['materials']['material']['maps'].pop('normal_tex')
        self.assertTrue(evaluate(data)['findings'])

    def test_derived_character_import_cache_does_not_change_qualification(self):
        import v2_surface_evidence as evidence
        original_glob=Path.glob
        def with_derived_cache(folder,pattern):
            yield from original_glob(folder,pattern)
            if folder.name=='mina_vale' and pattern=='*.png.import':
                yield folder/'ignored_surface_gate_probe.png.import'
        with patch.object(evidence,'file_hash',return_value='source'):
            before=evidence.inputs()['sha256']
            with patch.object(Path,'glob',with_derived_cache):
                self.assertEqual(before,evidence.inputs()['sha256'])
    def test_authored_shader_change_invalidates_qualification(self):
        import v2_surface_evidence as evidence
        with patch.object(evidence,'file_hash',return_value='source'):
            before=evidence.inputs()['sha256']
        def changed_shader(path):
            return 'changed' if path.name=='lamp_glass_surface.gdshader' else 'source'
        with patch.object(evidence,'file_hash',side_effect=changed_shader):
            self.assertNotEqual(before,evidence.inputs()['sha256'])

    def test_front_lighting_native_and_projection_changes_invalidate_qualification(self):
        import v2_surface_evidence as evidence
        with patch.object(evidence,'file_hash',return_value='source'):
            before=evidence.inputs()['sha256']
        for name in ('build.py','front_lighting_candidate.blend','front_lighting_plan.json',
                     'front_lighting_source.json','front_lighting_supply_export.json',
                     'prepare_v2_front_lighting.py','export.py',
                     'front_lighting_finish_candidate.blend','front_lighting_cornice_candidate.blend',
                     'millwork_profile.blend','front_trim_layout_source.json','front_trim_export_source.json',
                     'plan_v2_front_trim.py'):
            with self.subTest(name=name):
                with patch.object(evidence,'file_hash',side_effect=lambda path:
                                  'changed' if path.name==name else 'source'):
                    self.assertNotEqual(before,evidence.inputs()['sha256'])

    def test_heating_refit_authoring_inputs_invalidate_surface_qualification(self):
        import v2_surface_evidence as evidence
        with patch.object(evidence,'file_hash',return_value='source'):
            before=evidence.inputs()['sha256']
        for relative in ('art/blender/heating_distribution.blend',
                         'art/blender/heating_distribution_base19.blend',
                         'art/data/orison_v2/heating_refit_authoring.json',
                         'art/data/orison_v2/heating_refit_layout_source.json',
                         'tools/prepare_v2_heating_refit.py',
                         'art/blender/scripts/build_heating_refit.py',
                         'art/blender/scripts/heating_refit/export.py'):
            with self.subTest(path=relative):
                target=ROOT/relative
                with patch.object(evidence,'file_hash',side_effect=lambda path:
                                  'changed' if path==target else 'source'):
                    self.assertNotEqual(before,evidence.inputs()['sha256'])

if __name__=='__main__':unittest.main()
