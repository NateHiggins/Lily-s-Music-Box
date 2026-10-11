"""Fail-closed surface/import regressions for RUL-012."""
from pathlib import Path
import copy,importlib.util,sys,tempfile,unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from audit_v2_surfaces import evaluate
spec=importlib.util.spec_from_file_location('surface_imports',ROOT/'art/tools/fix_runtime_texture_imports.py');imports=importlib.util.module_from_spec(spec);spec.loader.exec_module(imports)

class Requirements(unittest.TestCase):
    def inventory(self):
        return {'schema':'orison.v2-surface-inventory.v1','passage_state':'RESIDENT',
                'draws':[{'path':'fixture','instances':1,'mesh':'mesh','materials':['material'],'visible':True}],
                'meshes':{'mesh':{'source':'fixture.glb','surfaces':[{'missing_uv':False,'nonfinite_uv':0,'degenerate_uv_triangles':0}]}},
                'materials':{'material':{'type':'StandardMaterial3D','normal_enabled':True,'filter':3,'maps':dict(zip(['albedo_texture','roughness_texture','normal_texture'],['albedo','rough','normal']))}},
                'textures':{k:{'type':'CompressedTexture2D','mips':True} for k in ['albedo','rough','normal']}}
    def test_transparent_physical_surface_cannot_hide_missing_maps(self):
        data=self.inventory();data['materials']['material'].update(transparency=1,maps={})
        self.assertIn('incomplete_pbr_maps',evaluate(data)['findings'][0]['reasons'])
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

if __name__=='__main__':unittest.main()
