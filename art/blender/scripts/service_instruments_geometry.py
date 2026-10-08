"""Per-instrument construction recipes, executed by build_service_instruments."""
def perforate(obj,holes):
 for size,at in holes:
  bpy.ops.mesh.primitive_cube_add(size=1,location=C.to_3x3()@Vector(at));cutter=bpy.context.object
  cutter.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Machined opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

def jointed_back(w,h,t,key):
 # A housed central board, discrete framing stocks and visible assembly seams.
 rail=min(.026,w*.1)
 box('Backboard',(w-rail*2,h-rail*2,t*.62),(0,0,-t*.19),key)
 frame('Housed frame',w,h,t,rail,(0,0,0),key)

def folded_tray(w,h,d,at,key):
 x,y,z=at;t=.002
 box('Folded sheet back',(w,h,t),(x,y,z-d/2+t/2),key,.00035)
 for side in [-1,1]:
  box('Folded side',(t,h,d-t),(x+side*(w-t)/2,y,z+t/2),key,.00035)
  box('Folded end',(w-2*t,t,d-t),(x,y+side*(h-t)/2,z+t/2),key,.00035)

def hinges(w,h,z,y=0):
 for yy in [y-h*.29,y+h*.29]:
  box('Hinge leaf',(.021,.040,.0015),(-w/2+.008,yy,z),'brass',.0002)
  rod('Hinge pin',.003,.044,(-w/2,yy,z+.002),'brass','y')
  for dy in [-.012,.012]:screw('Hinge screw',(-w/2+.009,yy+dy,z+.0015),radius=.002)

def tube_path(points,r,key):
 verts=[];n=12
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized();u=tangent.cross(Vector((0,0,1))).normalized();v=tangent.cross(u)
  verts.extend(p+r*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
 faces=[tuple(reversed(range(n)))]+[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)]+[tuple(range((len(points)-1)*n,len(points)*n))]
 solid('Continuous flexible lead',verts,faces,key)

for actor in plan['actors']:
 aid=actor['id'];replacements=[];review_parts=[];current=aid
 # Keep all source planes and controls. Only named fabrication partitions
 # replace their mesh payloads; the original node/material can stay live.
 for part in actor['meshes']:
  index=part['index'];current=f'{aid}_{index:03d}';start=len(pieces);key=current+'_source'
  material(key,part['materials'][0]);static=False;suppress=False
  if aid=='M01' and index==0:
   key='wood_dark';static=True;jointed_back(.26,.62,.06,key)
  elif aid=='M01' and index==1:
   key='brass';static=True;face=box('Pierced brass face',part['size'],(0,0,0),key,.0005)
   holes=[]
   for i in range(8):
    y=.235-i*.063
    holes.extend([((.051,.031,.04),(-.055,y,0)),((.071,.026,.04),(.040,y,0))])
   perforate(face,holes);fasteners(.190,.528,.007)
  elif aid=='M02' and index==6:
   shell=ellipsoid('Soldered copper float',(.079,.044,.079),key)
   seam=torus('Soldered equator',.078,.0014,key)
   # Fit the source guard's 162 mm clear throat and clear its back plate.
   # This is a visual depth offset; the original buoyancy datum stays owned.
   for obj in [shell,seam]:
    for v in obj.data.vertices:v.co+=C.to_3x3()@Vector((0,.040,0))
  elif aid=='M02' and index==9:
   weight=box('Captive adjustable weight',part['size'],(0,0,0),key,.003)
   perforate(weight,[((.09,.058,.036),(0,0,0))])
  elif aid=='M02' and index==10:
   # Rounded renewable valve casting with a separate union and cover flange.
   rod('Valve casting',.068,.13,(0,0,0),key,'y',.050)
   rod('Bonnet flange',.070,.018,(0,.063,0),key,'y')
   for x in [-.046,.046]:rod('Bonnet fastener',.006,.015,(x,.078,0),key,'y',n=6)
  elif aid=='M02' and index==13:
   tube('Open stop wheel',.088,.072,.026,(0,0,0),key,'y')
   rod('Stop wheel hub',.014,.026,(0,0,0),key,'y')
  elif aid=='M02' and index==19:
   # Open witness lip retains the water owner's exact discharge datum.
   box('Witness lip bottom',(.12,.006,.12),(0,-.0245,0),key)
   for x in [-.057,.057]:box('Witness lip side',(.006,.049,.12),(x,.003,0),key)
   box('Witness lip back',(.108,.049,.006),(0,.003,-.057),key)
  elif aid in ['M03','M04','M05','M06'] and index==0:
   key='wood_dark';static=True;jointed_back(*part['size'],key)
  elif (aid=='M03' and index in [1,2,3,4]) or (aid=='M04' and index in [1,2,3,4]) or (aid=='M05' and index in [2,3,4,5]) or (aid=='M06' and index in [1,2]):
   key='wood_dark';static=True;size=list(part['size'])
   # Rails fit between stiles. Fine seams make independently grained stock legible.
   if size[0]>.2 and size[1]<.04:size[0]-=.046 if aid=='M04' else .032
   box('Rebated cabinet stock',size,(0,0,0),key)
  elif aid=='M04' and index in [5,6]:
   key='wood_dark';static=True;x,y,z=part['size'];solid('Shaped shelf bracket',[(-x/2,y/2,-z/2),(x/2,y/2,-z/2),(-x/2,-y/2,-z/2),(x/2,-y/2,-z/2),(-x/2,y/2,z/2),(x/2,y/2,z/2)],[(0,1,3,2),(0,4,5,1),(2,3,5,4),(0,2,4),(1,5,3)],key,.001)
  elif aid=='M06' and index==8:
   tube('Open key bow',.015,.008,.005,(0,0,0),key,'y')
  elif aid=='M06' and index==9:suppress=True
  elif aid=='M07' and index==0:
   key='cast_iron';static=True;folded_tray(.66,.9,.12,(0,0,0),key)
  elif aid=='M07' and index in [1,2,3,21]:
   # Smooth painted sheet, dielectric. The inherited prop color remains the
   # finish owner; geometry provides thickness and rolled/folded returns.
   size=list(part['size'])
   if index==1:folded_tray(size[0],size[1],.006,(0,0,0),key)
   elif index in [2,3]:box('Sheet cabinet return',(.0025,size[1],size[2]),(0,0,0),key,.0004)
   else:
    pose=pose_of(part);hinge=C.to_3x3()@Vector((-.315,.5,.142));local=C.inverted().to_3x3()@(pose.inverted()@hinge)
    center=local+Vector((.32,0,0));folded_tray(.64,.90,.014,center,key)
  elif aid=='M07' and index==4:
   for x in [-.095,0,.095]:
    box('Knife contact left',(.009,.045,.045),(x-.009,0,0),key,.0007)
    box('Knife contact right',(.009,.045,.045),(x+.009,0,0),key,.0007)
  elif aid=='M07' and index==5:
   box('Common blade bridge',(.26,.012,.012),(0,-.009,0),key,.0005)
   for x in [-.095,0,.095]:box('Knife blade',(.007,.030,.030),(x,0,0),key,.0005)
  elif aid=='M07' and index in [8,9,10]:
   tube('Porcelain screw base',.038,.025,.030,(0,0,0),key)
  elif aid=='M07' and index in [11,23]:
   radius=part['top_radius'];tube('Plug body and inspection recess',radius,.026,part['height'],(0,0,0),key)
   for j in range(24):
    a=j*math.tau/24;rod('Grip rib',.0017,part['height']*.6,((radius-.001)*math.cos(a),(radius-.001)*math.sin(a),0),key,n=12)
  elif aid=='M07' and index in [12,18,19,20]:rod('Front facing insert',part['bottom_radius'],part['height'],(0,0,0),key)
  elif aid=='M08' and index==0:
   key='wood_dark';static=True;box('Removable rear board',(.620,.640,.012),(0,0,.074),key)
   frame('Housed switchboard case',.66,.68,.16,.025,(0,0,0),key)
   fasteners(.616,.638,-.080)
  elif aid=='M08' and index==1:
   key='bakelite';static=True;panel=box('Phenolic panel',part['size'],(0,0,0),key,.001)
   # The original socket axes pass through this panel; real bores receive
   # the brass liners instead of placing filled discs over a solid block.
   for row in range(3):
    for col in range(6):
     at=(-.25+col*.1,.15-row*.13,0);bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.015,depth=.05,location=C.to_3x3()@Vector(at),rotation=(math.pi/2,0,0));cutter=bpy.context.object
     bpy.context.view_layer.objects.active=panel;mod=panel.modifiers.new('Socket bore','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  elif aid=='M08' and 2<=index<=19:
   key='brass';static=True;tube('Jack ferrule',.018,.011,.018,(0,0,0),key,'y')
   tube('Recessed insulation',.011,.006,.015,(0,.004,0),'bakelite','y')
  elif aid=='M08' and index==22:
   key='rubber_aged';static=True;pose=pose_of(part);inv=C.inverted()@pose.inverted()@C
   points=[inv@Vector((-.25+.5*i/64,.055+3.28*(-.25+.5*i/64)**2,-.135)) for i in range(65)]
   tube_path(points,.006,key)
   for x in [-.25,.25]:
    plug=rod('Cord plug shank',.005,.026,(x,.26,-.125),'brass')
    collar=rod('Plug strain relief',.009,.008,(x,.26,-.137),key)
    for obj in [plug,collar]:
     for vertex in obj.data.vertices:vertex.co=pose.inverted()@vertex.co
  elif aid=='M08' and 23<=index<=30:suppress=True
  elif aid=='M09' and index in [6,7,8,9,10]:
   key='wood_dark';static=True;source_blank(part,key)
  elif aid=='M09' and index==3:
   blank=source_blank(part,key)
   perforate(blank,[((.022,.06,.022),(x,0,0)) for x in [-.269,.23]])
  elif aid=='M09' and index==4:
   key='timber';static=True
   # Open loading face, closed car stock; floor and wall joints stay legible.
   box('Car floor',(.42,.018,.20),(0,-.141,0),key)
   box('Car back',(.42,.282,.014),(0,.009,-.093),key)
   for x in [-.202,.202]:box('Car side',(.016,.282,.186),(x,.009,.007),key)
   for x in [-.193,.193]:box('Car corner angle',(.012,.26,.012),(x,0,-.079),'metal')
   box('Suspension crosshead',(.40,.012,.025),(0,.136,0),'metal')
   tube('Car suspension eye',.012,.006,.010,(-.179,.146,0),'metal')
  elif aid=='M09' and index==11:
   # Groove shoulders surround a recessed running surface, plus a real hub.
   rod('Sheave running surface',.093,.030,(0,0,0),key,'y')
   for y in [-.018,.018]:rod('Sheave rim',.105,.006,(0,y,0),key,'y')
   rod('Sheave axle collar',.022,.056,(0,0,0),key,'y')
   rod('Rear lift groove',.093,.015,(0,-.245,0),key,'y')
   for y in [-.256,-.234]:rod('Rear lift rim',.105,.007,(0,y,0),key,'y')
   rod('Connected head shaft',.012,.29,(0,-.1225,0),'metal','y')
  elif aid=='M09' and index==15:
   rod('Continuous hand rope',.009,.98,(0,0,0),key,'y',n=24)
  else:source_blank(part,key)
  name=f'{aid}_P{index:03d}'
  if suppress:
   replacements.append({'index':index,'mesh':'','source_type':part['type'],'size':part.get('size',[]),'preserve_material':True,'materials':[]});continue
  obj,used=mesh_partition(name,pieces[start:]);replacements.append({'index':index,'mesh':name,'source_type':part['type'],'size':part.get('size',[]),'preserve_material':not static,'materials':used if static else []})
  display=obj.copy();display.name=name+'_review';review.objects.link(display);display.matrix_world=pose_of(part);display['actor']=aid;display.hide_render=not part['visible'];review_parts.append(display)
  if aid=='M06' and part['path'].startswith('TourCheck/'):display.hide_render=True
  if aid=='M09' and index==15:display.hide_render=True
 # Fixed attachments are in actor coordinates, never below a moving paper,
 # shutter, key or blade. Small fasteners have actual slotted heads.
 current=aid+'_attachments';start=len(pieces)
 if aid=='M02':
  fasteners(.292,.212,.053,.05,'metal')
  # A fixed bearing around the source lever pivot, leaving its full sweep.
  tube('Lever pivot bushing',.020,.008,.026,(.12,.20,.091),'brass')
  rod('Lever pivot pin',.008,.065,(.12,.20,.12),'metal')
  box('Lever bearing pedestal',(.045,.075,.035),(.12,.172,.061),'cast_iron')
  for y in [.35,2.10]:
   tube('Balance pipe gland',.034,.025,.014,(-.14,y,.041),'brass')
  for y in [-.05,-1.13]:
   rod('Riser union',.046,.035,(-.14,y,.135),'brass','y',n=6)
  for y in [.6,1.95]:
   tube('Overflow clamp',.047,.042,.018,(-.34,y,.09),'metal','y')
   box('Overflow clamp seat',(.028,.035,.065),(-.34,y,.042),'metal')
 elif aid=='M01':
  hinges(.26,.62,.029);fasteners(.226,.57,.031)
 elif aid=='M03':
  frame('Glazing rebate',.318,.378,.004,.009,(0,.2,.140),'wood_dark');hinges(.34,.40,.143,.2)
  fasteners(.306,.357,.146,.2)
 elif aid=='M04':
  fasteners(.574,.435,.029,.25)
  for x in [.055,.215]:
   rod('Hook seating boss',.009,.004,(x,.400,.028),'brass');screw('Hook fixing',(x,.414,.03),radius=.0025)
  box('Ledger retaining lip',(.70,.012,.008),(0,.066,.234),'wood_dark')
 elif aid=='M05':
  hinges(.40,.46,.099,.23);fasteners(.373,.415,.101,.23)
  for x in [-.166,-.08,.006,.092,.166]:screw('Guide fastening',(x,.173,.101),radius=.0019)
 elif aid=='M06':
  fasteners(.125,.216,.024,.13);rod('Hook root ferrule',.008,.004,(0,.17,.024),'brass')
  rod('Latch pivot seat',.010,.004,(.03,.17,.028),'brass')
 elif aid=='M07':
  for x in [-.21,.21]:
   for y in [.385,.535]:screw('Fuse block screw',(x,y,.104),'metal',.004)
  for y in [.25,.75]:
   rod('Door hinge pin',.006,.065,(-.315,y,.142),'metal','y')
   box('Wall hinge leaf',(.025,.06,.002),(-.303,y,.139),'metal',.0004)
  for x in [-.095,0,.095]:rod('Knife insulating boss',.018,.025,(x,.80,.047),'ceramic')
 elif aid=='M08':
  for x in [-.275,.275]:
   for y in [.127,.612]:screw('Panel screw',(x,y,-.109),'brass',.0035)
 elif aid=='M09':
  # All guide and head bearings attach to the original shaft/casing stock.
  for x in [-.312,.132,.168,.292]:box('Guide rail',(.008,.60,.018),(x,.30,.119),'metal')
  for x in [-.17,.17]:
   box('Bearing foot',(.095,.020,.13),(x,.7915,.335),'cast_iron')
   for z in [.332,.416]:
    box('Bearing cheek',(.055,.108,.012),(x,.842,z),'cast_iron')
   rod('Head axle',.013,.112,(x,.89,.375),'metal')
   for dx in [-.032,.032]:screw('Bearing foot fixing',(x+dx,.790,.397),'metal')
  fasteners(.776,.720,.351,.30,'brass')
  # Source: US950828A draft rope joins car and counterweight; a separate
  # hand rope turns the common shaft. Routes adapt that construction to the
  # retained service prop's compact casing, without changing its state.
  for x in [-.17,.131]:
   box('Rear bearing cantilever',(.055,.016,.23),(x,.7895,.25),'cast_iron')
   box('Rear bearing pedestal',(.035,.09,.025),(x,.842,.106),'cast_iron')
   rod('Rear bearing axle',.012,.052,(x,.89,.13),'metal')
  rod('Counterweight guide groove',.093,.015,(.131,.89,.13),'metal')
  for z in [.119,.141]:rod('Counterweight guide rim',.105,.007,(.131,.89,z),'metal')
  load=[Vector((-.17+.099*math.cos(a),.89+.099*math.sin(a),.13)) for a in [math.pi-i*math.pi/64 for i in range(33)]]
  load.extend(Vector((.131+.099*math.cos(a),.89+.099*math.sin(a),.13)) for a in [math.pi/2-i*math.pi/64 for i in range(33)])
  tube_path(load,.006,'M09_015_source')
  tube_path([Vector((-.17+.099*math.cos(a),.89+.099*math.sin(a),.375)) for a in [math.pi-i*math.pi/64 for i in range(65)]],.006,'M09_015_source')
 if len(pieces)>start:
  obj,used=mesh_partition(aid+'_Fixed',pieces[start:]);display=obj.copy();review.objects.link(display);display['actor']=aid;display.name=aid+'_Fixed_review'
  additions=[{'mesh':obj.name,'materials':used}]
 else:additions=[]
 records.append({'id':actor['actor'],'script':actor['script'],'source_mesh_count':len(actor['meshes']),'replacements':replacements,'additions':additions})
