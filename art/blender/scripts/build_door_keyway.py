"""Native through-keyways matching the retained mortise escutcheon.

Two unscaled 60-mm lock-stile inserts replace the corresponding solid patch
in 44/52-mm V2 leaves. The actor retains all collision and lock authority.
"""
from pathlib import Path
import ast, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'tmp/v2-door-polish-20261012'
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

def cube(size, at):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def subtract(obj, tool):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Full-depth keyway', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.solver = 'EXACT'
    mod.object = tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool, do_unlink=True)

stats = []
for depth in [.044, .052]:
    # Blender X,Y,Z maps to Godot X,-Z,Y; local keyway stem at zero.
    obj = cube((.060, depth, .060), (0, 0, 0))
    obj.name = 'Keyway%d' % round(depth * 1000)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.004,
        depth=depth+.020, location=(0, 0, .008), rotation=(math.pi/2, 0, 0))
    subtract(obj, bpy.context.object)
    subtract(obj, cube((.005, depth+.020, .013), (0, 0, 0)))
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), obj.name
    assert bm.calc_volume(signed=True) > 0, obj.name
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data); bm.free()
    uv = obj.data.uv_layers.new(name='MetreUV')
    for face in obj.data.polygons:
        p = np.array([obj.data.vertices[i].co[:] for i in face.vertices])
        _, _, values, _ = chart_for_triangle(p, np.zeros(3), 1.2)
        for loop, value in zip(face.loop_indices, values): uv.data[loop].uv = value
    # Rays must pass through both round and stem, but hit the surrounding wood.
    for x, z, clear in [(0,.008,True),(0,0,True),(.006,.008,False),(.004,0,False)]:
        hit, *_ = obj.ray_cast(Vector((x,-depth,z)), Vector((0,1,0)))
        assert hit != clear, (obj.name, x, z, hit)
    stats.append({'name':obj.name,'triangles':len(obj.data.polygons),
                  'closed':True,'round_and_stem_clear':True})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/door_keyway.blend'))
# Match derivatives to final float32 export values, as on the radio bores.
path = Path(__file__).with_name('build_media_battery_supply.py')
tree = ast.parse(path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef)
    and n.name=='ExportDerivatives'],type_ignores=[]),str(path),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportDerivatives
asset = ROOT/'game/assets/props/door_keyway.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',
    export_tangents=True,export_apply=True,export_lights=False,export_cameras=False)
from check_exported_tangents import validate
result = {'evidence_class':'INERT','native':stats,'export':validate(asset)}
(OUT/'keyway_construction.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
