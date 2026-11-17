"""Preserve source authorities while moving real shop actor/transaction anchors."""
from pathlib import Path
import copy,importlib.util,json,math,sys,unittest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
import prepare_arcade_actor_projection as actors

class ActorProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.runtime,cls.fixture=actors.build(ROOT)
    def test_complete_same_id_roster_and_no_external_transform(self):
        rows=self.fixture['markers'];self.assertEqual(len(rows),61)
        self.assertEqual({k:sum(r['source_marker']['kind']==k for r in rows) for k in actors.KINDS},{'shop_sign':11,'passage_shop_hours':11,'cage_bulb':39})
        self.assertFalse(self.fixture['external_vantry_applied'])
        self.assertEqual(len({r['id'] for r in rows}),61)
    def test_all_nonspatial_actor_fields_are_exact(self):
        allowed={'pos','yaw_deg','w','half_width','blade_dx'}
        for row in self.fixture['markers']:
            a=row['source_marker'];b=row['target_marker']
            self.assertEqual({k:v for k,v in a.items() if k not in allowed},{k:v for k,v in b.items() if k not in allowed})
            self.assertTrue(all(math.isfinite(v) for v in b['pos']))
    def test_north_front_hours_keep_original_height_and_trade(self):
        rows=[r for r in self.fixture['markers'] if r['cell'] in ['shop_model_laundry','shop_hardware_paint','shop_luncheonette'] and r['source_marker']['kind']=='passage_shop_hours']
        self.assertEqual(len(rows),3)
        for row in rows:
            self.assertEqual(row['target_marker']['yaw_deg'],0.)
            self.assertEqual(row['source_marker']['h'],row['target_marker']['h'])
            self.assertEqual(row['source_marker']['trade'],row['target_marker']['trade'])
    def test_actual_native_counter_geometry_is_the_transaction_extent(self):
        for row in self.fixture['anchors']:
            a=row['source_record'];b=row['target_record'];self.assertEqual(a['id'],b['id'])
            for k in a:
                if k not in ['rect','z0']:self.assertEqual(a[k],b[k])
            self.assertAlmostEqual(b['rect'][2]-b['rect'][0],row['target_high'][0]-row['target_low'][0])
            self.assertAlmostEqual(b['rect'][3]-b['rect'][1],row['target_high'][2]-row['target_low'][2])
            self.assertAlmostEqual(b['z0'],a['z0']-.01,places=6)
            self.assertTrue(row['native_source']['part'].endswith('__countertop'))
    def test_original_safelight_uses_retained_process_group(self):
        rows=[r for r in self.fixture['markers'] if 'DARKROOM_' in r['id']]
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['source_marker']['kind'],'cage_bulb')
        self.assertIn('process_group',rows[0]['role']);self.assertEqual(rows[0]['target_marker']['energy'],rows[0]['source_marker']['energy'])
        target=rows[0]['target_marker'];self.assertEqual(target['yaw_deg'],180.)
        # Case back/source bracket atX22.94 lies on north room faceZ38.72;
        # the actor marker is .24m inside, rather than .02m into the wall.
        self.assertAlmostEqual(-target['pos'][1]-(22.94-rows[0]['source_marker']['pos'][0]),38.72)
    def test_shipping_patch_cannot_introduce_trade_inventory_or_light_policy(self):
        for row in self.runtime['markers']:
            self.assertEqual(set(row),{'id','kind','patch'})
            self.assertLessEqual(set(row['patch']),{'pos','yaw_deg','w','half_width','blade_dx'})
        for row in self.runtime['anchors']:self.assertEqual(set(row['patch']),{'rect','z0'})
    def test_legacy_news_extent_discrepancy_is_explicitly_retained(self):
        news=next(r for r in self.fixture['anchors'] if r['cell']=='shop_news_cigars')
        self.assertAlmostEqual(news['legacy_width_difference_m'],-.05,places=5)
    def test_generated_files_reproduce(self):
        for rel,doc in zip([actors.RUNTIME,actors.FIXTURE],[self.runtime,self.fixture]):
            self.assertEqual((ROOT/rel).read_text(encoding='utf-8'),json.dumps(doc,indent=1,allow_nan=False)+'\n')
    def test_builder_does_not_mutate_fabrication_or_placement_sources(self):
        paths=[ROOT/actors.doors.FABRICATION,ROOT/actors.doors.PLAN,ROOT/actors.RETAINED]
        before=[p.read_bytes() for p in paths];actors.build(ROOT);self.assertEqual(before,[p.read_bytes() for p in paths])
if __name__=='__main__':unittest.main()
