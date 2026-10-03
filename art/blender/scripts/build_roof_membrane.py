"""Fit closed roof finish within the retained upper 4 mm of the flat deck.

Finish and substrate occupy their existing layer envelope. Runtime suppresses
only the former bare top render triangles; its sole physical floor owner stays.
"""
from pathlib import Path
import collections, hashlib, json, math
import bpy, bmesh, numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
plan_path=ROOT/'art/data/roof_membrane/source_plan.json'
source_path=ROOT/'art/data/orison_v2/roof_source.json'
layout_path=ROOT/'game/data/orison_v2_blockout.json'
plan=json.loads(plan_path.read_text());roof=json.loads(source_path.read_text())['records']
layout=json.loads(layout_path.read_text())
assert plan['classification']=='ADAPTATION'
Y=roof['levels'][0]['y'];depth=plan['thickness']
decks=[r for r in roof['spaces'] if r['id'].startswith('ROOF_DECK_')]
assert len(decks)==7 and all(r in layout['spaces'] for r in decks)
holes=[r for r in layout.get('slab_openings',[]) if r['surface']=='Floor' and r['space'] in {d['id'] for d in decks}]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
closed_collection=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed_collection)
closed_collection.hide_render=True
materials={}
for key,colour in [('Field',(.042,.041,.038,1)),('Bond',(.027,.026,.024,1))]:
    mat=bpy.data.materials.new(key);mat.diffuse_color=colour;mat.use_nodes=True
    node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=colour
    node.inputs['Roughness'].default_value=.86 if key=='Field' else .78
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(ROOT/'art/textures/procedural/roof_bitumen/albedo.png'),check_existing=True)
    tex.image.filepath=bpy.path.relpath(tex.image.filepath,start=str(ROOT/'art/blender'))
    coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');mat.node_tree.links.new(coord.outputs['UV'],tex.inputs['Vector'])
    colour_node=mat.node_tree.nodes.new('ShaderNodeMixRGB');colour_node.blend_type='MULTIPLY';colour_node.inputs[0].default_value=1.0
    tint=plan['bond_tint'] if key=='Bond' else 1.0
    colour_node.inputs[2].default_value=(tint,tint,tint,1.0)
    mat.node_tree.links.new(tex.outputs['Color'],colour_node.inputs[1])
    mat.node_tree.links.new(colour_node.outputs['Color'],node.inputs['Base Color'])
    rough=mat.node_tree.nodes.new('ShaderNodeTexImage')
    rough.image=bpy.data.images.load(str(ROOT/'art/textures/procedural/roof_bitumen/roughness.png'),check_existing=True)
    rough.image.colorspace_settings.name='Non-Color'
    rough.image.filepath=bpy.path.relpath(rough.image.filepath,start=str(ROOT/'art/blender'))
    mat.node_tree.links.new(coord.outputs['UV'],rough.inputs['Vector'])
    rough_node=mat.node_tree.nodes.new('ShaderNodeMath');rough_node.operation='MULTIPLY'
    rough_node.inputs[1].default_value=1.0
    mat.node_tree.links.new(rough.outputs['Color'],rough_node.inputs[0])
    mat.node_tree.links.new(rough_node.outputs['Value'],node.inputs['Roughness'])
    normal=mat.node_tree.nodes.new('ShaderNodeTexImage')
    normal.image=bpy.data.images.load(str(ROOT/'art/textures/procedural/roof_bitumen/normal.png'),check_existing=True)
    normal.image.colorspace_settings.name='Non-Color'
    normal.image.filepath=bpy.path.relpath(normal.image.filepath,start=str(ROOT/'art/blender'))
    normal_node=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal_node.inputs['Strength'].default_value=.35
    mat.node_tree.links.new(coord.outputs['UV'],normal.inputs['Vector'])
    mat.node_tree.links.new(normal.outputs['Color'],normal_node.inputs['Color'])
    mat.node_tree.links.new(normal_node.outputs['Normal'],node.inputs['Normal'])
    materials[key]=mat
runtime_material=materials['Field'].copy();runtime_material.name='RoofFinish'
vertex_colour=runtime_material.node_tree.nodes.new('ShaderNodeVertexColor');vertex_colour.layer_name='SeamTint'
colour_mix=next(node for node in runtime_material.node_tree.nodes if node.type=='MIX_RGB')
runtime_material.node_tree.links.new(vertex_colour.outputs['Color'],colour_mix.inputs[2])

def subtract(rect,cut):
    a,b,c,d=rect;u,v,w,x=cut
    u=max(a,u);v=max(b,v);w=min(c,w);x=min(d,x)
    if u>=w or v>=x:return [rect]
    return [r for r in [(a,b,u,d),(w,b,c,d),(u,b,w,v),(u,x,w,d)] if r[2]-r[0]>1e-7 and r[3]-r[1]>1e-7]

def blender(x,y,z):return Vector((x,-z,y))
groups=collections.defaultdict(list);native=[];stations=[];omitted=0
def add_rect(owner,rect,key):
    global omitted
    a,b,c,d=rect
    verts=[(x,-z,y) for x in [a,c] for y in [Y-depth,Y] for z in [b,d]]
    # Vertex order gives bottom, top and four sides. Closed source remains
    # editable; the retained substrate and adjacent finish own contact planes.
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    mesh=bpy.data.meshes.new('Finish_'+owner+'_'+str(len(native)))
    origin=(round((a+c)/2,3),round(-(b+d)/2,3),Y-depth*.5)
    # Subtract the pivot in double precision before storing local float mesh
    # positions. Casting the distant absolute Y first distorted 4 mm stock.
    mesh.from_pydata([tuple(v[i]-origin[i] for i in range(3)) for v in verts],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(mesh.name,mesh);closed_collection.objects.link(obj);obj.location=origin
    obj.hide_render=True;mesh.materials.append(materials[key]);native.append(obj)
    chart=mesh.uv_layers.new(name='Metres');chart.active_render=True
    for face in mesh.polygons:
        normal=face.normal.normalized();seed=Vector((0,1,0)) if abs(normal.z)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=Vector(origin)+mesh.vertices[mesh.loops[loop].vertex_index].co
            chart.data[loop].uv=(p.x,-p.y) if normal.z>.9 else (p.dot(u),p.dot(v))
    group=(owner,math.floor((a+c)/8),math.floor((b+d)/8))
    # Finish is flush with the original datum. Retained wall, substrate and
    # neighbouring finish own hidden side/bottom contacts. Only its top is
    # newly visible. There is no extra floor collider or second shared plane.
    top=next(face for face in mesh.polygons if face.normal.z>.9)
    groups[group].append((key,[verts[i] for i in top.vertices]));omitted+=5
    stations.append({'owner':owner,'point':[(a+c)/2,Y,(b+d)/2],'finish':key})

width=plan['roll_width'];length=plan['sheet_length'];bond=plan['bond_width']
for deck in decks:
    a,b,c,d=deck['rect']
    # Work from a shared metre datum, so adjoining semantic deck records do
    # not reset roll widths, joint phase or texel density.
    xs=sorted({a,c,*[q for i in range(math.floor(a/width)-1,math.ceil(c/width)+1) for q in [i*width,i*width+bond] if a<q<c],
               *[i*4. for i in range(math.floor(a/4),math.ceil(c/4)) if a<i*4.<c]})
    for x0,x1 in zip(xs,xs[1:]):
        strip=math.floor(((x0+x1)/2)/width)
        offset=(strip%2)*length*.5
        zs=sorted({b,d,*[q for i in range(math.floor((b-offset)/length)-1,math.ceil((d-offset)/length)+1) for q in [offset+i*length,offset+i*length+bond] if b<q<d],
                   *[i*4. for i in range(math.floor(b/4),math.ceil(d/4)) if b<i*4.<d]})
        for z0,z1 in zip(zs,zs[1:]):
            rectangles=[(x0,z0,x1,z1)]
            for hole in holes:
                if hole['space']==deck['id']:
                    rectangles=[piece for r in rectangles for piece in subtract(r,hole['rect'])]
            key='Bond' if x1-x0<bond+.00001 or z1-z0<bond+.00001 else 'Field'
            for rect in rectangles:add_rect(deck['id'],rect,key)

parts=[];inventory=[];triangles=0
for (owner,ix,iz),records in sorted(groups.items()):
    polygons=[polygon for key,polygon in records]
    origin=(round(sum(v[0] for p in polygons for v in p)/sum(map(len,polygons)),3),
            round(sum(v[1] for p in polygons for v in p)/sum(map(len,polygons)),3),Y)
    vertices=[];faces=[];tints=[]
    for key,polygon in records:
        index=len(vertices);vertices.extend(tuple(v[i]-origin[i] for i in range(3)) for v in polygon);faces.append(tuple(range(index,index+len(polygon))))
        tints.extend([plan['bond_tint'] if key=='Bond' else 1.0]*len(polygon))
    mesh=bpy.data.meshes.new(f'{owner}__{ix}_{iz}__RoofFinish');mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    colour=mesh.color_attributes.new(name='SeamTint',type='FLOAT_COLOR',domain='CORNER')
    mesh.color_attributes.active_color=colour
    for face in mesh.polygons:
        for loop in face.loop_indices:
            p=Vector(origin)+mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.x,-p.y)
            tint=tints[mesh.loops[loop].vertex_index];colour.data[loop].color=(tint,tint,tint,1.0)
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin
    mesh.materials.append(runtime_material);parts.append(obj)
    mesh.calc_loop_triangles();count=len(mesh.loop_triangles);triangles+=count
    inventory.append({'name':obj.name,'owner':owner,'finish':'RoofFinish','triangles':count})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_membrane.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/roof_membrane.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True)
manifest={'evidence_class':'INERT','classification':'ADAPTATION','datum':Y,'thickness':depth,
    'parts':inventory,'triangles':triangles,'closed_native_pieces':len(native),'omitted_contact_faces':omitted,
    'bond_tint':plan['bond_tint'],
    'stations':stations,'apertures':holes,'owners':[r['id'] for r in decks],
    'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [plan_path,source_path,layout_path]},
    'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'open_work':plan['open_work']}
for path in ['art/blender/roof_membrane_construction.json','game/tests/fixtures/orison_roof_membrane.json']:
    (ROOT/path).write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
print('ROOF MEMBRANE',len(native),'closed pieces;',len(parts),'partitions;',triangles,'triangles')
