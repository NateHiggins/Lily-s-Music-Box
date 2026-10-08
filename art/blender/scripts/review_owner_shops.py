"""Render scoped shop finishes on unchanged native metre geometry for review.

This is optical inspection, not a substitute for native construction validators.
"""
from pathlib import Path
import hashlib,json,sys
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from owner_finish_materials import apply_current
out=ROOT/'tmp/v2-improvement/shop-native';out.mkdir(parents=True,exist_ok=True)
families=['pawn_display','pawn_fittings','pawn_clocks','hardware_tools','hardware_stock',
 'locksmith_fittings','cobbler_fittings','druggist_carboys','druggist_fountain','druggist_mortar',
 'diner_apparatus','diner_counter','diner_urns','photo_cameras','photo_stock','radio_wire',
 'radio_battery','laundry_trade','laundry_apparatus','laundry_fittings','funeral_drapes','funeral_foliage']
reviews=[]
for family in families:
    if family not in ['pawn_display','hardware_tools','hardware_stock','locksmith_fittings','cobbler_fittings','photo_cameras','druggist_carboys','laundry_fittings']:continue
    asset=ROOT/'art/blender'/f'{family}.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
    changed=apply_current('shop')
    fixture=json.loads((ROOT/'game/tests/fixtures'/f'orison_{family}.json').read_text())
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=1000;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.49,.55,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    for o in list(scene.objects):
        if o.type in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
    draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
    assert draws,family
    groups=[a['id'] for a in fixture['assemblies']]
    # Two existing identities per family, each framed independently at useful scale.
    kinds={'pawn_display':['case','window'],'hardware_tools':['tool_board','glass_rack'],
      'hardware_stock':['brass_stock','nail_stock'],'locksmith_fittings':['key_cutter','key_board'],
      'cobbler_fittings':['finisher','patcher'],'photo_cameras':['camera0','camera2'],
      'druggist_carboys':['carboy'],'laundry_fittings':['parcel','shirt']}
    selected=[]
    for kind in kinds.get(family,[]):
        match=next((a['id'] for a in fixture['assemblies'] if a.get('kind')==kind),None)
        if match:selected.append(match)
    chosen=selected or list(dict.fromkeys([groups[0],groups[-1]]))
    for index,identity in enumerate(chosen):
        visible=[o for o in draws if o.name.startswith(identity+'__')]
        assert visible,(family,identity)
        for o in draws:o.hide_render=o not in visible
        corners=[o.matrix_world@Vector(v) for o in visible for v in o.bound_box]
        low=Vector([min(v[i] for v in corners) for i in range(3)])
        high=Vector([max(v[i] for v in corners) for i in range(3)])
        center=(low+high)*.5;span=max(high-low)
        direction=Vector((-1.4,-1.9,1.1)).normalized()
        bpy.ops.object.camera_add(location=center+direction*max(span*2,.45));cam=bpy.context.object
        cam.data.lens=48;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
        for attempt in range(80):
            bpy.context.view_layer.update();projected=[world_to_camera_view(scene,cam,v) for v in corners]
            if all(.08<v.x<.92 and .08<v.y<.92 and v.z>0 for v in projected):break
            cam.location=center+(cam.location-center)*1.07
        else:raise AssertionError(('unframed',family,identity))
        lights=[]
        for offset,power,size in [(Vector((-1,-1,2)),180,1.5),(Vector((1,1,1)),100,1.)]:
            bpy.ops.object.light_add(type='AREA',location=center+offset*max(span,.5));light=bpy.context.object
            light.data.energy=power*max(span,.5)**2;light.data.shape='DISK';light.data.size=size*max(span,.5)
            light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler();lights.append(light)
        filename=f'{family}_{index}.png';scene.render.filepath=str(out/filename);bpy.ops.render.render(write_still=True)
        reviews.append(dict(family=family,identity=identity,file=filename,changed_materials=changed,
            native_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),eye=list(cam.location),target=list(center)))
        for o in lights+[cam]:bpy.data.objects.remove(o,do_unlink=True)
(out/'selected-review.json').write_text(json.dumps(dict(evidence_class='INERT',views=reviews,
    profile_sha256=hashlib.sha256((ROOT/'game/data/orison_v2/owner_finish_profiles.json').read_bytes()).hexdigest()),indent=2)+'\n',newline='\n')
