"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
OUT=ROOT/'art/blender';OUT.mkdir(parents=True,exist_ok=True)
field=json.loads((ROOT/'art/blender/roof_drainage_falls_construction.json').read_bytes())
ports=json.loads((ROOT/'art/blender/roof_drainage_ports_construction.json').read_bytes())['ports']
field_points=np.array(field['points'],dtype=np.float64)
field_faces=np.array(field['triangles_by_vertex'],dtype=np.int32)
field_triangles=field_points[field_faces][:,:,[0,2]]
field_planes=np.array([np.linalg.solve(np.c_[field_points[t][:,[0,2]],np.ones(3)],field_points[t][:,1]) for t in field_faces])
field_buckets={};edge_owners={}
for i,tri in enumerate(field_triangles):
    lo=tri.min(axis=0)-.00002;hi=tri.max(axis=0)+.00002
    for ix in range(math.floor(lo[0]/.5),math.floor(hi[0]/.5)+1):
        for iz in range(math.floor(lo[1]/.5),math.floor(hi[1]/.5)+1):field_buckets.setdefault((ix,iz),[]).append(i)
    for a,b in zip(tri,np.roll(tri,-1,axis=0)):
        key=tuple(sorted((tuple(a),tuple(b))));edge_owners.setdefault(key,[]).append(i)
# Split at physical drainage creases, rather than every coplanar sampling
# edge. Repeated cuts of the same plane create sub-micrometre dust faces in
# float32 native meshes and carry no change to the fitted underside.
field_edges={key:tuple(np.array(point) for point in key) for key,owners in edge_owners.items()
             if len(owners)==2 and np.max(np.abs(field_planes[owners[0]]-field_planes[owners[1]]))>1e-6}
def roof_height(x,z):
    at=np.array([x,z]);candidates=field_buckets.get((math.floor(x/.5),math.floor(z/.5)),[])
    for index in candidates:
        t=field_triangles[index];a=t[1]-t[0];b=t[2]-t[0];q=at-t[0];det=a[0]*b[1]-a[1]*b[0]
        u=(q[0]*b[1]-q[1]*b[0])/det;v=(a[0]*q[1]-a[1]*q[0])/det
        if u>=-.00015 and v>=-.00015 and u+v<=1.00015:return float(field_planes[index]@np.array([x,z,1.]))
    raise AssertionError(('No physical roof under fitted flashing',x,z))
plan_path = ROOT/'art/data/roof_base_flashings/source_plan.json'
roof_path = ROOT/'art/data/orison_v2/roof_source.json'
layout_path = ROOT/'game/data/orison_v2_blockout.json'
plan = json.loads(plan_path.read_text())
roof = json.loads(roof_path.read_text())['records']
layout = json.loads(layout_path.read_text())
assert plan['classification'] == 'ADAPTATION'
Y = roof['levels'][0]['y']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
materials = {}
for key, color in [('galvanized_roof',(.30,.32,.32,1)),('enamel',(.36,.34,.30,1))]:
    mat=bpy.data.materials.new(key);mat.diffuse_color=color;mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
    mat.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.9 if key=='galvanized_roof' else 0
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.5
    materials[key]=mat

def blender(p): return Vector((p[0],-p[2],p[1]))

closed=[]; closed_checks=[]; groups={}; stations=[]; joints=[]
def piece(name, vertices, faces, key, group, omit=()):
    origin=sum((blender(v) for v in vertices),Vector())/len(vertices)
    local=[blender(v)-origin for v in vertices]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(local,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    source_face=bm.faces.layers.int.new('SourceFace')
    for index,face in enumerate(bm.faces):face[source_face]=index
    # Split every folded stock at the actual roof triangle edges before
    # warping it. Its underside then stays in the same affine roof planes,
    # including drainage divides and mitered corners.
    footprint=np.array([[v[0],v[2]] for v in vertices]);lo=footprint.min(axis=0)-.00001;hi=footprint.max(axis=0)+.00001
    used=set()
    for a,b in field_edges.values():
        if np.any(np.maximum(a,b)<lo) or np.any(np.minimum(a,b)>hi):continue
        delta=b-a;normal=np.array([delta[1],-delta[0]]);normal/=np.linalg.norm(normal)
        if normal[0]<-1e-10 or (abs(normal[0])<1e-10 and normal[1]<0):normal=-normal
        constant=float(normal@a);identity=tuple(round(v,7) for v in [*normal,constant])
        if identity in used:continue
        used.add(identity)
        values=[normal@np.array(p)-constant for p in [[lo[0],lo[1]],[hi[0],lo[1]],[hi[0],hi[1]],[lo[0],hi[1]]]]
        if min(values)>0 or max(values)<0:continue
        plane_co=Vector((a[0],-a[1],float(origin.z)))-origin;plane_no=Vector((normal[0],-normal[1],0.))
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.0000001,plane_co=plane_co,plane_no=plane_no,clear_inner=False,clear_outer=False)
    for vertex in bm.verts:
        absolute=origin+vertex.co;vertex.co.z+=roof_height(float(absolute.x),float(-absolute.y))-Y
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>1e-12,name
    volume=bm.calc_volume(signed=True)
    assert all(face[source_face] in range(len(faces)) for face in bm.faces)
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.location=origin;mesh.materials.append(materials[key]);obj.hide_render=True;obj.hide_set(True)
    closed.append(obj)
    closed_checks.append({'name':name,'volume_m3':volume,'nonmanifold_edges':0})
    target=groups.setdefault((group,key),[])
    # Keep the closed native counterpart. Runtime omits shared retained-fabric
    # contacts and paired ends; each exposed surface has exactly one owner.
    source_indices=mesh.attributes['SourceFace']
    for face in mesh.polygons:
        if source_indices.data[face.index].value not in omit:
            target.append([origin + mesh.vertices[i].co for i in face.vertices])

def extrusion(name, rings, key, group, omit=()):
    n=len(rings[0]);vertices=rings[0]+rings[1]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    piece(name,vertices,faces,key,group,omit)

half=layout['dimensions']['partition_wall']/2
runs=[]
def perimeter(identity,rect,interior=False,door=None):
    a,b,c,d=rect
    sides=[('South',(a,b),(c,b),(0,0,-1)),('East',(c,b),(c,d),(1,0,0)),
           ('North',(a,d),(c,d),(0,0,1)),('West',(a,b),(a,d),(-1,0,0))]
    for side,start,end,out in sides:
        normal=Vector(out)*(-1 if interior else 1)
        tangent=Vector((end[0]-start[0],0,end[1]-start[1])).normalized()
        length=math.dist(start,end)
        intervals=[(0.,length,True,True)]
        if door and side=='West':
            centre=door['center'][1]-start[1]
            clearance=door['width']/2+plan['door_clearance']
            intervals=[(0.,centre-clearance,True,False),(centre+clearance,length,False,True)]
        if identity=='ROOF_PARAPET':
            for port in [p for p in ports if p['side']==side.lower()]:
                centre=(Vector(port['inner_point'])-Vector((start[0],0,start[1]))).dot(tangent)
                opening=port['notch_width']/2
                revised=[]
                for lo,hi,cs,ce in intervals:
                    if hi<=centre-opening or lo>=centre+opening:revised.append((lo,hi,cs,ce));continue
                    if lo<centre-opening:revised.append((lo,centre-opening,cs,False))
                    if hi>centre+opening:revised.append((centre+opening,hi,False,ce))
                intervals=revised
        for lo,hi,corner_start,corner_end in intervals:
            runs.append(dict(owner=identity,side=side,origin=[start[0],Y,start[1]],
                             tangent=list(tangent),normal=list(normal),length=length,
                             interval=[lo,hi],corner_start=corner_start,corner_end=corner_end,
                             miter_sign=-1 if interior else 1))

for identity in ['ROOF_PUBLIC_CORE','ROOF_SERVICE_CORE']:
    room=next(r for r in roof['spaces'] if r['id']==identity)
    assert room in layout['spaces']
    r=room['rect']; door=next(d for d in roof['doors'] if d['connects'][0]==identity)
    perimeter(identity,[r[0]-half,r[1]-half,r[2]+half,r[3]+half],door=door)
decks=[r['rect'] for r in roof['spaces'] if r['id'].startswith('ROOF_DECK_')]
parapet=next(f for f in roof['fixtures'] if f['id']=='ROOF_PARAPET_WEST')['size'][0]/2
perimeter('ROOF_PARAPET',[min(r[0] for r in decks)+parapet,min(r[1] for r in decks)+parapet,
                         max(r[2] for r in decks)-parapet,max(r[3] for r in decks)-parapet],True)

thickness=plan['sheet_thickness'];height=plan['upstand_height'];foot=plan['roof_foot'];fold=plan['counterfold_projection']
profile=[(0,0),(foot,0),(foot,thickness),(thickness,thickness),
         (thickness,height-thickness),(fold,height-thickness),(fold,height),(0,height)]
for run_number,run in enumerate(runs):
    base=Vector(run['origin']); tangent=Vector(run['tangent']); normal=Vector(run['normal'])
    lo,hi=run['interval']; count=math.ceil((hi-lo)/plan['maximum_partition_span'])
    for index in range(count):
        first=lo+(hi-lo)*index/count;last=lo+(hi-lo)*(index+1)/count
        start_corner=index==0 and run['corner_start'];end_corner=index==count-1 and run['corner_end']
        group=f'{run_number:02}_{index:02}'
        def at(along,u,h): return list(base+tangent*along+normal*u+Vector((0,h,0)))
        rings=[]
        for along,corner,sign in [(first,start_corner,-1),(last,end_corner,1)]:
            rings.append([at(along+sign*run['miter_sign']*u if corner else along,u,h) for u,h in profile])
        # Extrusion sides 2 and 9 are the original deck/wall contact planes.
        omit=[2,9]
        if index>0 or start_corner:omit.append(0)
        if index<count-1 or end_corner:omit.append(1)
        extrusion('FoldedStrip_'+group,rings,'galvanized_roof',group,omit)
        stations.append({'owner':run['owner'],'side':run['side'],
                         'wall_point':at((first+last)/2,0,.10),
                         'normal':list(normal),'foot_point':at((first+last)/2,.04,thickness)})
        for corner,along,sign in [(start_corner,first,-1),(end_corner,last,1)]:
            # Vertex zero belongs only to the buried wall/deck contact faces.
            if corner:joints.append([at(along+sign*run['miter_sign']*u,u,h) for u,h in profile[1:]])
        number=max(1,math.ceil((last-first)/plan['fastener_spacing']))
        for bolt in range(number):
            centre=first+(last-first)*(bolt+.5)/number
            # A 12 mm square clamp washer and exposed square screw head. Their
            # back faces seat on the sheet; one coated anchor records maintenance.
            for label,u0,u1,size in [('Washer',thickness,thickness+.002, .012),
                                     ('Screw',thickness+.002,thickness+.007,.007)]:
                rings=[]
                for u in [u0,u1]:
                    rings.append([at(centre+ds,u,.115+dy) for ds,dy in
                                  [(-size/2,-size/2),(size/2,-size/2),(size/2,size/2),(-size/2,size/2)]])
                key='enamel' if run_number==0 and index==0 and bolt==0 else 'galvanized_roof'
                extrusion(f'{label}_{group}_{bolt}',rings,key,group)

parts=[];triangles=0
for (group,key),polygons in sorted(groups.items()):
    origin=sum((v for polygon in polygons for v in polygon),Vector())/sum(map(len,polygons))
    # Godot conditions imported node translations to a decimal grid. A stable
    # millimetre pivot keeps the vertices unchanged and avoids moving seams.
    origin=Vector(tuple(round(float(value),3) for value in origin))
    vertices=[];faces=[]
    for polygon in polygons:
        offset=len(vertices);vertices.extend(v-origin for v in polygon);faces.append(tuple(range(offset,offset+len(polygon))))
    mesh=bpy.data.meshes.new('RoofBase_'+group+'_'+key);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        normal=face.normal.normalized();seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj);obj.location=origin
    mesh.materials.append(materials[key]);parts.append(obj)
    mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
    bounds=[max(v.co[i] for v in mesh.vertices)-min(v.co[i] for v in mesh.vertices) for i in range(3)]
    assert max(bounds)<4.,(obj.name,bounds)

bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'roof_base_flashings.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':self.normals=np.array(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,normal in enumerate(self.normals):
                seed=np.array((0,0,-1) if abs(normal[2])<.85 else (1,0,0),dtype=np.float64)
                tangent=seed-normal*np.dot(seed,normal);tangent/=np.linalg.norm(tangent)
                result[i,:3]=tangent;result[i,3]=-1
            data['data']=result
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_base_flashings.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
manifest={'evidence_class':'INERT','classification':'ADAPTATION','parts':len(parts),'triangles':triangles,
          'closed_native_pieces':len(closed),'sheet_thickness':thickness,'roof_datum':Y,
          'stations':stations,'miter_edges':joints,'door_clearance':plan['door_clearance'],
          'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [plan_path,roof_path,layout_path]},
          'open_work':plan['open_work']}
manifest['status']='SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED'
manifest['runtime_parts']=[{'name':obj.name,'material':obj.data.materials[0].name} for obj in parts]
manifest['field_sha256']=hashlib.sha256((ROOT/'art/blender/roof_drainage_falls_construction.json').read_bytes()).hexdigest()
manifest['closed_stocks']=closed_checks
manifest['closed_stock_names']=[o.name for o in closed]
manifest['native_sha256']=hashlib.sha256((OUT/'roof_base_flashings.blend').read_bytes()).hexdigest()
manifest['asset_sha256']=hashlib.sha256((ROOT/'game/assets/props/roof_base_flashings.glb').read_bytes()).hexdigest()
for station in manifest['stations']:
    for key in ['wall_point','foot_point']:
        p=station[key];p[1]+=roof_height(p[0],p[2])-Y
manifest['miter_edges']=[[[p[0],p[1]+roof_height(p[0],p[2])-Y,p[2]] for p in joint] for joint in manifest['miter_edges']]
for path in [OUT/'roof_base_flashings_construction.json']:
    path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ROOF BASE FLASHINGS',len(parts),'parts',triangles,'triangles;',len(closed),'closed native pieces')

(ROOT/'game/tests/fixtures/orison_roof_base_flashings.json').write_bytes((OUT/'roof_base_flashings_construction.json').read_bytes())
