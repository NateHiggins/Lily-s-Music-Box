"""Native fit and neutral images; not a production-world or input receipt."""
from pathlib import Path
import json,math,os
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=Path(os.environ.get('DISPATCH_REVIEW_OUT',str(R/'tmp/v2-annunciator-dispatch-20261017')));O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/annunciator_dispatch.blend'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));D=json.loads((R/'game/data/orison_v2/annunciator_dispatch.json').read_text())
parts={o.name:o for o in bpy.data.collections['Dispatch stocks'].objects}
for obj in parts.values():
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold and e.is_contiguous for e in bm.edges),obj.name
    assert bm.calc_volume(signed=True)>0,obj.name;bm.free()
def tree(obj,offset=Vector(),pressed=False):
    vertices=obj.data.shape_keys.key_blocks['Pressed'].data if pressed else obj.data.vertices
    return BVHTree.FromPolygons([v.co+offset for v in vertices],[list(p.vertices) for p in obj.data.polygons])
guide=tree(parts['Guides']);bus=tree(parts['ContactBus']);stem=parts['ButtonStem'];seats=tree(parts['BusInsulators'])
stem_tip=min((C.transposed()@v.co).z for v in stem.data.vertices)
fits=[]
for at in D['centers']:
    for travel in [0.,D['travel']*.5,D['travel']]:
        offset=C@Vector(at)-C@Vector((0,0,travel))
        assert not guide.overlap(tree(stem,offset)),('shaft binds',at,travel)
        tip=C@Vector((at[0],at[1],at[2]+stem_tip-travel))
        point,normal,_,distance=bus.find_nearest(tip,.01)
        assert point is not None
        if travel==D['travel']:assert distance<.00003,('full stroke misses bus',distance)
        else:assert distance>.0019,('partial stroke closes contacts',distance)
        fits.append({'center':at,'stroke':travel,'contact_gap_m':distance})
    for compressed in [False,True]:
        offset=C@Vector(at)+C@Vector((0,0,-.022))
        spring_tree=tree(parts['ReturnSpring'],offset,compressed)
        assert not bus.overlap(spring_tree),('return spring shorts the contacts',at,compressed)
        vertices=parts['ReturnSpring'].data.shape_keys.key_blocks['Pressed' if compressed else 'Basis'].data
        low=min((v.co+offset for v in vertices),key=lambda p:(C.transposed()@p).z)
        hit,normal,_,distance=seats.find_nearest(low,.003)
        assert hit is not None and distance<.00004,('spring loses insulating bearing',at,compressed,distance)
    wrong=C@Vector(at)+C@Vector((.001,0,0))
    assert guide.overlap(tree(stem,wrong)),('displaced-shaft negative control missed',at)
# Populate the shared moving stocks at their real eight mounting points.
for key in ['ButtonCap','ButtonStem','ReturnSpring']:parts[key].hide_render=True
for i,at in enumerate(D['centers']):
    for key in ['ButtonCap','ButtonStem','ReturnSpring']:
        clone=parts[key].copy();clone.data=parts[key].data;clone.hide_render=False
        bpy.context.scene.collection.objects.link(clone)
        clone.location=C@Vector(at)+ (C@Vector((0,0,-.022)) if key=='ReturnSpring' else Vector())
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral room');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.45,.5,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
center=C@Vector((0,-.338,.05))
for at,power,size in [((.2,.3,.2),12,.25),((-.2,-.25,.1),6,.25)]:
    bpy.ops.object.light_add(type='AREA',location=center+C@Vector(at));light=bpy.context.object
    light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
for name,offset in [('front',(.16,.14,.32)),('rear',(-.14,.12,-.30))]:
    bpy.ops.object.camera_add(location=center+C@Vector(offset));camera=bpy.context.object
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=52;scene.camera=camera
    scene.render.filepath=str(O/('native_'+name+'.png'));bpy.ops.render.render(write_still=True)
(O/'native_fit.json').write_text(json.dumps({'evidence_class':'INERT','fits':fits,'shifted_shaft_negative_controls':len(D['centers']),'scope':'Native guide/shaft travel and contact-bus fit, neutral images; no dispatch/input/room acceptance.'},indent=2)+'\n',newline='\n')
print('DISPATCH FIT:',len(fits),'travel samples;',len(D['centers']),'displaced-shaft controls',flush=True)
