"""The shipped cap kinematics must stay bound to the actual native recipe."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from build_v2_radiator_vent_thread import project,SOURCE,TARGET

class VentThreadProjectionTest(unittest.TestCase):
    def test_shipped_travel_and_envelope_match_current_native_authority(self):
        source=json.loads(SOURCE.read_text())
        self.assertEqual(json.loads(TARGET.read_text()),project(source))

    def test_invalid_physical_recipe_cannot_publish_runtime_motion(self):
        source=json.loads(SOURCE.read_text())
        for key,value in [('schema_version',True),('pitch_m',0),('pitch_m',True),('pitch_m',float('nan')),('engagement_m',.011),('root_radius_m',.02),('female_radial_clearance_m',.002),('angular_samples',8),('samples_per_pitch',3)]:
            bad=copy.deepcopy(source);bad[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):project(bad)

if __name__=='__main__':unittest.main()
