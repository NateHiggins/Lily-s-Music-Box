"""Complete uncovered source ceiling tops, retaining earlier slab owners.

Production omissions, ports, upper walking floors, roof bulkheads and the
native service-alley paving fields remain with their existing owners.
"""
from pathlib import Path
import json,math,collections,hashlib
import bpy
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
root=ROOT
layout_text=(ROOT/'game/data/orison_v2_blockout.json').read_text()
layout=json.loads(layout_text)
layout_hash=hashlib.sha256(layout_text.replace('\r\n','\n').encode()).hexdigest()
alley_hash=hashlib.sha256((ROOT/'game/assets/props/service_alley.glb').read_bytes()).hexdigest()
with bpy.data.libraries.load(str(root/'art/blender/service_alley.blend'),link=False) as (available,loaded):
 loaded.objects=[name for name in available.objects if name.startswith('PavingFoundation') or name.startswith('PavingSlab')]
fields=[];paving_tops=[]
for obj in loaded.objects:
 assert obj.parent is None,'Parented alley field requires its full source frame'
 pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale)
 corners=[pose@Vector(p) for p in obj.bound_box]
 if obj.name.startswith('PavingSlab'):
  paving_tops.append(round(max(p.z for p in corners),5));continue
 fields.append(dict(owner=obj.name,rect=[round(v,5) for v in [min(p.x for p in corners),-max(p.y for p in corners),max(p.x for p in corners),-min(p.y for p in corners)]],paving_top=0,substrate_y=[min(p.z for p in corners),max(p.z for p in corners)]))
assert paving_tops and max(paving_tops)==0,'Reinspect the changed alley paving datum'
levels={r['id']:r['y'] for r in layout['levels']}
excluded={'F01_STREET_APRON','F01_REAR_APRON'}
def subtract(rect,cut):
 a,b,c,d=rect;e,f,g,h=cut;lo=max(a,e);hi=min(c,g);low=max(b,f);high=min(d,h)
 if lo>=hi-1e-7 or low>=high-1e-7:return [rect]
 return [r for r in [(a,b,lo,d),(hi,b,c,d),(lo,b,hi,low),(lo,high,hi,d)] if r[2]-r[0]>1e-6 and r[3]-r[1]>1e-6]
def pieces(record,surface):
 result=[record['rect']]
 for aperture in layout['slab_openings']:
  if aperture['space']==record['id'] and aperture['surface']==surface:result=[r for p in result for r in subtract(p,aperture['rect'])]
 return result
floors=[]
for field in fields:
 floors.append((field['paving_top'],field['rect'],'ServiceAlley/'+field['owner']))
for r in layout['spaces']+layout['platforms']:
 if r.get('no_floor') or r['id'] in excluded:continue
 floors.extend((levels[r['level']],p,r['id']) for p in pieces(r,'Floor'))
out=[]
for r in layout['spaces']:
 if r.get('no_ceiling') or r['id'] in excluded or r['level']=='ROOF':continue
 y=levels[r['level']]+layout['dimensions']['clear_height']+layout['dimensions']['slab_thickness']
 exposed=pieces(r,'Ceiling');owners=[]
 for datum,p,owner in floors:
  if abs(datum-y)<1e-6:
   before=exposed;exposed=[rect for original in exposed for rect in subtract(original,p)]
   if before!=exposed:owners.append(owner)
 if exposed:out.append(dict(space=r['id'],level=r['level'],top_y=y,rectangles=exposed,area_m2=sum((p[2]-p[0])*(p[3]-p[1]) for p in exposed),subtracted_upper_owners=owners))
source=dict(evidence_class='INERT',method='Remaining actual runtime ceiling owners minus their source ports and coincident upper floors/platforms. Street/apron omissions and completed roof bulkheads are excluded. Retained native service-alley fields also own their entire pavement envelopes. Native/physical acceptance remains separate.',records=out)
levels={r['id']:r['y'] for r in layout['levels']};depth=layout['dimensions']['slab_thickness']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
material=bpy.data.materials.new('concrete');material.diffuse_color=(.36,.34,.30,1)
construction=bpy.data.collections.new('CeilingTopConstruction');bpy.context.scene.collection.children.link(construction)
construction.hide_viewport=True;construction.hide_render=True
def subtract(rect,cut):
 a,b,c,d=rect;e,f,g,h=cut;lo=max(a,e);hi=min(c,g);low=max(b,f);high=min(d,h)
 if lo>=hi-1e-7 or low>=high-1e-7:return [rect]
 return [r for r in [(a,b,lo,d),(hi,b,c,d),(lo,b,hi,low),(lo,high,hi,d)] if r[2]-r[0]>1e-6 and r[3]-r[1]>1e-6]
floors=[]
for field in fields:
 floors.append((field['paving_top'],field['rect']))
for room in layout['spaces']+layout['platforms']:
 if room.get('no_floor') or room['id'] in ['F01_STREET_APRON','F01_REAR_APRON']:continue
 rects=[room['rect']]
 for port in layout['slab_openings']:
  if port['space']==room['id'] and port['surface']=='Floor':rects=[r for p in rects for r in subtract(p,port['rect'])]
 floors.extend((levels[room['level']],r) for r in rects)
by_level=collections.defaultdict(list)
for row in source['records']:
 for i,r in enumerate(row['rectangles']):by_level[round(row['top_y'],5)].append((row['space'],i,[round(v,5) for v in r]))
parts=[];reports=[];all_quads=0
for top,records in sorted(by_level.items()):
 retained=[[round(v,5) for v in r] for y,r in floors if abs(y-top)<1e-6]
 coverage=[r for _,_,r in records]+retained
 xs=sorted(set(round(x,5) for r in coverage for x in [r[0],r[2]]));zs=sorted(set(round(z,5) for r in coverage for z in [r[1],r[3]]))
 def inside(x,z):return any(r[0]<x<r[2] and r[1]<z<r[3] for r in coverage)
 for space,i,r in records:
  nx=math.ceil((r[2]-r[0])/4);nz=math.ceil((r[3]-r[1])/4)
  for ix in range(nx):
   for iz in range(nz):
    a=r[0]+(r[2]-r[0])*ix/nx;c=r[0]+(r[2]-r[0])*(ix+1)/nx
    b=r[1]+(r[3]-r[1])*iz/nz;d=r[1]+(r[3]-r[1])*(iz+1)/nz
    faces=[[(a,-b,top),(a,-d,top),(c,-d,top),(c,-b,top)]]
    for side,fixed,start,end,cuts,edge in [('west',a,b,d,zs,ix==0),('east',c,b,d,zs,ix==nx-1),('south',b,a,c,xs,iz==0),('north',d,a,c,xs,iz==nz-1)]:
     if not edge:continue
     stations=sorted({start,end,*[v for v in cuts if start+1e-6<v<end-1e-6]})
     for low,high in zip(stations,stations[1:]):
      x,z=((fixed+(-1e-5 if side=='west' else 1e-5)),(low+high)/2) if side in ['west','east'] else ((low+high)/2,fixed+(-1e-5 if side=='south' else 1e-5))
      if inside(x,z):continue
      if side=='west':face=[(fixed,-low,top-depth),(fixed,-high,top-depth),(fixed,-high,top),(fixed,-low,top)]
      elif side=='east':face=[(fixed,-low,top-depth),(fixed,-low,top),(fixed,-high,top),(fixed,-high,top-depth)]
      elif side=='south':face=[(low,-fixed,top-depth),(low,-fixed,top),(high,-fixed,top),(high,-fixed,top-depth)]
      else:face=[(low,-fixed,top-depth),(high,-fixed,top-depth),(high,-fixed,top),(low,-fixed,top)]
      faces.append(face)
    name='%s_Top_%02d_%02d_%02d'%(space,i,ix,iz)
    mesh=bpy.data.meshes.new(name);vertices=[p for f in faces for p in f]
    mesh.from_pydata(vertices,[],[tuple(range(j,j+4)) for j in range(0,len(vertices),4)]);mesh.update()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
     drop=max(range(3),key=lambda k:abs(face.normal[k]));u,v=((1,2),(0,2),(0,1))[drop]
     for loop in face.loop_indices:
      p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u],p[v])
    mesh.materials.append(material);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);parts.append(obj)
    bound=bpy.data.objects.new(name+'_SourceBound',None);bound.empty_display_type='CUBE';bound.empty_display_size=.5
    bound.location=((a+c)/2,-(b+d)/2,top-depth/2);bound.scale=(c-a,d-b,depth);construction.objects.link(bound)
    reports.append(dict(id=name,space=space,bounds=[a,top-depth,b,c,top,d],quads=len(faces),internal_caps=False,duplicate_underside=False));all_quads+=len(faces)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ceiling_top_closures.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
 partitions=0
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/ceiling_top_closures.glb'),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
(ROOT/'art/blender/ceiling_top_closures_construction.json').write_text(json.dumps(dict(evidence_class='INERT',source=source,source_layout_sha256_lf=layout_hash,source_alley_sha256=alley_hash,parts=reports,triangles=all_quads*2,ownership='Only uncovered upper faces and true exterior edges; retained ceiling undersides and upper walking slabs remain.'),indent=2)+'\n')
print('CEILING TOP CLOSURES:',len(parts),'pieces;',all_quads*2,'triangles; retained ceiling and exterior owners preserved')
