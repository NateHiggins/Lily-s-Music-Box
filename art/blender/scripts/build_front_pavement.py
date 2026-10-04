"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json
import math
import collections
import hashlib
import bpy
import bmesh
from mathutils import Vector

root = next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
base = root / 'art/blender'
layout = json.loads((root / 'game/data/orison_v2_blockout.json').read_text())
geometry = json.loads((root / 'game/data/orison_v2/exterior/exterior_geometry.json').read_text())
door = next(row for row in layout['doors'] if row['id'] == 'F01_DOOR_06')
street = next(row for row in geometry['templates'] if row['id'] == 'TEMPLATE_STREET_SEGMENT_V1')
slab = next(row for row in street['boxes'] if row['id'] == 'pavement_slab')
assert slab['yaw_degrees'] == 0 and slab['position_m'][1] == -.08
assert door['center'][0] == 0 and door['level'] == 'F01'
x, y, z = slab['position_m']; w, depth, length = slab['size_m']
envelope = [-x-w/2, door['center'][1]-z-length/2,
            -x+w/2, door['center'][1]-z+length/2]
assert [round(v, 5) for v in envelope] == [-25.5, -16.605, 20.3, -11.65]
low = y-depth/2; high = y+depth/2
assert high == 0 and depth == .16
masks = []
regions=json.loads((root/'game/data/orison_v2/exterior/regions.json').read_text())
street_region=next(row for row in regions['surface_templates'] if row['id']=='TEMPLATE_STREET_SEGMENT_V1')
pavement=next(row for row in street_region['surfaces'] if row['id']=='pavement')
assert pavement['u_axis']==[1,0,0] and pavement['v_axis']==[0,0,1] and pavement['normal']==[0,1,0]
instance=next(row for row in regions['instances'] if row['id']=='SHOP_BODEGA')
assert instance['owner_surface_id']=='pavement' and instance['local_yaw_degrees']==0
origin=[pavement['point_m'][0]+instance['offset_uvn_m'][0],
        pavement['point_m'][1]+instance['offset_uvn_m'][2],
        pavement['point_m'][2]+instance['offset_uvn_m'][1]]
shop=next(row for row in geometry['templates'] if row['id']==instance['template_id'])
for record in shop['boxes']:
    if not record['collision']:continue
    px,py,pz=record['position_m'];sx,sy,sz=record['size_m']
    if origin[1]+py-sy/2>=high or origin[1]+py+sy/2<=low:continue
    assert record['yaw_degrees']==0
    px+=origin[0];pz+=origin[2]
    masks.append({'owner':'Bodega/'+record['id'],
                  'bounds':[-px-sx/2,door['center'][1]-pz-sz/2,-px+sx/2,door['center'][1]-pz+sz/2],
                  'kind':'retained_registered_shop_solid'})
shed=json.loads((root/'game/data/orison_v2/exterior/construction_shed.json').read_text())
assert shed['frame']=='ORISON_FRONT_DOOR_THRESHOLD'
for record in shed['boxes']:
    px,py,pz=record['center'];sx,sy,sz=record['size']
    if py-sy/2>=high or py+sy/2<=low:continue
    assert record.get('roll_degrees',0)==0
    masks.append({'owner':'StreetBoundaries/'+record['id'],
                  'bounds':[-px-sx/2,door['center'][1]-pz-sz/2,-px+sx/2,door['center'][1]-pz+sz/2],
                  'kind':'retained_authored_shed_solid'})
connection=json.loads((root/'game/data/orison_v2/world_connection.json').read_text())
for record in street['boxes']:
    if record['id']=='pavement_slab' or record['id'] in connection['remove_boxes'] or not record['collision']:continue
    px,py,pz=record['position_m'];sx,sy,sz=record['size_m']
    if py-sy/2>=high or py+sy/2<=low:continue
    assert record['yaw_degrees']==0, record['id']
    masks.append({'owner':'Street/'+record['id'],
                  'bounds':[-px-sx/2,door['center'][1]-pz-sz/2,-px+sx/2,door['center'][1]-pz+sz/2],
                  'kind':'retained_street_solid'})
for room in layout['spaces']:
    if room['level'] != 'F01' or room.get('open_shell') or room.get('no_floor'): continue
    masks.append({'owner': room['id']+'/Floor', 'bounds': room['rect'],
                  'kind': 'current_occupied_floor'})
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
source_path = root / 'art/blender/exterior_masonry.blend'
with bpy.data.libraries.load(str(source_path), link=False) as (available, loaded):
    assert 'PreServiceMasonry' in available.collections
    loaded.collections = ['PreServiceMasonry']
for obj in loaded.collections[0].objects:
    assert obj.type == 'EMPTY' and obj.parent is None
    assert max(abs(v) for v in obj.rotation_euler) < 1e-7
    p = obj.location; extent = obj.scale
    center = [p.x, p.z, -p.y]; size = [extent.x, extent.z, extent.y]
    bounds = [center[i]-size[i]/2 for i in range(3)] + [center[i]+size[i]/2 for i in range(3)]
    if bounds[1] >= high or bounds[4] <= low: continue
    masks.append({'owner': 'ExteriorMasonry/'+obj.name,
                  'bounds': [bounds[0], bounds[2], bounds[3], bounds[5]],
                  'kind': 'authored_original_box'})
receiver=json.loads((root/'art/blender/roof_drainage_reservations.json').read_bytes())
for row in receiver['grade_ports']:
    if row['provider']=='FrontPavement':masks.append({'owner':row['owner'],'bounds':row['rect'],'kind':'source_bound_receiver_port'})
a,b,c,d = envelope
masks = [row for row in masks if row['bounds'][2]>a and row['bounds'][0]<c
         and row['bounds'][3]>b and row['bounds'][1]<d]
xs = sorted({round(v, 5) for v in [a,c] + [4*n for n in range(math.ceil(a/4), math.ceil(c/4))]
              + [v for row in masks for v in row['bounds'][::2] if a<v<c]})
zs = sorted({round(v, 5) for v in [b,d] + [4*n for n in range(math.ceil(b/4), math.ceil(d/4))]
              + [v for row in masks for v in row['bounds'][1::2] if b<v<d]})
occupied = set()
for ix in range(len(xs)-1):
    for iz in range(len(zs)-1):
        x,z = (xs[ix]+xs[ix+1])/2, (zs[iz]+zs[iz+1])/2
        if not any(row['bounds'][0]<x<row['bounds'][2] and row['bounds'][1]<z<row['bounds'][3] for row in masks):
            occupied.add((ix,iz))
source_collection = loaded.collections[0]
for obj in list(source_collection.objects): bpy.data.objects.remove(obj, do_unlink=True)
bpy.data.collections.remove(source_collection)
material = bpy.data.materials.new('concrete'); material.diffuse_color = (.4,.4,.37,1)
groups = collections.defaultdict(list); group_owners = collections.defaultdict(list)
for ix,iz in sorted(occupied):
    x0,x1 = xs[ix:ix+2]; z0,z1 = zs[iz:iz+2]
    # Retain the accepted public top datum in this first ownership trial.
    faces = [[(x0,high,z0),(x0,high,z1),(x1,high,z1),(x1,high,z0)],
             [(x0,low,z0),(x1,low,z0),(x1,low,z1),(x0,low,z1)]]
    if (ix-1,iz) not in occupied: faces.append([(x0,low,z0),(x0,low,z1),(x0,high,z1),(x0,high,z0)])
    if (ix+1,iz) not in occupied: faces.append([(x1,low,z0),(x1,high,z0),(x1,high,z1),(x1,low,z1)])
    if (ix,iz-1) not in occupied: faces.append([(x0,low,z0),(x0,high,z0),(x1,high,z0),(x1,low,z0)])
    if (ix,iz+1) not in occupied: faces.append([(x0,low,z1),(x1,low,z1),(x1,high,z1),(x0,high,z1)])
    key = (math.floor((x0+x1)/8),math.floor((z0+z1)/8))
    groups[key].extend(faces); group_owners[key].extend([(ix,iz)]*len(faces))
parts = []; records = []
all_faces = [face for faces in groups.values() for face in faces]
face_owners = [owner for owners in group_owners.values() for owner in owners]
mesh = bpy.data.meshes.new('FittedPavementClosedUnion')
mesh.from_pydata([(p[0],-p[2],p[1]) for face in all_faces for p in face], [],
                 [tuple(range(i,i+4)) for i in range(0,len(all_faces)*4,4)])
bm = bmesh.new(); bm.from_mesh(mesh)
source_face = bm.faces.layers.int.new('SourceFace')
for index,face in enumerate(bm.faces): face[source_face]=index
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
non_manifold = sum(not edge.is_manifold for edge in bm.edges)
bad_edges = [edge for edge in bm.edges if not edge.is_manifold]
assert all(len(edge.link_faces)==4 for edge in bad_edges)
replacements={};affected_faces=set();split_fans=0
for vertex in set(vertex for edge in bad_edges for vertex in edge.verts):
    faces=list(vertex.link_faces);parent={face[source_face]:face[source_face] for face in faces}
    def find(index):
        while parent[index]!=index:parent[index]=parent[parent[index]];index=parent[index]
        return index
    def join(first,second):parent[find(first)]=find(second)
    for edge in vertex.link_edges:
        linked=list(edge.link_faces)
        if len(linked)==2:join(linked[0][source_face],linked[1][source_face])
        else:
            assert len(linked)==4
            owners=collections.defaultdict(list)
            for face in linked:owners[face_owners[face[source_face]]].append(face)
            assert len(owners)==2 and all(len(pair)==2 for pair in owners.values())
            for pair in owners.values():join(pair[0][source_face],pair[1][source_face])
    fans=collections.defaultdict(list)
    for face in faces:fans[find(face[source_face])].append(face)
    for index,fan in enumerate(fans.values()):
        target=vertex if index==0 else bm.verts.new(vertex.co.copy())
        if index:split_fans+=1
        for face in fan:replacements[(vertex,face[source_face])]=target;affected_faces.add(face)
templates=[(face[source_face],[replacements.get((vertex,face[source_face]),vertex) for vertex in face.verts]) for face in affected_faces]
for face in affected_faces:bm.faces.remove(face)
for index,vertices in templates:bm.faces.new(vertices)[source_face]=index
unused_edges=[edge for edge in bm.edges if not edge.link_faces]
if unused_edges:bmesh.ops.delete(bm,geom=unused_edges,context='EDGES')
unused_vertices=[vertex for vertex in bm.verts if not vertex.link_faces]
if unused_vertices:bmesh.ops.delete(bm,geom=unused_vertices,context='VERTS')
non_manifold=sum(not edge.is_manifold for edge in bm.edges)
assert non_manifold == 0, non_manifold
volume = bm.calc_volume(signed=True); assert volume>0
bm.to_mesh(mesh); bm.free()
construction = bpy.data.collections.new('PavementConstruction'); bpy.context.scene.collection.children.link(construction)
construction.hide_render=True; construction.hide_viewport=True
obj = bpy.data.objects.new('FittedPavementClosedUnion',mesh); construction.objects.link(obj)
for (ix,iz),faces in sorted(groups.items()):
    name = 'Pavement_%s_%s' % ('P%d'%ix if ix>=0 else 'N%d'%-ix, 'P%d'%iz if iz>=0 else 'N%d'%-iz)
    bounds = [min(p[axis] for face in faces for p in face) for axis in range(3)] + [max(p[axis] for face in faces for p in face) for axis in range(3)]
    center = [(bounds[axis]+bounds[axis+3])/2 for axis in range(3)]
    origin = Vector((center[0],-center[2],center[1]))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector((p[0],-p[2],p[1]))-origin for face in faces for p in face], [],
                     [tuple(range(i,i+4)) for i in range(0,len(faces)*4,4)])
    mesh.update(); uv=mesh.uv_layers.new(name='Metres'); uv.active_render=True
    for face in mesh.polygons:
        drop=max(range(3),key=lambda axis:abs(face.normal[axis]));u,v=((1,2),(0,2),(0,1))[drop]
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u],1+p[v])
    mesh.materials.append(material)
    obj=bpy.data.objects.new(name,mesh);obj.location=origin;bpy.context.scene.collection.objects.link(obj);parts.append(obj)
    records.append({'id':name,'bounds':bounds,'quads':len(faces)})
bpy.context.preferences.filepaths.save_version=0
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/front_pavement.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
class ExportUVHandedness:
    count=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).count+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=root/'game/assets/props/front_pavement.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.count==len(parts)
report={'evidence_class':'INERT','envelope':envelope,'y':[low,high],'masks':masks,'parts':records,
        'volume_m3':volume,'closed_source_non_manifold_edges':non_manifold,
        'zero_area_edge_contacts_split':len(bad_edges),'vertex_fans_split':split_fans,
        'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
        'source_native_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'note':'Current public-slab ownership construction. Existing rooms, shop and shed floors, curb and exterior masonry retain their own volumes. Public top datum stays zero. Drainage grade and finished joints remain open.'}
report['schema']='orison.v2.front-pavement-construction.v1'
report['source_bindings']={}
for relative in ['game/data/orison_v2_blockout.json', 'game/data/orison_v2/exterior/exterior_geometry.json',
                 'game/data/orison_v2/exterior/regions.json', 'game/data/orison_v2/exterior/construction_shed.json',
                 'game/data/orison_v2/world_connection.json', 'art/blender/exterior_masonry.blend']:
    path=root/relative
    payload=path.read_text().replace('\r\n','\n').encode() if path.suffix=='.json' else path.read_bytes()
    report['source_bindings'][relative]=hashlib.sha256(payload).hexdigest()
report['source_bindings'].update({p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [root/'art/blender/roof_drainage_reservations.json',Path(__file__)]})
(root/'art/blender/front_pavement_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FITTED FRONT PAVEMENT CONSTRUCTION:',len(parts),'parts;',len(all_faces)*2,'triangles;',len(masks),'retained masks;',volume,'m3')

(root/'game/tests/fixtures/orison_front_pavement_construction.json').write_bytes((root/'art/blender/front_pavement_construction.json').read_bytes())
print('SOURCE PROVIDER BUILD; INDEPENDENT VALIDATION REQUIRED')
