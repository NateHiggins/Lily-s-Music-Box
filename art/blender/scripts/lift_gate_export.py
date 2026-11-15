"""Exact lift-library exporter inherited from reviewed native delivery28.

Only the corner-tangent class is retained from the original scratch exporter;
no scratch driver, hard-coded checkout, reference image or render is executed.
The saved editable native source owns geometry. This helper exports its16
physical-metre templates and validates actual final buffer tangents.
"""
from pathlib import Path
import copy,sys
import bpy,numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from check_exported_tangents import validate
export_errors=[]
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

def export(path):
    export_errors.clear()
    ns = {'ExactCornerTangents': ExactCornerTangents, 'export_errors': export_errors}

    class Export(ns['ExactCornerTangents']):

        def gather_material_hook(self, material, blender_material, settings):
            material.name = material.name.removeprefix('Export__')

        def gather_mesh_hook(self, mesh, data, obj, *args):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            for p in mesh.primitives:
                n = p.attributes.pop('_AUTHORED_NORMAL')
                p.attributes['NORMAL'].buffer_view = BinaryData(n.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
                q = np.frombuffer(p.attributes.pop('_EXACT_UV').buffer_view.data, dtype='<f4').reshape(-1, 3)
                p.attributes['TEXCOORD_0'].buffer_view = BinaryData(q[:, :2].astype('<f4').tobytes(), BufferViewTarget.ARRAY_BUFFER)
            self.write_tangents(mesh, obj or data)
            for p in mesh.primitives:
                keys = sorted(p.attributes)
                arrays = []
                for key in keys:
                    a = p.attributes[key]
                    assert a.component_type == 5126
                    width = {'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a.type]
                    arrays.append(np.frombuffer(a.buffer_view.data, dtype='<f4').reshape(-1, width))
                values = np.ascontiguousarray(np.concatenate(arrays, axis=1))
                records = values.view(np.dtype((np.void, values.shape[1] * 4))).ravel()
                _, first, inverse = np.unique(records, return_index=True, return_inverse=True)
                for key, v in zip(keys, arrays):
                    p.attributes[key].count = len(first)
                    p.attributes[key].buffer_view = BinaryData(np.ascontiguousarray(v[first]).tobytes(), BufferViewTarget.ARRAY_BUFFER)
                ind = p.indices
                dtype = {5121: 'u1', 5123: '<u2', 5125: '<u4'}[ind.component_type]
                old = np.frombuffer(ind.buffer_view.data, dtype=dtype)
                mapped = inverse[old]
                ind.buffer_view = BinaryData(mapped.astype(dtype).tobytes(), BufferViewTarget.ELEMENT_ARRAY_BUFFER)
                ind.min = [int(mapped.min())]
                ind.max = [int(mapped.max())]
    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension = Export
    bpy.ops.object.select_all(action='DESELECT')
    col = bpy.data.collections['20_EXPORT_LIBRARY']
    saved = []
    for ob in col.objects:
        ob.hide_set(False)
        ob.select_set(True)
        if ob.type == 'MESH':
            saved.append((ob, list(ob.data.materials)))
            key = ob['catalog_key']
            ob.data.materials.clear()
            ob.data.materials.append(bpy.data.materials['Export__' + key])
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True, export_tangents=True, export_attributes=True, export_extras=True, export_materials='EXPORT', export_animations=False)
    for ob, mats in saved:
        ob.data.materials.clear()
        for mat in mats:
            ob.data.materials.append(mat)
    assert not ns['export_errors']
    return validate(path)
