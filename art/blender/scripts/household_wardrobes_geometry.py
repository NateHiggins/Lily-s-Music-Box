"""Fitted timber cases, rebated original hinges and source-owned hanging cloth."""
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]

def source_boxes(surface):
 for vertices in np.asarray(surface['vertices'],dtype=float).reshape((-1,36,3)):
  vertices=vertices[:,[0,2,1]];vertices[:,1]*=-1
  yield vertices.min(0),vertices.max(0)

def tag(obj):obj['component']=component;return obj
def stock(label,lo,hi,key,edge=.001):return tag(box(identity+'_'+label,lo,hi,identity,key,edge))

def folded_cloth(label,lo,hi):
 # A closed 1.2mm cloth skin folds over the real hanger crossbar. Top/hem
 # and source colour remain; soft widening folds replace the solid cuboid.
 nx=24;nz=18;cx=(lo[0]+hi[0])/2;half=(hi[0]-lo[0])/2
 half=min(half,abs(cx)-.023) if abs(cx)<.2 else half
 hem=lo[2];top=hi[2];bar=top-.0027
 if bare:
  # Dossier slice 40 (F04_D_BED-001): 4D's wardrobe holds only the wire hangers, emptied for the night.
  hw=half*.94
  tag(curved_wire(identity+'_'+label+'Hanger',[(cx-hw,.02,bar),(cx,.02,1.58),(cx+hw,.02,bar),(cx-hw,.02,bar)],.0015,identity,'metal'))
  path=[(cx,.02,1.58),(cx,.02,1.5965)]
  path.extend((cx,.02+.0135*math.cos(a),1.61+.0135*math.sin(a)) for a in np.linspace(-math.pi/2,math.pi*.90,35))
  tag(curved_wire(identity+'_'+label+'Hook',path,.0015,identity,'metal'))
  return
 # Outer drape runs up the back, over a 2.1mm crown, down the front.
 path=[(-.0027,hem+(bar-hem)*i/nz) for i in range(nz)]
 path.extend((.0027*math.cos(a),bar+.0027*math.sin(a)) for a in np.linspace(math.pi,0,9))
 path.extend((.0027,bar-(bar-hem)*i/nz) for i in range(1,nz+1))
 verts=[];nr=len(path)
 for skin in [0,1]:
  for i in range(nx+1):
   u=-1+2*i/nx;x=cx+half*u
   for j,(y,z) in enumerate(path):
    t=(top-z)/(top-hem);sgn=-1 if j<nr/2 else 1
    fold=(.015*math.sin(u*math.pi*3+.2)+.009*math.sin(u*math.pi*5+1.1))*t
    spread=.019*t+.011*t*t
    yy=.02+sgn*spread+y+fold
    # Inner skin shrinks toward the interior along the profile normal.
    a=Vector(path[max(0,j-1)]);b=Vector(path[min(nr-1,j+1)]);tangent=(b-a).normalized()
    yy+=skin*.0012*tangent.y;zz=z-skin*.0012*tangent.x
    if key in ['fabric_cool','fabric_green']:
     # Paired legs on trousers folded over the hanger; a rounded crotch
     # opening replaces a curtain-like straight hem without changing its low.
     zz+=.18*math.exp(-((u/.115)**4))*t**4
    verts.append((x,yy,zz))
 faces=[];stride=(nx+1)*nr
 for k in [0,1]:
  offset=k*stride
  for i in range(nx):
   for j in range(nr-1):
    q=(offset+i*nr+j,offset+(i+1)*nr+j,offset+(i+1)*nr+j+1,offset+i*nr+j+1)
    faces.append(q if k==0 else tuple(reversed(q)))
 boundary=list(range(nr))+[i*nr+nr-1 for i in range(1,nx+1)]+[nx*nr+j for j in range(nr-2,-1,-1)]+[i*nr for i in range(nx-1,0,-1)]
 faces.extend((a,b,b+stride,a+stride) for a,b in zip(boundary,boundary[1:]+boundary[:1]))
 tag(solid(identity+'_'+label,verts,faces,identity,key))
 # Folded hems and side seams belong to each retained garment, not to the
 # repeating weave tile. Half-embedded fine cords give a restrained sewn
 # edge without changing source colours, hems, hanger or garment count.
 for j in [1,nr-2]:
  seam=[]
  for i in range(1,nx):
   x,y,z=verts[i*nr+j];seam.append((x,y+(-.00025 if j<nr/2 else .00025),z))
  tag(curved_wire(identity+'_'+label+'Hem'+str(j),seam,.00045,identity,key))
 for i in [1,nx-1]:
  seam=[]
  for j in range(nr//2+3,nr-1):
   x,y,z=verts[i*nr+j];seam.append((x,y+.00025,z))
  tag(curved_wire(identity+'_'+label+'SideSeam'+str(i),seam,.00045,identity,key))
 # Hanger width fits the source silhouette; its crossbar carries the fold.
 hw=half*.94
 tag(curved_wire(identity+'_'+label+'Hanger',[(cx-hw,.02,bar),(cx,.02,1.58),(cx+hw,.02,bar),(cx-hw,.02,bar)],.0015,identity,'metal'))
 path=[(cx,.02,1.58),(cx,.02,1.5965)]
 path.extend((cx,.02+.0135*math.cos(a),1.61+.0135*math.sin(a)) for a in np.linspace(-math.pi/2,math.pi*.90,35))
 tag(curved_wire(identity+'_'+label+'Hook',path,.0015,identity,'metal'))

for assembly in assemblies:
 identity=assembly['id'];component='Body';start=len(stock_checks);member=assembly['members'][0]
 # Dossier slice 30 (F02_C_STUDIO-001): Juno's second wardrobe is the session archive. Shelves
 # replace the rail and grey reel boxes stand spine-out with coloured tape (owned, never loot).
 archive=identity=='Wardrobe13'
 # Dossier slice 35: 5C's pigment store and 6C's packing store are shelved like the archive;
 # 4C's two wardrobes carry their residents' own garment colours.
 store={'Wardrobe14':'pigment','Wardrobe12':'packing'}.get(identity)
 palette={'Wardrobe15':'jersey_maroon','Wardrobe08':'drill_indigo'}.get(identity)
 shelved=archive or store is not None
 bare=identity=='Wardrobe16'
 wood=variants[identity]['params']['case_wood']
 for surface in member['surfaces']:
  if surface['material']!=wood:continue
  for i,(lo,hi) in enumerate(source_boxes(surface)):stock('Case'+str(i),lo,hi,wood,.0011)
 # Source rail ends stop 30mm short of the cheeks: fitted sockets close it.
 if not shelved:
  tag(rod(identity+'_Rail',(-.55,.02,1.61),(.55,.02,1.61),.012,identity,'metal'))
  for side in [-1,1]:
   tag(rod(identity+'_RailSocket'+str(side),(side*.545,.02,1.61),(side*.582,.02,1.61),.017,identity,'metal'))
 stock('CentreStop',(-.018,.259,.12),(.018,.2925,1.81),wood,.0005)
 for x in [-.63,.595]:stock('RebatedJamb'+str(x),(x,.258,.07),(x+.035,.287,1.86),wood,.0005)
 for z in [.10,1.795]:stock('FrontStop'+str(z),(-.58,.26,z),(.58,.2925,z+.025),wood,.0005)
 for surface in member['surfaces']:
  key=surface['material']
  if shelved or key not in ['fabric_cool','fabric_green','fabric_warm','linen']:continue
  label='Cloth'+key
  if palette:key=palette
  for i,(lo,hi) in enumerate(source_boxes(surface)):folded_cloth(label+str(i),lo,hi)
 if archive:
  tapes=['fabric_warm','fabric_green','fabric_cool']
  for k,z in enumerate([.475,.9,1.3]):
   if z>.5:stock('ArchiveShelf'+str(z),(-.581,-.256,z-.022),(.581,.231,z),wood,.0008)
   for half in [-1,1]:
    for i in range(7):
     x=half*(.06+i*.07);w=.032;depth=.19;tall=.17+.01*((i+k)%3)
     stock('ReelBox'+str(k)+'_'+str(half)+'_'+str(i),(x-w/2,.02,z-.0005),(x+w/2,.02+depth,z+tall),'linen',.0008)
     stock('Tape'+str(k)+'_'+str(half)+'_'+str(i),(x-w/2-.0005,.02+depth-.0005,z+.05),(x+w/2+.0005,.02+depth+.0015,z+.08),tapes[(i+k)%3],.0002)
 if store:
  for z in [.9,1.3]:stock('StoreShelf'+str(z),(-.581,-.256,z-.022),(.581,.231,z),wood,.0008)
  if store=='pigment':
   # Iris's pigment store: tins of ground colour with painted lids, rolled canvas on the top shelf.
   for k,z in enumerate([.475,.9]):
    for half in [-1,1]:
     for i in range(5):
      x=half*(.08+i*.095);r=.035+.005*((i+k)%2);h=.11+.02*((i+k)%2)
      tag(rod(identity+'_Tin'+str(k)+'_'+str(half)+'_'+str(i),(x,.1,z-.0005),(x,.1,z+h),r,identity,'metal'))
      tag(rod(identity+'_Lid'+str(k)+'_'+str(half)+'_'+str(i),(x,.1,z+h-.005),(x,.1,z+h+.012),r+.003,identity,['brass','fabric_warm','fabric_green','fabric_cool'][(i+k+half)%4]))
   for j,y in enumerate([-.15,-.07,.01,.09]):
    tag(rod(identity+'_Roll'+str(j),(.05,y,1.3+.0295),(.55-.05*j,y,1.3+.0295),.03,identity,'linen'))
   for i,x in enumerate([-.5,-.38,-.26,-.14]):
    tag(rod(identity+'_Jar'+str(i),(x,.05,1.3-.0005),(x,.05,1.3+.14),.04,identity,'metal'))
  else:
   # Mae's packing store: stacked flat cartons, folded brown paper and balls of string.
   for k,z in enumerate([.475,.9,1.3]):
    for half in [-1,1]:
     x0,x1=(.05,.53) if half>0 else (-.53,-.05)
     for i in range(3+(k+(half>0))%2):
      stock('Carton'+str(k)+'_'+str(half)+'_'+str(i),(x0,-.2,z-.0005+i*.04),(x1,.18,z+.04+i*.04),'kraft',.002)
     top=z-.0005+(3+(k+(half>0))%2)*.04
     stock('Paper'+str(k)+'_'+str(half),(x0+.04,-.15,top-.0005),(x1-.04,.13,top+.03),'linen',.004)
     tag(rod(identity+'_String'+str(k)+'_'+str(half),((x0+x1)/2-.03,.15,top+.0295),((x0+x1)/2+.03,.15,top+.0295),.03,identity,'linen'))
 for side in [-1,1]:
  hx=side*.615;inward=-side
  component='Body'
  for z in [.34,1.57]:
   stock('HingeNeck'+str(side)+str(z),(hx-.003,.26,z-.004),(hx+.003,.305,z+.004),'brass',.0002)
   tag(rod(identity+'_HingePin'+str(side)+str(z),(hx,.305,z-.04),(hx,.305,z+.04),.004,identity,'brass'))
  component='LeftLeaf' if side<0 else 'RightLeaf'
  x0=min(hx,hx+inward*.603);x1=max(hx,hx+inward*.603)
  for i,x in enumerate([x0,x1-.05]):
   obj=stock(component+'Stile'+str(i),(x,.2925,.1),(x+.05,.3175,1.82),wood,.0008)
   if (side<0 and i==0) or (side>0 and i==1):
    # Applied circular rebate leaves the fixed pin and neck clear throughout
    # the original 92 degree swing. The cutter never ships in the export.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.015,depth=1.8,location=(hx,.305,.96))
    cutter=bpy.context.object;bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Continuous hinge clearance','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  for z in [.10,1.77]:stock(component+'Rail'+str(z),(x0+.049,.2925,z),(x1-.049,.3175,z+.05),wood,.0008)
  stock(component+'Field',(x0+.048,.296,.148),(x1-.048,.3135,1.772),wood,.0006)
  stock(component+'RaisedPanel',(x0+.05,.312,.22),(x1-.05,.331,1.68),wood,.0014)
  # Three completion placements are close to a side wall. A shallow turned
  # button retains the source axis while clearing that wall at the full 92°.
  tag(axial(identity+'_'+component+'Knob',side*.075,.945,[(0,.320),(.007,.320),(.007,.332),(.012,.336),(.014,.340),(.012,.345),(0,.347)],identity,'brass',48))
  for z in [.34,1.57]:
   for dz in [-.018,.018]:
    center=z+dz
    tag(vessel(identity+'_'+component+'Knuckle'+str(center),hx,.305,center-.010,[(.004,0),(.009,0),(.009,.020),(.004,.020),(.004,0)],identity,'brass'))
    ends=sorted([hx+inward*.007,hx+inward*.055])
    stock(component+'Strap'+str(center),(ends[0],.301,center-.010),(ends[1],.309,center+.010),'brass',.0003)
 for x in [-.5,.5]:
  for y in [-.20,.20]:support(identity,'support',(x,y,0),(0,0,1),'retained plinth underside')
 construction_groups.append({'assembly':identity,'id':identity+'_JoinedWardrobe','stocks':[x['name'] for x in stock_checks[start:]]})
 retained_stock.append({'assembly':identity,'source_id':member['id'],'garment_count':0 if shelved or bare else 4,'source_hems_and_colours':True,'hinges_godot':[[-.615,.10,-.305],[.615,.10,-.305]],'angle_degrees':92,'moving_components':['LeftLeaf','RightLeaf']})
