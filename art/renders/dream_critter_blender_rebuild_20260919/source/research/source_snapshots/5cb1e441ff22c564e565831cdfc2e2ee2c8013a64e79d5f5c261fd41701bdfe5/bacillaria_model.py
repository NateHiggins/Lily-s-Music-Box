"""Rigid sliding Bacillaria raft, external builder module only.

Nine independent cell bodies carry closed finite-thickness silica jackets.
Each jacket has an actual longitudinal raphe opening: its inner and outer
surfaces meet at a rounded slit rim, with no cap or painted substitute.
The closed living cortex lies beneath that opening and owns two chloroplasts.
Seventeen law keys sample a full existing law.x phase cycle; the last key is
identical to Basis. Both gait keys are intentionally neutral. No silica bends.
"""
import math

SPECIES_ID = 13
MOTION_PROFILE = "bacillaria_raphe_slide"
CILIUM_BRANCH_COUNT = 0
LAW_CYCLE_CLOSED = True
NEUTRAL_PHASE_KEYS = True
LAW_KEYS = ("Basis", "law_01", "law_02", "law_03", "law_04", "law_05",
            "law_06", "law_07", "law_half", "law_09", "law_10", "law_11",
            "law_12", "law_13", "law_14", "law_15", "law_full")
PHASE_KEYS = ("gait_a", "gait_b")
CELL_COUNT = 9
_API = None


def _add(a,b):
    return tuple(a[i]+b[i] for i in range(3))


def _scale(a,s):
    return tuple(x*s for x in a)


def _unit(a):
    n=math.sqrt(sum(x*x for x in a))
    if n<1e-12:
        raise ValueError("Degenerate Bacillaria shell frame")
    return _scale(a,1./n)


def _cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])


def _center(cell):
    return ((cell-4)*.100,0.,.34*math.sin(cell*.72))


def _surface(u,phi):
    theta=u*(math.pi-.10)
    x_radius=.043*math.sin(theta)
    # The upper opening is a narrow longitudinal slit, not the short circular
    # hole made by simply cutting the top off an ellipsoid.
    blend=max(0.,min(1.,(u-.58)/.42))
    blend=blend*blend*(3.-2.*blend)
    z_side=.455*math.sin(theta)*math.sin(phi)
    # A very long ellipse has almost zero tip curvature radius; offsetting
    # it by the wall thickness would fold the rim through itself.  Rounded
    # stadium-like ends keep curvature above the finitewall thickness.
    opening_half_width=.043*math.sin(.10)
    z_open=(.350-opening_half_width)*math.tanh(4.*math.sin(phi))/math.tanh(4.) \
            +opening_half_width*math.sin(phi)
    z=z_side*(1.-blend)+z_open*blend
    y=-.180*math.cos(theta)
    # A real raised girdle is carried by the closed silica wall.
    girdle=math.exp(-((y+.018)/.025)**2)
    x_radius+=.0018*girdle
    return (x_radius*math.cos(phi),y,z)


def _frame(u,phi):
    point=_surface(u,phi)
    if u<1e-9:
        return point,(0.,-1.,0.),(math.cos(phi),0.,math.sin(phi))
    delta=1e-5
    before=_surface(max(0.,u-delta),phi)
    after=_surface(min(1.,u+delta),phi)
    tangent=_unit(tuple(after[i]-before[i] for i in range(3)))
    left=_surface(u,phi-delta);right=_surface(u,phi+delta)
    around=tuple(right[i]-left[i] for i in range(3))
    normal=_unit(_cross(tangent,around))
    return point,normal,tangent


def _jacket(api,cell,lod):
    cage=api.Cage()
    around,bands=(24,16) if lod==0 else (12,8)
    center=_center(cell)
    ends={}

    def vertex(u,phi,side):
        p,n,t=_frame(u,phi)
        if side=="outer": offset=_scale(n,.0012)
        elif side=="inner": offset=_scale(n,-.0012)
        else: offset=_add(_scale(n,.0012*math.cos(side)),_scale(t,.0012*math.sin(side)))
        index=cage.vertex(_add(center,_add(p,offset)))
        cage.group("silica_wall",[index])
        if u>.86: cage.group("raphe_lip",[index],(u-.86)/.14)
        if abs(p[1]+.018)<.050: cage.group("girdle",[index])
        if side=="outer": cage.group("outer_valve",[index])
        elif side=="inner": cage.group("inner_valve",[index])
        return index

    for side in ("outer","inner"):
        pole=vertex(0.,0.,side)
        previous=None
        for band in range(1,bands+1):
            ring=[vertex(band/bands,math.tau*i/around,side) for i in range(around)]
            if previous is None:
                for i in range(around):
                    face=(pole,ring[(i+1)%around],ring[i])
                    cage.faces.append(tuple(reversed(face)) if side=="inner" else face)
            else:
                before=len(cage.faces);cage.connect(previous,ring)
                if side=="inner":
                    cage.faces[before:]=[tuple(reversed(f)) for f in cage.faces[before:]]
            previous=ring
        ends[side]=previous
    previous=ends["outer"]
    for step in range(1,4):
        ring=[vertex(1.,math.tau*i/around,math.pi*step/4.) for i in range(around)]
        cage.connect(previous,ring);previous=ring
    cage.connect(previous,ends["inner"])
    return cage


def build_objects(api,col,lod,seed):
    global _API
    _API=api
    central=None
    others=[]
    for cell in range(CELL_COUNT):
        center=_center(cell)
        cortex_name="Skin" if cell==4 else "Cortex_%02d"%cell
        cortex=api.make_object(cortex_name,api.ellipsoid_cage(center,(.032,.139,.417),seed+cell,
                                                            2 if lod==0 else 1),col,0,"continuous_skin")
        if cell==4:central=cortex
        else:others.append(cortex)
        others.append(api.make_object("Frustule_%02d"%cell,_jacket(api,cell,lod),col,0,"support"))
        for flank in (-1,1):
            # Separate contained plates remain in their owning cell's frame.
            p=_add(center,(flank*.014,0.,0.))
            cage=api.ellipsoid_cage(p,(.0075,.060,.235),seed+cell*3+flank,2 if lod==0 else 1)
            others.append(api.make_object("Chloroplast_%02d_%s"%(cell,"A" if flank<0 else "B"),
                                          cage,col,0,"internal_organ"))
    return [central]+others


def _cell(name):
    return 4 if name=="Skin" else int(name.split("_")[1])


def deform(point,law,phase,object_name):
    # Exact endpoints, and deliberately no phase-key jiggle of rigid silica.
    phase_angle=0. if law>=1. else math.tau*max(0.,float(law))
    cell=_cell(object_name)
    slide=.34*(math.sin(phase_angle+cell*.72)-math.sin(cell*.72))
    return (float(point[0]),float(point[1]),float(point[2])+slide)


def vertex_bindings(obj):
    return [(-1,0.) for _ in obj.data.vertices]


def _weights(obj,name):
    group=obj.vertex_groups.get(name)
    if group is None:return [0.]*len(obj.data.vertices)
    return [next((entry.weight for entry in vertex.groups if entry.group==group.index),0.)
            for vertex in obj.data.vertices]


def vertex_semantics(obj):
    if obj.name.startswith("Chloroplast_"):
        return [(.015,0.,2) for _ in obj.data.vertices]
    if not obj.name.startswith("Frustule_"):
        return [(.025,.55,1) for _ in obj.data.vertices]
    lips=_weights(obj,"raphe_lip");girdle=_weights(obj,"girdle")
    return [(min(.92,.06+.72*lips[i]+.12*girdle[i]),.84,1)
            for i in range(len(obj.data.vertices))]


def rig_specs():
    return [("DEF_cell_%02d"%cell,_add(_center(cell),(0.,0.,-.20)),
             _add(_center(cell),(0.,0.,.20))) for cell in range(CELL_COUNT)]


def metadata(species,objects):
    if species!="bacillaria":raise ValueError("Wrong species for Bacillaria module")
    parts=[]
    for obj in objects:
        owner=None
        if obj.name.startswith("Chloroplast_"):
            cell=_cell(obj.name);owner="Skin" if cell==4 else "Cortex_%02d"%cell
        parts.append({"object":obj.name,"role":obj["anatomy_role"],"topology":"closed","container":owner})
    return {"parts":parts,"attachments":[],
            "required_regions":[{"object":"Frustule_%02d"%cell,"vertex_group":group,"min_vertices":3}
                                for cell in range(CELL_COUNT)
                                for group in ("raphe_lip","silica_wall","inner_valve","outer_valve")]}
