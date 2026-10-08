"""Worked stock for the source lighting forms, in each original actor frame."""
import ast
from mathutils import Matrix
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py'
tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','transform','ring'}],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]

def component(obj,name):obj['component']=name;return obj

def cap(label,r,z,height,key='brass'):
 return lathe(label,0,0,z,[(0,0),(r-.001,0),(r,.001),(r,height-.001),(r-.001,height),(0,height)],key)

def ceiling_canopy(radius=.06):
 if 'inline_feed_radius' in variant:
  feed=float(variant['inline_feed_radius'])
  component(cap('InlineCollar',feed+.005,-.026,.026),'Mount')
  for x in [-feed*.5,feed*.5]:support(identity,'ceiling',(x,0,0),(0,0,-1),'retained source suspension rod endpoint')
  return
 start=len(pieces[identity])
 lathe('Canopy',0,0,-.026,[(0,0),(.018,0),(.025,.006),(radius-.005,.014),(radius,.018),(radius,.026),(radius-.002,.026),(radius-.002,.020),(.023,.008),(.016,.002),(0,.002)],'brass')
 for side in [-1,1]:
  x=side*radius*.65
  lathe('CanopyScrew'+str(side),x,0,-.018,[(0,0),(.004,0),(.0045,.001),(.004,.003),(0,.003)],'brass')
  support(identity,'ceiling',(side*(radius-.001),0,0),(0,0,-1),'canopy rim against original ceiling')
 for obj,key in pieces[identity][start:]:component(obj,'Mount')

def shell(label,center,radius,height,key='bulb',wall=.0016):
 # Closed thin glass wall, avoiding coincident solid sphere caps.
 neck=radius*math.sin(.20)
 profile=[(neck,height*.5)]
 for t in np.linspace(.20,math.pi,49):profile.append((0. if t==math.pi else radius*math.sin(t),height*.5*math.cos(t)))
 profile.extend((0. if t==math.pi else (radius-wall)*math.sin(t),(height*.5-wall)*math.cos(t)) for t in np.linspace(math.pi,.20,49))
 profile.extend([(neck-wall,height*.5),(neck,height*.5)])
 obj=lathe(label,center[0],center[1],center[2],profile,key)
 return component(obj,'Bulb' if key=='bulb' else 'Stained' if key=='stained' else 'Body')

def socket(label,center,height=.045,r=.017):
 x,y,z=center
 lathe(label,x,y,z,[(0,0),(r,0),(r+.002,.004),(r+.002,height-.004),(r,height),(0,height)],'enamel')
 for i in range(4):ring(label+'Thread'+str(i),x,y,z+.004+i*.003,r+.0028,r+.0015,.0018,'brass')

def pendant():
 ceiling_canopy()
 rise=float(variant.get('ceiling_rise',0))
 if rise:
  for obj,key in pieces[identity]:transform(obj,Matrix.Translation((0,0,rise)))
  for c in contacts:
   if c['assembly']==identity:c['point'][1]+=rise
 tube('BraidedDrop',(0,0,rise-.026),(0,0,-.55),.006,'rubber')
 socket('Socket',(0,0,-.575),.045,.021)
 # The original tapered fabric drum gains a closed skin, rolled hems and stays.
 lathe('Shade',0,0,0,[(.188,-.510),(.190,-.510),(.230,-.750),(.228,-.750),(.188,-.510)],'linen')
 ring('UpperHem',0,0,-.514,.191,.187,.004,'linen')
 ring('LowerHem',0,0,-.754,.231,.227,.004,'linen')
 for i in range(3):
  a=i*math.tau/3
  tube('ShadeSpider'+str(i),(math.cos(a)*.021,math.sin(a)*.021,-.538),(math.cos(a)*.189,math.sin(a)*.189,-.512),.002,'brass')
 # Lower diffuser is source-sized; three clips visibly support its rim.
 component(cap('Diffuser',.20,-.761,.012,'bulb'),'Bulb')
 for i in range(3):
  a=i*math.tau/3
  tube('DiffuserStay'+str(i),(math.cos(a)*.228,math.sin(a)*.228,-.748),(math.cos(a)*.198,math.sin(a)*.198,-.758),.002,'brass')
 shell('Lamp',(0,0,-.60),.04,.085)

def flush():
 lathe('SteppedCanopy',0,0,0,[(0,0),(.115,0),(.115,-.010),(.095,-.030),(.135,-.070),(.135,-.074),(.129,-.074),(.090,-.034),(.109,-.013),(.109,-.006),(0,-.006)],'brass')
 ring('RetainingRing',0,0,-.081,.149,.139,.017,'brass')
 # Schoolhouse globe retains its exact source ellipsoid and seats in its ring.
 shell('OpalBowl',(0,0,-.145),.165,.23)
 for i in range(3):
  a=i*math.tau/3
  tube('GlobeScrew'+str(i),(math.cos(a)*.133,math.sin(a)*.133,-.073),(math.cos(a)*.151,math.sin(a)*.151,-.073),.003,'brass')
 for x in [-.09,.09]:support(identity,'ceiling',(x,0,0),(0,0,-1),'schoolhouse canopy ceiling seat')

def sconce():
 back=float(variant.get('wall_back',.0245))
 stock('Backplate',(-.045,back-.004,-.08),(.045,back,.08),'brass',.0007)
 for z in [-.055,.055]:
  obj=cap('WallScrew'+str(z),.004,0,.003)
  transform(obj,Matrix.Translation((0,back-.004,z))@Matrix.Rotation(math.pi/2,4,'X'))
  support(identity,'wall',(0,back,z),(0,-1,0),'fitted wall backplate')
 # Connect the source angled bracket to the actual neck, without moving the globe.
 points=[(0,back-.004,0),(0,-.033,-.005),(0,-.058,-.012),(0,-.081,-.020),(0,-.103,-.025),(0,-.115,-.025)]
 wire('CastArm',points,.014,'brass')
 socket('GlobeSocket',(0,-.115,-.028),.038,.016)
 ring('GlobeCollar',0,-.115,.001,.024,.015,.008,'brass')
 globe=shell('OpalGlobe',(0,-.115,.09),.085,.17)
 transform(globe,Matrix.Translation((0,-.115,.09))@Matrix.Rotation(math.pi,4,'X')@Matrix.Translation((0,.115,-.09)))

def linear():
 # Folded enamel trough, closed edge returns and two source tube sockets.
 stock('Spine',(-.36,-.065,-.006),(.36,.065,0),'enamel',.0007)
 for y in [-.065,.062]:stock('Fold'+str(y),(-.36,y,-.05),(.36,y+.003,-.006),'enamel',.0005)
 for x in [-.357,.330]:stock('EndCap'+str(x),(x,-.062,-.05),(x+.027,.062,-.006),'enamel',.0007)
 for x in [-.323,.298]:
  stock('TubeSocket'+str(x),(x,-.027,-.069),(x+.025,.027,-.006),'enamel',.004)
  tube('LampPin'+str(x),(x-.003,0,-.065),(x+.029,0,-.065),.003,'brass')
 component(along_x(identity+'_Tube',0,0,-.065,[(0,-.31),(.018,-.31),(.02,-.308),(.02,.308),(.018,.31),(0,.31)],identity,'bulb'),'Bulb')
 for x in [-.25,.25]:support(identity,'ceiling',(x,0,0),(0,0,-1),'trough back to original ceiling')

def cage():
 ceiling_canopy(.037)
 tube('Drop',(0,0,-.026),(0,0,-.405),.005,'rubber')
 lathe('SocketCap',0,0,-.445,[(0,0),(.06,0),(.057,.006),(.05,.04),(.018,.04),(0,.04)],'iron')
 socket('Insulator',(0,0,-.458),.035,.023)
 shell('PearLamp',(0,0,-.49),.045,.11)
 for i in range(6):
  a=i*math.tau/6
  points=[(math.cos(a)*r,math.sin(a)*r,z) for r,z in [(.051,-.432),(.068,-.451),(.075,-.49),(.065,-.535),(.036,-.565),(0,-.569)]]
  wire('GuardRib'+str(i),points,.004,'iron')
 ring('GuardHoop',0,0,-.494,.079,.071,.008,'iron')

def fruit():
 tube('Stalk',(0,0,.05),(0,0,.15),.008,'brass')
 lathe('Calyx',0,0,.034,[(0,0),(.052,0),(.044,.006),(.03,.028),(0,.028)],'brass')
 shell('OpalFruit',(0,0,-.10),.115,.27)
 support(identity,'original branch',(0,0,.15),(0,0,-1),'fruit stalk at source branch tip')

def street():
 lathe('Shroud',0,0,0,[(0,.070),(.10,.070),(.16,-.030),(.156,-.030),(.096,.066),(0,.066)],'iron')
 ring('LensRetainer',0,0,-.029,.158,.151,.009,'iron')
 profile=[(.154*math.sin(t),-.022-.118*math.cos(t)) for t in np.linspace(math.pi/2,0,49)]
 profile[-1]=(0.,-.140)
 profile.extend((.152*math.sin(t),-.022-.116*math.cos(t)) for t in np.linspace(0,math.pi/2,49));profile[-49]=(0.,-.138);profile.append(profile[0])
 component(lathe('PrismaticLens',0,0,0,profile,'stained'),'Stained')
 socket('LampSocket',(0,0,-.025),.092,.018)
 shell('LampCore',(0,0,-.055),.036,.065)
 support(identity,'retained mast',(0,0,.070),(0,0,-1),'source mast head seat')

def lantern():
 stock('WallPlate',(-.15,-.0225,-.24),(.15,.0225,.20),'brass',.003)
 stock('Bracket',(-.05,-.30,-.04),(.05,0,.08),'brass',.003)
 for y in [-.426,-.216]:component(stock('Pane'+str(y),(-.115,y,-.26),(.115,y+.012,.10),'stained',.0005),'Stained')
 for x in [-.1575,.1325]:
  for y in [-.45,-.205]:stock('Frame'+str((x,y)),(x,y,-.32),(x+.025,y+.025,.16),'brass',.001)
 for z in [-.3225,.1375]:stock('Lintel'+str(z),(-.1325,-.45,z),(.1325,-.18,z+.025),'brass',.001)
 for y in [-.426,-.216]:
  for x in [-.140,.111]:stock('GlazingUpright'+str((x,y)),(x,y-.002,-.298),(x+.029,y+.014,.14),'brass',.0005)
  for z in [-.298,.098]:stock('GlazingRail'+str((z,y)),(-.115,y-.002,z),(.115,y+.014,z+.042),'brass',.0005)
 lathe('WeatherCap',0,-.315,0,[(0,.26),(.070,.26),(.240,.14),(.236,.14),(.069,.256),(0,.256)],'brass')
 for x in [-.12,.12]:tube('RoofTie'+str(x),(x,-.315,.15),(x,-.315,.221),.005,'brass')
 socket('LampSocket',(0,-.315,-.028),.070,.018)
 shell('LampCore',(0,-.315,-.08),.043,.11)
 for x in [-.11,.11]:support(identity,'original facade',(x,.0225,0),(0,-1,0),'lantern backplate wall bearing')

def chandelier():
 # Crown and bowl keep source landmarks; all six candle lamps remain.
 ceiling_canopy(.125)
 cap('CanopyCollar',.058,-.08,.045)
 for ch in range(3):
  a=math.tau*ch/3+.5
  top=Vector((math.cos(a)*.105,math.sin(a)*.105,-.07))
  bottom=Vector((math.cos(a)*.165,math.sin(a)*.165,-.385))
  for i in range(7):
   center=top.lerp(bottom,(i+.5)/7)
   # Alternating oval link planes, separate closed forged stocks.
   points=[]
   lateral=Vector((math.cos(a+(math.pi/2 if i%2 else 0)),math.sin(a+(math.pi/2 if i%2 else 0)),0))
   for theta in np.linspace(0,math.tau,65):points.append(center+lateral*(.017*math.cos(theta))+Vector((0,0,.027*math.sin(theta))))
   wire('Chain'+str((ch,i)),points,.0042,'brass')
  tube('ChainEye'+str(ch),bottom,Vector((math.cos(a)*.165,math.sin(a)*.165,-.410)),.005,'brass')
 ring('CrownUpper',0,0,-.413,.181,.156,.026,'brass')
 lathe('CrownBand',0,0,0,[(.172,-.403),(.15,-.465),(.146,-.465),(.168,-.403),(.172,-.403)],'brass')
 ring('CrownLower',0,0,-.480,.168,.148,.020,'brass')
 for i in range(6):
  a=i*math.tau/6;dx=math.cos(a);dy=math.sin(a)
  wire('CandleArm'+str(i),[(dx*r,dy*r,z) for r,z in [(.165,-.418),(.21,-.42),(.255,-.395),(.28,-.35),(.31,-.30)]],.0105,'brass')
  lathe('Bobeche'+str(i),dx*.31,dy*.31,-.307,[(0,0),(.020,0),(.046,.014),(.043,.014),(.019,.003),(0,.003)],'brass')
  lathe('CandleSleeve'+str(i),dx*.31,dy*.31,-.293,[(0,0),(.021,0),(.019,.09),(0,.09)],'enamel')
  shell('CandleLamp'+str(i),(dx*.31,dy*.31,-.172),.021,.062)
 for i in range(3):
  a=i*math.tau/3+.5
  tube('BowlStrap'+str(i),(math.cos(a)*.16,math.sin(a)*.16,-.480),(math.cos(a)*.330,math.sin(a)*.330,-.556),.0095,'brass')
 # Smooth spun profile replaces the old five separate conical bands.
 profile=[(.340*math.sin(t),-.550-.27*math.cos(t)) for t in np.linspace(math.pi/2,0,49)]
 profile[-1]=(0.,-.82)
 profile.extend((.337*math.sin(t),-.550-.267*math.cos(t)) for t in np.linspace(0,math.pi/2,49))
 profile[-49]=(0.,-.817);profile.append(profile[0])
 component(lathe('OpalBowl',0,0,0,profile,'bulb'),'Bulb')
 ring('BowlRim',0,0,-.563,.358,.332,.026,'brass')
 lathe('Finial',0,0,0,[(0,-.814),(.05,-.820),(.030,-.846),(.030,-.850),(.009,-.894),(0,-.896)],'brass')

recipes={'pendant_shade':pendant,'flush_dome':flush,'sconce_globe':sconce,'kitchen_linear':linear,'cage_bulb':cage,'eye_pendant':fruit,'street_lamp':street,'entry_lantern':lantern,'chandelier':chandelier}
for assembly in assemblies:
 identity=assembly['id'];variant=variants[identity]
 start=len(stock_checks)
 recipes['entry_lantern' if identity=='entry_lantern' else assembly['kind']]()
 rise=float(variant.get('ceiling_rise',0))
 if rise and assembly['kind']!='pendant_shade':
  # Keep the original actor, bulb and lower body heights. Only the fitted
  # suspension stock reaches the retained ceiling above the source anchor.
  component(tube('RigidMount',(0,0,-.024),(0,0,rise-.018),.010,'brass'),'Mount')
  component(lathe('UpperRosette',0,0,rise-.018,[(0,0),(.016,0),(.035,.010),(.045,.013),(.045,.018),(0,.018)],'brass'),'Mount')
  contacts[:]=[c for c in contacts if c['assembly']!=identity or c['owner']!='ceiling']
  for x in variant.get('seat_x',[-.025,.025]):support(identity,'ceiling',(x,0,rise),(0,0,-1),'fitted suspension seat')
 if 'wall_mount' in variant:
  wall=Vector(variant['wall_mount']);direction=Vector(variant.get('wall_direction',wall)).normalized()
  plate=cap('WallRosette',.055,-.004,.004)
  transform(plate,Matrix.Translation(wall)@Vector((0,0,1)).rotation_difference(direction).to_matrix().to_4x4());component(plate,'Mount')
  path=[(0,0,-.018),*variant.get('arm_path',[]),wall-direction*.002]
  component(wire('BracketArm',path,.012,'brass'),'Mount')
  contacts[:]=[c for c in contacts if c['assembly']!=identity]
  for z in [-.035,.035]:support(identity,'wall',wall+Vector((0,0,z)),-direction,'wall rosette fixed to retained fascia or pier')
 # Connectivity and installed bearings are verified separately by family;
 # interlocking chain links must not be unioned into a single solid.
 for obj,key in pieces[identity]:
  if not obj.get('component'):obj['component']='Body'
 if assembly['kind']!='chandelier':group('Fixture',start)
