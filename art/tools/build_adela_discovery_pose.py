from pathlib import Path
import json,math,hashlib
import numpy as np
import argparse
parser=argparse.ArgumentParser(description="Author and CPU-measure Adela's frozen discovery pose; never runs Godot.")
parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
parser.add_argument('--out',type=Path,required=True,help='New private report directory; refuses overwrite')
args=parser.parse_args();R=args.root.resolve();H=args.out.resolve();H.mkdir(parents=True,exist_ok=False)
F=R/'game/assets/characters/cast/adela_voss'
PARTS=['b_top','b_feet','k_head']
POSE={'hips':{'turn':0,'tilt':0},'spine':{'forward':8,'side':-5,'twist':-5},'head':{'nod':8,'turn':-10,'tilt':-40},'left':{'arm':[-15,100],'forearm':[-35,-70],'thigh':[3,15],'shin':[3,-12],'hand_turn':0,'curl':12,'foot':8},'right':{'arm':[58,70],'forearm':[-15,135],'thigh':[4,34],'shin':[4,-32],'hand_turn':0,'curl':12,'foot':8}}
def unit(x):return x/max(np.linalg.norm(x),1e-15)
def rot(axis,degrees):
 a=unit(np.array(axis,float));t=math.radians(degrees);K=np.array([[0,-a[2],a[1]],[a[2],0,-a[0]],[-a[1],a[0],0]]);return np.eye(3)+math.sin(t)*K+(1-math.cos(t))*(K@K)
def arc(a,b):
 a,b=unit(a),unit(b);cross=np.cross(a,b);length=np.linalg.norm(cross)
 if length<1e-9:return np.eye(3)
 return rot(cross,math.degrees(math.atan2(length,float(np.dot(a,b)))))
def quatmat(q):
 x,y,z,w=q;return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def matquat(m):
 # Stable branch-free extraction through the symmetric eigenproblem.
 K=np.array([[m[0,0]-m[1,1]-m[2,2],m[1,0]+m[0,1],m[2,0]+m[0,2],m[2,1]-m[1,2]],[m[1,0]+m[0,1],m[1,1]-m[0,0]-m[2,2],m[2,1]+m[1,2],m[0,2]-m[2,0]],[m[2,0]+m[0,2],m[2,1]+m[1,2],m[2,2]-m[0,0]-m[1,1],m[1,0]-m[0,1]],[m[2,1]-m[1,2],m[0,2]-m[2,0],m[1,0]-m[0,1],m.trace()]])/3
 val,vec=np.linalg.eigh(K);q=vec[:,np.argmax(val)];return q if q[3]>=0 else -q
class Model:
 def __init__(self,path):
  self.path=path;self.d=json.loads(path.read_text());self.buffers=[(path.parent/b['uri']).read_bytes() for b in self.d['buffers']];self.parents={c:i for i,n in enumerate(self.d['nodes']) for c in n.get('children',[])};self.cache={}
 def access(self,index):
  a=self.d['accessors'][index];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dt=np.dtype(dtype)
  if 'bufferView' in a:
   b=self.d['bufferViews'][a['bufferView']];offset=b.get('byteOffset',0)+a.get('byteOffset',0);x=np.ndarray((a['count'],n),dtype=dt,buffer=self.buffers[b['buffer']],offset=offset,strides=(b.get('byteStride',dt.itemsize*n),dt.itemsize)).copy()
  else:x=np.zeros((a['count'],n),dtype=dt)
  if 'sparse' in a:
   sparse=a['sparse'];ii=sparse['indices'];ib=self.d['bufferViews'][ii['bufferView']];ids=np.frombuffer(self.buffers[ib['buffer']],dtype={5121:'u1',5123:'<u2',5125:'<u4'}[ii['componentType']],count=sparse['count'],offset=ib.get('byteOffset',0)+ii.get('byteOffset',0));vv=sparse['values'];vb=self.d['bufferViews'][vv['bufferView']];vals=np.frombuffer(self.buffers[vb['buffer']],dtype=dt,count=sparse['count']*n,offset=vb.get('byteOffset',0)+vv.get('byteOffset',0)).reshape(-1,n);x[ids]=vals
  if a.get('normalized'):x=x/np.iinfo(dt).max
  return x

 def rest(self,i):
  if i in self.cache:return self.cache[i]
  n=self.d['nodes'][i];m=np.eye(4);m[:3,:3]=quatmat(n.get('rotation',[0,0,0,1]))@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);self.cache[i]=(self.rest(self.parents[i])@m) if i in self.parents else m;return self.cache[i]
base=Model(F/'adela_voss.gltf');joint_ids=base.d['skins'][0]['joints'];byname={base.d['nodes'][i]['name']:i for i in joint_ids};globals={};deltas={};locals_out=[]
for i in joint_ids:
 n=base.d['nodes'][i];name=n['name'];parent=base.parents.get(i);parent=parent if parent in globals else None;before=deltas[parent] if parent is not None else np.eye(3);delta=before.copy();side='Left' if name.startswith('Left') else 'Right' if name.startswith('Right') else '';part=name[len(side):];sign=1 if side=='Left' else -1;limb=POSE.get(side.lower(),{})
 if name=='Hips':delta=rot([0,1,0],POSE['hips']['turn'])@rot([0,0,1],POSE['hips']['tilt'])
 elif name.startswith('Spine'):delta=before@rot([0,0,1],POSE['spine']['side']/3)@rot([1,0,0],POSE['spine']['forward']/3)@rot([0,1,0],POSE['spine']['twist']/3)
 elif name in ['Neck','Head']:delta=before@rot([0,1,0],POSE['head']['turn']/2)@rot([1,0,0],POSE['head']['nod']/2)@rot([0,0,1],POSE['head']['tilt']/2)
 elif part in ['Arm','ForeArm','UpLeg','Leg']:
  a,b=limb[{'Arm':'arm','ForeArm':'forearm','UpLeg':'thigh','Leg':'shin'}[part]]
  if part in ['Arm','ForeArm']:a,b=math.radians(a),math.radians(b);want=np.array([sign*math.cos(a)*math.cos(b),-math.sin(a),math.cos(a)*math.sin(b)])
  else:want=rot([1,0,0],-b)@np.array([sign*math.sin(math.radians(a)),-math.cos(math.radians(a)),0])
  children=[c for c in n.get('children',[]) if base.d['nodes'][c]['name'].startswith(side) and 'Skirt' not in base.d['nodes'][c]['name']]
  if children:delta=arc(before@(base.rest(children[0])[:3,3]-base.rest(i)[:3,3]),want)@before
 elif side and part.startswith('Hand') and part!='Hand':
  hand=byname[side+'Hand'];across=unit(deltas[hand]@(base.rest(byname[side+'HandIndex1'])[:3,3]-base.rest(byname[side+'HandPinky1'])[:3,3]));delta=rot(across,limb['curl']*(.4 if 'Thumb' in part else 1)*sign*-1)@before
 rest=base.rest(i);rest_basis=rest[:3,:3];u,_,vh=np.linalg.svd(rest_basis);rest_basis=u@vh;gb=delta@rest_basis;origin=np.array(n.get('translation',[0,0,0]),float);gp=globals[parent][:3,3]+globals[parent][:3,:3]@origin if parent is not None else origin
 m=np.eye(4);m[:3,:3]=gb;m[:3,3]=gp;globals[i]=m;deltas[i]=delta;local_basis=globals[parent][:3,:3].T@gb if parent is not None else gb
 locals_out.append({'name':name,'position':origin.tolist(),'rotation':matquat(local_basis).tolist(),'rest_global':rest[:3,3].tolist()})
pose_by_name={base.d['nodes'][i]['name']:globals[i] for i in joint_ids};root_basis=rot([0,0,1],-90)
covered=set()
for part in PARTS:covered.update(json.loads((F/('adela_voss__'+part+'.json')).read_text())['covers'])
clouds={};bone_weights={};sources=[]
for part in [None]+PARTS:
 model=base if part is None else Model(F/('adela_voss__'+part+'.gltf'));sources.extend([model.path]+[model.path.parent/b['uri'] for b in model.d['buffers']]);skin=model.d['skins'][0];inv=model.access(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);mats=np.array([pose_by_name[model.d['nodes'][j]['name']]@inv[k] for k,j in enumerate(skin['joints'])])
 for node in model.d['nodes']:
  if 'mesh' not in node or 'skin' not in node:continue
  name=node['name']
  if part is None and ((name.startswith('Skin_') and name[5:] in covered) or name in ['Hair']):continue
  arr=[]
  for primitive in model.d['meshes'][node['mesh']]['primitives']:
   attrs=primitive['attributes'];pos=model.access(attrs['POSITION']).astype(float);mesh=model.d['meshes'][node['mesh']];target_names=mesh.get('extras',{}).get('targetNames',[])
   for tn,tar in zip(target_names,primitive.get('targets',[])):
    if tn in ['eyeBlinkLeft','eyeBlinkRight'] and 'POSITION' in tar:pos+=model.access(tar['POSITION'])
   joints=model.access(attrs['JOINTS_0']).astype(int);w=model.access(attrs['WEIGHTS_0']).astype(float);hp=np.c_[pos,np.ones(len(pos))];out=np.zeros((len(pos),3))
   for k in range(w.shape[1]):out+=np.einsum('nij,nj->ni',mats[joints[:,k]],hp)[:,:3]*w[:,k,None]
   arr.append(out@root_basis.T)
  clouds[(part or 'base')+':'+name]=np.concatenate(arr)
allpoints=np.concatenate(list(clouds.values()));height=-float(allpoints[:,1].min())+.002
for name in clouds:clouds[name][:,1]+=height
allpoints[:,1]+=height
head=(root_basis@pose_by_name['Head'][:3,3])+[0,height,0]
# Anchor is the projected Head pivot. Body extends west; full cloud is reported
# rather than presume that the forensic fall line already defines a footprint.
anchor_shift=np.array([-head[0],0,-head[2]])
for name in clouds:clouds[name]+=anchor_shift
allpoints+=anchor_shift
measure={'evidence_class':'INERT','method':'actual glTF skin weights/inversebind matrices + authored articulated bone directions, frozen side-rest; CPU, not native/render qualification','wardrobe':PARTS,'height_above_floor':height,'head_anchor_shift':anchor_shift.tolist(),'whole_bounds_relative_head_floor':[allpoints.min(axis=0).tolist(),allpoints.max(axis=0).tolist()],'parts':{name:{'vertices':len(p),'bounds':[p.min(axis=0).tolist(),p.max(axis=0).tolist()],'min_floor_gap_m':float(p[:,1].min())} for name,p in clouds.items()},'authored_directions':POSE,'posed_bone_world_relative_head':{name:(root_basis@m[:3,3]+[0,height,0]+anchor_shift).tolist() for name,m in pose_by_name.items()},'sources':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.gltf','.json'] else p.read_bytes()).hexdigest() for p in sources}}
recipe={'schema_version':1,'person':'adela_voss','model':'res://assets/characters/cast/adela_voss/adela_voss.gltf','parts':PARTS,'basis_rotation_z_degrees':-90,'local_offset':[float(anchor_shift[0]),height,float(anchor_shift[2])],'head_anchor':[-8.15,0,11.92],'bones':locals_out,'cpu_bounds':measure['whole_bounds_relative_head_floor'],'mesh_counts':{(key.split(':',1)[1] if key.startswith('base:') else key.replace(':','_',1)):len(points) for key,points in clouds.items()}}
(H/'adela_discovery_pose.json').write_text(json.dumps(recipe,indent=2)+'\n',encoding='utf8',newline='\n');(H/'CPU_MEASURE.json').write_text(json.dumps(measure,indent=2)+'\n',encoding='utf8',newline='\n');np.savez_compressed(H/'posed_skin.npz',**{k.replace(':','__'):v for k,v in clouds.items()})
print(json.dumps({'bounds':measure['whole_bounds_relative_head_floor'],'offset':recipe['local_offset'],'minimum':float(allpoints[:,1].min()),'vertices':len(allpoints)},indent=2))
