"""Read-only profile/native PBR review before the combined Godot import."""
from pathlib import Path
import json,sys,math,hashlib
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-active-media-20261012/review';OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
profiles=json.loads((ROOT/'game/data/domestic_radios.json').read_text(encoding='utf-8'))['profiles']
data=json.loads((ROOT/'game/data/orison_v2/active_household_radios.json').read_text(encoding='utf-8'))
families={r['id']:r['parts'] for r in data['families']};speakers={r['id']:r['parts'] for r in data['speakers']}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/active_household_radios.glb'))
radios={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/active_household_projector.glb'))
projector={o.name:o for o in bpy.context.selected_objects if o.type=='MESH'}
mapped={}
def stock(key,finish='',condition='',family=''):
    token=(key,finish,condition,family)
    if token in mapped:return mapped[token]
    if key=='glassish':
        mat=bpy.data.materials.new('Registered clear glass');mat.use_nodes=True
        bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Base Color'].default_value=(.98,.98,.98,1)
        bsdf.inputs['Transmission Weight'].default_value=1;bsdf.inputs['Roughness'].default_value=.06;bsdf.inputs['IOR'].default_value=1.52
    else:
        tint=[1,1,1,1];rough=catalog[key]['roughness_multiplier']
        if key=='enamel_appliance' and family=='atwater_kent_44':tint=[.14,.15,.15,1]
        if key=='wood_dark':
            if 'mahogany' in finish:tint=[.65,.48,.40,1]
            if finish=='dark_mahogany':tint=[.48,.39,.34,1]
            if condition in ['immaculate','performance_ready','dial_polished']:rough=.34
        if key=='leather_worn':tint=[.38,.28,.21,1]
        if key=='linen':tint=[.40,.32,.23,1]
        mat=material(ROOT,key,dict(catalog_key=key,tint=tint,pigment=1,normal=.08,roughness=rough),catalog)
    mapped[token]=mat;return mat
for obj in projector.values():
    key=obj.material_slots[0].material.name.split('.')[0];obj.data.materials.clear();obj.data.materials.append(stock(key))
bpy.ops.mesh.primitive_plane_add(size=3);table=bpy.context.object
table.data.materials.append(stock('oak_quartered'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=760;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.ops.object.light_add(type='AREA',location=(.2,-1.2,1.8));light=bpy.context.object;light.data.energy=650;light.data.size=1.5
light.rotation_euler=(Vector((0,0,.15))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.lens=48
observations=[]
for profile in profiles:
    chosen=list(families[profile['family']])
    for key,rows in speakers.items():
        if key in profile['speaker']:chosen+=rows
    for obj in list(radios.values())+list(projector.values()):obj.hide_render=True
    used=[]
    for row in chosen:
        condition=profile['condition']
        if row['component']=='Back' and condition=='back_removed':continue
        if row['component']=='Cover' and condition=='alignment_open':continue
        if row['component']=='Repair' and condition!='speaker_cloth_repaired':continue
        if row['component']=='Tag' and condition not in ['inventory_numbered','provenance_tagged']:continue
        obj=radios[row['name']];obj.hide_render=False
        obj.data.materials.clear();obj.data.materials.append(stock(row['material'],profile['finish'],condition,profile['family']))
        used.append(obj)
    points=[obj.matrix_world@v.co for obj in used for v in obj.data.vertices]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    assert abs(lo.z)<.001,('unsupported receiver base',profile['unit'],lo)
    center=(lo+hi)/2
    camera.location=center+Vector((.50,1.20,.72)) if condition!='back_removed' else center+Vector((.45,-1.2,.60))
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(profile['unit']+'.png'));bpy.ops.render.render(write_still=True)
    observations.append({'unit':profile['unit'],'family':profile['family'],'condition':condition,'native_draws':len(used),'bounds_blender':[list(lo),list(hi)]})
for obj in radios.values():obj.hide_render=True
for obj in projector.values():obj.hide_render=False
for label,at in [('projector',(.70,.8,.55)),('projector_reels',(.45,-.5,.55))]:
    target=Vector((0,0,.24));camera.location=Vector(at);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','observations':observations,'scope':'Native profile/base/PBR form review only; installed supports, actual control/decoder and composed appearance require Godot.'},indent=2)+'\n',encoding='utf-8',newline='\n')
