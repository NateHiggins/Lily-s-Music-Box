"""Fictional fold crab: one mantle with rooted jointed limbs and mouth organs.
The existing CPU socket/knee/foot state remains authoritative, including the
selected fixed-endpoint fold. Canonical four-left/four-right source slots map
to the existing6/7/8-leg state at runtime; they are not new gameplay limbs.
Cups, plates and recessed crease membranes are physical parts of the same
closed envelope. Dossier D48/D68/D15/D58/D76 informs the articulated design.
"""
import math
SPECIES_ID=2
CILIUM_BRANCH_COUNT=5
KNOTS=(0.,.18,.52,.84,1.)
JOINTS=[];MANIPULATORS=[];FOOT_ANCHORS=[]
_BIND={};_UV={};_SEM={};_CILIA_ROOTS=[];_CILIA_AXES=[]
def _key(p):return tuple(round(float(v),8) for v in p)
def _add(a,b):return tuple(x+y for x,y in zip(a,b))
def _mul(a,s):return tuple(x*s for x in a)
def _lerp(a,b,t):return tuple(x+(y-x)*t for x,y in zip(a,b))
def _weights(o,n):
 g=o.vertex_groups.get(n)
 return [next((a.weight for a in v.groups if g and a.group==g.index),0.) for v in o.data.vertices]

def _chain_point(chain,knots,u):
 segment=min(len(knots)-2,next((i for i in range(len(knots)-1) if u<=knots[i+1]),len(knots)-2))
 a,b=knots[segment:segment+2];t=(u-a)/(b-a)
 # Cubic centerline with common tangents avoids a hard-edged tube elbow.
 tangents=[]
 for i in (segment,segment+1):
  lo=max(0,i-1);hi=min(len(chain)-1,i+1)
  tangents.append(tuple((chain[hi][axis]-chain[lo][axis])/(knots[hi]-knots[lo]) for axis in range(3)))
 return tuple((2*t**3-3*t*t+1)*chain[segment][axis]+(t**3-2*t*t+t)*(b-a)*tangents[0][axis]+
              (-2*t**3+3*t*t)*chain[segment+1][axis]+(t**3-t*t)*(b-a)*tangents[1][axis] for axis in range(3))

def _root_face(cage,point,used,body_face_count,relocate=True,inset_scale=.60):
 from mathutils import Vector
 eligible=[(sum((Vector(cage.vertices[v]) for v in f),Vector())/len(f),i) for i,f in enumerate(cage.faces[:body_face_count]) if len(f)==4 and i not in used]
 _,fi=min(eligible,key=lambda pair:(pair[0]-Vector(point)).length_squared);used.add(fi)
 fi=cage.inset(fi,inset_scale);root=list(cage.faces[fi]);center=sum((Vector(cage.vertices[v]) for v in root),Vector())/len(root)
 delta=Vector(point)-center
 if relocate:
  for v in root:cage.vertices[v]=tuple(Vector(cage.vertices[v])+delta)
 return fi

def _extrude_chain(api,cage,face,chain,knots,group,lod,limb=True):
 from mathutils import Vector
 root=list(cage.faces[face]);cage.faces[face]=();cage.group(group+'_root',root);cage.group(group,root,0.)
 previous=root;side=None;orientation=1.
 samples=(32 if lod==0 else 20) if limb else 8
 for step in range(1,samples+1):
  u=step/samples;center=Vector(_chain_point(chain,knots,u))
  if limb:center.y+=.030*u**8 # center of the terminal pad above its planted sole
  tangent=(Vector(_chain_point(chain,knots,min(1.,u+.001)))-Vector(_chain_point(chain,knots,max(0.,u-.001)))).normalized()
  if side is None:
   side=Vector(cage.vertices[root[0]])-Vector(chain[0]);side=(side-tangent*side.dot(tangent)).normalized()
   if (Vector(cage.vertices[root[1]])-Vector(chain[0])).dot(tangent.cross(side))<0:orientation=-1.
  else:side=(side-tangent*side.dot(tangent)).normalized()
  other=tangent.cross(side).normalized()*orientation
  if limb:
   # Fold limbs are laminated blades. Constant flank-normal sections keep
   # adjacent mineral cups and inset crease membranes from crossing at the
   # high knee; the authored centerline and runtime joint controls stay fixed.
   plane=Vector((1.,0.,0.))
   side=Vector(cage.vertices[root[0]])-Vector(chain[0]);side.x=0.;side.normalize()
   if (Vector(cage.vertices[root[1]])-Vector(chain[0])).dot(plane.cross(side))<0:plane.negate()
   other=plane.cross(side).normalized()
  sides=8 if lod==1 or step==1 else 16
  if limb:
   cup=max(math.exp(-((u-k)/.033)**2) for k in (.18,.52,.84))
   radius=.050-.019*u+.020*cup+.014*max(0.,(u-.90)/.10)
  else:cup=0.;radius=.015-.007*u
  ring=[]
  for j in range(sides):
   angle=j*math.tau/sides
   point=center+radius*(side*math.cos(angle)+other*math.sin(angle)*(.85 if limb else 1.))
   ring.append(cage.vertex(point))
  cage.connect(previous,ring);cage.group(group,ring,u)
  if limb:cage.group('joint_cups',ring,cup)
  previous=ring
 cage.faces.append(tuple(previous))

def build_objects(api,col,lod,seed):
 from mathutils import Vector
 c=api.Cage();rings=[];n=24 if lod==0 else 16
 for z in (-.53,-.43,-.362,-.262,-.154,-.054,.054,.154,.262,.362,.43,.53):
  end=max(.09,1.-(abs(z)/.55)**4)**.45;ring=[]
  for j in range(n):
   a=math.tau*(j+.5)/n
   x=.35*end*math.cos(a)
   ventral=.30-.17*max(0.,min(1.,z/.30))
   y=(.30 if math.sin(a)>=0 else ventral)*end*math.sin(a)+.030
   if y>.18:y+=.035*(1.-abs(x)/.41)
   ring.append(c.vertex((x,y,z)))
  if rings:c.connect(rings[-1],ring)
  rings.append(ring)
 c.faces.append(tuple(reversed(rings[0])));c.faces.append(tuple(rings[-1]));used=set();body_face_count=len(c.faces)
 JOINTS.clear();FOOT_ANCHORS.clear();MANIPULATORS.clear();_CILIA_AXES.clear()
 for leg in range(8):
  flank=-1. if leg<4 else 1.;row=leg%4;fore=.4-row*.8/3
  root=(flank*.36,0.,fore*.78);foot=(flank*1.05,-.52,fore)
  knee=_add(_lerp(root,foot,.48),(flank*.24,.72+.18*math.sin(leg*2.17),0.))
  coxa=_add(root,(flank*.18,.08,0.));ankle=_add(_lerp(knee,foot,.70),(0.,.08,0.))
  chain=[root,coxa,knee,ankle,foot];JOINTS.append(chain);FOOT_ANCHORS.append(foot)
  face=_root_face(c,root,used,body_face_count);_extrude_chain(api,c,face,chain,KNOTS,'leg_%d'%leg,lod)
 for index,flank in enumerate((-1.,1.)):
  root=(flank*.13,-.10,.39);elbow=_add(root,(flank*.10,-.07,0.));tip=_add(elbow,(-flank*.04,-.03,.05))
  chain=[root,elbow,tip];MANIPULATORS.append(chain)
  face=_root_face(c,root,used,body_face_count,inset_scale=.60);_extrude_chain(api,c,face,chain,(0.,.52,1.),'manipulator_%d'%index,lod,False)
 for index in range(5):
  angle=-.95+index*.475;target=(.30*math.sin(angle),.32,.38-.06*abs(math.sin(angle)))
  face=_root_face(c,target,used,body_face_count,False)
  root=tuple(sum((Vector(c.vertices[v]) for v in c.faces[face]),Vector())/len(c.faces[face]))
  direction=Vector((math.sin(angle)*.55,1.,1.)).normalized();tip=Vector(root)+direction*.34
  _CILIA_AXES.append((tuple(direction),.34))
  c.extrude(face,[Vector(root).lerp(tip,u) for u in (.25,.5,.75,1.)],(.020,.014,.009,.003),group='cilium_%d'%index,region='feelers')
 skin=api.make_object('Skin',c,col,0,'continuous_skin');objects=[skin]
 _CILIA_ROOTS.clear()
 for i in range(5):
  vals=_weights(skin,'cilium_%d_root'%i);total=sum(vals)
  _CILIA_ROOTS.append(tuple(sum(api.gd(v.co)[a]*w for v,w in zip(skin.data.vertices,vals))/total for a in range(3)))
 for name,center,radius,offset in (
  ('FeedingChamber',(0.,.01,.21),(.13,.12,.16),1),
  ('MuscularGirdle',(0.,-.085,-.035),(.27,.070,.28),2),
  ('RearTransferReservoir',(0.,.01,-.32),(.13,.11,.12),3)):
  objects.append(api.make_object(name,api.ellipsoid_cage(center,radius,seed+offset,2 if lod==0 else 1),col,0,'internal_organ'))
 for side in (-1.,1.):
  for row in range(4):
   z=(.4-row*.8/3)*.78
   objects.append(api.make_object('Actuator_%s_%d'%('L' if side<0 else 'R',row),api.ellipsoid_cage((side*.23,.015,z),(.058,.055,.050),seed+30+row,2 if lod==0 else 1),col,0,'internal_organ'))
 for o in objects:
  legs=[_weights(o,'leg_%d'%i) for i in range(8)] if o.name=='Skin' else []
  roots=[_weights(o,'leg_%d_root'%i) for i in range(8)] if o.name=='Skin' else []
  mouths=[_weights(o,'manipulator_%d'%i) for i in range(2)] if o.name=='Skin' else []
  mouthroots=[_weights(o,'manipulator_%d_root'%i) for i in range(2)] if o.name=='Skin' else []
  cilia=[_weights(o,'cilium_%d'%i) for i in range(5)] if o.name=='Skin' else []
  cups=_weights(o,'joint_cups');bind={};uv=[];sem=[]
  for v in o.data.vertices:
   p=tuple(api.gd(v.co));code=-1;weight=0.
   if legs:
    vals=[max(t[v.index],r[v.index]*1e-6) for t,r in zip(legs,roots)];value=max(vals)
    if value>0.:code=vals.index(value);weight=legs[code][v.index]
   if code==-1 and mouths:
    vals=[max(t[v.index],r[v.index]*1e-6) for t,r in zip(mouths,mouthroots)];value=max(vals)
    if value>0.:index=vals.index(value);code=-20-index;weight=mouths[index][v.index]
   if code==-1 and cilia:
    vals=[t[v.index] for t in cilia];value=max(vals)
    if value>1e-7:
     index=vals.index(value);code=-2-index;axis,length=_CILIA_AXES[index]
     weight=max(0.,min(1.,sum((p[a]-_CILIA_ROOTS[index][a])*axis[a] for a in range(3))/length))
   bind[_key(p)]=(code,weight);uv.append((code,weight))
   if o.name=='Skin':
    crease=max(math.exp(-((weight-k)/.027)**2) for k in (.145,.485,.81)) if code>=0 else 0.
    sem.append((.10+.60*cups[v.index],crease*.46,3 if cups[v.index]>.40 else 5 if crease>.65 else 1))
   else:sem.append((.04,.03,2))
  _BIND[o.name]=bind;_UV[o.name]=uv;_SEM[o.name]=sem
 return objects

def deform(point,law,phase,object_name):
 p=tuple(float(v) for v in point);code,u=_BIND[object_name][_key(p)]
 if code>=0:
  center=_chain_point(JOINTS[code],KNOTS,u);center=(center[0],center[1]+.030*u**8,center[2])
  crease=max(math.exp(-((u-k)/.035)**2) for k in (.145,.485,.81))
  scale=1.-.18*float(law)*crease
  return tuple(center[i]+(p[i]-center[i])*scale for i in range(3))
 if -6<=code<=-2:return (p[0],p[1]+float(phase)*.015*u*u,p[2])
 if object_name=='FeedingChamber':return (p[0]*(1.+phase*.012),.01+(p[1]-.01)*(1.+phase*.012),p[2])
 return p

def vertex_semantics(obj):return list(_SEM[obj.name])
def vertex_bindings(obj):return list(_UV[obj.name])
def rig_specs():
 result=[('DEF_mantle',(0.,0.,-.42),(0.,0.,.42))]
 for leg,chain in enumerate(JOINTS):
  for section in range(4):result.append(('DEF_leg_%d_%d'%(leg,section),chain[section],chain[section+1]))
 for i,chain in enumerate(MANIPULATORS):
  for j in range(2):result.append(('DEF_manipulator_%d_%d'%(i,j),chain[j],chain[j+1]))
 return result

def metadata(species,objects):
 if species!='fold_crab':raise ValueError('Wrong fold crab species')
 return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
  'attachments':[],'required_regions':[{'object':'Skin','vertex_group':n,'min_vertices':3} for n in ['joint_cups']+['leg_%d_root'%i for i in range(8)]+['manipulator_%d_root'%i for i in range(2)]+['cilium_%d_root'%i for i in range(5)]],
  'runtime_fields':{'motion_profile':'fold_crab_joints','rest_joint_chains':[[list(p) for p in chain] for chain in JOINTS],
   'rest_manipulator_chains':[[list(p) for p in chain] for chain in MANIPULATORS],
   'foot_anchors':[[list(p) for p in FOOT_ANCHORS] for _ in range(19)]}}
