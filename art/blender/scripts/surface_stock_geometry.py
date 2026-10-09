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
 else:raise NotImplementedError(('remaining surface form',identity,kind))
