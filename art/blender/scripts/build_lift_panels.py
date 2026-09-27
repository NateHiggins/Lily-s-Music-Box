"""V2 sliding lift leaves; metres, Godot +Z front. Runtime owns motion.
Run: blender -b -P art/blender/scripts/build_lift_panels.py
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('steel'); mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF']
s.inputs['Base Color'].default_value=(.30,.36,.33,1)
s.inputs['Metallic'].default_value=.55; s.inputs['Roughness'].default_value=.45
def p(v): return Vector((v[0],-v[2],v[1]))
def box(name,at,size,radius=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at))
    o=bpy.context.object; o.name=name; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if radius:
        m=o.modifiers.new('Rolled edge','BEVEL'); m.width=radius; m.segments=3
        bpy.ops.object.modifier_apply(modifier=m.name)
    return o
def cut(o,cutter):
    bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Pressed recess or through aperture','BOOLEAN')
    m.operation='DIFFERENCE'; m.object=cutter
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
groups=[]
for name,x in [('PanelWest',.14),('PanelEast',-.14)]:
    # Existing body centers are +/-240 mm. A 478 mm visual leaf leaves a
    # 2 mm meeting seam, instead of overlapping 20 mm of coplanar steel.
    leaf=box(name,(0,0,0),(.478,2.06,.045),.001)
    cut(leaf,box('VisionAperture',(x,.32,0),(.11,.32,.08),.004))
    parts=[leaf]
    for side in [-1,1]:
        for y,h in [(-.35,.64),(.77,.28)]:
            cut(leaf,box('PressedField',(0,y,side*.024),(.37,h,.008),.002))
        bezel=box('GlazingBezel',(x,.32,side*.024),(.132,.342,.006),.001)
        cut(bezel,box('ClearGlazingBore',(x,.32,side*.024),(.108,.318,.02),.003))
        parts.append(bezel)
    groups.append((name,parts))
kick=box('KickPlate',(0,0,0),(.478,.16,.05),.001)
for side in [-1,1]:
    for y in [-.05,.05]:
        cut(kick,box('KickQuirk',(0,y,side*.025),(.42,.002,.002),.0004))
groups.append(('KickPlate',[kick]))
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons: face.use_smooth=True
    m=o.modifiers.new('Weighted manufactured normals','WEIGHTED_NORMAL'); m.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_panels.blend'))
for name,parts in groups:
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1: bpy.ops.object.join()
    bpy.context.object.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_panels.glb'),
    export_format='GLB',export_yup=True,export_apply=True)
