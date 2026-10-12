"""Native metre-charted timber storage partitions and retained open gate fabric."""
from pathlib import Path
import ast,json,math,hashlib
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/"tmp/v2-basement-storage-20261011";OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={}
for key in ["timber","iron_neutral"]:
 m=bpy.data.materials.new(key);m.use_nodes=True;materials[key]=m
helper=ROOT/"art/blender/scripts/build_electrical_service.py"
tree=ast.parse(helper.read_text(encoding="utf-8"))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {"point","cube","cylinder"}],type_ignores=[]),str(helper),"exec"))
stocks=[]
def stock(name,size,at,key,long_axis=None):
 o=cube(size,at);o.name=name;bpy.context.view_layer.objects.active=o
 bevel=o.modifiers.new("Stock eased edges","BEVEL");bevel.width=.001 if key=="timber" else .00035;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name)
 tri=o.modifiers.new("Stable stock charts","TRIANGULATE");bpy.ops.object.modifier_apply(modifier=tri.name)
 for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
 uv=o.data.uv_layers.new(name="MetreGrain")
 # Chart individual members before joining, so rails keep grain along their length.
 main=max(range(3),key=lambda i:size[i]) if long_axis is None else long_axis
 main=[0,2,1][main] # Godot X/Y/Z -> Blender X/Z/Y.
 for face in o.data.polygons:
  normal=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=normal]
  v=main if main in axes else axes[1];u=next(i for i in axes if i!=v)
  for loop in face.loop_indices:
   p=o.data.vertices[o.data.loops[loop].vertex_index].co
   uv.data[loop].uv=(p[v],p[u])
 o.data.materials.clear();o.data.materials.append(materials[key]);stocks.append(o);return o

def assembly(name,length,gate=False):
 start=len(stocks)
 ends=[] if name=="BayBack" else [length] if name=="FrontLeft" else [0] if name=="FrontRight" else [0,length]
 for x in ends:stock(name+"_Stile",(.06,1.996,.06),(x,1.002,0),"timber",1)
 for y in [.14,1.86]:stock(name+"_Rail",(length,.08,.045),(length*.5,y,0),"timber",0)
 divisions=max(2,int(math.ceil(length/.16)))
 for i in range(1,divisions):stock(name+"_Picket",(.035,1.8,.025),(i*length/divisions,1,0),"timber",1)
 if gate:
  # Diagonal ledge brace has its own member chart, preserving longitudinal grain.
  a=Vector((.08,.23,0));b=Vector((length-.08,1.77,0));d=b-a
  brace=stock(name+"_Brace",(.05,d.length,.025),tuple((a+b)*.5),"timber",1)
  brace.rotation_euler=Vector(point(d)).to_track_quat("Z","Y").to_euler()
  for y in [.30,1.70]:
   stock(name+"_HingeLeaf",(.085,.09,.006),(.025,y,-.033),"iron_neutral")
   barrel=cylinder(.0075,.085,(0,y,-.045));barrel.name=name+"_HingeBarrel"
   barrel.data.materials.append(materials["iron_neutral"])
   uv=barrel.data.uv_layers.active;uv.name="MetreGrain"
   # Cylinders already carry usable parametric charts; physical scale is explicit.
   for face in barrel.data.polygons:
    if abs(face.normal.z)>.5:
     for loop in face.loop_indices:
      q=barrel.data.vertices[barrel.data.loops[loop].vertex_index].co;uv.data[loop].uv=(q.x,q.y)
    else:
     values=[]
     for loop in face.loop_indices:
      q=barrel.data.vertices[barrel.data.loops[loop].vertex_index].co;values.append((loop,(math.atan2(q.y,q.x)+math.pi)/(2*math.pi),q.z))
     wrap=max(v[1] for v in values)-min(v[1] for v in values)>.5
     for loop,u,v in values:uv.data[loop].uv=((u-1 if wrap and u>.5 else u)*math.tau*.0075,v)
   stocks.append(barrel)
 else:
  for x in ends:
   stock(name+"_FloorSeat",(.09,.004,.09),(x,.002,0),"iron_neutral")
   for offset in [-.034,.034]:stock(name+"_SeatFastener",(.007,.003,.007),(x+offset,.0055,0),"iron_neutral")
 groups={key:[o for o in stocks[start:] if o.data.materials[0].name==key] for key in materials}
 if name=="BayBack":
  for x in [.025,length-.025]:
   for y in [.14,1.86]:stock(name+"_RailFastener",(.006,.006,.003),(x,y,-.024),"iron_neutral")
 groups={key:[o for o in stocks[start:] if o.data.materials[0].name==key] for key in materials}
 for key,objects in groups.items():
  bpy.ops.object.select_all(action="DESELECT")
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();joined=bpy.context.object;joined.name=name+"__"+key
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  tri=joined.modifiers.new("Final triangles","TRIANGULATE");bpy.ops.object.modifier_apply(modifier=tri.name)
  bm=bmesh.new();bm.from_mesh(joined.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(joined.data);bm.free()
  # The source objects stay closed individual stocks; touching lap joints are intentional.
  joined["source_partition"]=name;joined["material_key"]=key
for name,length,gate in [("DepthPanel",2.16,False),("BayBack",1.56,False),("FrontLeft",.15,False),("FrontRight",.10,False),("OpenGate",1.04,True)]:assembly(name,length,gate)
rows=[]
for o in bpy.context.scene.objects:
 if o.type!="MESH":continue
 bad=0
 for face in o.data.polygons:
  q=[Vector(o.data.uv_layers.active.data[i].uv) for i in face.loop_indices]
  if abs((q[1]-q[0]).cross(q[2]-q[0]))<1e-13:
   bad+=1
   if bad<3:print("UV DEBUG",o.name,list(face.normal),[list(v) for v in q],[list(o.data.vertices[i].co) for i in face.vertices])
 assert bad==0,(o.name,bad)
 rows.append({"name":o.name,"partition":o["source_partition"],"key":o["material_key"],"triangles":len(o.data.polygons),"degenerate_uv":bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/blender/resident_storage.blend"))
bpy.ops.export_scene.gltf(filepath=str(ROOT/"game/assets/props/resident_storage.glb"),export_format="GLB",export_apply=True,export_lights=False,export_cameras=False)
report={"evidence_class":"INERT","asset_sha256":hashlib.sha256((ROOT/"game/assets/props/resident_storage.glb").read_bytes()).hexdigest(),"parts":rows,"scope":"Source-owned partition/gate stock with actual longitudinal metre charts and zero collapsed triangle charts. Context, material/render and gameplay checks remain required."}
(OUT/"native_stock.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8",newline="\n")
