"""Fit folded base weather fittings to retained roof walls without new cuts.

The original slabs, parapets, bulkheads and doors retain ownership. Native
construction pieces are closed; runtime omits shared ends and fabric contacts.
Main roof falls, drainage and the field membrane remain separate open work.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
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
for key, color in [('metal',(.30,.32,.32,1)),('enamel',(.36,.34,.30,1))]:
    mat=bpy.data.materials.new(key);mat.diffuse_color=color;mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
    mat.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.6 if key=='metal' else 0
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.5
    materials[key]=mat

def blender(p): return Vector((p[0],-p[2],p[1]))

closed=[]; groups={}; stations=[]; joints=[]
def piece(name, vertices, faces, key, group, omit=()):
    origin=sum((blender(v) for v in vertices),Vector())/len(vertices)
    local=[blender(v)-origin for v in vertices]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(local,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>1e-12,name
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.location=origin;mesh.materials.append(materials[key]);obj.hide_render=True;obj.hide_set(True)
    closed.append(obj)
    target=groups.setdefault((group,key),[])
    # Keep the closed native counterpart. Runtime omits shared retained-fabric
    # contacts and paired ends; each exposed surface has exactly one owner.
    for face in mesh.polygons:
        if face.index not in omit:
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
        extrusion('FoldedStrip_'+group,rings,'metal',group,omit)
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
                key='enamel' if run_number==0 and index==0 and bolt==0 else 'metal'
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

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_base_flashings.blend'))
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
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_base_flashings.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True)
manifest={'evidence_class':'INERT','classification':'ADAPTATION','parts':len(parts),'triangles':triangles,
          'closed_native_pieces':len(closed),'sheet_thickness':thickness,'roof_datum':Y,
          'stations':stations,'miter_edges':joints,'door_clearance':plan['door_clearance'],
          'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [plan_path,roof_path,layout_path]},
          'open_work':plan['open_work']}
for path in [ROOT/'art/blender/roof_base_flashings_construction.json',ROOT/'game/tests/fixtures/orison_roof_base_flashings.json']:
    path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ROOF BASE FLASHINGS',len(parts),'parts',triangles,'triangles;',len(closed),'closed native pieces')
