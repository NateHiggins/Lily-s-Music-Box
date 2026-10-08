"""Read-only native alley material comparison; never rebuild accepted geometry."""
import hashlib,json,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
OUT=ROOT/'tmp/v2-alley-finish/native';OUT.mkdir(parents=True,exist_ok=True)
paths=['art/blender/service_alley.blend','art/blender/alley_groundworks.blend',
       'game/assets/props/service_alley.glb','game/assets/props/alley_groundworks.glb']
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
bound={p:sha(p) for p in paths}
recipes=json.loads((ROOT/'game/data/orison_v2/service_alley_finish.json').read_text())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/alley_groundworks.blend'))
scene=bpy.context.scene
with bpy.data.libraries.load(str(ROOT/'art/blender/service_alley.blend'),link=False) as (a,b):
    b.objects=[n for n in a.objects if n.startswith(('BoundaryMasonry','BondedPier','StoneCoping'))]
for o in b.objects:scene.collection.objects.link(o)
scene.view_layers[0].update()
# The retained boundary uses world projection in Godot: make equivalent planar
# charts on this disposable review copy, not on either native or exported asset.
for o in b.objects:
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='ReviewProjection')
    for poly in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        axes=((1,2),(0,2),(0,1))[axis]
        for loop in poly.loop_indices:
            p=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p[axes[0]],p[axes[1]])
closed=list(bpy.data.collections['AlleyGroundworksConstruction'].objects)+list(b.objects)
for o in closed:
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
    bm.free()
old_keys={'Paving':'concrete','Iron':'cast_iron','Coping':'limestone','Brick':'brick'}
finishes={}
for before in [True,False]:
    for role,recipe in recipes.items():
        r=dict(recipe,pigment=1.)
        if before and old_keys[role] not in catalog:
            mat=bpy.data.materials.new('OriginalUnmappedCoping');mat.use_nodes=True
            node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(1,1,1,1);node.inputs['Roughness'].default_value=1.
            finishes[before,role]=mat
            continue
        if before:
            k=old_keys[role];r.update(catalog_key=k,tint=[1,1,1,1],normal=.35,roughness=catalog[k].get('roughness_multiplier',1.),metallic=catalog[k]['metallic'])
        finishes[before,role]=material(ROOT,role+str(before),r,catalog)
objects=[o for o in scene.objects if o.type=='MESH']
roles={}
for o in objects:
    if o.name.startswith('StoneCoping'):role='Coping'
    elif o.name.startswith(('BoundaryMasonry','BondedPier')):role='Brick'
    else:role='Iron' if 'cast_iron' in o.name or o.get('material_key')=='cast_iron' else 'Paving'
    roles[o]=role
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NeutralAlley');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
data=bpy.data.lights.new('ReviewSun','SUN');data.energy=2;data.angle=.10
sun=bpy.data.objects.new(data.name,data);scene.collection.objects.link(sun);sun.rotation_euler=(.6,-.3,-.5)
data=bpy.data.cameras.new('Review');cam=bpy.data.objects.new(data.name,data);scene.collection.objects.link(cam);scene.camera=cam;data.lens=28
for name,at,target in [('boundary',(16.8,-10.7,1.65),(18,-4,1.7)),('grate',(16.3,-4.5,1.2),(17.2,-3.2,0))]:
    cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    for before in [True,False]:
        for o in objects:o.data.materials.clear();o.data.materials.append(finishes[before,roles[o]])
        scene.render.filepath=str(OUT/(name+('_before' if before else '_after')+'.png'))
        bpy.ops.render.render(write_still=True)
assert bound=={p:sha(p) for p in paths}
report={'evidence_class':'INERT','unchanged_native_and_export_sha256':bound,'positive_closed_stocks':len(closed),'finish_recipes_sha256':sha('game/data/orison_v2/service_alley_finish.json'),'scope':'Read-only neutral daylight comparison. Groundworks use native metre charts; boundary review copies use world-planar charts approximating retained Godot triplanar projection. Before reproduces catalogue response and plain fallback coping, not production lighting. No geometry rebuild or runtime proof.'}
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ALLEY NATIVE REVIEW',json.dumps(report))
