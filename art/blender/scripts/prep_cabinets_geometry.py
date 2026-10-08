"""Native carcass and bypass panels attached to the original sliding owner."""
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]
identity='PrepCabinet';component='Body'

def stock(label,lo,hi,key,edge=.001):
 obj=box(identity+'_'+label,lo,hi,identity,key,edge);obj['component']=component;return obj

def source_boxes(surface):
 for vertices in np.asarray(surface['vertices'],dtype=float).reshape((-1,36,3)):
  vertices=vertices[:,[0,2,1]];vertices[:,1]*=-1
  yield vertices.min(0),vertices.max(0)

for surface in assemblies[0]['members'][0]['surfaces']:
 for i,(lo,hi) in enumerate(source_boxes(surface)):
  stock('Carcass'+surface['material']+str(i),lo,hi,surface['material'],.0012 if surface['material']=='countertop' else .0007)
for x in [-.30,.30]:
 for y in [-.13,.13]:support(identity,'support',(x,y,0),(0,0,1),'original plinth bearing')

# Two 18mm leaves occupy their original bypass planes. The channels provide
# actual bearings across the source's 5mm lower and 15mm upper clearances.
for z in [.095,.85]:
 stock('TrackPlate'+str(z),(-.376,.211,z),(.376,.272,z+.005),'metal',.00035)
 for y in [.212,.239,.269]:stock('TrackLip'+str(z)+str(y),(-.376,y,z),(.376,y+.003,z+.010 if z<.2 else z+.015),'metal',.0003)
stock('UpperTrackBridge',(-.376,.201,.855),(.376,.245,.866),'plywood',.0006)

def panel(label,cx,front,handle_x,handle_front):
 lo=cx-.185;hi=cx+.185;back=front-.018
 for x in [lo,hi-.032]:stock(label+'Stile'+str(x),(x,back,.1),(x+.032,front,.85),'trim',.0006)
 for z in [.10,.818]:stock(label+'Rail'+str(z),(lo+.031,back,z),(hi-.031,front,z+.032),'trim',.0006)
 if label=='FixedLeaf':
  # The source projecting fixed handle crosses the other leaf's 382mm sweep.
  # A recessed brass finger cup keeps its X/height centre and clears that path.
  x0=handle_x-.011;x1=handle_x+.011;z0=.5675;z1=.6525
  for suffix,a,b in [('Below',(lo+.030,back+.002,.13),(hi-.030,front-.004,z0)),('Above',(lo+.030,back+.002,z1),(hi-.030,front-.004,.82)),('Left',(lo+.030,back+.002,z0),(x0,front-.004,z1)),('Right',(x1,back+.002,z0),(hi-.030,front-.004,z1))]:stock(label+'Inset'+suffix,a,b,'trim',.0004)
  stock(label+'CupBack',(x0,back+.002,z0),(x1,back+.004,z1),'brass',.0003)
  for x in [x0,x1-.002]:stock(label+'CupSide'+str(x),(x,back+.003,z0),(x+.002,front+.001,z1),'brass',.00035)
  for z in [z0,z1-.002]:stock(label+'CupEnd'+str(z),(x0,back+.003,z),(x1,front+.001,z+.002),'brass',.00035)
  return
 stock(label+'Inset',(lo+.030,back+.002,.13),(hi-.030,front-.004,.82),'trim',.0006)
 # Original handle extents: 22 x 85 x 22mm. The new curved bail is 4mm stock,
 # with mounting posts reaching the real leaf rather than floating in front.
 for z in [.577,.643]:
  obj=rod(identity+'_'+label+'HandlePost'+str(z),(handle_x,front-.005,z),(handle_x,handle_front-.004,z),.004,identity,'brass');obj['component']=component
 path=[(handle_x,front,z) for z in [.577]]
 path.extend([(handle_x,handle_front-.005,.579),(handle_x,handle_front,.587),(handle_x,handle_front,.633),(handle_x,handle_front-.005,.641),(handle_x,front,.643)])
 obj=curved_wire(identity+'_'+label+'Handle',path,.003,identity,'brass');obj['component']=component

panel('FixedLeaf',.191,.238,.06,.258)
stock('CentreUnderlap',(-.009,.222,.1),(.009,.237,.85),'trim',.0005)
component='SlidingPanel'
panel('SlidingLeaf',-.191,.262,-.06,.285)
construction_groups=[{'assembly':identity,'id':identity+'_JoinedCabinet','stocks':[x['name'] for x in stock_checks]}]
retained_stock=[{'assembly':identity,'kind':'prep_cabinet','worktop':.9,'source_panel_envelopes_preserved':True,'moving_component':'SlidingPanel','travel':.382,'fixed_panel_center_godot':[.191,.475,-.229],'sliding_panel_center_godot':[-.191,.475,-.253]}]
