"""Fitted contact leaves, insulating seats and a real reset spindle.
The original 28 board mesh owners and its service/job authorities survive.
"""
from pathlib import Path
import hashlib,json,math,sys
import bpy,bmesh
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
plan=json.loads((ROOT/'art/data/service_instruments/source_plan.json').read_text())
source=next(a for a in plan['actors'] if a['id']=='M01')
bridge=Vector(source['meshes'][26]['position']);reset=Vector(source['meshes'][27]['position'])
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
exports=bpy.data.collections.new('Runtime control stocks');bpy.context.scene.collection.children.link(exports)
pieces=[];native={}

def solid(name,points,faces,edge=0):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([C@Vector(p) for p in points],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    if edge:
        bpy.context.view_layer.objects.active=obj
        bevel=obj.modifiers.new('Manufacturing edge break','BEVEL');bevel.width=edge;bevel.segments=3;bevel.limit_method='ANGLE'
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-10)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    bm.to_mesh(obj.data);bm.free();pieces.append(obj);return obj

def box(name,size,at,edge=.00015):
    low=Vector(at)-Vector(size)*.5;high=Vector(at)+Vector(size)*.5
    return solid(name,[(x,y,z) for z in [low.z,high.z] for y in [low.y,high.y] for x in [low.x,high.x]],
        [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],edge)

def tube(name,outer,inner,low,high,at=(0,0,0),axis='z',scallop=False,edge=0):
    n=96 if scallop else 48;points=[]
    rings=[(low,outer),(high,outer)]+([(high,inner),(low,inner)] if inner else [])
    for height,radius in rings:
        for i in range(n):
            angle=math.tau*i/n;r=radius-(.0005*(1-math.cos(angle*24)) if scallop else 0)
            p=Vector((r*math.cos(angle),r*math.sin(angle),height)) if axis=='z' else Vector((height,r*math.cos(angle),r*math.sin(angle))) if axis=='x' else Vector((r*math.cos(angle),height,r*math.sin(angle)))
            points.append(p+Vector(at))
    faces=[]
    for row in range(len(rings)-1):
        faces.extend((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i) for i in range(n))
    if inner:faces.extend((3*n+i,3*n+(i+1)%n,(i+1)%n,i) for i in range(n))
    else:faces.extend([tuple(reversed(range(n))),tuple(n+i for i in range(n))])
    return solid(name,points,faces,edge)

def finish(name,key):
    global pieces
    spec=dict(catalog_key=key,normal=1.0 if key=='radiator_service_brass' else .12 if name=='FlagArm' else .35,roughness=.6 if name=='FlagArm' else 1.0,pigment=1.0,tint=[.48,.08,.055] if name=='FlagArm' else [1,1,1])
    mat=material(ROOT,key,spec,catalog)
    draw=partition(exports,name,pieces,spec,mat,Matrix.Identity(4),catalog)
    # Keep tiny bevel charts near zero rather than near a whole-metre UV
    # boundary. Offsets are whole catalogue texture periods: appearance and
    # physical scale stay identical while compressed coordinates retain detail.
    tile=catalog[key]['meters_per_tile'];uv=draw.data.uv_layers.active.data
    for face in draw.data.polygons:
        center=sum((uv[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
        shift=Vector((round(center.x/tile)*tile,round(center.y/tile)*tile))
        for i in face.loop_indices:uv[i].uv-=shift
    for obj in pieces:bpy.data.objects.remove(obj,do_unlink=True)
    pieces=[];native[name]=draw

for x in [-.035,.035]:box('Fixed silvered contact',(.009,.007,.004),(x,bridge.y,bridge.z-.009))
finish('FixedContactMetal','nickel_plated')
for x in [-.035,.035]:box('Porcelain contact seat',(.012,.012,.003),(x,bridge.y,bridge.z-.0125))
finish('FixedContactInsulators','porcelain_fixture')
for x in [-.035,.035]:tube('Moving contact button',.0025,0,-.007,-.006,(x,0,0))
box('Recessed conductive bridge',(.070,.002,.0004),(0,0,-.0065),.00008)
finish('MovingContactMetal','nickel_plated')
tube('External spindle bearing',.009,.0048,.030,.049,(reset.x,reset.y,0),edge=.00018)
tube('Bearing foot flange',.014,.0048,.030,.032,(reset.x,reset.y,0),edge=.00018)
for x in [-.010,.010]:tube('Bearing fixing head',.002,0,.032,.033,(reset.x+x,reset.y,0),edge=.00010)
finish('ResetBearing','radiator_service_brass')
tube('Reset shaft',.0045,0,-.025,.035,axis='y',edge=.00012)
knob=tube('Scalloped reset cap',.018,0,.030,.040,axis='y',scallop=True)
# Round the outside before cutting the recessed index. Beveling the Boolean's
# long bridge edges produced a visible diagonal scar across the knob face.
bpy.context.view_layer.objects.active=knob
edge=knob.modifiers.new('Rounded finger rim','BEVEL');edge.width=.00025;edge.segments=3;edge.limit_method='ANGLE'
bpy.ops.object.modifier_apply(modifier=edge.name)
cutter=box('Index groove cutter',(.026,.004,.0015),(0,.040,0),0)
bpy.context.view_layer.objects.active=knob
cut=knob.modifiers.new('Real face index groove','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=cutter
bpy.ops.object.modifier_apply(modifier=cut.name);pieces.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
finish('ResetKnob','radiator_service_brass')

# These payloads use the original live flag and ivory-seat frames. A real
# axle and two hollow journals make the unchanged rotation physically legible.
box('Folded flag blade',(.058,.021,.0015),(0,0,.0005),.00022)
tube('Flag axle',.0015,0,-.034,.034,axis='x',edge=.00008)
finish('FlagArm','indicator_enamel')
for side in [-1,1]:
    box('Ivory window stile',(.004,.030,.003),(side*.0355,0,.0015),.00022)
    box('Ivory window rail',(.067,.004,.003),(0,side*.013,.0015),.00022)
finish('FlagSeat','porcelain_fixture')
for side in [-1,1]:
    x=side*.0315
    tube('Flag journal',.0035,.0017,x-.0015,x+.0015,(0,0,0),axis='x',edge=.00010)
    box('Journal mounting foot',(.004,.006,.009),(x,0,-.0065),.00018)
finish('FlagBearings','radiator_service_brass')
report=export(ROOT,'annunciator_controls',exports)
report.update(evidence_class='INERT',scope='Native contact/reset stocks, not gameplay or room acceptance.',
              actor='LobbyPorterBoard',retained_source_meshes=28,
              uv_rebased_by_whole_texture_periods=True,
              flag_journal_running_clearance_m=.0002,reset_edge_break_m=.00025,
              source_actor_lf_sha256=hashlib.sha256((ROOT/'game/scripts/props/otis_prop.gd').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
              bridge_position=list(bridge),reset_position=list(reset),contact_plane_z=bridge.z-.007)
out=ROOT/'tmp/v2-radiator-polish-20261017';out.mkdir(exist_ok=True)
(out/'annunciator_native.json').write_text(json.dumps(report,indent=2)+'\n')
print('ANNUNCIATOR NATIVE',report,flush=True)
