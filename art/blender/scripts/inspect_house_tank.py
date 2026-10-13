"""Native tank and retained-owner service assembly review; no asset mutation."""
from pathlib import Path
import bpy,bmesh,json,sys,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
out=R/'tmp/v2-tower-20261013/native-review';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/house_tank.blend'))
cap=bpy.data.objects['ConicalCap'];bm=bmesh.new();bm.from_mesh(cap.data)
assert all(e.is_manifold for e in bm.edges)
tree=BVHTree.FromBMesh(bm)
for r in [.6,1.12]:
    hit,normal,_,_=tree.ray_cast(Vector((r,0,3.85)),Vector((0,0,1)),1)
    assert hit is not None and normal.z<-.3,(r,hit,normal)
bm.free()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'game/assets/props/house_tank.glb'))
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials']
mapping={'Timber':'tank_staves','Shell':'enamel','Iron':'iron_blackened','Structure':'iron_blackened','Fasteners':'iron_neutral'}
materials={}
triangles=0
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    key=mapping[obj.name]
    if key not in materials:materials[key]=material(R,key,dict(catalog_key=key,tint=[1,1,1,1],pigment=1,normal=.06 if key=='enamel' else .08,roughness=catalog[key]['roughness_multiplier']),catalog)
    obj.data.materials.clear();obj.data.materials.append(materials[key])
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops]
        if tri.area>1e-12:assert abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))>1e-12,(obj.name,tri.index)
        triangles+=1
# The native source contains each service mesh in its original animated pose.
with bpy.data.libraries.load(str(R/'art/blender/service_instruments.blend'),link=False) as (source,target):
    target.collections=['Composed review']
collection=target.collections[0];bpy.context.scene.collection.children.link(collection)
for obj in list(collection.objects):
    if obj.get('actor')!='M02':bpy.data.objects.remove(obj,do_unlink=True);continue
    obj.location+=Vector((-1,-1.15,1.30));obj.hide_render=False
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral construction light');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.36,.48,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for at,power,size in [((1,-4,7),1400,5),((-4,-1,4),800,4)]:
    bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=size
    lamp.rotation_euler=(Vector((0,0,2.4))-lamp.location).to_track_quat('-Z','Y').to_euler()
for name,eye,at in [('tower_with_service',(5,-7,4.5),(-.25,0,2.3)),('lid_underside',(1.7,-2.6,2.4),(0,0,3.9)),('service_detail',(-2.4,-3.4,2.4),(-1,-1.15,2.25))]:
    bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(at)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=48;scene.camera=camera
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','tank_triangles':triangles,'cap_manifold':True,'cap_underside_rays':2,'noncollapsed_native_uvs':True,'scope':'Native geometry and neutral material review. Separate production route and loaded-map checks required.'},indent=2)+'\n')
