"""Compose the retained nook and native loose copies, check external contact,
then render the actual source arrangement before Godot imports the batch."""
from pathlib import Path
import hashlib, json, math, os
import bpy, sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from book_flex_math import left_translation
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('NOOK_REVIEW_OUT',str(ROOT/'tmp/v2-readable-books-20261020/nook-source')))
OUT.mkdir(parents=True,exist_ok=True)
data=json.loads((ROOT/'game/data/orison_v2/nook_readable_books.json').read_text())
nook=json.loads((ROOT/'game/data/orison_v2/reading_nook.json').read_text())
base=json.loads((ROOT/'game/data/orison_v2/readable_library.json').read_text())
report=json.loads((ROOT/'art/blender/nook_readable_books_construction.json').read_text())
for name, expected in report['source_bindings'].items():
    path=ROOT/name; raw=path.read_bytes()
    actual=hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.json'] else raw).hexdigest()
    assert actual==expected,name
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/reading_nook.blend'))
scene=bpy.context.scene
fixed=[obj for obj in scene.objects if obj.type=='MESH' and not obj.hide_render]
G=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
frames={row['id']:row for row in nook['assemblies']}
def frame(row):
    return Matrix.Translation(Vector(row['position']))@Matrix.Rotation(row['yaw'],4,'Y')
def pose(record):
    axes=record['basis'];basis=Matrix(axes).transposed().to_4x4()
    basis.translation=Vector(record['position'])
    return frame(frames[record['assembly']])@basis
with bpy.data.libraries.load(str(ROOT/'art/blender/nook_readable_books.blend'),link=False) as (src,dst):
    dst.objects=list(data['parts'])
native={obj.name:obj for obj in dst.objects}
groups={}
for copy in data['copies']:
    objects=[]
    for name in data['books'][copy['id']]['parts']:
        obj=native[name];scene.collection.objects.link(obj);obj.hide_render=not data['parts'][name].get('render_surface',True)
        obj.data=obj.data.copy()
        if obj.data.shape_keys:
            step=max(0.,min(8.,copy['opening']*8/math.pi));low=int(step);high=min(8,low+1);fraction=step-low
            for index,key in enumerate(obj.data.shape_keys.key_blocks):key.value=(1-fraction if index==low else (fraction if index==high else 0.)) if index>0 else 0.
        target=pose(copy)
        if data['parts'][name]['role']=='left':
            book=data['books'][copy['id']]
            offset=Vector(left_translation(book['thickness'],copy['opening'],book['opening_style']))
            target=target@Matrix.Translation(offset)@Matrix.Rotation(-copy['opening'],4,'Y')
        obj.matrix_world=G.inverted()@target@G@obj.matrix_world
        objects.append(obj)
    groups[copy['id']]=objects
names=base['bookends']['pressed']['parts']
with bpy.data.libraries.load(str(ROOT/'art/blender/readable_library.blend'),link=False) as (src,dst):
    dst.objects=list(names)
templates=dict(zip(names,dst.objects))
for end in data['ends']:
    objects=[]
    for name in names:
        obj=templates[name].copy();obj.data=templates[name].data
        obj.name=end['id']+'_'+name;scene.collection.objects.link(obj);obj.hide_render=False
        obj.matrix_world=G.inverted()@pose(end)@G@obj.matrix_world;objects.append(obj)
    groups[end['id']]=objects
names=sorted({name for record in data['decorations'] for name in base['decorations'][record['style']]['parts']})
with bpy.data.libraries.load(str(ROOT/'art/blender/readable_library.blend'),link=False) as (src,dst):dst.objects=list(names)
templates=dict(zip(names,dst.objects))
for record in data['decorations']:
    target=frame(frames[record['assembly']])@Matrix.Translation(Vector(record['position']))@Matrix.Rotation(record['yaw'],4,'Y')
    objects=[]
    for name in base['decorations'][record['style']]['parts']:
        obj=templates[name].copy();obj.data=templates[name].data;obj.name=record['id']+'_'+name
        scene.collection.objects.link(obj);obj.hide_render=False
        obj.matrix_world=G.inverted()@target@G@obj.matrix_world;objects.append(obj)
    groups[record['id']]=objects
bpy.context.view_layer.update()
def tree(objects):
    vertices=[];faces=[]
    for obj in objects:
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in mesh.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in mesh.polygons)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices,faces,epsilon=0.)
trees={name:tree(objects) for name,objects in groups.items()}
obstructions={obj.name:tree([obj]) for obj in fixed}
overlaps=[]
for name,body in trees.items():
    for fixed_name,other in obstructions.items():
        if body.overlap(other):overlaps.append([name,fixed_name])
for index,(name,body) in enumerate(trees.items()):
    for other_name in list(trees)[index+1:]:
        if body.overlap(trees[other_name]):
            details=[]
            for left in groups[name]:
                for right in groups[other_name]:
                    if tree([left]).overlap(tree([right])):details.append([left.name,right.name])
            overlaps.append([name,other_name,details])
(OUT/'contacts.json').write_text(json.dumps({'evidence_class':'INERT','copies':len(data['copies']),
    'ends':len(data['ends']),'external_overlaps':overlaps,'source_asset_sha256':hashlib.sha256((ROOT/'game'/data['asset'].removeprefix('res://')).read_bytes()).hexdigest(),'programme_sha256':hashlib.sha256((ROOT/'game/data/orison_v2/nook_readable_books.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest()},indent=2)+'\n',newline='\n')
assert not overlaps,overlaps
if os.environ.get('NOOK_REVIEW_PROBE')=='1':
    first=data['copies'][0]
    for obj in groups[first['id']]:
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        print('NATIVE POSE PROBE',obj.name,'center=',tuple(sum((p for p in points),Vector())/len(points)))
    raise SystemExit(0)


scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Nook review daylight');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.40,.48,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
for at,target,power,size in [((-1,-.5,2.8),(-.5,-2.7,.7),170,2.),((1,-4,2),(-.5,-2.5,.6),90,1.5)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object
    light.data.energy=power;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(Vector(target)-light.location).to_track_quat('-Z','Y').to_euler()
for name,eye,target,lens in [('context',(-3.2,.7,2.1),(-.5,-2.35,.65),42),
                            ('rack',(-1.5,-1.8,1.5),(-.485,-3.34,.90),50),
                            ('pile',(.35,-.6,.95),(-.28,-1.43,.43),55),
                            ('reader',(-2.1,-1.4,1.05),(-.12,-3.02,.42),50)]:
    bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=lens
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera,do_unlink=True)
print('NOOK SOURCE REVIEW: PASS;',len(data['copies']),'copies;',len(data['ends']),'ends; zero external overlaps')
