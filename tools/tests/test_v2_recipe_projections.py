"""Catch an obsolete material snapshot before paying for a composed world."""
from pathlib import Path
import json,sys,tempfile,unittest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from check_v2_recipe_projections import evaluate,calibrated

class RecipeProjection(unittest.TestCase):
    def test_calibrated_recipes_declare_renderer_readable_normal_profiles(self):
        # The loaded ABI has dedicated readers for these older recipes. All
        # other procedural stock uses the structured metric authoring profile.
        catalogue=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
        for key,policy in calibrated(ROOT).items():
            mapping=catalogue[key]['catalog_mapping']
            if not mapping.startswith('procedural/') or key=='bakelite' or key.startswith(('site_softwood','arcade_')):
                continue
            with self.subTest(material=key):
                recipe=json.loads((ROOT/'art/textures'/mapping/'material.json').read_text())
                self.assertIn('normal_authoring',recipe,'Global loaded ABI cannot read a top-level strength alone')
                profile=recipe['normal_authoring']
                self.assertEqual(profile['height_units'],'metres')
                self.assertEqual(profile['normal_convention'],'OpenGL')
                self.assertEqual(profile['normal_strength'],recipe['normal_strength'])
                self.assertEqual(profile['normal_strength'],policy['normal_scale'])

    def evaluate(self,part):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);data=root/'game/data';(data/'orison_v2').mkdir(parents=True)
            (data/'runtime_material_sets.json').write_text(json.dumps({'materials':{'bakelite':{'meters_per_tile':.04}}}))
            (data/'orison_v2/receiver.json').write_text(json.dumps({'parts':[part]}))
            return evaluate(root,{'bakelite':{'normal_scale':1.}})[0]
    def test_retired_tile_rejected(self):
        result=self.evaluate({'catalog_key':'bakelite','tile':.35,'normal':1.})
        self.assertEqual(result['counts']['wrong'],1);self.assertIn('/tile',result['wrong'][0])
    def test_legacy_relief_attenuation_rejected(self):
        result=self.evaluate({'catalog_key':'bakelite','tile':.04,'finish':{'normal_scale':.025}})
        self.assertEqual(result['counts']['wrong'],1);self.assertIn('/normal_scale',result['wrong'][0])
    def test_calibrated_projection_passes(self):
        result=self.evaluate({'catalog_key':'bakelite','tile':.04,'normal':1.})
        self.assertFalse(result['wrong']);self.assertEqual(result['checked_tiles'],1)
    def test_unrelated_finish_remains_outside_migration_check(self):
        result=self.evaluate({'catalog_key':'wood_dark','tile':.9,'normal':.2})
        self.assertFalse(result['wrong']);self.assertEqual(result['checked_tiles'],0)

if __name__=='__main__':unittest.main()
