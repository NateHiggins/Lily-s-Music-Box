"""Editable bonded stove-stack candidate, circular room ports and open coping.

Output remains in art; installation and imported PBR/mip proof are separate.
"""
import argparse,hashlib,json,math,sys,random
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from repair_surface_uvs import repair_mesh
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.out_dir.resolve();out.mkdir(parents=True,exist_ok=True)
source_path=ROOT/'art/data/c_stove_stack/source_plan.json';plan=json.loads(source_path.read_bytes())
layout_path=ROOT/'game/data/orison_v2_blockout.json';layout=json.loads(layout_path.read_bytes())
assert hashlib.sha256(layout_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==plan['source_bindings']['game/data/orison_v2_blockout.json']
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
cv=lambda p:Vector((p[0],-p[2],p[1]));bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
keys=['stove_clinker','stove_lime','limewash_plaster','concrete'];materials={};strengths=dict(zip(keys,[1.,1.,1.,.12]))
for key in keys:
    spec=catalog[key];material=bpy.data.materials.new(key);material.use_nodes=True;nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=spec['metallic']
    for index,socket in enumerate(['Base Color','Roughness','Normal']):
        tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
        if index:tex.image.colorspace_settings.name='Non-Color'
        if index==2:
            normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=strengths[key];links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs[socket])
        elif index==1:
            split=nodes.new('ShaderNodeSeparateColor');factor=nodes.new('ShaderNodeMath');factor.operation='MULTIPLY';factor.inputs[1].default_value=spec['roughness_multiplier'];links.new(tex.outputs['Color'],split.inputs['Color']);links.new(split.outputs['Green'],factor.inputs[0]);links.new(factor.outputs[0],bsdf.inputs[socket])
        else:
            multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1.;color=nodes.new('ShaderNodeVertexColor');color.layer_name='KilnVariation';links.new(tex.outputs['Color'],multiply.inputs[1]);links.new(color.outputs['Color'],multiply.inputs[2]);links.new(multiply.outputs[0],bsdf.inputs[socket])
    materials[key]=material

parts=[];checks=[];bricks=0;borings=0
x0,z0,x1,z1=plan['riser']['rect'];wall=plan['wall_m'];low=plan['riser']['from_y'];top=plan['native_top_y']-.12

def boring(obj,center_y,depth):
    global borings
    # Axis X in both game and native frames. This drills, rather than paints,
    # a round throat through each stock intersected by the retained sleeve.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.14,depth=depth,location=cv((obj.location.x,center_y,(z0+z1)/2)),rotation=(0,math.pi/2,0));cutter=bpy.context.object
    bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('CircularStovePort','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True);borings+=1

def box(name,a,b,key,bevel=0.,ports=False):
    global bricks
    rng=random.Random(name)
    if key=='stove_lime':
        # Recess only the exposed outer mortar faces; keep the closed native
        # bed/head volumes and the exact inner airway datum.
        a=list(a);b=list(b)
        for axis,first,last in [(0,x0,x1),(2,z0,z1)]:
            if abs(a[axis]-first)<1e-7:a[axis]+=.002
            if abs(b[axis]-last)<1e-7:b[axis]-=.002
    if name.startswith('Brick_'):bevel=rng.uniform(.0013,.0021)
    assert all(b[i]>a[i]+1e-7 for i in range(3)),(name,a,b)
    # Thousands of bpy.ops cube/transform/bevel calls repeatedly evaluate the
    # growing scene. Construct repeated stock directly; only real bores need
    # Blender's boolean operator. The game still receives four material batches.
    mesh=bpy.data.meshes.new(name);bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
    for vertex in bm.verts:vertex.co.x*=b[0]-a[0];vertex.co.y*=b[2]-a[2];vertex.co.z*=b[1]-a[1]
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.location=cv([(a[i]+b[i])/2 for i in range(3)])
    if ports:
        for port in plan['ports']:
            if a[1]<port['center_y']+.14 and b[1]>port['center_y']-.14 and a[2]<(z0+z1)/2+.14 and b[2]>(z0+z1)/2-.14:boring(obj,port['center_y'],b[0]-a[0]+.02)
    if len(obj.data.polygons)==0:bpy.data.objects.remove(obj,do_unlink=True);return
    # Quantize the eventual baked export positions before cleanup. A few
    # boolean mortar slivers collapse when translated into a 24 m mesh; catch
    # them here in each closed stock, before batching and UV qualification.
    shift=obj.location.copy()
    for vertex in obj.data.vertices:vertex.co+=shift
    obj.location=Vector((0,0,0))
    bm=bmesh.new();bm.from_mesh(obj.data)
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1,profile=.5,affect='EDGES',clamp_overlap=True)
    # Coplanar port/course boundaries can differ by half a micrometre after
    # float32 baking. Remove that numerical foil, not the 3 mm mortar joint:
    # MikkTSpace cannot supply a useful tangent for its needle triangles.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for face in bm.faces:face.smooth=False
    bm.to_mesh(obj.data);bm.free();mesh=obj.data;mesh.update()
    # Boolean cutters can contribute a legacy UVMap. Keep exactly the authored
    # metric layer active for both rendering and glTF's TEXCOORD_0.
    while mesh.uv_layers:mesh.uv_layers.remove(mesh.uv_layers[0])
    uv=mesh.uv_layers.new(name='MetresOverCatalogueTile');mesh.uv_layers.active=uv;uv.active_render=True;tile=float(catalog[key]['meters_per_tile'])
    for face in mesh.polygons:
        n=face.normal.normalized();seed=Vector((0,0,1)) if abs(n.z)<.9 else Vector((1,0,0));u=n.cross(seed).normalized();v=n.cross(u)
        first=mesh.vertices[mesh.loops[face.loop_indices[0]].vertex_index].co.copy()
        origin=(math.fsum(float(first[i])*float(u[i]) for i in range(3))/tile,math.fsum(float(first[i])*float(v[i]) for i in range(3))/tile)
        origin=(origin[0]-math.floor(origin[0]),origin[1]-math.floor(origin[1]))
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co-first;uv.data[loop].uv=(origin[0]+p.dot(u)/tile,origin[1]+p.dot(v)/tile)
    assert repair_mesh(obj)==0,'Authored metric charts must not need an uncalibrated fallback: '+name
    tone=rng.uniform(.70,1.10) if key=='stove_clinker' else 1.
    if key=='stove_clinker' and rng.random()<.12:tone*=rng.uniform(.50,.72)
    color=mesh.color_attributes.new(name='KilnVariation',type='FLOAT_COLOR',domain='POINT');mesh.color_attributes.active_color=color
    for index,point in enumerate(color.data):
        p=mesh.vertices[index].co
        soot=max(0.,min(1.,(p.z-(top-1.8))/1.8))**2
        damp=.12*math.exp(-max(0.,p.z)*1.2)
        streak=(.5+.5*math.sin(p.x*17.-p.y*11.))*.06
        weather=1.-soot*.36-damp-streak if key in ['stove_clinker','stove_lime'] else 1.
        point.color=(tone*weather,tone*weather*.98,tone*weather*.94,1.)
    mesh.materials.clear();mesh.materials.append(materials[key]);obj['material_key']=key
    bm=bmesh.new();bm.from_mesh(mesh);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free();mesh.calc_loop_triangles();coords=mesh.uv_layers.active.data
    collapsed=sum(abs((coords[t.loops[1]].uv-coords[t.loops[0]].uv).cross(coords[t.loops[2]].uv-coords[t.loops[0]].uv))<1e-12 for t in mesh.loop_triangles)
    zero=sum((mesh.vertices[t.vertices[1]].co-mesh.vertices[t.vertices[0]].co).cross(mesh.vertices[t.vertices[2]].co-mesh.vertices[t.vertices[0]].co).length_squared==0 for t in mesh.loop_triangles)
    assert bad==0 and volume>0 and collapsed==0 and zero==0,(name,bad,volume,collapsed,zero)
    checks.append({'id':name,'material_key':key,'volume_m3':volume,'nonmanifold_edges':bad,'collapsed_uv_triangles':collapsed,'zero_area_triangles':zero});parts.append(obj)
    if key=='stove_clinker':bricks+=1

course=0;y=low;joint=.009
while y<top-1e-7:
    end=min(top,y+.08);bed_end=min(end,y+joint)
    # Alternating full ends/full cheeks bond the corners without duplicate
    # bricks or a solid hidden centre. Mortar fills actual bed/head gaps.
    if course%2==0:runs=[(x0,z0,x0+wall,z1,2),(x1-wall,z0,x1,z1,2),(x0+wall,z0,x1-wall,z0+wall,0),(x0+wall,z1-wall,x1-wall,z1,0)]
    else:runs=[(x0,z0,x1,z0+wall,0),(x0,z1-wall,x1,z1,0),(x0,z0+wall,x0+wall,z1-wall,2),(x1-wall,z0+wall,x1,z1-wall,2)]
    for run,(a,c,b,d,axis) in enumerate(runs):
        west=b<=x0+wall+.00001
        box(f'Bed_{course:03d}_{run}',(a,y,c),(b,bed_end,d),'stove_lime',ports=west)
        length=(b-a) if axis==0 else (d-c);count=max(1,round(length/.23))
        for index in range(count):
            start=length*index/count;finish=length*(index+1)/count;head=joint if index<count-1 else 0.
            p=(a+start,bed_end,c) if axis==0 else (a,bed_end,c+start)
            q=(a+finish-head,end,d) if axis==0 else (b,end,c+finish-head)
            box(f'Brick_{course:03d}_{run}_{index}',p,q,'stove_clinker',.0007,west)
            if head:
                p=(a+finish-head,bed_end,c) if axis==0 else (a,bed_end,c+finish-head)
                q=(a+finish,end,d) if axis==0 else (b,end,c+finish)
                box(f'Head_{course:03d}_{run}_{index}',p,q,'stove_lime',ports=west)
    y=end;course+=1
    if course%40==0:print('C STACK:',course,'courses;',len(parts),'closed stocks',flush=True)

for port in plan['ports']:
    a,b=port['plaster_patch_bounds'][:3],port['plaster_patch_bounds'][3:]
    box(port['id']+'_PlasterCollar',a,b,'limewash_plaster',ports=True)
    box(port['id']+'_OuterLeafCollar',(b[0],a[1],a[2]),(x0,b[1],b[2]),'stove_clinker',ports=True)
pad=.06
box('ContinuousStackFooting',(x0-pad,plan['native_footing_bottom_y'],z0-pad),(x1+pad,low,z1+pad),'concrete',.002)
for name,a,b in [('West',(x0-.05,top,z0-.05),(x0+wall,top+.12,z1+.05)),('East',(x1-wall,top,z0-.05),(x1+.05,top+.12,z1+.05)),('South',(x0+wall,top,z0-.05),(x1-wall,top+.12,z0+wall)),('North',(x0+wall,top,z1-wall),(x1-wall,top+.12,z1+.05))]:box('OpenCoping_'+name,a,b,'concrete',.003)

for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(out))
native=out/'c_stove_stack.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
# The editable file retains individual closed stocks; the export batches them
# by material to avoid thousands of game draw calls.
groups={key:[obj for obj in parts if obj.get('material_key')==key] for key in keys}
for key,group in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in group:obj.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();obj=bpy.context.object;obj.name=key;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.object.select_all(action='SELECT');asset=out/'c_stove_stack.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
# Measure the actual new native airway and all five circular wall passages.
trees=[]
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':trees.append(BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons]))
for port in plan['ports']:
    for dy,dz in [(0,0),(.08,0),(-.08,0),(0,.08),(0,-.08)]:
        origin=cv((port['position'][0]-.02,port['center_y']+dy,(z0+z1)/2+dz))
        assert all(tree.ray_cast(origin,Vector((1,0,0)),x0+wall+.02-origin.x)[0] is None for tree in trees),(port['id'],dy,dz)
for dx in [-.06,0,.06]:
    origin=cv(((x0+x1)/2+dx,low+.02,(z0+z1)/2))
    assert all(tree.ray_cast(origin,Vector((0,0,1)),plan['native_top_y']-low+.1)[0] is None for tree in trees),dx

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20;scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.color=(.06,.06,.06)
for point,power,size in [((5,14,8),900,5),((10,22,13),600,4)]:
    data=bpy.data.lights.new('ReviewSoftbox','AREA');data.energy=power;data.size=size;obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=cv(point);obj.rotation_euler=(cv(((x0+x1)/2,12,(z0+z1)/2))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera
scene.render.resolution_x=900;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
for name,eye,at,scale in [('whole_stack',(4,12,5),((x0+x1)/2,9,(z0+z1)/2),27),('room_port',(6,4.9,9.2),(7.25,4.64,(z0+z1)/2),1.35),('open_crown',(6,22.6,9.1),((x0+x1)/2,21.2,(z0+z1)/2),1.4)]:
    camera.location=cv(eye);camera.rotation_euler=(cv(at)-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=scale;scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
bindings={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [source_path,layout_path,ROOT/'game/data/runtime_material_sets.json']}
for key in keys:
    for file in catalog[key]['files']:
        path=ROOT/'game/assets/building/textures'/file;bindings[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
report={'evidence_class':'INERT','scope':'Native candidate only. Not installed; no imported precision, loaded mip, roof/grade cut or human acceptance.','source_bindings':bindings,'generator_sha256_lf':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_stocks':len(checks),'bricks':bricks,'courses':course,'bore_boolean_operations':borings,'checks':checks,'native_clear_port_rays':25,'native_clear_vertical_rays':3,'export_material_batches':len(keys)}
(out/'native_review.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print('C STOVE STACK NATIVE:',len(checks),'closed stocks;',bricks,'bricks; 25 round port and 3 vertical native rays clear')
