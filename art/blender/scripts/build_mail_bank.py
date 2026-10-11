"""Reusable cast mail-bank stock, metre UVs and genuine open compartments."""
from pathlib import Path
import json, math
import bpy, bmesh

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'tmp/v2-mail-bank-20261011'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
materials = {}
for key in ['brass_dull', 'iron_blackened', 'wood_dark', 'nickel_plated', 'paper']:
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

# 96 mm-deep folded lining. The lining remains proud of the wall while
# keeping the original 85 mm envelopes behind the closed tenant leaf.
case = cube((.290, .128, .096), (0, 0, .048))
boolean(case, cube((.284, .122, .105), (0, 0, .0415)), 'DIFFERENCE')
finish('PocketCase', [case], 'iron_blackened', .0004)
# Offset tenant aperture leaves room for the separate carrier slot above it.
frame = cube((.300, .130, .008))
boolean(frame, cube((.278, .108, .025), (0, -.008, 0)), 'DIFFERENCE')
boolean(frame, cube((.224, .006, .025), (0, .053, 0)), 'DIFFERENCE')
finish('CastFrame', [frame], 'brass_dull', .0006)
box('LeafShell', (.274, .104, .008), 'brass_dull', bevel=.001)
ring = cube((.155, .048, .004))
boolean(ring, cube((.145, .039, .012)), 'DIFFERENCE')
finish('CardFrame', [ring], 'brass_dull', .0004)
box('CarrierFlap', (.224, .005, .003), 'brass_dull', bevel=.0004)
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.011, depth=.012)
lock = bpy.context.object; lock.rotation_euler.x = math.pi/2
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
boolean(lock, cube((.0018, .0065, .024)), 'DIFFERENCE')
finish('CylinderLock', [lock], 'nickel_plated', .0004)
box('KeywayBack', (.0022, .007, .0008), 'iron_blackened', (0, 0, .0045), .0001)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=.003, depth=.024)
finish('HingeBarrel', [bpy.context.object], 'brass_dull', .0003)
# Butted timber rails leave the entire compartment field open. The moulded
# crown and its bead are distinct pieces, with horizontal grain charts.
box('TimberStile', (.060, 1.390, .050), 'wood_dark', bevel=.0015)
box('TimberLowerPanel', (1.240, .380, .050), 'wood_dark', bevel=.0015)
box('TimberHeaderRail', (1.240, .170, .050), 'wood_dark', bevel=.0015, horizontal=True)
finish('TimberCrown', [cube((1.360, .018, .016), (0, .004, 0)),
                       cube((1.340, .012, .011), (0, -.008, .0025))],
       'wood_dark', .0012, horizontal_grain=True)
box('HeaderPlate', (1.180, .130, .010), 'brass_dull', bevel=.001)
outgoing = cube((.300, .100, .012))
boolean(outgoing, cube((.204, .018, .030), (0, .015, 0)), 'DIFFERENCE')
finish('OutgoingPlate', [outgoing], 'brass_dull', .0008)
box('OutgoingFlap', (.210, .030, .006), 'brass_dull', bevel=.0007)
box('OutgoingPocket', (.216, .025, .002), 'iron_blackened', bevel=.0003)
# Delivery visuals keep their catalog/state owner but retire the solid V1 bricks.
box('EnvelopeStock', (.125, .0015, .085), 'paper', bevel=.0002)
finish('WorkOrderStock', [cube((.0012, .100, .062), (x, 0, 0))
                         for x in [-.0048, -.0016, .0016, .0048]], 'paper', .0002)
box('ParcelStock', (.130, .085, .055), 'paper', bevel=.001)
finish('ParcelBand', [cube((.133, .012, .0015), (0, 0, -.02825)),
                      cube((.133, .012, .0015), (0, 0, .02825))] +
                     [cube((.0015, .012, .055), (x, 0, 0)) for x in [-.06575, .06575]],
       'paper', .0002)

metrics = {}
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    o.data.calc_loop_triangles(); uv = o.data.uv_layers.active; bad = 0
    for t in o.data.loop_triangles:
        a, c, d = [uv.data[i].uv for i in t.loops]
        if t.area > 1e-12 and abs((c.x-a.x)*(d.y-a.y)-(d.x-a.x)*(c.y-a.y)) < 1e-12: bad += 1
    bm = bmesh.new(); bm.from_mesh(o.data)
    edges = sum(not e.is_manifold for e in bm.edges); volume = bm.calc_volume(signed=True)
    bm.free()
    metrics[o.name] = {'triangles': len(o.data.loop_triangles), 'degenerate_uv': bad,
                       'nonmanifold_edges': edges, 'volume_m3': volume}
    assert edges == 0 and volume > 0 and bad == 0, (o.name, edges, volume, bad)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/mail_bank.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/mail_bank.glb'),
                          export_format='GLB', export_yup=True, export_materials='EXPORT')
(OUT/'native-uv.json').write_text(json.dumps(metrics, indent=2)+'\n', encoding='utf8')
