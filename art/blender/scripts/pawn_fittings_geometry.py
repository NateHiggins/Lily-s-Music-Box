"""Room-composed Pawn fittings; executed by build_pawn_fittings.py's stock kernel."""

def bearing(identity, owner, point, direction=(0,0,1), label='seated bearing', native=False):
 support(identity,owner,point,direction,label)
 contacts[-1]['native_owner']=native

def slab_outline(name, outline, a, b, identity, key, axis='x'):
 # Outline is (Y,Z) for X extrusion, or (X,Z) for Y extrusion.
 n=len(outline)
 verts=[(t,u,v) if axis=='x' else (u,t,v) for t in [a,b] for u,v in outline]
 obj=solid(name,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],identity,key)
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked perimeter','BEVEL');mod.width=.004;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

for item in assemblies:
 row=item['body'];identity=item['id'];kind=item['kind'];ground=floor['z0']+floor['h']
 if kind=='rack':
  x0,y0,x1,y1=row['rect']
  for xx in [x0+.024,x1-.024]:
   for yy in [y0+.024,(y0+y1)/2,y1-.024]:
    box(identity+f'_Upright{xx}_{yy}',(xx-.023,yy-.023,ground),(xx+.023,yy+.023,2.57),identity,'timber',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='rack post on oak floor')
  for source in item['members']:
   q=source['rect'];z=source['z0'];name=source['id']
   if '_shelf' in name:
    box(name+'_Deck',(q[0],q[1],z),(q[2],q[3],z+source['h']),identity,'timber',.002)
    for yy in [y0+.024,(y0+y1)/2,y1-.024]:
     box(name+'_Bearer'+str(yy),(x0,yy-.03,z-.05),(x1,yy+.03,z+.003),identity,'timber',.002)
   else:
    z-=.005
    box(name+'_Wrapped',(q[0],q[1],z),(q[2],q[3],z+source['h']),identity,source['mat'],.012)
    cx=(q[0]+q[2])/2;cy=(q[1]+q[3])/2;top=z+source['h']
    # Two real cord loops seat on the wrapper; blank folded tag shares the knot.
    curved_wire(name+'_CrossTie',[(q[0]-.001,cy,z+.012),(q[0]-.001,cy,top-.01),(q[0]+.01,cy,top+.001),(q[2]-.01,cy,top+.001),(q[2]+.001,cy,top-.01),(q[2]+.001,cy,z+.012),(q[2]-.01,cy,z+.001),(q[0]+.01,cy,z+.001),(q[0]-.001,cy,z+.012)],.0022,identity,'linen')
    curved_wire(name+'_LongTie',[(cx,q[1]-.001,z+.012),(cx,q[1]-.001,top-.01),(cx,q[1]+.01,top+.001),(cx,q[3]-.01,top+.001),(cx,q[3]+.001,top-.01),(cx,q[3]+.001,z+.012),(cx,q[3]-.01,z+.001),(cx,q[1]+.01,z+.001),(cx,q[1]-.001,z+.012)],.0022,identity,'linen')
    box(name+'_BlankTag',(q[0]-.003,cy-.033,top-.12),(q[0]+.001,cy+.033,top-.03),identity,'paper',.0005)
  # Extra upper machine shelf is bracketed into the six original rack posts.
  box(identity+'_MachineDeck',(22.28,-54.50,2.35),(22.86,-53.20,2.38),identity,'timber',.003)
  for yy in [-54.412,-53.318]:
   rod(identity+'_DeckStrut'+str(yy),(22.835,yy,1.91),(22.31,yy,2.35),.016,identity,'iron_blackened',16)
   box(identity+'_DeckBackBearer'+str(yy),(22.815,yy-.022,1.90),(22.855,yy+.022,2.37),identity,'timber',.002)
  box(identity+'_TopRearRail',(22.813,y0,2.51),(22.86,y1,2.56),identity,'timber',.002)
  continue
 if kind=='counter':
  x0,y0,x1,y1=20.95,-54.84,21.65,-52.30
  box(identity+'_Worktop',(x0,y0,1.13),(x1,y1,1.18),identity,'countertop',.004)
  for xx in [20.988,21.612]:
   for yy in [-54.798,-53.78,-52.344]:
    box(identity+f'_Post{xx}_{yy}',(xx-.025,yy-.025,ground),(xx+.025,yy+.025,1.145),identity,'wood_dark',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='counter foot on retained floor')
  for xx in [20.97,21.60]:
   for zz in [.13,1.065]:box(identity+f'_Rail{xx}_{zz}',(xx,-53.805,zz),(xx+.035,-52.32,zz+.07),identity,'wood_dark',.002)
   for j in range(3):
    ya=-53.78+j*.473
    box(identity+f'_Panel{xx}_{j}',(xx+.006,ya,.185),(xx+.029,ya+.446,1.105),identity,'wood_dark',.003)
  for yy in [-54.82,-52.345]:box(identity+'_End'+str(yy),(20.984,yy,.14),(21.635,yy+.026,1.145),identity,'wood_dark',.002)
  gx=21.608;wy0=-53.65;wy1=-52.98;wz0=1.22;wz1=1.68
  for yy in [-54.79,-52.345]:rod(identity+'_GrillePost'+str(yy),(gx,yy,1.16),(gx,yy,2.13),.013,identity,'brass_dull',24)
  for zz in [1.192,2.115]:rod(identity+'_GrilleRail'+str(zz),(gx,-54.79,zz),(gx,-52.345,zz),.013,identity,'brass_dull',24)
  for j in range(31):
   yy=-54.77+j*.080
   intervals=[(1.19,2.12)] if not wy0<yy<wy1 else [(1.19,wz0),(wz1,2.12)]
   for lo,hi in intervals:rod(identity+f'_Vertical{j}_{lo}',(gx,yy,lo),(gx,yy,hi),.0038,identity,'brass_dull',12)
  for j in range(11):
   zz=1.205+j*.086
   intervals=[(-54.79,-52.345)] if not wz0<zz<wz1 else [(-54.79,wy0),(wy1,-52.345)]
   for lo,hi in intervals:rod(identity+f'_Horizontal{j}_{lo}',(gx,lo,zz),(gx,hi,zz),.0038,identity,'brass_dull',12)
  for yy in [wy0,wy1]:rod(identity+'_WicketJamb'+str(yy),(gx,yy,wz0),(gx,yy,wz1),.011,identity,'brass_dull',24)
  for zz in [wz0,wz1]:rod(identity+'_WicketRail'+str(zz),(gx,wy0,zz),(gx,wy1,zz),.011,identity,'brass_dull',24)
  box(identity+'_WicketSill',(21.51,wy0-.02,1.19),(21.73,wy1+.02,1.222),identity,'brass_dull',.002)
  continue
 if kind=='safe':
  x0,y0,x1,y1=20.90,-54.72,21.68,-53.88
  for xx in [x0+.065,x1-.055]:
   for yy in [y0+.055,y1-.055]:
    box(identity+f'_Foot{xx}_{yy}',(xx-.036,yy-.036,ground),(xx+.036,yy+.036,.10),identity,'cast_iron',.004)
    bearing(identity,floor['id'],(xx,yy,ground),label='safe foot in open counter bay')
  box(identity+'_Back',(x1-.026,y0,.085),(x1,y1,1.125),identity,'cast_iron',.003)
  for yy in [y0,y1-.026]:box(identity+'_Side'+str(yy),(x0+.03,yy,.085),(x1,yy+.026,1.125),identity,'cast_iron',.003)
  for zz in [.085,1.105]:box(identity+'_Cap'+str(zz),(x0+.03,y0,zz),(x1,y1,zz+.025),identity,'cast_iron',.003)
  box(identity+'_ClosedDoor',(x0+.016,y0+.024,.11),(x0+.065,y1-.024,1.108),identity,'cast_iron',.006)
  for yy in [y0+.04,y1-.069]:box(identity+'_RaisedStile'+str(yy),(x0+.006,yy,.145),(x0+.022,yy+.029,1.073),identity,'iron_blackened',.002)
  for zz in [.145,1.044]:box(identity+'_RaisedRail'+str(zz),(x0+.006,y0+.04,zz),(x0+.022,y1-.04,zz+.029),identity,'iron_blackened',.002)
  for zz in [.31,.89]:rod(identity+'_Hinge'+str(zz),(x0+.04,y0+.019,zz-.065),(x0+.04,y0+.019,zz+.065),.022,identity,'cast_iron',24)
  cy=(y0+y1)/2
  along_x(identity+'_Dial',x0+.016,cy,.82,[(0,-.022),(.053,-.022),(.057,-.010),(.057,.004),(0,.004)],identity,'brass_dull')
  for j in range(24):
   a=j*math.tau/24
   rod(identity+'_DialMark'+str(j),(x0-.008,cy+.043*math.sin(a),.82+.043*math.cos(a)),(x0-.004,cy+.043*math.sin(a),.82+.043*math.cos(a)),.0016,identity,'iron_blackened',8)
  for yy in [cy-.09,cy+.09]:rod(identity+'_HandleStud'+str(yy),(x0-.041,yy,.59),(x0+.022,yy,.59),.012,identity,'brass_dull',24)
  rod(identity+'_Handle',(x0-.041,cy-.105,.59),(x0-.041,cy+.105,.59),.014,identity,'brass_dull',24)
  # Dossier slice 62 (CITY_SHOP_PAWNBROKER-003): the painted name panel above the dial, left blank (no
  # lettering), an enamelled field inside a gold line.
  box(identity+'_NamePanel',(x0+.0145,cy-.18,.90),(x0+.0165,cy+.18,1.0),identity,'enamel',.0006)
  for zz in [.903,.994]:box(identity+'_PanelLine'+str(zz),(x0+.0135,cy-.17,zz),(x0+.0147,cy+.17,zz+.003),identity,'brass_dull',0)
  for yy in [cy-.173,cy+.17]:box(identity+'_PanelLineV'+str(yy),(x0+.0135,yy,.903),(x0+.0147,yy+.003,.997),identity,'brass_dull',0)
  bearing(identity,'storm_shop_pawnbroker_grille_counter',(21.25,-54.30,1.13),(0,0,-1),'safe cap beneath counter worktop',True)
  continue
 if kind=='violin':
  cx=22.375;cy=-54.68;z=ground+.03
  outline=[(cy-.12,z),(cy+.12,z),(cy+.158,z+.18),(cy+.145,z+.30),(cy+.095,z+.39),(cy+.116,z+.52),(cy+.088,z+.75),(cy-.088,z+.75),(cy-.116,z+.52),(cy-.095,z+.39),(cy-.145,z+.30),(cy-.158,z+.18)]
  box(identity+'_Cradle',(22.28,cy-.14,ground),(22.455,cy+.14,z+.018),identity,'wood_dark',.004)
  bearing(identity,floor['id'],(cx,cy,ground),label='upright case cradle on floor')
  slab_outline(identity+'_Case',outline,cx-.06,cx+.065,identity,'wood_dark')
  slab_outline(identity+'_Lid',[(y,zz+.002) for y,zz in outline],cx-.069,cx-.058,identity,'bakelite_black')
  for zz in [z+.19,z+.53]:box(identity+'_Latch'+str(zz),(cx-.073,cy-.13,zz),(cx-.047,cy-.085,zz+.032),identity,'brass_dull',.002)
  curved_wire(identity+'_Handle',[(cx-.065,cy+.105,z+.27),(cx-.10,cy+.12,z+.29),(cx-.10,cy+.12,z+.42),(cx-.065,cy+.105,z+.44)],.009,identity,'bakelite_black')
  continue
 if kind=='sewing':
  x0,y0,x1,y1=22.30,-54.29,22.84,-53.65;z=2.38
  box(identity+'_Base',(x0,y0,z),(x1,y1,z+.04),identity,'wood_dark',.004)
  bearing(identity,'storm_shop_pawnbroker_pledge_shelf0',((x0+x1)/2,(y0+y1)/2,z),label='machine bed on bracketed upper deck',native=True)
  box(identity+'_Bed',(x0+.025,y0+.025,z+.038),(x1-.025,y1-.025,z+.065),identity,'enamel',.007)
  # Broad arch in the Y/Z plane, assembled from solid cast members.
  outline=[(y0+.06,z+.06),(y0+.19,z+.06),(y0+.205,z+.10),(y0+.21,z+.29),(y0+.23,z+.34),(y0+.27,z+.365),(y1-.16,z+.365),(y1-.13,z+.34),(y1-.13,z+.265),(y1-.063,z+.265),(y1-.055,z+.34),(y1-.060,z+.39),(y1-.08,z+.42),(y1-.14,z+.445),(y0+.15,z+.45),(y0+.09,z+.43),(y0+.06,z+.38),(y0+.07,z+.13)]
  slab_outline(identity+'_CastHead',outline,22.49,22.61,identity,'enamel')
  box(identity+'_NeedlePlate',(22.488,y1-.16,z+.064),(22.572,y1-.045,z+.071),identity,'brass_dull',.001)
  along_x(identity+'_TensionKnob',22.49,y0+.17,z+.27,[(0,-.022),(.022,-.022),(.022,.004),(0,.004)],identity,'brass_dull')
  rod(identity+'_Needle',(22.53,y1-.10,z+.07),(22.53,y1-.10,z+.34),.003,identity,'brass_dull',16)
  rod(identity+'_SpoolPin',(22.55,y0+.17,z+.435),(22.55,y0+.17,z+.51),.006,identity,'brass_dull',16)
  rod(identity+'_Spool',(22.55,y0+.17,z+.455),(22.55,y0+.17,z+.50),.025,identity,'linen',32)
  axial(identity+'_Flywheel',22.55,z+.29,[(.098,y0+.04),(.113,y0+.04),(.113,y0+.059),(.098,y0+.059),(.098,y0+.04)],identity,'iron_blackened',48)
  rod(identity+'_WheelAxle',(22.55,y0+.045,z+.29),(22.55,y0+.15,z+.29),.02,identity,'iron_blackened',24)
  for j in range(5):
   a=j*math.tau/5
   rod(identity+'_Spoke'+str(j),(22.55,y0+.05,z+.29),(22.55+.105*math.cos(a),y0+.05,z+.29+.105*math.sin(a)),.006,identity,'iron_blackened',12)
  continue
 if kind=='coat':
  cx=22.66;cy=-55.26
  coat_start=len(pieces[identity])
  # Closed 3mm cloth shells retain an open hem, neck and sleeve cuffs.
  def cloth_shell(name,levels):
   n=48;verts=[]
   for inside in [False,True]:
    for zz,xx,yy,rx,ry in levels:
     for j in range(n):
      angle=j*math.tau/n;fold=.003*math.cos(j*math.tau/8)*(.35+.65*(2.44-zz))
      verts.append((xx+(rx-(.003 if inside else 0)+fold)*math.cos(angle),yy+(ry-(.003 if inside else 0)+fold*.55)*math.sin(angle),zz))
   layer=len(levels)*n;faces=[]
   for side in range(2):
    for k in range(len(levels)-1):
     for j in range(n):
      q=[side*layer+k*n+j,side*layer+k*n+(j+1)%n,side*layer+(k+1)*n+(j+1)%n,side*layer+(k+1)*n+j];faces.append(tuple(q if side==0 else q[::-1]))
   for k in [0,len(levels)-1]:
    for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,layer+k*n+(j+1)%n,layer+k*n+j))
   return solid(name,verts,faces,identity,'fabric_warm')
  cloth_shell(identity+'_Coat',[(1.43,cx,cy,.155,.064),(1.68,cx,cy,.148,.060),(1.95,cx,cy,.135,.056),(2.16,cx,cy,.134,.055),(2.31,cx,cy,.166,.055),(2.39,cx,cy,.13,.049),(2.435,cx,cy,.065,.043)])
  for sign in [-1,1]:
   cloth_shell(identity+'_Sleeve'+str(sign),[(1.72,cx+sign*.16,cy-.015,.036,.033),(1.92,cx+sign*.17,cy-.008,.039,.036),(2.15,cx+sign*.155,cy,.043,.041),(2.33,cx+sign*.145,cy,.046,.044)])
   outline=[(cx+sign*.035,2.43),(cx+sign*.102,2.35),(cx+sign*.040,2.17),(cx+sign*.004,2.28)]
   slab_outline(identity+'_Lapel'+str(sign),outline,cy-.057,cy-.049,identity,'fabric_warm','y')
  for zz,ry in [(1.73,.059),(1.91,.057),(2.10,.055)]:rod(identity+'_Button'+str(zz),(cx+.022,cy-ry-.008,zz),(cx+.022,cy-ry+.006,zz),.009,identity,'bakelite_black',16)
  curved_wire(identity+'_Hanger',[(cx-.17,cy,2.35),(cx,cy,2.46),(cx+.17,cy,2.35),(cx-.17,cy,2.35)],.009,identity,'timber')
  curved_wire(identity+'_Hook',[(cx,cy,2.46),(cx,cy,2.51),(cx,cy+.014,2.535),(cx,cy+.03,2.528),(cx,cy+.03,2.503)],.004,identity,'brass_dull')
  # Face the open operator aisle; leave the rack anchor at its real post.
  for obj,key in pieces[identity][coat_start:]:
   offset=tuple(float(v) for v in obj.location)
   for v in obj.data.vertices:
    v.co=Vector((v.co.y,-v.co.x*.85,v.co.z))
   obj.location=Vector((cx+offset[1]-cy,cy-(offset[0]-cx)*.85,offset[2]))
  rod(identity+'_RackPeg',(22.836,-55.05,2.52),(cx+.026,cy,2.52),.012,identity,'iron_blackened',24)
  bearing(identity,'storm_shop_pawnbroker_pledge_shelf0',(22.836,-55.05,2.52),(0,-1,0),'hanger peg in rack post',True)
  continue
 if kind=='balance':
  cx=21.23;cy=-52.87;z=1.18
  box(identity+'_Base',(cx-.247,cy-.455,z),(cx+.247,cy+.455,z+.035),identity,'brass_dull',.007)
  bearing(identity,'storm_shop_pawnbroker_grille_counter',(cx,cy,z),label='balance on worktop',native=True)
  rod(identity+'_Stem',(cx,cy,z+.025),(cx,cy,1.585),.016,identity,'brass_dull',32)
  rod(identity+'_Beam',(cx,cy-.39,1.57),(cx,cy+.39,1.57),.012,identity,'brass_dull',24)
  rod(identity+'_Pivot',(cx-.024,cy,1.57),(cx+.024,cy,1.57),.025,identity,'brass_dull',32)
  for sign in [-1,1]:
   yy=cy+sign*.32
   vessel(identity+'_Pan'+str(sign),cx,yy,1.34,[(0,0),(.10,0),(.118,.025),(.114,.030),(.095,.006),(0,.006)],identity,'brass_dull')
   for j in range(3):
    a=j*math.tau/3
    rod(identity+f'_Suspension{sign}_{j}',(cx,yy,1.575),(cx+.112*math.cos(a),yy+.112*math.sin(a),1.365),.0018,identity,'brass_dull',8)
  # 4mm closed bell shell, continuous outer and inner surfaces, open at the base.
  profile=[(.242,0),(.242,.31)]
  profile.extend((.242*math.cos(i*math.pi/24),.31+.302*math.sin(i*math.pi/24)) if i<12 else (0,.612) for i in range(1,13))
  profile.append((0,.608))
  profile.extend((.238*math.cos(i*math.pi/24),.31+.298*math.sin(i*math.pi/24)) for i in range(11,-1,-1))
  profile.extend([(.238,0),(.242,0)])
  obj=vessel(identity+'_GlassBell',cx,cy,z+.035,profile,identity,'glassish')
  for v in obj.data.vertices:
   p=v.co+obj.location;v.co.y=(p.y-cy)*1.85+cy-obj.location.y
  continue
 if kind=='ledger':
  x0,y0,x1,y1=21.025,-53.92,21.465,-53.48;z=1.18
  box(identity+'_LowerCover',(x0,y0,z),(x1,y1,z+.007),identity,'wood_dark',.002)
  box(identity+'_PaperBlock',(x0+.012,y0+.010,z+.006),(x1-.010,y1-.01,z+.049),identity,'paper',.001)
  box(identity+'_UpperCover',(x0,y0,z+.048),(x1,y1,z+.055),identity,'wood_dark',.002)
  box(identity+'_BoundSpine',(x1-.017,y0,z+.004),(x1+.001,y1,z+.053),identity,'fabric_warm',.002)
  for zz in [.016,.025,.034,.043]:box(identity+'_PageEdge'+str(zz),(x0+.009,y0+.01,z+zz),(x0+.013,y1-.01,z+zz+.001),identity,'linen',0)
  rod(identity+'_Pen',(x0+.055,y0+.045,z+.058),(x0+.075,y1-.055,z+.058),.004,identity,'bakelite_black',16)
  bearing(identity,'storm_shop_pawnbroker_grille_counter',((x0+x1)/2,(y0+y1)/2,z),label='ledger lower cover on worktop',native=True)
  continue
 if kind=='loupe':
  cx=21.15;cy=-54.12;z=1.18
  vessel(identity+'_Cup',cx,cy,z,[(.029,0),(.039,.015),(.030,.058),(.024,.062),(.019,.056),(.024,.016),(.022,0),(.029,0)],identity,'bakelite_black')
  vessel(identity+'_Lens',cx,cy,z+.053,[(0,0),(.022,0),(.022,.004),(0,.004)],identity,'glassish')
  path=[(cx+.030,cy,z+.021),(cx+.058,cy-.025,z+.002)]
  path.extend((cx+.09+.048*math.sin(i*math.tau/30),cy-.092+.04*math.cos(i*math.tau/30),z+.002) for i in range(32))
  curved_wire(identity+'_Cord',path,.002,identity,'linen')
  bearing(identity,'storm_shop_pawnbroker_grille_counter',(cx+.025,cy,z),label='loupe rim on worktop',native=True)
