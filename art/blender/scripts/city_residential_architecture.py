"""Source-fitted Hunters Point houses; LPC0450 forms, authored AU dimensions.

No occupied interiors, shop access or historical parcel/paint claim. All lower
bodies retain walls, floors, entries, roof volumes, dormers and joinery.
"""
import math
from mathutils import Vector
from city_industrial_architecture import MillLofts,EasternRows
from city_horizon_geometry import cornice_ring,offset_outline


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
        if self.style!='gable_2136' or self.basement:return super().wall_stock(O,U,N,lo,hi,length)
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
