"""Complete fitted galvanized powered wringer washer; retained functional owner.
No reference photograph is baked or exported. All stock uses metric charts.
"""
from pathlib import Path
import json,math,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,export
from fabrication_chart_batch import triangle_charts,revolved_charts
from fabrication_normals import stock_corner_normals
from fabrication_uvs import chart_for_triangle
bpy.ops.wm.read_factory_settings(use_empty=True)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
recipe=json.loads((ROOT/'game/data/orison_v2/washer_native.json').read_text(encoding='utf-8'))
collection=bpy.data.collections.new('Fitted washer');bpy.context.scene.collection.children.link(collection)
materials={role:material(ROOT,role,finish,catalog) for role,finish in recipe['finishes'].items()}
parts={};stocks=[];stock_report=[]
def bv(v):return Vector((v[0],-v[2],v[1]))
def begin(name,at=(0,0,0)):
 obj=bpy.data.objects.new(name,None);collection.objects.link(obj);obj.location=bv(at);parts[name]=obj;return obj

def keep(obj,label,parent,role,axis=None):
 obj.name=label;obj.parent=parent
 for c in list(obj.users_collection):c.objects.unlink(obj)
 collection.objects.link(obj);obj.data.materials.clear();obj.data.materials.append(materials[role]);obj['finish_role']=role
 bpy.context.view_layer.objects.active=obj;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0000001)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),label
 assert bm.calc_volume(signed=True)>0,label
 bm.to_mesh(obj.data);bm.free()
 # Triangles carry their own physical charts; turned bands share one seam.
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free();obj.data.update()
 coords=np.array([v.co[:] for v in obj.data.vertices]);indices=np.array([l.vertex_index for l in obj.data.loops]).reshape(-1,3)
 points=coords[indices];ns,us,uvs,_=triangle_charts(points,np.array(obj.location),1.)
 if axis is not None:revolved_charts(points,ns,us,uvs,np.tile(bv(axis),(len(points),1)),np.zeros((len(points),3)),1.)
 uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres');uv.name='Metres';uv.data.foreach_set('uv',uvs.astype(np.float32).ravel())
 g=np.repeat(us[:,[0,2,1]],3,axis=0);g[:,2]*=-1
 attr=obj.data.attributes.get('_tangent_guide') or obj.data.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');attr.data.foreach_set('vector',g.astype(np.float32).ravel())
 obj.data.normals_split_custom_set(stock_corner_normals(obj.data))
 stocks.append(obj);stock_report.append({'name':label,'part':parent.name,'finish':role});return obj

def box(label,at,size,parent,role,edge=.002,yaw=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=bv(at));obj=bpy.context.object;obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if edge:
  mod=obj.modifiers.new('Manufactured edge','BEVEL');mod.width=min(edge,min(size)*.35);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 if yaw:obj.rotation_euler.z=yaw
 return keep(obj,label,parent,role)

def rod(label,a,b,r,parent,role,edge=.0005):
 a,b=Vector(a),Vector(b);direction=(b-a).normalized()
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=(b-a).length,location=bv((a+b)*.5));obj=bpy.context.object;obj.rotation_mode='QUATERNION';obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(bv(direction))
 if edge:
  mod=obj.modifiers.new('Turned lip','BEVEL');mod.width=min(edge,r*.15);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return keep(obj,label,parent,role,direction)

def ring(label,at,axis,radius,bore,length,parent,role):
 # Four profile rings make an actual closed hollow sleeve.
 at,axis=Vector(at),Vector(axis).normalized();a=axis.cross(Vector((0,1,0)))
 if a.length<.1:a=axis.cross(Vector((1,0,0)))
 a.normalize();b=axis.cross(a);verts=[];faces=[];n=64
 for r,z in [(radius,-length/2),(radius,length/2),(bore,length/2),(bore,-length/2)]:
  for i in range(n):verts.append(bv(at+axis*z+r*(a*math.cos(i*math.tau/n)+b*math.sin(i*math.tau/n))))
 for band in range(4):
  next_band=(band+1)%4
  for i in range(n):j=(i+1)%n;faces.append((band*n+i,band*n+j,next_band*n+j,next_band*n+i))
 mesh=bpy.data.meshes.new(label);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
 return keep(obj,label,parent,role)

def casting(label,at,size,parent,role,bores=(),slot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=bv(at));obj=bpy.context.object;obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=obj.modifiers.new('Casting radii','BEVEL');mod.width=.006;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 cutters=[]
 for center,axis,radius,length in bores:
  bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=length,location=bv(center));cut=bpy.context.object;cut.rotation_mode='QUATERNION';cut.rotation_quaternion=Vector((0,0,1)).rotation_difference(bv(axis));cutters.append(cut)
 if slot is not None:
  center,dimensions=slot;bpy.ops.mesh.primitive_cube_add(size=1,location=bv(center));cut=bpy.context.object;cut.dimensions=(dimensions[0],dimensions[2],dimensions[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);cutters.append(cut)
 for cut in cutters:
  bpy.context.view_layer.objects.active=obj
  mod=obj.modifiers.new('Actual bearing or guide opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
 return keep(obj,label,parent,role)

def rounded_profile(half,radius,n=12,depth=None):
 depth=half if depth is None else depth
 pts=[]
 for cx,cz,start in [(half-radius,depth-radius,0),(-half+radius,depth-radius,90),(-half+radius,-depth+radius,180),(half-radius,-depth+radius,270)]:
  for i in range(n+1):t=math.radians(start+i*90/n);pts.append((cx+radius*math.cos(t),cz+radius*math.sin(t)))
 return pts

def shell(label,profile,parent,role,drain=False,depth=None,rear=False):
 # Closed thin sheet: rounded square, real inner wall and floor.
 verts=[];faces=[];n=len(rounded_profile(profile[0][0],profile[0][2]))
 for half,y,radius in profile:
  for x,z in rounded_profile(half,radius,depth=depth):verts.append(bv((x,y,z)))
 for band in range(len(profile)-1):
  for i in range(n):j=(i+1)%n;faces.append((band*n+i,band*n+j,(band+1)*n+j,(band+1)*n+i))
 faces+=[tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))]
 mesh=bpy.data.meshes.new(label);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
 if rear:
  # Fixed deck fills the curved rear corners around the shorter moving lid.
  outline=rounded_profile(.341,.080,depth=.236);count=len(outline)
  vertices=[bv((x,y,z-.105)) for y in [.79,.90] for x,z in outline]
  polygons=[tuple(reversed(range(count))),tuple(range(count,2*count))]
  for i in range(count):j=(i+1)%count;polygons.append((i,j,count+j,count+i))
  cutter_mesh=bpy.data.meshes.new('Fitted lid opening');cutter_mesh.from_pydata(vertices,[],polygons);cutter_mesh.update()
  cut=bpy.data.objects.new('Fitted lid opening',cutter_mesh);bpy.context.collection.objects.link(cut)
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Fixed deck around rounded lid','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
 if drain:
  bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.016,depth=.070,location=bv((.25,.385,.22)));cut=bpy.context.object
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Actual drain bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
 return keep(obj,label,parent,role)

def rounded_band(label,at,outer,inner,corner,height,parent,role,depth=None):
 rings=[(outer,at[1]-height/2,corner),(outer,at[1]+height/2,corner),(inner,at[1]+height/2,corner-(outer-inner)),(inner,at[1]-height/2,corner-(outer-inner))]
 verts=[];faces=[];n=len(rounded_profile(outer,corner))
 for half,y,r in rings:
  for x,z in rounded_profile(half,r,depth=None if depth is None else depth-(outer-half)):verts.append(bv((x+at[0],y,z+at[2])))
 for band in range(4):
  next_band=(band+1)%4
  for i in range(n):j=(i+1)%n;faces.append((band*n+i,band*n+j,next_band*n+j,next_band*n+i))
 mesh=bpy.data.meshes.new(label);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
 return keep(obj,label,parent,role)

def rounded_plate(label,at,half,radius,thickness,parent,role,depth=None):
 y=at[1];obj=shell(label,[(half,y-thickness*.5,radius),(half,y+thickness*.5,radius)],parent,role,depth=depth)
 obj.location+=bv((at[0],0,at[2]));return obj

def bolts(parent,points,axis=(0,0,1),role='iron'):
 for i,p in enumerate(points):rod(parent.name+'_Bolt'+str(len(stocks)),Vector(p)-Vector(axis)*.003,Vector(p)+Vector(axis)*.003,.006,parent,role)

fixed=begin('FixedBody')
# Sheet stock is 4 mm thick, with a rounded rolled rim and seated floor.
shell('GalvanizedVessel',[(.307,.376,.052),(.311,.391,.055),(.330,.820,.071),(.337,.826,.077),(.340,.832,.080),(.338,.839,.078),(.331,.842,.071),(.326,.836,.067),(.326,.821,.067),(.307,.397,.051),(.303,.386,.048)],fixed,'zinc',drain=True)
# The supporting skirt bears on the frame rather than hovering above its feet.
for x in [-.268,.268]:
 for z in [-.268,.268]:
  box('AngleLegWeb',(x,.185,z),(.031,.35,.006),fixed,'frame',.001)
  box('AngleLegReturn',(x+.012,.185,z-.012),(.006,.35,.030),fixed,'frame',.001)
  box('FootShoe',(x,.008,z),(.069,.016,.060),fixed,'iron',.003)
  box('RivetedLegSeat',(x,.347,z),(.055,.061,.047),fixed,'frame')
  bolts(fixed,[(x,.325,z-.025),(x,.360,z-.025)])
for z in [-.268,.268]:box('CrossRail',(0,.345,z),(.56,.037,.024),fixed,'frame')
for x in [-.268,.268]:box('SideRail',(x,.345,0),(.030,.037,.56),fixed,'frame')
box('MotorCradle',(0,.118,.060),(.37,.018,.25),fixed,'frame')
# Motor, mounting feet and an actual coupling into the gearbox.
rod('MotorHousing',(-.132,.222,.060),(.110,.222,.060),.084,fixed,'frame',.002)
for x in [-.126,.106]:rod('MotorEndcap',(x-.008,.222,.060),(x+.008,.222,.060),.085,fixed,'frame',.002)
for x in [-.09,.07]:
 box('MotorMount',(x,.136,.06),(.045,.036,.135),fixed,'frame')
 bolts(fixed,[(x,.147,-.010),(x,.147,.130)],(0,1,0))
for t in np.linspace(0,math.tau,9)[:-1]:
 y=.222+.087*math.cos(t);z=.06+.087*math.sin(t);rod('MotorRib',(-.112,y,z),(.085,y,z),.0025,fixed,'frame')
rod('MotorCoupling',(.111,.222,.06),(.181,.222,.06),.023,fixed,'iron')
box('Gearbox',( .233,.275,.04),(.202,.160,.300),fixed,'frame',.021)
box('GearboxSeam',(.337,.275,.04),(.005,.127,.258),fixed,'iron',.013)
bolts(fixed,[(.343,.223,-.066),(.343,.325,-.066),(.343,.223,.146),(.343,.325,.146)],(1,0,0))
# The two clutch shafts emerge from the gear casing, not isolated panels.
for z in [-.09,.13]:ring('ClutchBearing',(.353,.315,z),(1,0,0),.023,.011,.028,fixed,'brass')
rod('AgitatorGearOutput',(0,.283,0),(0,.398,0),.038,fixed,'frame')
box('GearBridge',(.108,.293,.04),(.223,.056,.104),fixed,'frame',.014)
# The wringer column reaches the underside gear train and the swivel socket.
ring('WringerColumn',(.27,.570,.20),(0,1,0),.041,.033,.490,fixed,'frame')
for y in [.353,.769]:ring('ColumnCollar',(.27,y,.20),(0,1,0),.048,.041,.022,fixed,'iron')
ring('SwivelBearing',(.27,.819,.20),(0,1,0),.052,.033,.045,fixed,'frame')
box('ColumnGearFoot',(.27,.314,.18),(.105,.104,.103),fixed,'frame',.014)
# Tub drain tail reaches the original hose mouth at (.27,.28,.336).
ring('DrainTail',(.25,.348,.22),(0,1,0),.021,.016,.083,fixed,'brass')
ring('DrainFlange',(.25,.388,.22),(0,1,0),.026,.016,.006,fixed,'brass')
rod('DrainElbow',(.25,.296,.22),(.27,.28,.22),.025,fixed,'brass')
ring('DrainOutlet',(.27,.28,.293),(0,0,1),.027,.020,.091,fixed,'brass')
rod('DrainValveBody',(.27,.28,.22),(.327,.28,.22),.024,fixed,'brass')
ring('DrainPacking',(.338,.28,.22),(1,0,0),.019,.011,.027,fixed,'brass')
# Inlet unions meet the retained hose tips; short spouts feed the actual tub.
for i,x in enumerate([-.105,.105]):
 rod('FillBody',(x,.900,.28),(x,.900,.327),.0165,fixed,'brass')
 ring('HoseUnion',(x,.91,.336),(0,0,1),.0215,.011,.022,fixed,'brass')
 rod('HoseElbow',(x,.900,.323),(x,.910,.327),.0165,fixed,'brass')
 rod('ValveBonnet',(x,.900,.30),(x,.939,.30),.012,fixed,'brass')
ring('FillManifold',(0,.900,.28),(1,0,0),.013,.009,.235,fixed,'brass')
ring('FillSpout',(0,.900,.243),(0,0,1),.013,.009,.074,fixed,'brass')
ring('DownturnedMouth',(0,.877,.21),(0,1,0),.013,.009,.044,fixed,'brass')
for x in [-.105,.105]:box('FillMount',(x,.867,.302),(.031,.048,.035),fixed,'brass',.003)
shell('FixedRearDeck',[(.340,.840,.080),(.340,.846,.080)],fixed,'zinc',rear=True)
# Fixed leaf hinge seats use the same axis as the lid owner.
for x in [-.115,.115]:
 box('TubHingeSeat',(x,.827,.139),(.049,.029,.019),fixed,'iron')
 ring('HingeBush',(x,.845,.133),(1,0,0),.011,.0065,.041,fixed,'iron')

lid=begin('TubLid',(0,.845,.133))
rounded_plate('StampedCover',(0,.002,-.238),.340,.080,.006,lid,'zinc',depth=.235)
rounded_band('CoverSeal',(0,-.002,-.238),.337,.329,.078,.002,lid,'rubber',depth=.232)
# A shallow pressed rib catches highlights without a noisy normal map.
for z in [-.365,-.100]:box('LidStiffeningRib',(0,.001,z),(.49,.006,.011),lid,'zinc',.002)
rod('HingePin',(-.150,0,0),(.150,0,0),.006,lid,'iron')
for x in [-.11,.11]:box('LidHingeLeaf',(x,0,-.022),(.049,.006,.050),lid,'iron',.001)
# Handle feet actually touch the sheet; rounded strap spans the knuckle gap.
for x in [-.073,.073]:
 rod('LidGripFoot',(x,.0,-.365),(x,.032,-.365),.007,lid,'iron')
 rod('HandleRivet',(x,-.002,-.365),(x,.005,-.365),.009,lid,'iron')
rod('LidGrip',(-.080,.032,-.365),(.080,.032,-.365),.008,lid,'iron')

gyrator=begin('Gyrator',(0,.405,0))
rod('AgitatorHub',(0,0,0),(0,.055,0),.034,gyrator,'zinc')
for i in range(4):
 t=i*math.pi/2;direction=Vector((math.cos(t),0,math.sin(t)))
 a=direction*.022+Vector((0,.030,0));b=direction*.125+Vector((0,.035,0))
 obj=box('AgitatorFin',(a+b)*.5,(.105,.048,.012),gyrator,'zinc',.003,yaw=t)

wringer=begin('SwingingWringer',(.27,.83,.20))
rod('SwivelShaft',(0,-.024,0),(0,.137,0),.032,wringer,'frame')
box('DriveElbow',(-.008,.132,-.110),(.100,.107,.235),wringer,'enamel',.015)
# Stationary cheeks surround real bearing centres and carriage travel slots.
for x in [-.515,-.025]:
 casting('WringerCheek',(x,.280,-.20),(.046,.420,.104),wringer,'enamel',bores=[((x,.160,-.20),(1,0,0),.0295,.10)],slot=((x,.319,-.20),(.10,.160,.078)))
 ring('LowerRollBearing',(x,.160,-.20),(1,0,0),.029,.013,.056,wringer,'brass')
 for z in [-.246,-.154]:box('CarriageGuide',(x,.292,z),(.052,.160,.009),wringer,'iron',.001)
 bolts(wringer,[(x,.119,-.254),(x,.402,-.254)])
box('WringerLowerTie',(-.27,.083,-.20),(.50,.029,.084),wringer,'enamel',.006)
# The quick-release pressure bridge moves separately, in the cheek slots.
bridge=begin('PressureBridge',(-.27,.405,-.20))
casting('Crosshead',(0,0,0),(.537,.037,.090),bridge,'enamel',bores=[((0,0,0),(0,1,0),.0135,.10)])
ring('PressureNut',(0,.008,0),(0,1,0),.026,.0105,.046,bridge,'brass')
for x in [-.245,.245]:box('ReleaseGuideFoot',(x,-.012,0),(.040,.064,.068),bridge,'iron',.004)
# Roller assemblies: shaft-centred spinning stock, independent sliding bearings.
for name,y,r in [('LowerRoll',.160,.0575),('UpperRoll',.275,.0575)]:
 parent=begin(name,(-.27,y,-.20))
 rod('RubberRoll',(-.194,0,0),(.194,0,0),r,parent,'rubber',.0025)
 rod('RollShaft',(-.274,0,0),(.274,0,0),.012,parent,'iron')
 for x in [-.199,.199]:ring('RollEndCollar',(x,0,0),(1,0,0),.020,.012,.012,parent,'iron')
carriage=begin('UpperCarriage')
for x in [-.515,-.025]:
 casting('SlidingBearing',(x,.275,-.20),(.049,.067,.074),carriage,'enamel',bores=[((x,.275,-.20),(1,0,0),.0252,.11)])
 ring('UpperBearing',(x,.275,-.20),(1,0,0),.025,.0125,.057,carriage,'brass')
box('PressureSaddle',(-.27,.346,-.20),(.510,.016,.062),carriage,'enamel',.003)
for x in [-.515,-.025]:box('SaddleSupport',(x,.319,-.20),(.029,.057,.063),carriage,'enamel',.003)
# Pressure thread/crutch bears on the carriage, never on spinning rubber.
pressure=begin('PressureScrew',(-.27,.41,-.20))
rod('PressureSpindle',(0,-.049,0),(0,.080,0),.0088,pressure,'iron')
# Real spiral thread crest, joined to its core. Pitch agrees with travel/turn.
points=[]
for i in range(601):
 t=i/600*math.tau*35;points.append(Vector((.0094*math.cos(t),-.035+i/600*.105,.0094*math.sin(t))))
# Curve-to-mesh avoids hundreds of disconnected cylinders.
curve=bpy.data.curves.new('PressureThread','CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_depth=.0011;curve.bevel_resolution=2;curve.use_fill_caps=True
spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
for v,p in zip(spline.points,points):v.co=(*bv(p),1)
obj=bpy.data.objects.new('PressureThread',curve);bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.convert(target='MESH');keep(bpy.context.object,'PressureThread',pressure,'iron')
rod('PressureFoot',(0,-.056,0),(0,-.047,0),.024,pressure,'brass')
rod('PressureCrutchCore',(-.085,.090,0),(.085,.090,0),.010,pressure,'wood',.001)
for x in [-.088,.088]:rod('CrutchEnd',(x-.012,.090,0),(x+.012,.090,0),.015,pressure,'wood',.002)
rod('CrutchSpindle',(0,.070,0),(0,.094,0),.012,pressure,'iron')
release=begin('SafetyRelease',(-.27,.35,-.20))
rod('ReleaseShaft',(-.251,0,0),(.251,0,0),.006,release,'iron')
for x in [-.22,.22]:rod('ReleaseArm',(x,0,0),(x,0,-.091),.005,release,'iron')
rod('SafetyBar',(-.243,0,-.091),(.243,0,-.091),.009,release,'enamel')
for x in [-.245,.245]:ring('ReleaseBush',(-.27+x,.35,-.20),(1,0,0),.011,.0065,.018,wringer,'brass')
reset=begin('SafetyReset',(-.015,.34,-.20))
rod('ResetSpindle',(-.030,0,0),(.025,0,0),.007,reset,'iron')
rod('ResetLever',(0,0,0),(0,0,-.064),.0065,reset,'iron')
rod('ResetGrip',(0,0,-.046),(0,0,-.081),.011,reset,'rubber')
for i,x in enumerate([-.105,.105]):
 parent=begin('HotCock' if i==0 else 'ColdCock',(x,.955,.30))
 rod('CockSpindle',(0,-.027,0),(0,.006,0),.006,parent,'brass')
 rod('CrossHandle',(-.048,0,0),(.048,0,0),.006,parent,'brass')
 rod('EndGrip',(-.048,0,0),(-.025,0,0),.009,parent,'rubber' if i==0 else 'enamel')
parent=begin('DrainCock',(.365,.28,.22))
rod('DrainSpindle',(-.045,0,0),(.008,0,0),.010,parent,'brass')
rod('DrainLever',(0,0,0),(0,.072,0),.007,parent,'brass')
rod('DrainGrip',(0,.050,0),(0,.084,0),.010,parent,'rubber')
for name,z in [('AgitatorDrive',-.09),('WringerDrive',.13)]:
 parent=begin(name,(.367,.315,z))
 rod('ClutchSpindle',(-.035,0,0),(.011,0,0),.010,parent,'iron')
 rod('ClutchLever',(0,0,0),(0,.104,0),.0065,parent,'iron')
 rod('ClutchGrip',(0,.075,0),(0,.124,0),.013,parent,'rubber')
water=begin('WaterSurface',(0,.79,0))
rounded_plate('WaterFace',(0,0,0),.319,.056,.0015,water,'zinc')
# Native source uses zinc only as a review placeholder; runtime water owner
# binds its existing registered dielectric material without changing identity.
# Merge fixed stock by role, preserving every moving pivot and its metric UV.
for parent in parts.values():
 for role in materials:
  objects=[o for o in list(parent.children) if o.type=='MESH' and o.get('finish_role')==role]
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name=parent.name+'_'+role
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  assert len(obj.data.uv_layers)==1,obj.name
  # Derive guides from the final float32-exported UVs after joining stock.
  mesh=obj.data;indices=np.array([l.vertex_index for l in mesh.loops]).reshape(-1,3)
  coords=np.array([v.co[:] for v in mesh.vertices],dtype=np.float32).astype(float)
  uv_values=np.array([d.uv[:] for d in mesh.uv_layers.active.data],dtype=np.float32).reshape(-1,3,2)
  raw_uv=uv_values.copy()
  # Keep every chart right-handed in Blender before glTF flips V.
  a=raw_uv[:,1].astype(float)-raw_uv[:,0];b=raw_uv[:,2].astype(float)-raw_uv[:,0]
  mirrored=a[:,0]*b[:,1]-a[:,1]*b[:,0]<0
  raw_uv[mirrored,:,1]*=-1
  raw_uv-=np.floor(raw_uv.min(axis=1)[:,None])
  mesh.uv_layers.active.data.foreach_set('uv',raw_uv.ravel())
  uv_values=raw_uv.copy();uv_values[:,:,1]=np.float32(1)-uv_values[:,:,1]
  d1=uv_values[:,1].astype(float)-uv_values[:,0];d2=uv_values[:,2].astype(float)-uv_values[:,0]
  det=d1[:,0]*d2[:,1]-d2[:,0]*d1[:,1]
  bad=np.flatnonzero(np.abs(det)<=1e-12)
  for index in bad:
   _,_,chart,_=chart_for_triangle(coords[indices[index]],np.zeros(3),1.)
   raw_uv[index]=chart
  if len(bad):
   mesh.uv_layers.active.data.foreach_set('uv',raw_uv.ravel())
   uv_values=raw_uv.copy();uv_values[:,:,1]=np.float32(1)-uv_values[:,:,1]
   d1=uv_values[:,1].astype(float)-uv_values[:,0];d2=uv_values[:,2].astype(float)-uv_values[:,0]
   det=d1[:,0]*d2[:,1]-d2[:,0]*d1[:,1]
  assert np.all(np.abs(det)>1e-12),(obj.name,float(np.abs(det).min()))
  e1=coords[indices[:,1]]-coords[indices[:,0]];e2=coords[indices[:,2]]-coords[indices[:,0]]
  guide=(e1*d2[:,1,None]-e2*d1[:,1,None])/det[:,None];guide/=np.linalg.norm(guide,axis=1)[:,None]
  guide=np.repeat(guide[:,[0,2,1]],3,axis=0);guide[:,2]*=-1
  mesh.attributes['_tangent_guide'].data.foreach_set('vector',guide.astype(np.float32).ravel())
bpy.context.preferences.filepaths.save_version=0
(ROOT/'tmp/v2-next-20261013/native-construction.json').write_text(json.dumps({'evidence_class':'INERT','stocks':stock_report,'parts':list(parts),'scope':'Complete native fabrication; fit and runtime review required.'},indent=2)+'\n',encoding='utf-8')
print('Export:',export(ROOT,'washer_controls',collection))
