"""V2 presentation for the original rinse stand and three-piece pulley airer.

ADAPTATION of LaundryAirerProp's fixed dimensions; no mechanism authority.
The original collision, controls, identity, sound and rack tween stay in Godot.
"""
from pathlib import Path
import hashlib,json,math,sys
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
import sys
sys.path.insert(0, str(Path(__file__).parent))
from repair_surface_uvs import repair_scene
sys.path.insert(0,str(Path(__file__).parent))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
materials={}
for key in ['zinc_liner','wood_dark','brass_dull','linen']:
    mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
    node=mat.node_tree.nodes['Principled BSDF'];spec=catalog[key]
    node.inputs['Metallic'].default_value=spec['metallic']
    node.inputs['Roughness'].default_value=spec['roughness_multiplier']

def p(v):return Vector((v[0],-v[2],v[1]))
def group(name):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
fixed=group('Fixed');rack=group('Rack');rope=group('Rope')
stocks=[]
def finish(o,name,key,parent):
    o.name=name;o.data.materials.append(materials[key]);o.parent=parent
    bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume()>0,name
    stocks.append({'name':name,'group':parent.name,'material':key,'volume_m3':bm.calc_volume()});bm.free()
    # Metre charts; MatLib retains its ordinary physical triplanar scale.
    uv=o.data.uv_layers.new(name='Metres')
    for face in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=axis]
        for index in face.loop_indices:
            v=o.matrix_world@o.data.vertices[o.data.loops[index].vertex_index].co
            uv.data[index].uv=(v[axes[0]],v[axes[1]])
    return o
def box(name,at,size,key,parent,edge=.001):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    m=o.modifiers.new('Worked edge','BEVEL');m.width=edge;m.segments=3
    return finish(o,name,key,parent)
def tube(name,points,r,key,parent):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;c.use_fill_caps=True
    s=c.splines.new('POLY');s.points.add(len(points)-1)
    for v,pt in zip(s.points,points):v.co=(*p(pt),1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
    result=finish(o,name,key,parent)
    for face in result.data.polygons:face.use_smooth=len(face.vertices)==4
    return result
def mesh(name,verts,faces,key,parent,thickness=0):
    m=bpy.data.meshes.new(name);m.from_pydata([p(v) for v in verts],[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    if thickness:
        mod=o.modifiers.new('Woven cloth thickness','SOLIDIFY');mod.thickness=thickness;mod.offset=0
    return finish(o,name,key,parent)

# Retain original wall/bottom/foot locations, changing only the visible lip
# and coved sheet junctions. Two open cavities remain empty, not capped.
for index,cx in enumerate([-.32,.32]):
    rings=[(.278,.232,.4275),(.299,.249,.783),(.305,.255,.796),(.305,.255,.805),(.298,.248,.805),(.293,.243,.796),(.285,.235,.455),(.275,.225,.444)]
    n=96;verts=[]
    for rx,rz,y in rings:
        for i in range(n):
            a=i*math.tau/n;c=math.cos(a);s=math.sin(a)
            verts.append((cx+rx*math.copysign(abs(c)**.20,c),y,rz*math.copysign(abs(s)**.20,s)))
    faces=[tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))]
    for j in range(len(rings)-1):
        faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n))
    mesh(f'RinseTub{index}',verts,faces,'zinc_liner',fixed)
    for x in [-.25,.25]:
        for z in [-.20,.20]:box(f'Tub{index}Foot{x}_{z}',(cx+x,.215,z),(.045,.43,.045),'wood_dark',fixed)
    tube(f'DrainTail{index}',[(cx,.31,.07),(cx,.31,.33)],.025,'brass_dull',fixed)
    tube(f'DrainNeck{index}',[(cx,.431,.20),(cx,.31,.20)],.025,'brass_dull',fixed)
    box(f'DrainCock{index}',(cx,.31,.345),(.12,.018,.022),'brass_dull',fixed)
for x in [-.52,.52]:
    tube(f'Pulley{x}',[(x,2.3975,0),(x,2.4425,0)],.055,'zinc_liner',fixed)
    box(f'CeilingTackle{x}',(x,2.44,0),(.12,.07,.16),'zinc_liner',fixed)
    # V2's retained clear height is 3 m. The former tackle stopped 525 mm
    # below it; a hanger and ceiling plate now complete each real bearing.
    tube(f'CeilingHanger{x}',[(x,2.47,0),(x,2.996,0)],.008,'zinc_liner',fixed)
    box(f'CeilingPlate{x}',(x,2.996,0),(.12,.008,.12),'zinc_liner',fixed)
box('OriginalCleat',(.72,1.15,.26),(.06,.30,.10),'wood_dark',fixed)
box('CleatStandExtension',(.57,.875,.20),(.045,.89,.045),'wood_dark',fixed)
box('CleatSupportArm',(.645,1.15,.235),(.16,.10,.07),'wood_dark',fixed)
for y in [1.06,1.15,1.24]:tube(f'CleatPin{y}',[(.72,y-.08,.20),(.72,y+.08,.20)],.010,'brass_dull',fixed)
for i in range(2):
    z=.015+i*.016
    tube(f'CleatedReturn{i}',[(-.52 if i==0 else .52,2.42,z),(.54,2.42,z),(.72,1.24-i*.09,.20)],.005,'linen',fixed)
for z in [-.22,-.11,0,.11,.22]:box(f'Lath{z}',(0,0,z),(1.14,.035,.045),'wood_dark',rack)
for x in [-.56,.56]:box(f'EndStrap{x}',(x,.015,0),(.05,.12,.56),'zinc_liner',rack)

# Each continuous cloth skin compresses around its original supporting lath.
# A rounded rectangular crown bears on the stock, with irregular folds
# increasing gently away from the bearing. No simulated cloth or new stock.
for index,(cx,z,w,drop) in enumerate([(-.31,-.11,.32,.36),(.20,.11,.20,.26),(.43,-.11,.12,.20)]):
    profile=[(-.024,-drop*.78+(.78*drop+.012)*j/18) for j in range(19)]
    profile.extend([(-.023,.0175),(-.018,.018),(0,.018),(.018,.018),(.023,.0175),(.024,.012)])
    profile.extend((.024,.012-(drop+.012)*j/24) for j in range(1,25))
    nx=32;verts=[];nr=len(profile)
    for i in range(nx+1):
        u=i/nx
        for zz,y in profile:
            t=max(0,-y/drop);wave=(.0025*math.sin(u*math.tau*2.3+index)+.0013*math.sin(u*math.tau*4.7))*t
            verts.append((cx+(u-.5)*w,y+.0015*math.sin(u*13+index)*t,z+zz+wave))
    faces=[(i*nr+j,(i+1)*nr+j,(i+1)*nr+j+1,i*nr+j+1) for i in range(nx) for j in range(nr-1)]
    mesh(f'Cloth{index}',verts,faces,'linen',rack,.001)
    for edge,j in [('BackHem',0),('FrontHem',nr-1)]:
        points=[]
        for i in range(nx+1):
            x,y,zz=verts[i*nr+j];points.append((x,y+.004,zz+(.0006 if j else -.0006)))
        tube(f'Cloth{index}{edge}',points,.0007,'linen',rack)
    for i in [0,nx]:tube(f'Cloth{index}Selvedge{i}',[verts[i*nr+j] for j in range(nr)],.0006,'linen',rack)
# Unit rope is stretched by the presentation adapter between real endpoints.
tube('SuspensionRope',[(0,0,0),(0,1,0)],.006,'linen',rope)
bpy.context.view_layer.update()
native=ROOT/'art/blender/basement_airer.blend';asset=ROOT/'game/assets/props/basement_airer.glb'
repair_scene()
bpy.ops.wm.save_as_mainfile(filepath=str(native))
repair_scene()
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_apply=True)
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix not in ['.blend','.glb'] else path.read_bytes()).hexdigest()
receipt={'evidence_class':'INERT','classification':'ADAPTATION of retained LaundryAirerProp dimensions; INFERRED cloth hems and wet-use finish','asset_sha256':sha(asset),'native_sha256':sha(native),'source_bindings':{str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in [Path(__file__),ROOT/'game/scripts/props/laundry_airer_prop.gd']},'stocks':stocks,'cloth_count':3,'tub_count':2,'rack_travel':[1.38,1.98],'floor_feet':8,'cloth_bearing_gap_m':0.,'rope_top':[[-.52,2.42,0],[.52,2.42,0]],'rope_bottom':[[-.56,.075,0],[.56,.075,0]]}
(ROOT/'game/tests/fixtures/orison_basement_airer.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n')
print('BASEMENT AIRER:',len(stocks),'closed stocks; two tubs; three cloths')
