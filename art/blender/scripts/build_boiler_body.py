"""Original boiler casing with open firing/ash throats and retained controls.

Dimensions and material roles follow BoilerProp. All coordinates below are
Godot-local metres; export uses the usual (x,-z,y) Blender conversion.
BoilerProp owns the moving leaves, heat, water column, draft and saves.
"""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
W, D = 1.16, 1.02
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
roles = {'Iron': (.20,.19,.18), 'Jacket': (.66,.63,.54),
         'Steel': (.34,.33,.31), 'Soot': (.09,.085,.08),
         'Lining': (.39,.19,.12), 'Hearth': (.42,.40,.37), 'LiveCoal': (.09,.085,.08)}
materials = {}
for name,color in roles.items():
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.75
    materials[name]=mat

def box(name,at,size,role=None,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    obj=bpy.context.object; obj.name=name
    obj.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if role: obj.data.materials.append(materials[role])
    if bevel: soften(obj,bevel)
    return obj

def soften(obj,width):
    bpy.context.view_layer.objects.active=obj
    bevel=obj.modifiers.new('Cast edge','BEVEL'); bevel.width=width; bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)

def cut(obj,cutter):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Open service throat','BOOLEAN')
    mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)

def cyl(name,at,radius,length,role,axis=(0,1,0),sides=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=length,
        location=(at[0],-at[2],at[1]))
    obj=bpy.context.object; obj.name=name
    obj.rotation_euler=Vector((axis[0],-axis[2],axis[1])).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    obj.data.materials.append(materials[role]); soften(obj,.001)
    return obj

# Cavities cut through every casing layer, stopping at the original hot block.
cutters=[box('FireThroatCut',(0,1.04,-.48),(.56,.37,.74)),
         box('AshThroatCut',(0,.43,-.48),(.48,.18,.74))]
box('Hearth',(0,.05,-.10),(W+.28,.10,D+.40),'Hearth',.006)
box('LowerCasting',(0,.21,0),(W,.22,D),'Iron',.005)
for i in range(5):
    casting=box('HeatingSection',(-.46+i*.23,.94,0),(.205,1.28,D),'Iron')
    for cutter in cutters: cut(casting,cutter)
    soften(casting,.003)

# The jacket is an actual shallow shell, not a block in the firebox.
jacket=box('LaggingJacket',(0,1,0),(W+.065,1.12,D+.065),'Jacket')
void=box('JacketInside',(0,1,0),(W+.013,1.068,D+.013))
cut(jacket,void); bpy.data.objects.remove(void,do_unlink=True)
for cutter in cutters: cut(jacket,cutter)
soften(jacket,.002)

# Retaining straps have a hollow centre and return round all four faces.
for y in [.56,.94,1.32]:
    strap=box('RetainingStrap',(0,y,0),(W+.09,.035,D+.09),'Steel')
    void=box('StrapInside',(0,y,0),(W+.068,.05,D+.068))
    cut(strap,void); bpy.data.objects.remove(void,do_unlink=True)
    for cutter in cutters: cut(strap,cutter)
    soften(strap,.001)

# Cast surrounds sit behind the existing moving plate, with a small seat gap.
for name,y,width,height in [('FiringSeat',1.04,.64,.415),('AshSeat',.43,.56,.25)]:
    frame=box(name,(0,y,-.53),(width,height,.045),'Iron')
    for cutter in cutters: cut(frame,cutter)
    soften(frame,.002)
for cutter in cutters: bpy.data.objects.remove(cutter,do_unlink=True)

# The firebrick lining has joints, a recessed back and a supported grate.
# No plate closes the mouth; the cavity remains visible from normal eye height.
for side in [-1,1]:
    for row in range(3):
        for depth in range(2):
            box('FirebrickCheek',(side*.269,.855+(row+.5)*.37/3,-.44+depth*.205),
                (.022,.37/3-.004,.20),'Lining',.001)
    box('GrateBearer',(side*.244,.845,-.32),(.027,.025,.38),'Iron',.001)
for row in range(3):
    for col in range(3):
        box('FirebrickBack',(-.18+col*.18,.855+(row+.5)*.37/3,-.12),
            (.176,.37/3-.004,.025),'Lining',.001)
box('FirebrickSoffit',(0,1.214,-.32),(.52,.022,.38),'Lining',.001)
for i in range(7):
    # Bars lie inside the throat, not through the closed door and into the aisle.
    box('GrateBar',(-.228+i*.076,.861,-.32),(.024,.018,.36),'Iron',.003)

# Ash pit and removable tray: real side returns, low front lip and back wall.
box('AshBack',(0,.43,-.12),(.47,.17,.025),'Soot',.001)
box('AshTray',(0,.347,-.32),(.448,.014,.36),'Steel',.002)
for side in [-1,1]:
    box('AshTraySide',(side*.221,.37,-.32),(.012,.045,.36),'Steel',.001)
    box('AshPitCheek',(side*.236,.43,-.32),(.008,.17,.38),'Iron',.001)
box('AshTrayLip',(0,.365,-.495),(.448,.038,.012),'Steel',.001)
box('AshPitRoof',(0,.516,-.32),(.47,.008,.38),'Iron')

# Tension ties and nuts retain the sectioned silhouette, clear of both mouths.
for y in [.29,1.48]:
    cyl('TieRod',(0,y,-.525),.018,1.25,'Steel',axis=(1,0,0))
    for side in [-1,1]:
        cyl('TieNut',(side*.611,y,-.525),.039,.027,'Iron',axis=(1,0,0),sides=6)
for side in [-1,1]:
    for y in [.56,.94,1.32]:
        cyl('StrapFastener',(side*.56,y,-.562),.010,.012,'Steel',axis=(0,0,1),sides=6)
box('RepairPatch',(-.45,.78,-.55),(.22,.22,.012),'Soot',.001)
box('SootAboveMouth',(.06,1.37,-.557),(.50,.22,.008),'Soot',.001)

# An independent irregular bed keeps the runtime heat material out of batching.
# Its bottoms rest on the bars; staggered lumps leave small views of the grate.
rng=random.Random(2941)
for row in range(3):
    for col in range(8):
        x=-.20+col*.057+rng.uniform(-.007,.007)
        z=-.405+row*.080+rng.uniform(-.009,.009)
        height=rng.uniform(.040,.063)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,
            location=(x,-z,.870+height*.5))
        coal=bpy.context.object; coal.name='CoalLump'
        for vertex in coal.data.vertices:
            vertex.co*=rng.uniform(.85,1.15)
        coal.scale=(rng.uniform(.029,.036),rng.uniform(.039,.046),height*.5)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        coal.data.materials.append(materials['LiveCoal'])

# Editable metre box UVs prepare every face for the existing mapping pipeline.
for obj in list(bpy.context.scene.objects):
    uv=obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        normal=poly.normal
        axis=max(range(3),key=lambda i:abs(normal[i]))
        axes=((1,2),(0,2),(0,1))[axis]
        for loop in poly.loop_indices:
            p=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p[axes[0]],p[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/boiler_body.blend'))
# One exported mesh per established finish role, with transforms baked.
for role in materials:
    bpy.ops.object.select_all(action='DESELECT')
    parts=[o for o in bpy.context.scene.objects if o.data.materials[0]==materials[role]]
    if not parts: continue
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=role
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/boiler_body.glb'),
    export_format='GLB',export_yup=True,export_apply=True)
