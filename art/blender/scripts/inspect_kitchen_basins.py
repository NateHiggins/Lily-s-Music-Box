"""Render the three native castings with their accepted faucet geometry."""
from pathlib import Path
import ast,json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-kitchen-castings-20261012/native';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/kitchen_basins.blend'))
families={n:bpy.data.objects[n] for n in ['Standard','Compact','Countertop']}
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
source=Path(__file__).with_name('inspect_domestic_door_leaves.py');tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='material'],type_ignores=[]),str(source),'exec'))
with bpy.data.libraries.load(str(ROOT/'art/blender/kitchen_faucet.blend'),link=False) as (src,dst):dst.objects=src.objects
faucets=dst.objects
for o in faucets:bpy.context.scene.collection.objects.link(o)
with bpy.data.libraries.load(str(ROOT/'art/blender/domestic_storage.blend'),link=False) as (src,dst):
    dst.objects=[n for n in src.objects if n.startswith('CounterCompact__')]
compact_frame=dst.objects
for o in compact_frame:bpy.context.scene.collection.objects.link(o);o.location=(0,0,0)
skins={k:material(k,(1,1,1)) for k in ['porcelain_fixture','faucet_nickel','rubber_aged','cast_iron','metal']}
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        key=o.data.materials[0].name.split('.')[0];o.data.materials.clear();o.data.materials.append(skins[key])
# Inspect actual support vertices and face centres against the casting. A
# vertical sightline must meet glaze before hardware, and hardware must not
# penetrate the casting's nearest oriented surface beyond contact tolerance.
bpy.context.view_layer.update()
bearing_checks=[]
for name in ['Standard','Compact']:
    shell=next(o for o in families[name].children_recursive if o.name.startswith('ContinuousCasting'))
    top=.9 if name=='Standard' else .9175
    w,d=(.61,.46) if name=='Standard' else (.5,.38)
    supports=compact_frame if name=='Compact' else [o for o in faucets if o.type=='MESH' and o.parent and o.parent.name.startswith('StandardBearers')]
    count=0
    for obj in supports:
        samples=[v.co for v in obj.data.vertices]+[f.center for f in obj.data.polygons]
        for q in samples:
            point=obj.matrix_world@q
            if not (top-.055<=point.z<=top+.0001 and abs(point.x)<w/2+.018 and abs(point.y)<d/2+.018):continue
            origin=Vector((point.x,point.y,top+.03));direction=Vector((0,0,-1))
            anywhere=shell.ray_cast(origin,direction,distance=.25)[0]
            if not anywhere:continue
            hit=shell.ray_cast(origin,direction,distance=top+.03-point.z+.0006)[0]
            assert hit,('support visible inside bowl',name,obj.name,point[:])
            found,at,normal,index=shell.closest_point_on_mesh(point)
            assert not found or (point-at).dot(normal)>-.0006,('support penetrates casting',name,obj.name,point[:])
            count+=1
    assert count>0
    bearing_checks.append({'variant':name,'actual_support_samples':count,'clear':True})
(OUT/'bearing-clearance.json').write_text(json.dumps(bearing_checks,indent=2)+'\n',encoding='utf-8',newline='\n')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('CastIronSinkReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.3
for at,power,size in [((-1,-1,3),150,2),((2,1,2),100,1)]:
    d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=size;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((.2,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Camera');c=bpy.data.objects.new(d.name,d);scene.collection.objects.link(c);scene.camera=c;d.lens=55;d.clip_start=.001
for family in families:
    top=.9 if family=='Standard' else .9175
    for name,parent in families.items():
        for o in parent.children_recursive:o.hide_render=name!=family or o.name.startswith('Water')
        plug=bpy.data.objects['Plug'+name];plug.location=(.095,.045,top-.124)
    for o in faucets:
        root=o
        while root.parent:root=root.parent
        wanted='Standard' if family=='Standard' else 'Compact'
        o.hide_render=not root.name.startswith(wanted) or root.name.startswith('StandardBearers')
    for o in compact_frame:o.hide_render=True
    c.location=(1.1,1.4,1.8);c.rotation_euler=(Vector((.18,0,1.0))-c.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(family+'.png'));bpy.ops.render.render(write_still=True)
    if family in ['Standard','Compact']:
        for o in compact_frame:o.hide_render=family!='Compact'
        if family=='Standard':
            for o in faucets:
                if o.parent and o.parent.name.startswith('StandardBearers'):o.hide_render=False
        c.location=(1.2,1.8,1.35);c.rotation_euler=(Vector((.15,0,.75))-c.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/(family+'_bearings.png'));bpy.ops.render.render(write_still=True)
    if family=='Standard':
        c.location=(.48,.65,1.52);c.rotation_euler=(Vector((0,0,.88))-c.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'bowl_detail.png');bpy.ops.render.render(write_still=True)
