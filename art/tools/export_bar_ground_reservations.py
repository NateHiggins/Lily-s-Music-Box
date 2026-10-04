"""Derive retained Harukiya construction and occupied voids for finite soil.

The original source boxes and registered frame own all dimensions. Air is
explicitly reserved; it is never classified as an exact construction solid.
"""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2]
def read(path):return json.loads((ROOT/path).read_bytes())
layout=read('art/data/building_layout.json');block=read('game/data/orison_v2_blockout.json');street=read('game/data/orison_v2/exterior/street_frame.json')
door=next(row for row in block['doors'] if row['id']=='F01_DOOR_06')
assert abs(door['center'][0])<1e-9
offset=float(door['center'][1])+float(street['source_threshold_z'])
assert abs(offset+1.855)<1e-9
rows=next(f for f in layout['floors'] if f['id']=='F01')['furniture']
pattern=r'^retail_bar_(lob_floor|tread\d+|vest_floor|floor|ceil\d+|threshold|shaft_[es]|wall_(e_n|e_s|e_lint|e_deep|w|s|n))$'
selected=[row for row in rows if re.match(pattern,row['id'])]
assert len([row for row in selected if re.match(r'retail_bar_tread\d+$',row['id'])])==15
def bounds(row):
 x0,y0,x1,y1=row['rect'];return [-x1,float(row['z0']),y0+offset,-x0,float(row['z0'])+float(row['h']),y1+offset]
solids=[{'owner':'RetainedBarGeometry/'+row['id'],'id':row['id'],'bounds':bounds(row),'kind':'authored_original_box'} for row in selected]
occupied=[]
for row in selected:
 if row['id'] in ['retail_bar_floor','retail_bar_vest_floor','retail_bar_threshold'] or re.match(r'retail_bar_tread\d+$',row['id']):
  b=bounds(row);b[4]=0.
  occupied.append({'owner':'RetainedBarGeometry/'+row['id']+'/ConstructionAndAir','bounds':b,'kind':'retained_bar_construction_and_occupied_air'})
foundation=read('art/blender/city_foundations_construction.json')
def overlaps(a,b):return all(min(a[i+3],b[i+3])-max(a[i],b[i])>2e-5 for i in range(3))
conflicts=[(a['id'],b['owner']) for a in foundation['components'] for b in occupied if overlaps(a['bounds'],b['bounds'])]
assert not conflicts,conflicts
sources=['art/data/building_layout.json','game/data/orison_v2_blockout.json','game/data/orison_v2/exterior/street_frame.json','art/tools/export_bar_ground_reservations.py','game/assets/building/floor_01_cells/shop_bar.gltf','game/assets/building/floor_01_cells/shop_bar.bin']
def digest(path):
 data=(ROOT/path).read_bytes();return hashlib.sha256(data if Path(path).suffix=='.bin' else data.replace(b'\r\n',b'\n')).hexdigest()
result={'evidence_class':'INERT','source_records':selected,'registration':{'flip_x':True,'z_offset_m':offset},'retained_solids':solids,'reservations':occupied,'city_foundation_conflicts':conflicts,'bindings':{p:digest(p) for p in sources},'note':'Original retained bar construction and occupied-air exclusion only. No new building service, structural-capacity or drainage claim.'}
path=ROOT/'art/data/orison_ground/bar_reservations.json';path.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('BAR GROUND:',len(solids),'retained construction boxes;',len(occupied),'occupied reservations; zero city-foundation conflicts')
