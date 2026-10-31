"""City discovery/precision policy must reject incomplete or misplaced assets."""
from pathlib import Path
import copy,json,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_horizon_assets import manifest_paths

class HorizonShards(unittest.TestCase):
    def setUp(self):self.source=json.loads((ROOT/'game/data/orison_v2/exterior/city_horizon.json').read_text(encoding='utf-8'))
    def rejected(self,source):
        with self.assertRaises((AssertionError,ValueError)):manifest_paths(source)
    def test_installed_manifest_covers_the_authored_replacement_buildings(self):
        paths=manifest_paths(self.source)
        self.assertEqual(len(paths),len(set(paths)))
        plan=json.loads((ROOT/'art/data/city_horizon/source_plan.json').read_text(encoding='utf-8'))
        authored={r['id'] for r in plan['buildings'] if r.get('architecture',{}).get('type') in ['industrial_front','mill_front','eastern_row','residential_front']}
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
