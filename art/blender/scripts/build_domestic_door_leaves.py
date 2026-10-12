"""Source-sized painted joinery: separate rails/stiles and solid raised panels."""
from pathlib import Path
import ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from check_exported_tangents import validate
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
sizes=sorted({(float(d['width']),float(d['height'])) for d in layout['doors']}|{(.81,2.03)})
source=Path(__file__).with_name('build_door_keyway.py')
tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['cube','subtract']],type_ignores=[]),str(source),'exec'))
records=[];native=[]

def mortise_cutter(x):
    # One extruded outline avoids microscopic seams where two Boolean
    # cutters would overlap at the round/stem junction.
    angle=math.acos(.0025/.004)
    outline=[(-.0025,-.0065),(.0025,-.0065)]
    outline += [(.004*math.cos(a),.008+.004*math.sin(a))
                for a in np.linspace(-angle,math.pi+angle,49)]
    count=len(outline)
    points=[(x+px,depth,.884+y) for depth in [-.040,.040] for px,y in outline]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new('ContinuousKeywayCutter');mesh.from_pydata(points,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new('ContinuousKeywayCutter',mesh);bpy.context.scene.collection.objects.link(obj)
    return obj

def panel(x0,x1,y0,y1):
    # A continuous cast of the timber profile, with real sloping shoulders.
    vertices=[];faces=[]
    profile=[(-.003,.007),(.006,.007),(.014,.011),(.027,.018)]
    for side in [-1,1]:
        for inset,depth in profile:
            vertices.extend([(x0+inset,-side*depth,y0+inset),
                (x1-inset,-side*depth,y0+inset),(x1-inset,-side*depth,y1-inset),
                (x0+inset,-side*depth,y1-inset)])
    for base in [0,16]:
        for layer in range(3):
            for i in range(4):
                a=base+layer*4+i;b=base+layer*4+(i+1)%4
                faces.append((a,b,b+4,a+4))
        faces.append(tuple(base+12+i for i in range(4)))
    for i in range(4):faces.append((i,(i+1)%4,16+(i+1)%4,16+i))
    mesh=bpy.data.meshes.new('RaisedPanel');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('RaisedPanel',mesh);bpy.context.scene.collection.objects.link(obj)
    return obj

for width,height in sizes:
    name='Leaf%04dx%04d'%(round(width*1000),round(height*1000))
    objects=[]
    for x0,x1 in [(.01,.16),(width-.16,width-.01)]:
        obj=cube((x1-x0,.044,height-.02),((x0+x1)/2,0,height/2))
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if x0>.2:
            subtract(obj,mortise_cutter(width-.085))
        objects.append((obj,False))
    for y0,y1 in [(.01,.16),(.86,.96),(height-.16,height-.01)]:
        obj=cube((width-.32,.044,y1-y0),(width/2,0,(y0+y1)/2))
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        objects.append((obj,True))
    objects.extend((panel(.16,width-.16,a,b),False) for a,b in [(.16,.86),(.96,height-.16)])
    vertices=[];faces=[];charts=[]
    for obj,horizontal in objects:
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges),name
        edges=[e for e in bm.edges if e.calc_face_angle(0)>math.radians(35)]
        bmesh.ops.bevel(bm,geom=edges,offset=.00065,segments=3,affect='EDGES')
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
        native.append({'family':name,'volume_m3':bm.calc_volume(signed=True),'closed':True})
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        for face in bm.faces:
            p=np.array([v.co[:] for v in face.verts])
            if np.linalg.norm(np.cross(p[1]-p[0],p[2]-p[0]))==0:continue
            order=[2,1,0] if horizontal else [0,1,2]
            _,_,uv,_=chart_for_triangle(p[:,order],np.zeros(3),.30)
            start=len(vertices);vertices.extend(p.tolist());faces.append((start,start+1,start+2));charts.extend(uv)
        bm.free();bpy.data.objects.remove(obj,do_unlink=True)
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='MetreJoinery')
    for loop,value in zip(uv.data,charts):loop.uv=value
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    for y in [.892,.884]:
        hit,*_=obj.ray_cast(Vector((width-.085,-.1,y)),Vector((0,1,0)))
        assert not hit,(name,y)
    records.append({'name':name,'width':width,'height':height,'triangles':len(faces)})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/domestic_door_leaves.blend'),compress=True)
source=Path(__file__).with_name('build_media_battery_supply.py')
tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),str(source),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportDerivatives
asset=ROOT/'game/assets/props/domestic_door_leaves.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_tangents=True,export_materials='NONE',export_lights=False,export_cameras=False)
result=validate(asset)
data={'schema_version':1,'families':records,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
(ROOT/'game/tests/fixtures/orison_domestic_door_leaves.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
out=ROOT/'tmp/v2-door-polish-20261012/domestic-construction.json'
out.write_text(json.dumps({'evidence_class':'INERT','native':native,'export':result,'families':records},indent=2)+'\n',encoding='utf-8',newline='\n')
print('NATIVE DOMESTIC DOORS:',len(records),'families;',result)
