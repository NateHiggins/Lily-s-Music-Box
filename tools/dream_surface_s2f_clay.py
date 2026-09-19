import bpy, math, os
from mathutils import Vector

ROOT = os.environ.get("S2F_OUT", r"C:\PleaseRemainOnTheLine-s2\art\renders\dream_surface_s2f\2026-08-28\clay_01")
os.makedirs(ROOT, exist_ok=True)

def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.curves, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass

def mat(name, value=.36, rough=.72):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(value,value*0.97,value*0.94,1); m.roughness=rough
    return m

CLAY=None; DARK=None

def uv(name, loc, scale, material=None, seg=32, rings=20):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material: o.data.materials.append(material)
    return o

def curve(name, pts, radii, material=None, bevel=.08, cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.resolution_u=3; cu.bevel_depth=bevel; cu.bevel_resolution=4
    sp=cu.splines.new('BEZIER'); sp.bezier_points.add(len(pts)-1); sp.use_cyclic_u=cyclic
    for i,(co,rad) in enumerate(zip(pts,radii)):
        p=sp.bezier_points[i]; p.co=co; p.radius=rad; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cu); bpy.context.collection.objects.link(o)
    if material: o.data.materials.append(material)
    return o

def join_remesh(objects, name, voxel=.045, smooth=5):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.convert(target='MESH');
    # Convert remaining curves individually, then join.
    for o in list(objects[1:]):
        if o.type!='MESH': bpy.context.view_layer.objects.active=o; bpy.ops.object.convert(target='MESH')
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        if o.name in bpy.context.view_layer.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); out=bpy.context.object; out.name=name
    rem=out.modifiers.new('Biological continuity','REMESH'); rem.mode='VOXEL'; rem.voxel_size=voxel; rem.use_smooth_shade=True
    bpy.context.view_layer.objects.active=out; bpy.ops.object.modifier_apply(modifier=rem.name)
    for _ in range(smooth):
        sm=out.modifiers.new('cortical relaxation','SMOOTH'); sm.factor=.32; sm.iterations=2; bpy.ops.object.modifier_apply(modifier=sm.name)
    bpy.ops.object.shade_smooth()
    return out

def boolean(obj, cutter, operation='DIFFERENCE'):
    mod=obj.modifiers.new('organic cutaway','BOOLEAN'); mod.operation=operation; mod.solver='EXACT'; mod.object=cutter
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)

def irregular_blob(name, loc, scale, material, seed=0):
    o=uv(name,loc,scale,material)
    for v in o.data.vertices:
        n=v.co.normalized(); wobble=1+.07*math.sin(n.x*5.1+seed)+.045*math.sin(n.z*7.3-seed*.7)
        v.co*=wobble
    bpy.ops.object.shade_smooth(); return o

def setup(camera_loc, target=(0,0,0), ortho=7.0):
    world=bpy.context.scene.world or bpy.data.worlds.new('World'); bpy.context.scene.world=world
    world.color=(.012,.012,.016)
    bpy.ops.object.camera_add(location=camera_loc); cam=bpy.context.object; cam.data.type='ORTHO'; cam.data.ortho_scale=ortho
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.camera=cam
    bpy.ops.object.light_add(type='AREA', location=(3,-4,6)); key=bpy.context.object; key.data.energy=520; key.data.shape='DISK'; key.data.size=5
    key.rotation_euler=(Vector(target)-key.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='AREA', location=(-4,2,3)); fill=bpy.context.object; fill.data.energy=180; fill.data.size=4
    fill.rotation_euler=(Vector(target)-fill.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='AREA', location=(0,4,-1)); back=bpy.context.object; back.data.energy=300; back.data.size=3
    back.rotation_euler=(Vector(target)-back.location).to_track_quat('-Z','Y').to_euler()
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.render.resolution_x=1600; sc.render.resolution_y=900; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.film_transparent=False
    sc.view_settings.look='AgX - Medium High Contrast'

def ground(z=-.34):
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0,0,z)); g=bpy.context.object; g.data.materials.append(mat('ground',.09,.9))

def save_render(filename):
    bpy.context.scene.render.filepath=os.path.join(ROOT,filename); bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,filename.replace('.png','.blend'))); bpy.ops.render.render(write_still=True)

def plasmodium():
    reset(); global CLAY; CLAY=mat('neutral wet clay',.30,.58)
    pieces=[]
    # One directional body: thin overlapping volumes are fused by voxel remesh.
    lobes=[((-1.7,.15,0),(.9,1.15,.18)),((-.7,.05,.04),(1.25,1.0,.25)),((.35,.0,.10),(1.45,.88,.31)),((1.45,.05,.04),(1.10,.72,.20)),
           ((2.15,.18,.00),(1.20,.42,.12)),((1.75,-.65,-.02),(1.35,.42,.11)),((.65,-1.0,-.03),(1.35,.55,.12)),((-.75,-.9,-.04),(1.1,.65,.10))]
    for i,(p,s) in enumerate(lobes): pieces.append(uv('fan',p,s,CLAY))
    paths=[([(-2.2,.2,.10),(-1.25,.12,.18),(-.35,.05,.28),(.55,.08,.34),(1.55,.10,.20),(2.5,.2,.09)],[.45,.7,1.0,.92,.58,.24]),
           ([(-1.8,-.45,.08),(-.9,-.28,.16),(-.2,.02,.27),(.7,-.38,.22),(1.75,-.72,.09)],[.30,.55,.92,.65,.22]),
           ([(-.2,.02,.25),(.3,-.55,.19),(.65,-1.25,.07)],[.8,.55,.18]),
           ([(.55,.08,.30),(1.0,.62,.18),(2.2,.72,.06)],[.7,.45,.18]),
           ([(-1.25,.12,.16),(-.65,.65,.12),(.3,.7,.15),(.55,.08,.30)],[.5,.35,.42,.72])]
    for i,(pts,rads) in enumerate(paths):
        lifted=[(x,y,z+.10) for x,y,z in pts]
        pieces.append(curve('grown vein',lifted,rads,CLAY,.18))
    body=join_remesh(pieces,'Watertight_Plasmodium',.045,2); body.data.materials.clear(); body.data.materials.append(CLAY)
    setup((5,-7,4),(0,0,.05),6.9); ground(-.35); save_render('01_fused_plasmodial_clay.png')

def transport():
    reset(); clay=mat('membrane clay',.34,.65); complex_mat=mat('protein clay',.22,.52); cargo_mat=mat('cargo clay',.46,.68)
    # A single closed, softly curved shell supplies continuous upper/lower
    # leaflets and rounded biological ends. Its unequal inner/outer surfaces
    # make thickness vary gently without becoming two detached boards.
    membrane=irregular_blob('Continuous_Layered_Membrane',(0,0,0),(2.75,1.72,.42),clay,17)
    inner_leaf=irregular_blob('interleaflet core',(0,0,.015),(2.57,1.54,.235),None,19); boolean(membrane,inner_leaf)
    # The spanning complex is a fused, asymmetric family of lobes. The waist
    # overlaps both leaflets so the organic seal is part of the silhouette.
    parts=[uv('receptor lip left',(-.36,0,.72),(.58,.76,.44),complex_mat),
           uv('receptor lip right',(.34,.04,.73),(.54,.70,.41),complex_mat),
           uv('transmembrane waist',(0,0,.02),(.52,.58,.78),complex_mat),
           uv('release vestibule',(.12,.02,-.70),(.78,.72,.50),complex_mat),
           uv('seal shoulder',(-.43,.02,.16),(.43,.55,.36),complex_mat)]
    protein=join_remesh(parts,'Membrane_Spanning_Transport_Complex',.035,2); protein.data.materials.clear(); protein.data.materials.append(complex_mat)
    lumen_parts=[uv('outer receptor mouth',(0,-.20,.75),(.31,.25,.24),None),
                 uv('capturing cleft',(-.08,-.20,.48),(.23,.19,.30),None),
                 uv('constricted passage',(0,-.20,.03),(.115,.11,.48),None),
                 uv('release vestibule',(.10,-.20,-.56),(.34,.27,.34),None)]
    lumen=join_remesh(lumen_parts,'Constricted_Passage',.025,1); boolean(protein,lumen)
    # The membrane opens only enough for the protein waist; their overlap forms
    # a continuous seal instead of a washer-like border.
    seal_hole=uv('protein seat',(0,0,0),(.36,.40,.68),None); boolean(membrane,seal_hole)
    # One clean sectional cut reveals both leaflets, the seal and lumen.
    bpy.ops.mesh.primitive_cube_add(location=(0,-2.05,0),scale=(4,1.92,2)); boolean(membrane,bpy.context.object)
    bpy.ops.mesh.primitive_cube_add(location=(0,-2.05,0),scale=(4,1.92,2)); boolean(protein,bpy.context.object)
    stages=[((-.58,-.34,1.33),(.27,.19,.20),1),
            ((-.20,-.34,.79),(.25,.17,.19),2),
            ((-.01,-.34,.03),(.145,.11,.22),3),
            ((.22,-.34,-.93),(.32,.22,.20),4)]
    for p,s,seed in stages: irregular_blob('Vesicular cargo stage',p,s,cargo_mat,seed)
    setup((3.6,-7.5,2.7),(0,0,0),5.25); ground(-1.45); save_render('01_membrane_transport_clay.png')

def physiology():
    reset(); shellmat=mat('cortical clay',.34,.66); inner=mat('internal clay',.18,.62); light=mat('soft organelle clay',.46,.72)
    outer=irregular_blob('Thin_Variable_Cortex',(0,0,0),(2.8,1.58,1.48),shellmat,8)
    cavity=irregular_blob('cytoplasmic cavity',(0,.01,0),(2.64,1.43,1.31),None,10); boolean(outer,cavity)
    bpy.ops.mesh.primitive_cube_add(location=(0,-2.0,.05),scale=(4,1.68,2.2)); boolean(outer,bpy.context.object)
    # Distinct nuclear envelope with a visible pore and a retained dense core.
    nucleus=irregular_blob('Irregular_Nuclear_Envelope',(-.42,-.26,.16),(.76,.50,.70),inner,5)
    nuclear_cavity=irregular_blob('nuclear lumen',(-.42,-.26,.16),(.60,.37,.54),None,6); boolean(nucleus,nuclear_cavity)
    pore=irregular_blob('nuclear transport opening',(.22,-.34,.22),(.18,.20,.16),None,9); boolean(nucleus,pore)
    core=irregular_blob('Nuclear interior density',(-.48,-.29,.15),(.46,.31,.42),light,11)
    # Network, vacuoles, budding vesicles and suspension strands are voxel-fused
    # into one continuous anatomy wrapping around the nucleus.
    anatomy=[]
    routes=[([(-2.35,-.38,.05),(-1.45,-.40,.20),(-.72,-.43,.62),(.18,-.43,.68),(1.05,-.40,.35),(2.35,-.30,.10)],[.34,.55,.65,.62,.48,.25]),
            ([(-1.45,-.40,.20),(-1.05,-.42,-.48),(-.20,-.43,-.72),(.72,-.40,-.58),(1.05,-.40,.35)],[.48,.55,.62,.48,.42]),
            ([(-.20,-.43,-.72),(.12,-.40,-1.14)],[.48,.20]),
            ([(.18,-.43,.68),(.82,-.35,1.08),(1.72,-.25,.86)],[.50,.34,.18]),
            # support strands connect the central system to upper/lower cortex
            ([(-.72,-.40,.62),(-1.28,-.18,1.18)],[.30,.18]),
            ([(.72,-.40,-.58),(1.18,-.18,-1.13)],[.28,.18])]
    for pts,rads in routes: anatomy.append(curve('fused cytoplasmic network',pts,rads,inner,.105))
    vacs=[((1.22,-.38,-.22),(.45,.28,.40),2),((-1.52,-.38,-.34),(.34,.24,.31),4),((1.48,-.31,.57),(.28,.21,.26),6)]
    for p,s,k in vacs: anatomy.append(irregular_blob('branch-integrated vacuole',p,s,inner,k))
    for i,p in enumerate([(-1.78,-.48,.14),(-1.28,-.48,.31),(-.79,-.48,.56),(.54,-.48,.59),(1.18,-.45,.32)]):
        anatomy.append(irregular_blob('budding transported vesicle',p,(.12,.085,.10),inner,i+12))
    network=join_remesh(anatomy,'Connected_Suspended_Physiology',.035,2); network.data.materials.clear(); network.data.materials.append(inner)
    # Contractile fibers remain slender but curve between unmistakable cortex anchors.
    fibers=[([(-2.22,-.30,.68),(-1.25,-.48,1.05),(.45,-.48,.92),(2.22,-.26,.55)],[.32,.65,.62,.32]),
            ([(-2.16,-.30,-.72),(-1.0,-.48,-1.10),(.62,-.48,-.98),(2.18,-.26,-.58)],[.32,.62,.62,.32])]
    for pts,rads in fibers: curve('cortex anchored contractile fiber',pts,rads,light,.030)
    # Short pore-associated transport neck visibly links envelope to the network.
    curve('nuclear pore transport neck',[(.17,-.40,.24),(.38,-.42,.42),(.56,-.43,.57)],[.65,.55,.45],inner,.075)
    setup((4.7,-7.5,3.4),(0,0,.05),6.7); ground(-1.8); save_render('02_connected_physiology_clay.png')

mode=os.environ.get('S2F_MODE','all')
if mode=='revision': transport(); physiology()
else: plasmodium(); transport(); physiology()
