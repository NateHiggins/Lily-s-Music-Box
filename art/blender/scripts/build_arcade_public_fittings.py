"""Reauthor two clock suspension stocks and five fixed pavement hatch plates.

Private native delivery only. The whole original clock remains scripted by
its existing owner; none of these seven stocks adds an interaction or save.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import sys

import bpy
import bmesh
from mathutils import Matrix

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
import arcade_clock_suspension_geometry as Clock
import arcade_hatch_geometry as Hatches
from fabrication_native_batch import material, partition, export


def load(name):
    return json.loads((ROOT/name).read_text(encoding='utf-8'))


def sha(path):
    data = Path(path).read_bytes()
    if Path(path).suffix not in {'.png', '.glb', '.blend'}:
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out = args.out.resolve()
    if out.is_relative_to(ROOT.resolve()): raise ValueError('private output required')
    if out.exists() and any(out.iterdir()): raise FileExistsError(out)
    for name in ['art/blender', 'game/assets/props', 'game/assets/building/textures', 'game/data/orison_v2']:
        (out/name).mkdir(parents=True, exist_ok=True)
    paths = dict(layout='game/data/building_layout.json', clock='game/data/orison_v2/arcade_clock.json',
                 plaza='art/data/arcade_plaza/source_plan.json', roof='art/data/arcade_plaza/roof_plan.json',
                 catalog='game/data/runtime_material_sets.json')
    inputs = {key: load(path) for key,path in paths.items()}
    clock = Clock.build(inputs['layout'], inputs['clock'], inputs['plaza'], inputs['roof'])
    hatches = Hatches.build(inputs['layout'], inputs['plaza'])
    catalog = inputs['catalog']['materials']
    finishes = {
        'cast_iron': dict(catalog_key='cast_iron', tint=[1,1,1,1], pigment=1., normal=.35, roughness=.6, metallic=.35),
        'brass_dull': dict(catalog_key='brass_dull', tint=[1,1,1,1], pigment=1., normal=.35, roughness=.52, metallic=.3),
        'metal': dict(catalog_key='metal', tint=[1,1,1,1], pigment=1., normal=.35, roughness=1., metallic=catalog['metal']['metallic']),
    }
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    scene['evidence_class']='INERT'
    scene['scope']='Seven source-owned public stocks; no original donor disposal or gameplay authority'
    stocks=bpy.data.collections.new('Editable closed source stocks')
    draws=bpy.data.collections.new('Seven UV mapped source identity draws')
    scene.collection.children.link(stocks); scene.collection.children.link(draws)
    mats={key:material(ROOT,'M_'+key,finish,catalog) for key,finish in finishes.items()}
    for image in bpy.data.images:
        if image.source=='FILE':
            target=out/'game/assets/building/textures'/Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath),target); image.filepath=str(target)
    parts=[]
    for kind,rows in [('clock',clock['stocks']),('hatch',hatches['stocks'])]:
        for row in rows:
            if kind=='clock':
                vertices=[(x,-z,y) for x,y,z in row['vertices']]
                godot_origin=inputs['clock']['origin']
            else:
                vertices=[(u,-v,h) for u,v,h in row['vertices']]
                p=inputs['plaza']['source_origin_blender_m']
                godot_origin=[p[0],p[2],-p[1]]
            frame=Matrix.Translation((godot_origin[0],-godot_origin[2],godot_origin[1]))
            mesh=bpy.data.meshes.new(row['name']); mesh.from_pydata(vertices,[],row['faces']); mesh.update()
            bm=bmesh.new(); bm.from_mesh(mesh)
            assert all(e.is_manifold for e in bm.edges),row['name']
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            volume=bm.calc_volume(signed=True); assert volume>0,row['name']
            bm.to_mesh(mesh); bm.free(); mesh.materials.append(mats[row['material']])
            obj=bpy.data.objects.new(row['name']+'__editable',mesh); stocks.objects.link(obj); obj.matrix_world=frame
            obj['source_record_id']=row['source_record_id']
            finish=finishes[row['material']]
            draw=partition(draws,row['name'],[obj],finish,mats[row['material']],frame,catalog)
            transform=[[1,0,0,godot_origin[0]],[0,1,0,godot_origin[1]],[0,0,1,godot_origin[2]],[0,0,0,1]]
            parts.append(dict(name=row['name'],source_id=row['source_record_id'],kind=kind,material=row['material'],
                              triangles=len(draw.data.polygons),transform=transform,closed_volume_m3=volume))
    stocks.hide_render=True; stocks.hide_viewport=True; scene.view_layers[0].update()
    derivative=export(out,'arcade_public_fittings',draws,material_names_only=True)
    assert derivative['status']=='PASS' and derivative['triangles']==sum(p['triangles'] for p in parts)
    bindings=list(paths.values())+['art/blender/scripts/'+name for name in [
        'build_arcade_public_fittings.py','arcade_clock_suspension_geometry.py','arcade_roof_geometry.py',
        'arcade_hatch_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py',
        'fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
    bindings+=['game/assets/building/textures/'+name for key in finishes for name in catalog[key]['files']]
    old_asset='game/'+inputs['clock']['asset'][6:]; bindings.append(old_asset)
    runtime=dict(schema='orison.v2.arcade-public-fittings.v1',asset='res://assets/props/arcade_public_fittings.glb',
        asset_sha256=sha(out/'game/assets/props/arcade_public_fittings.glb'),
        fabrication_sha256_lf=sha(ROOT/paths['layout']),clock_source_sha256_lf=sha(ROOT/paths['clock']),
        clock_asset_sha256=sha(ROOT/old_asset),clock_delta=clock['proof']['delta'],
        parts=[{k:v for k,v in p.items() if k!='closed_volume_m3'} for p in parts],
        materials=[dict(key=key,**{k:v for k,v in f.items() if k!='catalog_key'}) for key,f in finishes.items()])
    report=dict(evidence_class='INERT',status='NATIVE_EXPORT_PASS_UNRENDERED_NOT_INSTALLED',
        blender_version=bpy.app.version_string,clock=clock,hatches=hatches,parts=parts,derivatives=derivative,
        source_bindings={name:sha(ROOT/name) for name in sorted(set(bindings))},
        blend_sha256=sha(out/'art/blender/arcade_public_fittings.blend'),runtime=runtime,
        limits=['Original donor geometry retained; not source-disposal authorization.',
                'No runtime, gameplay/save, human-play or artistic acceptance from native export.'])
    for path,value in [(out/'PUBLIC_FITTINGS.json',report),(out/'game/data/orison_v2/arcade_public_fittings.json',runtime)]:
        path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ARCADE_PUBLIC_FITTINGS_PASS',len(parts),'stocks;',derivative['triangles'],'triangles')


if __name__=='__main__': main()
