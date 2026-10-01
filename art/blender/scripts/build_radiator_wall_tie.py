"""Slotted period wall plate for the six surveyed floating radiator ties."""
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}
for key, color in {'cast_iron': (.19,.18,.16), 'metal': (.32,.31,.28),
                   'enamel': (.65,.60,.49)}.items():
    mat = bpy.data.materials.new(key)
    mat.diffuse_color = (*color,1)
    materials[key] = mat

def point(x,y,z):
    return (x,-z,y)

def frame(name, width, height, hole_width, hole_height, front, rear):
    outer = [(-width/2,-height/2),(width/2,-height/2),
             (width/2,height/2),(-width/2,height/2)]
    inner = [(-hole_width/2,-hole_height/2),(hole_width/2,-hole_height/2),
             (hole_width/2,hole_height/2),(-hole_width/2,hole_height/2)]
    verts = [point(x,y,z) for z in [front,rear] for x,y in outer+inner]
    faces = []
    for i in range(4):
        j=(i+1)%4
        faces += [(i,j,j+4,i+4),(i+8,i+12,j+12,j+8),
                  (i,i+8,j+8,j),(i+4,j+4,j+12,i+12)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(materials['cast_iron'])
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bevel=obj.modifiers.new('Filed flange edges','BEVEL')
    bevel.width=.0004
    bevel.segments=1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)

# A real slot admits the small lateral/vertical movement of pitch service.
# The rod continues through it into the existing wall, without moving the plate.
frame('PressedWallFlange',.085,.12,.046,.052,-.006,0)
frame('SlottedTieBoss',.057,.064,.046,.052,-.021,-.006)
for index, y in enumerate([-.045,.045]):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.004,depth=.038,
        location=point(0,y,.013),rotation=(1.5707963267948966,0,0))
    stud=bpy.context.object
    stud.name='EmbeddedAnchorStud'
    stud.data.materials.append(materials['metal'])
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.012,depth=.002,
        location=point(0,y,-.007),rotation=(1.5707963267948966,0,0))
    washer=bpy.context.object
    washer.name='AnchorWasher'
    washer.data.materials.append(materials['metal'])
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.009,depth=.007,
        location=point(0,y,-.0115),rotation=(1.5707963267948966,0,0))
    bolt=bpy.context.object
    bolt.name='BareAnchor' if index==0 else 'PaintedAnchor'
    bolt.data.materials.append(materials['metal' if index==0 else 'enamel'])

for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    uv=obj.data.uv_layers.new(name='Metres')
    uv.active_render=True
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        axes=((1,2),(0,2),(0,1))[axis]
        for loop in face.loop_indices:
            at=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(at[axes[0]],at[axes[1]])
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/radiator_wall_tie.blend'))
for key, material in materials.items():
    parts=[obj for obj in bpy.context.scene.objects
           if obj.type=='MESH' and obj.data.materials[0]==material]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1: bpy.ops.object.join()
    bpy.context.object.name=key
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/radiator_wall_tie.glb'),
    export_format='GLB',export_yup=True,export_tangents=True)
print('RADIATOR WALL TIE: 85 x 120 mm flange / real 46 x 52 mm slot / 3 mapped partitions')
