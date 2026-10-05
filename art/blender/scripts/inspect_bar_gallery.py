"""Read the saved native, prove seated stocks, and render matched original/delivery views."""
from pathlib import Path
import hashlib, json, os
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_GALLERY_INSPECT_OUT',str(ROOT/'tmp/bar-gallery/native')));OUT.mkdir(parents=True,exist_ok=True)
report=json.loads((ROOT/'art/blender/bar_gallery_inventory.json').read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bar_gallery.blend'))
for row in report['stocks']:
    obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,row['name']
    assert abs(bm.calc_volume(signed=True)-row['volume_m3'])<1e-8,row['name'];bm.free()
wood=bpy.data.objects['Gallery__wood_dark'];native_tree=BVHTree.FromObject(wood,bpy.context.evaluated_depsgraph_get())
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=[o for o in bpy.context.scene.objects if o not in before]
wall=next(o for o in context if o.type=='MESH' and o.name.removesuffix('-col')=='F01_OWN_SHOP_BAR_retail_bar_bar_wall')
wall_tree=BVHTree.FromObject(wall,bpy.context.evaluated_depsgraph_get())
samples=0
for row in report['contacts']:
    at=Vector(row['bearing']);n=Vector(row['normal']);front=Vector(row['frame_back']);u=Vector((1,0,0)) if abs(n.y)>.9 else Vector((0,1,0))
    for du in [-.009,0.,.009]:
        for dz in [-.009,0.,.009]:
            offset=u*du+Vector((0,0,dz))
            for tree,point,direction,distance in [(wall_tree,at+n*.004+offset,-n,.004),(native_tree,at-n*.002+offset,n,.002)]:
                hit,normal,index,d=tree.ray_cast(point,direction,.008)
                assert hit is not None and abs(d-distance)<.00003,(row['picture'],point,hit,d);samples+=1
            # At the joining plane, both the closed packer front and frame back exist.
            hit,normal,index,d=native_tree.ray_cast(front+n*.002+offset,-n,.008)
            assert hit is not None and abs(d-.002)<.00003,(row['picture'],'frame back',d);samples+=1
old=[o for o in context if o.type=='MESH' and any(o.name.removesuffix('-col').endswith('furniture_'+k) for k in ['art','wood_dark'])]
assert len(old)==2
new=[bpy.data.objects['Gallery__'+key] for key in ['art','wood_dark','paper','iron_blackened']]
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('GalleryReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.22,.22,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
light=bpy.data.lights.new('ReviewOnlySun','SUN');light.energy=2.;lamp=bpy.data.objects.new('ReviewOnlySun',light);scene.collection.objects.link(lamp);lamp.rotation_euler=(.5,-.4,.2)
camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=28;camera_data.clip_start=.01
renders=[]
contact=report['contacts'][0];bearing=Vector(contact['bearing']);normal=Vector(contact['normal']);tangent=Vector((1,0,0)) if abs(normal.y)>.9 else Vector((0,1,0))
gap=float(contact['gap_m']);target=bearing+normal*gap*.5
views=[('west_frames',(-9.9,-35.3,-1.18),(-11.445,-35.2,-.95)),('west_score',(-9.6,-31.2,-1.18),(-11.445,-31.2,-.8)),('north_gallery',(-8.7,-31.25,-1.18),(-8.7,-28.755,-.95)),('backing_contact',tuple(target-tangent*.12),tuple(target))]
for name,at,target in views:
    camera_data.clip_start=.0003 if name=='backing_contact' else .01
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    for mode in ['original','installed']:
        for o in old:o.hide_render=mode=='installed'
        for o in new:o.hide_render=mode=='original'
        scene.render.filepath=str(OUT/(name+'_'+mode+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'_'+mode+'.png')
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(report['stocks']),'contact_samples':samples,'renders':renders,'native_sha256':hashlib.sha256((ROOT/'art/blender/bar_gallery.blend').read_bytes()).hexdigest(),'note':'Saved native with unchanged imported context; review lights are Blender-only, production uses original fixtures.'},indent=2)+'\n')
print('NATIVE BAR GALLERY:',len(report['stocks']),'closed stocks;',samples,'wall/packer/backing samples;',len(renders),'matched renders')
