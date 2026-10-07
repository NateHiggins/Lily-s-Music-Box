"""Twelve assemblies, built from their immutable door/knob/window source records."""
def bearing(identity, owner, point, direction=(0,0,1), label='seated bearing'):
 support(identity,owner,point,direction,label);contacts[-1]['native_owner']=False

for item in assemblies:
 row=item['body'];identity=item['id'];kind=item['kind'];floor=item['floor'];ground=floor['z0']+floor['h']
 if kind=='closed_door':
  x0,y0,x1,y1=row['rect'];top=row['z0']+row['h'];width=x1-x0
  direction=1 if (y0+y1)<(floor['rect'][1]+floor['rect'][3]) else -1
  wall=next(rows['storm_'+row['batch']+'_'+suffix] for suffix in ['dw','de'] if abs(sum(rows['storm_'+row['batch']+'_'+suffix]['rect'][i] for i in [1,3])*.5-(y0+y1)*.5)<.10)
  face=wall['rect'][3] if direction==1 else wall['rect'][1]
  def blank(label,u0,u1,z0,z1,d0,d1,key='wood_dark',bevel=.0015):
   a=face+direction*d0;b=face+direction*d1
   return box(identity+'_'+label,(u0,min(a,b),z0),(u1,max(a,b),z1),identity,key,bevel)
  # Floor bearing and a flush rear face seat the case in front of the retained wall.
  for u,label in [(x0,'LeftJamb'),(x1-.045,'RightJamb')]:
   blank(label,u,u+.045,ground,top,0,.055)
   bearing(identity,floor['id'],(u+.0225,face+direction*.0275,ground),label='jamb on retained shop floor')
   bearing(identity,wall['id'],(u+.0225,face,.50),(0,direction,0),'case back on retained wainscot')
  blank('Head',x0+.040,x1-.040,top-.045,top,0,.055)
  blank('Threshold',x0+.040,x1-.040,ground,row['z0'],0,.052)
  # Six recessed fields fit between real stiles and rails. The leaf remains closed.
  left=x0+.049;right=x1-.049;bottom=row['z0']+.003;upper=top-.049
  stile=.063;mid=(left+right)*.5
  for u,label in [(left,'HingeStile'),(right-stile,'LatchStile')]:blank(label,u,u+stile,bottom,upper,.011,.043)
  blank('MiddleStile',mid-.023,mid+.023,bottom,upper,.011,.043)
  knob=item['members'][1];q=knob['rect'];kx=(q[0]+q[2])*.5;kz=knob['z0']+knob['h']*.5
  heights=[bottom,bottom+.46,kz-.0325,upper-.065]
  for j,z in enumerate(heights):
   # Split rails at the continuous centre stile; no coplanar overlapping faces.
   for half,(a,b) in enumerate([(left+stile,mid-.023),(mid+.023,right-stile)]):blank(f'Rail{j}_{half}',a,b,z,min(upper,z+.065),.011,.043)
  for column,(a,b) in enumerate([(left+.058,mid-.020),(mid+.020,right-.058)]):
   for j in range(3):
    z0=heights[j]+.060;z1=heights[j+1]+.005
    blank(f'Field{column}_{j}',a,b,z0,z1,.018,.032,bevel=.003)
    # Narrow beads cover the panel/stile rebate without filling the recessed face.
    blank(f'BeadL{column}_{j}',a-.001,a+.008,z0,z1,.030,.038,bevel=.001)
    blank(f'BeadR{column}_{j}',b-.008,b+.001,z0,z1,.030,.038,bevel=.001)
    blank(f'BeadB{column}_{j}',a,b,z0-.002,z0+.007,.030,.038,bevel=.001)
    blank(f'BeadT{column}_{j}',a,b,z1-.007,z1+.002,.030,.038,bevel=.001)
  knob=item['members'][1];q=knob['rect'];kx=(q[0]+q[2])*.5;kz=knob['z0']+knob['h']*.5
  hinge=right+.002 if kx<mid else left-.002
  for j,z in enumerate([bottom+.19,upper-.22]):
   blank('HingePlate'+str(j),hinge-.018,hinge+.018,z-.038,z+.038,.041,.045,'iron_blackened',.0005)
   rod(identity+'_HingeBarrel'+str(j),(hinge,face+direction*.048,z-.043),(hinge,face+direction*.048,z+.043),.006,identity,'iron_blackened',32)
  # Closed lathed brass rose, neck and oval knob; source knob centre stays fixed.
  profile=[(0,.042),(.026,.042),(.029,.044),(.027,.047),(.011,.049),(.010,.060),(.019,.064),(.026,.071),(.028,.082),(.021,.093),(.009,.100),(0,.102)]
  axial(identity+'_TurnedKnob',kx,kz,[(radius,face+direction*depth) for radius,depth in profile],identity,'brass_dull',64)
  for z in [kz-.021,kz+.021]:
   axial(identity+'_RoseScrew'+str(z),kx,z,[(0,face+direction*.046),(.003,face+direction*.046),(.003,face+direction*.049),(0,face+direction*.050)],identity,'brass_dull',24)
  continue
 if kind=='window':
  x0,y0,x1,y1=row['rect'];top=row['z0']+row['h']
  for xx in [x0+.025,x1-.025]:
   for yy in [y0+.030,(y0+y1)/2,y1-.030]:
    box(identity+f'_Foot{xx}_{yy}',(xx-.022,yy-.022,ground),(xx+.022,yy+.022,top-.023),identity,'wood_dark',.002)
    bearing(identity,floor['id'],(xx,yy,ground),label='empty window stand foot on retained floor')
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
