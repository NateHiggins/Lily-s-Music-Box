"""Formed single-slot case and the existing independently moving mechanisms."""
import ast
from mathutils import Matrix
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','transform','ring'}],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]

def component(obj,name):obj['component']=name;return obj

def plate(label,width,y0,y1,z0,z1,holes):
 # Build the actual boundary of a perforated sheet from a 2-D occupancy grid.
 # Internal cell edges are coplanar, so the bevel works only on real cut edges.
 xs=sorted(set([-width/2,width/2,*[x for h in holes for x in h[:2]]]))
 zs=sorted(set([z0,z1,*[z for h in holes for z in h[2:]]]))
 occupied={(i,j) for i in range(len(xs)-1) for j in range(len(zs)-1) if not any(a<(xs[i]+xs[i+1])/2<b and c<(zs[j]+zs[j+1])/2<d for a,b,c,d in holes)}
 verts=[];indices={};faces=[]
 def vertex(x,y,z):
  p=(x,y,z)
  if p not in indices:indices[p]=len(verts);verts.append(p)
  return indices[p]
 for i,j in sorted(occupied):
  x0,x1=xs[i:i+2];low,high=zs[j:j+2]
  a=[vertex(x,y,z) for y in [y0,y1] for x,z in [(x0,low),(x1,low),(x1,high),(x0,high)]]
  faces.extend([tuple(reversed(a[:4])),tuple(a[4:])])
  for neighbour,edge in [((i,j-1),(0,1)),((i+1,j),(1,2)),((i,j+1),(2,3)),((i-1,j),(3,0))]:
   if neighbour not in occupied:
    q,r=edge;faces.append((a[q],a[r],a[r+4],a[q+4]))
 obj=solid(identity+'_'+label,verts,faces,identity,'nickel')
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Rolled cut edges','BEVEL');mod.width=.00018;mod.segments=3;mod.limit_method='ANGLE';mod.angle_limit=.01;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

def shoulder():
 profile=[(.154,.249,.121),(.156,.248,.112),(.158,.245,.099),(.162,.239,.086),(.166,.233,.075),(.170,.226,.064),(.1745,.218,.032)]
 verts=[];thick=.0012
 for inner in [False,True]:
  for z,w,d in profile:verts.extend((x*(w/2-(thick if inner else 0)),y*(d/2-(thick if inner else 0)),z) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)])
 faces=[];count=len(profile);offset=count*4
 for j in range(count-1):
  for i in range(4):
   k=(i+1)%4;a=j*4+i;b=j*4+k;faces.extend([(a,b,b+4,a+4),(a+offset,a+4+offset,b+4+offset,b+offset)])
 for j in [0,count-1]:
  for i in range(4):
   k=(i+1)%4;faces.append((j*4+i,j*4+k,offset+j*4+k,offset+j*4+i))
 solid(identity+'_PressedShoulder',verts,faces,identity,'nickel')

def toaster(axis):
 start=len(stock_checks)
 for x in [-.105,.105]:
  for y in [-.045,.045]:
   lathe('Foot'+str((x,y)),x,y,0,[(0,0),(.0135,0),(.014,.001),(.012,.011),(.011,.012),(0,.012)],'bakelite');bearing('original foot',(x,y,0))
 stock('PressedBase',(-.1285,-.0605,.012),(.1285,.0605,.024),'nickel',.0007)
 vents=[(-.088,.088,.057+i*.016,.063+i*.016) for i in range(5)]
 for sign in [-1,1]:
  holes=list(vents)
  if axis=='-z' and sign==1:holes.extend([(-.110,.110,.024,.041),(-.022,.022,.041,.043)])
  plate('VentWall'+str(sign),.249,sign*.0605-(.0012 if sign==1 else 0),sign*.0605+(.0012 if sign==-1 else 0),.024,.156,holes)
 for sign in [-1,1]:
  holes=[(-.054,.054,.024,.041),(-.022,.022,.041,.043)] if axis=='-x' and sign==-1 else []
  if sign==1:holes.append((-.009,.005,.084,.154))
  obj=plate('EndWall'+str(sign),.1186,-.0006,.0006,.024,.156,holes)
  transform(obj,Matrix.Translation((sign*.1239,0,0))@Matrix.Rotation(math.pi/2,4,'Z'))
 shoulder()
 frame(identity+'_SingleSlotLip',-.112,-.016,.112,.016,.1735,.1825,.006,identity,'nickel')
 for sign in [-1,1]:
  for x in [-.104,.104]:
   # A parted head leaves a physical screwdriver slot without a painted mark.
   y=sign*.061
   for half in [-1,1]:
    outline=[(x+.0036*math.cos(t),.043+.0036*math.sin(t)) for t in np.linspace(.09,math.pi-.09,25)]
    if half==-1:outline=[(px,.086-pz) for px,pz in outline]
    n=len(outline);verts=[(px,q,pz) for q in [y-sign*.0015,y+sign*.0015] for px,pz in outline]
    solid(identity+'_Screw'+str((sign,x,half)),verts,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,'nickel')
 # The raised cord entry clears the existing retrofit's swept lower opening.
 cord=[Vector(p) for p in [(-.105,.058,.050),(-.151,.076,.044),(-.173,.091,.025),(-.180,.109,.014),(-.160,.120,.009)]]
 path=[]
 for i in range(len(cord)-1):
  a,b,c,d=cord[max(i-1,0)],cord[i],cord[i+1],cord[min(i+2,len(cord)-1)]
  for t in np.linspace(0,1,12,endpoint=False):path.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 path.append(cord[-1]);wire('BraidedSupply',path,.006,'braid')
 stock('Plug',(-.177,.108,0),(-.143,.132,.018),'bakelite',.003)
 bearing('loose plug',(-.160,.120,0))
 for x in [-.167,-.153]:axial(identity+'_PlugPin'+str(x),x,.009,[(0,.130),(.002,.130),(.002,.149),(0,.149)],identity,'nickel',32)
 for y in [-.034,.034]:
  stock('MicaCard'+str(y),(-.095,y-.002,.051),(.095,y+.002,.149),'mica',.0002)
  for x in [-.0934,.0934]:stock('CardSaddle'+str((x,y)),(x-.002,y-.003,.043),(x+.002,y+.003,.053),'nickel',.0003)
 for y in [-.037,.037]:
  for j in range(7):component(tube('ResistanceWire'+str((y,j)),(-.088,y,.067+j*.012),(.088,y,.067+j*.012),.0015,'coil'),'ResistanceWire')
 stock('TimerTrack',(-.128,-.010,.064),(-.124,.006,.142),'bakelite',.0005)
 stock('TimerLever',(-.150,-.0105,.114),(-.124,.0145,.128),'bakelite',.002)
 for j in range(5):stock('TimerNotch'+str(j),(-.130,-.0105,.0745+j*.013),(-.126,.0145,.0775+j*.013),'nickel',.0004)
 component(stock('CarriageGrip',(.1295,-.015,.1295),(.154,.011,.1445),'bakelite',.002),'CarriageLever')
 component(along_x(identity+'_CarriageSpindle',.119,-.002,.137,[(0,-.009),(.006,-.009),(.006,.014),(0,.014)],identity,'nickel'),'CarriageLever')
 # Inner slider face bears against the end sheet while allowing its original
 # impatient sideways play. Contact is at the guide faces, not in the wall.
 for y in [-.014,.007]:stock('LeverGuideSide'+str(y),(.102,y,.083),(.124,y+.003,.156),'nickel',.0002)
 component(stock('LeverSlider',(.106,-.011,.130),(.111,.007,.144),'nickel',.0002),'CarriageLever')
 # The original carrier travels 87 mm, independently of the 46 mm hand
 # lever. Its narrow carrier fits through the lip during the spring pop.
 component(stock('BreadPlate',(-.094,-.0085,.148),(.094,.0085,.154),'nickel',.0005),'BreadCarrier')
 for x in [-.084,-.042,0,.042,.084]:component(tube('CarrierWire'+str(x),(x,.008,.141),(x,-.008,.177),.0015,'nickel'),'BreadCarrier')
 # Separate sliding yokes bear on fixed uprights. The two original pivots
 # remain independent; a rigid connecting arm would falsely couple them.
 for x in [-.097,.097]:
  stock('CarrierGuideBridge'+str(x),(x-.002,-.060,.042),(x+.002,.060,.044),'nickel',.0002)
  stock('CarrierGuide'+str(x),(x-.001,-.009,.043),(x+.001,.009,.1825),'nickel',.0001)
  for y in [-.010,.009]:component(stock('CarrierYoke'+str((x,y)),(x-.004,y,.147),(x+.004,y+.001,.155),'nickel',.0001),'BreadCarrier')
  component(stock('CarrierLink'+str(x),(-.095 if x<0 else .091,-.009,.147),(-.091 if x<0 else .095,.009,.150),'nickel',.0001),'BreadCarrier')
 # Stationary guide rails support the original pan's closed datum.
 if axis=='-z':
  for x in [-.095,.095]:stock('PanRail'+str(x),(x-.002,-.05,.024),(x+.002,.05,.0245),'nickel',.00005)
 else:
  for y in [-.04,.04]:stock('PanRail'+str(y),(-.10,y-.002,.024),(.10,y+.002,.0245),'nickel',.00005)
 tray_start=len(stock_checks)
 stock('Pan',(-.1075,-.0525,.0245),(.1075,.0525,.0257),'nickel',.0002)
 for y in [-.0525,.0513]:stock('PanFold'+str(y),(-.1075,y,.0254),(.1075,y+.0012,.039),'nickel',.0002)
 for x in [-.1075,.1063]:stock('PanEnd'+str(x),(x,-.052,.0254),(x+.0012,.052,.039),'nickel',.0002)
 if axis=='-x':
  stock('PanPullStrip',(-.117,-.041,.0247),(-.107,.041,.041),'nickel',.0005)
  stock('PanPull',(-.129,-.019,.0265),(-.113,.019,.0415),'bakelite',.002)
 else:
  stock('PanPullStrip',(-.041,.052,.0247),(.041,.063,.041),'nickel',.0005)
  stock('PanPull',(-.019,.059,.0265),(.019,.075,.0415),'bakelite',.002)
 stock('GreaseFilm',(-.082,-.024,.0257),(.038,.036,.02585),'grease',.00002)
 for item in stock_checks[tray_start:]:bpy.data.objects[item['name']]['component']='OrisonRetrofitCrumbTray'
 retained_stock.append({'assembly':identity,'tray_axis':axis,'lever_pivot_godot':[.137,.137,.002],'carrier_pivot_godot':[0,.151,0],'tray_pivot_godot':[0,.027,0],'lever_travel':.046,'carrier_travel':.087,'tray_travel':.160,'original_crumb_count':18,'native_pan_top':.0257})
 if identity=='ToasterForm':
  # Dossier slice 38: the replacement form Peter Wren never filed, taped to the plain -x end panel,
  # clear of the carriage lever slot on the +x end. Blank paper: no lettering.
  stock('Form',(-.1256,-.042,.045),(-.1244,.042,.14),'formpaper',.0001)
  for z in [.047,.128]:stock('Tape'+str(z),(-.1259,-.035,z),(-.1255,.035,z+.01),'tape',.0001)
 group('SupportedSingleSlotMechanism',start)

for assembly in assemblies:
 identity=assembly['id']
 if identity=='ToasterCrumb':
  start=len(stock_checks)
  # A normalized closed irregular crumb; original unit RNG supplies dimensions,
  # yaw, colour and footprint. Bottom datum is zero for real pan seating.
  outline=[(-.004,-.0028),(-.0029,-.004),(.0028,-.0035),(.004,-.0011),(.0032,.0034),(-.0017,.004),(-.0038,.0016)]
  prism(identity+'_Crumb',outline,0,.008,identity,'crumb',.001)
  group('CrumbPrototype',start)
 else:toaster(variants[identity]['tray_axis'])
