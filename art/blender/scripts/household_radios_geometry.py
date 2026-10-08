"""One source-equivalent cabinet; the original active knob stays separate."""
import ast
helper_path=ROOT/'art/blender/scripts/surface_stock_geometry.py';tree=ast.parse(helper_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'stock','lathe','tube','wire','bearing','group','ring'}],type_ignores=[]),str(helper_path),'exec'))
identity='HouseholdRadio';frames={identity:{'position':[0,0,0],'yaw':0}};retained_stock=[];construction_groups=[];start=len(stock_checks)
# Six-millimetre case stock with actual openings for the original grille/dial.
stock('Bottom',(-.19,-.11,0),(.19,.11,.006),'wood_dark',.001)
stock('Top',(-.19,-.11,.274),(.19,.11,.28),'wood_dark',.001)
for x in [-.19,.184]:stock('Side'+str(x),(x,-.11,.004),(x+.006,.11,.276),'wood_dark',.001)
stock('Back',(-.185,-.11,.005),(.185,-.104,.275),'wood_dark',.0006)
for x in [-.185,.125]:stock('FrontStile'+str(x),(x,.104,.005),(x+.06,.11,.275),'wood_dark',.001)
for label,z0,z1 in [('Sill',.005,.05),('Middle',.085,.115),('Crown',.245,.275)]:stock(label,(-.126,.104,z0),(.126,.11,z1),'wood_dark',.0008)
for x in [-.126,.100]:stock('DialJamb'+str(x),(x,.104,.049),(x+.026,.11,.086),'wood_dark',.0005)
stock('GrilleBacking',(-.127,.096,.113),(.127,.105,.247),'rubber_aged',.0005)
stock('WovenGrille',(-.125,.104,.115),(.125,.107,.245),'linen',.0004)
# Small beads border the cloth; no markings are baked into its weave.
for x in [-.127,.124]:stock('GrilleBead'+str(x),(x,.105,.113),(x+.003,.109,.247),'brass',.0005)
for z in [.113,.244]:stock('GrilleBead'+str(z),(-.126,.105,z),(.126,.109,z+.003),'brass',.0005)
stock('ScaleBack',(-.102,.099,.048),(.102,.105,.087),'wood_dark',.0003)
stock('Scale',(-.100,.1045,.05),(.100,.106,.085),'paper',.0002)
stock('OriginalPointer',(-.015,.106,.052),(-.011,.107,.083),'brass',.0003)
for i in range(17):
 x=-.092+i*.0115
 stock('ScaleTick'+str(i),(x,.106,.055),(x+.0006,.1065,.060 if i%4 else .064),'bakelite',.00006)
# Thin removable glazing sits behind the fitted frame, clear of the pointer.
stock('DialGlass',(-.100,.108,.05),(.100,.1092,.085),'glassish',.00015)
for x in [-.102,.100]:stock('DialBead'+str(x),(x,.105,.048),(x+.002,.112,.087),'brass',.0003)
for z in [.048,.085]:stock('DialBead'+str(z),(-.101,.105,z),(.101,.112,z+.002),'brass',.0003)
for i,x in enumerate([-.14,.14]):
 axial(identity+'_ControlSeat'+str(i),x,.062,[(0,.107),(.018,.107),(.019,.108),(.019,.112),(.015,.113),(0,.113)],identity,'brass',64)
 axial(identity+'_Spindle'+str(i),x,.062,[(0,.107),(.005,.107),(.005,.133),(0,.133)],identity,'metal',48)

def knob(x,front,moving):
 # Closed turned grip with shallow radial flutes. Native geometry is exported
 # in its rest pose and rebased under the original Godot pivot when mounted.
 n=128;profile=[(0,front-.025),(.0145,front-.025),(.017,front-.023),(.017,front-.004),(.0155,front-.001),(0,front)]
 obj=axial(identity+('_ActiveKnob' if moving else '_PassiveKnob'),x,.062,profile,identity,'bakelite',n)
 for v in obj.data.vertices:
  p=v.co+obj.location;dx=p.x-x;dz=p.z-.062;r=math.hypot(dx,dz)
  if r>.016:
   radius=r-.00045*(.5+.5*math.cos(math.atan2(dz,dx)*32));v.co.x=x+dx*radius/r-obj.location.x;v.co.z=.062+dz*radius/r-obj.location.z
 # Fluting is not a circular lathe: metric per-face charts remain exact.
 del obj['uv_axis'];del obj['uv_center']
 if moving:obj['component']='PowerTuningKnob'
 pointer=box(identity+('_ActiveIndex' if moving else '_PassiveIndex'),(x-.0005,front-.0015,.067),(x+.0005,front+.0001,.074),identity,'brass',.00012)
 if moving:pointer['component']='PowerTuningKnob'
 return obj,pointer
knob(-.14,.137,False);knob(.14,.152,True)
for x in [-.16,.16]:
 for y in [-.08,.08]:bearing('original cabinet base',(x,y,0))
retained_stock.append({'assembly':identity,'kind':'source_control','pivot_godot':[.14,.062,-.139],'angle_degrees':42,'authority':'game/scripts/props/baked_furniture_interaction.gd'})
group('CabinetAndSeatedControls',start)
