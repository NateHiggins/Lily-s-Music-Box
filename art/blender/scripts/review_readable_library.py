"""Native construction views before engine input/readability qualification."""
from pathlib import Path
import json,math
import bpy
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-readable-books-20261020/native'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/readable_library.blend'))
data=json.loads((ROOT/'game/data/orison_v2/readable_library.json').read_text())
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=40
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral library review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.56,.63,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
original={name:bpy.data.objects[name] for name in data['parts']}
for obj in original.values():obj.hide_render=True
copies=[]
def b(point):return Vector((point[0],-point[2],point[1]))
def copy(name,pose=Matrix.Identity(4)):
    obj=original[name].copy();scene.collection.objects.link(obj);obj.hide_render=False;obj.matrix_world=pose@original[name].matrix_world;copies.append(obj);return obj
def clear():
    for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
    copies.clear()
for at,power,size in [((1.4,-1.7,2.3),160,1.5),((-1.5,.5,1.8),80,1.2)]:
    bpy.ops.object.light_add(type='AREA',location=at);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(-o.location+Vector((0,0,.65))).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.0001));ground=bpy.context.object
m=bpy.data.materials.new('Review ground');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.22,.24,.25,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;ground.data.materials.append(m)
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.lens=50;scene.camera=camera
def capture(label,eye,point):
    camera.location=eye;camera.rotation_euler=(Vector(point)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
ids=['prospectus','minutes','wiring','atlas','sorting','glass','onefinger','letters','deadletter']
for style in ['plain','repaired','sectional']:
    clear();case=data['cases'][style]
    for name in case['parts']:copy(name)
    for index,door in enumerate(case['doors']):
        pivot=b(door['pivot']);angle=0. if index==0 else math.pi*.5;inset=.30 if index==2 else 0.
        for name in door['parts']:
            pose=Matrix.Translation(b((0,0,-inset)))
            if data['parts'][name]['role']!='carriage':pose=pose@Matrix.Translation(pivot)@Matrix.Rotation(-angle,4,'X')@Matrix.Translation(-pivot)
            copy(name,pose)
    cursor=-.13;top=case['shelf_tops'][1]
    for identity in ids:
        record=data['books'][identity];thick=record['thickness']
        pose=Matrix.Translation(b((cursor+thick*.5,top+.003,case['depth']*.5-.04)))@Matrix.Rotation(math.pi*.5,4,'Z')
        for name in record['parts']:copy(name,pose)
        cursor+=thick+.004
    endstyle='brass' if style=='sectional' else 'pressed'
    for side,x in enumerate([-.133,cursor-.002]):
        pose=Matrix.Translation(b((x,top+.0012,case['depth']*.5-.095)))@Matrix.Rotation(math.pi if side else 0,4,'Z')
        for name in data['bookends'][endstyle]['parts']:copy(name,pose)
    capture(style+'_case',Vector((1.55,-2.25,1.55)),(0,0,case['height']*.5))
clear()
record=data['books']['wiring']
for name in record['parts']:
    copy(name,Matrix.Rotation(-math.pi,4,'Z') if data['parts'][name]['role']=='left' else Matrix.Identity(4))
plate=data['illustrations']['circuit_wiring'];copy(plate['part'],Matrix.Translation(b((record['width']*.5,record['height']*.55,record['right_page_z']+.00004))))
capture('open_binding_and_plate',Vector((.10,-.57,.27)),(0,0,record['height']*.5))
clear()
for name in data['bookends']['pressed']['parts']:copy(name)
capture('pressed_bookend',Vector((.23,-.25,.20)),(.02,0,.06))
(OUT/'scope.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Native forms/finishes only; lettering, input, contacts and save reconstruction require the Godot bench.',source='art/blender/readable_library.blend'),indent=2)+'\n',encoding='utf8',newline='\n')
