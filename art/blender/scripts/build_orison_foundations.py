"""Source-owned exterior foundation stems and basement masonry footings.

This construction recipe repairs physical contact; it makes no soil, load or
reinforcement-capacity determination. Existing rooms, risers and wall profiles
are excluded from the ground stems. No service apertures are introduced.
"""
from pathlib import Path
import json,math,collections,hashlib
import bpy,bmesh
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout_text=(ROOT/'game/data/orison_v2_blockout.json').read_text()
layout=json.loads(layout_text)
layout_hash=hashlib.sha256(layout_text.replace('\r\n','\n').encode()).hexdigest()
masonry_hash=hashlib.sha256((ROOT/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest()
with bpy.data.libraries.load(str(ROOT/'art/blender/exterior_masonry.blend'),link=False) as (available,loaded):
    assert 'PreServiceMasonry' in available.collections,'Original masonry construction is required'
    loaded.collections=['PreServiceMasonry']
bounds=[]
for obj in loaded.collections[0].objects:
    assert obj.type=='EMPTY' and obj.parent is None,'Reinspect changed masonry authority'
    p=obj.location;s=obj.scale;at=[p.x,p.z,-p.y];size=[s.x,s.z,s.y]
    bounds.append(dict(name=obj.name,bounds=[at[i]-size[i]/2 for i in range(3)]+[at[i]+size[i]/2 for i in range(3)]))
levels={r['id']:r['y'] for r in layout['levels']}
slab=layout['dimensions']['slab_thickness'];partition=layout['dimensions']['partition_wall'];outer=layout['dimensions']['outer_wall']
def rectangle(record):
    b=[round(x,5) for x in record['bounds']];r=[b[0],b[2],b[3],b[5]];name=record['name']
    if '_south_' in name:r[3]+=partition
    elif '_north_' in name:r[1]-=partition
    elif '_west_' in name:r[2]+=partition
    elif '_east_' in name:r[0]-=partition
    return [round(x,5) for x in r]
def subtract(rect,cut):
    a,b,c,d=rect;e,f,g,h=cut;lo=max(a,e);hi=min(c,g);low=max(b,f);high=min(d,h)
    if lo>=hi-1e-7 or low>=high-1e-7:return [rect]
    return [r for r in [(a,b,lo,d),(hi,b,c,d),(lo,b,hi,low),(lo,high,hi,d)] if r[2]-r[0]>1e-6 and r[3]-r[1]>1e-6]
ground=[rectangle(r) for r in bounds if r['name'].startswith('F01_') and abs(r['bounds'][1]-(levels['F01']-slab))<.00001]
basement=[rectangle(r) for r in bounds if r['name'].startswith('B1_') and abs(r['bounds'][1]-(levels['B1']-slab))<.00001]
room_masks=[]
for room in layout['spaces']:
    if room['level']!='B1':continue
    r=room['rect'];room_masks.append([r[0]-partition*.5,r[1]-partition*.5,r[2]+partition*.5,r[3]+partition*.5])
masks=room_masks+basement+[r['rect'] for r in layout['risers']]
stems=ground
for mask in masks:stems=[r for original in stems for r in subtract(original,mask)]
footings=[]
for r in stems+basement:
    # A 700 mm course under the retained 350 mm wall is a construction
    # recipe, not a soil-bearing or reinforcement-capacity determination.
    margin=outer*.5
    footings.append([r[0]-margin,r[1]-margin,r[2]+margin,r[3]+margin])
def union(rects):
    xs=sorted(set(round(v,5) for r in rects for v in [r[0],r[2]]));zs=sorted(set(round(v,5) for r in rects for v in [r[1],r[3]]))
    rows=[]
    for z0,z1 in zip(zs,zs[1:]):
        runs=[];start=None;end=None
        for x0,x1 in zip(xs,xs[1:]):
            inside=any(r[0]<=(x0+x1)*.5<=r[2] and r[1]<=(z0+z1)*.5<=r[3] for r in rects)
            if inside:
                if start is None:start=x0
                end=x1
            elif start is not None:runs.append([start,z0,end,z1]);start=None
        if start is not None:runs.append([start,z0,end,z1])
        for run in runs:
            prior=next((p for p in rows if p[0]==run[0] and p[2]==run[2] and abs(p[3]-z0)<1e-6),None)
            if prior is not None:prior[3]=z1
            else:rows.append(run)
    return rows
stems=union(stems);footings=union(footings)
data=dict(evidence_class='INERT',authority=['game/data/orison_v2_blockout.json:dimensions/spaces','art/blender/exterior_masonry.blend:PreServiceMasonry'],
          method='Full ground masonry/partition profiles outside basement room/wall/riser projections; unioned stems and footings. No basement occupation, portal or service port is filled.',
          stem_y=[levels['B1']-slab,levels['F01']-slab],footing_y=[levels['B1']-slab-2*slab,levels['B1']-slab],stems=stems,footings=footings,basement_masks=masks)
source=data
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
material=bpy.data.materials.new('concrete');material.diffuse_color=(.36,.34,.30,1)
construction=bpy.data.collections.new('FoundationConstruction');bpy.context.scene.collection.children.link(construction)
construction.hide_render=True;construction.hide_viewport=True
for family,key in [('Stem','stems'),('Footing','footings')]:
    lo,hi=source[family.lower()+'_y']
    for i,r in enumerate(source[key]):
        obj=bpy.data.objects.new(family+'_%03d'%i,None);obj.empty_display_type='CUBE';obj.empty_display_size=.5
        obj.location=((r[0]+r[2])/2,-(r[1]+r[3])/2,(lo+hi)/2);obj.scale=(r[2]-r[0],r[3]-r[1],hi-lo)
        construction.objects.link(obj)
rects=source['stems']+source['footings']
def grid(axis):
    values=sorted(set(round(v,5) for r in rects for v in [r[axis],r[axis+2]]))
    cuts=set(values)
    cuts.update(4*i for i in range(math.floor(values[0]/4),math.ceil(values[-1]/4)+1) if values[0]<4*i<values[-1])
    return sorted(cuts)
xs,zs=grid(0),grid(1)
def cells(rects):
    return {(ix,iz) for ix,(a,c) in enumerate(zip(xs,xs[1:])) for iz,(b,d) in enumerate(zip(zs,zs[1:]))
            if any(r[0]<(a+c)/2<r[2] and r[1]<(b+d)/2<r[3] for r in rects)}
stem,foot=cells(source['stems']),cells(source['footings'])
assert not stem-foot,'Footings must cover every stem'
quads=[]
for family,occupied,ybounds in [('Stem',stem,source['stem_y']),('Footing',foot,source['footing_y'])]:
    lo,hi=ybounds
    for ix,iz in sorted(occupied):
        a,c=xs[ix],xs[ix+1];b,d=zs[iz],zs[iz+1]
        faces=[]
        if family=='Stem' or (ix,iz) not in stem:faces.append([(a,hi,b),(a,hi,d),(c,hi,d),(c,hi,b)])
        if family=='Footing':faces.append([(a,lo,b),(c,lo,b),(c,lo,d),(a,lo,d)])
        if (ix-1,iz) not in occupied:faces.append([(a,lo,b),(a,lo,d),(a,hi,d),(a,hi,b)])
        if (ix+1,iz) not in occupied:faces.append([(c,lo,b),(c,hi,b),(c,hi,d),(c,lo,d)])
        if (ix,iz-1) not in occupied:faces.append([(a,lo,b),(a,hi,b),(c,hi,b),(c,lo,b)])
        if (ix,iz+1) not in occupied:faces.append([(a,lo,d),(c,lo,d),(c,hi,d),(a,hi,d)])
        quads.extend((family,face) for face in faces)
# Keep one editable complete union; weld exact cell boundaries and inspect its
# closure before spatial export, which retains no artificial culling end caps.
vertices=[(p[0],-p[2],p[1]) for _,face in quads for p in face]
mesh=bpy.data.meshes.new('FoundationUnion');mesh.from_pydata(vertices,[],[tuple(range(i,i+4)) for i in range(0,len(vertices),4)]);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
open_edges=sum(not e.is_manifold for e in bm.edges)
print('FOUNDATION UNION:',len(quads),'quads;',len(bm.verts),'welded vertices;',open_edges,'non-manifold edges')
assert open_edges==0,'Native foundation union is not closed'
bm.to_mesh(mesh);bm.free()
complete=bpy.data.objects.new('FoundationUnion',mesh);construction.objects.link(complete)
groups=collections.defaultdict(list)
for family,face in quads:
    center=[sum(p[axis] for p in face)/4 for axis in range(3)]
    key=(family,math.floor(center[0]/4+1e-9),math.floor(center[2]/4+1e-9))
    groups[key].append(face)
parts=[];reports=[]
for (family,ix,iz),faces in sorted(groups.items()):
    name='%s_%s_%s'%(family,'P%d'%ix if ix>=0 else 'N%d'%-ix,'P%d'%iz if iz>=0 else 'N%d'%-iz)
    vertices=[(p[0],-p[2],p[1]) for face in faces for p in face]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[tuple(range(i,i+4)) for i in range(0,len(vertices),4)]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);parts.append(obj)
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        drop=max(range(3),key=lambda k:abs(face.normal[k]));u,v=((1,2),(0,2),(0,1))[drop]
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u],p[v])
    mesh.materials.append(material)
    lo=[min(p[k] for face in faces for p in face) for k in range(3)];hi=[max(p[k] for face in faces for p in face) for k in range(3)]
    assert max(hi[k]-lo[k] for k in range(3))<=4.000001
    reports.append(dict(id=name,bounds=lo+hi,quads=len(faces),internal_caps=False))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/orison_foundations.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/orison_foundations.glb'),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==len(parts)
(ROOT/'art/blender/orison_foundations_construction.json').write_text(json.dumps(dict(evidence_class='INERT',parts=reports,quads=len(quads),non_manifold_edges=open_edges,source_plan=source,source_layout_sha256_lf=layout_hash,source_masonry_sha256=masonry_hash),indent=2)+'\n')
print('ORISON FOUNDATIONS:',len(parts),'bounded parts;',len(quads)*2,'triangles; retained basement volumes preserved')
