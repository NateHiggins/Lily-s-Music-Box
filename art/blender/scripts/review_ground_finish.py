"""Read-only asphalt comparison over the saved fitted terrain/foundations."""
import hashlib,json,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
OUT=ROOT/'tmp/v2-ground-finish/native';OUT.mkdir(parents=True,exist_ok=True)
paths=['art/blender/orison_ground.blend','art/blender/city_foundations.blend','game/assets/props/orison_ground.glb','game/assets/props/city_foundations.glb']
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
bound={p:sha(p) for p in paths}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/paths[0]));scene=bpy.context.scene
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
recipe=json.loads((ROOT/'game/data/orison_v2/ground_finish.json').read_text())
original=dict(catalog_key='asphalt',tint=[1,1,1,1],pigment=1,normal=.35,roughness=1)
before=material(ROOT,'AsphaltBefore',original,catalog)
after=material(ROOT,'AsphaltAfter',dict(original,**recipe),catalog)
soil=material(ROOT,'Soil',dict(original,catalog_key='soil'),catalog)
draws=[o for o in scene.objects if o.type=='MESH' and not any(c.hide_render for c in o.users_collection)]
asphalt=[o for o in draws if 'asphalt' in o.name]
for o in draws:
    o.data.materials.clear();o.data.materials.append(before if o in asphalt else soil)
fixture=json.loads((ROOT/'game/tests/fixtures/orison_city_foundations_construction.json').read_text())
names={r['id'] for r in fixture['parts']}
with bpy.data.libraries.load(str(ROOT/paths[1]),link=False) as (a,b):b.objects=[n for n in a.objects if n in names]
assert len(b.objects)==len(names)
concrete=material(ROOT,'FoundationConcrete',dict(original,catalog_key='concrete'),catalog)
for o in b.objects:scene.collection.objects.link(o);o.data.materials.clear();o.data.materials.append(concrete)
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('GroundReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
d=bpy.data.lights.new('Sun','SUN');d.energy=2;d.angle=.1;sun=bpy.data.objects.new(d.name,d);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.4,-.5)
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.lens=28
for name,at,target in [('west_city_bedding',(-25,-10.5,1.524),(-26,-9.645,0)),('courtyard_city_plinth',(20.5,-11.6,1.524),(19.7,-10.15,0))]:
    cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    for label,mat in [('before',before),('after',after)]:
        for o in asphalt:o.data.materials.clear();o.data.materials.append(mat)
        scene.render.filepath=str(OUT/(name+'_'+label+'.png'));bpy.ops.render.render(write_still=True)
assert bound=={p:sha(p) for p in paths}
(OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','unchanged_native_and_exports':bound,'asphalt_parts':len(asphalt),'ground_parts':len(draws),'foundation_parts':len(names),'recipe_sha256':sha('game/data/orison_v2/ground_finish.json'),'scope':'Read-only surface review with fitted ground/foundation context. Superstructure and lights are supplied by the separate production capture. No geometry rebuild.'},indent=2)+'\n',encoding='utf-8',newline='\n')
