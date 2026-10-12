"""Review complete source-owned panel conduit, supported branch and riser join."""
from pathlib import Path
import json,math
import bpy
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/"tmp/v2-electrical-connections-20261011/blender";OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
plan=json.loads((ROOT/"art/data/electrical_service/connections_plan.json").read_text())
stocks={}
def library(path,names):
 with bpy.data.libraries.load(str(ROOT/path),link=False) as (a,b):b.objects=[n for n in a.objects if n in names]
 for o in b.objects:
  bpy.context.collection.objects.link(o);o.hide_render=True;stocks[o.name]=o
library("art/blender/electrical_service.blend",["ConduitUnit","ThreadedCoupling"])
library("art/blender/electrical_connections.blend",["FeedElbow","RiserFeedTee","UtilityEntryUnit","CeilingRodUnit","CeilingSeat","CeilingScrews"])
library("art/blender/domestic_objects.blend",["DomesticObject46__Body_ON_metal"])
cat=json.loads((ROOT/"game/data/runtime_material_sets.json").read_text())["materials"]
for key in ["iron_neutral","galvanized_roof","brass_dull"]:
 for mat in [m for m in bpy.data.materials if m.name.split(".")[0]==key]:
  p=mat.node_tree.nodes["Principled BSDF"];p.inputs["Metallic"].default_value=.65 if key=="brass_dull" else .75
  files=cat[key]["files"]
  if key=="brass_dull":files=["mailbank/T_mailbank_brass_albedo.png","mailbank/T_mailbank_brass_rough.png",files[2]]
  for i,socket in [(0,"Base Color"),(1,"Roughness"),(2,"Normal")]:
   t=mat.node_tree.nodes.new("ShaderNodeTexImage");t.image=bpy.data.images.load(str(ROOT/"game/assets/building/textures"/files[i]),check_existing=True)
   if i:t.image.colorspace_settings.name="Non-Color"
   if i==2:
    n=mat.node_tree.nodes.new("ShaderNodeNormalMap");n.inputs["Strength"].default_value=.15;mat.node_tree.links.new(t.outputs["Color"],n.inputs["Color"]);mat.node_tree.links.new(n.outputs["Normal"],p.inputs[socket])
   elif i==0 and key=="iron_neutral":
    n=mat.node_tree.nodes.new("ShaderNodeMixRGB");n.blend_type="MULTIPLY";n.inputs[0].default_value=1;n.inputs[2].default_value=(.35,.37,.39,1);mat.node_tree.links.new(t.outputs["Color"],n.inputs[1]);mat.node_tree.links.new(n.outputs[0],p.inputs[socket])
   else:mat.node_tree.links.new(t.outputs["Color"],p.inputs[socket])
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def draw(key,at,basis=Matrix.Identity(3),length=None):
 o=stocks[key].copy();o.data=o.data.copy();o.hide_render=False;bpy.context.collection.objects.link(o)
 if key!="DomesticObject46__Body_ON_metal":
  for uv in o.data.uv_layers.active.data:uv.uv/=.65
 if length is not None:
  for f in o.data.polygons:
   if abs(f.normal.z)<max(abs(f.normal.x),abs(f.normal.y)):
    for i in f.loop_indices:o.data.uv_layers.active.data[i].uv.y*=length
  for v in o.data.vertices:v.co.z*=length
 pose=basis.to_4x4();pose.translation=Vector(at);o.matrix_world=C@pose@C.inverted()@stocks[key].matrix_world
 return o
def span(a,b,key="ConduitUnit"):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();basis=Vector((0,1,0)).rotation_difference(axis).to_matrix();return draw(key,(a+b)*.5,basis,(b-a).length)
owner_basis=Matrix.Rotation(math.pi,3,"Y")
draw("DomesticObject46__Body_ON_metal",(7.6,-3.2,-6.21),owner_basis)
points=[Vector(p) for p in plan["route_corners"]];r=plan["bend_radius"];start=points[0]
for i in range(1,len(points)-1):
 incoming=(points[i]-points[i-1]).normalized();outgoing=(points[i+1]-points[i]).normalized()
 span(start,points[i]-incoming*r)
 basis=Matrix((outgoing,incoming,outgoing.cross(incoming))).transposed()
 draw("FeedElbow",points[i]-incoming*r,basis);start=points[i]+outgoing*r
span(start,points[-1]);draw("RiserFeedTee",plan["riser_tee"])
span((9.39,-1.23,1),(9.39,-.375,1));span((9.39,-.265,1),(9.39,.8,1))
span((7.6,-3.4,-6.17),(7.6,-3.2,-6.17),"UtilityEntryUnit")
for p in plan["ceiling_bearings"]:
 at=Vector(p);axis=Vector((0,0,1)) if at.x<8.1 else Vector((1,0,0));basis=Vector((0,1,0)).rotation_difference(axis).to_matrix()
 draw("ThreadedCoupling",(at.x,-.32,at.z),basis)
 span((at.x,-.291,at.z),(at.x,-.204,at.z),"CeilingRodUnit")
 draw("CeilingSeat",(at.x,-.202,at.z));draw("CeilingScrews",(at.x,-.202,at.z))
# Exact backing-box envelope from the retained basement owner; inspection
# proxy only, never exported or represented as accepted fuse apparatus.
bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector((7.6,-2.1,-6.18)));proxy=bpy.context.object;proxy.dimensions=(.66,.12,.90);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
proxy.data.materials.append(bpy.data.materials["iron_neutral"])
# Cutaway portions of the authored room shell retain the exact bearing planes.
wallmat=bpy.data.materials.new("Inspection retained shell");wallmat.use_nodes=True
p=wallmat.node_tree.nodes["Principled BSDF"];p.inputs["Roughness"].default_value=.8
for i,socket in [(0,"Base Color"),(1,"Roughness"),(2,"Normal")]:
 t=wallmat.node_tree.nodes.new("ShaderNodeTexImage");t.image=bpy.data.images.load(str(ROOT/"game/assets/building/textures"/cat["plaster_stained"]["files"][i]),check_existing=True)
 if i:t.image.colorspace_settings.name="Non-Color"
 if i==2:
  n=wallmat.node_tree.nodes.new("ShaderNodeNormalMap");n.inputs["Strength"].default_value=.15;wallmat.node_tree.links.new(t.outputs["Color"],n.inputs["Color"]);wallmat.node_tree.links.new(n.outputs["Normal"],p.inputs[socket])
 else:wallmat.node_tree.links.new(t.outputs["Color"],p.inputs[socket])
def shell(at,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(wallmat)
 uv=o.data.uv_layers.active
 for f in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(f.normal[i]));a,b=[(1,2),(0,2),(0,1)][axis]
  for i in f.loop_indices:
   v=o.data.vertices[o.data.loops[i].vertex_index].co;uv.data[i].uv=(v[a]/.65,v[b]/.65)
 return o
shell((7.45,-1.7,-6.3),(4.1,3,.14))
for port in plan["wall_ports"]:
 q=port["bounds"];z=(q[2]+q[5])*.5;o=shell((7.45,-.40,z),(4.1,.40,.14))
 bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector(((q[0]+q[3])*.5,(q[1]+q[4])*.5,z)));c=bpy.context.object;c.dimensions=(q[3]-q[0],q[5]-q[2],q[4]-q[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.view_layer.objects.active=o;m=o.modifiers.new("Authored wall port","BOOLEAN");m.operation="DIFFERENCE";m.object=c;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(c,do_unlink=True)
shell((7.92,-.10,-2.4),(.15,.20,6.6));shell((8.67,-.10,1.0),(1.3,.20,.15))
for at,power,size in [((8,-3,-.5),180,3),((6.5,-7,0),120,2)]:
 d=bpy.data.lights.new("Softbox","AREA");d.energy=power;d.size=size;o=bpy.data.objects.new("Softbox",d);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(C@Vector((7.9,-.7,-3))-o.location).to_track_quat("-Z","Y").to_euler()
d=bpy.data.cameras.new("Review");cam=bpy.data.objects.new("Review",d);bpy.context.collection.objects.link(cam)
s=bpy.context.scene;s.camera=cam;s.render.engine="CYCLES";s.cycles.samples=32;s.render.resolution_x=1200;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new("World");s.world.use_nodes=True;s.world.node_tree.nodes["Background"].inputs[0].default_value=(.10,.10,.10,1)
for label,at,target,scale in [("complete",(11,-7,3),(8.1,-1.2,-2.7),8.4),("panel_joint",(8.25,5.55,-.50),(7.65,-.6,-6.17),.52),("riser_joint",(10.2,-1.8,.6),(9.27,-.32,1),.48)]:
 cam.location=at;target=C@Vector(target);cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler();d.type="ORTHO";d.ortho_scale=scale;s.render.filepath=str(OUT/(label+".png"));bpy.ops.render.render(write_still=True)
