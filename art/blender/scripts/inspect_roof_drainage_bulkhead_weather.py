"""Reopen trimmed weather sources; verify retained upper geometry and open toes."""
from pathlib import Path
import json,hashlib,math,collections,subprocess,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'tmp/roof-drainage-review/bulkhead_weather';O.mkdir(parents=True,exist_ok=True)
def b(p):return Vector((p[0],-p[2],p[1]))
reports=[]
for kind in ['public','service']:
 manifest=json.loads((R/f'game/tests/fixtures/orison_roof_{kind}_weathering.json').read_bytes());native=R/f'art/blender/roof_{kind}_weathering.blend'
 # Historical published native source is compared in both directions; never
 # compare a regenerated source to itself and call it retained geometry.
 original=O/f'baseline-{kind}.blend';original.write_bytes(subprocess.check_output(['git','show','98c57c10601ccbcc52b46b8369d07e4da3824c76:art/blender/roof_'+kind+'_weathering.blend'],cwd=R))
 assert hashlib.sha256(native.read_bytes()).hexdigest()==manifest['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(original));upper={}
 cutoff=manifest['leader_y'][0]+.01
 for obj in bpy.context.scene.objects:
  if obj.type=='MESH' and 'Runtime' not in obj.name:upper[obj.name]=np.array([tuple(float(p[i]) for i in range(3)) for v in obj.data.vertices if (p:=obj.matrix_world@v.co).z>cutoff]).reshape(-1,3)
 bpy.ops.wm.open_mainfile(filepath=str(native));closed=[];upper_checks=[];trees={};origins={}
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH' or 'Runtime' in obj.name:continue
  bm=bmesh.new();bm.from_mesh(obj.data)
  if not all(e.is_manifold for e in bm.edges):
   assert 'Bearing' in obj.name and not obj.name.endswith('ClosedConstruction'),obj.name;bm.free();continue
  volume=bm.calc_volume(signed=True);assert volume>0,obj.name;bm.free();closed.append({'name':obj.name,'volume_m3':volume})
  measured=np.array([tuple(float(p[i]) for i in range(3)) for v in obj.data.vertices if (p:=obj.matrix_world@v.co).z>cutoff]).reshape(-1,3);before=upper[obj.name]
  assert len(measured)==len(before),('Upper source inventory changed',kind,obj.name,len(measured),len(before))
  errors=[]
  for source,target in [(before,measured),(measured,before)]:
   for start in range(0,len(source),128):errors.extend(np.sqrt(np.sum((source[start:start+128,None,:]-target[None,:,:])**2,axis=2)).min(axis=1).tolist())
  assert max(errors,default=0)<.000005,('Upper native geometry changed',kind,obj.name,max(errors))
  upper_checks.append({'name':obj.name,'retained_upper_vertices':len(measured),'cutoff_y':cutoff,'maximum_native_error_m':max(errors,default=0),'both_directions_checked':True})
  trees[obj.name]=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False);origins[obj.name]=obj.location.copy()
 airway=[]
 for dx,dz in [(0,0),(.030,0),(-.030,0),(0,.030),(0,-.030)]:
  point=b([manifest['gutter_x']+dx,21.9,manifest['outlet_z']+dz]);direction=Vector((0,0,-1));reach=21.9-manifest['leader_y'][0]+.01
  for name,tree in trees.items():
   hit,n,index,d=tree.ray_cast(point-origins[name],direction,reach);assert hit is None,(kind,name,dx,dz,hit)
  airway.append({'offset':[dx,dz],'clear_length_m':reach})
 toe_vertices=[float(v.co.z+obj.location.z) for obj in bpy.context.scene.objects if obj.type=='MESH' and obj.name in [kind.capitalize()+'RoofGutter',kind.capitalize()+'RoofGutterClosedConstruction'] for v in obj.data.vertices if abs(float(v.co.x+obj.location.x)-manifest['gutter_x'])<.07 and abs(float(-v.co.y-obj.location.y)-manifest['outlet_z'])<.07]
 assert toe_vertices and abs(min(toe_vertices)-manifest['leader_y'][0])<.000005,(kind,min(toe_vertices),manifest['leader_y'][0])
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
 sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
 camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=42;camera_data.clip_start=.01
 x,z=manifest['gutter_x'],manifest['outlet_z'];y=manifest['leader_y'][0]
 # Add the actual fitted field as context without saving diagnostic edits.
 with bpy.data.libraries.load(str(R/'art/blender/roof_drainage_falls.blend'),link=False) as (source,target):target.objects=[name for name in source.objects if '__Field_' in name]
 for obj in target.objects:
  if obj is not None:scene.collection.objects.link(obj)
 renders=[]
 for name,eye,at in [('toe',(x+.6,y+.30,z-.5),(x,y-.015,z)),('upper',(x+.6,22.6,z+.6),(x,22.2,z))]:
  camera.location=b(eye);camera.rotation_euler=(b(at)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(O/(kind+'_'+name+'.png'));bpy.ops.render.render(write_still=True);renders.append(kind+'_'+name+'.png')
 reports.append({'kind':kind,'native_sha256':manifest['native_sha256'],'asset_sha256':manifest['asset_sha256'],'original_source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'closed_stocks':closed,'retained_upper_source':upper_checks,'clear_bore_probes':airway,'measured_toe_y':min(toe_vertices),'renders':renders})
(O/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','weather':reports,'open_work':'Composed footprint contacts, supports and roof field joints remain separate acceptance work.'},indent=2)+'\n',newline='\n')
print('REOPENED FITTED WEATHER',[(r['kind'],len(r['closed_stocks']),sum(s['retained_upper_vertices'] for s in r['retained_upper_source']),len(r['clear_bore_probes'])) for r in reports])
