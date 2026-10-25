"""Native comparison of retained service-lid travel against the formed pan.

Both directions are diagnostics. Does not modify the source or game logic.
"""
from pathlib import Path
import argparse,json,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--out',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);source=(ROOT/args.source).resolve();out=(ROOT/args.out).resolve()
assert source.is_relative_to((ROOT/'tmp').resolve()) and out.is_relative_to((ROOT/'tmp').resolve())
out.mkdir(parents=True,exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(source))
def coords(p):return Vector((p[0],-p[2],p[1]))
def tree(objects):
    vertices=[];faces=[]
    for obj in objects:
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
    return BVHTree.FromPolygons(vertices,faces)
pan=tree([o for o in bpy.data.collections['FormedShellStudy'].objects if o.name.startswith('Stock__Continuous pressed structural pan')])
hood=bpy.data.objects['ServiceCover'];meshes=[o for o in hood.children_recursive if o.type=='MESH']
assert meshes
records=[]
for direction in [-1,1]:
    samples=[]
    for i in range(107):
        angle=direction*min(1.85,i/106*1.85);hood.rotation_euler.x=angle;bpy.context.view_layer.update()
        samples.append(dict(angle_rad=angle,intersecting_face_pairs=len(pan.overlap(tree(meshes)))))
    records.append(dict(direction=direction,samples=samples))
# Cutaway only: omit keyboard/review instances so the service lid is visible.
# The actual native keyboard and stays remain in the unmodified source file.
keyboard=bpy.data.objects['CompanionKeyboard']
for obj in keyboard.children_recursive:obj.hide_render=True
for obj in bpy.data.objects:
    if obj.name.startswith('Review flip tile'):obj.hide_render=True
scene=bpy.context.scene;scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.cycles.samples=24
camera=scene.camera;camera.data.ortho_scale=.23;camera.location=coords((.20,-.23,.34))
camera.rotation_euler=(coords((0,-.070,.030))-camera.location).to_track_quat('-Z','Y').to_euler()
for label,angle in [('closed',0.0),('existing_negative',-1.85),('outward_positive',1.85)]:
    hood.rotation_euler.x=angle;bpy.context.view_layer.update();scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
(out/'travel.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Native service-lid/formed-pan face-intersection diagnostic. Keyboard omitted from paired cutaway renders; no runtime change, environment sweep, input or acceptance claim.',records=records),indent=2)+'\n',newline='\n')
print('HOOD TRAVEL DIAGNOSTIC',[(r['direction'],sum(s['intersecting_face_pairs']>0 for s in r['samples'])) for r in records])
