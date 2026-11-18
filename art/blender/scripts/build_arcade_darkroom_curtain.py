"""Native curtained infill for the existing 1m arcade stock leaf; private output.

No leaf scaling, new mechanism, curtain simulation or source donor disposal.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,sys
import bpy,bmesh,numpy as np

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(Path(__file__).resolve().parent))
import arcade_darkroom_curtain_geometry as geometry
from fabrication_native_batch import material,export
from fabrication_normals import stock_corner_normals

SOURCE='game/data/orison_v2/photo_radio_fittings.json'
PROFILES='game/data/orison_v2/owner_finish_profiles.json'
CATALOG='game/data/runtime_material_sets.json'

def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def digest(path,raw=False):
    data=Path(path).read_bytes();return hashlib.sha256(data if raw else data.replace(b'\r\n',b'\n')).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.out.resolve()
    if out.is_relative_to(ROOT.resolve()):raise ValueError('private output required')
    if out.exists() and any(out.iterdir()):raise FileExistsError(out)
    for name in ['art/blender','game/assets/props','game/assets/building/textures']:(out/name).mkdir(parents=True,exist_ok=True)
    source=[r for c in load(SOURCE)['cells'] if c['id']=='shop_photo_supplies' for r in c['parts'] if r['name'].startswith('storm_shop_photo_supplies_dr_door__')]
    assert len(source)==3
    original=next(r for r in source if r['key']=='fabric_warm')
    profile=next(r for g in load(PROFILES)['groups'] if g['id']=='shop' for r in g['recipes'] if r['source_key']=='fabric_warm')
    assert profile['retain_tint']
    finish=dict(catalog_key=original['catalog_key'],tint=original['tint'],normal=profile['normal'],
                roughness=profile['roughness'],metallic=profile['metallic'],pigment=profile['pigment'])
    catalog=load(CATALOG)['materials'];assert catalog[finish['catalog_key']]['meters_per_tile']==original['tile']
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene['evidence_class']='INERT';scene['scope']='Two opaque cloth infill stocks, existing single-leaf mechanism owns motion'
    editable=bpy.data.collections.new('Editable closed pleated cloth stocks');draws=bpy.data.collections.new('Curtain material draw')
    scene.collection.children.link(editable);scene.collection.children.link(draws)
    mat=material(ROOT,'M_arcade_darkroom_fabric',finish,catalog)
    for image in bpy.data.images:
        if image.source=='FILE':
            target=out/'game/assets/building/textures'/Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath),target);image.filepath=str(target)
    records=[];objects=[]
    for row in geometry.stocks():
        vertices=[(x,-z,y) for x,y,z in row['vertices']]
        mesh=bpy.data.meshes.new(row['name']);mesh.from_pydata(vertices,[],row['faces']);mesh.update()
        uv=mesh.uv_layers.new(name='MetresCurvedRestLength')
        for face,values in zip(mesh.polygons,row['face_uvs']):
            assert len(values)==face.loop_total
            for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
        bm=bmesh.new();bm.from_mesh(mesh)
        assert all(e.is_manifold for e in bm.edges),row['name']
        volume=bm.calc_volume(signed=True);assert volume>0,row['name']
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
        xyz=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64)
        ids=np.asarray([l.vertex_index for l in mesh.loops]).reshape((-1,3));p=xyz[ids]
        coords=np.asarray([v.uv[:] for v in mesh.uv_layers.active.data],dtype=np.float64).reshape((-1,3,2))
        a=p[:,1]-p[:,0];b=p[:,2]-p[:,0];u=coords[:,1]-coords[:,0];v=coords[:,2]-coords[:,0]
        det=u[:,0]*v[:,1]-u[:,1]*v[:,0];assert np.all(abs(det)>1e-12),row['name']
        tangent=(a*v[:,1,None]-b*u[:,1,None])/det[:,None]
        bitangent=(-a*v[:,0,None]+b*u[:,0,None])/det[:,None]
        normals=np.cross(a,b)
        assert np.all(np.sum(np.cross(tangent,bitangent)*normals,axis=1)>0),'native UV orientation'
        guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
        # Custom vector attributes are not axis-converted by glTF's exporter.
        # The shared hook reads this guide beside already Godot-frame normals.
        converted=tangent[:,[0,2,1]].copy();converted[:,2]*=-1
        guide.data.foreach_set('vector',np.repeat(converted,3,axis=0).astype(np.float32).ravel())
        for face in mesh.polygons:face.use_smooth=True
        mesh.normals_split_custom_set(stock_corner_normals(mesh))
        mesh.materials.append(mat)
        obj=bpy.data.objects.new(row['name'],mesh);editable.objects.link(obj);objects.append(obj)
        obj['source_record_id']='storm_shop_photo_supplies_dr_door';obj['role']='opaque_pleated_infill'
        records.append(dict(name=row['name'],triangles=len(mesh.polygons),closed_volume_m3=volume,
                            low=[min(p[i] for p in row['vertices']) for i in range(3)],high=[max(p[i] for p in row['vertices']) for i in range(3)]))
    assert len(objects)==2
    vertices=[];faces=[];uv=[];normal=[];guide=[]
    for obj in objects:
        mesh=obj.data;offset=len(vertices);vertices.extend(v.co[:] for v in mesh.vertices)
        faces.extend(tuple(offset+i for i in f.vertices) for f in mesh.polygons)
        uv.extend(x.uv[:] for x in mesh.uv_layers.active.data);normal.extend(x.vector[:] for x in mesh.corner_normals)
        guide.extend(x.vector[:] for x in mesh.attributes['_tangent_guide'].data)
    mesh=bpy.data.meshes.new('LeftDarkroomCurtain');mesh.from_pydata(vertices,[],faces);mesh.update()
    layer=mesh.uv_layers.new(name='MetresCurvedRestLength');layer.data.foreach_set('uv',np.asarray(uv,dtype=np.float32).ravel())
    attribute=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');attribute.data.foreach_set('vector',np.asarray(guide,dtype=np.float32).ravel())
    for face in mesh.polygons:face.use_smooth=True
    mesh.normals_split_custom_set(normal);mesh.materials.append(mat)
    obj=bpy.data.objects.new('LeftDarkroomCurtain',mesh);draws.objects.link(obj)
    editable.hide_render=True;editable.hide_viewport=True;scene.view_layers[0].update()
    proof=export(out,'arcade_darkroom_curtain',draws,material_names_only=True);assert proof['status']=='PASS'
    assert proof['triangles']==sum(r['triangles'] for r in records)
    bindings=[SOURCE,PROFILES,CATALOG,'art/blender/scripts/photo_radio_fittings_geometry.py',
        'art/blender/scripts/build_photo_radio_fittings.py','art/blender/scripts/arcade_door_leaf_geometry.py']
    bindings+=['art/blender/scripts/'+name for name in ['build_arcade_darkroom_curtain.py','arcade_darkroom_curtain_geometry.py',
        'fabrication_native_batch.py','fabrication_normals.py','check_exported_tangents.py']]
    bindings+=['game/assets/building/textures/'+name for name in catalog['fabric_warm']['files']]
    report=dict(schema='orison.v2.arcade-darkroom-curtain.v1',evidence_class='INERT',
        status='NATIVE_EXPORT_PASS_UNRENDERED_NOT_INSTALLED',blender_version=bpy.app.version_string,
        asset='res://assets/props/arcade_darkroom_curtain.glb',asset_sha256=digest(out/'game/assets/props/arcade_darkroom_curtain.glb',True),
        native_sha256=digest(out/'art/blender/arcade_darkroom_curtain.blend',True),
        parts=[dict(name=obj.name,triangles=proof['triangles'],material_key='fabric_warm')],stocks=records,material=finish,
        original_parts=source,derivatives=proof,
        source_bindings={name:dict(sha256=digest(ROOT/name,name.endswith('.png')),kind='raw' if name.endswith('.png') else 'lf') for name in bindings},
        limits=['Curtained upper infill only; unchanged existing wood/hardware/collision envelope and one door state owner.',
                'Original three closed-wall donor parts remain retained; no disposal or full photometric light-tightness claim.',
                'No runtime import, loaded maps, movement, actual input, saved-state or artistic acceptance follows from native export.'])
    (out/'DARKROOM_CURTAIN.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ARCADE_DARKROOM_CURTAIN_PASS',len(records),'closed stocks',proof['triangles'],'triangles')

if __name__=='__main__':main()
