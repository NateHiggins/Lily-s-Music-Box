"""Reproducible gang anatomy, drawing on the existing hero's asymmetric profile.
Run Blender --background --python-exit-code 1 --python this_file.
All internal structures and membrane use the same local deformation coordinates.
"""
import ast
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/dream/tentacle_gang'
OUT.mkdir(parents=True, exist_ok=True)
METRES_PER_TILE = .08

def metric_smart_chart(obj):
    """Preserve smart-chart angles while fixing physical texel density."""
    mesh=obj.data
    mesh.calc_loop_triangles()
    layer=mesh.uv_layers.active.data
    area=sum(t.area for t in mesh.loop_triangles)
    uv_area=0.0
    for triangle in mesh.loop_triangles:
        a,b,c=[layer[i].uv for i in triangle.loops]
        uv_area+=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
    assert area>0 and uv_area>0,obj.name
    scale=math.sqrt(area/uv_area)/METRES_PER_TILE
    for loop in layer:loop.uv*=scale
tree = ast.parse((Path(__file__).with_name('build_dream_tentacle.py')).read_text())
PROFILE = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
               and any(isinstance(t, ast.Name) and t.id == 'PROFILE' for t in n.targets))

def radius(t):
    for a, b in zip(PROFILE, PROFILE[1:]):
        if a[0] <= t <= b[0]:
            return (a[1] + (b[1]-a[1])*(t-a[0])/(b[0]-a[0]))*.58
    return .009

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
            uv.append((j/sides*math.tau*radii[i]/METRES_PER_TILE, distance/METRES_PER_TILE))
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
    # The sphere unwrap has angular coordinates; rescale its physical chart.
    for loop in obj.data.uv_layers.active.data:
        loop.uv.x*=math.tau*math.sqrt(scale[0]*scale[1])/METRES_PER_TILE
        loop.uv.y*=math.pi*scale[2]/METRES_PER_TILE
    return obj

def build(tier, rings, sides):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    mats = {}
    for name, color in [('membrane',(.43,.31,.39,1)),('muscle',(.44,.25,.30,1)),
                        ('nerve',(.69,.61,.47,1)),('gold',(.55,.36,.12,1)),('eye',(.08,.045,.055,1))]:
        mat = bpy.data.materials.new('tentacle_gang_'+name)
        mat.diffuse_color = color
        mat.use_nodes = True
        bsdf=mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Roughness'].default_value=.27 if name=='membrane' else .48
        if name=='membrane':
            bsdf.inputs['Transmission Weight'].default_value=.65
            bsdf.inputs['IOR'].default_value=1.38
        if name=='gold': bsdf.inputs['Metallic'].default_value=1
        mats[name] = mat
    points = [(0,0,.70*i/rings) for i in range(rings+1)]
    rs = [radius(i/rings)*(1+.055*math.sin(i/rings*97)) for i in range(rings+1)]
    membrane=tube('MEMBRANE_epithelial_shell',points,rs,sides,mats['membrane'])
    # A real closed wall, including root and distal rims, not a paper tube.
    bpy.context.view_layer.objects.active=membrane
    membrane.select_set(True)
    wall=membrane.modifiers.new('Authored epithelial thickness','SOLIDIFY')
    wall.thickness=.0025
    wall.use_even_offset=True
    bpy.ops.object.modifier_apply(modifier=wall.name)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    metric_smart_chart(membrane)
    # Three concentric depth bands; fascicles are actual separated geometry.
    for band, distance in enumerate([.012,.025,.038]):
        for bundle in range(4 if tier!='remnant' else 2):
            angle = math.tau*bundle/4+band*.43
            ps = [(math.cos(angle+t*.9)*min(distance,radius(t)*.70),
                   math.sin(angle+t*.9)*min(distance,radius(t)*.70),t*.68+.005)
                  for t in [i/rings for i in range(rings+1)]]
            tube('MUSCLE_fascicle_%d_%d'%(band,bundle),ps,[.0035]*len(ps),6,mats['muscle'])
    for sign in [-1,1]:
        ps=[(sign*.011,.004+math.sin(i*.7)*.002,.68*i/rings) for i in range(rings+1)]
        tube('NERVE_paired_cord',ps,[.002]*len(ps),5,mats['nerve'])
        for i in range(1,9):
            z=.07*i
            ellipsoid('GANGLION', (sign*.011,.004,z),(.004,.005,.006),mats['nerve'],12)
            tube('GOLD_discontinuous_inclusion',[(sign*.014,.009,z),(sign*.013,.01,z+.028)],[.0008,.0006],5,mats['gold'])
            if sign==1:
                tube('NERVE_ladder_crosslink',[(-.011,.004,z),(.0,.006,z+.006),(.011,.004,z)],[.001]*3,5,mats['nerve'])
    tube('VASCULAR_dorsal_channel',[(.006,-.017,.67*i/rings) for i in range(rings+1)],
         [.003*(1+.18*math.sin(i*.7)) for i in range(rings+1)],6,mats['muscle'])
    tube('DIGESTIVE_intake_groove',[(-.008,.016,.67*i/rings) for i in range(rings+1)],
         [.003]* (rings+1),6,mats['nerve'])
    for i in range(1,8):
        z=.08*i
        ellipsoid('PRESSURE_gasless_chamber',(0,-.012,z),(.012,.013,.025),mats['nerve'],sides)
        ps=[(.025*math.cos(t*math.tau),.025*math.sin(t*math.tau),z+.008*t) for t in [j/24 for j in range(25)]]
        tube('MUSCLE_oblique_band',ps,[.002]*len(ps),5,mats['muscle'])
        if i in [2,4,6]:
            ellipsoid('COLLAGEN_transverse_septum',(0,0,z),(.024,.021,.0015),mats['nerve'],sides)
        for j in range(5):
            angle=j*math.tau/5
            r=radius(z/.7)
            tube('CILIUM_sensory_fan',[(r*math.cos(angle),r*math.sin(angle),z),
                ((r+.018)*math.cos(angle),(r+.018)*math.sin(angle),z+.013)],[.0008,.00015],4,mats['nerve'])
    ellipsoid('OCELLUS_cornea',(0,-.028,.57),(.021,.016,.025),mats['membrane'],sides)
    ellipsoid('PIGMENT_retinal_cup',(0,-.023,.57),(.016,.009,.019),mats['eye'],sides)
    ellipsoid('OCELLUS_lens',(0,-.037,.57),(.009,.006,.012),mats['membrane'],sides)
    ellipsoid('STATOCYST_chamber',(.024,0,.49),(.011,.012,.016),mats['membrane'],sides)
    ellipsoid('GOLD_statolith',(.024,0,.481),(.003,.003,.003),mats['gold'],12)
    for role in ['Probe','Disk','Brush']:
        group=bpy.data.objects.new('CONTACT_'+role,None)
        bpy.context.collection.objects.link(group)
        pieces=[]
        if role=='Probe':
            for side in [-1,1]:
                pieces.append(ellipsoid('TIP_probing_lobe',(side*.013,0,.70),(.018,.018,.012),mats['muscle'],sides))
        elif role=='Disk':
            pieces.append(ellipsoid('TIP_adhesive_disk',(0,0,.697),(.033,.026,.008),mats['muscle'],sides))
            for spoke in range(8):
                angle=spoke*math.tau/8
                pieces.append(tube('TIP_radial_fold',[(0,0,.707),(.015*math.cos(angle),.012*math.sin(angle),.711),
                    (.03*math.cos(angle),.024*math.sin(angle),.702)],[.0015,.0018,.001],5,mats['nerve']))
        else:
            for finger in [-1,0,1]:
                pieces.append(tube('TIP_ciliary_finger',[(0,0,.68),(finger*.012,.004,.71),
                    (finger*.025,.016,.73)],[.005,.003,.0008],6,mats['nerve']))
        for piece in pieces:
            piece.parent=group
            # All three are exported; the runtime retains one anatomical role.
            if role!='Probe': piece.hide_render=True
    ellipsoid('MEMBRANE_root_collar',(0,0,.014),(.085,.065,.025),mats['membrane'],sides)
    # Bake a curved hydrostat resting pose into every depth band alike.
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH': continue
        for vertex in obj.data.vertices:
            t=max(0,min(1,vertex.co.z/.70))
            vertex.co.x += .14*t*t
            vertex.co.y += .025*math.sin(t*math.pi)
    # Preserve named organs, but batch repeated anatomy by substance.
    for prefix in ['MUSCLE','NERVE','GANGLION','GOLD_discontinuous','PRESSURE','CILIUM','COLLAGEN']:
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(prefix)]
        if len(objects)<2: continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=prefix
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender'/('tentacle_gang_'+tier+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/('gang_'+tier+'.glb')),export_format='GLB',export_yup=True)
    if tier=='normal':
        bpy.ops.object.camera_add(location=(1.05,-1.4,.85))
        camera=bpy.context.object
        camera.rotation_euler=(Vector((0,0,.35))-camera.location).to_track_quat('-Z','Y').to_euler()
        bpy.context.scene.camera=camera
        for location,energy,size in [((1,-2,2),180,2),((-1,1,1),250,1)]:
            bpy.ops.object.light_add(type='AREA',location=location)
            light=bpy.context.object
            light.data.energy=energy;light.data.shape='DISK';light.data.size=size
            light.rotation_euler=(Vector((0,0,.35))-light.location).to_track_quat('-Z','Y').to_euler()
        scene=bpy.context.scene
        scene.render.engine='CYCLES';scene.cycles.samples=16
        scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
        scene.render.filepath=str(OUT/'anatomy_review.png')
        bpy.ops.render.render(write_still=True)
        for obj in scene.objects:
            if obj.type=='MESH' and obj.name.startswith('MEMBRANE'): obj.hide_render=True
        scene.render.filepath=str(OUT/'anatomy_internal_review.png')
        bpy.ops.render.render(write_still=True)

for args in [('hero',72,28),('normal',40,20),('remnant',16,12)]: build(*args)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
root_material=bpy.data.materials.get('tentacle_gang_membrane')
nerve_material=bpy.data.materials.get('tentacle_gang_nerve')
ellipsoid('MEMBRANE_shared_reservoir',(0,0,-.025),(.24,.21,.065),root_material,28)
ellipsoid('MUSCLE_fused_knot',(0,0,-.018),(.17,.14,.044),nerve_material,20)
for index in range(7):
    angle=math.tau*index/7
    tube('NERVE_converging_tendon',[(0,0,-.025),(.06*math.cos(angle),.06*math.sin(angle),-.01),
         (.13*math.cos(angle),.13*math.sin(angle),.005)],[.006,.004,.002],6,nerve_material)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/tentacle_gang_root.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'gang_root.glb'),export_format='GLB',export_yup=True)
