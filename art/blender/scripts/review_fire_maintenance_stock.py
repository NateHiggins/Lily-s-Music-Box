"""Native visual diagnostic, not runtime acceptance."""
from pathlib import Path
import bpy,json,bmesh,math,os
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
BUILD=Path(os.environ.get('FIRE_MAINTENANCE_OUT',str(ROOT))).resolve()
if BUILD!=ROOT:assert BUILD.is_relative_to((ROOT/'tmp').resolve())
OUT=BUILD/'art/reviews/v2_fire_maintenance_20261022/native';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BUILD/'art/blender/fire_maintenance_stock.blend'))
exports=bpy.data.collections['FireMaintenanceStock']
stocks=bpy.data.collections['EditableServiceStock']
checks=[]
for obj in stocks.objects:
    bm=bmesh.new();bm.from_mesh(obj.data)
    closed=all(edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    checks.append({'stock':obj.name,'closed':closed,'positive_volume':volume>1e-12})
assert all(row['closed'] and row['positive_volume'] for row in checks)
tin=stocks.objects['PressedGasketTin'];ring=stocks.objects['SpareUnionWasher']
bvh=BVHTree.FromPolygons([v.co for v in tin.data.vertices],[list(f.vertices) for f in tin.data.polygons])
bottom=min(v.co.z for v in ring.data.vertices);bearings=[]
for i in range(12):
    angle=i*math.tau/12;point=Vector((.0205*math.cos(angle),.0205*math.sin(angle),.012))
    hit=bvh.ray_cast(point,Vector((0,0,-1)),.02)[0]
    assert hit is not None and abs(hit.z-bottom)<.000001
    bearings.append({'angle':angle,'washer_bottom_m':bottom,'tin_support_m':hit.z})
bottle=stocks.objects['StonewareBottle']
inside=BVHTree.FromPolygons([v.co for v in bottle.data.vertices],[list(f.vertices) for f in bottle.data.polygons])
drain=inside.ray_cast(Vector((0,0,.19)),Vector((0,0,-1)),.20)[0]
assert drain is not None and abs(drain.z-.006)<.000001,'The cap must reveal an actual hollow mouth, not a sealed ceramic disc'
for name in ['Tin','Gasket']:exports.objects[name].location.x=.095
for name in ['TerminalShell','TerminalMetal','TerminalLever']:exports.objects[name].location.x=.23
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ServiceStockReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
bpy.ops.object.light_add(type='AREA',location=(.2,-.3,.5));bpy.context.object.data.energy=10;bpy.context.object.data.size=.4
bpy.ops.object.camera_add(location=(.30,-.47,.30));camera=bpy.context.object
camera.location=(.45,-.6,.4)
camera.rotation_euler=(Vector((.11,0,.085))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=.43;scene.camera=camera
scene.render.filepath=str(OUT/'stock_terminal.png');bpy.ops.render.render(write_still=True)
cap=exports.objects['Cap'];pivot=Vector((0,-.018,.171))
cap.matrix_world=Matrix.Translation(pivot)@Matrix.Rotation(1.9,4,'X')@Matrix.Translation(-pivot)
camera.location=(.23,.34,.42)
camera.rotation_euler=(Vector((0,0,.13))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=.23
scene.render.filepath=str(OUT/'bottle_open.png');bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','image':'stock_terminal.png','stocks':checks,
    'gasket_tin_bearings':bearings,'open_bottle_depth_m':.166-drain.z,'open_view':'bottle_open.png',
    'notes':'Blank paper label receives runtime Label3D lettering; no photograph baked. Native geometry checks are not runtime proof.'},indent=2)+'\n')
