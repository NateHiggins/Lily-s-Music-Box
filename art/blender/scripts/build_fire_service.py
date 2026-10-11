"""Native fire-line stock; source pivots remain the maintenance authority."""
from pathlib import Path
import json, math
import bpy, bmesh

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'tmp/v2-fire-service-20261011'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
materials = {}
for key in ['Paint', 'Lining', 'Brass', 'Iron', 'Linen', 'Rubber', 'Paper', 'Glass', 'Black']:
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    materials[key] = mat

def b(v): return (v[0], -v[2], v[1])

def cube(size, at=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=b(at))
    o = bpy.context.object
    o.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o

def boolean(o, other, operation):
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('Continuous casting', 'BOOLEAN')
    mod.operation = operation
    mod.solver = 'EXACT'
    mod.object = other
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(other, do_unlink=True)

def finish(name, objects, key, bevel=.0007, horizontal_grain=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    o = bpy.context.object
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    o.name = name
    if bevel:
        mod = o.modifiers.new('Fabricated edge radius', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.clear()
    o.data.materials.append(materials[key])
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    mod = o.modifiers.new('Stable triangle charts', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for previous in list(o.data.uv_layers): o.data.uv_layers.remove(previous)
    uv = o.data.uv_layers.new(name='MetreStock')
    for face in o.data.polygons:
        vertices = [o.data.vertices[i].co for i in face.vertices]
        normal = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
        axis = max(range(3), key=lambda i: abs(normal[i]))
        a, c = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in face.loop_indices:
            p = o.data.vertices[o.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[c], p[a]) if horizontal_grain else (p[a], p[c])
    return o

def box(name, size, key, at=(0, 0, 0), bevel=.0007, horizontal=False):
    return finish(name, [cube(size, at)], key, bevel, horizontal)

import hashlib
from mathutils import Vector
PLAN = ROOT/'art/data/fire_service/source_plan.json'
plan = json.loads(PLAN.read_text(encoding='utf-8'))
source = ROOT/'game/scripts/props/fire_line_cabinet_prop.gd'
assert hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest() == plan['source_sha256']
assert len(plan['parts']) == 82

def cylinder(radius, height, top=None, at=(0,0,0)):
    bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=radius,
        radius2=radius if top is None else top,depth=height,location=b(at))
    return bpy.context.object

def hollow(radius,height,inside,top=None,inside_top=None):
    o=cylinder(radius,height,top)
    boolean(o,cylinder(inside,height+.004,inside if inside_top is None else inside_top),'DIFFERENCE')
    return o

def sweep(points,radius,inside=None,wide=None,normal_axis=(0,0,1)):
    # Closed swept walls, including annular end faces for real pipe bores.
    points=[Vector(p) for p in points];axis=Vector(normal_axis);n=32;verts=[]
    for inner in ([False,True] if inside is not None else [False]):
        for i,p in enumerate(points):
            tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            radial=tangent.cross(axis).normalized()
            for j in range(n):
                a=j*math.tau/n;r=inside if inner else radius
                verts.append(b(p+radial*(r*math.cos(a))+axis*((wide if wide else r)*math.sin(a))))
    length=len(points);faces=[]
    for inner in range(2 if inside is not None else 1):
        offset=inner*length*n
        for i in range(length-1):
            for j in range(n):
                face=(offset+i*n+j,offset+i*n+(j+1)%n,offset+(i+1)*n+(j+1)%n,offset+(i+1)*n+j)
                faces.append(tuple(reversed(face)) if inner else face)
    if inside is None:
        faces.extend([tuple(reversed(range(n))),tuple(range((length-1)*n,length*n))])
    else:
        for end in [0,length-1]:
            for j in range(n):
                faces.append((end*n+j,end*n+(j+1)%n,length*n+end*n+(j+1)%n,length*n+end*n+j))
    mesh=bpy.data.meshes.new('Swept stock');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Swept stock',mesh);bpy.context.collection.objects.link(o);return o

def key(index):
    if index in [1,3,4,8,9,10,11,16,17,18,19,22,23,24,25,65,66,67,68]: return 'Paint'
    if index in [7,12,13,14,15]: return 'Lining'
    if index in [21,32,61,63,*range(70,81)]: return 'Iron'
    if index in [29,*range(37,59)]: return 'Linen'
    if index in [30,64]: return 'Rubber'
    if index==31:return 'Black'
    if index==33:return 'Paper'
    if index==69:return 'Glass'
    return 'Brass'

for p in plan['parts']:
    i=p['index'];name=f'F{i:03d}';finish_key=key(i)
    if i in [57,58]: continue # Moving crowns attach to the original fold leaves.
    if i==0: continue # Real standpipe tee replaces the overlapping take-off boss.
    if p['name'].startswith('Fold_'):
        legs=[sweep([(x,-.131,0),(x,.131,0)],.004,wide=.059) for x in [-.010,.010]]
        finish(name,legs,finish_key,0)
    elif p['name'].startswith('Turn_'):
        finish(name,[sweep([(.010*math.cos(a),0,.010*math.sin(a))
            for a in [j*math.pi/24 for j in range(25)]],.004,wide=.059,normal_axis=(0,1,0))],finish_key,0)
    elif i==1:
        # Horizontal branch ends on the elbow tangent, not inside a solid stub.
        run=hollow(.024,.240,.017);run.location.z=-.020
        finish(name,[run],finish_key,.0004)
    elif i==2:
        finish(name,[sweep([(.045-.045*math.cos(a),.045-.045*math.sin(a),0)
            for a in [j*math.pi/2/24 for j in range(25)]],.024,.017)],finish_key,0)
    elif i==3:
        finish(name,[hollow(.022,.172,.016)],finish_key,.0004)
    elif i==4:
        # Source owner is rotated 90 degrees about Z: chart this top bend in
        # that frame and retain its short tail into the original valve body.
        points=[(-.045+.045*math.sin(a),.014-.045*math.cos(a),0)
            for a in [j*math.pi/2/24 for j in range(25)]]
        points.append((0,.031,0))
        finish(name,[sweep(points,.022,.016)],finish_key,0)
    elif i in [27,28]:
        finish(name,[hollow(p['radius'],p['height'],.021)],finish_key,.0004)
    elif i==31:
        cup=cylinder(p['radius'],p['height']);boolean(cup,cylinder(.019,p['height']+.004,at=(0,.003,0)),'DIFFERENCE')
        finish(name,[cup],finish_key,.0002)
    elif i==59:
        finish(name,[hollow(p['radius'],p['height'],.012,p['top'],.0079)],finish_key,.0004)
    elif i==60:
        finish(name,[hollow(p['radius'],p['height'],.012)],finish_key,.0004)
    elif p['type']=='BoxMesh': box(name,p['size'],finish_key,bevel=min(.0015,min(p['size'])*.18))
    elif p['type']=='CylinderMesh': finish(name,[cylinder(p['radius'],p['height'],p['top'])],finish_key,min(.0006,p['height']*.15))
    elif p['type']=='TorusMesh':
        bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=12,
            major_radius=(p['outer']+p['inner'])*.5,minor_radius=(p['outer']-p['inner'])*.5)
        finish(name,[bpy.context.object],finish_key,0)

finish('FoldCrown',[sweep([(.010*math.cos(a),.010*math.sin(a),0)
    for a in [j*math.pi/24 for j in range(25)]],.004,wide=.059)],'Linen',0)
finish('PipeUnit',[hollow(.055,1.,.043)],'Paint',.0005)
finish('UnionCollar',[hollow(.069,.070,.0548)],'Brass',.0005)
finish('PipeElbow',[sweep([(.18-.18*math.cos(a),.18*math.sin(a),0)
    for a in [j*math.pi/2/32 for j in range(33)]],.055,.043)],'Paint',0)
finish('WallSaddle',[cube((.11,.11,.012),(0,0,-.134)),
    cube((.016,.05,.090),(-.047,0,-.088)),cube((.016,.05,.090),(.047,0,-.088))],'Iron',.001)
finish('FootCap',[cylinder(.069,.025)],'Brass',.0005)
box('SaddleBolt',(.012,.008,.010),'Brass',bevel=.0008)
for label,height,branch_radius,branch_length,offset in [
    ('StationTee',.090,.031,.075,-.042),('FeedTee',.200,.062,.180,0)]:
    o=cylinder(.069,height)
    branch=cylinder(branch_radius,branch_length,at=(-branch_length*.5,0,offset))
    branch.rotation_euler.y=math.pi*.5
    bpy.context.view_layer.objects.active=branch
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    boolean(o,branch,'UNION')
    boolean(o,cylinder(.043,height+.020),'DIFFERENCE')
    bore=cylinder(.017 if label=='StationTee' else .043,branch_length+.060,
        at=(-branch_length*.5,0,offset));bore.rotation_euler.y=math.pi*.5
    bpy.context.view_layer.objects.active=bore
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    boolean(o,bore,'DIFFERENCE');finish(label,[o],'Brass',.0004)
finish('HangerRod',[cylinder(.004,1.)],'Iron',.0003)
finish('CeilingSeat',[cylinder(.022,.004)],'Iron',.0004)

# Flexible runs are baked in the source owner's four ordinary poses. The
# runtime selector follows source facts only; it never owns a maintenance state.
from mathutils import Matrix
for fresh in [False,True]:
    shift=.01475 if fresh else 0.;drop=.016 if fresh else 0.
    for broken in [False,True]:
        rot=Matrix.Rotation(.92 if broken else 0.,4,'X')@Matrix.Rotation(.30 if broken else 0.,4,'Z')
        end=Vector((.17,.430,.126) if broken else (.17,.520,.098))+rot.to_3x3()@Vector((0,-.075,0))
        start=Vector((.0205+shift,.411-drop,.100))
        a=start;control=start+Vector((.07,.03,0));c=end+Vector((0,-.07,0));d=end
        points=[tuple((1-t)**3*a+3*(1-t)**2*t*control+3*(1-t)*t*t*c+t**3*d) for t in [i/40 for i in range(41)]]
        finish('HoseLead%d%d'%(int(fresh),int(broken)),[sweep(points,.021)],'Linen',0)
    for coupled in [False,True]:
        angle=2.42 if coupled else 1.5708
        end=Vector((.045,.205,.120) if coupled else (-.060,.068,.112))+Matrix.Rotation(angle,3,'Z')@Vector((0,-.012,0))
        start=Vector((-.265+shift,.149-(.004 if fresh else 0.),.100))
        a=start;control=start+Vector((0,-.09,.02));c=end+Vector((-.09,-.025,0));d=end
        points=[tuple((1-t)**3*a+3*(1-t)**2*t*control+3*(1-t)*t*t*c+t**3*d) for t in [i/40 for i in range(41)]]
        finish('HoseTail%d%d'%(int(fresh),int(coupled)),[sweep(points,.021)],'Linen',0)

metrics={}
for o in bpy.context.scene.objects:
    if o.type!='MESH':continue
    o.data.calc_loop_triangles();uv=o.data.uv_layers.active;bad=0
    for tri in o.data.loop_triangles:
        a,c,d=[uv.data[i].uv for i in tri.loops]
        if tri.area>1e-12 and abs((c.x-a.x)*(d.y-a.y)-(d.x-a.x)*(c.y-a.y))<1e-12:bad+=1
    bm=bmesh.new();bm.from_mesh(o.data);edges=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    metrics[o.name]={'triangles':len(o.data.loop_triangles),'degenerate_uv':bad,'nonmanifold_edges':edges,'volume_m3':volume}
    assert edges==0 and volume>0 and bad==0,(o.name,edges,volume,bad)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_service.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/fire_service.glb'),export_format='GLB',export_yup=True,export_materials='EXPORT')
(OUT/'native-uv.json').write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
print('FIRE SERVICE',len(metrics),'stocks',sum(r['triangles'] for r in metrics.values()),'triangles')

