"""Read-only native review; production geometry and its hashes stay unchanged."""
from pathlib import Path
import bpy,json,hashlib,os
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=ROOT/'tmp/v2-city-polish-20261018/horizon_native';OUT.mkdir(exist_ok=True,parents=True)
relief_review=os.environ.get('CITY_RELIEF_REVIEW')=='1'
if relief_review:
    OUT=Path(os.environ['CITY_REVIEW_OUTPUT']);OUT.mkdir(exist_ok=True,parents=True)
files=[ROOT/'art/blender'/name for name in ['city_horizon_near.blend','city_horizon_far.blend','city_ground_apron.blend']]
before={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());frame=json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text())
front=next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')['center'][1]
registered=Matrix.Diagonal((-1.,-1.,1.,1.));registered.translation.y=-(front+frame['source_threshold_z'])
bpy.ops.wm.read_factory_settings(use_empty=True)
for path,collection in zip(files,['CityHorizon_near','CityHorizon_far','DistantGroundApron']):
    with bpy.data.libraries.load(str(path),link=False) as (a,b):b.collections=[collection]
    loaded=b.collections[0];bpy.context.scene.collection.children.link(loaded)
    for obj in loaded.objects:
        obj.hide_render=False
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.8,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
sun=bpy.data.objects.new('ReviewSun',bpy.data.lights.new('ReviewSun','SUN'));scene.collection.objects.link(sun)
sun.data.energy=3;sun.rotation_euler=(.45,-.35,-.7)
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera
camera.data.lens=25
views=[('horizon_north',(0,0,24),(0,180,25)),('horizon_east',(0,0,24),(180,0,25)),
       ('horizon_south',(0,0,24),(0,-180,25)),('horizon_outer_grade',(140,-82,8),(110,-64,8))]
if relief_review:
    views=[('river_bank',(420,-10,10),(380,0,-4)),('canal_bank',(20,310,7),(50,360,-6)),
           ('rail_cut',(-305,-40,9),(-410,0,-3.5)),('relief_context',(480,540,240),(0,0,0))]
for label,at,target in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
after={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files};assert before==after
(OUT/'review.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Posed native review only; runtime, occupied access and human acceptance unproven',sources_unchanged=after,city_to_grade_frame=[list(r) for r in registered]),indent=2)+'\n')
