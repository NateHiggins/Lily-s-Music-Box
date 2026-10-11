"""Retained sectional bookcase sash, with separate wood/glass and metre UVs."""
from pathlib import Path
import hashlib,json,re,sys
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_surface_uvs import repair_scene
source=ROOT/'game/scripts/props/bookshelf_prop.gd'
text=source.read_text()
case_width=float(re.search(r'"sectional":\s+_case_w = ([.\d]+)',text)[1])
section=text.split('func _make_lift_door(')[1].split('\nfunc ')[0]
width=case_width-float(re.search(r'_case_w - ([.\d]+)',section)[1])
height=float(re.search(r'outer_h := ([.\d]+)',section)[1])
rail=float(re.search(r'rail := ([.\d]+)',section)[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={key:bpy.data.materials.new(key) for key in ('wood_dark','glassish')}

def box(name,size,center,key,grain_vertical=False):
    # Source coordinates are Godot X,Y,Z; Blender X,-Z,Y.
    bpy.ops.mesh.primitive_cube_add(size=1,location=(center[0],-center[2],center[1]))
    obj=bpy.context.object;obj.name=name;obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(materials[key])
    uv=obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        axes=sorted(range(3),key=lambda axis:abs(polygon.normal[axis]))[:2]
        # Walnut grain runs along texture V: rails follow X, stiles follow Z.
        grain_axis=2 if grain_vertical else 0
        if key=='wood_dark' and grain_axis in axes:
            axes=[next(axis for axis in axes if axis!=grain_axis),grain_axis]
        for loop in polygon.loop_indices:
            point=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(point[axes[0]],point[axes[1]])
    return obj

objects=[]
for side in (-1,1):
    objects.append(box('SashRail'+str(side),(width,rail,.012),(0,side*(height-rail)*.5,0),'wood_dark'))
    objects.append(box('SashStile'+str(side),(rail,height-2*rail,.012),(side*(width-rail)*.5,0,0),'wood_dark',True))
objects.append(box('Glazing',(width-2*rail,height-2*rail,.006),(0,0,.006),'glassish'))
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
obj=bpy.context.object;obj.name='LiftDoor';bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
repair_scene()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bookcase_lift_door.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/bookcase_lift_door.glb'),export_format='GLB',export_yup=True,export_apply=True)
fixture={'evidence_class':'INERT','source':source.relative_to(ROOT).as_posix(),
         'source_sha256':hashlib.sha256(text.replace('\r\n','\n').encode()).hexdigest(),
         'case_width':case_width,'outer_width':width,'height':height,'rail':rail,
         'state_owner':'Existing V2 bookshelf lift/sliding door; no collision or control changes.'}
(ROOT/'game/tests/fixtures/orison_bookcase_lift_door.json').write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
print('BOOKCASE SASH:',width,height,rail,'; wood and glass stock separated')
