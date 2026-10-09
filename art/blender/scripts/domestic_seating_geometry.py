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
  pad('SeatCushion'+str(i),(x0,-.28,.309),(x1,.41,.455),cloth,.026)
  pad('BackCushion'+str(i),(x0,-.34,.435),(x1,-.14,.82),cloth,.035)
  # Fine applied welts bear on the cushion side, below the rounded shoulder.
  wire('SeatWelt'+str(i),rounded_rectangle(x0-.0004,-.2804,x1+.0004,.4104,.365,.026),.0015,'linen')
  # The back welt follows the rounded front perimeter, in the vertical plane.
  path=rounded_rectangle(x0+.008,.447,x1-.008,.808,0,.029)
  wire('BackWelt'+str(i),[(x,-.141,z) for x,z,_ in path],.0015,'linen')
 retained_stock.append({'assembly':identity,'kind':'sofa','length':length,'cushions':count,'seat_top':.455,'back_top':.82})

for item in assemblies:
 identity=item['id'];start=len(stock_checks);params=variants[identity]['params']
 if item['kind']=='chair':chair(params)
 else:sofa(params)
 construction_groups.append({'assembly':identity,'id':identity+'_JoinedSeat','stocks':[x['name'] for x in stock_checks[start:]]})
