"""Derive the V2 outer masonry leaf from the authored occupied footprint.

The existing partition retains its room-side face. This adds the remaining
outer-wall thickness outside it, with the same aperture roster and storeys.
"""
from pathlib import Path
import json, math
import bpy
import hashlib

ROOT=Path(__file__).resolve().parents[3]
source=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
partition=float(source['dimensions']['partition_wall'])
outer=float(source['dimensions']['outer_wall'])
inner=partition/2
reach=outer-inner
height=float(source['dimensions']['floor_to_floor'])
slab=float(source['dimensions']['slab_thickness'])
levels={r['id']:float(r['y']) for r in source['levels']}
rooms={r['id']:r for r in source['spaces'] if not r.get('open_shell')}
edges=[]
corners=[]

def occupied(blockers,x,z):
 return any(r[0]-.001<x<r[2]+.001 and r[1]-.001<z<r[3]+.001 for r in blockers)

for level in levels:
 local=[r for r in rooms.values() if r['level']==level]
 blockers=[r['rect'] for r in local]+[r['rect'] for r in source['risers']]
 level_edges=[]
 for room in local:
  x0,z0,x1,z1=room['rect']
  segments=[dict(side=side) for side in room.get('wall_sides',['south','north','west','east'])]+room.get('wall_extensions',[])
  for segment in segments:
   side=segment['side']
   along_x=side in ['south','north'];sign=-1 if side in ['south','west'] else 1
   fixed={'south':z0,'north':z1,'west':x0,'east':x1}[side]
   start,end=(x0,x1) if along_x else (z0,z1)
   start,end=segment.get('start',start),segment.get('end',end)
   cuts={start,end}
   for rect in blockers:
    low,high=(rect[0],rect[2]) if along_x else (rect[1],rect[3])
    cuts.update(v for v in [low,high] if start<v<end)
   cuts=sorted(cuts);runs=[]
   for a,b in zip(cuts,cuts[1:]):
    middle=(a+b)/2
    x,z=(middle,fixed+sign*(inner+.01)) if along_x else (fixed+sign*(inner+.01),middle)
    if occupied(blockers,x,z):continue
    # Preserve narrow light slots where opposing leaves would bury windows.
    x_far,z_far=(middle,fixed+sign*(2*reach+.01)) if along_x else (fixed+sign*(2*reach+.01),middle)
    if occupied(blockers,x_far,z_far):continue
    if runs and abs(runs[-1][1]-a)<.001:runs[-1][1]=b
    else:runs.append([a,b])
   for a,b in runs:
    level_edges.append(dict(room=room['id'],level=level,side=side,axis='x' if along_x else 'z',sign=sign,fixed=fixed,start=a,end=b))
 edges.extend(level_edges)
 # Fill convex exterior corners. Straight leaves stop at their semantic
 # endpoints; this quarter-column closes the new outer quadrant without
 # duplicating either outward face.
 vertices={(r['rect'][i],r['rect'][j]) for r in local for i in [0,2] for j in [1,3]}
 for x,z in vertices:
  quadrants=[(sx,sz) for sx in [-1,1] for sz in [-1,1] if occupied(blockers,x+sx*.08,z+sz*.08)]
  if len(quadrants)!=1:continue
  sx,sz=(-quadrants[0][0],-quadrants[0][1])
  ends=[e for e in level_edges if abs(e['fixed']-(z if e['axis']=='x' else x))<.001 and any(abs(v-(x if e['axis']=='x' else z))<.001 for v in [e['start'],e['end']])]
  if {e['axis'] for e in ends}=={'x','z'}:corners.append((level,x,z,sx,sz))

def holes(edge):
 result=[]
 for table in ['doors','openings','windows']:
  for record in source.get(table,[]):
   if record['level']!=edge['level']:continue
   if table=='windows':
    if record['space']!=edge['room'] or record['axis']!=edge['axis']:continue
   elif edge['room'] not in record['connects']:continue
   if table=='openings' and record['axis']!=edge['axis']:continue
   axis=0 if edge['axis']=='x' else 1
   if abs(record['center'][1-axis]-edge['fixed'])>.001:continue
   center=record['center'][axis];half=record['width']/2;sill=record.get('sill',0)
   if center+half<=edge['start'] or center-half>=edge['end']:continue
   result.append((center-half,sill,center+half,sill+record['height'],record))
 return result

def subtract(rect,hole):
 a,b,c,d=rect;e,f,g,h=hole[:4]
 lo=max(a,e);hi=min(c,g);bottom=max(b,f);top=min(d,h)
 if hi<=lo or top<=bottom:return [rect]
 result=[]
 if lo>a:result.append((a,b,lo,d))
 if hi<c:result.append((hi,b,c,d))
 if bottom>b:result.append((lo,b,hi,bottom))
 if top<d:result.append((lo,top,hi,d))
 return result

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('PreServiceMasonry')
bpy.context.scene.collection.children.link(construction)
construction.hide_render=True
construction.hide_viewport=True
materials=[]
for name,color in [('CommonBrick',(.43,.30,.23)),('FaceBrick',(.39,.17,.10))]:
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);materials.append(mat)

def solid_piece(name,at,size,front=False,corner=False):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
 obj=bpy.context.object;obj.name=name;obj.scale=(size[0],size[2],size[1])
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for mat in materials:obj.data.materials.append(mat)
 for face in obj.data.polygons:
  face.material_index=1 if front or (corner and face.normal.y>.5) else 0
 return obj

def subtract_volume(bounds,cut):
 lo=[max(bounds[i],cut[i]) for i in range(3)]
 hi=[min(bounds[i+3],cut[i+3]) for i in range(3)]
 if any(hi[i]<=lo[i]+1e-7 for i in range(3)):return [bounds]
 a,b,c,d,e,f=bounds;x,y,z,u,v,w=(*lo,*hi)
 parts=[(a,b,c,x,e,f),(u,b,c,d,e,f),(x,b,c,u,y,f),
        (x,v,c,u,e,f),(x,y,c,u,v,z),(x,y,w,u,v,f)]
 return [p for p in parts if all(p[i+3]-p[i]>1e-6 for i in range(3))]

# At a setback, the next storey's outer leaf can sit inside the larger
# ceiling slab below. That slab owns its full 200 mm volume and underside;
# masonry starts at its top rather than emitting a competing brick soffit.
# Subtract real ceiling ports first so service openings keep their owner.
ceiling_volumes=[]
for room in source['spaces']:
 if room.get('no_ceiling') or room['id'] in ['F01_STREET_APRON','F01_REAR_APRON']:continue
 rects=[room['rect']]
 for opening in source.get('slab_openings',[]):
  if opening['space']==room['id'] and opening['surface']=='Ceiling':
   cut=opening['rect']
   rects=[piece for original in rects for piece in subtract(original,(cut[0],cut[1],cut[2],cut[3]))]
 y=levels[room['level']]+float(source['dimensions']['clear_height'])
 for a,b,c,d in rects:ceiling_volumes.append(dict(owner=room['id'],bounds=(a,y,b,c,y+slab,d)))
slab_fits=[]
stock_bounds=[]
door_corner_fits=[]
door_clearance_cuts=[]

def rear_leaf_corner_cut(bounds):
 # Fit only the outer return that reaches into the original rear doorway.
 # The source record owns its aperture, left hinge and outward quarter turn.
 door=next(row for row in source['doors'] if row['id']=='F01_REAR_SERVICE_DOOR')
 assert door['yaw']==0 and door['hinge']=='left' and door['swing']=='out'
 x,z=door['center'];width=door['width'];pivot=(x-width/2,z+.026)
 def clip(poly,axis,edge,greater):
  result=[]
  for a,b in zip(poly,poly[1:]+poly[:1]):
   aa=(a[axis]>=edge) if greater else (a[axis]<=edge)
   bb=(b[axis]>=edge) if greater else (b[axis]<=edge)
   if aa:result.append(a)
   if aa!=bb:
    t=(edge-a[axis])/(b[axis]-a[axis])
    result.append(tuple(a[i]+t*(b[i]-a[i]) for i in range(2)))
  return result
 points=[]
 # 80 mm half-depth conservatively includes the retained knobs and braces.
 for step in range(361):
  angle=-math.pi*.5*step/360;co,si=math.cos(angle),math.sin(angle)
  poly=[(pivot[0]+u*co+v*si,pivot[1]-u*si+v*co)
        for u,v in [(0,-.08-.026),(width,-.08-.026),(width,.08-.026),(0,.08-.026)]]
  for axis,edge,greater in [(0,bounds[0],True),(0,bounds[3],False),(1,bounds[2],True),(1,bounds[5],False)]:
   poly=clip(poly,axis,edge,greater)
   if not poly:break
  points.extend(poly)
 if not points:return None
 floor=levels[door['level']]
 return (max(bounds[0],min(p[0] for p in points)-.002),floor,
         max(bounds[2],min(p[1] for p in points)-.002),
         min(bounds[3],max(p[0] for p in points)+.002),floor+door['height'],
         min(bounds[5],max(p[1] for p in points)+.002))

rear_edge=next(edge for edge in edges if edge['room']=='F01_SERVICE_CORE' and edge['side']=='west')
rear_bounds=(rear_edge['fixed']-inner-reach,levels[rear_edge['level']]-slab,rear_edge['start'],
             rear_edge['fixed']-inner,levels[rear_edge['level']]+height-slab,rear_edge['end'])
rear_clearance=rear_leaf_corner_cut(rear_bounds)
assert rear_clearance is not None
door_clearance_cuts.append(dict(owner='F01_REAR_SERVICE_DOOR',bounds=rear_clearance))

def box(name,at,size,front=False,corner=False):
 bounds=tuple(at[i]-size[i]/2 for i in range(3))+tuple(at[i]+size[i]/2 for i in range(3))
 datum=bpy.data.objects.new(name+'_ConstructionBound',None)
 datum.empty_display_type='CUBE';datum.empty_display_size=.5
 datum.location=(at[0],-at[2],at[1]);datum.scale=(size[0],size[2],size[1])
 construction.objects.link(datum)
 parts=[bounds]
 for ceiling in ceiling_volumes:
  before=parts
  parts=[p for original in parts for p in subtract_volume(original,ceiling['bounds'])]
  if before!=parts:slab_fits.append(dict(stock=name,ceiling=ceiling['owner'],removed_m3=sum(math.prod(p[i+3]-p[i] for i in range(3)) for p in before)-sum(math.prod(p[i+3]-p[i] for i in range(3)) for p in parts)))
 for opening in source.get('masonry_service_openings',[]):
  assert opening['owner']=='ExteriorMasonry'
  parts=[p for original in parts for p in subtract_volume(original,opening['bounds'])]
 before=parts
 parts=[p for original in parts for p in subtract_volume(original,rear_clearance)]
 removed=sum(math.prod(p[i+3]-p[i] for i in range(3)) for p in before)-sum(math.prod(p[i+3]-p[i] for i in range(3)) for p in parts)
 if removed>1e-9:door_corner_fits.append(dict(stock=name,removed_m3=removed))
 for index,p in enumerate(parts):
  center=tuple((p[i]+p[i+3])/2 for i in range(3));extent=tuple(p[i+3]-p[i] for i in range(3))
  label=name if len(parts)==1 and parts[0]==bounds else name+f'_FittedPiece{index:02d}'
  obj=solid_piece(label,center,extent,front,corner)
  stock_bounds.append(dict(name=obj.name,bounds=p))

window_spans={};door_spans={}
for edge in edges:
 sections=[(edge['start'],-slab,edge['end'],height-slab)]
 for hole in holes(edge):
  sections=[piece for section in sections for piece in subtract(section,hole)]
  record=hole[4];fixed=edge['fixed'];sign=edge['sign']
  low,high=sorted([fixed-sign*inner,fixed+sign*reach])
  if 'space' in record and 'sill' in record:
   previous=window_spans.get(record['id'],[low,high])
   window_spans[record['id']]=[min(previous[0],low),max(previous[1],high)]
  elif record in source['doors']:
   # The door's local Z can reverse under authored yaw. Store local spans.
   factor=math.cos(record['yaw']) if edge['axis']=='x' else math.sin(record['yaw'])
   span=sorted([(low-fixed)*factor,(high-fixed)*factor])
   previous=door_spans.get(record['id'],span)
   door_spans[record['id']]=[min(previous[0],span[0]),max(previous[1],span[1])]
 for a,b,c,d in sections:
  middle=(a+c)/2;fixed=edge['fixed']+edge['sign']*(inner+reach)/2;y=levels[edge['level']]+(b+d)/2
  at=(middle,y,fixed) if edge['axis']=='x' else (fixed,y,middle)
  size=(c-a,d-b,reach-inner) if edge['axis']=='x' else (reach-inner,d-b,c-a)
  box(edge['room']+'_'+edge['side'],at,size,edge['side']=='south' and edge['level']!='B1')
for level,x,z,sx,sz in corners:
 box(level+'_Corner',(x+sx*reach/2,levels[level]+height/2-slab,z+sz*reach/2),(reach,height,reach),corner=level!='B1' and sz<0)

for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 # Edit-friendly UVs in metres; production catalogue remains triplanar.
 for layer in list(obj.data.uv_layers):obj.data.uv_layers.remove(layer)
 uv=obj.data.uv_layers.new(name='Metres')
 uv.active_render=True
 for face in obj.data.polygons:
  axis=max(range(3),key=lambda i:abs(face.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
  for loop in face.loop_indices:
   v=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
   uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/exterior_masonry.blend'))
bpy.ops.object.select_all(action='DESELECT')
export_meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
for obj in export_meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=export_meshes[0]
bpy.ops.object.join();mesh=bpy.context.object;mesh.name='ExteriorMasonry'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
class ExportUVHandedness:
 partitions=0
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':
   data['data'][:,3]*=-1
   type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/exterior_masonry.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==2

(ROOT/'art/blender/exterior_masonry_slab_fit.json').write_text(json.dumps(dict(
 evidence_class='INERT',source_sha256_lf=hashlib.sha256((ROOT/'game/data/orison_v2_blockout.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
 ceiling_volumes=ceiling_volumes,slab_fits=slab_fits,stocks=stock_bounds,
 door_clearance_cuts=door_clearance_cuts,door_corner_fits=door_corner_fits,
 removed_m3=sum(row['removed_m3'] for row in slab_fits)),indent=2)+'\n',encoding='utf-8',newline='\n')

def dictionary(name,values):
 lines=[f'const {name} := {{']
 for key,span in sorted(values.items()):lines.append(f'\t"{key}": Vector2({span[0]:.9f},{span[1]:.9f}),')
 return '\n'.join(lines+['}'])
generated='extends RefCounted\n## Generated by build_exterior_masonry.py; metres in the authored building frame.\n'
generated+=dictionary('WINDOW_SPANS',window_spans)+'\n'+dictionary('DOOR_SPANS',door_spans)+'\n'
(ROOT/'game/scripts/generated/v2_exterior_masonry.gd').write_text(generated,encoding='utf-8',newline='\n')
print('EXTERIOR MASONRY',len(edges),'exposed edges;',len(corners),'corners;',len(window_spans),'window reveals;',len(door_spans),'door reveals')
