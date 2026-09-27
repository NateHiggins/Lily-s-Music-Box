"""Five-knuckle butt hinge halves around the real door axis; mirrored face sets."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('brass_dull'); mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(.48,.35,.16,1)
s.inputs['Metallic'].default_value=.8; s.inputs['Roughness'].default_value=.42
groups={'FixedFront':[],'MovingFront':[]}
def box(name,at,size,group,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    o=bpy.context.object; o.name=name; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Leaf edge','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    groups[group].append(o); return o
def tube(name,y,height,group):
    n=48; verts=[]; faces=[]
    for r,dy in [(.008,-height/2),(.008,height/2),(.0035,height/2),(.0035,-height/2)]:
        for i in range(n):
            a=math.tau*i/n; verts.append((r*math.cos(a),-r*math.sin(a),y+dy))
    for j in range(4):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o); data.materials.append(mat); groups[group].append(o)
for group,side,ys in [('FixedFront',-1,[-.04,0,.04]),('MovingFront',1,[-.02,.02])]:
    box('HingeLeaf',(.001 if side<0 else .009,0,.027),(.002,.094,.034),group,.0004)
    for y in ys:
        tube('RolledKnuckle',y,.018,group)
        box('RolledTongue',(.001 if side<0 else .006,y,.008),(.002 if side<0 else .008,.018,.008),group)
    for y in [-.028,.028]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.0035,depth=.002,location=(.003 if side<0 else .007,-.027,y),rotation=(0,math.pi/2,0))
        screw=bpy.context.object; screw.name='SlottedScrew'; screw.data.materials.append(mat); groups[group].append(screw)
        bpy.ops.mesh.primitive_cube_add(size=1,location=(.004 if side<0 else .006,-.027,y))
        cutter=bpy.context.object; cutter.dimensions=(.0015,.005,.001)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=screw
        mod=screw.modifiers.new('Driver slot','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)
bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.0033,depth=.112)
o=bpy.context.object; o.name='FixedPin'; o.data.materials.append(mat); groups['FixedFront'].append(o)
for y in [-.056,.056]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=12,radius=1,location=(0,0,y))
    o=bpy.context.object; o.name='PinCap'; o.scale=(.009,.009,.004); o.data.materials.append(mat); groups['FixedFront'].append(o)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for group in list(groups):
    back=group.replace('Front','Back'); groups[back]=[]
    for o in groups[group]:
        clone=o.copy(); clone.data=o.data.copy(); clone.name=o.name+'Back'; bpy.context.collection.objects.link(clone)
        for vertex in clone.data.vertices: vertex.co.y *= -1
        groups[back].append(clone)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/door_butt_hinge.blend'))
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); bpy.context.object.name=name
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/door_butt_hinge.glb'),export_format='GLB',export_yup=True,export_apply=True)
