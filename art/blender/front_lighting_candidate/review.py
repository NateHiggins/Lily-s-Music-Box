"""Render the uninstalled native lighting batch against source-owned room planes.

Context is explicitly a cutaway, not a replacement for composed Godot review.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'tmp/v2-front-lighting-20261016'
path = ROOT/'art/blender/front_lighting_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
plan = json.loads((ROOT/'art/data/front_lighting_plan.json').read_text())
layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1440
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.view_settings.exposure = 1.0
scene.world = bpy.data.worlds.new('Native review ambient')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.35,.40,.48,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .40
context = bpy.data.collections.new('SourcePlanesForReviewOnly')
scene.collection.children.link(context)

def neutral(name, color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
    return m
wall=neutral('Review-only wall plane',(.30,.27,.22))
floor=neutral('Review-only floor plane',(.13,.095,.06))

def plane_box(name, center, size, finish):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(center[0],-center[2],center[1]))
    obj=bpy.context.object;obj.name=name
    obj.dimensions=(size[0],size[2],size[1])
    obj.data.materials.append(finish)
    for c in list(obj.users_collection):c.objects.unlink(obj)
    context.objects.link(obj)

def camera(at, target, lens=24):
    bpy.ops.object.camera_add(location=(at[0],-at[2],at[1]))
    obj=bpy.context.object
    obj.rotation_euler=(Vector((target[0],-target[2],target[1]))-obj.location).to_track_quat('-Z','Y').to_euler()
    obj.data.lens=lens;scene.camera=obj

views=[]
for level, base, at, target, name in [
    ('F02',3.2,[-4.6,4.85,-11.7],[6.5,5.65,-9.3],'gallery'),
    ('F01',0,[5.7,1.65,-11.7],[7.5,2.35,-10.3],'workroom_service'),
    ('F02',3.2,[7.7,4.9,-10.9],[8.23,4.55,-11.65],'switch_detail'),
    ('F02',3.2,[1.05,5.65,-10.35],[1.35,6.10,-9.825],'canopy_detail'),
    ('F02',3.2,[8.5,5.05,.45],[9.35,5.10,1.0],'source_cover')]:
    for obj in list(context.objects):bpy.data.objects.remove(obj,do_unlink=True)
    for obj in bpy.data.collections['FrontLightingCandidate'].objects:
        obj.hide_render=obj.get('level') != level
    for s in layout['spaces']:
        if s['level']!=level:continue
        # Nearby retained rooms, not an invented free-standing fixture display.
        x0,z0,x1,z1=s['rect']
        plane_box(s['id']+'_ReviewFloor',[(x0+x1)/2,base-.03,(z0+z1)/2],[x1-x0,.06,z1-z0],floor)
        if '_FRONT_' in s['id'] or s['id'].endswith('_SERVICE_HALL'):
            plane_box(s['id']+'_ReviewCeiling',[(x0+x1)/2,base+3.03,(z0+z1)/2],[x1-x0,.06,z1-z0],wall)
    # Full wall planes at actual source positions. Apertures are deliberately
    # omitted in this native cutaway; runtime shell review remains outstanding.
    plane_box('GalleryEastBearing',[8.3,base+1.5,-10.8],[.14,3,3.1],wall)
    plane_box('ServiceRiserBearing',[9.5,base+1.5,0],[.14,3,5],wall)
    if name != 'source_cover':
        plane_box('StreetCutawayWall',[1.35,base+1.5,-12.35],[13.9,3,.14],wall)
    else:
        # Show the new cover seated against the actual retained casting, not
        # a free-floating plate or an invented proxy enclosure.
        source=ROOT/'art/blender/electrical_service.blend'
        with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
            loaded.objects=[n for n in available.objects if n in ['JunctionCasting','CoverScrews','EntryBushUpper','EntryBushLower']]
        from mathutils import Matrix
        pose=Matrix.Translation(Vector((9.39,-1,base+1.85)))@Matrix.Rotation(-math.pi/2,4,'Z')
        for obj in loaded.objects:
            if obj is None:continue
            context.objects.link(obj);obj.matrix_world=pose@obj.matrix_world
            for i,mat in enumerate(obj.data.materials):
                obj.data.materials[i]=bpy.data.materials[mat.name.split('.')[0]]
    # Native light appearance is approximate optical review. Actual production
    # LightFixtureProp, light budget and circuit behavior are not exercised here.
    for fixture in plan['fixtures']:
        if fixture['level']!=level:continue
        x,y,z=fixture['position']
        bpy.ops.object.light_add(type='POINT',location=(x,-z,base+y-.25))
        light=bpy.context.object;light.data.energy=28;light.data.color=(1,.77,.48)
        light.data.shadow_soft_size=.08
        for c in list(light.users_collection):c.objects.unlink(light)
        context.objects.link(light)
    bpy.ops.object.light_add(type='AREA',location=(2,9,base+2.1))
    light=bpy.context.object;light.data.energy=160;light.data.shape='DISK';light.data.size=8
    light.rotation_euler=(Vector((2,7,base+1.5))-light.location).to_track_quat('-Z','Y').to_euler()
    for c in list(light.users_collection):c.objects.unlink(light)
    context.objects.link(light)
    camera(at,target,45 if name=='switch_detail' else 40 if name=='source_cover' else 24)
    if name in ['switch_detail','source_cover','canopy_detail']:
        bpy.ops.object.light_add(type='AREA',location=(at[0]-.15,-at[2],at[1]+.20))
        key=bpy.context.object;key.data.energy=65;key.data.shape='DISK';key.data.size=.75
        key.rotation_euler=(Vector((target[0],-target[2],target[1]))-key.location).to_track_quat('-Z','Y').to_euler()
        for c in list(key.users_collection):c.objects.unlink(key)
        context.objects.link(key)
    image=OUT/(name+'.png');scene.render.filepath=str(image)
    bpy.ops.render.render(write_still=True)
    views.append(dict(name=name,path=str(image.relative_to(ROOT)),sha256=hashlib.sha256(image.read_bytes()).hexdigest()))
(OUT/'native_views.json').write_text(json.dumps(dict(evidence_class='INERT',
    scope='Native cutaway views, approximate light; no composed/runtime/loaded-mip acceptance.',
    reference_electrical_native_sha256=hashlib.sha256((ROOT/'art/blender/electrical_service.blend').read_bytes()).hexdigest(),
    review_recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    blend_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),views=views),indent=2)+'\n',encoding='utf-8')
