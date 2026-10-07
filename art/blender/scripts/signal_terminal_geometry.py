"""The existing fixed instrument, in its unchanged actor coordinate frame."""
identity='VantryFixed';frames={identity:{'position':[0,0,0],'yaw':0}};retained_stock=[];construction_groups=[]
def stock(label,lo,hi,key,edge=.001):return box(identity+'_'+label,lo,hi,identity,key,edge)
def turned(label,y,z,profile,key):return along_x(identity+'_'+label,0,y,z,profile,identity,key)
def tube(label,a,b,r,key):return rod(identity+'_'+label,a,b,r,identity,key)
def wire(label,path,r,key):return curved_wire(identity+'_'+label,path,r,identity,key)
stock('Foot',(-.21,-.53,0),(.19,.53,.035),'bakelite',.003)
# A real wooden case, with a thin front instrument sheet and removable back.
stock('Floor',(-.19,-.51,.033),(.19,.51,.048),'wood_dark',.001)
stock('Top',(-.19,-.51,.255),(.19,.51,.270),'wood_dark',.002)
for y in (-.51,.495):stock('Cheek'+str(y),(-.19,y,.047),(.19,y+.015,.256),'wood_dark',.0015)
stock('Back',(-.19,-.496,.048),(-.175,.496,.255),'wood_dark',.001)
stock('Front',(.185,-.47,.0295),(.208,.47,.2545),'brass_dull',.0015)
# The bridge was floating above the cabinet in the primitive source.
for x in (-.16,.05):
 for y in (-.285,.285):stock('BridgePost'+str((x,y)),(x-.01,y-.013,.268),(x+.01,y+.013,.306),'wood_dark',.0008)
stock('Bridge',(-.18,-.31,.2875),(.07,.31,.3425),'wood_dark',.002)
# A fitted cage protects the original three dynamic valve bodies.
for y in (-.27,-.18,.18,.27):
 tube('GuardRoof'+str(y),(-.17,y,.484),(.08,y,.484),.007,'nickel_plated')
 for x in (-.17,.08):tube('GuardPost'+str((x,y)),(x,y,.336),(x,y,.484),.007,'nickel_plated')
for x in (-.17,.08):tube('GuardSpine'+str(x),(x,-.277,.484),(x,.277,.484),.007,'nickel_plated')
for y in (-.20,0,.20):
 # Original ValveBank material still drives these hollow envelopes at runtime.
 vessel(identity+'_ValveSocket'+str(y),.020,y,.337,[(0,0),(.033,0),(.033,.012),(0,.012)],identity,'bakelite')
 vessel(identity+'_ValveGlass'+str(y),.020,y,.348,[(.025,0),(.030,.008),(.030,.070),(.024,.090),(0,.0995),(0,.0975),(.022,.088),(.028,.069),(.028,.008),(.023,0),(.025,0)],identity,'glassish')
 tube('ValveCathode'+str(y),(.020,y,.346),(.020,y,.425),.007,'nickel_plated')
 for dx in (-.012,.012):
  stock('ValvePlate'+str((y,dx)),(.020+dx-.001,y-.015,.357),(.020+dx+.001,y+.015,.420),'nickel_plated',.0005)
  tube('ValvePlateLeg'+str((y,dx)),(.020+dx,y,.348),(.020+dx,y,.359),.0015,'nickel_plated')
# Original scope remains in front of this annular, seated bezel.
turned('ScopeBezel',.255,.165,[(.101,.202),(.119,.202),(.122,.208),(.122,.229),(.118,.236),(.101,.236),(.099,.231),(.099,.207),(.101,.202)],'nickel_plated')
turned('ScopeSeat',.255,.165,[(.0975,.215),(.101,.215),(.101,.225),(.0975,.225),(.0975,.215)],'bakelite')
for y in (-.045,-.265):
 stock('MeterCase'+str(y),(.2035,y-.0875,.1325),(.219,y+.0875,.2475),'bakelite',.002)
 stock('MeterFace'+str(y),(.216,y-.0725,.147),(.224,y+.0725,.237),'brass_dull',.001)
 # Small scale ticks are geometry, not lettering or new indicators.
 for i in range(9):
  angle=-.9+i*.225;cy=y+math.sin(angle)*.060;cz=.165+math.cos(angle)*.063
  stock('MeterTick'+str((y,i)),(.2238,cy-.00065,cz-.0025),(.2248,cy+.00065,cz+.0025),'bakelite',.0001)
for radius,gz in ((.030,-.405),(.041,-.035),(.030,.420)):
 y=-gz
 turned('Knob'+str(gz),y,.078,[(0,.206),(radius*.85,.206),(radius,.210),(radius,.237),(radius*.94,.243),(0,.243)],'bakelite')
 turned('KnobHub'+str(gz),y,.078,[(0,.242),(.004,.242),(.004,.244),(0,.244)],'nickel_plated')
stock('PatchField',(.204,-.390,.020),(.218,-.040,.110),'bakelite',.0015)
for i in range(6):
 y=-(.075+i*.057)
 turned('Jack'+str(i),y,.065,[(.006,.214),(.012,.214),(.012,.232),(.010,.236),(.006,.236),(.006,.214)],'copper_aged')
 # The original primitive field has six empty visible sockets. Preserve that
 # visible stock; its three-occupied comment is not a new cable authority.
# The original carbon handset, with actual supports down to the cabinet top.
for y in (-.32,-.48):stock('CradleSeat'+str(y),(-.045,y-.01,.268),(.005,y+.01,.300),'bakelite',.001)
stock('HandsetGrip',(-.060,-.575,.2875),(.020,-.285,.3425),'bakelite',.006)
for y in (-.31,-.55):
 obj=axial(identity+'_HandsetCup'+str(y),-.020,.315,[(0,y-.029),(.043,y-.029),(.05,y-.018),(.05,y+.016),(.043,y+.029),(0,y+.029)],identity,'bakelite',64)
 # Each cup has a shallow perforated-looking front grille of actual bars.
 for dx in (-.020,-.010,0,.010,.020):
  stock('HandsetGrille'+str((y,dx)),(-.021+dx,y-.030,.297),(-.019+dx,y-.028,.333),'nickel_plated',.0004)
for y in (-.445,.445):
 for z in (.046,.238):
  # Slotted screw head made from two separate seated halves.
  for dz in (-.0023,.0023):stock('PanelScrew'+str((y,z,dz)),(.2078,y-.003,z+dz-.0018),(.211,y+.003,z+dz+.0018),'nickel_plated',.0007)
for x in (-.15,.13):
 for y in (-.45,.45):support(identity,'support',(x,y,0),(0,0,1),'cabinet foot')
construction_groups.append({'assembly':identity,'id':'FixedInstrument','stocks':[s['name'] for s in stock_checks]})
