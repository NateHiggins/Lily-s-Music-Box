from pathlib import Path
import ast,json,math
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/"tmp/v2-electrical-connections-20261011"
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={}
for key in ["iron_neutral","galvanized_roof","brass_dull"]:
 m=bpy.data.materials.new(key);m.use_nodes=True;materials[key]=m
source=ROOT/"art/blender/scripts/build_electrical_service.py"
tree=ast.parse(source.read_text(encoding="utf-8"))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {"point","cube","cylinder","cut","ring","finish","screw"}],type_ignores=[]),str(source),"exec"))
def union(o,c):
 bpy.context.view_layer.objects.active=o
 m=o.modifiers.new("Joined bored casting","BOOLEAN");m.operation="UNION";m.solver="EXACT";m.object=c
 bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(c,do_unlink=True);return o
def horizontal(radius,height,at):
 o=cylinder(radius,height,at);o.rotation_euler.y=math.pi*.5;return o
tee=union(cylinder(.0225,.11),horizontal(.0225,.12,(-.06,0,0)))
cut(tee,cylinder(.0185,.13));cut(tee,horizontal(.0185,.14,(-.07,0,0)))
finish("RiserFeedTee",[tee],"iron_neutral",.0003)
# Sweep starts at the origin along +Y and turns to +X at radius .12.
centres=[Vector((.12*(1-math.cos(t)),.12*math.sin(t),0)) for t in [i*math.pi/2/24 for i in range(25)]]
verts=[];n=32;length=len(centres)
for r in [.0225,.0185]:
 for i,c in enumerate(centres):
  angle=i*math.pi/2/24;tangent=Vector((math.sin(angle),math.cos(angle),0))
  radial=tangent.cross(Vector((0,0,1))).normalized()
  for j in range(n):
   a=j*math.tau/n;verts.append(point(c+r*(radial*math.cos(a)+Vector((0,0,1))*math.sin(a))))
faces=[]
for k in range(2):
 for i in range(length-1):
  for j in range(n):
   a=k*length*n+i*n+j;b=k*length*n+i*n+(j+1)%n
   face=(a,b,b+n,a+n);faces.append(face if k==0 else tuple(reversed(face)))
for end in [0,length-1]:
 for j in range(n):
  a=end*n+j;b=end*n+(j+1)%n;c=length*n+b;d=length*n+a
  face=(a,d,c,b);faces.append(face if end==0 else tuple(reversed(face)))
mesh=bpy.data.meshes.new("Quarter bend");mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new("Quarter bend",mesh);bpy.context.collection.objects.link(o)
for f in mesh.polygons:f.use_smooth=len(faces)-f.index>n*2
finish("FeedElbow",[o],"galvanized_roof",.0002)
finish("UtilityEntryUnit",[ring(.016,.0125,1)],"galvanized_roof",.0002)
finish("CeilingRodUnit",[cylinder(.0035,1)],"iron_neutral",.00015)
finish("CeilingSeat",[cube((.06,.004,.06))],"iron_neutral",.0004)
heads=[]
for x in [-.02,.02]:
 head=cylinder(.0035,.003,(x,-.0035,0));cut(head,cube((.0045,.004,.0008),(x,-.005,0)));heads.append(head)
finish("CeilingScrews",heads,"brass_dull",.00015)
rows=[]
for o in bpy.context.scene.objects:
 if o.type!="MESH":continue
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data)
 manifold=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
 bad=0
 for f in o.data.polygons:
  q=[Vector(o.data.uv_layers.active.data[i].uv) for i in f.loop_indices]
  if abs((q[1]-q[0]).cross(q[2]-q[0]))<1e-13:bad+=1
 row={"name":o.name,"triangles":len(o.data.polygons),"manifold":manifold,"volume":volume,"degenerate_uv":bad};rows.append(row)
 assert manifold and volume>0 and bad==0,row
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/blender/electrical_connections.blend"))
bpy.ops.export_scene.gltf(filepath=str(ROOT/"game/assets/props/electrical_connections.glb"),export_format="GLB",export_apply=True,export_lights=False,export_cameras=False)
(OUT/"stock-uv.json").write_text(json.dumps({"evidence_class":"INERT","stocks":rows},indent=2)+"\n",newline="\n")
print("CONNECTION STOCK",len(rows),sum(r["triangles"] for r in rows))
