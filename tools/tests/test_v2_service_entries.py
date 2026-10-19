"""Missing door approach must never expand into a flight or shaft."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_service_entries import project


class ServiceEntries(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.source=json.loads((ROOT/'art/data/orison_v2/service_entry_source.json').read_text())

    def test_projection_is_current_idempotent_and_preserves_all_other_authorities(self):
        before=copy.deepcopy(self.layout)
        after=project(before,self.source)
        self.assertEqual(before,self.layout)
        self.assertEqual(after,self.layout)
        self.assertEqual(project(after,self.source),after)
        for key in before:
            if key!='platforms':self.assertEqual(before[key],after[key])
        original=[r for r in before['platforms'] if r['id']!='F01_SERVICE_ENTRY_PLATFORM']
        projected=[r for r in after['platforms'] if r['id']!='F01_SERVICE_ENTRY_PLATFORM']
        self.assertEqual(original,projected)

    def test_short_floor_larger_floor_and_invalid_owners_are_rejected(self):
        for field,value in [('rect',[9.5,5,10.55,6.05]),('rect',[9.5,5,10.6,6.75]),('rect',[9.4,5,10.55,6.75]),('rect',[9.5,4.9,10.55,6.75]),('rect',[9.5,5,10.55,float('nan')]),('door','F03_SERVICE_CORE_DOOR'),('stair','SERVICE_F02_F03'),('reason','')]:
            source=copy.deepcopy(self.source);source['repairs'][0][field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):project(self.layout,source)

    def test_changed_door_handing_or_width_requires_a_new_fit(self):
        for field,value in [('hinge','left'),('width',1.2),('yaw',0)]:
            layout=copy.deepcopy(self.layout)
            next(r for r in layout['doors'] if r['id']=='F01_SERVICE_CORE_DOOR')[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):project(layout,self.source)

    def test_existing_stock_and_non_solid_shaft_cannot_be_covered(self):
        for table,row in [('platforms',{'id':'foreign','level':'F01','rect':[9.7,5.1,10.1,5.7]}),('risers',{'id':'foreign','solid':False,'rect':[9.7,5.1,10.1,5.7]})]:
            layout=copy.deepcopy(self.layout);layout[table].append(row)
            with self.subTest(table=table),self.assertRaises(ValueError):project(layout,self.source)

    def test_bypasses_keep_existing_hall_walls_and_service_bores(self):
        after=project(self.layout,self.source)
        for identity in ['F01_SERVICE_HALL','F02_SERVICE_HALL','F01_CORE_TO_SERVICE']:
            self.assertEqual(next(r for r in after['spaces'] if r['id']==identity),next(r for r in self.layout['spaces'] if r['id']==identity))
        for key in ['riser_openings','slab_openings','risers','stairs','doors']:
            self.assertEqual(after[key],self.layout[key])
        for key in ['wall_service_openings','masonry_service_openings']:
            self.assertEqual([r for r in after[key] if not r['id'].startswith('F02_SERVICE_BYPASS_HEAT_')],
                             [r for r in self.layout[key] if not r['id'].startswith('F02_SERVICE_BYPASS_HEAT_')])

    def test_bypass_cannot_cover_private_space_or_cut_outside_shared_wall(self):
        for defect in ['width','owner','aperture','overlap']:
            layout=copy.deepcopy(self.layout);source=copy.deepcopy(self.source)
            if defect=='width':source['bypasses']['upper_room']['rect'][0]=6.5
            if defect=='owner':source['bypasses']['ground_openings'][0]['shared_wall_owner']='F01_D_MAIN'
            if defect=='aperture':source['bypasses']['upper_openings'][0]['center'][1]=-1.3
            if defect=='overlap':layout['spaces'].append({'id':'private','level':'F02','class':'private','rect':[7.2,0,8.2,.5]})
            with self.subTest(defect=defect),self.assertRaises(ValueError):project(layout,source)

    def test_unprojected_source_changes_only_named_new_stock(self):
        layout=copy.deepcopy(self.layout)
        owned_spaces={'F01_SERVICE_RISER_BYPASS','F02_SERVICE_RISER_BYPASS'}
        owned_openings={r['id'] for key in ['ground_openings','upper_openings'] for r in self.source['bypasses'][key]}
        layout['spaces']=[r for r in layout['spaces'] if r['id'] not in owned_spaces]
        layout['openings']=[r for r in layout['openings'] if r['id'] not in owned_openings]
        layout['platforms']=[r for r in layout['platforms'] if r['id']!='F01_SERVICE_ENTRY_PLATFORM']
        after=project(layout,self.source)
        for key in layout:
            if key not in ['spaces','platforms','openings']:self.assertEqual(layout[key],after[key])
        for key,owned in [('spaces',owned_spaces),('openings',owned_openings),('platforms',{'F01_SERVICE_ENTRY_PLATFORM'})]:
            self.assertEqual(layout[key],[r for r in after[key] if r['id'] not in owned])
        self.assertEqual(after,self.layout)


if __name__=='__main__':unittest.main()
