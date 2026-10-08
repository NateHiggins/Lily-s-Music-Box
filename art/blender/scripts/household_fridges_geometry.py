"""Source-owned cold boxes: joined carcasses, working leaves and larder stock."""
import ast
from mathutils import Matrix
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','transform','ring'}],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]

def component(obj,name):obj['component']=name;return obj

def screw(label,x,y,z,key='nickel',owner='Body'):
 # Recessed slot is geometry, never an albedo mark.
 for side in [-1,1]:
  points=[(x+.004*math.cos(a),z+.004*math.sin(a)) for a in np.linspace(.11,math.pi-.11,17)]
  if side<0:points=[(px,2*z-pz) for px,pz in points]
  n=len(points);v=[(px,q,pz) for q in [y-.0015,y+.0015] for px,pz in points]
  component(solid(identity+'_'+label+str(side),v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key),owner)

def hinges(w,front,zs,owner,key):
 for j,z in enumerate(zs):
  tag=owner+'_Hinge'+str(j);x=-w/2
  # Fixed pin lies on the original controller's exact pivot. Its short
  # central neck clears two separate rotating annular knuckles.
  tube(tag+'_Pin',(x,front,z-.045),(x,front,z+.045),.003,key)
  stock(tag+'_Neck',(x-.006,front-.035,z-.005),(x+.009,front+.003,z+.005),key,.0005)
  for zz in [z-.028,z+.028]:component(ring(tag+'_MovingKnuckle'+str(zz),x,front,zz-.012,.009,.003,.024,key),owner)
  for zz in [z-.028,z+.028]:component(stock(tag+'_Strap'+str(zz),(x+.005,front-.001,zz-.010),(x+.053,front+.014,zz+.010),key,.0005),owner)
  for zz in [z-.028,z+.028]:screw(tag+'_Screw'+str(zz),x+.04,front+.0145,zz,key,owner)

def shelves(monitor):
 half=.277 if monitor else .259;depth=.235 if monitor else .21
 for j,z in enumerate(plan['visual_fit']['monitor_shelves' if monitor else 'icebox_shelves']):
  # 18 mm pitch gives the smallest bottle a real bearing at every source
  # jitter position. Bars finish on the same top datum, with crossbars below.
  for n,x in enumerate(np.linspace(-half+.008,half-.008,41)):
   tube('Rack%d_Rod%02d'%(j,n),(x,-depth,z),(x,depth,z),.0045,'nickel')
  for y in [-depth+.012,depth-.012]:
   tube('Rack%d_Cross%s'%(j,y),(-half,y,z-.0045),(half,y,z-.0045),.0045,'nickel')
   for x in [-half,half]:stock('Rack%d_Clip%s'%(j,(x,y)),(x-.008,y-.014,z-.018),(x+.008,y+.014,z-.003),'nickel',.0007)

def door(w,front,z0,z1,owner,key,handle_z):
 start=len(stock_checks)
 # Keep a 16 mm hinge rebate; it clears the fixed central neck through
 # the full 105/98-degree swing without an invisible decorative hinge.
 component(stock(owner+'_Skin',(-w/2+.016,front,z0),(w/2,front+.036,z1),key,.006),owner)
 component(stock(owner+'_RaisedPanel',(-w/2+.065,front+.032,z0+.035),(w/2-.065,front+.052,z1-.035),key,.007),owner)
 component(stock(owner+'_Liner',(-w/2+.075,front-.007,z0+.028),(w/2-.075,front,z1-.028),'enamel' if key=='enamel' else 'liner',.003),owner)
 x=w/2-.075;metal='nickel' if key=='enamel' else 'brass';h=.24 if key=='enamel' else min(.17,(z1-z0)*.55)
 for z in [handle_z-h/2,handle_z+h/2]:
  component(axial(identity+'_'+owner+'_HandleFoot'+str(z),x,z,[(0,front+.05),(.016,front+.05),(.018,front+.054),(.013,front+.069),(.009,front+.073),(0,front+.073)],identity,metal,48),owner)
 component(wire(owner+'_BowHandle',[(x,front+.068+.020*math.sin(math.pi*t),handle_z-h/2+h*t) for t in np.linspace(0,1,33)],.009,metal),owner)
 component(stock(owner+'_Latch',(x-.04,front+.05,handle_z-h/2-.020),(x+.04,front+.064,handle_z-h/2+.013),metal,.004),owner)
 # Construction joins are checked after all moving hinge straps are added.
 hinges(w,front,[z0+.065,z1-.065] if z1-z0>.4 else [(z0+z1)/2],owner,metal)

def fridge(monitor):
 start=len(stock_checks);w=.72 if monitor else .70;d=.64 if monitor else .58;front=d/2
 key='enamel' if monitor else 'oak';low=.1775 if monitor else .05;top=1.3025 if monitor else 1.24;side=.055 if monitor else .075
 for x in [-.30,.30] if monitor else [-.29,.29]:
  for y in [-front+.055,front-.055]:
   if monitor:lathe('Leg'+str((x,y)),x,y,0,[(0,0),(.014,0),(.0145,.003),(.018,.17),(.024,.1775),(0,.1775)],'nickel')
   else:stock('Foot'+str((x,y)),(x-.0275,y-.0275,0),(x+.0275,y+.0275,.09),key,.002)
   bearing('original floor foot',(x,y,0))
 stock('Bottom',(-w/2,-front,low),(w/2,front if monitor else .264,low+.055 if monitor else .12),key,.004)
 stock('Top',(-w/2,-front,top-.055 if monitor else top-.065),(w/2,front,top),key,.006)
 # The front of each side ends 16 mm behind the pivot axis, allowing the
 # original outward swing at the rebated left edge.
 base_top=low+.055 if monitor else .12;top_bottom=top-.055 if monitor else top-.065
 for x in [-w/2,w/2-side]:stock('Cheek'+str(x),(x,-front+.045,base_top),(x+side,front-.016,top_bottom),key,.004 if monitor else .0015)
 stock('Back',(-w/2,-front,base_top),(w/2,-front+.045,top_bottom),key,.001)
 inner=.277 if monitor else .259;liner='enamel' if monitor else 'liner';bottom=.226 if monitor else .236;ceiling=1.254 if monitor else 1.185
 stock('LinerBack',(-inner-.018,-front+.043,bottom),(inner+.018,-front+.07,ceiling),liner,.003)
 for x in [-inner-.018,inner]:stock('LinerCheek'+str(x),(x,-front+.055,bottom),(x+.018,front-.07,ceiling),liner,.002)
 for z in [bottom,1.236] if monitor else [bottom,.921,1.167]:stock('LinerHorizontal'+str(z),(-inner-.018,-front+.055,z),(inner+.018,front-.07,z+.018),liner,.002)
 if not monitor:
  for z in [.215,.945]:stock('FrontRail'+str(z),(-w/2,front-.060,z),(w/2,front-.012,z+.032),'oak',.002)
  # Sloped zinc drip funnel and open drain neck connect the ice chamber
  # to the existing removable service pan, behind the food lining.
  tube('Drain',(0,-front+.052,.145),(0,-front+.052,.937),.006,'liner')
  for x in [-.249,.249]:stock('TrayGuide'+str(x),(x-.012,-.13,.117),(x+.012,front-.024,.133),'liner',.001)
 else:
  # Recess behind all permitted food jitter rather than through tall milk.
  stock('FreezerShelf',(-.215,-.25,1.119),(.215,-.155,1.141),'enamel',.005)
  stock('FreezerHood',(-.215,-.258,1.13),(.215,-.24,1.28),'enamel',.004)
  for x in [-.20,.20]:stock('FreezerBracket'+str(x),(x-.01,-.257,1.10),(x+.01,-.17,1.125),'nickel',.001)
 shelves(monitor)
 if monitor:
  lathe('CompressorBase',0,0,1.2995,[(0,0),(.25,0),(.27,.006),(.27,.020),(.25,.070),(.24,.075),(0,.075)],'enamel')
  lathe('MotorHousing',0,0,1.36,[(0,0),(.185,0),(.20,.012),(.197,.040),(.18,.183),(.175,.19),(0,.19)],'dark')
  lathe('CapNeck',0,0,1.53,[(0,0),(.095,0),(.095,.061),(0,.061)],'dark')
  lathe('MachineryCap',0,0,1.5845,[(0,0),(.163,0),(.17,.006),(.16,.019),(.083,.07),(.075,.075),(0,.075)],'dark')
  for z in [1.385,1.455,1.525]:
   torus(identity+'_Condenser'+str(z),(0,0,z),.225,.225,.011,identity,'copper')
   for side in [-1,1]:tube('CoilBridge'+str((z,side)),(side*.195,-.02,z),(side*.225,-.02,z),.009,'copper')
  for x in [-.205,.205]:tube('ServicePipe'+str(x),(x,-.02,1.31),(x,-.02,1.56),.010,'copper')
  stock('Badge',(-.09,front-.003,1.269),(.09,front+.018,1.30),'brass',.004)
  for x in [-.078,.078]:screw('BadgeScrew'+str(x),x,front+.019,1.2845,'brass')
  door(w,front,.2275,1.2625,'Door','enamel',.79)
 else:
  door(w,front,.25,.94,'Door','oak',.62);door(w,front,.9675,1.2025,'IceDoor','oak',1.085)
  # Original tray frame remains at Godot z=-.245 and slides out 300 mm.
  for label,lo,hi,key in [
   ('Pan',(-.25,.045,.133),(.25,.265,.147),'liner'),
   ('Left',(-.252,.045,.147),(-.238,.265,.1925),'liner'),
   ('Right',(.238,.045,.147),(.252,.265,.1925),'liner'),
   ('Rear',(-.238,.045,.147),(.238,.054,.1925),'liner'),
   ('Front',(-.26,.2675,.095),(.26,.2925,.205),'oak')]:component(stock('Tray'+label,lo,hi,key,.0015),'DripTray')
  # Folded front flange meets the wooden fascia, removing the source gap.
  component(stock('TrayFrontFold',(-.25,.26,.147),(.25,.273,.188),'liner',.001),'DripTray')
  for x in [-.10,.10]:component(axial(identity+'_TrayPullFoot'+str(x),x,.15,[(0,.289),(.014,.289),(.014,.294),(.008,.306),(0,.306)],identity,'brass',48),'DripTray')
  component(tube('TrayPull',(-.11,.305,.15),(.11,.305,.15),.01,'brass'),'DripTray')
 # Check the complete physical assembly as a joined construction at rest;
 # moving and fixed owners are additionally checked over full travel.
 group('CompleteColdBox',start)

def food(spec):
 start=len(stock_checks);w=spec['width'];h=spec['height'];name=spec['source_id'];r=w*.5
 branded=name.upper()==name
 if name.startswith(('MERIDIAN','PEERLESS','QUELL')) or name in ['jars',"KESSLER'S PICKLES",'ASTORIA CREAM',"HOLLOWAY'S"]:
  bottle=name.startswith(('MERIDIAN','PEERLESS','QUELL'));radius=r*.77 if not name.startswith(('MERIDIAN','PEERLESS','QUELL')) else r
  # Non-cylinder source jars retain their narrower 0.8w depth footprint.
  neck=radius*(.45 if bottle else .85);shoulder=h*(.70 if bottle else .87)
  profile=[(0,0),(radius*.90,0),(radius*.98,.001),(radius,.003),(radius,shoulder)]
  profile.extend((radius+(neck-radius)*(3*t*t-2*t*t*t),shoulder+h*.11*t) for t in np.linspace(0,1,13)[1:])
  profile.extend([(neck,h*.965),(0,h*.965)])
  lathe('Body',0,0,0,profile,'bottle')
  lathe('Closure',0,0,h*.965,[(0,0),(neck*1.05,0),(neck*1.09,h*.006),(neck*1.09,h*.028),(neck,h*.035),(0,h*.035)],'nickel')
  # Plain paper collar with real edges; runtime Label3D owns brand lettering.
  if branded:ring('LabelBand',0,0,h*.24,radius+.0004,radius-.0003,h*.28,'paper')
 elif name=='one lemon':
  profile=[(0,0),(.008,0)]+[(.02*math.sin(t)+.003*abs(math.cos(t)),h*(1-math.cos(t))*.5) for t in np.linspace(.25,math.pi-.12,33)]+[(0,h)]
  lathe('Lemon',0,0,0,profile,'food')
 elif name=='eggs':
  stock('PulpTray',(-w/2,-w*.4,0),(w/2,w*.4,h*.17),'paper',.003)
  for i,x in enumerate([-w*.31,0,w*.31]):
   for j,y in enumerate([-w*.18,w*.18]):
    profile=[(0,0),(.006,0)]+[(.020*math.sin(t)*(1+.16*math.cos(t)),h*.85*(1-math.cos(t))*.5) for t in np.linspace(.2,math.pi-.1,33)]+[(0,h*.85)]
    lathe('Egg%d%d'%(i,j),x,y,h*.15,profile,'food')
 else:
  wrapped=name in ['wrapped','furred']
  stock('Package',(-w/2,-w*.4,0),(w/2,w*.4,h if wrapped else h*.86),'food' if name=='furred' else 'paper',min(.004,h*.055))
  if name in ['wrapped','furred']:
   for side in [-1,1]:
    for upper in [False,True]:
     outline=[(-w*.34,h*.20),(w*.34,h*.20),(0,h*.75)] if not upper else [(-w*.34,h*.80),(w*.34,h*.80),(0,h*.30)]
     # Layer the second fold one paper thickness outwards; coincident
     # overlapping triangles otherwise produce a dark diamond in renders.
     offset=side*.0012 if upper else 0
     verts=[(xx,yy+offset,zz) for yy in [side*w*.4-.0006,side*w*.4+.0006] for xx,zz in outline]
     solid(identity+'_Fold'+str((side,upper)),verts,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],identity,'paper')
   stock('WrapSeam',(-w*.4,-.003,h-.001),(w*.4,.003,h+.0004),'paper',.0004)
  else:
   stock('Lid',(-w*.5,-w*.4,h*.86),(w*.5,w*.4,h),'paper',.001)
 group('LarderObject',start)

for spec in plan['variants']:
 identity=spec['id']
 if spec['kind']=='food':food(spec)
 else:fridge(spec['kind']=='monitor')
