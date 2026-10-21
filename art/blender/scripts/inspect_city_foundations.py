"""Reopen every closed city footing; render immutable native construction."""
from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/roof-drainage-review/city-foundations-native';OUT.mkdir(parents=True,exist_ok=True)
native=ROOT/'art/blender/city_foundations.blend';asset=ROOT/'game/assets/props/city_foundations.glb'
meta=json.loads((ROOT/'art/blender/city_foundations_construction.json').read_text())
assert hashlib.sha256(asset.read_bytes()).hexdigest()==meta['source_native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native));records=[]
expected={r['owner']:r for r in meta['closed_volumes']}
for obj in bpy.data.collections['CityFoundationConstruction'].objects:
    if obj.type!='MESH':continue
    owner=obj.name.removesuffix('_ClosedUnion');assert owner in expected
    bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True)
    assert all(e.is_manifold for e in bm.edges) and volume>0,obj.name
    assert abs(volume-expected[owner]['volume_m3'])<1e-7
    assert abs(volume-expected[owner]['grid_volume_m3'])<.001
    bm.free();records.append(dict(owner=owner,volume_m3=volume,nonmanifold_edges=0))
assert {r['owner'] for r in records}==expected.keys()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
light_data=bpy.data.lights.new('InspectionSun','SUN');light_data.energy=3
light=bpy.data.objects.new('InspectionSun',light_data);scene.collection.objects.link(light);light.rotation_euler=(.4,-.5,-.6)
camera_data=bpy.data.cameras.new('InspectionCamera');camera=bpy.data.objects.new(camera_data.name,camera_data);scene.collection.objects.link(camera);scene.camera=camera
views=[('all_city_footings',(-150,145,140),(2,22,-1),'ORTHO',250),('alley_bearing',(17,15,3),(18.5,9,-1),'PERSP',35),('rear_bearing',(11,-13,2),(14,-16.5,-1.5),'PERSP',45)]
for name,at,target,kind,lens in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type=kind
    if kind=='ORTHO':camera_data.ortho_scale=lens
    else:camera_data.lens=lens
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
report=dict(evidence_class='INERT',native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),asset_sha256=meta['source_native_sha256'],closed_stocks=records,renders=[r[0]+'.png' for r in views],scope='Closed native footing geometry only; neutral material overview is not final optical, soil capacity or runtime acceptance.')
(OUT/'inspection.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('REOPENED CITY FOOTINGS:',len(records),'closed positive native unions')
