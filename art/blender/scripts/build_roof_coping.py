"""Mitered, jointed stone weather caps with sloped crowns and underside drips."""
from pathlib import Path
import json, math
import bpy
ROOT=Path(__file__).resolve().parents[3]
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
records=[r for r in layout['fixtures'] if r.get('fabrication')=='roof_coping']
assert len(records)==4
x0=min(r['position'][0]-r['size'][0]*.5 for r in records)
x1=max(r['position'][0]+r['size'][0]*.5 for r in records)
z0=min(r['position'][2]-r['size'][2]*.5 for r in records)
z1=max(r['position'][2]+r['size'][2]*.5 for r in records)
low=min(r['position'][1]-r['size'][1]*.5 for r in records)
high=max(r['position'][1]+r['size'][1]*.5 for r in records)
width=min(min(r['size'][0],r['size'][2]) for r in records)
half_x=(x1-x0)*.5; half_z=(z1-z0)*.5
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('concrete'); mat.use_nodes=True
shader=mat.node_tree.nodes['Principled BSDF']; shader.inputs['Base Color'].default_value=(.43,.41,.37,1)
shader.inputs['Roughness'].default_value=.8
profile=[(0,low),(0,high-.015),(width*.5,high),(width,high-.015),
         (width,low),(width-.04,low),(width-.04,low+.006),
         (width-.05,low+.006),(width-.05,low),(.05,low),
         (.05,low+.006),(.04,low+.006),(.04,low)]
for axis in ['x','z']:
    half_length=half_x if axis=='x' else half_z
    half_normal=half_z if axis=='x' else half_x
    count=math.ceil(half_length*2/1.2); pitch=half_length*2/count
    for side in [-1,1]:
        for index in range(count):
            a=-half_length+index*pitch; b=a+pitch
            verts=[]
            for end in [0,1]:
                for inset,y in profile:
                    along=max(a+.00075,-half_length+inset) if end==0 else min(b-.00075,half_length-inset)
                    normal=side*(half_normal-inset)
                    x,z=(along,normal) if axis=='x' else (normal,along)
                    verts.append((x,-z,y))
            n=len(profile)
            faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
            faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            data=bpy.data.meshes.new('WeatherStone'); data.from_pydata(verts,[],faces); data.update()
            obj=bpy.data.objects.new('MiteredWeatherStone',data); bpy.context.collection.objects.link(obj)
            data.materials.append(mat)
for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_coping.blend'))
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
bpy.ops.object.join(); bpy.context.object.name='CopingCourse'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_coping.glb'),export_format='GLB',export_yup=True,export_apply=True)
