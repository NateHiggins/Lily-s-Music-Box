"""Source-fitted Hunters Point houses; LPC0450 forms, authored AU dimensions.

No occupied interiors, shop access or historical parcel/paint claim. All lower
bodies retain walls, floors, entries, roof volumes, dormers and joinery.
"""
import math
from mathutils import Vector
from city_industrial_architecture import MillLofts,EasternRows
from city_horizon_geometry import cornice_ring,offset_outline,extrusion


class ResidentialHouses(MillLofts):
    STYLES={'italianate_2109','mansard_2153','gable_2136'}
    covered=EasternRows.covered

    def __init__(self,row,emit,neighbours,lower=False):
        self.row=row;self.name=row['id'];self.emit=emit;self.neighbours=neighbours
        self.study=row['architecture'];self.style=self.study['style']
        assert self.style in self.STYLES
        self.lower=lower;self.steps=1;self.arch_steps=8 if lower else 16
        self.windows=[];self.bearings=[];self.entries=[];self.seams=[]
        self.parts=0;self.min_volume=math.inf;self.levels=[0.]
        for h in self.study['floor_heights_m']:self.levels.append(self.levels[-1]+h)
        assert abs(self.levels[-1]-row['height_m'])<1e-6
        a,b,c,d=row['rect'];self.rect=(a,-d+self.study['front_inset_m'],c,-b)
        self.eave=self.levels[-1] if self.style=='italianate_2109' else self.levels[-2]
        self.basement=False
        self.dormer=False

    def add(self,key,vertices,faces):
        if self.basement and key==self.row['wall_key']:key='concrete'
        elif self.dormer and key==self.row['wall_key']:key='door_paint'
        return super().add(key,vertices,faces)

    def wall_stock(self,O,U,N,lo,hi,length):
        if self.style!='gable_2136':
            l,back,z=lo;r,front,Z=hi
            if abs(l)<1e-7 or abs(r-length)<1e-7:
                return super().wall_stock(O,U,N,lo,hi,length)
            # These are abutting structural wall panels, not separate trim.
            # Rounding every panel's U/Z corners leaves14mm roof-seat notches
            # at internal bay joints. Preserve the flat receiving cap instead.
            self.profile(self.row['wall_key'],O,U,N,[(l,z),(r,z),(r,Z),(l,Z)],back,front)
            return
        if self.basement:return super().wall_stock(O,U,N,lo,hi,length)
        # Closed sheathing beneath individual lapped boards. Cut each board at
        # the same real opening; do not texture a window onto a solid wall.
        l,back,z=lo;r,front,Z=hi
        self.profile('timber',O,U,N,[(l,z),(r,z),(r,Z),(l,Z)],back,front)
        pitch=.145
        for i in range(math.floor(z/pitch),math.ceil(Z/pitch)):
            low=max(z,i*pitch);high=min(Z,(i+1)*pitch)
            if high-low<1e-7:continue
            # One building-wide course phase survives clipping at windows and
            # floor joints. Adaptive per-panel counts visibly broke alignment.
            lower_front=.035-.031*(low-i*pitch)/pitch
            upper_front=.035-.031*(high-i*pitch)/pitch
            local=[(l,-.004,low),(r,-.004,low),(r,lower_front,low),(l,lower_front,low),
                   (l,-.004,high),(r,-.004,high),(r,upper_front,high),(l,upper_front,high)]
            vertices=[tuple(O+U*a+N*b+Vector((0,0,c))) for a,b,c in local]
            self.add('door_paint',vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

    def panel(self,O,U,N,l,r,z0,z1,length,front=False,door=False,basement=False):
        if basement and door:
            self.wall_stock(O,U,N,(l,-.4,z0),(r,0,z1),length);return
        width=1.12 if door else 1.03 if front else 1.08
        width=min(width,r-l-.9);center=(l+r)/2;left=center-width/2;right=center+width/2
        low=z0+(.025 if door else .18 if basement else .59)
        high=z0+2.65 if door else z1-(.20 if basement else .48)
        assert z0<low<high<z1,(self.name,z0,z1,low,high)
        arched=front and not basement and self.style=='italianate_2109' and not door
        rise=.16 if arched else 0.;spring=high-rise
        for a,b in [((l,-.4,z0),(left,0,z1)),((right,-.4,z0),(r,0,z1)),
                    ((left,-.4,z0),(right,0,low)),((left,-.4,high),(right,0,z1))]:
            self.wall_stock(O,U,N,a,b,length)
        if arched:
            head=[(center-width/2*math.cos(i*math.pi/self.arch_steps),spring+rise*math.sin(i*math.pi/self.arch_steps)) for i in range(self.arch_steps+1)]
            for a,b in zip(head,head[1:]):
                p=[a,b,(b[0],high),(a[0],high)]
                p=[v for i,v in enumerate(p) if v!=p[i-1]]
                if len(p)>2:self.profile(self.row['wall_key'],O,U,N,p,-.4,0)
            self.arch('limestone',O,U,N,center,spring,width/2,rise,.09,-.10,.11)
        else:head=[(left,high),(right,high)]
        self.profile('door_paint' if door else 'mirror_aged',O,U,N,
                     [(left+.02,low+.02),(right-.02,low+.02)]+[(x,h-.02) for x,h in reversed(head)],-.205,-.17)
        self.wood_frame(O,U,N,left,right,low,high)
        self.stock('limestone',O,U,N,(left-.075,-.21,low-.075),(right+.075,.09,low),.008)
        if not arched:self.stock('limestone',O,U,N,(left-.08,-.22,high),(right+.08,.07,high+.13),.008)
        if door:
            self.stock('door_paint',O,U,N,(center-.025,-.16,low+.02),(center+.025,-.08,high-.04),.003)
            for a,b in [(left+.08,center-.06),(center+.06,right-.08)]:
                for z,Z in [(low+.12,low+.85),(low+1.04,high-.14)]:
                    self.stock('door_paint',O,U,N,(a,-.165,z),(b,-.13,Z),.01)
            self.stock('bronze_sheet',O,U,N,(center+.10,-.085,low+1.0),(center+.13,-.025,low+1.24),.003)
            if self.style=='italianate_2109':
                self.profile('limestone',O,U,N,[(left-.17,high+.15),(right+.17,high+.15),(center,high+.52)],-.05,.19)
                for at in [left-.12,right+.12]:
                    self.stock('limestone',O,U,N,(at-.065,-.08,high-.02),(at+.065,.16,high+.16),.008)
            self.stoop(O,U,N,left,right,low)
            self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,low+1.2))),kind='closed_scenic_leaf'))
        else:
            middle=(low+spring)/2
            self.stock('door_paint',O,U,N,(left+.06,-.19,middle-.028),(right-.06,-.08,middle+.028),.003)
            if not basement:
                self.stock('door_paint',O,U,N,(center-.014,-.185,low+.06),(center+.014,-.09,spring-.05),.002)
            sample=O+U*(left+width*.27)+Vector((0,0,low+(spring-low)*.28))
            self.windows.append(dict(building=self.name,point=list(sample),normal=list(N),recess_m=.17))

    def stoop(self,O,U,N,left,right,top):
        count=5;run=.25;landing=.23
        for i in range(count):
            self.stock('limestone',O,U,N,(left-.13,(count-i-1)*run+landing,0),
                       (right+.13,(count-i)*run+landing,top*(i+1)/count),.008)
        self.stock('limestone',O,U,N,(left-.13,-.05,0),(right+.13,landing,top),.008)
        # Rail ends stand on actual first tread and landing; preserve every
        # post/handrail in the lower body, simplifying only arrises.
        for at in [left-.10,right+.10]:
            first=(count-.5)*run+landing;last=landing/2
            for depth,height in [(first,top/count),(last,top)]:
                self.stock('cast_iron',O,U,N,(at-.022,depth-.022,height),(at+.022,depth+.022,height+.90),.002)
            self.profile('cast_iron',O,U,N,[(at-.022,top/count+.88),(at+.022,top/count+.88),(at+.022,top/count+.925),(at-.022,top/count+.925)],first-.025,first+.025)
            a=O+U*at+N*first+Vector((0,0,top/count+.90));b=O+U*at+N*last+Vector((0,0,top+.90))
            axis=(b-a).normalized();side=Vector((axis.y,-axis.x,0)).normalized();up=axis.cross(side)
            v=[tuple(p+side*s+up*t) for p in [a,b] for s,t in [(-.023,-.023),(.023,-.023),(.023,.023),(-.023,.023)]]
            self.add('cast_iron',v,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

    def flat_roof(self):
        x,y,X,Y=self.rect;z=self.eave;outline=[(X,y),(x,y),(x,Y),(X,Y)]
        self.box('galvanized_roof',(x,y,z),(X,Y,z+.14))
        for inset,width,low,high in [(0,.16,z-.15,z), (0,.32,z,z+.14),(-.18,.18,z+.14,z+.54)]:
            v,f=cornice_ring(offset_outline(outline,inset),width,low,high);self.add('door_paint',v,f)
        O,U,N,L=self.sides(self.rect)[0]
        for at in [.22,L/3,2*L/3,L-.22]:
            self.stock('door_paint',O,U,N,(at-.085,-.05,z-.40),(at+.085,.25,z),.012)
        for i in range(4):
            a=Vector((*outline[i],z+.14));b=Vector((*outline[(i+1)%4],z+.14));t=(b-a).normalized();n=Vector((-t.y,t.x,0))
            self.bearings.append(dict(building=self.name,wall_key=self.row['wall_key'],point=list((a+b)/2-n*.18),outside_probe=list((a+b)/2+n*.10)))

    def roof_sheet(self,points,key='city_slate'):
        # A closed vertical-thickness sheet retains the exact visible slope.
        n=len(points);v=[(x,y,z+dz) for dz in [0,.08] for x,y,z in points]
        f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        # Clockwise inputs are corrected before emission; signed-volume guard
        # in add() independently rejects incorrect shell winding.
        area=sum(x*Y-X*y for (x,y,_),(X,Y,_) in zip(points,points[1:]+points[:1]))
        if area<0:f=[tuple(reversed(q)) for q in f]
        self.add(key,v,f)

    def pitched_eave_course(self,bottom,top):
        x,y,X,Y=self.rect;outline=[(X,y),(x,y),(x,Y),(X,Y)]
        sides=self.sides(self.rect)
        west=0. if self.covered(*sides[3][:3],0,sides[3][3],self.eave,[]) else .26
        east=0. if self.covered(*sides[1][:3],0,sides[1][3],self.eave,[]) else .26
        # Common-eave neighbours meet at the parcel plane. Projecting both
        # courses260mm across it would leave coincident visible roof bands.
        inner=offset_outline(outline,-.08)
        outer=[(X+east,y-.26),(x-west,y-.26),(x-west,Y+.26),(X+east,Y+.26)]
        v=[(a,b,z) for z in [bottom,top] for ring in [inner,outer] for a,b in ring]
        f=[]
        for i in range(4):
            j=(i+1)%4
            f.extend([(i,j,j+4,i+4),(i+8,i+12,j+12,j+8),(i,i+8,j+8,j),(i+4,j+4,j+12,i+12)])
        self.add('door_paint',v,[tuple(reversed(face)) for face in f])

    def pitched_roof(self):
        x,y,X,Y=self.rect;e=self.eave;h=self.levels[-1]
        O,U,N,L=self.sides(self.rect)[0]
        outline=[(X,y),(x,y),(x,Y),(X,Y)]
        # A seated fascia/corona covers the eave joint. The mansard example's
        # bracketed cornice is part of its construction, not optional garnish.
        self.pitched_eave_course(e-.16,e+.10)
        if self.style=='mansard_2153':
            for at in [.22,L/3,2*L/3,L-.22]:
                self.stock('door_paint',O,U,N,(at-.065,-.03,e-.38),(at+.065,.22,e-.08),.01)
        if self.style=='mansard_2153':
            inset=1.65
            top=[(x+inset,y+inset,h),(X-inset,y+inset,h),(X-inset,Y-inset,h),(x+inset,Y-inset,h)]
            bottom=[(x,y,e),(X,y,e),(X,Y,e),(x,Y,e)]
            for i in range(4):self.roof_sheet([bottom[i],bottom[(i+1)%4],top[(i+1)%4],top[i]])
            self.roof_sheet(top,'galvanized_roof')
            for center in [L*.28,L*.72]:
                # Two true projecting dormers with closed cheeks, sash and
                # gabled caps. Their rear ends terminate inside the roof shell.
                D=O+U*center+N*.32
                low=e+.34;high=e+1.72;peak=e+2.12;w=.76;back=-1.28
                self.dormer=True
                self.panel(D,U,N,-w,w,low-.12,high+.18,2*w,front=False)
                self.dormer=False
                for side in [-1,1]:
                    self.profile('door_paint',D,U,N,[(side*w,low-.12),(side*w,high+.18),(side*(w-.12),high+.18),(side*(w-.12),low-.12)],back,-.05)
                self.profile('door_paint',D,U,N,[(-w,high+.18),(w,high+.18),(0,peak)],-.18,.03)
                a=D+U*(-w-.10)+Vector((0,0,high+.18));b=D+Vector((0,0,peak));c=D+U*(w+.10)+Vector((0,0,high+.18))
                for p,q in [(a,b),(b,c)]:self.roof_sheet([tuple(p+N*.10),tuple(q+N*.10),tuple(q+N*back),tuple(p+N*back)])
        else:
            mid=(x+X)/2
            # Longitudinal ridge; front and rear gables have real triangular
            # wall stock, preserving a full attic rather than a decorative cap.
            for a,b in [(x-.12,mid),(mid,X+.12)]:
                za=e if a<mid else h;zb=h if b==mid else e
                self.roof_sheet([(a,y-.25,za),(b,y-.25,zb),(b,Y+.15,zb),(a,Y+.15,za)])
            for side in [0,2]:
                A,T,F,width=self.sides(self.rect)[side]
                l=width/2-.32;r=width/2+.32;lo=e+.28;hi=e+1.18
                edge=e+(h-e)*l/(width/2)
                for p in [[(0,e),(l,e),(l,edge)],[(r,e),(width,e),(r,edge)],
                          [(l,e),(r,e),(r,lo),(l,lo)],
                          [(l,hi),(r,hi),(r,edge),(width/2,h),(l,edge)]]:
                    self.profile('door_paint',A,T,F,p,-.4,0)
                self.profile('mirror_aged',A,T,F,[(l+.02,lo+.02),(r-.02,lo+.02),(r-.02,hi-.02),(l+.02,hi-.02)],-.205,-.17)
                self.wood_frame(A,T,F,l,r,lo,hi)
                self.windows.append(dict(building=self.name,point=list(A+T*(l+.15)+Vector((0,0,lo+.25))),normal=list(F),recess_m=.17))
                for a,b in [(0,width/2),(width/2,width)]:
                    za=e if a==0 else h;zb=e if b==width else h
                    self.profile('door_paint',A,T,F,[(a,za-.08),(b,zb-.08),(b,zb+.04),(a,za+.04)],-.04,.10)
        # Continuous eave flashing is borne by actual wall stock, joining the
        # pitched shell at its edge. These are physical roof-seat controls.
        for a,b,c,d in [(x,y,X,y+.30),(x,Y-.30,X,Y),(x,y+.30,x+.30,Y-.30),(X-.30,y+.30,X,Y-.30)]:
            self.box('galvanized_roof',(a,b,e),(c,d,e+.08))
        for xx,yy,ox,oy in [(x+.15,(y+Y)/2,x-.12,(y+Y)/2),(X-.15,(y+Y)/2,X+.12,(y+Y)/2)]:
            self.bearings.append(dict(building=self.name,wall_key='timber' if self.style=='gable_2136' else self.row['wall_key'],point=[xx,yy,e+.08],outside_probe=[ox,oy,e+.08]))

    def build(self):
        x,y,X,Y=self.rect
        self.box('concrete',(x,y,-.28),(X,Y,0))
        for z in self.levels[1:]:
            if z>self.eave:continue
            self.box('timber',(x+.4,y+.4,z-.16),(X-.4,Y-.4,z))
        wall_levels=[z for z in self.levels if z<=self.eave]
        for side,(O,U,N,L) in enumerate(self.sides(self.rect)):
            count=self.study['side_bays'][side];pitch=L/count
            for floor,(z,Z) in enumerate(zip(wall_levels,wall_levels[1:])):
                self.basement=floor==0
                for bay in range(count):
                    l=bay*pitch;r=(bay+1)*pitch;entry=side==0 and bay==0
                    if self.covered(O,U,N,l,r,z,[]) or entry and floor==0:self.wall_stock(O,U,N,(l,-.4,z),(r,0,Z),L)
                    else:
                        projection=.16 if self.style=='gable_2136' and side==0 and floor>0 and bay>0 else 0.
                        self.panel(O+N*projection,U,N,l,r,z,Z,L,front=side==0,door=entry and floor==1,basement=floor==0)
        self.basement=False
        if self.style=='gable_2136':
            O,U,N,L=self.sides(self.rect)[0];pitch=L/self.study['side_bays'][0]
            for z in self.levels[1:-1]:
                self.profile('timber',O,U,N,[(pitch,z-.16),(L,z-.16),(L,z),(pitch,z)],-.4,.02)
            for at in [pitch,L-.06]:
                self.stock('door_paint',O,U,N,(at-.035,-.03,self.levels[1]),(at+.035,.18,self.eave),.004)
        if self.style=='italianate_2109':self.flat_roof()
        else:self.pitched_roof()
        assert len(self.entries)==1,(self.name,self.entries)
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,mitre_seams=self.seams,
                    closed_stocks=self.parts,min_closed_stock_volume_m3=self.min_volume,style=self.style)


class EasternHouses(EasternRows):
    """Three LPC0450 individuals, fitted to the eastern row's actual frontage.

    44-70's bowed pair,21-48's three-storey yellow-brick apartment,and21-34's
    timber-framed paired windows have different plans and floor schedules.
    Existing reservations remain; these are passive AU adaptations.
    """
    STYLES={'bow_4470','yellow_2148','frame_2134'}

    def __init__(self,row,emit,neighbours,lower=False):
        super().__init__(row,emit,neighbours,lower)
        self.front_x_sign=self.study.get('front_x_sign',1)
        assert self.front_x_sign in (-1,1)
        self.steps=1 if lower else 3
        self.substrate=None

    def add(self,key,vertices,faces):
        if self.substrate and key==self.row['wall_key']:key=self.substrate
        return super().add(key,vertices,faces)

    def wall_stock(self,O,U,N,lo,hi,length):
        wood=self.style=='frame_2134' and lo[2]>=self.levels[1]-.0001
        self.substrate='timber' if wood else 'arcade_brick_bond' if self.style=='frame_2134' else None
        super().wall_stock(O,U,N,lo,hi,length)
        self.substrate=None
        if not wood:return
        l,back,z=lo;r,front,Z=hi;pitch=.145
        for i in range(math.floor(z/pitch),math.ceil(Z/pitch)):
            bottom=max(z,i*pitch);top=min(Z,(i+1)*pitch)
            if top-bottom<1e-7:continue
            a=.035-.031*(bottom-i*pitch)/pitch;b=.035-.031*(top-i*pitch)/pitch
            v=[tuple(O+U*x+N*y+Vector((0,0,h))) for x,y,h in
               [(l,-.004,bottom),(r,-.004,bottom),(r,a,bottom),(l,a,bottom),
                (l,-.004,top),(r,-.004,top),(r,b,top),(l,b,top)]]
            self.add('door_paint',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

    def opening(self,O,U,N,l,r,z,Z,length,front,door,basement):
        # The timber house's central window pair occupies one real opening.
        paired=self.style=='frame_2134' and front and not door and not basement and abs((l+r)/2-length/2)<.1
        if not paired:
            self.row_opening(O,U,N,l,r,z,Z,length,door,basement)
        else:
            center=(l+r)/2;left=center-.82;right=center+.82;low=z+.64;high=Z-.52
            for a,b in [((l,-.28,z),(left,0,Z)),((right,-.28,z),(r,0,Z)),
                        ((left,-.28,z),(right,0,low)),((left,-.28,high),(right,0,Z))]:
                self.wall_stock(O,U,N,a,b,length)
            for a,b in [(left,center-.045),(center+.045,right)]:
                self.profile('mirror_aged',O,U,N,[(a+.02,low+.02),(b-.02,low+.02),(b-.02,high-.02),(a+.02,high-.02)],-.205,-.17)
                self.wood_frame(O,U,N,a,b,low,high)
                self.stock('door_paint',O,U,N,(a+.055,-.20,(low+high)/2-.025),(b-.055,-.075,(low+high)/2+.025),.003)
                self.windows.append(dict(building=self.name,point=list(O+U*((a+b)/2)+Vector((0,0,low+.35))),normal=list(N),recess_m=.17))
            self.stock('door_paint',O,U,N,(center-.045,-.28,low),(center+.045,.065,high),.006)
            for bottom,top in [(low-.09,low),(high,high+.13)]:
                self.stock('door_paint',O,U,N,(left-.10,-.20,bottom),(right+.10,.09,top),.008)
        if not front or basement:return
        if self.style=='bow_4470' and not door:
            center=(l+r)/2
            # Three separate fired-clay relief plaques on each bowed pier;
            # geometric bosses represent relief,with no lettering/photo pixels.
            for i in range(3):
                at=z+.16+i*.13
                self.stock('terracotta',O,U,N,(center-.10,.015,at),(center+.10,.055,at+.11),.004)
                self.stock('terracotta',O,U,N,(center-.035,.055,at+.03),(center+.035,.075,at+.08),.003)
        elif self.style=='frame_2134':
            # Joined vertical framing and incised diagonal spandrel boards.
            for at in [l+.045,r-.045]:
                self.stock('door_paint',O,U,N,(at-.035,.025,z),(at+.035,.09,Z),.004)
            self.stock('door_paint',O,U,N,(l+.06,.025,z+.04),(r-.06,.09,z+.14),.004)
            if not door:
                for a,b in [(l+.14,(l+r)/2),((l+r)/2,r-.14)]:
                    self.profile('door_paint',O,U,N,[(a,z+.17),(b,z+.42),(b,z+.46),(a,z+.21)],.035,.075)

    def cornice(self,outline,height):
        # Existing source-owned roof stock and unfiltered receiving controls.
        self.row_roof(outline,height)
        for side,(p,q) in enumerate(zip(outline,outline[1:]+outline[:1])):
            O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
            if N.x*self.front_x_sign<.65:continue
            count=4 if self.style!='bow_4470' else max(1,round(length/.85))
            for i in range(count):
                at=(i+.5)*length/count
                self.profile('door_paint',O,U,N,[(at-.065,height-.43),(at+.065,height-.43),(at+.09,height-.22),
                    (at+.055,height-.08),(at-.055,height-.08),(at-.09,height-.22)],-.05,.17)
            self.stock('door_paint',O,U,N,(.02,-.02,height-.18),(length-.02,.16,height-.04),.009)

    def build(self):
        outline=self.outline(True);inside=offset_outline(outline,-.28)
        for floor,(z,Z) in enumerate(zip(self.levels,self.levels[1:])):
            v,f=extrusion(outline if floor==0 else offset_outline(outline,-.14),-.28 if floor==0 else z-.16,0. if floor==0 else z)
            self.add('concrete' if floor==0 else 'timber',v,f)
            for side,(p,q) in enumerate(zip(outline,outline[1:]+outline[:1])):
                O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
                self.tapers=((Vector((*inside[side],0))-O).dot(U),length-(Vector((*inside[(side+1)%len(outline)],0))-O).dot(U))
                count=self.study['side_bays'][side];front=N.x*self.front_x_sign>.65
                for bay in range(count):
                    l=bay*length/count;r=(bay+1)*length/count
                    entry=side==self.study['front_side'] and bay==0
                    if length<1.2 or floor==0 and entry or self.covered(O,U,N,l,r,z,[]):
                        self.wall_stock(O,U,N,(l,-.28,z),(r,0,Z),length)
                    else:self.opening(O,U,N,l,r,z,Z,length,front,entry and floor==1,floor==0)
        self.cornice(outline,self.levels[-1])
        assert len(self.entries)==1,(self.name,'missing scenic entry',self.entries)
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,mitre_seams=self.seams,
                    closed_stocks=self.parts,min_closed_stock_volume_m3=self.min_volume,style=self.style)


class CourtApartments(EasternRows):
    """LPC1831 Cedar C-plan,Plymouth modified T,andWillow H-plan adaptations.

    Courts are real open exterior volumes,not dark rectangles on a solid slab.
    Passive leaves retain no occupied apartment or new gameplay authority.
    """
    STYLES={'cedar_8301','plymouth_3516','willow_3535'}

    def __init__(self,row,emit,neighbours,lower=False):
        super().__init__(row,emit,neighbours,lower)
        self.steps=1 if lower else 2;self.stone_base=False;self.stone_stock=False

    def add(self,key,vertices,faces):
        if self.stone_stock and key==self.row['wall_key']:key='limestone'
        return super().add(key,vertices,faces)

    def wall_stock(self,O,U,N,lo,hi,length):
        self.stone_stock=self.stone_base
        super().wall_stock(O,U,N,lo,hi,length)
        self.stone_stock=False

    def round_stock(self,key,center,radius,bottom,top):
        steps=8 if self.lower else 16
        ring=[(center.x+radius*math.cos(i*math.tau/steps),center.y+radius*math.sin(i*math.tau/steps)) for i in range(steps)]
        self.add(key,[(x,y,z) for z in [bottom,top] for x,y in ring],
                 [tuple(reversed(range(steps))),tuple(range(steps,2*steps))]+
                 [(i,(i+1)%steps,(i+1)%steps+steps,i+steps) for i in range(steps)])

    def entry_stoop(self,O,U,N,center,height):
        if self.style!='plymouth_3516':return super().entry_stoop(O,U,N,center,height)
        # The column bases stand on the broad porch landing,not on a lower
        # stair tread. The source frontage reserves the complete2.58m run.
        count=round(height/.15);landing=1.08;run=.25
        assert count>0 and .12<height/count<.18
        self.stock('limestone',O,U,N,(center-1.24,-.10,-.12),(center+1.24,landing,height),.008)
        for i in range(count):
            self.stock('limestone',O,U,N,(center-.77,landing+i*run,-.12),
                       (center+.77,landing+(i+1)*run,height*(count-i)/count),.008)
        for at in [center-.74,center+.74]:
            for i in [0,count]:
                depth=landing+(.5 if i==0 else count-.5)*run;top=height if i==0 else height/count
                self.stock('cast_iron',O,U,N,(at-.022,depth-.022,top),(at+.022,depth+.022,top+.90),.002)
            a=O+U*at+N*(landing+.5*run)+Vector((0,0,height+.90));b=O+U*at+N*(landing+(count-.5)*run)+Vector((0,0,height/count+.90))
            axis=(b-a).normalized();side=Vector((axis.y,-axis.x,0)).normalized();up=axis.cross(side)
            v=[tuple(p+side*s+up*t) for p in [a,b] for s,t in [(-.023,-.023),(.023,-.023),(.023,.023),(-.023,.023)]]
            self.add('cast_iron',v,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

    def aperture(self,O,U,N,l,r,z,Z,length,door=False,basement=False,loggia=False):
        width=min(1.50 if door else 1.35,r-l-.65);assert width>.5,(self.name,l,r)
        center=(l+r)/2;left=center-width/2;right=center+width/2
        low=z if door else z+(.18 if basement else .66)
        high=z+2.45 if door else Z-(.17 if basement else .52)
        arched=loggia or self.style=='cedar_8301' and door
        rise=.40 if arched else 0.;spring=high-rise
        for a,b in [((l,-.28,z),(left,0,Z)),((right,-.28,z),(r,0,Z)),
                    ((left,-.28,z),(right,0,low)),((left,-.28,high),(right,0,Z))]:
            if b[2]>a[2]+1e-8:self.wall_stock(O,U,N,a,b,length)
        head=[(left,high),(right,high)]
        if arched:
            head=[(center-width/2*math.cos(i*math.pi/self.arch_steps),spring+rise*math.sin(i*math.pi/self.arch_steps)) for i in range(self.arch_steps+1)]
            for a,b in zip(head,head[1:]):
                points=[a,b,(b[0],high),(a[0],high)];points=[v for i,v in enumerate(points) if v!=points[i-1]]
                if len(points)>2:self.profile(self.row['wall_key'],O,U,N,points,-.28,0.)
            self.arch('limestone',O,U,N,center,spring,width/2,rise,.09,-.08,.11)
        if loggia:
            # An open arcade has a real deck,guard and recessed backing facade.
            self.stock('cast_iron',O,U,N,(left,-.12,z+.88),(right,.015,z+.925),.003)
            for i in range(max(2,round(width/.14))+1):
                at=left+i*width/max(2,round(width/.14))
                self.stock('cast_iron',O,U,N,(at-.011,-.08,z+.02),(at+.011,-.045,z+.90),.002)
            return
        self.profile('door_paint' if door else 'mirror_aged',O,U,N,
                     [(left+.02,low+.02),(right-.02,low+.02)]+[(x,h-.02) for x,h in reversed(head)],-.205,-.17)
        self.wood_frame(O,U,N,left,right,low,high)
        self.stock('limestone',O,U,N,(left-.08,-.20,low-.08),(right+.08,.09,low),.008)
        if not arched:
            head_height=.12 if basement else .22;key_height=.145 if basement else .245
            assert high+max(head_height,key_height)<=Z-.015,(self.name,'lintel crosses storey',z,Z,high)
            header='limestone' if self.style=='plymouth_3516' or self.style=='willow_3535' and basement else self.row['wall_key']
            self.profile(header,O,U,N,
                         [(left-.08,high),(right+.08,high),(right+.22,high+head_height),(left-.22,high+head_height)],-.12,.055)
            self.profile('limestone',O,U,N,[(center-.055,high-.025),(center+.055,high-.025),(center+.09,high+key_height),(center-.09,high+key_height)],-.13,.075)
        if door:
            self.stock('door_paint',O,U,N,(center-.03,-.20,low+.02),(center+.03,-.075,high-.02),.004)
            for at in [center-.13,center+.13]:self.stock('bronze_sheet',O,U,N,(at-.012,-.075,low+.95),(at+.012,-.025,low+1.20),.003)
            self.entry_stoop(O,U,N,center,low)
            if self.style=='plymouth_3516':
                # Seated Doric portico columns,plinths,capitals and entablature.
                for at in [left-.22,right+.22]:
                    self.stock('limestone',O,U,N,(at-.23,.48,low),(at+.23,.94,low+.15),.009)
                    axis=O+U*at+N*.71;self.round_stock('limestone',axis,.155,low+.15,low+2.63)
                    self.stock('limestone',O,U,N,(at-.23,.48,low+2.63),(at+.23,.94,low+2.80),.009)
                self.stock('limestone',O,U,N,(left-.47,-.10,low+2.80),(right+.47,1.03,low+3.04),.012)
            else:
                for at in [left-.12,right+.12]:self.stock('limestone',O,U,N,(at-.07,-.08,high+.10),(at+.07,.30,high+.32),.009)
                self.profile('limestone',O,U,N,[(left-.27,high+.32),(right+.27,high+.32),(center,high+.66)],-.10,.36)
            self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,low+1.2))),kind='closed_scenic_leaf'))
        else:
            middle=(low+spring)/2
            self.stock('door_paint',O,U,N,(left+.055,-.20,middle-.025),(right-.055,-.075,middle+.025),.003)
            if not basement:
                for at in [left+width/3,left+2*width/3]:self.stock('door_paint',O,U,N,(at-.012,-.19,middle+.025),(at+.012,-.085,spring-.055),.002)
            self.windows.append(dict(building=self.name,point=list(O+U*(left+width*.27)+Vector((0,0,low+(spring-low)*.28))),normal=list(N),recess_m=.17))

    def crown(self,outline,height):
        self.row_roof(outline,height)
        for p,q in zip(outline,outline[1:]+outline[:1]):
            O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
            if N.x<.65 or length<1.:continue
            count=max(1,round(length/.85))
            for i in range(count):
                at=(i+.5)*length/count
                self.stock('limestone',O,U,N,(at-.075,-.04,height-.27),(at+.075,.19,height-.07),.008)
            if self.style=='willow_3535':
                count=max(1,round(length/1.1));pitch=length/count
                for i in range(count):
                    at=(i+.5)*pitch;half=pitch*.36;left=at-half;right=at+half
                    bottom=height+.58;low=height+.64;spring=height+.94;top=height+1.34
                    # A masonry arcade,not free U-shaped railing arches:
                    # closed piers/spandrels carry a continuous stone coping.
                    for l,r in [(i*pitch,left),(right,(i+1)*pitch)]:
                        self.profile(self.row['wall_key'],O,U,N,[(l,bottom),(r,bottom),(r,top),(l,top)],-.18,0.)
                    self.profile(self.row['wall_key'],O,U,N,[(left,bottom),(right,bottom),(right,low),(left,low)],-.18,0.)
                    head=[(at-half*math.cos(j*math.pi/self.arch_steps),spring+.24*math.sin(j*math.pi/self.arch_steps)) for j in range(self.arch_steps+1)]
                    for a,b in zip(head,head[1:]):self.profile(self.row['wall_key'],O,U,N,[a,b,(b[0],top),(a[0],top)],-.18,0.)
                    self.arch('limestone',O,U,N,at,spring,half,.24,.055,-.10,.035)
                self.stock('limestone',O,U,N,(0.,-.21,height+1.34),(length,.045,height+1.42),.008)
            elif self.style=='plymouth_3516':
                for i in range(max(1,round(length/3.))):
                    at=(i+.5)*length/max(1,round(length/3.))
                    # Raised stone swag panel: four closed curved ribbon stocks.
                    for j in range(4):
                        a=-.40+j*.20;b=a+.20;za=height+.38-.18*(1-(a/.4)**2);zb=height+.38-.18*(1-(b/.4)**2)
                        self.profile('limestone',O,U,N,[(at+a,za),(at+b,zb),(at+b,zb+.045),(at+a,za+.045)],-.015,.035)
        if self.style=='cedar_8301':
            a,b,c,d=self.row['rect'];front=c-1.9
            for low,high in [(b+.12,b+5.88),(d-5.88,d-.12)]:
                # Four closed hip slopes remove the open triangular ends of
                # the initial two-plane roof. A continuous timber curb seats
                # on the flat deck/parapet and supports the eaves all around.
                x=front-3.1;X=front+.10;y=-high;Y=-low;z=height+.58;ridge=(y+Y)/2
                perimeter=[(X,y),(x,y),(x,Y),(X,Y)]
                v,f=cornice_ring(offset_outline(perimeter,-.14),.14,height+.18,z);self.add('door_paint',v,f)
                r=(x+.65,ridge,z+.88);R=(X-.65,ridge,z+.88)
                for points in [[(x,y,z),(X,y,z),R,r],[r,R,(X,Y,z),(x,Y,z)],
                               [(x,Y,z),(x,y,z),r],[(X,y,z),(X,Y,z),R]]:
                    ResidentialHouses.roof_sheet(self,points,'city_roof_clay')

    def build(self):
        outline=self.outline(True);inside=offset_outline(outline,-.28)
        entries=self.study['entry_sides']
        for floor,(z,Z) in enumerate(zip(self.levels,self.levels[1:])):
            v,f=extrusion(outline if floor==0 else offset_outline(outline,-.14),-.28 if floor==0 else z-.16,0. if floor==0 else z)
            self.add('concrete' if floor==0 else 'timber',v,f)
            self.stone_base=self.style=='plymouth_3516' and floor==1 or self.style=='willow_3535' and floor==0
            for side,(p,q) in enumerate(zip(outline,outline[1:]+outline[:1])):
                O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
                self.tapers=((Vector((*inside[side],0))-O).dot(U),length-(Vector((*inside[(side+1)%len(outline)],0))-O).dot(U))
                count=self.study['side_bays'][side];loggia=self.style=='cedar_8301' and floor==len(self.levels)-2 and side in [3,7]
                for bay in range(count):
                    l=bay*length/count;r=(bay+1)*length/count;entry=side in entries and bay==count//2
                    if length<.7 or floor==0 and entry or self.covered(O,U,N,l,r,z,[]):self.wall_stock(O,U,N,(l,-.28,z),(r,0,Z),length)
                    else:self.aperture(O,U,N,l,r,z,Z,length,entry and floor==1,floor==0,loggia)
                if loggia:
                    self.tapers=(.28,.28)
                    for bay in range(count):self.aperture(O-N*2.35,U,N,bay*length/count,(bay+1)*length/count,z,Z,length)
            self.stone_base=False
        self.crown(outline,self.levels[-1])
        # Each open court receives a real paved surface,with buried sub-base.
        for x,y,X,Y in self.study['court_paving_m']:
            self.box('concrete',(x,-Y,-.12),(X,-y,0.))
        if self.style=='cedar_8301':
            a,b,c,d=self.row['rect'];front=c-1.9;middle=(b+d)/2
            # Winter garden beds leave both side stoops and a3.6m axial walk
            # open. The wrought gateway has a permanent3.2m clear opening.
            for low,high in [(b+6.30,middle-1.8),(middle+1.8,d-6.30)]:
                for x,X in [(front-6.8,front-4.5),(front-3.0,front-2.0)]:
                    self.box('soil',(x,-high,.005),(X,-low,.055))
            for z in [middle-1.6,middle+1.6]:
                self.round_stock('cast_iron',Vector((front+.35,-z,0)),.055,0,1.22)
        assert len(self.entries)==len(entries),(self.name,'scenic entry roster',self.entries)
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,mitre_seams=self.seams,
                    closed_stocks=self.parts,min_closed_stock_volume_m3=self.min_volume,style=self.style)


class CivicRows(ResidentialHouses):
    STYLES={'stone_2129','narrow_2141','neogrec_2122'}

    def __init__(self,row,emit,neighbours,lower=False):
        super().__init__(row,emit,neighbours,lower)
        self.eave=self.levels[-1]
        self.steps=1 if lower else 2
        if self.style=='narrow_2141':
            # The documented16ft frontage is a real proportion,not a tint on
            # another22ft box. Retain its parcel and leave two service gaps.
            x,y,X,Y=self.rect;middle=(x+X)/2
            self.rect=(middle-2.44,y,middle+2.44,Y)

    def add(self,key,vertices,faces):
        if self.basement and key==self.row['wall_key']:key='limestone'
        return MillLofts.add(self,key,vertices,faces)

    def star(self,O,U,N,center,height,radius):
        points=[]
        for i in range(10):
            angle=math.pi/2+i*math.pi/5;r=radius if i%2==0 else radius*.43
            points.append((center+math.cos(angle)*r,height+math.sin(angle)*r))
        self.profile('limestone',O,U,N,points,.18,.205)

    def panel(self,O,U,N,l,r,z0,z1,length,front=False,door=False,basement=False):
        if basement and door:
            self.wall_stock(O,U,N,(l,-.4,z0),(r,0,z1),length);return
        width=min(1.18 if door else .88 if self.style=='narrow_2141' else 1.06,r-l-.58)
        assert width>.65,(self.name,width)
        center=(l+r)/2;left=center-width/2;right=center+width/2
        low=z0+(.025 if door else .17 if basement else .58)
        high=z0+2.65 if door else z1-(.20 if basement else .47)
        arched=front and not basement and self.style=='stone_2129'
        rise=(.43 if door else .16) if arched else 0.;spring=high-rise
        assert z0<low<spring<=high<z1
        for a,b in [((l,-.4,z0),(left,0,z1)),((right,-.4,z0),(r,0,z1)),
                    ((left,-.4,z0),(right,0,low)),((left,-.4,high),(right,0,z1))]:
            self.wall_stock(O,U,N,a,b,length)
        if arched:
            head=[(center-width/2*math.cos(i*math.pi/self.arch_steps),spring+rise*math.sin(i*math.pi/self.arch_steps)) for i in range(self.arch_steps+1)]
            for a,b in zip(head,head[1:]):
                points=[a,b,(b[0],high),(a[0],high)]
                points=[p for i,p in enumerate(points) if p!=points[i-1]]
                if len(points)>2:self.profile(self.row['wall_key'],O,U,N,points,-.4,0)
        else:head=[(left,high),(right,high)]
        # Recessed physical pane/leaf and continuous jambs. The arched entry
        # has a separate glazed fanlight and solid double leaves below it.
        leaf=[(left+.02,low+.02),(right-.02,low+.02)]+[(x,h-.02) for x,h in reversed(head)]
        if door and arched:leaf=[(left+.02,low+.02),(right-.02,low+.02),(right-.02,spring),(left+.02,spring)]
        self.profile('door_paint' if door else 'mirror_aged',O,U,N,leaf,-.205,-.17)
        for a,b in [(left,left+.065),(right-.065,right)]:
            self.stock('door_paint',O,U,N,(a,-.205,low),(b,-.07,spring),.004)
        for h in [low,spring]:
            self.stock('door_paint',O,U,N,(left,-.205,h),(right,-.07,h+.055),.004)
        if arched:
            self.arch('door_paint',O,U,N,center,spring,width/2,rise,.065,-.205,-.07)
            self.arch('limestone',O,U,N,center,spring,width/2+.055,rise+.035,.11,-.10,.10)
            if door:
                inner=[(center-(width/2-.07)*math.cos(i*math.pi/self.arch_steps),spring+.055+(rise-.10)*math.sin(i*math.pi/self.arch_steps)) for i in range(self.arch_steps+1)]
                self.profile('mirror_aged',O,U,N,inner,-.208,-.173)
        self.stock('limestone',O,U,N,(left-.08,-.22,low-.08),(right+.08,.09,low),.008)
        if not arched:self.stock('limestone',O,U,N,(left-.07,-.22,high),(right+.07,.08,high+.12),.008)
        if door:
            self.stock('door_paint',O,U,N,(center-.025,-.16,low+.02),(center+.025,-.07,spring-.03),.003)
            for a,b in [(left+.10,center-.07),(center+.07,right-.10)]:
                for h,H in [(low+.13,low+.80),(low+1.02,spring-.13)]:
                    assert H>h
                    self.stock('door_paint',O,U,N,(a,-.166,h),(b,-.125,H),.01)
            self.stock('bronze_sheet',O,U,N,(center+.10,-.08,low+.95),(center+.13,-.025,low+1.20),.003)
            if self.style=='stone_2129':
                self.profile('limestone',O,U,N,[(left-.19,high+.13),(right+.19,high+.13),(center,high+.53)],-.05,.20)
                for at in [left-.12,right+.12]:
                    self.stock('limestone',O,U,N,(at-.075,-.07,high-.04),(at+.075,.17,high+.16),.008)
            self.stoop(O,U,N,left,right,low)
            self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,low+1.2))),kind='closed_scenic_leaf'))
        else:
            middle=low+(spring-low)*.48
            self.stock('door_paint',O,U,N,(left+.05,-.195,middle-.025),(right-.05,-.075,middle+.03),.003)
            if not basement:
                for at in [left+width/3,left+2*width/3]:
                    self.stock('door_paint',O,U,N,(at-.012,-.19,middle+.03),(at+.012,-.08,spring-.03),.002)
            if arched:
                floor=self.levels.index(z0)
                # Stone front has three different head/sill orders rather
                # than one repeating extrusion. First-floor stars belong to
                # the original ribbed head consoles described by LPC.
                for at in [left-.04,right+.04]:
                    self.stock('limestone',O,U,N,(at-.075,-.04,low-.20),(at+.075,.07,low-.075),.008)
                if floor==1:
                    self.arch('limestone',O,U,N,center,spring,width/2+.16,rise+.12,.10,-.03,.19)
                    for at in [left-.13,right+.13]:
                        self.stock('limestone',O,U,N,(at-.075,-.03,high-.04),(at+.075,.18,high+.12),.007)
                        self.star(O,U,N,at,high+.035,.055)
                elif floor==2:
                    self.arch('limestone',O,U,N,center,spring,width/2+.13,rise+.085,.075,-.025,.15)
            self.windows.append(dict(building=self.name,point=list(O+U*(left+width*.25)+Vector((0,0,low+(spring-low)*.27))),normal=list(N),recess_m=.17))

    def stoop(self,O,U,N,left,right,top):
        count=6;run=.25;landing=.25
        self.stock('limestone',O,U,N,(left-.14,-.06,-.12),(right+.14,landing,top),.008)
        for i in range(count):
            self.stock('limestone',O,U,N,(left-.14,landing+i*run,-.12),(right+.14,landing+(i+1)*run,top*(count-i)/count),.008)
        for at in [left-.10,right+.10]:
            for depth,height in [(landing/2,top),(landing+(count-.5)*run,top/count)]:
                self.stock('cast_iron',O,U,N,(at-.025,depth-.025,height),(at+.025,depth+.025,height+.90),.003)
            first=landing/2;last=landing+(count-.5)*run
            rise=lambda t:top+.90+(top/count-top)*(t-first)/(last-first)
            self.profile('cast_iron',O+U*at,N,-U,[(first,rise(first)-.023),(last,rise(last)-.023),(last,rise(last)+.023),(first,rise(first)+.023)],-.023,.023)
            if self.style=='neogrec_2122':
                # Curvilinear forged rail infill is retained in both bodies.
                for i in range(3):
                    center=first+(last-first)*(i+.5)/3;height=rise(center)-.27
                    self.arch('cast_iron',O+U*at,N,-U,center,height,.14,.18,.018,-.014,.014)

    def flat_roof(self):
        x,y,X,Y=self.rect;z=self.eave;outline=[(X,y),(x,y),(x,Y),(X,Y)]
        self.box('galvanized_roof',(x,y,z),(X,Y,z+.14))
        # A deep timber cornice has supported crown/fascia/base stocks; the
        # Neo-Grec frontage has exactly four principal shaped brackets.
        O,U,N,L=self.sides(self.rect)[0]
        for lo,hi,projection in [(z-.33,z-.24,.16),(z-.24,z+.035,.24),(z+.035,z+.14,.34)]:
            self.stock('door_paint',O,U,N,(0,-.12,lo),(L,projection,hi),.009)
        # Brackets sit onthe opening piers,not over window heads.
        # Neo-Grec's four aredocumented; the narrow two-bay front uses three.
        count=3 if self.style=='narrow_2141' else 4
        for i in range(count):
            at=.16+(L-.32)*i/(count-1)
            points=[(at-.07,z-.33),(at+.07,z-.33),(at+.07,z-.48),(at+.035,z-.57),(at-.035,z-.57),(at-.07,z-.48)]
            self.profile('door_paint',O,U,N,points,-.025,.22)
        for i in range(4):
            a=Vector((*outline[i],z+.14));b=Vector((*outline[(i+1)%4],z+.14));t=(b-a).normalized();n=Vector((-t.y,t.x,0))
            self.bearings.append(dict(building=self.name,wall_key=self.row['wall_key'],point=list((a+b)/2-n*.18),outside_probe=list((a+b)/2+n*.10)))

    def build(self):
        x,y,X,Y=self.rect;a,b,c,d=self.row['rect']
        #2.8m front reservation minus1.75m stoop leaves a continuous1.05m
        # lane at the adjoining school edge,clear for the0.66m player body.
        assert self.study['front_inset_m']>=2.8
        self.box('concrete',(a,-d,-.12),(c,y,0))
        self.box('concrete',(x,y,-.28),(X,Y,0))
        for z in self.levels[1:]:self.box('timber',(x+.4,y+.4,z-.16),(X-.4,Y-.4,z))
        for side,(O,U,N,L) in enumerate(self.sides(self.rect)):
            count=self.study['side_bays'][side];pitch=L/count
            for floor,(z,Z) in enumerate(zip(self.levels,self.levels[1:])):
                self.basement=floor==0
                for bay in range(count):
                    l=bay*pitch;r=(bay+1)*pitch;entry=side==0 and bay==0
                    if self.covered(O,U,N,l,r,z,[]) or entry and floor==0:self.wall_stock(O,U,N,(l,-.4,z),(r,0,Z),L)
                    else:self.panel(O,U,N,l,r,z,Z,L,front=side==0,door=entry and floor==1,basement=floor==0)
        self.basement=False;self.flat_roof()
        assert len(self.entries)==1,(self.name,self.entries)
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,mitre_seams=self.seams,closed_stocks=self.parts,min_closed_stock_volume_m3=self.min_volume,style=self.style)


class CivicBlocks(EasternRows):
    STYLES={'bryant_2801','garside_3502'}

    def __init__(self,row,emit,neighbours,lower=False):
        super().__init__(row,emit,neighbours,lower)
        self.steps=1 if lower else 2
        self.basement=False;self.windowing=False;self.crowning=False
        self.wall_depth=.3048 if self.style=='garside_3502' else .40

    def wall_stock(self,O,U,N,lo,hi,length):
        # Keep this cohort's actual section: Garside's documented12inch
        # brick/tile curtain andthe authored400mm school masonry. The older
        # garden-apartment helper's280mm section isnot silently substituted.
        l,back,z=lo;r,front,Z=hi
        assert abs(back+self.wall_depth)<1e-7 and abs(front)<1e-7
        left=self.tapers[0] if abs(l)<1e-7 else 0.
        right=self.tapers[1] if abs(r-length)<1e-7 else 0.
        assert r-l>0 and r-right>l+left,(self.name,l,r,left,right,length)
        plan=[(l,front),(r,front),(r-right,back),(l+left,back)]
        vertices=[tuple(O+U*a+N*b+Vector((0,0,h))) for h in [z,Z] for a,b in plan]
        faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        if U.cross(N).z>0:faces=[tuple(reversed(f)) for f in faces]
        self.add(self.row['wall_key'],vertices,faces)

    def add(self,key,vertices,faces):
        if self.style=='bryant_2801':
            if self.basement and key==self.row['wall_key']:key='limestone'
            if self.windowing and key=='cast_iron':key='door_paint'
        if self.crowning and key=='door_paint':key='limestone' if self.style=='bryant_2801' else 'concrete'
        return super().add(key,vertices,faces)

    def opening(self,O,U,N,l,r,z,Z,length,door=False,basement=False):
        school=self.style=='bryant_2801';center=(l+r)/2
        # Reserve the full two corner sections plus20mm on each side before
        # selecting a sash width. A fixed700mm allowance left5mm too little
        # material at the shortened school's17.2m/five-bay side.
        width=min(1.85 if door else 2.65 if school else 3.85,r-l-2*self.wall_depth-.04)
        assert width>.65,(self.name,l,r,width)
        left=center-width/2;right=center+width/2
        low=z+(.025 if door else .17 if basement else .64)
        high=z+2.82 if door else Z-(.18 if basement and school else .38 if basement else .54)
        assert z<low<high<Z,(self.name,z,Z,low,high)
        for a,b in [((l,-self.wall_depth,z),(left,0,Z)),((right,-self.wall_depth,z),(r,0,Z)),
                    ((left,-self.wall_depth,z),(right,0,low)),((left,-self.wall_depth,high),(right,0,Z))]:
            self.wall_stock(O,U,N,a,b,length)
        self.profile('door_paint' if door else 'mirror_aged',O,U,N,
                     [(left+.02,low+.02),(right-.02,low+.02),(right-.02,high-.02),(left+.02,high-.02)],-.205,-.17)
        self.windowing=True;self.rectangular_frame(O,U,N,left,right,low,high)
        trim='limestone' if school else 'concrete'
        self.stock(trim,O,U,N,(left-.075,-.22,low-.075),(right+.075,.075,low),.008)
        self.stock(trim,O,U,N,(left-.075,-.22,high),(right+.075,.075,high+.12),.008)
        if door:
            self.stock('door_paint',O,U,N,(center-.035,-.20,low+.025),(center+.035,-.07,high-.025),.004)
            for a,b in [(left+.10,center-.08),(center+.08,right-.10)]:
                self.stock('door_paint',O,U,N,(a,-.165,low+.15),(b,-.13,low+.82),.008)
                self.stock('door_paint',O,U,N,(a,-.165,low+1.04),(b,-.13,high-.13),.008)
            for at in [center-.13,center+.13]:
                self.stock('bronze_sheet',O,U,N,(at-.015,-.075,low+1.0),(at+.015,-.025,low+1.24),.003)
            self.windowing=False
            if school:
                # Compound limestone arch and abstract owl/tablet relief are
                # geometry; no lettering or new school/entry programme.
                self.arch('limestone',O,U,N,center,high-.12,width/2+.14,.31,.13,-.08,.20)
                self.arch('limestone',O,U,N,center,high-.12,width/2+.31,.43,.11,-.07,.25)
                self.profile('limestone',O,U,N,[(center-.11,high+.23),(center+.11,high+.23),(center+.15,high+.51),(center-.15,high+.51)],-.05,.30)
                for at in [center-.075,center+.075]:
                    self.profile('limestone',O,U,N,[(at-.05,high+.34),(at+.05,high+.34),(at,high+.45)],.30,.34)
                self.school_stair(O,U,N,center,low)
            else:self.entry_stoop(O,U,N,center,low)
            self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,low+1.2))),kind='closed_scenic_leaf'))
        else:
            columns=6;rows=1 if basement else 4
            for i in range(1,columns):
                at=left+width*i/columns
                thick=.038 if school and i in [2,4] else .016
                self.stock('cast_iron',O,U,N,(at-thick,-.195,low+.055),(at+thick,-.085,high-.035),.003)
            for i in range(1,rows):
                at=low+(high-low)*i/rows
                self.stock('cast_iron',O,U,N,(left+.055,-.195,at-.016),(right-.055,-.085,at+.016),.003)
            self.windowing=False
            self.windows.append(dict(building=self.name,point=list(O+U*(left+width*.27)+Vector((0,0,low+(high-low)*.29))),normal=list(N),recess_m=.17))

    def school_stair(self,O,U,N,center,top):
        # Two flights ascend parallel to the facade to a shared entrance
        # landing. The outer lane remains beyond their1.1m normal projection.
        self.stock('limestone',O,U,N,(center-.90,-.10,-.12),(center+.90,1.10,top),.009)
        count=7;run=.21
        for sign in [-1,1]:
            for i in range(count):
                a=center+sign*(.90+i*run);b=center+sign*(.90+(i+1)*run)
                self.stock('limestone',O,U,N,(min(a,b),.15,-.12),(max(a,b),1.10,top*(count-i)/count),.008)
            first=center+sign*(.90+(count-.5)*run);last=center+sign*.86
            for at,height in [(first,top/count),(last,top)]:
                self.stock('cast_iron',O,U,N,(at-.022,1.04-.022,height),(at+.022,1.04+.022,height+.90),.003)
            lo=min(first,last);hi=max(first,last)
            h=lambda x:top/count+.90+(top-top/count)*(x-first)/(last-first)
            self.profile('cast_iron',O,U,N,[(lo,h(lo)-.022),(hi,h(hi)-.022),(hi,h(hi)+.022),(lo,h(lo)+.022)],1.018,1.062)

    def school_detail(self,outline,height):
        z=self.levels[-2]
        v,f=cornice_ring(offset_outline(outline,-.04),.20,z-.13,z+.025)
        self.add('limestone',v,f)
        for index,(p,q) in enumerate(zip(outline,outline[1:]+outline[:1])):
            O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
            if length<.7:continue
            if N.x>.65:
                # End-pavilion quoins,not a flat color stripe.
                if index in [3,11]:
                    for at in [.13,length-.13]:
                        base=self.levels[1];span=height-.38-base
                        courses=max(1,round(span/.34));pitch=span/courses
                        assert pitch>.12
                        # Integer course phase avoids emitting a zero-height
                        # floating-point remainder after43 nominal courses.
                        for course in range(courses):
                            h=base+course*pitch;H=h+pitch-.08
                            self.stock('limestone',O,U,N,(at-.13,-.04,h),(at+.13,.065,H),.008)
                count=max(1,round(length/.48))
                for i in range(count):
                    at=(i+.5)*length/count
                    self.stock('limestone',O,U,N,(at-.065,-.04,height-.24),(at+.065,.18,height-.06),.008)
                if index in [3,11]:
                    center=length/2
                    # Solid gable spandrel and seated stone rakes retain the
                    # pre-alteration school's roof silhouette inboth LODs.
                    self.profile(self.row['wall_key'],O,U,N,[(.22,height+.52),(length-.22,height+.52),(center,height+1.55)],-.20,.0)
                    for a,b in [((.17,height+.50),(center,height+1.62)),((center,height+1.62),(length-.17,height+.50))]:
                        self.profile('limestone',O,U,N,[a,b,(b[0],b[1]+.10),(a[0],a[1]+.10)],-.10,.16)

    def factory_frame(self,outline):
        # The primary assessment explicitly describes mushroom columns.
        # These passive structural stocks carry floors/roof; no occupied
        # factory interior or new access authority isintroduced. Both bodies
        # retain every shaft andcapital,with16/8-sided section sampling.
        xs=[p[0] for p in outline];ys=[p[1] for p in outline]
        steps=8 if self.lower else 16
        for floor,(z,Z) in enumerate(zip(self.levels,self.levels[1:])):
            top=Z if floor==len(self.levels)-2 else Z-.18
            shoulder=top-.17
            assert z<shoulder<top
            for i in range(4):
                x=min(xs)+.8+(max(xs)-min(xs)-1.6)*i/3
                for j in range(4):
                    y=min(ys)+.8+(max(ys)-min(ys)-1.6)*j/3
                    vertices=[(x+radius*math.cos(k*math.tau/steps),y+radius*math.sin(k*math.tau/steps),h) for radius,h in [(.18,z),(.18,shoulder),(.60,top)] for k in range(steps)]
                    faces=[tuple(reversed(range(steps))),tuple(range(2*steps,3*steps))]
                    for ring in range(2):
                        for k in range(steps):
                            a=ring*steps+k;b=ring*steps+(k+1)%steps
                            faces.append((a,b,b+steps,a+steps))
                    self.add('concrete',vertices,faces)

    def build(self):
        outline=self.outline(True);inside=offset_outline(outline,-self.wall_depth);height=self.levels[-1]
        for box in self.study['court_paving_m']:
            a,b,c,d=box;self.box('concrete',(a,-d,-.12),(c,-b,0))
        for floor,(z,Z) in enumerate(zip(self.levels,self.levels[1:])):
            v,f=extrusion(outline if floor==0 else offset_outline(outline,-.16),-.28 if floor==0 else z-.18,0 if floor==0 else z)
            self.add('concrete',v,f)
            self.basement=floor==0
            for side,(p,q) in enumerate(zip(outline,outline[1:]+outline[:1])):
                O=Vector((*p,0));U=Vector((q[0]-p[0],q[1]-p[1],0));length=U.length;U.normalize();N=Vector((-U.y,U.x,0))
                self.tapers=((Vector((*inside[side],0))-O).dot(U),length-(Vector((*inside[(side+1)%len(outline)],0))-O).dot(U))
                count=self.study['side_bays'][side]
                for bay in range(count):
                    l=bay*length/count;r=(bay+1)*length/count
                    entry=side in self.study['entry_sides'] and bay==count//2
                    if length<.7 or floor==0 and entry or self.covered(O,U,N,l,r,z,[]):
                        self.wall_stock(O,U,N,(l,-self.wall_depth,z),(r,0,Z),length)
                    else:self.opening(O,U,N,l,r,z,Z,length,door=entry and floor==1,basement=floor==0)
                if self.style=='garside_3502':
                    # Actual exposed concrete piers andfloor beams wrap the
                    # brick/tile curtain wall; panes remain deeply recessed.
                    for bay in range(count+1):
                        at=bay*length/count
                        lo=max(0,at-.18);hi=min(length,at+.18)
                        if hi>lo:self.stock('concrete',O,U,N,(lo,-.12,z),(hi,.055,Z),.008)
                    self.stock('concrete',O,U,N,(0,-.10,Z-.22),(length,.075,Z),.008)
            self.basement=False
        if self.style=='garside_3502':self.factory_frame(outline)
        self.crowning=True;self.row_roof(outline,height);self.crowning=False
        if self.style=='bryant_2801':self.school_detail(outline,height)
        assert len(self.entries)==1,(self.name,self.entries)
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,mitre_seams=self.seams,closed_stocks=self.parts,min_closed_stock_volume_m3=self.min_volume,style=self.style)
