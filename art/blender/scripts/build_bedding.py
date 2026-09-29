"""Blender bedding library, preserving authored frame meshes and three bed sizes."""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mats={}
for name,color in {'Frame':(.3,.19,.1),'Mattress':(.78,.74,.62),'Blanket':(.27,.31,.36),'Pillows':(.79,.75,.65)}.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);mats[name]=m

def point(v):return (v[0],-v[2],v[1])
def mesh(name,verts,faces,owner,role):
 data=bpy.data.meshes.new(name);data.from_pydata([point(v) for v in verts],[],faces);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.parent=owner;obj.data.materials.append(mats[role]);return obj

def box(name,at,size,owner,role,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(at));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=owner;o.data.materials.append(mats[role])
 if bevel:
  mod=o.modifiers.new('Upholstered edge','BEVEL');mod.width=bevel;mod.segments=4;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def sheet(name,owner,W,L,fold=False):
 nx,nz=40,(12 if fold else 30);vertices=[];faces=[];head=-L/2+.68;foot=L/2-.14
 for j in range(nz+1):
  v=j/nz
  if fold:z=head+v*.135;foot_y=.516
  elif v<=.88:z=head+(foot-head)*v/.88;foot_y=.511
  elif v<=.94:
   a=(v-.88)/.06*math.pi/2;z=foot+.035*math.sin(a);foot_y=.511-.035*(1-math.cos(a))
  else:z=foot+.035;foot_y=.476-.105*(v-.94)/.06
  for i in range(nx+1):
   u=i/nx*2-1;t=abs(u);edge=W/2-.073
   if t<=.85:x=t/.85*edge;y=.511
   elif t<=.94:
    a=(t-.85)/.09*math.pi/2;x=edge+.035*math.sin(a);y=.511-.035*(1-math.cos(a))
   else:x=edge+.035;y=.476-.105*(t-.94)/.06
   x*=1 if u>=0 else -1
   y=min(y,foot_y)+.003*math.sin(x*37+z*5)*math.sin(z*19)+.002*math.sin(x*14-z*8)
   if fold:y+=.009+.007*math.sin(v*math.pi)
   vertices.append((x,y,-z))
 for j in range(nz):
  for i in range(nx):
   k=j*(nx+1)+i;faces.append((k,k+1,k+nx+2,k+nx+1))
 o=mesh(name,vertices,faces,owner,'Blanket');bpy.context.view_layer.objects.active=o
 m=o.modifiers.new('Woven thickness','SOLIDIFY');m.thickness=.004;m.offset=0;bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons:p.use_smooth=True

records=json.loads((ROOT/'art/data/orison_v2/domestic_furniture_source.json').read_text(encoding='utf-8'))['furniture'];owners=[];seen=set()
for record in records:
 if record['kind']!='bed':continue
 W=round(record['bounds'][1][0]-record['bounds'][0][0],3);L=round(record['bounds'][1][2]-record['bounds'][0][2],3)
 if (W,L) in seen:continue
 seen.add((W,L));owner=bpy.data.objects.new('Bed_%d_%d'%(round(W*100),round(L*100)),None);bpy.context.collection.objects.link(owner);owners.append(owner)
 frame=next(s for s in record['surfaces'] if s['material'] in ['wood_dark','oak_quartered'])
 vs=[frame['vertices'][i:i+3] for i in range(0,len(frame['vertices']),3)]
 mesh('AuthoredFrame',vs,[tuple(range(i,i+3)) for i in range(0,len(vs),3)],owner,'Frame')
 for j in range(11):box('MattressSlat',(0,.316,-L/2+.16+j*(L-.32)/10),(W-.084,.026,.075),owner,'Frame',.003)
 box('TickingMattress',(0,.415,0),(W-.12,.17,L-.16),owner,'Mattress',.033)
 sheet('DrapedBlanket',owner,W,L);sheet('Turnback',owner,W,L,True)
 for side in [-1,1]:
  vertices=[];faces=[];rings=16;n=40
  for j in range(rings+1):
   latitude=-math.pi/2+j*math.pi/rings;r=math.cos(latitude);y=.557+.053*math.sin(latitude)
   for i in range(n):
    a=i*math.tau/n;c=math.cos(a);s=math.sin(a)
    x=side*.29+math.copysign(abs(c)**.55,c)*.285*r;z=-L/2+.33+math.copysign(abs(s)**.55,s)*.18*r
    vertices.append((x,y+.003*math.sin(a*4)*r*r,-z))
  for j in range(rings):
   for i in range(n):k=j*n+i;q=j*n+(i+1)%n;faces.append((k,q,q+n,k+n))
  o=mesh('PuffedPillow',vertices,faces,owner,'Pillows')
  for p in o.data.polygons:p.use_smooth=True
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 uv=o.data.uv_layers.new(name='UVMap')
 for p in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
  for loop in p.loop_indices:
   v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bedding.blend'))
for owner in owners:
 for role,mat in mats.items():
  parts=[o for o in owner.children if o.type=='MESH' and o.data.materials[0]==mat]
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=owner.name+'_'+role;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/bedding.glb'),export_format='GLB',export_yup=True,export_apply=True)
