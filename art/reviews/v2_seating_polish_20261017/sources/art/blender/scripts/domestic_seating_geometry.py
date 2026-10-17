"""Four source-equivalent variants; every installed actor retains its frame."""
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]

def stock(label,lo,hi,key,edge=.002):
 return box(identity+'_'+label,lo,hi,identity,key,edge)

def pad(label,lo,hi,key,radius):
 obj=stock(label,lo,hi,key,0)
 bpy.context.view_layer.objects.active=obj
 mod=obj.modifiers.new('Upholstered radius','BEVEL');mod.width=radius;mod.segments=8
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

def wire(label,points,radius,key):
 return curved_wire(identity+'_'+label,points,radius,identity,key)

def spline(points,steps=12):
 points=[np.array(p,dtype=float) for p in points];out=[]
 for i in range(len(points)-1):
  a=points[max(0,i-1)];b=points[i];c=points[i+1];d=points[min(i+2,len(points)-1)]
  for t in np.linspace(0,1,steps,endpoint=False):
   out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 return out+[points[-1]]

def floor_spindle(label,x0,y0,x1,y1,height,r0,r1,key):
 # Rings are cut in horizontal planes, so all of each foot bears at Z=0.
 n=32;verts=[]
 for t in [0,.015,.18,.8,1]:
  radius=r0*(1-t)+r1*t
  verts.extend((x0*(1-t)+x1*t+radius*math.cos(i*math.tau/n),y0*(1-t)+y1*t+radius*math.sin(i*math.tau/n),height*t) for i in range(n))
 faces=[tuple(reversed(range(n))),tuple(range(4*n,5*n))]
 faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(4) for i in range(n)]
 obj=solid(identity+'_'+label,verts,faces,identity,key)
 support(identity,'support',(x0,y0,0),(0,0,1),label+' horizontal foot')
 return obj

def chair(params):
 wood=params['wood']
 vessel(identity+'_DishedSeat',0,0,0,[(0,.435),(.17,.433),(.20,.415),(.208,.419),(.215,.44),(.215,.473),(.21,.478),(.19,.476),(0,.468)],identity,wood)
 for i,(x,y) in enumerate([(-.14,.12),(.14,.12),(-.14,-.11),(.14,-.11)]):
  floor_spindle('SplayedLeg'+str(i),x*1.3,y*1.45,x,y,.442,.017,.015,wood)
 # Original hoop control points with smooth continuous bends and real seats.
 controls=[(-.15,-.15,.448),(-.135,-.205,.72),(-.095,-.225,.93),(0,-.245,.965),(.095,-.225,.93),(.135,-.205,.72),(.15,-.15,.448)]
 wire('SteamBentHoop',spline(controls),.014,wood)
 wire('BackCrossRail',spline([(-.136,-.202,.70),(0,-.225,.725),(.136,-.202,.70)],20),.011,wood)
 retained_stock.append({'assembly':identity,'kind':'chair','seat_top':.478,'hoop_control_points':controls,'original_foot_penetration_m':.003231483457181407})

def rounded_rectangle(x0,y0,x1,y1,z,radius=.02,n=12):
 points=[]
 for x,y,start in [(x1-radius,y1-radius,0),(x0+radius,y1-radius,math.pi/2),(x0+radius,y0+radius,math.pi),(x1-radius,y0+radius,3*math.pi/2)]:
  points += [(x+radius*math.cos(a),y+radius*math.sin(a),z) for a in np.linspace(start,start+math.pi/2,n,endpoint=False)]
 return points+[points[0]]

def boxed_cushion(label,lo,hi,key,radius,axis=2):
 # Sewn boxing joins two stuffed panels. Crown stays inside the original
 # envelope; the seat's lower panel still bears on its retained sprung base.
 # The back uses the same construction facing +Y instead of +Z.
 plane=[i for i in range(3) if i!=axis]
 center=np.array([(lo[i]+hi[i])*.5 for i in plane])
 half=np.array([(hi[i]-lo[i])*.5 for i in plane])
 thickness=hi[axis]-lo[axis]
 lower=lo[axis]+min(.012,thickness*.12)
 upper=hi[axis]-min(.030,thickness*.22)
 boundary=[np.array(p[:2]) for p in rounded_rectangle(*(center-half),*(center+half),0,radius,n=8)[:-1]]
 # Distribute vertices along straight hems too, so broad fabric panels do
 # not inherit the old box's long, sparsely sampled edges.
 outline=[]
 for a,b in zip(boundary,boundary[1:]+boundary[:1]):
  steps=max(1,math.ceil(float(np.linalg.norm(b-a))/.055))
  outline.extend(a+(b-a)*t/steps for t in range(steps))
 outline=np.array(outline)
 verts=[];rings=[]
 def ring(scale,height,edge_bulge=0.):
  ids=[]
  for uv in outline:
   uv=center+(uv-center)*scale
   if edge_bulge:uv+=((uv-center)/half)*edge_bulge
   p=[0.,0.,0.];p[axis]=height
   for j,i in enumerate(plane):p[i]=uv[j]
   ids.append(len(verts));verts.append(p)
  rings.append(ids)
 def pole(height):
  p=[0.,0.,0.];p[axis]=height
  for j,i in enumerate(plane):p[i]=center[j]
  rings.append([len(verts)]);verts.append(p)
 pole(lo[axis])
 for s in [.20,.45,.70,.88,.97,1.]:
  ring(s,lo[axis]+(lower-lo[axis])*s*s)
 ring(1.,lower+(upper-lower)*.35,.002)
 ring(1.,lower+(upper-lower)*.70,.002)
 ring(1.,upper)
 seam=[]
 for v in rings[-1]:seam.append(tuple(verts[v]))
 shoulder=min(.026,min(half)*.18)
 scales=[1.-shoulder/min(half)*t for t in [.04,.16,.36,.64,1.]]
 scales += [scales[-1]*t for t in [.85,.65,.40,.17]]
 for s in scales:
  # A rounded shoulder beneath a broad crown, not a planar box cap.
  inset=(1.-s)*min(half)
  q=min(inset/shoulder,1.)
  shoulder_height=math.sqrt(max(0.,1.-(1.-q)**2))
  # The horizontal panel's broad bearing stays level beneath the retained
  # loose cushions. The rounding is at its sewn shoulder; the upright back
  # panel can carry a fuller crown without disturbing supported stock.
  crown=shoulder_height if axis==2 else .80*shoulder_height+.20*(1.-s*s)
  height=upper+(hi[axis]-upper)*crown
  ring(s,height)
 pole(hi[axis])
 faces=[];n=len(outline)
 for a,b in zip(rings,rings[1:]):
  for j in range(n):
   k=(j+1)%n
   if len(a)==1:faces.append((a[0],b[j],b[k]))
   elif len(b)==1:faces.append((a[j],b[0],a[k]))
   else:faces.append((a[j],b[j],b[k],a[k]))
 obj=solid(identity+'_'+label,verts,faces,identity,key)
 # The welt is sewn at the actual cap/boxing junction, using the same cloth.
 wire(label+'Welt',seam+[seam[0]],.0015,key)
 return obj

def sofa(params):
 length=params['length'];wood=params['wood'];cloth=params['cloth'];depth=.88
 for ix,x in enumerate([-length/2+.10,length/2-.10]):
  for iy,y in enumerate([-depth/2+.09,depth/2-.09]):
   floor_spindle('Foot%d%d'%(ix,iy),x,y,x,y,.165,.030,.019,wood)
 pad('UpholsteredBase',(-length/2-.02,-.44,.15),(length/2+.02,.44,.31),cloth,.025)
 # A fitted rear shell connects both back cushions and the original arm stocks.
 pad('BackShell',(-length/2-.01,-.439,.285),(length/2+.01,-.314,.77),cloth,.018)
 for sign in [-1,1]:
  low=sign*length/2+(.02 if sign>0 else -.18);high=sign*length/2+(.18 if sign>0 else -.02)
  # Source arms touched only a tangent edge of the base: hide a timber seat
  # inside the upholstery to give each real support without widening the actor.
  bridge_low=low-.035 if sign>0 else low+.020;bridge_high=high-.020 if sign>0 else high+.035
  stock('ArmSeat'+str(sign),(bridge_low,-.35,.185),(bridge_high,.35,.28),wood,.005)
  if params.get('arms','rolled')=='rolled':
   # Dossier BW-003: a sprung 1910s sofa carries rolled arms, not square slabs.
   pad('Arm'+str(sign),(low,-.44,.15),(high,.44,.54),cloth,.05)
   pad('ArmRoll'+str(sign),(low-.01,-.43,.50),(high+.01,.42,.665),cloth,.075)
  else:
   pad('Arm'+str(sign),(low,-.44,.15),(high,.44,.62),cloth,.05)
 count=int(params.get('cushions',2));cw=(length-.04*(count+1))/count
 for i in range(count):
  x0=-length/2+.04+i*(cw+.04);x1=x0+cw
  boxed_cushion('SeatCushion'+str(i),(x0,-.28,.309),(x1,.41,.455),cloth,.026)
  boxed_cushion('BackCushion'+str(i),(x0,-.34,.435),(x1,-.14,.82),cloth,.035,axis=1)
 retained_stock.append({'assembly':identity,'kind':'sofa','length':length,'cushions':count,'seat_top':.455,'back_top':.82})

for item in assemblies:
 identity=item['id'];start=len(stock_checks);params=variants[identity]['params']
 if item['kind']=='chair':chair(params)
 else:sofa(params)
 construction_groups.append({'assembly':identity,'id':identity+'_JoinedSeat','stocks':[x['name'] for x in stock_checks[start:]]})
