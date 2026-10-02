"""Source-derived upper wall seats; retained inner and outer fabric remains uncut."""
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
components=[];beams=[];seats=[]
def box(name,b):components.append(dict(id=name,family='Steel',type='box',bounds=[round(v,5) for v in b]))
def prism(name,points,low,high):
 vertices=[[x,p[0],p[1]] for x in [low,high] for p in points]
 b=[min(p[k] for p in vertices) for k in range(3)]+[max(p[k] for p in vertices) for k in range(3)]
 components.append(dict(id=name,family='Steel',type='triangular_prism',vertices=vertices,bounds=[round(v,5) for v in b]))
for level,lower,upper_name in [('F03','F02','F03_PUBLIC_CORE_west_ConstructionBound'),('F05','F04','F05_PUBLIC_CORE_west_ConstructionBound.001')]:
 upper=bounds[upper_name];x=(upper[0]+upper[3])/2
 south_name=lower+'_WEST_HALL_north_ConstructionBound';north_name=lower+'_C_STUDIO_south_ConstructionBound'
 south=bounds[south_name][5];north=bounds[north_name][2];top=levels[level]-layout['dimensions']['slab_thickness'];low=top-.30
 # Keep the beam and bracket face within the lower walls' shared actual width.
 a=x-.175;e=min(x+.175,bounds[south_name][3],bounds[north_name][3]);assert e-a>.34999
 name=level+'_CoreWest';rect=[a,south+.02,e,north-.02]
 beams.append(dict(id=name,rect=rect,top=top,low=low,axis=2))
 box(name+'_Upper',[a,top-.03,rect[1],e,top,rect[3]]);box(name+'_Lower',[a,low,rect[1],e,low+.03,rect[3]])
 box(name+'_Web',[x-.008,low+.03,rect[1],x+.008,top-.03,rect[3]])
 for end,face,direction,source in [('south',south,1,south_name),('north',north,-1,north_name)]:
  prefix=name+'_'+end;zlo,zhi=sorted([face,face+direction*.02]);box(prefix+'_WallPlate',[a,low-.30,zlo,e,top-.035,zhi])
  zlo,zhi=sorted([face,face+direction*.30]);box(prefix+'_Seat',[a,low-.02,zlo,e,low,zhi])
  for i,off in enumerate([-.13,.13]):prism(prefix+'_Rib%d'%i,[(low-.265,face+direction*.018),(low-.018,face+direction*.018),(low-.018,face+direction*.275)],x+off-.004,x+off+.004)
  for i,(dx,dy) in enumerate([(-.155,-.24),(-.155,.20),(.155,-.24),(.155,.20)]):
   bx=x+dx;y=low+dy;zlo,zhi=sorted([face+direction*.02,face+direction*.023]);box(prefix+'_Anchor%d_Washer'%i,[bx-.0125,y-.0125,zlo,bx+.0125,y+.0125,zhi])
   zlo,zhi=sorted([face+direction*.023,face+direction*.035]);box(prefix+'_Anchor%d_Head'%i,[bx-.009,y-.009,zlo,bx+.009,y+.009,zhi])
  seats.append(dict(id=prefix,source=source,face_axis=2,face=face,normal=[0,0,direction],center=[(a+e)/2,low-.10,face],rect=[a,low-.30,e,top-.035]))
upper=bounds['F05_C_MAIN_west_ConstructionBound'];inner=rooms['F04_C_MAIN'];half=layout['dimensions']['partition_wall']/2
assert 'west' in inner['wall_sides'] and 'west' not in inner['exterior_sides']
face=inner['rect'][0]-half;outer=upper[0];start=inner['rect'][1];stop=bounds['F04_C_MAIN_west_ConstructionBound'][2]
top=levels['F05']-layout['dimensions']['slab_thickness']
def box(name,b):components.append(dict(id=name,family='Steel',type='box',bounds=[round(v,5) for v in b]))
box('CWestToe_Seat',[outer,top-.02,start,face,top,stop])
box('CWestToe_WallPlate',[face-.02,top-.30,start,face,top-.02,stop])
for i in range(4):
 z=start+.12+(stop-start-.24)*i/3
 vertices=[[x,y,at] for at in [z-.004,z+.004] for x,y in [(face-.018,top-.285),(face-.018,top-.018),(outer+.005,top-.018)]]
 b=[min(p[k] for p in vertices) for k in range(3)]+[max(p[k] for p in vertices) for k in range(3)]
 components.append(dict(id='CWestToe_Rib%d'%i,family='Steel',type='triangular_prism',vertices=vertices,bounds=[round(v,5) for v in b]))
 for j,(dy,dz) in enumerate([(dy,dz) for dy in [-.24,-.08] for dz in [-.02,.02]]):
  y=top+dy;bz=z+dz
  box('CWestToe_Anchor%d_%d_Washer'%(i,j),[face-.023,y-.0125,bz-.0125,face-.02,y+.0125,bz+.0125])
  box('CWestToe_Anchor%d_%d_Head'%(i,j),[face-.035,y-.009,bz-.009,face-.023,y+.009,bz+.009])
seats.append(dict(id='CWestToe',source='F04_C_MAIN/WallWest',face_axis=0,face=face,normal=[-1,0,0],center=[face,top-.15,(start+stop)/2],rect=[top-.30,start,top-.02,stop]))

plan=dict(evidence_class='INERT',method='Source-derived repeated upper-core wall transfers and a fitted C west toe ledger against its actual retained inner partition. Construction contacts only; joint capacity, remaining upper supports, exterior grade, weather closure and whole-shell readiness remain open.',beams=beams,seats=seats,components=components,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest())
assert len(components)==92 and len(seats)==5
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('UpperWallSeatConstruction');bpy.context.scene.collection.children.link(construction);construction.hide_render=True;construction.hide_viewport=True
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
    if family=='Steel':assert islands==3,'Two repeated upper-core beams and one C west toe ledger'
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
        chart_u=mesh.attributes.new(name='_AUTHORED_CHART_U',type='FLOAT_VECTOR',domain='CORNER')
        for poly in mesh.polygons:
            normal=source_normals[poly.index];axis=min([Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))],key=lambda v:abs(v.dot(normal)));u=(axis-normal*axis.dot(normal)).normalized();v=normal.cross(u).normalized()
            if family=='Steel':u=(u+v).normalized();v=normal.cross(u).normalized()
            for loop in poly.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
                chart_u.data[loop].vector=u
        low=[min(p[k] for face in triangles for p in face) for k in range(3)];high=[max(p[k] for face in triangles for p in face) for k in range(3)]
        assert max(high[k]-low[k] for k in range(3))<=4.000001
        reports.append(dict(id=name,family=family,bounds=low+high,native_triangles=len(mesh.polygons),internal_caps=False))
assert abs(area_before-area_after)<1e-5,(area_before,area_after)
assert abs(area_before-area_export)<1e-5,(area_before,area_export)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/upper_wall_seats.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
    partitions=0
    repaired_zero_tangents=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='_AUTHORED_CHART_U':self.chart_u=data['data'].copy()
        if attribute=='NORMAL':self.normals=data['data'].copy()
        # Every generated chart has v = normal cross u. Its known positive
        # native sign becomes negative when glTF flips the active UV V axis.
        if attribute=='TANGENT':
            for i,row in enumerate(data['data']):
                if sum(float(v)*float(v) for v in row[:3])>.5:continue
                # MikkTSpace can return zero at a narrow bounded fragment.
                # Keep the exact authored direction, carried on the same
                # exported corner. Reselecting an axis from rounded normals
                # can rotate the chart at a nearly axis-aligned narrow face.
                assert len(self.chart_u)==len(data['data'])
                native=Vector(self.chart_u[i]);u=Vector((native.x,native.z,-native.y))
                normal=Vector(self.normals[i]).normalized()
                u=(u-normal*u.dot(normal)).normalized()
                assert u.length>.999
                row[:3]=u;type(self).repaired_zero_tangents+=1
            data['data'][:,3]=-1;type(self).partitions+=1
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        # This construction aid stays editable in the native source; only
        # its repaired standard TANGENT is needed by the runtime export.
        for primitive in mesh.primitives:
            assert '_AUTHORED_CHART_U' in primitive.attributes
            del primitive.attributes['_AUTHORED_CHART_U']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/props/upper_wall_seats.glb'),export_format='GLB',export_yup=True,export_tangents=True,export_attributes=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
print('Native chart tangents replacing undefined MikkTSpace directions',ExportUVHandedness.repaired_zero_tangents)
export_bytes=(root/'game/assets/props/upper_wall_seats.glb').read_bytes()
json_size=struct.unpack_from('<I',export_bytes,12)[0];export_json=json.loads(export_bytes[20:20+json_size])
export_triangles=sum(export_json['accessors'][p['indices']]['count']//3 for m in export_json['meshes'] for p in m['primitives'])
assert all(set(p['attributes'])=={'POSITION','NORMAL','TEXCOORD_0','TANGENT'} for m in export_json['meshes'] for p in m['primitives'])
assert export_triangles==sum(r['native_triangles'] for r in reports),'The export must retain every fabricated native triangle'
report=dict(source_native_sha256=hashlib.sha256(export_bytes).hexdigest(),evidence_class='INERT',source_plan=plan,parts=reports,grid_union_quads=total_quads,native_triangles=sum(r['native_triangles'] for r in reports),native_area_before_clip_m2=area_before,native_area_after_clip_m2=area_after,native_area_after_partition_cleanup_m2=area_export,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest(),source_masonry_sha256=hashlib.sha256((root/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest())
(root/'art/blender/upper_wall_seats_construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('INERT UPPER WALL SEATS',len(parts),'parts',report['native_triangles'],'triangles','no internal culling caps','area delta',abs(area_before-area_after))
