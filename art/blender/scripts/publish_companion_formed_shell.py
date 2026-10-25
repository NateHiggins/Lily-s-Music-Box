"""Publish the separately reviewed shell over the uninstalled companion candidate.

Rebuild order: build_service_companion.py --publish, formed-shell study,
inspect_companion_formed_shell.py, then this publisher. Installed radiophone
source and runtime carrier are never replaced here.
"""
from pathlib import Path
import argparse,hashlib,json,math,shutil,sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--candidate',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);candidate=(ROOT/args.candidate).resolve()
assert candidate.is_relative_to((ROOT/'tmp').resolve())
review=json.loads((candidate/'review.json').read_text());contacts=json.loads((candidate/'clamp_contacts.json').read_text())
native=ROOT/'art/blender/service_companion_v2.blend';data_path=ROOT/'game/data/device/service_companion_v2.json'
assert hashlib.sha256(native.read_bytes()).hexdigest()==review['source_sha256'],'Rebuild pristine companion before applying the shell'
assert review['export']['status']=='PASS' and contacts['maximum_gap_m']<.000005 and contacts['checks']==23
assert contacts['reading_shaft_clear_stock_layers']==3 and abs(contacts['glass_thickness_m']-.0012)<.000005
data=json.loads(data_path.read_text());assert len(data['finishes'])==4,'Shell must be applied exactly once'
construction_path=ROOT/'art/blender/service_companion_v2_construction.json';construction=json.loads(construction_path.read_text())
bpy.ops.wm.open_mainfile(filepath=str(candidate/'art/blender/service_companion_formed_shell.blend'))
bpy.context.preferences.filepaths.save_version=0
keyboard=bpy.data.objects['CompanionKeyboard'];keyboard.rotation_euler.x=0
bpy.data.objects['CompanionKeyboardLatch'].rotation_euler.z=0;bpy.context.view_layer.update()
def coords(p):return Vector((p[0],-p[2],p[1]))
for x,label in [(-.094,'Port'),(.094,'Starboard')]:
    a=coords((x,-.084,.042));attachment=keyboard.matrix_world@coords((x,.016,-.006));delta=attachment-a
    elbow=(a+attachment)*.5+Vector((0,-delta.z,delta.y)).normalized()*math.sqrt(.05**2-delta.length_squared*.25)
    for suffix,start,end in [('Upper',a,elbow),('Lower',elbow,attachment)]:
        link=bpy.data.objects[label+'KeyboardStay'+suffix];link.location=start;link.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
for image in bpy.data.images:
    if image.source=='FILE':
        absolute=Path(bpy.path.abspath(image.filepath));assert absolute.is_file(),image.name
        image.filepath=bpy.path.relpath(str(absolute),start=str(native.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(native),relative_remap=False)
for image in bpy.data.images:
    if image.source=='FILE':assert Path(bpy.path.abspath(image.filepath)).is_file(),image.name
asset=ROOT/'game/assets/props/service_companion_v2.glb';shutil.copy2(candidate/'game/assets/props/service_companion_formed_shell.glb',asset)
data['asset_sha256']=hashlib.sha256(asset.read_bytes()).hexdigest();data['finishes'].update(review['finishes'])
data_path.write_text(json.dumps(data,indent=2)+'\n',newline='\n')
construction['export']=dict(review['export'],asset='res://assets/props/service_companion_v2.glb')
construction['formed_shell']=dict(review,contacts=contacts)
construction['limitations']=['Uninstalled companion candidate; requires imported/mechanical and actual-input checks','No autonomous movement, typing or world-performance qualification yet']
construction_path.write_text(json.dumps(construction,indent=2)+'\n',newline='\n')
print('PUBLISHED UNINSTALLED FORMED COMPANION',construction['export']['triangles'],'triangles',len(data['finishes']),'accessory finishes')
