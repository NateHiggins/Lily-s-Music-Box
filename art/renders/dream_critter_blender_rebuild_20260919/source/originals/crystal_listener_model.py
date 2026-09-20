"""Fictional crystal listener with a stationary receiver and actual rotor.
Dossier D2/D11/D18/D47 supplies support/section analogies, not acoustic proof.
The existing CPU spin is realized as internal mesh rotation only. Wet annular
suspension bearings meet an axial pole, so no membrane accumulates infinite
torsion. This is original alien anatomy, not a biological statocyst claim.
"""
import math
SPECIES_ID=1
CILIUM_BRANCH_COUNT=12
PROP_BRANCH_COUNT=5
_BIND={};_UV={};_SEM={};_ROOTS={};_AXES={}
def _key(p):return tuple(round(float(v),8) for v in p)
def _weights(o,n):
 g=o.vertex_groups.get(n)
 return [next((a.weight for a in v.groups if g and a.group==g.index),0.) for v in o.data.vertices]

def _annulus(api,y):
 c=api.Cage();rings=[];n=16
 for height,r in ((y-.010,.027),(y-.010,.064),(y+.010,.064),(y+.010,.027)):
  rings.append([c.vertex((r*math.cos(j*math.tau/n),height,r*math.sin(j*math.tau/n))) for j in range(n)])
 for i in range(4):c.connect(rings[i],rings[(i+1)%4])
 return c

def build_objects(api,col,lod,seed):
 from mathutils import Vector
 c=api.Cage();rings=[];n=24
 profile=((- .31,.09),(-.275,.18),(-.21,.27),(-.08,.34),(.08,.35),(.23,.28),(.31,.16),(.345,.045))
 for row,(y,r) in enumerate(profile):
  ring=[]
  for j in range(n):
   a=math.tau*j/n;ridge=max(0.,math.cos(a*4))**8
   radius=r+ridge*.025*math.sin(row/(len(profile)-1)*math.pi)
   vi=c.vertex((radius*math.cos(a),y,radius*math.sin(a)));ring.append(vi)
   if ridge>.3:c.group('mineral_cage',[vi],ridge)
  if rings:c.connect(rings[-1],ring)
  rings.append(ring)
 c.faces.append(tuple(reversed(rings[0])));c.faces.append(tuple(rings[-1]))
 _AXES.clear()
 # A stable tripod is always present; the extra two are compliant auxiliaries.
 for i,angle in enumerate((0.,math.tau/3,math.tau*2/3,math.pi/3,math.pi)):
  j=int(round(angle/math.tau*n))%n;fi=c.inset(n+j,.36)
  root=sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
  tip=Vector((.68*math.cos(angle),-.49,.68*math.sin(angle)))
  delta=tip-root;_AXES[i]=(tuple(delta.normalized()),delta.length)
  c.extrude(fi,[root.lerp(tip,u)+Vector((0.,.025*math.sin(math.pi*u),0.)) for u in (.30,.62,1.)],(.045,.034,.025),group='prop_%d'%i,region='prop')
 used=set()
 for i in range(12):
  angle=i*math.pi*(3.-math.sqrt(5.));j=int(round(angle/math.tau*n))%n
  while j in used:j=(j+1)%n
  used.add(j);fi=c.inset(5*n+j,.20)
  root=sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
  direction=Vector((math.cos(angle)*.42,1.,math.sin(angle)*.42)).normalized()
  tip=root+direction*(.58+.045*math.sin(i*2.1));delta=tip-root
  _AXES[-2-i]=(tuple(delta.normalized()),delta.length)
  c.extrude(fi,[root.lerp(tip,u) for u in (.25,.52,.77,1.)],(.010,.008,.005,.0018),group='cilium_%d'%i,region='cilia')
 skin=api.make_object('Skin',c,col,2 if lod==0 else 1,'continuous_skin');objects=[skin];_ROOTS.clear()
 for code,name in [(i,'prop_%d_root'%i) for i in range(5)]+[(-2-i,'cilium_%d_root'%i) for i in range(12)]:
  w=_weights(skin,name);total=sum(w)
  _ROOTS[code]=tuple(sum(api.gd(v.co)[a]*weight for v,weight in zip(skin.data.vertices,w))/total for a in range(3))
 rotor=api.Cage();previous=None
 # The faceted body is deliberately asymmetric; rotation is visible geometry.
 for y,rx,rz in ((-.25,.024,.024),(-.16,.025,.025),(-.11,.11,.073),(-.035,.16,.10),(.085,.12,.078),(.18,.025,.025),(.275,.024,.024)):
  ring=[rotor.vertex((rx*math.cos(j*math.tau/12),y,rz*math.sin(j*math.tau/12))) for j in range(12)]
  if previous is None:rotor.faces.append(tuple(reversed(ring)))
  else:rotor.connect(previous,ring)
  previous=ring
 rotor.faces.append(tuple(previous));rotor.group('resonant_core',range(len(rotor.vertices)))
 o=api.make_object('Resonator',rotor,col,0,'internal_organ')
 for polygon in o.data.polygons:polygon.use_smooth=False
 objects.append(o)
 for index,y in enumerate((-.20,.23)):
  objects.append(api.make_object('WetSuspension_%d'%index,_annulus(api,y),col,0,'internal_organ'))
 objects.append(api.make_object('ReceivingChamber',api.ellipsoid_cage((0.,0.,0.),(.235,.285,.235),seed+10,3 if lod==0 else 2),col,0,'internal_organ'))
 for o in objects:
  prop=[_weights(o,'prop_%d'%i) for i in range(5)] if o.name=='Skin' else []
  cilia=[_weights(o,'cilium_%d'%i) for i in range(12)] if o.name=='Skin' else []
  cageweights=_weights(o,'mineral_cage');bind={};uv=[];sem=[]
  for v in o.data.vertices:
   p=tuple(api.gd(v.co));code=-1;weight=0.
   if prop:
    vals=[t[v.index] for t in prop];w=max(vals)
    if w>1e-7:code=vals.index(w)
   if cilia and code==-1:
    vals=[t[v.index] for t in cilia];w=max(vals)
    if w>1e-7:code=-2-vals.index(w)
   if code!=-1:
    axis,length=_AXES[code];weight=max(0.,min(1.,sum((p[a]-_ROOTS[code][a])*axis[a] for a in range(3))/length))
   bind[_key(p)]=(code,weight);uv.append((code,weight))
   if o.name=='Skin':
    window=.78*max(0.,math.sin(math.atan2(p[2],p[0])))**2*(1.-cageweights[v.index])
    sem.append((.55*cageweights[v.index],window,5 if window>.35 else 1))
   elif o.name=='Resonator':sem.append((.30,.32,2))
   else:sem.append((.06,.80,5))
  _BIND[o.name]=bind;_UV[o.name]=uv;_SEM[o.name]=sem
 return objects

def deform(point,law,phase,object_name):
 p=tuple(float(v) for v in point);code,weight=_BIND[object_name][_key(p)]
 if object_name=='Resonator':
  a=math.tau*float(law);return (p[0]*math.cos(a)+p[2]*math.sin(a),p[1],-p[0]*math.sin(a)+p[2]*math.cos(a))
 q=list(p)
 if code<=-2:q[0]+=float(phase)*.022*weight*weight
 elif code>=0:q[1]-=float(phase)*.006*weight*weight
 return tuple(q)
def vertex_semantics(obj):return list(_SEM[obj.name])
def vertex_bindings(obj):return list(_UV[obj.name])
def rig_specs():return [('DEF_shell',(0.,-.3,0.),(0.,.32,0.)),('DEF_rotor',(0.,-.25,0.),(0.,.275,0.))]
def metadata(species,objects):
 if species!='crystal_listener':raise ValueError('Wrong crystal listener species')
 return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
  'attachments':[],'required_regions':[{'object':'Skin','vertex_group':g,'min_vertices':3} for g in ['mineral_cage']+['prop_%d_root'%i for i in range(5)]+['cilium_%d_root'%i for i in range(12)]]+[{'object':'Resonator','vertex_group':'resonant_core','min_vertices':3}],
  'runtime_fields':{'motion_profile':'crystal_listener_spin'}}
