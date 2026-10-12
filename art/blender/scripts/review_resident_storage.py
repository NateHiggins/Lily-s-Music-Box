"""Review all eighteen bays, protected aisles, shaft and retained native stock."""
from pathlib import Path
import json,math,hashlib
import bpy
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/"tmp/v2-basement-storage-20261011";OUT.mkdir(parents=True,exist_ok=True)
plan=json.loads((ROOT/"art/data/resident_storage/source_plan.json").read_text(encoding="utf-8"));catalog=json.loads((ROOT/"game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
bpy.ops.wm.read_factory_settings(use_empty=True)
def bp(v):return Vector((v[0],-v[2],v[1]))
def mapped(material):
 spec=catalog[material.name];material.use_nodes=True;nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get("Principled BSDF")
 coordinates=nodes.new("ShaderNodeTexCoord");scale=nodes.new("ShaderNodeVectorMath");scale.operation="SCALE";scale.inputs[3].default_value=1/spec["meters_per_tile"];links.new(coordinates.outputs["UV"],scale.inputs[0])
 images=[]
 for index,file in enumerate(spec["files"]):
  texture=nodes.new("ShaderNodeTexImage");texture.image=bpy.data.images.load(str(ROOT/"game/assets/building/textures"/file),check_existing=True)
  if index>0:texture.image.colorspace_settings.name="Non-Color"
  links.new(scale.outputs["Vector"],texture.inputs["Vector"]);images.append(texture)
 links.new(images[0].outputs["Color"],bsdf.inputs["Base Color"]);links.new(images[1].outputs["Color"],bsdf.inputs["Roughness"])
 normal=nodes.new("ShaderNodeNormalMap");normal.inputs["Strength"].default_value=.35;links.new(images[2].outputs["Color"],normal.inputs["Color"]);links.new(normal.outputs["Normal"],bsdf.inputs["Normal"]);bsdf.inputs["Metallic"].default_value=spec["metallic"]
with bpy.data.libraries.load(str(ROOT/"art/blender/resident_storage.blend"),link=False) as (source,dest):dest.objects=list(source.objects)
modules={o.name:o for o in dest.objects};assert len(modules)==10
for material in {m for o in modules.values() for m in o.data.materials}:mapped(material)
instances=[];placements=set()
def draw(part,x,z,angle,unit):
 signature=(part,round(x,6),round(z,6),round(angle,6))
 if signature in placements:return
 placements.add(signature)
 pose=Matrix.Translation(bp([x,-3.2,z]))@Matrix.Rotation(angle,4,"Z")
 for key in ["timber","iron_neutral"]:
  original=modules[part+"__"+key];obj=original.copy();obj.data=original.data;bpy.context.scene.collection.objects.link(obj);obj.name=unit+"_"+original.name;obj.matrix_world=pose@original.matrix_world;instances.append({"name":obj.name,"part":part,"key":key,"position":[x,0,z],"yaw":angle,"unit":unit})
for bay in plan["bays"]:
 for x in [bay["left"],bay["right"]]:draw("DepthPanel",x,min(bay["rear"],bay["front"]),-math.pi*.5,bay["unit"])
 draw("BayBack",bay["left"],bay["rear"],0,bay["unit"])
 draw("FrontLeft",bay["left"],bay["front"],0,bay["unit"])
 draw("FrontRight",bay["right"]-.1,bay["front"],0,bay["unit"])
 draw("OpenGate",bay["left"]+.085,bay["front"],math.pi*.5 if bay["row"]=="south" else -math.pi*.5,bay["unit"])
# Retain source models, identities and kind; fit their actual native extents to each bay.
family=json.loads((ROOT/"game/data/orison_v2/domestic_objects.json").read_text(encoding="utf-8"));variants={r["id"]:r["variant"] for r in family["instances"]}
with bpy.data.libraries.load(str(ROOT/"art/blender/domestic_objects.blend"),link=False) as (source,dest):dest.objects=[name for name in source.objects if any(name.startswith(variants[s["id"]]+"__") for s in plan["stock"])]
stock_objects=dest.objects;stock_checks=[]
for stock in plan["stock"]:
 bay=next(b for b in plan["bays"] if b["unit"]==stock["unit"]);objects=[o for o in stock_objects if o.name.startswith(variants[stock["id"]]+"__")]
 assert objects,stock["id"]
 if bay["row"]=="alcove":stock["yaw"]=0
 rotation=Matrix.Rotation(stock["yaw"],4,"Z");vertices=[rotation@o.matrix_world@v.co for o in objects for v in o.data.vertices]
 low=min(-v.y for v in vertices);high=max(-v.y for v in vertices)
 stock["position"][2]=round(bay["rear"]+.05-low if bay["row"]=="south" else bay["rear"]-.05-high,6)
 pose=Matrix.Translation(bp([stock["position"][0],-3.2,stock["position"][2]]))@rotation
 points=[]
 for original in objects:
  obj=original.copy();obj.data=original.data;bpy.context.scene.collection.objects.link(obj);obj.name=stock["id"]+"_"+original.name;obj.matrix_world=pose@original.matrix_world;points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
 bounds={"left":min(v.x for v in points),"right":max(v.x for v in points),"south":min(-v.y for v in points),"north":max(-v.y for v in points),"floor":min(v.z for v in points)}
 assert bounds["left"]>=bay["left"]+.03 and bounds["right"]<=bay["right"]-.03,(stock["id"],"side clearance",bounds)
 assert min(bay["rear"],bay["front"])+.03<=bounds["south"] and bounds["north"]<=max(bay["rear"],bay["front"])-.03,(stock["id"],"depth clearance",bounds)
 assert abs(bounds["floor"]+3.2)<.00006,(stock["id"],"floor bearing",bounds)
 stock_checks.append({"id":stock["id"],"unit":stock["unit"],"native_bounds":bounds,"inside_bay":True,"floor_bearing":True})
# Neutral physical context envelopes; they are not newly authored runtime surfaces.
neutral=bpy.data.materials.new("Review neutral context");neutral.diffuse_color=(.34,.34,.32,1)
def context(name,center,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=bp(center));obj=bpy.context.object;obj.name=name;obj.dimensions=(size[0],size[2],size[1]);obj.data.materials.append(neutral)
context("Existing storage floor",[-2.3,-3.26,6.675],[15.4,.12,5.65]);context("North bay floor",[4.425,-3.26,10.675],[1.95,.12,2.35])
context("Protected wet stack",[-6.175,-1.7,4.725],[.45,3,3.25])
context("Existing east wall",[5.4,-1.7,6.675],[.12,3,5.65])
context("Existing south wall",[-2.3,-1.7,3.85],[15.4,3,.12])
# Native stock is unchanged; current module material maps are reviewed in neutral light.
bpy.ops.object.light_add(type="AREA",location=bp([-2.3,3,6.675]));light=bpy.context.object;light.data.energy=1600;light.data.size=12
light.rotation_euler=(bp([-2.3,-3.2,6.675])-light.location).to_track_quat("-Z","Y").to_euler()
scene=bpy.context.scene;scene.world=bpy.data.worlds.new("Review ambient");scene.world.color=(.18,.18,.18);scene.render.engine="CYCLES";scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera
for name,at,target,lens in [("storage_overview",[-1.6,8,14.5],[-2.3,-2.2,6.9],29),("storage_aisle",[4.4,-1.7,6.675],[-5,-2.1,6.675],24),("storage_north_bay",[4.4,-1.7,8.75],[4.4,-2.2,10.8],28)]:
 camera.location=bp(at);camera.rotation_euler=(bp(target)-camera.location).to_track_quat("-Z","Y").to_euler();camera.data.lens=lens;scene.render.filepath=str(OUT/(name+".png"));bpy.ops.render.render(write_still=True)
plan["instances"]=instances;plan["stock_fit_review"]=stock_checks
(ROOT/"art/data/resident_storage/source_plan.json").write_text(json.dumps(plan,indent=2)+"\n",encoding="utf-8",newline="\n")
(OUT/"context_review.json").write_text(json.dumps({"evidence_class":"INERT","bays":18,"stock_checks":stock_checks,"clearances":plan["clearances"],"failures":[],"scope":"Actual native stock bounds, fixed-panel dimensions and rendered layout. Stock collision/gate swing/path and final installed room must still pass Godot."},indent=2)+"\n",encoding="utf-8",newline="\n")
print("STORAGE CONTEXT: 18 bays; 16 native stock poses; all floor/bay bounds pass")
