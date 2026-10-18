"""V2 moulded wall switch. Metres, Godot-facing -Z; no gameplay authority.
Run: blender -b -P art/blender/scripts/build_light_switch.py
"""
from pathlib import Path
import math,json,sys
import bpy,bmesh,numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material as stock_material,export
from fabrication_chart_batch import triangle_charts
from fabrication_normals import stock_corner_normals
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']

def p(v): return Vector((v[0], -v[2], v[1]))

def material(name, color, metal, rough):
    # Geometry retains its existing named material slots; runtime still owns
    # their resources. Native review now samples those same catalogue maps.
    return stock_material(ROOT,name,{'catalog_key':name,'normal':1. if name=='bakelite' else .35,
        'roughness':catalog[name]['roughness_multiplier'],'pigment':1.,'tint':[1,1,1]},catalog)

phenolic = material('bakelite', (.065,.041,.027), 0, .32)
nickel = material('nickel_plated', (.64,.63,.58), .82, .3)
ceramic = material('porcelain', (.85,.82,.72), 0, .22)
dark = material('rubber_aged', (.018,.015,.013), 0, .8)

def finish(o, name, mat, bevel=0):
    o.name = name
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Moulded edge radius', 'BEVEL')
        mod.width = bevel
        mod.segments = 4
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def box(name, at, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p(at))
    o = bpy.context.object
    o.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o,name,mat,bevel)

def cylinder(name, at, radius, depth, mat, bevel=.0007):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth, location=p(at))
    o = bpy.context.object
    o.rotation_euler.x = math.pi/2
    return finish(o,name,mat,bevel)

def cut(o, cutter):
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('Recess', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

# Back face matches the previous plate at z=-.008; no change to wall anchors.
box('BackingGasket',(0,0,-.009),(.116,.176,.002),dark,.001)
plate = box('MouldedPlate',(0,0,-.019),(.12,.18,.020),phenolic,.007)
slot = box('ToggleMortise',(0,0,-.032),(.018,.023,.021),dark,.005)
cut(plate,slot)
box('DarkSwitchThroat',(0,0,-.015),(.019,.039,.005),dark,.004)
for y in [-.063,.063]:
    pocket = cylinder('Counterbore',(0,y,-.030),.0065,.007,dark)
    cut(plate,pocket)
    head = cylinder('SlottedMountingScrew',(0,y,-.0275),.0054,.0025,nickel)
    slit = box('ScrewSlot',(0,y,-.029),(.0015,.009,.002),dark)
    cut(head,slit)
    box('SlotShadow',(0,y,-.0278),(.0012,.008,.0004),dark)
# Flanged nickel bushing, actual opening around the moving porcelain toggle.
collar = cylinder('ToggleCollar',(0,0,-.032),.014,.006,nickel)
cut(collar,cylinder('CollarBore',(0,0,-.032),.0095,.010,dark,0))
pivot = bpy.data.objects.new('TogglePivot',None)
bpy.context.collection.objects.link(pivot)
pivot.location = p((0,0,-.033))
stem = cylinder('NickelSpindle',(0,0,-.043),.005,.019,nickel)
grip = box('PorcelainToggle',(0,0,-.058),(.014,.017,.026),ceramic,.005)
for o in [stem,grip]:
    bpy.context.view_layer.update()
    transform = o.matrix_world.copy()
    o.parent = pivot
    o.matrix_world = transform

for o in list(bpy.context.scene.objects):
    if o.type != 'MESH': continue
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mesh=o.data;bm=bmesh.new();bm.from_mesh(mesh)
    # The old half-thickness bevel leaves subnanometre duplicate seams.
    # Weld those manufacturing-zero edges instead of exempting their charts.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    points=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([loop.vertex_index for loop in mesh.loops]).reshape((-1,3))
    _,us,charts,_=triangle_charts(points[indices],np.zeros(3),1.,np.broadcast_to(np.eye(3),(len(indices),3,3)),np.zeros(len(indices),dtype=bool))
    while mesh.uv_layers:mesh.uv_layers.remove(mesh.uv_layers[0])
    uv=mesh.uv_layers.new(name='Metres').data;uv.foreach_set('uv',charts.astype(np.float32).ravel())
    tile=catalog[mesh.materials[0].name]['meters_per_tile']
    for face in mesh.polygons:
        center=sum((uv[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
        shift=Vector((round(center.x/tile)*tile,round(center.y/tile)*tile))
        for i in face.loop_indices:uv[i].uv-=shift
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
    values=np.repeat(us[:,[0,2,1]],3,axis=0);values[:,2]*=-1;guide.data.foreach_set('vector',values.astype(np.float32).ravel())
    mesh.normals_split_custom_set(stock_corner_normals(mesh,planar_axes=[[1,0,0],[0,1,0],[0,0,1]]))
# Preserve individually editable fabrication pieces beside the runtime batch.
construction=bpy.data.collections.new('Closed construction');bpy.context.scene.collection.children.link(construction)
construction.hide_render=True;construction.hide_viewport=True
for o in list(bpy.context.scene.objects):
    if o.type!='MESH':continue
    original=o.matrix_world.copy();copy=o.copy();copy.data=o.data.copy();copy.name=o.name+'_Construction'
    copy.parent=None;construction.objects.link(copy);copy.matrix_world=original
# Keep the fabrication parts editable in the .blend; batch stationary hardware
# for the many installed instances. The toggle remains mechanically independent.
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type == 'MESH' and o.parent is None: o.select_set(True)
bpy.context.view_layer.objects.active = plate
bpy.ops.object.join()
print('LIGHT SWITCH',export(ROOT,'light_switch',bpy.context.scene.collection,material_names_only=True,staged_output=True),flush=True)
