"""Source-owned roof closures and public-court pitched skylight.

Retained ceilings own the interior underside. Native caps own their upper skin,
outer thickness and four aperture reveals; each remaining rectangle owns one
solid collider. The raised curb and glazing use separate fixed geometry.
"""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=ROOT/'art/blender';OUT.mkdir(parents=True,exist_ok=True)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
roof=json.loads((ROOT/'art/data/orison_v2/roof_source.json').read_text(encoding='utf-8'))
opening=next(r for r in layout['slab_openings'] if r['id']=='ROOF_PUBLIC_COURT_SKYLIGHT')
assert opening==dict(id='ROOF_PUBLIC_COURT_SKYLIGHT',space='ROOF_PUBLIC_CORE',surface='Ceiling',rect=[2.45,-1.9,3.45,-.25])
assert all(r in layout[table] for table,records in roof['records'].items() for r in records)
depth=layout['dimensions']['slab_thickness'];half=layout['dimensions']['partition_wall']/2
bottom=roof['records']['levels'][0]['y']+layout['dimensions']['clear_height'];top=bottom+depth
assert depth==.2 and abs(top-22.4)<1e-8
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
materials={}
for key,color in [('concrete',(.36,.35,.32,1)),('metal',(.23,.25,.25,1)),('glass',(.77,.85,.86,1))]:
    mat=bpy.data.materials.new(key);mat.use_nodes=True
    bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Metallic'].default_value=.75 if key=='metal' else 0
    bsdf.inputs['Roughness'].default_value=.045 if key=='glass' else (.5 if key=='metal' else .8)
    if key=='glass':bsdf.inputs['Transmission Weight'].default_value=1;bsdf.inputs['IOR'].default_value=1.52
    materials[key]=mat

def point(p):return Vector((p[0],-p[2],p[1]))
def mesh_object(name,vertices,faces,key,recalculate=True):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([point(p) for p in vertices],[],faces);mesh.update()
    if recalculate:
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(materials[key])
    return obj

def map_metres(obj):
    mesh=obj.data;bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    uv=mesh.uv_layers.active or mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        face.use_smooth=False;n=Vector(face.normal).normalized()
        seed=Vector((0,1,0)) if abs(n.y)<.85 else Vector((1,0,0))
        u=(seed-n*seed.dot(n)).normalized();v=n.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
    if 'custom_normal' in mesh.attributes:mesh.attributes.remove(mesh.attributes['custom_normal'])
    mesh.update()

def horizontal(rect,height,up):
    a,b,c,d=rect;face=[(a,height,b),(a,height,d),(c,height,d),(c,height,b)]
    return face if up else list(reversed(face))

def vertical_x(x,z0,z1,normal_x):
    face=[(x,bottom,z0),(x,bottom,z1),(x,top,z1),(x,top,z0)]
    # Godot outward -X is the right-handed front of this ordering.
    return face if normal_x<0 else list(reversed(face))

def vertical_z(z,x0,x1,normal_z):
    face=[(x0,bottom,z),(x0,top,z),(x1,top,z),(x1,bottom,z)]
    return face if normal_z<0 else list(reversed(face))

def subtract(rect,hole):
    a,b,c,d=rect;u,v,w,t=hole
    ix0=max(a,u);iz0=max(b,v);ix1=min(c,w);iz1=min(d,t)
    if ix0>=ix1 or iz0>=iz1:return [rect]
    return [r for r in [[a,b,ix0,d],[ix1,b,c,d],[ix0,b,ix1,iz0],[ix0,iz1,ix1,d]] if r[2]-r[0]>1e-8 and r[3]-r[1]>1e-8]

caps=[];cap_records=[]
for room in roof['records']['spaces']:
    if room.get('no_ceiling'):continue
    x0,z0,x1,z1=room['rect'];outer=[x0-half,z0-half,x1+half,z1+half]
    nx=math.ceil((outer[2]-outer[0])/4);nz=math.ceil((outer[3]-outer[1])/4)
    rim=[[outer[0],outer[1],outer[2],z0],[outer[0],z1,outer[2],outer[3]],
         [outer[0],z0,x0,z1],[x1,z0,outer[2],z1]]
    hole=opening['rect'] if room['id']==opening['space'] else None
    for ix in range(nx):
        for iz in range(nz):
            rect=[outer[0]+(outer[2]-outer[0])*ix/nx,outer[1]+(outer[3]-outer[1])*iz/nz,
                  outer[0]+(outer[2]-outer[0])*(ix+1)/nx,outer[1]+(outer[3]-outer[1])*(iz+1)/nz]
            pieces=subtract(rect,hole) if hole else [rect]
            for j,(a,b,c,d) in enumerate(pieces):
                faces=[horizontal([a,b,c,d],top,True)]
                if abs(a-outer[0])<1e-8:faces.append(vertical_x(a,b,d,-1))
                if abs(c-outer[2])<1e-8:faces.append(vertical_x(c,b,d,1))
                if abs(b-outer[1])<1e-8:faces.append(vertical_z(b,a,c,-1))
                if abs(d-outer[3])<1e-8:faces.append(vertical_z(d,a,c,1))
                if hole:
                    u,v,w,t=hole
                    if abs(c-u)<1e-8 and min(d,t)>max(b,v):faces.append(vertical_x(c,max(b,v),min(d,t),1))
                    if abs(a-w)<1e-8 and min(d,t)>max(b,v):faces.append(vertical_x(a,max(b,v),min(d,t),-1))
                    if abs(d-v)<1e-8 and min(c,w)>max(a,u):faces.append(vertical_z(d,max(a,u),min(c,w),1))
                    if abs(b-t)<1e-8 and min(c,w)>max(a,u):faces.append(vertical_z(b,max(a,u),min(c,w),-1))
                for ra,rb,rc,rd in rim:
                    seat=[max(a,ra),max(b,rb),min(c,rc),min(d,rd)]
                    if seat[2]-seat[0]>1e-8 and seat[3]-seat[1]>1e-8:faces.append(horizontal(seat,bottom,False))
                label=room['id']+'_Cap_%02d_%02d'%(ix,iz)+(f'_AroundCourt{j}' if len(pieces)>1 else '')
                vertices=[p for face in faces for p in face]
                obj=mesh_object(label,vertices,[tuple(range(i,i+4)) for i in range(0,len(vertices),4)],'concrete',False)
                map_metres(obj);caps.append(obj)
                cap_records.append({'id':label,'space':room['id'],'bounds':[a,bottom,b,c,top,d],'original_underside':room['rect'],'internal_caps':False})
assert len(caps)==10

prism_faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def prism(name,rect,lo,hi,key,bevel=0):
    a,b,c,d=rect
    vertices=[(x,fn(x,z),z) for fn in [lo,hi] for x,z in [(a,b),(c,b),(c,d),(a,d)]]
    obj=mesh_object(name,vertices,prism_faces,key)
    if bevel:
        mod=obj.modifiers.new('Cast arris','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def constant(y):return lambda x,z:y
sky=[];curbs=[]
outer=[2.37,-1.98,3.53,-.17];inner=opening['rect'];curb_top=top+.3
for label,rect in [
    ('South',[outer[0],outer[1],outer[2],inner[1]]),('North',[outer[0],inner[3],outer[2],outer[3]]),
    ('West',[outer[0],inner[1],inner[0],inner[3]]),('East',[inner[2],inner[1],outer[2],inner[3]])]:
    obj=prism('CourtSkylightCurb_'+label,rect,constant(top),constant(curb_top-.02),'concrete',.0015)
    sky.append(obj);curbs.append({'id':obj.name,'rect':rect,'seat_y':top,'top':curb_top-.02})

# Each cap overhangs the outer face by ten millimetres. Its actual underside
# groove receives the 1.2 mm boot while retaining the glazing's original seat.
cap_rects=[('South',[outer[0]-.01,outer[1]-.01,outer[2]+.01,inner[1]]),
    ('North',[outer[0]-.01,inner[3],outer[2]+.01,outer[3]+.01]),
    ('West',[outer[0]-.01,inner[1],inner[0],inner[3]]),
    ('East',[inner[2],inner[1],outer[2]+.01,inner[3]])]
grooves=[('South',[outer[0]-.02,outer[1]-.0012,outer[2]+.02,outer[1]+.0024]),
    ('North',[outer[0]-.02,outer[3]-.0024,outer[2]+.02,outer[3]+.0012]),
    ('West',[outer[0]-.0012,outer[1]-.02,outer[0]+.0024,outer[3]+.02]),
    ('East',[outer[2]-.0024,outer[1]-.02,outer[2]+.0012,outer[3]+.02])]
cap_records_sky=[]
for label,rect in cap_rects:
    obj=prism('CourtSkylightCurbCap_'+label,rect,constant(curb_top-.02),constant(curb_top),'concrete')
    for groove_label,groove in grooves:
        a,b,c,d=rect;u,v,w,t=groove
        if min(c,w)-max(a,u)<=1e-8 or min(d,t)-max(b,v)<=1e-8:continue
        tool=prism('GrooveTool',groove,constant(curb_top-.021),constant(curb_top-.016),'concrete')
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Flashing pocket '+groove_label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
    sky.append(obj);cap_records_sky.append({'id':obj.name,'rect':rect,'seat_y':curb_top-.02,'top':curb_top})

ridge_x=2.95;west_x=2.41;east_x=3.49;rise=.4;slope=rise/(ridge_x-west_x)
z_stations=[-1.94,-1.94+1.73/3,-1.94+1.73*2/3,-.21]
frame=[]
for x in [west_x,east_x]:
    frame.append(prism('SeatedEaveRail',[x-.03,z_stations[0],x+.03,z_stations[-1]],constant(curb_top),constant(curb_top+.060),'metal'))
frame.append(prism('RidgeTee',[ridge_x-.015,z_stations[0],ridge_x+.015,z_stations[-1]],constant(curb_top+.410),constant(curb_top+.463),'metal'))
panes=[]
for side,xa,xb in [('West',2.425,2.939),('East',2.961,3.475)]:
    m=slope if side=='West' else -slope
    def pane_y(x,z):return curb_top+.060+rise-slope*abs(x-ridge_x)
    offset=.003*math.sqrt(1+m*m)
    for z in z_stations:
        rect=[west_x if side=='West' else ridge_x,z-.015,ridge_x if side=='West' else east_x,z+.015]
        frame.append(prism('GlazingTee_'+side,rect,lambda x,z:pane_y(x,z)-offset-.05,lambda x,z:pane_y(x,z)-offset,'metal'))
        frame.append(prism('GlazingCap_'+side,rect,lambda x,z:pane_y(x,z)+offset,lambda x,z:pane_y(x,z)+offset+.002,'metal'))
    normal=Vector((-m,1,0)).normalized()
    for i,(za,zb) in enumerate(zip(z_stations,z_stations[1:])):
        centres=[Vector((x,pane_y(x,z),z)) for x,z in [(xa,za+.012),(xb,za+.012),(xb,zb-.012),(xa,zb-.012)]]
        vertices=[tuple(p+normal*t) for t in [-.003,.003] for p in centres]
        obj=mesh_object('CourtSkylightGlass_'+side+str(i),vertices,prism_faces,'glass');sky.append(obj)
        panes.append({'id':obj.name,'side':side,'thickness':.006,'rect':[xa,za+.012,xb,zb-.012],
                      'centre_plane_eave_y':curb_top+.06,'ridge_y':curb_top+.06+rise})
bpy.ops.object.select_all(action='DESELECT')
for obj in frame:obj.select_set(True)
bpy.context.view_layer.objects.active=frame[0];bpy.ops.object.join();frame[0].name='CourtSkylightSteelFrame';sky.append(frame[0])
for obj in sky:map_metres(obj)
for obj in sky:
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0, obj.name
    bm.free()
assert len(sky)==15

bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'roof_bulkhead_caps.blend'))
class ExportMetricBasis:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':self.normals=np.asarray(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,n in enumerate(self.normals):
                seed=np.array((0,0,-1) if abs(n[2])<.85 else (1,0,0),dtype=np.float64)
                u=seed-n*np.dot(seed,n);u/=np.linalg.norm(u);result[i,:3]=u;result[i,3]=-1
            data['data']=result
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportMetricBasis
for name,objects in [('roof_bulkhead_caps',caps),('light_court_skylight',sky)]:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'game/assets/props/{name}.glb'),export_format='GLB',
        export_yup=True,export_tangents=True,export_animations=False,use_selection=True)
(ROOT/'game/tests/fixtures/orison_light_court_skylight.json').write_text(json.dumps({'evidence_class':'INERT',
    'classification':'ADAPTATION','opening':opening,'caps':cap_records,'curbs':curbs,'curb_caps':cap_records_sky,'grooves':grooves,'panes':panes,
    'cap_top':top,'curb_top':curb_top,'ridge':curb_top+.46,'note':'Source-fitted skylight with real cap grooves; downstream main roof drainage remains unfinished.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('COURT ROOF TRIAL:',len(caps),'bounded caps around true hole;',len(sky),'closed curb, steel frame and six 6mm glass panes')

(OUT/'roof_bulkhead_caps_construction.json').write_text(json.dumps(dict(evidence_class='INERT',authority=['art/data/orison_v2/roof_source.json','game/data/orison_v2_blockout.json:dimensions'],parts=cap_records),indent=2)+'\n',encoding='utf-8',newline='\n')
