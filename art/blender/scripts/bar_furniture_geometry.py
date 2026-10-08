"""Construction in small assembly-local frames; called by the native builder."""
# Upright: source width, depth, keybed and top datums, hollow joined case.
frame('Piano',(-1.9,-37.15,-2.58))
for side,x in [('Left',-.55),('Right',.518)]:
    box(side+'CaseStile',(x,-.30,.075),(x+.032,.30,1.18))
    box(side+'Toe',(x,-.28,.02),(x+.032,.44,.085),bevel=.003)
    box(side+'FrontFoot',(x,.27,0),(x+.032,.405,.035),bevel=.003)
    box(side+'RearFoot',(x,-.28,0),(x+.032,-.19,.035),bevel=.003)
    for y in [-.235,.3375]:contact(side+'Bearing'+str(y),(x+.016,y,0),(0,0,1),'retail_bar_stage')
    box(side+'KeyCheek',(x,.295,.595),(x+.032,.505,.705),bevel=.003)
    box(side+'KeyArm',(x,.27,.075),(x+.032,.405,.60),bevel=.003)
box('Back',(-.518,-.30,.065),(.518,-.279,1.18),bevel=.001)
for x in [-.37,0,.37]:box('BackBrace'+str(x),(x-.019,-.278,.1),(x+.019,-.252,1.16),bevel=.001)
box('BottomRail',(-.518,-.28,.065),(.518,.30,.095))
box('Keybed',(-.518,-.02,.584),(.518,.52,.62),'keybed',.002)
box('KeySlip',(-.518,.507,.599),(.518,.526,.645),'keybed',.0015)
box('LowerServicePanel',(-.512,.279,.105),(.512,.298,.57))
for x in [-.43,.43]:screw('LowerPanelScrew'+str(x),(x,.300,.13))
box('UpperPanel',(-.512,.278,.729),(.512,.298,1.162))
for z in [.740,1.145]:box('UpperPanelRail'+str(z),(-.49,.298,z),(.49,.307,z+.013),bevel=.0015)
for x in [-.49,.477]:box('UpperPanelStile'+str(x),(x,.298,.753),(x+.013,.307,1.145),bevel=.0015)
box('RaisedFallboard',(-.506,.277,.67),(.506,.304,.726),'keybed',.002)
rod('FallboardHinge',(-.482,.290,.724),(.482,.290,.724),.003,'brass',32)
box('TopLid',(-.60,-.35,1.18),(.60,.35,1.24),bevel=.003)
rod('LidHinge',(-.49,-.29,1.180),(.49,-.29,1.180),.004,'brass',32)
for i,x in enumerate([-.09,.09]):
    rod('PedalPivot'+str(i),(x-.014,.215,.077),(x+.014,.215,.077),.008,'brass',32)
    box('PedalBearing'+str(i),(x-.019,.190,.065),(x+.019,.237,.097),'iron')
    box('PedalLever'+str(i),(x-.009,.213,.063),(x+.009,.385,.076),'brass',.002)
    box('PedalToe'+str(i),(x-.024,.36,.062),(x+.024,.439,.077),'brass',.004)
    rod('PedalPushRod'+str(i),(x,.214,.081),(x,.214,.36),.004,'iron',24)
    box('PedalUpperBearing'+str(i),(x-.012,.204,.348),(x+.012,.282,.371),'iron')
    joins.append({'id':'pedal_'+str(i),'minimum_floor_clearance_m':.062})
# Explicit passive 73-note C--C adaptation: 43 separated naturals, 30 sharps.
# Black keys sit on relieved rear tails instead of intersecting white solids.
pitch=1/43;black_width=.013;front=.386;back=.305
for i in range(43):
    left=-.5+i*pitch+.0004;right=-.5+(i+1)*pitch-.0004
    has_left=i>0 and (i-1)%7 in [0,1,3,4,5]
    has_right=i<42 and i%7 in [0,1,3,4,5]
    tail_left=left+(black_width*.5 if has_left else 0)
    tail_right=right-(black_width*.5 if has_right else 0)
    # One stepped key solid, finite and closed. Tops retain the source .67 m.
    outline=[(left,.505),(right,.505),(right,front),(tail_right,front),(tail_right,back),(tail_left,back),(tail_left,front),(left,front)]
    outline=[p for j,p in enumerate(outline) if p!=outline[j-1]]
    while True:
        straight=next((j for j,p in enumerate(outline) if abs((p[0]-outline[j-1][0])*(outline[(j+1)%len(outline)][1]-p[1])-(p[1]-outline[j-1][1])*(outline[(j+1)%len(outline)][0]-p[0]))<1e-14),None)
        if straight is None:break
        outline.pop(straight)
    m=len(outline)
    verts=[(x,y,z) for z in [.624,.67] for x,y in outline]
    faces=[tuple(reversed(range(m))),tuple(range(m,2*m))]+[(j,(j+1)%m,m+(j+1)%m,m+j) for j in range(m)]
    solid('Natural%02d'%i,verts,faces,'key_white_b' if i%11==3 else 'key_white',.00025)
    if has_right:
        x=-.5+(i+1)*pitch
        box('Accidental%02d'%i,(x-black_width*.5,.306,.625),(x+black_width*.5,.383,.686),'key_black',.0005)

# Original microphone pose: front capsule aims along the authored boom.
frame('Microphone',(-.7,-36.75,-2.58),Matrix.Rotation(math.pi,3,'Z'))
profile=[(.134,0),(.134,.006),(.112,.018),(.024,.033),(.019,.045)]
n=80;vertices=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for r,z in profile for i in range(n)]
solid('WeightedBase',vertices,[tuple(reversed(range(n)))]+[(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(len(profile)-1) for i in range(n)]+[tuple(range((len(profile)-1)*n,len(profile)*n))],'iron')
for i in range(8):
    a=i*math.tau/8;contact('BaseBearing'+str(i),(.09*math.cos(a),.09*math.sin(a),0),(0,0,1),'retail_bar_stage')
rod('StandLower',(0,0,.040),(0,0,.72),.011,'nickel',48)
rod('StandUpper',(0,0,.68),(0,0,1.08),.009,'nickel',48)
ring('HeightCollar',(0,0,.69),(0,0,.735),.017,.0091,'iron',48)
rod('HeightThumbScrew',(.011,0,.708),(.027,0,.708),.003,'brass',24)
rod('ThumbKnob',(.023,0,.708),(.034,0,.708),.007,'iron',32)
rod('Boom',(0,0,1.08),(0,.30,1.32),.008,'nickel',48)
rod('BoomJoint',(-.017,0,1.08),(.017,0,1.08),.018,'iron',48)
rod('JointClamp',(.017,0,1.08),(.023,0,1.08),.010,'brass',32)
head_a=Vector((0,.30,1.32));head_b=Vector((0,.355,1.278));head_axis=(head_b-head_a).normalized()
ring('CapsuleCase',head_a,head_b,.023,.019,'iron',64)
rod('CapsuleRear',head_a-head_axis*.002,head_a+head_axis*.003,.022,'iron',64)
rod('GrilleBacking',head_b-head_axis*.004,head_b-head_axis*.002,.0187,'cloth',64)
ring('GrilleRim',head_b-head_axis*.002,head_b,.023,.019,'nickel',64)
u=Vector((1,0,0));v=head_axis.cross(u)
for i in range(-5,6):
    offset=i*.003;half=math.sqrt(.0189**2-offset**2)
    rod('GrilleWire'+str(i),head_b+u*offset-v*half,head_b+u*offset+v*half,.0005,'nickel',12)
for i in [-1,1]:screw('CapsuleClosure'+str(i),head_a+head_axis*.001+u*i*.014,-head_axis,.0018)
# Fixed flex is clipped to the stand and terminates at both seated fittings.
path=[(.024,.006,.035),(.023,.009,.075),(.018,.016,.11),(.015,.018,.26),(.014,.018,.52),(.014,.018,.76),(.014,.018,1.045),(.014,.036,1.075),(.014,.16,1.176),(.014,.272,1.282),(.009,.299,1.309)]
for i,(a,b) in enumerate(zip(path,path[1:])):rod('ClothFlex'+str(i),a,b,.003,'cloth',24)
for z in [.25,.65,.98]:
    rod('FlexClip'+str(z),(0,.009,z),(.014,.018,z),.0015,'brass',16)
ring('BaseSocket',(.024,.006,.025),(.024,.006,.044),.007,.0031,'iron',32)
ring('HeadGland',path[-2],path[-1],.006,.0031,'iron',32)

# Target/cabinet frame: local X is along wall, local Y faces the room.
wall_frame=Matrix(((0,1,0),(-1,0,0),(0,0,1)))
frame('DartsCabinet',(-11.5,-33,-1.69),wall_frame)
box('Back',(-.55,0,0),(.55,.012,1.24),bevel=.001)
for x in [-.55,.525]:box('Stile'+str(x),(x,.012,0),(x+.025,.070,1.24),bevel=.002)
for z in [0,1.215]:box('Rail'+str(z),(-.525,.012,z),(.525,.070,z+.025),bevel=.002)
for x in [-.49,.49]:
    for z in [.065,1.175]:
        screw('BackScrew'+str(x)+str(z),(x,.014,z))
        contact('WallBearing'+str(x)+str(z),(x,0,z),(0,1,0),'retail_bar_wall_w')
# Keep both source parked leaf envelopes, including the omitted left leaf.
for side,lo,hi in [(-1,-1.08,-.56),(1,.56,1.08)]:
    first_stock=len(stocks.objects)
    for x in [lo,hi-.024]:box('DoorStile'+str(side)+str(x),(x,.010,.02),(x+.024,.060,1.22),bevel=.002)
    for z in [.02,1.196]:box('DoorRail'+str(side)+str(z),(lo+.024,.010,z),(hi-.024,.060,z+.024),bevel=.002)
    box('DoorInfill'+str(side),(lo+.024,.027,.044),(hi-.024,.040,1.196),bevel=.001)
    hx=side*.555
    for z in [.19,1.05]:
        rod('HingeKnuckle'+str(side)+str(z),(hx,.042,z-.03),(hx,.042,z+.03),.005,'brass',32)
        for x in [hx-.02,hx+.008]:box('HingeLeaf'+str(side)+str(x)+str(z),(x,.037,z-.018),(x+.012,.047,z+.018),'brass',.0004)
    if side==-1:box('DoorStop'+str(side),(side*.57-.006,.006,.62),(side*.57+.006,.028,.65),'iron')
    screw('DoorCatch'+str(side),(side*1.036,.063,.62))
    if side==1:
        # The never-exported leaf cannot occupy the gallery's retained
        # pictures. Park it at 90 degrees on its source hinge, keeping its
        # span and height. This is a fixed fitting, not a new moving door.
        pivot=Vector((.555,.042,0))
        turn=Matrix.Translation(pivot)@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation(-pivot)
        for obj in list(stocks.objects)[first_stock:]:
            if '__Door' in obj.name or '__HingeLeaf10.563' in obj.name:obj.data.transform(turn)
# A timber substrate retains all original target dimensions and radial marks.
rod('TargetBack',(0,.060,.62),(0,.080,.62),.245,'case',128)
rod('TargetBlank',(0,.080,.62),(0,.092,.62),.2255,'target',128)
ring('MountingRim',(0,.080,.62),(0,.097,.62),.245,.227,'iron',128)
for r in [.099,.107,.162,.17]:ring('ScoringWire'+str(r),(0,.092,.62),(0,.096,.62),r+.0006,r-.0006,'brass',128)
ring('OuterBull',(0,.092,.62),(0,.095,.62),.0159,.00635,'key_white',64)
rod('InnerBull',(0,.092,.62),(0,.095,.62),.00635,'key_black',64)
for i in range(7):
    angle=i*math.tau/7
    for band,(r0,r1) in enumerate([(.0159,.099),(.099,.107),(.107,.162),(.162,.170)]):
        n=24;angles=[angle-math.pi/7+j*(math.tau/7)/n for j in range(n+1)]
        outline=[(-r*math.sin(a),.62+r*math.cos(a)) for r,aa in [(r1,angles),(r0,list(reversed(angles)))] for a in aa];m=len(outline)
        verts=[(x,y,z) for y in [.092,.094] for x,z in outline]
        faces=[tuple(reversed(range(m))),tuple(range(m,2*m))]+[(j,(j+1)%m,m+(j+1)%m,m+j) for j in range(m)]
        field=solid('ScoringField'+str(i)+'_'+str(band),verts,faces,'sector_'+str(i)+('_single' if band in [0,2] else ''))
        if band in [0,2]:
            # Small closed tapered depressions, concentrated in the throwing
            # fields. The substrate, scoring wires and sampled axes stay whole.
            for mark in range(3):
                a=angle+(.11,.15,-.09)[mark]
                r=(.071 if band==0 else .135)+(.003,-.006,.009)[mark]
                at=Vector((-r*math.sin(a),.094,.62+r*math.cos(a)))
                bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.00018,radius2=.0009,depth=.0015)
                cutter=bpy.context.object
                cutter.rotation_euler=Vector((0,1,0)).to_track_quat('Z','Y').to_euler()
                cutter.location=at-Vector((0,.0005,0))
                bpy.context.view_layer.update()
                cutter.matrix_world=field.matrix_world@cutter.matrix_world
                bpy.context.view_layer.objects.active=field
                mod=field.modifiers.new('Shallow point impression','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
                bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    # Boundaries lie half way between existing seven source group axes.
    a=angle+math.pi/7
    rod('Divider'+str(i),(-.0159*math.sin(a),.095,.62+.0159*math.cos(a)),(-.170*math.sin(a),.095,.62+.170*math.cos(a)),.0006,'brass',16)
for i in range(4):
    a=(i+.5)*math.tau/4;screw('TargetFixing'+str(i),(.236*math.sin(a),.098,.62+.236*math.cos(a)))

frame('ScorePanel',(-11.5,-31.34,-1.41),wall_frame)
box('ScoreBacking',(-.44,.010,.04),(.44,.050,.90),'score',.001)
for x in [-.465,.44]:box('ScoreStile'+str(x),(x,.008,.04),(x+.025,.060,.915),bevel=.001)
box('ScoreCrown',(-.44,.008,.89),(.44,.060,.915),bevel=.001)
box('ChalkLedge',(-.48,0,0),(.48,.08,.05),bevel=.002)
for x in [-.40,.40]:
    for z in [.065,.855]:
        box('WallPacker'+str(x)+str(z),(x-.015,0,z-.015),(x+.015,.010,z+.015),bevel=.0005)
        screw('ScoreFixing'+str(x)+str(z),(x,.052,z))
        contact('WallBearing'+str(x)+str(z),(x,0,z),(0,1,0),'retail_bar_wall_w')
