"""Native electrical service stock; fixed fabric, no new circuit authority."""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'tmp/v2-electrical-service-20261011'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
materials = {}
for key in ('iron_neutral', 'galvanized_roof', 'brass_dull'):
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    materials[key] = mat

def point(v): return (v[0], -v[2], v[1])

def cube(size, at=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(at))
    o = bpy.context.object
    o.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o

def cylinder(radius, height, at=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=height, location=point(at))
    o = bpy.context.object
    for face in o.data.polygons: face.use_smooth = abs(face.normal.z) < .5
    return o

def cut(o, cutter):
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('Actual open bore', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'; mod.solver = 'EXACT'; mod.object = cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return o

def ring(radius, inside, height, at=(0,0,0)):
    return cut(cylinder(radius,height,at), cylinder(inside,height+.01,at))

def finish(name, objects, key, bevel=.0005):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join(); o = bpy.context.object
    bpy.context.scene.cursor.location = (0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR'); o.name = name
    if bevel:
        mod = o.modifiers.new('Worked edge', 'BEVEL'); mod.width = bevel; mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.clear(); o.data.materials.append(materials[key])
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
    mod = o.modifiers.new('Stable charts','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=mod.name)
    for layer in list(o.data.uv_layers): o.data.uv_layers.remove(layer)
    uv = o.data.uv_layers.new(name='MetreStock')
    for face in o.data.polygons:
        axis = max(range(3),key=lambda i:abs(face.normal[i]))
        a,b = [(1,2),(0,2),(0,1)][axis]
        for loop in face.loop_indices:
            p = o.data.vertices[o.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[a],p[b])
    return o

finish('ConduitUnit',[ring(.0225,.0185,1)],'galvanized_roof',.0002)
finish('ThreadedCoupling',[ring(.029,.0227,.045)],'iron_neutral',.0004)
finish('FloorSleeve',[ring(.033,.027,.20)],'iron_neutral',.0004)
finish('FloorEscutcheon',[ring(.038,.027,.004)],'iron_neutral',.0005)
finish('ConduitCap',[cylinder(.026,.008)],'iron_neutral')

# A genuinely hollow casting with open top/bottom conduit entries. The screw
# cover is separate; it is fixed service fabric, not an invented control.
shell = cube((.16,.24,.075),(0,0,-.0025))
cut(shell,cube((.144,.224,.080),(0,0,.010)))
cut(shell,cylinder(.0255,.30))
finish('JunctionCasting',[shell],'iron_neutral',.0007)
finish('JunctionCover',[cube((.156,.236,.004),(0,0,.037))],'iron_neutral',.0007)
for y in (-.12,.12):
    finish('EntryBush'+('Upper' if y>0 else 'Lower'),[ring(.030,.0227,.014,(0,y,0))],'iron_neutral',.0003)

# Local rear plane -0.04 contacts the authored wall; rotated on installation.
plate = cube((.072,.068,.004),(0,0,-.038))
stand = cube((.016,.040,.012),(0,0,-.030))
band = ring(.026,.0227,.024)
finish('WallSaddle',[plate,stand,band],'iron_neutral',.0003)

def screw(at):
    o = cylinder(.0035,.003,at)
    o.rotation_euler.x = math.pi*.5
    slot = cube((.005,.0008,.005),(at[0],at[1],at[2]+.001))
    cut(o,slot)
    return o
finish('CoverScrews',[screw((x,y,.040)) for x in (-.058,.058) for y in (-.096,.096)],'brass_dull',.00015)
finish('SaddleScrews',[screw((x,0,-.034)) for x in (-.026,.026)],'brass_dull',.00015)

rows=[]
for o in bpy.context.scene.objects:
    if o.type!='MESH': continue
    bm=bmesh.new(); bm.from_mesh(o.data)
    manifold=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    bad_uv=0;bad_tri=0
    for f in o.data.polygons:
        p=[o.data.vertices[i].co for i in f.vertices]
        q=[Vector(o.data.uv_layers.active.data[i].uv) for i in f.loop_indices]
        if (p[1]-p[0]).cross(p[2]-p[0]).length < 1e-13:bad_tri+=1
        if abs((q[1]-q[0]).cross(q[2]-q[0])) < 1e-13:bad_uv+=1
    row={'name':o.name,'triangles':len(o.data.polygons),'manifold':manifold,'volume':volume,'degenerate_triangles':bad_tri,'degenerate_uv':bad_uv}
    rows.append(row)
    assert manifold and volume>0 and not bad_uv and not bad_tri,row
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/electrical_service.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/electrical_service.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
(OUT/'native-uv.json').write_text(json.dumps({'evidence_class':'INERT','units':'metres','stocks':rows},indent=2)+'\n',encoding='utf-8',newline='\n')
print('ELECTRICAL STOCK:',len(rows),'partitions;',sum(r['triangles'] for r in rows),'triangles')
