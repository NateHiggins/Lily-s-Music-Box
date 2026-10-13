"""Neutral native facade review against regenerated full occupied shell."""
from pathlib import Path
import bpy,sys,json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/front_restoration_details.blend'))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
brick=material(ROOT,'Retained brick',dict(catalog_key='brick',tint=[.78,.72,.66,1],pigment=1.,normal=.35,roughness=1.),catalog)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/exterior_masonry.glb'))
for obj in bpy.context.selected_objects:
 if obj.type=='MESH':obj.data.materials.clear();obj.data.materials.append(brick)
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Review daylight');scene.world.color=(.4,.4,.4)
bpy.ops.object.light_add(type='AREA',location=(-10,20,25));bpy.context.object.data.energy=6000;bpy.context.object.data.size=15
bpy.ops.object.camera_add(location=(10,49,12));camera=bpy.context.object
camera.rotation_euler=(Vector((1,12,9))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=35;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1500;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'tmp/v2-front-restoration-20261013/native.png');bpy.ops.render.render(write_still=True)
