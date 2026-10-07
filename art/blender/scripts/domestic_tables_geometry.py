"""Source-fitted table variants, keeping the actual current support heights."""
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]

def stock(label,lo,hi,key='wood_dark',edge=.0015):
 return box(identity+'_'+label,lo,hi,identity,key,edge)

def lathe(label,x,y,z,profile,key):
 return vessel(identity+'_'+label,x,y,z,profile,identity,key)

def bearing(label,x,y):support(identity,'support',(x,y,0),(0,0,1),label)

def rect_table(p):
 length=p['length'];depth=p['depth'];top=p['top']
 stock('Worktop',(-length/2,-depth/2,.7),(length/2,depth/2,.745),top,.0025)
 for side in [-1,1]:
  yy=side*(depth/2-.084)
  stock('ApronLong'+str(side),(-length/2+.07,yy-.014,.62),(length/2-.07,yy+.014,.701))
  xx=side*(length/2-.084)
  stock('ApronEnd'+str(side),(xx-.014,-depth/2+.07,.62),(xx+.014,depth/2-.07,.701))
 for i,x in enumerate([-length/2+.10,length/2-.10]):
  for j,y in enumerate([-depth/2+.10,depth/2-.10]):
   lathe('TurnedLeg%d%d'%(i,j),x,y,0,[(0,0),(.033,0),(.034,.002),(.026,.10),(.040,.155),(.024,.48),(.032,.60),(.038,.621),(0,.621)],'wood_dark')
   bearing('turned leg%d%d'%(i,j),x,y)
 retained_stock.append({'assembly':identity,'kind':'table_rect','length':length,'depth':depth,'worktop':.745})

def round_table(p):
 lathe('Pedestal',0,0,0,[(0,0),(.268,0),(.27,.002),(.24,.02),(.075,.10),(.042,.42),(.05,.64),(.11,.685),(0,.685)],'trim')
 lathe('RoundWorktop',0,0,0,[(0,.685),(.50,.685),(.55,.7),(.55,.725),(.50,.735),(0,.735)],p['top'])
 for i in range(4):bearing('pedestal quarter '+str(i),.15*math.cos(i*math.tau/4),.15*math.sin(i*math.tau/4))
 retained_stock.append({'assembly':identity,'kind':'table_round','radius':.55,'worktop':.735})

def nightstand(p):
 wood=p['wood']
 for i,x in enumerate([-.17,.17]):
  for j,y in enumerate([-.15,.15]):
   lathe('Foot%d%d'%(i,j),x,y,0,[(0,0),(.019,0),(.020,.002),(.014,.121),(0,.121)],wood)
   bearing('nightstand foot%d%d'%(i,j),x,y)
 stock('Floor',(-.225,-.21,.12),(.225,.21,.136),wood)
 stock('Worktop',(-.225,-.21,.50),(.225,.21,.52),wood,.002)
 stock('Back',(-.225,-.21,.132),(.225,-.194,.505),wood)
 for sign in [-1,1]:stock('Side'+str(sign),(sign*.217-.008,-.2,.132),(sign*.217+.008,.21,.505),wood)
 stock('LowerFront',(-.210,.194,.135),(.210,.214,.299),wood)
 for sign in [-1,1]:stock('DrawerRunner'+str(sign),(sign*.207-.009,-.195,.286),(sign*.207+.009,.206,.303),wood,.0007)
 stock('DrawerFace',(-.20,.210,.30),(.20,.225,.47),wood,.0015)
 stock('DrawerBottom',(-.202,-.185,.302),(.202,.215,.313),wood,.0008)
 stock('DrawerBack',(-.202,-.187,.310),(.202,-.174,.459),wood,.0008)
 for sign in [-1,1]:stock('DrawerSide'+str(sign),(sign*.196-.006,-.181,.31),(sign*.196+.006,.215,.461),wood,.0008)
 stock('UpperRail',(-.210,.195,.476),(.210,.213,.507),wood,.0008)
 axial(identity+'_DrawerKnob',0,.39,[(0,.224),(.006,.224),(.006,.235),(.012,.238),(.012,.243),(.006,.246),(0,.246)],identity,'brass',48)
 # Source paperback, seated on the cabinet and kept within its original extent.
 stock('BookLowerCover',(-.14,-.10,.52),(.02,.01,.5212),'paper',.0002)
 stock('BookPages',(-.139,-.099,.5212),(.019,.0088,.5538),'paper',.0003)
 stock('BookUpperCover',(-.14,-.10,.5538),(.02,.01,.555),'paper',.0002)
 stock('BookSpine',(-.14,.0085,.5205),(.02,.01,.5545),'paper',.0002)
 lathe('DrinkingGlass',.10,.06,.52,[(0,0),(.033,0),(.035,.002),(.030,.103),(.029,.105),(.027,.104),(.028,.008),(.026,.004),(0,.004)],'glassish')
 retained_stock.append({'assembly':identity,'kind':'nightstand','cabinet_top':.52,'book_top':.555,'glass_top':.625})

def coffee(p):
 low=p['glass_low'];high=p['glass_high']
 for label,a,b,width in [('Left',(-.30,-.10,0),(.18,.13,low),.30),('Right',(.28,-.07,0),(-.14,.15,low),.26)]:
  a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=Vector((0,0,1)).cross(axis).normalized()*width/2;v=axis.cross(u.normalized())*.045/2
  vertices=[q+su*u+sv*v for q in [a,b] for su,sv in [(-1,-1),(1,-1),(1,1),(-1,1)]]
  for q in vertices[:4]:q.z=0
  for q in vertices[4:]:q.z=low
  obj=solid(identity+'_SawnFin'+label,vertices,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],identity,'wood_dark')
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Eased fin edges','BEVEL');mod.width=.0007;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  for i,t in enumerate([-.6,0,.6]):bearing(label+' keel '+str(i),a.x+t*u.x,a.y+t*u.y)
 glass=lathe('EllipticalGlass',0,0,0,[(0,low),(.549,low),(.55,low+.001),(.55,high-.001),(.549,high),(0,high)],'glassish')
 # Original sx=.62 applies to X; preserve the source ellipse and top datum.
 for vertex in glass.data.vertices:vertex.co.x*=.62
 glass.location.x*=.62
 del glass['uv_axis'];del glass['uv_center']
 retained_stock.append({'assembly':identity,'kind':'coffee','glass_low':low,'glass_high':high,'ellipse_radii':[.341,.55],'source_keels_cut_to_bearing_planes':True})

recipes={'table_rect':rect_table,'table_round':round_table,'nightstand':nightstand,'coffee':coffee}
for item in assemblies:
 identity=item['id'];start=len(stock_checks);recipes[item['kind']](variants[identity]['params'])
 construction_groups.append({'assembly':identity,'id':identity+'_JoinedTable','stocks':[x['name'] for x in stock_checks[start:]]})
