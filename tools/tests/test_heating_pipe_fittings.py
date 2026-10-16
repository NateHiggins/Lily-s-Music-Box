import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from heating_pipe_fittings import fitted_stations


class PipeFittingTests(unittest.TestCase):
    def test_quarter_circle_has_requested_radius_and_tangent_ports(self):
        stations=fitted_stations([[0,0,0],[1,0,0],[1,0,1]],radius=.1)
        for p,t in stations[1:-1]:
            self.assertAlmostEqual(math.dist(p,[.9,0,.1]),.1)
            self.assertAlmostEqual(sum(x*x for x in t),1)
        self.assertAlmostEqual(stations[1][0][0],.9)
        self.assertAlmostEqual(stations[-2][0][2],.1)

    def test_pitch_is_supported_without_forcing_square_bend(self):
        p=[[0,0,0],[1,.02,0],[1,.04,1]]
        stations=fitted_stations(p)
        self.assertEqual(stations[0][0],p[0])
        self.assertEqual(stations[-1][0],p[-1])
        self.assertGreater(stations[1][1][1],0)

    def test_short_leg_refused_instead_of_shrinking_elbow(self):
        with self.assertRaisesRegex(ValueError,'needs'):
            fitted_stations([[0,0,0],[.01,0,0],[.01,0,1]],radius=.04)


if __name__=='__main__': unittest.main()
