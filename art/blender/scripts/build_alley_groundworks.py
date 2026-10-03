"""Source-fitted graded paving, open catches and grated boiler well.

Retained masonry, coping, lamps and runtime state are unchanged. The exported
trial replaces only paving/iron in the existing V2 alley module. External drain completion,
boiler-window ventilation and weather acceptance remain separate checks.
"""
from pathlib import Path
import collections
import hashlib
import json
import math
import importlib.util
import numpy as np
import bpy
import bmesh
from mathutils import Vector

root = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
base=root/'art/blender'
source=root/'art/blender/service_alley.blend'
layout_path=root/'game/data/orison_v2_blockout.json'
layout=json.loads(layout_path.read_text(encoding='utf-8'))
window=next(w for w in layout['windows'] if w['id']=='B1_BOILER_AIR_E')
spaces={r['id']:r for r in layout['spaces']}
front=next(d['center'][1] for d in layout['doors'] if d['id']=='F01_DOOR_06')
outer=spaces['F01_D_MAIN']['rect'][2]+2.35
back=spaces['F01_SERVICE_CORE']['rect'][3]+4.30
drain_x=outer-.25
drain_z=[front+1.2,2.0,back-.65]
inner_x=window['center'][0]+layout['dimensions']['outer_wall']-layout['dimensions']['partition_wall']/2
half=window['width']/2+layout['dimensions']['partition_wall']
z0,z1=window['center'][1]-half,window['center'][1]+half
assert [round(v,5) for v in [inner_x,outer,z0,z1]]==[15.93,18,2.46,3.94]
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version=0
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.data.materials[0].name not in ['Paving','Iron']:
        bpy.data.objects.remove(obj,do_unlink=True)
materials={}
for key,color in [('concrete',(.36,.35,.32,1)),('cast_iron',(.12,.12,.11,1))]:
    mat=bpy.data.materials.new('Groundworks_'+key);mat.diffuse_color=color;materials[key]=mat
for obj in bpy.context.scene.objects:
    obj['material_key']='concrete' if obj.data.materials[0].name=='Paving' else 'cast_iron'

def grade(x,z):
    east=.005*(abs(x-drain_x)-abs(16.8-drain_x))+.002*min(abs(z-at) for at in drain_z)-.001
    rear=.0008*(abs(x-drain_x)-abs(8.9-drain_x))+.0005*abs(z-drain_z[-1])
    t=max(0,min(1,(z-7.8)/(9.32-7.8)))
    return east*(1-t)+rear*t

grade_breaks=[(0,drain_x)] + [(1,-z) for z in drain_z]
grade_breaks += [(1,-(drain_z[0]+drain_z[1])/2),(1,-(drain_z[1]+drain_z[2])/2),(1,-7.8),(1,-9.32)]

def split_grade_planes(bm,obj):
    inv=obj.matrix_world.inverted()
    for axis,value in grade_breaks:
        normal=Vector((1,0,0) if axis==0 else (0,1,0))
        at=Vector((value,0,0) if axis==0 else (0,value,0))
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
            plane_co=inv@at,plane_no=normal,dist=1e-7)

def point(p):return Vector((p[0],-p[2],p[1]))

def box(name,bounds,key):
    a,low,b,c,high,d=bounds
    bpy.ops.mesh.primitive_cube_add(size=1,location=((a+c)/2,-(b+d)/2,(low+high)/2))
    obj=bpy.context.object;obj.name=name;obj.dimensions=(c-a,d-b,high-low)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj['material_key']=key
    obj.data.materials.append(materials[key])
    return obj

def difference(obj,cutter):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Source-owned void','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)

def intersects(obj,bounds):
    ps=[obj.matrix_world@Vector(p) for p in obj.bound_box]
    lo=[min(p.x for p in ps),min(p.z for p in ps),-max(p.y for p in ps)]
    hi=[max(p.x for p in ps),max(p.z for p in ps),-min(p.y for p in ps)]
    return all(hi[i]>bounds[i] and lo[i]<bounds[i+3] for i in range(3))

paving=[obj for obj in bpy.context.scene.objects if obj['material_key']=='concrete']
original_bounds={}
for obj in paving:
    ps=[obj.matrix_world@Vector(p) for p in obj.bound_box]
    original_bounds[obj.name]=[min(p.x for p in ps),min(p.z for p in ps),-max(p.y for p in ps),
                               max(p.x for p in ps),max(p.z for p in ps),-min(p.y for p in ps)]
cuts=[('BoilerWell',[inner_x,-.5,z0-.14,outer,.10,z1+.14])]
cuts += [('Catch_%d'%i,[drain_x-.151,-.5,z-.258,drain_x+.151,.10,z+.258]) for i,z in enumerate(drain_z)]
cut_owners=[]
for name,bounds in cuts:
    cutter=box(name+'_CUT',bounds,'concrete')
    for obj in paving:
        if intersects(obj,bounds):
            difference(obj,cutter);cut_owners.append({'cut':name,'retained_source':obj.name})
    bpy.data.objects.remove(cutter,do_unlink=True)

# Split top faces at grade changes, then retain flat foundation bottoms.
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith('DrainRecess'):
        bpy.data.objects.remove(obj,do_unlink=True);continue
    if obj not in paving and not obj.name.startswith('DrainBar'):continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    inv=obj.matrix_world.inverted()
    split_grade_planes(bm,obj)
    for vertex in bm.verts:
        p=obj.matrix_world@vertex.co
        if not obj.name.startswith('PavingFoundation') or p.z>-.299999:
            p.z+=grade(p.x,-p.y);vertex.co=inv@p
    bm.to_mesh(obj.data);bm.free()

wall_bounds=[]
def graded_wall(name,rect,low,high):
    a,b,c,d=rect
    obj=box(name,[a,low,b,c,high,d],'concrete')
    inv=obj.matrix_world.inverted()
    bm=bmesh.new();bm.from_mesh(obj.data);split_grade_planes(bm,obj)
    for vertex in bm.verts:
        p=obj.matrix_world@vertex.co
        if p.z>high-1e-6:p.z+=grade(p.x,-p.y)
        vertex.co=inv@p
    bm.to_mesh(obj.data);bm.free()
    wall_bounds.append({'id':name,'rect':rect,'bottom':low,'top_recipe':high})
    return obj

# Three sides and a floor below the existing boiler sill; the retained masonry
# remains the western side. The east upstand meets its existing wall at -0.30.
well_floor=-2.20
graded_wall('WellNorth',[inner_x,z0-.14,outer,z0],-2.45,-.04)
graded_wall('WellSouth',[inner_x,z1,outer,z1+.14],-2.45,-.04)
box('WellEast',[outer,-2.45,z0-.14,outer+.24,-.30,z1+.14],'concrete')
for name,rect in [('WellNorthBearing',[inner_x,z0-.14,outer,z0]),
                  ('WellSouthBearing',[inner_x,z1,outer,z1+.14])]:
    graded_wall(name,rect,-.04,0)

def funnel(name,rect,y_outer,y_inner,depth,cx,cz,radius):
    a,b,c,d=rect
    # Include every rectangle corner exactly. A uniform circular sample alone
    # truncates the outer corners and leaves gaps beneath the catch walls.
    angles=sorted({2*math.pi*i/24 for i in range(24)} |
                  {math.atan2(z-cz,x-cx)%(2*math.pi) for x,z in [(a,b),(c,b),(c,d),(a,d)]})
    n=len(angles)
    rings=[]
    for y,inner in [(y_outer,False),(y_inner,True),(y_inner-depth,True),(y_outer-depth,False)]:
        ring=[]
        for angle in angles:
            dx,dz=math.cos(angle),math.sin(angle)
            if inner:x,z=cx+radius*dx,cz+radius*dz
            else:
                tx=((c-cx)/dx if dx>0 else (a-cx)/dx) if abs(dx)>1e-8 else math.inf
                tz=((d-cz)/dz if dz>0 else (b-cz)/dz) if abs(dz)>1e-8 else math.inf
                scale=min(tx,tz);x,z=cx+scale*dx,cz+scale*dz
            ring.append(point((x,y,z)))
        rings.extend(ring)
    faces=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(rings,[],faces)
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    obj['material_key']='concrete';mesh.materials.append(materials['concrete'])
    return obj

funnel('WellFallingFloor',[inner_x,z0-.14,outer,z1+.14],well_floor,well_floor-.05,.12,drain_x,window['center'][1],.0635)
for i,z in enumerate(drain_z):
    g=grade(drain_x,z)
    for name,rect in [('West',[drain_x-.151,z-.258,drain_x-.12,z+.258]),
                      ('East',[drain_x+.12,z-.258,drain_x+.151,z+.258]),
                      ('North',[drain_x-.12,z-.258,drain_x+.12,z-.22]),
                      ('South',[drain_x-.12,z+.22,drain_x+.12,z+.258])]:
        graded_wall('Catch%d_%s'%(i,name),rect,-.65,-.005)
    funnel('Catch%d_FallingFloor'%i,[drain_x-.151,z-.258,drain_x+.151,z+.258],-.60+g,-.65+g,.10,drain_x,z,.0635)

def iron_at_grade(name,rect,low,high):
    obj=box(name,[rect[0],low,rect[1],rect[2],high,rect[3]],'cast_iron')
    inv=obj.matrix_world.inverted()
    bm=bmesh.new();bm.from_mesh(obj.data);split_grade_planes(bm,obj)
    for vertex in bm.verts:
        p=obj.matrix_world@vertex.co;p.z+=grade(p.x,-p.y);vertex.co=inv@p
    bm.to_mesh(obj.data);bm.free()
    return obj

# Two supported grating panels follow the source grade, with a central bearer.
for i in range(37):
    z=z0+.02+i*.04
    for j,(a,c) in enumerate([(inner_x,drain_x),(drain_x,outer)]):
        iron_at_grade('WellBar_%02d_%d'%(i,j),[a,z-.004,c,z+.004],-.035,0)
for x in [inner_x,drain_x,outer]:
    iron_at_grade('WellLongBearer',[x-.015,z0,x+.015,z1],-.095,-.035)
for z in [z0,z1]:
    iron_at_grade('WellEndBearing',[inner_x,z-.015,outer,z+.015],-.095,-.035)

collector_recipe_path=Path(__file__).with_name('alley_drain_collector_recipe.py')
recipe_spec=importlib.util.spec_from_file_location('alley_drain_collector_recipe',collector_recipe_path)
recipe_module=importlib.util.module_from_spec(recipe_spec);recipe_spec.loader.exec_module(recipe_module)
public_front=json.loads((root/'art/blender/front_pavement_construction.json').read_text(encoding='utf-8'))['envelope'][1]
collector=recipe_module.build_collector(point,box,materials,drain_x,drain_z,window['center'][1],well_floor,grade,public_front)

# Keep editable, individually closed source pieces. Partition exported faces
# by four-metre cells without inserting artificial caps between partitions.
groups=collections.defaultdict(list);proof=[];fully_removed=[];collapsed_world_triangles=[]
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    if not bm.faces:
        assert not bm.verts and obj.name in original_bounds,obj.name
        bounds=original_bounds[obj.name]
        containing=[name for name,cut in cuts if all(bounds[i]>=cut[i]-1e-6 and bounds[i+3]<=cut[i+3]+1e-6 for i in range(3))]
        assert containing,(obj.name,bounds)
        fully_removed.append({'id':obj.name,'original_bounds':bounds,'source_cuts':containing})
        bm.free();bpy.data.objects.remove(obj,do_unlink=True);continue
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not edge.is_manifold for edge in bm.edges)
    assert bad==0,(obj.name,bad)
    volume=bm.calc_volume(signed=True)
    assert volume>0,(obj.name,volume)
    proof.append({'id':obj.name,'nonmanifold_edges':bad,'volume_m3':volume})
    # Retain the repaired outward winding in the editable closed source, too.
    # Export partitioning below uses this same bmesh but does not rewrite it.
    bm.to_mesh(obj.data);obj.data.update()
    for axis in [0,1]:
        inv=obj.matrix_world.inverted()
        coords=[(obj.matrix_world@v.co)[axis] for v in bm.verts]
        for index in range(math.ceil(min(coords)/4),math.ceil(max(coords)/4)):
            at=Vector((index*4,0,0) if axis==0 else (0,index*4,0))
            normal=Vector((1,0,0) if axis==0 else (0,1,0))
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=inv@at,plane_no=normal,dist=1e-7)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
    # Exact booleans at coincident cut/substrate boundaries can leave triangles
    # of zero area after subdivision. They carry no surface or volume; omit
    # those numerical faces and orient the actual closed construction afresh.
    degenerate=[face for face in bm.faces if face.calc_area()<=1e-12]
    if degenerate:bmesh.ops.delete(bm,geom=degenerate,context='FACES_ONLY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
    for face in bm.faces:
        vertices=[obj.matrix_world@v.co for v in face.verts]
        world_area=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).length/2
        longest=max((vertices[i]-vertices[(i+1)%3]).length for i in range(3))
        altitude=2*world_area/longest if longest else 0
        # Grade-plane splits along a straight boundary can create almost
        # collinear triangles through float rounding. One micrometre is below
        # the ten-micrometre construction epsilon and all authored details.
        if altitude<=.000001:
            collapsed_world_triangles.append({'source':obj.name,'area_m2':world_area,'altitude_m':altitude})
            continue
        center=sum(vertices,Vector())/3
        key=(obj['material_key'],math.floor(center.x/4),math.floor(center.y/4))
        groups[key].append(vertices)
    bm.free()
construction=bpy.data.collections.new('AlleyGroundworksConstruction')
bpy.context.scene.collection.children.link(construction)
for obj in list(bpy.context.scene.objects):
    for collection in list(obj.users_collection):collection.objects.unlink(obj)
    construction.objects.link(obj)
construction.hide_render=True;construction.hide_viewport=True
parts=[];reports=[]
for (key,ix,iy),triangles in sorted(groups.items()):
    name='Groundworks_%s_%d_%d'%(key,ix,iy)
    origin=Vector((4*ix+2,4*iy+2,-.15))
    mesh=bpy.data.meshes.new(name)
    vertices=[p-origin for triangle in triangles for p in triangle]
    mesh.from_pydata(vertices,[],[(i,i+1,i+2) for i in range(0,len(vertices),3)]);mesh.update()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    tile=json.loads((root/'art/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials'][key]['meters_per_tile']
    for face in mesh.polygons:
        points=[mesh.vertices[i].co for i in face.vertices]
        guide=Vector((1,0,0)) if abs(face.normal.x)<.9 else Vector((0,1,0))
        u=(guide-face.normal*guide.dot(face.normal)).normalized();v=face.normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            if abs(face.normal.z)>.99:
                uv.data[loop].uv=(p.x+origin.x%tile,1+p.y+origin.y%tile)
            else:
                uv.data[loop].uv=(p.dot(u)+(origin.dot(u)%tile),1+p.dot(v)+(origin.dot(v)%tile))
    mesh.materials.append(materials[key])
    obj=bpy.data.objects.new(name,mesh);obj.location=origin
    bpy.context.scene.collection.objects.link(obj);parts.append(obj)
    reports.append({'id':name,'material':key,'triangles':len(mesh.polygons)})
path=base/'alley_groundworks.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportAnalyticPlanarTangents:
    count=0
    normals=None
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='POSITION':self.normals=None
        if attribute=='NORMAL':self.normals=np.asarray(data['data'],dtype=np.float64).copy()
        if attribute=='TANGENT':
            # These meshes use explicit planar metre charts. Derive their
            # tangent from that chart and the extracted normal, rather than
            # MikkTSpace's fallback on long, narrow Boolean bore triangles.
            # Blender's exporter has already rotated normals to glTF Y-up.
            n=self.normals
            assert n is not None and len(n)==len(data['data'])
            n/=np.linalg.norm(n,axis=1)[:,None]
            guides=np.tile([1.,0.,0.],(len(n),1))
            guides[np.abs(n[:,0])>=.9]=[0.,0.,-1.]
            tangent=guides-n*np.sum(guides*n,axis=1)[:,None]
            horizontal=np.abs(n[:,1])>.99
            tangent[horizontal]=np.column_stack((np.ones(horizontal.sum()),-n[horizontal,0]/n[horizontal,1],np.zeros(horizontal.sum())))
            tangent/=np.linalg.norm(tangent,axis=1)[:,None]
            signs=-np.ones(len(n));signs[horizontal]=-np.sign(n[horizontal,1])
            assert np.isfinite(tangent).all() and np.max(np.abs(np.sum(n*tangent,axis=1)))<1e-7
            data['data'][:,:3]=tangent;data['data'][:,3]=signs
            type(self).count+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportAnalyticPlanarTangents
asset=root/'game/assets/props/alley_groundworks.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportAnalyticPlanarTangents.count==len(parts)
metadata={'evidence_class':'INERT','parts':reports,'closed_source_pieces':proof,'cut_owners':cut_owners,'fully_removed_sources':fully_removed,
          'zero_area_world_triangles_omitted':collapsed_world_triangles,
          'well':[inner_x,z0,outer,z1],'well_floor':well_floor,'drain_centres':[[drain_x,z] for z in drain_z],
          'local_collector':collector,
          'grade_recipe':'east V crossfall .005 and nearest catch longitudinal .002 with -.001 datum; blend to rear .0008 crossfall from Z7.8 to9.32',
          'bindings':{'art/blender/service_alley.blend':hashlib.sha256(source.read_bytes()).hexdigest(),
                      'game/data/orison_v2_blockout.json':hashlib.sha256(layout_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()},
          'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
          'open':['Downstream street-main connection at the bolted property blank','Boiler air-window operating geometry','Joint-scale runoff and weather joins'],
          'note':'Fitted production construction, replacing only the original alley paving and iron owners. No new simulation or drainage-capacity verdict.'}
(base/'alley_groundworks_construction.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
print('INERT ALLEY GROUNDWORKS:',len(proof),'closed source pieces;',len(parts),'bounded parts;',sum(p['triangles'] for p in reports),'triangles',flush=True)

(root/'game/tests/fixtures/orison_alley_groundworks_construction.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
