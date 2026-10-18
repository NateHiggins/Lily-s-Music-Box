"""Offline repeated-surface optical controls; does not publish game materials."""
from pathlib import Path
import argparse,hashlib,json,sys
import bpy
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work-dir',type=Path,required=True);args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.work_dir.resolve();out.mkdir(parents=True,exist_ok=True)
source=ROOT/'art/reviews/v2_panel_oak_20261018/material01'
candidate=json.loads((source/'material_candidate.json').read_text())
for name,value in candidate['map_sha256'].items():
    if hashlib.sha256((source/name).read_bytes()).hexdigest()!=value:raise ValueError('Candidate map changed: '+name)
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;bpy.context.preferences.filepaths.save_version=0
mesh=bpy.data.meshes.new('ThreeByThreeMaterialTiles');mesh.from_pydata([(-.9,0,0),(.9,0,0),(.9,0,1.8),(-.9,0,1.8)],[],[(0,1,2,3)]);mesh.update();uv=mesh.uv_layers.new(name='Metres')
for loop in mesh.loops:
    v=mesh.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(v.x+.9,v.z)
board=bpy.data.objects.new('OpticalMaterialSpecimen',mesh);scene.collection.objects.link(board)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
old=catalog['wood_dark'];textures=ROOT/'game/assets/building/textures'
def material(name,paths,tile,normal_gain,roughness_gain,albedo_only=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();links=m.node_tree.links
    output=n.new('ShaderNodeOutputMaterial');surface=n.new('ShaderNodeEmission' if albedo_only else 'ShaderNodeBsdfPrincipled');links.new(surface.outputs[0],output.inputs[0])
    texcoord=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/tile;links.new(texcoord.outputs['UV'],scale.inputs[0])
    for index,path in enumerate(paths[:1] if albedo_only else paths):
        image=bpy.data.images.load(str(path),check_existing=False)
        if index:image.colorspace_settings.name='Non-Color'
        texture=n.new('ShaderNodeTexImage');texture.image=image;texture.extension='REPEAT';links.new(scale.outputs[0],texture.inputs[0])
        if index==0:links.new(texture.outputs['Color'],surface.inputs['Color' if albedo_only else 'Base Color'])
        elif index==1:
            gain=n.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=roughness_gain;links.new(texture.outputs['Color'],gain.inputs[0]);links.new(gain.outputs[0],surface.inputs['Roughness'])
        else:
            normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=normal_gain;links.new(texture.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],surface.inputs['Normal'])
    return m
before=[textures/old['files'][i] for i in range(3)];after=[source/'albedo_source.png',source/'roughness.png',source/'normal.png']
mats={}
for state,paths,tile,ng,rg in [('before',before,float(old['meters_per_tile']),.12,.65),('after',after,.6,1.,1.)]:
    for mode in ['albedo','lit']:mats[(state,mode)]=material(state+'_'+mode,paths,tile,ng,rg,mode=='albedo')
world=bpy.data.worlds.new('NeutralReview');world.use_nodes=True;scene.world=world;world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.08,.08,1);world.node_tree.nodes['Background'].inputs[1].default_value=.4
light=bpy.data.objects.new('ControlledGrazing',bpy.data.lights.new('ControlledGrazing','AREA'));scene.collection.objects.link(light);light.location=(-1.8,-.65,2.2);light.data.energy=180;light.data.shape='DISK';light.data.size=.8;light.rotation_euler=(Vector((0,0,.9))-light.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('MaterialReviewCamera',bpy.data.cameras.new('MaterialReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=1.95;camera.location=(0,-3,.9);camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
rows=[]
for mode in ['albedo','lit']:
    light.hide_render=mode=='albedo'
    for state in ['before','after']:
        board.data.materials.clear();board.data.materials.append(mats[(state,mode)]);file=mode+'_'+state+'.png';scene.render.filepath=str(out/file);bpy.ops.render.render(write_still=True)
        rows.append({'file':file,'sha256':hashlib.sha256((out/file).read_bytes()).hexdigest(),'scope':'Offline 1.8 m material specimen; not a composed-world or loaded-mipmap qualification.'})
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(out))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'panel_oak_review.blend'),relative_remap=False)
proof=dict(evidence_class='INERT',status='RENDERED_UNREVIEWED',candidate_material_sha256=hashlib.sha256((source/'material_candidate.json').read_bytes()).hexdigest(),new_repeat_m=.6,old_repeat_m=float(old['meters_per_tile']),specimen_size_m=[1.8,1.8],images=rows,pending=candidate['pending'],source_bindings_lf={relative:hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for relative in ['art/blender/arcade_fabric_candidate/review_panel_oak.py','art/blender/arcade_fabric_candidate/build_panel_oak_maps.py','game/data/runtime_material_sets.json']})
(out/'review.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf8',newline='\n');print('OAK OPTICAL CANDIDATE:',len(rows),'views; no runtime publication')
