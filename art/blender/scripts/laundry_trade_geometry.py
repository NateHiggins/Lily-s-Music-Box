"""Seven source-owned Laundry assemblies; executed by the fabrication kernel."""
def bearing(identity,owner,point,direction=(0,0,1),label='seated bearing',native=False):
 support(identity,owner,point,direction,label);contacts[-1]['native_owner']=native

for item in assemblies:
 row=item['body'];identity=item['id'];kind=item['kind'];ground=floor['z0']+floor['h']
 if kind=='rack':
  x0,y0,x1,y1=row['rect'];ys=[y0+.035,(y0+y1)/2,y1-.035]
  for xx in [x0+.020,x1]:
   for yy in ys:
    box(identity+f'_Post{xx}_{yy}',(xx-.018,yy-.018,ground),(xx+.018,yy+.018,2.64),identity,'timber',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='rack post on retained floor')
  for source in item['members']:
   q=source['rect'];z=source['z0']
   box(source['id']+'_Deck',(q[0],q[1],z),(q[2],q[3],z+source['h']),identity,'timber',.002)
   for yy in ys:box(source['id']+'_Bearer'+str(yy),(x0+.003,yy-.025,z-.038),(x1+.015,yy+.025,z+.004),identity,'timber',.002)
  for xx in [x0+.02,x1]:box(identity+'_Crown'+str(xx),(xx-.018,y0,2.60),(xx+.018,y1,2.64),identity,'timber',.002)
  continue
 if kind=='tickets':
  cx=4.50;z=2.5375;ya=-44.45;yb=-39.55
  for yy in [-44.445,-42.0,-39.555]:
   box(identity+'_PostPlate'+str(yy),(4.438,yy-.020,2.505),(4.453,yy+.020,2.57),identity,'iron_blackened',.001)
   rod(identity+'_StandOff'+str(yy),(4.443,yy,z),(cx,yy,z),.009,identity,'iron_blackened',16)
   bearing(identity,'storm_shop_model_laundry_parcel_shelf0',(4.438,yy,2.560),(1,0,0),'ticket bracket on rack post',True)
  rod(identity+'_Wire',(cx,ya,z),(cx,yb,z),.003,identity,'iron_blackened',16)
  for i,source in enumerate(item['members'][1:]):
   q=source['rect'];bottom=source['z0'];top=bottom+source['h'];yc=(q[1]+q[3])*.5
   # A shallow crease and torn lower edge give the original blank paper thickness.
   outline=[(q[1],top),(q[3],top),(q[3],bottom+.008),(yc+.027,bottom+.003),(yc+.012,bottom+.010),(yc-.008,bottom),(q[1],bottom+.006)]
   n=len(outline);verts=[(xx,yy,zz) for xx in [4.513,4.5145] for yy,zz in outline]
   solid(source['id']+'_Paper',verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],identity,'paper')
   curved_wire(source['id']+'_Tie',[(cx,yc,z+.005),(cx-.004,yc,z),(cx+.014,yc,top-.020),(cx+.018,yc,top-.024),(cx+.014,yc,top-.026),(cx+.005,yc,z-.004),(cx,yc,z+.005)],.0012,identity,'linen')
  continue
 if kind=='window':
  q=row['rect'];top=row['z0']+row['h'];x0,y0,x1,y1=q
  for xx in [x0+.025,x1-.025]:
   for yy in [y0+.028,(y0+y1)/2,y1-.028]:
    box(identity+f'_Leg{xx}_{yy}',(xx-.022,yy-.022,ground),(xx+.022,yy+.022,top-.022),identity,'wood_dark',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='window stand foot on retained floor')
  box(identity+'_Deck',(x0,y0,top-.03),(x1,y1,top),identity,'wood_dark',.003)
  for xx in [x0+.002,x1-.027]:
   box(identity+'_LowerRail'+str(xx),(xx,y0,.06),(xx+.025,y1,.115),identity,'wood_dark',.002)
   for j in range(5):
    a=y0+j*(y1-y0)/5
    box(identity+f'_InsetPanel{xx}_{j}',(xx+.004,a+.014,.11),(xx+.021,a+(y1-y0)/5-.014,top-.022),identity,'wood_dark',.002)
  back=item['members'][1];q=back['rect'];z=back['z0'];high=z+back['h']
  box(identity+'_PlywoodBack',(q[0],q[1],z),(q[2],q[3],high),identity,'plywood',.002)
  for yy in [q[1],q[3]-.026]:box(identity+'_BackStile'+str(yy),(q[0]-.001,yy,z),(q[2]+.007,yy+.026,high+.009),identity,'wood_dark',.002)
  box(identity+'_BackCap',(q[0]-.004,q[1],high-.007),(q[2]+.01,q[3],high+.02),identity,'wood_dark',.003)
  continue
 if kind=='counter':
  # Eight millimetres clear of retained north wainscot; source outline stays in the comparison collection.
  x0,y0,x1,y1=9.70,-43.10,10.32,-39.36;flap_end=-42.47
  for xx in [x0+.030,x1-.030]:
   for yy in [y0+.032,flap_end+.032,-40.90,y1-.032]:
    box(identity+f'_Post{xx}_{yy}',(xx-.025,yy-.025,ground),(xx+.025,yy+.025,1.01),identity,'wood_dark',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='counter foot on retained floor')
  for xx in [x0+.009,x1-.035]:
   for zz in [.12,.935]:box(identity+f'_Rail{xx}_{zz}',(xx,flap_end,zz),(xx+.027,y1,zz+.066),identity,'wood_dark',.002)
   for j in range(5):
    a=flap_end+j*(y1-flap_end)/5
    box(identity+f'_Panel{xx}_{j}',(xx+.005,a+.021,.17),(xx+.022,a+(y1-flap_end)/5-.021,.975),identity,'wood_dark',.002)
  for yy in [y0+.010,y1-.025]:box(identity+'_EndRail'+str(yy),(x0,yy,.90),(x1,yy+.025,1.01),identity,'wood_dark',.002)
  box(identity+'_Worktop',(9.66,flap_end+.003,1.00),(10.36,-39.358,1.05),identity,'countertop',.003)
  box(identity+'_ClosedFlap',(9.66,-43.14,1.00),(10.36,flap_end-.003,1.05),identity,'countertop',.003)
  for xx in [9.76,10.20]:
   box(identity+'_HingePlate'+str(xx),(xx-.022,flap_end-.047,1.049),(xx+.022,flap_end+.047,1.052),identity,'brass_dull',.0005)
   rod(identity+'_HingeBarrel'+str(xx),(xx-.030,flap_end,1.055),(xx+.030,flap_end,1.055),.006,identity,'brass_dull',20)
  continue
 if kind=='bench':
  x0,y0,x1,y1=row['rect'];top=row['z0']+row['h']
  for xx in [x0+.065,x1-.065]:
   for yy in [y0+.045,y1-.045]:
    box(identity+f'_Leg{xx}_{yy}',(xx-.025,yy-.025,ground),(xx+.025,yy+.025,top-.025),identity,'timber',.003)
    bearing(identity,floor['id'],(xx,yy,ground),label='bench foot on retained floor')
   box(identity+'_CrossBearer'+str(xx),(xx-.032,y0+.025,top-.065),(xx+.032,y1-.025,top-.025),identity,'timber',.002)
  for yy in [y0+.024,y1-.049]:box(identity+'_Apron'+str(yy),(x0+.040,yy,top-.10),(x1-.040,yy+.025,top-.025),identity,'timber',.002)
  for j in range(3):
   a=y0+j*(y1-y0)/3
   box(identity+'_SeatBoard'+str(j),(x0,a+.0015,top-.031),(x1,a+(y1-y0)/3-.0015,top),identity,'timber',.005)
  continue
 if kind=='ledger':
  q=row['rect'];x0,y0,x1,y1=q;z=1.05
  box(identity+'_LowerCover',(x0,y0,z),(x1,y1,z+.006),identity,'wood_dark',.002)
  box(identity+'_Pages',(x0+.006,y0+.005,z+.006),(x1-.007,y1-.005,z+.045),identity,'paper',.001)
  box(identity+'_TopCover',(x0,y0,z+.045),(x1,y1,z+.052),identity,'wood_dark',.002)
  box(identity+'_Spine',(x0,y0,z+.004),(x0+.012,y1,z+.05),identity,'wood_dark',.002)
  bearing(identity,'storm_shop_model_laundry_counter',((x0+x1)/2,(y0+y1)/2,z),label='ledger on counter',native=True)
  continue
 if kind=='pencil':
  # The loose pencil has its own support and never gains an invented join to the ledger.
  cy=-42.22;cz=1.05+.0048*math.sqrt(3)/2
  rod(identity+'_Pencil',(9.85,cy,cz),(10.10,cy,cz),.0048,identity,'timber',6)
  verts=[(10.10,cy+.0048*math.cos(j*math.tau/6),cz+.0048*math.sin(j*math.tau/6)) for j in range(6)]+[(10.12,cy,cz)]
  solid(identity+'_SharpenedPoint',verts,[tuple(reversed(range(6)))]+[(j,(j+1)%6,6) for j in range(6)],identity,'iron_blackened')
  bearing(identity,'storm_shop_model_laundry_counter',(9.92,cy,1.05),label='pencil on counter',native=True)
  continue
