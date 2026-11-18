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
                         {self.plan['mount_source'], self.plan['cell_source']+'.import'} | {m['sidecar'] for m in self.plan['models']} | set(self.plan['cell_buffers']))
        for source, row in fixture['source_bindings'].items():
            self.assertEqual(row['kind'], 'raw' if source in self.plan['cell_buffers'] else 'lf')
            self.assertEqual(row['sha256'], gen.sha(gen.resource(gen.ROOT, source), row['kind']=='lf'))
        for source, digest in fixture['native_assets'].items():
            self.assertEqual(digest, gen.sha(gen.resource(gen.ROOT, source)))
        self.assertNotIn('C:/', (gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        self.assertNotIn('C:\\', (gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        self.assertNotIn('C:/ov', Path(gen.__file__).read_text(encoding='utf-8'))
    def test_raw_import_preserves_source_position_precision(self):
        from unittest.mock import patch
        path = gen.resource(gen.ROOT, self.plan['cell_source'] + '.import')
        original_read = Path.read_text
        def compressed_read(current, *args, **kwargs):
            text = original_read(current, *args, **kwargs)
            return text.replace('meshes/force_disable_compression=true', 'meshes/force_disable_compression=false') if current == path else text
        with patch.object(Path, 'read_text', compressed_read):
            self.reject(self.plan, 'exact uncompressed imported positions')

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
    def test_raw_stocks_are_complete_original_box_surfaces(self):
        fixture = gen.build()
        rows = fixture['raw_stocks']
        self.assertEqual(fixture['raw_stock_ids'], list(gen.RAW_IDS))
        self.assertEqual({r['id'] for r in rows}, set(fixture['raw_stock_ids']))
        self.assertEqual(len(rows), 12)
        self.assertEqual(sum(r['expected_triangles'] for r in rows), 144)
        selected = set()
        for row in rows:
            self.assertEqual(row['expected_triangles'], 12)
            self.assertEqual((row['source_low'],row['source_high']), gen.raw_bounds(row['source_record']))
            for primitive in row['source_selections']:
                self.assertIn('POSITION', primitive['attributes'])
                self.assertIn('NORMAL', primitive['attributes'])
                self.assertIn('TEXCOORD_0', primitive['attributes'])
                self.assertEqual(len(primitive['selected_indices']), 3*len(primitive['selected_triangle_indices']))
                for triangle in primitive['selected_triangle_indices']:
                    key = (primitive['node_index'],primitive['primitive_index'],triangle)
                    self.assertNotIn(key, selected, 'each original facet belongs to one stock only')
                    selected.add(key)
        self.assertEqual(len(selected), 144)
    def test_missing_empty_or_duplicate_raw_inventory_refuses(self):
        for value in (None, [], list(gen.RAW_IDS[:-1])+[gen.RAW_IDS[0]]):
            with self.subTest(value=value):
                plan = copy.deepcopy(self.plan)
                plan['raw_stock_ids'] = value
                self.reject(plan, 'raw stock inventory')
    def test_missing_raw_stock_refuses(self):
        self.plan['raw_stocks'].pop()
        self.reject(self.plan, 'missing mandatory raw stocks')
    def test_duplicate_raw_stock_refuses(self):
        self.plan['raw_stocks'].append(copy.deepcopy(self.plan['raw_stocks'][0]))
        self.reject(self.plan, 'duplicate raw stock')
    def test_false_raw_source_record_refuses(self):
        self.plan['raw_stocks'][0]['source_record']['z0'] += .001
        self.reject(self.plan, 'literal raw source record changed')
    def test_false_raw_source_box_refuses(self):
        self.plan['raw_stocks'][0]['source_low'][0] += .001
        self.reject(self.plan, 'false raw source box')
    def test_wrong_raw_target_bounds_refuses(self):
        self.plan['raw_stocks'][0]['target_low'][0] += .001
        self.reject(self.plan, 'wrong raw target bounds')
    def test_wrong_cell_binary_hash_refuses(self):
        for name in self.plan['cell_buffers']:
            self.plan['cell_buffers'][name] = '0'*64
        self.reject(self.plan, 'cell binary binding changed')
    def test_ambiguous_actual_original_facets_refuse(self):
        cell = gen.SourceCell(gen.ROOT, self.plan['cell_source'], self.plan['cell_buffers'])
        first = self.plan['raw_stocks'][0]
        alias = copy.deepcopy(first)
        alias['id'] = 'overlapping_selector'
        with self.assertRaisesRegex(ValueError, 'ambiguous original stock facets'):
            gen.select_raw_faces(cell, [first,alias])
    def test_twelve_facets_cannot_hide_a_missing_box_face(self):
        cell = gen.SourceCell(gen.ROOT, self.plan['cell_source'], self.plan['cell_buffers'])
        first = self.plan['raw_stocks'][0]
        faces = gen.select_raw_faces(cell,[first])[first['id']]
        self.assertEqual(len(faces),12)
        faces[-1] = faces[0]
        with self.assertRaisesRegex(ValueError, 'missing oriented face|duplicated or incomplete|face diagonal'):
            gen.validate_box_faces(faces,first)
    def test_raw_rack_cannot_change_internal_support_relationships(self):
        first = self.plan['raw_stocks'][0]
        first['delta_transform'][0][3] += .10
        first['target_low'][0] += .10
        first['target_high'][0] += .10
        self.reject(self.plan, 'raw group relative geometry changed')

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
