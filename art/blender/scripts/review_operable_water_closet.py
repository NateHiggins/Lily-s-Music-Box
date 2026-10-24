"""Native form/UV witnesses and three neutral shape views; not acceptance."""
from pathlib import Path
import bpy,bmesh,json,math,os,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('TOILET_FORM_REVIEW_OUT',str(ROOT/'art/reviews/v2_toilet_form_20261022/native_v1')));OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bath_water_closet.blend'))
def p(v):return Vector((v[0],-v[2],v[1]))
stocks=[];trees={};failures=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 m=o.data;m.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(m)
 bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
 if bad or volume<=0:failures.append([o.name,'solid',bad,volume])
 bm.free()
 points=np.asarray([v.co[:] for v in m.vertices]);indices=np.asarray([t.vertices[:] for t in m.loop_triangles]);at=points[indices]
 uv=np.asarray([[m.uv_layers.active.data[i].uv[:] for i in t.loops] for t in m.loop_triangles]);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2)
 metric=np.linalg.svd(np.stack([at[:,1]-at[:,0],at[:,2]-at[:,0]],axis=2)@np.linalg.inv(d),compute_uv=False)
 if not np.all((metric>.99)&(metric<1.01)):failures.append([o.name,'metric',float(metric.min()),float(metric.max())])
 stocks.append(dict(name=o.name,triangles=len(m.loop_triangles),nonmanifold_edges=bad,volume_m3=volume,minimum_metres_per_uv=float(metric.min()),maximum_metres_per_uv=float(metric.max())))
 trees[o.name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
witnesses=[]
for name,origin,direction,length in [('HollowWashDownBowl',(0,.174,-.045),(0,-.100,.097),.14),('PolishedWoodSeat',(0,.60,-.15),(0,-1,0),.21),('HollowCistern',(.075,.54,.205),(0,-1,0),.075)]:
 hit=trees[name].ray_cast(p(origin),p(direction).normalized(),length)[0]
 witnesses.append(dict(part=name,ray_origin=origin,direction=direction,length=length,clear=hit is None))
 if hit is not None:failures.append([name,'blocked aperture',list(hit)])
# World-space contact witnesses supplement individual closed-solid checks.
contacts=[]
for suffix,x in [('',-.092),('.001',.092)]:
 for left,right,at in [('PorcelainHingePlinth'+suffix,'HingeRosette'+suffix,(x,.421,.118)),('HingeRosette'+suffix,'HingePost'+suffix,(x,.426,.118))]:
  distances=[trees[name].find_nearest(p(at))[3] for name in [left,right]]
  ok=all(d is not None and d<.0001 for d in distances)
  contacts.append(dict(parts=[left,right],at=at,distances=distances,pass_contact=ok))
  if not ok:failures.append([left,right,'attachment',distances])
for x in [-.092,.092]:
 hit=trees['HollowWashDownBowl'].ray_cast(p((x,.43,.060)),p((0,-1,0)),.06)[0]
 height=hit.z if hit is not None else None
 ok=height is not None and .401<=height<=.421
 contacts.append(dict(part='hinge plinth to bowl',x=x,bowl_height=height,pass_contact=ok))
 if not ok:failures.append(['hinge plinth to bowl',x,height])
# The trap's annular mating port must coincide with the porcelain mouth.
for name in ['HollowWashDownBowl','DrainTrap']:
 distance=trees[name].find_nearest(p((.040,.089,.052)))[3]
 contacts.append(dict(part=name,at=[.040,.089,.052],distance=distance,pass_contact=distance<.0001))
 if distance>=.0001:failures.append([name,'drain port',distance])
(OUT/'native.json').write_text(json.dumps(dict(evidence_class='INERT',stocks=stocks,witnesses=witnesses,contacts=contacts,failures=failures),indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral form review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.34,.38,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for at,energy,size in [((1,1.6,-1),100,1.4),((-1,1.,-.1),65,1.3),((0,.6,.9),30,1.)]:
 bpy.ops.object.light_add(type='AREA',location=p(at));o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(p((0,.4,0))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();scene.camera=bpy.context.object;scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=1.03
for name,eye,at in [('context',(.9,1.02,-1.1),(0,.41,-.02)),('seat_and_well',(.2,1.45,-.65),(0,.25,-.11)),('cistern_underside',(.65,.24,-.65),(.025,.49,.17)),('hinge_mounts',(.40,.70,-.12),(0,.43,.10)),('cistern_linkage',(.45,1.20,-.1),(.04,.68,.24))]:
 for o in bpy.data.objects['CisternCover'].children_recursive:o.hide_render=name=='cistern_linkage'
 scene.camera.data.ortho_scale=.55 if name in ['hinge_mounts','cistern_linkage'] else 1.03
 scene.camera.location=p(eye);scene.camera.rotation_euler=(p(at)-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
print('WATER CLOSET NATIVE FORM: PASS',len(stocks),'closed stocks; metric charts; three open-aperture witnesses')
