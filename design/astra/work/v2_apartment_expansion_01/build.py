"""Build 3A/4A rooms and domestic categories from named, preserved sources.

Pure source generation. No engine or Blender execution.
"""
import argparse
import ast
import copy
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE="1aa22cc"
LAYOUT="game/data/orison_v2_blockout.json"
FURNITURE="game/data/orison_v2/domestic_furniture.json"
FITTINGS="game/data/orison_v2/domestic_fittings.json"
LIGHTING="game/data/orison_v2/room_lighting.json"
REPAIRS={}
for unit,level in [('2A','F02'),('3A','F03')]:
    REPAIRS.update({unit+'_wc':[-6.94,0,5.16],unit+'_wc_STANCE':[-7.0,0,4.35],
                    level+'_'+unit+'_SHOWER_01':[-6.94,0,3.57],level+'_'+unit+'_SHOWER_01_STANCE':[-7.0,0,4.35],
                    level+'_A_BATH_SWITCH':[-6.49,1.12,4.45],level+'_A_BATH_SWITCH_STANCE':[-7.6,0,4.45]})
REPAIRS['4B_wc_STANCE']=[-6.9,0,4.5]
DOOR_WIDTHS={'F02_A_BATH_DOOR':.91,'F03_A_BATH_DOOR':.91}
PAIRS=[("2A","3A","F02_A_","F03_A_","Malcolm Reed"),
       ("2B","4A","F02_B_","F04_A_","Peter Wren")]

def load(path): return json.loads((ROOT/path).read_text(encoding="utf-8"))
def base(path): return json.loads(subprocess.check_output(["git","show",BASE+":"+path],cwd=ROOT))
def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def renamed(value,old,new,old_prefix,new_prefix):
    if isinstance(value,str):
        value=value.replace(old_prefix,new_prefix).replace("F02_"+old,"F0"+new[0]+"_"+new)
        value=value.replace("F02","F0"+new[0]).replace(old+"_",new+"_")
        if value==old:return new
        if new=="4A" and value=="F04_A_ENTRY_DOOR":return "F04_DOOR_02"
        return value
    if isinstance(value,list):return [renamed(v,old,new,old_prefix,new_prefix) for v in value]
    if isinstance(value,dict):return {k:renamed(v,old,new,old_prefix,new_prefix) for k,v in value.items()}
    return value

def build(apply=False):
    old_layout=base(LAYOUT);layout=copy.deepcopy(old_layout)
    old_furniture=base(FURNITURE);furniture=copy.deepcopy(old_furniture)
    fittings=base(FITTINGS);lighting=base(LIGHTING)
    source=load("game/data/building_layout.json")
    records={r["id"]:r for f in source["floors"] for r in f.get("furniture",[])}
    markers={r["id"]:r for f in source["floors"] for r in f.get("markers",[]) if "id" in r}
    extractor=module("design/astra/work/v2_apartment_batches_01/build.py","expansion_extractor")
    tree=ast.parse((ROOT/extractor.SOURCE).read_text(encoding="utf-8"));selected=[]
    names={"asm_bed","asm_nightstand","asm_wardrobe","asm_toilet","asm_table_rect","asm_table_round","asm_chair","case_wood","hash_str","_jit"}
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in extractor.METHODS];selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame":selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in names:selected.append(node)
    ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=selected,type_ignores=[]),extractor.SOURCE,"exec"),ns)
    old_anchors={r["id"]:r for r in old_layout["anchors"]}
    by_furniture={r["id"]:r for r in old_furniture["furniture"]}
    new_furniture=[];new_fittings=[];new_doors=[];new_spaces=[];new_lights=[];programs=[]
    for old,new,prefix,target,resident in PAIRS:
        rename=lambda value:renamed(value,old,new,prefix,target)
        room_ids={r["id"] for r in old_layout["spaces"] if r["id"].startswith(prefix)}
        for r in old_layout["spaces"]:
            if r["id"] not in room_ids:continue
            record=rename(r)
            if r["id"]==prefix+"MAIN":record["purpose"]=resident+ (" living, meals and propagation work" if new=="3A" else " living, meals and legal correspondence")
            elif "fabric" in record.get("purpose",""):record["purpose"]="private bed and bath distribution with document storage"
            layout["spaces"].append(record);new_spaces.append(record["id"])
        for table in ["doors","openings","windows"]:
            for r in old_layout[table]:
                if r.get("space") not in room_ids and not any(s in room_ids for s in r.get("connects",[])):continue
                record=rename(r);layout[table].append(record)
                if table=="doors":new_doors.append(record["id"])
        # Full per-room fixture/switch circuits, with no inherited case device.
        selected_lights=[r for r in base(LIGHTING)["fixtures"] if r["room"] in room_ids and r["kind"]!="lamp"]
        selected_switches=[r for r in base(LIGHTING)["switches"] if r["room"] in room_ids]
        for key,rows in [("fixtures",selected_lights),("switches",selected_switches)]:
            lighting[key]+=[rename(r) for r in rows]
            for r in rows:
                layout["anchors"].append(rename(old_anchors[r["id"]]))
                if key=="fixtures":new_lights.append(rename(r["id"]))
                elif r["id"]+"_STANCE" in old_anchors:layout["anchors"].append(rename(old_anchors[r["id"]+"_STANCE"]))
        for r in base(FITTINGS)["fittings"]:
            if r["unit"]!=old:continue
            identity=rename(r["id"])
            record=extractor.fitting_record(identity,markers)
            fittings["fittings"].append(record);new_fittings.append(identity)
            layout["anchors"].append(rename(old_anchors[r["id"]]))
            if r["id"]+"_STANCE" in old_anchors:layout["anchors"].append(rename(old_anchors[r["id"]+"_STANCE"]))
        # Household-specific authored beds, wood and meal furniture.
        selection=[(old+"_wc",new+"_wc"),(old+"_bed0" if old=="2A" else "2B_abed",new+"_bed0"),
                   (old+"_w0_wardrobe" if old=="2A" else "2B_aw_wardrobe",new+"_w0_wardrobe"),
                   (old+"_din_t",new+"_din_t"),(old+"_din_dc1",new+"_din_dc1"),(old+"_din_dc2",new+"_din_dc2")]
        for template,identity in selection:
            record=extractor.furniture_record(identity,records,ns)
            anchor=rename(old_anchors[template]);anchor["id"]=identity
            furniture["furniture"].append(record);new_furniture.append(identity);layout["anchors"].append(anchor)
            stance=old_anchors.get(template+"_STANCE")
            if stance:
                stance=rename(stance);stance["id"]=identity+"_STANCE";layout["anchors"].append(stance)
        for suffix in ["sink_support","prep_cabinet","k_wall_cupboard"]:
            identity=old+"_"+suffix;record=rename(by_furniture[identity])
            furniture["furniture"].append(record);new_furniture.append(record["id"])
            layout["anchors"].append(rename(old_anchors[identity]))
            if identity+"_STANCE" in old_anchors:layout["anchors"].append(rename(old_anchors[identity+"_STANCE"]))
        # Nightstands retain each household's original source object.
        identity=new+"_bed0_ns";record=extractor.furniture_record(identity,records,ns)
        anchor=rename(old_anchors["2A_bed0_ns"]) if new=="3A" else dict(id=identity,level="F04",space="F04_A_BED",position=[11.85,0,-11.5],yaw=math.pi,kind="furniture")
        furniture["furniture"].append(record);new_furniture.append(identity);layout["anchors"].append(anchor)
        identity=new+("_potting_bench" if new=="3A" else "_writing_table")
        record=copy.deepcopy(by_furniture["2B_fabric_worktable"]);record["id"]=identity
        anchor=dict(id=identity,level="F0"+new[0],space=target+"MAIN",position=[-15.25,0,0] if new=="3A" else [12.65,0,-.15],yaw=-math.pi/2 if new=="3A" else 0,kind="furniture")
        furniture["furniture"].append(record);new_furniture.append(identity);layout["anchors"].append(anchor)
        layout["anchors"].append(dict(id=identity+"_STANCE",level=anchor["level"],space=anchor["space"],position=[-14.35,0,0] if new=="3A" else [12.65,0,-1.05],yaw=math.pi/2 if new=="3A" else math.pi,kind="clearance"))
        programs.append(dict(unit=new,resident=resident,rooms=[i for i in new_spaces if i.startswith(target)],status="SOURCE_DOMESTIC_CORE_RUNTIME_PENDING",remaining="personal objects, domestic radio, heating/emitter and actual resident navigation; runtime and visual checks"))
    # F03 western approach joins the actual public core, which owns this wall.
    hallway=copy.deepcopy(next(r for r in old_layout["spaces"] if r["id"]=="F02_WEST_HALL"))
    hallway.update(id="F03_WEST_HALL",level="F03",purpose="public approach to Malcolm Reed at 3A")
    layout["spaces"].append(hallway)
    layout["openings"].append(dict(id="F03_CORE_WEST_OPENING",level="F03",center=[-2.2,0],width=1.2,height=2.4,axis="z",connects=["F03_PUBLIC_CORE","F03_WEST_HALL"],shared_wall_owner="F03_PUBLIC_CORE"))
    # Split the old continuous F04 service hallway around the public crossing.
    for r in layout["spaces"]:
        if r["id"]=="F04_SERVICE_HALL":r["rect"]=[7.1,-2.65,9.5,9.25]
    for identity in ["F02_EAST_HALL","F02_SERVICE_CROSSING","F02_SERVICE_HALL_SOUTH"]:
        r=next(r for r in old_layout["spaces"] if r["id"]==identity)
        r=renamed(r,"2B","4A","F02_B_","F04_A_");r["purpose"]=r["purpose"].replace("2B","4A")
        layout["spaces"].append(r)
    for r in old_layout["openings"]:
        if r["id"] in ["F02_CORE_EAST_HALL_OPENING","F02_EAST_CROSSING_OPENING","F02_SERVICE_CROSSING_NORTH","F02_SERVICE_CROSSING_SOUTH"]:
            layout["openings"].append(renamed(r,"2B","4A","F02_B_","F04_A_"))
    outputs={LAYOUT:layout,FURNITURE:furniture,FITTINGS:fittings,LIGHTING:lighting}
    for door in layout['doors']:
        if door['id'] in DOOR_WIDTHS:door['width']=DOOR_WIDTHS[door['id']]
    for anchor in layout['anchors']:
        if anchor['id']=='4A_bed0_STANCE':anchor['position']=[12.15,0,-10.45]
        if anchor['id'] in REPAIRS:anchor['position']=REPAIRS[anchor['id']]
    indexed={a['id']:a for a in layout['anchors']}
    for identity in REPAIRS:
        if not identity.endswith('_STANCE') or identity[:-7] not in indexed:continue
        at=indexed[identity[:-7]]['position'];stance=indexed[identity]['position']
        indexed[identity]['yaw']=math.atan2(-(at[0]-stance[0]),-(at[2]-stance[2]))
    validate_geometry(outputs,new_furniture,new_spaces,new_doors)
    # Allow reruns only against the exact original or this generated record.
    for path,result in outputs.items():
        current=load(path)
        comparison=copy.deepcopy(current)
        if path==LAYOUT:
            for r in comparison['doors']:
                if r['id'] in DOOR_WIDTHS:r['width']=DOOR_WIDTHS[r['id']]
            for a in comparison['anchors']:
                if a['id'] in REPAIRS:
                    a['position']=REPAIRS[a['id']];a['yaw']=indexed[a['id']]['yaw']
            for r in comparison['spaces']:
                if r['id']=='F04_SERVICE_HALL':r['rect']=[7.1,-2.65,9.5,9.25]
        assert current==base(path) or comparison==result,("unexpected concurrent data edit",path)
        if apply:
            if path==LAYOUT:
                text=subprocess.check_output(["git","show",BASE+":"+path],cwd=ROOT).decode()
                for table in ["spaces","doors","openings","windows","anchors"]:
                    original_ids={r['id'] for r in old_layout[table]}
                    additions=[r for r in result[table] if r['id'] not in original_ids]
                    if not additions:continue
                    start=text.index("[",text.index('"'+table+'"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
                    extra=',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in additions)
                    text=text[:end].rstrip()+',\n'+extra+'\n  '+text[end:]
                start=text.rfind('{',0,text.index('"F04_SERVICE_HALL"'))
                record,length=json.JSONDecoder().raw_decode(text[start:])
                record['rect']=[7.1,-2.65,9.5,9.25]
                text=text[:start]+json.dumps(record,separators=(',',':'))+text[start+length:]
                for identity,position in REPAIRS.items():
                    # Restrict replacement to the anchor array; IDs can also
                    # appear as references earlier in the layout.
                    anchor_start=text.index('[',text.index('"anchors"'))
                    start=text.rfind('{',anchor_start,text.index('"'+identity+'"',anchor_start))
                    record,length=json.JSONDecoder().raw_decode(text[start:]);record['position']=position;record['yaw']=indexed[identity]['yaw']
                    text=text[:start]+json.dumps(record,separators=(',',':'))+text[start+length:]
                for identity,width in DOOR_WIDTHS.items():
                    start=text.rfind('{',0,text.index('"'+identity+'"'))
                    record,length=json.JSONDecoder().raw_decode(text[start:]);record['width']=width
                    text=text[:start]+json.dumps(record,separators=(',',':'))+text[start+length:]
                (ROOT/path).write_text(text,encoding="utf-8")
            else:
                encoded=json.dumps(result,separators=(",",":")) if path==FURNITURE else json.dumps(result,indent=2)
                (ROOT/path).write_text(encoded+'\n',encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",base=BASE,programs=programs,rooms_added=len(new_spaces),doors_added=new_doors,furniture_added=new_furniture,fittings_added=new_fittings,fixtures_added=new_lights,
                 limits="Source-only domestic core. Personal dressing, radio/heating, resident migration, full route/use/visual/performance acceptance remain open. Existing furniture/fitting records preserved. Named layout repairs: F04 service-hall partition, 2A/3A bathroom clearance and door widths, and 4B WC stance.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+'\n',encoding="utf-8")
    print(json.dumps({k:receipt[k] for k in ['status','rooms_added','doors_added']},indent=2))
    print("Furniture",len(new_furniture),"fittings",len(new_fittings),"fixtures",len(new_lights))

def validate_geometry(outputs,new_furniture,new_spaces,new_doors):
    layout=outputs[LAYOUT];anchors={r['id']:r for r in layout['anchors']}
    spaces={r['id']:r for r in layout['spaces']}
    for key in ['spaces','doors','openings','windows','anchors']:
        ids=[r['id'] for r in layout[key]];assert len(ids)==len(set(ids)),key
    for r in layout['doors']+layout['openings']:
        assert all(i in spaces for i in r['connects']),r['id']
    for a in layout['spaces']:
        if a.get('open_shell'):continue
        for b in layout['spaces']:
            if a['id']>=b['id'] or a['level']!=b['level'] or b.get('open_shell'):continue
            ar,br=a['rect'],b['rect']
            assert max(0,min(ar[2],br[2])-max(ar[0],br[0]))*max(0,min(ar[3],br[3])-max(ar[1],br[1]))<=.0001,('room overlap',a['id'],b['id'])
    geometry=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','expansion_geometry')
    # Reuse estimates with the candidate fitting manifest, without mutating disk.
    real_load=geometry.load
    geometry.load=lambda path:outputs[path] if path in outputs else real_load(path)
    rows=outputs[FURNITURE]['furniture'];obstacles=geometry.obstacles(layout,rows)
    new_fitting_ids={r['id'] for r in outputs[FITTINGS]['fittings'] if r['unit'] in ['3A','4A']}
    for riser in layout['risers']:
        if not riser.get('solid',True):continue
        r=riser['rect']
        for level in layout['levels']:
            obstacles.append((riser['id'],level['id'],[r[0],riser['from_y']-level['y'],r[1],r[2],riser['to_y']-level['y'],r[3]]))
    wall_geometry=module('design/astra/work/v2_apartment_walls_batch_01/build.py','expansion_walls')
    wall_geometry.PREFIXES=('F03_A_','F04_A_')
    assert not wall_geometry.missing(layout),'missing apartment boundary intervals'
    door_geometry=module('design/astra/work/v2_apartment_doors_batch_01/check.py','expansion_doors')
    swing={i:False for i in new_doors}
    for i in ['F03_A_HALL_DOOR','F03_A_BATH_DOOR','F04_DOOR_02']:swing[i]=True
    for door in layout['doors']:
        if door['id'] not in new_doors:continue
        for step in range(201):
            polygon=door_geometry.leaf_polygon(door,swing[door['id']],100*step/200)
            for other,level,b in obstacles:
                if level==door['level'] and b[1]<door['height'] and b[4]>.02:
                    assert not door_geometry.overlaps(polygon,door_geometry.rect_polygon([b[0],b[2],b[3],b[5]])),('new leaf sweep hits object',door['id'],other)
    # Doors/openings must connect every new room to the existing public core.
    graph={i:set() for i in spaces}
    for r in layout['doors']+layout['openings']:
        a,b=r['connects'];graph[a].add(b);graph[b].add(a)
    for level in ['F03','F04']:
        reached={level+'_PUBLIC_CORE'};todo=list(reached)
        while todo:
            for target in graph[todo.pop()]-reached:reached.add(target);todo.append(target)
        assert all(i in reached for i in new_spaces if i.startswith(level)),('disconnected new apartment',level)
    for a in layout['anchors']:
        if (a.get('space') not in new_spaces and a['id'] not in REPAIRS) or a.get('kind')!='clearance':continue
        p=[a['position'][0],a['position'][2]]
        for identity,level,b in obstacles:
            if level==a['level'] and b[1]<1.574 and b[4]>.02:
                assert door_geometry.distance(p,door_geometry.rect_polygon([b[0],b[2],b[3],b[5]]))>=.38,('new stance blocked',a['id'],identity)
    for identity,floor,b in obstacles:
        if identity not in new_furniture and identity not in new_fitting_ids and identity not in REPAIRS:continue
        for other,level,c in obstacles:
            support_pair={identity,other} in [{u+'_sink_support','F0'+u[0]+'_'+u+'_KITCHEN_SINK_01'} for u in ['3A','4A']]
            if identity!=other and floor==level and not support_pair:assert not geometry.overlap(b,c),('object overlap',identity,other)
        r=spaces[anchors[identity]['space']]['rect']
        assert b[0]>=r[0]+.07-1e-6 and b[3]<=r[2]-.07+1e-6 and b[2]>=r[1]+.07-1e-6 and b[5]<=r[3]-.07+1e-6,('object crosses room',identity)
    materials=load('game/data/runtime_material_sets.json')['materials']
    for r in rows:
        if r['id'] not in new_furniture:continue
        for surface in r['surfaces']:
            assert surface['material'] in materials or surface['material'] in ['fabric_green','fabric_cool','glassish'],(r['id'],surface['material'])
            assert len(surface['vertices'])==len(surface['normals']) and len(surface['vertices'])%9==0
            assert all(math.isfinite(x) for x in surface['vertices']+surface['normals'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');build(parser.parse_args().apply)
