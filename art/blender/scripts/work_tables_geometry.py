"""Closed stock in each existing table's local frame; original working datums."""
import ast
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};paper_stock=[]
original={};source_script=ROOT/'art/blender/scripts/build_orison.py'
tree=ast.parse(source_script.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'hash_str','_jit','asm_plantable'}],type_ignores=[]),str(source_script),'exec'),original)
class Collector:
 def __init__(self):self.rows=[]
 def __getattr__(self,name):
  def collect(*args,**kw):self.rows.append((name,args,kw))
  return collect

def stock(label,lo,hi,key='wood_dark',edge=.001):return box(identity+'_'+label,lo,hi,identity,key,edge)
def turned(label,a,b,r,key='nickel_plated',n=48):return rod(identity+'_'+label,a,b,r,identity,key,n)
def beam(label,a,b,w,t,key='wood_dark',floor=False,ceiling=None):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();ref=Vector((0,0,1)) if abs(axis.z)<.985 else Vector((1,0,0));u=ref.cross(axis).normalized()*w/2;v=axis.cross(u).normalized()*t/2
 verts=[p+su*u+sv*v for p in (a,b) for su,sv in [(-1,-1),(1,-1),(1,1),(-1,1)]]
 # Saw both foot ends in the horizontal floor plane; do not lift the top.
 if floor:
  for p in verts[:4]:p.z=0.
 if ceiling is not None:
  for p in verts[4:]:p.z=ceiling
 obj=solid(identity+'_'+label,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],identity,key)
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Eased stock','BEVEL');mod.width=.0008;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 if floor:support(identity,'floor',a,(0,0,1),label+' sawn foot')
 return obj
def fastener(label,x,y,z,r=.003):
 # Closed slotted heads formed as a lower disc and two upper half lands.
 turned(label+'_Head',(x,y,z-.001),(x,y,z+.0005),r)
 for side in (-1,1):stock(label+'_SlotLand'+str(side),(x-r*.68,y+side*r*.43-r*.22,z),(x+r*.68,y+side*r*.43+r*.22,z+.001),'nickel_plated',.00012)
def floor_leg(label,x,y,top,width=.055,key='wood_dark'):
 stock(label,(x-width/2,y-width/2,0),(x+width/2,y+width/2,top),key,.001)
 support(identity,'floor',(x,y,0),(0,0,1),label)

identity='2A_desk'
stock('Top',(-.75,-.325,.70),(.75,.325,.735),'oak_work_surface',.0025)
# A closed, passive drawer and five-sided carcass retain the original silhouette.
stock('CarcassFloor',(-.69,-.28,.585),(.69,.28,.603))
stock('CarcassBack',(-.69,-.28,.60),(.69,-.262,.701))
for side in (-1,1):stock('CarcassSide'+str(side),(side*.681-.009,-.28,.60),(side*.681+.009,.281,.701))
stock('Divider',(-.024,-.263,.602),(-.008,.281,.701))
stock('FixedFront',(-.008,.263,.603),(.672,.28,.70))
stock('DrawerFace',(-.66,.274,.600),(-.020,.295,.685),edge=.0015)
stock('DrawerBottom',(-.651,-.245,.604),(-.028,.277,.612))
stock('DrawerBack',(-.651,-.245,.610),(-.028,-.235,.680))
for x in (-.651,-.036):stock('DrawerSide'+str(x),(x,-.235,.610),(x+.008,.28,.680))
# Recessed dark finger strip in the face, bounded by real lips.
stock('FingerInset',(-.62,.294,.635),(-.06,.2955,.655),'soot',.0003)
stock('FingerLip',(-.62,.2945,.654),(-.06,.300,.658),edge=.0007)
for side in (-1,1):
 x=side*.65
 for sign in (-1,1):beam('Leg'+str((side,sign)),(x*1.10,sign*.31,0),(x,sign*.26,.603),.034,.034,floor=True,ceiling=.603)
 # Original crossbars missed the splayed legs. Fit both ends at their real axes.
 z=.16;t=z/.603;bx=x*1.10*(1-t)+x*t;by=.31*(1-t)+.26*t
 beam('Stretcher'+str(side),(bx,-by,z),(bx,by,z),.028,.028)

identity='3B_workbench'
# One joined hardwood worktop, kept continuous at the four lamp/stock bearings.
stock('Top',(-1.1,-.4,.85),(1.1,.4,.91),'oak_work_surface',.0025)
for sx in (-1,1):
 for sy in (-1,1):
  x=sx*1.;y=sy*.32;label=str((sx,sy))
  stock('AngleA'+label,(x-.025,y-.006,0),(x+.025,y+.006,.851),'iron_blackened',.0006)
  stock('AngleB'+label,(x-sx*.012-.006,y-.025,0),(x-sx*.012+.006,y+.025,.851),'iron_blackened',.0006)
  support(identity,'floor',(x,y,0),(0,0,1),'angle leg '+label)
  stock('TopBracket'+label,(x-.044,y-.034,.837),(x+.044,y+.034,.85),'iron_blackened')
  fastener('TopBolt'+label,x,y,.91,.004)
# Dossier slice 43: the tray and the hanging cupboard are grey painted iron.
# Folded lower tray reaches the leg angles at its hem.
stock('ShelfPan',(-1.02,-.34,.22),(1.02,.34,.223),'iron_neutral',.0005)
for side in (-1,1):stock('ShelfHem'+str(side),(-1.02,side*.338-.002,.221),(1.02,side*.338+.002,.25),'iron_neutral',.0005)
for side in (-1,1):stock('ShelfEnd'+str(side),(side*1.018-.002,-.34,.221),(side*1.018+.002,.34,.25),'iron_neutral',.0005)
# Folded hanging tool cupboard. Native shell, shut door, actual hangers.
stock('CabinetBottom',(-.55,-.36,.60),(.05,.36,.603),'iron_neutral',.0005)
stock('CabinetTop',(-.55,-.36,.817),(.05,.36,.82),'iron_neutral',.0005)
stock('CabinetBack',(-.55,-.36,.602),(.05,-.357,.819),'iron_neutral',.0005)
for side,x in enumerate((-.55,.047)):
 stock('CabinetSide'+str(side),(x,-.359,.602),(x+.003,.36,.819),'iron_neutral',.0005)
 stock('CabinetHanger'+str(side),(x-.005,-.30,.817),(x+.008,.30,.851),'iron_neutral',.0007)
stock('CabinetFace',(-.549,.357,.602),(.049,.361,.819),'iron_neutral',.0005)
stock('CabinetDoor',(-.52,.360,.63),(.02,.375,.79),'iron_neutral',.0015)
for x in (-.35,-.15):turned('PullPost'+str(x),(x,.372,.71),(x,.39,.71),.008,'iron_blackened')
turned('Pull',(-.36,.39,.71),(-.14,.39,.71),.01,'iron_blackened')
# Original closed passive edge vise: two jaws, slide and screw held in a saddle.
stock('ViseSaddle',(.92,.375,.78),(1.1,.445,.865),'iron_blackened',.003)
stock('ViseSlide',(.965,.437,.794),(1.055,.545,.836),'iron_blackened',.002)
stock('FixedJaw',(.92,.401,.847),(1.1,.444,.908),'iron_blackened',.002)
stock('MovingJaw',(.92,.449,.837),(1.1,.56,.908),'iron_blackened',.002)
stock('FixedJawInsert',(.925,.440,.892),(1.095,.446,.91),'nickel_plated',.0005)
stock('MovingJawInsert',(.925,.447,.892),(1.095,.453,.91),'nickel_plated',.0005)
turned('ViseScrew',(1.01,.54,.845),(1.01,.64,.845),.014)
turned('ViseHandle',(.95,.64,.845),(1.07,.64,.845),.01,'iron_blackened')
for x in (.95,1.07):turned('HandleStop'+str(x),(x-.006,.64,.845),(x+.006,.64,.845),.014,'iron_blackened')

identity='4B_terminal_desk'
stock('Top',(-.29,-.625,.705),(.29,.625,.75),'oak_work_surface',.002)
for sx in (-1,1):
 for sy in (-1,1):floor_leg('Leg'+str((sx,sy)),sx*.23,sy*.565,.706)
for side in (-1,1):
 stock('LongApron'+str(side),(side*.23-.018,-.565,.58),(side*.23+.018,.565,.706))
 stock('EndApron'+str(side),(-.23,side*.565-.018,.58),(.23,side*.565+.018,.706))

identity='5A_plantable'
stock('Top',(-1,-.6,.76),(1,.6,.8),'oak_work_surface',.0025)
for sx in (-1,1):
 tx=sx*.72
 for sy in (-1,1):beam('TrestleLeg'+str((sx,sy)),(tx-sx*.14,sy*.234,0),(tx,sy*.52,.761),.05,.05,floor=True,ceiling=.761)
 z=.6;t=z/.761;x=(tx-sx*.14)*(1-t)+tx*t;y=.234*(1-t)+.52*t
 beam('UpperCrossbar'+str(sx),(x,-y,z),(x,y,z),.045,.045)
 beam('TrestleUpright'+str(sx),(tx,0,0),(tx,0,.614),.05,.05,floor=True,ceiling=.614)
beam('LongRail',(-.72,0,.28),(.72,0,.28),.05,.04)
source=Collector();original['asm_plantable'](source,rows['5A_plantable'])
for shape,args,kw in source.rows:
 if args[0]!='paper':continue
 index=len(paper_stock)
 if shape=='box':
  _,x0,y0,z0,x1,y1,z1=args;low=.8
  # Preserve original plan footprints; each layer rests on a real earlier sheet.
  for prior in paper_stock:
   if 'bounds' not in prior:continue
   lo,hi=prior['bounds']
   if min(x1,hi[0])-max(x0,lo[0])>.001 and min(y1,hi[1])-max(y0,lo[1])>.001:low=max(low,hi[2])
  high=low+.003
  stock('Plan'+str(index),(x0,y0,low),(x1,y1,high),'paper',.0002)
  paper_stock.append({'name':'Plan'+str(index),'source_args':args,'bounds':[[x0,y0,low],[x1,y1,high]]})
 else:
  _,a,b,radius,_=args;height=b[2]-a[2]
  profile=[(radius,0),(radius,height),(radius-.003,height),(radius-.003,0),(radius,0)]
  vessel(identity+'_Roll'+str(index),a[0],a[1],.8,profile,identity,'paper')
  paper_stock.append({'name':'Roll'+str(index),'source_args':args,'hollow_wall_m':.003})

identity='6A_deskwall'
# Dossier slice 43 (F06_A_STUDY-003): an oak top on two solid oak ends, inside the original
# slab-support envelope; the white painted slab and the black folded pedestals read as modern.
stock('Top',(-.4,-1.3,.72),(.4,1.3,.77),'oak_work_surface',.002)
for sy in (-1,1):
 y=sy*1.14;label=str(sy)
 stock('PedestalPanel'+label,(-.28,y-.024,.05),(.28,y+.024,.699),'wood_dark',.003)
 stock('PedestalCap'+label,(-.30,y-.045,.698),(.30,y+.045,.721),'wood_dark',.003)
 stock('PedestalPlinth'+label,(-.30,y-.06,0),(.30,y+.06,.051),'wood_dark',.003)
 for x in (-.24,.24):support(identity,'floor',(x,y,0),(0,0,1),'folded pedestal '+label)
