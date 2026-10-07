"""Closed double-curtain entrance, wall-mounted controlled lamp and supported display."""
def bearing(identity,owner,point,direction=(0,0,1),native=False,label='seated bearing'):
 support(identity,owner,point,direction,label);contacts[-1]['native_owner']=native

def turned_x(name,cy,cz,profile,identity,key,closed=False):
 obj=axial(name,0,0,profile+profile[:1] if closed else profile,identity,key,64)
 for v in obj.data.vertices:
  p=v.co+obj.location;v.co=Vector((p.y,p.x,p.z))
 obj.location=Vector((0,cy,cz))
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 return obj

for item in assemblies:
 row=item['body'];identity=item['id'];kind=item['kind'];floor=item['floor'];ground=floor['z0']+floor['h']
 x0,y0,x1,y1=row['rect'];top=row['z0']+row['h']
 if kind=='darkroom':
  wall=rows['storm_shop_photo_supplies_back_lo'];face=wall['rect'][0]
  wainscot=rows['storm_shop_photo_supplies_db'];low_face=wainscot['rect'][0];dado=wainscot['z0']+wainscot['h'];x0=low_face-.070
  wall_owner='storm_shop_photo_supplies_borrowed_sill'
  for yy,label in [(y0,'NearJamb'),(y1-.045,'FarJamb')]:
   box(identity+'_'+label+'Lower',(x0,yy,ground),(low_face,yy+.045,dado),identity,'wood_dark',.002)
   box(identity+'_'+label+'Upper',(x0,yy,dado),(face,yy+.045,top),identity,'wood_dark',.002)
   bearing(identity,floor['id'],((x0+low_face)/2,yy+.0225,ground),label='door case on retained shop floor')
   bearing(identity,wainscot['id'],(low_face,yy+.0225,.75),(-1,0,0),False,'lower case on retained wainscot')
   bearing(identity,wainscot['id'],((low_face+face)/2,yy+.0225,dado),(0,0,1),False,'case rebate on retained dado top')
   bearing(identity,wall_owner,(face,yy+.0225,1.5),(-1,0,0),True,'upper case on fitted rear plaster')
  box(identity+'_Head',(x0,y0+.041,top-.065),(face,y1-.041,top),identity,'wood_dark',.002)
  box(identity+'_Threshold',(x0,y0+.041,ground),(low_face,y1-.041,row['z0']),identity,'wood_dark',.002)
  # Two opaque leaves stagger in depth and overlap in the middle. Their upper
  # hems terminate in the header; the closed original wall remains behind them.
  mid=(y0+y1)/2
  for number,(a,b,depth,amplitude) in enumerate([(y0+.035,mid+.045,22.844,.008),(mid-.045,y1-.035,22.872,.004)]):
   steps=80;verts=[];z0=row['z0']+.002;z1=top-.060
   for z in [z0,z1]:
    for side in [-.0012,.0012]:
     for j in range(steps+1):
      yy=a+(b-a)*j/steps;xx=depth+amplitude*math.cos(j/steps*math.tau*7)
      verts.append((xx+side,yy,z))
   n=steps+1;faces=[]
   for j in range(steps):
    faces.extend([(j,j+1,2*n+j+1,2*n+j),(n+j,3*n+j,3*n+j+1,n+j+1),
                  (j,n+j,n+j+1,j+1),(2*n+j,2*n+j+1,3*n+j+1,3*n+j)])
   faces.extend([(0,2*n,3*n,n),(steps,n+steps,3*n+steps,2*n+steps)])
   solid(identity+'_LightTrapCurtain'+str(number),verts,faces,identity,'fabric_warm')
  # Small fixed finger plate makes the closed entrance readable without adding
  # a lock, an interactive handle or a new route.
  box(identity+'_FingerPlate',(x0-.003,y1-.044,.96),(x0+.001,y1-.013,1.16),identity,'iron_blackened',.001)
  continue
 if kind=='controlled_lamp':
  cy=(y0+y1)/2;cz=(row['z0']+top)/2;wall=rows['storm_shop_photo_supplies_back_lo']['rect'][0]
  box(identity+'_WallBracket',(22.876,cy-.038,2.19),(wall,cy+.038,2.285),identity,'iron_blackened',.001)
  bearing(identity,'storm_shop_photo_supplies_borrowed_sill',(wall,cy,2.23),(-1,0,0),True,'lamp bracket on fitted plaster below clerestory sill')
  box(identity+'_CaseBack',(22.88,y0,row['z0']),(22.888,y1,top),identity,'iron_blackened',.001)
  for yy in [y0,y1-.009]:box(identity+'_CaseSide'+str(yy),(22.80,yy,row['z0']),(22.883,yy+.009,top),identity,'iron_blackened',.001)
  for zz in [row['z0'],top-.009]:box(identity+'_CaseCap'+str(zz),(22.80,y0+.006,zz),(22.883,y1-.006,zz+.009),identity,'iron_blackened',.001)
  # A real annular bezel surrounds a shallow solid red opal diffuser.
  turned_x(identity+'_Bezel',cy,cz,[(.061,22.794),(.074,22.794),(.077,22.80),(.077,22.809),(.061,22.809)],identity,'iron_blackened',True)
  turned_x(identity+'_RedDiffuser',cy,cz,[(0,22.778),(.025,22.779),(.048,22.784),(.062,22.792),(.065,22.799),(.065,22.807),(0,22.807)],identity,'milk_glass')
  # The bezel is carried by two radial webs; the lens chamber stays hollow.
  for yy in [y0+.006,cy+.073]:box(identity+'_BezelWeb'+str(yy),(22.80,yy,cz-.015),(22.810,yy+(cy-.073-(y0+.006)),cz+.015),identity,'iron_blackened',.001)
  for yy in [y0+.020,y1-.020]:
   for zz in [row['z0']+.02,top-.02]:
    box(identity+'_CornerEar'+str((yy,zz)),(22.80,yy-.016,zz-.016),(22.811,yy+.016,zz+.016),identity,'iron_blackened',.001)
    turned_x(identity+'_CaseScrew'+str((yy,zz)),yy,zz,[(0,22.798),(.0035,22.798),(.0035,22.805),(0,22.807)],identity,'iron_blackened')
  continue
 if kind=='window':
  for xx in [x0+.025,x1-.025]:
   for yy in [y0+.030,(y0+y1)/2,y1-.030]:
    box(identity+f'_Foot{xx}_{yy}',(xx-.022,yy-.022,ground),(xx+.022,yy+.022,top-.023),identity,'wood_dark',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='Radio window stand foot on retained floor')
  box(identity+'_Deck',(x0,y0,top-.030),(x1,y1,top),identity,'wood_dark',.003)
  for xx in [x0+.002,x1-.027]:
   box(identity+'_LowerRail'+str(xx),(xx,y0,.06),(xx+.025,y1,.115),identity,'wood_dark',.002)
   for j in range(5):
    a=y0+j*(y1-y0)/5
    box(identity+f'_Panel{xx}_{j}',(xx+.004,a+.012,.11),(xx+.021,a+(y1-y0)/5-.012,top-.024),identity,'wood_dark',.002)
  back=item['members'][1];q=back['rect'];z=back['z0'];high=z+back['h']
  box(identity+'_Back',(q[0],q[1],z),(q[2],q[3],high),identity,'plywood',.002)
  for yy in [q[1],q[3]-.026]:box(identity+'_BackStile'+str(yy),(q[0]-.001,yy,z),(q[2]+.007,yy+.026,high+.009),identity,'wood_dark',.002)
  box(identity+'_BackCap',(q[0]-.004,q[1],high-.007),(q[2]+.010,q[3],high+.020),identity,'wood_dark',.003)
