"""Source-derived F03-F05 remaining transfers; retained fabric remains uncut."""
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
top=levels['F03']-layout['dimensions']['slab_thickness'];components=[];beams=[];seats=[]
def box(name,b):components.append(dict(id=name,family='Steel',type='box',bounds=[round(v,5) for v in b]))
def prism(name,axis,points,low,high):
    vertices=[]
    for plane in [low,high]:
        for point in points:
            row=list(point);row.insert(axis,plane);vertices.append(row)
    b=[min(v[k] for v in vertices) for k in range(3)]+[max(v[k] for v in vertices) for k in range(3)]
    components.append(dict(id=name,family='Steel',type='triangular_prism',vertices=vertices,bounds=[round(v,5) for v in b]))
def rectangular(axis,start,end,low,high,wlo,whi):
    return [start,low,wlo,end,high,whi] if axis==0 else [wlo,low,start,whi,high,end]
def span(name,axis,left_source,right_source,wlo,whi,depth,target):
    left=bounds[left_source];right=bounds[right_source];waxis=2 if axis==0 else 0
    start=left[axis+3];end=right[axis];low=top-depth
    assert left[waxis]-.00001<=wlo<whi<=left[waxis+3]+.00001
    assert right[waxis]-.00001<=wlo<whi<=right[waxis+3]+.00001
    center=(wlo+whi)/2;half=(whi-wlo)/2
    rect=[start+.02,wlo,end-.02,whi] if axis==0 else [wlo,start+.02,whi,end-.02]
    beams.append(dict(id=name,rect=rect,top=top,low=low,axis=axis,target=target))
    box(name+'_Upper',rectangular(axis,start+.02,end-.02,top-.03,top,wlo,whi))
    box(name+'_Lower',rectangular(axis,start+.02,end-.02,low,low+.03,wlo,whi))
    box(name+'_Web',rectangular(axis,start+.02,end-.02,low+.03,top-.03,center-.008,center+.008))
    for side,face,direction,source in [('start',start,1,left_source),('end',end,-1,right_source)]:
        prefix=name+'_'+side
        a,b=sorted([face,face+direction*.02]);box(prefix+'_WallPlate',rectangular(axis,a,b,low-.30,top-.035,wlo,whi))
        a,b=sorted([face,face+direction*.30]);box(prefix+'_Seat',rectangular(axis,a,b,low-.02,low,wlo,whi))
        for i,off in enumerate([-(half-.045),half-.045]):
            points=[(face+direction*.018,low-.265),(face+direction*.018,low-.018),(face+direction*.275,low-.018)] if axis==0 else [(low-.265,face+direction*.018),(low-.018,face+direction*.018),(low-.018,face+direction*.275)]
            prism(prefix+'_Rib%d'%i,waxis,points,center+off-.004,center+off+.004)
        for i,(off,dy) in enumerate([(off,dy) for off in [-(half-.02),half-.02] for dy in [-.24,.20]]):
            at=center+off;y=low+dy
            a,b=sorted([face+direction*.02,face+direction*.023]);box(prefix+'_Anchor%d_Washer'%i,rectangular(axis,a,b,y-.0125,y+.0125,at-.0125,at+.0125))
            a,b=sorted([face+direction*.023,face+direction*.035]);box(prefix+'_Anchor%d_Head'%i,rectangular(axis,a,b,y-.009,y+.009,at-.009,at+.009))
        normal=[0,0,0];normal[axis]=direction
        point=[face,low-.1,center] if axis==0 else [center,low-.1,face]
        seats.append(dict(id=prefix,source=source,face_axis=axis,face=face,normal=normal,center=point,rect=[wlo,low-.30,whi,top-.035]))

all_components=[];all_beams=[];all_seats=[]
def capture_floor(floor):
    for original,target in [(components,all_components),(beams,all_beams),(seats,all_seats)]:
        for row in original:
            copy=dict(row);copy['id']=floor+'_'+copy['id'];target.append(copy)
upper=bounds['F03_SERVICE_HALL_west_ConstructionBound'];x=(upper[0]+upper[3])/2
span('ServiceWest',2,'F02_EAST_HALL_north_ConstructionBound','F02_C_KITCHEN_south_ConstructionBound',x-.175,min(x+.175,bounds['F02_C_KITCHEN_south_ConstructionBound'][3]),.45,'F03_SERVICE_HALL_west_ConstructionBound')
corner=bounds['F02_Corner_ConstructionBound.015']
span('ServiceNorth',0,'F02_C_BED2_east_ConstructionBound','F02_Corner_ConstructionBound.015',corner[2],corner[5],.30,'F03_SERVICE_HALL_north_ConstructionBound')
upper=bounds['F03_B_VESTIBULE_south_ConstructionBound'];z=(upper[2]+upper[5])/2
rooms={r['id']:r for r in layout['spaces']};half=layout['dimensions']['partition_wall']/2
# The first live preflight rejected 32 contacts with the retained kitchen
# north extension and vestibule south partition. Fit their actual 210 mm
# channel rather than extending a generic 350 mm profile through old fabric.
channel_south=rooms['F02_B_KITCHEN']['rect'][3]+half
channel_north=rooms['F02_B_VESTIBULE']['rect'][1]-half
assert abs(channel_south-upper[2])<.00001 and abs(channel_north-upper[5])<.00001
span('BVestSouth',0,'F02_SERVICE_HALL_SOUTH_east_ConstructionBound','F02_B_MAIN_west_ConstructionBound',channel_south,channel_north,.30,'F03_B_VESTIBULE_south_ConstructionBound')

capture_floor('F03')
components=[];beams=[];seats=[];top=levels['F04']-layout['dimensions']['slab_thickness']
vest=bounds['F03_A_VESTIBULE_north_ConstructionBound'];corner=bounds['F03_Corner_ConstructionBound.009']
start=bounds['F03_A_MAIN_east_ConstructionBound.001'][3];stop=corner[3];face=vest[5]
outer=bounds['F04_B_VESTIBULE_north_ConstructionBound'][5]
box('VestToe_Seat',[start,top-.02,face,stop,top,outer])
box('VestToe_WallPlate',[start,top-.30,face,stop,top-.02,face+.02])
for i in range(4):
    x=start+.12+(stop-start-.24)*i/3
    prism('VestToe_Rib%d'%i,0,[(top-.285,face+.018),(top-.018,face+.018),(top-.018,outer-.005)],x-.004,x+.004)
    for j,(dx,dy) in enumerate([(dx,dy) for dx in [-.02,.02] for dy in [-.24,-.08]]):
        at=x+dx;y=top+dy
        box('VestToe_Anchor%d_%d_Washer'%(i,j),[at-.0125,y-.0125,face+.02,at+.0125,y+.0125,face+.023])
        box('VestToe_Anchor%d_%d_Head'%(i,j),[at-.009,y-.009,face+.023,at+.009,y+.009,face+.035])
for label,lo,hi,source in [('Vest',start,vest[3],'F03_A_VESTIBULE_north_ConstructionBound'),('Corner',corner[0],stop,'F03_Corner_ConstructionBound.009')]:
    seats.append(dict(id='VestToe_'+label,source=source,face_axis=2,face=face,normal=[0,0,1],center=[(lo+hi)/2,top-.15,face],rect=[lo,top-.30,hi,top-.02]))
upper=bounds['F04_B_CLOSET_north_ConstructionBound'];z=(upper[2]+upper[5])/2
span('NorthTransfer',0,'F03_A_BED_east_ConstructionBound','F03_C_RESTRICTED_west_ConstructionBound',z-.175,z+.175,.30,'F04_B_ALCOVE_APPROACH_north_ConstructionBound/F04_B_CLOSET_north_ConstructionBound')
# Do not put a backplate against the front of an open I section. The branch
# flanges and web enter the main beam's actual flanges/web at a positive T union.
upper=bounds['F04_B_CLOSET_west_ConstructionBound'];x=(upper[0]+upper[3])/2
south=bounds['F03_A_BATH_north_ConstructionBound'][5];north=z+.02;low=top-.30
a=x-.175;e=x+.175
assert bounds['F03_A_BATH_north_ConstructionBound'][0]<=a<e<=bounds['F03_A_BATH_north_ConstructionBound'][3]
beams.append(dict(id='ClosetBranch',rect=[a,south+.02,e,north],top=top,low=low,axis=2,target='F04_B_CLOSET_west_ConstructionBound',connection='positive union into NorthTransfer flanges and web'))
box('ClosetBranch_Upper',[a,top-.03,south+.02,e,top,north]);box('ClosetBranch_Lower',[a,low,south+.02,e,low+.03,north]);box('ClosetBranch_Web',[x-.008,low+.03,south+.02,x+.008,top-.03,north])
prefix='ClosetBranch_start'
box(prefix+'_WallPlate',[a,low-.30,south,e,top-.035,south+.02]);box(prefix+'_Seat',[a,low-.02,south,e,low,south+.30])
for i,off in enumerate([-.13,.13]):prism(prefix+'_Rib%d'%i,0,[(low-.265,south+.018),(low-.018,south+.018),(low-.018,south+.275)],x+off-.004,x+off+.004)
for i,(off,dy) in enumerate([(off,dy) for off in [-.155,.155] for dy in [-.24,.20]]):
    at=x+off;y=low+dy
    box(prefix+'_Anchor%d_Washer'%i,[at-.0125,y-.0125,south+.02,at+.0125,y+.0125,south+.023])
    box(prefix+'_Anchor%d_Head'%i,[at-.009,y-.009,south+.023,at+.009,y+.009,south+.035])
seats.append(dict(id=prefix,source='F03_A_BATH_north_ConstructionBound',face_axis=2,face=south,normal=[0,0,1],center=[x,low-.10,south],rect=[a,low-.30,e,top-.035]))

capture_floor('F04')
components=[];beams=[];seats=[];top=levels['F05']-layout['dimensions']['slab_thickness']
left='F04_Corner_ConstructionBound.010';right='F04_Corner_ConstructionBound.012'
wlo=bounds[left][2];whi=bounds[left][5]
assert abs(wlo-bounds[right][2])<.00001 and abs(whi-bounds[right][5])<.00001
span('NorthTransfer',0,left,right,wlo,whi,.30,'F05_B_PRIVATE_HALL_north/F05_B_KITCHEN_north/F05_Corner.009')
# All steel beside the light slot stays west of its original X=-6.22 edge.
upper=bounds['F05_B_KITCHEN_east_ConstructionBound'];e=upper[3];a=e-.35;x=(a+e)/2
south=bounds['F04_B_CLOSET_north_ConstructionBound'][5];z=(wlo+whi)/2;north=z+.02;low=top-.30
assert bounds['F04_B_CLOSET_north_ConstructionBound'][0]<=a<e<=bounds['F04_B_CLOSET_north_ConstructionBound'][3]
beams.append(dict(id='KitchenBranch',rect=[a,south+.02,e,north],top=top,low=low,axis=2,target='F05_B_KITCHEN_east_ConstructionBound',connection='positive union into NorthTransfer flanges and web; original light-slot width retained'))
box('KitchenBranch_Upper',[a,top-.03,south+.02,e,top,north]);box('KitchenBranch_Lower',[a,low,south+.02,e,low+.03,north]);box('KitchenBranch_Web',[x-.008,low+.03,south+.02,x+.008,top-.03,north])
prefix='KitchenBranch_start'
box(prefix+'_WallPlate',[a,low-.30,south,e,top-.035,south+.02]);box(prefix+'_Seat',[a,low-.02,south,e,low,south+.30])
for i,off in enumerate([-.13,.13]):prism(prefix+'_Rib%d'%i,0,[(low-.265,south+.018),(low-.018,south+.018),(low-.018,south+.275)],x+off-.004,x+off+.004)
for i,(off,dy) in enumerate([(off,dy) for off in [-.155,.155] for dy in [-.24,.20]]):
    at=x+off;y=low+dy
    box(prefix+'_Anchor%d_Washer'%i,[at-.0125,y-.0125,south+.02,at+.0125,y+.0125,south+.023])
    box(prefix+'_Anchor%d_Head'%i,[at-.009,y-.009,south+.023,at+.009,y+.009,south+.035])
seats.append(dict(id=prefix,source='F04_B_CLOSET_north_ConstructionBound',face_axis=2,face=south,normal=[0,0,1],center=[x,low-.10,south],rect=[a,low-.30,e,top-.035]))
south_source='F04_B_VESTIBULE_north_ConstructionBound';north_source='F04_B_BATH_south_ConstructionBound'
east=bounds[north_source][3];west=east-.35
span('VestOffset',2,south_source,north_source,west,east,.30,'F05_B_VESTIBULE_east_ConstructionBound')
# A continuous widened upper flange, supported by true web-to-flange ribs,
# carries the east wall toe. It stops at the existing wet-stack Z=3.1 edge.
upper=bounds['F05_B_VESTIBULE_east_ConstructionBound'];outer=upper[3]
stack=next(r for r in layout['risers'] if r['id']=='WEST_WET_STACK')['rect']
start=bounds[south_source][5]+.02;stop=min(upper[5],stack[1]);center=(west+east)/2
assert abs(east-stack[0])<.00001 and stop<=stack[1]
box('VestOffset_WidenedUpper',[center,top-.03,start,outer,top,stop])
for i,at in enumerate([start+.18,stop-.18]):
    prism('VestOffset_ToeRib%d'%i,2,[(center+.002,low+.045),(center+.002,top-.024),(outer-.005,top-.024)],at-.004,at+.004)

capture_floor('F05')

components=all_components;beams=all_beams;seats=all_seats
plan=dict(evidence_class='INERT',method='Source-derived remaining F03-F05 wall transfers with retained-face brackets, continuous T junctions and offset wet-stack/light-slot boundaries. Physical construction contacts only; joint capacity, exterior grade, weather closure and whole-shell readiness remain open.',beams=beams,seats=seats,components=components,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest())
assert len(components)==233 and len(seats)==16
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('RemainingUpperTransferConstruction');bpy.context.scene.collection.children.link(construction);construction.hide_render=True;construction.hide_viewport=True
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
    if family=='Steel':assert islands==7,'Three F03 spans, one F04 ledger/T frame and two F05 offset/T frames'
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
        low=[min(p[k] for face in triangles for p in face) for k in range(3)];high=[max(p[k] for face in triangles for p in face) for k in range(3)]
        centre=[(low[k]+high[k])/2 for k in range(3)]
        # Bounded native parts retain their world bounds but store small local
        # coordinates. Float32 rounding at world X=8 collapsed a clipped face.
        mesh=bpy.data.meshes.new(name);mesh.from_pydata([(p[0]-centre[0],-(p[2]-centre[2]),p[1]-centre[1]) for face in triangles for p in face],[],[tuple(range(i,i+3)) for i in range(0,len(triangles)*3,3)]);mesh.update()
        # These are true clipped triangles of the already-beveled closed
        # assembly. Preserve their geometry and winding in open partitions.
        area_export+=sum(area([tuple(mesh.vertices[k].co) for k in face.vertices]) for face in mesh.polygons)
        for face,normal in zip(mesh.polygons,source_normals):
            assert face.normal.dot(normal)>.999,(name,'bounded fragment reversed its native outward face',face.index,face.normal,normal)
        mesh.normals_split_custom_set([source_normals[face.index] for face in mesh.polygons for _ in face.loop_indices])
        obj=bpy.data.objects.new(name,mesh);obj.location=(centre[0],-centre[2],centre[1]);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(mat);parts.append(obj)
        uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        chart_u=mesh.attributes.new(name='_AUTHORED_CHART_U',type='FLOAT_VECTOR',domain='CORNER')
        for poly in mesh.polygons:
            normal=source_normals[poly.index];axis=min([Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))],key=lambda v:abs(v.dot(normal)));u=(axis-normal*axis.dot(normal)).normalized();v=normal.cross(u).normalized()
            if family=='Steel':u=(u+v).normalized();v=normal.cross(u).normalized()
            for loop in poly.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),1.0+p.dot(v))
                chart_u.data[loop].vector=u
        low=[min(p[k] for face in triangles for p in face) for k in range(3)];high=[max(p[k] for face in triangles for p in face) for k in range(3)]
        assert max(high[k]-low[k] for k in range(3))<=4.000001
        reports.append(dict(id=name,family=family,bounds=low+high,native_triangles=len(mesh.polygons),internal_caps=False))
assert abs(area_before-area_after)<1e-5,(area_before,area_after)
assert abs(area_before-area_export)<1e-5,(area_before,area_export)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/remaining_upper_transfers.blend'))
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
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/props/remaining_upper_transfers.glb'),export_format='GLB',export_yup=True,export_tangents=True,export_attributes=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
print('Native chart tangents replacing undefined MikkTSpace directions',ExportUVHandedness.repaired_zero_tangents)
export_bytes=(root/'game/assets/props/remaining_upper_transfers.glb').read_bytes()
json_size=struct.unpack_from('<I',export_bytes,12)[0];export_json=json.loads(export_bytes[20:20+json_size])
export_triangles=sum(export_json['accessors'][p['indices']]['count']//3 for m in export_json['meshes'] for p in m['primitives'])
assert all(set(p['attributes'])=={'POSITION','NORMAL','TEXCOORD_0','TANGENT'} for m in export_json['meshes'] for p in m['primitives'])
assert export_triangles==sum(r['native_triangles'] for r in reports),'The export must retain every fabricated native triangle'
report=dict(source_native_sha256=hashlib.sha256(export_bytes).hexdigest(),evidence_class='INERT',source_plan=plan,parts=reports,grid_union_quads=total_quads,native_triangles=sum(r['native_triangles'] for r in reports),native_area_before_clip_m2=area_before,native_area_after_clip_m2=area_after,native_area_after_partition_cleanup_m2=area_export,source_layout_sha256_lf=hashlib.sha256((root/'game/data/orison_v2_blockout.json').read_text().replace('\r\n','\n').encode()).hexdigest(),source_masonry_sha256=hashlib.sha256((root/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest())
(root/'art/blender/remaining_upper_transfers_construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('INERT REMAINING UPPER TRANSFERS',len(parts),'parts',report['native_triangles'],'triangles','no internal culling caps','area delta',abs(area_before-area_after))
