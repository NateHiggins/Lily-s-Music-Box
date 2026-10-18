"""Controlled finish/planar-normal diagnosis; never writes authoring geometry."""
from pathlib import Path
import json,math,os,sys
import bpy
from mathutils import Matrix,Vector
R=Path(__file__).resolve().parents[3];O=Path(os.environ.get('CONTROL_FINISH_OUT',str(R/'tmp/v2-control-finish-20261017/final_native')));O.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent));from fabrication_normals import stock_corner_normals
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/annunciator_dispatch.blend'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
parts={o.name:o for o in bpy.data.collections['Dispatch stocks'].objects}
D=json.loads((R/'game/data/orison_v2/annunciator_dispatch.json').read_text())
metrics={}
def bias(mesh):
    front=C@Vector((0,0,1));worst=1.;area=0.;count=0;rim=set()
    for face in mesh.polygons:
        if face.normal.dot(front)<.999999:continue
        count+=1;area+=face.area
        for loop in face.loop_indices:
            worst=min(worst,mesh.corner_normals[loop].vector.dot(face.normal));rim.add(mesh.loops[loop].vertex_index)
    junction=1.
    for face in mesh.polygons:
        if face.normal.dot(front)<math.cos(math.radians(40)):continue
        for loop in face.loop_indices:
            if mesh.loops[loop].vertex_index in rim:junction=min(junction,mesh.corner_normals[loop].vector.dot(front))
    return {'front_triangles':count,'front_area_m2':area,'maximum_front_normal_bias_degrees':math.degrees(math.acos(min(1.,worst))),
        'maximum_inner_bevel_tangent_bias_degrees':math.degrees(math.acos(min(1.,junction)))}
for key in ['Apron','ButtonCap']:
    mesh=parts[key].data;metrics[key]=bias(mesh)
    assert metrics[key]['maximum_front_normal_bias_degrees']<.05,key
    assert metrics[key]['maximum_inner_bevel_tangent_bias_degrees']<.05,key
    retained=[n.vector.copy() for n in mesh.corner_normals]
    mesh.normals_split_custom_set(stock_corner_normals(mesh));negative=bias(mesh)
    assert negative['maximum_front_normal_bias_degrees']>1.,('unanchored control should expose the defect',key)
    mesh.normals_split_custom_set(retained)
    metrics[key]['unanchored_negative_control']=negative
for obj in parts.values():obj.hide_render=obj.name not in ['Apron']
for at in D['centers']:
    for key in ['ButtonCap','ButtonStem','ReturnSpring']:
        obj=parts[key].copy();obj.data=parts[key].data;obj.hide_render=False
        bpy.context.scene.collection.objects.link(obj);obj.location=C@Vector(at)+(C@Vector((0,0,-.022)) if key=='ReturnSpring' else Vector())
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Controlled neutral');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.35,.4,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
center=C@Vector((0,-.344,.055))
for at,power,size in [((.12,.15,.23),8,.14),((-.25,-.08,.1),4,.2)]:
    bpy.ops.object.light_add(type='AREA',location=center+C@Vector(at));light=bpy.context.object
    light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=center+C@Vector((.12,.12,.32)));camera=bpy.context.object
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=58;scene.camera=camera
for mode in ['mapped','normal_off','constant']:
    if mode=='normal_off':
        for mat in bpy.data.materials:
            if mat.use_nodes:
                for node in mat.node_tree.nodes:
                    if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=0.
    if mode=='constant':
        for mat in bpy.data.materials:
            if not mat.use_nodes or 'Principled BSDF' not in mat.node_tree.nodes:continue
            node=mat.node_tree.nodes['Principled BSDF']
            for name in ['Base Color','Roughness','Normal']:
                for link in list(node.inputs[name].links):mat.node_tree.links.remove(link)
            node.inputs['Base Color'].default_value=(.32,.22,.08,1) if node.inputs['Metallic'].default_value>.5 else (.025,.016,.011,1)
            node.inputs['Roughness'].default_value=.4 if node.inputs['Metallic'].default_value>.5 else .23
    scene.render.filepath=str(O/('baseline_'+mode+'.png'));bpy.ops.render.render(write_still=True)
(O/'baseline_normals.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Controlled diagnostic only; no production acceptance','metrics':metrics},indent=2)+'\n',newline='\n')
print(metrics,flush=True)
