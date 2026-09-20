"""Fictional seam grazer: continuous low mantle and rooted ventral comb.
Mapped dossier D6/D16/D33 informs proportions and layered organization, not
literal flatworm organs or copied colour bands. Twin appearance remains the
existing controller's one-identity thin-wall behavior; this builds one animal.
"""
import math
SPECIES_ID=0
CILIUM_BRANCH_COUNT=8
_BIND={};_UV={};_SEM={};_ROOTS=[];_AXES=[]
def _key(p):return tuple(round(float(v),8) for v in p)
def _weights(o,n):
 g=o.vertex_groups.get(n)
 return [next((a.weight for a in v.groups if g and a.group==g.index),0.) for v in o.data.vertices]

def build_objects(api,col,lod,seed):
 from mathutils import Vector
 c=api.Cage();rings=[];n=16
 for row in range(17):
  z=-.55+row*1.10/16;section=max(.06,1.-(abs(z)/.558)**2)**.55;ring=[]
  for j in range(n):
   a=math.tau*j/n;side=math.cos(a)
   edge=.012*math.sin(z*17.+.7)*(abs(side)**8)
   ring.append(c.vertex((.53*section*side,.28*section*math.sin(a)+edge,z)))
  if rings:c.connect(rings[-1],ring)
  rings.append(ring)
 c.faces.append(tuple(reversed(rings[0])));c.faces.append(tuple(rings[-1]))
 _AXES.clear()
 for branch in range(8):
  pair=branch//2;side=-1. if branch%2==0 else 1.
  row=(12,10,8,6)[pair];fi=row*n+(11 if side<0 else 12)
  fi=c.inset(fi,.34);root=sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
  tip=Vector((side*(.35+.055*pair),-.37,root.z+.22))
  delta=tip-root;_AXES.append((tuple(delta.normalized()),delta.length))
  centers=[root.lerp(tip,u)+Vector((0.,-.03*math.sin(math.pi*u),0.)) for u in (.22,.45,.72,1.)]
  c.extrude(fi,centers,(.019,.015,.010,.005),group='cilium_%d'%branch,region='ventral_comb')
 # A broad short seam-following pad grows from the anterior mantle surface.
 fi=c.inset(15*n+12,.52);root=sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
 c.extrude(fi,[root+Vector((0.,-.015,.045)),root+Vector((0.,-.025,.105))],(.029,.017),group='seam_pad',region='ventral_comb')
 skin=api.make_object('Skin',c,col,2 if lod==0 else 1,'continuous_skin');objects=[skin]
 _ROOTS.clear()
 for i in range(8):
  weights=_weights(skin,'cilium_%d_root'%i);total=sum(weights)
  _ROOTS.append(tuple(sum(api.gd(v.co)[a]*w for v,w in zip(skin.data.vertices,weights))/total for a in range(3)))
 for i,(center,radius) in enumerate((((-.15,-.035,-.21),(.16,.046,.18)),((.16,-.045,.06),(.15,.041,.17)),((-.03,.03,.32),(.10,.075,.10)))):
  o=api.make_object('ShallowCompartment_%02d'%i,api.ellipsoid_cage(center,radius,seed+30+i,2 if lod==0 else 1),col,0,'internal_organ');objects.append(o)
 for i in range(4):
  z=-.26+i*.16;pts=[(-.25,-.12,z),(-.08,-.145,z+.015),(.10,-.14,z+.012),(.25,-.12,z)]
  o=api.make_object('VentralLamella_%02d'%i,api.tube_cage(pts,[.011]*4,6 if lod==0 else 4),col,0,'internal_organ');objects.append(o)
 for o in objects:
  tables=[_weights(o,'cilium_%d'%i) for i in range(8)] if o.name=='Skin' else []
  comb=_weights(o,'ventral_comb');bind={};uv=[];sem=[]
  for v in o.data.vertices:
   p=tuple(api.gd(v.co));code=-1;weight=0.
   if tables:
    vals=[t[v.index] for t in tables];w=max(vals)
    if w>1e-7:
     index=vals.index(w);code=-2-index;axis,length=_AXES[index]
     weight=max(0.,min(1.,sum((p[a]-_ROOTS[index][a])*axis[a] for a in range(3))/length))
   bind[_key(p)]=(code,weight);uv.append((code,weight))
   if o.name=='Skin':
    window=.68*max(0.,1.-(abs(p[0])/.54-.82)**2*35.)
    sem.append((.42*comb[v.index],window,5 if window>.30 else 1))
   else:sem.append((.10 if o.name.startswith('Ventral') else .02,.06,2))
  _BIND[o.name]=bind;_UV[o.name]=uv;_SEM[o.name]=sem
 return objects

def deform(point,law,phase,object_name):
 p=tuple(float(v) for v in point);code,weight=_BIND[object_name][_key(p)]
 q=list(p);q[1]+=float(phase)*.025*math.sin(p[2]*5.+.4)
 if code<=-2:
  flank=-1. if (-2-code)%2==0 else 1.
  q[0]+=flank*.35*float(law)*weight;q[1]+=.40*float(law)*weight**3;q[2]+=.10*float(law)*weight
 return tuple(q)
def vertex_semantics(obj):return list(_SEM[obj.name])
def vertex_bindings(obj):return list(_UV[obj.name])
def rig_specs():return [('DEF_mantle_%d'%i,(0.,0.,-.48+i*.24),(0.,0.,-.24+i*.24)) for i in range(4)]
def metadata(species,objects):
 if species!='seam_grazer':raise ValueError('Wrong seam grazer species')
 return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
  'attachments':[],'required_regions':[{'object':'Skin','vertex_group':n,'min_vertices':3} for n in ['seam_pad_root','ventral_comb']+['cilium_%d_root'%i for i in range(8)]],
  'runtime_fields':{'motion_profile':'seam_grazer_unfold'}}
