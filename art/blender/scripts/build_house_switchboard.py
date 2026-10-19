"""Original native candidate inside the retained porter-board envelope.
No installation or runtime claim. Existing catalogue PBR maps are preview only.
"""
from pathlib import Path
import bpy,bmesh,json,math,sys,os,shutil,hashlib,struct
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
OUT=Path(os.environ.get('ORISON_SWITCHBOARD_OUT',str(R/'tmp/v2-service-programmes-20261019/switchboard_candidate')));OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={
 'wood_dark':dict(normal=.10,roughness=.68,pigment=.65,tint=[.45,.30,.20,1]),
 'bakelite_black':dict(normal=.015,roughness=.30,pigment=.15,tint=[.18,.17,.16,1]),
 'brass_dull':dict(normal=.035,roughness=.60,pigment=.35,tint=[.85,.74,.45,1],metallic=.85),
 'iron_blackened':dict(normal=.10,roughness=.85,pigment=.3,tint=[.25,.25,.25,1]),
 'rubber_aged':dict(normal=.05,roughness=.80,pigment=.3,tint=[.20,.20,.20,1]),
 'nickel_plated':dict(normal=.02,roughness=.42,pigment=.3,tint=[.86,.86,.86,1],metallic=.9),
 'milk_glass':dict(normal=.02,roughness=.55,pigment=1.,tint=[.9,.5,.22,1])}
materials={key:material(R,key,dict(catalog_key=key,**finish),catalog) for key,finish in finishes.items()}
def b(v):return (v[0],-v[2],v[1])
def cube(size,at):
    bpy.ops.mesh.primitive_cube_add(size=1,location=b(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def cylinder(radius,depth,at,axis='z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=b(at));o=bpy.context.object
    if axis=='z':o.rotation_euler.x=math.pi/2
    if axis=='x':o.rotation_euler.y=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return o
def cut(stock,tool):
    bpy.context.view_layer.objects.active=stock;m=stock.modifiers.new('Through machining','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=tool;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(tool,do_unlink=True)
def finish(o,name,key,bevel=.0005,grain_horizontal=False):
    o.name=name;bpy.context.view_layer.objects.active=o
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if bevel:
        m=o.modifiers.new('Worked edge radius','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    m=o.modifiers.new('Triangle charts','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data);bm.free()
    o.data.materials.clear();o.data.materials.append(materials[key]);o['catalog_key']=key
    # Primitives already carry a unit-template UVMap. Remove it: retaining
    # that first layer made glTF export the wrong charts as TEXCOORD_0.
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='MetreStock');uv.active_render=True
    for face in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(face.normal[a]));u,v=[(1,2),(0,2),(0,1)][axis]
        if grain_horizontal:u,v=v,u
        for loop in face.loop_indices:
            p=o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u],p[v])
    # Boolean flats can retain tiny opposite normal tilts along long fans.
    # Use manufactured-stock corner normals and exact axes on those flats,
    # while retaining the turned/bevel fans. Do not hide seams with roughness
    # or by removing the normal maps.
    normals=np.asarray(stock_corner_normals(o.data,planar_axes=np.eye(3)))
    axes=np.argmax(abs(normals),axis=1);flat=np.max(abs(normals),axis=1)>=1.-1e-7
    for i in np.flatnonzero(flat):
        value=math.copysign(1.,normals[i,axes[i]]);normals[i]=0.;normals[i,axes[i]]=value
    o.data.normals_split_custom_set(normals.tolist())
    return o
def box(name,size,at,key='wood_dark',bevel=.0007,horizontal=False):return finish(cube(size,at),name,key,bevel,horizontal)
# Original 0.66 x 0.68 x 0.16 metre envelope, separate joined cabinet stocks.
box('RearPanel',(.61,.63,.012),(0,.34,.071))
for side in [-1,1]:box('SideStile_'+str(side),(.025,.68,.16),(side*.3175,.34,0))
for y,name in [(.0125,'LowerRail'),(.6675,'UpperRail')]:box(name,(.61,.025,.16),(0,y,0),horizontal=True)
box('TopBead',(.66,.012,.012),(0,.652,-.081),horizontal=True)
box('BottomBead',(.66,.012,.012),(0,.028,-.081),horizontal=True)
face=cube((.6,.55,.016),(0,.37,-.1))
ports=[]
for row in range(3):
    for col in range(6):
        x,y=-.25+col*.1,.52-row*.13
        cut(face,cylinder(.009,.04,(x,y,-.1)))
        ring=cylinder(.018,.012,(x,y,-.115));cut(ring,cylinder(.009,.04,(x,y,-.115)));finish(ring,f'Jack_{row}_{col}','brass_dull',.0004)
        sleeve=cylinder(.0105,.025,(x,y,-.094));cut(sleeve,cylinder(.008,.04,(x,y,-.094)));finish(sleeve,f'Insulator_{row}_{col}','bakelite_black',.0002)
        ports.append(dict(id=f'{row}_{col}',center=[x,y,-.121],bore_m=.016))
finish(face,'JackField','bakelite_black',.0008)
parking=cube((.48,.042,.004),(0,.063,-.096))
for x in [-.16,.16]:cut(parking,cylinder(.0085,.025,(x,.063,-.096)))
finish(parking,'ParkingStrip','brass_dull',.0005)
for x in [-.282,.282]:
    for y in [.123,.617]:
        screw=cylinder(.004,.003,(x,y,-.111));cut(screw,cube((.0012,.009,.003),(x,y,-.112)));finish(screw,'Screw_'+('West' if x<0 else 'East')+'_'+('Lower' if y<.3 else 'Upper'),'nickel_plated',.00015)
# Two separate shaft/insulator stocks per plug, assembled at runtime. The
# tip points toward +Z into the board. Pivot is the hand-held handle centre.
for name,key,radius,depth,z in [('PlugHandle','bakelite_black',.012,.062,0),('PlugCollar','brass_dull',.013,.009,.034),('PlugShaft','nickel_plated',.0068,.033,.055),('PlugInsulator','bakelite_black',.007,.004,.052)]:
    stock=cylinder(radius,depth,(0,0,z))
    if name=='PlugShaft':cut(stock,cylinder(.008,.004,(0,0,.052)))
    finish(stock,name,key,.0005)
box('ListeningKeyLever',(.022,.10,.018),(0,.05,0),'brass_dull')
finish(cylinder(.017,.03,(0,.108,0),'x'),'ListeningKeyKnob','bakelite_black',.001)
bezel=cylinder(.037,.008,(0,0,0));cut(bezel,cylinder(.029,.03,(0,0,0)));finish(bezel,'AskingLampBezel','brass_dull',.0005)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1)
lens=bpy.context.object;lens.scale=(.028,.006,.028);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
finish(lens,'AskingLampLens','milk_glass',0)
box('MountCleat',(.5,.025,.022),(0,0,0),bevel=.001,horizontal=True)
# A native closed flexible stock. Runtime may bend its source rings, while
# retaining this topology, circumference/length UVs, normals and tangent frame.
length=.8;radius=.0035;segments=96;sides=16;vertices=[];faces=[]
for row in range(segments+1):
    for side in range(sides):
        theta=math.tau*side/sides;vertices.append(b((radius*math.cos(theta),length*row/segments,radius*math.sin(theta))))
for row in range(segments):
    for side in range(sides):
        a=row*sides+side;c=row*sides+(side+1)%sides;faces.append((a,c,c+sides,a+sides))
faces += [tuple(reversed(range(sides))),tuple(segments*sides+i for i in range(sides))]
mesh=bpy.data.meshes.new('Native cord rings');mesh.from_pydata(vertices,[],faces);mesh.update()
cord=bpy.data.objects.new('CordStock',mesh);bpy.context.collection.objects.link(cord);finish(cord,'CordStock','rubber_aged',0)
uv=cord.data.uv_layers.active
chart_radius=radius*math.sin(math.pi/sides)/(math.pi/sides)
for face in cord.data.polygons:
    points=[cord.data.vertices[cord.data.loops[i].vertex_index].co for i in face.loop_indices]
    cap=max(p.z for p in points)-min(p.z for p in points)<1e-8;face.use_smooth=not cap
    angles=[math.atan2(-p.y,p.x) for p in points]
    if max(angles)-min(angles)>math.pi:angles=[a+math.tau if a<0 else a for a in angles]
    for i,p,angle in zip(face.loop_indices,points,angles):uv.data[i].uv=(p.x,-p.y) if cap else (chart_radius*angle,p.z)

def cord_pose(distance,start,end):
    start,end=Vector(start),Vector(end);horizontal=end-start;horizontal.y=0;d=horizontal.length
    assert d>.028
    h=horizontal/d;r=d*.5;common=(start.y+end.y+math.pi*r-length)*.5
    assert common<=min(start.y,end.y)
    first=start.y-common;s=distance
    if s<first:at=start-Vector((0,s,0));tangent=Vector((0,-1,0))
    elif s<first+math.pi*r:
        theta=(s-first)/r;at=(start+end)*.5;at.y=common;at-=h*r*math.cos(theta);at.y-=r*math.sin(theta);tangent=h*math.sin(theta)-Vector((0,math.cos(theta),0))
    else:at=end.copy();at.y=common+s-first-math.pi*r;tangent=Vector((0,1,0))
    binormal=Vector((0,1,0)).cross(h);side=tangent.cross(binormal)
    return at,side,binormal
metrics={}
for o in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    # Explicit per-corner derivatives preserve chart seams and the signed-V
    # convention without cancellation from glTF's usual one-minus-V offset.
    guides=[o.data.attributes.new(name=name,type='FLOAT_VECTOR',domain='CORNER') for name in ['_native_uv','_native_du','_native_dv']]
    layer=o.data.uv_layers.active
    for face in o.data.polygons:
        loops=list(face.loop_indices);p=[o.data.vertices[o.data.loops[i].vertex_index].co for i in loops];t=[layer.data[i].uv.copy() for i in loops]
        a=t[1]-t[0];c=t[2]-t[0];det=a.x*c.y-c.x*a.y
        assert abs(det)>1e-12,(o.name,'collapsed metric chart',det)
        du=((p[1]-p[0])*c.y-(p[2]-p[0])*a.y)/det
        dv=((p[2]-p[0])*a.x-(p[1]-p[0])*c.x)/det
        for i,tex in zip(loops,t):
            guides[0].data[i].vector=(tex.x,tex.y,0)
            guides[1].data[i].vector=(du.x,du.z,-du.y)
            guides[2].data[i].vector=(-dv.x,-dv.z,dv.y)
    bm=bmesh.new();bm.from_mesh(o.data);edges=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    bad=0
    for f in o.data.polygons:
        a,c,d=[o.data.uv_layers.active.data[i].uv for i in f.loop_indices]
        if abs((c.x-a.x)*(d.y-a.y)-(c.y-a.y)*(d.x-a.x))<1e-15:bad+=1
    assert edges==0 and volume>0 and bad==0,(o.name,edges,volume,bad)
    metrics[o.name]=dict(nonmanifold_edges=edges,volume_m3=volume,degenerate_uv=bad,triangles=len(o.data.polygons),catalog_key=o['catalog_key'])
trees=[]
deps=bpy.context.evaluated_depsgraph_get()
for o in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    if o.name.startswith(('Plug','Listening','Asking','MountCleat','CordStock')):continue
    trees.append(BVHTree.FromObject(o,deps))
def first_z(x,y):
    start=Vector(b((x,y,-.4)));direction=Vector((0,-1,0));distances=[]
    for tree in trees:
        hit=tree.ray_cast(start,direction,.6)
        if hit[0] is not None:distances.append(-hit[0].y)
    assert distances,(x,y)
    return min(distances)
bores=0;bearings=0
for port in ports:
    x,y,z=port['center']
    for side in range(17):
        theta=math.tau*side/16;r=.007 if side<16 else 0
        assert first_z(x+r*math.cos(theta),y+r*math.sin(theta))>.05,(port,'blocked bore')
        bores+=1
    for side in range(16):
        theta=math.tau*side/16;actual=first_z(x+.013*math.cos(theta),y+.013*math.sin(theta))
        assert abs(actual-z)<=.0001,(port,'collar bearing',actual)
        bearings+=1
native_checks=dict(bore_clearance_samples=bores,collar_bearing_samples=bearings,tolerance_m=.0001)
projection=dict(schema_version=1,asset='res://assets/props/house_switchboard.glb',parts=list(metrics),finishes=[dict(key=key,**recipe) for key,recipe in finishes.items()],ports=ports,
    parking=[dict(id='park_'+str(i),center=[x,.063,-.098],bore_m=.017) for i,x in enumerate([-.16,.16])],
    plug=dict(shaft_radius_m=.007,tip_z=.0715,collar_z=.0385,skin_m=.00005,cord_outlet_z=-.031,rest=[[x,.063,-.13655] for x in [-.16,.16]]),
    cord=dict(length_m=length,radius_m=radius,anchors=[[x,.04,-.095] for x in [-.16,.16]],mesh='CordStock'),
    key=dict(pivot=[.25,.10,-.12],minimum=-.42,maximum=0.,answer_stop=-.38),lamp=dict(at=[-.25,.58,-.122]),
    calling_ports=[dict(endpoint='F02_A_TELEPHONE',port='0_0')],trunk=dict(port='2_5',id='outside_trunk'))
(OUT/'runtime_projection.json').write_text(json.dumps(projection,indent=2)+'\n')
bindings={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [Path(__file__).resolve(),R/'art/blender/scripts/fabrication_native_batch.py',R/'art/blender/scripts/fabrication_normals.py',R/'art/blender/scripts/check_exported_tangents.py',R/'game/data/runtime_material_sets.json']}
(OUT/'construction.json').write_text(json.dumps(dict(evidence_class='INERT',cabinet_envelope_m=[.66,.68,.16],parts=metrics,ports=ports,finishes=finishes,native_checks=native_checks,source_bindings=bindings,scope='Native fabrication and preview only; no composed runtime or human grant.'),indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'house_switchboard.blend'))
# Render the cabinet alone; reusable plugs/keys are exported about their own
# runtime pivot, not visually superimposed over the board for this review.
stocks=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in stocks:
    if o.name.startswith(('Plug','Listening','MountCleat','Asking','CordStock')):o.hide_render=True
# Review an assembled set as well as the reusable template stocks. These
# duplicates are excluded from GLB export and do not enter the native library.
instances=[]
for source in stocks:
    offsets=[]
    if source.name.startswith('Plug'):offsets=[(-.16,.063,-.1365),(.16,.063,-.1365)]
    if source.name.startswith('Listening'):offsets=[(.25,.10,-.12)]
    if source.name.startswith('Asking'):offsets=[(-.25,.58,-.122)]
    for at in offsets:
        copy=source.copy();copy.data=source.data.copy();copy.hide_render=False;bpy.context.collection.objects.link(copy);copy.location=b(at);instances.append(copy)
    if source.name=='CordStock':
        for x in [-.16,.16]:
            copy=source.copy();copy.data=source.data.copy();copy.hide_render=False;bpy.context.collection.objects.link(copy);instances.append(copy)
            for vertex in copy.data.vertices:
                p=vertex.co.copy();at,side,normal=cord_pose(p.z,(x,.04,-.095),(x,.063,-.1675));vertex.co=b(at+side*p.x+normal*(-p.y))
            copy.data.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.threads_mode='FIXED';scene.render.threads=4
if scene.world is None:scene.world=bpy.data.worlds.new('Neutral cabinet review')
scene.world.color=(.12,.12,.12)
for at,power,size in [((1,1.5,2.1),200,1.5),((-1,1,.9),90,1.3)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.35))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();scene.camera=bpy.context.object;scene.camera.data.lens=55
for name,at,target in [('front',(0,1.5,.65),(0,0,.34)),('oblique',(.9,1.25,.8),(0,0,.34)),('jack_detail',(.2,.6,.65),(0,.11,.4)),('assembled_full',(0,2.2,.5),(0,0,.16))]:
    scene.camera.location=at;scene.camera.rotation_euler=(Vector(target)-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
# Catalogue names only in GLB. Game PBR remains owned by MatLib; no duplicate
# image embedding or reference photography is introduced into the asset.
# Disabling nodes alone leaves linked images in Blender's glTF gather graph.
# Save/render above with catalogue previews, then use fresh name-only materials
# for export so the installed stock does not duplicate MatLib's texture payload.
export_materials={}
for key,mat in materials.items():
    name=mat.name;mat.name=name+'_native_preview'
    clean=bpy.data.materials.new(name);clean.diffuse_color=(.5,.5,.5,1)
    export_materials[mat.as_pointer()]=clean
for stock in stocks:
    for slot in stock.material_slots:
        if slot.material is not None:slot.material=export_materials[slot.material.as_pointer()]
bpy.ops.object.select_all(action='DESELECT')
for o in stocks:o.select_set(True);o.hide_render=False
bpy.context.view_layer.objects.active=stocks[0]
class NativeChartExport:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            uv=values('_NATIVE_UV')[:,:2];uv[:,1]*=-1
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
            du=values('_NATIVE_DU');dv=values('_NATIVE_DV')
            tangent=du-n*np.sum(du*n,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
            handed=np.sign(np.sum(np.cross(n,tangent)*dv,axis=1));assert np.all(handed!=0)
            primitive.attributes['TEXCOORD_0'].buffer_view=BinaryData(uv.astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((tangent,handed)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            for key in ['_NATIVE_UV','_NATIVE_DU','_NATIVE_DV']:del primitive.attributes[key]
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=NativeChartExport
bpy.ops.export_scene.gltf(filepath=str(OUT/'house_switchboard.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True)
from check_exported_tangents import validate as validate_tangents
export_proof=validate_tangents(OUT/'house_switchboard.glb')
export_proof['asset']='game/assets/props/house_switchboard.glb'
raw=(OUT/'house_switchboard.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0];document=json.loads(raw[20:20+size]);assert not document.get('images') and not document.get('textures')
report=json.loads((OUT/'construction.json').read_text());report['export']={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'images':0,'tangents':export_proof};(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('SWITCHBOARD NATIVE CANDIDATE PASS',len(metrics),'parts',len(ports),'through sockets')
if os.environ.get('ORISON_SWITCHBOARD_INSTALL')=='1':
    for source,target in [('house_switchboard.blend','art/blender/house_switchboard.blend'),('house_switchboard.glb','game/assets/props/house_switchboard.glb'),('construction.json','art/blender/house_switchboard_construction.json'),('runtime_projection.json','game/data/orison_v2/house_switchboard.json')]:shutil.copyfile(OUT/source,R/target)
    print('Installed original native stock and generated runtime projection')
