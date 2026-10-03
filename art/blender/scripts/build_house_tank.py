"""Fabricate the semantic roof tank's timber boards, bound straps and steelwork."""
from pathlib import Path
import json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
records=[r for r in layout['fixtures'] if r.get('fabrication')=='house_tank']
body=next(r for r in records if r['fabrication_part']=='body')
origin=Vector((body['position'][0],0,body['position'][2]))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
groups={key:[] for key in ['Timber','Iron','Fasteners']}
materials={}
for name,color,metal in [('timber',(.30,.20,.12),0),('cast_iron',(.16,.17,.15),.65),('metal',(.30,.31,.29),.8)]:
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF']; shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.65; shader.inputs['Metallic'].default_value=metal
    materials[name]=mat

def keep(obj,name,group):
    obj.name=name; groups[group].append(obj)
    obj.data.materials.append(materials[{'Timber':'timber','Iron':'cast_iron','Fasteners':'metal'}[group]])
    return obj

def box(name,at,size,group,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object; obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Fabricated edge','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return keep(obj,name,group)

def cylinder(name,at,radius,depth,normal,vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(at.x,-at.z,at.y))
    obj=bpy.context.object; obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector((normal.x,-normal.z,normal.y)))
    return keep(obj,name,'Fasteners')

for record in records:
    role=record['fabrication_part']; at=Vector(record['position'])-origin; size=Vector(record['size'])
    if role=='body':
        # Floor owns the underside. Staves begin at its upper edge, avoiding
        # coplanar bottom faces while keeping the original external envelope.
        floor=.08; wall=.08
        box('TankBottom',at+Vector((0,-size.y*.5+floor*.5,0)),(size.x,floor,size.z),'Timber',.001)
        height=size.y-floor; y=at.y+floor*.5
        for side in [-1,1]:
            count=math.ceil(size.x/.24); pitch=size.x/count
            for i in range(count):
                length=pitch-(.001 if i in [0,count-1] else .002)
                x=-size.x*.5+(i+.5)*pitch+(.0005 if i==0 else -.0005 if i==count-1 else 0)
                box('FrontStave',(x,y,side*(size.z-wall)*.5),(length,height,wall),'Timber',.0006)
            count=math.ceil((size.z-2*wall)/.24); pitch=(size.z-2*wall)/count
            for i in range(count):
                box('SideStave',(side*(size.x-wall)*.5,y,-(size.z-2*wall)*.5+(i+.5)*pitch),(wall,height,pitch-.002),'Timber',.0006)
        # Thin interior boards back the visible seams; this does not become a
        # second physics owner or an invented fluid simulation.
        for side in [-1,1]:
            box('InnerFacing',(0,y,side*(size.z-2*wall-.012)*.5),(size.x-2*wall,height,.012),'Timber')
            box('InnerFacing',(side*(size.x-2*wall-.012)*.5,y,0),(.012,height,size.z-2*wall),'Timber')
    elif role=='lid':
        box('FoldedWeatherLid',at,size,'Iron',.006)
        for ratio in [-.3,0,.3]:
            box('StandingSeam',at+Vector((size.x*ratio,size.y*.5+.003,0)),(.012,.006,size.z-.024),'Iron',.001)
    elif role=='support':
        box('SupportColumn',at,size,'Iron',.005)
        # Recessed seam plates and visible rivets on the two exposed faces.
        for normal in [Vector((1,0,0)),Vector((0,0,1))]:
            for fraction in [-.38,.38]:
                point=at+Vector((0,size.y*fraction,0))+normal*(size.x*.5+.004)
                cylinder('ColumnRivet',point,.012,.008,normal)
    elif role=='binding':
        box('BindingStrap',at,size,'Iron',.002)
        along=Vector((1,0,0)) if size.x>size.z else Vector((0,0,1))
        normal=Vector((0,0,1 if at.z>0 else -1)) if size.x>size.z else Vector((1 if at.x>0 else -1,0,0))
        depth=min(size.x,size.z)
        plate_size=(.20,size.y,.006) if size.x>size.z else (.006,size.y,.20)
        box('LapPlate',at+normal*(depth*.5+.003),plate_size,'Iron',.001)
        for hand in [-1,1]:
            point=at+along*(hand*.065)+normal*(depth*.5+.006)
            cylinder('BindingWasher',point+normal*.001,.012,.002,normal)
            cylinder('BindingNut',point+normal*.006,.008,.008,normal,6)


    elif role=='collector_floor':
        box('CollectorFloor',at,size,'Timber',.002)
    elif role=='collector_wall':
        # X cheeks own all four corners; Z ends terminate at their inner faces.
        along_x=size.x>size.z
        collector=[r for r in records if r['fabrication_part']=='collector_floor'][0]
        collector_at=Vector(collector['position'])-origin
        wall=min(size.x,size.z)
        span=(size.x-2*wall) if along_x else size.z
        count=math.ceil(span/.16); pitch=span/count
        for i in range(count):
            offset=-span*.5+(i+.5)*pitch
            plank_at=at+Vector((offset if along_x else 0,-.015,0 if along_x else offset))
            plank_size=(pitch-.002,size.y-.03,wall) if along_x else (wall,size.y-.03,pitch-.002)
            box('CollectorStave',plank_at,plank_size,'Timber',.0006)
        cap_span=span-.006 if along_x else span+.006
        cap_size=(cap_span,.03,wall+.006) if along_x else (wall+.006,.03,cap_span)
        box('CollectorRim',at+Vector((0,size.y*.5-.015,0)),cap_size,'Iron',.001)
        normal=Vector((0,0,1 if at.z>collector_at.z else -1)) if along_x else Vector((1 if at.x>collector_at.x else -1,0,0))
        strap_span=size.x if along_x else size.z+.012
        strap_size=(strap_span,.05,.006) if along_x else (.006,.05,strap_span)
        strap_at=at+Vector((0,-size.y*.5+.14,0))+normal*(wall*.5+.003)
        box('CollectorBinding',strap_at,strap_size,'Iron',.001)
        along=Vector((1,0,0)) if along_x else Vector((0,0,1))
        for hand in [-1,1]:
            cylinder('CollectorRivet',strap_at+along*(span*.3*hand)+normal*.005,.008,.004,normal)

for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/house_tank.blend'))
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/house_tank.glb'),export_format='GLB',export_yup=True,export_apply=True)
