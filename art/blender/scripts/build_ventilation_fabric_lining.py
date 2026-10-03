"""Fit 2 mm steel to authored wall, chase and outer-leaf service apertures.

The existing route and structural sources govern every seat. Axis-aligned
volume subtraction keeps bends open without Boolean triangulation slivers.
The native file retains editable construction datums; exports have four draws.
"""
from pathlib import Path
import json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
source=json.loads((ROOT/'art/data/orison_v2/ventilation_fabric_source.json').read_text())
graph=json.loads((ROOT/'game/data/orison_v2/completion_interiors.json').read_text())['ventilation']
levels={r['id']:r['y'] for r in layout['levels']}
rooms={r['id']:r for r in layout['spaces']}
risers={r['id']:r for r in layout['risers']}
anchors={r['id']:r for r in layout['anchors']}
EPS=1e-6
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
steel=bpy.data.materials.new('metal');steel.diffuse_color=(.32,.31,.28,1)
construction=bpy.data.collections.new('EditableLiningSeats')
bpy.context.scene.collection.children.link(construction)
construction.hide_render=True;construction.hide_viewport=True

def intersect(a,b):
    p=tuple(max(a[i],b[i]) for i in range(3))+tuple(min(a[i+3],b[i+3]) for i in range(3))
    return p if all(p[i+3]-p[i]>EPS for i in range(3)) else None

def subtract(a,b):
    overlap=intersect(a,b)
    if overlap is None:return [a]
    x,y,z,u,v,w=overlap;c,d,e,f,g,h=a
    pieces=[(c,d,e,x,g,h),(u,d,e,f,g,h),(x,d,e,u,y,h),
            (x,v,e,u,g,h),(x,y,e,u,v,z),(x,y,w,u,v,h)]
    return [p for p in pieces if all(p[i+3]-p[i]>EPS for i in range(3))]

def datum(name,bounds):
    at=[(bounds[i]+bounds[i+3])/2 for i in range(3)]
    size=[bounds[i+3]-bounds[i] for i in range(3)]
    obj=bpy.data.objects.new(name,None);obj.empty_display_type='CUBE';obj.empty_display_size=.5
    obj.location=(at[0],-at[2],at[1]);obj.scale=(size[0],size[2],size[1])
    construction.objects.link(obj)

def placement(identity):
    a=anchors[identity];p=a['position']
    return [p[0],levels[a['level']]+p[1],p[2]]

cutters={}
for spec in graph['stacks']:
    sid=spec['id'];cutters[sid]=[]
    fan=placement('ROOF_VENT_FAN_'+sid)
    top=[spec['riser'][0],fan[1]-graph['roof_branch_drop_m'],spec['riser'][1]]
    lowest=top[1]
    def segment(name,a,b):
        axis=max(range(3),key=lambda i:abs(b[i]-a[i]))
        if abs(b[axis]-a[axis])<.001:return
        low=[min(a[i],b[i])-.098 for i in range(3)]
        high=[max(a[i],b[i])+.098 for i in range(3)]
        low[axis]-=.012;high[axis]+=.012
        bounds=(*low,*high);cutters[sid].append(bounds);datum(sid+'_'+name+'_Clearance',bounds)
    for record in graph['registers']:
        if record['stack']!=sid:continue
        grille=placement(record['anchor']);a=[grille[0],grille[1]+.09,grille[2]]
        lowest=min(lowest,a[1]);b=[top[0],a[1],top[2]]
        corner=[b[0],a[1],a[2]] if spec['branch_axis']=='xz' else [a[0],a[1],b[2]]
        segment(record['anchor']+'_First',a,corner);segment(record['anchor']+'_Second',corner,b)
    segment('Stem',[top[0],lowest,top[2]],top)
    corner=[fan[0],top[1],top[2]];end=[fan[0],top[1],fan[2]]
    segment('RoofFirst',top,corner);segment('RoofSecond',corner,end)
    segment('Uptake',end,[fan[0],fan[1]+.169,fan[2]])

# Read pre-cut native masonry seats from its own generator's construction
# collection. Exported glTF and its bounding box are never edited or guessed.
with bpy.data.libraries.load(str(ROOT/'art/blender/exterior_masonry.blend'),link=False) as (available,loaded):
    assert 'PreServiceMasonry' in available.collections
    loaded.collections=['PreServiceMasonry']
masonry=[]
for obj in loaded.collections[0].objects:
    at=(obj.location.x,obj.location.z,-obj.location.y)
    size=(obj.scale.x,obj.scale.z,obj.scale.y)
    masonry.append(tuple(at[i]-size[i]/2 for i in range(3))+tuple(at[i]+size[i]/2 for i in range(3)))

def wall_seats(port):
    room=rooms[port['space']];side=port['side'];x0,z0,x1,z1=room['rect']
    axis=0 if side in ['south','north'] else 2;fixed={'south':z0,'north':z1,'west':x0,'east':x1}[side]
    low,high=(x0,x1) if axis==0 else (z0,z1)
    intervals=[]
    if side in room.get('wall_sides',['south','north','west','east']):intervals.append((low,high))
    intervals.extend((r['start'],r['end']) for r in room.get('wall_extensions',[]) if r['side']==side)
    pieces=[]
    for lo,hi in intervals:
        bounds=list(port['bounds']);bounds[axis]=max(bounds[axis],lo);bounds[axis+3]=min(bounds[axis+3],hi)
        p=intersect(bounds,port['bounds'])
        if p:pieces.append(p)
    for table in ['doors','openings','windows']:
        for row in layout.get(table,[]):
            if row['level']!=room['level']:continue
            if table=='windows':
                if row['space']!=room['id'] or row['axis']!=('x' if axis==0 else 'z'):continue
            elif room['id'] not in row['connects']:continue
            if table=='openings' and row['axis']!=('x' if axis==0 else 'z'):continue
            position=row['center'][0 if axis==2 else 1]
            if abs(position-fixed)>.00001:continue
            center=row['center'][0 if axis==0 else 1];lo=center-row['width']/2;hi=center+row['width']/2
            bottom=levels[room['level']]+row.get('sill',0);top=bottom+row['height']
            if table=='openings' and row.get('shared_wall_owner',room['id'])!=room['id']:
                other=rooms[next(v for v in row['connects'] if v!=room['id'])]['rect']
                lo=max(low,other[0 if axis==0 else 1]);hi=min(high,other[2 if axis==0 else 3])
                bottom=levels[room['level']];top=bottom+layout['dimensions']['clear_height']
            hole=(lo,bottom,fixed-1,hi,top,fixed+1) if axis==0 else (fixed-1,bottom,lo,fixed+1,top,hi)
            pieces=[p for old in pieces for p in subtract(old,hole)]
    return pieces

def riser_seats(port):
    r=risers[port['riser']];rect=r['rect']
    p=intersect(port['bounds'],(rect[0],r['from_y'],rect[1],rect[2],r['to_y'],rect[3]))
    pieces=[p] if p else []
    for row in layout.get('riser_openings',[]):
        if row['riser']==r['id'] and row['id'] not in owned_riser:
            pieces=[p for old in pieces for p in subtract(old,row['bounds'])]
    for row in layout['windows']:
        axis=0 if row['axis']=='x' else 2;fixed=row['center'][0 if axis==2 else 1]
        if fixed<rect[1 if axis==0 else 0]-.001 or fixed>rect[3 if axis==0 else 2]+.001:continue
        center=row['center'][0 if axis==0 else 1];lo=center-row['width']/2;hi=center+row['width']/2
        bottom=levels[row['level']]+row['sill'];top=bottom+row['height']
        hole=(lo,bottom,rect[1],hi,top,rect[3]) if axis==0 else (rect[0],bottom,lo,rect[2],top,hi)
        pieces=[p for old in pieces for p in subtract(old,hole)]
    return pieces

owned_riser={r['id'] for r in source['records']['riser_openings']}
parts={sid:[] for sid in cutters}
seats={sid:0 for sid in cutters}
for table,rows in source['records'].items():
    for port in rows:
        sid=port['id'].split('_')[1]
        if table=='wall_service_openings':volumes=wall_seats(port)
        elif table=='riser_openings':volumes=riser_seats(port)
        else:volumes=[p for b in masonry if (p:=intersect(b,port['bounds'])) is not None]
        assert volumes,port['id']+' has no original structural bearing'
        seats[sid]+=1
        for index,bounds in enumerate(volumes):datum(port['id']+f'_Seat{index:02d}',bounds)
        for cutter in cutters[sid]:volumes=[p for old in volumes for p in subtract(old,cutter)]
        for volume in volumes:
            remaining=[volume]
            for existing in parts[sid]:remaining=[p for old in remaining for p in subtract(old,existing)]
            parts[sid].extend(remaining)

def subtract_rect(a,b):
    x,y,u,v=max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])
    if u-x<=EPS or v-y<=EPS:return [a]
    c,d,e,f=a
    return [p for p in [(c,d,x,f),(u,d,e,f),(x,d,u,y),(x,v,u,f)] if p[2]-p[0]>EPS and p[3]-p[1]>EPS]

finished=[];report=[]
for sid,boxes in parts.items():
    vertices=[];faces=[]
    for bounds in boxes:
        for axis in range(3):
            u,v=[i for i in range(3) if i!=axis]
            for sign in [-1,1]:
                plane=bounds[axis if sign<0 else axis+3]
                rectangles=[(bounds[u],bounds[v],bounds[u+3],bounds[v+3])]
                for other in boxes:
                    if other is bounds:continue
                    covers=(other[axis]<plane-EPS and other[axis+3]>=plane-EPS if sign<0
                            else other[axis]<=plane+EPS and other[axis+3]>plane+EPS)
                    if covers:rectangles=[p for old in rectangles for p in subtract_rect(old,(other[u],other[v],other[u+3],other[v+3]))]
                for a,b,c,d in rectangles:
                    points=[]
                    for pu,pv in [(a,b),(c,b),(c,d),(a,d)]:
                        p=[0,0,0];p[axis]=plane;p[u]=pu;p[v]=pv;points.append((p[0],-p[2],p[1]))
                    normal=(Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]))
                    expected=[0,0,0];expected[axis]=sign;expected=Vector((expected[0],-expected[2],expected[1]))
                    if normal.dot(expected)<0:points.reverse()
                    offset=len(vertices);vertices.extend(points);faces.append(tuple(range(offset,offset+4)))
    mesh=bpy.data.meshes.new(sid+'_Lining');mesh.from_pydata(vertices,[],faces);mesh.materials.append(steel);mesh.update()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        normal=face.normal.normalized();seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))
        u=normal.cross(seed).normalized();v=normal.cross(u).normalized();origin=mesh.vertices[face.vertices[0]].co
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(p.dot(u),p.dot(v))
    obj=bpy.data.objects.new(sid+'_FabricLining',mesh);bpy.context.scene.collection.objects.link(obj);finished.append(obj)
    report.append(dict(stack=sid,authored_ports=seats[sid],steel_volumes=len(boxes),triangles=len(faces)*2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ventilation_fabric_lining.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in finished:obj.select_set(True)
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/ventilation_fabric_lining.glb'),
    export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==4
out=ROOT/'tmp/vent-wall-ports';out.mkdir(parents=True,exist_ok=True)
(out/'lining-generation.json').write_text(json.dumps(dict(evidence_class='INERT',stacks=report),indent=2)+'\n')
print('VENTILATION FABRIC LINING',json.dumps(report))
