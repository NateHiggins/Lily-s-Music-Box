"""Reopen the saved native candidate and probe its real bores and seats."""
from pathlib import Path
import hashlib
import json
import math
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-lighting-20261016'
path=ROOT/'art/blender/front_lighting_candidate.blend'
plan=json.loads((ROOT/'art/data/front_lighting_plan.json').read_text())
construction=json.loads((OUT/'native_inspection.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not construction['failures']
if construction['blend_sha256']!=sha(path):
    refinement=json.loads((OUT/'normal_refinement.json').read_text())
    assert not refinement['failures'] and refinement['source_blend_sha256']==construction['blend_sha256']
    assert refinement['blend_sha256']==sha(path)
    assert refinement['recipe_sha256_lf']==hashlib.sha256(Path(__file__).with_name('refine_normals.py').read_bytes().replace(b'\r\n',b'\n')).hexdigest()
assert construction['plan_sha256']==sha(ROOT/'art/data/front_lighting_plan.json')
bpy.ops.wm.open_mainfile(filepath=str(path))
bpy.context.view_layer.update()
trees={}
checks=[]

def tree(obj):
    if obj.name not in trees:
        bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(obj.matrix_world);bm.normal_update()
        trees[obj.name]=BVHTree.FromBMesh(bm);bm.free()
    return trees[obj.name]

def point(v):return Vector((v[0],-v[2],v[1]))
def check(label, good, **detail):
    checks.append(dict(check=label,passed=bool(good),**detail))

for relative,expected in construction.get('binary_source_bindings',{}).items():
    check('retained native source matches construction',sha(ROOT/relative)==expected,path=relative)
for relative,expected in construction['source_bindings_lf'].items():
    actual=hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    check('construction recipe remains unchanged',actual==expected,path=relative)
for obj in bpy.data.collections['FrontLightingCandidate'].objects:
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active
    bm=bmesh.new();bm.from_mesh(mesh)
    closed=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    bad=0
    for tri in mesh.loop_triangles:
        p=[Vector(uv.data[i].uv) for i in tri.loops]
        if tri.area>1e-12 and abs((p[1]-p[0]).cross(p[2]-p[0]))<1e-13:bad+=1
    finite=all(math.isfinite(v) for value in uv.data for v in value.uv)
    finite=finite and all(math.isfinite(value) for vertex in mesh.vertices for value in vertex.co)
    check('saved mesh is closed positive stock with finite noncollapsed UVs',closed and volume>0 and bad==0 and finite,
          id=obj.name,collapsed_uv=bad)

for fixture in plan['fixtures']:
    key='Mount_ON_brass' if fixture['kind']=='cage_bulb' else 'Body_ON_brass'
    obj=bpy.data.objects[fixture['id']+'__'+key]
    p=point(fixture['canopy_seat'])
    center_hit=tree(obj).ray_cast(p+Vector((0,0,.012)),Vector((0,0,-1)),.080)[0]
    check('canopy entry is open',center_hit is None,id=fixture['id'])
    hit,normal,_,distance=tree(obj).ray_cast(p+Vector((.020,0,.012)),Vector((0,0,-1)),.080)
    check('canopy retains annular ceiling bearing',hit is not None and abs(hit.z-p.z)<.0001
          and normal.z>.9,id=fixture['id'],distance=distance)
    if fixture['kind']=='cage_bulb':
        for depth in [.05,.15,.25]:
            at=p+Vector((.025,0,-depth))
            hit,normal,_,distance=tree(obj).ray_cast(at,Vector((-1,0,0)),.04)
            check('cage suspension retains continuous metal wall',hit is not None and abs(distance-.015)<.00015
                  and normal.x>.9,id=fixture['id'],depth=depth)
    box_point=[fixture['position'][0],fixture['ceiling_seat'][1]-.05,fixture['position'][2]]
    index=next(i for i,j in enumerate(plan['junctions']) if all(abs(j['position'][k]-box_point[k])<1e-5 for k in range(3)))
    adapter=bpy.data.objects['Junction_%03d'%index]
    width=.09 if fixture['kind']=='flush_dome' else .05
    for side in [-1,1]:
        at=p+Vector((side*width,0,-.005))
        hit,normal,_,_=tree(adapter).ray_cast(at,Vector((0,0,1)),.015)
        check('native canopy rim seats against adapter underside',hit is not None and abs(hit.z-p.z)<.0001
              and normal.z<-.9,id=fixture['id'],side=side)
        bearing=bpy.data.objects['CanopyBearing_%03d_%d'%(index,0 if side<0 else 1)]
        top=point(fixture['ceiling_seat'])+Vector((side*width+.008,0,.005))
        hit,normal,_,_=tree(bearing).ray_cast(top,Vector((0,0,-1)),.015)
        check('canopy stays bear on actual ceiling',hit is not None and abs(hit.z-top.z+.005)<.0001
              and normal.z>.9,id=fixture['id'],side=side)

for station in plan['source_junctions']:
    obj=bpy.data.objects[station['id']+'_BoredCover']
    p=point(station['cover_face'])
    hit=tree(obj).ray_cast(p+Vector((-.01,0,0)),Vector((1,0,0)),.02)[0]
    check('source-cover entry is open',hit is None,id=station['id'])
    hit,normal,_,_=tree(obj).ray_cast(p+Vector((-.01,0,.025)),Vector((1,0,0)),.02)
    check('source-cover retained face surrounds bore',hit is not None and normal.x<-.9,id=station['id'])

for i,support in enumerate(plan['supports']):
    obj=bpy.data.objects['CeilingStay_%03d'%i]
    p=point(support['seat'])
    hit,normal,_,_=tree(obj).ray_cast(p+Vector((.010,0,.005)),Vector((0,0,-1)),.012)
    check('ceiling bearing seats at actual source underside',hit is not None and abs(hit.z-p.z)<.0001
          and normal.z>.9,id=obj.name)

levels={r['id']:r['y'] for r in json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())['levels']}
for switch in plan['switches']:
    obj=bpy.data.objects[switch['id']+'_Backbox']
    p=Vector(switch['position']);p.y+=levels[switch['level']]+.087
    inward=Vector((math.sin(switch['yaw']),0,math.cos(switch['yaw'])))
    p+=inward*.012
    hit=tree(obj).ray_cast(point(p)+Vector((0,0,.020)),Vector((0,0,-1)),.05)[0]
    check('switch-box top entry is open',hit is None,id=switch['id'])
    # Backbox rear must actually bear on the original wall's inside face.
    vertices=[obj.matrix_world@v.co for v in obj.data.vertices]
    rear=max(Vector((v.x,v.z,-v.y)).dot(inward) for v in vertices)
    expected=Vector(switch['position']).dot(inward)+.032
    check('switch-box rear has authored wall bearing',abs(rear-expected)<.00005,id=switch['id'])

images=[]
for image in bpy.data.images:
    if image.source!='FILE' or image.users==0:continue
    source=Path(bpy.path.abspath(image.filepath))
    check('portable catalogue image resolves',source.is_file(),image=image.name)
    if source.is_file():images.append(dict(path=str(source.relative_to(ROOT)),sha256=sha(source)))

failures=[c for c in checks if not c['passed']]
report=dict(evidence_class='INERT',status='NATIVE_CANDIDATE_NOT_INSTALLED',blend_sha256=sha(path),
    checks=checks,failures=failures,images=images,
    inspection_recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    scope='Reopened-native bore and bearing probes. No game import, composed shell fit, gameplay, performance or human acceptance.')
(OUT/'saved_native_probes.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('SAVED FRONT LIGHTING:',len(checks),'checks;',len(failures),'failures')
if failures:raise RuntimeError(str(failures[:8]))
