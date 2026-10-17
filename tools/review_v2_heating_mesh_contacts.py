"""Diagnostic only: actual changed native stocks versus acquired production mesh."""
from pathlib import Path
import bpy, bmesh, hashlib, json, argparse, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--context',type=Path,required=True)
parser.add_argument('--build-dir',type=Path,required=True)
parser.add_argument('--native',type=Path,default=ROOT/'art/blender/heating_distribution.blend')
parser.add_argument('--out',type=Path,required=True)
parser.add_argument('--coverage-routes',type=Path,help='Explicit acquisition-only route superset; original installed routes must remain identical')
parser.add_argument('--allow-prior-context',action='store_true',help='Explicit historical/candidate diagnostic; never current installation proof')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
context_dir=args.context.resolve()
context=json.loads((context_dir/'context.json').read_text())
assert context['valid']
sys.path.insert(0,str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256
from v2_surface_evidence import inputs
current_runtime=runtime_inputs_sha256(ROOT);current_render=inputs(ROOT)['sha256']
context_is_current=(context['runtime_inputs_sha256']==current_runtime and context['rendering_inputs_sha256']==current_render)
assert context_is_current or args.allow_prior_context,'Acquired context is stale; reacquire or explicitly request a prior-context diagnostic'
coverage=args.coverage_routes or args.build_dir/'routes.json'
if args.coverage_routes:
    installed=json.loads((args.build_dir/'routes.json').read_text())['branches']
    acquired=json.loads(coverage.read_text())['branches']
    assert all(sum(candidate==branch for candidate in acquired)==1 for branch in installed),'Coverage must retain every installed route unchanged'
assert hashlib.sha256(coverage.read_bytes()).hexdigest()==context['route_sha256'],'Context route coverage differs from the reviewed assembly'

assert hashlib.sha256((context_dir/'context.glb').read_bytes()).hexdigest()==context['context_sha256']
reports=args.build_dir.resolve()
native_path=args.native.resolve()
pipe=json.loads((reports/'refit_pipes_native.json').read_text())
support=json.loads((reports/'refit_supported_native.json').read_text())
fittings=json.loads((reports/'native_review.json').read_text())
allowed_native={fittings['native_sha256']}
package_path=reports/'native_package.json'
if package_path.is_file():
    package=json.loads(package_path.read_text())
    assert not package['failures'] and package['geometry_sha256_before']==package['geometry_sha256_after']
    assert package['source_sha256']==fittings['native_sha256']
    allowed_native.add(package['native_sha256'])
assert hashlib.sha256(native_path.read_bytes()).hexdigest() in allowed_native,'Native file does not match the actual inspected/packaged build'
names=set(pipe['new_stocks'])
for row in support['parts']+fittings['passages']+fittings['main_supports']:
    names.update(row['parts'])
names.update(row['id'] for row in fittings['tailpieces'])
bpy.ops.wm.open_mainfile(filepath=str(native_path))
native=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name in names]
assert {o.name for o in native}==names
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(context_dir/'context.glb'))
sources={r['name']:r for r in context['draws']}
acquired=[]; excluded=[]
for obj in bpy.data.objects:
    if obj in before or obj.type!='MESH': continue
    source=sources[obj.name.split('.')[0]]
    if '/HeatingDistribution/' in source['source']:
        excluded.append(source); continue
    acquired.append((obj,source))

def row(obj,source=None):
    points=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    return dict(obj=obj,source=source,bounds=[min(v[i] for v in points) for i in range(3)]+[max(v[i] for v in points) for i in range(3)])

cache={}; face_bounds={}
def geometry(r):
    obj=r['obj']
    if obj.name not in cache:
        bm=bmesh.new(); bm.from_mesh(obj.data); bm.transform(obj.matrix_world); bm.normal_update()
        closed=all(e.is_manifold for e in bm.edges)
        bm.faces.ensure_lookup_table(); bm.faces.index_update()
        face_bounds[obj.name]=[[min(v.co[i] for v in f.verts) for i in range(3)]+[max(v.co[i] for v in f.verts) for i in range(3)] for f in bm.faces]
        cache[obj.name]=(BVHTree.FromBMesh(bm),closed,[v.co.copy() for v in bm.verts])
        bm.free()
    return cache[obj.name]

def inside(tree,p):
    # Majority parity on non-axis-aligned rays. Only evaluated for closed owners.
    votes=0
    for d in [Vector((1,.371,.193)).normalized(),Vector((.217,1,.439)).normalized(),Vector((.319,.173,1)).normalized()]:
        at=p.copy(); hits=0
        for _ in range(256):
            pos,normal,face,dist=tree.ray_cast(at,d,1000)
            if pos is None: break
            hits+=1; at=pos+d*.00001
        votes+=hits%2
    return votes>=2

world=[row(obj,source) for obj,source in acquired]
contacts=[]; containments=[]; candidates=0
for number,obj in enumerate(native):
    a=row(obj); ta,ca,va=geometry(a)
    for b in world:
        if not all(a['bounds'][i]<=b['bounds'][i+3]+1e-6 and b['bounds'][i]<=a['bounds'][i+3]+1e-6 for i in range(3)): continue
        candidates+=1; tb,cb,vb=geometry(b); hits=ta.overlap(tb)
        if hits:
            faces=[face_bounds[b['obj'].name][index] for index in {pair[1] for pair in hits}]
            contact_bounds=[min(f[i] for f in faces) for i in range(3)]+[max(f[i+3] for f in faces) for i in range(3)]
            contacts.append(dict(part=obj.name,other=b['obj'].name,source=b['source'],triangle_pairs=len(hits),bounds_native=a['bounds'],bounds_world=b['bounds'],world_contact_face_bounds=contact_bounds))
        elif cb:
            # With no intersecting triangles a connected closed stock cannot cross
            # the owner's boundary; test representative native component vertices.
            contained=[]
            for at in va[::max(1,len(va)//16)]:
                nearest=tb.find_nearest(at)
                if nearest[0] is not None and nearest[3]>.0001 and inside(tb,at): contained.append(list(at))
            if contained: containments.append(dict(part=obj.name,source=b['source'],samples=contained))
    if number%40==0: print('AUDIT',number,len(native),'contacts',len(contacts),'containments',len(containments),flush=True)
result=dict(evidence_class='INERT',scope='Exact triangle intersections and sampled containment against acquired actual post-installation production meshes. Contacts remain unclassified; no clearance, walking, surface or human acceptance claim.',context_sha256=context['context_sha256'],native_sha256=hashlib.sha256(native_path.read_bytes()).hexdigest(),changed_stocks=len(native),acquired_world_meshes=len(world),excluded_duplicate_distribution=excluded,candidate_pairs=candidates,contacts=contacts,containments=containments)
args.out.parent.mkdir(parents=True,exist_ok=True)
result.update(context_is_current=context_is_current,context_runtime_inputs_sha256=context['runtime_inputs_sha256'],current_runtime_inputs_sha256=current_runtime,context_rendering_inputs_sha256=context['rendering_inputs_sha256'],current_rendering_inputs_sha256=current_render,reviewer_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())
args.out.write_text(json.dumps(result,indent=2)+'\n')
print('RESULT',len(contacts),'contacts',len(containments),'containments',flush=True)
