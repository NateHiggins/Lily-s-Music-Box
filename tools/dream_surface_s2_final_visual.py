import bpy, os, math
from mathutils import Vector

OUT=os.environ['S2_FINAL_OUT']; ASSET=os.environ['S2_FINAL_ASSET']
os.makedirs(OUT,exist_ok=True)

def node_input(bsdf,names,value):
    for n in names:
        if n in bsdf.inputs: bsdf.inputs[n].default_value=value; return

def tissue(name,color,rough=.42,sub=.18,trans=.12,absorb=None,density=.5):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; bs=nt.nodes.get('Principled BSDF')
    node_input(bs,['Base Color'],color); node_input(bs,['Roughness'],rough)
    node_input(bs,['Subsurface Weight','Subsurface'],sub); node_input(bs,['Transmission Weight','Transmission'],trans)
    node_input(bs,['Coat Weight','Clearcoat'],.16); node_input(bs,['IOR'],1.39)
    noise=nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=5.2; noise.inputs['Detail'].default_value=3.0; noise.inputs['Roughness'].default_value=.62
    bump=nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.10; bump.inputs['Distance'].default_value=.055
    nt.links.new(noise.outputs['Fac'],bump.inputs['Height']); nt.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    if absorb:
        vol=nt.nodes.new('ShaderNodeVolumeAbsorption'); vol.inputs['Color'].default_value=absorb; vol.inputs['Density'].default_value=density
        nt.links.new(vol.outputs['Volume'],nt.nodes['Material Output'].inputs['Volume'])
    return m

def assign(o,m):
    if o.type=='CURVE': o.data.materials.clear(); o.data.materials.append(m)
    elif o.type=='MESH': o.data.materials.clear(); o.data.materials.append(m)

def clean_scene():
    for o in list(bpy.context.scene.objects):
        if o.type in {'LIGHT','CAMERA'} or o.name=='Plane': bpy.data.objects.remove(o,do_unlink=True)

def lighting(camera_pos,target,back_energy=850):
    world=bpy.context.scene.world or bpy.data.worlds.new('World'); bpy.context.scene.world=world; world.color=(.006,.008,.012)
    for p,e,size,color in [((4,-5,6),720,5.0,(1.0,.78,.70)),((-4,-2,2),180,4.5,(.45,.58,.68)),((0,4,.4),back_energy,3.6,(.72,.86,1.0))]:
        bpy.ops.object.light_add(type='AREA',location=p); l=bpy.context.object; l.data.energy=e; l.data.shape='DISK'; l.data.size=size; l.data.color=color
        l.rotation_euler=(Vector(target)-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=camera_pos); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=6.3
    c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.camera=c

def render(name):
    s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.render.resolution_x=1600; s.render.resolution_y=900; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.filepath=os.path.join(OUT,name); s.view_settings.look='AgX - Medium High Contrast'; s.render.film_transparent=False
    s.render.image_settings.color_mode='RGBA'; bpy.ops.render.render(write_still=True)

def animate_cargo():
    cargos=[bpy.data.objects.get(n) for n in ['approaching cargo','captured cargo','compressed cargo','released cargo']]
    cargos=[o for o in cargos if o]; route=[o.location.copy() for o in cargos]
    for i,o in enumerate(cargos):
        base=route[i]
        prev=route[max(0,i-1)]; nxt=route[min(len(route)-1,i+1)]
        o.location=base.lerp(prev,.12); o.keyframe_insert('location',frame=1)
        o.location=base; o.keyframe_insert('location',frame=20)
        o.location=base.lerp(nxt,.12); o.keyframe_insert('location',frame=40)
        o.scale=Vector((.96,1.03,.98)); o.keyframe_insert('scale',frame=1)
        o.scale=Vector((1,1,1)); o.keyframe_insert('scale',frame=20)
        o.scale=Vector((1.04,.97,1.02)); o.keyframe_insert('scale',frame=40)
    bpy.context.scene.frame_start=1; bpy.context.scene.frame_end=40; bpy.context.scene.frame_set(20)

def export_lods(prefix,objects):
    # Bounded shipping meshes; hero sources remain untouched in their .blend.
    levels=[('lod0',.34),('lod1',.13),('lod2',.055)]
    if prefix=='transmembrane_complex': levels.append(('lod3',.012))
    for label,ratio in levels:
        copies=[]
        for src in objects:
            if src.type not in {'MESH','CURVE'}: continue
            d=src.copy(); d.data=src.data.copy(); bpy.context.collection.objects.link(d); d.animation_data_clear()
            bpy.context.view_layer.objects.active=d; d.select_set(True)
            if d.type=='CURVE': bpy.ops.object.convert(target='MESH'); d=bpy.context.object
            if len(d.data.polygons)>180:
                dec=d.modifiers.new('bounded runtime topology','DECIMATE'); dec.ratio=ratio; dec.use_collapse_triangulate=True
                bpy.context.view_layer.objects.active=d; bpy.ops.object.modifier_apply(modifier=dec.name)
            copies.append(d)
        bpy.ops.object.select_all(action='DESELECT')
        for d in copies: d.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,f'{prefix}_{label}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
        for d in copies: bpy.data.objects.remove(d,do_unlink=True)

clean_scene()
if ASSET=='moss':
    skin=tissue('wet plasmodial tissue',(.34,.095,.15,1),.34,.26,.10,(.18,.025,.04,1),.42)
    body=bpy.data.objects['Watertight_Plasmodium']; assign(body,skin)
    lighting((5,-7,4),(0,0,.04),620); bpy.context.scene.camera.data.ortho_scale=6.9
    render('01_fused_plasmodial_tissue.png'); export_lods('plasmodial_tissue',[body])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'plasmodial_tissue_final.blend'))
elif ASSET=='transport':
    membrane=tissue('layered flexible membrane',(.31,.09,.14,1),.38,.22,.16,(.16,.025,.045,1),.70)
    protein=tissue('embedded transport protein',(.17,.075,.11,1),.48,.12,.05,(.08,.02,.035,1),1.10)
    cargo=tissue('deformable cargo',(.46,.30,.20,1),.52,.14,.08,(.22,.10,.045,1),.38)
    assign(bpy.data.objects['Soft_Undulating_Membrane'],membrane); assign(bpy.data.objects['Asymmetric_Transmembrane_Complex'],protein)
    for n in ['approaching cargo','captured cargo','compressed cargo','released cargo']: assign(bpy.data.objects[n],cargo)
    animate_cargo(); lighting((4.4,-7.4,3.1),(0,0,0),720); bpy.context.scene.camera.data.ortho_scale=5.5
    render('02_membrane_transport_sequence.png')
    export_lods('transmembrane_complex',[bpy.data.objects[n] for n in ['Soft_Undulating_Membrane','Asymmetric_Transmembrane_Complex','approaching cargo','captured cargo','compressed cargo','released cargo']])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'transmembrane_complex_final.blend'))
elif ASSET=='interior':
    cortex=tissue('transmitting cortex',(.30,.085,.13,1),.44,.25,.38,(.19,.025,.05,1),.82)
    endo=tissue('endoplasmic network',(.24,.11,.15,1),.56,.16,.10,(.12,.03,.055,1),.62)
    nucleus=tissue('dense nuclear envelope',(.18,.07,.12,1),.50,.12,.06,(.055,.012,.03,1),1.65)
    nucleoplasm=tissue('nuclear interior density',(.25,.13,.16,1),.70,.08,.03,(.08,.025,.04,1),1.10)
    fiber=tissue('contractile cortex fiber',(.32,.18,.19,1),.62,.08,.02,None)
    assign(bpy.data.objects['intact soft cortex'],cortex); assign(bpy.data.objects['irregular nuclear envelope'],nucleus); assign(bpy.data.objects['nuclear interior density'],nucleoplasm); assign(bpy.data.objects['Connected_Endoplasmic_Anatomy'],endo)
    for o in bpy.context.scene.objects:
        if 'fiber' in o.name or 'anchor' in o.name: assign(o,fiber)
        elif 'suspension web' in o.name: assign(o,endo)
    lighting((4.8,-7.8,3.3),(0,0,.03),1280); bpy.context.scene.camera.data.ortho_scale=6.5
    render('03_backlit_organized_physiology.png')
    export_lods('cellular_interior',[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'cellular_interior_final.blend'))
