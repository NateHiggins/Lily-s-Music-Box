"""Fitted lower cab joinery and rear enamel field, in production car coordinates."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Roughness'].default_value=rough
    return m
oak=material('oak_quartered',(.42,.28,.16),.45)
enamel=material('enamel',(.88,.84,.74),.42)
def box(name,at,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    o=bpy.context.object; o.name=name; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.append(mat); return o
wood=[]; paint=[]
for side in [-1,1]:
    # Butt to the rear board's front face, avoiding doubled corner volumes.
    o=box('SideBacking',(side*.744,.58,(-1.063+1.10)*.5),(.012,.64,2.163),oak)
    wood.append(o)
    if side==1:
        # Existing cab-panel mounting stems continue to the structural wall.
        for z in [.802,.958]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0073,depth=.03,
                location=(.744,-z,.735),rotation=(0,math.pi/2,0))
            cutter=bpy.context.object; bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new('Control mounting clearance','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
            bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)
wood.append(box('RearBacking',(0,.58,-1.069),(1.5,.64,.012),oak))

def panel(name,width,center,side):
    # Continuous rectangular rings form mitered molding and a raised centre.
    # Depth is measured inward from the structural wall; the rear sits just
    # inside the backing so the applied molding has no floating outer edge.
    hw=width*.5
    rings=[(hw,.30,.0115),(hw,.30,.015),(hw-.008,.292,.019),
           (hw-.018,.282,.019),(hw-.023,.277,.026),
           (hw-.030,.270,.027),(hw-.036,.264,.021),
           (hw-.042,.258,.020)]
    verts=[]
    for x,y,depth in rings:
        for u,v in [(-x,-y),(x,-y),(x,y),(-x,y)]:
            p=(side*(.75-depth),.58+v,center+u) if side else (center+u,.58+v,-1.075+depth)
            verts.append((p[0],-p[2],p[1]))
    faces=[]
    for ring in range(len(rings)-1):
        for i in range(4): faces.append((ring*4+i,ring*4+(i+1)%4,(ring+1)*4+(i+1)%4,(ring+1)*4+i))
    faces += [tuple(reversed(range(4))),tuple(range((len(rings)-1)*4,len(rings)*4))]
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o); data.materials.append(oak)
    wood.append(o)
for side in [-1,1]:
    # A flat front stile leaves the cab controls clear of raised molding.
    for index,z in enumerate([-.73,-.11,.51]): panel('SidePanel'+str(side)+'_'+str(index),.50,z,side)
for index,x in enumerate([-.36,.36]): panel('RearPanel'+str(index),.60,x,0)
# The rear field stops at the mirror frame's outer edge instead of burying it.
for x in [-.64,.64]: paint.append(box('RearSideField',(x,1.5275,-1.066),(.22,1.055,.018),enamel))
paint.append(box('BelowMirrorField',(0,1.045,-1.066),(1.06,.09,.018),enamel))
paint.append(box('AboveMirrorField',(0,2.0025,-1.066),(1.06,.105,.018),enamel))
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_joinery.blend'))
for name,group in [('CabJoinery',wood),('RearEnamel',paint)]:
    bpy.ops.object.select_all(action='DESELECT')
    for o in group: o.select_set(True)
    bpy.context.view_layer.objects.active=group[0]; bpy.ops.object.join(); bpy.context.object.name=name
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_joinery.glb'),export_format='GLB',export_yup=True,export_apply=True)
