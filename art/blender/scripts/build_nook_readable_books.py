"""Manufacture the 60 retained nook volumes and its face-down reader.

Reuse only pure native manufacturing functions, never the library builder's
scene/export side effects. The original nook report supplies physical lineage;
the title catalogue supplies content, not object identity or world placement.
"""
from pathlib import Path
import ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export
from fabrication_chart_batch import triangle_charts

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
source = bpy.data.collections.new('ClosedSourceStock')
bpy.context.scene.collection.children.link(source)
draws = bpy.data.collections.new('AuthoredMetrePartitions')
bpy.context.scene.collection.children.link(draws)
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
base = json.loads((ROOT/'game/data/orison_v2/readable_library.json').read_text())
library = json.loads((ROOT/'game/data/library.json').read_text())['books']
# Rare personal pamphlets and the singular minutes ledger stay with their owners.
public_titles = [entry for entry in library if entry['id'] not in ['prospectus','hymns','onefinger','minutes']]
programme_path = ROOT/'art/data/reading_nook/book_programme.json'
programme = json.loads(programme_path.read_text())['copies']
nook = json.loads((ROOT/'art/blender/reading_nook_construction.json').read_text())
runtime = nook['runtime']
frames = {row['id']: row for row in runtime['assemblies']}
rows = {row['id']: row for row in nook['original_records']}
finishes = base['finishes']
materials = {key: material(ROOT, key, spec, catalog) for key, spec in finishes.items()}
parts, stocks, exports = {}, [], []
factory = ROOT/'art/blender/scripts/build_readable_library.py'
tree = ast.parse(factory.read_text(encoding='utf8'))
functions = {'b', 'cube', 'finish', 'box', 'wire'}
exec(compile(ast.Module(body=[node for node in tree.body if isinstance(node, ast.FunctionDef)
                             and node.name in functions], type_ignores=[]), str(factory), 'exec'))

books, copies, lineage = {}, [], []
flat_bearings = []

def binding(identity, width, height, thickness, key):
    assert min(width, height) > .12 and thickness > .004, (identity, width, height, thickness)
    cover = .0014
    record = dict(width=width, height=height, thickness=thickness, material=key,
                  parts=[], binding='case binding', right_page_z=-.00016, left_page_z=.00016)
    for side, low, high in [('right', -thickness/2, -.0002), ('left', .0002, thickness/2)]:
        board_z = low+cover/2 if side == 'right' else high-cover/2
        record['parts'].append(box(identity+'__'+side+'_board', (width, height, cover),
                                   (width/2, height/2, board_z), key, side, .00028))
        page_low, page_high = (low+cover, high) if side == 'right' else (low, high-cover)
        record['parts'].append(box(identity+'__'+side+'_leaves',
                                   (width-.007, height-.007, page_high-page_low),
                                   ((width+.001)/2, height/2, (page_high+page_low)/2),
                                   'paper', side, .00012))
        if key in ['book_brown', 'book_burgundy']:
            z = board_z+(-1 if side == 'right' else 1)*(cover/2+.00006)
            tooling = [cube((.00045, height-.020, .00012), (x, height/2, z)) for x in [.010, width-.010]]
            tooling += [cube((width-.020, .00045, .00012), (width/2, y, z)) for y in [.010, height-.010]]
            record['parts'].append(finish(identity+'__'+side+'_tooling', tooling, key, side, .00002, False))
    record['parts'].append(box(identity+'__spine', (.002, height, thickness),
                               (-.001, height/2, 0), key, 'fixed', .00045))
    books[identity] = record

G = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
relocation = Matrix.Rotation(math.pi, 3, 'Z')

def pose(assembly, row, origin, axes):
    yaw = math.radians(row.get('yaw', 0))
    at = row.get('at', [0, 0])
    turn = Matrix.Rotation(yaw, 3, 'Z')
    source_origin = turn@origin+Vector((at[0], at[1], row.get('z0', 0)))
    target_origin = G@(relocation@source_origin+Vector((-.96, -2.10, 0)))
    target_basis = G@relocation@turn@axes
    frame = frames[assembly]
    inverse = Matrix.Rotation(frame['yaw'], 3, 'Y').inverted()
    local_origin = inverse@(target_origin-Vector(frame['position']))
    local_basis = inverse@target_basis
    assert abs(local_basis.determinant()-1) < 1e-6
    return dict(position=list(local_origin), basis=[list(local_basis.col[i]) for i in range(3)])

for index, original in enumerate(nook['book_stock']):
    assembly = original['assembly']
    identity = assembly+'__'+original['label']
    low, high = map(Vector, original['bounds'])
    size = high-low
    flat = size.z < .08
    width, height, thickness = (size.y-.002, size.x, size.z) if flat else (size.y-.002, size.z, size.x)
    key = original['source']['args'][0]
    binding(identity, width, height, thickness, key)
    row = dict(rows[assembly])
    if assembly == 'nook_pile': row['z0'] = .365
    # Width starts just inside the original spine edge, preserving the full
    # cover+spine reserve. Native stock is never scaled in the runtime.
    origin = Vector((low.x if flat else (low.x+high.x)/2,
                     high.y-.002, (low.z+high.z)/2 if flat else low.z))
    axes = Matrix(((0, 1, 0), (-1, 0, 0), (0, 0, 1))) if flat else Matrix(((0, 0, -1), (-1, 0, 0), (0, 1, 0)))
    lift = .00035
    if flat:
        for previous_assembly, previous_low, previous_high, previous_lift in flat_bearings:
            if previous_assembly == assembly and abs(low.z-previous_high.z) < .002 \
                    and low.x < previous_high.x and high.x > previous_low.x \
                    and low.y < previous_high.y and high.y > previous_low.y:
                lift = max(lift, previous_lift+.00059)
        flat_bearings.append((assembly, low, high, lift))
    origin.z += lift
    placed = pose(assembly, row, origin, axes)
    copies.append(dict(id=identity, title_id=programme[identity],
                       assembly=assembly, opening=0., **placed))
    lineage.append(dict(id=identity, source=original, dimensions=[width, height, thickness]))

# The formerly fused tented reader remains on the same cushion. Its pages face
# down, with both fore-edges seated and the spine lifted; it can be picked up.
identity = 'nook_cush1__Reader'
width, height, thickness = .13, .20, .012
binding(identity, width, height, thickness, 'book_green')
row = rows['nook_cush1']
theta = math.asin(.022/width)
axes = Matrix(((math.cos(theta), 0, -math.sin(theta)),
               (0, -1, 0), (-math.sin(theta), 0, -math.cos(theta))))
origin = Vector((-.84, 1.05, row['z0']+row['h']+.02835))
copies.append(dict(id=identity, title_id=programme[identity], assembly='nook_cush1',
                   opening=math.pi-2*theta,
                   **pose('nook_cush1', {}, origin, axes)))
lineage.append(dict(id=identity, source='nook_cush1 retained face-down reader',
                    dimensions=[width, height, thickness]))
assert len(copies) == 61 and len({copy['id'] for copy in copies}) == 61
assert {copy['id'] for copy in copies} == set(programme)
assert {copy['title_id'] for copy in copies} <= {entry['id'] for entry in public_titles}

# Real bearing stock uses the existing manufactured end, not a new primitive.
# The references stay out of this glTF: runtime uses the shared library cache.
reference = bpy.data.collections.new('ReferenceEndTemplates')
bpy.context.scene.collection.children.link(reference)
end_spec = base['bookends']['pressed']
with bpy.data.libraries.load(str(ROOT/'art/blender/readable_library.blend'), link=False) as (src, dst):
    dst.objects = list(end_spec['parts'])
end_objects = {}
for obj in dst.objects:
    reference.objects.link(obj); obj.hide_render = True; end_objects[obj.name] = obj

def native_points(names, opening=0.):
    result = []
    leaf = Matrix.Rotation(-opening, 3, 'Y')
    for name in names:
        obj = draws.objects.get(name) or end_objects[name]
        role = parts.get(name, {}).get('role', '')
        for vertex in obj.data.vertices:
            point = G@(obj.matrix_world@vertex.co)
            result.append(leaf@point if role == 'left' else point)
    return result

point_cache = {}
def bounds(copy):
    identity = copy['id']
    if identity not in point_cache:
        point_cache[identity] = np.array([tuple(p) for p in native_points(books[identity]['parts'], copy['opening'])])
    points = point_cache[identity]@np.array(copy['basis'])+np.array(copy['position'])
    return Vector(points.min(0)), Vector(points.max(0))

bpy.context.view_layer.update()
ends = []
for level, top in enumerate([.582, 1.002, 1.422]):
    residents = [copy for copy in copies if copy['assembly'] == 'nook_books'
                 and min(range(3), key=lambda i: abs(bounds(copy)[0].y-[.582, 1.002, 1.422][i])) == level]
    if not residents: continue
    spans = [bounds(copy) for copy in residents]
    left, right = min(lo.x for lo, hi in spans), max(hi.x for lo, hi in spans)
    center_z = (min(lo.z for lo, hi in spans)+max(hi.z for lo, hi in spans))/2
    for side, x, angle in [('left', left-.012, 0.), ('right', right+.012, math.pi)]:
        basis = Matrix.Rotation(angle, 3, 'Y')
        heel = [basis@p for p in native_points(['bookend_pressed__FloorReturn'])]
        # Keep the upturned foot edge outside the book's depth reserve. Only
        # the thin horizontal sole bears under pages, as on a real bookend.
        if side == 'left':
            center_z = max(hi.z for lo, hi in spans)+.00035-min(p.z for p in heel)
        else:
            center_z = min(lo.z for lo, hi in spans)-.00035-max(p.z for p in heel)
        origin = Vector((x, top-end_spec['support_y']+.00035, center_z))
        ends.append(dict(id=f'nook_books__End{level}_{side}', assembly='nook_books', style='pressed',
                         position=list(origin), basis=[list(basis.col[i]) for i in range(3)]))
        foot = [origin+basis@p for p in native_points(['bookend_pressed__Foot'])]
        lo = Vector([min(p[i] for p in foot) for i in range(3)])
        hi = Vector([max(p[i] for p in foot) for i in range(3)])
        for copy in residents:
            book_low, book_high = bounds(copy)
            if book_low.x < hi.x and book_high.x > lo.x and book_low.z < hi.z and book_high.z > lo.z:
                copy['position'][1] += max(0., hi.y+.00035-book_low.y)
    # Propagate a raised bearing through a flat stack, rather than overlapping
    # the next book or freezing an intersecting construction pose.
    for _ in range(len(residents)):
        changed = False
        for upper in residents:
            up_lo, up_hi = bounds(upper)
            if abs(Matrix(upper['basis']).transposed().col[1].y) > .3: continue
            for lower in residents:
                if upper is lower: continue
                low_lo, low_hi = bounds(lower)
                if low_lo.y >= up_lo.y or low_hi.y < up_lo.y-.005: continue
                if up_lo.x < low_hi.x and up_hi.x > low_lo.x and up_lo.z < low_hi.z and up_hi.z > low_lo.z:
                    lift = low_hi.y+.00035-up_lo.y
                    if lift > .000001:
                        upper['position'][1] += lift; changed = True; up_lo.y += lift; up_hi.y += lift
        if not changed: break
assert ends and len(ends) % 2 == 0
source.hide_render = True
proof = export(ROOT, 'nook_readable_books', draws)
data = dict(schema_version=1, asset='res://assets/props/nook_readable_books.glb',
            books=books, parts=parts, copies=copies, ends=ends)
data_path = ROOT/'game/data/orison_v2/nook_readable_books.json'
data_path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf8', newline='\n')
bindings = [Path(__file__), factory, programme_path, ROOT/'art/blender/reading_nook_construction.json',
            ROOT/'game/data/orison_v2/readable_library.json', ROOT/'game/data/library.json',
            ROOT/'game/data/runtime_material_sets.json']
bindings += [ROOT/'art/blender/readable_library.blend',ROOT/'art/blender/scripts/review_nook_readable_books.py']
bindings += [ROOT/'game/assets/building/textures'/name for key in finishes for name in catalog[key]['files']]
bindings += [ROOT/'art/blender/scripts'/name for name in ['fabrication_native_batch.py',
             'fabrication_chart_batch.py', 'fabrication_grain.py', 'fabrication_normals.py', 'check_exported_tangents.py']]
def digest(path):
    data = path.read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if path.suffix in ['.py', '.json'] else data).hexdigest()
report = dict(evidence_class='INERT', lineage=lineage, parts=parts, closed_stocks=stocks,
              export=proof, source_bindings={p.relative_to(ROOT).as_posix(): digest(p) for p in bindings},
              outputs={p.relative_to(ROOT).as_posix(): digest(p) for p in [data_path,
                       ROOT/'game/assets/props/nook_readable_books.glb', ROOT/'art/blender/nook_readable_books.blend']})
(ROOT/'art/blender/nook_readable_books_construction.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf8', newline='\n')
print('NOOK READABLE BOOKS:', len(copies), 'physical copies;', len(parts), 'native parts')
