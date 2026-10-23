"""Compact fictional type-cylinder printer, laid out from one print datum.

All coordinates are Godot metres. The web travels from the lower roll,
around the platen, then upward across the copy bed. Holes are machined into
the carrying plates before bushings/shafts are installed. No operating-state
or gameplay ownership is defined by this authoring module.
"""
import math
import bpy,bmesh
from mathutils import Matrix,Vector

def build(api):
    box,cyl,tube,rod,strip,pivot,screw=[api[n] for n in ['box','cylinder','tube','rod','strip','pivot','screw']]
    coords,finish=api['coords'],api['finish']
    W,H,PW,PH,PX,PY=.214,.193,.140,.114,0.,.028
    P=-.030;Z=.044;R=.008
    paper_z=Z+R+.0003
    SX,SY,SZ=.083,-.058,.016
    rail_y=[-.067,-.057];rail_z=.066
    head_x=-.059

    def profile(name,points,at,depth,plane='yz',surface='Steel',group='Fixed'):
        """One closed contoured casting/pressing, not overlapping blocks."""
        rounded=[]
        for i,p in enumerate(points):
            p=Vector(p);before=Vector(points[i-1])-p;after=Vector(points[(i+1)%len(points)])-p
            amount=min(.0015,before.length*.2,after.length*.2)
            a=p+before.normalized()*amount;b=p+after.normalized()*amount
            for j in range(5):
                t=j/4;rounded.append(a*(1-t)**2+p*2*t*(1-t)+b*t*t)
        points=rounded
        vertices=[]
        for h in [-depth/2,depth/2]:
            for u,v in points:
                q={'yz':(h,u,v),'xy':(u,v,h),'xz':(u,h,v)}[plane]
                vertices.append(coords([q[i]+at[i] for i in range(3)]))
        n=len(points);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);api['stocks'].objects.link(obj)
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        return finish(obj,name,group,surface)

    def cut(obj,at,radius=None,size=None,axis='x'):
        if radius:
            bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=.12,location=coords(at))
            tool=bpy.context.object
            if axis=='x':tool.rotation_euler[1]=math.pi/2
            elif axis=='z':tool.rotation_euler[0]=math.pi/2
        else:
            bpy.ops.mesh.primitive_cube_add(size=1,location=coords(at));tool=bpy.context.object
            tool.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
            bevel=tool.modifiers.new('Radiused machining corners','BEVEL');bevel.width=min(.0015,min(size)/5);bevel.segments=4
            bpy.ops.object.modifier_apply(modifier=bevel.name)
        mod=obj.modifiers.new('Machined clearance','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(tool,do_unlink=True)

    # Case is a shallow shell. Cartridge feet bolt to its front return lip;
    # dry cells stay behind the paper supply, separated in depth.
    for x in [-W/2+.0045,W/2-.0045]:box('Case side',(x,0,0),(.009,H,.055),'Case',bevel=.002)
    for y in [-H/2+.0045,H/2-.0045]:box('Case end',(0,y,0),(W-.018,.009,.055),'Case',bevel=.002)
    box('Rear pan',(0,0,-.029),(W-.010,H-.010,.004),'Steel')
    for x in [-.093,.093]:box('Chassis return',(x,0,.029),(.016,H-.016,.003),'Steel')

    # A common side-frame profile carries reel, platen and slide-rail bores.
    outline=[(-.076,.008),(-.076,.038),(-.064,.051),(-.055,.073),(-.016,.073),
             (-.008,.055),(.087,.055),(.093,.049),(.093,.025),(.085,.018),(-.054,.018),(-.060,.008)]
    for x in [-SX,SX]:
        frame=profile('Cartridge side frame',outline,(x,0,0),.003)
        for y,z,r in [(P,Z,.00385),(SY,SZ,.00385)]+[(y,rail_z,.00285) for y in rail_y]:
            cut(frame,(x,y,z),radius=r)
        cut(frame,(x,.038,.031),size=(.012,.065,.013))
        for y in [-.061,.070]:
            foot=box('Bolted cartridge foot',(x+(-.004 if x<0 else .004),y,.028),(.018,.012,.003),'Steel')
            cut(foot,(x,y,.028),radius=.0013,axis='z')
            screw((x,y,.031))
        for y,z in [(P,Z),(SY,SZ)]:tube('Pressed bronze bush',(x,y,z),.0038,.00245,.0032,'Brass',axis='x')
        for y in rail_y:tube('Rail frame bush',(x,y,rail_z),.0028,.0016,.0032,'Brass',axis='x',sides=20)

    # Through shafts are retained outside bored frame cheeks.
    cyl('Platen shaft',(0,P,Z),.0023,W+.026,'Steel',axis='x',sides=20)
    cyl('Platen',(0,P,Z),R,PW+.009,'Rubber','Platen',axis='x',sides=40);pivot('Platen',(0,P,Z))
    for i,x in enumerate([-W/2-.007,W/2+.007]):
        group='FeedWheel'+str(i);pivot(group,(x,P,Z));api['knurl']('Platen finger wheel',(x,P,Z),.0075,.005,group,'x',20)
    for x in [-SX-.003,SX+.003]:tube('Shaft circlip',(x,P,Z),.0032,.0023,.001,'Steel',axis='x',sides=20)
    cyl('Supply reel spindle',(0,SY,SZ),.0023,.179,'Steel',axis='x',sides=20)
    cyl('Unprinted paper roll',(0,SY,SZ),.012,PW+.002,'Paper',axis='x',sides=40)

    # Analytic external tangent between the supply roll and platen. Each web
    # point is outside the roller's physical radius, including sheet thickness.
    def tangent(c1,r1,c2,r2):
        d=Vector(c2)-Vector(c1);u=d.normalized();k=(r1-r2)/d.length
        n=u*k+Vector((-u.y,u.x))*math.sqrt(1-k*k)
        if n.y<0:n=u*k-Vector((-u.y,u.x))*math.sqrt(1-k*k)
        return Vector(c1)+r1*n,Vector(c2)+r2*n,n
    a,b,n=tangent((SY,SZ),.0122,(P,Z),.0082)
    theta=math.atan2(n.x,n.y)
    web=[((0,a.x,a.y),(PW/2,0,0)),((0,b.x,b.y),(PW/2,0,0))]
    for j in range(1,13):
        t=theta*(1-j/12);web.append(((0,P+.0082*math.sin(t),Z+.0082*math.cos(t)),(PW/2,0,0)))
    web.append(((0,PY-PH/2,paper_z),(PW/2,0,0)))
    strip('Unbroken paper feed',web,group='Paper')
    box('Paper',(0,PY,paper_z),(PW,PH,.0003),'Paper','Paper',bevel=0);pivot('Paper',(0,PY,paper_z))
    box('Copy support bed',(0,PY,paper_z-.00115),(PW+.003,PH+.004,.002),'Steel')
    # Two pressure rollers hold the sheet to the driven platen at its edges.
    for x in [-.067,.067]:
        cyl('Feed pressure roller',(x,P,Z+.0114),.003,.006,'Rubber',axis='x',sides=24)
        arm=profile('Pressure roller fork',[(-.008,0),(-.008,.005),(.007,.005),(.010,.002),(.010,0)],
                    (x,P-.003,Z+.0114),.003,plane='yz')
        cut(arm,(x,P,Z+.0114),radius=.0011)
        cyl('Pressure roller pin',(x,P,Z+.0114),.001,.010,'Brass',axis='x',sides=12)
    box('Top tear bar',(0,.087,.054),(PW+.009,.003,.003),'Brass')
    for x in [-.076,.076]:
        box('Bed flange',(x,.030,.045),(.006,.116,.019),'Steel')
        for y in [.010,.069]:screw((x,y,.055))

    # The carriage is a bored bridge sliding on two parallel ground rods.
    for y in rail_y:cyl('Carriage way rod',(0,y,rail_z),.0015,.176,'Steel',axis='x',sides=20)
    bridge=profile('Carriage bearing bridge',[(-.010,-.007),(.010,-.007),(.013,-.004),(.013,.007),(-.013,.007),(-.013,-.004)],
                   (head_x,-.062,rail_z),.016,plane='yz',surface='Brass',group='Carriage')
    for y in rail_y:cut(bridge,(head_x,y,rail_z),radius=.00165)
    cut(bridge,(head_x,-.0515,.068),size=(.0035,.005,.005))
    pivot('Carriage',(head_x,-.062,rail_z))

    # Three banks of sixteen type seats select by rotation + axial shift.
    # This is a fictional compact type-cylinder, not a claimed Hammond copy.
    # The selected seat strikes the ribbon/paper against the fixed platen.
    rotor_z=.068;type_y=P
    fork=profile('Hollow print-head cradle',[(-.020,-.020),(.020,-.020),(.022,-.018),(.022,.013),(.020,.015),(-.020,.015),(-.022,.013),(-.022,-.018)],
                 (head_x,type_y,rotor_z),.007,plane='xy',surface='Brass',group='Type_hammer')
    cut(fork,(head_x,type_y,rotor_z),size=(.0324,.024,.030))
    cut(fork,(head_x,type_y,rotor_z),radius=.00165,axis='y')
    pivot('Type_hammer',(head_x,type_y,rotor_z))
    pivot('TypeSelector',(head_x,type_y,rotor_z))
    cyl('Type selector sleeve',(head_x,type_y,rotor_z),.0135,.0137,'Steel','TypeSelector',axis='y',sides=48)
    cyl('Selector sliding spindle',(head_x,type_y,rotor_z),.0015,.034,'Steel','TypeSelector',axis='y',sides=16)
    for row in [-1,0,1]:
        for j in range(16):
            angle=j*math.tau/16
            pad=box('Replaceable type seat',(head_x+.01365*math.sin(angle),type_y+row*.0045,rotor_z-.01365*math.cos(angle)),
                    (.0036,.0038,.0005),'Steel','TypeSelector',bevel=.0001)
            rot=Matrix.Rotation(-angle,4,'Z')
            # Rotate pads around their own Y-axis centre, not the whole sleeve.
            pos=coords((head_x+.01365*math.sin(angle),type_y+row*.0045,rotor_z-.01365*math.cos(angle)))
            pad.data.transform(Matrix.Translation(pos) @ rot @ Matrix.Translation(-pos))
    # A pair of thin parallel cantilever leaves retains the impression cradle.
    # The bank spindle clears both way rods throughout its +/-4.5mm shift.
    for x in [head_x-.017,head_x+.017]:
        strip('Impression flexure leaf',[
            ((x,-.064,.073),( .002,0,0)),((x,-.058,.074),(.002,0,0)),
            ((x,-.046,.0715),(.002,0,0))],surface='Steel',group='Carriage',thickness=.00015)
        box('Flexure root clamp',(x,-.063,.0735),(.005,.004,.001),'Brass','Carriage')
        box('Flexure end clamp',(x,-.046,.072),(.005,.004,.001),'Brass','Type_hammer')

    # Horizontal-axis ribbon reels keep ribbon width vertical all the way to
    # the printing line: no unexplained quarter-turns or floating ribbon ends.
    for side in [-1,1]:
        x=side*.094;group='SupplySpool' if side<0 else 'TakeupSpool'
        bracket=profile('Ribbon spindle bracket',[(side*.080,-.053),(side*.101,-.053),(side*.101,-.038),(side*.088,-.038),(side*.088,-.046),(side*.080,-.046)],
                        (0,0,.066),.006,plane='xy')
        cut(bracket,(x,-.044,.066),radius=.00165,axis='y')
        cyl('Ribbon reel spindle',(x,-.034,.066),.0015,.025,'Steel',axis='y',sides=16)
        pivot(group,(x,P,.066));tube('Ribbon wound core',(x,P,.066),.009,.0016,.004,'Rubber',group,axis='y')
        for y in [P-.003,P+.003]:tube('Ribbon spool flange',(x,y,.066),.010,.0016,.0008,'Steel',group,axis='y',sides=24)
        cyl('Spool retaining nut',(x,P+.004,.066),.003,.0015,'Brass',group,axis='y',sides=8)
        rod('Ribbon guide stalk',(side*.072,P-.010,.058),(side*.072,P+.004,.058),.001,'Steel')
    strip('Ink ribbon',[((-.094,P,.057),(0,.002,0)),((-.072,P,.0528),(0,.002,0)),
                       ((.072,P,.0528),(0,.002,0)),((.094,P,.057),(0,.002,0))],surface='Rubber',thickness=.00018)

    # Lamp is retained by a split clamp in a profiled mounting yoke.
    lx,ly=-.079,.069
    lamp=profile('Bent lamp yoke',[(-.026,0),(.026,0),(.026,-.026),(.020,-.026),(.020,-.006),(-.020,-.006),(-.020,-.026),(-.026,-.026)],
                 (lx,ly,-.034),.020,plane='xz')
    cut(lamp,(lx,ly,-.052),radius=.0021,axis='x')
    tube('Lamp shell',(lx,ly,-.060),.018,.0155,.036,'Brass',sides=32)
    tube('Threaded lens bezel',(lx,ly,-.077),.019,.0145,.005,'Brass',sides=32)
    cyl('TorchLens',(lx,ly,-.079),.0148,.0015,'Lens','TorchLens',sides=32)
    for x in [lx-.023,lx+.023]:cyl('Lamp clamp trunnion',(x,ly,-.052),.002,.012,'Brass',axis='x',sides=16)

    # Simple case-level controls retain their existing identities.
    cover_w=.134;door_y=-H/2+.018
    box('Service door',(0,door_y,.039),(cover_w,.028,.004),'Case','ServiceCover');pivot('ServiceCover',(0,-.094,.036))
    for i in range(15):tube('Door hinge',( -.063+i*.009,-.094,.036),.0025,.0012,.0085,'Brass','ServiceCover' if i%2 else 'Fixed',axis='x',sides=12)
    rod('Door hinge pin',(-.070,-.094,.036),(.070,-.094,.036),.0011)
    for x in [-.028,.028]:cyl('Dry cell',(x,-.070,-.015),.010,.036,'Rubber',axis='y',sides=20)
    for x,name in [(-.028,'OrderJewel'),(0,'NetJewel'),(.028,'LampJewel')]:
        cyl('Jewel bezel',(x,-.059,.048),.004,.004,'Brass',sides=20)
        cyl(name,(x,-.059,.0505),.0028,.001,'Porcelain',name,sides=20)
    for x,name in [(-.094,'LampSwitch'),(.094,'RadioSwitch')]:
        cyl('Panel switch bush',(x,-.079,.034),.004,.010,'Brass',sides=8)
        pivot(name,(x,-.079,.039));rod('Switch lever',(x,-.079,.039),(x,-.067,.045),.0015,'Steel',name)
    ax=.094;ay=H/2
    cyl('Aerial socket',(ax,ay+.003,.005),.006,.012,'Porcelain',axis='y',sides=16)
    pivot('Aerial',(ax,ay+.009,.005));rod('Aerial',(ax,ay+.009,.005),(ax,ay+.053,.005),.0015,'Brass','Aerial')
    pivot('FocusWheel',(.114,.038,0));cyl('Reading wheel',(.114,.038,0),.009,.006,'Brass','FocusWheel',axis='x',sides=24)
    rod('Reading shaft',(.103,.038,0),(.116,.038,0),.0018)
    box('Rear strap',(0,0,-.037),(.166,.024,.004),'Leather')
    for x in [-.083,.083]:box('Strap attachment',(x,0,-.034),(.008,.030,.006),'Brass')
    # These are native layout assertions, not runtime mechanical proof.
    # mathutils coordinates are float32; ten nanometres bounds their rounding.
    assert abs((a-Vector((SY,SZ))).length-.0122)<1e-8
    assert abs((b-Vector((P,Z))).length-.0082)<1e-8
    assert .00245-.0023>.0001 and .00165-.0015>.0001
    # Exact booleans can leave redundant coplanar boundary vertices. Remove
    # those in the owning editable stock before triangulation/metric charts.
    for obj in api['stocks'].objects:
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.dissolve_limit(bm,angle_limit=1e-5,use_dissolve_boundaries=True,
                                verts=list(bm.verts),edges=list(bm.edges))
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    return W,H,PW,PH,PX,PY,paper_z,door_y,cover_w,lx,ly,-.062
