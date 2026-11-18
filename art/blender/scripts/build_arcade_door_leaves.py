"""CPU/background native authoring; mandatory fresh PRIVATE --out directory.

No render, GPU job, Godot import or repository output. Both1m leaves retain
their own local hinge frames. Stock doors reuse one of these unscaled leaves.
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import sys

import bpy
import bmesh
import numpy as np

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(Path(__file__).resolve().parent))
import arcade_door_leaf_geometry as geometry
from fabrication_native_batch import material, export
from fabrication_chart_batch import triangle_charts
from fabrication_normals import stock_corner_normals


def digest(path,lf=True):
    data=Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n',b'\n') if lf else data).hexdigest()


def godot_to_blender(p):return (p[0],-p[2],p[1])
def blender_to_godot(p):return [p[0],p[2],-p[1]]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    output=args.out.resolve()
    if output.is_relative_to(ROOT.resolve()):raise ValueError('private output outside checkout required')
    if output.exists() and any(output.iterdir()):raise FileExistsError('fresh empty output required')
    (output/'art/blender').mkdir(parents=True,exist_ok=True)
    (output/'game/assets/props').mkdir(parents=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene['evidence_class']='INERT'
    scene['scope']='Native unscaled1m paired/stock leaves; no runtime motion/save/render proof'
    editable=bpy.data.collections.new('Independent editable closed leaf stocks')
    draws=bpy.data.collections.new('Moving and fixed local hinge exports')
    scene.collection.children.link(editable);scene.collection.children.link(draws)
    catalog_path=ROOT/'game/data/runtime_material_sets.json'
    catalog=json.loads(catalog_path.read_text())['materials']
    keys=['door_oak','glass_drawn_expressive','door_brass']
    finishes={key:dict(catalog_key=key,tint=[1,1,1,1],pigment=1.,normal=.18,
                       roughness=1.) for key in keys}
    mats={key:material(ROOT,'M_'+key,finishes[key],catalog) for key in keys}

    def chart_mesh(mesh,horizontal=False):
        coords=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64)
        indices=np.asarray([l.vertex_index for l in mesh.loops]).reshape((-1,3))
        rotation=np.array([[0,0,-1],[0,1,0],[1,0,0]]) if horizontal else np.eye(3)
        rotations=np.broadcast_to(rotation,(len(indices),3,3))
        _,tangent,uv,_=triangle_charts(coords[indices],np.zeros(3),1.,rotations)
        layer=mesh.uv_layers.new(name='MetresLongitudinalStock')
        layer.data.foreach_set('uv',uv.astype(np.float32).ravel())
        guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
        values=np.repeat(tangent[:,[0,2,1]],3,axis=0);values[:,2]*=-1
        guide.data.foreach_set('vector',values.astype(np.float32).ravel())
        for face in mesh.polygons:face.use_smooth=True
        mesh.normals_split_custom_set(stock_corner_normals(mesh,planar_axes=((1,0,0),(0,1,0),(0,0,1))))

    parts=[];groups=collections.defaultdict(list)
    for row in geometry.stocks():
        mesh=bpy.data.meshes.new(row['name'])
        mesh.from_pydata([godot_to_blender(v) for v in row['vertices']],[],row['faces']);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),row['name']
        assert bm.calc_volume(signed=True)>1e-12,row['name']
        if row['bevel_m']:
            edges=[e for e in bm.edges if e.calc_face_angle(0)>.6]
            bmesh.ops.bevel(bm,geom=edges,offset=row['bevel_m'],segments=2,affect='EDGES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),row['name']
        volume=bm.calc_volume(signed=True);assert volume>1e-12,row['name']
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
        chart_mesh(mesh,row['material']=='door_oak' and row['grain']=='horizontal')
        mesh.materials.append(mats[row['material']])
        obj=bpy.data.objects.new(row['name'],mesh);editable.objects.link(obj)
        obj['role']=row['role'];obj['export_group']=row['group'];obj['material_key']=row['material']
        obj['grain']='longitudinal_'+row['grain'] if row['material']=='door_oak' else 'nonwood'
        vertices=[blender_to_godot(v.co) for v in mesh.vertices]
        parts.append(dict(name=row['name'],group=row['group'],side=row['side'],role=row['role'],
            material_key=row['material'],triangles=len(mesh.polygons),closed_volume_m3=volume,
            low=[min(v[i] for v in vertices) for i in range(3)],high=[max(v[i] for v in vertices) for i in range(3)],
            grain=row['grain'] if row['material']=='door_oak' else None))
        groups[row['group']].append(obj)
    # Copy actual derivative arrays into eight identity-frame material draws;
    # keep editable source stocks separate and closed in the native.blend.
    draw_records=[]
    for name,objects in sorted(groups.items()):
        verts=[];faces=[];uv=[];normal=[];guide=[]
        for obj in objects:
            mesh=obj.data;offset=len(verts);verts.extend(v.co[:] for v in mesh.vertices)
            faces.extend(tuple(offset+i for i in f.vertices) for f in mesh.polygons)
            uv.extend(x.uv[:] for x in mesh.uv_layers.active.data)
            normal.extend(x.vector[:] for x in mesh.corner_normals)
            guide.extend(x.vector[:] for x in mesh.attributes['_tangent_guide'].data)
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
        layer=mesh.uv_layers.new(name='MetresLongitudinalStock')
        layer.data.foreach_set('uv',np.asarray(uv,dtype=np.float32).ravel())
        attribute=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
        attribute.data.foreach_set('vector',np.asarray(guide,dtype=np.float32).ravel())
        for face in mesh.polygons:face.use_smooth=True
        mesh.normals_split_custom_set(normal)
        mesh.materials.append(objects[0].data.materials[0])
        obj=bpy.data.objects.new(name,mesh);draws.objects.link(obj)
        draw_records.append(dict(name=name,material_key=str(objects[0]['material_key']),triangles=len(faces),
                                 transform='IDENTITY_LOCAL_HINGE'))
    expected={'LeftWood','LeftGlass','LeftBrass','RightWood','RightGlass','RightBrass','LeftFixedBrass','RightFixedBrass'}
    assert set(groups)==expected
    editable.hide_render=True;editable.hide_viewport=True
    scene.view_layers[0].update()
    proof=export(output,'arcade_door_leaves',draws,material_names_only=True)
    assert proof['status']=='PASS'
    assert proof['triangles']==sum(x['triangles'] for x in draw_records)
    pulls={};cores={}
    for side in ['Left','Right']:
        wood=[x for x in parts if x['side']==side and x['material_key']=='door_oak']
        cores[side]={'low':[min(x['low'][i] for x in wood) for i in range(3)],
                     'high':[max(x['high'][i] for x in wood) for i in range(3)]}
        pulls[side]=[]
        for face in [-1,1]:
            selected=[x for x in parts if x['side']==side and x['role'].startswith('pull_')
                      and (x['low'][2]+x['high'][2])*face>0]
            pulls[side].append(dict(face=face,low=[min(x['low'][i] for x in selected) for i in range(3)],
                high=[max(x['high'][i] for x in selected) for i in range(3)],source_stocks=[x['name'] for x in selected]))
    bindings=['art/blender/scripts/'+f for f in ['build_arcade_door_leaves.py','arcade_door_leaf_geometry.py',
        'build_passage_shop_leaves.py','fabrication_native_batch.py','fabrication_chart_batch.py',
        'fabrication_uvs.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
    bindings+=['game/data/runtime_material_sets.json','art/data/arcade_plaza/source_plan.json']
    bindings+=['game/assets/building/textures/'+name for key in keys for name in catalog[key]['files']]
    plaza=json.loads((ROOT/'art/data/arcade_plaza/source_plan.json').read_text())
    report=dict(evidence_class='INERT',schema='orison.v2.arcade-door-leaves.v1',
        status='NATIVE_EXPORT_PASS_UNRENDERED_NOT_INSTALLED',blender_version=bpy.app.version_string,
        dimensions=dict(nominal_width_m=1.,nominal_height_m=2.30,bottom_m=.020,top_m=2.290,
                        timber_depth_m=.044,left_x_m=[.01,.99],right_x_m=[-.99,-.01]),
        hinge_axis_local_godot=dict(Left=[0,0,geometry.HINGE_Z],Right=[0,0,geometry.HINGE_Z]),
        hinge_heights_m=list(geometry.HINGE_HEIGHTS),pull_centre_height_m=geometry.PULL_CENTRE_Y,
        core_collision_boxes=cores,pull_collision_boxes=pulls,parts=parts,draws=draw_records,
        asset='res://assets/props/arcade_door_leaves.glb',asset_sha256=digest(output/'game/assets/props/arcade_door_leaves.glb',False),
        native_sha256=digest(output/'art/blender/arcade_door_leaves.blend',False),derivatives=proof,
        materials=finishes,glazing_runtime=plaza['materials']['glazing'],
        source_bindings={name:dict(sha256=digest(ROOT/name,not name.endswith('.png')),
                                 kind='raw' if name.endswith('.png') else 'lf') for name in bindings},
        limits=['No rendered/material appearance or Godot import/motion/contact proof.',
                'Runtime owns separate fixed/moving transforms, original keys/locks/save and actual inputs.',
                'Core/pull colliders are native-local bounds; never use the complete brass bounds for a collider.',
                'Geometry is authored at full metric size; stock doors reuse one unscaled leaf.',
                'Hinge pin radius3.8mm/bore4.5mm; loaded moving sweep/contact remains unqualified.'])
    (output/'DOOR_LEAVES.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ARCADE_DOOR_LEAVES_PASS',len(parts),'closed stocks',proof['triangles'],'triangles')


if __name__=='__main__':main()
