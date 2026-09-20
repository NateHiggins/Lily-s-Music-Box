import bpy,importlib.util,json,sys,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(r'C:/Users/nate_/OneDrive/Documents/New Game Plus');sys.path.insert(0,str(root))
out=root/'blender_pass_work/fold_mapping_prepared'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);return mod
api=load('pilot_api',root/'critter_pilots_v11/build_dream_critter.py')
check=load('checker',Path(r'C:/ov/astra-main-acdb4be/art/blender/scripts/check_dream_critter_anatomy.py'))
import fold_crab_model as model

def cpu_slot(canonical,count,old=False):
 per=(count+1)//2;row=canonical%4;side_count=per if canonical<4 else count-per
 if side_count==3:
  if old:
   if row==3:return -1
  else:
   if row==2:return -1
   if row==3:row=2
 return (0 if canonical<4 else per)+row

def collar(p,count):
 per=(count+1)//2;side_count=per if p.x<0 else count-per
 if side_count!=3:return Vector(p)
 t=max(0.,min(1.,(abs(p.x)-.1)/.18));lateral=t*t*(3.-2.*t)
 delta=-.104*lateral*max(0.,min(1.,(p.z+.074)/.148))*max(0.,min(1.,(.282-p.z)/.148))
 return p+Vector((0.,0.,delta))

def target_chain(slot,count,selected=-1,bob=0.):
 per=(count+1)//2;flank=-1. if slot<per else 1.;row=slot if slot<per else slot-per
 side_count=per if slot<per else count-per;fore=.4-.8*row/(side_count-1)
 r=Vector((flank*.36,0,fore*.78));f=Vector((flank*1.05,-.52-bob,fore))
 knee=r.lerp(f,.48)+Vector((flank*.24,.72+.18*math.sin(slot*2.17),0))
 if slot==selected:knee+=Vector((-flank*.22,.20,.12))
 c=r+Vector((flank*.18,.08,0));a=knee.lerp(f,.7)+Vector((0,.08,0))
 return [r,c,knee,a,f]

rows=[]
for lod in (1,):
 bpy.ops.wm.read_factory_settings(use_empty=True);col=bpy.data.collections.new('FOLD_MAPPING');bpy.context.scene.collection.children.link(col)
 objects=model.build_objects(api,col,lod,24002)
 for count in (6,):
  for selected in (-1,):
   gs={};root_errors=[]
   for obj in objects:
    uv=model.vertex_bindings(obj);points=[]
    for v,(code,u) in zip(obj.data.vertices,uv):
     rest=Vector(api.gd(v.co));cpu=cpu_slot(int(code),count) if code>=0 else -1
     posed=Vector(model.deform(rest,1. if cpu==selected and selected>=0 else 0.,0.,obj.name))
     if code>=0:
      if cpu<0:p=Vector(model.JOINTS[int(code)][0]) if u>1e-4 else posed
      else:
       src=Vector(model._chain_point(model.JOINTS[int(code)],model.KNOTS,u));dst=Vector(model._chain_point(target_chain(cpu,count,selected),model.KNOTS,u))
       p=posed+dst-src
       if u<1e-6:root_errors.append((p-collar(posed,count)).length)
     elif code==-1:p=posed
     else:p=posed
     points.append(p)
    # Intentional inactive-limb collapse creates zero-area triangles. Exclude
    # only these from this geometric crossing instrument, count them explicitly.
    tris=[tuple(p.vertices) for p in obj.data.polygons]
    live=[t for t in tris if (points[t[1]]-points[t[0]]).cross(points[t[2]]-points[t[0]]).length>1e-12]
    gs[obj.name]={'points':points,'triangles':live,'bvh':BVHTree.FromPolygons(points,live,all_triangles=True),'collapsed_triangles':len(tris)-len(live)}
   problems=[]
   for name,g in gs.items():
    hit=check.surface_intersections(g,g,same=True,tolerance=3e-8)
    if hit['count_at_least']:problems.append({'object':name,'self':hit})
    if name!='Skin':
     hit=check.surface_intersections(g,gs['Skin'],tolerance=3e-8)
     outside=[i for i,p in enumerate(g['points']) if not check.inside_surface(p,gs['Skin'],3e-6)]
     if hit['count_at_least'] or outside:problems.append({'object':name,'outside':outside,'crossings':hit})
   row={'lod':lod,'count':count,'selected':selected,'max_shared_root_warp_error':max(root_errors),'collapsed_triangles':gs['Skin']['collapsed_triangles'],'problems':problems}
   rows.append(row);print('FOLD_MAPPING',json.dumps(row),flush=True)
(out/'root_only_red_probe.json').write_text(json.dumps(rows,indent=2)+'\n')
