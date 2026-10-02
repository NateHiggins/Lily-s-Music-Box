"""Fitted V2 bodega receiving room behind the existing delivery aperture.

Front deliveries follow the retained sales aisle. The existing shop floor,
registered template and opening supply metre scale and physical ownership.
"""
from pathlib import Path
import json
import math
import bpy
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from bodega_services_geometry import dimensions as service_dimensions
ROOT=Path(__file__).resolve().parents[3]

g=json.loads((ROOT/'game/data/orison_v2/exterior/exterior_geometry.json').read_text())
s=next(x for x in g['templates'] if x['id']=='TEMPLATE_BODEGA_CELL_V1')
rows={x['id']:x for x in s['boxes']}
floor=rows['shop_floor'];start=floor['position_m'][2]-floor['size_m'][2]/2
half=floor['size_m'][0]/2
end=start-2.0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mats={}
for key in ['terrazzo','plaster_stained','brick','wood_dark','cast_iron','porcelain']:
 m=bpy.data.materials.new(key);m.diffuse_color=(.45,.40,.32,1);mats[key]=m
parts={}
def box(name,rect,lo,hi,key,bevel=.003):
 x0,z0,x1,z1=rect
 bpy.ops.mesh.primitive_cube_add(size=1,location=((x0+x1)/2,-(z0+z1)/2,(lo+hi)/2))
 o=bpy.context.object;o.name=name;o.dimensions=(x1-x0,z1-z0,hi-lo)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mats[key])
 if bevel:
  b=o.modifiers.new('Worked edge','BEVEL');b.width=min(bevel,min(o.dimensions)/5);b.segments=1;bpy.ops.object.modifier_apply(modifier=b.name)
 for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
 uv=o.data.uv_layers.new(name='Metres');uv.active_render=True
 for face in o.data.polygons:
  axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=((1,2),(0,2),(0,1))[axis]
  for loop in face.loop_indices:
   v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(v[axes[0]],v[axes[1]])
 parts.setdefault(key,[]).append(o)
 return o
box('ReceivingFoundation',(-half,end,half,start),-.30,-.05,'brick',0)
box('ReceivingFloor',(-half,end,half,start),-.05,0,'terrazzo',.001)
for x0,x1 in [(-half,-half+.14),(half-.14,half)]:
 box('ReceivingPartyWall',(x0,end,x1,start),-.30,3.25,'plaster_stained')
# This owner's wall keeps its single mesh/collision partition. The independent
# electrical intake has a 44 mm square sleeve through the actual 160 mm fabric.
service=service_dimensions();px,py,pz=service['rear_port'];r=.022
box('ReceivingBackWallW',(-half,end-.16,px-r,end),-.30,3.25,'plaster_stained')
box('ReceivingBackWallE',(px+r,end-.16,half,end),-.30,3.25,'plaster_stained')
box('ReceivingBackWallBelow',(px-r,end-.16,px+r,end),-.30,py-r,'plaster_stained')
box('ReceivingBackWallAbove',(px-r,end-.16,px+r,end),py+r,3.25,'plaster_stained')
box('ReceivingCeiling',(-half,end,half,start),3.15,3.25,'plaster_stained')
# Original opening: 1.05 m clear; frame does not reduce its accepted width.
a=rows['back_opening_head'];cx=a['position_m'][0];width=a['size_m'][0]
for x in [cx-width/2-.025,cx+width/2+.025]:
 box('ReceivingJamb',(x-.025,start-.10,x+.025,start+.035),0,2.25,'wood_dark')
box('ReceivingDoorHead',(cx-width/2-.05,start-.10,cx+width/2+.05,start+.035),2.25,2.32,'wood_dark')
# Fixed receiving bench, kept out of the incoming cart/capsule lane.
for x in [-1.93,-1.10]:
 for z in [end+.35,end+1.15]:
  box('BenchLeg',(x-.035,z-.035,x+.035,z+.035),0,.83,'wood_dark')
box('ReceivingBench',(-2.04,end+.23,-.99,end+1.27),.83,.90,'wood_dark')
box('BenchBackBoard',(-2.04,end+.23,-1.99,end+1.27),.90,1.15,'wood_dark')
# A supported fixture stem for the existing relocated delivery practical.
box('PracticalCeilingMount',(.56,end+1.04,.74,end+1.22),3.08,3.15,'cast_iron')
box('PracticalStem',(.635,end+1.095,.665,end+1.125),2.73,3.08,'cast_iron')
box('PracticalShade',(.46,end+.94,.84,end+1.28),2.68,2.73,'cast_iron')
bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.045,location=(.65,-(end+1.11),2.62))
o=bpy.context.object;o.name='ReceivingBulb';o.data.materials.append(mats['porcelain']);parts.setdefault('porcelain',[]).append(o)
for loop in o.data.uv_layers.active.data:
 loop.uv.x*=2*math.pi*.045;loop.uv.y*=math.pi*.045

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bodega_receiving.blend'))
for key,objects in parts.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='Receiving__'+key
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/bodega_receiving.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
print('BODEGA RECEIVING',start,end,len(parts),'partitions')
