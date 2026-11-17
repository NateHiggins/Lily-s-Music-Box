"""Author source-bound supporting felt stocks into a fresh private output tree.

CPU/background Blender authoring only. Original apparatus/donor files stay intact.
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

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(Path(__file__).resolve().parent))
import arcade_cobbler_field_geometry as geometry
from fabrication_native_batch import material,partition,export

INPUTS=['art/data/arcade_plaza/source_plan.json','game/data/building_layout.json',
        'art/data/arcade_plaza/retained_equipment_placements.json',
        'game/tests/fixtures/orison_cobbler_fittings.json']
SIDECAR='game/data/orison_v2/cobbler_fittings.json'
PROFILES='game/data/orison_v2/owner_finish_profiles.json'
CATALOG='game/data/runtime_material_sets.json'

def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def digest(path,raw=False):
    value=Path(path).read_bytes()
    return hashlib.sha256(value if raw else value.replace(b'\r\n',b'\n')).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.out.resolve()
    if out.is_relative_to(ROOT.resolve()):raise ValueError('fresh private output required')
    if out.exists() and any(out.iterdir()):raise FileExistsError(out)
    for path in ['art/blender','game/assets/props','game/assets/building/textures']:(out/path).mkdir(parents=True,exist_ok=True)
    values=[load(path) for path in INPUTS];result=geometry.build(*values)
    source_parts=[r for cell in load(SIDECAR)['cells'] if cell['id']==geometry.CELL
                  for r in cell['parts'] if r['name'].startswith(geometry.FELT+'__')]
    assert {r['name'] for r in source_parts}=={geometry.FELT+'__soot__north',geometry.FELT+'__soot__south'}
    recipe={k:v for k,v in source_parts[0].items() if k!='name'}
    assert all({k:v for k,v in r.items() if k!='name'}==recipe for r in source_parts)
    profile=next(r for g in load(PROFILES)['groups'] if g['id']=='shop' for r in g['recipes'] if r['source_key']==recipe['catalog_key'])
    assert profile.get('retain_tint') is True
    finish=dict(catalog_key=recipe['catalog_key'],tint=recipe['tint'],normal=profile['normal'],
                roughness=profile['roughness'],metallic=profile['metallic'],pigment=profile['pigment'])
    catalog=load(CATALOG)['materials'];assert catalog[finish['catalog_key']]['meters_per_tile']==recipe['tile']
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene['evidence_class']='INERT';scene['scope']='Source fitted support mats; no donor disposal/runtime admission'
    editable=bpy.data.collections.new('Editable closed supporting felt stocks')
    draws=bpy.data.collections.new('Material batch')
    scene.collection.children.link(editable);scene.collection.children.link(draws)
    mat=material(ROOT,'M_arcade_cobbler_felt',finish,catalog)
    # Keep the saved native source portable at its eventual canonical location.
    for image in bpy.data.images:
        if image.source=='FILE':
            target=out/'game/assets/building/textures'/Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath),target);image.filepath=str(target)
    origin=values[0]['source_origin_blender_m'];objects=[];records=[]
    for row in result['stocks']:
        vertices=[(u+origin[0],origin[1]-v,h) for u,v,h in row['vertices']]
        mesh=bpy.data.meshes.new(row['name']);mesh.from_pydata(vertices,[],row['faces']);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),row['name']
        actual=[v.co[:] for v in bm.verts]
        low=[min(v[i] for v in actual) for i in range(3)];high=[max(v[i] for v in actual) for i in range(3)]
        quantized_volume=(high[0]-low[0])*(high[1]-low[1])*(high[2]-low[2])
        volume=bm.calc_volume(signed=True);assert abs(volume-quantized_volume)<1e-10
        vertex_error=max(abs(a-b) for p,q in zip(actual,vertices) for a,b in zip(p,q))
        assert vertex_error<.000004 # Float32 at the actual ~50m source coordinates, not contact tolerance.
        bm.to_mesh(mesh);bm.free()
        obj=bpy.data.objects.new(row['name'],mesh);editable.objects.link(obj);objects.append(obj)
        obj['source_record_id']=geometry.FELT;obj['role']='supporting_felt_field'
        obj['source_geometry_unchanged']=True
        records.append(dict(row,actual_native_volume_m3=volume,native_vertex_quantization_m=vertex_error))
    draw=partition(draws,'CobblerSupportingFelt',objects,finish,mat,Matrix.Identity(4),catalog)
    editable.hide_render=True;editable.hide_viewport=True;scene.view_layers[0].update()
    proof=export(out,'arcade_cobbler_field',draws,material_names_only=True)
    assert proof['status']=='PASS' and proof['triangles']==12*len(records)
    bindings=INPUTS+[SIDECAR,PROFILES,CATALOG,'game/assets/props/cobbler_fittings.glb']
    bindings+=['art/blender/scripts/'+name for name in ['build_arcade_cobbler_field.py','arcade_cobbler_field_geometry.py',
        'fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py','fabrication_grain.py',
        'fabrication_normals.py','check_exported_tangents.py']]
    bindings+=['game/assets/building/textures/'+name for name in catalog[finish['catalog_key']]['files']]
    report=dict(schema='orison.v2.arcade-cobbler-field.v1',evidence_class='INERT',
        status='NATIVE_EXPORT_PASS_UNRENDERED_NOT_INSTALLED',blender_version=bpy.app.version_string,
        asset='res://assets/props/arcade_cobbler_field.glb',
        asset_sha256=digest(out/'game/assets/props/arcade_cobbler_field.glb',True),
        native_sha256=digest(out/'art/blender/arcade_cobbler_field.blend',True),
        draw=dict(name=draw.name,triangles=proof['triangles'],transform='IDENTITY_SOURCE_GODOT'),
        material=finish,source_material_parts=source_parts,stocks=records,support=result['proof'],derivatives=proof,
        source_bindings={name:dict(sha256=digest(ROOT/name,name.endswith(('.glb','.png'))),
            kind='raw' if name.endswith(('.glb','.png')) else 'lf') for name in bindings},
        limits=['No original apparatus or old field changed/disposed.',
                'New lower face0 and upper face.008 preserve transformed foot heights and remove old2mm floor gap.',
                'Runtime material must borrow original mounted linen/tint and use the existing shop owner finish.',
                'No runtime contact/import/mipmap or rendered acceptance follows from native export.'])
    (out/'COBBLER_FIELD.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ARCADE_COBBLER_FIELD_PASS',len(records),'closed stocks',proof['triangles'],'triangles')

if __name__=='__main__':main()
