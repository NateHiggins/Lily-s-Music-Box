"""Fired-enamel range: source dimensions, supported racks and service owners."""
import ast
from mathutils import Matrix
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','transform','ring'}],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]
def owner(obj,name):obj['component']=name;return obj

def screw(label,x,y,z,key='nickel',part='Body'):
 # Two slightly rounded semicircular heads leave a real recessed slot.
 for side in [-1,1]:
  pp=[(x+.0035*math.cos(a),z+.0035*math.sin(a)) for a in np.linspace(.12,math.pi-.12,17)]
  if side<0:pp=[(px,2*z-pz) for px,pz in pp]
  n=len(pp);v=[(px,q,pz) for q in [y-.001,y+.001] for px,pz in pp]
  owner(solid(identity+'_'+label+str(side),v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key),part)

def hinge(label,x,y,z,part):
 # A physical fixed pin and two annular moving knuckles share the source axis.
 tube(label+'_Pin',(x-.040,y,z),(x+.040,y,z),.0035,'iron')
 stock(label+'_FixedNeck',(x-.009,y-.029,z-.009),(x+.009,y,z+.007),'iron',.0008)
 for xx in [x-.027,x+.027]:
  profile=[(.008,xx-.009),(.008,xx+.009),(.0035,xx+.009),(.0035,xx-.009),(.008,xx-.009)]
  owner(along_x(identity+'_'+label+'_Knuckle'+str(xx),0,y,z,profile,identity,'iron'),part)
  owner(stock(label+'_LeafNeck'+str(xx),(xx-.009,y-.002,z+.004),(xx+.009,y+.011,z+.017),'iron',.001),part)

def body():
 for x in [-.275,.275]:
  for y in [-.245,.245]:
   lathe('Foot'+str((x,y)),x,y,0,[(0,0),(.017,0),(.021,.002),(.022,.008),(.016,.018),(.018,.13),(.023,.165),(.023,.170),(0,.170)],'iron')
   bearing('original range foot',(x,y,0))
 for y in [-.245,.245]:tube('FootRail'+str(y),(-.275,y,.105),(.275,y,.105),.011,'dark')
 # Pressed skins with returned edges expose their real thickness at the back.
 stock('Base',(-.32,-.30,.170),(.32,.30,.2175),ENAMEL,.004)
 for s in [-1,1]:
  x=s*.3185
  stock('SideSkin'+str(s),(x-.0015,-.30,.2175),(x+.0015,.30,.844),ENAMEL,.001)
  lo,hi=sorted([s*.2545,s*.317])
  for z in [.2175,.835]:stock('SideReturn'+str((s,z)),(lo,-.30,z),(hi,.30,z+.009),ENAMEL,.001)
  for y in [-.30,.285]:stock('SideEdge'+str((s,y)),(lo,y,.2265),(hi,y+.015,.835),ENAMEL,.0015)
  # Inner load frame meets the oven mouth and the raised deck.
  stock('Frame'+str(s),(s*.241-.011,-.265,.2175),(s*.241+.011,.285,.838),'dark',.0015)
 stock('DeckRim',(-.32,-.30,.844),(.32,.30,.872),ENAMEL,.003)
 stock('HobTray',(-.30,-.28,.872),(.30,.28,.877),'dark',.001)
 # Upper face and lower rail surround the source hollow oven, not a black decal.
 stock('UpperFascia',(-.2545,.263,.697),(.2545,.293,.835),ENAMEL,.003)
 stock('LowerFascia',(-.2545,.263,.309),(.2545,.293,.333),'dark',.001)
 # Full liner mouth reaches the original door heat shield without crossing it.
 stock('OvenBack',(-.220,-.258,.349),(.220,-.232,.671),'dark',.001)
 for x in [-.229,.220]:stock('OvenSide'+str(x),(x,-.232,.349),(x+.009,.284,.671),'iron',.001)
 for z in [.331,.671]:stock('OvenShelf'+str(z),(-.229,-.258,z),(.229,.284,z+.018),'iron',.001)
 for x in [-.222,.207]:stock('RackSlide'+str(x),(x,-.214,.475),(x+.015,.219,.484),'iron',.0007)
 for y in [-.19,.20]:tube('OvenRackCross'+str(y),(-.210,y,.487),(.211,y,.487),.003,'nickel')
 for i,x in enumerate(np.linspace(-.19,.19,17)):tube('OvenRackWire'+str(i),(x,-.195,.492),(x,.205,.492),.003,'nickel')
 # Closed broiler chamber remains a passive original door owner.
 stock('BroilerBack',(-.22,-.258,.2175),(.22,-.243,.307),'dark',.001)
 stock('BroilerFloor',(-.22,-.25,.2175),(.22,.298,.2295),'iron',.001)
 for x in [-.229,.220]:stock('BroilerSide'+str(x),(x,-.258,.2295),(x+.009,.298,.309),'iron',.001)
 stock('BackSplash',(-.305,-.296,.872),(.305,-.268,1.1225),ENAMEL,.004)
 stock('CondimentShelf',(-.31,-.315,1.113),(.31,-.095,1.139),ENAMEL,.003)
 # Two returns connect the retained guard rail to its shelf.
 for x in [-.27,.27]:tube('ShelfRailPost'+str(x),(x,-.095,1.133),(x,-.095,1.145),.008,'brass')
 tube('ShelfRail',(-.27,-.095,1.145),(.27,-.095,1.145),.008,'brass')
 tube('GasRail',(-.275,.323,.785),(.275,.323,.785),.012,'brass')
 for x in [-.26,.26]:
  stock('GasRailBracket'+str(x),(x-.015,.287,.768),(x+.015,.326,.802),'iron',.0015)
  screw('GasRailFixing'+str(x),x,.327,.776)

def doors():
 part='OvenDoor'
 owner(stock('OvenSkin',(-.22,.302,.352),(.22,.334,.68),OVEN_ENAMEL,.004),part)
 owner(stock('OvenHeatShield',(-.1975,.286,.3625),(.1975,.302,.6575),'iron',.002),part)
 owner(stock('OvenPressedPanel',(-.1825,.334,.375),(.1825,.343,.63),OVEN_ENAMEL,.006),part)
 for x in [-.16,.16]:hinge('OvenHinge'+str(x),x,.318,.34,part)
 for x in [-.1892,.1892]:
  owner(axial(identity+'_OvenHandleFoot'+str(x),x,.645,[(0,.333),(.015,.333),(.015,.343),(.010,.369),(0,.369)],identity,'brass',48),part)
 owner(tube('OvenHandle',(-.19,.370,.645),(.19,.370,.645),.010,'brass'),part)
 part='BroilerDrawer'
 owner(stock('BroilerSkin',(-.22,.302,.217),(.22,.330,.30),ENAMEL,.003),part)
 for x in [-.15,.15]:hinge('BroilerHinge'+str(x),x,.316,.205,part)
 owner(stock('BroilerInset',(-.095,.330,.2475),(.095,.339,.2725),'dark',.002),part)
 # The original lower leaf has no user actuator; retain its owner and pose.
 for x in [-.13,.13]:
  owner(stock('BroilerFastener'+str(x),(x-.007,.294,.236),(x+.007,.304,.269),'iron',.001),part)
  screw('BroilerScrew'+str(x),x,.331,.253,'nickel',part)

def controls():
 for i in range(5):
  part='BurnerValve'+str(i+1) if i<4 else 'OvenValve';x=-.235+i*.1175
  owner(axial(identity+'_'+part+'_Stem',x,.785,[(0,.318),(.009,.318),(.009,.350),(0,.350)],identity,'brass',48),part)
  owner(axial(identity+'_'+part+'_Grip',x,.785,[(0,.340),(.020,.340),(.026,.345),(.026,.352),(.023,.359),(.020,.361),(0,.361)],identity,'bakelite',64),part)
  owner(stock(part+'_Pointer',(x-.005,.358,.784),(x+.005,.372,.822),'brass',.0015),part)

def burners():
 for i,(x,y) in enumerate([(-.17,.13),(.17,.13),(-.17,-.14),(.17,-.14)]):
  part='Grate'+str(i+1)
  # Open fingers leave the serviceable cap unobstructed, with a 0.90 m top.
  owner(ring(part+'_Rim',x,y,.888,.116,.096,.012,'iron'),part)
  for k in range(8):
   theta=k*math.tau/8;u=Vector((math.cos(theta),math.sin(theta),0));v=Vector((-u.y,u.x,0));verts=[]
   for z in [.890,.900]:
    for radius in [.069,.101]:
     for side in [-.006,.006]:verts.append(Vector((x,y,z))+u*radius+v*side)
   owner(solid(identity+'_'+part+'_Finger'+str(k),verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,'iron'),part)
  for a in [math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4]:
   xx=x+.105*math.cos(a);yy=y+.105*math.sin(a)
   owner(lathe(part+'_Foot'+str(a),xx,yy,.877,[(0,0),(.007,0),(.007,.012),(0,.012)],'iron'),part)
  part='BurnerCap'+str(i+1)
  owner(lathe(part+'_Head',x,y,.877,[(0,0),(.064,0),(.069,.002),(.069,.005),(.063,.007),(.052,.008),(0,.008)],'dark'),part)
  owner(ring(part+'_PortCrown',x,y,.884,.060,.051,.004,'iron'),part)
  # Cast radial ridges express individual ports without a painted black ring.
  for a in np.linspace(0,math.tau,32,endpoint=False):
   p=Vector((x,y,.887));u=Vector((math.cos(a),math.sin(a),0))
   owner(tube(part+'_Port'+str(a),p+u*.055,p+u*.064,.0013,'iron'),part)

def wear():
 # Dossier slice 36: owner wear expressed in geometry over the tinted enamel.
 if identity=='HouseholdGasRangePaintFlecked':
  rng=np.random.default_rng(1928)
  for i in range(24):
   key=['paint_ochre','paint_viridian','paint_white'][i%3];x=float(rng.uniform(-.27,.27));y=float(rng.uniform(-.25,.25));s=float(rng.uniform(.004,.009))
   if abs(abs(x)-.17)<.12 and abs(abs(y)-.135)<.12:continue
   stock('FleckHob'+str(i),(x-s,y-s,.8766),(x+s,y+s,.8774),key,.0003)
  for i in range(12):
   key=['paint_ochre','paint_viridian','paint_white'][i%3];x=float(rng.uniform(-.24,.24));z=float(rng.uniform(.705,.83));s=float(rng.uniform(.003,.007))
   stock('FleckFascia'+str(i),(x-s,.2926,z-s),(x+s,.2934,z+s),key,.0003)
  for i in range(8):
   key=['paint_ochre','paint_viridian','paint_white'][i%3];x=float(rng.uniform(-.29,.29));z=float(rng.uniform(.9,1.1));s=float(rng.uniform(.004,.009))
   stock('FleckSplash'+str(i),(x-s,-.2684,z-s),(x+s,-.2676,z+s),key,.0003)
  # Colour at the control zone, where the knobs are turned with painted hands.
  for i,x in enumerate([-.2,-.09,.07,.18]):
   stock('ThumbPrint'+str(i),(x-.013,.2926,.755),(x+.013,.2934,.775),['paint_ochre','paint_viridian'][i%2],.0003)
  # One cold burner is the brush-drying rack: a tin of brushes on the back-left grate.
  lathe('BrushTin',-.17,-.14,.8995,[(0,0),(.04,0),(.042,.004),(.042,.12),(.044,.125),(0,.125)],'nickel')
  for j,(dx,dy) in enumerate([(-.012,-.01),(.014,.006),(-.004,.016),(.01,-.014)]):
   tube('BrushHandle'+str(j),(-.17+dx,-.14+dy,.95),(-.17+dx*1.8,-.14+dy*1.8,1.1),.0045,'bakelite')
   tube('BrushHead'+str(j),(-.17+dx*1.8,-.14+dy*1.8,1.098),(-.17+dx*1.9,-.14+dy*1.9,1.13),.006,'dark')
 elif identity=='HouseholdGasRangePot':
  # Dossier slice 44 (F02_B_KITCHEN-003): Lena's borrowed-family stock pot on 2B's one lit ring
  # (burner 4, back right, the ring the marker keeps low), lid on, its two loop handles.
  x,y=.17,-.14
  lathe('StockPot',x,y,.8995,[(0,0),(.11,0),(.115,.005),(.115,.15),(.12,.155),(.12,.16),(.113,.16),(.111,.155),(0,.155)],'enamel_pot')
  lathe('PotLid',x,y,.8995+.155,[(0,0),(.116,0),(.118,.004),(.1,.016),(.02,.024),(.02,.036),(0,.036)],'enamel_pot')
  for side in [-1,1]:tube('PotHandle'+str(side),(x+side*.108,y,.8995+.135),(x+side*.142,y,.8995+.135),.007,'nickel')
 elif identity in ['HouseholdGasRangeGreasy','HouseholdGasRangeGreasyTapes']:
  # Slice 37: a taller tide line and wider prints, so the grease reads at the kitchen's detail distance.
  stock('TideLine',(-.25,.2925,.69),(.25,.2935,.72),'grime',.0004)
  for i,x in enumerate([-.2,-.08,.06,.19]):stock('Fingerprint'+str(i),(x-.018,.2925,.755),(x+.018,.2935,.795),'grime',.0003)
  for i,(x,z) in enumerate([(-.18,.95),(-.05,.99),(.1,.93),(.2,1.02)]):stock('Spatter'+str(i),(x-.03,-.2684,z-.012),(x+.03,-.2676,z+.012),'grime',.0003)
 elif identity=='HouseholdGasRangeWorkshop':
  for i,(x,z) in enumerate([(-.2,.82),(.0,.81),(.19,.825)]):stock('Tape'+str(i),(x-.04,.2925,z-.008),(x+.04,.2935,z+.008),'tape_residue',.0003)
  for i,(x,z) in enumerate([(-.2,1.06),(.15,1.0)]):stock('TapeBack'+str(i),(x-.05,-.2684,z-.009),(x+.05,-.2676,z+.009),'tape_residue',.0003)


def tapes():
 if identity!='HouseholdGasRangeGreasyTapes':return
 # Dossier slice 44 (F02_C_KITCHEN-003): Juno's tape boxes stacked on the cold front-left ring,
 # the side she never cooks on. Plain reel boxes, no lettering.
 for i,(dx,dy) in enumerate([(0,0),(.006,-.004),(-.004,.005),(.003,.002)]):
  z=.8995+i*.0218
  stock('TapeBox'+str(i),(-.26+dx,.04+dy,z),(-.08+dx,.22+dy,z+.022),'tapebox',.0012)

FINISH={'HouseholdGasRangePristine':('enamel_pristine','enamel_pristine'),'HouseholdGasRangeGreasy':('enamel_greasy','enamel_greasy'),'HouseholdGasRangeGreasyTapes':('enamel_greasy','enamel_greasy'),
        'HouseholdGasRangeWorkshop':('enamel_workshop','enamel_mismatch'),'HouseholdGasRangePaintFlecked':('enamel_paint','enamel_paint')}
for variant in plan['variants']:
 identity=variant['id'];start=len(stock_checks)
 ENAMEL,OVEN_ENAMEL=FINISH.get(identity,('enamel','enamel'))
 body();doors();controls();burners();wear();tapes();group('GasRange',start)
