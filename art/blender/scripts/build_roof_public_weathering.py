"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
import bpy
import bmesh
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=ROOT/'art/blender'
OUT.mkdir(parents=True,exist_ok=True)
MODEL=ROOT/'game/assets/props/roof_public_weathering.glb'
plan_path=ROOT/'art/data/roof_public_weather/source_plan.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'))
assert plan['schema']=='orison.public-roof-weather.v1' and plan['classification']=='ADAPTATION'
layout_path=ROOT/'game/data/orison_v2_blockout.json'
roof_path=ROOT/'art/data/orison_v2/roof_source.json'
layout=json.loads(layout_path.read_text(encoding='utf-8'))
roof=json.loads(roof_path.read_text(encoding='utf-8'))
room=next(r for r in roof['records']['spaces'] if r['id']==plan['room_owner'])
assert room in layout['spaces'] and not room['no_ceiling']
y=roof['records']['levels'][0]['y']
bottom=y+layout['dimensions']['clear_height']
cap_top=bottom+layout['dimensions']['slab_thickness']
half=layout['dimensions']['partition_wall']/2
r=room['rect'];x0,z0,x1,z1=r[0]-half,r[1]-half,r[2]+half,r[3]+half

# Adaptation dimensions, not a hydraulic or structural capacity specification.
sheet=plan['sheet_thickness'];roof_fall=plan['roof_fall'];toe=plan['bearing_toe']
gutter_radius=plan['gutter_radius'];gutter_wall=plan['gutter_wall'];gutter_fall=plan['gutter_fall']
leader_inner=plan['leader_bore_radius'];leader_wall=plan['leader_wall'];leader_outer=leader_inner+leader_wall
gutter_x=x1+plan['gutter_wall_offset'];outlet_z=z1-plan['outlet_end_offset']
gutter_low=cap_top-plan['gutter_low_offset']
field=json.loads((ROOT/'art/blender/roof_drainage_falls_construction.json').read_bytes())
ports=json.loads((ROOT/'art/blender/roof_drainage_ports_construction.json').read_bytes())['ports']
field_points=np.array(field['points'],dtype=np.float64)
field_faces=np.array(field['triangles_by_vertex'],dtype=np.int32)
field_triangles=field_points[field_faces][:,:,[0,2]]
field_planes=np.array([np.linalg.solve(np.c_[field_points[t][:,[0,2]],np.ones(3)],field_points[t][:,1]) for t in field_faces])
field_buckets={};field_edges={}
for i,tri in enumerate(field_triangles):
    lo=tri.min(axis=0)-.00002;hi=tri.max(axis=0)+.00002
    for ix in range(math.floor(lo[0]/.5),math.floor(hi[0]/.5)+1):
        for iz in range(math.floor(lo[1]/.5),math.floor(hi[1]/.5)+1):field_buckets.setdefault((ix,iz),[]).append(i)
    for a,b in zip(tri,np.roll(tri,-1,axis=0)):
        key=tuple(sorted((tuple(a),tuple(b))));field_edges[key]=(a,b)
def roof_height(x,z):
    at=np.array([x,z]);candidates=field_buckets.get((math.floor(x/.5),math.floor(z/.5)),[])
    for index in candidates:
        t=field_triangles[index];a=t[1]-t[0];b=t[2]-t[0];q=at-t[0];det=a[0]*b[1]-a[1]*b[0]
        u=(q[0]*b[1]-q[1]*b[0])/det;v=(a[0]*q[1]-a[1]*q[0])/det
        if u>=-.00015 and v>=-.00015 and u+v<=1.00015:return float(field_planes[index]@np.array([x,z,1.]))
    raise AssertionError(('No physical roof under fitted flashing',x,z))

roof_deck_y=y
fitted_field_y=roof_height(gutter_x,outlet_z)
fitted_foot_y=fitted_field_y+.0012
parts=[];records=[];closed=[]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
materials={}
for key,color in [('galvanized_roof',(.30,.32,.32,1)),('concrete',(.36,.35,.32,1))]:
    mat=bpy.data.materials.new(key);mat.diffuse_color=color;mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=color
    shader.inputs['Metallic'].default_value=.65 if key=='galvanized_roof' else 0
    shader.inputs['Roughness'].default_value=.48 if key=='galvanized_roof' else .85
    materials[key]=mat

def point(p):return Vector((p[0],-p[2],p[1]))
def godot(p):return [p[0],p[2],-p[1]]
def mesh_object(name,vertices,faces,key,hidden=False,recalculate=True):
    assert key in materials,key
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([point(v) for v in vertices],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(materials[key]);obj['material_key']=key
    if recalculate:
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        normal=Vector(face.normal).normalized()
        # Per-face orthonormal projection gives true metres on curved facets,
        # sloping roof skins and narrow folded returns, without dominant-axis shrink.
        seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=(p.dot(u),p.dot(v))
    if hidden:
        obj.hide_render=True;obj.hide_set(True);closed.append(obj)
    else:parts.append(obj)
    return obj

def _uncut_rectangular_prism(name,rect,low,high,key,omit_bottom=False):
    a,b,c,d=rect
    vertices=[(a,low(a,b),b),(c,low(c,b),b),(c,low(c,d),d),(a,low(a,d),d),
              (a,high(a,b),b),(c,high(c,b),b),(c,high(c,d),d),(a,high(a,d),d)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    if omit_bottom:
        construction=mesh_object(name+'_ClosedConstruction',vertices,faces,key,True)
        bm=bmesh.new();bm.from_mesh(construction.data)
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
        bm.free();faces=faces[1:]
    obj=mesh_object(name,vertices,faces,key)
    records.append({'id':name,'key':key,'rect':rect,'role':'tapered bearing' if omit_bottom else 'sheet roof','omit_retained_bottom':omit_bottom})
    return obj

def subtract_rect(rect,hole):
    a,b,c,d=rect;u,v,w,t=hole
    ix0=max(a,u);iz0=max(b,v);ix1=min(c,w);iz1=min(d,t)
    if ix0>=ix1 or iz0>=iz1:return [rect]
    return [r for r in [[a,b,ix0,d],[ix1,b,c,d],[ix0,b,ix1,iz0],[ix0,iz1,ix1,d]] if r[2]-r[0]>1e-8 and r[3]-r[1]>1e-8]

curb=plan['curb_outer_rect'];apron=plan['flashing_apron']
cricket=[curb[0]-plan['cricket_width'],curb[1]-apron,curb[0],curb[3]+apron]
apron_rectangles=[('South',[curb[0]-apron,curb[1]-apron,curb[2]+apron,curb[1]]),
    ('North',[curb[0]-apron,curb[3],curb[2]+apron,curb[3]+apron]),
    ('East',[curb[2],curb[1],curb[2]+apron,curb[3]]),
    ('West',[curb[0]-apron,curb[1],curb[0],curb[3]])]
def rectangular_prism(name,rect,low,high,key,omit_bottom=False):
    if not name.startswith(('PublicRoofBearing_','PublicRoofSheet_','PublicRoofSeam_')):
        return _uncut_rectangular_prism(name,rect,low,high,key,omit_bottom)
    regions=[rect]
    holes=[curb,cricket]
    if not omit_bottom:holes += [r for _,r in apron_rectangles]
    for hole in holes:regions=[piece for region in regions for piece in subtract_rect(region,hole)]
    result=[]
    for i,region in enumerate(regions):result.append(_uncut_rectangular_prism(name+'_AroundCourt'+str(i),region,low,high,key,omit_bottom))
    return result

def roof_y(x,z):return cap_top+toe+roof_fall*(x1-x)
def constant(value):return lambda x,z:value

# Three independently culled support wedges seat on the original concrete cap.
# Hidden native construction is closed; runtime omits only that shared bottom.
span=plan['maximum_partition_span']
nx=math.ceil((x1-x0)/span);nz=math.ceil((z1-z0)/span)
for ix in range(nx):
    for iz in range(nz):
        rect=[x0+(x1-x0)*ix/nx,z0+(z1-z0)*iz/nz,x0+(x1-x0)*(ix+1)/nx,z0+(z1-z0)*(iz+1)/nz]
        rectangular_prism('PublicRoofBearing_%d_%d'%(ix,iz),rect,constant(cap_top),roof_y,'concrete',True)

# Individual flat-lapped sheets. Laps face downhill, no raised dam across runoff.
sx=math.ceil((x1-x0)/plan['sheet_width']);sz=math.ceil((z1-z0)/plan['sheet_length'])
seam=plan['seam_half_width']
for ix in range(sx):
    for iz in range(sz):
        a=x0+(x1-x0)*ix/sx;c=x0+(x1-x0)*(ix+1)/sx
        b=z0+(z1-z0)*iz/sz;d=z0+(z1-z0)*(iz+1)/sz
        # Flush soldered joints occupy the seam strips themselves; they do not
        # make a raised transverse dam across the roof fall.
        panel_a=a+seam if ix>0 else a
        panel_c=c-seam if ix<sx-1 else c
        rectangular_prism('PublicRoofSheet_%02d_%02d'%(ix,iz),[panel_a,b,panel_c,d],roof_y,lambda x,z:roof_y(x,z)+sheet,'galvanized_roof')
        if ix>0:
            rectangular_prism('PublicRoofSeam_%02d_%02d'%(ix,iz),[a-seam,b,a+seam,d],roof_y,
                              lambda x,z:roof_y(x,z)+sheet,'galvanized_roof')

# Four triangular facets fill the clipped upstream rectangle. The two raised
# facets divert water to the two diagonal valleys; the valleys fall toward the
# curb corners, outside the flashing upstands. The outer fillers retain X fall.
def clip_polygon(polygon,rect):
    result=list(polygon)
    for axis,bound,inside in [(0,rect[0],1),(0,rect[2],-1),(1,rect[1],1),(1,rect[3],-1)]:
        old=result;result=[]
        if not old:break
        previous=old[-1];prev_inside=inside*(previous[axis]-bound)>=-1e-10
        for current in old:
            curr_inside=inside*(current[axis]-bound)>=-1e-10
            if curr_inside!=prev_inside:
                t=(bound-previous[axis])/(current[axis]-previous[axis])
                result.append(tuple(previous[i]+t*(current[i]-previous[i]) for i in [0,1]))
            if curr_inside:result.append(current)
            previous=current;prev_inside=curr_inside
    clean=[]
    for p in result:
        if not clean or math.dist(p,clean[-1])>1e-8:clean.append(p)
    if len(clean)>1 and math.dist(clean[0],clean[-1])<1e-8:clean.pop()
    return clean

def subtract_polygon(polygon,hole):
    a,b,c,d=hole
    regions=[[-1e6,-1e6,a,1e6],[c,-1e6,1e6,1e6],[a,-1e6,c,b],[a,d,c,1e6]]
    return [p for r in regions if len(p:=clip_polygon(polygon,r))>=3]

def triangular_prism(name,polygon,low,high,key,omit_bottom=False):
    vertices=[(x,fn(x,z),z) for fn in [low,high] for x,z in polygon]
    faces=[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
    if omit_bottom:
        obj=mesh_object(name+'_ClosedConstruction',vertices,faces,key,True)
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
        bm.free();faces=faces[1:]
    obj=mesh_object(name,vertices,faces,key)
    records.append({'id':name,'key':key,'polygon':polygon,'role':'cricket bearing' if omit_bottom else 'cricket sheet',
                    'omit_retained_bottom':omit_bottom})
    return obj

def plane_for(points,heights):
    matrix=np.array([[x,z,1] for x,z in points],dtype=np.float64)
    coefficients=np.linalg.solve(matrix,np.asarray(heights,dtype=np.float64))
    return lambda x,z:float(coefficients[0]*x+coefficients[1]*z+coefficients[2])

mid=(curb[1]+curb[3])*.5
ws=(cricket[0],cricket[1]);es=(cricket[2],cricket[1]);wm=(cricket[0],mid)
em=(cricket[2],mid);en=(cricket[2],cricket[3]);wn=(cricket[0],cricket[3])
facets=[]
for label,polygon,raised in [('SouthFiller',[ws,es,wm],False),('SouthCricket',[wm,es,em],True),
    ('NorthCricket',[wm,em,en],True),('NorthFiller',[wm,en,wn],False)]:
    heights=[roof_y(x,z)+(plan['cricket_rise'] if raised and (x,z)==em else 0) for x,z in polygon]
    surface=plane_for(polygon,heights);facets.append((label,polygon,surface))
    triangular_prism('PublicRoofCricketBearing_'+label,polygon,constant(cap_top),surface,'concrete',True)
    skins=[polygon]
    for _,rect in apron_rectangles:skins=[p for skin in skins for p in subtract_polygon(skin,rect)]
    for k,skin in enumerate(skins):
        for j in range(1,len(skin)-1):
            points=[skin[0],skin[j],skin[j+1]]
            area=abs(float(np.linalg.det(np.asarray([np.asarray(points[1])-points[0],np.asarray(points[2])-points[0]]))))*.5
            if area>1e-10:triangular_prism('PublicRoofCricketSheet_'+label+str(k)+'_'+str(j),points,surface,lambda x,z:surface(x,z)+sheet,'galvanized_roof')

def profile_sweep(name,profile,stations,key,closed_ends=True):
    # profile: (X,Y) cross-section; station supplies Z and vertical shift.
    vertices=[(x,h+shift,z) for z,shift in stations for x,h in profile]
    n=len(profile);faces=[]
    for j in range(len(stations)-1):
        faces.extend([(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n)])
    if closed_ends:faces += [tuple(reversed(range(n))),tuple(range((len(stations)-1)*n,len(stations)*n))]
    return mesh_object(name,vertices,faces,key)

# Folded upstand/cover returns stop roof water at the three non-draining edges.
# Their wall skirts physically lap the retained cap edge, with a small drip hem.
for side,x in [('West',x0),('East',x1)]:
    if side=='East':continue  # The east apron feeds the open gutter.
    top=roof_y(x,0)+sheet
    profile=[(x-.0012,cap_top-.15),(x-.0012,top+.018),(x+.025,top+.018),
             (x+.025,top+.0168),(x,top+.0168),(x,cap_top-.15)]
    for i in range(nz):
        a=z0+(z1-z0)*i/nz;b=z0+(z1-z0)*(i+1)/nz
        profile_sweep('PublicRoofWestReturn_%d'%i,profile,[(a,0),(b,0)],'galvanized_roof')
for side,z in [('South',z0),('North',z1)]:
    # A closed sheet strip follows the X fall while covering the actual cap face.
    for i in range(sx):
        a=x0+(x1-x0)*i/sx;c=x0+(x1-x0)*(i+1)/sx
        sign=-1 if side=='South' else 1
        vertices=[]
        for x in [a,c]:
            top=roof_y(x,z)+sheet
            vertices += [(x,cap_top-.15,z+sign*.0012),(x,top+.018,z+sign*.0012),
                         (x,top+.018,z-sign*.025),(x,top+.0168,z-sign*.025),
                         (x,top+.0168,z),(x,cap_top-.15,z)]
        n=6;faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh_object('PublicRoof%sReturn_%d'%(side,i),vertices,faces,'galvanized_roof')

# A thin folded boot follows the actual roof and cricket facets, then rises
# against the outer curb face into a real recess beneath the projecting cap.
# Aprons replace those roof-skin strips at the same height. Their flush joints
# introduce no raised curb around either downhill valley.
top=plan['flashing_top']
for side,rect in apron_rectangles:
    for k,region in enumerate(subtract_rect(rect,cricket)):
        rectangular_prism('PublicRoofCurbApron_'+side+str(k),region,roof_y,lambda x,z:roof_y(x,z)+sheet,'galvanized_roof')
    for label,polygon,surface in facets:
        clipped=clip_polygon(polygon,rect)
        for j in range(1,len(clipped)-1):
            points=[clipped[0],clipped[j],clipped[j+1]]
            area=abs(float(np.linalg.det(np.asarray([np.asarray(points[1])-points[0],np.asarray(points[2])-points[0]]))))*.5
            if area<1e-10:continue
            triangular_prism('PublicRoofCurbApron_'+side+'_'+label+str(j),points,surface,lambda x,z:surface(x,z)+sheet,'galvanized_roof')
for side,rect in [('South',[curb[0],curb[1]-sheet,curb[2],curb[1]]),
    ('North',[curb[0],curb[3],curb[2],curb[3]+sheet]),
    ('East',[curb[2],curb[1],curb[2]+sheet,curb[3]])]:
    rectangular_prism('PublicRoofCurbUpstand_'+side,rect,lambda x,z:roof_y(x,z)+sheet,constant(top),'galvanized_roof')
for label,za,zb in [('South',curb[1],mid),('North',mid,curb[3])]:
    surface=next(row[2] for row in facets if row[0]==label+'Cricket')
    rectangular_prism('PublicRoofCurbUpstand_West_'+label,[curb[0]-sheet,za,curb[0],zb],
        lambda x,z:surface(curb[0],z)+sheet,constant(top),'galvanized_roof')

# Eastern eave projects over the gutter's western lip. No flat cap seals its bore.
rectangular_prism('PublicRoofDrainApron',[x1-.018,z0,gutter_x+.008,z1],
                  lambda x,z:roof_y(x1,0)-.006*(x-x1),
                  lambda x,z:roof_y(x1,0)-.006*(x-x1)+sheet,'galvanized_roof')

def gutter_centre(z):return gutter_low+gutter_fall*abs(outlet_z-z)
profile=[]
for inner in [False,True]:
    radius=gutter_radius-gutter_wall if inner else gutter_radius
    indices=range(25) if not inner else reversed(range(25))
    for i in indices:
        angle=math.pi*i/24
        profile.append((gutter_x+radius*math.cos(angle),-radius*math.sin(angle)))
gutter=profile_sweep('PublicRoofGutterClosedConstruction',profile,[(z0,gutter_centre(z0)),(outlet_z,gutter_centre(outlet_z)),(z1,gutter_centre(z1))],'galvanized_roof')

def cylinder(name,a,b,radius,key):
    a,b=point(a),point(b);axis=(b-a).normalized()
    u=Vector((1,0,0));v=axis.cross(u).normalized();n=32
    verts=[at+radius*(u*math.cos(2*math.pi*i/n)+v*math.sin(2*math.pi*i/n)) for at in [a,b] for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_object(name,[godot(p) for p in verts],faces,key)

def difference(obj,tool):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Open rainwater throat','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=tool
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    parts.remove(tool);bpy.data.objects.remove(tool,do_unlink=True)

def unite(obj,tool):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Continuous soldered water joint','BOOLEAN');modifier.operation='UNION';modifier.solver='EXACT';modifier.object=tool
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    parts.remove(tool);bpy.data.objects.remove(tool,do_unlink=True)

hole=cylinder('GutterOutletAir',(gutter_x,cap_top-.15,outlet_z),(gutter_x,cap_top+.08,outlet_z),leader_inner,'galvanized_roof')
difference(gutter,hole)
# Closed end wall plates prevent water leaving at the two gutter ends.
for side,z in [('South',z0),('North',z1)]:
    profile_sweep('PublicRoofGutter'+side+'End',[(gutter_x,0)]+[(gutter_x+gutter_radius*math.cos(math.pi*i/24),-gutter_radius*math.sin(math.pi*i/24)) for i in range(25)],
                  [(z,gutter_centre(z)),(z+(.0012 if side=='North' else -.0012),gutter_centre(z))],'galvanized_roof')

# Soldered sheet-metal leader; annular ends preserve its open lumen.
leader_top=gutter_centre(outlet_z)-.012
leader_bottom=fitted_foot_y+plan['leader_deck_clearance']
outer=cylinder('PublicRoofLeader',(gutter_x,leader_bottom,outlet_z),(gutter_x,leader_top,outlet_z),leader_outer,'galvanized_roof')
air=cylinder('LeaderAir',(gutter_x,leader_bottom-.005,outlet_z),(gutter_x,leader_top+.005,outlet_z),leader_inner,'galvanized_roof')
difference(outer,air)
# Trim the leader crown to the actual inner gutter bowl. A flat annular rim
# projecting into that bowl would form an unintended 36 mm standpipe dam.
inner_radius=gutter_radius-gutter_wall
water_profile=[(gutter_x-inner_radius,.2),(gutter_x+inner_radius,.2)]
water_profile += [(gutter_x+inner_radius*math.cos(math.pi*i/24),-inner_radius*math.sin(math.pi*i/24)) for i in range(25)]
water=profile_sweep('GutterContinuousWaterSpace',water_profile,
                    [(z0-.001,gutter_centre(z0-.001)),(outlet_z,gutter_centre(outlet_z)),(z1+.001,gutter_centre(z1+.001))],'galvanized_roof')
difference(outer,water)
unite(gutter,outer)

# Flat wall plates and rigid straps actually bridge the wall/leader gap.
for i,height in enumerate([roof_deck_y+.6,roof_deck_y+1.8,leader_top-.3]):
    rectangular_prism('PublicRoofLeaderWallPlate_%d'%i,[x1-.002,outlet_z-.035,x1+.002,outlet_z+.035],constant(height-.055),constant(height+.055),'galvanized_roof')
    rectangular_prism('PublicRoofLeaderWallTongue_%d'%i,[x1,outlet_z-.012,gutter_x-leader_outer,outlet_z+.012],constant(height-.003),constant(height+.003),'galvanized_roof')
    strap_outer=cylinder('PublicRoofLeaderStrap_%d'%i,(gutter_x,height-.012,outlet_z),(gutter_x,height+.012,outlet_z),leader_outer+.002,'galvanized_roof')
    strap_air=cylinder('LeaderStrapAir_%d'%i,(gutter_x,height-.018,outlet_z),(gutter_x,height+.018,outlet_z),leader_outer,'galvanized_roof')
    difference(strap_outer,strap_air)
for i in range(math.ceil((z1-z0)/1.2)+1):
    z=z0+(z1-z0)*i/math.ceil((z1-z0)/1.2)
    h=gutter_centre(z)-gutter_radius
    rectangular_prism('PublicRoofGutterBracket_%02d'%i,[x1-.002,z-.012,gutter_x+.012,z+.012],constant(h-.006),constant(h),'galvanized_roof')

# Recompute exact orthonormal UVs after booleans and validate editable sheets.
triangles=0
open_bearings={r['id'] for r in records if r['omit_retained_bottom']}
for obj in parts:
    mesh=obj.data;mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    if obj.name in open_bearings:
        # Runtime deliberately omits the original cap's shared contact face;
        # its separately retained native construction is closed and positive.
        assert all(e.is_manifold or (e.is_boundary and all(abs(v.co.z-cap_top)<1e-6 for v in e.verts)) for e in bm.edges),obj.name
    else:
        assert all(e.is_manifold for e in bm.edges),obj.name
        assert bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    bm=bmesh.new();bm.from_mesh(mesh)
    # Exact Boolean intersections contain two sub-five-micrometre diagonals
    # at the curved outlet. Condition them before triangulation, as in the
    # accepted ventilation-sheet pipeline; no architectural boundary shifts.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000005)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000005)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000005)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000005)
    if obj.name not in open_bearings:
        assert all(e.is_manifold for e in bm.edges),'Post-triangulation closure: '+obj.name
        assert bm.calc_volume(signed=True)>0
    bm.to_mesh(mesh);bm.free();mesh.update()
    uv=mesh.uv_layers.active
    for face in mesh.polygons:
        normal=Vector(face.normal).normalized();seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
    mesh.calc_loop_triangles();triangles += len(mesh.loop_triangles)

# Runtime partitions include only original triangles, split at four-metre
# culling boundaries. No closed caps are introduced at those boundaries.
runtime_sets_path=ROOT/'art/data/runtime_material_sets.json'
runtime_sets=json.loads(runtime_sets_path.read_text(encoding='utf-8'))['materials']
import runpy
runpy.run_path(str(ROOT/'art/blender/scripts/roof_weather_retained_gutter.py'))['retain_gutter'](ROOT,'public',gutter,leader_bottom,materials)
native_parts=parts.copy();groups={}
grid_start=[min(v.co[axis] for obj in native_parts for v in obj.data.vertices)-.0001 for axis in range(3)]
for obj in native_parts:
    bm=bmesh.new();bm.from_mesh(obj.data)
    for axis,start in enumerate(grid_start):
        values=[v.co[axis] for v in bm.verts]
        lo=min(values);hi=max(values)
        first=math.floor((lo-start)/span)+1;last=math.ceil((hi-start)/span)
        for i in range(first,last):
            normal=Vector((0,0,0));normal[axis]=1
            at=Vector((0,0,0));at[axis]=start+span*i
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=at,plane_no=normal,dist=1e-7)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    for face in bm.faces:
        if face.calc_area()<1e-12:continue
        centre=face.calc_center_median()
        cell=tuple(math.floor((centre[axis]-grid_start[axis])/span) for axis in range(3))
        groups.setdefault((obj['material_key'],cell),[]).append([godot(v.co) for v in face.verts])
    bm.free();obj.hide_render=True;obj.hide_set(True)
parts=[]
for index,((key,cell),faces) in enumerate(sorted(groups.items())):
    vertices=[p for face in faces for p in face]
    name='PublicRoofRuntime_%02d_%s'%(index,key)
    obj=mesh_object(name,vertices,[tuple(range(i,i+3)) for i in range(0,len(vertices),3)],key,recalculate=False)
    # Preserve whole-tile phase while keeping both UV and local coordinates
    # near the origin. Global 22 m float UVs lose precision on outlet slivers.
    # Integer tile shifts leave the existing repeating maps and triplanar
    # material phase unchanged, including across the culling boundaries.
    tile=float(runtime_sets[key]['meters_per_tile']);mesh=obj.data
    centre=np.mean(np.asarray([list(vertex.co) for vertex in mesh.vertices],dtype=np.float64),axis=0)
    origin=np.floor(centre/tile)*tile
    for vertex in mesh.vertices:vertex.co=np.asarray(vertex.co,dtype=np.float64)-origin
    obj.location=origin;mesh.update();uv=mesh.uv_layers.active
    for face in mesh.polygons:
        normal=np.asarray(face.normal,dtype=np.float64);normal/=np.linalg.norm(normal)
        seed=np.asarray((0,1,0) if abs(normal[1])<.85 else (1,0,0),dtype=np.float64)
        u=seed-normal*np.dot(seed,normal);u/=np.linalg.norm(u);v=np.cross(normal,u)
        centre=np.mean([np.asarray(mesh.vertices[index].co,dtype=np.float64)+origin for index in face.vertices],axis=0)
        offset_u=round(float(np.dot(centre,u))/tile)*tile;offset_v=round(float(np.dot(centre,v))/tile)*tile
        for loop in face.loop_indices:
            p=np.asarray(mesh.vertices[mesh.loops[loop].vertex_index].co,dtype=np.float64)+origin
            uv.data[loop].uv=(float(np.dot(p,u))-offset_u,float(np.dot(p,v))-offset_v)
triangles=sum(len(obj.data.polygons) for obj in parts)

bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'roof_public_weathering.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':
            self.normals=np.array(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,normal in enumerate(self.normals):
                assert abs(np.linalg.norm(normal)-1)<.001,'Invalid native exported normal'
                seed=np.array((0,0,-1) if abs(normal[2])<.85 else (1,0,0),dtype=np.float64)
                tangent=seed-normal*np.dot(seed,normal);tangent/=np.linalg.norm(tangent)
                result[i,:3]=tangent
                # Blender's orthonormal V is flipped by the GLB UV conversion.
                result[i,3]=-1
            assert result.shape==data['data'].shape
            data['data']=result;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(MODEL),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
assert ExportUVHandedness.partitions==len(parts)
manifest={'evidence_class':'INERT','classification':'ADAPTATION','authority':[
    'art/data/orison_v2/roof_source.json:ROOF_PUBLIC_CORE','game/data/orison_v2_blockout.json:dimensions'],
    'curb_outer_rect':curb,'cricket_rect':cricket,'cricket_rise':plan['cricket_rise'],'flashing_top':plan['flashing_top'],
    'cricket_facets':[{'id':label,'points':[[x,surface(x,z),z] for x,z in polygon]} for label,polygon,surface in facets],
    'source_bindings':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [layout_path,roof_path,plan_path,runtime_sets_path]},
    'cap_outer_rect':[x0,z0,x1,z1],'retained_cap_top':cap_top,'bearing_toe':toe,'sheet_thickness':sheet,'roof_fall':roof_fall,
    'gutter_x':gutter_x,'gutter_z':[z0,z1],'gutter_radius':gutter_radius,'gutter_wall':gutter_wall,'gutter_fall':gutter_fall,
    'gutter_low_y':gutter_low,'outlet_z':outlet_z,'leader_bore_radius':leader_inner,'leader_y':[leader_bottom,leader_top],
    'parts':len(parts),'native_triangles':triangles,'sheets':records,
    'seam_recipe':{'x':[x0+(x1-x0)*i/sx for i in range(1,sx)],'half_width':seam,'extra_height':0},
    'leader_wall_plates':[roof_deck_y+.6,roof_deck_y+1.8,leader_top-.3],
    'open_work':plan['open_work']}
(OUT/'roof_public_weathering_construction.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
fixture_keys=['cap_outer_rect','retained_cap_top','bearing_toe','sheet_thickness','roof_fall','gutter_x','gutter_z','gutter_radius','gutter_wall','gutter_fall','gutter_low_y','outlet_z','leader_bore_radius','seam_recipe','leader_wall_plates']
fixture_keys += ['curb_outer_rect','cricket_rect','cricket_rise','cricket_facets','flashing_top','parts','native_triangles','leader_y']
manifest.update({'status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','field_y':fitted_field_y,'foot_y':fitted_foot_y,'leader_toe_y':leader_bottom,'retained_plate_datum':roof_deck_y,'native_sha256':hashlib.sha256((OUT/'roof_public_weathering.blend').read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(MODEL.read_bytes()).hexdigest(),'runtime_parts':[{'name':obj.name,'material':obj.data.materials[0].name} for obj in parts]})
manifest['source_bindings'].update({p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() if p.suffix=='.blend' else hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [ROOT/'art/blender/roof_weather_retained_gutters.blend',ROOT/'art/blender/roof_drainage_falls_construction.json',ROOT/'art/blender/scripts/roof_weather_retained_gutter.py',Path(__file__)]})
fixture=manifest
fixture_path=ROOT/'game/tests/fixtures/orison_roof_public_weathering.json'
fixture_path.write_text(json.dumps(fixture,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ROOF SERVICE WEATHERING',len(parts),'parts',triangles,'triangles; field discharge unresolved')

(OUT/'roof_public_weathering_construction.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
