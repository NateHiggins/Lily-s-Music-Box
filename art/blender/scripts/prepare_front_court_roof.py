"""Freeze the retained roof bay and the nearest source masonry on each side."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
LAYOUT=ROOT/'game/data/orison_v2_blockout.json'
layout=json.loads(LAYOUT.read_bytes())
levels={r['id']:r['y'] for r in layout['levels']}
deck=next(r for r in layout['spaces'] if r['id']=='ROOF_DECK_SOUTH')
reach=layout['dimensions']['outer_wall']-layout['dimensions']['partition_wall']/2
z0,z1=deck['rect'][1],deck['rect'][3]
beams=[]
for z in [z0+.35,(z0+z1)/2,z1-.35]:
    sides={-1:[],1:[]}
    for room in layout['spaces']:
        if room['level']!='F06' or room.get('open_shell'):continue
        x0,a,x1,b=room['rect']
        if not a<z<b:continue
        walls=room.get('wall_sides',['south','north','west','east'])
        if x1<0 and 'east' in walls:sides[-1].append((x1,room['id']))
        if x0>0 and 'west' in walls:sides[1].append((x0,room['id']))
    left=max(sides[-1]);right=min(sides[1])
    beams.append({'z':round(z,6),'left':round(left[0]+reach,6),
                  'right':round(right[0]-reach,6),'wall_owners':[left[1],right[1]]})
assert [(r['left'],r['right']) for r in beams]==[(-5.32,9.22),(-5.32,8.02),(-5.32,8.02)]
bindings=['game/data/orison_v2_blockout.json','game/scripts/generated/v2_exterior_masonry.gd',
          'game/data/runtime_material_sets.json','art/data/material_catalog.json']
plan={'schema':'orison.front-court-roof.v1','evidence_class':'INERT','classification':'ADAPTATION',
      'roof_underside':levels['ROOF']-layout['dimensions']['slab_thickness'],
      'girder_depth':.55,'girder_width':.30,'web_thickness':.016,'flange_thickness':.022,
      'bracket_projection':.40,'bracket_width':.50,'bracket_height':.86,
      'beams':beams,'bindings':{p:hashlib.sha256((ROOT/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in bindings},
      'limits':'Geometric support/finish fit only; retained roof bounds, thickness, walking surfaces, apertures and collision owners remain. No structural capacity or whole-building acceptance.'}
out=ROOT/'art/data/front_court_roof/source_fit.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT COURT ROOF: three source-derived spans',[(r['left'],r['right'],r['z']) for r in beams])
