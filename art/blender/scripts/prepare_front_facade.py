"""Fit original entrance vocabulary to the current single-owner V2 envelope."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
def digest(p):return hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes())
original=json.loads((ROOT/'art/data/building_layout.json').read_bytes())
floor=next(f for f in original['floors'] if f['id']=='F01')
door=next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')
assert door['hinge']=='left' and door['yaw']==0 and door['swing']=='out'
reach=layout['dimensions']['outer_wall']-layout['dimensions']['partition_wall']/2
front_z=door['center'][1]-reach
levels={l['id']:l['y'] for l in layout['levels']};edges=[]
for level in ['F01','F02','F03','F04','F05','F06']:
    rooms=[r for r in layout['spaces'] if r['level']==level and not r.get('open_shell')]
    blockers=[r['rect'] for r in rooms]+[r['rect'] for r in layout['risers']]
    for room in rooms:
        if 'south' not in room.get('wall_sides',['south','north','west','east']):continue
        x0,z0,x1,z1=room['rect']
        if z0>-8:continue
        stations=sorted({x0,x1}|{v for r in blockers for v in [r[0],r[2]] if x0<v<x1})
        for a,b in zip(stations,stations[1:]):
            x=(a+b)/2
            if any(r[0]-.001<x<r[2]+.001 and r[1]-.001<z0-layout['dimensions']['partition_wall']/2-.01<r[3]+.001 for r in blockers):continue
            if any(r[0]-.001<x<r[2]+.001 and r[1]-.001<z0-2*reach-.01<r[3]+.001 for r in blockers):continue
            cuts=[(a,b)]
            if level=='F01':
                for d in layout['doors']:
                    if d['level']!=level or room['id'] not in d['connects'] or abs(d['center'][1]-z0)>.001:continue
                    lo=d['center'][0]-d['width']/2-.02;hi=d['center'][0]+d['width']/2+.02
                    cuts=[p for c,e in cuts for p in [(c,min(e,lo)),(max(c,hi),e)] if p[1]-p[0]>1e-6]
            edges.extend({'owner':room['id'],'level':level,'x0':a,'x1':b,'front_z':z0-reach,'y':levels[level]} for a,b in cuts)
sources=['art/data/building_layout.json','art/data/gen_layout.py','art/blender/scripts/build_orison.py',
         'game/data/orison_v2_blockout.json','game/data/orison_v2/world_connection.json',
         'game/scripts/props/landmark_entry_door.gd','game/scripts/props/entrance_marquee_dress.gd',
         'game/assets/building/floor_01.gltf','art/data/material_catalog.json','art/textures/catalog_mapping.json',
         'game/data/runtime_material_sets.json']
sources=[p for p in sources if (ROOT/p).is_file()]
blade=next(r for r in floor['markers'] if r['id']=='F01_NEON_BLADE')
assert blade['pos'][0]>0
blade_seats=[]
for level in ['F02','F03']:
    hosts=[r for r in layout['spaces'] if r['level']==level and not r.get('open_shell')
           and 'south' in r.get('wall_sides',['south','north','west','east'])
           and r['rect'][2]<-door['width']/2 and r['rect'][1]<=door['center'][1]]
    host=max(hosts,key=lambda r:r['rect'][2])
    blade_seats.append({'owner':host['id'],'x':host['rect'][2]-.25,'front_z':host['rect'][1]-reach})
assert abs(blade_seats[0]['front_z']-blade_seats[1]['front_z'])<1e-6
assert abs(blade_seats[0]['x']-blade_seats[1]['x'])<1e-6
plan={'evidence_class':'INERT','classification':'ADAPTATION','door':door,'facade_root_z':front_z,
      'original_entrance':[r for r in floor['furniture'] if r.get('id','').startswith('entry_')],
      'original_markers':[r for r in floor['markers'] if r['id'] in ['F01_DOOR_06','F01_NEON_BLADE']],
      'front_edges':edges,'front_windows':[dict(r,y=levels[r['level']],front_z=r['center'][1]-reach) for r in layout['windows'] if r['axis']=='x' and r['center'][1]<-8],
      'canopy_support':'pier-mounted knee frames; original upper anchors have no host at V2 vestibule',
      'blade_root_position':[blade_seats[0]['x'],blade['pos'][2],blade_seats[0]['front_z']],
      'blade_seats':blade_seats,
      'bindings':{p:digest(ROOT/p) for p in sources}}
out=ROOT/'art/data/front_facade/source_fit.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(plan,indent=2)+'\n',newline='\n')
print('Front facade:',len(edges),'exposed source edges;',len(plan['front_windows']),'retained windows; single original door and blade')
