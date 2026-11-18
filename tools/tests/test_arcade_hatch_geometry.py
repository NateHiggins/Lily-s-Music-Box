"""Pure hatch/finish construction and retained-source circulation controls."""
import collections
import copy
import importlib.util
import itertools
import json
import math
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_arcade_native_projection import NativeGLB
SPEC=importlib.util.spec_from_file_location('arcade_hatch_geometry',ROOT/'art/blender/scripts/arcade_hatch_geometry.py')
geo=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(geo)


def manifold(stock):
    edges=collections.Counter((a,b)for face in stock['faces']for a,b in zip(face,face[1:]+face[:1]))
    return all(n==1 and edges[(b,a)]==1 for(a,b),n in edges.items())


def bound(stock):return[[min(p[i]for p in stock['vertices'])for i in range(3)],[max(p[i]for p in stock['vertices'])for i in range(3)]]


def overlap(a,b):return min(a[2],b[2])>max(a[0],b[0])and min(a[3],b[3])>max(a[1],b[1])


def covers(rect,x,y):return rect[0]<=x<=rect[2]and rect[1]<=y<=rect[3]


def floor_source(name):return dict(name=name,owner='public',material='public_floor',plan_rect_m=list(geo.FLOOR_RECTS[name]),bottom_m=-.04,top_m=0.,original_identity='keep_me',role='public_walk')


class ArcadeHatchGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout=json.loads((ROOT/'game/data/building_layout.json').read_text(encoding='utf-8'))
        cls.plaza=json.loads((ROOT/'art/data/arcade_plaza/source_plan.json').read_text(encoding='utf-8'))
        cls.output=geo.build(cls.layout,cls.plaza)
    def test_exact_five_ids_literal_sources_and_no_input_mutation(self):
        layout,plaza=copy.deepcopy(self.layout),copy.deepcopy(self.plaza);before=(copy.deepcopy(layout),copy.deepcopy(plaza));out=geo.build(layout,plaza)
        self.assertEqual((layout,plaza),before)
        self.assertEqual({r['source_record_id']for r in out['stocks']},{h[0]for h in geo.HATCHES})
        self.assertEqual(out['proof']['counts'],dict(hatches=5,hatch_triangles=60))
        for stock in out['stocks']:
            source=next(r for f in layout['floors']if f['id']=='F01'for r in f['furniture']if r['id']==stock['source_record_id'])
            self.assertEqual(stock['source_record'],source);self.assertEqual(stock['source_record_sha256'],geo._digest(source))
            self.assertEqual(stock['source_material'],'metal');self.assertEqual(stock['material'],'metal');self.assertFalse(stock['interactive']);self.assertFalse(stock['disposal_authorized'])
            self.assertIn('UPGRADE',stock['finish_upgrade']);self.assertNotIn('news',stock['name'])
    def test_actual_closed_hatch_topology_dimensions_orientation_volume(self):
        for stock in self.output['stocks']:
            self.assertTrue(manifold(stock));self.assertEqual(len(stock['faces']),12)
            low,high=bound(stock);self.assertEqual(low[2],-.004);self.assertEqual(high[2],0.)
            self.assertAlmostEqual(geo.volume(stock),.9*1.3*.004,places=12)
            lengths=[high[0]-low[0],high[1]-low[1]]
            expected=[1.3,.9]if stock['owner']in('shop_model_laundry','shop_luncheonette')else[.9,1.3]
            for a,b in zip(lengths,expected):self.assertAlmostEqual(a,b,places=12)
            self.assertEqual(stock['orientation_yaw_deg'],90 if expected==[1.3,.9]else 0)
    def test_missing_duplicate_and_changed_original_source_refuse(self):
        identity=geo.HATCHES[0][0]
        for mode in('missing','duplicate','width','material','unknown_metadata'):
            layout=copy.deepcopy(self.layout);f=next(f for f in layout['floors']if f['id']=='F01');r=next(r for r in f['furniture']if r['id']==identity)
            if mode=='missing':f['furniture'].remove(r)
            elif mode=='duplicate':f['furniture'].append(copy.deepcopy(r))
            elif mode=='width':r['rect'][2]+=.01
            elif mode=='material':r['mat']='wood_dark'
            else:r['new_field']='not_in_literal_source'
            with self.subTest(mode=mode),self.assertRaisesRegex(ValueError,'original hatch'):geo.build(layout,self.plaza)
    def test_source_frame_floor_names_and_pair_dimensions_refuse_drift(self):
        for mode in('origin','layer','rectangle','pair'):
            p=copy.deepcopy(self.plaza)
            if mode=='origin':p['source_origin_blender_m'][0]+=.01
            elif mode=='layer':p['finish_layer_m']=.03
            elif mode=='rectangle':p['public_floor_rects_m'][0][0]+=.1
            else:p['front_frame_clear_m']=1.8
            with self.subTest(mode=mode),self.assertRaises(ValueError):geo.build(self.layout,p)
    def test_receiving_cut_pieces_are_closed_disjoint_exact_volume_and_support(self):
        cuts=self.output['floor_cuts'];byid={s['source_record_id']:s for s in self.output['stocks']}
        for name in geo.FLOOR_RECTS:
            original=floor_source(name);before=copy.deepcopy(original);pieces=geo.cut_public_floor(original,cuts);self.assertEqual(original,before)
            self.assertEqual(len({p['name']for p in pieces}),len(pieces))
            own=[c for c in cuts if c['floor_stock_name']==name]
            for p in pieces:
                self.assertTrue(manifold(p));self.assertGreater(geo.volume(p),0);self.assertEqual(p['owner'],'public');self.assertEqual(p['material'],'public_floor');self.assertEqual(p['source_stock_name'],name);self.assertEqual(p['source_stock_snapshot'],original);self.assertEqual(p['original_identity'],'keep_me');self.assertEqual(p['role'],'public_walk');self.assertEqual(p['bottom_m'],-.04)
            for i,p in enumerate(pieces):
                for q in pieces[i+1:]:self.assertFalse(overlap(p['plan_rect_m'],q['plan_rect_m']))
            self.assertAlmostEqual(sum(p['area_m2']for p in pieces),geo.area(original['plan_rect_m']),places=10)
            removed=sum(geo.area(c['plan_rect_m'])*.004 for c in own)
            self.assertAlmostEqual(sum(geo.volume(p)for p in pieces),geo.area(original['plan_rect_m'])*.04-removed,places=10)
            self.assertAlmostEqual(sum(geo.volume(p)for p in pieces)+sum(geo.volume(byid[c['source_record_id']])for c in own),geo.area(original['plan_rect_m'])*.04,places=10)
            for c in own:
                receivers=[p for p in pieces if p.get('receives_source_record_id')==c['source_record_id']];self.assertEqual(len(receivers),1);r=receivers[0]
                self.assertEqual(r['top_m'],-.004);self.assertEqual(r['plan_rect_m'],c['plan_rect_m']);self.assertAlmostEqual(r['top_m']-r['bottom_m'],.036)
                self.assertEqual(byid[c['source_record_id']]['bottom_m'],r['top_m'])
                self.assertFalse(any(overlap(p['plan_rect_m'],c['plan_rect_m'])for p in pieces if p['hatch_cut_role']=='UNCHANGED_FULL_DEPTH_FINISH'))
    def test_every_public_surface_sample_has_exactly_one_floor_or_hatch_cap(self):
        for name in geo.FLOOR_RECTS:
            pieces=geo.cut_public_floor(floor_source(name));hatches=[s for s in self.output['stocks']if s['receiver_floor_stock']==name];surfaces=[p for p in pieces if p['top_m']==0.]+hatches;rect=geo.FLOOR_RECTS[name]
            # Sample strict interiors of all independently derived arrangement cells.
            xs=sorted({rect[0],rect[2]}|{p['plan_rect_m'][i]for p in surfaces for i in(0,2)});ys=sorted({rect[1],rect[3]}|{p['plan_rect_m'][i]for p in surfaces for i in(1,3)})
            for a,b in zip(xs,xs[1:]):
                for c,d in zip(ys,ys[1:]):
                    x,y=(a+b)/2,(c+d)/2
                    if covers(rect,x,y):self.assertEqual(sum(covers(p['plan_rect_m'],x,y)for p in surfaces),1)
    def test_invalid_outside_overlap_depth_identity_and_anchor_cuts_refuse(self):
        for mode in('outside','overlap','depth','duplicate','missing','anchor'):
            cuts=copy.deepcopy(self.output['floor_cuts'])
            if mode=='outside':cuts[0]['plan_rect_m']=[-1.,21.25,.3,22.15]
            elif mode=='overlap':cuts[4]['plan_rect_m']=list(cuts[3]['plan_rect_m'])
            elif mode=='depth':cuts[0]['bottom_m']=-.05;cuts[0]['cut_depth_m']=.05
            elif mode=='duplicate':cuts[-1]=copy.deepcopy(cuts[0])
            elif mode=='missing':cuts.pop()
            else:cuts[0]['plan_rect_m']=[1.2,21.25,2.5,22.15]
            with self.subTest(mode=mode),self.assertRaises(ValueError):geo.cut_public_floor(floor_source('PublicFloor_00'),cuts)
    def test_wrong_floor_owner_material_height_or_footprint_refuses(self):
        for key,value in [('owner','shop_model_laundry'),('material','structure'),('top_m',.01),('bottom_m',-.004),('plan_rect_m',[0,0,1,1])]:
            s=floor_source('PublicFloor_00');s[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):geo.cut_public_floor(s)
    def test_every_unrelated_stock_is_exact_and_detached_from_input(self):
        originals=[dict(name='HallFoundation',owner='public',material='structure',vertices=[[0,0,0]],faces=[],other={'x':[1]}),dict(name='PublicFloor_01',owner='public',material='public_floor',plan_rect_m=[0,18.8,9.65,20.3],bottom_m=-.04,top_m=0.)]
        for source in originals:
            result=geo.cut_public_floor(source);self.assertEqual(result,[source]);self.assertIsNot(result[0],source)
    def test_candidate_display_bays_protected_band_and_all_pair_sweeps(self):
        frames=json.loads((ROOT/'game/tests/fixtures/arcade_door_frames.json').read_text(encoding='utf-8'))['frames'];leaf=json.loads((ROOT/'game/data/orison_v2/arcade_door_leaves.json').read_text(encoding='utf-8'));native=NativeGLB(ROOT/'game'/leaf['asset'][6:]);radius=0.
        # Actual native local POSITION streams, not an invented 1m proxy.
        for row in leaf['parts']:
            mesh=native.doc['meshes'][native.doc['nodes'][native.names[row['name']]]['mesh']]
            for primitive in mesh['primitives']:
                accessor=native.doc['accessors'][primitive['attributes']['POSITION']];view=native.doc['bufferViews'][accessor['bufferView']];import struct
                at=view.get('byteOffset',0)+accessor.get('byteOffset',0);stride=view.get('byteStride',12)
                for i in range(accessor['count']):
                    x,y,z=struct.unpack_from('<fff',native.binary,at+i*stride);radius=max(radius,math.hypot(x,z))
        origin=[1.18,38.6]
        for hatch in self.output['stocks']:
            shop=next(s for s in self.plaza['shops']if s['id']==hatch['owner']);r=hatch['plan_rect_m'];along=[r[0],r[2]]if shop['front']=='north'else[r[1],r[3]];interval=shop['frontage']['display_clear_interval_m'];self.assertGreaterEqual(along[0],interval[0]);self.assertLessEqual(along[1],interval[1])
            f=next(f for f in frames if f['cell']==hatch['owner']and f['frame_kind']=='front_pair');T=f['frame_transform'];hinges=[[T[0][3],T[2][3]],[T[0][3]+T[0][0]*2,T[2][3]+T[2][0]*2]]
            for h in hinges:
                u,v=h[0]-origin[0],h[1]-origin[1];du=max(r[0]-u,0,u-r[2]);dv=max(r[1]-v,0,v-r[3]);self.assertGreater(math.hypot(du,dv)-radius,.27)
        self.assertAlmostEqual(14.94-10.7,4.24)
        self.assertTrue(all(not overlap(s['plan_rect_m'],[10.7,0,14.94,18.8])for s in self.output['stocks']))
    def test_all_canonical_native_and_raw_apparatus_xz_bounds_are_disjoint(self):
        # Re-read actual source geometry/targets: do not turn the earlier private
        # intake or canonical metadata's ideal bounds into runtime proof.
        doc=json.loads((ROOT/'art/data/arcade_plaza/retained_equipment_placements.json').read_text(encoding='utf-8'));cache={f['name']:NativeGLB(ROOT/f['asset'])for f in doc['families']};import struct
        rectangles=[]
        for row in doc['projection']['native_entries']:
            n=cache[row['family']];mesh=n.doc['meshes'][n.doc['nodes'][n.names[row['part']]]['mesh']];T=row['target_transform'];points=[]
            for p in mesh['primitives']:
                a=n.doc['accessors'][p['attributes']['POSITION']];v=n.doc['bufferViews'][a['bufferView']];at=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12)
                for i in range(a['count']):
                    q=struct.unpack_from('<fff',n.binary,at+i*stride);points.append([sum(T[k][j]*q[j]for j in range(3))+T[k][3]for k in(0,2)])
            rectangles.append((row['part'],[min(p[0]for p in points)-1.18,min(p[1]for p in points)-38.6,max(p[0]for p in points)-1.18,max(p[1]for p in points)-38.6]))
        rectangles += [(r['id'],[r['target_low'][0]-1.18,r['target_low'][2]-38.6,r['target_high'][0]-1.18,r['target_high'][2]-38.6])for r in doc['projection']['raw_entries']]
        for h in self.output['stocks']:
            for identity,rect in rectangles:self.assertFalse(overlap(h['plan_rect_m'],rect),(h['name'],identity))


class NamedCutGuards(unittest.TestCase):
    def test_receiver_and_surround_keep_original_top_chart(self):
        origin=[1.18,-38.6,0.]
        for floor,rect in geo.FLOOR_RECTS.items():
            anchors=[math.floor(origin[0]+rect[0]),math.floor(origin[1]-rect[3])]
            pieces=geo.cut_public_floor(floor_source(floor))
            for piece in pieces:
                for u,v,h in piece['vertices']:
                    world=[origin[0]+u,origin[1]-v,h]
                    self.assertEqual(geo.public_top_uv(floor,world,origin),[world[0]-anchors[0],world[1]-anchors[1]])

    def test_changed_named_cut_refused(self):
        import copy
        cuts=copy.deepcopy(geo._cuts())
        cuts[0]['plan_rect_m'][0]+=.01
        with self.assertRaisesRegex(ValueError,'named hatch receiver placement'):
            geo.cut_public_floor(dict(name='PublicFloor_02',owner='public',material='public_floor',plan_rect_m=[0,20.3,25.64,22.3],bottom_m=-.04,top_m=0),cuts)

if __name__=='__main__':unittest.main()
