import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from plan_v2_heating_distribution import route, segment_distance


class HeatingRouteTests(unittest.TestCase):
    def test_route_goes_around_open_shaft(self):
        points=route([.2,1],[2.8,1],[[0,0,3,2]],[[1,.5,2,1.5]])
        self.assertTrue(points)
        self.assertTrue(any(p[1]<.5 or p[1]>1.5 for p in points))

    def test_reserved_neighbor_survives_route_simplification(self):
        barrier=([1,.2],[1,1.6])
        points=route([.2,1],[2.8,1],[[0,0,3,2]],[],pipes=[barrier])
        self.assertTrue(points)
        for a,b in zip(points,points[1:]):
            self.assertGreaterEqual(segment_distance(a,b,*barrier),.072-1e-8)

    def test_short_diagonal_cannot_clip_reserved_pipe_between_samples(self):
        barrier=([.5,.5],[.5,.5])
        points=route([.2,.57],[.8,.57],[[0,0,1,1]],[],pipes=[barrier])
        self.assertTrue(points)
        for a,b in zip(points,points[1:]):
            self.assertGreaterEqual(segment_distance(a,b,*barrier),.072-1e-8)

    def test_unsmoothed_route_keeps_shaft_detour(self):
        points=route([.23,1],[2.77,1],[[0,0,3,2]],[[1,.5,2,1.5]],smooth=False)
        self.assertTrue(points)
        self.assertEqual(points[0],[.23,1])
        self.assertEqual(points[-1],[2.77,1])
        self.assertTrue(any(p[1]<.5 or p[1]>1.5 for p in points))

    def test_disconnected_floor_is_not_bridged(self):
        self.assertEqual(route([.2,.5],[2.8,.5],[[0,0,1,1],[2,0,3,1]],[]),[])

    def test_pipe_radius_must_fit_at_endpoint(self):
        self.assertEqual(route([.01,.5],[.8,.5],[[0,0,1,1]],[]),[])

    def test_crossing_and_skew_pipes(self):
        self.assertAlmostEqual(segment_distance([-1,0,0],[1,0,0],[0,0,-1],[0,0,1]),0)
        self.assertAlmostEqual(segment_distance([-1,0,0],[1,0,0],[0,.2,-1],[0,.2,1]),.2)

    def test_parallel_disjoint_and_zero_length_segments(self):
        self.assertAlmostEqual(segment_distance([0,0,0],[1,0,0],[0,2,0],[1,2,0]),2)
        self.assertAlmostEqual(segment_distance([0,0,0],[1,0,0],[2,0,0],[3,0,0]),1)
        self.assertAlmostEqual(segment_distance([0,0,0],[0,0,0],[0,0,2],[0,0,3]),2)


if __name__=='__main__': unittest.main()
