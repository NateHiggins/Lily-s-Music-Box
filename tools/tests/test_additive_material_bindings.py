"""Construction renewal must not conceal an altered old finish or native source."""
import copy, hashlib, json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from renew_additive_material_bindings import additions, renew, FAMILIES, MANIFEST


class AdditiveBindingsTests(unittest.TestCase):
    def test_old_finish_and_manifest_authorities_cannot_change(self):
        old={'schema':1,'materials':{'old':{'files':['normal.png'],'normal_scale':1.}}}
        new=copy.deepcopy(old);new['materials']['new']={'files':['other.png']}
        self.assertEqual(additions(old,new),['new'])
        for changed in ('normal','removed','schema'):
            altered=copy.deepcopy(new)
            if changed=='normal':altered['materials']['old']['normal_scale']=.5
            elif changed=='removed':del altered['materials']['old']
            else:altered['schema']=2
            with self.assertRaises(ValueError):additions(old,altered)

    def fixture(self,root):
        previous=root/'previous.json';previous.write_text(json.dumps({'schema':1,'materials':{'old':{'normal':1}}}))
        current=root/MANIFEST;current.parent.mkdir(parents=True);current.write_text(json.dumps({'schema':1,'materials':{'old':{'normal':1},'new':{'normal':1}}}))
        source=root/'builder.py';source.write_text('original source')
        bindings={MANIFEST:hashlib.sha256(previous.read_bytes()).hexdigest(),
                  'builder.py':hashlib.sha256(source.read_bytes()).hexdigest()}
        for family in FAMILIES:
            asset_family='city_shells' if family=='city_closure' else family
            asset=root/f'game/assets/props/{asset_family}.glb';asset.parent.mkdir(parents=True,exist_ok=True);asset.write_bytes(b'unchanged mesh')
            data={'source_bindings':bindings,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':[{'id':'original'}]}
            for name in [f'art/blender/{family}_construction.json',f'game/tests/fixtures/orison_{family}.json']:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n')
        return previous,source

    def test_renewal_preserves_geometry_and_archives_construction(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);previous,_=self.fixture(root)
            report=renew(root,previous,root/'archive')
            self.assertEqual(len(report['renewed_records']),10)
            self.assertEqual(report['unchanged_materials'],1)
            self.assertTrue((root/'archive/previous_runtime_material_sets.json').is_file())
            for name in report['renewed_records']:
                data=json.loads((root/name).read_text());self.assertEqual(data['parts'],[{'id':'original'}])
                self.assertEqual(data['source_bindings'][MANIFEST],report['current_manifest_sha256'])

    def test_altered_source_or_output_aborts_without_writing(self):
        for change in ('source','mesh'):
            with self.subTest(change=change),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);previous,source=self.fixture(root)
                path=source if change=='source' else root/'game/assets/props/city_shells.glb'
                path.write_bytes(b'changed')
                with self.assertRaises(ValueError):renew(root,previous,root/'archive')
                self.assertFalse((root/'archive').exists())


if __name__=='__main__':unittest.main()
