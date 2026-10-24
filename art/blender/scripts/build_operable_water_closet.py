"""Editable hollow low-cistern closet with articulated seat, cover and ball-cock.
Run in Blender; runtime ownership remains in orison_v2_water_closet.gd.
"""
import bpy
import math
import json
import sys
import os
import bmesh
import numpy as np
import hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(os.environ.get("ORISON_REPO_ROOT",str(Path(__file__).resolve().parents[3])))
OUT=Path(os.environ.get("ORISON_OUTPUT_ROOT",str(ROOT)))
import sys
sys.path.insert(0, str(ROOT/"art/blender/scripts"))
from repair_surface_uvs import repair_scene
import water_closet_form as form
from fabrication_chart_batch import triangle_charts
def p(v): return Vector((v[0],-v[2],v[1]))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metal=0,rough=.5):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough
    return m
def group(name,at=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p(at);return o
def finish(o,name,mat,parent=None):
    o.name=name;o.data.materials.append(mat)
    if o.type=='MESH':
        for f in o.data.polygons:f.use_smooth=True
    bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o
def pipe(name,points,r,mat,parent=None):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=3;c.use_fill_caps=True
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for b,v in zip(s.bezier_points,points):b.co=p(v);b.handle_left_type=b.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);return finish(o,name,mat,parent)
def cyl(name,at,r,h,mat,axis=(0,1,0),parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=h,location=p(at));o=bpy.context.object
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(p(axis))
    mod=o.modifiers.new('Soft machined edge','BEVEL');mod.width=.0015;mod.segments=2
    return finish(o,name,mat,parent)
def mesh(name,verts,faces,mat,parent=None,solid=0):
    m=bpy.data.meshes.new(name);m.from_pydata([p(v) for v in verts],[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,name,mat,parent)
    if solid:
        mod=o.modifiers.new('Physical cloth thickness','SOLIDIFY');mod.thickness=solid
    return o
def apply():
    catalogue=json.loads((ROOT/'art/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
    for o in list(bpy.context.scene.objects):
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    repair_scene()
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH':continue
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        collapsed=[f for f in bm.faces if f.calc_area()<=1e-16]
        if collapsed:bmesh.ops.delete(bm,geom=collapsed,context='FACES')
        bm.to_mesh(o.data);bm.free()
        m=o.data;m.calc_loop_triangles()
        points=np.asarray([[(o.matrix_world@m.vertices[i].co)[:] for i in t.vertices] for t in m.loop_triangles],dtype=np.float64)
        assert len(points)>0,o.name
        key=o.data.materials[0].name
        tile=float(catalogue['water_clear' if key=='WaterSeal' else key]['meters_per_tile'])
        _,_,values,_=triangle_charts(points,np.zeros(3),tile)
        layer=m.uv_layers.active or m.uv_layers.new(name='MetricSurface')
        for triangle,uvs in zip(m.loop_triangles,values):
            for index,uv in zip(triangle.loops,uvs):layer.data[index].uv=uv
def save(name):
    (OUT/"art/blender").mkdir(parents=True,exist_ok=True)
    (OUT/"game/assets/props").mkdir(parents=True,exist_ok=True)
    repair_scene()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'art/blender/{name}.blend'))
    native_parts=[{'name':o.name,'triangles':len(o.data.polygons),'materials':[m.name for m in o.data.materials]} for o in bpy.context.scene.objects if o.type=='MESH']
    # Keep the editable hardware separate, batch only rigid shared-material
    # export stock. The selectable linkage and animated chain keep their roots.
    batches={}
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH' or o.parent is None or o.parent.name=='DischargeChain' or o.name in ['HandleInsideArm','WaterSeal','StoredWater']:continue
        batches.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    for (parent,key),objects in batches.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();bpy.context.object.name=parent+'_'+key+'_Stock'
    # Joining applies world-space float32 placement: discard only collapsed
    # export slivers and chart the final coordinates, leaving native stock intact.
    catalogue=json.loads((ROOT/'art/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        tiny=[f for f in bm.faces if f.calc_area()<=1e-12]
        if tiny:bmesh.ops.delete(bm,geom=tiny,context='FACES')
        bm.to_mesh(o.data);bm.free();m=o.data;m.calc_loop_triangles()
        points=np.asarray([[(o.matrix_world@m.vertices[i].co)[:] for i in t.vertices] for t in m.loop_triangles],dtype=np.float64)
        key=m.materials[0].name;tile=float(catalogue['water_clear' if key=='WaterSeal' else key]['meters_per_tile'])
        _,_,values,_=triangle_charts(points,np.zeros(3),tile)
        for triangle,uvs in zip(m.loop_triangles,values):
            for index,uv in zip(triangle.loops,uvs):m.uv_layers.active.data[index].uv=uv
    # Use the existing production export convention: this bundled exporter
    # flips UV V but retains Blender's bitangent sign unless corrected here.
    class ExportUVHandedness:
        partitions=0
        def gather_attribute_change(self,attribute,data,normalized,export_settings):
            if attribute=='TANGENT':
                data['data'][:,3]*=-1
                type(self).partitions+=1
    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'game/assets/props/{name}.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
    from check_exported_tangents import validate
    tangent_review=validate(OUT/f'game/assets/props/{name}.glb')
    source_paths=['art/blender/scripts/build_operable_water_closet.py','art/blender/scripts/water_closet_form.py','art/blender/scripts/fabrication_chart_batch.py','art/blender/scripts/repair_surface_uvs.py','art/data/runtime_material_sets.json']
    report={'evidence_class':'INERT','scope':'Native casting/form and metric chart source record; no runtime qualification.',
        'asset_sha256':hashlib.sha256((OUT/f'game/assets/props/{name}.glb').read_bytes()).hexdigest(),
        'source_bindings':{path:hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for path in source_paths},
        'parts':native_parts,'runtime_meshes':[o.name for o in bpy.context.scene.objects if o.type=='MESH'],
        'exported_tangents':tangent_review,'corrected_partitions':ExportUVHandedness.partitions,
        'handle_pivot':[.188,.744,.119],'handle_touch':[.214,.706,.098],
        'bowl_throat':{'mouth_y':.176,'minimum_radius_m':.040,'outlet_y':.089},'seat_aperture':{'half_width_m':.137,'half_length_m':.186,'centre_z':-.157,'back_fraction':.82}}
    (OUT/f'art/blender/{name}_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')

# A hollow wash-down closet and low cistern, retaining the existing flush pivot.
clear()
nickel=material("nickel_plated",(.72,.71,.67),.82,.28)
brass=material("brass",(.55,.46,.26),.85,.3)
rubber=material("rubber_aged",(.026,.026,.022),0,.8)
iron=material('iron_blackened',(.025,.028,.027),.65,.72)
glaze=material('porcelain_fixture',(.88,.87,.82),0,.22)
wood=material('wood_dark',(.075,.048,.026),0,.32)
fixed=group('WaterClosetCasting')
def oval_shell(name,rings,mat,parent=fixed):
    verts=[];faces=[];n=96
    for rx,rz,y,z in rings:
        for i in range(n):
            a=math.tau*i/n;verts.append((rx*math.cos(a),y,z+rz*math.sin(a)))
    for j in range(len(rings)):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(rings))*n+(i+1)%n,((j+1)%len(rings))*n+i))
    return mesh(name,verts,faces,mat,parent)
def rounded_box(name,at,size,mat,parent=fixed,bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    m=o.modifiers.new('Cast radiused corners','BEVEL');m.width=bevel;m.segments=5
    o.modifiers.new('Weighted casting normals','WEIGHTED_NORMAL')
    return finish(o,name,mat,parent)
form.bowl(fixed,glaze,mesh)
form.pedestal(fixed,glaze,mesh)
seat=group('SeatHinge',(0,.442,.118))
form.seat(seat,wood,mesh)
# Continuous outer wall, rim, inner wall and floor, with 16 mm porcelain stock.
form.cistern(fixed,glaze,mesh)
cover=group('CisternCover',(0,.817,.235))
rounded_box('RemovableCisternLid',(0,.817,.235),(.475,.025,.235),glaze,cover,bevel=.009)
form.flush_connection(fixed,glaze,mesh)
form.drain_trap(fixed,iron,mesh)
pipe('SupplyPipe',[(-.17,.52,.275),(-.17,.23,.31),(-.17,.23,.35)],.008,nickel,fixed)
cyl('SupplyShutoff',(-.17,.23,.32),.017,.028,nickel,(0,0,1),fixed)
for x in [-.092,.092]:
    cyl('FloorBolt',(x,.048,-.15),.012,.012,nickel,parent=fixed)
    rounded_box('PorcelainHingePlinth',(x,.411,.097),(.058,.020,.100),glaze,fixed,bevel=.005)
    cyl('HingeRosette',(x,.4235,.118),.019,.005,nickel,parent=fixed)
    cyl('HingePost',(x,.434,.118),.006,.016,nickel,parent=fixed)
    cyl('HingePin',(x,.442,.118),.0045,.060,nickel,(1,0,0),fixed)
    cyl('SeatKnuckle',(x-.015,.442,.118),.0095,.016,nickel,(1,0,0),seat)
    rounded_box('SeatLeaf',(x-.015,.438,.099),(.023,.004,.042),nickel,seat,bevel=.001)
    cyl('SeatLeafScrew',(x-.015,.441,.084),.004,.003,nickel,parent=seat)
# Raised lid is a separate editable rigid component, leaving the seat aperture open.
lid=group('RaisedLid',(0,.442,.118))
lid_mesh=form.lid(lid,wood,mesh)
for face in lid_mesh.data.polygons:
    if abs(face.normal.z)>.99:face.use_smooth=False
for x in [-.092,.092]:
    cyl('LidKnuckle',(x+.015,.442,.118),.0095,.016,nickel,(1,0,0),lid)
    rounded_box('LidLeaf',(x+.015,.465,.099),(.023,.004,.045),nickel,lid,bevel=.001)
    rounded_box('LidLeafWeb',(x+.015,.454,.113),(.023,.024,.003),nickel,lid,bevel=.001)
    cyl('LidLeafScrew',(x+.015,.469,.084),.004,.003,nickel,parent=lid)
lid.rotation_euler.x=math.radians(82)
lever=group('CisternHandle',(.188,.744,.119))
cyl('HandleRose',(.188,.744,.121),.012,.012,nickel,(0,0,1),fixed)
pipe('FlushLever',[(.188,.744,.119),(.188,.744,.106),(.207,.718,.103),(.218,.698,.103)],.0045,nickel,lever)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=p((.216,.699,.103)))
paddle=bpy.context.object;paddle.scale=(.012,.005,.021);paddle.rotation_euler.y=math.radians(-24)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
finish(paddle,'FingerPaddle',nickel,lever)
cyl('HandleShaftBush',(.188,.744,.143),.010,.028,brass,(0,0,1),fixed)
cyl('HandleSpindle',(.188,.744,.163),.004,.080,brass,(0,0,1),lever)
group('HandleTouchPoint',(.214,.706,.098)).parent=lever
# Keep the authored world point when parenting the semantic grip marker.
bpy.data.objects['HandleTouchPoint'].matrix_world.translation=p((.214,.706,.098))
# Period ball-cock and lift-ball discharge, independently articulated.
# Form references: US1551808A (1925) and US1190917A (1916); no image projection.
pipe('InletRiser',[(-.17,.52,.275),(-.17,.746,.275)],.008,brass,fixed)
cyl('InletValveBody',(-.17,.748,.275),.017,.045,brass,(1,0,0),fixed)
float_arm=group('FloatArm',(-.17,.748,.275))
pipe('FloatRod',[(-.17,.748,.275),(-.03,.728,.275),(.08,.725,.275)],.0032,brass,float_arm)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=.040,location=p((.08,.725,.275)))
finish(bpy.context.object,'BallFloat',brass,float_arm)
# Open overflow bore, not a capped cylinder.
def tube(name,at,r,wall,h,mat,parent):
    points=[];sides=48
    for rr,y in [(r,at[1]),(r,at[1]+h),(r-wall,at[1]+h),(r-wall,at[1])]:
        for i in range(sides):
            a=math.tau*i/sides;points.append((at[0]+rr*math.cos(a),y,at[2]+rr*math.sin(a)))
    fs=[]
    for j in range(4):
        for i in range(sides):fs.append((j*sides+i,j*sides+(i+1)%sides,((j+1)%4)*sides+(i+1)%sides,((j+1)%4)*sides+i))
    return mesh(name,points,fs,mat,parent)
tube('OverflowStandpipe',(.145,.523,.29),.017,.002,.258,brass,fixed)
tube('CisternOutletBoss',(.075,.491,.205),.045,.016,.015,glaze,fixed)
tube('OutletUnion',(.075,.477,.205),.038,.009,.026,nickel,fixed)
tube('OutletGasket',(.075,.473,.205),.037,.008,.006,rubber,fixed)
tube('InletUnion',(-.17,.486,.275),.014,.006,.022,nickel,fixed)
tube('DischargeSeat',(.075,.526,.205),.033,.004,.010,brass,fixed)
flush_ball=group('FlushBall',(.075,.558,.205))
bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=20,radius=.032,location=p((.075,.558,.205)))
finish(bpy.context.object,'RubberFlushBall',rubber,flush_ball)
cyl('LiftRod',(.075,.602,.205),.0025,.088,brass,parent=flush_ball)
pipe('HandleInsideArm',[(.188,.744,.130),(.188,.744,.205),(.075,.722,.205)],.004,brass,lever)
group('LiftLeverAnchor',(.075,.722,.205)).parent=lever
bpy.data.objects['LiftLeverAnchor'].matrix_world.translation=p((.075,.722,.205))
group('LiftEye',(.075,.648,.205)).parent=flush_ball
bpy.data.objects['LiftEye'].matrix_world.translation=p((.075,.648,.205))
# Eight rigid presentation links follow the authoritative lever and lift eye.
chain=group('DischargeChain')
for i in range(8):
    at=(.075,.653+i*.009,.205)
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,location=p(at),major_radius=.0038,minor_radius=.0009)
    link=bpy.context.object;link.scale=(.7,1.3,1);link.rotation_euler.x=math.pi/2
    if i%2:link.rotation_euler.z=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    finish(link,'ChainLink%02d'%i,brass,chain)
# Real support for each valve, guide and overflow standpipe.
tube('DischargeFlange',(.075,.526,.205),.047,.018,.004,brass,fixed)
tube('InletFloorNut',(-.17,.526,.275),.015,.007,.008,brass,fixed)
for z in [.260,.290]:
    rounded_box('BallcockPivotCheek',(-.17,.744,z),(.016,.034,.004),brass,fixed,bevel=.001)
cyl('BallcockPivotPin',(-.17,.748,.275),.0035,.036,nickel,(0,0,1),fixed)
cyl('FloatThreadedNipple',(.042,.725,.275),.005,.018,brass,(1,0,0),float_arm)
tube('OverflowFoot',(.145,.526,.29),.025,.010,.005,brass,fixed)
rounded_box('OverflowWallPlate',(.145,.710,.326),(.034,.040,.006),brass,fixed,bevel=.002)
pipe('OverflowWallStrap',[(.129,.710,.290),(.126,.710,.315),(.145,.710,.326),(.164,.710,.315),(.161,.710,.290)],.0025,brass,fixed)
for x in [.063,.087]:
    cyl('GuideFoot',(x,.532,.205),.005,.009,brass,parent=fixed)
# A transverse clevis makes the lift rod's chain eye explicit.
bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=p((.075,.648,.205)),major_radius=.004,minor_radius=.0015)
eye=bpy.context.object;eye.rotation_euler.x=math.pi/2
finish(eye,'LiftRodEye',brass,flush_ball)
for x in [-.012,.012]:
    pipe('LiftGuide',[(.075+x,.526,.205),(.075+x,.645,.205),(.075,.645,.205)],.002,brass,fixed)
cistern_water=group('CisternWaterSurface',(0,.745,.235))
rounded_box('StoredWater',(0,.745,.235),(.421,.002,.185),material('WaterSeal',(.40,.48,.43),0,.2),cistern_water,bevel=.005)
# The water seal has its own ordinary transparent surface; no animation authority.
water=material('WaterSeal',(.40,.48,.43),0,.2)
optics=water.node_tree.nodes.get('Principled BSDF')
optics.inputs['Alpha'].default_value=.10;optics.inputs['Transmission Weight'].default_value=.9;optics.inputs['IOR'].default_value=1.333
oval_shell('WaterSeal',[(.001,.001,.181,-.045),(.043,.050,.181,-.045),
    (.043,.050,.180,-.045),(.001,.001,.180,-.045)],water)
apply();save('bath_water_closet')

