import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_c_stove_stack import plan,project

class CStoveStackPlan(unittest.TestCase):
    def setUp(self):self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes())
    def test_five_owned_ports_preserve_restricted_third_floor(self):
        p=plan(self.layout);self.assertEqual(len(p['ports']),5);self.assertEqual(p['ports'][1]['space'],'F03_C_RESTRICTED')
        self.assertEqual([r['id'] for r in p['ports']],[f'F{f:02d}_FLUE_BREAST' for f in range(2,7)])
    def test_projection_adds_only_required_records_and_preserves_originals(self):
        original=copy.deepcopy(self.layout);p=plan(original);result=project(original,p)
        self.assertEqual(original,self.layout);self.assertEqual(project(result,p),result)
        for key,value in self.layout.items():
            if key=='anchors':
                expected=copy.deepcopy(value)
                for move in p['furniture_moves']:next(r for r in expected if r['id']==move['id'])['position'][2]=move['z']
                self.assertEqual(result[key][:len(value)],expected)
            elif isinstance(value,list):self.assertEqual(result[key][:len(value)],value)
            else:self.assertEqual(result[key],value)
    def test_conflicting_existing_identity_is_refused(self):
        p=plan(self.layout);self.layout['anchors'].append({'id':'F02_FLUE_BREAST','position':[0,0,0]})
        with self.assertRaisesRegex(ValueError,'Conflicting'):project(self.layout,p)
    def test_wall_patch_matches_original_plaster_thickness(self):
        p=plan(self.layout)
        for port in p['ports']:
            b=port['plaster_patch_bounds'];self.assertAlmostEqual(b[3]-b[0],self.layout['dimensions']['partition_wall']);self.assertAlmostEqual(port['position'][0]+.002,b[0])
        for cut in p['masonry_service_openings']:self.assertAlmostEqual(cut['bounds'][3],p['riser']['rect'][0])
    def test_stack_has_real_continuity_and_owned_roof(self):
        p=plan(self.layout);b=p['riser_openings'][0]['bounds'];self.assertEqual([b[0],b[2],b[3],b[5]],p['slab_openings'][0]['rect']);self.assertEqual(b[4],19.2);self.assertLess(p['riser']['from_y'],0)
    def test_window_conflict_is_not_silently_covered(self):
        self.layout['windows'].append({'id':'fixture','space':'F02_C_BED2','axis':'z','center':[7.1,10.05],'width':.6})
        with self.assertRaisesRegex(ValueError,'blocks a window'):plan(self.layout)
    def test_stack_does_not_occupy_any_existing_room(self):
        rect=plan(self.layout)['riser']['rect']
        for room in self.layout['spaces']:
            if room['level'] not in ['F02','F03','F04','F05','F06']:continue
            r=room['rect'];area=max(0,min(rect[2],r[2])-max(rect[0],r[0]))*max(0,min(rect[3],r[3])-max(rect[1],r[1]))
            self.assertEqual(area,0,room['id'])
    def test_roof_connection_goes_around_the_open_stairwell(self):
        p=plan(self.layout);self.assertNotIn('ROOF_SERVICE_CORE/Floor',p['masonry_coupling']['owners'])
        self.assertEqual(p['masonry_coupling']['points_local_godot'][1][2],10.75)
    def test_shaft_avoids_retained_c_wing_steel_and_foundation_components(self):
        p=plan(self.layout);a,c,b,d=p['riser']['rect'];shaft=[a,p['riser']['from_y'],c,b,p['native_top_y'],d]
        native=json.loads((ROOT/'art/blender/rear_wing_c_support_construction.json').read_bytes())['source_plan']['components']
        self.assertGreater(len(native),20)
        for part in native:
            r=part['bounds'];overlap=[max(0,min(shaft[i+3],r[i+3])-max(shaft[i],r[i])) for i in range(3)]
            self.assertEqual(overlap[0]*overlap[1]*overlap[2],0,part['id'])
    def test_partial_apron_penetration_is_explicitly_owned(self):
        p=plan(self.layout);cut=next(r for r in p['slab_openings'] if r['space']=='F01_REAR_APRON')['rect'];apron=next(r for r in self.layout['spaces'] if r['id']=='F01_REAR_APRON')['rect']
        self.assertEqual(cut[0],apron[0]);self.assertLess(cut[0],cut[2]);self.assertLess(cut[2],apron[2]);self.assertLess(apron[1],cut[1]);self.assertLess(cut[3],apron[3])

if __name__=='__main__':unittest.main()
