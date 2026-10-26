"""Sessile Vorticella guide-bell; reproducible native geometry and UV review.
Uses the zoo Vorticella's flared bell / spasmoneme / ciliary identity.
Blender --background --python-exit-code 1 --python this_file
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/dream/guide_bell'
OUT.mkdir(parents=True, exist_ok=True)
# Local fabrication primitives keep this asset independently reproducible.
def tube(name, points, radii, sides, material):
    vertices, faces, uv = [], [], []
    distance=0.0
    for i, p in enumerate(points):
        if i:distance+=(Vector(p)-Vector(points[i-1])).length
        tangent=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        reference=Vector((0,0,1)) if abs(tangent.z)<.95 else Vector((0,1,0))
        right=tangent.cross(reference).normalized()
        across=tangent.cross(right).normalized()
        for j in range(sides+1):
            angle = math.tau*j/sides
            vertices.append(tuple(Vector(p)+radii[i]*(math.cos(angle)*right+math.sin(angle)*across)))
            uv.append((j/sides*math.tau*radii[i]/.16, distance/.16))
    for i in range(len(points)-1):
        for j in range(sides):
            a = i*(sides+1)+j
            faces.append((a,a+1,a+sides+2,a+sides+1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.uv_layers.new(name='AnatomicalUV')
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices: mesh.uv_layers[0].data[loop].uv = uv[mesh.loops[loop].vertex_index]
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj

def ellipsoid(name, location, scale, material, segments):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=max(6,segments//2), location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Bake coordinates so every organ shares the body deformation field.
    for vertex in obj.data.vertices: vertex.co += obj.location
    obj.location = (0,0,0)
    obj.data.materials.append(material)
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj
# The fabrication primitives supply topology. This species supplies
# metric charts: one texture tile is 16 cm, including joined microstructures.
native_tube=tube
native_ellipsoid=ellipsoid
TILE=.16
def tube(name,points,radii,sides,material):
    obj=native_tube(name,points,radii,sides,material)
    lengths=[0.0]
    for a,b in zip(points,points[1:]): lengths.append(lengths[-1]+(Vector(b)-Vector(a)).length)
    for loop in obj.data.loops:
        ring,spoke=divmod(loop.vertex_index,sides+1)
        obj.data.uv_layers.active.data[loop.index].uv=(spoke/sides*math.tau*radii[ring]/TILE,lengths[ring]/TILE)
    return obj
def ellipsoid(name,location,scale,material,segments):
    obj=native_ellipsoid(name,location,scale,material,segments)
    radial=(scale[0]+scale[1])*.5
    for uv in obj.data.uv_layers.active.data:
        uv.uv.x*=math.tau*radial/TILE
        uv.uv.y*=math.pi*(radial+scale[2])*.5/TILE
    return obj
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
random.seed(61025)
mats = {}
for name, color in [('membrane',(.53,.57,.43,1)),('tissue',(.38,.29,.39,1))]:
    mat=bpy.data.materials.new('guide_bell_'+name); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Roughness'].default_value=.32
    if name=='membrane':
        bsdf.inputs['Transmission Weight'].default_value=.96
        bsdf.inputs['IOR'].default_value=1.36
    mats[name]=mat
    for channel,socket in [('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]:
        path=OUT/f'{name}_{channel}.png'
        if not path.exists(): continue
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(path))
        if channel!='albedo': tex.image.colorspace_settings.name='Non-Color'
        if channel=='normal':
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value=.18 if name=='membrane' else .6
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[socket])
        elif name=='membrane' and channel=='albedo':
            # Thin cytoplasm transmits much more light than opaque purple stock.
            tint=mat.node_tree.nodes.new('ShaderNodeMixRGB')
            tint.inputs[0].default_value=.18
            tint.inputs[2].default_value=(1,1,1,1)
            mat.node_tree.links.new(tex.outputs['Color'],tint.inputs[1])
            mat.node_tree.links.new(tint.outputs[0],bsdf.inputs[socket])
        else: mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])

ellipsoid('Holdfast_secreted_pad',(0,0,.008),(.12,.095,.012),mats['tissue'],24)
for k in range(11):
    angle=k*math.tau/11
    points=[(math.cos(angle)*(.03+t*.13),math.sin(angle)*(.03+t*.10),.008+math.sin(t*math.pi)*.009) for t in [i/8 for i in range(9)]]
    tube('Holdfast_fibril_%02d'%k,points,[.003*(1-i/10) for i in range(9)],6,mats['tissue'])
points=[(.013*math.sin(i/40*2),0,.02+i/40*.35) for i in range(41)]
tube('Membrane_stalk_sheath',points,[.009+i/40*.002 for i in range(41)],14,mats['membrane'])
tube('Spasmoneme_calcium_fiber',points,[.003]*41,8,mats['tissue'])
for k in range(3):
    ps=[]
    for i in range(81):
        t=i/80; angle=t*math.tau*9+k*math.tau/3
        ps.append((.013*math.sin(t*2)+.007*math.cos(angle),.007*math.sin(angle),.02+t*.35))
    tube('Helical_fibril_%d'%k,ps,[.0012]*81,5,mats['tissue'])
# Asymmetric hollow bell, not a capped chalice. Real thick lip and lumen.
profile=[(.34,.012),(.37,.035),(.40,.077),(.44,.115),(.49,.135),(.54,.139),(.58,.15),(.60,.147),(.605,.137),(.59,.130),(.56,.124),(.52,.120),(.48,.116),(.44,.092),(.40,.051)]
vertices=[]; faces=[]; uvs=[]
profile_distance=0.0
for i,(z,r) in enumerate(profile):
    if i: profile_distance+=math.hypot(z-profile[i-1][0],r-profile[i-1][1])
    for j in range(49):
        a=math.tau*j/48; asym=1+.045*math.sin(a*3+.3)
        vertices.append((r*math.cos(a)*asym+.014,r*.86*math.sin(a),z+.012*math.cos(a)*max(0,(z-.40)/.2)))
        uvs.append((j/48*math.tau*r/TILE,profile_distance/TILE))
for i in range(len(profile)-1):
    for j in range(48):
        a=i*49+j; faces.append((a,a+1,a+50,a+49))
mesh=bpy.data.meshes.new('Bell'); mesh.from_pydata(vertices,[],faces); mesh.uv_layers.new(name='CellWallUV')
for poly in mesh.polygons:
    poly.use_smooth=True
    for loop in poly.loop_indices: mesh.uv_layers[0].data[loop].uv=uvs[mesh.loops[loop].vertex_index]
obj=bpy.data.objects.new('Membrane_bell_wall',mesh); bpy.context.collection.objects.link(obj); obj.data.materials.append(mats['membrane'])
for band in range(3):
    for k in range(32):
        if (k+band*3)%17==0: continue
        a=math.tau*(k+.3*band)/32
        r=.139+band*.004; length=.045+.014*math.sin(k*3.7+band)
        ps=[]
        for i in range(7):
            t=i/6
            ps.append((.014+math.cos(a)*(r+t*.025)+t*t*.024,math.sin(a)*(r*.86+t*.018),.588+band*.006+t*length))
        tube('Cilium_%d_%02d'%(band,k),ps,[.0018*(1-.8*i/6) for i in range(7)],5,mats['tissue'])
ellipsoid('Nucleus_macronucleus',(.02,.013,.465),(.041,.023,.045),mats['tissue'],24)
ellipsoid('Nucleus_micronucleus',(-.026,.022,.455),(.010,.008,.011),mats['tissue'],16)
for k in range(12):
    a=k*2.399; z=.42+random.random()*.13; r=(z-.36)*.34
    ellipsoid('Vacuole_%02d'%k,(.014+math.cos(a)*r,math.sin(a)*r*.7,z),(.012,.009,.015),mats['membrane'],16)
for k in range(24):
    z=random.uniform(.42,.55); r=(z-.36)*random.uniform(.08,.35); a=random.random()*math.tau
    ellipsoid('Granule_%02d'%k,(.014+math.cos(a)*r,math.sin(a)*r,z),(.003,.003,.004),mats['tissue'],8)
for k in range(7):
    z=.405+k*.025; r=(z-.35)*.53
    ps=[(.014+math.cos(i*math.tau/48)*r,math.sin(i*math.tau/48)*r*.86,z) for i in range(49)]
    tube('Cortex_band_%d'%k,ps,[.0015]*49,5,mats['tissue'])
# Explicit native triangle UV check, including inherited sphere pole charts.
errors=[]
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH': continue
    obj.data.calc_loop_triangles()
    uv=obj.data.uv_layers.active.data
    for tri in obj.data.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))
        if tri.area>1e-12 and area<1e-12: errors.append(obj.name)
assert not errors, errors[:10]
# Related anatomical structures share draws; no individual-cilium submission
# overhead. All coordinates were baked before joining and UVs remain intact.
families={}
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH': continue
    obj.data.uv_layers.active.name='AnatomicalUV'
    name=obj.name
    family='Tissue_fibrils'
    if name.startswith('Membrane'): family='Membrane_cell'
    elif name.startswith('Nucleus'): family='Nucleus_pair'
    elif name.startswith('Vacuole'): family='Vacuole_chain'
    elif name.startswith('Granule'): family='Granule_flow'
    elif name.startswith('Cilium'): family='_'.join(name.split('_')[:2])+'_band'
    families.setdefault(family,[]).append(obj)
for family,objects in families.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join(); bpy.context.object.name=family
    merged=bpy.context.object.data; merged.calc_loop_triangles()
    for tri in merged.loop_triangles:
        a,b,c=[merged.uv_layers.active.data[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))
        assert tri.area<=1e-12 or area>1e-12, family
blend=ROOT/'art/blender/dream_critters/guide_bell.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(OUT/'guide_bell.glb'),export_format='GLB',export_apply=True,export_yup=True)
# Native inspection before Godot capture.
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.world.color=(.09,.09,.09)
bpy.ops.object.camera_add(location=(1.0,-1.5,.85)); camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.32))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.lens=65; scene.camera=camera
for at,power,size in [((.4,-.8,1.2),55,.7),((-.4,.5,.75),75,.5)]:
    bpy.ops.object.light_add(type='AREA',location=at); light=bpy.context.object; light.data.energy=power; light.data.shape='DISK'; light.data.size=size
    light.rotation_euler=(Vector((0,0,.35))-light.location).to_track_quat('-Z','Y').to_euler()
render=ROOT/'tmp/guide_bell/blender.png'; render.parent.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(render); bpy.ops.render.render(write_still=True)
