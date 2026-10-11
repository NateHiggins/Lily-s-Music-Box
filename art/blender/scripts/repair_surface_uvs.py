"""Repair collapsed UV polygons without moving vertices or changing topology.

Existing charts remain intact. Fallback charts use metre coordinates in the
object frame, with a projection that keeps every geometric triangle of the
polygon representable after glTF's float32 V flip. Call before save/export.
"""
import bpy
import numpy as np


def repair_mesh(obj):
    mesh = obj.data
    if not mesh.vertices or not mesh.polygons:
        return 0
    if not mesh.uv_layers:
        mesh.uv_layers.new(name='Metres')
    if mesh.uv_layers.active is None:
        mesh.uv_layers.active_index = 0
    uv = mesh.uv_layers.active.data
    mesh.calc_loop_triangles()
    groups = {}
    for tri in mesh.loop_triangles:
        groups.setdefault(tri.polygon_index, []).append(tuple(tri.loops))

    def area(loops):
        values = np.array([uv[i].uv[:] for i in loops], dtype=np.float32)
        values[:, 1] = np.float32(1) - values[:, 1]
        a, b = values[1]-values[0], values[2]-values[0]
        return float(a[0])*float(b[1])-float(a[1])*float(b[0])

    repaired = 0
    for polygon in mesh.polygons:
        triangles = []
        for loops in groups.get(polygon.index, []):
            points = np.array([mesh.vertices[mesh.loops[i].vertex_index].co[:] for i in loops])
            n = np.cross(points[1]-points[0], points[2]-points[0])
            length = np.linalg.norm(n)
            if length > 1e-9:
                triangles.append((loops, n/length))
        if not triangles or all(abs(area(loops)) > 1e-12 for loops, _ in triangles):
            continue
        normals = np.array([n for _, n in triangles])
        candidates = list(normals) + [np.array(v, dtype=float) for v in
                         [(1,1,1),(1,2,3),(3,1,2),(-1,2,3),(2,-3,1)]]
        candidates = [n/np.linalg.norm(n) for n in candidates]
        n = max(candidates, key=lambda n: np.abs(normals @ n).min())
        seed = np.eye(3)[np.argmin(np.abs(n))]
        u = np.cross(n, seed); u /= np.linalg.norm(u)
        v = np.cross(n, u)
        points = np.array([mesh.vertices[mesh.loops[i].vertex_index].co[:] for i in polygon.loop_indices])
        # Include object scale while keeping translation out of float32 UVs.
        linear = np.array(obj.matrix_world.to_3x3())
        points = (points-points[0]) @ linear.T
        values = np.column_stack((points @ u, points @ v))
        # Float32 1-V loses microscopic differences near zero. Put the
        # narrow dimension in U when necessary, without changing scale.
        for angle in [0., np.pi/2, np.pi/4, -np.pi/4]:
            rotation = np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])
            candidate = values @ rotation.T
            for loop, value in zip(polygon.loop_indices, candidate): uv[loop].uv = value
            if all(abs(area(loops)) > 1e-12 for loops, _ in triangles): break
        else:
            raise AssertionError((obj.name, polygon.index, values.tolist()))
        repaired += 1
    return repaired


def repair_scene():
    bpy.context.view_layer.update()
    # Export applies modifiers. Repair their final UVs rather than the cage,
    # where a bevel can still introduce a collapsed cap after this check.
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH' or not obj.modifiers: continue
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            if modifier.show_render:
                bpy.ops.object.modifier_apply(modifier=modifier.name)
    repaired = sum(repair_mesh(obj) for obj in bpy.context.scene.objects if obj.type == 'MESH')
    print('SURFACE UV REPAIR: %d polygons; vertex positions and topology retained' % repaired)
    return repaired
