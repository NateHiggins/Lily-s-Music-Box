"""Whole-category upper furniture batch, extracted without Blender or Godot."""
import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='c8908f2'
LAYOUT='game/data/orison_v2_blockout.json'
FURNITURE='game/data/orison_v2/domestic_furniture.json'
PROBES='game/tests/data/v2_upper_floor_probes.json'
PI=math.pi
UNITS=['5A','5B','5C','6A','6B','6C']

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def baseline(path):return json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8'))
def write(path,value,compact=False):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes((json.dumps(value,**({'separators':(',',':')} if compact else {'indent':2}))+'\n').encode('utf-8'))

def placements():
    rows=[]
    def add(identity,room,xz,yaw,stance):rows.append((identity,room,[xz[0],0,xz[1]],yaw,stance))
    for u in UNITS:
        prefix='F0'+u[0]+'_'+u[1]+'_'
        if u[1]=='A':
            add(u+'_bed0',prefix+'BED',[-14.3,-10.8],0,[-13.1,-10.3])
            add(u+'_bed0_ns',prefix+'BED',[-13.15,-11.5],0,[-12.45,-11.5])
            add(u+'_w0_wardrobe',prefix+'BED',[-11.65,-8.1],PI/2,[-13.0,-8.1])
            tx,tz=-12.0,-2.1
        elif u[1]=='B':
            add(u+'_abed',prefix+'ALCOVE',[-14.3,10.2],0,[-13.15,9.8])
            add(u+'_abed_ns',prefix+'ALCOVE',[-13.15,10.8],0,[-12.45,10.8])
            add(u+'_aw_wardrobe',prefix+'ALCOVE',[-11.65,7.4],PI/2,[-13.0,7.4])
            tx,tz=-11.1,3.2
        else:
            for i,dx in [(0,0),(1,3.3)]:
                room=prefix+'BED'+str(i+1)
                add(u+'_bed'+str(i),room,[1.4+dx,10.5],0,[2.5+dx,9.0])
                add(u+'_bed'+str(i)+'_ns',room,[3.3+dx,11.15],0,[2.6+dx,11.05])
                # Shared clothing wall keeps both small bedrooms accessible
                # with wardrobe leaves open. No additional resident implied.
                add(u+'_w'+str(i)+'_wardrobe',prefix+'STUDIO',[-4.7+i*1.65,4.3],PI,[-4.7+i*1.65,5.65])
            tx,tz=-1.5,9.6
        room=prefix+'MAIN'
        if u[1]=='C':
            add(u+'_din_t',room,[tx,tz],0,[tx+1.05,tz])
            add(u+'_din_dc1',room,[tx,tz-1.05],PI,[tx+.85,tz-1.05])
            add(u+'_din_dc2',room,[tx,tz+1.05],0,[tx+.85,tz+1.05])
            continue
        add(u+'_din_t',room,[tx,tz],0,[tx,tz+1.0 if u[1]=='A' else tz+1.05 if u[1]=='C' else tz-1.05])
        for i,dx,yaw in [(1,-1,-PI/2),(2,1,PI/2)]:
            add(u+'_din_dc'+str(i),room,[tx+dx,tz],yaw,[tx+dx,tz+(.75 if u[1]!='C' else -.8)])
    add('5A_plantable','F05_A_MAIN',[-12.5,-4.6],0,[-11.0,-4.6])
    add('5A_stool','F05_A_MAIN',[-12.5,-3.55],0,[-13.2,-3.55])
    add('5A_planshelf','F05_A_STUDY',[-9.7,-11.95],PI,[-9.7,-11.0])
    add('5A_modtable','F05_A_STUDY',[-10.65,-10.7],0,[-9.7,-10.2])
    add('6A_deskwall','F06_A_STUDY',[-9.75,-11.85],PI/2,[-10.6,-10.8])
    add('6A_deskchair','F06_A_STUDY',[-9.1,-10.8],0,[-9.1,-10.0])
    add('6C_sofa','F06_C_MAIN',[-5.05,9.3],-PI/2,[-4.15,10.5])
    add('6C_cof','F06_C_MAIN',[-3.7,9.3],PI/2,[-3.7,10.5])
    return rows

def extract():
    old=module('design/astra/work/v2_apartment_batches_01/build.py','upper_furniture_extract')
    source=load('game/data/building_layout.json')
    records={r['id']:r for f in source['floors'] for r in f.get('furniture',[])}
    tree=ast.parse((ROOT/old.SOURCE).read_text(encoding='utf-8'));nodes=[]
    kinds={'bed','nightstand','wardrobe','chair','table_round','table_rect','plantable','shelf','sofa','coffee'}
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=='MeshBuf':
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in old.METHODS];nodes.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=='Frame':nodes.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {'asm_'+k for k in kinds}|{'case_wood','hash_str','_jit'}:nodes.append(node)
    ns={'math':math,'zlib':zlib};exec(compile(ast.Module(body=nodes,type_ignores=[]),old.SOURCE,'exec'),ns)
    # Preserve Sacha's three authored desk members as one support assembly,
    # with open leg space instead of a solid generic desk block.
    members=[records[k] for k in ['6A_deskwall','6A_dwleg_s','6A_dwleg_n']]
    def desk(frame,spec):
        for r in members:
            x0,y0,x1,y1=r['rect']
            frame.box(r['mat'],x0+12.85,y0+4.95,r['z0'],x1+12.85,y1+4.95,r['z0']+r['h'])
    ns['asm_desk']=desk;records['6A_deskwall']=dict(id='6A_deskwall',asm='desk')
    additions=[old.furniture_record(p[0],records,ns) for p in placements()]
    for r in additions:
        if r['kind']=='plantable':
            r['kind']='table_rect';r['source_component']={'assembly':r['id'],'component':'complete_drafting_table'}
        if r['id']=='6A_deskwall':
            r['source_component']={'assembly':'6A_deskwall','members':[m['id'] for m in members]}
            r['collision_boxes']=[[[m['rect'][0]+12.85,m['z0'],-m['rect'][3]-4.95],
                                   [m['rect'][2]+12.85,m['z0']+m['h'],-m['rect'][1]-4.95]] for m in members]
        if r['kind']=='coffee':
            bottom=r['bounds'][0][1]
            for s in r['surfaces']:
                for i in range(1,len(s['vertices']),3):s['vertices'][i]-=bottom
            r['bounds'][1][1]-=bottom;r['bounds'][0][1]=0
    return additions

def make():
    layout=baseline(LAYOUT);furniture=baseline(FURNITURE);new=extract();targets=[]
    for identity,room,position,yaw,stance in placements():
        level=room[:3]
        layout['anchors'].append(dict(id=identity,level=level,space=room,position=position,yaw=yaw,kind='furniture'))
        layout['anchors'].append(dict(id=identity+'_STANCE',level=level,space=room,position=[stance[0],0,stance[1]],
                                      yaw=math.atan2(-(position[0]-stance[0]),-(position[2]-stance[1])),kind='clearance'))
        targets.append(dict(id=identity,level=level,point=stance))
    furniture['furniture']+=new
    return {LAYOUT:layout,FURNITURE:furniture},new,targets

def validate(outputs,new,targets):
    fixtures=module('design/astra/work/v2_upper_fixtures_01/build.py','upper_furniture_fixture_check')
    _,old,old_targets=fixtures.make()
    all_outputs=dict(outputs);all_outputs[fixtures.FITTINGS]=load(fixtures.FITTINGS)
    proof=fixtures.validate(all_outputs,old+new,old_targets+targets)
    geo=module('design/astra/work/v2_apartment_doors_batch_01/check.py','upper_furniture_leaf')
    anchors={a['id']:a for a in outputs[LAYOUT]['anchors']};spaces={s['id']:s for s in outputs[LAYOUT]['spaces']}
    open_leaves=[];poses=0
    for record in new:
        if record['kind']!='wardrobe':continue
        a=anchors[record['id']];room=spaces[a['space']]['rect'];stance=next(t['point'] for t in targets if t['id']==record['id'])
        for side in [-1,1]:
            for n in range(185):
                local=geo.rect_polygon([0 if side<0 else -.603,-.07,.603 if side<0 else 0,.015])
                local=[geo.rotate(p,math.radians(n*.5*-side)) for p in local]
                local=[[p[0]+side*.615,p[1]-.305] for p in local]
                poly=[[a['position'][0]+p[0],a['position'][2]+p[1]] for p in [geo.rotate(p,a['yaw']) for p in local]]
                assert all(room[0]+.07<=p[0]<=room[2]-.07 and room[1]+.07<=p[1]<=room[3]-.07 for p in poly),('wardrobe motion outside room',record['id'])
                for other in proof['footprints']:
                    if other['level']!=a['level'] or other['id']==record['id']:continue
                    assert not geo.overlaps(poly,geo.rect_polygon(other['rect'])),('wardrobe motion hits furniture',record['id'],other['id'])
                assert geo.distance(stance,poly)>=.38,('wardrobe motion hits stance',record['id'])
                poses+=1
                if n==184:open_leaves.append((record['id']+'_leaf_'+str(side),a['level'],[min(p[0] for p in poly),min(p[1] for p in poly),max(p[0] for p in poly),max(p[1] for p in poly)]))
    routes=module('design/astra/work/v2_upper_floors_01/routes.py','upper_furniture_open_routes')
    solids=[(p['id'],p['level'],p['rect']) for p in proof['footprints']]+open_leaves
    proof['routes']=routes.check(outputs[LAYOUT],load(fixtures.PROGRAM),solids,old_targets+targets)
    proof['wardrobe_leaf_poses']=poses
    return proof

def run(apply=False):
    outputs,new,targets=make();proof=validate(outputs,new,targets)
    for path,key in [(LAYOUT,'anchors'),(FURNITURE,'furniture')]:
        current=load(path);original=baseline(path)
        if apply:
            own={r['id'] for r in outputs[path][key]}-{r['id'] for r in original[key]}
            current[key]=[r for r in current[key] if r['id'] not in own]
            assert current==original,('unexpected concurrent source',path)
        else:assert current==outputs[path],('generation differs',path)
    if apply:
        write(ROOT/FURNITURE,outputs[FURNITURE],True)
        text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode('utf-8')
        start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
        rows=outputs[LAYOUT]['anchors'][len(baseline(LAYOUT)['anchors']):]
        (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  '+text[end:]).encode('utf-8'))
        probes=dict(floors=[dict(level=f['level'],rooms=[dict(id=p['room'],point=p['points'][-1]) for p in f['room_routes']]) for f in proof['routes']['floors']])
        write(ROOT/PROBES,probes)
    write(OUT/'routes.json',proof.pop('routes'),True)
    proof.update(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,new_furniture=len(new),new_anchors=2*len(new),
                 counts={kind:sum(r['kind']==kind for r in new) for kind in sorted({r['kind'] for r in new})},
                 targets=targets,total_furniture=len(outputs[FURNITURE]['furniture']),triangles=sum(len(s['vertices'])//9 for r in new for s in r['surfaces']))
    write(OUT/'checks.json',proof)
    inventory=load('design/astra/work/v2_upper_fixtures_01/current_inventory.json')
    for row in inventory['units']:
        if row['unit'] not in UNITS:continue
        row['furniture'] += [r['id'] for r in new if r['id'].startswith(row['unit']+'_')]
        row['status']='DOMESTIC_FURNITURE_SOURCE_RUNTIME_PENDING'
        row['pending']=['remaining resident-specific props and work equipment','kitchen storage and preparation surfaces',
                        'household accessories','installed heat emitters','room lighting','resident migration',
                        'physical utilities and runtime/visual proof']
    inventory['totals']['furniture']=len(outputs[FURNITURE]['furniture'])
    inventory.update(batch='v2_upper_furniture_01',limits='Six upper homes now have sleep, clothing and meal furniture plus selected authored work/living pieces. Props, cabinets, accessories, lighting, heat, resident consumers and runtime proof remain pending. Eight other numbered residential programs and B1 housing remain separate.')
    write(OUT/'current_inventory.json',inventory)
    probes=dict(furniture=[dict(id=r['id'],kind=r['kind'],bounds=r['bounds'],
                               materials=[s['material'] for s in r['surfaces']],mechanism=r.get('mechanism',{})) for r in new])
    if apply:write(ROOT/'game/tests/data/v2_upper_furniture_probes.json',probes)
    print(json.dumps({k:v for k,v in proof.items() if k in ['status','new_furniture','new_anchors','counts','triangles','wardrobe_leaf_poses']}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
