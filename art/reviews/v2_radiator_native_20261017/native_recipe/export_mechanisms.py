"""Scratch native export; final buffer validator must pass before installation."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import sys, json, hashlib, copy
import bpy, bmesh, numpy as np
ROOT = repository_root()
P = output_directory()
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from check_exported_tangents import validate
from fabrication_normals import stock_corner_normals
export_errors = []

class ExactCornerTangents:
    """Use final exported normals and native UV derivatives at split corners.

    Custom attributes force the exporter to preserve a corner where adjacent
    chart derivatives differ. Compute handedness after glTF's V flip.
    """

    def gather_mesh_hook(self, mesh, blender_data, blender_object, vertex_groups, modifiers, materials, export_settings):
        try:
            self.write_tangents(mesh, blender_object)
        except Exception as exc:
            export_errors.append(dict(object=blender_object.name, error=repr(exc)))
            raise

    def write_tangents(self, mesh, blender_object):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:

            def values(key):
                return np.frombuffer(primitive.attributes[key].buffer_view.data, dtype='<f4').reshape((-1, 3)).astype(float)
            n = values('NORMAL')
            n /= np.linalg.norm(n, axis=1)[:, None]
            p = values('POSITION')
            uv = np.frombuffer(primitive.attributes['TEXCOORD_0'].buffer_view.data, dtype='<f4').reshape((-1, 2)).astype(float)
            index_buffer = primitive.indices
            indices = np.frombuffer(index_buffer.buffer_view.data, dtype={5121: 'u1', 5123: '<u2', 5125: '<u4'}[index_buffer.component_type]).astype(int).reshape((-1, 3))
            assert len(np.unique(indices)) == indices.size
            tex = uv[indices]
            a = tex[:, 1] - tex[:, 0]
            b = tex[:, 2] - tex[:, 0]
            det = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
            assert np.all(abs(det) > 1e-12), (blender_object.name, 'collapsed final chart', float(abs(det).min()))

            def frame(position, normal):
                normal = normal / np.linalg.norm(normal, axis=1)[:, None]
                point = position[indices]
                du = ((point[:, 1] - point[:, 0]) * b[:, 1, None] - (point[:, 2] - point[:, 0]) * a[:, 1, None]) / det[:, None]
                dv = ((point[:, 2] - point[:, 0]) * a[:, 0, None] - (point[:, 1] - point[:, 0]) * b[:, 0, None]) / det[:, None]
                u = np.empty_like(position)
                v = np.empty_like(position)
                u[indices] = du[:, None, :]
                v[indices] = dv[:, None, :]
                tangent = u - normal * np.sum(u * normal, axis=1)[:, None]
                tangent /= np.linalg.norm(tangent, axis=1)[:, None]
                sign = np.sign(np.sum(np.cross(normal, tangent) * v, axis=1))
                assert np.isfinite(tangent).all() and np.all(sign != 0)
                return (tangent, sign)
            tangent, sign = frame(p, n)
            primitive.attributes['TANGENT'].buffer_view = BinaryData(np.column_stack((tangent, sign)).astype('<f4').tobytes(), BufferViewTarget.ARRAY_BUFFER)
            for target in primitive.targets or []:

                def delta(key):
                    return np.frombuffer(target[key].buffer_view.data, dtype='<f4').reshape((-1, 3)).astype(float) if key in target else np.zeros_like(p)
                morphed, handed = frame(p + delta('POSITION'), n + delta('NORMAL'))
                assert np.array_equal(sign, handed), (blender_object.name, 'morph changes UV handedness')
                accessor = copy.copy(primitive.attributes['TANGENT'])
                accessor.type = 'VEC3'
                accessor.min = None
                accessor.max = None
                accessor.buffer_view = BinaryData((morphed - tangent).astype('<f4').tobytes(), BufferViewTarget.ARRAY_BUFFER)
                target['TANGENT'] = accessor
            del primitive.attributes['_TANGENT_GUIDE']
            del primitive.attributes['_BITANGENT_GUIDE']
            del primitive.attributes['_EXPORT_CORNER']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExactCornerTangents
reports = []
for family in ['automatic_vent', 'packed_union', 'sliding_wall_ties', 'pitch_shims']:
    native = P / (family + '_candidate.blend' if family in ['packed_union', 'sliding_wall_ties', 'pitch_shims'] else family + '_finished_candidate.blend')
    bpy.ops.wm.open_mainfile(filepath=str(native))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        if family == 'pitch_shims' and (not obj.name.startswith('Shim_')):
            continue
        if family in ['articulated_union', 'packed_union']:
            keep = {'ArticulatedValveHousing', 'SweptSupplyElbow', 'ThreadedMovingValveCore', 'SixSpokeHandwheel', 'FixedStemPacking', 'CastSectionThreeColumnCandidate', 'CastShoeFoot', 'BlindHeaderPlug', 'VentHeaderReducer', 'HeaderSealWasher', 'FloatingMetalBearingRing', 'ValveSphericalRetainer', 'HeaderSphericalRetainer'}
            keep.update(('SphericalNeck_%d' % count for count in [7, 8, 9, 10]))
            keep.update({'PackedHeaderSocket', 'RemovableFibrousUnionPacking'} if family == 'packed_union' else {'HeaderSphericalSocket'})
            if obj.name not in keep:
                continue
        obj.hide_set(False)
        obj.select_set(True)
        mesh = obj.data
        mesh.name = obj.name
        if obj.name == 'RemovableFibrousUnionPacking':
            keys = mesh.shape_keys.key_blocks
            rest = np.array([v.co[:] for v in keys['Seated'].data])
            end = np.array([v.co[:] for v in keys['SpreadForRemoval'].data])
            obj.shape_key_clear()
            obj.shape_key_add(name='Seated')
            for index in range(1, 21):
                key = obj.shape_key_add(name='Spread_%02d' % index)
                key.data.foreach_set('co', (rest + (end - rest) * index / 20).astype(np.float32).ravel())
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.normals_split_custom_set(stock_corner_normals(mesh))
        uv = mesh.uv_layers.active.data
        tangents = []
        bitangents = []
        for face in mesh.polygons:
            a, b, c = [mesh.vertices[i].co for i in face.vertices]
            ua, ub, uc = [uv[i].uv for i in face.loop_indices]
            du = ub - ua
            dv = uc - ua
            det = du.x * dv.y - du.y * dv.x
            assert abs(det) > 1e-18, (obj.name, face.index, 'collapsed native chart')
            u = ((b - a) * dv.y - (c - a) * du.y) / det
            v = ((c - a) * du.x - (b - a) * dv.x) / det
            u.normalize()
            v.normalize()
            tangents.extend([(u.x, u.z, -u.y)] * 3)
            bitangents.extend([(-v.x, -v.z, v.y)] * 3)
        for name, values in [('_tangent_guide', tangents), ('_bitangent_guide', bitangents)]:
            attr = mesh.attributes.new(name=name, type='FLOAT_VECTOR', domain='CORNER')
            attr.data.foreach_set('vector', np.asarray(values, dtype=np.float32).ravel())
        unique = mesh.attributes.new(name='_export_corner', type='FLOAT', domain='CORNER')
        unique.data.foreach_set('value', np.arange(len(mesh.loops), dtype=np.float32))
    output = P / (family + '_scratch.glb')
    export_errors.clear()
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_yup=True, export_tangents=True, export_attributes=True, export_morph_tangent=True, export_materials='PLACEHOLDER')
    assert not export_errors, export_errors
    try:
        report = validate(output)
    except (AssertionError, KeyError) as exc:
        report = dict(status='FAIL', error=str(exc))
    report.update(native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), asset_sha256=hashlib.sha256(output.read_bytes()).hexdigest(), family=family)
    reports.append(report)
    print('SCRATCH EXPORT', family, report, flush=True)
(P / 'scratch_export_review.json').write_text(json.dumps(dict(evidence_class='INERT', scope='Scratch GLB base-pose final float32 tangent/UV check; excludes retired study stocks. No morph-target tangent qualification, production install or loaded mip chain proof.', reports=reports), indent=2) + '\n')
if any((r['status'] != 'PASS' for r in reports)):
    raise RuntimeError('Scratch export has unresolved buffer defects')
