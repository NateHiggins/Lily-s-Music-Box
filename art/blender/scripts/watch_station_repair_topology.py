"""Trial local topology repairs, rejecting every nonmanifold mutation."""
from pathlib import Path
import sys,json,ast,math
from functools import lru_cache
sys.dont_write_bytecode=True
import bpy,bmesh,numpy as np
from mathutils.bvhtree import BVHTree
R=Path('C:/PleaseRemainOnTheLine');O=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
@lru_cache(maxsize=200000)
def bad_coords(coords,tile):
 try:chart_for_triangle(np.array(coords),np.zeros(3),tile);return False
 except AssertionError:return True
_tile=.2
def bad(f):return bad_coords(tuple(tuple(v.co) for v in f.verts),_tile)
def failures(bm):return [f for f in bm.faces if bad(f)]
def patch_tree(faces):
 points=[v.co.copy() for f in faces for v in f.verts]
 return BVHTree.FromPolygons(points,[(i,i+1,i+2) for i in range(0,len(points),3)],all_triangles=True)
def patch_samples(faces):
 for f in faces:
  p=[v.co.copy() for v in f.verts]
  yield sum(p,p[0]*0)/3
  for i in range(3):yield (p[i]+p[(i+1)%3])/2
def patch_error(old,new):
 a=patch_tree(old);b=patch_tree(new);dist=[]
 for tree,faces in [(a,new),(b,old)]:
  for p in patch_samples(faces):
   hit=tree.find_nearest(p)
   if hit[0] is None:return float('inf')
   dist.append(hit[3])
 return max(dist)
def rebuild_case(ob,outer_radius=.002):
 # One hollow casting avoids the installed overlapping Boolean skin.
 # Preserve its datums, with explicit door/crank running clearances.
 tree=ast.parse((O/'baseline/build_watch_stations.py').read_text(encoding='utf-8'))
 scope={'bpy':bpy}
 exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['b','cube','cyl']],type_ignores=[]),'frozen_case_helpers','exec'),scope)
 cube=scope['cube'];base=cube((.250,.320,.120),(0,0,.047),outer_radius)
 cuts=[cube((.210,.280,.140),(0,0,.083),.001)]
 cuts += [cube((.030,.032,.040),(-.115,y,.103),.001) for y in [-.10,0,.10]]
 cuts += [cube((.040,.330,.010),(-.130,0,.1105),.0003)]
 pocket=scope['cyl'](.0685,.040,(.052,.038,.083));pocket.rotation_euler.x=math.pi/2;cuts.append(pocket)
 bpy.context.view_layer.objects.active=base
 for other in cuts:
  mod=base.modifiers.new('Cast cavity and hinge clearance','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=other;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
 mod=base.modifiers.new('Stable triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.context.view_layer.update();ob.data=base.data.copy();ob.data.transform(base.matrix_world);bpy.data.objects.remove(base,do_unlink=True)
def clean(mesh,tile=.2):
 global _tile
 _tile=tile
 bm=bmesh.new();bm.from_mesh(mesh);steps=[]
 for iteration in range(100):
  failed=failures(bm)
  if not failed:break
  original=len(failed);accepted=False;bm.edges.index_update();bm.verts.index_update()
  candidates=[]
  for f in failed:
   candidates.extend(sorted(f.edges,key=lambda e:e.calc_length(),reverse=True))
  for edge in dict.fromkeys(candidates):
   if len(edge.link_faces)!=2 or any(len(f.verts)!=3 for f in edge.link_faces):continue
   trial=bm.copy();trial.edges.ensure_lookup_table();e=trial.edges[edge.index];oldpatch=list(edge.link_faces)
   try:result=bmesh.ops.rotate_edges(trial,edges=[e],use_ccw=False)
   except Exception:trial.free();continue
   trial.normal_update();newpatch=list({f for e in result['edges'] for f in e.link_faces});error=patch_error(oldpatch,newpatch) if newpatch else float('inf')
   if error>1e-7:trial.free();continue
   count=len(failures(trial))
   if count<original and all(e.is_manifold for e in trial.edges):
    steps.append({'iteration':iteration,'operation':'edge_flip','sampled_patch_displacement_m':error,'bad_before':original,'bad_after':count});bm.free();bm=trial;accepted=True;break
   trial.free()
  if accepted:continue
  # Retire a thin triangle by seating its tip on a split of the opposite edge.
  # Unlike a global weld, this touches only the demonstrated sliver patch.
  for f in failed:
   for edge in sorted(f.edges,key=lambda e:e.calc_length(),reverse=True):
    tip=next(v for v in f.verts if v not in edge.verts);a,b=edge.verts;delta=b.co-a.co;t=(tip.co-a.co).dot(delta)/delta.length_squared
    if not 0<t<1:continue
    distance=(tip.co-(a.co+t*delta)).length
    if distance>1e-7:continue
    trial=bm.copy();trial.edges.ensure_lookup_table();trial.verts.ensure_lookup_table();e=trial.edges[edge.index];v=trial.verts[tip.index]
    _,seat=bmesh.utils.edge_split(e,e.verts[0],t);bmesh.ops.weld_verts(trial,targetmap={v:seat});trial.normal_update()
    if any(len(f.verts)!=3 for f in trial.faces):bmesh.ops.triangulate(trial,faces=[f for f in trial.faces if len(f.verts)!=3])
    count=len(failures(trial))
    if count<original and all(e.is_manifold for e in trial.edges):
     steps.append({'iteration':iteration,'operation':'sliver_tip_to_split_edge','distance_m':distance,'bad_before':original,'bad_after':count});bm.free();bm=trial;accepted=True;break
    trial.free()
   if accepted:break
  if accepted:continue
  # Collapse only an actual short edge, and accept only if all edges remain manifold.
  for edge in sorted(dict.fromkeys(candidates),key=lambda e:e.calc_length()):
   if edge.calc_length()>1e-7:continue
   for end in [0,1]:
    trial=bm.copy();trial.verts.ensure_lookup_table();a,b=[trial.verts[v.index] for v in edge.verts];source,target=(a,b) if end==0 else (b,a)
    bmesh.ops.weld_verts(trial,targetmap={source:target});trial.normal_update();count=len(failures(trial))
    if count<original and all(e.is_manifold for e in trial.edges):
     steps.append({'iteration':iteration,'operation':'short_edge_weld','distance_m':edge.calc_length(),'bad_before':original,'bad_after':count});bm.free();bm=trial;accepted=True;break
    trial.free()
   if accepted:break
  if not accepted:break
 bm.to_mesh(mesh);remaining=len(failures(bm));nonmanifold=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free();mesh.update();return {'steps':steps,'remaining':remaining,'nonmanifold':nonmanifold,'volume':volume}
if __name__=='__main__':
 bpy.ops.wm.open_mainfile(filepath=str(O/'baseline/watch_stations.blend'));bpy.context.preferences.filepaths.save_version=0;rows=[]
 for ob in bpy.context.scene.objects:
  if ob.type!='MESH':continue
  if ob.name=='StationCase':rebuild_case(ob)
  result=clean(ob.data);rows.append({'name':ob.name,**result});print(ob.name,len(result['steps']),result['remaining'],flush=True)
 (O/'topology_trial.json').write_text(json.dumps(rows,indent=2),encoding='utf-8');bpy.ops.wm.save_as_mainfile(filepath=str(O/'topology_trial.blend'))
