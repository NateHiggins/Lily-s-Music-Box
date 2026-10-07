"""Native fixed cabinet bearings and fitted lamp clearance in desktop space."""
from pathlib import Path
import json,math
import bpy
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/signal_terminal.blend'))
fixture=json.loads((r/'game/tests/fixtures/orison_signal_terminal.json').read_text())
def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(p,yaw):return Matrix.Translation(bp(p))@Matrix.Rotation(yaw,4,'Z')
def tree(obj,transform):return BVHTree.FromPolygons([transform@obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
terminal=pose((.075,.75,0),math.pi)
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('VantryFixed__')]
with bpy.data.libraries.load(str(r/'art/blender/work_tables.blend'),link=False) as (src,table):table.objects=[n for n in src.objects if n.startswith('4B_terminal_desk__')]
with bpy.data.libraries.load(str(r/'art/blender/task_lamps.blend'),link=False) as (src,lamps):lamps.objects=[n for n in src.objects if n.startswith('TaskLamp_landlord_enamel__')]
for obj in table.objects+lamps.objects:bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.update()
supports=[tree(o,Matrix.Identity(4)) for o in table.objects]
for contact in fixture['contacts']:
 at=terminal@bp(contact['point']);hits=[t.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008) for t in supports]
 assert any(p is not None and (p-at).length<.00003 and n.z>.9 for p,n,_,_ in hits),contact
lamp=next(a for a in json.loads((r/'game/data/orison_v2/task_lamp_installations.json').read_text())['lamps'] if a['id']=='F04_B_LAMP_01')
lamp_pose=pose(lamp['position'],lamp['yaw']);lamp_trees=[tree(o,lamp_pose) for o in lamps.objects]
for obj in draws:
 own=tree(obj,terminal)
 assert not any(own.overlap(other) for other in lamp_trees),('terminal crosses native task lamp',obj.name)
out=r/'tmp/v2-finish-review/signal-terminal-context.json';out.write_text(json.dumps({'evidence_class':'INERT','bearings':len(fixture['contacts']),'native_lamp_part_pairs':len(draws)*len(lamp_trees),'scope':'Native desktop contacts and lamp clearance; original dynamic instrument and input are verified in the shared engine batch.'},indent=2)+'\n',newline='\n')
print('SIGNAL TERMINAL CONTEXT:',len(fixture['contacts']),'desktop bearings; native lamp clear')
