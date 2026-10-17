"""Uninstalled split fibrous packing liner with a peelable native shape key.

The permanent metal bearing ring remains hardware. This cloth is the single
removable seal proposed for the existing inventory item, not a new custodian.
"""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, json, math, hashlib, sys
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
P = output_directory()
R = repository_root()
source = P / 'articulated_union_finished_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
objects = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
parsed = ast.parse(primitive_source().read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['lathe', 'sphere_profile']], type_ignores=[]), '<native packing profiles>', 'exec'))
old = objects['HeaderSphericalSocket']
socket = lathe('PackedHeaderSocket', sphere_profile(0.042, 0, 0.023, 18) + [(0.025, 0.0265), (0.045, 0.0265), (0.045, 0.019), (0.027, 0.019)] + list(reversed(sphere_profile(0.0328, 0, 0.025, 18))))
socket.data.materials.clear()
for mat in old.data.materials:
    socket.data.materials.append(mat)
old.hide_render = True
profile = sphere_profile(0.0328, 0.0002, 0.025, 12) + list(reversed(sphere_profile(0.032, 0.0002, 0.025, 12)))
segments = 96
vertices = []
faces = []
opened = []
for step in range(segments + 1):
    t = step / segments
    angle = math.pi + 0.001 + t * (math.tau - 0.002)
    open_angle = math.radians(255) + t * math.radians(210)
    scale = (math.tau - 0.002) / math.radians(210)
    for axial, radius in profile:
        vertices.append((axial, radius * math.cos(angle), radius * math.sin(angle)))
        opened.append((axial, radius * scale * math.cos(open_angle), radius * scale * math.sin(open_angle)))
width = len(profile)
for step in range(segments):
    for i in range(width):
        j = (i + 1) % width
        faces.append((step * width + i, step * width + j, (step + 1) * width + j, (step + 1) * width + i))
faces.extend([tuple(reversed(range(width))), tuple((segments * width + i for i in range(width)))])
mesh = bpy.data.meshes.new('SplitUnionCloth')
mesh.from_pydata(vertices, [], faces)
mesh.update()
packing = bpy.data.objects.new('RemovableFibrousUnionPacking', mesh)
bpy.context.collection.objects.link(packing)
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.triangulate(bm, faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(mesh)
bm.free()
packing.shape_key_add(name='Seated')
key = packing.shape_key_add(name='SpreadForRemoval')
for vertex, p in zip(key.data, opened):
    vertex.co = p
mat = bpy.data.materials.new('UNREGISTERED_graphited_cloth')
mat.use_nodes = True
principled = mat.node_tree.nodes['Principled BSDF']
principled.inputs['Metallic'].default_value = 0
coords = mat.node_tree.nodes.new('ShaderNodeTexCoord')
scale_node = mat.node_tree.nodes.new('ShaderNodeVectorMath')
scale_node.operation = 'SCALE'
scale_node.inputs['Scale'].default_value = 125
mat.node_tree.links.new(coords.outputs['UV'], scale_node.inputs[0])
for name, target in [('albedo', 'Base Color'), ('roughness', 'Roughness'), ('normal', 'Normal')]:
    texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = bpy.data.images.load(str(P / 'graphited_cloth' / (name + '.png')))
    if name != 'albedo':
        texture.image.colorspace_settings.name = 'Non-Color'
    mat.node_tree.links.new(scale_node.outputs[0], texture.inputs[0])
    if name == 'normal':
        normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = 0.5
        mat.node_tree.links.new(texture.outputs[0], normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs[0], principled.inputs[target])
    else:
        mat.node_tree.links.new(texture.outputs[0], principled.inputs[target])
mesh.materials.append(mat)
objects['FixedStemPacking'].data.materials.clear()
objects['FixedStemPacking'].data.materials.append(mat)
objects['FixedStemPacking']['finish_pending'] = 'Register graphited_packing and bind the runtime material before installation.'
sys.path.insert(0, str(R / 'art/blender/scripts'))
from fabrication_normals import stock_corner_normals
for obj in [socket, packing]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.data.uv_layers.new(name='Metres')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.01)
    bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
    bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.005)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.calc_loop_triangles()
    uv = obj.data.uv_layers.active.data

    def area(tri):
        a, b, c = [uv[i].uv for i in tri.loops]
        return abs((b - a).cross(c - a)) * 0.5
    scale = math.sqrt(sum((t.area for t in obj.data.loop_triangles)) / sum((area(t) for t in obj.data.loop_triangles)))
    for loop in uv:
        loop.uv *= scale
    obj.data.normals_split_custom_set(stock_corner_normals(obj.data))
    for face in obj.data.polygons:
        face.use_smooth = True
    obj.hide_render = True
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))

def tree(obj, xf=Matrix.Identity(4), spread=0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    if obj == packing:
        for v, rest, unbent in zip(bm.verts, vertices, opened):
            v.co = Vector(rest).lerp(Vector(unbent), spread)
    bm.transform(xf)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
for obj in [socket, packing]:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    check('new sealing stock has closed positive walls', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)), volume_m3=bm.calc_volume(signed=True))
    bm.free()
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())['poses']
for row in poses:
    a = Vector(row['fixed_joint'])
    b = Vector(row['header_joint'])
    beta = row['feed_angle_radians']
    theta = row['body_angle_radians']
    count = row['sections']
    up = Matrix.Translation(a) @ Matrix.Rotation(-beta, 4, 'Y')
    down = Matrix.Translation(b) @ Matrix.Rotation(-theta, 4, 'Y')
    bearing = Matrix.Translation(b) @ Matrix.Rotation(-beta, 4, 'Y')
    for label, owner_tree in [('ball', tree(objects['SphericalNeck_%d' % count], up)), ('cup', tree(socket, down))]:
        worst = 0.0
        inside = 0
        for point in vertices:
            world_point = down @ Vector(point)
            hit, normal, face, distance = owner_tree.find_nearest(world_point)
            signed = (world_point - hit).dot(normal)
            if signed < 0:
                inside += 1
                worst = max(worst, -signed)
        check('seated cloth stays within its bounded compression allowance', worst <= 0.0001, sections=count, pitch=row['pitch'], owner=label, inside_samples=inside, maximum_compression_m=worst, allowance_m=0.0001)
    for part, xf in [(objects['SphericalNeck_%d' % count], up), (objects['FloatingMetalBearingRing'], bearing), (objects['HeaderSphericalRetainer'], down)]:
        hits = tree(socket, down).overlap(tree(part, xf))
        check('lined socket preserves metal-part clearance', not hits, sections=count, pitch=row['pitch'], other=part.name, triangle_pairs=len(hits))
    other_trees = [('neck', tree(objects['SphericalNeck_%d' % count], up)), ('bearing', tree(objects['FloatingMetalBearingRing'], bearing)), ('socket', tree(socket, Matrix.Translation((0.04, 0, 0)) @ down)), ('retainer', tree(objects['HeaderSphericalRetainer'], Matrix.Translation((0.04, 0, 0)) @ down @ Matrix.Translation((0.001, 0, 0))))]
    for progress in [0.25, 0.5, 0.75, 1]:
        spread = min(progress / 0.5, 1)
        offset = max((progress - 0.5) / 0.5, 0) * 0.12
        cloth = tree(packing, Matrix.Translation((0, offset, 0)) @ down, spread)
        for label, other in other_trees:
            hits = cloth.overlap(other)
            check('opened packing can unbend and leave its actual pipe', not hits, sections=count, pitch=row['pitch'], progress=progress, other=label, triangle_pairs=len(hits))
native = P / 'packed_union_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='Uninstalled split graphited fibre liner and revised socket; native peel diagnostic only. Existing metal bearing remains permanent. No registered material, runtime custody, room fit, loaded mipmaps, pressure or human acceptance.', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'union_packing_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('UNION PACKING', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError('Packing geometry needs refitting')
