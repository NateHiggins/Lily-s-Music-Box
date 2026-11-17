"""Native-only Diner projection custody and fail-closed semantic controls."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_arcade_native_projection as gen

class ArcadeNativeProjectionTests(unittest.TestCase):
    def setUp(self):
        self.plan = json.loads((gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
    def reject(self, plan, message):
        with self.assertRaisesRegex(ValueError, message):
            gen.build(gen.ROOT, plan)
    def test_current_fixture_is_reproducible_and_complete(self):
        fixture = gen.build()
        self.assertEqual((gen.ROOT/gen.FIXTURE).read_text(encoding='utf-8').replace('\r\n','\n'), gen.render(fixture))
        self.assertEqual(len(fixture['models']), 7)
        self.assertEqual(len(fixture['entries']), 41)
        self.assertEqual(sum(x['triangles'] for x in fixture['entries']), 81408)
        stool_parts = [x for x in fixture['entries'] if x['model']=='ShopSeating']
        self.assertEqual(len(stool_parts), 7)
        self.assertEqual(sum(x['triangles'] for x in stool_parts), 6508)
        self.assertEqual({x['part_id'].split('__')[0] for x in stool_parts},
                         {'storm_shop_luncheonette_stool'+str(n) for n in (2,4,6)})
        assemblies = [a['id'] for g in self.plan['groups'] for a in g['assemblies']]
        self.assertEqual(len(assemblies), 17)
        self.assertEqual(len(set(assemblies)), 17)
    def test_provenance_binds_plan_mount_owner_and_sidecars(self):
        fixture = gen.build()
        self.assertEqual(fixture['placement_source'], gen.PLAN.as_posix())
        self.assertEqual(fixture['placement_sha256_lf'], gen.sha(gen.ROOT/gen.PLAN, True))
        self.assertEqual(set(fixture['source_bindings']),
                         {self.plan['mount_source']} | {m['sidecar'] for m in self.plan['models']})
        for source, row in fixture['source_bindings'].items():
            self.assertEqual(row['kind'], 'lf')
            self.assertEqual(row['sha256'], gen.sha(gen.resource(gen.ROOT, source), True))
        for source, digest in fixture['native_assets'].items():
            self.assertEqual(digest, gen.sha(gen.resource(gen.ROOT, source)))
        self.assertNotIn('C:/', (gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        self.assertNotIn('C:\\', (gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        self.assertNotIn('C:/ov', Path(gen.__file__).read_text(encoding='utf-8'))
    def test_menu_labels_preserve_exact_source_text_and_menu_projection(self):
        fixture = gen.build()
        sidecar = json.loads((gen.ROOT/'game/data/orison_v2/diner_overhead.json').read_text(encoding='utf-8'))
        source = {l['id']: l for c in sidecar['cells'] if c['id']=='shop_luncheonette' for l in c['labels']}
        self.assertEqual({l['label_id'] for l in fixture['labels']}, {'menu0','menu1','menu2'})
        self.assertEqual(len(fixture['labels']), 3)
        delta = next(g['delta_transform'] for g in self.plan['groups'] if g['name']=='diner_menu')
        declared = {l['label_id']: l for l in self.plan['labels']}
        for label in fixture['labels']:
            self.assertEqual(label['model'], 'DinerOverhead')
            self.assertEqual(label['node_name'], 'Words_'+label['label_id'])
            self.assertEqual(label['target_name'], label['node_name'])
            self.assertEqual(label['text'], source[label['label_id']]['text'])
            self.assertEqual([label['source_transform'][i][3] for i in range(3)], source[label['label_id']]['at'])
            self.assertEqual(label['delta_transform'], delta)
            self.assertEqual(label['target_transform'], declared[label['label_id']]['target_transform'])
    def test_missing_label_refuses(self):
        self.plan['labels'].pop()
        self.reject(self.plan, 'missing native labels')
    def test_duplicate_label_refuses(self):
        self.plan['labels'].append(copy.deepcopy(self.plan['labels'][0]))
        self.reject(self.plan, 'duplicate native label')
    def test_foreign_label_refuses(self):
        self.plan['labels'][0]['label_id'] = 'missing_menu'
        self.reject(self.plan, 'foreign native label')
    def test_menu_label_misgroup_refuses(self):
        self.plan['labels'][0]['group'] = 'diner_fan'
        self.reject(self.plan, 'wrong group')
    def test_menu_text_change_refuses(self):
        self.plan['labels'][0]['text'] += ' changed'
        self.reject(self.plan, 'native label text changed')
    def test_nonfinite_label_target_refuses(self):
        self.plan['labels'][0]['target_transform'][0][3] = float('inf')
        self.reject(self.plan, 'nonfinite matrix')
    def test_double_menu_label_delta_refuses(self):
        label = self.plan['labels'][0]
        delta = next(g['delta_transform'] for g in self.plan['groups'] if g['name']=='diner_menu')
        label['target_transform'] = gen.mul(delta, label['target_transform'])
        self.reject(self.plan, 'label target differs from menu delta')
    def test_missing_part_refuses(self):
        self.plan['groups'][0]['assemblies'][0]['parts'].pop()
        self.reject(self.plan, 'missing native parts')
    def test_duplicate_part_refuses(self):
        parts = self.plan['groups'][0]['assemblies'][0]['parts']
        parts.append(copy.deepcopy(parts[0]))
        self.reject(self.plan, 'duplicate native part')
    def test_foreign_part_refuses(self):
        self.plan['groups'][0]['assemblies'][0]['parts'][0]['part_id'] = 'unrelated_shop_fixture__metal'
        self.reject(self.plan, 'foreign native part')
    def test_part_cannot_be_assigned_to_another_assembly(self):
        self.plan['groups'][0]['assemblies'][0]['id'] = 'wrong_owner'
        self.reject(self.plan, 'wrong assembly')
    def test_duplicate_assembly_refuses(self):
        group = self.plan['groups'][0]
        group['assemblies'].append(copy.deepcopy(group['assemblies'][0]))
        self.reject(self.plan, 'duplicate assembly')
    def test_nonfinite_delta_or_declared_target_refuses(self):
        for delta in (True, False):
            with self.subTest(delta=delta):
                plan = copy.deepcopy(self.plan)
                value = plan['groups'][0]['delta_transform'] if delta else plan['groups'][0]['assemblies'][0]['parts'][0]['target_transform']
                value[0][3] = float('nan')
                self.reject(plan, 'nonfinite matrix')
    def test_scale_or_reflection_refuses(self):
        for value in (2.0, -1.0):
            with self.subTest(value=value):
                plan = copy.deepcopy(self.plan)
                plan['groups'][0]['delta_transform'][0][0] = value
                self.reject(plan, 'delta scale/shear|delta reflection')
    def test_double_delta_transform_refuses(self):
        group = self.plan['groups'][0]
        part = group['assemblies'][0]['parts'][0]
        part['target_transform'] = gen.mul(group['delta_transform'], part['target_transform'])
        self.reject(self.plan, 'target differs from delta')
    def test_native_asset_and_source_bindings_cannot_be_repinned_silently(self):
        for which in ('asset', 'sidecar', 'fabrication', 'cell', 'owner'):
            with self.subTest(which=which):
                plan = copy.deepcopy(self.plan)
                if which in ('asset', 'sidecar'):
                    plan['models'][0][which+'_sha256'+('_lf' if which=='sidecar' else '')] = '0'*64
                else:
                    key = {'fabrication':'fabrication_source', 'cell':'cell_source', 'owner':'mount_source'}[which]
                    plan[key+'_sha256_lf'] = '0'*64
                self.reject(plan, 'binding changed|sidecar changed|asset changed')
    def test_mount_metadata_and_prefix_match_actual_owner(self):
        for field in ('prefix','part_meta'):
            with self.subTest(field=field):
                plan = copy.deepcopy(self.plan)
                plan['models'][0][field] = 'wrong_'+field
                self.reject(plan, 'mount_records identity changed')

if __name__=='__main__':
    unittest.main()
