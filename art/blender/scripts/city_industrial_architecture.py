"""Three source-fitted Dutch Kills industrial elevations.

Native geometry only. The horizon producer owns grade, charts, materials,
export and collision. Profiles refer to individual buildings described in
the Dutch Kills assessment, PDF135-139; modern photographs are form references,
not period colour, window-replacement or parcel evidence.
"""
import math
from collections import Counter
from mathutils import Vector
from city_horizon_geometry import cornice_ring, offset_outline, party_wall_overlap
from frame_mitre_geometry import frame_parts, interface_points


class IndustrialBuildings:
    STYLES = {'karp_4024', 'karp_4018', 'walters_4036'}

    def __init__(self, row, emit, neighbours, lower=False):
        self.row = row
        self.name = row['id']
        self.emit = emit
        self.neighbours = neighbours
        self.study = row['architecture']
        self.style = self.study['style']
        assert self.style in self.STYLES
        self.steps = 1 if lower else 3
        self.arch_steps = 6 if lower else 12
        self.windows = []
        self.bearings = []
        self.entries = []
        self.seams = []
        self.parts = 0
        self.min_volume = math.inf
        self.levels = [0.]
        for height in self.study['floor_heights_m']:
            self.levels.append(self.levels[-1] + float(height))
        assert len(self.levels) == 6 and abs(self.levels[-1]-row['height_m']) < 1e-6

    def add(self, key, vertices, faces):
        edges=Counter(tuple(sorted((a,b))) for face in faces
                      for a,b in zip(face,face[1:]+face[:1]))
        assert edges and all(count==2 for count in edges.values()),(self.name,key,'open stock')
        origin=Vector(vertices[0])
        points=[Vector(v)-origin for v in vertices]
        volume=sum(points[f[0]].dot(points[f[i]].cross(points[f[i+1]]))/6
                   for f in faces for i in range(1,len(f)-1))
        assert volume>1e-12,(self.name,key,'reversed or collapsed stock',volume)
        self.min_volume=min(self.min_volume,volume)
        self.emit(self.name, key, vertices, faces)
        self.parts += 1

    def box(self, key, lo, hi):
        x,y,z = lo; X,Y,Z = hi
        assert x<X and y<Y and z<Z, (self.name,lo,hi)
        self.add(key, [(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),
                       (x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],
                 [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

    def profile(self, key, origin, u, out, points, back, front):
        assert front > back and len(points) >= 3
        points = list(points)
        area = sum(a*B-A*b for (a,b),(A,B) in zip(points,points[1:]+points[:1]))
        assert abs(area) > 1e-12
        if area < 0: points.reverse()
        if u.cross(Vector((0,0,1))).dot(out) > 0: points.reverse()
        n = len(points)
        vertices = [tuple(origin+u*a+out*d+Vector((0,0,z)))
                    for d in [back,front] for a,z in points]
        faces = [tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
        faces += [(i,i+n,j+n,j) for i,j in zip(range(n),list(range(1,n))+[0])]
        self.add(key, vertices, faces)

    def stock(self, key, origin, u, out, lo, hi, radius=.012):
        """Closed stock with rounded U/Z arrises; lower body retains the arris.

        All near and lower stock extents, openings and partitions agree. Only
        the curved cross-section sampling changes, including structural piers.
        """
        l,back,b = lo; r,front,t = hi
        assert l<r and back<front and b<t, (self.name,lo,hi)
        radius = min(radius,(r-l)*.24,(t-b)*.24)
        points = []
        for x,z,start in [(l+radius,b+radius,math.pi),
                          (r-radius,b+radius,math.pi*1.5),
                          (r-radius,t-radius,0.),
                          (l+radius,t-radius,math.pi*.5)]:
            for step in range(self.steps+1):
                angle = start+math.pi*.5*step/self.steps
                points.append((x+radius*math.cos(angle),z+radius*math.sin(angle)))
        self.profile(key,origin,u,out,points,back,front)

    def arch(self,key,O,U,N,cx,spring,half,rise,width,back,front):
        inside = [(cx-half*math.cos(i*math.pi/self.arch_steps),
                   spring+rise*math.sin(i*math.pi/self.arch_steps))
                  for i in range(self.arch_steps+1)]
        outside = [(cx-(half+width)*math.cos(i*math.pi/self.arch_steps),
                    spring+(rise+width)*math.sin(i*math.pi/self.arch_steps))
                   for i in range(self.arch_steps+1)]
        for i in range(self.arch_steps):
            self.profile(key,O,U,N,[inside[i],inside[i+1],outside[i+1],outside[i]],back,front)

    def rectangular_frame(self,O,U,N,left,right,low,high):
        frame=frame_parts(right-left-.11,high-low-.11,.055,.125)
        joints=interface_points(frame)
        center=(left+right)*.5
        def place(p):
            a,d,z=p
            return tuple(O+U*(center+a)+N*(-.1475+d)+Vector((0,0,low+.055+z)))
        for member in frame.values():
            # The helper's native depth convention has negative volume for
            # this U/out/up basis; reverse its faces, preserving exact caps.
            faces=[tuple(reversed(f)) for f in member['faces']]
            if U.cross(N).z<0:faces=[tuple(reversed(f)) for f in faces]
            self.add('cast_iron',[place(v) for v in member['vertices']],faces)
        self.stock('cast_iron',O,U,N,(left,-.21,low),(right,-.085,low+.055),.004)
        self.seams.append(dict(building=self.name,full_depth_m=.125,
                               interfaces={k:[list(place(p)) for p in points] for k,points in joints.items()}))

    @staticmethod
    def sides(rect):
        x,y,X,Y=rect
        return [(Vector((X,y,0)),Vector((-1,0,0)),Vector((0,-1,0)),X-x),
                (Vector((X,Y,0)),Vector((0,-1,0)),Vector((1,0,0)),Y-y),
                (Vector((x,Y,0)),Vector((1,0,0)),Vector((0,1,0)),X-x),
                (Vector((x,y,0)),Vector((0,1,0)),Vector((-1,0,0)),Y-y)]

    def covered(self,O,U,N,l,r,z,extra):
        a=O+U*l+N*.025; b=O+U*r+N*.025
        return party_wall_overlap((a.x,-a.y),(b.x,-b.y),
                                  z+float(self.row['grade_datum_m']),self.neighbours+extra)

    def wall_stock(self,O,U,N,lo,hi,length):
        """Mitre structural corner piers instead of overlapping end caps.

        Each outward plane has one physical owner. Adjacent wall stocks meet
        on an internal diagonal; their end caps no longer share the exposed
        face of the perpendicular wall.
        """
        l,back,z=lo;r,front,Z=hi
        left=abs(l)<1e-7;right=abs(r-length)<1e-7
        if not (left or right):
            self.stock(self.row['wall_key'],O,U,N,lo,hi,.014);return
        assert abs(back+.4)<1e-7 and abs(front)<1e-7
        plan=[(l,front),(r,front),(r-(.4 if right else 0),back),(l+(.4 if left else 0),back)]
        assert r-l>.4
        vertices=[tuple(O+U*a+N*b+Vector((0,0,h))) for h in [z,Z] for a,b in plan]
        faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        if U.cross(N).z>0:faces=[tuple(reversed(f)) for f in faces]
        self.add(self.row['wall_key'],vertices,faces)

    def opening(self,O,U,N,l,r,z0,z1,width,length,columns=6,rows=4,arched=False,door=False):
        wall=self.row['wall_key']; center=(l+r)*.5
        # Leave a complete 400 mm structural corner, including narrow annex
        # bays, before the reveal begins. This is actual wall thickness.
        width=min(width,r-l-.90)
        left=center-width*.5; right=center+width*.5
        low=z0+(.10 if door else .64); high=z1-(.70 if self.style=='karp_4024' else .54)
        if door: high=z0+3.10
        assert l<left<right<r and z0<low<high<z1
        spring=high-(.20 if arched else 0.)
        for a,b in [((l,-.40,z0),(left,0,z1)),((right,-.40,z0),(r,0,z1)),
                    ((left,-.40,z0),(right,0,low)),((left,-.40,high),(right,0,z1))]:
            self.wall_stock(O,U,N,a,b,length)
        head=[(left,spring),(right,spring)]
        if arched:
            head=[(center-width*.5*math.cos(i*math.pi/self.arch_steps),
                   spring+.20*math.sin(i*math.pi/self.arch_steps)) for i in range(self.arch_steps+1)]
            for a,b in zip(head,head[1:]):
                if max(a[1],b[1])>=high-1e-8:
                    # The crown apex touches the next stock; a triangle avoids
                    # a duplicate apex vertex in the closed spandrel profile.
                    poly=[a,b,(a[0],high)] if a[1]<b[1] else [a,b,(b[0],high)]
                else: poly=[a,b,(b[0],high),(a[0],high)]
                self.profile(wall,O,U,N,poly,-.40,0.)
            self.arch('limestone',O,U,N,center,spring,width*.5,.20,.065,-.08,.065)
        pane_head=list(reversed(head)) if arched else [(right,high),(left,high)]
        key='door_paint' if door else 'mirror_aged'
        self.profile(key,O,U,N,[(left+.02,low+.02),(right-.02,low+.02)]+
                     ([(x, h-.02) for x,h in pane_head] if arched else [(right-.02,high-.02),(left+.02,high-.02)]),-.205,-.17)
        trim='limestone' if self.style=='karp_4024' else 'concrete'
        for a,b in [((left-.075,-.22,low-.075),(right+.075,.065,low)),
                    ((left-.075,-.22,high),(right+.075,.055,high+.12))]:
            self.stock(trim,O,U,N,a,b)
        frame='cast_iron'
        if not arched:self.rectangular_frame(O,U,N,left,right,low,high)
        else:
            for a,b in [((left,-.21,low),(left+.055,-.085,spring)),
                        ((right-.055,-.21,low),(right,-.085,spring)),
                        ((left,-.21,low),(right,-.085,low+.055))]:
                self.stock(frame,O,U,N,a,b,.004)
            self.arch(frame,O,U,N,center,spring,width*.5-.055,.145,.055,-.21,-.085)
        if door:
            self.stock(frame,O,U,N,(center-.04,-.17,low+.02),(center+.04,-.075,high-.06),.004)
            for at in [center-.14,center+.14]:
                self.stock('bronze_sheet',O,U,N,(at-.015,-.075,low+.98),(at+.015,-.025,low+1.28),.003)
            self.stock('concrete',O,U,N,(left-.12,-.16,-.06),(right+.12,.40,low),.008)
            self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,low+1.2))),kind='closed_scenic_leaf'))
        else:
            for i in range(1,columns):
                at=left+width*i/columns
                self.stock(frame,O,U,N,(at-.016,-.195,low+.055),(at+.016,-.085,spring-.035),.003)
            for i in range(1,rows):
                at=low+(spring-low)*i/rows
                self.stock(frame,O,U,N,(left+.055,-.195,at-.016),(right-.055,-.085,at+.016),.003)
            sample=O+U*(left+width*.27)+Vector((0,0,low+(spring-low)*.29))
            self.windows.append(dict(building=self.name,point=list(sample),normal=list(N),recess_m=.17))

    def roof(self,rect,height):
        x,y,X,Y=rect;outline=[(X,y),(x,y),(x,Y),(X,Y)]
        assert sum(a*B-A*b for (a,b),(A,B) in zip(outline,outline[1:]+outline[:1]))<0
        self.box('galvanized_roof',(x,y,height),(X,Y,height+.18))
        v,f=cornice_ring(offset_outline(outline,-.18),.18,height+.18,height+.58)
        self.add(self.row['wall_key'],v,f)
        n=len(outline)
        for i in range(n):
            j=(i+1)%n
            point=sum((Vector(v[k]) for k in [i,j,i+n,j+n]),Vector())*.25
            edge=Vector((*outline[j],0))-Vector((*outline[i],0));edge.normalize()
            outside=(Vector((*outline[i],height+.18))+Vector((*outline[j],height+.18)))*.5+Vector((-edge.y,edge.x,0))*.09
            self.bearings.append(dict(building=self.name,wall_key=self.row['wall_key'],point=list(point),outside_probe=list(outside)))
        # Cornice is entirely within the parcel, including its mitred corners.
        for back,width,z0,z1 in [(.40,.24,height-.23,height-.11),(.22,.22,height-.11,height)]:
            v,f=cornice_ring(offset_outline(outline,-back),width,z0,z1)
            self.add('limestone' if self.style=='karp_4024' else 'concrete',v,f)

    def mass(self,rect,levels,annex=False,extra=None):
        x,y,X,Y=rect;wall=self.row['wall_key'];extra=extra or []
        self.box(wall,(x,y,-.28),(X,Y,0.))
        for z in levels[1:-1]:self.box('concrete',(x+.40,y+.40,z-.18),(X-.40,Y-.40,z))
        for side,(O,U,N,length) in enumerate(self.sides(rect)):
            front=side==1
            count=1 if annex and side in [1,3] else 5 if self.style=='karp_4024' else 4 if self.style=='karp_4018' else max(3,round(length/6.1))
            if self.style=='karp_4024' and front:
                factors=[5.,3.5,5.,3.5,5.];widths=[length*f/sum(factors) for f in factors]
            else: widths=[length/count]*count
            edges=[0.]
            for width in widths:edges.append(edges[-1]+width)
            for floor,(z0,z1) in enumerate(zip(levels,levels[1:])):
                for bay,(l,r) in enumerate(zip(edges,edges[1:])):
                    covered=self.covered(O,U,N,l,r,z0,extra)
                    if covered:
                        self.wall_stock(O,U,N,(l,-.40,z0),(r,0.,z1),length);continue
                    passage=annex and floor==0 and side in [1,3]
                    if passage:
                        mid=(l+r)*.5
                        for a,b in [((l,-.40,z0),(mid-.85,0.,z1)),((mid+.85,-.40,z0),(r,0.,z1)),
                                    ((mid-.85,-.40,2.8),(mid+.85,0.,z1))]:self.wall_stock(O,U,N,a,b,length)
                        if side==1:self.entries.append(dict(building=self.name,kind='open_annex_passage',point=list(O+U*mid),normal=list(N),depth_m=X-x,width_m=1.7,headroom_m=2.8))
                        continue
                    narrow=self.style=='karp_4024' and front and bay%2==1
                    width=.78 if narrow else min(3.35 if self.style=='karp_4024' else 3.65 if self.style=='karp_4018' else 4.8,r-l-.60)
                    door=not annex and front and floor==0 and bay==len(widths)//2
                    self.opening(O,U,N,l,r,z0,z1,2.10 if door else width,length,columns=2 if narrow else 6,rows=3 if narrow else 4,arched=narrow,door=door)
                # A party wall carries no outward-facing applied stock into
                # the neighbouring owner's volume. Individual window bays
                # above already retain their own overlap controls.
                if self.covered(O,U,N,0.,length,z0,extra):continue
                if self.style=='karp_4018' and floor==0:
                    # Actual scored ground piers: recessed seams, not a map.
                    for at in edges:
                        l=max(.01,at-.20);r=min(length-.01,at+.20)
                        if l>=r:continue
                        for z in [.5,1.15,1.8,2.45,3.1]:
                            self.stock('concrete',O,U,N,(l,0.,z),(r,.035,z+.055),.004)
                if self.style=='karp_4024' and front:
                    for at in edges[1:-1]:
                        # Three concave channels survive in the lower body.
                        profile=[(at-.19,-.10),(at+.19,-.10),(at+.19,.035)]
                        for channel in range(3):
                            cx=at+.125-channel*.125
                            for step in range(self.arch_steps+1):
                                u=cx+.045*math.cos(step*math.pi/self.arch_steps)
                                profile.append((u,.035-.018*math.sin(step*math.pi/self.arch_steps)))
                        profile.append((at-.19,.035));n=len(profile)
                        verts=[tuple(O+U*u+N*d+Vector((0,0,z))) for z in [z0+.10,z1-.10] for u,d in profile]
                        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
                        self.add('limestone',verts,faces)
                if self.style=='walters_4036':
                    for at in edges:
                        l=max(.01,at-.34);r=min(length-.01,at+.34)
                        if l<r:self.stock(wall,O,U,N,(l,-.08,z0+.02),(r,.045,z1-.02),.02)
                for z in [z1-.10]:self.stock('limestone' if self.style=='karp_4024' else 'concrete',O,U,N,(0.,-.14,z),(length,.035,z1+.04),.012)
        self.roof(rect,levels[-1])

    def build(self):
        a,b,c,d=self.row['rect'];rect=(a,-d,c,-b)
        if self.style=='karp_4018':
            x,y,X,Y=rect;annex=(x,y,X,y+2.6);main=(x,y+2.6,X,Y)
            def other(r,h):return dict(rect=[r[0],-r[3],r[2],-r[1]],height_m=h,grade_datum_m=self.row['grade_datum_m'])
            self.mass(main,self.levels,extra=[other(annex,self.levels[3])])
            self.mass(annex,self.levels[:4],annex=True,extra=[other(main,self.levels[-1])])
        else:self.mass(rect,self.levels)
        x,y,X,Y=rect;h=self.levels[-1]
        # Seated masonry flue and cap, retaining the source's industrial use.
        flue_y=y+(3.4 if self.style=='karp_4018' else .8)
        self.box(self.row['wall_key'],(x+.8,flue_y,h+.18),(x+1.5,flue_y+.7,h+2.08))
        self.box('limestone',(x+.7,flue_y-.1,h+2.08),(x+1.6,flue_y+.8,h+2.20))
        self.bearings.append(dict(building=self.name,wall_key=self.row['wall_key'],
            kind='flue_seat',point=[x+1.15,flue_y+.35,h+.18],
            outside_probe=[x-.10,flue_y+.35,h+.18]))
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,
                    mitre_seams=self.seams,closed_stocks=self.parts,
                    min_closed_stock_volume_m3=self.min_volume,style=self.style)
