import copy
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from prepare_v2_front_lighting import source_from_plan,project,supply_from_export,render_layout

class FrontLightingProjectionTests(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.lights=json.loads((ROOT/'game/data/orison_v2/room_lighting.json').read_text())
        self.plan=json.loads((ROOT/'art/data/front_lighting_plan.json').read_text())
        self.source=source_from_plan(self.plan,self.layout)

    def test_projection_is_idempotent_and_preserves_unowned_records(self):
        before=copy.deepcopy(self.layout);new,lights=project(self.layout,self.lights,self.source)
        self.assertEqual(before,self.layout)
        self.assertEqual((new,lights),project(new,lights,self.source))
        for key,rows in self.layout.items():
            owned={r['id'] for r in self.source['records'].get(key,[])}
            if key not in self.source['records']:self.assertEqual(rows,new[key])
            else:self.assertEqual([r for r in rows if r['id'] not in owned],[r for r in new[key] if r['id'] not in owned])

    def test_port_extent_contains_pipe_without_cutting_other_height_bands(self):
        for port in self.source['records']['wall_service_openings']:
            bounds=port['bounds'];axis=0 if port['side'] in ['west','east'] else 2
            self.assertAlmostEqual(bounds[axis+3]-bounds[axis],self.layout['dimensions']['partition_wall'])
            self.assertAlmostEqual(bounds[4]-bounds[1],.038)

    def test_single_room_circuit_has_all_fixtures_and_one_control(self):
        fixtures=self.source['lighting']['fixtures'];controls=self.source['lighting']['switches']
        self.assertEqual(len({r['room'] for r in controls}),20)
        self.assertEqual({r['room'] for r in controls},{r['room'] for r in fixtures})
        self.assertEqual(len(controls),20);self.assertEqual(len(fixtures),35)

    def test_openings_are_enclosed_by_their_owning_walls(self):
        rooms={room['id']:room for room in self.layout['spaces']}
        levels={level['id']:level['y'] for level in self.layout['levels']}
        half=self.layout['dimensions']['partition_wall']/2
        for port in self.source['records']['wall_service_openings']:
            room=rooms[port['space']];x0,z0,x1,z1=room['rect'];y=levels[room['level']]
            side=port['side']
            height=self.layout['dimensions']['floor_to_floor' if room.get('no_ceiling') else 'clear_height']
            if side in ['north','south']:
                z=z0 if side=='south' else z1
                owner=[x0,y,z-half,x1,y+height,z+half]
            else:
                x=x0 if side=='west' else x1
                owner=[x-half,y,z0,x+half,y+height,z1]
            for axis in range(3):
                self.assertGreaterEqual(port['bounds'][axis]+1e-5,owner[axis],port['id'])
                self.assertLessEqual(port['bounds'][axis+3]-1e-5,owner[axis+3],port['id'])

    def test_missing_space_refuses_projection(self):
        self.layout['spaces']=[s for s in self.layout['spaces'] if s['id']!=self.plan['fixtures'][0]['room']]
        with self.assertRaises(ValueError):source_from_plan(self.plan,self.layout)

    def test_layout_render_preserves_checkout_line_endings(self):
        for ending in ['\n','\r\n']:
            original='{' + ending + '  "anchors": []' + ending + '}' + ending
            result={'anchors':[{'id':'new','position':[1,2,3]}]}
            rendered=render_layout(original,result)
            self.assertEqual(json.loads(rendered),result)
            self.assertEqual(rendered.count(ending),rendered.count('\n'))
            self.assertEqual(render_layout(rendered,result),rendered)

    def test_supply_mapping_matches_actual_export_and_rejects_ambiguous_names(self):
        asset=(ROOT/'game/assets/props/front_lighting_supply.glb').read_bytes()
        report=json.loads((ROOT/'art/data/orison_v2/front_lighting_supply_export.json').read_text())
        data=supply_from_export(asset,report)
        self.assertEqual(len(data['hangers']),407)
        self.assertEqual(len({row['node'] for row in data['hangers']}),407)
        self.assertEqual(len(data['materials']),20)
        self.assertEqual(data,json.loads((ROOT/'game/data/orison_v2/front_lighting_supply.json').read_text()))
        with self.assertRaises(ValueError):supply_from_export(asset+b'changed',report)
        report['hanger_placements'][0]['node']='absent'
        with self.assertRaises(ValueError):supply_from_export(asset,report)

if __name__=='__main__':unittest.main()
