"""Shared native primitives; metres, no gameplay ownership."""
import bpy, math
from mathutils import Vector
def ellipsoid(name, at, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def tube(name, a, b, radius, segments=24):
    a, b = (Vector(a), Vector(b))
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=delta.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj

def boolean(body, other, operation):
    bpy.context.view_layer.objects.active = body
    mod = body.modifiers.new('Foundry ' + operation, 'BOOLEAN')
    mod.operation = operation
    mod.solver = 'EXACT'
    mod.object = other
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(other, do_unlink=True)

def lathe(name, profile, sides=64):
    vertices = []
    faces = []
    for x, radius in profile:
        for index in range(sides):
            angle = index * math.tau / sides
            vertices.append((x, radius * math.cos(angle), radius * math.sin(angle)))
    for row in range(len(profile)):
        other = (row + 1) % len(profile)
        for index in range(sides):
            peer = (index + 1) % sides
            faces.append((row * sides + index, row * sides + peer, other * sides + peer, other * sides + index))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def sphere_profile(radius, start, end, steps):
    return [(start + (end - start) * i / steps, math.sqrt(radius * radius - (start + (end - start) * i / steps) ** 2)) for i in range(steps + 1)]
