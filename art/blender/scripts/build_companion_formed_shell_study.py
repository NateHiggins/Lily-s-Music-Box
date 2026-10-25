"""Isolated formed-shell candidate. Never writes installed assets.

Blender --background --python-exit-code 1 --python THIS -- --out tmp/shell
Requires the separately authored service_companion_v2 native candidate.
"""
from pathlib import Path
import sys, math, json, collections, argparse, hashlib
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--out',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=(ROOT/args.out).resolve();assert OUT.is_relative_to((ROOT/'tmp').resolve())
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export
source=ROOT/'art/blender/service_companion_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version=0
stocks=bpy.data.collections['EditableIndividualStock']
exports=bpy.data.collections['ServiceRadiophoneV2']
review=bpy.data.collections['ReviewOnlyLetteringAndStage']
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
new=bpy.data.collections.new('FormedShellStudy');bpy.context.scene.collection.children.link(new)
groups=collections.defaultdict(list);checks=[];fasteners=[]
def coords(p):return Vector((p[0],-p[2],p[1]))
def signature(points):return tuple(sorted(tuple(round(c,7) for c in p) for p in points))
# Retire precisely the four old strips and rear pan; retained native triangles
# are matched by geometry, not by an approximate region or a material wipe.
retired=[o for o in stocks.objects if o.name.startswith(('Stock__Case side','Stock__Case end','Stock__Rear pan','Stock__Returned tray edge','Stock__Returned tray lip'))]
assert len(retired)==8,[o.name for o in retired]
triangles=set()
for obj in retired:
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
    triangles.update(signature([v.co for v in face.verts]) for face in bm.faces);bm.free()
removed=0
for obj in exports.objects:
    if obj.type!='MESH':continue
    doomed=[p.index for p in obj.data.polygons if signature([obj.matrix_world@obj.data.vertices[i].co for i in p.vertices]) in triangles]
    if not doomed:continue
    obj.data=obj.data.copy();bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in doomed],context='FACES');bm.to_mesh(obj.data);bm.free();removed+=len(doomed)
assert removed==len(triangles),(removed,len(triangles))
def mesh(name,points,faces,surface):
    data=bpy.data.meshes.new(name);data.from_pydata([coords(p) for p in points],[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume()>0,name
    bm.to_mesh(data);bm.free()
    obj=bpy.data.objects.new('Stock__'+name,data);new.objects.link(obj);groups[surface].append(obj);return obj
def loop(w,h,r,z,n=10):
    return [(sx*(w/2-r)+r*math.cos(a),sy*(h/2-r)+r*math.sin(a),z)
      for sx,sy,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]
      for a in [math.radians(start+i*90/n) for i in range(n+1)]]
def skin(name,w,h,r,back,front,t,surface,pan=False):
    loops=[loop(w,h,r,back),loop(w,h,r,front),loop(w-2*t,h-2*t,r-t,front),loop(w-2*t,h-2*t,r-t,back+t if pan else back)]
    n=len(loops[0]);points=sum(loops,[]);faces=[]
    for k in range(3):faces.extend((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for i in range(n))
    if pan:faces.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))])
    else:faces.extend((3*n+i,3*n+(i+1)%n,(i+1)%n,i) for i in range(n))
    return mesh(name,points,faces,surface)
def cut(obj,center,radius,depth,axis='z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=coords(center));tool=bpy.context.object
    if axis=='z':tool.rotation_euler.x=math.pi/2
    if axis=='x':tool.rotation_euler.y=math.pi/2
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Machined through bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
def union(obj,tool):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Integral cast fastening boss','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for objects in groups.values():
        if tool in objects:objects.remove(tool)
    bpy.data.objects.remove(tool,do_unlink=True)
def leaf_slot(obj,at,angle):
    outline=[(t-.5,sign*math.sin(math.pi*t)*.5) for sign,ts in [(1,range(13)),(-1,range(11,0,-1))] for t in [j/12 for j in ts]]
    points=[]
    for z in [at[2]-.008,at[2]+.008]:
        for u,v in outline:
            u*=.0038;v*=.0022
            points.append(coords((at[0]+u*math.cos(angle)-v*math.sin(angle),at[1]+u*math.sin(angle)+v*math.cos(angle),z)))
    n=len(outline);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    data=bpy.data.meshes.new('Leaf piercing cutter');data.from_pydata(points,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    tool=bpy.data.objects.new('Leaf piercing cutter',data);new.objects.link(tool)
    bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Pierced foliate scroll','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
def rod(name,a,b,r,surface):
    a,b=coords(a),coords(b);bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4);obj.name='Stock__'+name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    new.objects.link(obj);groups[surface].append(obj);return obj
def strap(name,path,width,thickness,surface):
    pts=[]
    for i,p in enumerate(path):
        tangent=Vector(path[min(i+1,len(path)-1)])-Vector(path[max(i-1,0)])
        side=Vector((-tangent.y,tangent.x,0)).normalized()*width/2
        for dz,sign in [(-thickness/2,-1),(-thickness/2,1),(thickness/2,1),(thickness/2,-1)]:
            q=Vector(p)+side*sign+Vector((0,0,dz));pts.append(tuple(q))
    faces=[(3,2,1,0),tuple((len(path)-1)*4+i for i in range(4))]
    for i in range(len(path)-1):faces.extend((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for j in range(4))
    return mesh(name,pts,faces,surface)
pan=skin('Continuous pressed structural pan',.214,.193,.017,-.031,.0275,.0025,'ShellSteel',True)
for x,y,r in [(.043,.049,.021),(-.049,-.041,.013)]:cut(pan,(x,y,-.030),r,.012)
leather=skin('One piece moulded leather jacket',.216,.195,.018,-.0322,.0265,.001,'ShellLeather',True)
for x,y,r in [(.043,.049,.021),(-.049,-.041,.013)]:cut(leather,(x,y,-.0315),r,.012)
# Retained control shafts enter real machined openings. A stepped top-hat
# bearing sits against the leather face and carries the existing reading shaft.
for body in [pan,leather]:
    cut(body,(.106,.038,0),.00265,.016,axis='x')
    cut(body,(.094,.096,.005),.00615,.016,axis='y')
profile=[(.1045,.0026),(.108,.0026),(.108,.0042),(.110,.0042),(.110,.00205),(.1045,.00205)]
count=24;points=[(x,.038+r*math.cos(i*math.tau/count),r*math.sin(i*math.tau/count)) for x,r in profile for i in range(count)]
faces=[(k*count+i,k*count+(i+1)%count,((k+1)%len(profile))*count+(i+1)%count,((k+1)%len(profile))*count+i) for k in range(len(profile)) for i in range(count)]
mesh('Stepped bored reading shaft bearing',points,faces,'ShellBrass')
liner=skin('Soft fitted liner return',.2088,.1878,.0144,-.025,.0268,.0011,'StudyVelvet')
cut(liner,(.104,.038,0),.00265,.016,axis='x')
cut(liner,(.094,.096,.005),.00615,.016,axis='y')
# Rolled edges follow the same continuous curvature; no square corner joints.
for z in [-.0334,.026]:skin('Continuous rolled brass edge',.217,.196,.0185,z-.0012,z+.0012,.0018,'ShellBrass')
# Four scalloped openwork guards: each is a structural strap anchored by two
# real through-bolts. The curved web wraps the rounded corner without a seam.
for sx in [-1,1]:
  for sy in [-1,1]:
    path=[(sx*.106,sy*.062,.0286),(sx*.106,sy*.079,.0286)]
    for i in range(1,13):
        a=i*math.pi/24
        path.append((sx*(.089+.017*math.cos(a)),sy*(.079+.017*math.sin(a)),.0286))
    path.extend([(sx*.071,sy*.096,.0286),(sx*.058,sy*.096,.0286)])
    guard=strap('Pierced corner fastening guard',path,.009,.0022,'ShellBrass')
    for angle in [25,45,65]:
        a=math.radians(angle)
        leaf_slot(guard,(sx*(.089+.017*math.cos(a)),sy*(.079+.017*math.sin(a)),.029),math.atan2(sy*math.cos(a),-sx*math.sin(a)))
    anchors=[(sx*.1025,sy*.066,.0286),(sx*.063,sy*.093,.0286)]
    for x,y,z in anchors:
        # Wider end pad seats screw and washer completely on the guard.
        pad=rod('Guard bolt seating pad',(x,y,z-.0011),(x,y,z+.0011),.005,'ShellBrass')
        union(guard,pad)
        cut(guard,(x,y,z),.00125,.012)
        boss=rod('Integral shell threaded boss',(x,y,.021),(x,y,.0275),.0035,'ShellSteel')
        union(pan,boss)
        cut(pan,(x,y,z-.002),.00125,.012)
        fasteners.append((guard,(x,y,z)))
        rod('Guard screw shank',(x,y,.021),(x,y,.031),.0011,'ShellSteel')
        head=rod('Slotted guard screw',(x,y,.0297),(x,y,.0314),.0026,'ShellBrass')
        # Head slot is an actual subtraction, not an intersecting black bar.
        bpy.ops.mesh.primitive_cube_add(size=1,location=coords((x,y,.0314)));tool=bpy.context.object;tool.scale=(.004,.0014,.0007)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bpy.context.view_layer.objects.active=head
        mod=head.modifiers.new('Screwdriver slot','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
# The keyboard gets one rounded perimeter, retaining its separate bored guide
# plate, latch, hinge, keys, tile module and all the original pivot datums.
keyboard_frame=skin('One piece rounded keyboard perimeter',.204,.094,.006,.103,.115,.003,'KeyboardShellBrass')
for v in keyboard_frame.data.vertices:v.co.z-=.057
# Real, thin, rounded glass pane over the reading bed. Gasket and retaining
# lip share a measured seat; printer action below y=-.012 stays uncovered.
pane=skin('Reading window pane',.137,.096,.006,.0573,.0585,.001,'ShellGlass',True)
# The pane is solid glass, so close its front opening with the same material.
# Replace this hollow-profile helper result with a rounded solid extrusion.
bpy.data.objects.remove(pane,do_unlink=True);groups['ShellGlass']=[]
points=loop(.137,.096,.006,.0573)+loop(.137,.096,.006,.0585);n=len(points)//2
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
pane=mesh('1.2 millimetre reading glass',[(x,y+.036,z) for x,y,z in points],faces,'ShellGlass')
for name,w,h,r,back,front,t,surface in [
 ('Glazing rear bearing flange',.142,.101,.0085,.0563,.0573,.0045,'ShellRubber'),
 ('Glazing side gasket',.142,.101,.0085,.0573,.0585,.0025,'ShellRubber'),
 ('Reading glass retaining frame',.145,.104,.010,.0585,.0605,.005,'ShellBrass')]:
    obj=skin(name,w,h,r,back,front,t,surface)
    for v in obj.data.vertices:v.co.z+=.036
    if name=='Reading glass retaining frame':glazing_frame=obj
# One frame with four formed clamp arms. The U-section engages both sides
# and the top of the original 3 mm cartridge frame. Clamp screws bear on the
# old frame rather than pretending there is a pre-existing threaded hole.
clamp_profile=[(.0715,.0585),(.0791,.0585),(.0807,.05665),(.0807,.0505),
 (.0815,.0505),(.0815,.055),(.0845,.055),(.0845,.0505),(.0861,.0505),
 (.0861,.05665),(.0823,.05665),(.0800,.0601),(.0715,.0601)]
for side in [-1,1]:
    for y in [0.0,.076]:
        points=[(side*x,yy,z) for yy in [y-.003,y+.003] for x,z in clamp_profile]
        n=len(clamp_profile)
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        arm=mesh('Integral reading frame clamp arm',points,faces,'ShellBrass')
        union(glazing_frame,arm)
        cut(glazing_frame,(side*.0853,y,.0528),.00085,.003,axis='x')
        rod('Reading frame clamp screw',(side*.0845,y,.0528),(side*.0875,y,.0528),.00075,'ShellSteel')
        head=rod('Reading frame clamp screw head',(side*.0861,y,.0528),(side*.0875,y,.0528),.00165,'ShellBrass')
        bpy.ops.mesh.primitive_cube_add(size=1,location=coords((side*.0875,y,.0528)))
        tool=bpy.context.object;tool.scale=(.0007,.00045,.0024)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=head
        mod=head.modifiers.new('Clamp screw driver slot','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
# Measure real stock surfaces. A clear axial bore plus four annular bearing
# rays proves the guard has a seated fastening face, rather than a nearby bolt.
def bvh(obj):
    return BVHTree.FromPolygons([v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
def hit_depth(tree,x,y,start,end):
    origin=coords((x,y,start));finish=coords((x,y,end));delta=finish-origin
    hit=tree.ray_cast(origin,delta.normalized(),delta.length)
    return -hit[0].y if hit[0] is not None else None
pan_bvh=bvh(pan);bearing_checks=[]
for guard,point in fasteners:
    x,y,z=point;guard_bvh=bvh(guard)
    assert hit_depth(pan_bvh,x,y,.034,.019) is None,('filled shell bore',point)
    assert hit_depth(guard_bvh,x,y,.034,.019) is None,('filled guard bore',point)
    for dx,dy in [(.002,0),(-.002,0),(0,.002),(0,-.002)]:
        pan_face=hit_depth(pan_bvh,x+dx,y+dy,.034,.019)
        guard_back=hit_depth(guard_bvh,x+dx,y+dy,.023,.033)
        assert pan_face is not None and guard_back is not None,('missing bearing',point,dx,dy)
        assert abs(pan_face-.0275)<.000005 and abs(guard_back-pan_face)<.000005,('guard not seated',point,pan_face,guard_back)
        bearing_checks.append(dict(point=[x+dx,y+dy],seat_m=pan_face,gap_m=guard_back-pan_face))
specs={
 'ShellSteel':dict(catalog_key='fire_hardware_steel',tint=[.3,.35,.34,1],normal=.25,roughness=.8,pigment=.5),
 'ShellLeather':dict(catalog_key='leather_worn',tint=[.38,.20,.11,1],normal=.45,roughness=.9,pigment=.6),
 'ShellBrass':dict(catalog_key='brass_dull',tint=[.82,.67,.39,1],normal=.2,roughness=.65,pigment=.45),
 'ShellRubber':dict(catalog_key='washer_rubber',tint=[.2,.17,.13,1],normal=.2,roughness=1.,pigment=.5),
 'ShellGlass':dict(catalog_key='glass_drawn_expressive',tint=[.9,.98,.96,.15],normal=.15,roughness=.3,pigment=.2),
 'StudyVelvet':dict(catalog_key='velour',tint=[.28,.06,.10,1],normal=.35,roughness=1.,pigment=.65)}
specs['KeyboardShellBrass']=dict(specs['ShellBrass'])
for surface,objects in groups.items():
    if not objects:continue
    for obj in objects:
        bm=bmesh.new();bm.from_mesh(obj.data)
        before=bm.calc_volume()
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),('cleaned native stock open',obj.name)
        assert abs(bm.calc_volume()-before)<1e-10,('clean changed stock volume',obj.name)
        bm.to_mesh(obj.data);bm.free()
    spec=specs[surface];mat=material(ROOT,surface,spec,catalog)
    if surface=='ShellGlass':
        p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Transmission Weight'].default_value=1.;p.inputs['IOR'].default_value=1.49
    if surface=='StudyVelvet':
        p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Sheen Weight'].default_value=.18
    draw=partition(exports,'ShellStudy__'+surface,objects,spec,mat,Matrix.Identity(4),catalog)
    if surface=='KeyboardShellBrass':
        parent=bpy.data.objects['CompanionKeyboard'];draw.data.transform(Matrix.Translation(-parent.location));draw.parent=parent;draw.location=(0,0,0)
for objects in groups.values():
    for obj in objects:
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),('open finished stock',obj.name)
        assert bm.calc_volume()>1e-13,('nonpositive finished stock',obj.name)
        remaining=set(bm.verts);components=0
        while remaining:
            components+=1;pending=[remaining.pop()]
            while pending:
                vertex=pending.pop()
                for edge in vertex.link_edges:
                    neighbour=edge.other_vert(vertex)
                    if neighbour in remaining:remaining.remove(neighbour);pending.append(neighbour)
        assert components==1,('disconnected finished stock',obj.name,components)
        checks.append(dict(name=obj.name,volume_m3=bm.calc_volume()));bm.free()
new.hide_render=True;new.hide_viewport=True
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.abspath(image.filepath)
for folder in ['art/blender','game/assets/props']:(OUT/folder).mkdir(parents=True,exist_ok=True)
# Establish the output blend location before the generic exporter makes paths
# relative. Otherwise Blender's save relocation remaps those paths a second time.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/service_companion_formed_shell.blend'),relative_remap=False)
proof=export(OUT,'service_companion_formed_shell',exports,material_names_only=True,staged_output=True)
assert proof['triangles']<50000,proof
for image in bpy.data.images:
    if image.source=='FILE':assert Path(bpy.path.abspath(image.filepath)).is_file(),('missing native image',image.name)
scene=bpy.context.scene;scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.cycles.samples=32
camera=scene.camera;camera.data.ortho_scale=.56
def aim(at,target):camera.location=coords(at);camera.rotation_euler=(coords(target)-camera.location).to_track_quat('-Z','Y').to_euler()
for name,at,target,scale in [('front',(.32,.26,.65),(0,-.01,0),.56),('shell_corner',(.32,.26,.46),(.087,.077,.012),.16),('rear',(-.36,.22,-.63),(0,0,0),.55),('typing',(.32,.26,.65),(0,-.01,0),.56)]:
    if name=='typing':
        keyboard=bpy.data.objects['CompanionKeyboard'];keyboard.rotation_euler.x=math.pi/2
        bpy.data.objects['CompanionKeyboardLatch'].rotation_euler.z=-.65
        bpy.context.view_layer.update()
        for x,label in [(-.094,'Port'),(.094,'Starboard')]:
            a=coords((x,-.084,.042));attachment=keyboard.matrix_world@coords((x,.016,-.006))
            delta=attachment-a;distance=delta.length;assert distance<.100
            perpendicular=Vector((0,-delta.z,delta.y)).normalized()
            elbow=(a+attachment)*.5+perpendicular*math.sqrt(.050**2-distance**2*.25)
            for suffix,start,end in [('Upper',a,elbow),('Lower',elbow,attachment)]:
                link=bpy.data.objects[label+'KeyboardStay'+suffix];link.location=start;link.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
    camera.data.ortho_scale=scale;aim(at,target);scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/service_companion_formed_shell.blend'),relative_remap=False)
(OUT/'review.json').write_text(json.dumps(dict(evidence_class='INERT',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),export=proof,finishes=specs,retired_stock=[o.name for o in retired],removed_triangles=removed,finished_stocks=checks,fastener_bearing_rays=bearing_checks,clear_axial_bores=len(fasteners)*2,glazing_seats=dict(glass_back=.0573,glass_front=.0585,gasket_rear_flange_front=.0573,side_gasket_inner_width=.137,retainer_back=.0585),scope='Isolated native form study; not installed or Godot qualified',limitations=['Lining uses existing registered cotton-pile velour; native sheen is a form review','Glass requires production wet/smudge shader binding and readability review','Clamp contact and moving assembly clearance need imported verification']),indent=2)+'\n')
