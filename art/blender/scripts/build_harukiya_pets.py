"""Original static pet study. CPU model/export only; no render or game edits.
Blender5.2 -b --python-exit-code 1 -P this.py -- OUTPUT
Private proposed PBR recipes are not registered runtime materials yet.
"""
from pathlib import Path
import bpy,bmesh,numpy as np,sys,json,math,hashlib
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert OUT != ROOT, 'Choose an explicit generation directory'
OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'judge.blend').exists() and not (OUT/'lafitte.blend').exists()
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from export_character_hair import prepare_static_hair_mesh,HairDerivativeExportExtension
from check_exported_tangents import validate
MAPS=OUT/'maps';MAPS.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0

def maps():
    rng=np.random.default_rng(19291115);size=1024
    yy,xx=np.mgrid[:size,:size].astype(float)/size
    recipes={}
    for key,tile,rough,amplitude in [('pet_fur',.08,.84,.000020),('pet_skin',.03,.57,.000006),('pet_eye',.02,.10,.00000015)]:
        noise=rng.random((size,size))-.5
        grain=np.sin(xx*math.tau*97+np.sin(yy*math.tau*5)*1.2)
        height=amplitude*(.8*grain+.2*noise)
        dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*tile/size)
        dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*tile/size)
        normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
        value=np.clip(.82+.025*grain+.025*noise,0,1)
        data={'albedo':np.repeat(value[:,:,None],3,axis=2),'roughness':np.repeat(np.clip(rough+.025*noise,0,1)[:,:,None],3,axis=2),'normal':normal*.5+.5}
        paths={}
        for role,rgb in data.items():
            image=bpy.data.images.new(key+'_'+role,width=size,height=size,alpha=True)
            image.colorspace_settings.name='sRGB' if role=='albedo' else 'Non-Color'
            rgba=np.concatenate((rgb,np.ones((size,size,1))),axis=2).astype(np.float32)
            image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(MAPS/(key+'_'+role+'.png'));image.file_format='PNG';image.save()
            paths[role]=image.filepath_raw
        recipes[key]={'tile_metres':tile,'maps':paths,'source':'original seeded analytical fibre/pores, no reference pixels','status':'PROPOSED private preview; catalogue/runtime intake pending'}
    (OUT/'PROPOSED_MATERIALS.json').write_text(json.dumps(recipes,indent=2)+'\n',encoding='utf-8')
    return recipes
RECIPES=maps()

def material(name,key,tint):
    m=bpy.data.materials.new(name);m.use_nodes=True;m['proposed_catalogue_key']=key;m['tint']=tint
    nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF')
    coord=nodes.new('ShaderNodeTexCoord');mapping=nodes.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(1/RECIPES[key]['tile_metres'],)*3
    links.new(coord.outputs['UV'],mapping.inputs['Vector'])
    tex={}
    for role,path in RECIPES[key]['maps'].items():
        n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(path,check_existing=True);n.image.colorspace_settings.name='sRGB' if role=='albedo' else 'Non-Color';links.new(mapping.outputs['Vector'],n.inputs['Vector']);tex[role]=n
    # Bake original procedural tint into its own albedo image: exporter ignores unsupported MixRGB factors.
    base=tex['albedo'].image;pixels=np.empty(len(base.pixels),dtype=np.float32);base.pixels.foreach_get(pixels);rgba=pixels.reshape((-1,4));rgba[:,:3]*=np.array(tint);tinted=bpy.data.images.new(name+'_albedo',width=base.size[0],height=base.size[1],alpha=True);tinted.colorspace_settings.name='sRGB';tinted.pixels.foreach_set(rgba.ravel());tinted.filepath_raw=str(MAPS/(name+'_albedo.png'));tinted.file_format='PNG';tinted.save();tex['albedo'].image=tinted;links.new(tex['albedo'].outputs['Color'],bs.inputs['Base Color'])
    links.new(tex['roughness'].outputs['Color'],bs.inputs['Roughness']);bs.inputs['Metallic'].default_value=0
    normal=nodes.new('ShaderNodeNormalMap');links.new(tex['normal'].outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    return m

def sphere(name,at,radius,mat,rotation=(0,0,0),segments=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=at)
    o=bpy.context.object;o.name=name;o.scale=radius;o.rotation_euler=rotation
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def tube(name,points,radius,mat):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=5;c.bevel_depth=radius;c.bevel_resolution=1;c.use_fill_caps=True
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for i,(p,co) in enumerate(zip(s.bezier_points,points)):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO';p.radius=1-.5*i/max(1,len(points)-1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(mat)
    return o

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o

def body_finish(objects,name,voxel,target,cream,stripe=None):
    o=join(objects,name);bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Original continuous anatomy','REMESH');m.mode='VOXEL';m.voxel_size=voxel;m.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Soft resting silhouette','SMOOTH');m.factor=.55;m.iterations=3;bpy.ops.object.modifier_apply(modifier=m.name)
    count=sum(len(p.vertices)-2 for p in o.data.polygons)
    if count>target:
        m=o.modifiers.new('Game silhouette allocation','DECIMATE');m.ratio=target/count;bpy.ops.object.modifier_apply(modifier=m.name)
    floor=min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:
        v.co.z-=floor
        if v.co.z<voxel*1.5:v.co.z=0
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-8);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    o.data.materials.append(cream);cream_index=len(o.data.materials)-1
    if stripe:o.data.materials.append(stripe)
    for p in o.data.polygons:
        c=p.center;p.use_smooth=True
        pale=(c.x>.245 and c.z<.20 and abs(c.y)<.10) if name.startswith('Judge') else ((c.x>.12 and c.z<.14) or(c.x>.035 and c.z<.09)or c.z<.023)
        if pale:p.material_index=cream_index
        # Orange-and-white coat: no triangle-wise fake stripes.
    return o

def metric_uv(o):
    mesh=o.data
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    for layer in list(mesh.uv_layers):mesh.uv_layers.remove(layer)
    uv=mesh.uv_layers.new(name='PhysicalMetres')
    for p in mesh.polygons:
        pts=np.array([mesh.vertices[i].co[:] for i in p.vertices]);n=np.cross(pts[1]-pts[0],pts[2]-pts[0]);length=np.linalg.norm(n);assert length>1e-12,(o.name,p.index,length);n/=length
        flow=np.array([1.,0.,0.]);v=flow-n*np.dot(flow,n)
        if np.linalg.norm(v)<.1:flow=np.array([0.,1.,0.]);v=flow-n*np.dot(flow,n)
        v/=np.linalg.norm(v);u=np.cross(v,n);q=np.column_stack((pts@u,pts@v));q-=np.floor(q.min(axis=0)/.08)*.08
        for li,co in zip(p.loop_indices,q):uv.data[li].uv=co

def cat_ear(name,at,sign,mat):
    x,y,z=at;vs=[(x-.025,y-sign*.015,z),(x+.024,y-sign*.015,z),(x+.005,y+sign*.006,z+.064),(x-.022,y+sign*.013,z),(x+.019,y+sign*.013,z)]
    fs=[(0,1,2),(1,4,2),(4,3,2),(3,0,2),(0,3,4,1)];mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o

def build(which):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
    fur=material('PetFur_'+which,'pet_fur',(.66,.43,.22) if which=='judge' else(.85,.31,.065));cream=material('PetFur_Cream','pet_fur',(.92,.86,.72));dark=material('PetFur_Shadow','pet_fur',(.29,.13,.055));skin=material('PetSkin_Dark','pet_skin',(.10,.065,.045));pink=material('PetSkin_Pink','pet_skin',(.62,.28,.24));eye=material('PetEye_Olive','pet_eye',(.26,.40,.10));pupil=material('PetEye_Dark','pet_eye',(.012,.018,.007))
    detail=[]
    if which=='judge':
        parts=[sphere('Torso',(-.055,0,.145),(.28,.155,.145),fur),sphere('Shoulders',(.115,-.015,.16),(.16,.13,.15),fur),sphere('Neck',(.18,-.025,.19),(.105,.095,.11),fur),sphere('Head',(.245,-.035,.20),(.11,.10,.105),fur),sphere('Muzzle',(.325,-.065,.16),(.09,.074,.058),fur)]
        for side in [-1,1]:
            parts.append(sphere('Resting forepaw',(.235,side*.105,.027),(.15,.055,.038),fur));parts.append(sphere('Folded hind leg',(-.22,side*.09,.06),(.12,.065,.065),fur))
            parts.append(sphere('Soft hanging ear',(.205,side*.097-.025,.17),(.075,.035,.092),fur,rotation=(side*.15,.12,0)))
            y=side*.071-.035
            detail.append(tube('Resting eyelid',[(.303,y-.018,.222),(.311,y,.218),(.303,y+.018,.222)],.0018,skin))
        parts.append(tube('Resting curled tail',[(-.24,.065,.10),(-.35,.11,.08),(-.405,.07,.035),(-.37,-.015,.028),(-.30,-.015,.04)],.025,fur))
        body=body_finish(parts,'Judge_continuous_resting_body',.0045,8500,cream)
        detail.append(sphere('Soft dark nose',(.391,-.065,.174),(.023,.028,.020),skin,segments=20,rings=10))
        detail.append(tube('Closed muzzle crease',[(.357,-.123,.145),(.383,-.066,.137),(.357,-.007,.145)],.0015,skin))
        target=(.84,.39,.32)
    else:
        parts=[sphere('Loaf torso',(-.04,0,.075),(.12,.075,.075),fur),sphere('Upright chest',(.055,0,.09),(.077,.068,.08),fur),sphere('Head',(.108,0,.135),(.068,.065,.066),fur)]
        for side in [-1,1]:parts.append(sphere('Tucked forepaw',(.093,side*.037,.018),(.055,.025,.023),fur));parts.append(cat_ear('Rooted ear',(.08,side*.045,.17),side,fur))
        parts.append(tube('Tail wrapped round loaf',[(-.12,.025,.06),(-.175,-.04,.032),(-.11,-.083,.022),(.015,-.076,.020),(.065,-.04,.026)],.013,fur))
        body=body_finish(parts,'Lafitte_continuous_loaf_body',.0025,6000,cream,dark)
        for side in [-1,1]:
            y=side*.037
            detail.append(sphere('Half open olive eye',(.164,y,.146),(.005,.017,.006),eye,segments=20,rings=10));detail.append(sphere('Narrow pupil',(.171,y,.146),(.0012,.0022,.005),pupil,segments=16,rings=8))
            detail.append(tube('Relaxed upper eyelid',[(.166,y-.021,.149),(.174,y,.154),(.166,y+.021,.149)],.0018,dark))
            for j in range(3):detail.append(tube('Cream whisker',[(.172,side*.025,.118),(.182,side*.056,.119+(j-1)*.009),(.18,side*.093,.119+(j-1)*.014)],.0005,cream))
        detail.append(sphere('Pink nose',(.177,0,.12),(.009,.010,.006),pink,segments=16,rings=8))
        detail.append(tube('Quiet mouth',[(.174,-.013,.108),(.181,0,.105),(.174,.013,.108)],.001,skin));target=(.34,.17,.22)
    objects=[body]+detail
    coords=np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objects]);lo=coords.min(0);hi=coords.max(0);factor=min(1.,*(np.array(target)/(hi-lo)))
    for o in objects:
        for v in o.data.vertices:v.co=Vector((np.array(v.co[:])-np.array([0,0,lo[2]]))*factor)
        metric_uv(o)
    # Keep editable original anatomical stocks as well as the exported static mesh.
    originals=[]
    for o in objects:
        original=o.copy();original.data=o.data.copy();original.name='SOURCE_'+o.name;bpy.context.collection.objects.link(original);original.hide_render=True;original.hide_set(True);originals.append(original)
    asset=join(objects,which.capitalize()+'_StaticFirstPass');asset['status']='Original static first pass; no rig/animation/gameplay acceptance';asset['anatomical_axes']='Native +X headward,+Y left,+Z up; glTF conversion once'
    row,fields=prepare_static_hair_mesh(asset);expected=row['triangles']
    assert expected<15000,(which,expected)
    bpy.context.scene.render.engine='BLENDER_EEVEE';bpy.context.scene.render.resolution_x=960;bpy.context.scene.render.resolution_y=720;bpy.context.scene.render.resolution_percentage=100
    bpy.context.scene.world=bpy.data.worlds.new('Neutral review world');bpy.context.scene.world.use_nodes=True;bpy.context.scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.22,.22,1);bpy.context.scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    for name,at,power,size in [('Key',(1,-2,3),220,2),('Fill',(-1,1,2),90,1.5)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;o=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,0,.12))-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=4,location=(0,0,-.0001));floor=bpy.context.object;floor.name='REVIEW_ONLY_ground';m=bpy.data.materials.new('Diagnostic neutral floor');m.diffuse_color=(.22,.22,.22,1);floor.data.materials.append(m)
    camera=bpy.data.cameras.new('ReviewCamera');ob=bpy.data.objects.new('ReviewCamera',camera);bpy.context.collection.objects.link(ob);ob.location=(1.1,-1.2,.8);ob.rotation_euler=(Vector((0,0,.12))-ob.location).to_track_quat('-Z','Y').to_euler();bpy.context.scene.camera=ob
    for image in bpy.data.images:
        if image.has_data and image.filepath:image.pack()
    bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(which+'.blend')))
    bpy.ops.object.select_all(action='DESELECT');asset.hide_set(False);asset.select_set(True);bpy.context.view_layer.objects.active=asset
    import io_scene_gltf2
    HairDerivativeExportExtension.corrected=0;io_scene_gltf2.glTF2ExportUserExtension=HairDerivativeExportExtension
    glb=OUT/(which+'.glb');bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_skins=False,export_animations=False,export_tangents=True,export_attributes=True)
    assert HairDerivativeExportExtension.corrected==expected
    result=validate(glb);assert result['triangles']==expected
    co=np.array([v.co[:] for v in asset.data.vertices]);faces=[p for p in asset.data.polygons if all(abs(asset.data.vertices[i].co.z)<1e-7 for i in p.vertices)];area=sum(p.area for p in faces)
    report={**result,'evidence_class':'INERT','scope':'Original CPU native mesh/export only; renders/runtime/catalogue/fit pending','bounds_min':co.min(0).tolist(),'bounds_max':co.max(0).tolist(),'flat_contact_area_m2':area,'authoring_scale':factor,'native':str(OUT/(which+'.blend')),'source_builder':str(Path(__file__).resolve()),'source_builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'maps':'PROPOSED_MATERIALS.json','downloaded_sources':[],'rig':None}
    (OUT/(which+'.native_report.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('PET_NATIVE',json.dumps(report))

for animal in ['judge','lafitte']:build(animal)
