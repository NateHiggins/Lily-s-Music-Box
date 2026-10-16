import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_v2_heating_interfaces import build,clip_segment,subtract_box


class HeatingInterfacesTests(unittest.TestCase):
    def test_box_subtraction_preserves_volume_without_overlapping_parts(self):
        pieces=subtract_box([0,0,0,3,3,3],[1,1,1,2,2,2])
        volume=lambda b:math.prod(b[i+3]-b[i] for i in range(3))
        self.assertEqual(sum(map(volume,pieces)),26)
        for i,a in enumerate(pieces):
            for b in pieces[i+1:]:
                self.assertTrue(any(min(a[k+3],b[k+3])<=max(a[k],b[k]) for k in range(3)))

    def fixture(self):
        return ({'spaces':[{'id':'ROOM','level':'F01','rect':[0,0,2,2]}],
                 'risers':[{'id':'HEAT_STACK','rect':[.4,.4,.6,.6],'from_y':-1,'to_y':1}]},
                {'branches':[{'id':'RADIATOR','level':'F01','riser':'H-A',
                              'points_local_godot':[[.5,-.13,.5],[1,0,1]]}]})

    def test_segment_clip_handles_parallel_miss_and_diagonal_entry(self):
        bounds=[0,0,0,1,1,1]
        self.assertIsNone(clip_segment([2,0,0],[2,1,1],bounds))
        self.assertEqual(clip_segment([-1,-1,-1],[2,2,2],bounds),[[0,0,0],[1,1,1]])

    def test_shaft_exit_opens_through_wall_with_fitting_clearance(self):
        layout,routes=self.fixture();result=build(layout,routes)
        port=next(r for r in result['riser_openings'] if 'SHAFT_EXIT' in r['id'])
        self.assertLessEqual(port['bounds'][0],.46)
        self.assertEqual(port['bounds'][3],.6)
        self.assertEqual(port['bounds'][5],.6)

    def test_floor_plate_covers_square_aperture_and_clears_pipe(self):
        layout,routes=self.fixture();result=build(layout,routes)
        opening=result['slab_openings'][0];sleeve=result['floor_sleeves'][0]
        self.assertEqual(opening['space'],'ROOM')
        half=(opening['rect'][2]-opening['rect'][0])/2
        self.assertGreater(sleeve['plate_outer_radius_m'],math.sqrt(2)*half)
        self.assertGreater(sleeve['bore_radius_m'],.029)
        self.assertLess(sleeve['neck_outer_radius_m'],half)

    def test_main_bore_clears_blind_cap_above_last_branch(self):
        layout,routes=self.fixture();result=build(layout,routes)
        bore=next(r for r in result['riser_openings'] if r['id']=='HEAT_H-A_MAIN_CLEAR')
        pipe_top=routes['branches'][0]['points_local_godot'][0][1]+.15
        self.assertGreaterEqual(bore['bounds'][4],pipe_top+.026+.01)

    def test_main_support_lugs_have_retained_shaft_bearing(self):
        layout,routes=self.fixture()
        layout['risers'][0]['to_y']=4
        routes['branches'][0]['points_local_godot']=[[.5,2,.5],[1,2.1,1]]
        result=build(layout,routes)
        self.assertTrue(result['main_supports'])
        for support in result['main_supports']:
            self.assertGreater(support['lug_reach_m'],.04)
            self.assertGreaterEqual(abs(support['center'][1]-2),.12)

    def test_main_support_cannot_anchor_outside_shaft(self):
        layout,routes=self.fixture()
        layout['risers'][0].update(rect=[.45,.4,.55,.6],to_y=4)
        routes['branches'][0]['points_local_godot']=[[.5,2,.5],[1,2.1,1]]
        with self.assertRaisesRegex(ValueError,'retained shaft bearing'):build(layout,routes)

    def test_cannot_silently_drill_an_unsupported_platform(self):
        layout,routes=self.fixture()
        layout['platforms']=[{'id':'PLATFORM','level':'F01','rect':[0,0,2,2]}]
        with self.assertRaisesRegex(ValueError,'Platform penetration'):build(layout,routes)

    def test_crossing_room_edge_is_not_accepted(self):
        layout,routes=self.fixture();routes['branches'][0]['points_local_godot'][-1]=[.01,0,1]
        with self.assertRaisesRegex(ValueError,'room edge'):build(layout,routes)

    def test_missing_floor_is_not_accepted(self):
        layout,routes=self.fixture();layout['spaces']=[]
        with self.assertRaisesRegex(ValueError,'No floor owner'):build(layout,routes)


if __name__=='__main__':unittest.main()
