"""Blender glTF export hook: repair UV tangents without changing skin/morph data.

Install CastDerivativeExportExtension as io_scene_gltf2.glTF2ExportUserExtension
before export. Runs before GLB serialization; never edits an emitted asset.
All vertex attributes and morph deltas follow the same original-index remap.
Sparse morph storage remains sparse, including all-zero targets. Does not
alter native meshes, materials, node transforms, joint order, or morph names.
"""
import copy
import numpy as np

DTYPES = {5120: 'i1', 5121: 'u1', 5122: '<i2', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def _read(accessor):
    """Read pre-writer BinaryData accessors, including sparse replacements."""
    dtype = np.dtype(DTYPES[accessor.component_type])
    width = WIDTHS[accessor.type]

    def block(view, offset, count, dt, columns):
        if not hasattr(view, 'data'):
            raise ValueError('Cast derivative hook requires pre-writer BinaryData accessors')
        return np.frombuffer(view.data, dtype=dt, count=count * columns,
                             offset=offset or 0).reshape(count, columns).copy()

    values = (np.zeros((accessor.count, width), dtype=dtype) if accessor.buffer_view is None
              else block(accessor.buffer_view, accessor.byte_offset, accessor.count, dtype, width))
    if accessor.sparse is not None:
        sparse = accessor.sparse
        index = block(sparse.indices.buffer_view, sparse.indices.byte_offset,
                      sparse.count, np.dtype(DTYPES[sparse.indices.component_type]), 1).ravel()
        if np.any(index >= accessor.count) or np.any(np.diff(index.astype(np.int64)) <= 0):
            raise ValueError('Invalid sparse accessor indices')
        values[index] = block(sparse.values.buffer_view, sparse.values.byte_offset, sparse.count, dtype, width)
    return values


def _remap(accessor, values, sparse=False, element=False):
    from io_scene_gltf2.io.exp.binary_data import BinaryData
    from io_scene_gltf2.io.com import gltf2_io
    from io_scene_gltf2.io.com.constants import BufferViewTarget
    result = copy.copy(accessor)
    result.count = len(values); result.byte_offset = None; result.sparse = None
    if accessor.min is not None:
        result.min = values.min(axis=0).tolist()
    if accessor.max is not None:
        result.max = values.max(axis=0).tolist()
    if sparse:
        index = np.flatnonzero(np.any(values != 0, axis=1)).astype('<u4')
        # glTF sparse.count is >=1: one zero replacement encodes an all-zero target.
        if len(index) == 0:
            index = np.array([0], dtype='<u4')
        result.buffer_view = None
        result.sparse = gltf2_io.AccessorSparse(
            count=len(index), extensions=None, extras=None,
            indices=gltf2_io.AccessorSparseIndices(
                buffer_view=BinaryData(index.tobytes()), byte_offset=None,
                component_type=5125, extensions=None, extras=None),
            values=gltf2_io.AccessorSparseValues(
                buffer_view=BinaryData(values[index].tobytes()), byte_offset=None,
                extensions=None, extras=None))
    else:
        target = BufferViewTarget.ELEMENT_ARRAY_BUFFER if element else BufferViewTarget.ARRAY_BUFFER
        result.buffer_view = BinaryData(values.tobytes(), target)
    return result


class CastDerivativeExportExtension:
    """Reindex only incompatible frames; retain raw non-tangent attribute bytes."""
    reports = []

    def gather_mesh_hook(self, mesh, *unused):
        for primitive in mesh.primitives:
            attributes = primitive.attributes
            if '_NORMAL_GUIDE' in attributes or '_CORNER_GUARD' in attributes:
                raise ValueError('Run the native hair guide hook before the cast derivative hook')
            if primitive.mode not in (None, 4):
                raise ValueError('Cast derivative hook supports triangle primitives only')
            if primitive.indices is None:
                raise ValueError('Cast derivative hook requires indexed triangles')
            if any(k not in attributes for k in ('POSITION', 'NORMAL', 'TEXCOORD_0', 'TANGENT')):
                raise ValueError('Cast triangle missing POSITION/NORMAL/UV0/TANGENT')
            arrays = {k: _read(a) for k, a in attributes.items()}
            if any(attributes[k].component_type != 5126 or attributes[k].normalized
                   for k in ('POSITION', 'NORMAL', 'TEXCOORD_0', 'TANGENT')):
                raise ValueError('Float32 nonnormalized position/normal/UV/tangent accessors required')
            old_count = len(arrays['POSITION'])
            if any(len(a) != old_count for a in arrays.values()):
                raise ValueError('Vertex attribute counts disagree')
            indices = _read(primitive.indices).astype(np.int64).reshape(-1, 3)
            p = arrays['POSITION'][indices].astype(float)
            n = arrays['NORMAL'][indices].astype(float)
            uv = arrays['TEXCOORD_0'][indices].astype(float)
            a, b = uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]
            det = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
            if not np.isfinite(det).all() or np.any(abs(det) <= 1e-12):
                raise ValueError('Collapsed/nonfinite exported UV triangle; native repair required')
            du = ((p[:, 1] - p[:, 0]) * b[:, 1, None] - (p[:, 2] - p[:, 0]) * a[:, 1, None]) / det[:, None]
            dv = ((p[:, 2] - p[:, 0]) * a[:, 0, None] - (p[:, 1] - p[:, 0]) * b[:, 0, None]) / det[:, None]
            expected = du[:, None, :] - n * np.sum(du[:, None, :] * n, axis=2)[:, :, None]
            expected /= np.linalg.norm(expected, axis=2)[:, :, None]
            tangent = arrays['TANGENT'][indices].copy()
            agreement = np.sum(expected * tangent[:, :, :3], axis=2)
            handed = np.sum(np.cross(n, tangent[:, :, :3]) * dv[:, None, :], axis=2) * tangent[:, :, 3]
            bad = np.any((agreement <= .9995) | (handed <= 0) | ~np.isfinite(agreement), axis=1)
            if not np.any(bad):
                continue
            tangent[bad, :, :3] = expected[bad].astype('<f4')
            tangent[bad, :, 3] = np.where(np.sum(np.cross(n[bad], tangent[bad, :, :3].astype(float)) * dv[bad, None, :], axis=2) < 0, -1, 1)
            if not np.isfinite(tangent).all():
                raise ValueError('Nonfinite corrected tangent; native repair required')
            # Equal original indices have identical skin/morph/every other attribute.
            # Dedupe only their bit-identical corrected frames, preserving seams.
            keys = np.empty(indices.size, dtype=[('vertex', '<u4'), ('frame', '<u4', (4,))])
            keys['vertex'] = indices.ravel()
            keys['frame'] = tangent.reshape(-1, 4).view('<u4')
            _, first, inverse = np.unique(keys, return_index=True, return_inverse=True)
            origin = indices.ravel()[first]
            for key, accessor in list(attributes.items()):
                values = tangent.reshape(-1, 4)[first] if key == 'TANGENT' else arrays[key][origin]
                attributes[key] = _remap(accessor, values, sparse=accessor.sparse is not None)
            for target in primitive.targets or []:
                for key, accessor in list(target.items()):
                    values = _read(accessor)
                    if len(values) != old_count:
                        raise ValueError('Morph target count disagrees with base vertices')
                    values = values[origin]
                    target[key] = _remap(accessor, values, sparse=accessor.sparse is not None or not np.any(values))
            final = inverse.reshape(-1, 1).astype('<u4')
            primitive.indices = _remap(primitive.indices, final, element=True)
            primitive.indices.component_type = 5125
            type(self).reports.append({'mesh': mesh.name, 'triangles': len(indices), 'repaired_faces': int(bad.sum()),
                                       'vertices_before': old_count, 'vertices_after': len(origin),
                                       'morph_targets': len(primitive.targets or []), 'attributes': sorted(arrays)})
