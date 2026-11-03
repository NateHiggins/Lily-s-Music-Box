"""Source-fitted city packet bodies. No runtime or collision ownership.

The local fabrication profiles are regenerated at their stated bay pitches;
only rigid frames transform emitted stock. Meshes are never stretched to lots.
"""
import copy
from mathutils import Matrix, Vector
from city_industrial_architecture import IndustrialBuildings, MillLofts, EasternRows
from city_residential_architecture import ResidentialHouses, CivicRows, CourtApartments


class PacketBuildings:
    def __init__(self, row, emit, neighbours, lower=False):
        self.row = row
        self.roof_vertices=[];self.roof_faces=[]
        self.study = row['architecture']
        self.frame = Matrix(self.study['native_frame'])
        self.inverse = self.frame.inverted()
        local = copy.deepcopy(self.study['fabrication_profile'])
        local.update(id=row['id'], grade_datum_m=row.get('grade_datum_m', 0.),
                     grade_low_m=row.get('grade_low_m', 0.))
        self.emit = emit
        converted = []
        for other in neighbours:
            x,z,X,Z = other['rect']
            points = [self.inverse @ Vector((u,-v,0)) for u,v in [(x,z),(X,z),(X,Z),(x,Z)]]
            converted.append(dict(other, rect=[min(p.x for p in points), -max(p.y for p in points),
                                               max(p.x for p in points), -min(p.y for p in points)]))
        cls = {'house': ResidentialHouses, 'civic_house': CivicRows,
               'court': CourtApartments, 'industrial': IndustrialBuildings,
               'mill': MillLofts, 'hampton': HamptonCourt,
               'office': QueensOffice}[self.study['fabricator']]
        self.builder = cls(local, self._emit, converted, lower)

    def _emit(self, name, key, vertices, faces):
        if key in ['galvanized_roof','city_slate','city_roof_clay']:
            start=len(self.roof_vertices);self.roof_vertices.extend(vertices)
            self.roof_faces.extend(tuple(start+i for i in f) for f in faces)
        self.emit(name, key, [tuple(self.frame @ Vector(p)) for p in vertices], faces)

    def build(self):
        result = self.builder.build()
        if self.study['fabricator']=='house':
            a,b,c,d=self.builder.row['rect']
            self.builder.box('concrete',(a,-d,-.12),(c,-d+self.builder.study['front_inset_m'],0.))
        if self.study['fabricator'] in ['house','civic_house','court','hampton']:
            self.flues(result)
        for field in ['windows', 'bearings', 'entries']:
            for witness in result[field]:
                for key in ['point', 'outside_probe']:
                    if key in witness:
                        witness[key] = list(self.frame @ Vector(witness[key]))
                if 'normal' in witness:
                    witness['normal'] = list(self.frame.to_3x3() @ Vector(witness['normal']))
        for seam in result['mitre_seams']:
            seam['interfaces'] = {k:[list(self.frame @ Vector(p)) for p in v]
                                  for k,v in seam['interfaces'].items()}
        result['style'] = self.study['style']
        result.update(closed_stocks=self.builder.parts,min_closed_stock_volume_m3=self.builder.min_volume)
        return result

    def flues(self,result):
        from mathutils.bvhtree import BVHTree
        tree=BVHTree.FromPolygons(self.roof_vertices,self.roof_faces)
        x,y,X,Y=[min(p[i] for p in self.roof_vertices) if j<2 else max(p[i] for p in self.roof_vertices)
                 for j,i in enumerate([0,1,0,1])]
        height=self.builder.levels[-1];wanted=2 if max(X-x,Y-y)>30 else 1;seats=[]
        candidates=[(x+(X-x)*u,y+(Y-y)*v) for u,v in
                    [(.15,.85),(.85,.15),(.15,.15),(.85,.85),(.50,.15),(.50,.85),(.25,.50),(.75,.50)]]
        for cx,cy in candidates:
            hits=[]
            for dx,dy in [(-.23,-.23),(.23,-.23),(.23,.23),(-.23,.23)]:
                hit,normal,_,_=tree.ray_cast(Vector((cx+dx,cy+dy,height+3)),Vector((0,0,-1)),height+4)
                if hit is not None and normal.z>.2:hits.append(hit)
            if len(hits)!=4:continue
            bottom=min(p.z for p in hits)-.10;top=max(height+1.25,max(p.z for p in hits)+.95)
            for lo,hi in [((cx-.26,cy-.26,bottom),(cx+.26,cy-.14,top)),
                          ((cx-.26,cy+.14,bottom),(cx+.26,cy+.26,top)),
                          ((cx-.26,cy-.14,bottom),(cx-.14,cy+.14,top)),
                          ((cx+.14,cy-.14,bottom),(cx+.26,cy+.14,top))]:
                self.builder.box('arcade_brick_bond',lo,hi)
            for lo,hi in [((cx-.30,cy-.30,top),(cx+.30,cy-.14,top+.12)),
                          ((cx-.30,cy+.14,top),(cx+.30,cy+.30,top+.12)),
                          ((cx-.30,cy-.14,top),(cx-.14,cy+.14,top+.12)),
                          ((cx+.14,cy-.14,top),(cx+.30,cy+.14,top+.12))]:
                self.builder.box('limestone',lo,hi)
            seats.append(dict(roof_hits_local=[list(p) for p in hits],bottom_m=bottom,top_m=top,
                              bore_width_m=.28,through_roof=True))
            if len(seats)==wanted:break
        assert len(seats)==wanted,(self.row['id'],'hollow flue roof seats')
        result['flue_seats']=seats


class HamptonCourt(CourtApartments):
    """79th Street central entry, flanking canted bays and openwork parapet.

    LPC1831 PDF129 supplies form, not an AU parcel survey. No later balcony
    rails from the report's separate 78th Street description are copied.
    """
    STYLES = {'hampton_7916'}

    def add(self,key,vertices,faces):
        # The documented light painted sash uses an existing dielectric
        # coating recipe. The metal entry remains a separate finish/stock.
        return super().add('enamel' if key=='door_paint' else key,vertices,faces)

    def crown(self, outline, height):
        self.row_roof(outline, height)
        for p,q in zip(outline, outline[1:]+outline[:1]):
            O = Vector((*p,0)); U = Vector((q[0]-p[0],q[1]-p[1],0))
            length = U.length; U.normalize(); N = Vector((-U.y,U.x,0))
            if N.x < .5 or length < 1.: continue
            # True open slots between closed stone piers and lintel stocks.
            count = max(1, round(length/.65))
            self.stock('limestone',O,U,N,(0,-.19,height+.56),(length,.025,height+.66),.006)
            self.stock('limestone',O,U,N,(0,-.20,height+1.14),(length,.045,height+1.25),.006)
            for i in range(count+1):
                at = i*length/count
                self.stock('limestone',O,U,N,(max(0,at-.055),-.16,height+.65),
                           (min(length,at+.055),.005,height+1.15),.006)

    def aperture(self,O,U,N,l,r,z,Z,length,door=False,basement=False,loggia=False):
        if not door:
            return super().aperture(O,U,N,l,r,z,Z,length,False,basement,False)
        # Metal/glass double leaf and transom, separate from white timber sash.
        width=min(1.65,r-l-.65); center=(l+r)/2; left=center-width/2; right=center+width/2
        high=z+2.52
        for lo,hi in [((l,-.28,z),(left,0,Z)),((right,-.28,z),(r,0,Z)),
                      ((left,-.28,high),(right,0,Z))]:
            if hi[2]>lo[2]:self.wall_stock(O,U,N,lo,hi,length)
        self.stock('limestone',O,U,N,(left-.13,-.20,z),(left,.10,high+.16),.008)
        self.stock('limestone',O,U,N,(right,-.20,z),(right+.13,.10,high+.16),.008)
        for lo,hi in [((left-.22,-.22,high),(right+.22,.16,high+.16)),
                      ((left-.28,-.24,high+.16),(right+.28,.24,high+.27))]:
            self.stock('limestone',O,U,N,lo,hi,.008)
        self.profile('mirror_aged',O,U,N,[(left+.04,z+.04),(right-.04,z+.04),
                     (right-.04,high-.04),(left+.04,high-.04)],-.205,-.17)
        for at in [left,center-.0275,right-.055]:
            self.stock('cast_iron',O,U,N,(at,-.17,z),(at+.055,-.075,high),.003)
        for at in [z,z+2.10,high-.055]:
            self.stock('cast_iron',O,U,N,(left,-.17,at),(right,-.075,at+.055),.003)
        for at in [center-.13,center+.10]:
            self.stock('bronze_sheet',O,U,N,(at,-.065,z+.95),(at+.03,-.025,z+1.28),.004)
        self.entry_stoop(O,U,N,center,z)
        self.entries.append(dict(building=self.name,point=list(O+U*center+Vector((0,0,z+1.2))),kind='closed_scenic_leaf'))


class QueensOffice(IndustrialBuildings):
    """AU 1927 limestone office accent with a podium and two setback stages.

    The Bank of Manhattan source informs vertical piers and an office accent.
    Its eleven-storey brick/limestone body and three-storey clock tower are
    distinct from these authored setbacks and retained 35.2m AU height cap.
    """
    STYLES = {'queens_office_1927'}
    __init__ = EasternRows.__init__

    def build(self):
        a,b,c,d=self.row['rect']; outer=(a,-d,c,-b)
        # Complete storeys; only the ground stage receives the scenic leaf.
        for start,end,inset in [(0,3,0.),(3,8,1.25),(8,len(self.levels)-1,2.8)]:
            x,y,X,Y=outer;rect=(x+inset,y+inset,X-inset,Y-inset)
            x,y,X,Y=rect
            if start==0:self.box('limestone',(x,y,-.28),(X,Y,0))
            for floor in range(start,end):
                z,Z=self.levels[floor:floor+2]
                if floor>0:self.box('concrete',(x+.40,y+.40,z-.18),(X-.40,Y-.40,z))
                for side,(O,U,N,length) in enumerate(self.sides(rect)):
                    count=max(3,int(length/2.8));pitch=length/count
                    for bay in range(count):
                        l=bay*pitch;r=l+pitch
                        if self.covered(O,U,N,l,r,z,[]):
                            self.wall_stock(O,U,N,(l,-.40,z),(r,0,Z),length);continue
                        door=floor==0 and side==1 and bay==count//2
                        self.opening(O,U,N,l,r,z,Z,1.65 if door else min(1.35,pitch-.7),
                                     length,columns=2,rows=3,door=door)
                        self.stock('limestone',O,U,N,(l+.01,-.06,z+.08),(l+.20,.08,Z-.08),.008)
                    self.stock('limestone',O,U,N,(0,-.10,Z-.13),(length,.09,Z+.03),.008)
            self.roof(rect,self.levels[end])
        return dict(windows=self.windows,bearings=self.bearings,entries=self.entries,
                    mitre_seams=self.seams,closed_stocks=self.parts,
                    min_closed_stock_volume_m3=self.min_volume,style=self.style)
