"""Assemble the native grid, source hinge states and custom PBR for review."""
from pathlib import Path
import json, math
import bpy
from mathutils import Matrix, Vector
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'tmp/v2-mail-bank-20261011/blender'; OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/mail_bank.blend'))
stocks = {o.name:o for o in bpy.context.scene.objects if o.type == 'MESH'}
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for name, o in stocks.items():
    o.hide_render = True
    key = o.data.materials[0].name; spec = dict(catalog[key])
    if key == 'brass_dull':
        spec['files'] = ['mailbank/T_mailbank_brass_albedo.png', 'mailbank/T_mailbank_brass_rough.png', spec['files'][2]]
        spec['meters_per_tile'] = .35
        spec['metallic'] = .55
    mat = bpy.data.materials.new(key+'_review'); mat.use_nodes = True
    o.data.materials.clear(); o.data.materials.append(mat)
    p = mat.node_tree.nodes['Principled BSDF']; p.inputs['Metallic'].default_value = spec['metallic']
    p.inputs['Roughness'].default_value = .9 if key == 'paper' else .52 if key == 'wood_dark' else .65 if key == 'iron_blackened' else .5
    for i, socket in [(0, 'Base Color'), (1, 'Roughness'), (2, 'Normal')]:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]), check_existing=True)
        if i: tex.image.colorspace_settings.name = 'Non-Color'
        if i == 2:
            n = mat.node_tree.nodes.new('ShaderNodeNormalMap'); n.inputs['Strength'].default_value = .035 if key in ['brass_dull','nickel_plated'] else .1
            mat.node_tree.links.new(tex.outputs['Color'], n.inputs['Color']); mat.node_tree.links.new(n.outputs['Normal'], p.inputs[socket])
        else: mat.node_tree.links.new(tex.outputs['Color'], p.inputs[socket])
    for loop in o.data.uv_layers.active.data: loop.uv /= spec['meters_per_tile']
C = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
made = []
def part(name, at=(0,0,0), parent=None, angle=0, axis='X'):
    o=stocks[name].copy(); o.data=stocks[name].data; bpy.context.collection.objects.link(o); o.hide_render=False
    pose=Matrix.Translation(Vector(at))@Matrix.Rotation(angle,4,axis)
    o.matrix_world=C@(parent if parent is not None else Matrix.Identity(4))@pose@C.inverted(); made.append(o)
def leaf(parent, player=False):
    part('LeafShell',(.137,-.008,0),parent)
    part('CardFrame',(.112 if player else .137,.012,-.006),parent)
    part('CylinderLock',(.242,-.039,-.007),parent); part('KeywayBack',(.242,-.039,-.007),parent)
def assemble(opened):
    for o in made: bpy.data.objects.remove(o,do_unlink=True)
    made.clear()
    for x in [-.65,.65]: part('TimberStile',(x,1.235,-.025))
    part('TimberLowerPanel',(0,.730,-.025)); part('TimberHeaderRail',(0,1.845,-.025)); part('TimberCrown',(0,1.917,-.059))
    part('HeaderPlate',(0,1.845,-.053))
    for floor in range(1,7):
        for col, stack in enumerate('ABCD'):
            unit=f'{floor}{stack}'; x=(col-1.5)*.31; y=.92+(floor-.5)*.14
            for name,z in [('PocketCase',-.112),('CastFrame',-.116)]: part(name,(x,y,z))
            part('CarrierFlap',(x,y+.053,-.122),angle=-.14)
            for dy in [-.033,.033]: part('HingeBarrel',(x-.137,y+dy,-.112))
            if unit in ['1B','1C','2D','3C','5D','6D']: continue
            if unit in ['4B','1D','5B']:
                angle=math.radians(95) if unit=='4B' and opened else .16 if unit!='4B' else 0
                leaf(Matrix.Translation(Vector((x-.137,y,-.112)))@Matrix.Rotation(angle,4,'Y'),unit=='4B')
            else:
                part('LeafShell',(x,y-.008,-.112)); part('CardFrame',(x,y+.012,-.118))
                part('CylinderLock',(x+.105,y-.039,-.119)); part('KeywayBack',(x+.105,y-.039,-.119))
    part('OutgoingPlate',(.38,.60,-.053)); part('OutgoingFlap',(.38,.594,-.060),angle=-.14); part('OutgoingPocket',(.38,.615,-.047))
    # Adjacent retained wall datum makes the proud mounting and open depths legible.
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.02,1.235));o=bpy.context.object
    o.dimensions=(1.65,.02,1.65);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);made.append(o)
    m=bpy.data.materials.new('Review wall');m.diffuse_color=(.22,.18,.14,1);o.data.materials.append(m)
for at, power in [((1,2,2.5),180),((-1,.8,1.5),80)]:
    d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=1
    o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,.1,1.25))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');camera=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(camera)
s=bpy.context.scene;s.camera=camera;s.render.engine='CYCLES';s.cycles.samples=32
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.10,.10,1)
s.render.resolution_x=1200;s.render.resolution_y=1000;s.render.resolution_percentage=100
for label,opened,at,target,scale in [('closed',False,(.8, 2.1,1.65),(0,.09,1.24),1.58),('open',True,(.65,1.8,1.60),(0,.1,1.30),1.45),('pocket_detail',True,(-.6,1.2,1.6),(-.155,.1,1.40),.52),('delivery_stock',True,(-.6,1.2,1.6),(-.155,.1,1.40),.52)]:
    assemble(opened); camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale
    if label == 'delivery_stock':
        part('EnvelopeStock',(-.135,1.34975,-.063));part('WorkOrderStock',(-.222,1.399,-.063))
        part('ParcelStock',(-.145,1.3915,-.049));part('ParcelBand',(-.145,1.3915,-.049))
    s.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
