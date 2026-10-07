"""Five source silhouettes. Inputs below are local Godot metres, converted once."""
def gp(value):return Vector((value[0],-value[2],value[1]))
def add(a,b):return tuple(Vector(a)+Vector(b))
def gbox(label,at,size,key,bevel=.001):
 low=gp((at[0]-size[0]/2,at[1]-size[1]/2,at[2]+size[2]/2));high=gp((at[0]+size[0]/2,at[1]+size[1]/2,at[2]-size[2]/2))
 return box(identity+'_'+label,low,high,identity,key,bevel)
def tube(label,a,b,radius,key):return rod(identity+'_'+label,gp(a),gp(b),radius,identity,key,48)
def lathe(label,at,axis,profile,key,segments=64):
 direction=gp(axis).normalized();seed=Vector((0,0,1)) if abs(direction.z)<.9 else Vector((1,0,0));u=direction.cross(seed).normalized();v=direction.cross(u);origin=gp(at)
 is_ring=profile[0]==profile[-1];profile=profile[:-1] if is_ring else profile;verts=[];rings=[]
 for distance,radius in profile:
  point=origin+direction*distance
  if radius==0:rings.append([len(verts)]);verts.append(point)
  else:
   rings.append(list(range(len(verts),len(verts)+segments)));verts.extend(point+radius*(u*math.cos(i*math.tau/segments)+v*math.sin(i*math.tau/segments)) for i in range(segments))
 faces=[]
 for a,b in zip(rings,rings[1:]+(rings[:1] if is_ring else [])):
  for j in range(segments):
   k=(j+1)%segments
   if len(a)==len(b)==1:continue
   if len(a)==1:faces.append((a[0],b[j],b[k]))
   elif len(b)==1:faces.append((a[j],b[0],a[k]))
   else:faces.append((a[j],b[j],b[k],a[k]))
 return solid(identity+'_'+label,verts,faces,identity,key)
def disc(label,at,axis,radius,depth,key):
 return lathe(label,at,axis,[(0,0),(0,radius-.001),(.001,radius),(depth-.001,radius),(depth,radius-.001),(depth,0)],key)
def wire(label,points,radius=.003):return curved_wire(identity+'_'+label,[gp(p) for p in points],radius,identity,'rubber_aged')
def strut(label,start,degrees,length,radius,key):
 angle=math.radians(degrees);end=add(start,(math.sin(angle)*length,math.cos(angle)*length,0));tube(label,start,end,radius,key);return end
def joint(label,at,radius=.024,key='iron_blackened'):
 disc(label+'Body',add(at,(0,0,-.014)),(0,0,1),radius,.028,key)
 disc(label+'Washer',add(at,(0,0,.012)),(0,0,1),radius*.69,.005,'nickel_plated')
 disc(label+'Screw',add(at,(0,0,.016)),(0,0,1),radius*.60,.012,'nickel_plated')
 for j in range(24):
  a=j*math.tau/24;offset=(math.sin(a)*radius*.595,math.cos(a)*radius*.595,0)
  tube(label+'Knurl'+str(j),add(at,add(offset,(0,0,.017))),add(at,add(offset,(0,0,.027))),.0008,'nickel_plated')
def ball_joint(label,at):
 profile=[(-.019,0)]+[(.019*math.sin(-math.pi/2+j*math.pi/20),.019*math.cos(-math.pi/2+j*math.pi/20)) for j in range(1,20)]+[(.019,0)]
 lathe(label+'Ball',at,(0,1,0),profile,'nickel_plated')
 lathe(label+'Socket',at,(0,1,0),[(-.014,.010),(-.014,.015),(-.006,.020),(.003,.020),(.005,.017),(-.007,.015),(-.014,.010)],'nickel_plated')
def canopy(half,base,height,depth):
 # Closed, thin half-elliptical sheet; the lower opening is not a solid box.
 n=64;verts=[]
 for x in [-half,half]:
  for inset in [0.,.0025]:
   for j in range(n+1):
    theta=j*math.pi/n;verts.append(gp((x,base+(height-inset)*math.sin(theta),(depth-inset)*math.cos(theta))))
 m=n+1;faces=[]
 for j in range(n):faces.extend([(j,j+1,2*m+j+1,2*m+j),(m+j,3*m+j,3*m+j+1,m+j+1),(j,m+j,m+j+1,j+1),(2*m+j,2*m+j+1,3*m+j+1,3*m+j)])
 faces.extend([(0,2*m,3*m,m),(n,m+n,3*m+n,2*m+n)])
 solid(identity+'_CasedGreenCanopy',verts,faces,identity,'green_glass')
 for zz in [-depth,depth]:tube('RolledGlassRim'+str(zz),(-half,base,zz),(half,base,zz),.0025,'brass')
 # Side cheeks are actual two-millimetre glass stock, not a solid hood fill.
 for side in [-1,1]:
  verts=[]
  for xx in [side*(half-.002),side*half]:
   verts.append(gp((xx,base,0)))
   verts.extend(gp((xx,base+height*math.sin(j*math.pi/n),depth*math.cos(j*math.pi/n))) for j in range(n+1))
  count=n+2;faces=[tuple(range(count)),tuple(reversed(range(count,count*2)))]+[(j,(j+1)%count,count+(j+1)%count,count+j) for j in range(count)]
  solid(identity+'_GlassCheek'+str(side),verts,faces,identity,'green_glass')

emitters={}
for assembly in assemblies:
 identity=assembly['id'];variant=assembly['cell'];key='brass' if variant in ['emeralite','office_green'] else ('enamel' if variant=='landlord_enamel' else 'iron_blackened')
 radius={'emeralite':.095,'office_green':.078,'bench_friction':.110,'landlord_enamel':.082,'architect_counterweight':.112}[variant]
 height={'emeralite':.022,'office_green':.020,'bench_friction':.030,'landlord_enamel':.034,'architect_counterweight':.034}[variant]
 base_key='wood_dark' if variant=='architect_counterweight' else key
 lathe('WeightedFoot',(0,0,0),(0,1,0),[(0,0),(0,radius-.005),(.002,radius),(.009,radius), (height-.003,radius*.82),(height,radius*.78),(height,0)],base_key)
 # The material footprint stays exactly on the original support datum.
 for a in [0,math.tau/3,2*math.tau/3]:
  contacts.append({'assembly':identity,'owner':'external_support','point':[math.cos(a)*radius*.5,0,math.sin(a)*radius*.5],'direction':[0,1,0],'label':'retained flat lamp base datum'})
 if variant in ['emeralite','office_green']:
  office=variant=='office_green';stem_top=.270 if office else .342;shade_base=.269 if office else .338
  lathe('StemCollar',(0,height-.003,0),(0,1,0),[(0,0),(0,.030),(.012,.030),(.018,.020),(.023,.014),(.023,0)],'brass')
  tube('UprightStem',(0,height+.012,0),(0,stem_top,0),.010 if office else .011,'brass')
  canopy(.10 if office else .13,shade_base,.10,.0525 if office else .065)
  half=.10 if office else .13
  for side in [-1,1]:
   tube('YokeCrossbar'+str(side),(0,shade_base-.008,0),(side*(half+.005),shade_base-.008,0),.0035,'brass')
   tube('YokeUpright'+str(side),(side*(half+.005),shade_base-.008,0),(side*(half+.005),shade_base+.048,0),.004,'brass')
   disc('ShadePivot'+str(side),(side*(half-.003),shade_base+.048,0),(side,0,0),.011,.012,'brass')
  emitter=(.08,.33,0) if office else (.10,.40,0)
  tube('SocketRiser',(0,stem_top-.006,0),(0,emitter[1],0),.012,'brass')
  disc('PorcelainSocket',(0,emitter[1],0),(1,0,0),.018,.060 if office else .075,'bakelite')
  start=.057 if office else .072;length=emitter[0]-start
  lathe('IncandescentBulb',(start,emitter[1],0),(1,0,0),[(0,0),(0,.012),(length*.7,.018),(length+.013,.016),(length+.025,0)],'bulb_opal')
  wire('ClothFlex',[(.025,emitter[1]-.013,.012),(0,stem_top-.01,.023),(.01,.13,.027),(.014,height-.002,.035)])
 else:
  if variant=='bench_friction':
   hip=(0,.080,0);lathe('SocketFoot',(0,.026,0),(0,1,0),[(0,0),(0,.040),(.052,.036),(.055,0)],key)
   joint('Hip',hip);elbow=strut('LowerArm',hip,26,.30,.011,'nickel_plated');joint('Elbow',elbow)
   wrist=strut('UpperArm',elbow,-34,.28,.010,'nickel_plated');joint('Wrist',wrist)
   center=add(wrist,(.012,-.062,0));size=.15;rim=.115;neck=.030;angle=8;emitter=add(wrist,(.016,-.100,0))
  elif variant=='landlord_enamel':
   hip=(0,.034,0);elbow=strut('UprightArm',hip,14,.34,.008,'enamel');joint('WornKnuckle',elbow,.020,'enamel');wrist=elbow
   center=add(elbow,(.014,-.052,0));size=.112;rim=.090;neck=.026;angle=10;emitter=add(elbow,(.018,-.078,0))
  else:
   # The old short counterweight crossed the support plane. Raise only the
   # lower fulcrum on a real pedestal; retain elbow, wrist and emitter datums.
   hip=(0,.132,0);tube('FulcrumPedestal',(0,.031,0),hip,.013,'nickel_plated');ball_joint('LowerBall',hip)
   elbow=(math.sin(math.radians(24))*.34,.052+math.cos(math.radians(24))*.34,0)
   tube('LowerArm',hip,elbow,.009,'nickel_plated');ball_joint('UpperBall',elbow)
   wrist=strut('UpperArm',elbow,-30,.30,.008,'nickel_plated');ball_joint('HeadBall',wrist)
   axis=(math.sin(math.radians(24)),math.cos(math.radians(24)),0);weight=tuple(Vector(hip)-Vector(axis)*.048)
   disc('Counterweight',tuple(Vector(weight)-Vector(axis)*.026),axis,.026,.052,'nickel_plated')
   tube('CounterweightSpindle',weight,hip,.006,'nickel_plated')
   center=add(wrist,(.010,-.046,0));size=.098;rim=.078;neck=.022;angle=10;emitter=add(wrist,(.014,-.072,0));key='nickel_plated'
  axis=(-math.sin(math.radians(angle)),math.cos(math.radians(angle)),0);bottom=tuple(Vector(center)-Vector(axis)*size*.5);top=tuple(Vector(center)+Vector(axis)*size*.5)
  lathe('SpunHollowShade',bottom,axis,[(0,rim),(size,neck),(size,neck-.002),(0,rim-.002),(0,rim)],key)
  lathe('RolledShadeLip',bottom,axis,[(0,rim-.002),(-.002,rim),(.001,rim+.002),(.004,rim),(.003,rim-.002),(0,rim-.002)],'nickel_plated')
  tube('ShadeNeckBearing',wrist,top,.018,key)
  tube('BakeliteSocket',tuple(Vector(emitter)+Vector(axis)*.016),top,.017,'bakelite')
  lathe('IncandescentBulb',emitter,axis,[(-.017,0),(-.014,.015),(0,.021),(.015,.017),(.019,0)],'bulb_opal')
  wire('SupportedFlex',[add(top,(0,0,.015)),add(wrist,(0,0,.029)),add(elbow,(0,0,.029)),add(hip,(0,0,.027)),(.012,height-.002,.033)])
  for label,at in [('LowerCordClip',hip),('UpperCordClip',elbow)]:
   tube(label,add(at,(0,0,.005)),add(at,(0,0,.029)),.004,'iron_blackened')
 # The original moving switch pivot remains separate from stationary finishes.
 pivot=(.060,.037,-.045)
 tube('SwitchSocket',(0.060,height-.004,-.024),pivot,.012,base_key)
 disc('SwitchBushing',add(pivot,(0,0,-.007)),(0,0,1),.013,.012,'nickel_plated')
 tube('KeySpindle',add(pivot,(0,0,-.014)),add(pivot,(0,0,.013)),.010,'switch_bakelite')
 gbox('KeyGrip',add(pivot,(0,0,-.018)),(.045,.012,.018),'switch_bakelite',.002)
 emitters[variant]=list(emitter)
