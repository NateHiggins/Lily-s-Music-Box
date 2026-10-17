"""Review saved vent prototype after reboot; diagnostic only, no asset edits."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import hashlib, json, os
import bpy, bmesh
from mathutils import Vector
P = output_directory()
suffix = '_finished' if os.environ.get('RADIATOR_FINISHED_REVIEW') == '1' else ''
native = P / ('automatic_vent' + suffix + '_candidate.blend')
bpy.ops.wm.open_mainfile(filepath=str(native))
sources = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new('Diagnostic vent studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
scene.world = world
bpy.ops.object.camera_add(location=(0.18, 0.28, 0.14))
camera = bpy.context.object
camera.data.type = 'ORTHO'
scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(0.02, 0.2, 0.23))
light = bpy.context.object
light.data.energy = 12
light.data.size = 0.2
light.rotation_euler = (Vector((0.043, 0, 0.03)) - light.location).to_track_quat('-Z', 'Y').to_euler()
images = []
for label, cut, lift in [('assembled', False, 0), ('cold_cutaway', True, 0), ('closed_cutaway', True, 0.0055)]:
    shown = []
    for name in ['VentBody', 'VentCap', 'FloatAndNeedle', 'VentOrificeInsert_2']:
        obj = sources[name].copy()
        obj.data = sources[name].data.copy()
        obj.hide_render = False
        bpy.context.collection.objects.link(obj)
        if name == 'FloatAndNeedle':
            for vertex in obj.data.vertices:
                vertex.co.z += lift
        if cut and name in ['VentBody', 'VentCap', 'VentOrificeInsert_2']:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=(0, 0, 0), plane_no=(0, 1, 0), clear_outer=True, dist=1e-08)
            bm.to_mesh(obj.data)
            bm.free()
        shown.append(obj)
    target = Vector((0.028, 0, 0.031))
    camera.location = (0.12, 0.28, 0.1) if not cut else (0.058, 0.3, 0.075)
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = 0.13
    path = P / ('vent' + suffix + '_' + label + '.png')
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    images.append(dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for obj in shown:
        bpy.data.objects.remove(obj, do_unlink=True)
(P / ('automatic_vent' + suffix + '_captures.json')).write_text(json.dumps(dict(evidence_class='INERT', scope='Uninstalled native diagnostic, provisional finish. Cutaway exposes float and needle; no production or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), images=images), indent=2) + '\n')
