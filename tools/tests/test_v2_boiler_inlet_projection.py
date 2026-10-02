"""A boiler service repair must preserve independent construction owners."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_boiler_inlet import project,SOURCE
from build_v2_roof import render
from build_v2_ventilation_fabric import project as ventilation_project,SOURCE as VENTILATION

class BoilerInletProjectionTest(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.source=json.loads(SOURCE.read_text())

    def test_round_trip_preserves_every_unowned_record(self):
        result=project(self.layout,self.source)
        self.assertEqual(self.layout,result,'Authored boiler service ports must already be projected')
        self.assertEqual(result,project(result,self.source))
        self.assertEqual(result,json.loads(render(json.dumps(self.layout,indent=2)+'\n',result)))
        owned={table:{r['id'] for r in rows} for table,rows in self.source['records'].items()}
        for table,rows in self.layout.items():
            expected=[r for r in rows if r['id'] not in owned.get(table,set())] if isinstance(rows,list) else rows
            actual=[r for r in result[table] if r['id'] not in owned.get(table,set())] if isinstance(rows,list) else result[table]
            self.assertEqual(expected,actual,table)

    def test_ventilation_can_regenerate_in_either_order(self):
        vent=json.loads(VENTILATION.read_text())
        self.assertEqual(project(ventilation_project(self.layout,vent),self.source),
                         ventilation_project(project(self.layout,self.source),vent))

    def test_foreign_table_id_and_duplicate_are_rejected(self):
        bad=copy.deepcopy(self.source);bad['records']['doors']=[{'id':'HEAT_FOREIGN_DOOR'}]
        with self.assertRaises(ValueError):project(self.layout,bad)
        bad=copy.deepcopy(self.source);bad['records']['wall_service_openings'][0]['id']='VENT_FOREIGN_PORT'
        with self.assertRaises(ValueError):project(self.layout,bad)
        bad=copy.deepcopy(self.source);bad['records']['wall_service_openings'].append(copy.deepcopy(bad['records']['wall_service_openings'][0]))
        with self.assertRaises(ValueError):project(self.layout,bad)

if __name__=='__main__':unittest.main()
