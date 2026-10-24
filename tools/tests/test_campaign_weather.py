"""Cross-owner calendar consistency, including dated newspapers and forecast issue times."""
import datetime as dt
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CampaignWeatherTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.calendar = json.loads((ROOT/'game/data/weather/campaign_weather.json').read_text(encoding='utf8'))
        cls.days = cls.calendar['days']

    def test_complete_contiguous_playable_year(self):
        actual = [d['date'] for d in self.days]
        start = dt.date(1928,11,10)
        self.assertEqual(actual, [(start+dt.timedelta(days=i)).isoformat() for i in range(365)])

    def test_newspaper_ears_and_existing_authored_owners_are_exact(self):
        papers = {d['date']:d for p in (ROOT/'game/data/newspapers').glob('19*.json')
                  for d in json.loads(p.read_text(encoding='utf8'))['issues']}
        for day in self.days:
            self.assertEqual(day['record_ear'],papers[day['date']]['record']['ear'])
            self.assertEqual(day['speaker_ear'],papers[day['date']]['speaker']['ear'])

    def test_forecasts_have_issue_and_validity_not_hindsight(self):
        for day in self.days:
            self.assertEqual(len(day['bulletins']),2)
            for report in day['bulletins']:
                issued = dt.datetime.fromisoformat(report['issued_at'])
                self.assertEqual(issued.date().isoformat(),day['date'])
                self.assertLessEqual(issued,dt.datetime.fromisoformat(report['valid_from']))
                self.assertLess(dt.datetime.fromisoformat(report['valid_from']),dt.datetime.fromisoformat(report['valid_until']))
                self.assertIn(report['confidence'],['fair','uncertain'])
        april = next(d for d in self.days if d['date']=='1929-04-16')
        self.assertIn('clearing',april['bulletins'][0]['prediction'])
        self.assertTrue(april['bulletins'][1]['revision'])
        self.assertTrue(any(f['rain_mm']>0 for f in april['frames']))

    def test_all_frames_are_bounded_and_interpolatable(self):
        for day in self.days:
            frames=day['frames']
            self.assertEqual(frames[0]['minute'],0)
            self.assertEqual([f['minute'] for f in frames],sorted(set(f['minute'] for f in frames)))
            for f in frames:
                self.assertTrue(-35<=f['temperature_c']<=45)
                self.assertTrue(0<=f['relative_humidity']<=100)
                for key in ['cloud_total','cloud_low','cloud_mid','cloud_high','hail','cyclone','severe_storm_threat']:
                    self.assertTrue(0<=f[key]<=1,(day['date'],key))
                self.assertTrue(0<=f['rain_mm']<=8 and 0<=f['snowfall_cm']<=4)
                self.assertTrue(970<=f['pressure_hpa']<=1045)
                self.assertGreaterEqual(f['wind_gusts_kmh'],f['wind_speed_kmh'])

    def test_remark_profiles_cover_existing_trees_without_touching_mina(self):
        records=json.loads((ROOT/'game/data/weather/resident_weather.json').read_text(encoding='utf8'))['residents']
        self.assertEqual(len(records),17)
        self.assertEqual(len({r['resident_id'] for r in records}),17)
        for r in records:
            self.assertTrue((ROOT/f"game/data/dialogue/{r['resident_id']}.json").exists())
            for kind in ['cold','heat','wet','snow','clearing','fair','fog','night','trend']:
                self.assertGreater(len(r[kind]),20)
            self.assertNotEqual(r['resident_id'],'mina')

    def test_fog_forecast_and_storm_timing_match_the_authored_papers(self):
        rows={d['date']:d for d in self.days}
        jan7={f['minute']:f for f in rows['1929-01-07']['frames']}
        jan8={f['minute']:f for f in rows['1929-01-08']['frames']}
        self.assertNotEqual(jan7[720]['weather_code'],45)
        self.assertEqual(jan7[1080]['weather_code'],45)
        self.assertEqual(jan8[0]['weather_code'],45)
        self.assertNotEqual(jan8[1260]['weather_code'],45)
        july={f['minute']:f for f in rows['1929-07-11']['frames']}
        self.assertEqual(july[1304]['rain_mm'],0)
        self.assertGreater(july[1305]['rain_mm'],0)
        self.assertAlmostEqual((july[1305]['temperature_c']-july[1365]['temperature_c'])*9/5,22,places=1)
        self.assertEqual(july[1391]['rain_mm'],0)

    def test_regeneration_is_byte_stable(self):
        path=ROOT/'tools/build_weather_calendar.py'
        spec=importlib.util.spec_from_file_location('calendar_generator',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        import tempfile
        with tempfile.TemporaryDirectory() as target:
            module.OUT=Path(target)/'calendar.json';module.generate()
            self.assertEqual(module.OUT.read_bytes(),(ROOT/'game/data/weather/campaign_weather.json').read_bytes())


if __name__=='__main__': unittest.main()
