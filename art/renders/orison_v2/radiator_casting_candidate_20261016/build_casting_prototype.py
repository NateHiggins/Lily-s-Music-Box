"""Nonshipping three-column casting study; retains the current section envelope."""
from pathlib import Path
import hashlib,json,math,sys
import bpy,bmesh
from mathutils import Vector
ROOT=Path.cwd();OUT=ROOT/'tmp/v2-radiator-next-20261016'
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from repair_surface_uvs import repair_scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.unit_settings.system='METRIC'

def lathe(name,cy):
    profile=[(0,.0001,.0001),(.001,.0045,.0045),(.004,.009,.009),(.009,.014,.014),(.016,.019,.019),(.028,.023,.023),(.045,.026,.026),(.09,.026,.026),(.15,.022,.024),(.30,.019,.022),(.46,.019,.022),(.55,.022,.024),(.625,.026,.026),(.642,.023,.023),(.654,.019,.019),(.661,.014,.014),(.666,.009,.009),(.669,.0045,.0045),(.67,.0001,.0001)]
    vertices=[];faces=[];sides=32
    for h,rx,ry in profile:
        vertices.extend((rx*math.cos(i*math.tau/sides),cy+ry*math.sin(i*math.tau/sides),h) for i in range(sides))
    for row in range(len(profile)-1):
        for i in range(sides):
            a=row*sides+i;b=row*sides+(i+1)%sides;c=b+sides;d=a+sides;faces.append((a,b,c,d))
    faces.extend([tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+i for i in range(sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj

def cylinder(name,at,radius,length,axis):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=length,location=at)
    obj=bpy.context.object;obj.name=name;obj.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return obj

def boolean(body,cutter,operation):
    bpy.context.view_layer.objects.active=body
    modifier=body.modifiers.new(operation,'BOOLEAN');modifier.operation=operation;modifier.solver='EXACT';modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)

body=lathe('CastSection',-.075)
for cy in [0,.075]:boolean(body,lathe('Column',cy),'UNION')
for height in [.085,.615]:
    boolean(body,cylinder('Header',(0,0,height),.028,.19,(0,1,0)),'UNION')
    boolean(body,cylinder('Nipple',(0,.055,height),.030,.092,(1,0,0)),'UNION')
# Connected inner waterways; ports are genuine bores, never painted dots.
for cy in [-.075,0,.075]:boolean(body,cylinder('VerticalWaterway',(0,cy,.35),.014,.57,(0,0,1)),'DIFFERENCE')
for height in [.085,.615]:
    boolean(body,cylinder('HeaderWaterway',(0,0,height),.017,.166,(0,1,0)),'DIFFERENCE')
    boolean(body,cylinder('NippleBore',(0,.055,height),.016,.13,(1,0,0)),'DIFFERENCE')
bpy.context.view_layer.objects.active=body
bevel=body.modifiers.new('Foundry edge easing','BEVEL');bevel.width=.0006;bevel.segments=2;bevel.limit_method='ANGLE';bevel.angle_limit=.5
bpy.ops.object.modifier_apply(modifier=bevel.name)
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free();body.data.update()
for face in body.data.polygons:face.use_smooth=True
# Continuous smart-projected islands, rescaled to metre area, not per-triangle phases.
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.008,correct_aspect=True,scale_to_bounds=False)
bpy.ops.object.mode_set(mode='OBJECT');body.data.update();body.data.calc_loop_triangles()
uv=body.data.uv_layers.active.data
world_area=sum(face.area for face in body.data.polygons)
uv_area=sum(abs((uv[t.loops[1]].uv-uv[t.loops[0]].uv).cross(uv[t.loops[2]].uv-uv[t.loops[0]].uv))*.5 for t in body.data.loop_triangles)
factor=math.sqrt(world_area/uv_area)
for loop in uv:loop.uv*=factor
repair_scene()
spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']['iron_neutral']
material=bpy.data.materials.new('iron_neutral');material.use_nodes=True;material.node_tree.nodes.clear();nodes=material.node_tree.nodes;links=material.node_tree.links
shader=nodes.new('ShaderNodeBsdfPrincipled');output=nodes.new('ShaderNodeOutputMaterial');links.new(shader.outputs['BSDF'],output.inputs['Surface']);shader.inputs['Metallic'].default_value=spec['metallic']
coordinates=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs[3].default_value=1.0/spec['meters_per_tile'];links.new(coordinates.outputs['UV'],scale.inputs[0])
for i,label in enumerate(['Base Color','Roughness','Normal']):
    tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]))
    links.new(scale.outputs['Vector'],tex.inputs['Vector'])
    if i:tex.image.colorspace_settings.name='Non-Color'
    if i==2:
        node=nodes.new('ShaderNodeNormalMap');node.inputs['Strength'].default_value=.2;links.new(tex.outputs['Color'],node.inputs['Color']);links.new(node.outputs['Normal'],shader.inputs[label])
    else:links.new(tex.outputs['Color'],shader.inputs[label])
body.data.materials.clear();body.data.materials.append(material)
for polygon in body.data.polygons:polygon.material_index=0
bm=bmesh.new();bm.from_mesh(body.data);nonmanifold=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
body.data.calc_loop_triangles();uv=body.data.uv_layers.active.data
meaningful=[t for t in body.data.loop_triangles if (body.data.vertices[t.vertices[1]].co-body.data.vertices[t.vertices[0]].co).cross(body.data.vertices[t.vertices[2]].co-body.data.vertices[t.vertices[0]].co).length_squared>1e-18]
bad_uv=sum(abs((uv[t.loops[1]].uv-uv[t.loops[0]].uv).cross(uv[t.loops[2]].uv-uv[t.loops[0]].uv))<1e-12 for t in meaningful)
failures=[]
if nonmanifold:failures.append('nonmanifold edges: '+str(nonmanifold))
if volume<=0:failures.append('nonpositive solid volume')
if bad_uv:failures.append('collapsed UVs: '+str(bad_uv))
report={'evidence_class':'INERT','status':'AUTHORING_PROTOTYPE_NOT_INSTALLED','scope':'Three-column silhouette, closed cast crown, connected internal waterways and actual nipple bores; no fit, runtime, performance or human acceptance.','triangles':len(body.data.loop_triangles),'nonmanifold_edges':nonmanifold,'volume_m3':volume,'collapsed_uv_triangles':bad_uv,'bounds_blender':[list(body.bound_box[0]),list(body.bound_box[6])],'failures':failures,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
if failures:
    (OUT/'inspection.json').write_text(json.dumps(report,indent=2)+'\n');raise RuntimeError(str(failures))
native=OUT/'radiator_casting_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native));report['native_sha256']=hashlib.sha256(native.read_bytes()).hexdigest()
for i in range(1,9):
    copy=body.copy();copy.data=body.data;bpy.context.collection.objects.link(copy);copy.location.x=.092*i
body.location.x=0
# Simple studio floor is review-only, not an accepted game asset.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.12));floor=bpy.context.object
mat=bpy.data.materials.new('Review floor');mat.diffuse_color=(.23,.24,.25,1);floor.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review world');scene.world.color=(.17,.17,.17)
def light(at,power,size):
    bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(Vector((.36,0,.35))-lamp.location).to_track_quat('-Z','Y').to_euler()
light((.2,-1.6,2.4),180,2);light((1.1,.9,1.1),100,1.3)
bpy.ops.object.camera_add(location=(1.25,-1.4,1.0));camera=bpy.context.object;camera.data.lens=50;camera.rotation_euler=(Vector((.36,0,.34))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(OUT/'three_column_review.png');bpy.ops.render.render(write_still=True)
report['review_sha256']=hashlib.sha256((OUT/'three_column_review.png').read_bytes()).hexdigest();(OUT/'inspection.json').write_text(json.dumps(report,indent=2)+'\n');print('RADIATOR PROTOTYPE',json.dumps(report))
