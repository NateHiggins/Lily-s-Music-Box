"""Original fifteen records, manufactured locally, then one rigid V2 relocation."""
import ast
# Only these pure authoring functions are evaluated. The original builder's
# scene construction, exports and filesystem side effects never execute here.
source_script=ROOT/'art/blender/scripts/build_orison.py'
functions={'hash_str','_jit','asm_shelf','asm_bookpile'}
tree=ast.parse(source_script.read_text(encoding='utf-8'));original={}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in functions],type_ignores=[]),str(source_script),'exec'),original)
class Collector:
 def __init__(self):self.rows=[]
 def __getattr__(self,name):
  def collect(*args,**kwargs):self.rows.append({'shape':name,'args':args,'kwargs':kwargs})
  return collect
book_stock=[];frames={}

def local(row,point):
 x,y,z=point;a=math.radians(row.get('yaw',0));at=row.get('at',[0,0])
 return Vector((at[0]+math.cos(a)*x-math.sin(a)*y,at[1]+math.sin(a)*x+math.cos(a)*y,z+row.get('z0',0)))
def move_local(obj,row):
 obj.location=local(row,obj.location)
 a=math.radians(row.get('yaw',0));c,s=math.cos(a),math.sin(a)
 for v in obj.data.vertices:x,y=v.co.x,v.co.y;v.co.x=c*x-s*y;v.co.y=s*x+c*y
 return obj
def lbox(label,row,low,high,key,bevel=.001):return move_local(box(row['id']+'_'+label,low,high,row['id'],key,bevel),row)
def lrod(label,row,a,b,radius,key,n=32):return move_local(rod(row['id']+'_'+label,a,b,radius,row['id'],key,n),row)
def lvessel(label,row,z,profile,key):return move_local(vessel(row['id']+'_'+label,0,0,z,profile,row['id'],key),row)
def lwire(label,row,points,radius,key):return move_local(curved_wire(row['id']+'_'+label,points,radius,row['id'],key),row)
def bearing(row,owner,point,direction,label):support(row['id'],owner,local(row,point),Vector(direction),label)

def book(row,label,key,low,high,flat,source):
 # Distinct covers/spine and recessed page block; no letters or texture titles.
 x0,y0,z0=low;x1,y1,z1=high;thick=.0014
 if flat:
  lbox(label+'_LowerCover',row,(x0,y0,z0),(x1,y1,z0+thick),key,.0004)
  lbox(label+'_UpperCover',row,(x0,y0,z1-thick),(x1,y1,z1),key,.0004)
  lbox(label+'_Pages',row,(x0+.0015,y0+.002,z0+thick-.0001),(x1-.0015,y1-.0015,z1-thick+.0001),'paper',.0002)
 else:
  lbox(label+'_LeftCover',row,(x0,y0,z0),(x0+thick,y1,z1),key,.0004)
  lbox(label+'_RightCover',row,(x1-thick,y0,z0),(x1,y1,z1),key,.0004)
  lbox(label+'_Pages',row,(x0+thick-.0001,y0+.002,z0+.0015),(x1-thick+.0001,y1-.0015,z1-.0015),'paper',.0002)
 lbox(label+'_Spine',row,(x0,y1-.002,z0),(x1,y1,z1),key,.0005)
 book_stock.append({'assembly':row['id'],'label':label,'source':source,'bounds':[list(low),list(high)]})

for assembly in assemblies:
 row=assembly['members'][0];identity=row['id'];kind=row.get('asm','box')
 if kind=='box':
  x0,y0,x1,y1=row['rect'];z0=row['z0'];z1=z0+row['h'];key=row['mat']
  if identity=='nook_rug':z0=0.;z1=.008
  elif identity.startswith('nook_apron'):z0=.008
  # Padded stock has a broad cloth face and a soft worked perimeter.
  edge=.018 if 'cush' in identity else (.006 if identity=='nook_throw' else .002)
  if identity=='nook_throw':
   for layer in range(3):
    inset=layer*.002
    obj=box(identity+'_Fold'+str(layer),(x0+inset,y0+inset,z0+layer*.014),(x1-inset,y1-inset,z0+layer*.014+.020),identity,key,.009)
    # Relax the folded edges; repeated rigid white slabs read as paper stock.
    for vertex in obj.data.vertices:
     point=vertex.co+obj.location
     if layer==0 and point.z<z0+.008:continue
     vertex.co.z+=.0015*math.sin(point.x*21+point.y*16)
  else:box(identity+'_Body',(x0,y0,z0),(x1,y1,z1),identity,key,edge)
  owner='floor' if identity=='nook_rug' else ('nook_rug' if 'apron' in identity else ('nook_apron_'+identity[-1] if 'seat' in identity else ('nook_seat_n' if identity=='nook_cush1' else ('nook_seat_e' if identity=='nook_cush2' else 'nook_seat_w'))))
  for x,y in [(x0+(x1-x0)*.3,y0+(y1-y0)*.3),(x0+(x1-x0)*.7,y0+(y1-y0)*.7)]:support(identity,owner,(x,y,z0),(0,0,1),'flat seated stock datum')
  if 'cush' in identity:
   points=[]
   for cx,cy,start in [(x1-.018,y1-.018,0),(x0+.018,y1-.018,math.pi/2),(x0+.018,y0+.018,math.pi),(x1-.018,y0+.018,math.pi*1.5)]:
    for j in range(9):a=start+j*math.pi/16;points.append((cx+.018*math.cos(a),cy+.018*math.sin(a),z0+.023))
   points.append(points[0])
   curved_wire(identity+'_Welt',points,.0016,identity,key)
  if identity=='nook_cush1':
   # Dossier slice 73 (B1_PUBLIC_CORE-001): a book left open face down on the cushion, covers tented over the
   # spine, sunk 3 mm into the padding. Sheared boxes: pages, then cover, rising 22 mm to the ridge.
   cx,by0,by1,seat=-.84,.85,1.05,z1-.003
   def tent(obj):
    for vertex in obj.data.vertices:
     p=vertex.co+obj.location;vertex.co.z+=.022*max(0.,1-abs(p.x-cx)/.13)
   for side in [-1,1]:
    outer=cx+side*.13
    tent(box(identity+'_ReaderPages'+str(side),(min(outer-side*.004,cx),by0+.004,seat),(max(outer-side*.004,cx),by1-.004,seat+.007),identity,'paper',.0008))
    tent(box(identity+'_ReaderCover'+str(side),(min(outer,cx),by0,seat+.006),(max(outer,cx),by1,seat+.0095),identity,'book_green',.0008))
   box(identity+'_ReaderSpine',(cx-.007,by0,seat+.018),(cx+.007,by1,seat+.034),identity,'book_green',.002)
 elif kind=='coffee':
  for index,(bottom,top,width) in enumerate([((-.30,-.10),(.18,.13),.30),((.28,-.07),(-.14,.15),.26)]):
   verts=[(center[0]+dx,center[1]+dy,z) for center,z in [(bottom,.008),(top,.346)] for dy in [-width/2,width/2] for dx in [-.0225,.0225]]
   obj=solid(identity+'_Keel'+str(index),verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,'wood_dark');move_local(obj,row)
   lbox('GlassPad'+str(index),row,(top[0]-.022,top[1]-width*.45,.3455),(top[0]+.022,top[1]+width*.45,.350),'rubber_aged',.0005)
   bearing(row,'nook_rug',(bottom[0],bottom[1],.008),(0,0,1),'table keel floor bearing')
  outline=[(.55*math.cos(i*math.tau/96),.341*math.sin(i*math.tau/96)) for i in range(96)]
  move_local(prism(identity+'_PolishedGlass',outline,.350,.365,identity,'glassish',.0006),row)
 elif kind=='shelf':
  # Original visible books reached well above the short declared uprights.
  # Put every shelf above the seat so none of the retained stock is buried
  # behind its closed apron; complete the four legs under this real rack.
  w=row['W'];levels=[.55,.97,1.39]
  for i,(x,y) in enumerate([(x,y) for x in [-w/2+.02,w/2-.02] for y in [-.13,.13]]):
   lrod('Upright'+str(i),row,(x,y,.008),(x,y,1.45),.013,'metal')
   bearing(row,'nook_rug',(x,y,.008),(0,0,1),'rack foot on rug')
  for i,z in enumerate(levels):lbox('Shelf'+str(i),row,(-w/2,-.15,z),(w/2,.15,z+.032),'floor_oak',.002)
  original_shelf=Collector();original['asm_shelf'](original_shelf,row)
  source_books=[v for v in original_shelf.rows if v['shape']=='box' and v['args'][0].startswith('book_')]
  assert len(source_books)==plan['retained_stock'][identity]
  units=[];stacks={}
  for i,v in enumerate(source_books):
   a=v['args'];lo=Vector(a[1:4]);hi=Vector(a[4:7]);record=(i,a[0],lo,hi)
   if hi.z-lo.z<.08:
    shelf=max(z for z in [.06,.50,.94,1.38] if z+.032<lo.z+.00001);stacks.setdefault(shelf,[]).append(record)
   else:units.append([record])
  units.extend(stacks.values());level=0;cursor=-w/2+.055
  for group in units:
   low=Vector(tuple(min(v[2][i] for v in group) for i in range(3)));high=Vector(tuple(max(v[3][i] for v in group) for i in range(3)));size=high-low
   if cursor+size.x>w/2-.04:level+=1;cursor=-w/2+.055
   assert level<len(levels),'original books exceed available fitted shelves'
   delta=Vector((cursor-low.x,0,levels[level]+.032-low.z))
   for index,key,lo,hi in group:book(row,'Volume'+str(index),key,lo+delta,hi+delta,hi.z-lo.z<.08,source_books[index])
   cursor+=size.x+.009
 elif kind=='bookpile':
  row=dict(row);row['z0']=.365;collector=Collector();original['asm_bookpile'](collector,row)
  assert len(collector.rows)==plan['retained_stock'][identity]
  for i,record in enumerate(collector.rows):a=record['args'];book(row,'Volume'+str(i),a[0],Vector(a[1:4]),Vector(a[4:7]),True,record)
  bearing(row,'nook_table',(0,0,0),(0,0,1),'book pile on actual glass')
 elif kind=='mug':
  row=dict(row);row['z0']=.365
  lvessel('ThrownCup',row,0,[(0,0),(.033,0),(.039,.008),(.040,.092),(.038,.100),(.035,.100),(.033,.093),(.032,.010),(0,.010)],'ceramic')
  lwire('Handle',row,[(.037,0,.025),(.054,0,.030),(.064,0,.050),(.063,0,.067),(.053,0,.081),(.036,0,.080)],.0055,'ceramic')
  bearing(row,'nook_table',(0,0,0),(0,0,1),'mug foot on actual glass')
 elif kind=='plant':
  row=dict(row);row['z0']=.008
  lvessel('Saucer',row,0,[(0,0),(.15,0),(.168,.01),(.158,.032),(.146,.026),(.14,.012),(0,.012)],'terracotta')
  lvessel('ThrownPot',row,.012,[(0,0),(.105,0),(.148,.043),(.175,.278),(.178,.29),(.196,.302),(.198,.34),(.18,.348),(.160,.338),(.16,.285),(.13,.047),(.09,.010),(0,.01)],'terracotta')
  lvessel('Soil',row,0,[(0,.03),(.10,.03),(.16,.335),(.118,.36),(.045,.374),(0,.378)],'soil')
  seed=identity
  for i in range(3):
   angle=math.radians(original['_jit'](seed,i,0,360));lean=original['_jit'](seed,i+9,.10,.22);top=original['_jit'](seed,i+17,.62,.92)
   start=Vector((.03*math.cos(angle),.03*math.sin(angle),.36));tip=Vector((lean*math.cos(angle),lean*math.sin(angle),top));middle=Vector((tip.x*.6,tip.y*.6,top*.62))
   lwire('Branch'+str(i),row,[start,middle,tip],.0065,'timber')
   for k in range(5):
    t=.42+.58*k/4;attach=middle.lerp(tip,t);direction=Vector((math.cos(angle+k*2.4),math.sin(angle+k*2.4),.12)).normalized();length=original['_jit'](seed,i*41+k,.055,.095)*2
    stem_end=attach+direction*.022;lrod('Petiole%d_%d'%(i,k),row,attach,stem_end,.0017,'plant',16)
    # A closed, curved two-sided leaf whose central vein reaches its petiole.
    side=Vector((-direction.y,direction.x,0));verts=[];segments=18
    for layer in [-1,1]:
     for j in range(segments+1):
      u=j/segments;width=max(.0006,math.sin(math.pi*u)**.85*length*.24);center=stem_end+direction*(length*u)+Vector((0,0,-.025*u*u))
      for v in [-1,0,1]:verts.append(center+side*(width*v)+Vector((0,0,.004*(1-v*v)*math.sin(math.pi*u)+layer*.0003)))
    m=(segments+1)*3;faces=[]
    for j in range(segments):
     for v in range(2):a=j*3+v;faces.extend([(a,a+1,a+4,a+3),(m+a,m+a+3,m+a+4,m+a+1)])
    boundary=[j*3 for j in range(segments+1)]+[segments*3+1]+[j*3+2 for j in reversed(range(segments+1))]+[1]
    faces.extend((a,b,m+b,m+a) for a,b in zip(boundary,boundary[1:]+boundary[:1]));move_local(solid(identity+'_Leaf%d_%d'%(i,k),verts,faces,identity,'plant'),row)
  bearing(row,'nook_rug',(0,0,0),(0,0,1),'saucer on rug')
 else:raise AssertionError(('unhandled original record',identity,kind))
 at=row.get('at',[(row['rect'][0]+row['rect'][2])*.5,(row['rect'][1]+row['rect'][3])*.5] if 'rect' in row else [0,0])
 frames[identity]={'position':[-.96-at[0],0,2.10+at[1]],'yaw':math.pi-math.radians(row.get('yaw',0))}

# Apply the declared rigid relocation once, retaining local height datums.
for obj in closed.objects:
 obj.location.x=-.96-obj.location.x;obj.location.y=-2.10-obj.location.y
 for v in obj.data.vertices:v.co.x=-v.co.x;v.co.y=-v.co.y
for contact in contacts:
 p=contact['point'];p[0]=-.96-p[0];p[2]=2.10-p[2]
 contact['direction'][0]*=-1;contact['direction'][2]*=-1
assert len(book_stock)==sum(plan['retained_stock'].values())
