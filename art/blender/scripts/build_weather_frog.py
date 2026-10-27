"""Small original leopard-frog fallout stock; no rigid bodies or baked photos.

blender --background --python-exit-code 1 --python art/blender/scripts/build_weather_frog.py
Reuses the repository's metric UV/tangent exporter and registered PBR pipeline.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import sys
import zlib

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path[:0] = [str(ROOT/'art/blender/scripts'), str(ROOT/'art/tools')]
from fabrication_native_batch import material, partition, export
from material_relief import normals

KEY = 'weather_frog_skin'
TILE = .12
SIZE = 128
OUT = ROOT/'tmp/weather-frog-review'
OUT.mkdir(parents=True, exist_ok=True)


def png(path, values, bits=8):
    values = np.asarray(values)
    height, width = values.shape[:2]
    channels = 1 if values.ndim == 2 else values.shape[2]
    colour = 0 if channels == 1 else 2
    raw = values.astype('>u2' if bits == 16 else np.uint8).tobytes()
    stride = width*channels*(bits//8)
    def chunk(name, payload):
        return struct.pack('>I', len(payload))+name+payload+struct.pack('>I', zlib.crc32(name+payload)&0xffffffff)
    data = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, bits, colour, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(b''.join(b'\0'+raw[y*stride:(y+1)*stride] for y in range(height)), 9))+chunk(b'IEND', b'')
    path.write_bytes(data)


def register_skin():
    folder = ROOT/'art/textures/procedural'/KEY
    folder.mkdir(parents=True, exist_ok=True)
    y, x = np.mgrid[:SIZE, :SIZE]/SIZE
    rng = np.random.default_rng(19280912)
    spots = np.zeros((SIZE, SIZE))
    for _ in range(11):
        cx, cy = rng.random(2)
        dx = (x-cx+.5)%1-.5;dy = (y-cy+.5)%1-.5
        radius = rng.uniform(.055,.10)
        spots = np.maximum(spots, np.exp(-(dx*dx+dy*dy*1.35)/radius**2))
    pigment = np.clip((spots-.30)/.35,0,1)
    halo = np.clip((spots-.16)/.12,0,1)*(1-pigment)
    base = np.array([.25,.37,.085])[None,None,:]*np.ones((SIZE,SIZE,3))
    albedo = base*(1-pigment[...,None])+np.array([.035,.065,.017])*pigment[...,None]
    albedo = albedo*(1-halo[...,None]*.45)+np.array([.52,.55,.22])*halo[...,None]*.45
    # Pigment does not become relief. Millimetre-scale skin undulation owns the normal.
    h = .000025*(np.sin(x*math.tau*13)*np.cos(y*math.tau*11)+.35*np.cos((x+y)*math.tau*7))
    normal = normals(h,TILE)
    rough = .43+.10*(.5+.5*np.sin(x*math.tau*9)*np.cos(y*math.tau*7))
    png(folder/'albedo.png',np.clip(albedo*255,0,255))
    png(folder/'roughness.png',rough*255)
    png(folder/'normal.png',(normal*.5+.5)*255)
    png(folder/'height.png',(h-h.min())/(h.max()-h.min())*65535,16)
    metadata = {'material':KEY,'status':'QUALIFICATION_PENDING','meters_per_tile':TILE,
        'generator':'art/blender/scripts/build_weather_frog.py',
        'generator_sha256_lf':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        'maps':{'albedo':'albedo.png','roughness':'roughness.png','normal':'normal.png','height':'height.png'},
        'height_storage_bits':16,'normal_convention':'OpenGL','normal_strength':1.0,
        'normal_authoring':{'construction':'smooth periodic skin undulation, independent of oval pigmentation; unresolved pores belong to roughness','height_units':'metres',
            'normal_convention':'OpenGL','normal_strength':1.0,'physical_tile_m':TILE,
            'height_min_m':float(h.min()),'height_max_m':float(h.max()),'pigment_is_not_height':True},
        'references':['https://www.fws.gov/species/northern-leopard-frog-lithobates-pipiens',
                      'https://dec.ny.gov/sites/default/files/2024-01/amphguide.pdf'],
        'reference_policy':'Form information only. No reference image was baked, projected or stored.'}
    metadata['map_sha256']={k:hashlib.sha256((folder/v).read_bytes()).hexdigest() for k,v in metadata['maps'].items()}
    (folder/'material.json').write_bytes((json.dumps(metadata,indent=2)+'\n').encode())
    target = ROOT/'game/assets/building/textures'
    for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
        (target/f'T_ai_materials_{KEY}_{suffix}.png').write_bytes((folder/f'{source}.png').read_bytes())
    for relative,value in [('art/data/material_catalog.json',{'base_color':[1.,1.,1.,1.],'roughness':1.,'metallic':0.}),
                           ('art/textures/catalog_mapping.json','procedural/'+KEY)]:
        path=ROOT/relative;data=json.loads(path.read_text(encoding='utf-8'))
        if KEY not in data:
            text=path.read_text(encoding='utf-8').rstrip()
            text=text[:-1].rstrip()+',\n  '+json.dumps(KEY)+': '+json.dumps(value)+'\n}\n'
            path.write_bytes(text.encode())
        else:assert data[KEY]==value
    source=ROOT/'art/data/gen_layout.py';text=source.read_text(encoding='utf-8')
    if '"'+KEY+'"' not in text:
        text=text.replace('MATERIAL_CATALOG = {','MATERIAL_CATALOG = {\n    "'+KEY+'": {"base_color": [1.0,1.0,1.0,1.0], "roughness": 1.0, "metallic": 0.0},',1)
        source.write_bytes(text.encode())
    source=ROOT/'art/tools/generate_runtime_materials.py';text=source.read_text(encoding='utf-8')
    if '"'+KEY+'"' not in text:
        text=text.replace('RUNTIME_POLICY = {','RUNTIME_POLICY = {\n    "'+KEY+'": {"normal_scale": 1.0},',1)
        source.write_bytes(text.encode())
    import generate_runtime_materials
    generate_runtime_materials.generate()


def ellipsoid(name, at, scale, parts):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,location=at)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    parts.append(obj)
    return obj


def build():
    register_skin()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts=[]
    ellipsoid('Body',(0,.014,.031),(.036,.055,.024),parts)
    ellipsoid('Head',(0,-.039,.042),(.039,.032,.019),parts)
    for side in [-1,1]:
        ellipsoid('Haunch',(side*.041,.042,.023),(.022,.028,.018),parts)
        ellipsoid('Shin',(side*.061,.060,.012),(.012,.033,.010),parts)
        ellipsoid('RearWeb',(side*.062,.091,.007),(.019,.024,.006),parts)
        ellipsoid('Forearm',(side*.042,-.031,.018),(.011,.029,.012),parts)
        ellipsoid('FrontWeb',(side*.049,-.059,.006),(.014,.018,.005),parts)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    body=parts[0]
    body.data.remesh_voxel_size=.004
    bpy.ops.object.voxel_remesh()
    body.data.calc_loop_triangles()
    dec=body.modifiers.new('BoundedFalloutStock','DECIMATE');dec.ratio=min(1.,360/max(1,len(body.data.loop_triangles)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    stock=bpy.data.collections.new('WeatherFrog');bpy.context.scene.collection.children.link(stock)
    catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
    finish={'catalog_key':KEY,'normal':1.,'roughness':1.,'pigment':1.,'tint':[1,1,1,1]}
    skin=material(ROOT,KEY,finish,catalog)
    eye=skin.copy();eye.name=KEY+'_eye'
    node=eye.node_tree.nodes['Principled BSDF']
    node.inputs['Base Color'].links[0].from_node.inputs[2].default_value=(.025,.030,.018,1.)
    node.inputs['Roughness'].links[0].from_node.inputs[1].default_value=.22
    exports=[partition(stock,'WeatherFrogBody',[body],finish,skin,Matrix.Identity(4),catalog)]
    bpy.data.objects.remove(body,do_unlink=True)
    for side in [-1,1]:
        parts=[];obj=ellipsoid('Eye',(side*.025,-.046,.058),(.009,.010,.009),parts)
        exports.append(partition(stock,'WeatherFrogEye'+str(side),parts,finish,eye,Matrix.Identity(4),catalog))
        bpy.data.objects.remove(obj,do_unlink=True)
    proof=export(ROOT,'weather_frog',stock)
    proof.update(evidence_class='INERT',scope='Blender source, metric UV and tangent validation; not Godot/runtime acceptance')
    (ROOT/'art/blender/weather_frog_construction.json').write_bytes((json.dumps(proof,indent=2)+'\n').encode())
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('ReviewAir');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.23,1)
    bpy.ops.object.light_add(type='AREA',location=(.2,-.2,.3));bpy.context.object.data.energy=3;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=.25
    bpy.ops.object.camera_add(location=(.23,-.29,.18));camera=bpy.context.object;scene.camera=camera;camera.data.lens=48
    for name,at in [('three_quarter',(.23,-.29,.18)),('top',(.01,-.01,.40)),('side',(.29,-.03,.12))]:
        camera.location=at;camera.rotation_euler=(Vector((0,.015,.03))-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    print('WEATHER FROG:',json.dumps(proof))


if __name__=='__main__':build()
