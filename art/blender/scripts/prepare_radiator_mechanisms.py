"""Prepare catalogue-bound radiator assets from the reviewed native kit.

Blender: --python-exit-code 1 --python this_file -- --source-dir DIR --out DIR
The input directory must contain the intact reviewed build manifest and outputs.
This does not install assets. Castings receive finer contours and five worked
fittings receive edge breaks; other stocks, frames and shape keys are preserved. Packed
image paths and catalogue bindings become production-ready.
"""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
RECIPE = ROOT / 'art/reviews/v2_radiator_native_20261017/native_recipe'
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material
from check_exported_tangents import validate


def digest_geometry(exclude=()):
    h = hashlib.sha256()
    for obj in sorted(bpy.context.scene.objects, key=lambda x: x.name):
        if obj.type != 'MESH' or obj.name in exclude:
            continue
        h.update(obj.name.encode())
        for row in obj.matrix_world:
            h.update(struct.pack('<4d', *row))
        mesh = obj.data
        for vertex in mesh.vertices:
            h.update(struct.pack('<3d', *vertex.co))
        for polygon in mesh.polygons:
            h.update(struct.pack('<I', len(polygon.vertices)))
            h.update(struct.pack('<' + 'I' * len(polygon.vertices), *polygon.vertices))
        for layer in mesh.uv_layers:
            for loop in layer.data:
                h.update(struct.pack('<2d', *loop.uv))
        if mesh.shape_keys:
            for key in mesh.shape_keys.key_blocks:
                h.update(key.name.encode())
                for vertex in key.data:
                    h.update(struct.pack('<3d', *vertex.co))
    return h.hexdigest()


def glb_json(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20 + length])


def prepare():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--retained-cast-native',type=Path,
                        help='Reuse reviewed casting/shoe stocks while refining fittings')
    parser.add_argument('--family', choices=['radiator_mechanisms', 'radiator_air_vent',
                        'radiator_wall_support', 'radiator_pitch_shims'])
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    source, out = args.source_dir.resolve(), args.out.resolve()
    assert out != source and not out.is_relative_to(ROOT / 'game')
    out.mkdir(parents=True, exist_ok=True)
    build = json.loads((source / 'build_manifest.json').read_text())
    assert build['status'] == 'PASS'
    for name, expected in build['outputs_sha256'].items():
        raw = (source / name).read_bytes()
        if Path(name).suffix in {'.py', '.gd', '.json'}:
            raw = raw.replace(b'\r\n', b'\n')
        assert hashlib.sha256(raw).hexdigest() == expected, name
    catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
    # Reuse the reviewed final-float32 exporter hook without executing its
    # standalone scratch driver or editing any generated glTF.
    tree = ast.parse((RECIPE / 'export_mechanisms.py').read_text(encoding='utf-8'))
    extension = next(n for n in tree.body if isinstance(n, ast.ClassDef)
                     and n.name == 'ExactCornerTangents')
    namespace = dict(np=np, copy=copy, export_errors=[])
    exec(compile(ast.Module(body=[extension], type_ignores=[]),
                 str(RECIPE / 'export_mechanisms.py'), 'exec'), namespace)
    import io_scene_gltf2
    class ProductionTangents(namespace['ExactCornerTangents']):
        def gather_mesh_hook(self, mesh, blender_data, blender_object, vertex_groups,
                             modifiers, materials, export_settings):
            # Blender may deduplicate a mesh without supplying an object.
            # Preserve the original tangent algorithm and record its actual
            # failure rather than masking it with an object-name exception.
            owner=blender_object or blender_data
            try:
                self.write_tangents(mesh,owner)
            except Exception as exc:
                namespace['export_errors'].append(dict(object=getattr(owner,'name','mesh'),error=repr(exc)))
                raise
    io_scene_gltf2.glTF2ExportUserExtension = ProductionTangents
    families = {
        'radiator_mechanisms': ('packed_union', 'packed_union_candidate.blend'),
        'radiator_air_vent': ('automatic_vent', 'automatic_vent_finished_candidate.blend'),
        'radiator_wall_support': ('sliding_wall_ties', 'sliding_wall_ties_candidate.blend'),
        'radiator_pitch_shims': ('pitch_shims', 'pitch_shims_candidate.blend'),
    }
    report = dict(evidence_class='INERT', scope='Production preparation, not installation or runtime proof.',
                  source_manifest_sha256=hashlib.sha256((source / 'build_manifest.json').read_bytes()).hexdigest(),
                  recipe_lf_sha256={path.name:hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
                                    for path in [Path(__file__),Path(__file__).with_name('radiator_cast_detail.py'),
                                                 Path(__file__).with_name('radiator_fitting_detail.py'),
                                                 Path(__file__).with_name('radiator_vent_detail.py'),
                                                 Path(__file__).with_name('radiator_cap_thread.py'),
                                                 ROOT/'art/data/orison_v2/radiator_vent_thread_source.json',
                                                 ROOT/'tools/build_v2_radiator_vent_thread.py']},
                  families={})
    if args.retained_cast_native:
        report['retained_cast_native_sha256']=hashlib.sha256(args.retained_cast_native.read_bytes()).hexdigest()
    for target, (family, native_name) in families.items():
        if args.family and target != args.family:
            continue
        bpy.ops.wm.open_mainfile(filepath=str(source / native_name))
        bpy.context.preferences.filepaths.save_version = 0
        original = digest_geometry()
        refinement = {}
        if family == 'packed_union':
            from radiator_cast_detail import refine_castings
            from radiator_fitting_detail import refine_fittings, STOCKS
            changed = ('CastSectionThreeColumnCandidate','CastShoeFoot')+STOCKS
            unchanged = digest_geometry(changed)
            if args.retained_cast_native:
                names=['CastSectionThreeColumnCandidate','CastShoeFoot']
                with bpy.data.libraries.load(str(args.retained_cast_native.resolve()),link=False) as (_,loaded):
                    loaded.objects=list(names)
                for name,reused in zip(names,loaded.objects):
                    owner=bpy.data.objects[name]
                    previous=owner.data
                    owner.data=reused.data
                    bpy.data.objects.remove(reused,do_unlink=True)
                    if previous.users==0: bpy.data.meshes.remove(previous)
                    refinement[name]={'retained_reviewed_native':True}
            else:
                refinement = refine_castings()
            refinement.update(refine_fittings())
            assert digest_geometry(changed) == unchanged, 'Detail altered another stock or mechanism'
        if family == 'automatic_vent':
            from radiator_vent_detail import refine_vent
            untouched = digest_geometry(('VentBody','VentCap','FloatAndNeedle'))
            refinement.update(refine_vent())
            assert digest_geometry(('VentBody','VentCap','FloatAndNeedle')) == untouched
        before = digest_geometry()
        keep = {m['name'] for m in glb_json(source / (family + '_scratch.glb'))['meshes']}
        keys = {}
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH':
                continue
            for slot in obj.material_slots:
                key = slot.material.name.split('.')[0]
                if key == 'UNREGISTERED_graphited_cloth':
                    key = 'graphited_packing'
                if key == 'PitchShimTimber':
                    key = 'timber'
                if key == 'door_brass' and family in {'packed_union','automatic_vent'}:
                    key = 'radiator_service_brass'
                if family == 'packed_union' and key == 'iron_neutral' and obj.name in {
                        'CastSectionThreeColumnCandidate', 'CastShoeFoot'}:
                    key = 'radiator_cast_iron'
                assert key in catalog, (obj.name, key)
                if key not in keys:
                    tint = [.62, .52, .4] if family == 'pitch_shims' else [1, 1, 1]
                    strength = 1.0 if key in {'radiator_cast_iron','graphited_packing','radiator_service_brass'} else .35
                    keys[key] = material(ROOT, key, dict(catalog_key=key, normal=strength,
                        roughness=catalog[key]['roughness_multiplier'], tint=tint, pigment=1), catalog)
                    keys[key]['catalog_key'] = key
                    keys[key]['catalog_tint'] = tint
                slot.material = keys[key]
            if 'finish_pending' in obj:
                del obj['finish_pending']
        assert digest_geometry() == before, 'Material binding altered native geometry'
        for image in list(bpy.data.images):
            if image.users and image.source == 'FILE':
                image.pack()
                image.filepath = '//textures/' + Path(image.filepath).name
        bpy.ops.wm.save_as_mainfile(filepath=str(out / (target + '.blend')))
        bpy.ops.object.select_all(action='DESELECT')
        # Explicit named, untextured export slots retain catalogue identity.
        # Actual PBR maps are shared at runtime rather than embedded per asset.
        placeholders = {}
        for key in keys:
            mat = bpy.data.materials.new('CATALOG_' + key)
            mat.use_nodes = True
            node = mat.node_tree.nodes['Principled BSDF']
            node.inputs['Base Color'].default_value = (.5, .5, .5, 1)
            node.inputs['Metallic'].default_value = catalog[key]['metallic']
            node.inputs['Base Color'].default_value = (*keys[key]['catalog_tint'], 1)
            placeholders[key] = mat
        native_parts = {}
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH' or obj.name not in keep:
                continue
            obj.hide_set(False)
            obj.select_set(True)
            mesh = obj.data
            mesh.name = obj.name
            for slot in obj.material_slots:
                slot.material = placeholders[slot.material['catalog_key']]
            native_parts[obj.name] = dict(matrix=[list(row) for row in obj.matrix_world],
                materials=[slot.material.name.removeprefix('CATALOG_') for slot in obj.material_slots])
            if obj.name == 'RemovableFibrousUnionPacking':
                rest = np.array([v.co[:] for v in mesh.shape_keys.key_blocks['Seated'].data])
                end = np.array([v.co[:] for v in mesh.shape_keys.key_blocks['SpreadForRemoval'].data])
                obj.shape_key_clear()
                obj.shape_key_add(name='Seated')
                for index in range(1, 21):
                    key = obj.shape_key_add(name='Spread_%02d' % index)
                    key.data.foreach_set('co', (rest + (end - rest) * index / 20).astype(np.float32).ravel())
            import bmesh
            from fabrication_normals import stock_corner_normals
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            bm.to_mesh(mesh)
            bm.free()
            mesh.normals_split_custom_set(stock_corner_normals(mesh))
            # Native kit files may already contain corner export guides.
            # Topology edits invalidate them; replace rather than generating
            # .001 attributes beside stale guides with the same export name.
            for attr in list(mesh.attributes):
                if any(attr.name==prefix or attr.name.startswith(prefix+'.')
                       for prefix in ['_tangent_guide','_bitangent_guide','_export_corner']):
                    mesh.attributes.remove(attr)
            uv = mesh.uv_layers.active.data
            tangents, bitangents = [], []
            for face in mesh.polygons:
                a, b, c = [mesh.vertices[i].co for i in face.vertices]
                ua, ub, uc = [uv[i].uv for i in face.loop_indices]
                du, dv = ub - ua, uc - ua
                det = du.x * dv.y - du.y * dv.x
                assert abs(det) > 1e-18
                u = (((b - a) * dv.y - (c - a) * du.y) / det).normalized()
                v = (((c - a) * du.x - (b - a) * dv.x) / det).normalized()
                tangents.extend([(u.x, u.z, -u.y)] * 3)
                bitangents.extend([(-v.x, -v.z, v.y)] * 3)
            for name, values in [('_tangent_guide', tangents), ('_bitangent_guide', bitangents)]:
                attr = mesh.attributes.new(name=name, type='FLOAT_VECTOR', domain='CORNER')
                attr.data.foreach_set('vector', np.asarray(values, dtype=np.float32).ravel())
            attr = mesh.attributes.new(name='_export_corner', type='FLOAT', domain='CORNER')
            attr.data.foreach_set('value', np.arange(len(mesh.loops), dtype=np.float32))
        asset = out / (target + '.glb')
        namespace['export_errors'].clear()
        bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
            export_yup=True, export_tangents=True, export_attributes=True,
            export_morph_tangent=True, export_materials='EXPORT', export_unused_images=False)
        assert not namespace['export_errors'], namespace['export_errors']
        check = validate(asset)
        exported = glb_json(asset)
        assert 'images' not in exported and 'textures' not in exported
        assert {m['name'] for m in exported['meshes']} == keep
        for mat in exported['materials']:
            assert mat['name'].removeprefix('CATALOG_') in catalog
        check.update(native_geometry_sha256=before, native_parts=native_parts,
            source_native_geometry_sha256=original,
            cast_refinement=refinement,
            asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),
            native_sha256=hashlib.sha256((out / (target + '.blend')).read_bytes()).hexdigest())
        report['families'][target] = check
        print('PRODUCTION RADIATOR', target, check['status'], flush=True)
    (out / 'production_manifest.json').write_text(json.dumps(report, indent=2) + '\n',
                                                encoding='utf-8', newline='\n')


if __name__ == '__main__':
    prepare()
