"""Native thirteen-carrier rack for the uninstalled full-length hose.

Reuses the source-owned machined fittings. Extends only the plain shaft stock;
shoulders and both mating threads retain their original pitch. Every exported
part receives fresh metre charts after the refit. No production publication.
"""
from pathlib import Path
import hashlib,json,math,os,sys
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_CAPACITY_RACK_OUT',str(ROOT/'tmp/v2-hose-follower-20261021/rack_v1'))).resolve()
CLOTH=Path(os.environ.get('ORISON_FIRE_CAPACITY_CLOTH',str(ROOT/'tmp/v2-deployable-hose-20261021/stock_v3/art/blender/fire_capacity_candidate.blend'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp') and CLOTH.is_relative_to(ROOT)
for path in ['art/blender','game/assets/props']:(OUT/path).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={
 'iron':dict(catalog_key='fire_hardware_steel',tint=[1,1,1,1],pigment=1.,normal=1.,roughness=1.,metallic=.88),
 'brass':dict(catalog_key='radiator_service_brass',tint=[1,1,1,1],pigment=1.,normal=1.,roughness=1.,metallic=.92)}
mats={key:material(ROOT,key,spec,catalog) for key,spec in finishes.items()}
native=bpy.data.collections.new('Editable thirteen-carrier rack');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireCapacityRack');bpy.context.scene.collection.children.link(exports)
keys=['Shaft','EndNut','MountBracket','MountScrew','CarrierArm']
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_hose_rack.blend'),link=False) as (_,loaded):loaded.objects=[key+'_Editable' for key in keys]
objects=dict(zip(keys,loaded.objects));proofs={};draws={}
assert all(objects.values())
# These source objects already use their local manufacturing frame. Preserve it.
assert all(obj.matrix_world==Matrix.Identity(4) for obj in objects.values())
for vertex in objects['Shaft'].data.vertices:
 x=vertex.co.x
 if x<=-.276:vertex.co.x=x-.009
 elif x<.050:vertex.co.x=-.285+(x+.276)*(.393/.326)
 else:vertex.co.x=x+.058
for vertex in objects['EndNut'].data.vertices:vertex.co.x+=.058
# Keep the machined eye and its blind seat exactly; replace only the separate
# closed rod with an explicitly sampled stem/spherical end, never a decimator.
arm=objects['CarrierArm'];bm=bmesh.new();bm.from_mesh(arm.data)
unseen=set(bm.verts);components=[]
while unseen:
 seed=unseen.pop();component={seed};stack=[seed]
 while stack:
  vertex=stack.pop()
  for edge in vertex.link_edges:
   other=edge.other_vert(vertex)
   if other in unseen:unseen.remove(other);component.add(other);stack.append(other)
 components.append(component)
assert len(components)==2, len(components)
rod=max(components,key=lambda group:max(vertex.co.z for vertex in group))
assert max(vertex.co.z for vertex in rod)>.07
bmesh.ops.delete(bm,geom=list(rod),context='VERTS');bm.to_mesh(arm.data);bm.free()
def b(p):return Vector((p[0],-p[2],p[1]))
r=.00595;stem=.0028;end=Vector((0,.014,.068))
back=-math.sqrt(r*r-stem*stem);entry=end+Vector((0,0,back))
a=Vector((0,0,.0045));c1=a+Vector((0,0,.014));c2=entry-Vector((0,0,.020))
centers=[];radii=[];tangents=[]
for i in range(17):
 t=i/16;centers.append((1-t)**3*a+3*(1-t)**2*t*c1+3*(1-t)*t*t*c2+t**3*entry)
 tangents.append((3*(1-t)**2*(c1-a)+6*(1-t)*t*(c2-c1)+3*t*t*(entry-c2)).normalized());radii.append(stem)
angle=math.acos(back/r)
for i in range(1,33):
 theta=angle*(1-i/32);centers.append(end+Vector((0,0,r*math.cos(theta))))
 tangents.append(Vector((0,0,1)));radii.append(r*math.sin(theta))
n=32;vertices=[];faces=[]
for center,radius,tangent in zip(centers,radii,tangents):
 u=Vector((1,0,0));v=tangent.cross(u).normalized()
 for i in range(n):vertices.append(b(center+radius*(u*math.cos(math.tau*i/n)+v*math.sin(math.tau*i/n))))
for row in range(len(centers)-1):
 for i in range(n):faces.append((row*n+i,(row+1)*n+i,(row+1)*n+(i+1)%n,row*n+(i+1)%n))
faces.append(tuple(reversed(range(n))))
mesh=bpy.data.meshes.new('Reduced continuous rounded carrier');mesh.from_pydata(vertices,[],faces);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9);bm.to_mesh(mesh);bm.free()
rod=bpy.data.objects.new('Reduced closed rod',mesh);bpy.context.scene.collection.objects.link(rod)
bpy.context.scene.collection.objects.link(arm);bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);rod.select_set(True);bpy.context.view_layer.objects.active=arm;bpy.ops.object.join()
for collection in list(arm.users_collection):collection.objects.unlink(arm)
for key,obj in objects.items():
 native.objects.link(obj);obj.name=key+'_Editable';obj.data.update()
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True)
 assert bad==0 and volume>0,(key,bad,volume)
 bm.to_mesh(obj.data);bm.free()
 finish='brass' if key in ['EndNut','CarrierArm'] else 'iron'
 draws[key]=partition(exports,key,[obj],finishes[finish],mats[finish],Matrix.Identity(4),catalog)
 proofs[key]={'nonmanifold_edges':bad,'volume_m3':volume,'triangles':len(draws[key].data.polygons),'material':finish}
def b(p):return Vector((p[0],-p[2],p[1]))
def at(p):return Matrix.Translation(b(p))
def tree(obj,pose=Matrix.Identity(4)):
 return BVHTree.FromPolygons([pose@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
with bpy.data.libraries.load(str(CLOTH),link=False) as (_,loaded):loaded.objects=['Capacity study hose']
cloth=loaded.objects[0];assert cloth is not None
bpy.context.scene.collection.objects.link(cloth);cloth.hide_render=False;cloth.matrix_world=Matrix.Identity(4)
cloth_tree=tree(cloth)
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=['F007']
case=loaded.objects[0];assert case is not None
case_tree=tree(case,at((0,.390,.009)))
shaft_tree=tree(objects['Shaft'],at((0,.666,.032)))
nut_tree=tree(objects['EndNut'],at((0,.666,.032)))
assert not shaft_tree.overlap(nut_tree),'thread overlap'
checks=[];negatives=[];crossings=[];shaft_crossings=[];gaps=[];copies=[]
def show(key,pose):
 obj=draws[key].copy();obj.matrix_world=pose;bpy.context.scene.collection.objects.link(obj);copies.append(obj)
for i in range(13):
 x=-.264+i*.0295;pose=at((x,.666,.032));arm=tree(objects['CarrierArm'],pose)
 crossings.append(len(arm.overlap(cloth_tree)));shaft_crossings.append(len(shaft_tree.overlap(arm)))
 lowered=tree(objects['CarrierArm'],at((x,.665,.032)))
 for dx in [-.002,-.001,0,.001,.002]:
  origin=b((x+dx,.678,.100));direction=b((0,1,0))
  a=arm.ray_cast(origin,direction,.016)[0];c=cloth_tree.ray_cast(origin,direction,.016)[0];n=lowered.ray_cast(origin,direction,.016)[0]
  gap=(a-c).length if a is not None and c is not None else None
  gaps.append(gap);checks.append(gap is not None and gap<.0001)
  negatives.append(n is not None and c is not None and (n-c).length>.0009)
 show('CarrierArm',pose)
mount_gaps=[]
for x in [-.279,.103]:
 pose=at((x,.666,.032));bracket=tree(objects['MountBracket'],pose)
 for dy in [-.012,-.006,.006,.012]:
  origin=b((x,.666+dy,.019));direction=b((0,0,-1))
  a=case_tree.ray_cast(origin,direction,.005)[0];c=bracket.ray_cast(origin,direction,.005)[0]
  mount_gaps.append((a-c).length if a is not None and c is not None else None)
 show('MountBracket',pose)
 for dy in [-.021,.021]:show('MountScrew',at((x,.666+dy,.022)))
for key in ['Shaft','EndNut']:show(key,at((0,.666,.032)))
left_clearance=min(vertex.co.x for vertex in objects['Shaft'].data.vertices)+.28795
assert sum(checks)==65 and sum(negatives)==65
assert not any(crossings) and not any(shaft_crossings)
assert left_clearance>0 and len(mount_gaps)==8 and all(gap is not None and gap<.0001 for gap in mount_gaps)
assert not shaft_tree.overlap(cloth_tree) and not nut_tree.overlap(cloth_tree)
native.hide_render=True;native.hide_viewport=True
for obj in exports.objects:obj.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Rack review');scene.world.color=(.18,.18,.18)
for position,power in [((.10,.82,.45),8),((-.35,.70,.25),5)]:
 bpy.ops.object.light_add(type='AREA',location=b(position));light=bpy.context.object;light.data.energy=power;light.data.size=.25
 light.rotation_euler=(b((-.08,.67,.08))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=b((.13,.84,.50)));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(b((-.08,.66,.085))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'supported_rack.png');bpy.ops.render.render(write_still=True)
scene.camera.location=b((.08,.80,.90));scene.camera.rotation_euler=(b((-.08,.64,.07))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'whole_rack.png');bpy.ops.render.render(write_still=True)
cloth.hide_render=True
scene.camera.location=b((.07,.73,.40));scene.camera.rotation_euler=(b((-.08,.67,.06))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'bare_rack.png');bpy.ops.render.render(write_still=True)
for obj in copies+[cloth]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_capacity_rack',exports,material_names_only=True)
def digest(path):
 raw=path.read_bytes();return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.json'] else raw).hexdigest()
sources=[Path(__file__),ROOT/'art/blender/fire_hose_rack.blend',CLOTH,ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'game/data/runtime_material_sets.json']
report={'evidence_class':'INERT','scope':'Uninstalled source-owned thirteen-carrier rack. Native support, fresh metre charts and tangents only. No deployed, loaded, runtime or human acceptance.','source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in sources},'stocks':proofs,'bearing_samples':65,'bearing_passes':sum(checks),'maximum_gap_m':max(gaps),'negative_controls':sum(negatives),'cloth_arm_crossings':crossings,'shaft_arm_crossings':shaft_crossings,'shaft_nut_crossings':0,'mount_gaps_m':mount_gaps,'left_clearance_m':left_clearance,'export':result,'blend_sha256':digest(OUT/'art/blender/fire_capacity_rack.blend'),'glb_sha256':digest(OUT/'game/assets/props/fire_capacity_rack.glb')}
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
(OUT/'runtime_projection.json').write_text(json.dumps({'schema_version':1,'asset':'res://tests/fixtures/v2_fire_capacity_rack.glb','parts':{key:value['material'] for key,value in proofs.items()},'materials':finishes,'pivot_y_m':.666,'pivot_z_m':.032,'tip_local_m':[0,.014,.068],'carrier_x_m':[-.264+i*.0295 for i in range(13)],'bracket_x_m':[-.279,.103]},indent=2)+'\n',newline='\n')
print('THIRTEEN CARRIER NATIVE PASS',json.dumps({key:report[key] for key in ['bearing_passes','maximum_gap_m','negative_controls','left_clearance_m']}))
