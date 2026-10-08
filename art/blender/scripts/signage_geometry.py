"""Source-sized Harukiya apparatus. No new audio, take or game authority."""
def orient(p,axis):
 x,y,z=p
 return (y,x,z) if axis=='x' else (x,z,y) if axis=='z' else (x,y,z)

def shell(name,r0,r1,depth,thickness,key,axis='y',n=64):
 verts=[]
 for y,r in [(-depth/2,r0),(depth/2,r1),(depth/2,r1-thickness),(-depth/2,r0-thickness)]:
  verts.extend(orient((r*math.cos(i*math.tau/n),y,r*math.sin(i*math.tau/n)),axis) for i in range(n))
 return solid(name,verts,[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)],key)

def bore(obj,radius,at,depth=.05):
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=depth,location=C.to_3x3()@Vector(at),rotation=(math.pi/2,0,0))
 cutter=bpy.context.object;bpy.context.view_layer.objects.active=obj
 mod=obj.modifiers.new('Actual aperture','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

def profile_y(name,profile,key,n=48):
 verts=[(r*math.cos(i*math.tau/n),y,r*math.sin(i*math.tau/n)) for y,r in profile for i in range(n)]
 faces=[tuple(reversed(range(n)))]+[(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(len(profile)-1) for i in range(n)]+[tuple(range((len(profile)-1)*n,len(profile)*n))]
 return solid(name,verts,faces,key)

def link(name,a,b,r,key):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u);n=16
 vertices=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,vertices,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],key)

def cable(name,points,r,key):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=8;curve.bevel_depth=r;curve.bevel_resolution=2;curve.use_fill_caps=True
 spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
 for p,at in zip(spline.bezier_points,points):p.co=C.to_3x3()@Vector(at);p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 obj=bpy.data.objects.new(name,curve);bpy.context.scene.collection.objects.link(obj);bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH')
 vertices=[C.inverted().to_3x3()@v.co for v in obj.data.vertices];faces=[tuple(p.vertices) for p in obj.data.polygons];bpy.data.objects.remove(obj,do_unlink=True)
 return solid(name,vertices,faces,key)

def pan(name,size,key,wall=.002):
 w,h,d=size
 box(name+' back',(w,h,wall),(0,0,-d/2+wall/2),key,.0005)
 for x in [-1,1]:box(name+' return',(wall,h-wall,d-wall),(x*(w-wall)/2,0,wall/2),key,.00045)
 for y in [-1,1]:box(name+' end',(w-2*wall,wall,d-wall),(0,y*(h-wall)/2,wall/2),key,.00045)

def move_stock(start,offset):
 for obj,_ in pieces[start:]:
  for vertex in obj.data.vertices:vertex.co+=C.to_3x3()@Vector(offset)

def profiled_lantern(key):
 # Fine circumferential paper ribs, a finite shell and seated end necks.
 profile=[]
 for j in range(145):
  y=-.305+j*.610/144
  r=.2 if abs(y)<=.10 else math.sqrt(max(0.,.2**2-(abs(y)-.10)**2))
  r=max(.082,r)+.0008*math.cos(j*math.tau/4)
  profile.append((y,r))
 n=72;closed=profile+[(y,r-.0012) for y,r in reversed(profile)]
 vertices=[(r*math.cos(i*math.tau/n),y,r*math.sin(i*math.tau/n)) for y,r in closed for i in range(n)]
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%len(closed))*n+(i+1)%n,((j+1)%len(closed))*n+i) for j in range(len(closed)) for i in range(n)]
 solid('Ribbed finite paper envelope',vertices,faces,key)

def folded_blade():
 # Matches the original 0.22 m thickness, 5.665 m height and 0.85 m reach.
 h=5.665;mid=.765;lo=.34;hi=1.19
 for side in [-1,1]:
  box('Sheet face',(.002,h-.035,.814),(side*.109,0,mid),'iron_neutral')
  for z in [lo+.012,hi-.012]:box('Folded face seam',(.016,h-.04,.004),(side*.100,0,z),'iron_neutral')
 for y in [-h/2+.006,h/2-.006]:box('Turned end plate',(.216,.012,.826),(0,y,mid),'iron_neutral')
 for z in [lo+.006,hi-.006]:box('End return',(.216,h-.024,.012),(0,0,z),'iron_neutral')
 box('Transformer folded enclosure',(.16,.20,.30),(0,-h/2-.30,.58),'iron_neutral',.003)

for actor in plan['actors']:
 aid=actor['id'];replacements=[]
 chosen={'M14':[0,24,25,26,28,29,30,32,33,34,35,36,37],
         'M17':[0,1,2,3,4], 'M26':[36,37,41,42]}[aid]
 for part in actor['meshes']:
  index=part['index']
  if index not in chosen:continue
  current=f'{aid}_{index:03d}';start=len(pieces);key=current+'_source';static=True
  appearance=dict(part['materials'][0])
  finish=next((f for f in plan['source_finishes'] if f['actor']==actor['actor'] and (f['index']==index or aid=='M17' and index in [1,2])),None)
  if finish:appearance.update(color=finish['color'],roughness=finish['roughness'])
  material(key,appearance)
  if aid=='M14':
   if index==0:
    key='wood_dark'
    # Three fitted boards, with closed end grain and a narrow recessed seam.
    for i in range(3):box('Timber fascia board',(2.35,.1815,.05),(0,(i-1)*.184,0),key,.001)
    for x in [-1.075,1.075]:
     box('Rear cross batten',(.060,.51,.015),(x,0,-.0325),key)
     for y in [-.205,.205]:screw('Board fixing',(x,y,.0255),'brass',.003)
   elif index in [24,25,28,29]:
    key='iron_neutral';source_blank(part,key)
    # Hollow threaded socket collars at the existing pipe ends.
    for y in [-part['height']/2,part['height']/2]:tube('Threaded pipe socket',part['bottom_radius']+.004,part['bottom_radius']-.001,.018,(0,y,0),key,'y')
   elif index in [26,30]:
    shell('Open spun lamp shade',.095,.022,.10,.0015,'iron_neutral')
    tube('Rolled shade lip',.096,.092,.004,(0,-.049,0),'iron_neutral','y')
    tube('Porcelain lampholder',.023,.011,.034,(0,.028,0),'porcelain','y')
   elif index==32:
    rod('Fitted lantern bracket arm',.013,.40,(0,.01,0),'iron_neutral','y')
    tube('Lantern arm union',.019,.012,.030,(0,0,0),'iron_neutral','y')
   elif index==33:
    cable('Braided suspension flex',[(0,-.09,0),(.003,0,0),(0,.09,0)],.006,'rubber_aged')
    for y in [-.08,.08]:tube('Strain relief collar',.010,.006,.012,(0,y,0),'iron_neutral','y')
   elif index in [34,36]:
    profile_y('Turned lantern end',[(-.025,.086),(-.020,.09),(-.012,.09),(-.009,.080),(.020,.080),(.025,.07)],'iron_neutral')
    if index==34:
     tube('Seated lantern socket',.021,.010,.04,(0,.044,0),'porcelain','y')
   elif index==35:
    static=False;profiled_lantern(key)
   elif index==37:
    pan('Arrow service pan',part['size'],'iron_neutral')
    box('Removable arrow face',(.288,.838,.002),(0,0,.014),'iron_neutral')
    for x in [-.135,.135]:
     for y in [-.40,.40]:screw('Arrow cover screw',(x,y,.016),'brass',.0025)
  elif aid=='M17':
   if index in [0,1,2]:
    # Preserve the shared emission material and exact panel spans.
    static=False
    if index==0:box('Soft edge sign face',part['size'],(0,0,0),key,.0015)
    else:box('Rear-seated side return',(.05,.55,.975),(0,0,.0225),key,.0015)
   elif index==3:
    box('Bracket arm',(.05,.10,.522),(0,0,.039),'iron_neutral')
    box('Bracket wall plate',(.16,.25,.008),(0,0,-.226),'iron_neutral')
    link('Bracket triangular stay',(0,-.105,-.222),(0,-.048,.21),.009,'iron_neutral')
    for x in [-.053,.053]:
     for y in [-.08,.08]:screw('Bracket lag',(x,y,-.216),'brass',.004)
   elif index==4:
    # Open centre behind original independently controlled light faces.
    for x in [-.070,.070]:
     for z in [-.285,.285]:box('Face folded retaining lip',(.010,1.47,.030),(x,0,z),'iron_neutral')
     for y in [-.735,.735]:box('Face cap retaining lip',(.010,.030,.54),(x,y,0),'iron_neutral')
    for z in [-.296,.296]:box('Cabinet return',(.13,1.50,.008),(0,0,z),'iron_neutral')
    for y in [-.746,.746]:box('Cabinet end cap',(.13,.008,.584),(0,y,0),'iron_neutral')
    for y in [-.69,.69]:
     for x in [-.04,.04]:screw('End service screw',(x,y,.301),'brass',.003)
  else:
   half=2.8325;z0=.34
   if index==36:folded_blade()
   elif index==37:
    for sy in [-1,1]:
     box('Rolled blade end',(.242,.075,.90),(0,sy*half,.765),'iron_neutral',.006)
    for z in [.34,1.19]:box('Rolled long edge',(.242,5.74,.075),(0,0,z),'iron_neutral',.008)
    for sy in [-1,1]:
     y=sy*(half-.35)
     box('Cantilever arm',(.060,.090,.42),(0,y,.17),'iron_neutral')
     box('Seated wall plate',(.20,.30,.035),(0,y,.018),'iron_neutral',.003)
     link('Triangular bracket stay',(0,y-sy*.55,0),(0,y,.39),.016,'iron_neutral')
     box('Brace foot plate',(.08,.12,.010),(0,y-sy*.55,.005),'iron_neutral')
     for dy in [-.043,.043]:screw('Brace foot fixing',(0,y-sy*.55+dy,.013),'brass',.004)
    for x in [-.053,.053]:
     box('Transformer suspension strap',(.024,.27,.004),(x,-half-.105,.705),'iron_neutral')
     for y in [-half+.015,-half-.205]:screw('Transformer strap fixing',(x,y,.709),'brass',.003)
    for i in range(5):box('Transformer cooling fin',(.185,.016,.28),(0,-half-.375+i*.037,.58),'metal')
    box('Existing wall condulet',(.075,.075,.11),(0,-half-.65,.055),'iron_neutral',.008)
    box('Condulet cover',(.064,.064,.004),(0,-half-.65,.112),'iron_neutral')
    for y in [-half-.674,-half-.626]:screw('Condulet screw',(0,y,.115),'brass',.003)
   elif index==41:
    for sy in [-1,1]:
     for x in [-.062,.062]:
      for y in [-.10,.10]:
       rod('Lag seated washer',.016,.003,(x,sy*(half-.35)+y,.038),'metal')
       screw('Slotted bracket lag',(x,sy*(half-.35)+y,.042),'brass',.007)
   elif index==42:
    static=False
    # Retire broad rectangular rust decals; short tapered joint trails.
    for sy in [-1,1]:
     y=sy*(half-.35)
     for x in [-.062,.062]:
      solid('Tapered anchor rain trace',[(x-.006,y-.10,.036),(x+.006,y-.10,.036),(x+.001,y-.145,.036),(x-.001,y-.145,.036),(x-.006,y-.10,.0364),(x+.006,y-.10,.0364),(x+.001,y-.145,.0364),(x-.001,y-.145,.0364)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],key)
  name=f'{aid}_P{index:03d}';obj,used=mesh_partition(name,pieces[start:])
  replacements.append({'index':index,'mesh':name,'source_type':part['type'],'size':part.get('size',[]),'preserve_material':not static,'materials':used if static else []})
  display=obj.copy();display.name=name+'_review';review.objects.link(display);display.matrix_world=pose_of(part);display['actor']=aid;display.hide_render=not part['visible']
 current=aid+'_attachments';start=len(pieces)
 if aid=='M14':
  # A common rear box explains the existing switched sign circuits. The
  # concealed incoming supply is not extended into undocumented masonry.
  box('Rear sign junction',(.10,.075,.014),(0,.20,-.032),'iron_neutral')
  for x in [-1.02,1.02]:
   cable('Board lamp branch',[(0,.20,-.032),(x,.20,-.032),(x,.282,-.032),(x,.32,.015)],.004,'rubber_aged')
   box('Board lamp flange',(.050,.06,.006),(x,.303,.014),'iron_neutral')
  cable('Lantern branch',[(0,.20,-.032),(1.20,.20,-.032),(1.42,.32,-.04),(1.42,.32,.13)],.004,'rubber_aged')
  box('Lantern arm fixing plate',(.10,.13,.012),(1.42,.32,-.054),'iron_neutral')
  for y in [.277,.363]:screw('Lantern bracket fixing',(1.42,y,-.045),'brass',.004)
 elif aid=='M17':
  # Narrow edge folds explain the existing valance thickness without covering
  # any face text. The original opaque panels keep their emission identity.
  for y in [-.59,-.05]:
   box('Valance front folded edge',(4.35,.010,.055),(0,y,1.05),'iron_neutral')
   for x in [-2.175,2.175]:box('Valance side fold',(.055,.010,1.01),(x,y,.53),'iron_neutral')
  for x in [-2.175,2.175]:
   box('Rear valance flange',(.06,.55,.008),(x,-.32,.064),'iron_neutral')
   for y in [-.52,-.13]:screw('Valance end fixing',(x,y,.070),'brass',.003)
  # Fitted sign frame = original bodega frame translated (0,2.62,.08).
  # Start at the existing independent lighting-spine front junction.
  service=plan['bodega_service'];supply_point=Vector(service['existing_front_junction'])-Vector(service['sign_offset']);sx,sy,sz=supply_point
  # A 22 mm sleeved service port in the fitted timber header, below masonry.
  port_y=plan['bodega_service_port']['center'][1]-service['sign_offset'][1]
  route=[tuple(supply_point),(sx,sy,-.30),(sx,port_y,-.30),(sx,port_y,.12),(sx,sy,.12),(-2.05,sy,.12),(-2.05,sy,.33)]
  for i,(a,b) in enumerate(zip(route,route[1:])):link('Existing-service branch '+str(i),a,b,.008,'iron_neutral')
  for at in route:
   box('Screwed conduit elbow',(.029,.029,.029),at,'iron_neutral',.004)
  for z in [-1.5,-.7]:
   box('Ceiling-seated conduit strap',(.050,.007,.025),(sx,.5265,z),'iron_neutral')
   link('Ceiling conduit hanger',(sx,.523,z),(sx,sy+.008,z),.003,'iron_neutral')
  for y in [.14,.36]:
   box('Vertical branch saddle',(.045,.018,.055),(sx,y,.0975),'iron_neutral')
  tube('Timber header insulating sleeve',.0105,.0085,.10,(sx,port_y,-.045),'rubber_aged','z')
  for z in [-.097,.007]:tube('Seated service-port escutcheon',.018,.0085,.004,(sx,port_y,z),'iron_neutral','z')
  for x in [-1.7,-.5,.65,1.55]:
   box('Conduit bearing saddle',(.045,.018,.05),(x,.48,.097),'iron_neutral')
   for dx in [-.017,.017]:screw('Conduit saddle fixing',(x+dx,.48,.082),'brass',.0025)
  link('Valance branch drop',(sx,sy,.12),(sx,-.035,.12),.006,'iron_neutral')
  link('Valance top-edge branch',(sx,-.035,.12),(sx,-.035,1.012),.006,'iron_neutral')
  box('Valance existing-light termination',(.055,.035,.04),(sx,-.035,1.01),'iron_neutral')
 if len(pieces)>start:
  obj,used=mesh_partition(aid+'_Fixed',pieces[start:]);display=obj.copy();review.objects.link(display);display['actor']=aid;display.name=aid+'_Fixed_review';additions=[{'mesh':obj.name,'materials':used}]
 else:additions=[]
 records.append({'id':actor['actor'],'script':actor['script'],'source_mesh_count':len(actor['meshes']),'replacements':replacements,'additions':additions})
