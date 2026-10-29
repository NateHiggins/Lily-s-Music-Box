"""Fit a low, closed timber works barricade to the retained public pavement."""
from pathlib import Path
import hashlib,json,sys,math
import bpy,bmesh
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
plan_path=ROOT/'art/data/city_frontage/source_plan.json';plan=json.loads(plan_path.read_text(encoding='utf-8'))
assert plan['schema']=='orison.city-frontage.v1' and plan['frame']=='CITY_ELEVATIONS_SOURCE' and plan['id']=='WestNorthWorks'
x,y=plan['center_xy_m'];width=float(plan['width_m']);height=float(plan['height_m'])
assert (x,y,width)==(-20.10,-12.10,5.30) and 1.2<height<1.5 and plan['thickness_m']==.36
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
exports=bpy.data.collections.new('CityFrontage');bpy.context.scene.collection.children.link(exports)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={key:dict(catalog_key=key,tint=[1,1,1,1],normal=.35,roughness=1.,pigment=1.) for key in plan['material_keys']}
mats={key:material(ROOT,'Frontage_'+key,spec,catalog) for key,spec in finishes.items()}
stocks={key:[] for key in finishes};records=[]
def box(name,lo,hi,key,bevel=.002):
    assert all(b>a for a,b in zip(lo,hi)),name
    bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
    for v in bm.verts:v.co=Vector(tuple((a+b)*.5+q*(b-a) for q,a,b in zip(v.co,lo,hi)))
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1,affect='EDGES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);stocks[key].append(obj)
    records.append(dict(id=name,material=key,bounds=list(lo)+list(hi)));return obj
def nail(name,at,vertical=False):
    bm=bmesh.new();bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=False,segments=8,radius1=.009,radius2=.009,depth=.004)
    rotation=Matrix.Identity(4) if vertical else Matrix.Rotation(math.pi/2,4,'Y')
    for v in bm.verts:v.co=rotation@v.co+Vector(at)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
    mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);stocks['iron_neutral'].append(obj)
    points=[v.co for v in mesh.vertices];records.append(dict(id=name,material='iron_neutral',bounds=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]))
post_offsets=[-width/2+plan['post_setback_m'],0,width/2-plan['post_setback_m']]
feet=[]
for i,along in enumerate(post_offsets):
    cy=y+along
    box(f'AnchorPlate_{i}',(x-.14,cy-.12,0),(x+.14,cy+.12,.008),'iron_neutral',.001)
    box(f'Post_{i}',(x-.09,cy-.09,.008),(x+.09,cy+.09,height-.05),'timber')
    for a in [-.11,.11]:
        for b in [-.09,.09]:nail(f'Anchor_{i}_{a}_{b}',(x+a,cy+b,.010),True)
    feet.extend([[x+a,cy+b,0] for a,b in [(-.13,-.11),(.13,-.11),(-.13,.11),(.13,.11),(0,0)]])
# Rail ends butt against the actual post sides; two short end cantilevers
# carry the boards to the unchanged full-width boundary.
intervals=[(-width/2,post_offsets[0]-.09)]+[(a+.09,b-.09) for a,b in zip(post_offsets,post_offsets[1:])]+[(post_offsets[-1]+.09,width/2)]
for level in [.35,.95]:
    for i,(a,b) in enumerate(intervals):box(f'Bearer_{level}_{i}',(x+.03-.06,y+a,level-.06),(x+.03+.06,y+b,level+.06),'timber')
for i in range(int(plan['boards'])):
    a=y-width/2+width*i/plan['boards']+plan['board_joint_m']/2;b=y-width/2+width*(i+1)/plan['boards']-plan['board_joint_m']/2
    box(f'Board_{i}',(x+.09,a,.10),(x+.17,b,height-.05),'timber')
    for level in [.35,.95]:nail(f'BoardNail_{i}_{level}',(x+.171,(a+b)*.5,level))
box('SeatedTopCap',(x-.18,y-width/2,height-.05),(x+.18,y+width/2,height),'timber')
# Check actual retained slab faces, not its overall envelope. It is authored in
# the building frame; convert that frame once into the city's native frame.
paving_path=ROOT/'art/blender/front_pavement_construction.json';paving=json.loads(paving_path.read_text())
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());frame=json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text())
delta=next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')['center'][1]+frame['source_threshold_z']
registered=Matrix.Diagonal((-1.,-1.,1.,1.));registered.translation.y=-delta
with bpy.data.libraries.load(str(ROOT/'art/blender/front_pavement.blend'),link=False) as (a,b):b.objects=[r['id'] for r in paving['parts']]
context=bpy.data.collections.new('RetainedPavement');bpy.context.scene.collection.children.link(context);context.hide_render=True
for obj in b.objects:context.objects.link(obj)
bpy.context.view_layer.update();vs=[];fs=[]
for obj in b.objects:
    at=len(vs);vs.extend(registered@obj.matrix_world@v.co for v in obj.data.vertices);fs.extend(tuple(at+i for i in p.vertices) for p in obj.data.polygons)
support=BVHTree.FromPolygons(vs,fs)
for sample in feet:
    p=Vector(sample);hit,n,index,distance=support.ray_cast(p+Vector((0,0,.03)),Vector((0,0,-1)),.06)
    assert hit is not None and (hit-p).length<.0001,('pavement contact',sample,hit)
# The visible boards must bear on real carriers, not hover in front of them.
carrier=[o for o in stocks['timber'] if o.name.startswith(('Post_','Bearer_'))]
vv=[];ff=[]
for obj in carrier:
    start=len(vv);vv.extend(v.co.copy() for v in obj.data.vertices);ff.extend(tuple(start+i for i in p.vertices) for p in obj.data.polygons)
carrier_tree=BVHTree.FromPolygons(vv,ff);board_contacts=0
for i in range(int(plan['boards'])):
    cy=y-width/2+width*(i+.5)/plan['boards']
    for level in [.35,.95]:
        p=Vector((x+.09,cy,level));hit,n,index,distance=carrier_tree.ray_cast(p+Vector((.03,0,0)),Vector((-1,0,0)),.06)
        assert hit is not None and (hit-p).length<.0001,('board carrier',i,level,hit)
        board_contacts+=1
for key,objects in stocks.items():
    center=Vector((x,y,0))
    for obj in objects:
        for v in obj.data.vertices:v.co-=center
        obj.location=center
    partition(exports,'WestNorthWorks__'+key,objects,finishes[key],mats[key],Matrix.Translation(center),catalog)
proof=export(ROOT,'city_frontage',exports,staged_output=True)
def sha(path):
    raw=path.read_bytes();return hashlib.sha256(raw if path.suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
runtime=dict(schema=1,id=plan['id'],asset='res://assets/props/city_frontage.glb',height_m=height,width_m=width,collision_center_m=[x,y,height/2],collision_size_m=[plan['thickness_m'],width,height],beacon_center_m=[x,y,height+plan['beacon_radius_m']],material_keys=plan['material_keys'])
runtime_path=ROOT/'game/data/orison_v2/exterior/city_frontage.json';runtime_path.write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
paths=[plan_path,paving_path,ROOT/'art/blender/front_pavement.blend',ROOT/'game/data/runtime_material_sets.json',ROOT/'game/scripts/building/v2_street_end_details.gd',runtime_path,Path(__file__)]+[ROOT/'art/blender/scripts'/p for p in ['fabrication_native_batch.py','fabrication_grain.py','fabrication_normals.py','fabrication_uvs.py','fabrication_chart_batch.py','check_exported_tangents.py']]
report=dict(evidence_class='INERT',scope=plan['scope'],source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths},asset_sha256=sha(ROOT/'game/assets/props/city_frontage.glb'),export_check=proof,stocks=records,closed_stocks=sum(len(v) for v in stocks.values()),pavement_contacts=feet,board_carrier_contacts=board_contacts,tolerance_m=.0001,finishes=finishes,failures=[])
for relative in ['art/blender/city_frontage_construction.json','game/tests/fixtures/orison_city_frontage.json']:(ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY FRONTAGE NATIVE:',report['closed_stocks'],'closed stocks;',len(feet),'pavement contacts;',proof)
