"""Editable bounded subgrade fitted to retained owners; whole-shell readiness is open."""
from pathlib import Path
import json
import math
import collections
import hashlib
import bpy
import bmesh
import numpy as np
from mathutils import Vector

root = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
base = root / 'art/blender'
work = root/'tmp/orison-ground'; work.mkdir(parents=True,exist_ok=True)
plan = json.loads((root/'art/data/orison_ground/retained_grade_source.json').read_text(encoding='utf-8'))
foundation_path=base/'city_foundations_construction.json'
foundation=json.loads(foundation_path.read_text(encoding='utf-8'))
plan['retained_solids'].extend(foundation['components'])
plan['bindings'].update(foundation['bindings'])
plan['bindings']['art/blender/city_foundations_construction.json']=hashlib.sha256(foundation_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
for profile in foundation['profiles']:
    x0,z0,x1,z1=profile['underside']
    plan['surface_exclusions'].append({'owner':profile['id'],'kind':'actual_planar_native_underside_projection','bounds':[x0,plan['soil_bottom'],z0,x1,0,z1]})
reservations_path=base/'alley_groundworks_reservations.json'
reservations=json.loads(reservations_path.read_text(encoding='utf-8'))
plan['occupation_reservations'].extend(reservations['reservations'])
plan['surface_exclusions'].append(next(r for r in reservations['reservations'] if r['owner']=='BoilerWell/ConstructionAndAir'))
plan['bindings'].update(reservations['bindings'])
plan['bindings']['art/blender/alley_groundworks_reservations.json']=hashlib.sha256(reservations_path.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
for relative, expected in plan['bindings'].items():
    path = root / relative
    raw = path.read_bytes() if path.suffix in ['.blend','.glb'] else path.read_text(encoding='utf-8').replace('\r\n', '\n').encode()
    assert hashlib.sha256(raw).hexdigest() == expected, relative
a, b, c, d = plan['region']
low = plan['soil_bottom']; asphalt_low, top = plan['asphalt_y']
masks = plan['retained_solids'] + plan['occupation_reservations']
limits = [(a, c), (low, top), (b, d)]
coordinates = []
for axis, (start, end) in enumerate(limits):
    values = {start, end}
    if axis == 1: values.add(asphalt_low)
    else: values.update(4 * index for index in range(math.ceil(start / 4), math.ceil(end / 4)) if start < 4 * index < end)
    for row in masks + plan['surface_exclusions']:
        bounds = row['bounds']
        values.update(round(value, 5) for value in [bounds[axis], bounds[axis + 3]] if start < value < end)
    coordinates.append(sorted(values))
xs, ys, zs = coordinates
indexes = [{value: index for index, value in enumerate(values)} for values in coordinates]
size = tuple(len(values) - 1 for values in coordinates)
assert all(value > 0 for value in size)
solid = np.ones(size, dtype=bool)
retained = np.zeros(size, dtype=bool)

def slices(bounds):
    result = []
    for axis, (start, end) in enumerate(limits):
        lo = max(start, round(bounds[axis], 5)); hi = min(end, round(bounds[axis + 3], 5))
        if hi <= lo: return None
        result.append(slice(indexes[axis][lo], indexes[axis][hi]))
    return tuple(result)

exact_kinds = {'authored_original_box', 'authored_union_component',
               'actual_axis_aligned_box', 'retained_continuous_paving_substrate'}
for row in masks:
    selection = slices(row['bounds'])
    if selection is None: continue
    solid[selection] = False
    if row.get('kind') in exact_kinds: retained[selection] = True
asphalt = np.zeros(size, dtype=bool)
asphalt[:, indexes[1][asphalt_low]:, :] = True
for row in plan['surface_exclusions']:
    bounds = row['bounds']
    lo_x = max(a, round(bounds[0], 5)); hi_x = min(c, round(bounds[3], 5))
    lo_z = max(b, round(bounds[2], 5)); hi_z = min(d, round(bounds[5], 5))
    if hi_x <= lo_x or hi_z <= lo_z: continue
    asphalt[indexes[0][lo_x]:indexes[0][hi_x], :, indexes[2][lo_z]:indexes[2][hi_z]] = False
asphalt &= solid
np.savez_compressed(work / 'orison-ground-cells.npz', solid=solid,
                    asphalt=asphalt, xs=xs, ys=ys, zs=zs)
print('COURTYARD TRIAL GRID:', size, 'solid cells', int(solid.sum()), 'asphalt cells', int(asphalt.sum()), flush=True)

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
source_collection = bpy.data.collections.new('OrisonGroundConstruction')
bpy.context.scene.collection.children.link(source_collection)
source_collection.hide_render = True; source_collection.hide_viewport = True
materials = {}
for name, color in [('soil', (.16, .12, .08, 1)), ('asphalt', (.18, .18, .17, 1))]:
    material = bpy.data.materials.new(name); material.diffuse_color = color
    materials[name] = material
groups = collections.defaultdict(list)
complete_faces = []
face_owners = []
buried = 0
site_base_omitted = 0
for axis in range(3):
    for direction in [-1, 1]:
        neighbor = np.zeros(size, dtype=bool)
        native_neighbor = np.zeros(size, dtype=bool)
        target = [slice(None)] * 3; source = [slice(None)] * 3
        target[axis] = slice(1, None) if direction == -1 else slice(None, -1)
        source[axis] = slice(None, -1) if direction == -1 else slice(1, None)
        neighbor[tuple(target)] = solid[tuple(source)]
        native_neighbor[tuple(target)] = retained[tuple(source)]
        cells = np.argwhere(solid & ~neighbor)
        for ix, iy, iz in cells:
            x0, x1 = xs[ix:ix + 2]; y0, y1 = ys[iy:iy + 2]; z0, z1 = zs[iz:iz + 2]
            if axis == 0 and direction == -1: points = [(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)]
            elif axis == 0: points = [(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]
            elif axis == 1 and direction == -1: points = [(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]
            elif axis == 1: points = [(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)]
            elif direction == -1: points = [(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)]
            else: points = [(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
            complete_faces.append(points)
            face_owners.append((int(ix), int(iy), int(iz)))
            if native_neighbor[ix, iy, iz]: buried += 1; continue
            # Preserve the closed editable source bottom. Runtime omits only
            # the buried underside below every occupied Orison space.
            # The finite site boundary remains an explicit open city task.
            if axis == 1 and direction == -1 and abs(y0-low)<1e-8:
                site_base_omitted += 1; continue
            key = (math.floor((x0 + x1) / 8), math.floor((z0 + z1) / 8))
            family = 'asphalt' if asphalt[ix, iy, iz] else 'soil'
            groups[(key, family)].append(points)

vertices = [(p[0], -p[2], p[1]) for face in complete_faces for p in face]
mesh = bpy.data.meshes.new('OrisonGroundClosedUnion')
mesh.from_pydata(vertices, [], [tuple(range(index, index + 4)) for index in range(0, len(vertices), 4)])
bm = bmesh.new(); bm.from_mesh(mesh)
source_face = bm.faces.layers.int.new('SourceFace')
for index, face in enumerate(bm.faces): face[source_face] = index
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
non_manifold = sum(not edge.is_manifold for edge in bm.edges)
print('COURTYARD CLOSED UNION:', len(complete_faces), 'quads;', non_manifold, 'non-manifold edges', flush=True)
for edge in [edge for edge in bm.edges if not edge.is_manifold][:40]:
    print('UNION EDGE DIAGNOSTIC:', [[float(value) for value in vertex.co] for vertex in edge.verts],
          'incident faces', len(edge.link_faces), flush=True)
# Source differences can meet only on an edge. Keep every coordinate and face,
# but split the coincident surface fans instead of welding four faces onto one
# topological edge. No source volume, clearance or contact plane is altered.
bad_edges = [edge for edge in bm.edges if not edge.is_manifold]
assert all(len(edge.link_faces) == 4 for edge in bad_edges)
affected_vertices = set(vertex for edge in bad_edges for vertex in edge.verts)
replacements = {}; affected_faces = set()
split_fans = 0
for vertex in affected_vertices:
    faces = list(vertex.link_faces)
    parent = {face[source_face]: face[source_face] for face in faces}
    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]; index = parent[index]
        return index
    def join(first, second):
        parent[find(first)] = find(second)
    for edge in vertex.link_edges:
        linked = list(edge.link_faces)
        if len(linked) == 2:
            join(linked[0][source_face], linked[1][source_face])
        else:
            assert len(linked) == 4
            owners = collections.defaultdict(list)
            for face in linked: owners[face_owners[face[source_face]]].append(face)
            assert len(owners) == 2 and all(len(pair) == 2 for pair in owners.values())
            for pair in owners.values(): join(pair[0][source_face], pair[1][source_face])
    fans = collections.defaultdict(list)
    for face in faces: fans[find(face[source_face])].append(face)
    for index, fan in enumerate(fans.values()):
        target = vertex if index == 0 else bm.verts.new(vertex.co.copy())
        if index: split_fans += 1
        for face in fan:
            replacements[(vertex, face[source_face])] = target
            affected_faces.add(face)
templates = [(face[source_face], [replacements.get((vertex, face[source_face]), vertex)
              for vertex in face.verts]) for face in affected_faces]
for face in affected_faces: bm.faces.remove(face)
for index, vertices in templates: bm.faces.new(vertices)[source_face] = index
unused_edges = [edge for edge in bm.edges if not edge.link_faces]
if unused_edges: bmesh.ops.delete(bm, geom=unused_edges, context='EDGES')
unused_vertices = [vertex for vertex in bm.verts if not vertex.link_faces]
if unused_vertices: bmesh.ops.delete(bm, geom=unused_vertices, context='VERTS')
non_manifold = sum(not edge.is_manifold for edge in bm.edges)
print('COURTYARD SOURCE FANS:', len(bad_edges), 'zero-area shared edges;', split_fans,
      'separated vertex fans;', non_manifold, 'non-manifold edges after repair', flush=True)
assert non_manifold == 0
assert len(bm.faces) == len(complete_faces)
bm.normal_update()
native_area = sum(face.calc_area() for face in bm.faces)
print('COURTYARD EDITABLE CLOSED UNION:', len(bm.faces), 'source faces; coordinate-preserving manifold proof', flush=True)
bm.to_mesh(mesh); bm.free()
obj = bpy.data.objects.new('OrisonGroundClosedUnion', mesh); source_collection.objects.link(obj)

def merge_planar_rectangles(faces):
    planes = collections.defaultdict(list)
    for points in faces:
        normal = (Vector(points[1]) - Vector(points[0])).cross(Vector(points[2]) - Vector(points[0]))
        axis = max(range(3), key=lambda index: abs(normal[index]))
        direction = 1 if normal[axis] > 0 else -1
        axes = [index for index in range(3) if index != axis]
        u, v = axes
        ui = indexes[u][min(point[u] for point in points)]
        vi = indexes[v][min(point[v] for point in points)]
        planes[(axis, direction, points[0][axis])].append((ui, vi))
    result = []
    for (axis, direction, plane), cells in planes.items():
        u, v = [index for index in range(3) if index != axis]
        rows = collections.defaultdict(set)
        for ui, vi in cells: rows[vi].add(ui)
        active = {}; rectangles = []
        for vi, occupied in sorted(rows.items()):
            runs = []; start = end = None
            for ui in sorted(occupied):
                if start is None: start = end = ui
                elif ui == end + 1: end = ui
                else: runs.append((start, end + 1)); start = end = ui
            if start is not None: runs.append((start, end + 1))
            current = {}
            for left, right in runs:
                previous = active.get((left, right))
                if previous is not None and previous[3] == vi:
                    previous[3] = vi + 1; current[(left, right)] = previous
                else:
                    rectangle = [left, vi, right, vi + 1]
                    rectangles.append(rectangle); current[(left, right)] = rectangle
            active = current
        for left, bottom_index, right, top_index in rectangles:
            bound_low = [plane] * 3; bound_high = [plane] * 3
            bound_low[u], bound_high[u] = coordinates[u][left], coordinates[u][right]
            bound_low[v], bound_high[v] = coordinates[v][bottom_index], coordinates[v][top_index]
            x0,y0,z0 = bound_low; x1,y1,z1 = bound_high
            if axis == 0 and direction == -1: points = [(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)]
            elif axis == 0: points = [(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]
            elif axis == 1 and direction == -1: points = [(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]
            elif axis == 1: points = [(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)]
            elif direction == -1: points = [(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)]
            else: points = [(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
            result.append(points)
    def area(points):
        widths = [max(point[axis] for point in points) - min(point[axis] for point in points) for axis in range(3)]
        widths = sorted(widths)
        return widths[1] * widths[2]
    assert abs(sum(area(face) for face in faces) - sum(area(face) for face in result)) < 1e-7
    return result

parts = []; reports = []
for ((ix, iz), family), faces in sorted(groups.items()):
    source_face_count = len(faces)
    faces = merge_planar_rectangles(faces)
    name = 'Court_%s_%s_%s' % (family, 'P%d' % ix if ix >= 0 else 'N%d' % -ix,
                              'P%d' % iz if iz >= 0 else 'N%d' % -iz)
    lo = [min(point[axis] for face in faces for point in face) for axis in range(3)]
    hi = [max(point[axis] for face in faces for point in face) for axis in range(3)]
    assert max(hi[axis] - lo[axis] for axis in range(3)) <= 4.000001
    center = [(lo[axis] + hi[axis]) / 2 for axis in range(3)]
    origin = Vector((center[0], -center[2], center[1]))
    vertices = [Vector((point[0], -point[2], point[1])) - origin for face in faces for point in face]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [tuple(range(index, index + 4)) for index in range(0, len(vertices), 4)])
    mesh.update()
    uv = mesh.uv_layers.new(name='Metres'); uv.active_render = True
    for face in mesh.polygons:
        assert face.area > 1e-12
        drop = max(range(3), key=lambda axis: abs(face.normal[axis]))
        u, v = ((1,2),(0,2),(0,1))[drop]
        for loop in face.loop_indices:
            point = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = (point[u], 1 + point[v])
    mesh.materials.append(materials[family])
    obj = bpy.data.objects.new(name, mesh); obj.location = origin
    bpy.context.scene.collection.objects.link(obj); parts.append(obj)
    reports.append({'id': name, 'material': family, 'bounds': lo + hi,
                    'source_quads': source_face_count, 'native_faces': len(mesh.polygons),
                    'internal_caps': False})
out = base / 'orison_ground.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(out), compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
class ExportUVHandedness:
    count = 0
    def gather_attribute_change(self, attribute, data, normalized, export_settings):
        if attribute == 'TANGENT': data['data'][:, 3] *= -1; type(self).count += 1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportUVHandedness
asset = root / 'game/assets/props/orison_ground.glb'
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', export_yup=True,
                          export_tangents=True, use_selection=True)
assert ExportUVHandedness.count == len(parts)
metadata = {'evidence_class': 'INERT', 'source_plan': plan, 'parts': reports,
            'closed_union_non_manifold_edges': non_manifold, 'buried_quads_omitted': buried, 'site_base_quads_omitted': site_base_omitted,
            'source_edge_contacts_split': len(bad_edges), 'source_vertex_fans_split': split_fans,
            'native_faces': sum(row['native_faces'] for row in reports),
            'source_native_sha256': hashlib.sha256(asset.read_bytes()).hexdigest(),
            'note': 'Installed bounded subgrade and original-datum courtyard surface. Drainage, operating glazing, broader city closure and weather findings remain open; no whole-shell acceptance.'}
(base / 'orison_ground_construction.json').write_text(json.dumps(metadata, indent=2) + '\n',encoding='utf-8',newline='\n')
print('COURTYARD GRADE TRIAL:', len(parts), 'bounded material parts;', metadata['native_faces'],
      'coalesced native faces;', buried, 'buried interface quads omitted; production ground construction.', flush=True)

(root/'game/tests/fixtures/orison_ground_construction.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
