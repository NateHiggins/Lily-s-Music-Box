"""Construction renewal must not conceal an altered old finish or native source."""
import copy, hashlib, json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from renew_additive_material_bindings import additions, renew, unused_replacements, FAMILIES, MANIFEST


class AdditiveBindingsTests(unittest.TestCase):
    def test_readable_family_checks_every_export_and_preserves_other_families(self):
        for changed in [False,True]:
            with self.subTest(changed=changed),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);previous,_=self.fixture(root)
                city=root/'art/blender/city_closure_construction.json';untouched=city.read_bytes()
                source=json.loads(untouched);source.pop('asset_sha256')
                source['outputs']={}
                for name in ['book.glb','book.blend']:
                    path=root/name;path.write_bytes(b'original stock')
                    source['outputs'][name]=hashlib.sha256(path.read_bytes()).hexdigest()
                record=root/'art/blender/readable_library_construction.json'
                record.write_text(json.dumps(source));original=record.read_bytes()
                if changed:
                    (root/'book.blend').write_bytes(b'changed native source')
                    with self.assertRaises(ValueError):renew(root,previous,root/'archive',families=['readable_library'])
                    self.assertEqual(record.read_bytes(),original)
                    self.assertFalse((root/'archive').exists())
                else:
                    report=renew(root,previous,root/'archive',families=['readable_library'])
                    self.assertEqual(list(report['renewed_records']),['art/blender/readable_library_construction.json'])
                self.assertEqual(city.read_bytes(),untouched)

    def test_named_switchboard_checks_its_export_before_renewing(self):
        for changed in [False,True]:
            with self.subTest(changed=changed),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);previous,_=self.fixture(root)
                source=json.loads((root/'art/blender/city_closure_construction.json').read_text())
                source['export']={'sha256':source.pop('asset_sha256')}
                path=root/'art/blender/house_switchboard_construction.json'
                path.write_text(json.dumps(source))
                asset=root/'game/assets/props/house_switchboard.glb'
                asset.write_bytes(b'changed' if changed else b'unchanged mesh')
                if changed:
                    with self.assertRaises(ValueError):renew(root,previous,root/'archive',families=['house_switchboard'])
                    self.assertFalse((root/'archive').exists())
                else:
                    report=renew(root,previous,root/'archive',families=['house_switchboard'])
                    self.assertEqual(list(report['renewed_records']),['art/blender/house_switchboard_construction.json'])

    def test_unused_replacement_requires_exact_manifest_delta(self):
        old={'schema':1,'materials':{'binding':{'normal':1},'stone':{'normal':2}}}
        new=copy.deepcopy(old);new['materials']['binding']['normal']=3
        self.assertEqual(unused_replacements(old,new,['binding']),['binding'])
        for keys in [[],['stone'],['binding','binding']]:
            with self.subTest(keys=keys),self.assertRaises(ValueError):unused_replacements(old,new,keys)
        new['materials']['stone']['normal']=5
        with self.assertRaises(ValueError):unused_replacements(old,new,['binding'])

    def test_unused_replacement_cannot_renew_a_consuming_native_family(self):
        for consumes in [False,True]:
            with self.subTest(consumes=consumes),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);previous,_=self.fixture(root)
                new=json.loads(previous.read_text());new['materials']['old']['normal']=2
                (root/MANIFEST).write_text(json.dumps(new))
                if consumes:
                    path=root/'art/blender/city_closure_construction.json'
                    data=json.loads(path.read_text());data['parts'][0]['key']='old'
                    path.write_text(json.dumps(data))
                    with self.assertRaises(ValueError):renew(root,previous,root/'archive',['old'])
                    self.assertFalse((root/'archive').exists())
                else:
                    report=renew(root,previous,root/'archive',['old'])
                    self.assertEqual(report['replaced_unused_keys'],['old'])
                    self.assertEqual(report['added_keys'],[])
                    self.assertEqual(report['unchanged_materials'],0)

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
