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

for actor in plan['actors']:
 aid=actor['id'];replacements=[]
 for part in actor['meshes']:
  index=part['index'];current=f'{aid}_{index:03d}';start=len(pieces);key=current+'_source';static=False
  material(key,part['materials'][0])
  if aid=='M11' and index in [3,5,7,8]:
   key={3:'paper',5:'bakelite',7:'brass',8:'brass'}[index];static=True
  if aid=='M13' and index in [2,3,5,6,7,8,12,13,14,15,16,18]:
   key='brass' if index in [8,12,14,15,18] else 'cast_iron';static=True
  if aid=='M11' and index==0:
   key='wood_dark';static=True
   for x in [-.163,.163]:box('Veneered side',(.014,.55,.30),(x,0,0),key)
   for y in [-.2675,.2675]:box('Housed end',(.312,.015,.30),(0,y,0),key)
   frame('Rear service frame',.312,.520,.014,.025,(0,0,-.143),key)
   box('Recessed back panel',(.259,.467,.010),(0,0,-.142),key)
  elif aid=='M11' and index==1:
   panel=box('Recessed baffle',part['size'],(0,0,0),key)
   for at,r in [((0,.085,0),.105),((0,-.16,0),.052),((.09,-.16,0),.030)]:bore(panel,r,at)
  elif aid=='M11' and index==3:
   # A thin conical paper shell, open toward the listener. The inherited
   # primitive had a filled cap and hid the recess against the baffle.
   obj=shell('Paper cone',.100,.028,.030,.0012,key)
   for v in obj.data.vertices:v.co+=C.to_3x3()@Vector((0,-.015,0))
  elif aid=='M11' and index==4:
   profile_y('Domed dust cap',[(-.014,.001),(-.012,.010),(-.007,.018),(.003,.023),(.014,.026),(.023,.028)],key)
  elif aid=='M11' and index==5:
   shell('Open tweeter flare',.052,.016,.035,.002,key)
  elif aid=='M11' and index==6:
   tube('Open bass port',.030,.025,.020,(0,0,0),key,'y')
  elif aid=='M12' and index==0:
   box('Holder bottom',(.075,.006,.075),(0,-.047,0),key)
   for x in [-.0345,.0345]:box('Holder side',(.006,.094,.075),(x,.003,0),key)
   for z in [-.0345,.0345]:box('Holder end',(.063,.094,.006),(0,.003,z),key)
  elif aid=='M12' and index in [1,2,3]:
   profile_y('Point and turned barrel',[(-.08,.0002),(-.062,.0025),(-.045,.0025),(-.041,.004),(.005,.004),(.010,.002),(.08,.002)],key,n=32)
   for y in [-.033,-.024,-.015,-.006]:tube('Barrel grip ring',.0042,.0039,.0015,(0,y,0),key,'y',n=32)
  elif aid=='M12' and index in [4,5,6]:
   outline=[(-.006,-.015),(-.013,.006),(-.010,.015),(.010,.015),(.013,.006),(.006,-.015)]
   for cross in [False,True]:
    verts=[(z,y,x) if cross else (x,y,z) for z in [-.00045,.00045] for x,y in outline];n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
    solid('Folded finite flight',verts,faces,key,.00012)
   # Fit the flight to its source shaft while retaining the original node pose.
   shaft=actor['meshes'][index-3]
   fit=pose_of(part).inverted()@pose_of(shaft)@Matrix.Translation(C.to_3x3()@Vector((0,.076,0)))
   for obj,_ in pieces[start:]:
    for vertex in obj.data.vertices:vertex.co=fit@vertex.co
  elif aid=='M13' and index in [0,1]:
   key='wood_dark';static=True
   if index==0:
    frame('Joined walnut plinth',.62,.10,.34,.014,(0,0,0),key)
    box('Plinth bottom',(.59,.008,.31),(0,-.046,0),key)
    for z in [-.164,.164]:box('Housed plinth panel',(.592,.072,.012),(0,0,z),key)
   else:box('Moulded top',part['size'],(0,0,0),key,.003)
  elif aid=='M13' and index==4:
   key='wood_dark';static=True
   # Coopered recording horn, 32 finite staves. The mouth is genuinely open.
   for stave in range(32):
    angles=[(stave+(j/3))*math.tau/32+.00035 for j in range(4)]
    angles[-1]-=.00070
    verts=[(r*math.cos(a),y,r*math.sin(a)) for y,r in [(-.15,.052),(.15,.145),(.15,.138),(-.15,.045)] for a in angles]
    faces=[]
    for k in range(4):
     for j in range(3):faces.append((k*4+j,k*4+j+1,((k+1)%4)*4+j+1,((k+1)%4)*4+j))
    faces.extend([(0,4,8,12),(3,15,11,7)]);solid('Coopered horn stave',verts,faces,key)
  elif aid=='M13' and index in [5,6,7]:
   x=part['position'][0];r=.052+.093*(-(x+.16)+.15)/.30
   shell('Seated hoop',r-.00186+.0015,r+.00186+.0015,.012,.0025,key)
  elif aid=='M13' and index==8:
   shell('Open diaphragm collar',.055,.055,.030,.005,key,axis='x')
  elif aid=='M13' and index==10:
   obj=profile_y('Tapered recording bristle',[(-.0375,.0013),(.020,.0006),(.025,.0002)],key,n=16)
   # Retain the original lever owner, with its passive tip at cylinder x=.08.
   for v in obj.data.vertices:v.co=C.to_3x3()@Vector(orient(C.inverted().to_3x3()@v.co,'x'))
  elif aid=='M13' and index==17:
   profile_y('Turned crank grip',[(-.02,.009),(-.018,.014),(-.012,.013),(.012,.011),(.018,.014),(.02,.010)],key)
  elif aid=='M13' and index==11:
   rod('Smoked recording cylinder',part['bottom_radius'],part['height'],(0,0,0),key,'y',part['top_radius'],n=64)
  elif aid=='M13' and index==12:
   rod('Continuous axle into crank hub',.020,.320,(0,0,0),key,'y',n=48)
  else:source_blank(part,key)
  if aid=='M13':
   # The retained marker was inside the dado. Move only visual stock along
   # the common cylinder/crank axis; source nodes and their axes stay intact.
   offset=pose_of(part).to_3x3().inverted()@(C.to_3x3()@Vector((0,0,.10)))
   for piece,_ in pieces[start:]:
    for vertex in piece.data.vertices:vertex.co+=offset
  name=f'{aid}_P{index:03d}';obj,used=mesh_partition(name,pieces[start:])
  replacements.append({'index':index,'mesh':name,'source_type':part['type'],'size':part.get('size',[]),'preserve_material':not static,'materials':used if static else []})
  display=obj.copy();display.name=name+'_review';review.objects.link(display);display.matrix_world=pose_of(part);display['actor']=aid;display.hide_render=not part['visible']
 current=aid+'_attachments';start=len(pieces)
 if aid=='M11':
  fasteners(.264,.474,.157,.275,'brass')
  for x in [-.13,.13]:
   for y in [.055,.495]:screw('Back service fixing',(x,y,-.155),'brass')
  box('Attached terminal plate',(.085,.052,.006),(0,.105,-.153),'bakelite')
  for x in [-.023,.023]:rod('Speaker binding post',.006,.012,(x,.105,-.161),'brass')
  # The existing 60 mm dado is the visible bearing face below its top.
  for x in [-.115,.115]:
   box('Wall bearing plate',(.055,.34,.008),(x,-.05,-.536),'cast_iron')
   box('Cabinet bearing arm',(.026,.012,.648),(x,-.006,-.208),'cast_iron')
   link('Triangular bracket stay',(x,-.205,-.529),(x,-.012,.095),.009,'cast_iron')
   for y in [-.18,.08]:screw('Wall fixing',(x,y,-.531),'brass')
  box('Passive wall termination',(.066,.058,.010),(0,.09,-.535),'bakelite')
  cable('Terminated speaker flex',[(0,.066,-.18),(0,.018,-.26),(0,-.015,-.43),(0,.065,-.50),(0,.09,-.523)],.0035,'rubber_aged')
  for x in [-.023,.023]:cable('Terminal branch',[(x,.105,-.168),(x,.085,-.19),(0,.066,-.18)],.0016,'rubber_aged')
 elif aid=='M13':
  # The retained west dado is 100 mm behind the actor marker.
  # The two original iron feet bear on these short, braced shelf arms.
  for x in [-.26,.26]:
   box('Wall mounting plate',(.060,.22,.006),(x,-.08,-.097),'cast_iron')
   box('Foot bearing shelf',(.066,.008,.262),(x,-.009,.035),'cast_iron')
   link('Shelf brace',(x,-.182,-.093),(x,-.013,.150),.007,'cast_iron')
   for y in [-.163,-.030]:screw('Wall plate fixing',(x,y,-.092),'brass')
  mount_end=len(pieces)
  for x in [.018,.292]:
   for z in [-.09,.09]:
    box('Carriage rail pedestal',(.022,.060,.024),(x,.145,z),'cast_iron')
    box('Carriage foot',(.042,.008,.040),(x,.119,z),'cast_iron')
  for z in [-.138,.138]:
   box('Axle bearing foot',(.067,.018,.058),(.155,.124,z),'cast_iron')
   box('Axle bearing pedestal',(.040,.15,.024),(.155,.203,z),'cast_iron')
   tube('Axle bearing bush',.029,.0202,.019,(.155,.30,z),'brass')
   for x in [.133,.177]:screw('Bearing foot fixing',(x,.133,z+.016),'brass')
  for x in [-.27,-.08]:
   r=.052+.093*(-(x+.16)+.15)/.30;top=.30-r-.0015
   box('Horn hoop saddle',(.028,top-.115,.035),(x,(top+.115)*.5,0),'cast_iron')
   box('Horn foot',(.052,.008,.065),(x,.119,0),'cast_iron')
  for x in [-.27,.27]:
   for z in [-.135,.135]:screw('Plinth fixing',(x,.117,z),'brass')
  for piece,_ in pieces[mount_end:]:
   for vertex in piece.data.vertices:vertex.co+=C.to_3x3()@Vector((0,0,.10))
 if len(pieces)>start:
  obj,used=mesh_partition(aid+'_Fixed',pieces[start:]);display=obj.copy();review.objects.link(display);display['actor']=aid;display.name=aid+'_Fixed_review';additions=[{'mesh':obj.name,'materials':used}]
 else:additions=[]
 records.append({'id':actor['actor'],'script':actor['script'],'source_mesh_count':len(actor['meshes']),'replacements':replacements,'additions':additions})
