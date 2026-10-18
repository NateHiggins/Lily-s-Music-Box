from pathlib import Path
import json,math,runpy
from mathutils import Matrix,Vector,Quaternion
from mathutils.bvhtree import BVHTree
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-control-finish-20261017'
read=runpy.run_path(str(T/'compare_geometry.py'))['read']
def stock(path,angle):
 d,get=read(path);out={}
 def walk(i,parent):
  n=d['nodes'][i]
  q=n.get('rotation',[0,0,0,1]);rot=Quaternion((q[3],q[0],q[1],q[2])).to_matrix().to_4x4()
  matrix=Matrix.Translation(Vector(n.get('translation',[0,0,0])))@rot@Matrix.Diagonal(Vector(n.get('scale',[1,1,1])+[1]))
  if n.get('name')=='TogglePivot':matrix=matrix@Matrix.Rotation(math.radians(angle),4,'X')
  matrix=parent@matrix
  if 'mesh' in n:
   vs=[];fs=[]
   for p in d['meshes'][n['mesh']]['primitives']:
    offset=len(vs);vs.extend(matrix@Vector(v) for v in get(p['attributes']['POSITION']))
    ids=get(p['indices']).reshape(-1);fs.extend(tuple(offset+int(v) for v in ids[j:j+3]) for j in range(0,len(ids),3))
   out[n['name']]=(vs,fs)
  for child in n.get('children',[]):walk(child,matrix)
 for i in d['scenes'][d.get('scene',0)]['nodes']:walk(i,Matrix.Identity(4))
 return out
rows=[]
for angle in [-22,0,22]:
 a=stock(T/'switch_before.glb',angle);b=stock(R/'game/assets/props/light_switch.glb',angle);assert a.keys()==b.keys()
 for name in a:
  worst=0.;samples=0
  for one,two in [(a[name],b[name]),(b[name],a[name])]:
   vs,fs=one;tree=BVHTree.FromPolygons(*two,all_triangles=True)
   for f in fs:
    points=[vs[i] for i in f]
    for point in points+[(points[0]+points[1]+points[2])/3]+[(points[i]+points[(i+1)%3])/2 for i in range(3)]:
     distance=tree.find_nearest(point)[3];assert distance is not None;worst=max(worst,distance);samples+=1
  assert worst<.00005,(angle,name,worst)
  rows.append(dict(angle_degrees=angle,part=name,bidirectional_surface_samples=samples,maximum_surface_distance_m=worst))
(T/'switch_geometry_comparison.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Exported physical surfaces at rest and both travel limits; not runtime input acceptance.',rows=rows),indent=2)+'\n')
print('SWITCH GEOMETRY',len(rows),'posed surfaces',max(r['maximum_surface_distance_m'] for r in rows),flush=True)
