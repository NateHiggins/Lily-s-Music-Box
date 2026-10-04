"""Reopen closed source-fit port stocks and test their actual unobstructed airways."""
from pathlib import Path
import json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=R/'tmp/roof-drainage-review/ports';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_ports_construction.json').read_bytes());native=O/'roof_drainage_ports.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native));trees={};origins={};closed=[];bounds=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<1e-8;bm.free()
 closed.append({'name':obj.name,'volume_m3':volume});trees[obj.name]=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False);origins[obj.name]=tuple(obj.location)
 if 'source_fixture' in row:
  f=row['source_fixture'];center=[f['position'][0],19.2+f['position'][1],f['position'][2]];expected_lo=[center[i]-f['size'][i]/2 for i in range(3)];expected_hi=[center[i]+f['size'][i]/2 for i in range(3)]
  points=[obj.matrix_world@v.co for v in obj.data.vertices];measured_lo=[min(p[0] for p in points),min(p[2] for p in points),-max(p[1] for p in points)];measured_hi=[max(p[0] for p in points),max(p[2] for p in points),-min(p[1] for p in points)]
  assert max(abs(a-b) for a,b in zip(measured_lo+measured_hi,expected_lo+expected_hi))<.000005
  bounds.append({'id':f['id'],'bounds_equal':True,'low':measured_lo,'high':measured_hi})
def b(p):return Vector((p[0],-p[2],p[1]))
def ray(name,point,direction,distance):
 origin=Vector(origins[name]);hit,n,index,d=trees[name].ray_cast(point-origin,direction,distance)
 return None if hit is None else hit+origin,n,d
air=[];bed_contacts=[]
for port in report['ports']:
 n=b(port['normal']);t=b(port['tangent']);p=b(port['inner_point']);up=Vector((0,0,1))
 for lateral in [-.10,0.,.10]:
  for height in [.02,.06,.10]:
   at=p+t*lateral+up*height-n*.015
   for name in trees:
    hit,normal,d=ray(name,at,n,port['channel_length']+.03)
    assert hit is None,(port['id'],lateral,height,name,hit)
   air.append({'id':port['id'],'offset':[lateral,height],'clear_length_m':port['channel_length']+.03})
 for along in [0.04,.15,.24,.35,.40]:
  for lateral in [-.10,0.,.10]:
   expected=p+n*along+t*lateral-up*(port['outfall']*along+port['sheet_thickness']);at=expected+up*.0006
   hit,normal,d=ray('Scupper_'+port['id']+'__Bed',at,-up,.0012)
   assert hit is not None and (hit-expected).length<.000005,(port['id'],along,lateral,hit,expected)
   bed_contacts.append({'id':port['id'],'along':along,'lateral':lateral,'error_m':(hit-expected).length})
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=35;camera_data.clip_start=.01
renders=[]
for port_id,side in [('W_M','inside'),('E_S','outside'),('N_E','outside')]:
 port=next(p for p in report['ports'] if p['id']==port_id);p=b(port['inner_point']);n=b(port['normal']);t=b(port['tangent']);up=Vector((0,0,1))
 camera.location=p+n*(-.65 if side=='inside' else 1.1)+t*.45+up*.42;target=p+n*.18+up*.04;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(port_id+'_'+side+'.png'));bpy.ops.render.render(write_still=True);renders.append(port_id+'_'+side+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'source_equal_parapet_bounds':bounds,'clear_airways':air,'bedded_sheet_contacts':bed_contacts,'renders':renders,'note':'Native geometry and diagnostic gray materials only. Flashing, receiver, supported leader and downstream connection remain open; no production, capacity, weather or ledger acceptance.'},indent=2)+'\n',newline='\n')
print('REOPENED SCRATCH PORTS',len(closed),'closed stocks;',len(air),'clear airways;',len(bed_contacts),'bedded sheet contacts; four original parapet bounds unchanged')
