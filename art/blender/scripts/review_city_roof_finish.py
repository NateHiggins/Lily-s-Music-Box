"""Read-only native comparison of the existing eleven galvanized city groups."""
import hashlib,json,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
OUT=ROOT/'tmp/v2-city-roof-finish/native';OUT.mkdir(parents=True,exist_ok=True)
paths=['art/blender/city_closure.blend','game/assets/props/city_shells.glb']
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
bound={p:sha(p) for p in paths}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/paths[0]));scene=bpy.context.scene
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
profile=json.loads((ROOT/'game/data/orison_v2/owner_finish_profiles.json').read_text())
recipe=next(r for g in profile['groups'] if g['id']=='roof' for r in g['recipes'] if r['source_key']=='galvanized_roof')
before=material(ROOT,'CityRoofBefore',dict(catalog_key='galvanized_roof',tint=[1,1,1,1],pigment=1,normal=.35,roughness=catalog['galvanized_roof']['roughness_multiplier']),catalog)
after=material(ROOT,'CityRoofAfter',dict(catalog_key=recipe['catalog'],tint=recipe['color'],pigment=recipe['pigment'],normal=recipe['normal'],roughness=recipe['roughness'],metallic=recipe['metallic']),catalog)
stocks=list(bpy.data.collections['ClosedConstruction'].objects)+list(bpy.data.collections['ClosedParapets'].objects)
for o in stocks:
    bm=bmesh.new();bm.from_mesh(o.data);assert bm.calc_volume(signed=True)>0 and all(e.is_manifold for e in bm.edges),o.name;bm.free()
draws=[o for o in scene.objects if o.type=='MESH' and o.name.endswith('__galvanized_roof') and not o.hide_render]
assert len(draws)==11,len(draws)
scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NeutralCityReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
d=bpy.data.lights.new('Sun','SUN');d.energy=2.;d.angle=.1;sun=bpy.data.objects.new(d.name,d);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.4,-.5)
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.lens=35
scene.view_layers[0].update()
for name in ['site_back_e','site_sw2']:
    o=next(o for o in draws if o.name==name+'__galvanized_roof')
    ps=[o.matrix_world@Vector(v) for v in o.bound_box]
    corner=Vector((max(p.x for p in ps),min(p.y for p in ps),max(p.z for p in ps)))
    target=corner+Vector((-.4,.4,-.5));cam.location=corner+Vector((4,-4,3));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    for label,mat in [('before',before),('after',after)]:
        for draw in draws:draw.data.materials.clear();draw.data.materials.append(mat)
        scene.render.filepath=str(OUT/(name+'_'+label+'.png'));bpy.ops.render.render(write_still=True)
assert bound=={p:sha(p) for p in paths}
(OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','native_and_export_unchanged':bound,'positive_closed_stocks':len(stocks),'galvanized_groups':len(draws),'profile_sha256':sha('game/data/orison_v2/owner_finish_profiles.json'),'scope':'Neutral native roof-corner finish comparison; no geometry rebuild or new material key. Godot composition remains a separate review.'},indent=2)+'\n',encoding='utf-8',newline='\n')
