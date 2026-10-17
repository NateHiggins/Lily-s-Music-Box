"""Native workshop insert rack: five blind pockets and wall-borne supports.

Unlettered timber and steel; runtime Label3D owns the inventory lettering.
"""
from pathlib import Path
import json, math, sys
import bpy, bmesh
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-radiator-polish-20261017'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']

def box(name,size,at):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj

def cut(obj,tool,operation='DIFFERENCE'):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Machined joint','BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool,do_unlink=True)

def finish(obj,width):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Worked edge radius','BEVEL');mod.width=width;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-8)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
    bm.to_mesh(obj.data);bm.free()

tray=box('Five blind insert sockets',(.34,.16,.012),(0,0,-.006))
for index in range(5):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0033,depth=.010,location=((index-2)*.06,0,-.004))
    cut(tray,bpy.context.object)
board=box('Workshop rack backboard',(.34,.012,.112),(0,.074,.044))
wood=[tray,board]
steel=[]
for x in [-.14,.14]:
    brace=box('Continuous shelf angle',(.014,.14,.006),(x,.012,-.015))
    cut(brace,box('Vertical angle leg',(.014,.006,.082),(x,.083,.023)),'UNION')
    cut(brace,box('Wall standoff',(.014,.020,.032),(x,.090,.045)),'UNION')
    steel.append(brace)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.0017,depth=.035,location=(x,.0845,.045),rotation=(math.pi/2,0,0))
    shank=bpy.context.object;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);steel.append(shank)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.0045,depth=.005,location=(x,.0655,.045),rotation=(math.pi/2,0,0))
    screw=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    cut(screw,box('Driver slot',(.006,.002,.0012),(x,.0635,.045)))
    steel.append(screw)
for obj in wood:finish(obj,.0003)
for obj in steel:finish(obj,.0002)
exports=bpy.data.collections.new('Runtime workshop stock');bpy.context.scene.collection.children.link(exports)
for key,objects,tint in [('timber',wood,[.50,.43,.34]),('iron_neutral',steel,[.65,.65,.65])]:
    spec=dict(catalog_key=key,normal=.35,roughness=1.,pigment=1.,tint=tint)
    mat=material(ROOT,'CATALOG_'+key,spec,catalog)
    partition(exports,'Rack_'+key,objects,spec,mat,Matrix.Identity(4),catalog)
for obj in wood+steel:bpy.data.objects.remove(obj,do_unlink=True)
report=export(ROOT,'radiator_service_stock',exports)
(OUT/'service_stock_native.json').write_text(json.dumps(report,indent=2)+'\n')
print('WORKSHOP INSERT RACK',report,flush=True)
