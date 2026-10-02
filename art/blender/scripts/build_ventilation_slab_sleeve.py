"""Editable 200 mm slab lining with thin square escutcheons; metres, Y up."""
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
material=bpy.data.materials.new('metal')
material.diffuse_color=(.32,.31,.28,1)
parts=[]

def box(name,at,size):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(material)
    bevel=obj.modifiers.new('Worked arris','BEVEL')
    bevel.width=.0003
    bevel.segments=1
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for layer in list(obj.data.uv_layers):obj.data.uv_layers.remove(layer)
    uv=obj.data.uv_layers.new(name='Metres')
    uv.active_render=True
    for face in obj.data.polygons:
        normal=face.normal.normalized()
        seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))
        u=normal.cross(seed).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p.dot(u),p.dot(v))
    parts.append(obj)

def ring(name,y,height,outer,inner):
    width=(outer-inner)/2
    for side in [-1,1]:
        box(name+'X'+str(side),(side*(outer+inner)/4,y,0),(width,height,outer))
        box(name+'Z'+str(side),(0,y,side*(outer+inner)/4),(inner,height,width))

ring('Lining',-.10,.202,.200,.196)
ring('UpperEscutcheon',.002,.004,.224,.196)
ring('LowerEscutcheon',-.202,.004,.224,.196)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ventilation_slab_sleeve.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
obj=bpy.context.object
obj.name='SlabSleeve'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':
            data['data'][:,3]*=-1
            type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/ventilation_slab_sleeve.glb'),
    export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
assert ExportUVHandedness.partitions==1
print('VENTILATION SLAB SLEEVE: one shared mesh; 196 mm clear bore; 200 mm lining; 224 mm flanges')
