"""Repair the one collinear UV triangle in Jonah's approved hero.

Emit a tiny UV-only patch instead of re-exporting the approved skeleton.
The runtime applies it to a local mesh; original geometry, skin weights,
bone rest matrices and the personal animation bake remain untouched.
"""
from pathlib import Path
import hashlib, json
import bpy

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
source = ROOT/'game/assets/characters/jonah_price/jonah_price.gltf'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
repairs = []
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH' or not obj.vertex_groups: continue
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    for face in mesh.polygons:
        if len(face.loop_indices) != 3: raise ValueError('Expected approved triangulated mesh')
        loops = list(face.loop_indices)
        a, b, c = [uv[i].uv.copy() for i in loops]
        if abs((b-a).cross(c-a)) >= 1e-12: continue
        # 0.04 texel at the original 1024 atlas: retain the sampled fabric
        # while giving the nearly collinear source sliver a real derivative.
        before = b.copy(); after = b.copy(); after.x += .00004
        vertex = mesh.loops[loops[1]].vertex_index
        point = obj.matrix_world @ mesh.vertices[vertex].co
        changed = 0
        for loop in mesh.loops:
            if loop.vertex_index == vertex and (uv[loop.index].uv-before).length < 1e-7:
                uv[loop.index].uv = after; changed += 1
        # Blender Z-up -> original glTF/Godot Y-up. Keep all source axes.
        repairs.append({'position': [point.x, point.z, -point.y],
                        'before': list(before), 'after': list(after), 'native_loops': changed})
assert len(repairs) == 1, repairs
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/resident_atlas_uv_repair.blend'))
output = {'schema_version': 1, 'resident': 'jonah_price',
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'source': 'res://assets/characters/jonah_price/jonah_price.gltf',
          'repairs': repairs}
# Blender UV origin is bottom-left. Godot's glTF importer flips V.
for repair in repairs:
    for key in ('before', 'after'): repair[key][1] = 1.0-repair[key][1]
target = ROOT/'game/data/orison_v2/resident_atlas_uv_repair.json'
target.write_bytes((json.dumps(output, indent=2)+'\n').encode('utf8'))
print(json.dumps(output, indent=2))
