"""Reopen and measure closed native scratch stocks, then render actual field maps.

Retained production geometry is read-only gray diagnostic context. This does
not accept ports, weather joints, fixtures, drainage capacity or gameplay.
"""
from pathlib import Path
import json,hashlib,math,os
import bpy,bmesh,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=R/'tmp/roof-drainage-review/falls';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_falls_construction.json').read_bytes());native=O/'roof_drainage_falls.blend'
assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native))
stock_checks=[];trees={};origins={};volumes={}
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True)
 assert all(e.is_manifold for e in bm.edges) and volume>0 and abs(volume-row['volume_m3'])<1e-8
 assert tuple(obj.rotation_euler)==(0.,0.,0.) and tuple(obj.scale)==(1.,1.,1.)
 vertices=[v.co for v in obj.data.vertices];faces=[tuple(p.vertices) for p in obj.data.polygons]
 trees[(row['owner'],row['kind'])]=BVHTree.FromPolygons(vertices,faces,all_triangles=False)
 origins[(row['owner'],row['kind'])]=tuple(obj.location)
 volumes[(row['owner'],row['kind'])]=volume;stock_checks.append({'name':row['name'],'volume_m3':volume,'manifold':True});bm.free()
projected=0.;samples=[];gradients=[]
def ray(owner,kind,point):
 origin=origins[(owner,kind)];local=Vector((point[0]-origin[0],-point[2]-origin[1],point[1]+.3-origin[2]))
 hit,n,f,d=trees[(owner,kind)].ray_cast(local,Vector((0,0,-1)),.6)
 return None if hit is None else hit.z+origin[2],n
for ids,owner in zip(report['triangles_by_vertex'],report['triangle_owners']):
 points=np.array([report['points'][i] for i in ids]);u=points[1,[0,2]]-points[0,[0,2]];v=points[2,[0,2]]-points[0,[0,2]];area=abs(u[0]*v[1]-u[1]*v[0])*.5;projected+=area
 center=points.mean(axis=0);at=Vector((center[0],-center[2],center[1]));contacts={}
 for kind,dy in [('Membrane',0.),('TaperedBacking',-.004),('PhysicalEnvelope',0.)]:
  hit,normal=ray(owner,kind,center)
  assert hit is not None and abs(hit-(center[1]+dy))<.000002,(owner,kind,center,hit)
  assert normal.z>.999,(owner,kind,normal)
  contacts[kind]=float(hit)
 samples.append({'owner':owner,'point':center.tolist(),'contacts':contacts})
 for native_hit in [contacts['Membrane']]:assert native_hit>19.2+.009
 membrane=trees[(owner,'Membrane')]
 # Measure the reopened positions rather than repeat only the analytic model.
 measured=[];inset=points*.8+center*.2
 for p in inset:
  hit,n=ray(owner,'Membrane',p);assert hit is not None;measured.append(hit)
 gradient=np.linalg.solve(np.c_[inset[:,0],inset[:,2],np.ones(3)],measured)
 gradients.append(float(np.linalg.norm(gradient[:2])))
assert min(gradients)>.0099,(min(gradients),max(gradients))
assert abs(sum(v for (owner,kind),v in volumes.items() if kind=='Membrane')-.004*projected)<.00002
# Original production draw vertices give factual context for the coordinated
# follow-up work. Their original material appearance is not claimed here.
context=bpy.data.collections.new('ReadOnlyProductionContext');bpy.context.scene.collection.children.link(context)
grey=bpy.data.materials.new('DiagnosticContextGray');grey.diffuse_color=(.38,.38,.38,1)
for row in report.get('door_fittings',[]):
 original=bpy.data.objects[row['id']+'__FittedHead'];copy=bpy.data.objects.new(original.name+'_ReadOnlyContext',original.data.copy());copy.location=original.location;copy.data.materials.clear();copy.data.materials.append(grey);context.objects.link(copy)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=28;camera_data.clip_start=.01
views=[('roof_field',(-21,20,38),(-1,0,19.3)),('public_interface',(-3.6,0,20.61),(-2.2,0,19.36)),('service_interface',(8.1,-3,20.61),(9.5,-3,19.31)),('north_falls',(-10,-9.5,20.61),(-6.3,-5.8,19.32))];renders=[]
for name,at,target in views:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'stock_checks':stock_checks,'projected_area_m2':float(projected),'native_gradient_range':[min(gradients),max(gradients)],'surface_contacts':samples,'renders':renders,'note':__doc__},indent=2)+'\n',newline='\n')
print('REOPENED SCRATCH ROOF',len(stock_checks),'closed stocks;',len(samples),'triple layer contacts; native gradients',min(gradients),max(gradients))
