"""INERT source-fitted foundations for authored ground-level city masses.

The closed city masses remain intentional distant
closures. Contact geometry is not a soil, reinforcement or load-capacity finding.
"""
from pathlib import Path
import json, math, hashlib, collections
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
work=root/'art/blender'
source=work/'city_shells.blend'
roster_path=root/'art/data/city_foundations/source_plan.json'
roster=json.loads(roster_path.read_text(encoding='utf-8'))
ids=set(roster['native_base_ids'])
assert len(ids)==len(roster['native_base_ids'])
frame_path=root/'game/data/orison_v2/exterior/street_frame.json'
layout_path=root/'game/data/orison_v2_blockout.json'
frame=json.loads(frame_path.read_text(encoding='utf-8'))
layout=json.loads(layout_path.read_text(encoding='utf-8'))
sets_path=root/'game/data/runtime_material_sets.json'
tile=float(json.loads(sets_path.read_text(encoding='utf-8'))['materials']['concrete']['meters_per_tile'])
front=next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')['center'][1]
delta=front+float(frame['source_threshold_z'])
with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
    assert ids.issubset(available.objects)
    loaded.objects=sorted(ids)
profiles=[]
for obj in loaded.objects:
    pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale)
    def registered(p):
        at=pose@p
        return Vector((-at.x,at.z,at.y+delta))
    all_points=[registered(v.co) for v in obj.data.vertices]
    bounds=[min(p[i] for p in all_points) for i in range(3)]+[max(p[i] for p in all_points) for i in range(3)]
    faces=[]
    for face in obj.data.polygons:
        points=[registered(obj.data.vertices[i].co) for i in face.vertices]
        if all(abs(p.y)<1e-7 for p in points):faces.append([[float(v) for v in p] for p in points])
    assert len(faces)==1 and len(faces[0])==4, obj.name
    points=faces[0]
    rect=[min(p[0] for p in points),min(p[2] for p in points),max(p[0] for p in points),max(p[2] for p in points)]
    assert all(abs(p[0]-rect[0])<1e-8 or abs(p[0]-rect[2])<1e-8 for p in points)
    assert all(abs(p[2]-rect[1])<1e-8 or abs(p[2]-rect[3])<1e-8 for p in points)
    # Carry the exact saved bottom plane. Outer worked arrises remain separate.
    profiles.append({'id':obj.name,'native_bounds':bounds,'underside':rect,'underside_faces':faces,
                     'classification':'actual_planar_native_underside'})
for index, first in enumerate(profiles):
    a,b,c,d=first['underside']
    for second in profiles[index+1:]:
        e,f,g,h=second['underside']
        assert min(c,g)<=max(a,e)+1e-7 or min(d,h)<=max(b,f)+1e-7, (first['id'],second['id'])
slab=float(layout['dimensions']['slab_thickness'])
outer=float(layout['dimensions']['outer_wall'])
levels={r['id']:float(r['y']) for r in layout['levels']}
footing_top=levels['B1']-slab
bottom=footing_top-2*slab
pad_bottom=-slab
components=[]
def component(owner,family,rect,lo,hi):
    a,b,c,d=rect
    components.append({'owner':owner,'id':owner+'/'+family,'kind':'authored_union_component',
                       'bounds':[a,lo,b,c,hi,d]})
def ring(owner,family,rect,width,lo,hi):
    a,b,c,d=rect
    component(owner,family+'_North',[a,b,c,b+width],lo,hi)
    component(owner,family+'_South',[a,d-width,c,d],lo,hi)
    component(owner,family+'_West',[a,b+width,a+width,d-width],lo,hi)
    component(owner,family+'_East',[c-width,b+width,c,d-width],lo,hi)
for row in profiles:
    rect=row['underside'];owner=row['id']
    component(owner,'ContactCourse',rect,pad_bottom,0)
    ring(owner,'Stem',rect,outer,footing_top,pad_bottom)
    margin=outer*.5
    a,b,c,d=rect
    ring(owner,'Footing',[a-margin,b-margin,c+margin,d+margin],2*outer,bottom,footing_top)

# Reconcile retained physical volumes before making any new construction.
# The west near mass partly rests on the accepted public slab. Preserve that
# existing 160 mm course and fit the new course beneath it; never double it.
retained_path=root/'art/data/orison_ground/retained_grade_source.json'
retained=json.loads(retained_path.read_text(encoding='utf-8'))
for relative,expected in retained['bindings'].items():
    path=root/relative
    raw=path.read_bytes() if path.suffix in ['.blend','.glb'] else path.read_text(encoding='utf-8').replace('\r\n','\n').encode()
    assert hashlib.sha256(raw).hexdigest()==expected,relative
cut_masks=retained['retained_solids']+[r for r in retained['occupation_reservations'] if r['kind']!='outside_this_bounded_ground_batch']
def subtract_box(bounds,mask):
    lo=[max(bounds[i],mask[i]) for i in range(3)];hi=[min(bounds[i+3],mask[i+3]) for i in range(3)]
    if any(hi[i]<=lo[i]+1e-8 for i in range(3)):return [bounds]
    a,b,c,d,e,f=bounds;x,y,z,u,v,w=lo+hi
    result=[[a,b,c,x,e,f],[u,b,c,d,e,f],[x,b,c,u,y,f],[x,v,c,u,e,f],[x,y,c,u,v,z],[x,y,w,u,v,f]]
    return [r for r in result if all(r[i+3]-r[i]>1e-7 for i in range(3))]
initial_components=components
components=[];retained_intersections=[]
for component_row in initial_components:
    boxes=[component_row['bounds']]
    for mask in cut_masks:
        prior=boxes;boxes=[r for box in prior for r in subtract_box(box,mask['bounds'])]
        if boxes!=prior:retained_intersections.append({'added':component_row['id'],'retained_owner':mask['owner'],'retained_id':mask.get('id'),'classification':mask['kind']})
    for index,bounds in enumerate(boxes):
        components.append({**component_row,'id':component_row['id']+'_Piece%02d'%index,'bounds':bounds})

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
collection=bpy.data.collections.new('CityFoundationConstruction');bpy.context.scene.collection.children.link(collection)
collection.hide_render=True;collection.hide_viewport=True
for row in components:
    b=row['bounds'];p=[(b[i]+b[i+3])/2 for i in range(3)];s=[b[i+3]-b[i] for i in range(3)]
    obj=bpy.data.objects.new(row['id'],None);obj.empty_display_type='CUBE';obj.empty_display_size=.5
    obj.location=(p[0],-p[2],p[1]);obj.scale=(s[0],s[2],s[1]);collection.objects.link(obj)
material=bpy.data.materials.new('concrete');material.diffuse_color=(.36,.34,.3,1)
parts=[];reports=[];closed_volumes=[]
for row in profiles:
    selected=[r for r in components if r['owner']==row['id']]
    coordinates=[]
    for axis in range(3):
        values={round(r['bounds'][i],7) for r in selected for i in [axis,axis+3]}
        if axis!=1:
            low,high=min(values),max(values)
            values.update(4*n for n in range(math.floor(low/4),math.ceil(high/4)+1) if low<4*n<high)
        coordinates.append(sorted(values))
    xs,ys,zs=coordinates
    indexes=[{v:i for i,v in enumerate(values)} for values in coordinates]
    size=tuple(len(v)-1 for v in coordinates);solid=np.zeros(size,dtype=bool)
    for item in selected:
        b=item['bounds'];s=tuple(slice(indexes[i][round(b[i],7)],indexes[i][round(b[i+3],7)]) for i in range(3))
        assert not solid[s].any(),'Construction components must have one owner and zero positive overlap'
        solid[s]=True
    quads=[]
    for ix,iy,iz in np.argwhere(solid):
        a,c=xs[ix:ix+2];lo,hi=ys[iy:iy+2];b,d=zs[iz:iz+2]
        for axis,direction,face in [(0,-1,[(a,lo,b),(a,lo,d),(a,hi,d),(a,hi,b)]),
            (0,1,[(c,lo,b),(c,hi,b),(c,hi,d),(c,lo,d)]),
            (1,-1,[(a,lo,b),(c,lo,b),(c,lo,d),(a,lo,d)]),
            (1,1,[(a,hi,b),(a,hi,d),(c,hi,d),(c,hi,b)]),
            (2,-1,[(a,lo,b),(a,hi,b),(c,hi,b),(c,lo,b)]),
            (2,1,[(a,lo,d),(c,lo,d),(c,hi,d),(a,hi,d)])]:
            n=[int(ix),int(iy),int(iz)];n[axis]+=direction
            if n[axis]<0 or n[axis]>=size[axis] or not solid[tuple(n)]:quads.append(face)
    vertices=[(p[0],-p[2],p[1]) for face in quads for p in face]
    mesh=bpy.data.meshes.new(row['id']+'_ClosedUnion');mesh.from_pydata(vertices,[],[tuple(range(i,i+4)) for i in range(0,len(vertices),4)])
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    nonmanifold=sum(not e.is_manifold for e in bm.edges);bm.normal_update();volume=bm.calc_volume(signed=True)
    assert nonmanifold==0 and volume>0,(row['id'],nonmanifold,volume)
    expected=sum(np.prod([r['bounds'][i+3]-r['bounds'][i] for i in range(3)]) for r in selected)
    assert abs(volume-expected)<.001,(volume,expected)
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(obj)
    closed_volumes.append({'owner':row['id'],'volume_m3':volume,'grid_volume_m3':float(expected),'nonmanifold_edges':nonmanifold})
    groups=collections.defaultdict(list)
    omitted_contacts=0
    exact_kinds={'authored_original_box','authored_union_component','actual_axis_aligned_box','retained_continuous_paving_substrate'}
    for face in quads:
        normal=(Vector(face[1])-Vector(face[0])).cross(Vector(face[2])-Vector(face[0])).normalized()
        center=Vector(tuple(sum(p[i] for p in face)/4 for i in range(3)))
        probe=center+normal*.00001
        # The saved source is closed. Hidden shared interfaces belong to the
        # existing native city underside or exact retained floor, so the new
        # runtime mesh does not add another coincident surface/collider.
        city_contact=normal.y>.999 and abs(center.y)<1e-8
        retained_contact=any(m['kind'] in exact_kinds and all(m['bounds'][i]-1e-8<probe[i]<m['bounds'][i+3]+1e-8 for i in range(3)) for m in cut_masks)
        if city_contact or retained_contact:omitted_contacts+=1;continue
        x=sum(p[0] for p in face)/4;z=sum(p[2] for p in face)/4
        groups[(math.floor(x/4+1e-9),math.floor(z/4+1e-9))].append(face)
    for (ix,iz),faces in sorted(groups.items()):
        name=row['id']+'_Foundation_'+str(ix)+'_'+str(iz)
        lo=[min(p[i] for face in faces for p in face) for i in range(3)]
        hi=[max(p[i] for face in faces for p in face) for i in range(3)]
        center=[(lo[i]+hi[i])/2 for i in range(3)];origin=Vector((center[0],-center[2],center[1]))
        vertices=[Vector((p[0],-p[2],p[1]))-origin for face in faces for p in face]
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[tuple(range(i,i+4)) for i in range(0,len(vertices),4)]);mesh.update()
        uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        for polygon in mesh.polygons:
            drop=max(range(3),key=lambda i:abs(polygon.normal[i]));u,v=((1,2),(0,2),(0,1))[drop]
            for loop in polygon.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u]+origin[u]%tile,1+p[v]+origin[v]%tile)
        mesh.materials.append(material)
        obj=bpy.data.objects.new(name,mesh);obj.location=origin;bpy.context.scene.collection.objects.link(obj);parts.append(obj)
        assert max(hi[i]-lo[i] for i in range(3))<=4.000001
        reports.append({'id':name,'owner':row['id'],'bounds':lo+hi,'quads':len(faces),'internal_caps':False})
    row['runtime_shared_contact_quads_omitted']=omitted_contacts

bpy.ops.wm.save_as_mainfile(filepath=str(work/'city_foundations.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
    count=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).count+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=root/'game/assets/props/city_foundations.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.count==len(parts)
bindings={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes() if p.suffix in ['.blend','.glb'] else p.read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest() for p in [source,frame_path,layout_path,retained_path,roster_path,sets_path,Path(__file__)]}
margin=float(roster.get('grade_margin_m',0))
grid=float(roster.get('grade_grid_m',4))
assert margin>=0 and grid>0
# The grade limit follows actual saved face coordinates and the fitted footing
# width. It is a finite backdrop fit, not an invented road or utility network.
envelope=[grid*math.floor((min(p['underside'][i] for p in profiles)-outer*.5-margin)/grid) for i in [0,1]]
envelope.extend(grid*math.ceil((max(p['underside'][i] for p in profiles)+outer*.5+margin)/grid) for i in [2,3])
out={'evidence_class':'INERT','bindings':bindings,'profiles':profiles,'components':components,'parts':reports,'closed_volumes':closed_volumes,
     'grade_envelope':envelope,
     'surface_phase':'Registered global metre axes, with each local origin reduced by whole catalogue concrete tiles only.',
     'retained_intersections_resolved':retained_intersections,'retained_support_volumes':[m for m in cut_masks if m.get('owner')=='FrontPavement'],
     'native_faces':sum(r['quads'] for r in reports),'source_native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
     'note':'Registered ground-level source masses fitted to a contact course, perimeter stems and footings. Raised storefront masses retain their existing lower owners. Retained sidewalk contacts keep their original owner. Geometric fit only; no soil, reinforcement or load-capacity verdict.'}
(work/'city_foundations_construction.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
print('INERT CITY FOUNDATION TRIAL:',len(profiles),'native underside profiles;',len(components),'nonoverlapping components;',len(parts),'parts;',out['native_faces']*2,'triangles',flush=True)

(root/'game/tests/fixtures/orison_city_foundations_construction.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
