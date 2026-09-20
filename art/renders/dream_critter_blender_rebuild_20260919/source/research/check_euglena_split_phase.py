"""Read-only source geometry check for Euglena's independent atlas phase routing."""
import argparse,importlib.util,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=argparse.ArgumentParser(allow_abbrev=False);p.add_argument('--blend',required=True,type=Path);p.add_argument('--checker',required=True,type=Path);p.add_argument('--manifest',required=True,type=Path);p.add_argument('--out',required=True,type=Path);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
s=importlib.util.spec_from_file_location('checker',a.checker);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
source,before,c,objects,rig=m.load_source(a.blend);assert c['species_id']==10 and c['provenance']['motion_profile']=='euglena_metaboly'
manifest=m.strict_json(a.manifest.read_text());assert len(manifest['cilium_anchors'])==19 and all(len(x)==1 for x in manifest['cilium_anchors'])
poses={r['name']:r for r in c['poses']};names=['neutral']+['law_half' if i==8 else 'law_full' if i==16 else 'law_%02d'%i for i in range(1,17)]
skin=objects['Skin'];group=skin.vertex_groups['cilium_0_root'];weights=[next((g.weight for g in v.groups if g.group==group.index),0.) for v in skin.data.vertices];assert sum(weights)>0
bindings={}
for loop in skin.data.loops:
 x,y=skin.data.uv_layers['AnatomyBinding'].data[loop.index].uv;v=(int(round(x)),1-y)
 if loop.vertex_index in bindings:assert bindings[loop.vertex_index]==v
 bindings[loop.vertex_index]=v
assert all(code in [-1,-2] and 0<=weight<=1 and (code!=-1 or weight==0) for code,weight in bindings.values())
def evaluate(amount):
 i=min(15,int(amount*16));w=amount*16-i;shape={}
 for name,weight in [(names[i],1-w),(names[i+1],w)]:
  for obj,keys in poses[name].get('shape_keys',{}).items():
   for key,value in keys.items():shape.setdefault(obj,{})[key]=value*weight
 m.apply_pose(c,objects,rig,{'name':'mixed','shape_keys':shape,'bones':{}})
 deps=bpy.context.evaluated_depsgraph_get();result={n:m.evaluated_geometry(o,deps) for n,o in objects.items() if o.type=='MESH'}
 anchor=sum((p*w for p,w in zip(result['Skin']['points'],weights)),Vector())/sum(weights)
 expected=Vector(manifest['cilium_anchors'][i][0]).lerp(Vector(manifest['cilium_anchors'][i+1][0]),w);expected=Vector((expected.x,-expected.z,expected.y))
 return result,anchor,(anchor-expected).length
samples=[0.,.03125,.25,.5,.53125,.75];cache={t:evaluate(t) for t in samples};rows=[]
for body in samples:
 for flag in [0.,.25,.5,.75]:
  geometry,body_anchor,body_error=cache[body];flag_geometry,flag_anchor,flag_error=cache[flag]
  points=[(flag_geometry['Skin']['points'][i]+body_anchor-flag_anchor) if bindings[i][0]==-2 else p.copy() for i,p in enumerate(geometry['Skin']['points'])]
  mesh=bpy.data.meshes.new('SplitPhaseDiagnostic');mesh.from_pydata(points,[],geometry['Skin']['polygons']);mesh.update();obj=bpy.data.objects.new('SplitPhaseDiagnostic',mesh);bpy.context.scene.collection.objects.link(obj);bpy.context.view_layer.update()
  mixed=m.evaluated_geometry(obj,bpy.context.evaluated_depsgraph_get());lo,hi=m.bounds_of([mixed]);scale=max(hi-lo);facts=m.topology(mixed,scale);contacts=m.surface_intersections(mixed,mixed,same=True,tolerance=scale*1e-8)
  failures=[]
  if any(facts[k] for k in ['boundary_edges','nonmanifold_edges','nonmanifold_vertices','winding_conflicts','degenerate_triangles','invalid_vertex_normals']) or facts['components']!=1:failures.append('topology')
  if contacts['count_at_least']:failures.append('self_contact')
  for part in c['parts']:
   if part['container']=='Skin':
    organ=geometry[part['object']];outside=sum(not m.inside_surface(x,mixed,scale*1e-6) for x in organ['points']);cross=m.surface_intersections(organ,mixed,tolerance=scale*1e-8)
    if outside or cross['count_at_least']:failures.append('containment '+part['object'])
  if max(body_error,flag_error)>1e-6:failures.append('anchor correspondence')
  rows.append({'body_phase':body,'flag_phase':flag,'failures':failures,'anchor_deviation':max(body_error,flag_error),'self_contacts':contacts})
  bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
result={'schema':'euglena_split_phase_source_check.v1','evidence_class':'INERT','source_sha256':before,'checker_sha256':m.sha256(a.checker),'manifest_sha256':m.sha256(a.manifest),'script_sha256':m.sha256(__file__),'source_unchanged':m.sha256(source)==before,'cases':rows,'all_passed':all(not r['failures'] for r in rows),'limits':['Normalized source geometry, not native shader implementation or normal parity.','Finite independent phase grid, not continuous-domain proof.']}
m.write_report(a.out,result);print('[EUGLENA SPLIT PHASE]',len(rows),'PASS' if result['all_passed'] else 'FAIL');raise SystemExit(0 if result['all_passed'] else 1)
