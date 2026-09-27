"""Passive ceiling grille in metres: mounting rear at Y=0, visible side -Y."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
paint=mat('trim',(.72,.69,.60),0,.48)
metal=mat('metal',(.43,.43,.40),.7,.38)
def mesh(name,verts,faces,material):
    data=bpy.data.meshes.new(name); data.from_pydata([(x,-z,y) for x,y,z in verts],[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o); data.materials.append(material)
    return o
# Four continuous rectangular rings form the flange and inward-folded lip.
profile=[(.19,.18,0),(.19,.18,-.008),(.154,.141,-.010),(.154,.141,0)]
verts=[(x*sx,y,z*sz) for x,z,y in profile for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]]
faces=[]
for j in range(4):
    for i in range(4): faces.append((j*4+i,j*4+(i+1)%4,((j+1)%4)*4+(i+1)%4,((j+1)%4)*4+i))
parts=[mesh('Flange',verts,faces,paint)]
# Bent sheet blades leave actual open slots between their projected edges.
for i in range(9):
    z=-.12+i*.03
    cross=[(-.012,-.020),(.010,-.009),(.012,-.009),(.012,-.0105),(.010,-.0105),(-.012,-.0215)]
    verts=[(x,y,z+dz) for x in [-.158,.158] for dz,y in cross]
    n=len(cross); faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    parts.append(mesh('FoldedLouver'+str(i),verts,faces,paint))
for x in [-.172,.172]:
    for z in [-.157,.157]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.006,depth=.003,location=(x,-z,-.010))
        screw=bpy.context.object; screw.name='SlottedScrew'; screw.data.materials.append(metal)
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,-.0115))
        cutter=bpy.context.object; cutter.dimensions=(.008,.0012,.002)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=screw
        mod=screw.modifiers.new('Driver slot','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/vent_register.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); bpy.context.object.name='Grille'
screws=[o for o in bpy.context.scene.objects if o.name.startswith('SlottedScrew')]
bpy.ops.object.select_all(action='DESELECT')
for o in screws: o.select_set(True)
bpy.context.view_layer.objects.active=screws[0]; bpy.ops.object.join(); bpy.context.object.name='Fasteners'
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/vent_register.glb'),export_format='GLB',export_yup=True,export_apply=True)
