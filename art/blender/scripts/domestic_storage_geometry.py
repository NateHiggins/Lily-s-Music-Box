"""Source-fitted shelves, wall cases and sink frames; all old supports retained."""
frames={a['id']:{'position':[0,0,0],'yaw':0} for a in assemblies}
retained_stock=[];construction_groups=[]

def stock(label,lo,hi,key,edge=.001):
 return box(identity+'_'+label,lo,hi,identity,key,edge)

def source_boxes(surface):
 values=np.asarray(surface['vertices'],dtype=float).reshape((-1,36,3))
 for vertices in values:
  # Production uses Godot axes; Blender keeps right/up orientation.
  vertices=vertices[:,[0,2,1]];vertices[:,1]*=-1
  low=vertices.min(0);high=vertices.max(0)
  assert all(np.isin(vertices[:,axis].round(6),[round(low[axis],6),round(high[axis],6)]).all() for axis in range(3)),('non-box source',identity)
  yield low,high

def foot(label,x,y):support(identity,'support',(x,y,0),(0,0,1),label)

def bound_book(label,lo,hi,key):
 axis=int(np.argmin(hi-lo));assert axis in [0,2]
 cover=.001
 a=lo.copy();b=hi.copy();b[axis]=a[axis]+cover;stock(label+'LowerCover',a,b,key,.00018)
 a=lo.copy();b=hi.copy();a[axis]=b[axis]-cover;stock(label+'UpperCover',a,b,key,.00018)
 a=lo.copy();b=hi.copy();a[axis]+=cover;b[axis]-=cover
 a[1]+=.001;b[1]-=.001
 if axis==0:a[2]+=.001;b[2]-=.001
 else:a[0]+=.001;b[0]-=.001
 stock(label+'Pages',a,b,'paper',.0002)
 a=lo.copy();b=hi.copy();a[1]=b[1]-.0013
 stock(label+'Spine',a,b,key,.00018)

def closed_container(label,lo,hi,key):
 t=.0015
 stock(label+'Bottom',lo,(hi[0],hi[1],lo[2]+t),key,.0003)
 stock(label+'Lid',(lo[0],lo[1],hi[2]-t),hi,key,.0003)
 for axis in [0,1]:
  for side in [-1,1]:
   a=lo.copy();b=hi.copy()
   if side<0:b[axis]=a[axis]+t
   else:a[axis]=b[axis]-t
   stock(label+'Wall'+str(axis)+str(side),a,b,key,.0003)
 # Folded rim gives the lid a physical seam, within the source bounds.
 retained_stock.append({'assembly':identity,'kind':'closed_storage_container','label':label,'low':lo.tolist(),'high':hi.tolist()})

def shelf(row,p):
 width=p['W'];height=p['H'];surfaces={s['material']:s for s in row['surfaces']}
 boards=list(source_boxes(surfaces['floor_oak']))
 assert height>=max(lo[2] for lo,hi in boards)
 oak=p.get('posts','oak')=='oak'
 for i,x in enumerate([-width/2+.02,width/2-.02]):
  for j,y in enumerate([-.13,.13]):
   if oak:
    # Dossier BW-003: an oak open shelf unit; square posts replace the steel rods.
    stock('Upright%d%d'%(i,j),(x-.016,y-.016,0),(x+.016,y+.016,height),'floor_oak',.002)
   else:
    rod(identity+'_Upright%d%d'%(i,j),(x,y,0),(x,y,height),.013,identity,'metal')
   foot('shelf foot%d%d'%(i,j),x,y)
 for i,(lo,hi) in enumerate(boards):
  stock('Board'+str(i),lo,hi,'floor_oak',.001)
  for sign in [-1,1]:
   x=sign*(width/2-.02)
   # A rail below each board supplies an actual bearing, not just a
   # coincident board cut through a vertical post.
   if oak:
    stock('Rail%d_%d'%(i,sign),(x-.012,-.13,lo[2]-.012),(x+.012,.13,lo[2]),'floor_oak',.001)
   else:
    rod(identity+'_Rung%d_%d'%(i,sign),(x,-.13,lo[2]-.006),(x,.13,lo[2]-.006),.006,identity,'metal')
 # Dossier slice 37: a bare variant (4B's equipment shelf) leaves out the source record's
 # painted bins and metal tins, which read as placeholder cubes in that closet.
 bins=p.get('bins',True)
 for key,surface in surfaces.items():
  if key.startswith('book_'):
   for i,(lo,hi) in enumerate(source_boxes(surface)):bound_book(key+str(i),lo,hi,key)
  elif key=='trim' and bins:
   for i,(lo,hi) in enumerate(source_boxes(surface)):closed_container('PaintedBin'+str(i),lo,hi,key)
 if not p.get('books',True) and bins:
  # Four original 8-sided posts precede the two rectangular metal tins.
  surface={**surfaces['metal'],'vertices':surfaces['metal']['vertices'][-216:]}
  for i,(lo,hi) in enumerate(source_boxes(surface)):closed_container('MetalTin'+str(i),lo,hi,'metal')
 retained_stock.append({'assembly':identity,'kind':'shelf','boards':len(boards),'height':height,'books':sum(len(s['vertices'])//108 for k,s in surfaces.items() if k.startswith('book_'))})

def cupboard(row,p):
 # The original cupboard is a solid block. This passive case keeps its outer
 # envelope, split closed leaves and recessed black pulls, with a real interior.
 stock('Back',(-.55,-.3,0),(.55,-.278,.7),'trim')
 for z in [0,.68]:stock('Deck'+str(z),(-.55,-.3,z),(.55,.05,z+.02),'trim')
 for x in [-.55,.53]:stock('Cheek'+str(x),(x,-.3,.018),(x+.02,.05,.682),'trim')
 stock('Shelf',(-.53,-.278,.335),(.53,.047,.351),'trim')
 for z0,z1 in [(.018,.04),(.66,.682)]:stock('FaceRail'+str(z0),(-.53,.028,z0),(.53,.051,z1),'trim',.0006)
 stock('CentreFace',(-.01,.028,.02),(.01,.05,.68),'trim',.0006)
 for side,lo,hi in [('Left',-.53,-.01),('Right',.01,.53)]:
  # Outer frame with a genuine recess behind each source black handhold.
  for x in [lo,hi-.025]:stock(side+'Stile'+str(x),(x,.051,.04),(x+.025,.071,.66),'trim',.0008)
  for z0,z1 in [(.04,.06),(.095,.12),(.635,.66)]:stock(side+'Rail'+str(z0),(lo+.024,.051,z0),(hi-.024,.071,z1),'trim',.0008)
  stock(side+'Panel',(lo+.024,.051,.119),(hi-.024,.067,.636),'trim',.0006)
  stock(side+'Recess',(lo+.025,.051,.06),(hi-.025,.053,.095),'soot',.0004)
  # Rear battens fasten the passive leaves into the original case.
  stock(side+'LeafBatton',(lo+.04,.036,.15),(lo+.06,.053,.62),'trim',.0005)
  stock(side+'HingeSeat',(lo-.02 if side=='Left' else hi-.02,.028,.22),(lo+.06 if side=='Left' else hi+.02,.053,.30),'trim',.0005)
 back=p['back_plane']
 for x in [-.43,.43]:
  if back>.3:stock('MountingBatten'+str(x),(x-.025,-back,.05),(x+.025,-.299,.65),'trim',.0005)
  for z in [.10,.60]:support(identity,'wall',(x,-back,z),(0,1,0),'cabinet rear bearing')
 retained_stock.append({'assembly':identity,'kind':'cupboard','closed_passive_leaves':2,'shelves':1,'back_plane_godot_z':back})

def countertop_ring():
 # One closed ring around the preserved half-metre sink opening.
 outer=[(-.97,-.3),(.38,-.3),(.38,.28),(-.97,.28)]
 inner=[(-.25,-.19),(.25,-.19),(.25,.19),(-.25,.19)]
 verts=[(x,y,z) for z in [.86,.905] for x,y in outer+inner];faces=[]
 for i in range(4):
  j=(i+1)%4
  faces.extend([(i,j,8+j,8+i),(4+j,4+i,12+i,12+j),(8+i,8+j,12+j,12+i),(i,4+i,4+j,j)])
 obj=solid(identity+'_PiercedWorktop',verts,faces,identity,'countertop')
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worktop eased edges','BEVEL');mod.width=.001;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)

def counter(row,p):
 surfaces={s['material']:s for s in row['surfaces']}
 if 'countertop' in surfaces:
  countertop_ring()
  for i,(lo,hi) in enumerate(source_boxes(surfaces['wood_dark'])):
   stock('Frame'+str(i),lo,hi,'wood_dark',.0015)
   if lo[2]==0:foot('timber sink foot'+str(i),(lo[0]+hi[0])/2,(lo[1]+hi[1])/2)
 else:
  for i,(lo,hi) in enumerate(source_boxes(surfaces['metal'])):
   if lo[2]==0:
    stock('FootPlate'+str(i),lo,(hi[0],hi[1],.003),'metal',.0003)
    a=lo.copy();b=hi.copy();b[0]=a[0]+.003;stock('LegWeb'+str(i),a,b,'metal',.0005)
    a=lo.copy();b=hi.copy();b[1]=a[1]+.003;stock('LegFlange'+str(i),a,b,'metal',.0005)
    foot('metal sink foot'+str(i),(lo[0]+hi[0])/2,(lo[1]+hi[1])/2)
   else:
    # Closed thin rectangular rail, with top bearing retained at .75m.
    axis=int(np.argmax(hi[:2]-lo[:2]));short=1-axis;t=.003
    for sign in [-1,1]:
     a=lo.copy();b=hi.copy()
     if sign<0:b[short]=a[short]+t
     else:a[short]=b[short]-t
     stock('RailWeb%d_%d'%(i,sign),a,b,'metal',.0004)
    for sign in [-1,1]:
     a=lo.copy();b=hi.copy()
     if sign<0:b[2]=a[2]+t
     else:a[2]=b[2]-t
     stock('RailFlange%d_%d'%(i,sign),a,b,'metal',.0004)
    for sign in [-1,1]:
     a=lo.copy();b=hi.copy()
     if sign<0:b[axis]=a[axis]+t
     else:a[axis]=b[axis]-t
     stock('RailEnd%d_%d'%(i,sign),a,b,'metal',.0004)
 retained_stock.append({'assembly':identity,'kind':'counter','worktop':.905 if 'countertop' in surfaces else .75})

for item in assemblies:
 identity=item['id'];start=len(stock_checks);row=item['members'][0];p=variants[identity]['params']
 {'shelf':shelf,'cupboard':cupboard,'counter':counter}[item['kind']](row,p)
 construction_groups.append({'assembly':identity,'id':identity+'_JoinedStorage','stocks':[x['name'] for x in stock_checks[start:]]})
