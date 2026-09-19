import bpy, math, os
from mathutils import Vector

OUT=os.environ.get('S2G_OUT',r'C:\PleaseRemainOnTheLine-s2\art\renders\dream_surface_s2g\2026-08-28\hero_01')
os.makedirs(OUT,exist_ok=True)

def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def material(name,v,rough=.72):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(v,v*.98,v*.95,1); m.roughness=rough
    return m

CLAY=material('warm neutral clay',.31,.62)
INNER=material('deep neutral clay',.19,.68)
CARGO=material('pale neutral clay',.43,.76)

def blob(name,p,s,mat=CLAY,sub=4,phase=0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=p)
    o=bpy.context.object; o.name=name; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Low-amplitude hand-shaped irregularity, followed by relaxed subdivision.
    for v in o.data.vertices:
        n=v.co.normalized(); k=1+.026*math.sin(n.x*4.7+phase)+.019*math.sin(n.y*6.1-phase*.3)+.013*math.sin(n.z*7.2+phase)
        v.co*=k
    o.data.materials.append(mat); bpy.ops.object.shade_smooth(); return o

def path(name,coords,radii,bevel,mat=INNER,cyclic=False):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=5; c.bevel_depth=bevel; c.bevel_resolution=5
    s=c.splines.new('BEZIER'); s.bezier_points.add(len(coords)-1); s.use_cyclic_u=cyclic
    for i,(co,r) in enumerate(zip(coords,radii)):
        p=s.bezier_points[i]; p.co=co; p.radius=r; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(mat); return o

def convert(o):
    if o.type!='MESH': bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o=bpy.context.object
    return o

def fuse(objects,name,voxel=.028,relax=2,mat=CLAY):
    converted=[]
    for o in objects:
        bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=o; o.select_set(True); converted.append(convert(o))
    bpy.ops.object.select_all(action='DESELECT')
    for o in converted: o.select_set(True)
    bpy.context.view_layer.objects.active=converted[0]; bpy.ops.object.join(); out=bpy.context.object; out.name=name
    rem=out.modifiers.new('continuous biological retopology','REMESH'); rem.mode='VOXEL'; rem.voxel_size=voxel; rem.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=rem.name)
    for _ in range(relax):
        sm=out.modifiers.new('junction relaxation','SMOOTH'); sm.factor=.24; sm.iterations=2; bpy.ops.object.modifier_apply(modifier=sm.name)
    out.data.materials.clear(); out.data.materials.append(mat); bpy.ops.object.shade_smooth(); return out

def subtract(obj,cutter,name='clean sectional opening'):
    mod=obj.modifiers.new(name,'BOOLEAN'); mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)

def bevel_cut(obj,width=.035):
    b=obj.modifiers.new('hand softened cut edge','BEVEL'); b.width=width; b.segments=3; b.limit_method='ANGLE'; b.angle_limit=.5
    bpy.context.view_layer.objects.active=obj
    try: bpy.ops.object.modifier_apply(modifier=b.name)
    except: pass

def camera(p,target,scale):
    bpy.ops.object.camera_add(location=p); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=scale
    c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.camera=c; return c

def lighting(target=(0,0,0)):
    w=bpy.context.scene.world or bpy.data.worlds.new('World'); bpy.context.scene.world=w; w.color=(.012,.014,.017)
    for kind,p,e,size in [('AREA',(4,-5,6),560,5.5),('AREA',(-4,-1,3),190,4),('AREA',(1,4,1),330,3.5)]:
        bpy.ops.object.light_add(type=kind,location=p); l=bpy.context.object; l.data.energy=e; l.data.shape='DISK'; l.data.size=size
        l.rotation_euler=(Vector(target)-l.location).to_track_quat('-Z','Y').to_euler()

def render(name,cam_pos,target,scale,wire=False):
    old=[o for o in bpy.context.scene.objects if o.type=='CAMERA']
    for o in old: bpy.data.objects.remove(o,do_unlink=True)
    camera(cam_pos,target,scale); sc=bpy.context.scene; sc.render.resolution_x=1600; sc.render.resolution_y=900; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.filepath=os.path.join(OUT,name)
    if wire:
        sc.render.engine='BLENDER_EEVEE'; sc.view_settings.look='AgX - Medium High Contrast'
        wiremat=material('topology graphite',.018,.92); overlays=[]
        for o in list(sc.objects):
            if o.type!='MESH' or 'ground' in o.name.lower(): continue
            d=o.copy(); d.data=o.data.copy(); d.name=o.name+'_topology'; bpy.context.collection.objects.link(d)
            d.data.materials.clear(); d.data.materials.append(wiremat)
            wf=d.modifiers.new('retopology edges','WIREFRAME'); wf.thickness=.0035; wf.use_replace=True; wf.use_even_offset=True
            overlays.append(d)
    else:
        sc.render.engine='BLENDER_EEVEE'; sc.view_settings.look='AgX - Medium High Contrast'
        for o in sc.objects:
            if o.type=='MESH': o.show_wire=False
    bpy.ops.render.render(write_still=True)
    if wire:
        for d in overlays: bpy.data.objects.remove(d,do_unlink=True)

def ground(z):
    bpy.ops.mesh.primitive_plane_add(size=30,location=(0,0,z)); bpy.context.object.data.materials.append(material('matte ground',.08,.95))

def cargo(name,p,s,phase):
    return blob(name,p,s,CARGO,4,phase)

def build_transport():
    reset(); membrane_parts=[]
    # Continuous undulating tissue volume, broad enough that its rounded edge is
    # visible in section. Local lobes provide the pinch and thickened protein seal.
    membrane_parts += [blob('membrane field',(-1.20,.08,0),(2.05,1.55,.29),CLAY,4,2),
                       blob('membrane field',(1.30,-.06,.015),(2.10,1.48,.31),CLAY,4,5),
                       blob('membrane pinch',(-.40,.02,.02),(1.25,1.35,.34),CLAY,4,7),
                       blob('membrane pinch',(.48,-.03,-.01),(1.20,1.32,.36),CLAY,4,9)]
    membrane=fuse(membrane_parts,'Soft_Undulating_Membrane',.032,2,CLAY)
    # A clean oval inspection window removes only the near wall and leaves an
    # unbroken, rounded rear membrane to prove continuity.
    cutter=blob('section cutter',(0,-1.40,0),(2.15,1.25,.72),None,4,1); subtract(membrane,cutter); bevel_cut(membrane,.028)
    lobes=[blob('left receptor lobe',(-.34,-.28,.70),(.62,.52,.43),INNER,4,4),
           blob('right receptor lobe',(.37,-.20,.77),(.48,.46,.36),INNER,4,8),
           blob('receptor hinge',(-.05,-.14,.48),(.48,.42,.34),INNER,4,12),
           blob('sealed transmembrane waist',(0,-.08,.03),(.39,.42,.73),INNER,4,6),
           blob('cytoplasmic vestibule',(.12,-.10,-.67),(.72,.57,.48),INNER,4,10),
           blob('asymmetric release lip',(-.34,-.08,-.58),(.38,.39,.30),INNER,4,2)]
    protein=fuse(lobes,'Asymmetric_Transmembrane_Complex',.024,2,INNER)
    lumen=fuse([blob('capture mouth',(0,-.50,.78),(.29,.26,.25),None,3,1),
                blob('receptor cleft',(-.08,-.42,.52),(.21,.20,.31),None,3,3),
                blob('channel constriction',(0,-.35,.03),(.105,.12,.45),None,3,5),
                blob('release chamber',(.10,-.36,-.56),(.34,.28,.31),None,3,7)],'Transport_Lumen',.018,1,INNER)
    subtract(protein,lumen,'enclosed transport passage'); bevel_cut(protein,.018)
    # Related deformable cargo masses progressively flatten, compress and relax.
    cargo('approaching cargo',(-.55,-.62,1.38),(.28,.23,.20),1)
    cargo('captured cargo',(-.15,-.57,.78),(.27,.17,.17),2)
    cargo('compressed cargo',(0,-.49,.05),(.115,.09,.25),3)
    cargo('released cargo',(.18,-.52,-1.05),(.34,.25,.20),4)
    lighting(); ground(-1.40)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'transmembrane_complex_hero.blend'))
    render('01_transmembrane_complex_beauty.png',(4.4,-7.4,3.1),(0,0,0),5.5)
    render('01_transmembrane_complex_section.png',(3.8,-8.5,.25),(0,0,0),5.2)
    render('01_transmembrane_complex_wireframe.png',(4.4,-7.4,3.1),(0,0,0),5.5,True)

def build_interior():
    reset()
    # Thin, variable cortex made as one relaxed shell.
    outer=blob('intact soft cortex',(0,0,0),(2.85,1.62,1.48),CLAY,4,13)
    inner=blob('cortical lumen',(0,.02,0),(2.68,1.46,1.32),None,4,15); subtract(outer,inner,'thin variable cortex')
    # One smooth oval inspection window, not a fractured half-shell.
    window=blob('inspection window',(0,-1.50,.05),(1.95,1.05,1.05),None,4,3); subtract(outer,window); bevel_cut(outer,.035)
    # Double envelope with a localized pore facing the surrounding network.
    nucleus=blob('irregular nuclear envelope',(-.42,-.34,.14),(.76,.56,.70),INNER,4,4)
    nuc_inner=blob('perinuclear space',(-.42,-.34,.14),(.62,.43,.56),None,4,5); subtract(nucleus,nuc_inner)
    pore=blob('nuclear pore',(.25,-.52,.22),(.16,.18,.15),None,3,2); subtract(nucleus,pore); bevel_cut(nucleus,.018)
    core=blob('nuclear interior density',(-.45,-.39,.14),(.50,.35,.46),CARGO,4,11)
    # One fused endoplasmic web wraps both poles of the nucleus, integrates
    # vacuoles in its junctions, buds vesicles, and reaches cortical anchors.
    anatomy=[]
    curves=[([(-2.32,-.48,.06),(-1.52,-.53,.22),(-.86,-.55,.72),(-.05,-.56,.88),(.82,-.53,.62),(1.52,-.46,.24),(2.34,-.30,.08)],[.30,.48,.62,.60,.55,.42,.25],.095),
            ([(-1.52,-.53,.22),(-1.18,-.54,-.54),(-.35,-.57,-.82),(.52,-.55,-.70),(1.52,-.46,.24)],[.43,.52,.60,.53,.40],.095),
            ([(-.86,-.55,.72),(-1.42,-.37,1.15)],[.42,.18],.075),
            ([(-.35,-.57,-.82),(-.70,-.32,-1.20)],[.42,.18],.075),
            ([(.82,-.53,.62),(1.36,-.30,1.12)],[.38,.17],.068),
            ([(.52,-.55,-.70),(1.20,-.30,-1.12)],[.38,.17],.068),
            ([(.17,-.55,.38),(.35,-.56,.48),(.58,-.55,.57)],[.52,.48,.40],.072)]
    for pts,rads,b in curves: anatomy.append(path('continuous endoplasmic web',pts,rads,b,INNER))
    vacs=[((-1.58,-.51,-.35),(.36,.28,.34),2),((1.25,-.46,-.30),(.44,.31,.39),6),((1.47,-.40,.55),(.28,.22,.27),9)]
    for p,s,k in vacs: anatomy.append(blob('network nestled vacuole',p,s,INNER,4,k))
    buds=[(-1.83,-.61,.15),(-1.30,-.62,.38),(-.79,-.63,.69),(.66,-.62,.67),(1.14,-.58,.42)]
    for i,p in enumerate(buds): anatomy.append(blob('budding route vesicle',p,(.11,.085,.095),INNER,3,i+2))
    web=fuse(anatomy,'Connected_Endoplasmic_Anatomy',.026,2,INNER)
    # Curved fibers terminate within four thickened cortical anchor pads.
    fibers=[]
    for pts in [[(-2.42,-.42,.76),(-1.20,-.62,1.10),(.35,-.62,.98),(2.38,-.34,.65)],
                [(-2.35,-.42,-.76),(-1.00,-.62,-1.12),(.62,-.62,-1.02),(2.34,-.34,-.64)]]:
        fibers.append(path('tensioned cortical fiber',pts,[.28,.55,.54,.28],.028,CARGO))
        blob('cortical anchor',pts[0],(.16,.12,.16),CARGO,3,3); blob('cortical anchor',pts[-1],(.16,.12,.16),CARGO,3,7)
    # Broad suspension webs connect major junctions to the rear cortex.
    for pts in [[(-1.1,.15,.55),(-.75,-.05,.78),(-.35,-.42,.82)],[(.95,.12,.40),(.72,-.06,.65),(.35,-.48,.78)],
                [(-.9,.12,-.58),(-.52,-.08,-.75),(-.18,-.48,-.82)],[(1.0,.12,-.50),(.75,-.10,-.72),(.45,-.48,-.72)]]:
        path('cytoplasmic suspension web',pts,[.28,.55,.34],.052,INNER)
    lighting(); ground(-1.72)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'cellular_interior_hero.blend'))
    render('02_cellular_interior_beauty.png',(4.8,-7.8,3.3),(0,0,.03),6.5)
    render('02_cellular_interior_section.png',(3.7,-8.7,.35),(0,0,.02),6.2)
    render('02_cellular_interior_wireframe.png',(4.8,-7.8,3.3),(0,0,.03),6.5,True)

build_transport(); build_interior()
