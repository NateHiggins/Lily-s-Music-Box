"""Native review against the retained masonry mass before installed capture."""
from pathlib import Path
import bpy,sys,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/fire_repairs.blend'))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
brick=material(ROOT,'Existing brick',dict(catalog_key='brick',tint=[.78,.72,.66,1],pigment=1.,normal=.65,roughness=1.),catalog)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/exterior_masonry.glb'))
for obj in bpy.context.selected_objects:
 if obj.type=='MESH':obj.data.materials.clear();obj.data.materials.append(brick)
bpy.ops.object.light_add(type='AREA',location=(-12,16,22));bpy.context.object.data.energy=4500;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=12
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Review daylight');scene.world.color=(.35,.35,.35)
bpy.ops.object.camera_add(location=(-19,27,12));camera=bpy.context.object
camera.rotation_euler=(Vector((-8,12.35,7))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=38;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
out=ROOT/'tmp/v2-renovation-20261013/native.png';scene.render.filepath=str(out);bpy.ops.render.render(write_still=True)
