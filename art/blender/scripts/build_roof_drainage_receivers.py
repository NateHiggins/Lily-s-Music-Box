"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,hashlib,math,collections
import bpy,bmesh,numpy as np
from mathutils import Vector
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
study_path=R/'art/data/orison_roof_drainage/receiver_routes.json';grades_path=R/'art/data/orison_roof_drainage/receiver_grade_datums.json'
study=json.loads(study_path.read_bytes());grades=json.loads(grades_path.read_bytes());N=32
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
materials={}
for key,color,metal in [('cast_iron',(.12,.115,.105,1),.7),('concrete',(.31,.29,.26,1),0),('rubber_aged',(.055,.05,.045,1),0)]:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=color;node.inputs['Metallic'].default_value=metal;node.inputs['Roughness'].default_value=.75;materials[key]=mat
grade_stations=grades['stations']
def height(x,z):
 values=[]
 station=next((q for q in grade_stations if q['domain'][0]-1e-8<=x<=q['domain'][2]+1e-8 and q['domain'][1]-1e-8<=z<=q['domain'][3]+1e-8),None)
 assert station,('Outside bounded grade datum',x,z)
 for row in station['retained_grade_triangles']:
  t=np.array(row['points'])
  p=t[:,[0,2]];a=p[1]-p[0];c=p[2]-p[0];v=np.array([x,z])-p[0];det=a[0]*c[1]-a[1]*c[0]
  if abs(det)<1e-12:continue
  u=(v[0]*c[1]-v[1]*c[0])/det;w=(a[0]*v[1]-a[1]*v[0])/det
  if u>=-1e-7 and w>=-1e-7 and u+w<=1.0000001:values.append(float(t[0,1]+u*(t[1,1]-t[0,1])+w*(t[2,1]-t[0,1])))
 assert values,('Missing retained native grade',x,z)
 return max(values)
def b(p):return Vector((p[0],-p[2],p[1]))
def g(p):return [float(p.x),float(p.z),float(-p.y)]
def make(name,points,faces,key='cast_iron'):
 pivot=b(np.mean(points,axis=0));pivot=Vector(tuple(round(v,3) for v in pivot))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([b(p)-pivot for p in points],[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;obj['material_key']=key;mesh.materials.append(materials[key])
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);assert bm.calc_volume(signed=True)>0;bm.to_mesh(mesh);bm.free();return obj
def solid_loft(name,rings,key='cast_iron'):
 n=len(rings[0]);points=[p for ring in rings for p in ring];levels=len(rings)
 faces=[tuple(reversed(range(n))),tuple(range((levels-1)*n,levels*n))]
 faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(levels-1) for i in range(n)]
 return make(name,points,faces,key)
def sweep(name,path,radius,key='cast_iron',extend=(0.,0.)):
 path=[Vector(p) for p in path];directions=[(c-a).normalized() for a,c in zip(path,path[1:])]
 path[0]-=directions[0]*extend[0];path[-1]+=directions[-1]*extend[1]
 seed=Vector((0,1,0)) if abs(directions[0].y)<.85 else Vector((1,0,0));u=(seed-directions[0]*seed.dot(directions[0])).normalized();v=directions[0].cross(u).normalized();rings=[]
 for index,p in enumerate(path):
  previous=directions[max(index-1,0)];following=directions[min(index,len(directions)-1)];normal=(previous+following).normalized()
  ring=[]
  for i in range(N):
   q=radius*(u*math.cos(2*math.pi*i/N)+v*math.sin(2*math.pi*i/N));q-=previous*(q.dot(normal)/previous.dot(normal));ring.append(list(p+q))
  rings.append(ring)
  rotation=previous.rotation_difference(following);u=rotation@u;v=rotation@v
 return solid_loft(name,rings,key)
def vertical(name,x,z,profiles,key='cast_iron',graded=False):
 rings=[]
 for radius,y in profiles:
  rings.append([[x+radius*math.cos(i*2*math.pi/N),y+(height(x+radius*math.cos(i*2*math.pi/N),z+radius*math.sin(i*2*math.pi/N)) if graded else 0),z+radius*math.sin(i*2*math.pi/N)] for i in range(N)])
 return solid_loft(name,rings,key)
def annulus(name,x,z,ri,ro,low,high,key='cast_iron',graded=False):
 obj=vertical(name,x,z,[(ro,low),(ro,high)],key,graded);tool=vertical(name+'_Air',x,z,[(ri,low-.005),(ri,high+.005)],key,graded);boolean(obj,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True);return obj
def boolean(owner,tool,operation):
 bpy.context.view_layer.objects.active=owner;mod=owner.modifiers.new('Source-owned '+operation,'BOOLEAN');mod.operation=operation;mod.solver='MANIFOLD';mod.object=tool;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(owner.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free()
 if bad:
  print('FAILED CLOSED BOOLEAN',owner.name,operation,tool.name,'nonmanifold edges',bad,flush=True);bpy.ops.wm.save_as_mainfile(filepath=str(O/'failed-boolean.blend'),compress=True)
 assert not bad,(owner.name,operation,tool.name,bad)
def union(parts,name):
 owner=parts[0]
 for obj in parts[1:]:boolean(owner,obj,'UNION');bpy.data.objects.remove(obj,do_unlink=True)
 owner.name=name;return owner
def box(name,lo,hi,key='concrete',graded_top=False):
 points=[[x,y+(height(x,z) if graded_top and y==hi[1] else 0),z] for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]]
 return make(name,points,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],key)
outer=[];air=[];socket_specs=[];beds=[];receivers=[];cleanouts=[]
for trunk in study['trunks']:
 end_overlap=.20 if trunk['id']=='EAST' else 0.
 outer.append(sweep('Trunk_'+trunk['id'],trunk['path'],trunk['outer_radius'],extend=(0.,end_overlap)));air.append(sweep('TrunkAir_'+trunk['id'],trunk['path'],trunk['bore_radius'],extend=(.01,end_overlap+.01)))
 for segment,(a,c) in enumerate(zip(trunk['path'],trunk['path'][1:])):
  a=Vector(a);c=Vector(c);axis=(c-a).normalized();length=(c-a).length;count=math.ceil(length/1.5)
  for i in range(count):
   t=(i+.5)/count;p=a.lerp(c,t);half=axis*.06;bell=sweep('MainBell_'+trunk['id']+'_'+str(segment)+'_'+str(i),[list(p-half),list(p+half)],.185)
   tool=sweep(bell.name+'_Air',[list(p-half),list(p+half)],trunk['outer_radius'],extend=(.01,.01));boolean(bell,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
   socket_specs.append({'owner':trunk['id'],'stock':bell.name,'center':list(p),'axis':list(axis),'outer_radius':.185,'length_m':.12,'support_interval_m':length/count})
for branch in study['branches']:
 ident=branch['id'];x,y,z=branch['axis'][0];outer.append(sweep('Branch_'+ident,branch['axis'],branch['outer_radius']));air.append(sweep('BranchAir_'+ident,branch['axis'],branch['bore_radius'],extend=(.01,.005)))
 outer.append(vertical('ReceiverSocket_'+ident,x,z,[(.105,.225),(.105,.39)]));air.append(vertical('ReceiverSocketAir_'+ident,x,z,[(.0762,.22),(.0762,.23),(.0804,.27),(.0804,.40)]))
 annulus('ReceiverInsertSeal_'+ident,x,z,.0774,.0804,.30,.39,'rubber_aged')
 collar=annulus('GradeCollar_'+ident,x,z,.091,.133,-.015,0.,graded=True)
 annulus('GradeSeal_'+ident,x,z,.0889,.091,-.015,0.,'rubber_aged',graded=True)
 bed=box('ReceiverBed_'+ident,[x-.15,-.35,z-.15],[x+.15,0.,z+.15],graded_top=True)
 tool=vertical('ReceiverBedAir_'+ident,x,z,[(.105,-.36),(.105,.10)]);boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
 # Cut the receiving pocket with a solid tool extending above the grade.
 # Subtracting the finished annular collar at a coincident graded top can
 # retain overlapping top fragments after float32 representation.
 tool=vertical('ReceiverCollarPocket_'+ident,x,z,[(.133,-.015),(.133,.05)],graded=True);boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
 receivers.append({**branch,'native_grade_y':height(x,z),'bed_owner':bed.name,'bed_rect':[x-.15,z-.15,x+.15,z+.15],'bed_bottom_y':-.35,'grade_collar':collar.name,'ground_port':'Source-owned 300 mm square fitted bed; matching source-owned provider port.'})
for trunk,ident in zip(study['trunks'],['WEST_CLEANOUT','EAST_CLEANOUT']):
 p=trunk['path'][0];x,y,z=p;top=height(x,z)-.04
 outer.append(sweep('CleanoutRiser_'+ident,[[x,y-.01,z],[x,top,z]],.1683));air.append(sweep('CleanoutRiserAir_'+ident,[[x,y-.005,z],[x,top+.01,z]],.1524))
 flange=annulus('CleanoutFlange_'+ident,x,z,.1524,.206,-.04,-.018,graded=True)
 cap=vertical('CleanoutCap_'+ident,x,z,[(.206,-.018),(.206,0.)],graded=True)
 for i in range(6):
  angle=2*math.pi*i/6;bx=x+.185*math.cos(angle);bz=z+.185*math.sin(angle);at=height(bx,bz)
  tool=vertical('CleanoutCapRecess_'+ident,bx,bz,[(.009,at-.008),(.009,at+.01)]);boolean(cap,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
  tool=vertical('CleanoutBoltAir_'+ident,bx,bz,[(.0055,at-.045),(.0055,at+.01)]);boolean(cap,tool,'DIFFERENCE');boolean(flange,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
  vertical('CleanoutBolt_'+ident+'_'+str(i),bx,bz,[(.0055,at-.037),(.0055,at-.008),(.008,at-.008),(.008,at-.001)])
 bed=box('CleanoutBed_'+ident,[x-.215,-.35,z-.215],[x+.215,0.,z+.215],graded_top=True)
 tool=vertical('CleanoutBedAir_'+ident,x,z,[(.1683,-.36),(.1683,.1)]);boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
 tool=vertical('CleanoutBedPocket_'+ident,x,z,[(.206,-.04),(.206,.05)],graded=True);boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
 cleanouts.append({'id':ident,'center':[x,z],'riser_axis':[[x,y-.01,z],[x,top,z]],'grade_y':height(x,z),'bed_owner':bed.name,'bed_rect':[x-.215,z-.215,x+.215,z+.215],'bed_bottom_y':-.35,'cover':cap.name,'ground_port':'Source-owned 430 mm square, matching source-owned provider port.'})
x,y,z=study['downstream']['point']
# The construction blank bolts need a receiving flange attached to the
# actual collector wall. Integrate that flange before opening the main bore.
outer.append(solid_loft('PropertyReceivingFlange',[[[x+.206*math.cos(i*2*math.pi/N),y+dy+.206*math.sin(i*2*math.pi/N),z+dz] for i in range(N)] for dy,dz in [(.00009,.018),(.00020,.040)]]))
wall=union(outer,'RoofCollectorClosedWall')
x,y,z=study['downstream']['point'];tool=box('RetainedPropertyPlaneCut',[x-1,y-1,z-1],[x+1,y+1,z]);boolean(wall,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
envelope=wall.copy();envelope.data=wall.data.copy();envelope.name='CollectorOuterEnvelopeCut';bpy.context.scene.collection.objects.link(envelope)
bore=union(air,'RoofCollectorInnerAir');boolean(wall,bore,'DIFFERENCE');bpy.data.objects.remove(bore,do_unlink=True)
for index,spec in enumerate(socket_specs):
 x,y,z=spec['center'];p=Vector(spec['center']);axis=Vector(spec['axis']);bed=box('MainSaddle_'+str(index),[x-.21,y-.30,z-.21],[x+.21,y+.02,z+.21]);tool=sweep('SaddleSeatCut_'+str(index),[list(p-axis*.35),list(p+axis*.35)],.185);boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True);boolean(bed,envelope,'DIFFERENCE');beds.append({**spec,'id':bed.name,'bottom_y':y-.30,'bounds':[x-.21,y-.30,z-.21,x+.21,y+.02,z+.21]})
bpy.data.objects.remove(envelope,do_unlink=True)
down=study['downstream']['point'];x,y,z=down
blank=solid_loft('RoofDrainPropertyBlank',[[[x+.206*math.cos(i*2*math.pi/N),y+dy+.206*math.sin(i*2*math.pi/N),z+dz] for i in range(N)] for dy,dz in [(0,0),(.00009,.018)]])
for i in range(8):
 angle=2*math.pi*i/8;bx=x+.185*math.cos(angle);by=y+.185*math.sin(angle)
 tool=sweep('PropertyBoltAir_'+str(i),[[bx,by-.00001,z-.002],[bx,by+.00025,z+.05]],.0075)
 for owner in [blank,wall]:boolean(owner,tool,'DIFFERENCE')
 bpy.data.objects.remove(tool,do_unlink=True)
 tool=sweep('PropertyBoltRecess_'+str(i),[[bx,by-.00001,z-.002],[bx,by+.0000325,z+.0065]],.0125);boolean(blank,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
 sweep('PropertyBlankBolt_'+str(i),[[bx,by+.0000325,z+.0065],[bx,by+.00023,z+.046]],.007)
 sweep('PropertyBlankBoltHead_'+str(i),[[bx,by+.0000025,z+.0005],[bx,by+.0000325,z+.0065]],.012)
 nut=sweep('PropertyBlankNut_'+str(i),[[bx,by+.00020,z+.040],[bx,by+.00023,z+.046]],.012)
 tool=sweep('PropertyNutAir_'+str(i),[[bx,by+.00019,z+.038],[bx,by+.00024,z+.048]],.007);boolean(nut,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
closed=bpy.data.collections.new('ClosedReceiverStocks');bpy.context.scene.collection.children.link(closed);closed.hide_render=True;groups=collections.defaultdict(list);stocks=[]
bpy.context.view_layer.update()
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bad=[e for e in bm.edges if not e.is_manifold]
 if bad:
  (O/'failed-native-edges.json').write_text(json.dumps({'owner':obj.name,'bad_edges':[[g(obj.location+v.co) for v in e.verts] for e in bad]},indent=2)+'\n',newline='\n');bm.to_mesh(obj.data);bpy.ops.wm.save_as_mainfile(filepath=str(O/'failed-native.blend'),compress=True)
 assert not bad,(obj.name,len(bad));volume=bm.calc_volume(signed=True);assert volume>0,obj.name;bm.to_mesh(obj.data)
 bounds=[g(obj.matrix_world@v.co) for v in obj.data.vertices];stocks.append({'name':obj.name,'material':obj['material_key'],'volume_m3':volume,'bounds':[min(p[i] for p in bounds) for i in range(3)]+[max(p[i] for p in bounds) for i in range(3)]})
 for axis in range(3):
  values=[(obj.location+v.co)[axis] for v in bm.verts]
  for k in range(math.ceil(min(values)/4),math.ceil(max(values)/4)):
   normal=Vector(tuple(int(i==axis) for i in range(3)));at=normal*(k*4)-obj.location;bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=at,plane_no=normal,dist=1e-8)
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
 for face in bm.faces:
  points=[obj.location+v.co for v in face.verts]
  if (points[1]-points[0]).cross(points[2]-points[0]).length<1e-11:continue
  center=sum(points,Vector())/3;key=(obj['material_key'],math.floor(center.x/4),math.floor(center.y/4),math.floor(center.z/4));groups[key].append(points)
 bm.free()
 for collection in list(obj.users_collection):collection.objects.unlink(obj)
 closed.objects.link(obj);obj.hide_render=True
parts=[]
for key,triangles in sorted(groups.items()):
 family,*cell=key;name='Receiver_'+family+'_'+'_'.join(map(str,cell));pivot=Vector([4*k+2 for k in cell])
 # The local float32 representation can collapse an already coincident
 # Boolean edge. Omit only triangles with zero represented area.
 local=[np.array([tuple(p-pivot) for p in t],dtype=np.float32) for t in triangles]
 local=[t for t in local if np.linalg.norm(np.cross(t[1].astype(np.float64)-t[0],t[2].astype(np.float64)-t[0]))>0]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(np.concatenate(local).tolist(),[],[(i,i+1,i+2) for i in range(0,3*len(local),3)]);mesh.update();uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 loop_normals=[];chart_uv=[];chart_tangents=[]
 for face in mesh.polygons:
  # Calculate from the actual represented local positions in double precision.
  # Boolean junction slivers retain every native coordinate; Blender's normal
  # fallback on those slivers can disagree with the true imported triangle.
  points=np.array([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
  normal=np.cross(points[1]-points[0],points[2]-points[0]);normal/=np.linalg.norm(normal)
  edges=[points[(i+1)%3]-points[i] for i in range(3)];longest=max(edges,key=lambda e:np.linalg.norm(e));u=longest/np.linalg.norm(longest);v=np.cross(normal,u)
  # A local triangle chart avoids subtracting two large UV numbers across
  # micrometre-wide faces. The chart still carries one actual metre per metre.
  origin=points[0]
  for loop in face.loop_indices:
   p=np.array(mesh.vertices[mesh.loops[loop].vertex_index].co[:],dtype=np.float64)-origin;value=(np.dot(p,u),np.dot(p,v));uv.data[loop].uv=value;chart_uv.append(value);chart_tangents.append(u.tolist());loop_normals.append(normal.tolist())
 mesh.normals_split_custom_set(loop_normals)
 # Explicit native chart attributes preserve the small chart coordinates
 # through the exporter's V-flip and MikkTSpace fallback on Boolean slivers.
 native_uv=mesh.attributes.new('_roof_chart_uv','FLOAT2','POINT')
 native_tangent=mesh.attributes.new('_roof_chart_tangent','FLOAT_VECTOR','POINT')
 for i,(uv_value,tangent_value) in enumerate(zip(chart_uv,chart_tangents)):
  native_uv.data[i].vector=uv_value;native_tangent.data[i].vector=tangent_value
 mesh.materials.append(materials[family]);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;parts.append({'name':name,'material':family,'triangles':len(local),'zero_area_after_local_encoding':len(triangles)-len(local)})
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True);native=O/'roof_drainage_receivers.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for part in parts:bpy.data.objects[part['name']].select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='_ROOF_CHART_UV':self.chart_uv=np.array(data['data'],dtype=np.float64).reshape(-1,2)
  elif attribute=='_ROOF_CHART_TANGENT':
   native=np.array(data['data'],dtype=np.float64).reshape(-1,3);self.chart_tangent=np.column_stack((native[:,0],native[:,2],-native[:,1]))
  elif attribute=='NORMAL':self.normals=np.array(data['data'],dtype=np.float64).reshape(-1,3)
  elif attribute=='TEXCOORD_0':
   data['data']=np.column_stack((self.chart_uv[:,0],-self.chart_uv[:,1])).astype(np.float32)
  elif attribute=='TANGENT':
   n=self.normals;t=self.chart_tangent-n*np.sum(n*self.chart_tangent,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
   data['data']=np.column_stack((t,-np.ones(len(t)))).astype(np.float32)
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_drainage_receivers.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,export_attributes=True,use_selection=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','source_bindings':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [study_path,grades_path,Path(__file__)]},'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_stocks':stocks,'parts':parts,'receivers':receivers,'cleanouts':cleanouts,'main_saddle_beds':beds,'trunks':study['trunks'],'downstream':study['downstream'],'open_work':['Actual native bores, union junctions, wall thickness and fitted bearing/grade interfaces','Soil and original paving provider ports/reservations','Retained neighboring foundation and existing alley collector native clearance','UV/tangents and direct native/game renders','Production route and installed candidate verification']}
for path in [O/'roof_drainage_receivers_construction.json',R/'game/tests/fixtures/orison_roof_drainage_receivers.json']:path.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE ROOF RECEIVERS',len(stocks),'closed stocks;',len(beds),'fitted main saddles;',len(parts),'bounded parts;',sum(q['triangles'] for q in parts),'triangles')
