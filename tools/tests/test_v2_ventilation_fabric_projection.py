"""Ventilation service clearances cannot rewrite another construction owner."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_ventilation_fabric import project, SOURCE
from build_v2_roof import project as roof_project, render
from build_v2_vertical_services import project as other_project

class VentilationFabricProjectionTest(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.source=json.loads(SOURCE.read_text())

    def test_new_tables_round_trip_and_unowned_records_survive(self):
        before=copy.deepcopy(self.layout)
        before.pop('wall_service_openings',None)
        before.pop('masonry_service_openings',None)
        before['riser_openings'].append({'id':'OTHER_PIPE_PORT','bounds':[1,2,3,4,5,6]})
        result=project(before,self.source)
        self.assertEqual(result,project(result,self.source))
        owned={table:{r['id'] for r in rows} for table,rows in self.source['records'].items()}
        for table,rows in before.items():
            expected=[r for r in rows if r['id'] not in owned.get(table,set())] if isinstance(rows,list) else rows
            actual=[r for r in result[table] if r['id'] not in owned.get(table,set())] if isinstance(rows,list) else result[table]
            self.assertEqual(expected,actual,table)
        self.assertEqual(json.loads(render(json.dumps(before,indent=2)+'\n',result)),result)

    def test_roof_and_home_owners_stay_fresh(self):
        candidate=project(self.layout,self.source)
        roof=json.loads((ROOT/'art/data/orison_v2/roof_source.json').read_text())
        self.assertEqual(candidate,roof_project(candidate,roof))
        for name in ['vertical_services','completion_interiors']:
            other=json.loads((ROOT/f'art/data/orison_v2/{name}_source.json').read_text())
            self.assertEqual(candidate,other_project(candidate,other))

    def test_foreign_tables_and_duplicate_owned_ids_are_rejected(self):
        bad=copy.deepcopy(self.source)
        bad['records']['doors']=[{'id':'FOREIGN_DOOR'}]
        with self.assertRaises(ValueError):project(self.layout,bad)
        bad=copy.deepcopy(self.source)
        bad['records']['wall_service_openings'].append(copy.deepcopy(bad['records']['wall_service_openings'][0]))
        with self.assertRaises(ValueError):project(self.layout,bad)

if __name__=='__main__':unittest.main()
