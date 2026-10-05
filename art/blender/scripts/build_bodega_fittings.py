"""Fabricate source-owned retail stock, open racks, cases and practical housings."""
from pathlib import Path
import argparse,collections,hashlib,json,math,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
p=argparse.ArgumentParser();p.add_argument('--out',help='Optional isolated preview directory; omit to install production outputs')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=Path(args.out) if args.out else ROOT/'art/blender';OUT.mkdir(parents=True,exist_ok=True)
ASSET=OUT/'bodega_fittings.glb' if args.out else ROOT/'game/assets/props/bodega_fittings.glb'
source=ROOT/'game/data/orison_v2/exterior/exterior_geometry.json'
data=json.loads(source.read_text());template=next(t for t in data['templates'] if t['id']=='TEMPLATE_BODEGA_CELL_V1')
rows={r['id']:r for r in template['boxes']};palette={r['id']:r['albedo_rgba'] for r in data['materials']}
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed)
surfaces=bpy.data.collections.new('InstalledSurfaces');bpy.context.scene.collection.children.link(surfaces)
parts=collections.defaultdict(list);materials={};stocks=[];adaptations=[]

def material(key):
 if key in materials:return materials[key]
 spec=catalog[key];mat=bpy.data.materials.new(key);mat.use_nodes=True
 node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Metallic'].default_value=spec['metallic']
 coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
 tint=mat.node_tree.nodes.new('ShaderNodeVertexColor');tint.layer_name='SourceTint'
 for i,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  im=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
  im.filepath=bpy.path.relpath(im.filepath,start=str(OUT))
  if i:im.colorspace_settings.name='Non-Color'
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if i==0:
   mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
   mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(tint.outputs['Color'],mix.inputs[2]);mat.node_tree.links.new(mix.outputs[0],node.inputs[target])
  elif i==2:
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
  else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
 materials[key]=mat;return mat

def solid(name,vertices,faces,identity,key,tint=(1,1,1,1),bevel=0):
 points=np.asarray([(x,-z,y) for x,y,z in vertices],dtype=np.float64);origin=points.mean(axis=0)
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(points-origin,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);obj.location=origin;obj['assembly']=identity;obj['material_key']=key
 bpy.context.view_layer.objects.active=obj
 if bevel:
  mod=obj.modifiers.new('WorkedEdges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.dissolve_degenerate(bm,dist=1e-8,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12,name
 bm.to_mesh(obj.data);bm.free();obj.data.materials.clear();obj.data.materials.append(material(key))
 for layer in list(obj.data.uv_layers):obj.data.uv_layers.remove(layer)
 uv=obj.data.uv_layers.new(name='Metres');colour=obj.data.color_attributes.new(name='SourceTint',type='FLOAT_COLOR',domain='CORNER');guide=obj.data.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
 normals=[]
 for face in obj.data.polygons:
  points=np.asarray([obj.data.vertices[i].co[:] for i in face.vertices]);assert np.linalg.norm(np.cross(points[1]-points[0],points[2]-points[0]))>0,(name,points)
  normal,u,values,fallback=chart_for_triangle(points,origin,catalog[key]['meters_per_tile'],key in ['timber','wood_dark','oak_quartered'])
  for loop,value in zip(face.loop_indices,values):
   uv.data[loop].uv=value;colour.data[loop].color=tint;guide.data[loop].vector=(u[0],u[2],-u[1]);normals.append(tuple(normal))
 obj.data.normals_split_custom_set(normals)
 # Attribute creation and custom-normal installation can invalidate the old
 # RNA colour-layer handle. Resolve the final layer before assigning tint.
 colour=obj.data.color_attributes['SourceTint']
 colour.data.foreach_set('color',np.tile(np.asarray(tint,dtype=np.float32),len(colour.data)))
 assert max(abs(colour.data[0].color[i]-tint[i]) for i in range(4))<1e-6
 rgb=obj.data.attributes.new(name='_source_tint_rgb',type='FLOAT_VECTOR',domain='CORNER')
 rgb.data.foreach_set('vector',np.tile(np.asarray(tint[:3],dtype=np.float32),len(rgb.data)))
 obj.hide_render=True;parts[identity].append(obj);stocks.append({'name':name,'assembly':identity,'key':key})
 return obj

def box(name,low,high,identity,key,tint=(1,1,1,1),bevel=.0015):
 vertices=[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]]
 return solid(name,vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key,tint,bevel)

def rod(name,a,b,r,identity,key):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u);n=20
 vertices=[tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for p in [a,b] for i in range(n)]
 return solid(name,vertices,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)

def lathe(name,center,profile,identity,key,tint=(1,1,1,1),n=24,wave=0,axis='y'):
 vertices=[]
 for y,r in profile:
  for i in range(n):
   angle=math.tau*i/n;radius=r*(1+wave*math.sin(5*angle+3*y))
   vertices.append((center[0]+radius*math.cos(angle),y,center[2]+radius*math.sin(angle)) if axis=='y' else (center[0]+y,center[1]+radius*math.cos(angle),center[2]+radius*math.sin(angle)))
 faces=[tuple(reversed(range(n)))]+[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]+[tuple(range((len(profile)-1)*n,len(profile)*n))]
 return solid(name,vertices,faces,identity,key,tint)

def bounds(row):
 p=row['position_m'];s=row['size_m'];assert row['yaw_degrees']==0
 return [p[i]-s[i]*.5 for i in range(3)]+[p[i]+s[i]*.5 for i in range(3)]

def crate(identity,low,high):
 x,y,z=low;X,Y,Z=high;t=.014
 for i in range(4):
  a=x+(X-x)*i/4;box(identity+f'_Base{i}',(a,y,z),(a+(X-x)/4-.001,y+t,Z),identity,'timber')
 for level in range(3):
  a=y+t+(Y-y-t)*level/3;b=a+(Y-y-t)/3-.005
  for suffix,l,h in [('Front',(x,a,z),(X,b,z+t)),('Back',(x,a,Z-t),(X,b,Z)),('Left',(x,a,z+t),(x+t,b,Z-t)),('Right',(X-t,a,z+t),(X,b,Z-t))]:box(identity+f'_{suffix}{level}',l,h,identity,'timber')
 for a in [x+t,X-2*t]:
  for c in [z+t,Z-2*t]:box(identity+f'_Corner{a:.3f}_{c:.3f}',(a,y+t,c),(a+t,Y,c+t),identity,'timber')

def ellipse(name,center,rx,ry,back,front,identity,key):
 n=48;vertices=[(center[0]+rx*math.cos(i*math.tau/n),center[1]+ry*math.sin(i*math.tau/n),z) for z in [back,front] for i in range(n)]
 return solid(name,vertices,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)

def ellipse_ring(name,center,rx,ry,inner_x,inner_y,back,front,identity,key):
 n=48;vertices=[]
 for a,b,z in [(rx,ry,back),(rx,ry,front),(inner_x,inner_y,front),(inner_x,inner_y,back)]:vertices.extend((center[0]+a*math.cos(i*math.tau/n),center[1]+b*math.sin(i*math.tau/n),z) for i in range(n))
 return solid(name,vertices,[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)],identity,key)

def can(identity,index,x,z,base,height,r,tint):
 h=min(height,.235);cap=.0025
 lathe(identity+f'_Tin{index}',(x,0,z),[(base,r*.94),(base+.004,r),(base+h-.004,r),(base+h,r*.94)],identity,'metal')
 lathe(identity+f'_PaperBand{index}',(x,0,z),[(base+.012,r+.0006),(base+h-.012,r+.0006)],identity,'paper',tint)
 for y in [base+cap,base+h-cap]:lathe(identity+f'_RolledRim{index}_{y:.4f}',(x,0,z),[(y-.0015,r*.95),(y,r+.001),(y+.0015,r*.95)],identity,'nickel_plated')

def packet(identity,index,low,high,tint):
 box(identity+f'_Packet{index}',low,high,identity,'paper',tint,bevel=.004)
 x,y,z=low;X,Y,Z=high;t=.0007
 box(identity+f'_TopFold{index}',(x+.004,Y-.004,z+.003),(X-.004,Y+.0007,Z-.003),identity,'paper',tint,bevel=.0003)
 box(identity+f'_BackSeam{index}',(x+.008,y+.003,Z-.002),(X-.008,Y-.006,Z+.0005),identity,'paper',tint,bevel=.0002)

def cabbage(identity,index,x,z,base,r,height):
 profile=[(base+height*t,r*scale) for t,scale in [(0,.12),(.10,.58),(.25,.87),(.42,1),(.60,.96),(.76,.80),(.89,.56),(.97,.23),(1,.06)]]
 lathe(identity+f'_CabbageCore{index}',(x,0,z),profile,identity,'plant',n=32,wave=.025)
 centre=base+height*.52;ry=height*.49;nu=9;nv=11;count=nu*nv
 for leaf in range(5):
  angle=leaf*math.tau/5;vertices=[]
  for thickness in [0,.0009]:
   for v in range(nv):
    theta=.32+v*2.25/(nv-1)
    for u in range(nu):
     phi=angle-.72+u*1.44/(nu-1);rr=r+.002+(.0015*math.sin(4*phi+theta))-thickness
     vertices.append((x+rr*math.sin(theta)*math.cos(phi),centre+(ry-thickness)*math.cos(theta),z+rr*math.sin(theta)*math.sin(phi)))
  faces=[]
  for side in range(2):
   for v in range(nv-1):
    for u in range(nu-1):
     a=side*count+v*nu+u;face=(a,a+1,a+1+nu,a+nu);faces.append(face if side==0 else tuple(reversed(face)))
  perimeter=list(range(nu))+[v*nu+nu-1 for v in range(1,nv)]+list(reversed(range((nv-1)*nu,(nv-1)*nu+nu-1)))+[v*nu for v in reversed(range(1,nv-1))]
  for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):faces.append((a,a+count,b+count,b))
  solid(identity+f'_CabbageLeaf{index}_{leaf}',vertices,faces,identity,'plant')

for identity,row in rows.items():
 if row['presentation_role']!='stock':continue
 b=bounds(row);x,y,z,X,Y,Z=b;mid=row['material_id'];tint=tuple(palette[mid]);base=y
 if identity.startswith('aisle_'):
  number='1' if identity.startswith('aisle_a') else '2'
  shelf=rows[f'aisle_{number}_shelf_'+('low' if identity.endswith('low') else 'middle')];base=bounds(shelf)[4]
 elif identity.startswith('stock_aisle_'):
  number=identity.split('_')[2];base=bounds(rows[f'aisle_{number}_shelf_high'])[4]
 elif identity.startswith('stock_left_window') or identity.startswith('stock_right_window'):
  base=bounds(rows['left_bulkhead' if 'left' in identity else 'right_bulkhead'])[4]
 elif identity.startswith('stock_counter'):
  base=.445 if mid=='tinned_goods' else .675
  shift=bounds(rows['counter_glass_front'])[2]-.006-Z;z+=shift;Z+=shift
 adaptations.append({'id':identity,'original_base_y':y,'fitted_base_y':base,'support':'source shelf/case/sill','height_m':Y-y})
 if 'window' in identity:
  height=Y-y;crate(identity,(x,base,z),(X,base+min(.18,height*.45),Z))
  if mid=='produce_green':
   for i in range(8):
    xx=x+.105+(i%4)*(X-x-.21)/3;zz=z+.105+(i//4)*(Z-z-.21);r=.085
    cabbage(identity,i,xx,zz,base+.02,r,.21)
  else:
   for i in range(3):packet(identity,i,(x+.025+i*(X-x)/3,base+.014,z+.025),(x+(i+1)*(X-x)/3-.025,base+height-.01,Z-.025),(1,1,1,1))
 elif mid=='tinned_goods':
  count=max(2,int((X-x)/.075)) if Z-z<.15 else max(2,int((Z-z)/.12));two=Z-z>=.15
  for i in range(count*(2 if two else 1)):
   if two:xx=x+(X-x)*(.28 if i//count==0 else .72);zz=z+(i%count+.5)*(Z-z)/count;r=min((X-x)*.19,(Z-z)/count*.43)
   else:xx=x+(i+.5)*(X-x)/count;zz=(z+Z)*.5;r=min((X-x)/count*.43,(Z-z)*.42)
   can(identity,i,xx,zz,base,Y-y,r,tint)
 elif mid=='produce_green':
  crate(identity,(x,base,z),(X,base+.075,Z))
  for i in range(4):
   xx=x+(i%2+.5)*(X-x)/2;zz=z+(i//2+.5)*(Z-z)/2;r=min((X-x)/4,(Z-z)/4)*.9
   cabbage(identity,i,xx,zz,base+.025,r,.155)
 else:
  axis=0 if X-x>Z-z else 2;length=(X-x) if axis==0 else (Z-z);count=max(2,round(length/.15));height=Y-y
  for i in range(count):
   low=[x+.008,base,z+.008];high=[X-.008,base+height,Z-.008]
   low[axis]=(x if axis==0 else z)+i*length/count+.003;high[axis]=(x if axis==0 else z)+(i+1)*length/count-.003
   packet(identity,i,low,high,tint)

# Window stock originally floated behind a narrow bulkhead. Preserve the
# vertical facade stock and add a seated inner ledge in that same source node.
for identity,goods in [('left_bulkhead','stock_left_window_crates'),('right_bulkhead','stock_right_window_baskets')]:
 x,y,z,X,Y,Z=bounds(rows[identity]);g=bounds(rows[goods]);t=.028
 box(identity+'_Panel',(x,y,z),(X,Y-t,Z),identity,'enamel',tuple(palette[rows[identity]['material_id']]))
 box(identity+'_DisplayLedge',(x,Y-t,min(z,g[2]-.01)),(X,Y,max(Z,g[5]+.01)),identity,'oak_quartered')

for identity in ['aisle_a_body','aisle_b_body']:
 x,y,z,X,Y,Z=bounds(rows[identity]);t=.027
 for a in [x,X-t]:box(identity+f'_RearStile{a:.3f}',(a,0,z),(a+t,Y,z+t),identity,'iron_blackened')
 for level in ['low','middle','high']:
  number='1' if identity=='aisle_a_body' else '2';at=bounds(rows[f'aisle_{number}_shelf_{level}'])[1]
  for a in [x,X-t]:box(identity+f'_Bearer{a:.3f}_{level}',(a,at-.028,z),(a+t,at,Z),identity,'iron_blackened')
 box(identity+'_BaseTie',(x,.035,z),(X,.065,z+t),identity,'iron_blackened')

for identity,row in rows.items():
 if '_shelf_' in identity and identity.startswith('aisle_'):
  x,y,z,X,Y,Z=bounds(row);t=.002
  box(identity+'_Deck',(x,Y-t,z),(X,Y,Z),identity,'zinc_liner')
  for a,b in [(x,x+t),(X-t,X)]:box(identity+f'_Edge{a}',(a,y,z),(b,Y-t,Z),identity,'zinc_liner')
  for a,b in [(z,z+t),(Z-t,Z)]:box(identity+f'_End{a}',(x+t,y,a),(X-t,Y-t,b),identity,'zinc_liner')
 elif 'front_upright' in identity:
  b=bounds(row);box(identity+'_Post',b[:3],b[3:],identity,'iron_blackened',bevel=.003)

# Counter carcase stays inside its original hull; the source glass display
# owns an actual opening rather than an opaque panel behind the stock.
identity='counter_case';x,y,z,X,Y,Z=bounds(rows[identity]);t=.035
for name,low,high in [('Bottom',(x,y,z),(X,y+t,Z)),('Left',(x,y+t,z),(x+t,Y,Z)),('Right',(X-t,y+t,z),(X,Y,Z)),('Back',(x+t,y+t,z),(X-t,Y,z+t)),('FrontKick',(x+t,y+t,Z-t),(X-t,.37,Z)),('FrontHead',(x+t,.805,Z-t),(X-t,Y,Z))]:box(identity+'_'+name,low,high,identity,'wood_dark',bevel=.003)
for at in [.445,.675]:box(identity+f'_DisplayShelf{at}',(x+t,at-.014,z+t),(X-t,at,Z-t),identity,'oak_quartered')
identity='counter_front_panel';x,y,z,X,Y,Z=bounds(rows[identity]);box(identity+'_Kick',(x,y,z),(X,.37,Z),identity,'enamel',(.20,.38,.27,1),bevel=.002)
for a,b in [(x,x+.03),(X-.03,X)]:box(identity+f'_Stile{a}',(a,.37,z),(b,Y,Z),identity,'enamel',(.20,.38,.27,1))
identity='counter_top';b=bounds(rows[identity]);box(identity+'_Stone',b[:3],b[3:],identity,'countertop',bevel=.006)

identity='counter_scale_base';x,y,z,X,Y,Z=bounds(rows[identity]);base=bounds(rows['counter_top'])[4]
box(identity+'_Foot',(x,base,z),(X,Y-.003,Z),identity,'iron_blackened',bevel=.006)
box(identity+'_Pan',(x+.012,Y-.003,z+.012),(X-.012,Y,Z-.012),identity,'nickel_plated',bevel=.001)
identity='counter_scale_column';x,y,z,X,Y,Z=bounds(rows[identity]);base=bounds(rows['counter_scale_base'])[4]
box(identity+'_Column',(x,base,z),(X,Y,Z),identity,'iron_blackened',bevel=.004)
identity='counter_scale_head';x,y,z,X,Y,Z=bounds(rows[identity]);center=((x+X)*.5,(y+Y)*.5)
ellipse(identity+'_Back',center,(X-x)*.5,(Y-y)*.5,z,Z-.009,identity,'iron_blackened')
ellipse_ring(identity+'_Rim',center,(X-x)*.5,(Y-y)*.5,(X-x)*.5-.009,(Y-y)*.5-.009,Z-.009,Z,identity,'nickel_plated')
ellipse(identity+'_Dial',center,(X-x)*.5-.010,(Y-y)*.5-.010,Z-.009,Z-.006,identity,'paper')
for i in range(13):
 angle=math.radians(20+i*140/12);a=Vector((center[0]+.116*math.cos(angle),center[1]+.073*math.sin(angle),Z-.004));b=Vector((center[0]+.103*math.cos(angle),center[1]+.061*math.sin(angle),Z-.004))
 rod(identity+f'_Tick{i}',a,b,.0007,identity,'iron_blackened')
rod(identity+'_Needle',(center[0],center[1],Z-.003),(center[0]-.064,center[1]+.050,Z-.003),.0011,identity,'iron_blackened')
rod(identity+'_Hub',(center[0],center[1],Z-.006),(center[0],center[1],Z-.002),.0045,identity,'nickel_plated')

for identity in ['delivery_crate_left_lower','delivery_crate_left_upper','delivery_crate_right']:
 b=bounds(rows[identity]);crate(identity,b[:3],b[3:])

# The static icebox keeps its original shell/collider and observation owners.
# Its previous opaque body and glass backing become a lined visible cavity.
identity='cooler_body';x,y,z,X,Y,Z=bounds(rows[identity]);t=.045
for name,low,high in [('Bottom',(x,y,z),(X,y+t,Z)),('Top',(x,Y-t,z),(X,Y,Z)),('Back',(X-t,y+t,z),(X,Y-t,Z)),('Left',(x,y+t,z),(X-t,Y-t,z+t)),('Right',(x,y+t,Z-t),(X-t,Y-t,Z))]:box(identity+'_'+name,low,high,identity,'enamel_appliance',(.66,.8,.73,1),bevel=.006)
for at in [.49,1.0,1.5]:box(identity+f'_InteriorShelf{at}',(x+.055,at-.012,z+t),(X-t,at,Z-t),identity,'zinc_liner')
identity='cooler_door_frame';x,y,z,X,Y,Z=bounds(rows[identity]);glass=bounds(rows['cooler_door']);trim=.035
for name,low,high in [('Low',(x,y,z),(X,glass[1]-.002,Z)),('High',(x,glass[4]+.002,z),(X,Y,Z)),('Left',(x,glass[1]-.002,z),(X,glass[4]+.002,glass[2]-.002)),('Right',(x,glass[1]-.002,glass[5]+.002),(X,glass[4]+.002,Z))]:box(identity+'_'+name,low,high,identity,'nickel_plated',bevel=.002)
identity='cooler_inner_glow';b=bounds(rows[identity]);b[0]=bounds(rows['cooler_body'])[3]-.050;b[3]=b[0]+.005
box(identity+'_LinedBack',b[:3],b[3:],identity,'enamel_appliance',(.9,.95,.9,1))
identity='cooler_handle';x,y,z,X,Y,Z=bounds(rows[identity]);r=.011
rod(identity+'_Grip',((x+X)*.5,y+r,(z+Z)*.5),((x+X)*.5,Y-r,(z+Z)*.5),r,identity,'nickel_plated')
for at in [y+.05,Y-.05]:rod(identity+f'_Foot{at}',((x+X)*.5,at,(z+Z)*.5),(bounds(rows['cooler_door_frame'])[0]+.006,at,(z+Z)*.5),r*.8,identity,'nickel_plated')
for identity in ['cooler_top_trim','cooler_base_trim']:
 b=bounds(rows[identity]);box(identity+'_Trim',b[:3],b[3:],identity,'enamel_appliance' if 'top' in identity else 'iron_blackened',bevel=.007)

for identity,row in rows.items():
 if not identity.startswith('shop_floor_joint_'):continue
 b=bounds(row);b[1]=-.0012;b[4]=.0008
 box(identity+'_FlushSeal',b[:3],b[3:],identity,'rubber_aged',bevel=0)

for stem in ['front','middle','back']:
 identity=stem+'_practical_shade';x,y,z,X,Y,Z=bounds(rows[identity]);t=.006
 tint=tuple(palette['aged_green'])
 box(identity+'_Top',(x,Y-t,z),(X,Y,Z),identity,'enamel',tint,bevel=.001)
 for a,b in [(z,z+t),(Z-t,Z)]:box(identity+f'_Skirt{a}',(x,y,a),(X,Y-t,b),identity,'enamel',tint,bevel=.001)
 for a,b in [(x,x+t),(X-t,X)]:box(identity+f'_End{a}',(a,y,z+t),(b,Y-t,Z-t),identity,'enamel',tint,bevel=.001)
 identity='ceiling_practical_'+stem
 for index in range(3):
  xx=x+(index+.5)*(X-x)/3;zz=(z+Z)*.5
  lathe(identity+f'_Bulb{index}',(xx,0,zz),[(y+.014,.012),(y+.021,.025),(y+.034,.037),(y+.053,.037),(y+.071,.023),(y+.078,.013)],identity,'milk_glass',n=28)
  lathe(identity+f'_Socket{index}',(xx,0,zz),[(y+.078,.015),(Y-t,.015)],identity,'porcelain',n=24)
  lathe(identity+f'_Contact{index}',(xx,0,zz),[(Y-t-.011,.013),(Y-t,.013)],identity,'brass',n=24)
 # The source practical retains its original emissive colour and energy.
 mat=material('milk_glass');shader=mat.node_tree.nodes['Principled BSDF'];definition=next(m for m in data['materials'] if m['id']=='warm_practical')
 shader.inputs['Emission Color'].default_value=(*definition['emission_rgb'],1);shader.inputs['Emission Strength'].default_value=definition['emission_energy']

identity='delivery_handcart_base';x,y,z,X,Y,Z=bounds(rows[identity]);t=.025
for i in range(5):
 a=x+i*(X-x)/5;box(identity+f'_Deck{i}',(a,Y-t,z),(a+(X-x)/5-.002,Y,Z),identity,'wood_dark')
for a in [x+.035,X-.055]:box(identity+f'_Runner{a}',(a,y,z),(a+.02,Y-t,Z),identity,'iron_blackened')
axle_z=z+.16
rod(identity+'_Axle',(x+.012,.105,axle_z),(X-.012,.105,axle_z),.011,identity,'iron_blackened')
for side in [x+.023,X-.023]:
 rod(identity+f'_AxleBearer{side}',(side,.105,axle_z),(side,y+.02,axle_z),.014,identity,'iron_blackened')
 # Closed wheel shells are horizontal-axis lathes, transformed as native solids.
 lathe(identity+f'_Wheel{side}',(side,.105,axle_z),[(-.017,.105),(.017,.105)],identity,'rubber_aged',n=32,axis='x')
 rod(identity+f'_Hub{side}',(side-.023,.105,axle_z),(side+.023,.105,axle_z),.022,identity,'nickel_plated')
identity='delivery_handcart_back';x,y,z,X,Y,Z=bounds(rows[identity]);r=.016
for at in [x+r,X-r]:rod(identity+f'_Upright{at}',(at,y,(z+Z)*.5),(at,Y-r,(z+Z)*.5),r,identity,'iron_blackened')
rod(identity+'_Grip',(x+r,Y-r,(z+Z)*.5),(X-r,Y-r,(z+Z)*.5),r,identity,'iron_blackened')
for at in [y+.22,y+.55]:box(identity+f'_Strap{at}',(x+r,at-.025,z+.014),(X-r,at+.025,Z-.014),identity,'wood_dark')

draws=[];assembly_records=[]
for identity,objects in parts.items():
 row=rows[identity];origin=Vector((row['position_m'][0],-row['position_m'][2],row['position_m'][1]))
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 # Copy stocks so the saved source keeps every editable closed constituent.
 bpy.ops.object.duplicate();bpy.ops.object.join();o=bpy.context.object;o.name=identity
 for c in list(o.users_collection):c.objects.unlink(o)
 surfaces.objects.link(o);o.hide_render=False;o.data.transform(__import__('mathutils').Matrix.Translation(o.location-origin));o.location=origin
 draws.append(o);assembly_records.append({'id':identity,'source':row,'stocks':len(objects),'materials':[m.name for m in o.data.materials]})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'bodega_fittings.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in draws:o.select_set(True)
class ExportTangent:
 corrected=0
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  for primitive in mesh.primitives:
   def vectors(key):
    accessor=primitive.attributes[key];assert accessor.component_type==5126 and accessor.type=='VEC3'
    return np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(np.float64)
   n=vectors('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];guide=vectors('_TANGENT_GUIDE');tangent=guide-n*np.sum(guide*n,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
   assert np.isfinite(tangent).all()
   from io_scene_gltf2.io.exp.binary_data import BinaryData
   from io_scene_gltf2.io.com.constants import BufferViewTarget
   from io_scene_gltf2.io.com.gltf2_io import Accessor
   rgb=vectors('_SOURCE_TINT_RGB');assert np.isfinite(rgb).all() and rgb.min()>=0 and rgb.max()<=1
   # Preserve the saved source tint explicitly, just as the metric tangent
   # guide supplies the actual normal-map basis. Do this before serialization.
   primitive.attributes['COLOR_0']=Accessor(buffer_view=BinaryData(np.column_stack((rgb,np.ones(len(rgb)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER),byte_offset=None,component_type=5126,count=len(rgb),extensions=None,extras=None,max=None,min=None,name=None,normalized=None,sparse=None,type='VEC4')
   primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((tangent,-np.ones(len(n)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
   type(self).corrected+=1
   for key in list(primitive.attributes):
    if key.upper() in ['_TANGENT_GUIDE','_SOURCE_TINT_RGB']:del primitive.attributes[key]
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportTangent
# The saved native retains full catalogue shaders. Export only named material
# bindings: production supplies the same existing maps without embedding copies.
for mat in materials.values():
 for node in list(mat.node_tree.nodes):
  if node.type not in ['BSDF_PRINCIPLED','OUTPUT_MATERIAL']:mat.node_tree.nodes.remove(node)
 colour=mat.node_tree.nodes.new('ShaderNodeVertexColor');colour.layer_name='SourceTint'
 mat.node_tree.links.new(colour.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
export_path=OUT/'bodega_fittings_export.glb'
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT',export_vertex_color='MATERIAL')
export_path.replace(ASSET)
import struct
raw=ASSET.read_bytes();length=struct.unpack_from('<I',raw,12)[0];document=json.loads(raw[20:20+length])
assert not document.get('images') and not document.get('textures'),'catalogue maps must not be embedded'
assert {m['name'] for m in document['materials']}==set(materials)
assert all('COLOR_0' in primitive['attributes'] and 'TANGENT' in primitive['attributes'] for mesh in document['meshes'] for primitive in mesh['primitives'])
fixture=dict(evidence_class='INERT',classification='ADAPTATION',source_geometry_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),assemblies=assembly_records,stocks=stocks,adaptations=adaptations,materials={key:catalog[key] for key in materials},export_tangent_partitions=ExportTangent.corrected,native_sha256=hashlib.sha256((OUT/'bodega_fittings.blend').read_bytes()).hexdigest(),asset_sha256=hashlib.sha256(ASSET.read_bytes()).hexdigest())
(OUT/'bodega_fittings_construction.json').write_text(json.dumps(fixture,indent=2)+'\n',encoding='utf-8',newline='\n')
if not args.out:
 (ROOT/'game/tests/fixtures/orison_bodega_fittings.json').write_text(json.dumps(fixture,indent=2)+'\n',encoding='utf-8',newline='\n')
 generated='extends RefCounted\n# Generated from the retained exterior template by build_bodega_fittings.py.\n'
 generated+='const SOURCE_GEOMETRY_SHA256_LF := '+json.dumps(fixture['source_geometry_sha256_lf'])+'\n'
 generated+='const REPLACE_IDS := '+json.dumps(list(parts),indent=1)+'\n'
 (ROOT/'game/scripts/generated/v2_bodega_fittings.gd').write_text(generated,encoding='utf-8',newline='\n')
print('BODEGA FABRICATION:',len(assembly_records),'source owners;',len(stocks),'closed stocks;',ExportTangent.corrected,'material partitions')
