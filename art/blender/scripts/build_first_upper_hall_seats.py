"""Source-derived first-upper hall seats; retained wall faces remain uncut."""
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
bounds=lookup
top=levels['F02']-layout['dimensions']['slab_thickness'];components=[];beams=[];seats=[]
def box(name,b):
 components.append(dict(id=name,family='Steel',type='box',bounds=[round(v,5) for v in b]))
def prism(name,points,axis,low,high):
 vertices=[]
 for plane in [low,high]:
  for p in points:
   v=list(p);v.insert(axis,plane);vertices.append(v)
 b=[min(v[k] for v in vertices) for k in range(3)]+[max(v[k] for v in vertices) for k in range(3)]
 components.append(dict(id=name,family='Steel',type='triangular_prism',vertices=vertices,bounds=[round(v,5) for v in b]))
def anchor(name,x,y,z,direction):
 # Local normal X, with exposed washer and square head; no shaft is projected into retained masonry.
 lo,hi=sorted([x,x+direction*.003]);box(name+'_Washer',[lo,y-.0125,z-.0125,hi,y+.0125,z+.0125])
 lo,hi=sorted([x+direction*.003,x+direction*.015]);box(name+'_Head',[lo,y-.009,z-.009,hi,y+.009,z+.009])
for side in ['south','north']:
 wall=bounds['F02_EAST_HALL_'+side+'_ConstructionBound'];z=(wall[2]+wall[5])/2
 left_name='F01_LOBBY_east_ConstructionBound.001' if side=='south' else 'F01_PUBLIC_CORE_east_ConstructionBound'
 right_name='F01_SERVICE_HALL_west_ConstructionBound.001'
 left=bounds[left_name][3];right=bounds[right_name][0]
 rect=[left+.02,z-.175,right-.02,z+.175];low=top-.30
 beams.append(dict(id='East_'+side,rect=rect,top=top,low=low,axis=0))
 a,c,e,f=rect;box('East_'+side+'_Upper',[a,top-.03,c,e,top,f]);box('East_'+side+'_Lower',[a,low,c,e,low+.03,f]);box('East_'+side+'_Web',[a,low+.03,z-.008,e,top-.03,z+.008])
 for end,face,direction,source in [('west',left,1,left_name),('east',right,-1,right_name)]:
  name='East_'+side+'_'+end;lo,hi=sorted([face,face+direction*.02])
  box(name+'_WallPlate',[lo,low-.30,z-.20,hi,top-.035,z+.20])
  lo,hi=sorted([face,face+direction*.30]);box(name+'_Seat',[lo,low-.02,z-.175,hi,low,z+.175])
  for i,off in enumerate([-.13,.13]):
   prism(name+'_Rib%d'%i,[(face+direction*.018,low-.265),(face+direction*.018,low-.018),(face+direction*.275,low-.018)],2,z+off-.004,z+off+.004)
  for i,(dy,dz) in enumerate([(-.24,-.16),(-.24,.16),(.20,-.16),(.20,.16)]):anchor(name+'_Anchor%d'%i,face+direction*.02,low+dy,z+dz,direction)
  seats.append(dict(id=name,source=source,face_axis=0,face=face,normal=[direction,0,0],center=[face,low-.10,z],rect=[low-.30,z-.20,top-.035,z+.20]))
watch=bounds['F01_WATCH_north_ConstructionBound'];upper=bounds['F02_WEST_HALL_north_ConstructionBound'];face=watch[5]
# Fit the narrow unsupported toe only; the original wall continues to carry its old footprint.
a=max(watch[0],upper[0]);e=upper[3];outer=upper[5]+.05
package=bounds['F01_PACKAGE_east_ConstructionBound']
# The package return includes the retained inner partition collider as well as
# the editable outer leaf. Its inner strip already owns the short west interval;
# live preflight one rejected all eleven redundant components there.
for segment,(start,stop) in enumerate([(package[3],e)]):
 assert stop>start
 prefix='WestHall_%d'%segment
 box(prefix+'_ToeSeat',[start,top-.02,face,stop,top,outer]);box(prefix+'_WallPlate',[start,top-.28,face,stop,top-.02,face+.02])
 positions=[(start+stop)/2] if stop-start<.36 else [start+.18+(stop-start-.36)*i/3 for i in range(4)]
 for i,x in enumerate(positions):
  prism(prefix+'_Rib%d'%i,[(top-.265,face+.018),(top-.018,face+.018),(top-.018,outer-.005)],0,x-.004,x+.004)
  for j,(dx,y) in enumerate([(dx,y) for dx in [-.02,.02] for y in [top-.23,top-.08]]):
   bx=x+dx
   box(prefix+'_Anchor%d_%d_Washer'%(i,j),[bx-.0125,y-.0125,face+.02,bx+.0125,y+.0125,face+.023])
   box(prefix+'_Anchor%d_%d_Head'%(i,j),[bx-.009,y-.009,face+.023,bx+.009,y+.009,face+.035])
 seats.append(dict(id=prefix,source='F01_WATCH_north_ConstructionBound',face_axis=2,face=face,normal=[0,0,1],center=[(start+stop)/2,top-.14,face],rect=[start,top-.28,stop,top-.02]))
plan=dict(evidence_class='INERT',method='Source-derived bracket-supported hall beams and a narrow watch-wall toe ledger. Retained inner and outer wall fabric keeps its owner. Modeled construction only; no joint capacity or whole-shell readiness acceptance.',beams=beams,seats=seats,components=components,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest())

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('HallSeatConstruction');bpy.context.scene.collection.children.link(construction);construction.hide_render=True;construction.hide_viewport=True
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
    solids=[r['bounds'] for r in plan['components'] if r['family']==family and r['type']=='box']
    if not solids:continue
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
    if family=='Steel':assert islands==3,'Two bracket-supported beams and one ledger beyond the retained inner and outer package return'
    print(family,'connected native assemblies',islands)
    before=len(bm.faces);bmesh.ops.dissolve_limit(bm,angle_limit=.001,use_dissolve_boundaries=False,verts=list(bm.verts),edges=list(bm.edges),delimit=set());bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges))
    print(family,'grid quads',before,'true faces',len(bm.faces))
    # Union actual triangular gusset prisms with positive overlap only into new
    # steel plates. Old masonry is neither loaded into this Boolean nor changed.
    bm.to_mesh(mesh);bm.free();mesh.update()
    carrier=bpy.data.objects.new('BooleanCarrier',mesh);bpy.context.scene.collection.objects.link(carrier)
    bpy.context.view_layer.objects.active=carrier;carrier.select_set(True)
    for record in plan['components']:
        if record['type']!='triangular_prism':continue
        rib_mesh=bpy.data.meshes.new(record['id'])
        rib_mesh.from_pydata([(p[0],-p[2],p[1]) for p in record['vertices']],[],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)])
        rib_mesh.update();rib_bm=bmesh.new();rib_bm.from_mesh(rib_mesh);bmesh.ops.recalc_face_normals(rib_bm,faces=list(rib_bm.faces));rib_bm.to_mesh(rib_mesh);rib_bm.free()
        rib=bpy.data.objects.new(record['id'],rib_mesh);bpy.context.scene.collection.objects.link(rib)
        modifier=carrier.modifiers.new(record['id'],'BOOLEAN');modifier.operation='UNION';modifier.solver='EXACT';modifier.object=rib
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(rib,do_unlink=True)
    mesh=carrier.data;bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges))
    assert all(e.is_manifold for e in bm.edges),'Actual gusset unions must stay closed'
    bpy.data.objects.remove(carrier,do_unlink=True)
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
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/first_upper_hall_seats.blend'))
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
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/props/first_upper_hall_seats.glb'),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
print('Native chart tangents replacing undefined MikkTSpace directions',ExportUVHandedness.repaired_zero_tangents)
export_bytes=(root/'game/assets/props/first_upper_hall_seats.glb').read_bytes()
json_size=struct.unpack_from('<I',export_bytes,12)[0];export_json=json.loads(export_bytes[20:20+json_size])
export_triangles=sum(export_json['accessors'][p['indices']]['count']//3 for m in export_json['meshes'] for p in m['primitives'])
assert export_triangles==sum(r['native_triangles'] for r in reports),'The export must retain every fabricated native triangle'
report=dict(source_native_sha256=hashlib.sha256(export_bytes).hexdigest(),evidence_class='INERT',source_plan=plan,parts=reports,grid_union_quads=total_quads,native_triangles=sum(r['native_triangles'] for r in reports),native_area_before_clip_m2=area_before,native_area_after_clip_m2=area_after,native_area_after_partition_cleanup_m2=area_export,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest(),source_masonry_sha256=hashlib.sha256((root/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest())
(root/'art/blender/first_upper_hall_seats_construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('INERT FIRST-UPPER HALL SEATS',len(parts),'parts',report['native_triangles'],'triangles','no internal culling caps','area delta',abs(area_before-area_after))
