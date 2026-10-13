"""Apply the owner-requested central frontage restoration to the V2 authority.
Adds spaces, apertures and windows; relocates the two retained lobby windows.
"""
from pathlib import Path
import json,copy
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'game/data/orison_v2_blockout.json'

def additions():
 result={k:[] for k in ['spaces','openings','windows']}
 def room(level,name,rect,sides,purpose,extensions=None):
  r=dict(id=level+'_FRONT_'+name,level=level,rect=rect,wall_sides=sides,**{'class':'public'},purpose=purpose)
  if extensions:r['wall_extensions']=extensions
  result['spaces'].append(r);return r['id']
 def opening(level,name,center,axis,width,a,b):
  result['openings'].append(dict(id=level+'_FRONT_'+name,level=level,center=center,axis=axis,width=width,height=2.45,connects=[a,b]))
 def windows(level,owner,centers,width=1.6):
  next(r for r in result['spaces'] if r['id']==owner)['exterior_sides']=['south']
  for n,x in enumerate(centers):result['windows'].append(dict(id=owner+'_WINDOW_'+str(n+1),level=level,space=owner,center=[x,-12.35],axis='x',width=width,height=1.75,sill=.80))
 for n in range(2,7):
  lv=f'F{n:02d}'
  gallery=room(lv,'GALLERY',[-5.6,-12.35,8.3,-7.3],['south'],
   'restored street-facing common gallery within the original continuous building mass',
   [{'side':'east','start':-12.35,'end':-9.25}])
  left=-2.2 if n<5 else -5.6
  hall=room(lv,'HALL',[left,-7.3,8.3,-3.85],[],
   'restored circulation connecting the front gallery to the existing east hall',
   [{'side':'north','start':-5.6,'end':-2.2}] if n>=5 else None)
  bay=room(lv,'SERVICE_RETURN',[8.3,-12.35,9.5,-9.25],['south'],
   'street-front return at the existing service spine')
  opening(lv,'HALL_ACCESS',[6.8,-3.85],'x',1.6,lv+'_EAST_HALL',hall)
  opening(lv,'SERVICE_ACCESS',[8.9,-9.25],'x',.96,lv+'_SERVICE_HALL_SOUTH',bay)
  opening(lv,'GALLERY_SERVICE',[8.3,-10.75],'z',1.1,gallery,bay)
  if n<5:opening(lv,'WEST_ACCESS',[-3.8,-7.3],'x',1.5,lv+'_SOUTHWEST_HALL',gallery)
  windows(lv,gallery,[-3.7,0,3.7,6.8]);windows(lv,bay,[8.9],.60)
 lv='F01'
 left=room(lv,'WEST_BAY',[-5.4,-12.35,-2.4,-9.25],['south'],'restored glazed lobby waiting bay',
  [{'side':'east','start':-12.35,'end':-11.65}])
 right=room(lv,'EAST_BAY',[2.4,-12.35,5.4,-9.25],['south','east'],'restored street-facing lobby bay',
  [{'side':'west','start':-12.35,'end':-11.65}])
 work=room(lv,'WORKROOM',[5.4,-12.35,8.3,-8.3],['south'],'restored front maintenance workroom',
  [{'side':'east','start':-12.35,'end':-9.25}])
 bay=room(lv,'SERVICE_RETURN',[8.3,-12.35,9.5,-9.25],['south'],'restored street-front service return')
 link=room(lv,'STORE_ALCOVE',[5.4,-4.6,8.3,-3.85],['north'],'shallow storage recess behind the retained staff restroom')
 opening(lv,'WEST_LOBBY_ACCESS',[-4.85,-9.25],'x',.80,'F01_LOBBY',left)
 opening(lv,'EAST_LOBBY_ACCESS',[4.85,-9.25],'x',.80,'F01_LOBBY',right)
 opening(lv,'WORKROOM_ACCESS',[5.4,-10.7],'z',1.2,right,work)
 opening(lv,'WORKROOM_SERVICE',[8.3,-10.7],'z',1.2,work,bay)
 opening(lv,'SERVICE_ACCESS',[8.9,-9.25],'x',.96,'F01_SERVICE_HALL',bay)
 opening(lv,'STORE_ACCESS',[5.4,-4.22],'z',.70,'F01_LOBBY',link)
 for owner in [left,right]:next(r for r in result['spaces'] if r['id']==owner)['exterior_sides']=['south']
 for owner,x,w in [(work,6.8,1.6),(bay,8.9,.60)]:windows(lv,owner,[x],w)
 return result

def relocate_windows(data):
 for suffix,owner in [('W','WEST_BAY'),('E','EAST_BAY')]:
  w=next(r for r in data['windows'] if r['id']=='F01_LOBBY_WINDOW_'+suffix)
  w['space']='F01_FRONT_'+owner;w['center'][1]=-12.35

def main():
 raw=PATH.read_text(encoding='utf-8');data=json.loads(raw);new=additions()
 if any(r['id']=='F02_FRONT_GALLERY' for r in data['spaces']):raise SystemExit('Restoration already applied')
 before=copy.deepcopy(data)
 # Preserve original bytes and record formatting outside the three insertions.
 for key,records in new.items():
  marker='"'+key+'": ['
  assert raw.count(marker)==1,key
  insert='\n'+''.join('    '+json.dumps(r,separators=(',',':'))+',\n' for r in records)
  raw=raw.replace(marker,marker+insert,1)
 parsed=json.loads(raw)
 for key in new:assert parsed[key][len(new[key]):]==before[key]
 for key in before:
  if key not in new:assert parsed[key]==before[key]
 relocated=copy.deepcopy(parsed);relocate_windows(relocated)
 for old,new_window in zip(parsed['windows'],relocated['windows']):
  if old!=new_window:
   old_line=next(line for line in raw.splitlines() if '"id":"'+old['id']+'"' in line)
   raw=raw.replace(old_line,'    '+json.dumps(new_window,separators=(',',':'))+',')
 PATH.write_text(raw,encoding='utf-8',newline='\n')
 plan=ROOT/'art/data/front_volume_restoration.json'
 plan.write_text(json.dumps(dict(evidence_class='INERT',source='Owner correction: missing central front facade and associated interior; original rectangular mass.',additions=new,relocated_windows=[dict(id='F01_LOBBY_WINDOW_'+s,space='F01_FRONT_'+o,from_z=-9.25,to_z=-12.35,preserved='identity, width, height and sill') for s,o in [('W','WEST_BAY'),('E','EAST_BAY')]]),indent=2)+'\n',encoding='utf-8',newline='\n')
 print({k:len(v) for k,v in new.items()})
if __name__=='__main__':main()
