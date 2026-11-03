"""City discovery/precision policy must reject incomplete or misplaced assets."""
from pathlib import Path
import copy,hashlib,json,sys,unittest,zipfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_horizon_assets import manifest_paths,native_groups

class HorizonNativeGroups(unittest.TestCase):
    def test_far_street_ends_have_one_additional_source_with_exact_part_coverage(self):
        names=['HORIZON_FAR_0_0_P0__limestone','HORIZON_FAR_0_0_P0__mirror_aged',
               'HORIZON_STREET_END_0_P1__limestone','HORIZON_STREET_END_3_P2__mirror_aged']
        groups=native_groups('far',names)
        self.assertEqual(groups,{'far':sorted(names[:2]),'street_end':sorted(names[2:])})
        self.assertEqual(native_groups('lod1',names),{'lod1':sorted(names)})
    def test_wrong_family_duplicate_and_malformed_native_parts_fail_closed(self):
        far='HORIZON_FAR_0_0_P0__limestone'
        for family,names in [('near',[far]),('far',[far,far]),('far',['bad']),('bad',[far]),('far',[])]:
            with self.subTest(family=family,names=names):
                with self.assertRaises((AssertionError,ValueError)):native_groups(family,names)

class HorizonShards(unittest.TestCase):
    def setUp(self):self.source=json.loads((ROOT/'game/data/orison_v2/exterior/city_horizon.json').read_text(encoding='utf-8'))
    def pane_disposition(self):
        archive=ROOT/'art/reviews/city_streets_20261029/city_building_packets_native_20261103.zip'
        self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(),'f3a45dcb3117b3dc7b3817a4f064ff2b0e0904f1672563a1fa6849b7d0f9886e')
        with zipfile.ZipFile(archive) as packet:
            return json.loads(packet.read('P2_PANE_DISPOSITION.json'))
    def test_replaced_p2_preserves_every_declared_new_aperture_witness(self):
        disposition=self.pane_disposition()
        self.assertEqual(len(disposition['old_roster']),192)
        self.assertEqual(len(disposition['new_roster']),184)
        self.assertEqual(len({r['semantic_id'] for r in disposition['new_roster']}),184)
        self.assertTrue(disposition['near_lower_witnesses_exact'])
        fixture=json.loads((ROOT/'game/tests/fixtures/orison_city_horizon.json').read_bytes())
        actual=[w for w in fixture['window_rows'] if w['building']=='HORIZON_NEAR_3_0_P2']
        # Full body replacement, not eight waived rays: every new point,
        # normal and recess must match the independently reviewed delivery.
        self.assertEqual(actual,[r['witness'] for r in disposition['new_roster']])
    def test_p2_replacement_keeps_the_separate_46_pane_neighbor_exact(self):
        fixture=json.loads((ROOT/'game/tests/fixtures/orison_city_horizon.json').read_bytes())
        neighbor=[w for w in fixture['window_rows'] if w['building']=='HORIZON_NEAR_3_0_P0R2']
        self.assertEqual(len(neighbor),46)
        digest=hashlib.sha256(json.dumps(neighbor,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        self.assertEqual(digest,self.pane_disposition()['neighbor_46_sha256'])
    def rejected(self,source):
        with self.assertRaises((AssertionError,ValueError)):manifest_paths(source)
    def test_installed_manifest_covers_the_authored_replacement_buildings(self):
        paths=manifest_paths(self.source)
        self.assertEqual(len(paths),len(set(paths)))
        plan=json.loads((ROOT/'art/data/city_horizon/source_plan.json').read_text(encoding='utf-8'))
        authored={r['id'] for r in plan['buildings'] if r.get('architecture',{}).get('type') in ['industrial_front','mill_front','eastern_row','residential_front','packet_front']}
        actual={identity for entry in self.source['body_lod']['assets'] for identity in entry['buildings']}
        self.assertEqual(actual,authored)
    def test_missing_base_block_is_rejected(self):
        self.source['assets'].pop();self.rejected(self.source)
    def test_duplicate_part_is_rejected(self):
        entry=self.source['assets'][0];entry['parts'].append(entry['parts'][0]);self.rejected(self.source)
    def test_split_building_is_rejected(self):
        first,second=self.source['assets'][:2];second['parts'].append(first['parts'].pop());self.rejected(self.source)
    def test_precision_exception_cannot_target_an_unregistered_mesh(self):
        self.source['assets'][0]['asset']='res://assets/props/orison_ground.glb';self.rejected(self.source)
    def test_partial_replacement_body_is_rejected(self):
        self.source['body_lod']['assets'][0]['parts'].pop();self.rejected(self.source)
    def test_duplicate_building_declaration_is_rejected(self):
        entry=self.source['assets'][0];entry['buildings'].append(entry['buildings'][0]);self.rejected(self.source)
    def test_malformed_part_is_rejected(self):
        self.source['assets'][0]['parts'][0]='HORIZON_NEAR_BAD__limestone';self.rejected(self.source)

if __name__=='__main__':unittest.main()
