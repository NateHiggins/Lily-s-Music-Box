"""Fabricate the four authored ventilation stacks with continuous sheet airways.

Layout anchors and the projected ventilation graph remain the route authority.
Construction volumes and airway cutters stay editable in the native blend.
"""
from pathlib import Path
import json
import time
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
layout = json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text())
graph = json.loads((ROOT / 'game/data/orison_v2/completion_interiors.json').read_text())['ventilation']
levels = {r['id']: float(r['y']) for r in layout['levels']}
anchors = {r['id']: r for r in layout['anchors']}
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}
for key in ['metal', 'cast_iron']:
    materials[key] = bpy.data.materials.new(key)
    materials[key].diffuse_color = (.32, .31, .28, 1)
finished = []
reports = []


def placement(identity):
    anchor = anchors[identity]
    p = anchor['position']
    return Vector((p[0], levels[anchor['level']] + p[1], p[2]))


def point(p):
    return Vector((p[0], -p[2], p[1]))


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def cube(name, at, size, target):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(at))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)
    return obj


def apply_collection(obj, target, operation):
    modifier = obj.modifiers.new(operation + ' construction volumes', 'BOOLEAN')
    modifier.operation = operation
    modifier.solver = 'EXACT'
    modifier.operand_type = 'COLLECTION'
    modifier.collection = target
    modifier.use_self = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def triangle_area(face):
    # BMesh's float area test retained three exactly collinear triangles.
    # Evaluate exported float coordinates in double precision instead.
    points = np.array([tuple(vertex.co) for vertex in face.verts], dtype=np.float64)
    assert len(points) == 3
    return float(np.linalg.norm(np.cross(points[1]-points[0], points[2]-points[0])))*.5


def ill_conditioned(face):
    area = triangle_area(face)
    longest = max(edge.calc_length() for edge in face.edges)
    # Submicrometre slivers along multi-metre faces lose their UV determinant
    # in float storage. Dissolve their diagonals without moving the boundary.
    return area<1e-12 or area/max(longest*longest,1e-20)<1e-6


def finish(parts, airway, name, material):
    shell = list(parts.objects)[0]
    parts.objects.unlink(shell)
    bpy.context.scene.collection.objects.link(shell)
    apply_collection(shell, parts, 'UNION')
    apply_collection(shell, airway, 'DIFFERENCE')
    shell.name = name
    shell.data.materials.clear()
    shell.data.materials.append(materials[material])
    bpy.ops.object.select_all(action='DESELECT')
    shell.select_set(True)
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = bmesh.new()
    mesh.from_mesh(shell.data)
    # Coincident Boolean joints differ by a few single-precision micrometres
    # in this 19 m world frame. Weld those slivers before the strict shell check.
    bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=.000005)
    loose = [edge for edge in mesh.edges if not edge.link_faces]
    bmesh.ops.delete(mesh, geom=loose, context='EDGES')
    unused = [vertex for vertex in mesh.verts if not vertex.link_faces]
    bmesh.ops.delete(mesh, geom=unused, context='VERTS')
    nonmanifold = sum(not edge.is_manifold for edge in mesh.edges)
    assert nonmanifold == 0, f'{name}: {nonmanifold} nonmanifold edges'
    bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
    # Boolean n-gons can triangulate through a collinear junction vertex.
    # Dissolve zero-area faces/diagonals, retaining a closed manifold shell.
    degenerate_before = sum(ill_conditioned(face) for face in mesh.faces)
    for attempt in range(8):
        degenerate = [face for face in mesh.faces if ill_conditioned(face)]
        if not degenerate:
            break
        bmesh.ops.dissolve_faces(mesh, faces=degenerate, use_verts=True)
        bmesh.ops.dissolve_degenerate(mesh, dist=.000005, edges=list(mesh.edges))
        bmesh.ops.triangulate(mesh, faces=list(mesh.faces), ngon_method='EAR_CLIP')
    for attempt in range(8):
        degenerate = [face for face in mesh.faces if ill_conditioned(face)]
        if not degenerate:
            break
        diagonals = {max(face.edges, key=lambda edge: edge.calc_length()) for face in degenerate}
        bmesh.ops.dissolve_edges(mesh, edges=list(diagonals), use_verts=True, use_face_split=False)
        bmesh.ops.triangulate(mesh, faces=list(mesh.faces), ngon_method='EAR_CLIP')
    assert all(not ill_conditioned(face) for face in mesh.faces), f'{name}: ill-conditioned triangle remains'
    nonmanifold = sum(not edge.is_manifold for edge in mesh.edges)
    assert nonmanifold == 0, f'{name}: conditioning opened the sheet shell'
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    mesh.to_mesh(shell.data)
    mesh.free()
    shell.data.update()
    for layer in list(shell.data.uv_layers):
        shell.data.uv_layers.remove(layer)
    uv = shell.data.uv_layers.new(name='Metres')
    uv.active_render = True
    loop_normals = [(0,0,1)]*len(shell.data.loops)
    for face in shell.data.polygons:
        points = np.array([tuple(shell.data.vertices[index].co) for index in face.vertices], dtype=np.float64)
        normal = np.cross(points[1]-points[0], points[2]-points[0])
        normal /= np.linalg.norm(normal)
        axis = int(np.argmax(np.abs(normal)))
        axes = ((1, 2), (0, 2), (0, 1))[axis]
        origin = shell.data.vertices[face.vertices[0]].co
        for loop in face.loop_indices:
            vertex = shell.data.vertices[shell.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (vertex[axes[0]]-origin[axes[0]], vertex[axes[1]]-origin[axes[1]])
            loop_normals[loop] = tuple(normal)
    shell.data.normals_split_custom_set(loop_normals)
    finished.append(shell)
    return {'partition': name, 'vertices': len(shell.data.vertices),
            'triangles': len(shell.data.polygons), 'nonmanifold_edges': nonmanifold,
            'discarded_loose_edges': len(loose), 'degenerate_triangles_conditioned': degenerate_before}


for specification in graph['stacks']:
    identity = specification['id']
    started = time.monotonic()
    outer = collection(identity + '_AuthoredOuterSections')
    inner = collection(identity + '_AirwayCutters')
    seams = collection(identity + '_SeamConstruction')

    def boxes(name, at, size, open_axis=None):
        cube(name, at, size, outer)
        cavity = size - Vector((.004, .004, .004))
        if open_axis is not None:
            # Seam shoes project 7 mm below the 90 mm plenum. Extend the
            # register cutter beyond them so no seam becomes a false end cap.
            cavity[open_axis] = size[open_axis] + .05
        cube(name + 'Airway', at, cavity, inner)

    def segment(name, a, b, upper_limit=None):
        delta = Vector(abs(value) for value in (b-a))
        if delta.length < .001:
            return
        axis = max(range(3), key=lambda i: delta[i])
        size = Vector((.18, .18, .18))
        size[axis] = delta[axis] + .18
        at = (a+b)*.5
        if upper_limit is not None:
            low = at.y-size.y/2
            size.y = upper_limit-low
            at.y = (upper_limit+low)/2
        boxes(name, at, size)
        count = max(1, math.ceil(delta[axis]/1.2))
        for i in range(count+1):
            band = Vector((.194, .194, .194))
            band[axis] = .025
            cube(name + f'Seam{i:02d}', a.lerp(b, i/count), band, seams)

    fan = placement('ROOF_VENT_FAN_' + identity)
    top = Vector((specification['riser'][0], fan.y-.22, specification['riser'][1]))
    lowest = top.y
    ports = []
    for record in graph['registers']:
        if record['stack'] != identity:
            continue
        grille = placement(record['anchor'])
        start = grille+Vector((0, .09, 0))
        lowest = min(lowest, start.y)
        end = Vector((top.x, start.y, top.z))
        corner = (Vector((end.x, start.y, start.z)) if specification['branch_axis'] == 'xz'
                  else Vector((start.x, start.y, end.z)))
        boxes(record['anchor']+'Plenum', grille+Vector((0, .045, 0)), Vector((.36, .09, .34)), 1)
        segment(record['anchor']+'First', start, corner)
        segment(record['anchor']+'Second', corner, end)
        ports.append({'id': record['anchor'], 'at': list(grille)})
    segment('VerticalStack', Vector((top.x, lowest, top.z)), top)
    corner = Vector((fan.x, top.y, top.z))
    end = Vector((fan.x, top.y, fan.z))
    segment('RoofFirst', top, corner)
    segment('RoofSecond', corner, end)
    segment('RoofUptake', end, fan+Vector((0, .08, 0)), fan.y+.169)
    cube('FanMouthCut', fan+Vector((0, .155, 0)), Vector((.176, .12, .176)), inner)
    partitions = [finish(outer, inner, identity+'_metal', 'metal'),
                  finish(seams, inner, identity+'_cast_iron', 'cast_iron')]
    for target in [outer, inner, seams]:
        target.hide_render = True
        target.hide_viewport = True
    reports.append({'stack': identity, 'register_ports': ports, 'fan': list(fan),
                    'partitions': partitions, 'generation_seconds': time.monotonic()-started})

bpy.ops.object.select_all(action='DESELECT')
for obj in finished:
    obj.select_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ventilation_ducts.blend'))


class PlanarSheetTangents:
    """Author exact planar UV derivatives through Blender's export hook.

    MikkTSpace's corner weighting yields zero tangents at some narrow Boolean
    junctions. The sheet's active UV planes define an analytic tangent basis.
    This runs before serialization; no exported glTF is edited afterward.
    """
    partitions = 0
    vertices = 0

    def gather_attribute_change(self, attribute, data, normalized, export_settings):
        if attribute == 'NORMAL':
            self.normals = np.array(data['data'], dtype=np.float64).reshape(-1, 3)
        elif attribute == 'TANGENT':
            normals = self.normals
            result = np.zeros((len(normals), 4), dtype=np.float32)
            # glTF is Y-up and flips UV V; these are the Metres planes after
            # Blender (x,y,z) becomes glTF (x,z,-y).
            planes = [((0,0,-1),(0,-1,0)), ((1,0,0),(0,0,1)), ((1,0,0),(0,-1,0))]
            for i, normal in enumerate(normals):
                u, v = (np.array(axis, dtype=np.float64) for axis in planes[int(np.argmax(np.abs(normal)))])
                tangent = np.cross(normal, v)
                if np.dot(tangent, u) < 0:
                    tangent = -tangent
                tangent /= np.linalg.norm(tangent)
                bitangent = np.cross(normal, u)
                if np.dot(bitangent, v) < 0:
                    bitangent = -bitangent
                result[i, :3] = tangent
                result[i, 3] = 1 if np.dot(np.cross(normal, tangent), bitangent) > 0 else -1
            assert data['data'].shape == result.shape
            data['data'] = result
            type(self).partitions += 1
            type(self).vertices += len(result)


import io_scene_gltf2
assert 'io_scene_gltf2' in bpy.context.preferences.addons
io_scene_gltf2.glTF2ExportUserExtension = PlanarSheetTangents
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/ventilation_ducts.glb'),
                          export_format='GLB', export_yup=True, export_tangents=True, use_selection=True)
assert PlanarSheetTangents.partitions == 8, 'Planar tangent export hook did not author every partition'
out = ROOT/'tmp/roof-throats'
out.mkdir(parents=True, exist_ok=True)
(out/'generation.json').write_text(json.dumps({'evidence_class': 'INERT', 'stacks': reports,
    'planar_tangent_vertices': PlanarSheetTangents.vertices}, indent=1)+'\n')
print('HOLLOW VENTILATION DUCTS', json.dumps(reports))
