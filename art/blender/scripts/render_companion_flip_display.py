"""Native optical review of real tile rotations, not a gameplay capture."""
from pathlib import Path
import argparse,json,math,sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--out',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=(ROOT/a.out).resolve()
assert out.is_relative_to((ROOT/'tmp').resolve());out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_companion_v2.blend'))
for image in bpy.data.images:
    if image.source=='FILE':assert Path(bpy.path.abspath(image.filepath)).is_file(),('native texture missing',image.name,image.filepath)
data=json.loads((ROOT/'game/data/device/service_companion_v2.json').read_text())['flip_display']
tiles=[]
for obj in bpy.data.objects:
    if not obj.name.startswith('Review flip tile'):continue
    point=obj.matrix_world.translation
    column=round((point.x-data['center'][0])/data['pitch']+15.5)
    row=round((data['center'][1]-point.z)/data['pitch']+5.5)
    assert 0<=row<12 and 0<=column<32,(obj.name,row,column)
    tiles.append((obj,row,column))
assert len(tiles)==768,len(tiles)
scene=bpy.context.scene;scene.render.resolution_x=1100;scene.render.resolution_y=500
scene.render.resolution_percentage=100;scene.cycles.samples=24
camera=scene.camera;camera.data.ortho_scale=.220
def coords(v):return Vector((v[0],-v[2],v[1]))
target=coords((0,-.057,.123));camera.location=coords((.035,-.035,.45))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
def bit(row,column,pose):
    if column in [10,11,20,21] and row in [3,4]:return True
    if pose=='open':
        ellipse=((column-15.5)/5.5)**2+((row-8.5)/2.0)**2
        return .45<=ellipse<=1.3
    if pose=='umbrella':
        return (row==2 and 12<=column<=19) or (row==3 and 10<=column<=21) or (row==4 and 8<=column<=23) or (row==5 and 6<=column<=25) or (column==15 and 5<=row<=10) or (row==10 and column in [16,17])
    return (row==8 and column in [9,22]) or (row==9 and column in [10,11,20,21]) or (row==10 and 12<=column<=19)
for name,pose,blend in [('smile','smile',0),('opening','open',.5),('open','open',1),('closing','smile',.5),('smile_return','smile',1),('umbrella','umbrella',1)]:
    for obj,row,column in tiles:
        previous=bit(row,column,'open' if name=='closing' else 'smile')
        desired=bit(row,column,pose)
        first=0.0 if previous else math.pi;last=0.0 if desired else math.pi
        obj.rotation_euler.z=first+(last-first)*blend
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Native review of 32x12 physical square tiles; not a Godot capture or gameplay proof','tile_instances':len(tiles)//2,'views':['smile','opening','open','closing','smile_return','umbrella']},indent=2)+'\n',newline='\n')
