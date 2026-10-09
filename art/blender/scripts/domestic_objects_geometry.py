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
 else:raise NotImplementedError(('native recipe still required',identity,kind))
