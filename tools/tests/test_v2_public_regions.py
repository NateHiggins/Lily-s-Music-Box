"""Real source frame conservation, complete old-record retention and dogleg shape."""
import copy,json,sys,unittest
import importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from build_v2_public_regions import derive,NAMES

class PublicRegionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.values=[json.loads((ROOT/p).read_text(encoding='utf8')) for p in ['art/data/building_layout.json','game/data/orison_v2/exterior/regions.json','game/data/orison_v2/exterior/construction_shed.json','game/data/orison_v2/exterior/street_frame.json']]
    def test_source_preserved_and_projection_idempotent(self):
        values=copy.deepcopy(self.values);before=copy.deepcopy(values);data,bindings=derive(*values)
        self.assertEqual(values,before);self.assertEqual((data,bindings),derive(values[0],data,values[2],values[3]))
        for key in ['regions','instances','routes']:
            current={r['id']:r for r in data[key]}
            generated={'ROUTE_STREET_TO_ARCADE','ROUTE_ARCADE_TO_STREET','ROUTE_STREET_TO_CONSTRUCTION','ROUTE_CONSTRUCTION_TO_STREET'} if key=='routes' else {'REGION_'+n if key=='regions' else n+'_01' for n in NAMES}
            for row in values[1][key]:
                if row['id'] not in generated:self.assertEqual(row,current[row['id']])
        for old in values[1]['surface_templates']:
            if old['id'] in {'TEMPLATE_'+n+'_V2' for n in NAMES}:continue
            current=next(r for r in data['surface_templates'] if r['id']==old['id'])
            for key in ['surfaces','placements']:
                byid={r['id']:r for r in current[key]}
                for row in old[key]:
                    if row['id'] not in {'arcade_crossing','public_pavement_clear','arcade_pavement_turn','arcade_crossing_near','arcade_crossing_far','construction_approach'}:self.assertEqual(row,byid[row['id']])
    def test_every_imported_instance_has_one_owner_without_duplicating_bounded_cells(self):
        data,bindings=derive(*self.values);bounded=bindings['bounded_instance_ids'];external=[m['instance_id'] for m in bindings['modules']]
        self.assertEqual(set(bounded),{'STREET_ORISON_01','SHOP_BODEGA'});self.assertEqual(len(external),4)
        self.assertFalse(set(bounded)&set(external));self.assertEqual(set(bounded+external),{i['id'] for i in data['instances']})
        for module in bindings['modules']:self.assertTrue(module['geometry_paths']);self.assertIn(module['owner_node'],['StreetBoundaries','VantryArcade'])
    def test_frames_independently_conserve_existing_geometry_placement(self):
        data,bindings=derive(*self.values);instances={r['id']:r for r in data['instances']};templates={r['id']:r for r in data['surface_templates']}
        def origin(identity):
            i=instances[identity];offset=i['offset_uvn_m'];self.assertEqual(i['local_yaw_degrees'],0)
            if not i['owner_instance_id']:return [offset[0],offset[2],offset[1]]
            owner=instances[i['owner_instance_id']];surface=next(s for s in templates[owner['template_id']]['surfaces'] if s['id']==i['owner_surface_id']);base=origin(owner['id'])
            return [base[k]+surface['point_m'][k]+sum(surface[axis][k]*offset[j] for j,axis in enumerate(['u_axis','v_axis','normal'])) for k in range(3)]
        for module in bindings['modules']:
            at=origin(module['instance_id']);delta=[a-b for a,b in zip(at,module['source_origin_m'])]
            expected=[0,0,0] if module['owner_node']=='StreetBoundaries' else [0,0,-self.values[3]['source_threshold_z']]
            for actual,want in zip(delta,expected):self.assertAlmostEqual(actual,want,places=10)
    def test_construction_region_retains_the_concave_covered_dogleg(self):
        data,_=derive(*self.values);p=next(r['boundary'] for r in data['regions'] if r['id']=='REGION_CONSTRUCTION_SEAM')
        self.assertEqual(len(p),6);area=abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(p,p[1:]+p[:1])))/2
        self.assertAlmostEqual(area,34.25);self.assertLess(area,(max(x for x,z in p)-min(x for x,z in p))*(max(z for x,z in p)-min(z for x,z in p)))
    def test_changed_physical_datums_cannot_silently_publish_a_route(self):
        for change in ['wall','frame','roof']:
            values=copy.deepcopy(self.values)
            if change=='wall':next(r for f in values[0]['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']=='site_passage_throat_e')['rect'][0]+=.1
            if change=='frame':values[3]['arcade_building_line_z']+=.1
            if change=='roof':next(r for r in values[2]['boxes'] if r['id']=='ShedTurnRoof')['center'][2]+=.1
            with self.subTest(change=change),self.assertRaises(ValueError):derive(*values)

    def city_derivation(self):
        spec=importlib.util.spec_from_file_location('public_city_registration',ROOT/'art/blender/scripts/city_registration.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module.derive_city_offsets

    def test_public_programmes_preserve_every_registered_city_offset(self):
        derive_offsets=self.city_derivation()
        blockout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        registered=json.loads((ROOT/'art/blender/city_shells_registration.json').read_text())['offsets']
        augmented,_=derive(*self.values)
        actual=derive_offsets(self.values[0],blockout,augmented)
        self.assertEqual(actual,registered)

    def test_actual_street_boundary_change_cannot_reuse_city_registration(self):
        derive_offsets=self.city_derivation()
        blockout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        original=derive_offsets(self.values[0],blockout,self.values[1])
        changed=copy.deepcopy(self.values[1]);boundary=next(r['boundary'] for r in changed['regions'] if r['id']=='REGION_STREET')
        east=max(p[0] for p in boundary)
        for point in boundary:
            if point[0]==east:point[0]+=1.0
        updated=derive_offsets(self.values[0],blockout,changed)
        self.assertNotEqual(updated,original)
        self.assertTrue(all(abs(updated[k]-original[k]-1.0)<1e-9 for k in original if k.startswith('site_ne')))

if __name__=='__main__':unittest.main()
