"""Source-owned first-upper A rear-wing support; true bounded native surfaces."""
from pathlib import Path
import json,math,collections,hashlib,itertools,struct
import bpy,bmesh
from mathutils import Vector
root=Path(__file__).resolve().parents[3]
layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text());rooms={r['id']:r for r in layout['spaces']};levels={r['id']:r['y'] for r in layout['levels']}
lookup={}
with bpy.data.libraries.load(str(root/'art/blender/exterior_masonry.blend'),link=False) as (available,loaded):
    assert 'PreServiceMasonry' in available.collections
    loaded.collections=['PreServiceMasonry']
for obj in loaded.collections[0].objects:
    assert obj.type=='EMPTY' and obj.parent is None
    p=obj.location;s=obj.scale;at=[p.x,p.z,-p.y];size=[s.x,s.z,s.y]
    lookup[obj.name]=[at[i]-size[i]/2 for i in range(3)]+[at[i]+size[i]/2 for i in range(3)]
d=layout['dimensions'];half=d['partition_wall']/2;reach=d['outer_wall']-half;slab=d['slab_thickness'];top=levels['F02']-slab;low=top-.45
bed=rooms['F02_A_BED']['rect'];hall=rooms['F02_A_PRIVATE_HALL']['rect'];bath=rooms['F02_A_BATH']['rect'];common=rooms['F01_COMMON_B']['rect'];storage=rooms['B1_RESIDENT_STORAGE']['rect']
beams=[];components=[];columns=[]
def add(family,name,b):components.append(dict(family=family,id=name,bounds=[round(v,5) for v in b]))
def beam(name,r,axis):
    a,c,e,f=r;beams.append(dict(id=name,rect=r,axis=axis));fl=.035;web=.016
    add('Steel',name+'_Upper',[a,top-fl,c,e,top,f]);add('Steel',name+'_Lower',[a,low,c,e,low+fl,f])
    if axis==2:
        middle=(a+e)/2;add('Steel',name+'_Web',[middle-web/2,low+fl,c,middle+web/2,top-fl,f])
    else:
        middle=(c+f)/2;add('Steel',name+'_Web',[a,low+fl,middle-web/2,e,top-fl,middle+web/2])
west=[bed[0]-reach,common[3]+reach,bed[0]+half,bed[3]+reach]
north=[west[0],bed[3]-half,bed[2]+reach,bed[3]+reach]
east=[bed[2]-half,hall[3],bed[2]+reach,north[3]]
step=[hall[0],hall[3]-half,hall[2]+reach,hall[3]+reach]
hall_edge=lookup['F02_A_PRIVATE_HALL_east_ConstructionBound']
bath_edge=lookup['F02_A_BATH_north_ConstructionBound']
common_corner=lookup['F01_Corner_ConstructionBound.001']
hall_east=[hall[2]-half,max(hall_edge[2],round(common_corner[5],5)),hall[2]+reach,step[3]]
bath_north=[max(bath_edge[0],round(common_corner[3],5)),bath[3]-half,bath_edge[3],bath[3]+reach]
for name,r,axis in [('West',west,2),('North',north,0),('East',east,2),('Step',step,0),('HallEast',hall_east,2),('BathNorth',bath_north,0)]:beam(name,r,axis)
joint_x=(hall_east[0]+hall_east[2])/2
add('Steel','BathHall_JunctionWeb',[joint_x-.008,low+.035,(bath_north[1]+bath_north[3])/2,joint_x+.008,top-.035,hall_east[1]+.016])
middle_z=min((hall[3]+bed[3])/2,storage[3]-.4)
beam('BedroomCross',[west[0],middle_z-.175,east[2],middle_z+.175],0)
west_x=(west[0]+west[2])/2;east_x=(east[0]+east[2])/2;north_z=(north[1]+north[3])/2
base_y=levels['F01'];cap_y=low
positions=[('WestSouth',west_x,bed[1]+.1,'external'),('WestMiddle',west_x,middle_z,'external'),('WestNorth',west_x,north_z,'external'),('BedroomMiddle',(west_x+east_x)/2,middle_z,'external'),('EastNorth',east_x,north_z,'external'),('EastMiddle',east_x,middle_z,'storage_edge'),('EastSouth',east_x,(step[1]+step[3])/2,'storage_edge'),('Step',(hall_east[0]+hall_east[2])/2,(step[1]+step[3])/2,'storage_ceiling'),('Bath',bath_north[2]-.175,(bath_north[1]+bath_north[3])/2,'storage_ceiling')]
found=json.loads((root/'art/blender/orison_foundations_construction.json').read_text())['source_plan']
def subtract(r,c):
    a,b,d,e=r;x,y,z,w=c;lo=max(a,x);hi=min(d,z);bottom=max(b,y);top_=min(e,w)
    if lo>=hi-1e-7 or bottom>=top_-1e-7:return [r]
    return [p for p in [(a,b,lo,e),(hi,b,d,e),(lo,b,hi,bottom),(lo,top_,hi,e)] if p[2]-p[0]>1e-6 and p[3]-p[1]>1e-6]
for name,x,z,base_owner in positions:
    columns.append(dict(id=name,center=[round(x,5),base_y,round(z,5)],base_owner=base_owner))
    add('Steel',name+'_Base',[x-.13,base_y,z-.13,x+.13,base_y+.02,z+.13]);add('Steel',name+'_Cap',[x-.13,cap_y-.02,z-.13,x+.13,cap_y,z+.13])
    add('Steel',name+'_WestFlange',[x-.09,base_y+.02,z-.09,x-.07,cap_y-.02,z+.09]);add('Steel',name+'_EastFlange',[x+.07,base_y+.02,z-.09,x+.09,cap_y-.02,z+.09]);add('Steel',name+'_Web',[x-.07,base_y+.02,z-.008,x+.07,cap_y-.02,z+.008])
    for j,(dx,dz) in enumerate([(-.11,-.11),(-.11,.11),(.11,-.11),(.11,.11)]):
        bx,bz=x+dx,z+dz;add('Steel',name+'_Washer%d'%j,[bx-.0125,base_y+.02,bz-.0125,bx+.0125,base_y+.023,bz+.0125]);add('Steel',name+'_AnchorHead%d'%j,[bx-.009,base_y+.023,bz-.009,bx+.009,base_y+.035,bz+.009])
    if base_owner=='external':
        add('Concrete',name+'_Pedestal',[x-.175,found['stem_y'][0],z-.175,x+.175,base_y,z+.175])
        pieces=[[x-.35,z-.35,x+.35,z+.35]]
        for mask in found['footings']:pieces=[s for p in pieces for s in subtract(p,mask)]
        for i,r in enumerate(pieces):add('Concrete',name+'_Pad%d'%i,[r[0],found['footing_y'][0],r[1],r[2],found['footing_y'][1],r[3]])
    elif base_owner=='storage_edge':
        # A missing slab edge above the existing basement west wall; do not
        # duplicate the retained ceiling volume inside x >= storage[0].
        add('Concrete',name+'_StorageEdge',[storage[0]-reach,base_y-slab,z-.13,storage[0],base_y,z+.13])

plan=dict(evidence_class='INERT',method='Source-derived rear-wing frame. Preserves existing shell, apertures, basement storage and wet stack; modeled construction only, without capacity or whole-shell acceptance.',beams=beams,columns=columns,components=components)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('RearWingConstruction');bpy.context.scene.collection.children.link(construction);construction.hide_render=True;construction.hide_viewport=True
for record in plan['components']:
    b=record['bounds'];obj=bpy.data.objects.new(record['id'],None);obj.empty_display_type='CUBE';obj.empty_display_size=.5;obj.location=((b[0]+b[3])/2,-(b[2]+b[5])/2,(b[1]+b[4])/2);obj.scale=(b[3]-b[0],b[5]-b[2],b[4]-b[1]);construction.objects.link(obj)
parts=[];reports=[];total_quads=0;area_before=0.;area_after=0.;area_export=0.
def clip(points,axis,plane,positive):
    result=[]
    for a,b in zip(points,points[1:]+points[:1]):
        da=(a[axis]-plane)*(1 if positive else -1);db=(b[axis]-plane)*(1 if positive else -1)
        if da>=-1e-10:result.append(a)
        if (da<0<db) or (db<0<da):
            t=(plane-a[axis])/(b[axis]-a[axis]);p=tuple(a[k]+t*(b[k]-a[k]) for k in range(3));result.append(p)
    return result
def area(points):
    a=[points[1][k]-points[0][k] for k in range(3)];b=[points[2][k]-points[0][k] for k in range(3)]
    return math.sqrt(sum(v*v for v in [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]))/2
for family,key in [('Steel','metal'),('Concrete','concrete')]:
    solids=[r['bounds'] for r in plan['components'] if r['family']==family]
    grids=[]
    for axis in range(3):
        values={b[k] for b in solids for k in [axis,axis+3]};values.update(4*i for i in range(math.floor(min(values)/4),math.ceil(max(values)/4)+1) if min(values)<4*i<max(values));grids.append(sorted(values))
    lookup=[{v:i for i,v in enumerate(g)} for g in grids];occupied=set()
    for b in solids:
        occupied.update(itertools.product(*(range(lookup[k][b[k]],lookup[k][b[k+3]]) for k in range(3))))
    xs,ys,zs=grids;faces=[]
    for ix,iy,iz in sorted(occupied):
        a,d=xs[ix:ix+2];b,e=ys[iy:iy+2];c,f=zs[iz:iz+2]
        for neighbor,face in [((ix-1,iy,iz),[(a,b,c),(a,b,f),(a,e,f),(a,e,c)]),((ix+1,iy,iz),[(d,b,c),(d,e,c),(d,e,f),(d,b,f)]),((ix,iy-1,iz),[(a,b,c),(d,b,c),(d,b,f),(a,b,f)]),((ix,iy+1,iz),[(a,e,c),(a,e,f),(d,e,f),(d,e,c)]),((ix,iy,iz-1),[(a,b,c),(a,e,c),(d,e,c),(d,b,c)]),((ix,iy,iz+1),[(a,b,f),(d,b,f),(d,e,f),(a,e,f)])]:
            if neighbor not in occupied:faces.append(face)
    total_quads+=len(faces)
    mesh=bpy.data.meshes.new(family+'Union');mesh.from_pydata([(p[0],-p[2],p[1]) for face in faces for p in face],[],[tuple(range(i,i+4)) for i in range(0,4*len(faces),4)]);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bm.normal_update();assert all(e.is_manifold for e in bm.edges)
    unseen=set(bm.verts);islands=0
    while unseen:
        islands+=1;stack=[unseen.pop()]
        while stack:
            vertex=stack.pop()
            for edge in vertex.link_edges:
                other=edge.other_vert(vertex)
                if other in unseen:unseen.remove(other);stack.append(other)
    if family=='Steel':assert islands==1,'Every post and beam must join the native frame'
    print(family,'connected native assemblies',islands)
    before=len(bm.faces);bmesh.ops.dissolve_limit(bm,angle_limit=.001,use_dissolve_boundaries=False,verts=list(bm.verts),edges=list(bm.edges),delimit=set());bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges))
    print(family,'grid quads',before,'true faces',len(bm.faces))
    if family=='Steel':
        bmesh.ops.bevel(bm,geom=[e for e in bm.edges if e.calc_face_angle(0)>1e-5],offset=.0015,segments=1,affect='EDGES',clamp_overlap=True)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
    assert all(e.is_manifold for e in bm.edges),'True external corners must retain a closed union'
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));assert all(f.calc_area()>1e-12 for f in bm.faces)
    bm.to_mesh(mesh);bm.free();mesh.update();native=bpy.data.objects.new(family+'ClosedNativeUnion',mesh);construction.objects.link(native)
    groups=collections.defaultdict(list)
    for poly in mesh.polygons:
        points=[(mesh.vertices[v].co.x,mesh.vertices[v].co.z,-mesh.vertices[v].co.y) for v in poly.vertices];area_before+=area(points)
        source_plane_normal=Vector((poly.normal.x,poly.normal.z,-poly.normal.y)).normalized()
        ranges=[range(math.floor(min(p[k] for p in points)/4),math.floor(max(p[k] for p in points)/4)+1) for k in range(3)]
        for index in itertools.product(*ranges):
            polygon=points
            for axis in range(3):
                polygon=clip(polygon,axis,index[axis]*4,True)
                if len(polygon)<3:break
                polygon=clip(polygon,axis,(index[axis]+1)*4,False)
                if len(polygon)<3:break
            for j in range(1,len(polygon)-1):
                triangle=[polygon[0],polygon[j],polygon[j+1]];size=area(triangle)
                if size>1e-12:
                    assert all(abs((Vector(p)-Vector(points[0])).dot(source_plane_normal))<.00003 for p in triangle),'Clipped vertices must retain their closed native source plane'
                    groups[index].append((triangle,tuple(poly.normal)));area_after+=size
    mat=bpy.data.materials.new(key);mat.diffuse_color=(.28,.27,.25,1) if family=='Steel' else (.36,.34,.30,1)
    for index,records in sorted(groups.items()):
        triangles=[r[0] for r in records];source_normals=[Vector(r[1]).normalized() for r in records]
        name=family+'_'+'_'.join('P%d'%v if v>=0 else 'N%d'%-v for v in index)
        mesh=bpy.data.meshes.new(name);mesh.from_pydata([(p[0],-p[2],p[1]) for face in triangles for p in face],[],[tuple(range(i,i+3)) for i in range(0,len(triangles)*3,3)]);mesh.update()
        # These are true clipped triangles of the already-beveled closed
        # assembly. Preserve their geometry and winding in open partitions.
        area_export+=sum(area([tuple(mesh.vertices[k].co) for k in face.vertices]) for face in mesh.polygons)
        for face,normal in zip(mesh.polygons,source_normals):
            assert face.normal.dot(normal)>.999,(name,'bounded fragment reversed its native outward face',face.index,face.normal,normal)
        mesh.normals_split_custom_set([source_normals[face.index] for face in mesh.polygons for _ in face.loop_indices])
        obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(mat);parts.append(obj)
        uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        for poly in mesh.polygons:
            normal=source_normals[poly.index];axis=min([Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))],key=lambda v:abs(v.dot(normal)));u=(axis-normal*axis.dot(normal)).normalized();v=normal.cross(u).normalized()
            if family=='Steel':u=(u+v).normalized();v=normal.cross(u).normalized()
            for loop in poly.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
        low=[min(p[k] for face in triangles for p in face) for k in range(3)];high=[max(p[k] for face in triangles for p in face) for k in range(3)]
        assert max(high[k]-low[k] for k in range(3))<=4.000001
        reports.append(dict(id=name,family=family,bounds=low+high,native_triangles=len(mesh.polygons),internal_caps=False))
assert abs(area_before-area_after)<1e-5,(area_before,area_after)
assert abs(area_before-area_export)<1e-5,(area_before,area_export)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/rear_wing_a_support.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
    partitions=0
    repaired_zero_tangents=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':self.normals=data['data'].copy()
        # Every generated chart has v = normal cross u. Its known positive
        # native sign becomes negative when glTF flips the active UV V axis.
        if attribute=='TANGENT':
            for i,row in enumerate(data['data']):
                if sum(float(v)*float(v) for v in row[:3])>.5:continue
                # MikkTSpace can return zero at a narrow bounded fragment.
                # Reconstruct its actual steel chart, in native Blender axes,
                # rather than exporting an undefined direction to the engine.
                n=self.normals[i];normal=Vector((n[0],-n[2],n[1])).normalized()
                axis=min([Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))],key=lambda v:abs(v.dot(normal)))
                u=(axis-normal*axis.dot(normal)).normalized();v=normal.cross(u).normalized();u=(u+v).normalized()
                row[:3]=(u.x,u.z,-u.y);type(self).repaired_zero_tangents+=1
            data['data'][:,3]=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/props/rear_wing_a_support.glb'),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
print('Native chart tangents replacing undefined MikkTSpace directions',ExportUVHandedness.repaired_zero_tangents)
export_bytes=(root/'game/assets/props/rear_wing_a_support.glb').read_bytes()
json_size=struct.unpack_from('<I',export_bytes,12)[0];export_json=json.loads(export_bytes[20:20+json_size])
export_triangles=sum(export_json['accessors'][p['indices']]['count']//3 for m in export_json['meshes'] for p in m['primitives'])
assert export_triangles==sum(r['native_triangles'] for r in reports),'The export must retain every fabricated native triangle'
report=dict(source_native_sha256=hashlib.sha256(export_bytes).hexdigest(),evidence_class='INERT',source_plan=plan,parts=reports,grid_union_quads=total_quads,native_triangles=sum(r['native_triangles'] for r in reports),native_area_before_clip_m2=area_before,native_area_after_clip_m2=area_after,native_area_after_partition_cleanup_m2=area_export,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest(),source_masonry_sha256=hashlib.sha256((root/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest())
(root/'art/blender/rear_wing_a_support_construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('A REAR WING SUPPORT',len(parts),'parts',report['native_triangles'],'triangles','no internal culling caps','area delta',abs(area_before-area_after))
