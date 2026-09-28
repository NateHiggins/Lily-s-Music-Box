"""Bonded brick chimney with recessed mortar and an open weathered stone coping."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
groups={name:[] for name in ['Brick','Mortar','Coping']}
materials={}
for name,color in [('brick',(.38,.17,.10)),('concrete',(.42,.40,.35))]:
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.85
    materials[name]=mat

def box(name,at,size,group,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object; obj.name=name; obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Arris','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(materials['brick' if group=='Brick' else 'concrete'])
    groups[group].append(obj)

# Recessed bed surrounds the real throat; no solid cap or hidden centre cube.
for side in [-1,1]:
    box('MortarCheek',(side*.175,1.02,0),(.097,2.04,.697),'Mortar')
    box('MortarEnd',(0,1.02,side*.30),(.253,2.04,.097),'Mortar')

for course in range(24):
    y=(course+.5)*.085
    # Alternate bonded corners: long cheeks on one course, long ends on next.
    for side in [-1,1]:
        if course%2==0:
            for z in [-.17575,.17575]:
                box('BondedCheek',(side*.175,y,z),(.10,.082,.3485),'Brick',.001)
            box('BondedEnd',(0,y,side*.30),(.247,.082,.10),'Brick',.001)
        else:
            for x in [-.11325,.11325]:
                box('BondedEnd',(x,y,side*.30),(.2235,.082,.10),'Brick',.001)
            box('BondedCheek',(side*.175,y,0),(.10,.082,.497),'Brick',.001)

# Cross-section walks up the outer weather edge and back down the open throat.
profile=[(.255,.41,2.04),(.255,.41,2.14),(.245,.40,2.16),
         (.095,.22,2.16),(.095,.22,2.04)]
verts=[(sx*x,-sz*z,y) for x,z,y in profile for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]]
faces=[]
for ring in range(len(profile)):
    for corner in range(4):
        faces.append((ring*4+corner,ring*4+(corner+1)%4,((ring+1)%len(profile))*4+(corner+1)%4,((ring+1)%len(profile))*4+corner))
data=bpy.data.meshes.new('OpenCoping'); data.from_pydata(verts,[],faces); data.update()
obj=bpy.data.objects.new('OpenCoping',data); bpy.context.collection.objects.link(obj)
obj.data.materials.append(materials['concrete']); groups['Coping'].append(obj)

for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/chimney_crown.blend'))
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/chimney_crown.glb'),export_format='GLB',export_yup=True,export_apply=True)
