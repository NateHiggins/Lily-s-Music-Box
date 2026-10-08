"""Reopen native street detail, inspect real supports and render retained context."""
import hashlib,json,math,os,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
OUT=Path(os.environ.get('STREET_REVIEW_OUT',str(ROOT/'tmp/v2-street-finish/native')));OUT.mkdir(parents=True,exist_ok=True)
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
f=read('game/tests/fixtures/orison_street_paving_details.json');review=read('game/tests/fixtures/orison_front_pavement_review.json')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/street_paving_details.blend'))
scene=bpy.context.scene;scene.view_layers[0].update()
stocks=bpy.data.collections['ClosedConstruction'].objects
for o in stocks:
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
    bm.free()
exports=list(bpy.data.collections['Exports'].objects)
assert len(exports)==len(f['parts']) and len(stocks)==f['stocks']
for o in exports:
    r=next(r for r in f['parts'] if r['id']==o.name)
    p=[o.matrix_world@v.co for v in o.data.vertices]
    bounds=[min(v.x for v in p),min(v.z for v in p),-max(v.y for v in p),max(v.x for v in p),max(v.z for v in p),-min(v.y for v in p)]
    assert max(abs(a-b) for a,b in zip(bounds,r['bounds']))<3e-6,o.name
    assert len(o.data.polygons)==r['triangles']
    if r['kind']=='damp':
        alpha=[v.color[3] for v in o.data.color_attributes['Color'].data]
        assert min(alpha)<.00001 and max(alpha)>.99
        assert bounds[5]<4.615 and bounds[1]>0
context=bpy.data.collections.new('InspectionContext');scene.collection.children.link(context)
catalog=read('game/data/runtime_material_sets.json')['materials']
concrete=material(ROOT,'ContextConcrete',f['finishes']['panel'],catalog)
asphalt=material(ROOT,'ContextAsphalt',dict(f['finishes']['panel'],catalog_key='asphalt'),catalog)
original=[]
def cube(name,p,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1]));o=bpy.context.object;o.name=name
    o.scale=(size[0],size[2],size[1]);o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    uv=o.data.uv_layers.active
    for face in o.data.polygons:
        drop=max(range(3),key=lambda a:abs(face.normal[a]));u,v=((1,2),(0,2),(0,1))[drop]
        for loop in face.loop_indices:
            at=o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(at[u],at[v])
    for c in list(o.users_collection):c.objects.unlink(o)
    context.objects.link(o);return o
source=read('game/data/orison_v2/exterior/exterior_geometry.json')
rows={r['id']:r for t in source['templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1' for r in t['boxes']}
for name in ['street_curb','passage_street_curb','street_lane']:
    r=rows[name];cube(name,r['position_m'],r['size_m'],asphalt if name=='street_lane' else concrete)
for r in f['parts']:
    row=r['source'];mat=bpy.data.materials[r['kind']]
    if r['kind']=='damp':
        mat=mat.copy();alpha=mat.node_tree.nodes['Principled BSDF'].inputs['Alpha']
        for link in list(alpha.links):mat.node_tree.links.remove(link)
        alpha.default_value=1.
    o=cube('Before_'+r['id'],row['position_m'],row['size_m'],mat);o.hide_render=True;original.append(o)
with bpy.data.libraries.load(str(ROOT/'art/blender/front_pavement.blend'),link=False) as (a,b):
    b.objects=[n for n in a.objects if n.startswith('Pavement_')]
frame=Matrix.Translation((0,-review['blockout_projection']['door']['center'][1],0))@Matrix.Rotation(math.pi,4,'Z')
verts=[];faces=[]
for o in b.objects:context.objects.link(o)
scene.view_layers[0].update()
for o in b.objects:o.matrix_world=frame@o.matrix_world
scene.view_layers[0].update()
for o in b.objects:
    o.data.materials.clear();o.data.materials.append(concrete)
    offset=len(verts);verts.extend(o.matrix_world@v.co for v in o.data.vertices);faces.extend(tuple(offset+i for i in p.vertices) for p in o.data.polygons)
bvh=BVHTree.FromPolygons(verts,faces)
maximum=0
for row in f['contacts']:
    x,y,z=row['point']
    if row['owner']=='front_pavement':
        hit,n,_,distance=bvh.ray_cast(Vector((x,-z,.05)),Vector((0,0,-1)),.10)
        assert hit is not None and abs(hit.z)<.00003 and n.z>.999,row
        maximum=max(maximum,abs(hit.z))
    else:
        source=rows[row['owner']];cx,cy,cz=source['position_m'];sx,sy,sz=source['size_m']
        assert abs(y-(cy+sy/2))<1e-7 and cx-sx/2<x<cx+sx/2 and cz-sz/2<z<cz+sz/2,row
    draw=bpy.data.objects[row['id']]
    # Actual native triangles must occupy the support sample from above.
    ps=[draw.matrix_world@v.co for v in draw.data.vertices];fs=[tuple(p.vertices) for p in draw.data.polygons]
    native=BVHTree.FromPolygons(ps,fs)
    hit,n,_,dist=native.ray_cast(Vector((x,-z,y+.06)),Vector((0,0,-1)),.08)
    assert hit is not None and n.z>.99,row
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NeutralStreetReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
data=bpy.data.lights.new('InspectionSun','SUN');data.energy=2.;data.angle=.08;sun=bpy.data.objects.new(data.name,data);scene.collection.objects.link(sun);sun.rotation_euler=(.55,-.3,-.5)
data=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new(data.name,data);scene.collection.objects.link(cam);scene.camera=cam;data.lens=27
views=[('paving',(-1,-1.3,1.65),(7,-3.5,.0)),('coping',(3.5,-3.15,1.65),(6,-4.785,.13)),('passage',(8,-18,1.65),(13,-16.3,0)),('coping_end',(20.2,-5.8,1.1),(20.8,-4.785,.13))]
if os.environ.get('STREET_RENDER','1')=='1':
    for name,at,target in views:
        cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        for before in [False,True]:
            for o in exports:o.hide_render=before
            for o in original:o.hide_render=not before
            scene.render.filepath=str(OUT/(name+('_before' if before else '')+'.png'));bpy.ops.render.render(write_still=True)
report={'evidence_class':'INERT','parts':len(exports),'closed_positive_stocks':len(stocks),'triangles':f['triangles'],'support_samples':len(f['contacts']),'maximum_front_support_error_m':maximum,'native_sha256':hashlib.sha256((ROOT/'art/blender/street_paving_details.blend').read_bytes()).hexdigest(),'asset_sha256':f['asset_sha256'],'views':[v[0] for v in views],'scope':'Native solids, metric export, actual fitted-floor BVH bearings and retained collider bounds. Neutral daylight reference; before shows original proxy geometry with catalogue reference finishes, not original lighting/material acceptance. No route proof.'}
(OUT/'street_native_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('STREET NATIVE REVIEW',json.dumps(report))
