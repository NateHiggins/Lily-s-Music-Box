"""Period-informed rigid airship for the owner's growing alternate-history trade.

No photograph pixels, lettering, engines, lights or gameplay states exported.
Shared metre charts, closed stock, custom normals and explicit tangent export.
Nose Blender +X; glTF +Y is up. Adaptation, not an LZ 127 replica.
"""
from pathlib import Path
import sys,json,math,hashlib
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from fabrication_chart_batch import revolved_charts
import build_v2_period_traffic as kit

FINISHES={
 'linen':{'catalog_key':'linen','tint':[.83,.84,.79,1.],'normal':.22,'roughness':.9,'pigment':1.},
 'frame':{'catalog_key':'nickel_plated','tint':[.68,.71,.70,1.],'normal':.3,'roughness':.8,'pigment':1.},
 'iron':{'catalog_key':'iron_blackened','tint':[.6,.63,.65,1.],'normal':.5,'roughness':1.,'pigment':1.},
 'window':{'catalog_key':'mirror_aged','tint':[.14,.22,.25,1.],'normal':.12,'roughness':.55,'pigment':1.},
 'timber':{'catalog_key':'wood_dark','tint':[.9,.8,.7,1.],'normal':.4,'roughness':1.,'pigment':1.}}
# Fictional Queens passenger liner, informed by the external-gondola layout of
# the contemporary Graf Zeppelin. Reduced to 168 m for this local service.
LENGTH=168.;RADIUS=12.;PODS=[(-12.,-12.8,-10.2),(27.,-12.8,-10.2),(-12.,12.8,-10.2),(27.,12.8,-10.2),(-45.,0.,-14.6)]

def radius(x):return RADIUS*math.sqrt(max(0.,1.-(x/(LENGTH*.5))**2))*(.92+.08*(x/LENGTH+.5))

def build():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
 catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
 kit.scratch=bpy.data.collections.new('Closed editable airship stock');bpy.context.scene.collection.children.link(kit.scratch)
 exports=bpy.data.collections.new('Airship runtime partitions');bpy.context.scene.collection.children.link(exports)
 mats={key:material(ROOT,key,finish,catalog) for key,finish in FINISHES.items()}
 parts={key:[] for key in FINISHES}
 profile=[(0.,-LENGTH*.5)]+[(radius(x),x) for x in np.linspace(-LENGTH*.5+.3,LENGTH*.5-.3,41)]+[(0.,LENGTH*.5)]
 hull=kit.lathe(profile,(0,0,0),'X',64);parts['linen'].append(hull)
 # Longitudinal stitched panel covers, ring stations and end mooring fittings.
 for i in range(24):
  a=i*math.tau/24
  points=[(x,(radius(x)+.018)*math.cos(a),(radius(x)+.018)*math.sin(a)) for x in np.linspace(-81.,81.,31)]
  parts['linen'].append(kit.tube(points,.035,n=4))
 for x in [-68.,-48.,-24.,0.,24.,48.,68.]:
  parts['frame'].append(kit.torus((x,0,0),radius(x)+.02,.055,'X',64,4))
 parts['frame'].append(kit.cyl((83.7,0,0),.25,1.0,'X',16))
 parts['frame'].append(kit.torus((84.3,0,0),.35,.055,'X',16,6))
 # Four closed fins grow from the aft envelope. Distinct trailing control
 # leaves, hinge rods and fabric ribs make them manufactured surfaces.
 for i in range(4):
  angle=i*math.pi*.5
  turn=Matrix.Rotation(angle,4,'X')
  for profile,lo,hi in [([(-77.,2.),(-74.,15.),(-55.,16.),(-48.,9.)],-.2,.2),([(-82.,3.),(-79.,14.8),(-74.5,15.),(-77.5,2.8)],-.22,.22)]:
   obj=kit.prism(profile,lo,hi,.04);obj.data.transform(turn);parts['linen'].append(obj)
  for x in [-73.,-67.,-61.,-55.]:
   obj=kit.tube([(x,0,9.),(x-2.,0,15.5)],.045,4);obj.data.transform(turn);parts['frame'].append(obj)
  rod=kit.tube([(-77.,0,3.),(-74.,0,14.9)],.12,8);rod.data.transform(turn);parts['frame'].append(rod)
 # Streamlined external gondola beneath the forward half, framed window bays,
 # a bridge, access door, keel saddles and diagonals rather than a floating box.
 parts['linen'].append(kit.prism([(8.,-15.),(43.,-15.),(47.,-13.5),(44.,-10.7),(8.,-10.7),(4.,-12.4)],-2.3,2.3,.2))
 for side in [-1,1]:
  for x in np.linspace(10.,42.,14):
   parts['frame'].append(kit.box((x,side*2.35,-12.1),(2.0,.18,1.4),.06))
   parts['window'].append(kit.box((x,side*2.45,-12.1),(1.75,.08,1.12),.04))
  parts['frame'].append(kit.box((6.5,side*2.1,-12.1),(1.5,.15,1.6),.05))
  parts['window'].append(kit.box((6.5,side*2.2,-12.1),(1.25,.08,1.35),.04))
  for x in [8.,23.,40.]:
   parts['frame'].append(kit.tube([(x,side*1.9,-10.8),(x,side*3.,-9.7)],.11,8))
  parts['frame'].append(kit.box((15.,side*2.4,-13.6),(1.8,.16,2.3),.06))
  for x in [13.7,16.3]:parts['iron'].append(kit.tube([(x,side*2.6,-14.7),(x,side*2.6,-12.6)],.055,6))
 # Engine cars hang from struts meeting the envelope, each with an actual
 # rear spindle, radiator louvers, crew hatch and shared propeller stock.
 for x,y,z in PODS:
  parts['frame'].append(kit.sphere((x,y,z),1.,(3.,1.,1.1),24,12))
  for dx in [-1.8,1.8]:
   surface=Vector((x+dx,y*.55,-radius(x+dx)*.82))
   parts['iron'].append(kit.tube([surface,(x+dx,y,z+.7)],.14,8))
  parts['iron'].append(kit.cyl((x-3.,y,z),.14,1.4,'X',12))
  parts['frame'].append(kit.torus((x-3.55,y,z),.30,.065,'X',16,6))
  for j in range(7):parts['iron'].append(kit.box((x+.2+j*.22,y-1.01,z),(.09,.06,.7),.015))
  parts['window'].append(kit.box((x+1.8,y-.85,z+.25),(.65,.1,.45),.04))
 prop=[kit.sphere((0,0,0),.36,(.7,1,1),16,8)]
 for sign in [-1,1]:
  blade=kit.prism([(-.08,.18),(-.30,1.3),(-.10,2.35),(.14,2.55),(.27,1.35),(.13,.18)],-.07,.07,.03)
  blade.data.transform(Matrix.Rotation(.25,4,'Z')@Matrix.Rotation(0 if sign==1 else math.pi,4,'X'));prop.append(blade)
 for key,objects in parts.items():
  if not objects:continue
  obj=partition(exports,'liner__'+key,objects,FINISHES[key],mats[key],Matrix.Identity(4),catalog)
  if key=='linen':
   # Develop the envelope around its long axis. Small flat fin/gondola charts
   # retain the existing metric mapping instead of a stretched hull projection.
   mesh=obj.data;coords=np.array([v.co[:] for v in mesh.vertices]);idx=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3));points=coords[idx]
   normal=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]);normal/=np.linalg.norm(normal,axis=1)[:,None]
   uv=np.array([v.uv[:] for v in mesh.uv_layers.active.data]).reshape((-1,3,2));guide=mesh.attributes['_tangent_guide'];g=np.array([a.vector[:] for a in guide.data])[::3];u=g[:,[0,2,1]].copy();u[:,1]*=-1
   selected=np.all(idx<len(hull.data.vertices),axis=1)
   su=u[selected].copy();sv=uv[selected].copy();revolved_charts(points[selected],normal[selected],su,sv,np.tile((1,0,0),(selected.sum(),1)),np.zeros((selected.sum(),3)),1.)
   u[selected]=su;uv[selected]=sv;mesh.uv_layers.active.data.foreach_set('uv',uv.astype(np.float32).ravel())
   g=np.repeat(u[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
 partition(exports,'propeller__timber',prop,FINISHES['timber'],mats['timber'],Matrix.Identity(4),catalog)
 counts=[]
 for obj in kit.scratch.objects:
  bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges),obj.name
  assert bm.calc_volume(signed=True)>1e-9,obj.name;bm.free();counts.append(obj.name)
 kit.scratch.hide_render=True;kit.scratch.hide_viewport=True
 proof=export(ROOT,'skyward_liner',exports,material_names_only=True)
 table={'schema':'orison.skyward-liner.v1','classification':'FICTIONAL_PERIOD_ADAPTATION','stock':'res://assets/props/skyward_liner.glb','length_m':LENGTH,'propeller_mounts':[[x-3.8,z,-y] for x,y,z in PODS],'finishes':[dict({'id':k},**{n:v for n,v in spec.items() if n!='pigment'}) for k,spec in FINISHES.items()]}
 (ROOT/'game/data/orison_v2/exterior/skyward_liner.json').write_text(json.dumps(table,indent=2)+'\n',newline='\n')
 result={'evidence_class':'INERT','scope':'native airship stock authoring, not installed runtime qualification','closed_stocks':len(counts),'export_validation':proof,'source_lf_sha256':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()}
 (ROOT/'art/blender/skyward_liner_construction.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n');print('SKYWARD STOCK',result)

if __name__=='__main__':build()
