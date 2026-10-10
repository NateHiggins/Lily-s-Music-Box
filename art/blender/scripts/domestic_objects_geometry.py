"""Household and studio objects retain their original counts and passive roles."""
import ast
from mathutils import Matrix
source_script=ROOT/'art/blender/scripts/build_orison.py';tree=ast.parse(source_script.read_text(encoding='utf-8'));original={'math':math,'GARDEN':()}
functions={'hash_str','_jit','_plant_pot','_plant_species',*('asm_'+kind for kind in ['pinboard','toolboard','crate','reeldeck','plant','bookpile','tripod','softbox','cablecoil'])}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in functions],type_ignores=[]),str(source_script),'exec'),original)
# Reuse the accepted native stock helpers without executing another recipe.
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';helper_tree=ast.parse(helper_path.read_text(encoding='utf-8'))
helpers={'stock','lathe','tube','wire','bearing','group','transform','ring','book','books'}
exec(compile(ast.Module(body=[n for n in helper_tree.body if isinstance(n,ast.FunctionDef) and n.name in helpers or isinstance(n,ast.ClassDef) and n.name=='Collector'],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]

def wall_mount(source,width,height):
 back=variants[identity]['rear_wall_y']
 if back>=-.025:
  for x in [-width*.35,width*.35]:stock('RearBatten'+str(x),(x-.018,back,.04),(x+.018,.001,height-.04),'wood_dark',.0005)
 else:
  for x in [-width*.35,width*.35]:
   stock('WallRail'+str(x),(x-.020,back,.04),(x+.020,back+.003,height-.04),'metal',.0004)
   for z in [.08,height-.08]:tube('Standoff'+str((x,z)),(x,back+.002,z),(x,.002,z),.006,'metal')
 for x in [-width*.35,width*.35]:
  for z in [.08,height-.08]:support(identity,'wall',(x,back,z),(0,1,0),'retained wall face behind fitted spacer')

def pinboard(source,collected):
 start=len(stock_checks);width=source.get('W',.9);height=source.get('H',.6)
 stock('Back',(-width/2,0,0),(width/2,.016,height),'wood_dark',.0008)
 stock('PinField',(-width/2+.029,.015,.029),(width/2-.029,.026,height-.029),'timber',.0006)
 for x in [-width/2,width/2-.025]:stock('FrameStile'+str(x),(x,.012,0),(x+.025,.029,height),'wood_dark',.001)
 for z in [0,height-.025]:stock('FrameRail'+str(z),(-width/2+.024,.012,z),(width/2-.024,.029,z+.025),'wood_dark',.001)
 wall_mount(source,width,height);papers=[]
 for i,(_,args,_) in enumerate([r for r in collected if r[0]=='box' and r[1][0]=='paper']):
  _,x0,y0,z0,x1,y1,z1=args;front=max(.027,y1)
  for prior in papers:
   if x0<prior[2] and x1>prior[0] and z0<prior[3] and z1>prior[1]:front=max(front,prior[4]+.0008)
  papers.append((x0,z0,x1,z1,front))
  stock('Card'+str(i),(x0,front-.0006,z0),(x1,front,z1),'paper',.00008)
  x=(x0+x1)/2;z=z1-.006
  # Original cards become actual thin sheets held at one visible pin.
  obj=axial(identity+'_CardPin'+str(i),x,z,[(0,.021),(.001,.021),(.001,front+.001),(.0025,front+.001),(.0025,front+.0022),(0,front+.0022)],identity,'brass',24)
  retained_stock.append({'assembly':identity,'kind':'pinned_card','index':i,'source_args':args,'native_front':front})
 if source.get('route'):
  # Dossier slice 42 (F04_C_MAIN-004): Cam's route by movement, a red thread pinned across the board
  # with ticket stubs at the stops. No lettering.
  stops=[(-.42,.62),(-.25,.55),(-.1,.6),(.05,.42),(.2,.47),(.35,.3),(.42,.15)]
  wire('RouteThread',[(x,.0265,z) for x,z in stops],.0012,'wool_burgundy')
  for i,(x,z) in enumerate(stops):
   if i%2==0:stock('TicketStub'+str(i),(x-.025,.0258,z-.015),(x+.025,.0272,z+.015),'paper',.0001)
 group('PinnedBoard',start)

def crate(source,collected):
 start=len(stock_checks)
 for i,(shape,args,_) in enumerate(collected):
  if shape!='box':continue
  key,*values=args;lo=values[:3];hi=values[3:]
  if key=='timber':stock('CrateSlat'+str(i),lo,hi,key,.001)
  else:
   # The one undifferentiated gear mass becomes three closed passive housings
   # seated within its same envelope. It remains one non-inventory source.
   x0,y0,z0=lo;x1,y1,z1=hi;step=(z1-z0)/3
   for j in range(3):
    z=z0+j*step
    stock('StoredCase'+str(j),(x0+.002*(j%2),y0,z),(x1-.002*(j%2),y1,z+step),key,.002)
    stock('CaseBand'+str(j),(x0+.001,y0-.0005,z+step*.68),(x1-.001,y0+.0007,z+step*.68+.0015),'metal',.0002)
   retained_stock.append({'assembly':identity,'kind':'source_gear_mass','source_args':args,'native_passive_housings':3})
 width=source.get('W',.42);depth=source.get('D',.35)
 for x in [-width*.35,width*.35]:
  for y in [-depth*.35,depth*.35]:bearing('crate base',(x,y,0))
 group('SlattedCrate',start)

def cablecoil(source):
 start=len(stock_checks);radius=source.get('r',.11)
 # One continuous open cable, with two ends; the V1 torus plus attached rod
 # was a T junction rather than a usable lead. Keep radius and tail endpoint.
 angles=sorted(set([.55,*np.linspace(.55,math.tau,193),math.pi/2,math.pi,3*math.pi/2]))
 path=[(radius*math.cos(t),radius*math.sin(t),.010+.010*math.sin(2*t)**2) for t in angles]
 end=(radius+original['_jit'](source['id'],1,.18,.30),original['_jit'](source['id'],2,-.15,.15),.010)
 controls=[Vector(path[-1]),Vector((radius,.07,.010)),Vector((end[0]-.05,end[1],.010)),Vector(end)]
 path.extend(tuple((1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3]) for t in np.linspace(0,1,49)[1:])
 wire('ContinuousLead',path,.010,'rubber_aged')
 for angle in (0,math.pi/2,math.pi,3*math.pi/2):bearing('coil floor contact '+str(angle),(radius*math.cos(angle),radius*math.sin(angle),0))
 bearing('tail floor contact',(*path[-3][:2],0));group('Cable',start)

def flat_stock(label,outline,y0,y1,key):
 n=len(outline);verts=[(x,y,z) for y in [y0,y1] for x,z in outline]
 return solid(identity+'_'+label,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)

def toolboard(source):
 start=len(stock_checks);width=source.get('W',1.05);height=source.get('H',.7)
 stock('PlywoodBack',(-width/2,0,0),(width/2,.018,height),'plywood',.001)
 wall_mount(source,width,height)
 for i in range(5):
  x=-width/2+.10+i*(width-.55)/4;length=original['_jit'](source['id'],i,.15,.24);bottom=height-.10-length;eye=height-.110
  # Forged shank, open jaw and a real hanging eye retain the original row.
  flat_stock('WrenchShank'+str(i),[(x-.006,bottom+.002),(x+.006,bottom+.002),(x+.005,eye-.007),(x-.005,eye-.007)],.021,.029,'metal')
  outline=[(x+.017*math.cos(a),bottom-.010+.017*math.sin(a)) for a in np.linspace(-math.pi/3,4*math.pi/3,51)]
  outline.extend((x+.009*math.cos(a),bottom-.010+.009*math.sin(a)) for a in np.linspace(4*math.pi/3,-math.pi/3,51))
  flat_stock('WrenchJaw'+str(i),outline,.021,.029,'metal')
  axial(identity+'_WrenchEye'+str(i),x,eye,[(.003,.021),(.010,.021),(.010,.029),(.003,.029),(.003,.021)],identity,'metal',48)
  axial(identity+'_WrenchPeg'+str(i),x,eye+.0005,[(0,.013),(.0025,.013),(.0025,.032),(.005,.032),(.005,.034),(0,.034)],identity,'brass',48)
  retained_stock.append({'assembly':identity,'kind':'source_wrench','index':i,'source_length':length})
 hx=width/2-.22
 stock('HammerHandle',(hx-.012,.018,height-.38),(hx+.012,.032,height-.10),'timber',.004)
 head=along_x(identity+'_HammerHead',hx,.027,height-.120,[(0,-.055),(.019,-.055),(.024,-.050),(.021,-.033),(.020,.030),(.014,.046),(.009,.055),(0,.055)],identity,'metal')
 for v in head.data.vertices:v.co.y*=.54
 # This forged oval is no longer a circular lathe. Use metric face charts.
 del head['uv_axis'];del head['uv_center']
 wire('HammerCradle',[(hx-.035,.015,height-.148),(hx-.035,.027,height-.148),(hx+.035,.027,height-.148),(hx+.035,.015,height-.148)],.003,'metal')
 cx=width/2-.09;cz=height-.44
 coil=torus(identity+'_CordLoop',(0,0,0),.055,.055,.009,identity,'rubber_aged');transform(coil,Matrix.Translation((cx,.030,cz))@Matrix.Rotation(math.pi/2,4,'X'))
 axial(identity+'_CordPeg',cx,cz+.0435,[(0,.012),(.0025,.012),(.0025,.038),(.005,.038),(.005,.040),(0,.040)],identity,'brass',48)
 group('SupportedToolboard',start)

def reeldeck(source):
 start=len(stock_checks)
 stock('PanBottom',(-.24,-.17,0),(.24,.17,.004),'metal',.001)
 for x in [-.24,.236]:stock('PanSide'+str(x),(x,-.17,.003),(x+.004,.17,.099),'metal',.0007)
 for y in [-.17,.166]:stock('PanEnd'+str(y),(-.237,y,.003),(.237,y+.004,.099),'metal',.0007)
 for x in [-.240,.231]:stock('DeckBearing'+str(x),(x,-.16,.091),(x+.009,.16,.097),'metal',.0005)
 stock('Deck',(-.235,-.165,.096),(.235,.165,.105),'bakelite',.001)
 for i,x in enumerate([-.115,.115]):
  lathe('ReelBase'+str(i),x,.03,.105,[(0,0),(.099,0),(.1,.0005),(.1,.002),(.03,.002),(.03,.010),(0,.010)],'soot')
  ring('TapePack'+str(i),x,.03,.107,.096,.032,.008,'rubber_aged')
  ring('ReelOuter'+str(i),x,.03,.115,.100,.088,.002,'soot')
  ring('ReelCentre'+str(i),x,.03,.115,.041,.026,.002,'soot')
  for j in range(3):
   a=j*math.tau/3;u=Vector((math.cos(a),math.sin(a)));v=Vector((-u.y,u.x));center=Vector((x,.03))
   outline=[center+u*rr+v*ww for rr,ww in [(.038,-.006),(.095,-.006),(.095,.006),(.038,.006)]]
   prism(identity+'_ReelSpoke'+str((i,j)),outline,.115,.117,identity,'soot',.0003)
  lathe('ReelBoss'+str(i),x,.03,.117,[(0,0),(.028,0),(.030,.001),(.030,.004),(.025,.007),(0,.007)],'enamel')
  lathe('Spindle'+str(i),x,.03,.123,[(0,0),(.006,0),(.006,.003),(.004,.004),(0,.004)],'metal')
 stock('HeadBlock',(-.055,-.135,.105),(.055,-.085,.135),'metal',.001)
 for x in [-.063,.063]:lathe('Guide'+str(x),x,-.117,.105,[(0,0),(.006,0),(.006,.018),(.004,.02),(0,.02)],'metal')
 # Thin closed tape strip follows the retained head block between the reels.
 path=[(-.115,-.066),(-.077,-.098),(-.067,-.119),(-.054,-.1351),(.054,-.1351),(.067,-.119),(.077,-.098),(.115,-.066)]
 verts=[]
 for i,p in enumerate(path):
  tangent=(Vector(path[min(i+1,len(path)-1)])-Vector(path[max(i-1,0)])).normalized();normal=Vector((-tangent.y,tangent.x))
  for z,offset in [(.108,-.0001),(.114,-.0001),(.114,.0001),(.108,.0001)]:
   xy=Vector(p)+normal*offset;verts.append((xy.x,xy.y,z))
 faces=[(3,2,1,0),tuple(range((len(path)-1)*4,len(path)*4))]
 for i in range(len(path)-1):faces.extend((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for j in range(4))
 solid(identity+'_TapePath',verts,faces,identity,'rubber_aged')
 for i,x in enumerate([-.16,.16]):
  stock('MeterFace'+str(i),(x-.028,-.15,.105),(x+.028,-.10,.106),'paper',.0002)
  frame(identity+'_MeterRim'+str(i),x-.030,-.152,x+.030,-.098,.105,.108,.003,identity,'metal')
  # Geometric ticks and pointers have no numbers or generated lettering.
  for j in range(5):stock('MeterTick'+str((i,j)),(x-.021+j*.01,-.115,.106),(x-.020+j*.01,-.106,.1065),'soot',.00005)
  stock('MeterPointer'+str(i),(x-.0005,-.143,.106),(x+.0005,-.115,.1067),'soot',.00005)
 for i,x in enumerate([-.06,0,.06]):lathe('Control'+str(i),x,-.045,.105,[(0,0),(.010,0),(.010,.013),(.008,.017),(0,.017)],'bakelite')
 for x in [-.18,.18]:
  for y in [-.12,.12]:bearing('retained coffee-table bearing',(x,y,0))
 group('PassiveReelDeck',start)

def plant(source,collected):
 start=len(stock_checks);s=1.35 if source.get('big') else 1.;soil_z=.372*s;cane=.62*s
 assert source.get('species')=='rubber','retain the source species explicitly'
 lathe('Saucer',0,0,0,[(r*s,z*s) for r,z in [(0,0),(.150,0),(.168,.010),(.166,.020),(.158,.032),(.148,.032),(.150,.013),(0,.013)]],'terracotta')
 lathe('ThrownPot',0,0,0,[(r*s,z*s) for r,z in [(0,.012),(.105,.012),(.148,.055),(.175,.290),(.178,.302),(.196,.314),(.198,.352),(.180,.360),(.160,.350),(.155,.320),(.150,.290),(.098,.027),(0,.027)]],'terracotta')
 lathe('Soil',0,0,0,[(r*s,z*s) for r,z in [(0,.027),(.098,.027),(.150,.290),(.155,.320),(.158,.335),(.118,.360),(.045,.374),(0,.378)]],'soil')
 # The V1 cylinder supplies height and six leaf nodes, not a sawn timber pole.
 # A taper and slight curve keep those nodes on one living stem.
 def stem(t):return Vector((s*(.014*t+.008*math.sin(t*math.pi)),s*.010*t*t,soil_z+cane*t))
 verts=[];n=32;sections=25
 for j in range(sections):
  t=j/(sections-1);p=stem(t);radius=s*(.010*(1-t)+.0025*t)
  verts.extend(p+Vector((radius*math.cos(i*math.tau/n),radius*math.sin(i*math.tau/n),0)) for i in range(n))
 faces=[tuple(reversed(range(n))),tuple(range((sections-1)*n,sections*n))]
 faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(sections-1) for i in range(n))
 solid(identity+'_LivingCane',verts,faces,identity,'cane')
 bud=lathe('TerminalBud',0,0,0,[(0,0),(.0035,0),(.005,.013),(.003,.028),(0,.042)],'leaf_rib');transform(bud,Matrix.Translation(stem(1)-Vector((0,0,.006))))
 leaves=[args for shape,args,_ in collected if shape=='lathe' and args[0]=='plant'];assert len(leaves)==6
 for index,args in enumerate(leaves):
  _,old_cx,old_cy,profile,*_=args;r,lz=profile[1];verts=[];rings=[];segments=48
  t=(lz-soil_z)/cane;root=stem(t)-Vector((0,0,.018*s));angle=.5+index*2.39996323
  u=Vector((math.cos(angle),math.sin(angle),0));v=Vector((-u.y,u.x,0));center=root+u*(r+.025*s)
  def point(x,y):return center+u*x+v*y+Vector((0,0,s*(.018+.026*(x/r)-.024*(x/r)**2)-.055*abs(y)))
  for lower in [False,True]:
   rings.append([len(verts)]);verts.append(point(0,0)-Vector((0,0,.0007 if lower else 0)))
   for fraction in [.25,.5,.75,1.]:
    ring_ids=[]
    for i in range(segments):
     a=math.tau*i/segments;x=r*fraction*math.cos(a);y=r*.44*fraction*math.sin(a)*abs(math.sin(a))**.25;ring_ids.append(len(verts));verts.append(point(x,y)-Vector((0,0,.0007 if lower else 0)))
    rings.append(ring_ids)
  faces=[]
  for base in [0,5]:
   for a,b in zip(rings[base:base+4],rings[base+1:base+5]):
    for i in range(segments):faces.append((a[0],b[i],b[(i+1)%segments]) if len(a)==1 else (a[i],b[i],b[(i+1)%segments],a[(i+1)%segments]))
  for i in range(segments):faces.append((rings[4][i],rings[9][i],rings[9][(i+1)%segments],rings[4][(i+1)%segments]))
  solid(identity+'_RubberLeaf'+str(index),verts,faces,identity,'plant')
  base=point(-r*.94,0)
  wire('Petiole'+str(index),[root,(root+base)*.5+Vector((0,0,.005*s)),base],.0022*s,'leaf_rib')
  wire('Midrib'+str(index),[point(r*q,0)+Vector((0,0,.0001)) for q in np.linspace(-.97,.97,33)],.00045,'leaf_rib')
  for vein in range(1,7):
   x=r*(-.75+vein*.21)
   for side in [-1,1]:
    end_x=min(r*.96,x+r*.15);end_y=side*r*.37*math.sqrt(max(0,1-(end_x/r)**2))
    wire('Vein'+str((index,vein,side)),[point(x+(end_x-x)*q,end_y*q)+Vector((0,0,.00003)) for q in np.linspace(0,1,9)],.00014,'leaf_rib')
  retained_stock.append({'assembly':identity,'kind':'rubber_leaf','index':index,'source_args':args})
 bearing('pot saucer',(0,0,0));group('PottedRubberPlant',start)

def stand(label,radius,angles,join_height,top_height,stem_radius):
 for i,angle in enumerate(angles):
  a=math.radians(angle);x=radius*math.cos(a);y=radius*math.sin(a)
  lathe(label+'Foot'+str(i),x,y,0,[(0,0),(.013,0),(.015,.003),(.013,.014),(0,.014)],'rubber_aged')
  tube(label+'Leg'+str(i),(x,y,.010),(0,0,join_height),.011,'metal')
  bearing(label+' foot '+str(i),(x,y,0))
 lathe(label+'Pole',0,0,join_height-.035,[(0,0),(stem_radius+.003,0),(stem_radius+.003,.06),(stem_radius,.065),(stem_radius,top_height-join_height+.035),(0,top_height-join_height+.035)],'metal')
 for z in [join_height+.045,(join_height+top_height)*.5]:
  lathe(label+'Collar'+str(z),0,0,z,[(0,0),(stem_radius+.005,0),(stem_radius+.005,.022),(0,.022)],'soot')
  tube(label+'Clamp'+str(z),(stem_radius,0,z+.011),(stem_radius+.022,0,z+.011),.005,'soot')

def tripod(source,member):
 start=len(stock_checks);h=source.get('H',1.32)
 body_surface=next(s for s in member['surfaces'] if s['material']=='soot');offset=min(np.asarray(body_surface['vertices']).reshape((-1,3))[:,1])-h;h+=offset
 stand('Tripod',.30,[90,210,330],h-.22,h-.014,.017)
 lathe('CameraMount',0,0,h-.035,[(0,0),(.030,0),(.037,.012),(.037,.030),(.050,.035),(0,.035)],'metal')
 stock('CameraBack',(-.075,-.10,h),(.075,-.093,h+.11),'soot',.002)
 stock('CameraFront',(-.075,.088,h),(.075,.095,h+.11),'soot',.002)
 for x in [-.075,.068]:stock('CameraSide'+str(x),(x,-.095,h),(x+.007,.09,h+.11),'soot',.002)
 for z in [h,h+.103]:stock('CameraEnd'+str(z),(-.07,-.095,z),(.07,.09,z+.007),'soot',.002)
 axial(identity+'_LensBarrel',0,h+.055,[(.027,.094),(.032,.094),(.033,.106),(.030,.112),(.030,.176),(.033,.180),(.033,.185),(.025,.185),(.025,.110),(.027,.094)],identity,'metal',64)
 axial(identity+'_LensFace',0,h+.055,[(0,.180),(.024,.180),(.025,.182),(.018,.184),(0,.185)],identity,'milk_glass',64)
 stock('RearGroundGlass',(-.055,-.102,h+.02),(.055,-.099,h+.09),'milk_glass',.0005)
 for x in [-.058,.055]:stock('FinderSide'+str(x),(x,-.104,h+.017),(x+.003,-.098,h+.093),'metal',.0004)
 for z in [h+.017,h+.09]:stock('FinderRail'+str(z),(-.058,-.104,z),(.058,-.098,z+.003),'metal',.0004)
 group('CameraAndTripod',start)

def softbox(source,member):
 start=len(stock_checks)
 # Original stand cross-sections were normalized upward in the V2 record.
 # Keep the existing head position; new feet have genuine flat floor bearings.
 old=np.asarray(next(s for s in member['surfaces'] if s['material']=='soot')['vertices']).reshape((-1,3));offset=float(old[:,1].mean())-1.55
 stand('LightStand',.26,[30,150,270],.55+offset,1.52+offset,.012)
 a=Vector((0,-.02,1.66+offset));c=Vector((0,.195,1.4135+offset));axis=(c-a).normalized();u=Vector((1,0,0));v=axis.cross(u).normalized();thickness=.0015
 verts=[]
 for inset in [0,thickness]:
  for center,w,d in [(a,.46,.09),(c,.42,.075)]:
   verts.extend(center+u*x*(w/2-inset)+v*y*(d/2-inset) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)])
 faces=[]
 for j in range(4):
  k=(j+1)%4;faces.extend([(j,k,4+k,4+j),(8+j,12+j,12+k,8+k),(j,8+j,8+k,k),(4+j,4+k,12+k,12+j)])
 solid(identity+'_FoldedLightHousing',verts,faces,identity,'soot')
 def cap(label,center,w,d,depth,key):
  points=[center+axis*z+u*x*w/2+v*y*d/2 for z in [-depth/2,depth/2] for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
  return solid(identity+'_'+label,points,[(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,4+(i+1)%4,4+i) for i in range(4)],identity,key)
 cap('BackCap',a+axis*.001,.459,.089,.002,'soot')
 # Retained linen diffuser: a shallow tensioned sheet inside the original
 # mouth, with turned seams. This is an unlit diffusion fitting, not a new
 # emissive lamp or a claim of a historically documented modern softbox.
 nx=32;ny=10;verts=[]
 for skin in [0,1]:
  for j in range(ny+1):
   yy=j/ny
   for i in range(nx+1):
    xx=i/nx;slack=.0015*math.sin(xx*math.pi)*math.sin(yy*math.pi)
    verts.append(c+u*(xx-.5)*.419+v*(yy-.5)*.074-axis*(.0001+slack+skin*.0012))
 count=(nx+1)*(ny+1);faces=[]
 for skin in [0,1]:
  for j in range(ny):
   for i in range(nx):
    a=skin*count+j*(nx+1)+i;q=(a,a+1,a+nx+2,a+nx+1);faces.append(q if skin==0 else tuple(reversed(q)))
 boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
 faces.extend((a,b,b+count,a+count) for a,b in zip(boundary,boundary[1:]+boundary[:1]))
 solid(identity+'_ClothDiffuser',verts,faces,identity,'linen')
 for j in [1,ny-1]:
  wire('DiffuserHem'+str(j),[verts[j*(nx+1)+i]-axis*.0002 for i in range(1,nx)],.00035,'linen')
 # The old head floated beyond the pole. A seated tilt yoke bridges it.
 tube('HeadYoke',(0,0,1.50+offset),(0,.055,1.53+offset),.011,'metal')
 tube('TiltAxle',(-.034,.052,1.53+offset),(.034,.052,1.53+offset),.007,'metal')
 for x in [-.034,.034]:
  knob=along_x(identity+'_TiltButton'+str(x),x,.052,1.53+offset,[(0,-.004),(.014,-.004),(.014,.004),(0,.004)],identity,'soot')
 group('StudioLightStand',start)

# Dossier entry landing sets (slice 8): a floor-standing hall stand against the
# vestibule wall. Backboard with four iron hooks at 1.65 m, a shelf at 1.1 m on
# brackets, a plinth carrying a brass drip tray. All stocks touch; bearings are
# the plinth's underside corners on the floor.
def hallstand(source):
 start=len(stock_checks)
 stock('Plinth',(-.30,-.15,0),(.30,.14,.05),'wood_dark',.0015)
 stock('Backboard',(-.30,.10,.05),(.30,.14,1.80),'wood_dark',.0015)
 stock('Cornice',(-.31,.09,1.80),(.31,.145,1.85),'wood_dark',.001)
 stock('Shelf',(-.30,-.15,1.10),(.30,.10,1.13),'wood_dark',.0012)
 for x in [-.27,.27]:stock('Bracket'+str(x),(x-.015,-.03,1.02),(x+.015,.10,1.10),'wood_dark',.0008)
 stock('Tray',(-.27,-.13,.05),(.27,.08,.07),'brass',.0006)
 for i,x in enumerate([-.21,-.07,.07,.21]):
  stock('HookPlate'+str(i),(x-.02,.096,1.62),(x+.02,.10,1.68),'metal',.0004)
  wire('Hook'+str(i),[(x,.096,1.65),(x,.05,1.65),(x,.04,1.67),(x,.04,1.70)],.006,'metal')
 for x in [-.27,.27]:
  for y in [-.13,.12]:bearing('stand foot '+str((x,y)),(x,y,0))
 group('HallStand',start)

def artframe(source):
 # Dossier slice 11/12 wall art: a stretched canvas or a framed document, hung
 # on rear battens to the actual wall face (wall_mount). No lettering: a seal
 # disc and a pen stroke stand for the document's text.
 start=len(stock_checks);width=source['W'];height=source['H']
 if source['style']=='canvas':
  for x in [-width/2,width/2-.035]:stock('Stile'+str(x),(x,0,0),(x+.035,.02,height),'timber',.0006)
  for z in [0,height-.035]:stock('Rail'+str(z),(-width/2+.034,0,z),(width/2-.034,.02,z+.035),'timber',.0006)
  # A centre brace takes the rear battens; the canvas wraps both side edges.
  stock('Brace',(-width/2+.034,0,height/2-.02),(width/2-.034,.02,height/2+.02),'timber',.0006)
  stock('Canvas',(-width/2-.002,.0195,0),(width/2+.002,.0235,height),'linen',.0004)
  for side in [-1,1]:stock('Wrap'+str(side),(min(side*width/2,side*(width/2+.002)),.002,0),(max(side*width/2,side*(width/2+.002)),.0236,height),'linen',.0003)
  fields=source.get('fields',[])
  for i,(x0,z0,x1,z1,key) in enumerate(fields):
   stock('Paint'+str(i),(-width/2+x0*width,.023,z0*height),(-width/2+x1*width,.0245+.0004*(i%3),z1*height),key,.0002)
  for side in [-1,1]:
   for i in range(5):
    z=.08+i*(height-.16)/4;x=side*(width/2+.00235)
    # Tack heads driven through the wrapped canvas edge (wrap .000-.002 m proud).
    stock('Tack'+str((side,i)),(x-.00115,.009,z-.003),(x+.00115,.013,z+.003),'metal',.0002)
 else:
  stock('Backing',(-width/2+.01,0,.01),(width/2-.01,.006,height-.01),'plywood',.0004)
  stock('Mat',(-width/2+.02,.0055,.02),(width/2-.02,.009,height-.02),'linen',.0003)
  if source['style']=='photo':
   # A toned print under the mat window (slice 15).
   stock('Print',(-width/2+.055,.0085,.065),(width/2-.055,.0105,height-.065),source.get('print','book_brown'),.0002)
  else:
   stock('Document',(-width/2+.055,.0085,.065),(width/2-.055,.0105,height-.055),'paper',.0002)
   axial(identity+'_Seal',width/2-.105,.115,[(0,.0100),(.021,.0100),(.021,.0118),(.017,.0128),(0,.0128)],identity,'brass',32)
   stock('Signature',(-width/2+.08,.0102,.1),(-width/2+.17,.0110,.103),'soot',.0001)
  for x in [-width/2,width/2-.025]:stock('Moulding'+str(x),(x,0,0),(x+.025,.028,height),'wood_dark',.001)
  for z in [0,height-.025]:stock('MouldingRail'+str(z),(-width/2+.024,0,z),(width/2-.024,.028,z+.025),'wood_dark',.001)
 wall_mount(source,width,height)
 group('WallArt',start)

def garmentrail(source):
 # Dossier slice 13: a wall rail on a header board with garments on wooden
 # hangers, hung edge-on to the wall; optional paper repair tags.
 start=len(stock_checks);width=source['W'];height=source['H'];top=height-.13
 wall_mount(source,width,height)
 stock('Header',(-width/2,0,height-.12),(width/2,.022,height),'wood_dark',.001)
 for x in [-width/2+.03,width/2-.03]:stock('Bracket'+str(x),(x-.008,.021,height-.07),(x+.008,.33,height-.05),'metal',.0004)
 tube('Rail',(-width/2+.02,.31,height-.06),(width/2-.02,.31,height-.06),.011,'metal')
 garments=source['garments'];pitch=(width-.16)/max(len(garments)-1,1)
 for i,key in enumerate(garments):
  x=-width/2+.08+i*pitch;length=(.55,.65,.72)[i%3]
  wire('Hook'+str(i),[(x,.31,top+.02),(x,.31,height-.035),(x,.30,height-.03),(x,.29,height-.04)],.003,'metal')
  tube('Hanger'+str(i),(x,.11,top+.02),(x,.51,top+.02),.006,'wood_dark')
  stock('Shoulders'+str(i),(x-.02,.12,top-.06),(x+.02,.50,top+.016),key,.004)
  stock('Body'+str(i),(x-.018,.14,top-.06-length),(x+.018,.48,top-.055),key,.004)
  if source.get('tags'):stock('Tag'+str(i),(x+.017,.40,top-.2),(x+.021,.45,top-.14),'paper',.0002)
 group('GarmentRail',start)

def blanket(source):
 # Dossier slice 13: a moving blanket hung from a batten, edges bound and
 # quilted in rows.
 start=len(stock_checks);width=source['W'];height=source['H'];key=source['key']
 wall_mount(source,width,height)
 stock('Batten',(-width/2-.03,0,height-.05),(width/2+.03,.02,height),'timber',.0006)
 stock('Blanket',(-width/2,.0195,0),(width/2,.04,height-.02),key,.003)
 for side in [-1,1]:stock('Bind'+str(side),(min(side*width/2,side*(width/2-.025)),.018,0),(max(side*width/2,side*(width/2-.025)),.0415,height-.02),'linen',.0004)
 stock('BindFoot',(-width/2+.024,.018,0),(width/2-.024,.0415,.025),'linen',.0004)
 for i in range(1,int(height/.3)):
  z=i*.3;stock('Stitch'+str(i),(-width/2+.03,.0398,z-.0012),(width/2-.03,.0412,z+.0012),'linen',.0001)
 group('HungBlanket',start)

def hamper(source):
 # Dossier slice 14: a lidded wicker laundry hamper on four feet, a linen
 # corner caught under the lid at the front.
 start=len(stock_checks)
 for x in [-.21,.21]:
  for y in [-.13,.13]:stock('Foot'+str((x,y)),(x-.02,y-.02,0),(x+.02,y+.02,.022),'wood_dark',.002);bearing('hamper foot '+str((x,y)),(x,y,0))
 stock('Body',(-.25,-.17,.02),(.25,.17,.46),'cane',.01)
 for z in [.02,.43]:stock('Band'+str(z),(-.252,-.172,z),(.252,.172,z+.03),'wood_dark',.002)
 stock('Lid',(-.26,-.18,.459),(.26,.18,.5),'cane',.008)
 for x in [-.245,.245]:wire('Handle'+str(x),[(x,-.07,.33),(x+(.035 if x>0 else -.035),-.07,.36),(x+(.035 if x>0 else -.035),.07,.36),(x,.07,.33)],.006,'cane')
 stock('Linen',(.05,.165,.40),(.2,.175,.47),'linen',.001)
 group('Hamper',start)

def boottray(source):
 # Dossier slice 14: a galvanised boot tray with a pair of rubber galoshes and
 # a little dried mud.
 start=len(stock_checks)
 stock('TrayPlate',(-.3,-.18,0),(.3,.18,.006),'metal',.001)
 for y in [-.18,.172]:stock('RimLong'+str(y),(-.3,y,.005),(.3,y+.008,.03),'metal',.0008)
 for x in [-.3,.292]:stock('RimEnd'+str(x),(x,-.173,.005),(x+.008,.173,.03),'metal',.0008)
 for x,y in [(-.28,-.16),(.28,-.16),(-.28,.16),(.28,.16)]:bearing('tray corner '+str((x,y)),(x,y,0))
 stock('Mud',(-.2,-.08,.0055),(.12,.1,.0075),'soil',.0005)
 for i,(x,y) in enumerate([(-.1,0),(.1,.02)]):
  stock('Sole'+str(i),(x-.055,y-.14,.0055),(x+.055,y+.14,.03),'rubber_aged',.006)
  stock('Vamp'+str(i),(x-.047,y-.12,.029),(x+.047,y+.06,.11),'rubber_aged',.012)
  stock('Shaft'+str(i),(x-.048,y+.03,.029),(x+.048,y+.135,.29),'rubber_aged',.012)
 group('BootTray',start)

def suitcase(source):
 # Dossier slice 17: a leather case standing on its long edge against a
 # wall, two straps, brass corner caps and a handle on top.
 start=len(stock_checks);w=source['W'];d=source['D'];h=source['H'];key=source['key']
 stock('Body',(-w/2,-d/2,.006),(w/2,d/2,h),key,.012)
 for x in [-w/2+.02,w/2-.02]:
  for y in [-d/2+.02,d/2-.02]:stock('Foot'+str((x,y)),(x-.012,y-.012,0),(x+.012,y+.012,.0065),'brass',.002);bearing('case foot '+str((x,y)),(x,y,0))
 for x in [-w/4,w/4]:stock('Strap'+str(x),(x-.015,-d/2-.003,.006),(x+.015,d/2+.003,h+.003),'rubber_aged',.0008)
 wire('Handle',[(-.06,0,h-.002),(-.05,0,h+.03),(.05,0,h+.03),(.06,0,h-.002)],.008,key)
 group('Suitcase',start)

def sewingmachine(source):
 # Dossier slice 18: a treadle sewing machine. Cast-iron side frames and
 # treadle, an oak cabinet top, a black japanned head with its handwheel.
 start=len(stock_checks)
 for sx in [-.38,.38]:
  for sy in [-.18,.18]:
   stock('Leg'+str((sx,sy)),(sx-.02,sy-.02,0),(sx+.02,sy+.02,.745),'soot',.002);bearing('treadle foot '+str((sx,sy)),(sx,sy,0))
  for z in [.09,.45]:stock('Rail'+str((sx,z)),(sx-.015,-.2,z),(sx+.015,.2,z+.03),'soot',.002)
 tube('Axle',(-.39,0,.105),(.39,0,.105),.012,'soot')
 stock('Treadle',(-.25,-.1,.09),(.25,.12,.115),'soot',.002)
 stock('Top',(-.43,-.23,.74),(.43,.23,.775),'timber',.003)
 stock('Drawer',(-.4,-.2,.66),(-.15,.2,.745),'timber',.002)
 stock('Bed',(-.2,-.08,.774),(.2,.08,.805),'soot',.003)
 stock('Pillar',(.12,-.04,.80),(.18,.04,1.06),'soot',.004)
 stock('Arm',(-.17,-.035,.98),(.18,.035,1.06),'soot',.006)
 stock('NeedleHead',(-.21,-.03,.9),(-.14,.03,1.06),'soot',.004)
 tube('Needle',(-.175,0,.905),(-.175,0,.808),.002,'metal')
 stock('NeedlePlate',(-.22,-.05,.803),(-.13,.05,.808),'brass',.0005)
 axial(identity+'_Handwheel',.205,.985,[(0,.035),(.06,.035),(.06,.055),(0,.055)],identity,'metal',32)
 group('SewingMachine',start)

def teardown(source):
 # Dossier slice 18: a radio chassis with its valves out, on a newspaper
 # sheet, screws in a saucer. Passive; never a live receiver.
 start=len(stock_checks)
 stock('Newspaper',(-.3,-.22,0),(.3,.22,.003),'paper',.0002)
 for p in [(-.27,-.19,0),(.27,-.19,0),(-.27,.19,0),(.27,.19,0)]:bearing('sheet '+str(p),p)
 stock('Chassis',(-.17,-.1,.0025),(.13,.08,.07),'metal',.002)
 for i,x in enumerate([-.11,-.05,.01]):
  lathe('Socket'+str(i),x,.0,.069,[(0,0),(.014,0),(.014,.008),(0,.008)],'bakelite')
 for i,(x,y) in enumerate([(.18,-.12),(.22,-.05),(.2,.05)]):
  lathe('Valve'+str(i),x,y,.0025,[(0,0),(.013,0),(.013,.015),(.015,.02),(.015,.07),(.01,.09),(0,.092)],'milk_glass')
 lathe('Saucer',-.2,.14,.0025,[(0,0),(.03,0),(.05,.012),(.052,.014),(.048,.014),(.028,.004),(0,.004)],'enamel')
 for i in range(4):stock('Screw'+str(i),(-.215+i*.008,.135,.0065),(-.209+i*.008,.141,.011),'metal',.0002)
 group('Teardown',start)

def easel(source):
 # Dossier slice 18: a studio easel, two splayed front legs and a back leg,
 # a ledge holding a blank canvas, the top clamp down on it.
 start=len(stock_checks)
 # Tilted legs stand on small foot pads so their cut ends stay above the floor.
 for sx in [-1,1]:
  stock('FrontPad'+str(sx),(sx*.28-.02,.08,0),(sx*.28+.02,.12,.012),'timber',.001);bearing('front foot '+str(sx),(sx*.28,.10,0))
  tube('FrontLeg'+str(sx),(sx*.28,.10,.008),(sx*.05,.02,1.6),.015,'timber')
 stock('TopBlock',(-.07,0,1.55),(.07,.04,1.62),'timber',.002)
 stock('BackPad',(-.02,-.47,0),(.02,-.43,.012),'timber',.001);bearing('back foot',(0,-.45,0))
 tube('BackLeg',(0,.02,1.6),(0,-.45,.008),.015,'timber')
 stock('Ledge',(-.25,.03,.69),(.25,.09,.72),'timber',.002)
 stock('Canvas',(-.3,.04,.719),(.3,.065,1.42),'linen',.002)
 stock('Clamp',(-.03,.035,1.415),(.03,.07,1.6),'timber',.002)
 group('Easel',start)

def canvasstack(source):
 # Dossier slice 18: six failed canvases standing face to the wall, their
 # stretcher backs to the room, one pencil mark on each.
 for i in range(6):
  start=len(stock_checks);w=(.6,.5,.55,.45,.6,.4)[i];h=(.8,.7,.75,.6,.65,.5)[i];y0=.012+i*.03
  stock('Face'+str(i),(-w/2,y0,0),(w/2,y0+.006,h),'linen',.001)
  for x in [-w/2,w/2-.03]:stock('Stile'+str((i,x)),(x,y0+.0055,0),(x+.03,y0+.025,h),'timber',.002)
  for z in [0,h-.03]:stock('Rail'+str((i,z)),(-w/2+.029,y0+.0055,z),(w/2-.029,y0+.025,z+.03),'timber',.002)
  stock('Mark'+str(i),(-w/2+.08,y0+.0249,h-.025),(-w/2+.14,y0+.0256,h-.022),'soot',.0001)
  for x in [-w/2+.015,w/2-.015]:bearing('canvas foot '+str((i,x)),(x,y0+.015,0))
  group('Canvas'+str(i),start)

def cardcabinet(source):
 # Dossier slice 19: an oak card-index cabinet, three columns of four
 # drawers with brass pulls and blank label frames; one drawer carries a
 # brass lock plate (the provenance drawer: locked, RESIST-REFUSE later).
 start=len(stock_checks)
 stock('Case',(-.3,-.2,.05),(.3,.2,.8),'timber',.004)
 for x in [-.27,.27]:
  for y in [-.17,.17]:stock('Foot'+str((x,y)),(x-.025,y-.025,0),(x+.025,y+.025,.051),'wood_dark',.002);bearing('cabinet foot '+str((x,y)),(x,y,0))
 for c in range(3):
  for r in range(4):
   x0=-.28+c*.19;z0=.08+r*.175
   stock('Drawer'+str((c,r)),(x0,.195,z0),(x0+.18,.215,z0+.165),'wood_dark',.002)
   stock('Label'+str((c,r)),(x0+.06,.2145,z0+.11),(x0+.12,.2175,z0+.145),'brass',.0005)
   stock('Pull'+str((c,r)),(x0+.07,.2145,z0+.05),(x0+.11,.232,z0+.07),'brass',.001)
 stock('LockPlate',(-.09+.0,.2145,.33),(-.05,.219,.37),'brass',.0005)
 group('CardCabinet',start)

def backdroprail(source):
 # Dossier slice 20: a photographer's backdrop, a paper roll on a rail in
 # two brackets under a header strip, the paper hanging almost to the floor.
 start=len(stock_checks);width=source['W'];height=source['H']
 wall_mount(source,width,height)
 stock('Header',(-width/2,0,height-.12),(width/2,.02,height),'wood_dark',.001)
 for x in [-width/2+.02,width/2-.02]:stock('Bracket'+str(x),(x-.01,.0,height-.1),(x+.01,.1,height-.04),'metal',.0006)
 tube('Rail',(-width/2+.015,.08,height-.065),(width/2-.015,.08,height-.065),.012,'metal')
 tube('Roll',(-width/2+.04,.08,height-.065),(width/2-.04,.08,height-.065),.05,'paper')
 stock('Sheet',(-width/2+.05,.124,.05),(width/2-.05,.13,height-.065),'paper',.0005)
 group('BackdropRail',start)

def printline(source):
 # Dossier slice 20: contact sheets pegged to a string between two wall
 # hooks; each sheet a grid of small dark frames (no lettering).
 start=len(stock_checks);width=source['W'];back=variants[identity]['rear_wall_y']
 for x in [-width/2,width/2]:
  stock('HookPlate'+str(x),(x-.02,back,.27),(x+.02,.004,.33),'metal',.0006)
  for z in [.28,.32]:support(identity,'wall',(x,back,z),(0,1,0),'wall face behind hook plate')
 tube('String',(-width/2,.002,.3),(width/2,.002,.3),.0015,'linen')
 for i in range(6):
  x=-width/2+.16+i*(width-.32)/5
  stock('Peg'+str(i),(x-.006,-.004,.285),(x+.006,.009,.32),'timber',.0008)
  stock('Sheet'+str(i),(x-.1,.001,.04),(x+.1,.003,.292),'paper',.0002)
  for r in range(4):
   for c in range(3):stock('Frame'+str((i,r,c)),(x-.075+c*.055,.0029,.06+r*.055),(x-.03+c*.055,.0036,.1+r*.055),'soot',.0001)
 group('PrintLine',start)

def hookstrip(source):
 # Dossier slice 25: a cable hook strip, a batten with five hooks and the
 # session cables hanging from them in loops, each bound with tape.
 start=len(stock_checks);width=source['W'];height=source['H']
 wall_mount(source,width,height)
 stock('Batten',(-width/2,0,height-.07),(width/2,.022,height),'wood_dark',.002)
 for i in range(5):
  x=-width/2+.07+i*(width-.14)/4;r=(.07,.06,.075,.065,.07)[i];zc=height-.05-r
  stock('Hook'+str(i),(x-.005,.02,height-.055),(x+.005,.05,height-.045),'metal',.0006)
  wire('Loop'+str(i),[(x+r*math.cos(t),.04,zc+r*math.sin(t)) for t in np.linspace(0,math.tau,41)],.006,'rubber_aged')
  stock('Tape'+str(i),(x-.012,.032,zc-r-.004),(x+.012,.048,zc-r+.012),'linen',.0005)
  stock('Link'+str(i),(x-.004,.034,zc+r-.008),(x+.004,.046,height-.05),'rubber_aged',.0005)
 group('HookStrip',start)

def coathook(source):
 # Dossier slice 28: one coat hung by its loop from a hook on a short board.
 start=len(stock_checks);width=source['W'];height=source['H'];key=source['key']
 wall_mount(source,width,height)
 stock('Board',(-width/2,0,height-.1),(width/2,.018,height),'wood_dark',.001)
 wire('Hook',[(0,.016,height-.05),(0,.06,height-.05),(0,.07,height-.035),(0,.07,height-.02)],.005,'brass')
 stock('Collar',(-.06,.035,height-.12),(.06,.075,height-.045),key,.004)
 stock('Shoulders',(-width/2+.02,.03,height-.2),(width/2-.02,.11,height-.1),key,.006)
 stock('Body',(-width/2,.025,0),(width/2,.12,height-.18),key,.006)
 for z in [height*.55,height*.4,height*.25]:stock('Button'+str(round(z,3)),(-.012,.119,z),(.012,.126,z+.022),'bakelite',.0004)
 group('Coat',start)

def headsethook(source):
 # Dossier slice 28: the operator's headset hung on its hook beside the house board.
 start=len(stock_checks);width=source['W'];height=source['H']
 wall_mount(source,width,height)
 stock('Plate',(-width/2,0,height-.14),(width/2,.016,height),'wood_dark',.002)
 stock('Hook',(-.007,.014,height-.075),(.007,.075,height-.061),'brass',.0006)
 stock('HookTip',(-.007,.061,height-.075),(.007,.075,height-.045),'brass',.0006)
 zc=height-.135
 wire('Band',[(.065*math.cos(t),.068,zc+.065*math.sin(t)) for t in np.linspace(0,math.pi,33)],.004,'metal')
 for side in [-1,1]:tube('Receiver'+str(side),(side*.052,.068,zc-.012),(side*.08,.068,zc-.012),.03,'bakelite')
 wire('Cord',[(-.066,.06,zc-.04),(-.064,.05,zc-.12),(-.04,.038,zc-.2),(0,.03,zc-.22),(.03,.022,zc-.16),(.035,.01,height-.135)],.0035,'rubber_aged')
 group('HeadsetHook',start)

def foldedcot(source):
 # Dossier slice 28: the night watch's iron camp cot folded on end, a grey blanket strapped to it.
 start=len(stock_checks)
 for x in [-.34,.34]:
  stock('Foot'+str(x),(x-.02,-.04,0),(x+.02,.04,.035),'rubber_aged',.002)
  tube('Rail'+str(x),(x,0,.03),(x,0,.95),.014,'metal')
 for z in [.06,.93]:tube('Bar'+str(z),(-.34,0,z),(.34,0,z),.012,'metal')
 stock('Canvas',(-.33,-.02,.07),(.33,.02,.92),'linen',.002)
 for y in [-.028,.028]:
  tube('LegA'+str(y),(-.3,y,.1),(.3,y,.52),.01,'metal')
  tube('LegB'+str(y),(.3,y,.1),(-.3,y,.52),.01,'metal')
 stock('Blanket',(-.27,-.075,.5),(.27,-.03,.82),'blanket_grey',.008)
 for z in [.56,.76]:stock('Strap'+str(z),(-.3,-.08,z),(.3,-.015,z+.025),'linen',.0008)
 for x in [-.34,.34]:
  for y in [-.035,.035]:bearing('cot foot '+str((x,y)),(x,y,0))
 group('FoldedCot',start)

def shovel(source):
 # Dossier slice 29: a coal shovel leaning on the wall beside the fire door, blade on the floor.
 start=len(stock_checks)
 stock('Blade',(-.13,.22,0),(.13,.5,.012),'metal',.002)
 for x in [-.13,.122]:stock('Lip'+str(x),(x,.22,.005),(x+.008,.5,.06),'metal',.001)
 stock('Back',(-.13,.22,.005),(.13,.23,.08),'metal',.001)
 stock('Socket',(-.025,.2,0),(.025,.29,.07),'metal',.002)
 tube('Shaft',(0,.245,.05),(0,.005,1.0),.017,'timber')
 stock('Grip',(-.07,-.02,.98),(.07,.025,1.05),'timber',.004)
 for p in [(-.12,.24,0),(.12,.24,0),(-.12,.49,0),(.12,.49,0)]:bearing('shovel blade '+str(p),p)
 support(identity,'wall',(0,-.02,1.015),(0,1,0),'grip resting on the wall')
 group('Shovel',start)

def rakerack(source):
 # Dossier slice 29: the clinker rake resting on two nails driven into the wall.
 start=len(stock_checks);length=source['L'];back=variants[identity]['rear_wall_y']
 for x in [-.45,.45]:
  tube('Nail'+str(x),(x,back,.1),(x,.07,.1),.004,'metal')
  stock('NailHead'+str(x),(x-.007,.066,.093),(x+.007,.072,.107),'metal',.0004)
  support(identity,'wall',(x,back,.1),(0,1,0),'nail driven into the wall')
 tube('Handle',(-length/2,.045,.118),(length/2-.04,.045,.118),.016,'timber')
 stock('Ferrule',(length/2-.06,.03,.1),(length/2-.02,.06,.136),'metal',.001)
 stock('Head',(length/2-.025,0,.02),(length/2-.005,.09,.25),'metal',.002)
 group('ClinkerRake',start)

def ashcan(source):
 # Dossier slice 29: the lidded ash can, and an oil can standing on a folded rag beside it.
 start=len(stock_checks)
 lathe('Can',0,0,0,[(0,0),(.19,0),(.2,.01),(.215,.47),(.222,.48),(0,.48)],'metal')
 for z in [.12,.3]:ring('Rib'+str(z),0,0,z,.214,.19,.018,'metal')
 lathe('Lid',0,0,.475,[(0,0),(.228,0),(.228,.014),(.2,.03),(0,.04)],'metal')
 stock('LidGrip',(-.05,-.012,.51),(.05,.012,.535),'metal',.002)
 for x in [-1,1]:wire('Handle'+str(x),[(x*.205,0,.38),(x*.245,0,.395),(x*.245,0,.425),(x*.21,0,.44)],.006,'metal')
 for p in [(.14,0,0),(-.14,0,0),(0,.14,0),(0,-.14,0)]:bearing('ash can '+str(p),p)
 group('AshCan',start)
 start=len(stock_checks)
 stock('Rag',(.27,-.2,0),(.49,-.06,.02),'linen',.004)
 lathe('OilCan',.38,-.13,.019,[(0,0),(.06,0),(.06,.09),(.035,.12),(.012,.13),(0,.13)],'metal')
 tube('Spout',(.38,-.13,.12),(.46,-.13,.22),.005,'brass')
 for p in [(.3,-.18,0),(.46,-.18,0),(.3,-.08,0),(.46,-.08,0)]:bearing('rag '+str(p),p)
 group('OilCanOnRag',start)

def signalframe(source):
 # Dossier slice 29: the Vantry signal frame. Brass terminals on bakelite strips on a board, cloth
 # leads dressed into a bundle and a trunk cleated up the wall to the ceiling; blank tag cards.
 start=len(stock_checks);width=source['W'];height=source['H'];top=source['top']
 wall_mount(source,width,height)
 stock('Board',(-width/2,0,0),(width/2,.022,height),'wood_dark',.002)
 for z in [.06,height-.06]:stock('Rail'+str(z),(-width/2+.04,.02,z-.015),(width/2-.04,.035,z+.015),'brass',.001)
 rows=6;cols=12;bx=width/2-.05
 for i in range(rows):
  z=.17+i*(height-.34)/(rows-1)
  stock('Strip'+str(i),(-width/2+.08,.02,z-.012),(width/2-.1,.032,z+.012),'bakelite',.001)
  for j in range(cols):
   x=-width/2+.12+j*(width-.26)/(cols-1)
   stock('Terminal'+str(i)+'_'+str(j),(x-.006,.031,z-.006),(x+.006,.042,z+.006),'brass',.0004)
   if j%3==1:stock('Tag'+str(i)+'_'+str(j),(x-.02,.02,z-.04),(x+.02,.024,z-.02),'paper',.0002)
  tube('Lead'+str(i),(x-.004,.04,z),(bx,.06,z),.008,'linen')
 tube('Bundle',(bx,.06,.12),(bx,.06,height),.03,'linen')
 tube('Trunk',(bx,.06,height-.01),(bx,.06,top),.035,'linen')
 for z in [height+.25,(height+top)/2,top-.12]:
  stock('Cleat'+str(round(z,2)),(bx-.05,-.02,z-.015),(bx+.05,.1,z+.015),'wood_dark',.001)
  support(identity,'wall',(bx,-.02,z),(0,1,0),'trunk cleat on the wall')
 group('SignalFrame',start)

def conduit(source):
 # Dossier slice 29: steel conduit from the floor into the fuse panel's backing box and out of
 # its top to a junction box under the ceiling; two runs, each saddled to the wall.
 low=source['low'];high=source['high'];top=source['top'];back=variants[identity]['rear_wall_y'];y=.04
 for label,z0,z1 in [('Riser',0,low),('Trunk',high,top)]:
  start=len(stock_checks)
  tube(label,(0,y,z0),(0,y,z1),.016,'metal')
  if z0==0:
   lathe(label+'Flange',0,y,0,[(0,0),(.035,0),(.035,.012),(.02,.02),(0,.02)],'metal')
   for p in [(.03,y,0),(-.03,y,0),(0,y+.03,0)]:bearing('flange '+str(p),p)
   saddles=[.2,low-.12]
  else:
   stock(label+'Junction',(-.07,back,top-.45),(.07,y+.04,top-.31),'metal',.002)
   support(identity,'wall',(0,back,top-.38),(0,1,0),'junction box screwed to the wall')
   saddles=[high+.15]
  for z in saddles:
   stock(label+'Saddle'+str(round(z,2)),(-.028,back,z-.012),(.028,y+.02,z+.012),'metal',.0006)
   support(identity,'wall',(0,back,z),(0,1,0),'saddle screwed to the wall')
  group(label,start)

def oilcan(source):
 # Dossier slice 32: an oil can standing on a folded rag.
 start=len(stock_checks)
 stock('Rag',(-.11,-.07,0),(.11,.07,.02),'linen',.004)
 lathe('Can',0,0,.019,[(0,0),(.06,0),(.06,.09),(.035,.12),(.012,.13),(0,.13)],'metal')
 tube('Spout',(0,0,.12),(.08,0,.22),.005,'brass')
 for p in [(-.09,-.05,0),(.09,-.05,0),(-.09,.05,0),(.09,.05,0)]:bearing('rag '+str(p),p)
 group('OilCan',start)

def beltnail(source):
 # Dossier slice 32: a spare drive belt hung in a loop on a nail.
 start=len(stock_checks);height=source['H'];back=variants[identity]['rear_wall_y']
 tube('Nail',(0,back,height-.03),(0,.04,height-.03),.004,'metal')
 support(identity,'wall',(0,back,height-.03),(0,1,0),'nail driven into the wall')
 r=.17;zc=height-.03-r
 wire('Belt',[(r*math.sin(t)*.55,.02,zc+r*math.cos(t)) for t in np.linspace(0,math.tau,49)],.006,'rubber_aged')
 group('SpareBelt',start)

def stepladder(source):
 # Dossier slice 32: a folded wooden stepladder leaning on the wall, feet on the floor.
 start=len(stock_checks);back=variants[identity]['rear_wall_y']
 for x in [-.2,.2]:
  stock('Foot'+str(x),(x-.03,.28,0),(x+.03,.36,.03),'timber',.002)
  tube('Stile'+str(x),(x,.32,.02),(x,.03,1.45),.022,'timber')
  stock('Top'+str(x),(x-.03,back,1.42),(x+.03,.05,1.5),'timber',.002)
  bearing('ladder foot '+str(x),(x,.32,0))
 for x in [-.17,.17]:tube('BackLeg'+str(x),(x,.29,.03),(x,.0,1.42),.015,'timber')
 for i in range(5):
  t=(i+1)/6;y=.32-.29*t;z=.02+1.43*t
  tube('Tread'+str(i),(-.2,y,z),(.2,y,z),.02,'timber')
 stock('Cap',(-.24,back,1.48),(.24,.05,1.53),'timber',.002)
 for x in [-.2,.2]:support(identity,'wall',(x,back,1.505),(0,1,0),'ladder cap resting on the wall')
 group('StepLadder',start)

def umbrellastand(source):
 # Dossier slice 32: a cast-iron umbrella stand with its drip tray, two furled umbrellas and a stick.
 start=len(stock_checks)
 stock('Tray',(-.16,-.11,0),(.16,.11,.025),'metal',.003)
 for x in [-.16,.15]:stock('Side'+str(x),(x,-.11,.02),(x+.01,.11,.62),'metal',.002)
 for y in [-.11,.1]:stock('Rail'+str(y),(-.16,y,.55),(.16,y+.01,.6),'metal',.002)
 stock('Divider',(-.16,-.005,.55),(.16,.005,.6),'metal',.002)
 for i,(x,y,key) in enumerate([(-.07,-.05,'cape_navy'),(.06,.05,'coat_grey')]):
  lathe('Canopy'+str(i),x,y,.02,[(0,0),(.012,0),(.03,.25),(.028,.6),(.01,.64),(0,.65)],key)
  tube('Shaft'+str(i),(x,y,.66),(x,y,.8),.007,'wood_dark')
  wire('Crook'+str(i),[(x,y,.79),(x,y,.83),(x+.02,y,.85),(x+.04,y,.83),(x+.04,y,.81)],.007,'wood_dark')
 tube('Stick',(.0,-.06,.02),(.02,-.06,.86),.01,'wood_dark')
 lathe('Knob',.02,-.06,.85,[(0,0),(.016,0),(.018,.015),(.01,.03),(0,.032)],'brass')
 for p in [(-.14,-.09,0),(.14,-.09,0),(-.14,.09,0),(.14,.09,0)]:bearing('tray '+str(p),p)
 group('UmbrellaStand',start)

def spittoon(source):
 # Dossier slice 32: the lobby's brass spittoon.
 start=len(stock_checks)
 lathe('Bowl',0,0,0,[(0,0),(.11,0),(.14,.04),(.145,.08),(.12,.12),(.1,.135),(.12,.15),(.13,.16),(.11,.165),(.085,.14),(0,.14)],'brass')
 for p in [(.08,0,0),(-.08,0,0),(0,.08,0),(0,-.08,0)]:bearing('base '+str(p),p)
 group('Spittoon',start)

def soapdish(source):
 # Dossier slice 32: a wall soap dish beside the basin with a bar of carbolic.
 start=len(stock_checks);height=source['H'];back=variants[identity]['rear_wall_y']
 stock('Plate',(-.07,back,height-.06),(.07,.0,height),'enamel',.002)
 for z in [height-.045,height-.015]:support(identity,'wall',(0,back,z),(0,1,0),'dish screwed to the wall')
 stock('Dish',(-.065,-.005,height-.07),(.065,.08,height-.055),'enamel',.003)
 for x in [-.065,.055]:stock('Lip'+str(x),(x,-.005,height-.06),(x+.01,.08,height-.045),'enamel',.001)
 stock('Front',(-.065,.07,height-.06),(.065,.08,height-.045),'enamel',.001)
 stock('Soap',(-.04,.015,height-.056),(.04,.065,height-.032),'terracotta',.004)
 group('SoapDish',start)

def rollertowel(source):
 # Dossier slice 32: a roller towel on its bracket, the towel a loop over the roller.
 start=len(stock_checks);height=source['H'];width=source['W'];back=variants[identity]['rear_wall_y']
 stock('Backboard',(-width/2,back,height-.12),(width/2,.0,height),'wood_dark',.002)
 for z in [height-.1,height-.02]:
  for x in [-width*.4,width*.4]:support(identity,'wall',(x,back,z),(0,1,0),'backboard screwed to the wall')
 for x in [-width/2,width/2-.015]:stock('Arm'+str(x),(x,-.005,height-.1),(x+.015,.1,height-.05),'wood_dark',.002)
 tube('Roller',(-width/2+.005,.07,height-.075),(width/2-.005,.07,height-.075),.025,'timber')
 stock('TowelFront',(-width/2+.03,.094,height-.075-.65),(width/2-.03,.102,height-.07),'linen',.002)
 stock('TowelBack',(-width/2+.03,.038,height-.075-.6),(width/2-.03,.046,height-.07),'linen',.002)
 stock('TowelFold',(-width/2+.03,.038,height-.075-.66),(width/2-.03,.102,height-.075-.6),'linen',.002)
 group('RollerTowel',start)

def mopbucket(source):
 # Dossier slice 32: a galvanised bucket with the mop standing in it, the handle resting on the wall.
 start=len(stock_checks);back=variants[identity]['rear_wall_y']
 lathe('Bucket',0,0,0,[(0,0),(.12,0),(.125,.01),(.15,.28),(.155,.29),(.14,.29),(.115,.02),(0,.02)],'metal')
 wire('Bail',[(-.15,0,.27),(-.1,0,.4),(0,0,.44),(.1,0,.4),(.15,0,.27)],.004,'metal')
 lathe('MopHead',0,0,.015,[(0,0),(.09,0),(.1,.08),(.06,.14),(0,.15)],'linen')
 tube('Handle',(0,0,.14),(0,back+.02,1.3),.014,'timber')
 stock('Cap',(-.02,back,1.27),(.02,back+.025,1.33),'rubber_aged',.002)
 support(identity,'wall',(0,back,1.3),(0,1,0),'handle cap resting on the wall')
 for p in [(.09,0,0),(-.09,0,0),(0,.09,0),(0,-.09,0)]:bearing('bucket '+str(p),p)
 group('MopBucket',start)

def ropecoil(source):
 # Dossier slice 33: a coil of washing line, its free end trailing.
 start=len(stock_checks)
 for i in range(5):
  r=.13-.004*i;z=.011+.018*i
  wire('Turn'+str(i),[(r*math.cos(t),r*math.sin(t),z) for t in np.linspace(0,math.tau,49)],.011,'linen')
 wire('Tail',[(.13,0,.011),(.2,.05,.011),(.28,.02,.011)],.011,'linen')
 stock('Bind',(-.008,-.142,.0),(.008,-.11,.1),'linen',.002)
 for p in [(.13,0,0),(-.13,0,0),(0,.13,0),(0,-.13,0)]:bearing('coil '+str(p),p)
 group('WashingLine',start)

def wateringcan(source):
 # Dossier slice 33: a galvanised watering can with its long spout and rose.
 start=len(stock_checks)
 lathe('Body',0,0,0,[(0,0),(.1,0),(.105,.01),(.105,.24),(.09,.26),(0,.27)],'metal')
 tube('Spout',(.08,0,.06),(.34,0,.32),.012,'metal')
 lathe('Rose',.35,0,.31,[(0,0),(.012,0),(.03,.03),(.03,.036),(0,.036)],'brass')
 wire('Handle',[(-.1,0,.12),(-.16,0,.2),(-.12,0,.32),(0,0,.33),(.07,0,.27)],.008,'metal')
 for p in [(.07,0,0),(-.07,0,0),(0,.07,0),(0,-.07,0)]:bearing('base '+str(p),p)
 group('WateringCan',start)

def trug(source):
 # Dossier slice 33: a shallow wooden gardening trug with its carrying handle.
 start=len(stock_checks)
 stock('Bottom',(-.22,-.11,0),(.22,.11,.012),'timber',.002)
 for y in [-.11,.1]:stock('Side'+str(y),(-.22,y,.008),(.22,y+.01,.09),'timber',.002)
 for x in [-.22,.21]:stock('End'+str(x),(x,-.105,.008),(x+.01,.105,.1),'timber',.002)
 for x in [-.212,.2]:stock('Post'+str(x),(x,-.008,.02),(x+.012,.008,.28),'timber',.0015)
 stock('Bar',(-.2,-.01,.27),(.2,.01,.29),'timber',.002)
 for p in [(-.2,-.09,0),(.2,-.09,0),(-.2,.09,0),(.2,.09,0)]:bearing('trug '+str(p),p)
 group('Trug',start)

def sootsack(source):
 # Dossier slice 34: the chimney sweep's soot sack, tied at the neck and sagging.
 start=len(stock_checks)
 stock('Base',(-.2,-.15,0),(.2,.15,.12),'soot',.03)
 stock('Body',(-.18,-.135,.1),(.18,.135,.42),'soot',.04)
 stock('Shoulder',(-.13,-.1,.4),(.13,.1,.5),'soot',.03)
 stock('Neck',(-.05,-.04,.48),(.05,.04,.58),'soot',.012)
 stock('Tie',(-.055,-.045,.5),(.055,.045,.52),'linen',.004)
 for p in [(-.17,-.12,0),(.17,-.12,0),(-.17,.12,0),(.17,.12,0)]:bearing('sack '+str(p),p)
 group('SootSack',start)

def sweeprods(source):
 # Dossier slice 34: a bundle of sweep's rods with brass ferrules and the brush head, leaning on the wall.
 start=len(stock_checks);back=variants[identity]['rear_wall_y']
 stock('Foot',(-.07,.2,0),(.07,.28,.03),'rubber_aged',.004)
 for i,dx in enumerate([-.03,0,.03]):
  tube('Rod'+str(i),(dx,.24,.02),(dx,back+.03,1.32),.011,'cane')
  for k in range(3):
   t=(k+1)/4;y=.24+(back+.03-.24)*t;z=.02+1.3*t
   tube('Ferrule'+str(i)+'_'+str(k),(dx,y+.012,z-.03),(dx,y-.012,z+.03),.014,'brass')
 stock('Band',(-.06,back,1.2),(.06,.06,1.24),'linen',.003)
 lathe('Brush',0,.1,1.28,[(0,0),(.05,0),(.11,.04),(.11,.07),(.05,.11),(0,.12)],'soot')
 stock('Cap',(-.05,back,1.32),(.05,.05,1.4),'wood_dark',.003)
 support(identity,'wall',(0,back,1.36),(0,1,0),'rod bundle resting on the wall')
 for x in [-.05,.05]:bearing('rod foot '+str(x),(x,.24,0))
 group('SweepRods',start)

def workboots(source):
 # Dossier slice 37: a pair of work boots kicked off at the bed foot, one fallen against the other.
 start=len(stock_checks)
 stock('SoleA',(-.12,-.14,0),(-.02,.14,.022),'rubber_aged',.004)
 stock('HeelA',(-.12,-.14,.021),(-.02,-.08,.034),'rubber_aged',.003)
 stock('VampA',(-.115,-.12,.021),(-.025,.12,.095),'book_brown',.012)
 stock('ShaftA',(-.116,-.13,.033),(-.024,-.02,.2),'book_brown',.01)
 stock('LacesA',(-.078,-.02,.094),(-.062,.08,.0975),'linen',.0008)
 # The second boot lies on its side, its sole against the first.
 stock('SoleB',(-.021,-.14,0),(.001,.14,.1),'rubber_aged',.004)
 stock('HeelB',(0,-.14,0),(.013,-.08,.09),'rubber_aged',.003)
 stock('VampB',(0,-.12,0),(.074,.12,.09),'book_brown',.012)
 stock('ShaftB',(.012,-.13,0),(.18,-.02,.092),'book_brown',.01)
 stock('LacesB',(.073,-.02,.04),(.0765,.08,.056),'linen',.0008)
 for p in [(-.11,-.13,0),(-.03,-.13,0),(-.11,.13,0),(-.03,.13,0),(-.01,0,0),(.04,.08,0),(.1,-.075,0)]:bearing('boot '+str(p),p)
 group('WorkBoots',start)

def dressform(source):
 # Dossier slice 38: a tripod dress form wearing Lena's own voile frock, its hem pinned up on one side.
 start=len(stock_checks)
 lathe('Hub',0,0,.1,[(0,0),(.03,0),(.03,.06),(0,.06)],'timber')
 for i,a in enumerate([math.pi/2,math.pi*7/6,math.pi*11/6]):
  x=.25*math.cos(a);y=.25*math.sin(a)
  tube('Leg'+str(i),(0,0,.14),(x,y,.02),.012,'timber')
  stock('Foot'+str(i),(x-.02,y-.02,0),(x+.02,y+.02,.022),'timber',.003)
  bearing('dress form foot '+str(i),(x,y,0))
 tube('Pole',(0,0,.15),(0,0,.95),.012,'metal')
 lathe('Skirt',0,0,.55,[(0,0),(.26,0),(.27,.01),(.2,.25),(.15,.48),(.14,.5),(0,.5)],'voile')
 lathe('Bodice',0,0,1.05,[(0,0),(.15,0),(.17,.1),(.16,.2),(.13,.3),(.07,.36),(0,.37)],'voile')
 lathe('NeckCap',0,0,1.41,[(0,0),(.035,0),(.035,.04),(0,.05)],'timber')
 # The pinned hem: a row of steel pins through the turned-up edge on the side she was working.
 for i in range(7):
  a=-.6+.2*i
  tube('Pin'+str(i),(.235*math.cos(a),.235*math.sin(a),.585),(.285*math.cos(a),.285*math.sin(a),.59),.0012,'metal')
 group('DressForm',start)

def tsquare(source):
 # Dossier slice 40: Nadia's boxwood T-square hung by its blade hole on a nail, head down.
 start=len(stock_checks);height=source['H'];back=variants[identity]['rear_wall_y']
 tube('Nail',(0,back,height-.03),(0,.04,height-.03),.004,'metal')
 support(identity,'wall',(0,back,height-.03),(0,1,0),'nail driven into the wall')
 stock('Blade',(-.025,0,.045),(.025,.004,height-.01),'timber',.0008)
 stock('Edge',(.023,-.0005,.05),(.027,.0045,height-.012),'wood_dark',.0005)
 stock('Head',(-.11,-.008,0),(.11,.012,.05),'timber',.0015)
 for x in [-.015,.015]:stock('Screw'+str(x),(x-.004,.0115,.02),(x+.004,.0135,.028),'brass',.0005)
 group('TSquare',start)

def verticalfile(source):
 # Dossier slice 41: Peter Wren's second-hand oak four-drawer vertical file, the top drawer not quite shut.
 start=len(stock_checks)
 stock('Plinth',(-.18,-.31,0),(.18,.29,.065),'wood_dark',.004)
 stock('Carcass',(-.19,-.325,.064),(.19,.305,1.3),'timber',.004)
 stock('Top',(-.2,-.33,1.299),(.2,.315,1.335),'timber',.004)
 for i,(z0,z1) in enumerate([(.07,.37),(.38,.68),(.69,.99),(1.0,1.29)]):
  out=.06 if i==3 else 0
  stock('Drawer'+str(i),(-.178,.3045+out,z0),(.178,.322+out,z1),'timber',.003)
  if out:
   for x in [-.17,.152]:stock('DrawerSide'+str(x),(x,.25,z0+.02),(x+.018,.31+out,z1-.03),'timber',.001)
  zp=z0+(z1-z0)*.62
  tube('Pull'+str(i),(-.05,.3215+out,zp),(.05,.3215+out,zp),.008,'metal')
  stock('LabelFrame'+str(i),(-.045,.3215+out,zp+.035),(.045,.325+out,zp+.065),'brass',.0006)
  stock('LabelCard'+str(i),(-.04,.3245+out,zp+.039),(.04,.3255+out,zp+.061),'paper',.0002)
 # Finger grime round the top pull and a cup ring on the top.
 stock('Grime',(-.065,.3815,1.165),(.065,.3825,1.2),'soot',.0002)
 lathe('CupRing',.06,-.12,1.3348,[(.0355,0),(.036,.0002),(.036,.0004),(.0315,.0004),(.031,.0002),(.0315,0),(.0355,0)],'soot')
 for p in [(-.17,-.3,0),(.17,-.3,0),(-.17,.28,0),(.17,.28,0)]:bearing('file '+str(p),p)
 group('VerticalFile',start)

def chargingcase(source):
 # Dossier slice 41: the SR7 battery charging case on the floor by the wall, its cloth lead run up to a wall plate.
 start=len(stock_checks);back=variants[identity]['rear_wall_y']
 stock('Case',(-.18,back+.04,0),(.18,back+.3,.22),'timber',.004)
 stock('Lid',(-.185,back+.035,.218),(.185,back+.305,.24),'timber',.003)
 for x in [-.1,.1]:
  lathe('Terminal'+str(x),x,back+.2,.239,[(0,0),(.012,0),(.012,.02),(.007,.024),(.007,.035),(0,.035)],'brass')
 stock('Handle',(-.06,back+.16,.239),(.06,back+.18,.26),'rubber_aged',.002)
 stock('Plate',(-.05,back,.32),(.05,back+.008,.42),'bakelite',.002)
 support(identity,'wall',(0,back,.37),(0,1,0),'signal plate screwed to the wall')
 wire('Lead',[(-.1,back+.2,.265),(-.12,back+.12,.32),(-.06,back+.05,.36),(0,back+.006,.37)],.004,'linen')
 for p in [(-.16,back+.06,0),(.16,back+.06,0),(-.16,back+.28,0),(.16,back+.28,0)]:bearing('case '+str(p),p)
 group('ChargingCase',start)

def wallbell(source):
 # Dossier slice 42: Teresa's 1912 house bell high on the wall, a Bakelite dome on a brass bracket,
 # its grey cloth flex run down to the signal outlet and taped where she tried to cut it.
 start=len(stock_checks);height=source['H'];back=variants[identity]['rear_wall_y']
 stock('Base',(-.06,back,height-.08),(.06,back+.012,height+.04),'brass',.002)
 support(identity,'wall',(0,back,height-.02),(0,1,0),'bell base screwed to the wall')
 stock('Bracket',(-.03,back+.011,height-.03),(.03,back+.1,height),'brass',.002)
 lathe('Dome',0,back+.06,height-.001,[(0,0),(.05,0),(.05,.008),(.045,.03),(.03,.045),(0,.05)],'bakelite')
 lathe('Knob',0,back+.06,height+.048,[(0,0),(.008,0),(.008,.012),(0,.014)],'brass')
 wire('Flex',[(0,back+.008,height-.06),(0,back+.012,height-.2),(.004,back+.012,.5),(0,back+.012,.006)],.0035,'blanket_grey')
 stock('Tape',(-.008,back+.006,.55),(.008,back+.02,.58),'rubber_aged',.0005)
 group('HouseBell',start)

def quietsign(source):
 # Dossier slice 42: Teresa's quiet sign by the door, a framed card with one hand-drawn stroke
 # and no lettering, and the hook under it where her fob watch hangs when she is home.
 start=len(stock_checks);back=variants[identity]['rear_wall_y'];z0=.06
 stock('Backing',(-.1,back,z0),(.1,back+.006,z0+.15),'plywood',.0005)
 for x in [-.1,.088]:stock('Stile'+str(x),(x,back+.005,z0),(x+.012,back+.018,z0+.15),'wood_dark',.0008)
 for z in [z0,z0+.138]:stock('Rail'+str(z),(-.089,back+.005,z),(.089,back+.018,z+.012),'wood_dark',.0008)
 stock('Card',(-.088,back+.0055,z0+.012),(.088,back+.009,z0+.138),'paper',.0003)
 wire('Stroke',[(-.06,back+.0092,z0+.07),(-.02,back+.0092,z0+.085),(.02,back+.0092,z0+.065),(.06,back+.0092,z0+.08)],.0012,'soot')
 support(identity,'wall',(0,back,z0+.075),(0,1,0),'frame hung on the wall')
 group('QuietSign',start)
 start=len(stock_checks)
 stock('HookPlate',(-.012,back,0),(.012,back+.005,.03),'brass',.0005)
 wire('Hook',[(0,back+.004,.015),(0,back+.03,.015),(0,back+.034,.03)],.0025,'brass')
 support(identity,'wall',(0,back,.015),(0,1,0),'hook plate screwed to the wall')
 group('WatchHook',start)

def overflowtray(source):
 # Dossier slice 44: Wren's japanned umbrella drip tray by the door, the one thing he lets
 # overflow: water standing at the rim and a dark water line spread on the oak around it.
 start=len(stock_checks)
 stock('Spill',(-.21,-.13,0),(.19,.12,.0006),'wood_dark',.0002)
 stock('SpillTongue',(-.25,-.06,0),(-.1,.15,.0005),'wood_dark',.0002)
 stock('Tray',(-.15,-.09,.0004),(.15,.09,.004),'soot',.0008)
 for y in [-.09,.082]:stock('RimY'+str(y),(-.15,y,.003),(.15,y+.008,.03),'soot',.0008)
 for x in [-.15,.142]:stock('RimX'+str(x),(x,-.082,.003),(x+.008,.082,.03),'soot',.0008)
 stock('Water',(-.1425,-.0825,.0035),(.1425,.0825,.0285),'standwater',.0004)
 # Slice 47: his furled umbrella stands in it, tip on the tray floor, leaning to the south wall
 # (0.17 m behind the tray's centre line); the black water alone read as a floor register.
 tip=(.04,.0,.0035);top=(.075,.152,.87)
 def along(t):return tuple(a+(b-a)*t for a,b in zip(tip,top))
 tube('Ferrule',tip,along(.06),.0035,'metal')
 tube('Shaft',along(.04),top,.0048,'metal')
 for i,(a,b,r) in enumerate([(.06,.12,.008),(.11,.2,.011),(.19,.3,.014),(.29,.42,.017),(.41,.58,.0195),(.57,.68,.017),(.67,.75,.0135),(.74,.8,.0095)]):tube('Canopy'+str(i),along(a),along(b),r,'rubber_aged')
 tube('TieStrap',along(.47),along(.51),.0205,'cape_navy')
 wire('Crook',[top,(.075,.155,.93),(.075,.13,.975),(.075,.095,.97),(.075,.08,.935)],.009,'wood_dark')
 for p in [(-.18,-.11,0),(.17,-.11,0),(-.18,.1,0),(.17,.1,0)]:bearing('spill '+str(p),p)
 group('DripTray',start)

def bathshelf(source):
 # Dossier slice 47 (F0x_y_BATH-001): the household's bath set on an opal glass shelf over the basin,
 # hung on two nickel brackets between the basin's coved back and the medicine cabinet's lower edge.
 start=len(stock_checks);back=variants[identity]['rear_wall_y'];z0=.106;yc=back+.062
 stock('Glass',(-.23,back+.004,.1),(.23,back+.125,z0),'opal',.002)
 for x in [-.17,.17]:
  stock('BracketPlate'+str(x),(x-.012,back,.008),(x+.012,back+.0055,.104),'metal',.0008)
  stock('BracketArm'+str(x),(x-.006,back+.005,.094),(x+.006,back+.112,.1002),'metal',.0005)
  tube('BracketBrace'+str(x),(x,back+.004,.022),(x,back+.096,.097),.0042,'metal')
  for z in [.03,.085]:support(identity,'wall',(x,back,z),(0,1,0),'bracket plate screwed to the wall')
 for x in [-.205,.205]:tube('RailPost'+str(x),(x,back+.114,.104),(x,back+.114,.132),.003,'metal')
 tube('Rail',(-.208,back+.114,.13),(.208,back+.114,.13),.003,'metal')
 items=source['set'];widths=source['widths'];gap=.014
 x=-(sum(widths)+gap*(len(items)-1))/2
 for i,(item,w) in enumerate(zip(items,widths)):
  cx=x+w/2;x+=w+gap;tag=str(i);b=z0-.0002
  if item in ['glass','glass_spoon','glass_plain']:
   lathe('Tumbler'+tag,cx,yc,b,[(0,0),(.028,0),(.031,.088),(.0285,.088),(.0255,.0052),(0,.0052)],'tumbler')
   if item=='glass':
    tube('Toothbrush'+tag,(cx+.006,yc+.004,b+.003),(cx+.016,yc+.011,b+.142),.0034,'bone')
    stock('Bristles'+tag,(cx+.0125,yc+.0115,b+.112),(cx+.0215,yc+.0205,b+.138),'linen',.0006)
   if item=='glass_spoon':
    tube('DosingSpoon'+tag,(cx-.006,yc-.003,b+.003),(cx-.014,yc-.009,b+.128),.0018,'metal')
    lathe('SpoonBowl'+tag,cx-.0145,yc-.0145,b+.122,[(0,0),(.009,0),(.01,.004),(0,.004)],'metal')
  elif item in ['pillbottle','antiseptic','amber']:
   s={'pillbottle':.68,'antiseptic':.95,'amber':1.0}[item]
   lathe('Bottle'+tag,cx,yc,b,[(0,0),(.022*s,0),(.024*s,.004),(.024*s,.07*s),(.018*s,.082*s),(.008*s,.088*s),(.008*s,.1*s),(0,.1*s)],'amber')
   lathe('Stopper'+tag,cx,yc,b+.0998*s,[(0,0),(.0088*s,0),(.0088*s,.012),(0,.012)],'rubber_aged')
  elif item=='powder':
   lathe('PowderBox'+tag,cx,yc,b,[(0,0),(.034,0),(.035,.004),(.035,.026),(0,.026)],'enamel')
   lathe('PowderLid'+tag,cx,yc,b+.0258,[(0,0),(.0365,0),(.0365,.007),(.03,.012),(0,.012)],'bone')
   lathe('PowderKnob'+tag,cx,yc,b+.0375,[(0,0),(.006,0),(.006,.005),(.004,.007),(0,.007)],'brass')
  elif item=='pins':
   stock('PinTin'+tag,(cx-.025,yc-.016,b),(cx+.025,yc+.016,b+.012),'brass',.002)
   for k in range(3):tube('HairPin'+tag+str(k),(cx-.022+k*.012,yc+.0155,b+.0118),(cx-.012+k*.012,yc+.0245,b+.0118),.0011,'rubber_aged')
  elif item in ['coldcream','pastilles']:
   lathe('Jar'+tag,cx,yc,b,[(0,0),(.028,0),(.03,.004),(.03,.04),(0,.04)],'enamel' if item=='coldcream' else 'amber')
   lathe('JarLid'+tag,cx,yc,b+.0398,[(0,0),(.031,0),(.031,.009),(.028,.011),(0,.011)],'metal')
  elif item=='comb':
   stock('CombSpine'+tag,(cx-.058,yc-.012,b),(cx+.058,yc-.004,b+.004),'rubber_aged',.0006)
   for k in range(14):stock('CombTooth'+tag+str(k),(cx-.055+k*.0083,yc-.0042,b),(cx-.052+k*.0083,yc+.012,b+.0032),'rubber_aged',.0002)
  elif item in ['soap','carbolic','wrapped']:
   key={'soap':'linen','carbolic':'terracotta','wrapped':'paper'}[item];h=.024 if item!='wrapped' else .02
   stock('Soap'+tag,(cx-w/2+.002,yc-.022,b),(cx+w/2-.002,yc+.022,b+h),key,.005 if item!='wrapped' else .0015)
  elif item=='selvedge':
   stock('Selvedge'+tag,(cx-.058,yc-.009,b),(cx+.058,yc+.009,b+.0022),'voile',.0004)
   stock('SelvedgeEdge'+tag,(cx-.058,yc+.0075,b),(cx+.058,yc+.0112,b+.0026),'linen',.0004)
  elif item=='kohl':
   lathe('KohlPot'+tag,cx,yc,b,[(0,0),(.015,0),(.016,.004),(.016,.024),(0,.024)],'rubber_aged')
   tube('KohlStick'+tag,(cx,yc,b+.02),(cx+.004,yc-.004,b+.075),.0022,'wood_dark')
  elif item=='compact':
   lathe('Compact'+tag,cx,yc,b,[(0,0),(.03,0),(.031,.003),(.031,.009),(.028,.0115),(0,.0115)],'brass')
  elif item=='nailbrush':
   stock('NailBrushBack'+tag,(cx-.04,yc-.016,b+.012),(cx+.04,yc+.016,b+.03),'wood_dark',.003)
   stock('NailBrushBristles'+tag,(cx-.037,yc-.013,b),(cx+.037,yc+.013,b+.0122),'linen',.0008)
  elif item=='mug':
   lathe('ShavingMug'+tag,cx,yc,b,[(0,0),(.036,0),(.038,.072),(.0345,.072),(.0335,.006),(0,.006)],'enamel')
   lathe('BrushHandle'+tag,cx,yc,b+.0058,[(0,0),(.012,0),(.014,.028),(.0115,.05),(0,.05)],'bone')
   lathe('BrushKnot'+tag,cx,yc,b+.0555,[(0,0),(.0115,0),(.017,.025),(.014,.042),(.008,.047),(0,.047)],'blanket_grey')
  elif item=='razor':
   tube('RazorHandle'+tag,(cx-.044,yc,b+.0048),(cx+.028,yc,b+.0048),.0049,'metal')
   stock('RazorHead'+tag,(cx+.027,yc-.022,b),(cx+.04,yc+.022,b+.011),'metal',.0015)
  elif item=='pumice':
   stock('Pumice'+tag,(cx-.03,yc-.02,b),(cx+.03,yc+.02,b+.026),'blanket_grey',.008)
  elif item=='inhaler':
   lathe('Inhaler'+tag,cx,yc,b,[(0,0),(.008,0),(.0085,.004),(.0085,.058),(.005,.066),(0,.066)],'metal')
  elif item=='lipstick':
   lathe('Lipstick'+tag,cx,yc,b,[(0,0),(.0078,0),(.0082,.003),(.0082,.052),(0,.052)],'brass')
  elif item=='tape':
   stock('TapeLine'+tag,(cx-.008,back+.008,b),(cx+.008,back+.121,b+.0006),'paper',.0002)
  elif item=='card':
   stock('RulesCard'+tag,(cx-.04,back+.006,b),(cx+.04,back+.0085,b+.1),'paper',.0004)
  elif item=='cells':
   for k in range(3):
    lathe('Cell'+tag+str(k),cx-.021+k*.021,yc,b,[(0,0),(.0088,0),(.0092,.003),(.0092,.04),(0,.04)],'rubber_aged')
    lathe('CellCap'+tag+str(k),cx-.021+k*.021,yc,b+.0398,[(0,0),(.006,0),(.006,.004),(0,.004)],'brass')
  elif item=='turps':
   lathe('TurpsJar'+tag,cx,yc,b,[(0,0),(.034,0),(.036,.005),(.036,.08),(.03,.088),(0,.088)],'amber')
   lathe('TurpsLid'+tag,cx,yc,b+.0878,[(0,0),(.031,0),(.031,.012),(0,.012)],'metal')
  elif item=='brushtin':
   lathe('BrushTin'+tag,cx,yc,b,[(0,0),(.035,0),(.036,.072),(.033,.072),(.032,.004),(0,.004)],'metal')
   for k,(dx,dy) in enumerate([(-.012,-.006),(.011,-.004),(0,.012)]):
    tube('PaintBrush'+tag+str(k),(cx+dx*.6,yc+dy*.6,b+.002),(cx+dx,yc+dy,b+.118),.0035,'wood_dark')
    lathe('Bristle'+tag+str(k),cx+dx,yc+dy,b+.114,[(0,0),(.0045,0),(.005,.012),(.002,.024),(0,.024)],'blanket_grey')
  elif item=='tongs':
   for k,dy in enumerate([-.009,.009]):stock('Tong'+tag+str(k),(cx-.068,yc+dy-.004,b+k*.0048),(cx+.068,yc+dy+.004,b+.005+k*.0048),'cane',.0008)
   stock('TongJoint'+tag,(cx+.05,yc-.0135,b),(cx+.068,yc+.0135,b+.0098),'cane',.001)
  elif item=='buttonhook':
   tube('ButtonHook'+tag,(cx-.036,yc,b+.0035),(cx+.052,yc,b+.0035),.0016,'metal')
   lathe('HookHandle'+tag,cx-.04,yc,b,[(0,0),(.0065,0),(.007,.007),(0,.007)],'bone')
  else:raise AssertionError(('unknown bath set item',item))
 group('BathShelf',start)

# The remaining recipes are deliberately required before export. A scaffold
# cannot silently fall back to the legacy source boxes and claim completion.
for assembly in assemblies:
 identity=assembly['id'];source=variants[identity]['params'];kind=assembly['kind'];col=Collector()
 if 'asm_'+kind in original:original['asm_'+kind](col,source)
 if kind=='pinboard':pinboard(source,col.rows)
 elif kind=='crate':crate(source,col.rows)
 elif kind=='bookpile':books(source,col.rows)
 elif kind=='cablecoil':cablecoil(source)
 elif kind=='toolboard':toolboard(source)
 elif kind=='reeldeck':reeldeck(source)
 elif kind=='plant':plant(source,col.rows)
 elif kind=='tripod':tripod(source,assembly['members'][0])
 elif kind=='softbox':softbox(source,assembly['members'][0])
 elif kind=='hallstand':hallstand(source)
 elif kind=='artframe':artframe(source)
 elif kind=='garmentrail':garmentrail(source)
 elif kind=='blanket':blanket(source)
 elif kind=='hamper':hamper(source)
 elif kind=='boottray':boottray(source)
 elif kind=='suitcase':suitcase(source)
 elif kind=='sewingmachine':sewingmachine(source)
 elif kind=='teardown':teardown(source)
 elif kind=='easel':easel(source)
 elif kind=='canvasstack':canvasstack(source)
 elif kind=='cardcabinet':cardcabinet(source)
 elif kind=='backdroprail':backdroprail(source)
 elif kind=='printline':printline(source)
 elif kind=='hookstrip':hookstrip(source)
 elif kind=='coathook':coathook(source)
 elif kind=='headsethook':headsethook(source)
 elif kind=='foldedcot':foldedcot(source)
 elif kind=='shovel':shovel(source)
 elif kind=='rakerack':rakerack(source)
 elif kind=='ashcan':ashcan(source)
 elif kind=='signalframe':signalframe(source)
 elif kind=='conduit':conduit(source)
 elif kind=='oilcan':oilcan(source)
 elif kind=='beltnail':beltnail(source)
 elif kind=='stepladder':stepladder(source)
 elif kind=='umbrellastand':umbrellastand(source)
 elif kind=='spittoon':spittoon(source)
 elif kind=='soapdish':soapdish(source)
 elif kind=='rollertowel':rollertowel(source)
 elif kind=='mopbucket':mopbucket(source)
 elif kind=='ropecoil':ropecoil(source)
 elif kind=='wateringcan':wateringcan(source)
 elif kind=='trug':trug(source)
 elif kind=='sootsack':sootsack(source)
 elif kind=='sweeprods':sweeprods(source)
 elif kind=='workboots':workboots(source)
 elif kind=='dressform':dressform(source)
 elif kind=='tsquare':tsquare(source)
 elif kind=='verticalfile':verticalfile(source)
 elif kind=='chargingcase':chargingcase(source)
 elif kind=='wallbell':wallbell(source)
 elif kind=='quietsign':quietsign(source)
 elif kind=='overflowtray':overflowtray(source)
 elif kind=='bathshelf':bathshelf(source)
 else:raise NotImplementedError(('native recipe still required',identity,kind))
