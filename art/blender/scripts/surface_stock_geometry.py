"""Ten source-owned passive forms; construction stock grouped by real object."""
import ast
from mathutils import Matrix
source_script=ROOT/'art/blender/scripts/build_orison.py';tree=ast.parse(source_script.read_text(encoding='utf-8'));original={'math':math}
functions={'hash_str','_jit',*('asm_'+kind for kind in ['papers','bookpile','partstray','jarrow','dishrack','cablecoil','bottles','sitemodel'])}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in functions],type_ignores=[]),str(source_script),'exec'),original)
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]
class Collector:
 def __init__(self):self.rows=[]
 def __getattr__(self,name):
  def collect(*args,**kw):self.rows.append((name,args,kw))
  return collect
def stock(label,lo,hi,key,edge=.0006):return box(identity+'_'+label,lo,hi,identity,key,edge)
def lathe(label,x,y,z,profile,key):return vessel(identity+'_'+label,x,y,z,profile,identity,key)
def tube(label,a,b,r,key):return rod(identity+'_'+label,a,b,r,identity,key,48)
def wire(label,points,r,key):return curved_wire(identity+'_'+label,points,r,identity,key)
def bearing(label,point):support(identity,'support',point,(0,0,1),label)
def group(label,start):construction_groups.append({'assembly':identity,'id':identity+'_'+label,'stocks':[x['name'] for x in stock_checks[start:]]})
def transform(obj,matrix):
 for vertex in obj.data.vertices:vertex.co=matrix@(vertex.co+obj.location)
 obj.location=(0,0,0)
 if 'uv_axis' in obj:
  obj['uv_axis']=matrix.to_3x3()@Vector(obj['uv_axis']);obj['uv_center']=matrix@Vector(obj['uv_center'])
 return obj
def ring(label,x,y,z,outer,inner,height,key):
 bevel=min(.0007,height*.18,(outer-inner)*.18)
 return lathe(label,x,y,z,[(outer-bevel,0),(outer,bevel),(outer,height-bevel),(outer-bevel,height),(inner+bevel,height),(inner,height-bevel),(inner,bevel),(inner+bevel,0),(outer-bevel,0)],key)
def book(label,lo,hi,key):
 x0,y0,z0=lo;x1,y1,z1=hi;t=.0014
 stock(label+'_LowerCover',(x0,y0,z0),(x1,y1,z0+t),key,.0003)
 stock(label+'_UpperCover',(x0,y0,z1-t),(x1,y1,z1),key,.0003)
 stock(label+'_Pages',(x0+.001,y0+.002,z0+t-.0001),(x1-.001,y1-.001,z1-t+.0001),'paper',.0002)
 stock(label+'_Spine',(x0,y1-.002,z0),(x1,y1,z1),key,.0004)
def mug(source):
 key=source.get('mat','porcelain');start=len(stock_checks)
 lathe('Cup',0,0,0,[(0,0),(.028,0),(.034,.001),(.039,.008),(.040,.090),(.038,.098),(.036,.100),(.033,.099),(.034,.094),(.036,.012),(.027,.005),(0,.005)],key)
 points=[(.037+.025*math.sin(math.pi*t),0,.026+.054*t) for t in np.linspace(0,1,33)]
 wire('Handle',points,.0065,key);bearing('cup foot',(0,0,0));group('Mug',start)
def headphones(source):
 start=len(stock_checks)
 lathe('Stand',0,0,0,[(0,0),(.063,0),(.065,.002),(.05,.012),(.012,.022),(.009,.24),(.02,.25),(.014,.26),(0,.265)],'wood_dark')
 # A formed arch with rectangular cross-section, seated on the turned crown.
 n=48;verts=[]
 for theta in np.linspace(0,math.pi,n+1):
  for radius in (.061,.065):
   for y in (-.010,.010):verts.append((radius*math.cos(theta),y,.2+radius*math.sin(theta)))
 faces=[(0,1,3,2),(n*4,n*4+2,n*4+3,n*4+1)]
 for i in range(n):
  a=i*4;b=a+4
  faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
 solid(identity+'_Headband',verts,faces,identity,'bakelite')
 for side in (-1,1):
  # Closed back and annular ear pad are distinct manufactured stock.
  cup=along_x(identity+'_Earcup'+str(side),0,0,.158,[(0,.080),(.023,.080),(.038,.072),(.040,.06),(.035,.050),(0,.050)],identity,'bakelite')
  pad=along_x(identity+'_EarPad'+str(side),0,0,.158,[(.035,.052),(.039,.048),(.036,.043),(.024,.043),(.023,.051),(.035,.052)],identity,'rubber_aged')
  if side<0:
   for obj in (cup,pad):
    for v in obj.data.vertices:v.co.x=-v.co.x
    obj.location.x=-obj.location.x
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
  tube('Yoke'+str(side),(side*.062,0,.197),(side*.062,0,.204),.007,'nickel_plated')
  tube('CupPivot'+str(side),(side*.059,-.011,.196),(side*.065,.011,.196),.003,'nickel_plated')
 wire('Lead',[(-.062,0,.120),(-.064,.012,.086),(-.035,.034,.030),(.008,.057,.006),(.05,.09,.004)],.004,'rubber_aged')
 bearing('turned stand',(0,0,0));group('Headphones',start)
def papers(source,collected):
 start=len(stock_checks);z=0.
 for index,(shape,args,kw) in enumerate(collected):
  if shape!='box':continue
  key,x0,y0,old0,x1,y1,old1=args;thick=old1-old0
  # Original slabs represent document bundles; remove their unsupported gaps.
  for layer in range(5):
   t=thick/5;inset=(layer%2)*.0004
   stock('Bundle%d_Sheet%d'%(index,layer),(x0+inset,y0,z+layer*t),(x1,y1-inset,z+(layer+1)*t),key,.00008)
  retained_stock.append({'assembly':identity,'kind':'paper_bundle','index':index,'source_args':args,'base':z,'height':thick});z+=thick
 bearing('paper bundle',((collected[0][1][1]+collected[0][1][4])*.5,(collected[0][1][2]+collected[0][1][5])*.5,0));group('Papers',start)
def books(source,collected):
 start=len(stock_checks)
 for index,(shape,args,kw) in enumerate(collected):
  key,*bounds=args;book('Book'+str(index),bounds[:3],bounds[3:],key);retained_stock.append({'assembly':identity,'kind':'book','index':index,'source_args':args})
 bearing('bound book pile',(0,0,0));group('Books',start)
def jar(label,x,y,height,fill,key='glassish'):
 start=len(stock_checks)
 lathe(label+'_Glass',x,y,0,[(0,0),(.036,0),(.044,.006),(.046,.011),(.046,.110),(.039,.122),(.035,.122),(.035,.115),(.042,.106),(.042,.014),(.033,.004),(0,.004)],key)
 lathe(label+'_Lid',x,y,.120,[(.035,0),(.04,0),(.041,.004),(.04,.027),(.037,.028),(0,.028),(0,.024),(.035,.024),(.035,0)],'bakelite')
 # The source fill identifies the sorted finish; model a small seated stack.
 levels=max(2,round((height-.006)/.010))
 for i in range(levels):
  z=.004+i*.009
  for j,(dx,dy) in enumerate([(-.018,-.012),(.018,-.012),(0,.020)]):ring(label+'_Washer'+str((i,j)),x+dx,y+dy,z,.011,.005,.009,fill)
 bearing(label+' jar base',(x,y,0));group(label,start)
def jars(source,collected):
 fills=[args for shape,args,kw in collected if shape=='box'];n=len(fills)
 for i,args in enumerate(fills):
  key,x0,y0,z0,x1,y1,z1=args;jar('Jar'+str(i),(x0+x1)*.5,(y0+y1)*.5,z1,key)
  retained_stock.append({'assembly':identity,'kind':'salvage_jar','index':i,'source_fill':args})
def tray(source,collected):
 start=len(stock_checks)
 stock('TrayBottom',(-.20,-.14,0),(.20,.14,.004),'metal',.0007)
 for s in (-1,1):
  stock('TraySide'+str(s),(s*.2-.003,-.14,.002),(s*.2+.003,.14,.045),'metal',.001)
  stock('TrayEnd'+str(s),(-.2,s*.14-.003,.002),(.2,s*.14+.003,.045),'metal',.001)
 # Original twelve sorted items keep their finish, count and footprint cells.
 original_parts=[args for shape,args,kw in collected if shape=='box' and abs(args[3]-.012)<1e-8]
 assert len(original_parts)==12
 for i,args in enumerate(original_parts):
  key,x0,y0,z0,x1,y1,z1=args;x=(x0+x1)/2;y=(y0+y1)/2;h=z1-z0
  if key in ['brass','chrome']:
   ring('SortedRing'+str(i),x,y,.004,.023,.010,h,key)
  elif key=='bakelite':
   lathe('SortedBobbin'+str(i),x,y,.004,[(0,0),(.024,0),(.024,.003),(.017,.004),(.017,h-.003),(.024,h-.003),(.024,h),(0,h)],key)
  else:
   stock('SortedBlock'+str(i),(x0,y0,.004),(x1,y1,.004+h),key,.002)
  retained_stock.append({'assembly':identity,'kind':'sorted_part','index':i,'source_args':args})
 bearing('formed tray',(0,0,0));group('Tray',start)
 if not source.get('chassis'):return
 start=len(stock_checks)
 stock('ChassisFloor',(.26,-.12,0),(.52,.12,.006),'bakelite',.001)
 for sx in (.263,.517):stock('ChassisEnd'+str(sx),(sx-.003,-.12,.004),(sx+.003,.12,.05),'bakelite',.0008)
 for sy in (-.117,.117):stock('ChassisSide'+str(sy),(.26,sy-.003,.004),(.52,sy+.003,.05),'bakelite',.0008)
 stock('ChassisDeck',(.26,-.12,.045),(.52,.12,.05),'bakelite',.001)
 for i,tx in enumerate((.32,.40,.47)):
  y=original['_jit'](source['id'],i+40,-.06,.06)
  ring('ValveSocket'+str(i),tx,y,.049,.016,.006,.007,'nickel_plated')
  # Open lower skirt fits the socket; a single glass wall closes over the dome.
  lathe('ValveGlass'+str(i),tx,y,.054,[(.012,0),(.014,.008),(.013,.050),(.009,.061),(0,.062),(0,.059),(.007,.058),(.011,.048),(.012,.008),(.010,0),(.012,0)],'glassish')
  tube('ValveCore'+str(i),(tx,y,.050),(tx,y,.104),.005,'nickel_plated')
 lathe('ChassisCoil',.34,.07,.050,[(0,0),(.022,0),(.022,.035),(0,.035)],'brass')
 bearing('open chassis',(.39,0,0));group('Chassis',start)

def dishrack(source):
 start=len(stock_checks);W=source.get('W',.12);D=source.get('D',.26);n=max(2,int(source.get('n',4)))
 for sx in (-1,1):
  x=sx*W/2
  tube('LowerRail'+str(sx),(x,-D/2,.012),(x,D/2,.012),.005,'nickel_plated')
  for sy in (-1,1):
   y=sy*D/2
   lathe('Foot'+str((sx,sy)),x,y,0,[(0,0),(.007,0),(.007,.009),(0,.009)],'rubber_aged')
   tube('Upright'+str((sx,sy)),(x,y,.012),(x,y,.105),.005,'nickel_plated')
 for sy in (-1,1):
  # Cross feet bridge the actual drainboard ribs beneath the narrow rack.
  stock('CrossFoot'+str(sy),(-W/2,sy*D/2-.004,0),(W/2,sy*D/2+.004,.008),'nickel_plated',.0004)
  for x in ((-.015,.035) if W>.10 else (-W*.3,W*.3)):bearing('cross foot '+str((sy,x)),(x,sy*D/2,0))
  tube('TopEnd'+str(sy),(-W/2,sy*D/2,.105),(W/2,sy*D/2,.105),.005,'nickel_plated')
  tube('Cradle'+str(sy),(-W/2,sy*.042,.019),(W/2,sy*.042,.019),.004,'nickel_plated')
 for i in range(n):
  x=-W*.36+W*.72*i/max(1,n-1);radius=min(.095,D*.40)
  along_x(identity+'_Plate'+str(i),x,0,.105,[(0,-.005),(.04,-.005),(.075,-.003),(radius,.004),(radius+.006,.005),(radius+.005,.008),(radius,.009),(.073,.001),(.04,-.001),(0,-.001)],identity,'porcelain')
  retained_stock.append({'assembly':identity,'kind':'plate','index':i,'source_radius':radius})
 group('RackAndPlates',start)
def cablecoil(source):
 start=len(stock_checks);radius=source.get('r',.11)
 path=[(radius*math.cos(t),radius*math.sin(t),.010+.010*math.sin(2*t)**2) for t in np.linspace(0,math.tau,129)]
 wire('Coil',path,.010,'rubber_aged')
 end=(radius+original['_jit'](identity,1,.18,.30),original['_jit'](identity,2,-.15,.15),.008)
 # Smooth tangent changes instead of three visibly kinked straight segments.
 controls=[Vector((radius,0,.008)),Vector((radius+.07,end[1]*.12,.008)),Vector((end[0]-.05,end[1]*.8,.008)),Vector(end)]
 path=[tuple((1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3]) for t in np.linspace(0,1,33)]
 wire('Tail',path,.008,'rubber_aged')
 for angle in (0,math.pi/2,math.pi,3*math.pi/2):bearing('coil bearing '+str(angle),(radius*math.cos(angle),radius*math.sin(angle),0))
 bearing('cable tail',(*path[-3][:2],0));group('Cable',start)
def bottles(source,collected):
 index=0;upright_count=source.get('n',5)-1
 columns=min(3,upright_count);rows_count=math.ceil(upright_count/columns)
 def standing_center(i):
  return ((i%columns-(columns-1)/2)*.080, -.035 if rows_count==1 else -.090+(i//columns)*.075)
 for shape,args,kw in collected:
  start=len(stock_checks);key=args[0]
  if shape=='tube':
   _,a,b,radius,n=args;length=(Vector(b)-Vector(a)).length
   # Separate the can's lid so its hollow shell has one contiguous boundary.
   profile=[(0,0),(radius-.002,0),(radius,.003),(radius,length-.003),(radius-.002,length),(radius-.003,length),(radius-.003,.003),(0,.003)]
   if not source.get('cans'):
    profile=[(0,0),(radius-.002,0),(radius,.003),(radius,length*.58),(.013,length*.76),(.012,length-.006),(.014,length),(.010,length),(.009,length*.77),(radius-.002,length*.57),(radius-.003,.003),(0,.003)]
   obj=lathe('Fallen'+str(index),0,0,0,profile,key)
   axis=(Vector(b)-Vector(a)).normalized();u=Vector((0,0,-1));v=axis.cross(u)
   rot=Matrix((u,v,axis)).transposed().to_4x4()
   transform(obj,Matrix.Translation(Vector(a))@rot)
   if source.get('cans'):
    lid=lathe('FallenLid'+str(index),0,0,0,[(0,length-.003),(radius-.001,length-.003),(radius-.001,length-.001),(0,length-.001)],key)
    transform(lid,Matrix.Translation(Vector(a))@rot)
   bearing('fallen container',(a[0]+(b[0]-a[0])*.3,a[1]+(b[1]-a[1])*.3,0))
  elif shape=='cyl':
   _,x,y,z0,z1,r0,r1,n=args;h=z1-z0
   x,y=standing_center(index)
   lathe('Can'+str(index),x,y,0,[(0,0),(.029,0),(.033,.002),(.033,.004),(.032,.006),(.032,h-.004),(.033,h-.003),(.032,h),(.029,h),(.030,.004),(0,.004)],key)
   lathe('CanLid'+str(index),x,y,0,[(0,h-.003),(.031,h-.003),(.031,h-.001),(0,h-.001)],key)
   bearing('can base '+str(index),(x,y,0))
  elif shape=='lathe':
   _,x,y,profile,n=args;h=profile[-1][1]
   x,y=standing_center(index)
   lathe('Bottle'+str(index),x,y,0,[(0,0),(.028,0),(.031,.002),(.033,h*.55),(.013,h*.72),(.012,h-.008),(.014,h-.006),(.014,h),(.010,h),(.009,h-.007),(.010,h*.73),(.030,h*.54),(.028,.004),(0,.004)],key)
   bearing('bottle base '+str(index),(x,y,0))
  else:raise AssertionError((identity,shape))
  retained_stock.append({'assembly':identity,'kind':'can' if source.get('cans') else 'bottle','index':index,'source_shape':shape,'source_args':args,**({'adapted_center':list(standing_center(index)),'adaptation':'Original upright cylinders overlap; preserve count/height and separate within the supporting surface.'} if shape!='tube' else {})});group('Container'+str(index),start);index+=1
 assert index==source.get('n',5)
def sitemodel(source,collected):
 start=len(stock_checks)
 for i,(shape,args,kw) in enumerate(collected):
  key,x0,y0,z0,x1,y1,z1=args
  if i==2:
   # Card walls, roof and base retain the original massing silhouette.
   t=.0015
   stock('MainBase',(x0,y0,z0),(x1,y1,z0+t),key,.00015)
   stock('MainRoof',(x0,y0,z1-t),(x1,y1,z1),key,.00015)
   for side,y in enumerate((y0,y1-t)):stock('MainEnd'+str(side),(x0,y,z0),(x1,y+t,z1),key,.00015)
   for side,x in enumerate((x0,x1-t)):stock('MainSide'+str(side),(x,y0,z0),(x+t,y1,z1),key,.00015)
  else:stock('ModelStock'+str(i),(x0,y0,z0),(x1,y1,z1),key,.00025)
  retained_stock.append({'assembly':identity,'kind':'model_mass','index':i,'source_args':args})
 bearing('model base',(0,0,0));group('MassingStudy',start)

# Dossier kitchen sets (BW-001 kitchen pages, slice 7): four more closed forms
# with the same helpers and bearings. Sizes are period domestic ware; each
# record's retained frame box is authored to the same envelope.
def kettle(source):
 start=len(stock_checks)
 lathe('Body',0,0,0,[(0,0),(.072,0),(.084,.004),(.090,.030),(.088,.100),(.070,.125),(.040,.134),(.040,.140),(0,.140)],'enamel')
 lathe('Knob',0,0,.140,[(0,0),(.012,0),(.014,.008),(.008,.015),(0,.017)],'bakelite')
 tube('Spout',(.070,0,.070),(.115,0,.132),.011,'enamel')
 wire('Handle',[(-.052,0,.118),(-.052,0,.165),(-.030,0,.198),(0,0,.208),(.030,0,.198),(.052,0,.165),(.052,0,.118)],.007,'bakelite')
 bearing('kettle base',(0,0,0));group('Kettle',start)
def tin(source):
 start=len(stock_checks);key=source.get('mat','nickel_plated')
 lathe('Can',0,0,0,[(0,0),(.048,0),(.050,.002),(.050,.115),(.048,.117),(0,.117)],key)
 lathe('Lid',0,0,.117,[(0,0),(.051,0),(.052,.004),(.052,.012),(.050,.014),(0,.014)],key)
 bearing('tin base',(0,0,0));group('Tin',start)
def board(source):
 start=len(stock_checks)
 stock('Slab',(-.17,-.11,0),(.17,.11,.020),'timber',.0015)
 stock('Handle',(.17,-.03,.004),(.23,.03,.016),'timber',.0012)
 for p in [(-.12,-.08),(.12,-.08),(-.12,.08),(.12,.08)]:bearing('board corner '+str(p),(p[0],p[1],0))
 group('BreadBoard',start)
def plate(source):
 start=len(stock_checks)
 lathe('Dish',0,0,0,[(0,0),(.095,0),(.105,.003),(.112,.012),(.110,.016),(.104,.015),(.098,.006),(0,.008)],'porcelain')
 bearing('plate foot',(0,0,0));group('Plate',start)

# Dossier resident surfaces (slice 9): eight more self-contained closed forms.
def sheets(source):
 start=len(stock_checks);n=int(source.get('n',8));w=source.get('W',.21);d=source.get('D',.30)
 for layer in range(n):
  dx=.0012*((layer*7)%3-1);dy=.0015*((layer*5)%3-1)
  stock('Sheet%d'%layer,(-w/2+dx,-d/2+dy,layer*.0025),(w/2+dx,d/2+dy,(layer+1)*.0025),'paper',.00008)
 bearing('sheet stack',(0,0,0));group('Sheets',start)
def volumes(source):
 start=len(stock_checks)
 book('Lower',(-.11,-.08,0),(.11,.08,.032),'book_navy')
 book('Upper',(-.10,-.075,.032),(.10,.07,.058),'book_burgundy')
 bearing('book pile',(0,0,0));group('Volumes',start)
def brasstray(source):
 start=len(stock_checks)
 stock('Bottom',(-.17,-.12,0),(.17,.12,.004),'brass',.0006)
 for s in (-1,1):
  stock('Side'+str(s),(s*.17-.003,-.12,.004),(s*.17+.003,.12,.03),'brass',.0008)
  stock('End'+str(s),(-.17,s*.12-.003,.004),(.17,s*.12+.003,.03),'brass',.0008)
 for p in [(-.14,-.09),(.14,-.09),(-.14,.09),(.14,.09)]:bearing('tray foot '+str(p),(p[0],p[1],0))
 group('BrassTray',start)
def frame(source):
 start=len(stock_checks)
 stock('Face',(-.075,-.006,0),(.075,.006,.10),'wood_dark',.0008)
 stock('Print',(-.06,-.0068,.012),(.06,-.006,.088),'paper',.0002)
 stock('Strut',(-.01,.006,0),(.01,.045,.06),'wood_dark',.0006)
 bearing('frame foot',(0,0,0));bearing('strut foot',(0,.04,0));group('StandingFrame',start)
def clock(source):
 start=len(stock_checks)
 along_x(identity+'_Case',0,0,.047,[(0,-.016),(.045,-.016),(.047,-.013),(.047,.013),(.045,.016),(0,.016)],identity,'nickel_plated')
 stock_checks.append({'name':identity+'_Case','assembly':identity,'key':'nickel_plated'}) if False else None
 lathe('Face',0,-.016,.047,[(0,0),(.040,0),(.040,.001),(0,.001)],'porcelain') if False else None
 for s in (-1,1):lathe('Bell'+str(s),0,s*.022,.090,[(0,0),(.012,0),(.013,.006),(.008,.012),(0,.014)],'brass')
 stock('Yoke',(-.004,-.026,.086),(.004,.026,.090),'brass',.0003)
 for s in (-1,1):stock('Leg'+str(s),(-.004,s*.028-.004,0),(.004,s*.028+.004,.012),'nickel_plated',.0003)
 bearing('clock foot',(0,-.028,0));bearing('clock foot b',(0,.028,0));group('AlarmClock',start)
def can(source):
 start=len(stock_checks)
 lathe('Body',0,0,0,[(0,0),(.14,0),(.145,.004),(.145,.33),(.14,.335),(0,.335)],'metal')
 lathe('Lid',0,0,.335,[(0,0),(.15,0),(.152,.006),(.15,.012),(.10,.03),(0,.034)],'metal')
 wire('LidHandle',[(-.06,0,.364),(-.06,0,.39),(.06,0,.39),(.06,0,.364)],.005,'metal')
 bearing('can base',(0,0,0));group('GalvanisedCan',start)
def parcel(source):
 start=len(stock_checks)
 stock('Box',(-.12,-.09,0),(.12,.09,.08),'paper',.0008)
 stock('StringAlong',(-.12,-.0025,.08),(.12,.0025,.0825),'bakelite',.0002)
 stock('StringAcross',(-.0025,-.09,.0825),(.0025,.09,.085),'bakelite',.0002)
 bearing('parcel base',(0,0,0));group('Parcel',start)
def flask(source):
 start=len(stock_checks)
 lathe('Body',0,0,0,[(0,0),(.04,0),(.042,.003),(.042,.24),(.04,.25),(.03,.255),(.03,.27),(.035,.272),(.035,.29),(0,.29)],'nickel_plated')
 bearing('flask base',(0,0,0));group('VacuumFlask',start)

# Dossier slice 11: card cartons, reel boxes in rows and a wire wastebasket.
def carton(source):
 start=len(stock_checks);w,d,h=.28,.2,.12
 stock('Body',(-w/2,-d/2,0),(w/2,d/2,h-.03),'paper',.0008)
 stock('Lid',(-w/2-.002,-d/2-.002,h-.03),(w/2+.002,d/2+.002,h),'paper',.0008)
 bearing('carton base',(0,0,0));group('Carton',start)
def reelbox(source):
 start=len(stock_checks);w,h=.19,.03
 stock('Body',(-w/2,-w/2,0),(w/2,w/2,h-.008),'paper',.0006)
 stock('Lid',(-w/2-.002,-w/2-.002,h-.008),(w/2+.002,w/2+.002,h),'paper',.0006)
 bearing('reel box base',(0,0,0));group('ReelBox',start)
def boxrow(source):
 count=14;pitch=.034;x0=-pitch*(count-1)/2
 for i in range(count):
  # Each standing box is its own physical object: a card box with a seam line.
  start=len(stock_checks);x=x0+i*pitch;lean=(.004,-.003,0)[i%3]
  stock('Box'+str(i),(x-.014,-.095+lean,0),(x+.014,.095+lean,.19),'paper',.0006)
  stock('Seam'+str(i),(x-.0145,-.0955+lean,.165),(x+.0145,.0955+lean,.167),'bakelite',.0002)
  bearing('box '+str(i),(x,lean,0));group('Box'+str(i),start)
def basket(source):
 start=len(stock_checks)
 lathe('Wall',0,0,0,[(0,0),(.115,0),(.118,.002),(.13,.3),(.133,.3),(.133,.302),(.128,.302),(.126,.3),(.114,.004),(0,.004)],'metal')
 # Crushed sheets as a chain of overlapping balls from the basket floor over the rim.
 for i,(x,y,z,rr) in enumerate([(0,0,.063,.06),(.045,.03,.145,.055),(-.03,-.01,.2,.05),(.015,-.045,.265,.045),(-.01,.01,.305,.04)]):
  lathe('Paper'+str(i),x,y,z,[(0,-rr)]+[(rr*math.sin(t),-rr*math.cos(t)) for t in np.linspace(.2,math.pi-.2,9)]+[(0,rr)],'paper')
 bearing('basket base',(0,0,0));group('WireBasket',start)
# Dossier slice 16: bedside and tabletop pieces.
def spectacles(source):
 start=len(stock_checks)
 for side in [-1,1]:
  x=side*.032
  ring('Rim'+str(side),x,0,0,.024,.020,.004,'metal')
  lathe('Lens'+str(side),x,0,.0005,[(0,0),(.0205,0),(.0205,.0025),(0,.0025)],'glassish')
  tube('Temple'+str(side),(side*.054,.0,.003),(side*-.01,.012,.003),.0012,'metal')
  for r in [-.022,.022]:bearing('rim '+str((side,r)),(x+r,0,0))
 tube('Bridge',(-.0095,0,.003),(.0095,0,.003),.0015,'metal')
 group('Spectacles',start)
def pencil(source):
 start=len(stock_checks)
 stock('Shaft',(-.085,-.0035,0),(.085,.0035,.007),'book_burgundy',.0008)
 stock('Point',(.084,-.0025,.001),(.1,.0025,.006),'timber',.0006)
 for x in [-.07,.07]:bearing('pencil '+str(x),(x,0,0))
 group('Pencil',start)
def booklet(source):
 start=len(stock_checks);key=source.get('mat','book_teal')
 stock('LowerCover',(-.075,-.05,0),(.075,.05,.0013),key,.0003)
 stock('Pages',(-.072,-.047,.0012),(.072,.047,.0108),'paper',.0002)
 stock('UpperCover',(-.075,-.05,.0107),(.075,.05,.012),key,.0003)
 stock('Spine',(-.075,-.05,0),(-.071,.05,.012),key,.0003)
 for x in [-.06,.06]:
  for y in [-.04,.04]:bearing('booklet '+str((x,y)),(x,y,0))
 group('Booklet',start)
def wallet(source):
 start=len(stock_checks)
 stock('Body',(-.055,-.045,0),(.055,.045,.022),'book_brown',.004)
 stock('Note',(.02,.03,.008),(.07,.06,.012),'paper',.0002)
 for x in [-.045,.045]:
  for y in [-.035,.035]:bearing('wallet '+str((x,y)),(x,y,0))
 group('Wallet',start)
def foldrule(source):
 start=len(stock_checks)
 for i in range(4):stock('Leaf'+str(i),(-.075,-.008,i*.003),(.075,.008,i*.003+.0031),'timber',.0003)
 for x in [-.068,.068]:lathe('Rivet'+str(x),x,0,0,[(0,0),(.004,0),(.004,.0125),(0,.0125)],'brass')
 for x in [-.06,.06]:bearing('rule '+str(x),(x,0,0))
 group('FoldingRule',start)
def case(source):
 start=len(stock_checks)
 stock('Body',(-.06,-.04,0),(.06,.04,.045),'book_brown',.003)
 stock('Lining',(-.055,-.035,.044),(.055,.035,.046),'book_burgundy',.0005)
 stock('Lid',(-.06,.036,.044),(.06,.04,.11),'book_brown',.0015)
 for x in [-.05,.05]:
  for y in [-.03,.03]:bearing('case '+str((x,y)),(x,y,0))
 group('OpenCase',start)
def gloves(source):
 for g,cx in enumerate([-.045,.045]):
  start=len(stock_checks)
  stock('Palm'+str(g),(cx-.033,-.04,0),(cx+.033,.01,.006),'book_brown',.002)
  for f in range(4):
   fx=cx-.024+f*.016;stock('Finger'+str((g,f)),(fx-.006,.009,0),(fx+.006,.045+.004*(f%2),.005),'book_brown',.002)
  side=1 if g else -1;stock('Thumb'+str(g),(min(cx+side*.032,cx+side*.048),-.03,0),(max(cx+side*.032,cx+side*.048),.0,.005),'book_brown',.002)
  bearing('palm '+str(g),(cx,-.015,0));group('Glove'+str(g),start)
def hammer(source):
 start=len(stock_checks)
 stock('Handle',(-.14,-.012,0),(.10,.012,.022),'timber',.003)
 stock('Head',(.09,-.035,0),(.125,.035,.03),'metal',.002)
 for p in [(-.12,0,0),(.11,-.025,0),(.11,.025,0)]:bearing('hammer '+str(p),p)
 group('Hammer',start)
# Dossier slice 19: seed jars, cloth-covered objects, a folded cloth.
def seedjars(source,gap=False):
 for row,y in enumerate([-.045,.045]):
  for i in range(8):
   if gap and row==1 and i==7:continue
   start=len(stock_checks);x=-.28+i*.08
   lathe('Jar'+str((row,i)),x,y,0,[(0,0),(.03,0),(.032,.004),(.032,.085),(.026,.092),(.026,.1),(0,.1)],'glassish')
   lathe('Lid'+str((row,i)),x,y,.0985,[(0,0),(.028,0),(.028,.012),(0,.012)],'bakelite')
   bearing('jar '+str((row,i)),(x+.022,y,0));group('Jar'+str((row,i)),start)
def covered(source):
 start=len(stock_checks)
 stock('Object',(-.09,-.07,0),(.09,.07,.12),'paper',.003)
 stock('Drape',(-.1,-.08,.03),(.1,.08,.128),'linen',.012)
 for x in [-.07,.07]:
  for y in [-.05,.05]:bearing('covered '+str((x,y)),(x,y,0))
 group('CoveredObject',start)
def foldedcloth(source):
 start=len(stock_checks)
 for i in range(4):stock('Fold'+str(i),(-.11,-.08,i*.008),(.11,.08,i*.008+.0085),'linen',.003)
 for x in [-.09,.09]:
  for y in [-.06,.06]:bearing('cloth '+str((x,y)),(x,y,0))
 group('FoldedCloth',start)
# Dossier slice 20: a row of labelled box files.
def fileboxes(source):
 keys=['book_navy','book_green','book_burgundy','book_navy','book_brown','book_green','book_navy']
 for i,key in enumerate(keys):
  start=len(stock_checks);x=-.345+i*.115
  stock('Box'+str(i),(x-.054,-.125,0),(x+.054,.125,.26),key,.002)
  stock('Label'+str(i),(x-.035,.1245,.15),(x+.035,.127,.21),'paper',.0003)
  stock('Pull'+str(i),(x-.012,.1245,.06),(x+.012,.131,.075),'brass',.0006)
  bearing('box file '+str(i),(x,0,0));group('BoxFile'+str(i),start)
# Dossier slice 22: the icebox drip pan, wet or dry.
def driptray(source,wet=True):
 start=len(stock_checks)
 stock('Pan',(-.24,-.25,0),(.24,.25,.004),'nickel_plated',.001)
 for y in [-.25,.242]:stock('RimLong'+str(y),(-.24,y,.003),(.24,y+.008,.03),'nickel_plated',.0008)
 for x in [-.24,.232]:stock('RimEnd'+str(x),(x,-.243,.003),(x+.008,.243,.03),'nickel_plated',.0008)
 if wet:stock('Water',(-.233,-.243,.0035),(.233,.243,.013),'glassish',.0004)
 else:stock('Dust',(-.233,-.243,.0035),(.233,.243,.0045),'paper',.0002)
 for p in [(-.22,-.23,0),(.22,-.23,0),(-.22,.23,0),(.22,.23,0)]:bearing('pan corner '+str(p),p)
 group('DripPan',start)
# Dossier slice 24: an out-tray of receipts, a torch, a battery case, a cap and a light table.
def outtray(source):
 start=len(stock_checks)
 stock('Tray',(-.14,-.1,0),(.14,.1,.006),'wood_dark',.001)
 for y in [-.1,.092]:stock('Side'+str(y),(-.14,y,.005),(.14,y+.008,.045),'wood_dark',.001)
 for x in [-.14,.132]:stock('End'+str(x),(x,-.093,.005),(x+.008,.093,.045),'wood_dark',.001)
 for i in range(5):stock('Receipt'+str(i),(-.12+i*.003,-.08+i*.002,.0055+i*.004),(.11+i*.002,.08-i*.003,.0095+i*.004),'paper',.0002)
 for p in [(-.12,-.08,0),(.12,-.08,0),(-.12,.08,0),(.12,.08,0)]:bearing('tray '+str(p),p)
 group('OutTray',start)
def torch(source):
 start=len(stock_checks)
 tube('Barrel',(-.1,0,.018),(.08,0,.018),.018,'nickel_plated')
 tube('Head',(.075,0,.026),(.125,0,.026),.026,'nickel_plated')
 tube('Lens',(.124,0,.026),(.128,0,.026),.021,'glassish')
 stock('Switch',(-.02,-.006,.034),(.01,.006,.04),'bakelite',.0005)
 for p in [(-.08,0,0),(.1,0,0)]:bearing('torch '+str(p),p)
 group('Torch',start)
def batterycase(source):
 start=len(stock_checks)
 stock('Case',(-.12,-.08,0),(.12,.08,.16),'wood_dark',.004)
 for i,x in enumerate([-.055,.055]):
  lathe('Cell'+str(i),x,0,.155,[(0,0),(.04,0),(.04,.03),(.034,.036),(0,.036)],'glassish')
  tube('Terminal'+str(i),(x,0,.19),(x,0,.205),.006,'brass')
 for p in [(-.1,-.06,0),(.1,-.06,0),(-.1,.06,0),(.1,.06,0)]:bearing('case '+str(p),p)
 group('BatteryCase',start)
def cap(source):
 start=len(stock_checks)
 lathe('Crown',0,0,0,[(0,0),(.085,0),(.088,.01),(.1,.06),(.098,.07),(0,.075)],'book_navy')
 stock('Peak',(-.07,.06,0),(.07,.13,.008),'bakelite',.003)
 stock('Band',(-.088,-.088,.004),(.088,-.083,.03),'bakelite',.001)
 for p in [(-.07,0,0),(.07,0,0),(0,-.07,0)]:bearing('cap '+str(p),p)
 group('ServiceCap',start)
def lighttable(source):
 start=len(stock_checks)
 for x in [-.18,.16]:stock('Rail'+str(x),(x,-.13,0),(x+.02,.13,.07),'timber',.002)
 for y in [-.13,.11]:stock('Stile'+str(y),(-.16,y,0),(.16,y+.02,.07),'timber',.002)
 stock('Glass',(-.165,-.115,.065),(.165,.115,.072),'glassish',.001)
 for p in [(-.17,-.12,0),(.17,-.12,0),(-.17,.12,0),(.17,.12,0)]:bearing('light table '+str(p),p)
 group('LightTable',start)
# Dossier slice 27: the memorial pot, the plate box, the loupe, the print rack and the never-opened ledger.
def memorialpot(source):
 start=len(stock_checks)
 lathe('Pot',0,0,0,[(0,0),(.054,0),(.056,.004),(.066,.098),(.074,.1),(.074,.118),(.066,.118),(.062,.11),(.06,.096),(0,.096)],'terracotta')
 lathe('Soil',0,0,.094,[(0,0),(.0605,0),(.0612,.006),(0,.006)],'soil')
 stock('Chalk',(-.015,.066,.1175),(.015,.072,.1195),'paper',.0003)
 for p in [(-.05,0,0),(.05,0,0),(0,-.04,0),(0,.04,0)]:bearing('pot '+str(p),p)
 group('MemorialPot',start)
def platebox(source):
 start=len(stock_checks)
 stock('Floor',(-.1,-.075,0),(.1,.075,.01),'wood_dark',.001)
 for y in [-.075,.065]:stock('Side'+str(y),(-.1,y,.005),(.1,y+.01,.095),'wood_dark',.001)
 for x in [-.1,.09]:stock('End'+str(x),(x,-.067,.005),(x+.01,.067,.095),'wood_dark',.001)
 for i in range(7):
  x=-.072+i*.024
  stock('Plate'+str(i),(x-.0012,-.06,.0095),(x+.0012,.06,.118-.004*(i%3)),'glassish',.0002)
 stock('Catch',(-.012,-.079,.07),(.012,-.074,.088),'brass',.0004)
 for p in [(-.09,-.065,0),(.09,-.065,0),(-.09,.065,0),(.09,.065,0)]:bearing('box '+str(p),p)
 group('PlateBox',start)
def loupe(source):
 start=len(stock_checks)
 lathe('Body',0,0,0,[(0,0),(.022,0),(.022,.004),(.017,.042),(.016,.046),(0,.046)],'bakelite')
 lathe('Lens',0,0,.045,[(0,0),(.0145,0),(.0135,.005),(0,.006)],'glassish')
 for p in [(-.018,0,0),(.018,0,0),(0,.018,0)]:bearing('loupe '+str(p),p)
 group('Loupe',start)
def printrack(source):
 start=len(stock_checks)
 stock('Base',(-.15,-.05,0),(.15,.05,.016),'wood_dark',.001)
 for x in [-.15,.138]:stock('Upright'+str(x),(x,-.012,.015),(x+.012,.012,.2),'wood_dark',.001)
 stock('Rail',(-.15,-.008,.188),(.15,.008,.2),'wood_dark',.0008)
 for i,y in enumerate([-.032,-.004,.024]):
  stock('Print'+str(i),(-.125+.01*i,y,.0155),(.115+.01*i,y+.0015,.17-.012*i),'paper',.0002)
 for p in [(-.14,-.04,0),(.14,-.04,0),(-.14,.04,0),(.14,.04,0)]:bearing('rack '+str(p),p)
 group('PrintRack',start)
def ledger(source):
 start=len(stock_checks)
 book('Ledger',(-.14,-.105,0),(.14,.105,.068),'book_brown')
 for x in [-.09,-.03,.03,.09]:stock('Band'+str(x),(x-.006,.1035,.008),(x+.006,.107,.06),'book_brown',.0005)
 stock('Dust',(-.135,-.1,.0675),(.125,.1,.0688),'paper',.0001)
 for p in [(-.13,-.095,0),(.13,-.095,0),(-.13,.095,0),(.13,.095,0)]:bearing('ledger '+str(p),p)
 group('Ledger',start)
# Dossier slice 31: bedside and garment stock.
def earplugs(source):
 start=len(stock_checks)
 lathe('Saucer',0,0,0,[(0,0),(.035,0),(.05,.012),(.052,.016),(.046,.016),(.036,.007),(0,.007)],'porcelain')
 for i,(x,y) in enumerate([(-.012,-.008),(.01,.006),(.002,-.018)]):lathe('Plug'+str(i),x,y,.0065,[(0,0),(.007,0),(.0075,.005),(.005,.01),(0,.011)],'paper')
 for p in [(-.03,0,0),(.03,0,0),(0,.03,0)]:bearing('saucer '+str(p),p)
 group('EarPlugs',start)
def fobwatch(source):
 start=len(stock_checks)
 stock('Foot',(-.03,-.025,0),(.03,.025,.008),'wood_dark',.001)
 tube('Post',(0,0,.006),(0,0,.12),.004,'brass')
 tube('Arm',(0,0,.116),(0,-.03,.116),.003,'brass')
 tube('Bow',(0,-.03,.116),(0,-.03,.104),.0025,'brass')
 axial(identity+'_Case',0,.074,[(0,-.036),(.022,-.036),(.024,-.032),(.024,-.024),(.022,-.02),(0,-.02)],identity,'brass')
 tube('Ring',(0,-.03,.104),(0,-.03,.095),.004,'brass')
 for p in [(-.025,-.02,0),(.025,-.02,0),(-.025,.02,0),(.025,.02,0)]:bearing('watch stand '+str(p),p)
 group('FobWatch',start)
def tuningfork(source):
 start=len(stock_checks)
 stock('Stem',(-.06,-.003,0),(-.01,.003,.006),'nickel_plated',.0005)
 stock('Yoke',(-.012,-.012,0),(.0,.012,.006),'nickel_plated',.0005)
 for y in [-.012,.008]:stock('Tine'+str(y),(-.002,y,0),(.07,y+.004,.006),'nickel_plated',.0005)
 for i in range(9):
  x=-.058-i*.009;y=.002*((i%2)*2-1)
  stock('Link'+str(i),(x-.011,y-.003,0),(x+.001,y+.003,.003),'nickel_plated',.0004)
 for p in [(-.04,0,0),(.05,-.01,0),(.05,.01,0)]:bearing('fork '+str(p),p)
 group('TuningFork',start)
def scarf(source):
 # Draped over a bedpost: the fold rests on the post top, the tails hang down the post's two faces.
 start=len(stock_checks);top=.36
 stock('Fold',(-.048,-.047,top),(.048,.047,top+.014),'wool_burgundy',.004)
 stock('FrontTail',(-.045,.047,0),(.045,.059,top+.014),'wool_burgundy',.003)
 stock('BackTail',(-.04,-.059,.12),(.04,-.047,top+.014),'wool_burgundy',.003)
 for i in range(5):stock('Fringe'+str(i),(-.04+i*.019,.048,-.0),(-.034+i*.019,.058,.03),'wool_burgundy',.0008)
 # The post ends in a turned finial: the fold bears on its apex.
 bearing('finial apex',(0,0,top))
 group('Scarf',start)
def jersey(source):
 # Folded on the chair seat, one sleeve over the front edge, a mended patch on the shoulder.
 start=len(stock_checks);top=.2
 for i in range(3):stock('Fold'+str(i),(-.17,-.15,top+i*.018),(.17,.23,top+i*.018+.019),'jersey_maroon',.006)
 stock('Sleeve',(.06,.225,.0),(.13,.245,top+.03),'jersey_maroon',.008)
 stock('Cuff',(.058,.223,0),(.132,.247,.04),'jersey_maroon',.004)
 stock('Patch',(-.12,-.02,top+.0535),(-.04,.06,top+.0575),'linen',.002)
 for p in [(-.13,-.13,top),(.13,-.13,top),(-.13,.13,top),(.13,.13,top)]:bearing('seat '+str(p),p)
 group('Jersey',start)
def overalls(source):
 # Folded on the chair seat; both straps hang over the front edge with their brass buckles.
 start=len(stock_checks);top=.2
 for i in range(2):stock('Fold'+str(i),(-.16,-.16,top+i*.024),(.16,.23,top+i*.024+.025),'cape_navy',.006)
 for x in [-.08,.06]:
  stock('Strap'+str(x),(x,.225,.02),(x+.03,.237,top+.03),'cape_navy',.002)
  stock('Buckle'+str(x),(x-.004,.235,.02),(x+.034,.242,.055),'brass',.001)
 stock('Pocket',(-.07,-.09,top+.049),(.07,.03,top+.053),'cape_navy',.002)
 for p in [(-.14,-.14,top),(.14,-.14,top),(-.14,.14,top),(.14,.14,top)]:bearing('seat '+str(p),p)
 group('Overalls',start)
def canvasback(source):
 # A small study canvas lying face down: the stretcher frame and the raw back of the canvas.
 start=len(stock_checks)
 stock('Face',(-.08,-.065,0),(.08,.065,.003),'linen',.0005)
 for y in [-.065,.053]:stock('BarLong'+str(y),(-.08,y,.003),(.08,y+.012,.018),'timber',.001)
 for x in [-.08,.068]:stock('BarShort'+str(x),(x,-.053,.003),(x+.012,.053,.018),'timber',.001)
 for p in [(-.07,-.055,0),(.07,-.055,0),(-.07,.055,0),(.07,.055,0)]:bearing('canvas face '+str(p),p)
 group('FaceDownCanvas',start)
def pillbox(source):
 # A seven-day medication organizer: a tin tray of lidded compartments, two lids open.
 start=len(stock_checks)
 stock('Tray',(-.1,-.03,0),(.1,.03,.018),'enamel',.001)
 for i in range(7):
  x=-.0855+i*.0285
  if i in (2,3):
   stock('LidOpen'+str(i),(x-.0125,.022,.016),(x+.0125,.027,.045),'enamel',.0004)
   lathe('Pill'+str(i),x,0,.017,[(0,0),(.005,0),(.005,.003),(0,.004)],'paper')
  else:stock('Lid'+str(i),(x-.0125,-.023,.017),(x+.0125,.023,.021),'enamel',.0004)
 # Drainboard ribs run 50 mm apart: the tray's long edges bear on two of them.
 for p in [(-.09,-.025,0),(.09,-.025,0),(-.09,.025,0),(.09,.025,0)]:bearing('organizer '+str(p),p)
 group('PillBox',start)
# Dossier slice 33: a scatter cushion with piped edges.
def cushion(source):
 start=len(stock_checks)
 stock('Pad',(-.18,-.18,0),(.18,.18,.09),source.get('mat','linen'),.03)
 for y in [-.18,.172]:stock('PipingX'+str(y),(-.18,y,.04),(.18,y+.008,.05),'linen',.002)
 for x in [-.18,.172]:stock('PipingY'+str(x),(x,-.18,.04),(x+.008,.18,.05),'linen',.002)
 for p in [(-.13,-.13,0),(.13,-.13,0),(-.13,.13,0),(.13,.13,0)]:bearing('seat '+str(p),p)
 group('Cushion',start)
for assembly in assemblies:
 identity=assembly['id'];source=rows.get(identity) or table_records[identity];kind=table_records[identity]['kind'];col=Collector()
 if 'asm_'+kind in original:original['asm_'+kind](col,source)
 if kind=='mug':mug(source)
 elif kind=='headphones':headphones(source)
 elif kind=='papers':papers(source,col.rows)
 elif kind=='bookpile':books(source,col.rows)
 elif kind=='jarrow':jars(source,col.rows)
 elif kind=='partstray':tray(source,col.rows)
 elif kind=='dishrack':dishrack(source)
 elif kind=='cablecoil':cablecoil(source)
 elif kind=='bottles':bottles(source,col.rows)
 elif kind=='sitemodel':sitemodel(source,col.rows)
 elif kind=='kettle':kettle(source)
 elif kind=='tin':tin(source)
 elif kind=='board':board(source)
 elif kind=='plate':plate(source)
 elif kind=='sheets':sheets(source)
 elif kind=='volumes':volumes(source)
 elif kind=='brasstray':brasstray(source)
 elif kind=='frame':frame(source)
 elif kind=='clock':clock(source)
 elif kind=='can':can(source)
 elif kind=='parcel':parcel(source)
 elif kind=='flask':flask(source)
 elif kind=='carton':carton(source)
 elif kind=='reelbox':reelbox(source)
 elif kind=='boxrow':boxrow(source)
 elif kind=='basket':basket(source)
 elif kind=='spectacles':spectacles(source)
 elif kind=='pencil':pencil(source)
 elif kind=='booklet':booklet(source)
 elif kind=='wallet':wallet(source)
 elif kind=='foldrule':foldrule(source)
 elif kind=='case':case(source)
 elif kind=='gloves':gloves(source)
 elif kind=='hammer':hammer(source)
 elif kind=='seedjars':seedjars(source)
 elif kind=='seedjarsgap':seedjars(source,True)
 elif kind=='covered':covered(source)
 elif kind=='foldedcloth':foldedcloth(source)
 elif kind=='fileboxes':fileboxes(source)
 elif kind=='driptray':driptray(source)
 elif kind=='driptraydry':driptray(source,False)
 elif kind=='outtray':outtray(source)
 elif kind=='torch':torch(source)
 elif kind=='batterycase':batterycase(source)
 elif kind=='cap':cap(source)
 elif kind=='lighttable':lighttable(source)
 elif kind=='memorialpot':memorialpot(source)
 elif kind=='platebox':platebox(source)
 elif kind=='loupe':loupe(source)
 elif kind=='printrack':printrack(source)
 elif kind=='ledger':ledger(source)
 elif kind=='earplugs':earplugs(source)
 elif kind=='fobwatch':fobwatch(source)
 elif kind=='tuningfork':tuningfork(source)
 elif kind=='scarf':scarf(source)
 elif kind=='jersey':jersey(source)
 elif kind=='overalls':overalls(source)
 elif kind=='canvasback':canvasback(source)
 elif kind=='pillbox':pillbox(source)
 elif kind=='cushion':cushion(source)
 else:raise NotImplementedError(('remaining surface form',identity,kind))
