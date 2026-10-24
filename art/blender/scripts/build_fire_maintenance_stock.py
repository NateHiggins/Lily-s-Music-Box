"""Original reusable rubber-dressing bottle and spare-washer tin.

ADAPTATION: a small glazed stoneware service bottle, fitted metal screw cap,
paper label, and pressed tin. No reference photograph or lettering is baked.
"""
from pathlib import Path
import sys,json,math,collections,hashlib,os
import bpy,bmesh
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('FIRE_MAINTENANCE_OUT',str(ROOT))).resolve()
if OUT!=ROOT:
    assert OUT.is_relative_to((ROOT/'tmp').resolve()),'Partial review output must stay below repository tmp/'
for folder in ['art/blender','game/assets/props','game/data/orison_v2']:(OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from native_textile_export import export_textile
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
stocks=bpy.data.collections.new('EditableServiceStock');bpy.context.scene.collection.children.link(stocks)
exports=bpy.data.collections.new('FireMaintenanceStock');bpy.context.scene.collection.children.link(exports)
groups=collections.defaultdict(list)
finishes={
 # The generic ceramic plate has architectural crackle. Small service stock
 # needs continuous glaze, with the existing fixture plate's fine variation.
 'Bottle':dict(catalog_key='porcelain_fixture',normal=.18,roughness=.70,pigment=1.,tint=[.48,.28,.12,1]),
 'Cap':dict(catalog_key='brass_dull',normal=.35,roughness=1.,pigment=1.,tint=[.65,.60,.47,1]),
 'Label':dict(catalog_key='paper',normal=.35,roughness=1.,pigment=1.,tint=[.85,.79,.62,1]),
 'Tin':dict(catalog_key='fire_hardware_steel',normal=1.,roughness=1.,pigment=1.,tint=[.70,.70,.66,1]),
 'Gasket':dict(catalog_key='washer_rubber',normal=1.,roughness=1.,pigment=1.,tint=[1,1,1,1]),
 'BottleHinge':dict(catalog_key='brass_dull',normal=.35,roughness=1.,pigment=1.,tint=[.65,.60,.47,1]),
 'TerminalShell':dict(catalog_key='bakelite_black',normal=.35,roughness=1.,pigment=1.,tint=[1,1,1,1]),
 'TerminalMetal':dict(catalog_key='brass_dull',normal=.35,roughness=1.,pigment=1.,tint=[1,1,1,1]),
 'TerminalLever':dict(catalog_key='bakelite_black',normal=.35,roughness=1.,pigment=1.,tint=[1,1,1,1])}

def solid(name,verts,faces,group):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12,name
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);stocks.objects.link(obj);groups[group].append(obj)
    return obj

def lathe(name,profile,group,n=32):
    # Profiles have nonzero radii and closed end discs; author in Blender Z-up.
    verts=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for r,z in profile for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]
    obj=solid(name,verts,faces,group)
    # Develop each straight cylindrical/conical band at its true slant length.
    # Adjacent triangles share one chart; the previous flat triangle charts
    # visibly restarted the glaze at every triangle in the close review.
    uv=obj.data.uv_layers.new(name='Metres')
    for face in obj.data.polygons:
        if face.index<2:
            for li in face.loop_indices:
                v=obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv.data[li].uv=(v.x,v.y)
            continue
        band=(face.index-2)//n;start=(face.index-2)%n
        r0,z0=profile[band];r1,z1=profile[band+1]
        dr=r1-r0;length=math.hypot(dr,z1-z0)
        for li in face.loop_indices:
            row,k=divmod(obj.data.loops[li].vertex_index,n)
            angle=(k if k>=start else n)*math.tau/n
            if abs(dr)<1e-10:point=(r0*angle,profile[row][1])
            else:
                radius=profile[row][0]*length/dr;theta=angle*dr/length
                point=(radius*math.sin(theta),radius*math.cos(theta))
            uv.data[li].uv=point
        face.use_smooth=True
    obj['continuous_chart']=True
    return obj

def box(name,at,size,group):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object;obj.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=obj.modifiers.new('Small worked edge','BEVEL');bevel.width=min(.001,min(size)*.2);bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.name=name;obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    for c in list(obj.users_collection):c.objects.unlink(obj)
    stocks.objects.link(obj);groups[group].append(obj)
    return obj

lathe('StonewareBottle',[(.027,0),(.033,.004),(.034,.014),(.034,.113),(.033,.122),(.024,.141),(.014,.147),(.014,.166),
                       (.0105,.166),(.0105,.148),(.0205,.142),(.0305,.121),(.0305,.006)],'Bottle')
lathe('ScrewCap',[(.016,.165),(.017,.167),(.017,.184),(.015,.186)],'Cap')
for i in range(24):
    a=i*math.tau/24
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6,ring_count=4,radius=1,location=(.017*math.cos(a),.017*math.sin(a),.176))
    obj=bpy.context.object;obj.scale=(.00065,.00065,.007);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.name='CapGrip%02d'%i;obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    for c in list(obj.users_collection):c.objects.unlink(obj)
    stocks.objects.link(obj);groups['Cap'].append(obj)
# Captive flip cap. The barrel/ears terminate on the neck and cap rather than
# leaving an unscrewed lid floating above the bottle during use.
box('NeckHingeFoot',(0,.163,.017),(.022,.014,.006),'BottleHinge')
box('CapHingeTongue',(0,.175,.018),(.014,.012,.004),'Cap')
box('HingePin',(0,.171,.018),(.025,.004,.004),'BottleHinge')
# A shallow curved paper label, attached to the front half of the bottle.
n=20;verts=[]
for radius in [.03404,.03420]:
    for z in [.027,.105]:
        for i in range(n+1):
            a=-math.pi*.5+(-.95+1.9*i/n)
            verts.append((radius*math.cos(a),radius*math.sin(a),z))
faces=[];stride=n+1
for i in range(n):
    faces.extend([(i,i+1,stride+i+1,stride+i),(2*stride+i,3*stride+i,3*stride+i+1,2*stride+i+1),
                  (i,2*stride+i,2*stride+i+1,i+1),(stride+i,stride+i+1,3*stride+i+1,3*stride+i)])
faces.extend([(0,stride,3*stride,2*stride),(n,2*stride+n,3*stride+n,stride+n)])
label=solid('GluedPaperLabel',verts,faces,'Label')
uv=label.data.uv_layers.new(name='Metres')
for face in label.data.polygons:
    for li in face.loop_indices:
        vi=label.data.loops[li].vertex_index;layer,row=divmod(vi,2*stride);height,k=divmod(row,stride)
        uv.data[li].uv=(.03412*(-.95+1.9*k/n),[.027,.105][height])
label['continuous_chart']=True
lathe('PressedGasketTin',[(.031,0),(.034,.002),(.034,.017),(.033,.018),(.032,.017),(.032,.003)],'Tin')
# Real annular washer, no filled collision disc in the source geometry.
joint_blend=ROOT/'art/blender/fire_joint_stock.blend'
with bpy.data.libraries.load(str(joint_blend),link=False) as (original,loaded):
    assert 'UnionGasket' in original.objects
    loaded.objects=['UnionGasket']
original_gasket=loaded.objects[0]
radii=[math.hypot(v.co.x,v.co.y) for v in original_gasket.data.vertices]
inner=min(radii);outer=max(radii)
joint_dimensions=json.loads((ROOT/'game/data/orison_v2/fire_joint_stock.json').read_text())['dimensions']
assert abs(inner-joint_dimensions['bore_radius_m'])<1e-7
thickness=joint_dimensions['gasket_thickness_m']
bpy.data.objects.remove(original_gasket,do_unlink=True)
profile=[(outer,.003),(outer,.003+thickness),(inner,.003+thickness),(inner,.003)]
verts=[(r*math.cos(i*math.tau/48),r*math.sin(i*math.tau/48),z) for r,z in profile for i in range(48)]
faces=[(j*48+i,j*48+(i+1)%48,((j+1)%4)*48+(i+1)%48,((j+1)%4)*48+i) for j in range(4) for i in range(48)]
solid('SpareUnionWasher',verts,faces,'Gasket')
box('TerminalBase',(0,.008,0),(.124,.016,.144),'TerminalShell')
box('TerminalCase',(0,.043,.018),(.112,.055,.103),'TerminalShell')
box('TerminalFace',(0,.042,-.036),(.098,.048,.003),'TerminalMetal')
box('LeverRailLeft',(-.020,.075,0),(.008,.008,.116),'TerminalMetal')
box('LeverRailRight',(.020,.075,0),(.008,.008,.116),'TerminalMetal')
box('PricePlate',(0,.073,.032),(.080,.002,.034),'TerminalMetal')
box('PullLeverStem',(0,.084,-.025),(.009,.020,.010),'TerminalLever')
box('PullLeverGrip',(0,.094,-.025),(.050,.012,.018),'TerminalLever')
box('AerialInsulator',(.047,.079,.051),(.012,.020,.012),'TerminalShell')
box('AerialStaff',(.047,.156,.051),(.003,.140,.003),'TerminalMetal')
for group,objects in groups.items():
    spec=finishes[group];mat=material(ROOT,group,spec,catalog)
    for obj in objects:obj.data.materials.append(mat)
    if all(obj.get('continuous_chart',False) for obj in objects):
        for original in objects:
            obj=original.copy();obj.data=original.data.copy();obj.name=group;exports.objects.link(obj)
            obj.data.materials.clear();obj.data.materials.append(mat)
    else:partition(exports,group,objects,spec,mat,Matrix.Identity(4),catalog)
# Export each final corner frame from its physical chart, preserving handedness.
for obj in exports.objects:
    mesh=obj.data;bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    uv=mesh.uv_layers.active
    for key in ['_tangent_guide','_tangent_sign']:
        if key in mesh.attributes:mesh.attributes.remove(mesh.attributes[key])
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
    signs=mesh.attributes.new(name='_tangent_sign',type='FLOAT',domain='CORNER')
    normals=[item.vector.copy() for item in mesh.corner_normals]
    for face in mesh.polygons:
        ids=list(face.loop_indices);p=[mesh.vertices[mesh.loops[i].vertex_index].co for i in ids];q=[uv.data[i].uv.copy() for i in ids]
        a=q[1]-q[0];b=q[2]-q[0];det=a.x*b.y-a.y*b.x
        if abs(det)<1e-12:
            u=(p[1]-p[0]).normalized();v=(p[1]-p[0]).cross(p[2]-p[0]).normalized().cross(u)
            for i,point in zip(ids,p):uv.data[i].uv=((point-p[0]).dot(u),(point-p[0]).dot(v))
            q=[uv.data[i].uv.copy() for i in ids];a=q[1]-q[0];b=q[2]-q[0];det=a.x*b.y-a.y*b.x
        assert abs(det)>1e-12
        du=((p[1]-p[0])*b.y-(p[2]-p[0])*a.y)/det;dv=((p[2]-p[0])*a.x-(p[1]-p[0])*b.x)/det
        for i in ids:
            normal=normals[i];t=(du-normal*du.dot(normal)).normalized()
            guide.data[i].vector=(t.x,t.z,-t.y);signs.data[i].value=-1 if normal.cross(t).dot(dv)>0 else 1
stocks.hide_render=True;stocks.hide_viewport=True
proof=export_textile(OUT,'fire_maintenance_stock',exports)
bindings={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes() if p.suffix=='.blend' else p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
          for p in [Path(__file__),ROOT/'art/blender/scripts/native_textile_export.py',joint_blend,ROOT/'game/data/orison_v2/fire_joint_stock.json']}
meta={'schema_version':1,'asset':'res://assets/props/fire_maintenance_stock.glb','finishes':finishes,
      'cap_pivot':[0,.171,.018],'asset_sha256':hashlib.sha256((OUT/'game/assets/props/fire_maintenance_stock.glb').read_bytes()).hexdigest()}
(OUT/'game/data/orison_v2/fire_maintenance_meshes.json').write_text(json.dumps(meta,indent=2)+'\n')
out=OUT/'art/reviews/v2_fire_maintenance_20261022/native';out.mkdir(parents=True,exist_ok=True)
(out/'build.json').write_text(json.dumps({'evidence_class':'INERT','export':proof,'editable_stock_count':len(stocks.objects),
    'source_bindings':bindings,'replacement_gasket_m':{'inner_radius':inner,'outer_radius':outer,'thickness':thickness}},indent=2)+'\n')
print(json.dumps(proof))
