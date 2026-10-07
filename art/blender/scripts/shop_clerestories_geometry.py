"""Rebate original wall panels around the original sill/head; split at glass faces."""
def bearing(identity,owner,point,direction,label):
 support(identity,owner,point,direction,label);contacts[-1]['native_owner']=False

for item in assemblies:
 identity=item['id'];prefix='storm_'+item['floor']['batch'];glass=item['glazing'];g=glass['rect'];cx=(g[0]+g[2])/2;gz=glass['z0'];gt=gz+glass['h']
 members={row['id']:row for row in item['members']};sill=members[prefix+'_borrowed_sill'];head=members[prefix+'_borrowed_head']
 for row in [sill,head]:
  q=row['rect'];box(row['id']+'_Rail',(q[0],q[1],row['z0']),(q[2],q[3],row['z0']+row['h']),identity,'trim',.0006)
 # Axis-aligned wall solids have actual rebates around retained/renewed joinery.
 def rebated_wall(row,cutters):
  low,high=bounds(row);cuts=[bounds(c) for c in cutters]
  grid=[sorted({round(v,9) for v in [low[i],high[i]]+[v for a,b in cuts for v in [a[i],b[i]] if low[i]<v<high[i]]}) for i in range(3)]
  occupied=set()
  for i in range(len(grid[0])-1):
   for j in range(len(grid[1])-1):
    for k in range(len(grid[2])-1):
     at=[(grid[n][index]+grid[n][index+1])/2 for n,index in enumerate([i,j,k])]
     if not any(all(a[n]<at[n]<b[n] for n in range(3)) for a,b in cuts):occupied.add((i,j,k))
  vertices=[];faces=[];indices={}
  directions=[(-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1)]
  corners=[[(0,0,0),(0,0,1),(0,1,1),(0,1,0)],[(1,0,0),(1,1,0),(1,1,1),(1,0,1)],[(0,0,0),(1,0,0),(1,0,1),(0,0,1)],[(0,1,0),(0,1,1),(1,1,1),(1,1,0)],[(0,0,0),(0,1,0),(1,1,0),(1,0,0)],[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]]
  for cell in sorted(occupied):
   for direction,face in zip(directions,corners):
    if tuple(cell[n]+direction[n] for n in range(3)) in occupied:continue
    polygon=[]
    for corner in face:
     vertex=tuple(cell[n]+corner[n] for n in range(3))
     if vertex not in indices:indices[vertex]=len(vertices);vertices.append(tuple(grid[n][vertex[n]] for n in range(3)))
     polygon.append(indices[vertex])
    faces.append(polygon)
  solid(row['id']+'_RebatedWall',vertices,faces,identity,'plaster_stained')
 def bounds(row):
  q=row['rect'];return ([q[0],q[1],row['z0']],[q[2],q[3],row['z0']+row['h']])
 wall_rows=[r for r in item['members'] if '_back_lo' in r['id'] or r['id'].endswith('_back_hi')]
 cutters=[sill,head,rows[prefix+'_dw'],rows[prefix+'_de']]
 if prefix+'_chapel_head' in rows:cutters.append(rows[prefix+'_chapel_head'])
 for row in wall_rows:
  rebated_wall(row,cutters)
  q=row['rect'];z=row['z0']
  if abs(z-(item['floor']['z0']+item['floor']['h']))<.00001:
   for y in [q[1]+.20,q[3]-.20]:bearing(identity,item['floor']['id'],((q[0]+q[2])/2,y,z),(0,0,1),'rebated wall on original floor')
 # Bind both end jambs, their top/bottom boundaries, and retained wainscot.
 for suffix in ['back_jamb_e','back_jamb_w']:
  owner=rows[prefix+'_'+suffix];q=owner['rect'];y=(q[1]+q[3])/2
  bearing(identity,owner['id'],((q[0]+q[2])/2,y,gz),(0,0,-1),'lower panel below retained jamb')
  bearing(identity,owner['id'],((q[0]+q[2])/2,y,gt),(0,0,1),'upper panel above retained jamb')
  edge=g[1] if abs(q[3]-g[1])<.00001 else g[3];direction=1 if edge==g[1] else -1
  bearing(identity,owner['id'],(cx+.015,edge,(gz+gt)/2),(0,direction,0),'sash at retained jamb')
 facing=1 if cx<(item['floor']['rect'][0]+item['floor']['rect'][2])/2 else -1
 wainscot=rows[prefix+'_db'];wx=wainscot['rect'][0] if facing==1 else wainscot['rect'][2]
 lower=next(r for r in wall_rows if abs(r['z0']-.01)<.00001);y=(lower['rect'][1]+lower['rect'][3])/2
 bearing(identity,wainscot['id'],(wx,y,.50),(-facing,0,0),'wall front meets retained wainscot back')
 if prefix+'_chapel_head' in rows:
  owner=rows[prefix+'_chapel_head'];q=owner['rect'];bearing(identity,owner['id'],((q[0]+min(q[2],4.06))/2,(q[1]+q[3])/2,owner['z0']+owner['h']),(0,0,1),'plaster rebate above retained chapel head')
 for suffix in ['dw','de']:
  owner=rows[prefix+'_'+suffix];q=owner['rect'];z=owner['z0'];high=z+owner['h'];wx=(lower['rect'][0]+lower['rect'][2])/2;y=(q[1]+q[3])/2
  bearing(identity,owner['id'],(wx,y,z),(0,0,-1),'lower plaster rebate below party wainscot')
  bearing(identity,owner['id'],(wx,y,high),(0,0,1),'upper plaster rebate above party wainscot')
  edge=q[3] if y<(item['floor']['rect'][1]+item['floor']['rect'][3])/2 else q[1];sign=1 if edge==q[3] else -1
  bearing(identity,owner['id'],(wx,edge,.50),(0,sign,0),'plaster rebate at party wainscot end')
 if prefix+'_chapel_head' in rows:
  owner=rows[prefix+'_chapel_head'];q=owner['rect'];wx=(q[0]+4.06)/2;z=owner['z0'];high=z+owner['h']
  for y,sign in [(q[1],-1),(q[3],1)]:bearing(identity,owner['id'],(wx,y,(z+high)/2),(0,sign,0),'plaster rebate at chapel head end')
  for y in [q[1]+.02,q[3]-.02]:bearing(identity,owner['id'],(wx,y,z),(0,0,-1),'plaster rebate beneath chapel head oversail')
 # Existing common-brick backing remains a separate owner, seated at the outer plane.
 for row in wall_rows:
  q=row['rect'];x=q[0] if facing==1 else q[2];y=(q[1]+q[3])/2;z=row['z0']+row['h']*.5
  for owner in rows.values():
   if owner.get('mat')!='common_brick':continue
   a=owner['rect']
   if owner.get('mat')=='common_brick' and abs((a[2] if facing==1 else a[0])-x)<.00001 and a[1]<y<a[3] and owner['z0']<z<owner['z0']+owner['h']:
    bearing(identity,owner['id'],(x,y,z),(facing,0,0),'native wall seated against original brick backing');break
 # Exposed side edges remain flush against the source party-wall planes.
 for edge,sign in [(item['floor']['rect'][1],1),(item['floor']['rect'][3],-1)]:
  wx=(lower['rect'][0]+lower['rect'][2])/2
  for z in [1.50,3.15]:
   for owner in rows.values():
    if owner.get('mat')!='common_brick':continue
    q=owner['rect']
    if abs((q[3] if sign==1 else q[1])-edge)<.00001 and q[0]<wx<q[2] and owner['z0']<z<owner['z0']+owner['h']:
     bearing(identity,owner['id'],(wx,edge,z),(0,sign,0),'rebated wall edge at original party wall');break
 if item['cell']=='shop_photo_supplies':
  muntin=members[prefix+'_borrowed_muntin1'];y=sum(muntin['rect'][i] for i in [1,3])/2
  for x,sign in [(cx-.003,-1),(cx+.003,1)]:
   support(identity,glass['id'],(x,y,(gz+gt)/2),(sign,0,0),'split sash seats against retained Photo pane');contacts[-1]['native_owner']=True
  for z,sign in [(gz,-1),(gt,1)]:
   support(identity,glass['id'],(cx,(g[1]+g[3])/2,z),(0,0,sign),'rail seats against retained Photo sheet edge');contacts[-1]['native_owner']=True
 # A continuous 6mm pane keeps its original centre. Photo's accepted owner stays.
 if glass['id'] in members:box(glass['id']+'_Sheet',(cx-.003,g[1],gz),(cx+.003,g[3],gt),identity,'glassish',0)
 # Split each sash member around the sheet, so wood never occupies glass volume.
 for j in range(1,4):
  row=members[prefix+'_borrowed_muntin'+str(j)];q=row['rect']
  for side,(x0,x1) in enumerate([(q[0],cx-.003),(cx+.003,q[2])]):
   box(row['id']+'_Rebate'+str(side),(x0,q[1],gz),(x1,q[3],gt),identity,'trim',.0006)
 # Original jamb edges receive narrow paired stops on both glass faces.
 outer=sill['rect']
 for end,(y0,y1) in enumerate([(g[1],g[1]+.018),(g[3]-.018,g[3])]):
  for side,(x0,x1) in enumerate([(outer[0],cx-.003),(cx+.003,outer[2])]):
   box(identity+f'_JambStop{end}_{side}',(x0,y0,gz),(x1,y1,gt),identity,'trim',.0006)
 for edge,(z0,z1) in enumerate([(gz,gz+.012),(gt-.012,gt)]):
  for side,(x0,x1) in enumerate([(cx-.010,cx-.003),(cx+.003,cx+.010)]):
   muntins=sorted([members[prefix+'_borrowed_muntin'+str(j)]['rect'] for j in range(1,4)],key=lambda q:q[1])
   ends=[g[1]+.018]+[q[3] for q in muntins];starts=[q[1] for q in muntins]+[g[3]-.018]
   for pane,(y0,y1) in enumerate(zip(ends,starts)):
    box(identity+f'_HorizontalBead{edge}_{side}_{pane}',(x0,y0,z0),(x1,y1,z1),identity,'trim',.0005)

 # Accepted fixtures that already bore on these walls keep their exact contacts.
 selected_here={r['id'] for r in item['members']}
 for family in plan['context_families']:
  accepted_fixture=json.loads((ROOT/f'game/tests/fixtures/orison_{family}.json').read_text(encoding='utf-8'))
  for contact in accepted_fixture.get('contacts',[]):
   if contact.get('owner') not in selected_here:continue
   p=contact['point'];d=contact['direction']
   support(identity,contact['assembly'],(p[0],-p[2]+(.010 if contact['label']=='extended picture rail actual back-wall fixing' else 0.),p[1]),(-d[0],d[2],-d[1]),'reciprocal accepted bearing: '+contact['label']);contacts[-1]['native_owner']=True
 if item['cell']=='shop_keys_cut':
  support(identity,prefix+'_board',(sill['rect'][2],g[1]+.009,2.60),(-1,0,0),'sash stop meets accepted key-board back');contacts[-1]['native_owner']=True
