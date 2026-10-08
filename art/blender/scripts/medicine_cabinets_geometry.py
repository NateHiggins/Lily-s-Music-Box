"""Folded cabinet stock and the exact source-owned kept-item profiles."""
import ast
from mathutils import Matrix
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','transform','ring'}],type_ignores=[]),str(helper_path),'exec'))
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies};retained_stock=[];construction_groups=[]

def component(obj,name):obj['component']=name;return obj

def cabinet(side):
 start=len(stock_checks);z0=1.20;z1=1.81;c=1.505
 stock('FoldedBack',(-.23,-.058,z0),(.23,-.056,z1),'enamel',.0004)
 for x in [-.23,.2288]:stock('FoldedSide'+str(x),(x,-.057,z0),(x+.0012,.042,z1),'enamel',.00025)
 for z in [z0,z1-.0012]:stock('FoldedEnd'+str(z),(-.23,-.057,z),(.23,.042,z+.0012),'enamel',.00025)
 # Original flange envelope, with actual returned edges instead of an 18mm slab.
 for sign in [-1,1]:
  x=sign*.242
  stock('SideFlange'+str(sign),(x-.012,.050,z0),(x+.012,.0515,z1),'enamel',.0003)
  stock('SideReturn'+str(sign),(sign*.23-.0006,.040,z0),(sign*.23+.0006,.051,z1),'enamel',.00025)
 for z in [z0-.012,z1+.012]:
  stock('EndFlange'+str(z),(-.254,.050,z-.012),(.254,.0515,z+.012),'enamel',.0003)
  stock('EndReturn'+str(z),(-.23,.040,(z0 if z<c else z1)-.0006),(.23,.051,(z0 if z<c else z1)+.0006),'enamel',.00025)
 for x in [-.242,.242]:
  for z in [z0-.012,z1+.012]:
   # Domed countersunk heads with a real parted screwdriver slot.
   axial(identity+'_ScrewSeat'+str((x,z)),x,z,[(0,.051),(.0058,.051),(.0065,.052),(.0058,.054),(0,.054)],identity,'nickel',48)
   for sign in [-1,1]:
    angles=np.linspace(.12,math.pi-.12,25)
    outline=[(x+.0058*math.cos(t),z+sign*.0058*math.sin(t)) for t in angles]
    n=len(outline);solid(identity+'_SlottedHead'+str((x,z,sign)),[(px,y,pz) for y in [.0535,.0555] for px,pz in outline],[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,'nickel')
 for height in [1.40,1.59]:
  stock('GlassShelf'+str(height),(-.2025,-.039,height-.004),(.2025,.031,height+.004),'glassish',.0005)
  stock('ShelfLip'+str(height),(-.2075,.0295,height-.009),(.2075,.0385,height+.001),'enamel',.0006)
  for sign in [-1,1]:
   for y in [-.036,.020]:
    lo,hi=sorted([sign*.229,sign*.199])
    stock('ShelfClip'+str((height,sign,y)),(lo,y,height-.006),(hi,y+.008,height-.004),'nickel',.00025)
 for x in [-.15,.15]:
  for z in [1.30,1.70]:support(identity,'wall',(x,-.058,z),(0,1,0),'original cabinet back')
 # Fixed hinge leaves and the two outer knuckles retain the source pin axes.
 for z in [c-.183,c+.183]:
  lo,hi=sorted([side*.239,side*.246])
  stock('FixedHingeLeaf'+str(z),(lo,.051,z-.035),(hi,.056,z+.035),'nickel',.0004)
  for low,high in [(z-.035,z-.021),(z+.021,z+.035)]:
   lo,hi=sorted([side*.230,side*.246])
   stock('FixedHingeTab'+str((z,low)),(lo,.051,low),(hi,.056,high),'nickel',.0004)
   lathe('FixedKnuckle'+str((z,low)),side*.230,.060,low,[(0,0),(.0075,0),(.008,.0005),(.008,high-low-.0005),(.0075,high-low),(0,high-low)],'nickel')
  lathe('HingePin'+str(z),side*.230,.060,z-.037,[(0,0),(.003,0),(.003,.074),(.004,.075),(0,.076)],'nickel')
 leaf_start=len(stock_checks)
 stock('LeafBacking',(-.224,.050,c-.299),(.224,.052,c+.299),'enamel',.0004)
 # Frame channels return from the backing to the front retaining beads.
 for x in [-.23,.206]:
  cuts=[c-.281,c-.183-.043,c-.183+.043,c+.183-.043,c+.183+.043,c+.281] if (x>0)==(side>0) else [c-.281,c+.281]
  for i,(low,high) in enumerate(zip(cuts,cuts[1:])):
   x0,x1=x,x+.024
   if len(cuts)>2 and i in [1,3]:
    if side>0:x1=.221
    else:x0=-.221
   stock('FrameStile'+str((x,i)),(x0,.051,low),(x1,.057,high),'nickel',.001)
   stock('FrameBead'+str((x,i)),(x0,.056,low),(x1,.076,high),'nickel',.001)
 for z in [c-.305,c+.281]:
  stock('FrameRail'+str(z),(-.23,.051,z),(.23,.076,z+.024),'nickel',.001)
 for x in [-.196,.196]:
  for z in [c-.265,c+.265]:stock('MirrorBed'+str((x,z)),(x-.005,.051,z-.005),(x+.005,.066,z+.005),'bakelite',.0006)
 mirror=stock('MirrorGlass',(-.210,.066,c-.285),(.210,.074,c+.285),'mirror',.00035)
 component(mirror,'Mirror')
 for z in [c-.183,c+.183]:
  lo,hi=sorted([side*.214,side*.2255])
  stock('MovingHingeLeaf'+str(z),(lo,.056,z-.020),(hi,.061,z+.020),'nickel',.0004)
  # An annular centre knuckle clears the fixed pin instead of overlapping it.
  lathe('MovingKnuckle'+str(z),side*.230,.060,z-.020,[(.0075,0),(.008,.0005),(.008,.0395),(.0075,.04),(.003,.04),(.003,0),(.0075,0)],'nickel')
 axial(identity+'_Pull',-side*.217,c,[(0,.074),(.010,.074),(.009,.077),(.005,.080),(.005,.090),(.011,.094),(.012,.097),(.011,.099),(0,.099)],identity,'nickel',64)
 x=-side*.214
 stock('FrictionCatch',(x-.009,.045,c-.145),(x+.009,.052,c-.115),'nickel',.0006)
 for item in stock_checks[leaf_start:]:
  obj=bpy.data.objects[item['name']]
  if obj!=mirror:obj['component']='CabinetDoor'
 retained_stock.append({'assembly':identity,'hinge_side':'left' if side==1 else 'right','hinge_pivot_godot':[side*.230,c,-.060],'angle_degrees':95,'mirror_center_godot':[0,c,-.070],'mirror_size':[.420,.570],'shelf_top_y':[1.404,1.594]})
 group('FittedCabinet',start)

def kept(row):
 name,colour,w,h=row['source_item'];start=len(stock_checks)
 if h>w:
  radius=w*.5;neck=radius*.53
  # Closed glass wall, rounded shoulder, recessed bottom and seated stopper.
  lathe('Bottle',0,0,0,[(0,.001),(radius*.72,.001),(radius*.85,0),(radius*.94,0),(radius,.002),(radius,h*.66),(radius*.94,h*.72),(neck,h*.82),(neck,h*.93),(neck-.0015,h*.93),(neck-.0015,h*.84),(radius-.0015,h*.70),(radius-.0015,.003),(0,.003)],'bottle')
  lathe('Stopper',0,0,h*.90,[(0,0),(neck,0),(neck*1.10,h*.015),(neck*1.10,h*.080),(neck*.95,h*.10),(0,h*.10)],'bakelite')
  if name in ['shaving stick','QUELL TONIC']:
   # Source kept item is a cylindrical wrapped stick, with a cap above its sleeve.
   lathe('PaperSleeve',0,0,h*.08,[(radius*.999,0),(radius*1.001,0),(radius*1.001,h*.55),(radius*.999,h*.55),(radius*.999,0)],'paper')
 elif name=='razor':
  # Preserve the flat source footprint: a short safety razor lying on its back.
  stock('Handle',(-w*.50,-w*.045,0),(w*.18,w*.045,h*.45),'bakelite',.0015)
  tube('Neck',(w*.13,0,h*.23),(w*.30,0,h*.23),h*.12,'nickel')
  stock('GuardPlate',(w*.23,-w*.325,0),(w*.50,w*.325,h*.15),'nickel',.0004)
  # Thin cambered cap and two seated posts replace the source head block.
  profile=[(w*(.23+.27*t),h*(.70+.30*math.sin(math.pi*t))) for t in np.linspace(0,1,17)]
  outline=profile+[(x,z-.0012) for x,z in reversed(profile)];n=len(outline)
  solid(identity+'_CamberedCap',[(x,y,z) for y in [-w*.325,w*.325] for x,z in outline],[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,'nickel')
  for y in [-w*.25,w*.25]:tube('HeadPost'+str(y),(w*.365,y,h*.12),(w*.365,y,h*.96),.0015,'nickel')
  for i in range(13):stock('GuardTooth'+str(i),(w*.18,-w*.31+i*w*.05,h*.10),(w*.30,-w*.29+i*w*.05,h*.30),'nickel',.0002)
 elif name in ['cold cream','thimble tin']:
  key='porcelain' if name=='cold cream' else 'nickel'
  # Oval pressed tin / cream pot stays inside the source shallow footprint.
  body=lathe('Container',0,0,0,[(0,0),(w*.44,0),(w*.485,.002),(w*.485,h*.84),(w*.47,h*.86),(0,h*.86)],key)
  lid=lathe('Lid',0,0,h*.82,[(w*.49,0),(w*.50,h*.02),(w*.50,h*.14),(w*.46,h*.18),(0,h*.18),(0,h*.13),(w*.47,h*.13),(w*.48,0),(w*.49,0)],key)
  for obj in [body,lid]:
   for vertex in obj.data.vertices:vertex.co.y*=.68
   del obj['uv_axis'];del obj['uv_center']
 else:
  stock('Carton',(-w*.5,-w*.34,0),(w*.5,w*.34,h-.0006),'paper',.001)
  stock('CartonSeam',(-w*.49,-w*.34,h-.0006),(w*.49,w*.34,h),'paper',.0001)
 retained_stock.append({'assembly':identity,'source_name':name,'source_width':w,'source_height':h,'source_colour':colour,'native_bottom':0})
 if h>w:bearing('bottle heel',(0,w*.445,0))
 elif name=='razor':
  bearing('razor handle',(-w*.16,0,0));bearing('razor guard',(w*.365,0,0))
 else:bearing('kept container',(0,0,0))
 group('KeptItem',start)

for assembly in assemblies:
 identity=assembly['id'];row=variants[identity]
 if row['kind']=='medicine_cabinet':cabinet(1 if row['hinge_side']=='left' else -1)
 else:kept(row)
