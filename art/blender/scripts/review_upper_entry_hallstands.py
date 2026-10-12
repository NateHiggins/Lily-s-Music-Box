"""Review the two moved, unchanged native hallstands against their authored room.
Neutral context boxes are fitting envelopes, not new runtime assets.
"""
from pathlib import Path
import hashlib,json,math
import bpy
from mathutils import Matrix,Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/"game/project.godot").is_file())
OUT=ROOT/"tmp/v2-upper-entry-storage-20261011/blender";OUT.mkdir(parents=True,exist_ok=True)
layout=json.loads((ROOT/"game/data/orison_v2_blockout.json").read_text(encoding="utf-8"))
anchors={a["id"]:a for a in layout["anchors"]};spaces={s["id"]:s for s in layout["spaces"]};levels={l["id"]:l["y"] for l in layout["levels"]}
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/"art/blender/domestic_objects.blend"),link=False) as (source,dest):dest.objects=[n for n in source.objects if n.startswith("DomesticObject16__")]
native=dest.objects;assert native,"Native hallstand missing"
neutral=bpy.data.materials.new("Review-only neutral context");neutral.diffuse_color=(.38,.38,.36,1);neutral.use_nodes=True
rows=[]
def bp(v):return Vector((v[0],-v[2],v[1]))
def box(name,at,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=bp(at));obj=bpy.context.object;obj.name=name;obj.dimensions=(size[0],size[2],size[1]);obj.data.materials.append(neutral);return obj
for identity in ["5B_hallstand","6B_hallstand"]:
 for obj in list(bpy.context.scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
 a=anchors[identity];space=spaces[a["space"]];y=levels[a["level"]];rect=space["rect"]
 pose=Matrix.Translation(bp([a["position"][0],y,a["position"][2]]))@Matrix.Rotation(a["yaw"],4,"Z")
 points=[]
 for original in native:
  obj=original.copy();obj.data=original.data;bpy.context.scene.collection.objects.link(obj);obj.matrix_world=pose@original.matrix_world
  points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
 lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
 assert abs(lo[2]-y)<.00005,(identity,"floor bearing",lo[2],y)
 assert rect[0]<=lo[0] and hi[0]<=rect[2] and rect[1]<=-hi[1] and -lo[1]<=rect[3],(identity,"outside source room")
 box("Source floor",[(rect[0]+rect[2])/2,y-.06,(rect[1]+rect[3])/2],[rect[2]-rect[0],.12,rect[3]-rect[1]])
 box("Source east wall",[rect[2]+.06,y+1.5,(rect[1]+rect[3])/2],[.12,3,rect[3]-rect[1]])
 box("Source bath partition",[(rect[0]+rect[2])/2,y+1.5,rect[3]+.06],[rect[2]-rect[0],3,.12])
 # Door owner mounts at z+.08 with a 0.026 hinge setback; quarter-turn leaf.
 # This simple envelope illustrates the source opening, not fabricated door detail.
 box("Open entry leaf envelope",[-7.529,y+1.065,.68+.455],[.045,2.13,.91])
 bpy.ops.object.light_add(type="AREA",location=bp([-8.2,y+2.6,1.1]));bpy.context.object.data.energy=350;bpy.context.object.data.shape="DISK";bpy.context.object.data.size=3
 bpy.context.object.rotation_euler=(Vector(bp([-6.72,y+.9,2.65]))-bpy.context.object.location).to_track_quat("-Z","Y").to_euler()
 bpy.ops.object.camera_add(location=bp([-8.6,y+1.65,1.9]));camera=bpy.context.object;camera.rotation_euler=(bp([-6.72,y+.95,2.65])-camera.location).to_track_quat("-Z","Y").to_euler();camera.data.lens=30
 scene=bpy.context.scene;scene.camera=camera;scene.render.engine="CYCLES";scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.world=bpy.data.worlds.new("Review ambient");scene.world.color=(.15,.15,.15);scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(identity+".png"));bpy.ops.render.render(write_still=True)
 rows.append({"id":identity,"position":a["position"],"source_space":space["id"],"native_world_bounds":{"min":[lo[0],lo[2],-hi[1]],"max":[hi[0],hi[2],-lo[1]]},"floor_bearing":True,"inside_room":True,"open_leaf_to_stock_gap_m":(-hi[1])-(.68+.91)})
report={"evidence_class":"INERT","scope":"Two unchanged native variants at updated authored anchors; actual native bounds/floor bearing and rendered room/entry fitting envelopes. Real doorway collision, materials and walking must still pass in Godot.","installations":rows,"failures":[],"sources":{p:hashlib.sha256((ROOT/p).read_bytes().replace(b"\r\n",b"\n") if p.endswith(".json") else (ROOT/p).read_bytes()).hexdigest() for p in ["game/data/orison_v2_blockout.json","art/blender/domestic_objects.blend","game/assets/props/domestic_objects.glb"]}}
(OUT/"fit_review.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8",newline="\n")
print("UPPER HALLSTANDS: 2 installed native variants, zero fit failures")
