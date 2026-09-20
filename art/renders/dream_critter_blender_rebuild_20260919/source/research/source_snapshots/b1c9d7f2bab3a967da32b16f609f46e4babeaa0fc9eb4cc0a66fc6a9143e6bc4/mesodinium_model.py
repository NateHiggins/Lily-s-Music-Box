"""Bilobed Mesodinium with contained host nuclei and retained prey plastids.

Form-only references: https://pubmed.ncbi.nlm.nih.gov/22888970/ and
https://www.nature.com/articles/s41396-020-00830-9 . The former describes oral
ultrastructure; the latter distinguishes retained prey compartments from host
control. This is an authored dream interpretation, not a cellular simulation.
The existing controller phase still moves its internal archipelago; no jump
behavior is introduced. Geometry and all texture masks are original.
"""
import math

SPECIES_ID=15
MOTION_PROFILE="mesodinium_archipelago"
CILIUM_BRANCH_COUNT=12
REFERENCE_URLS=("https://pubmed.ncbi.nlm.nih.gov/22888970/",
                "https://www.nature.com/articles/s41396-020-00830-9")
_SEMANTICS={}
_PHASE={}
PROFILE=[(-.50,.025),(-.475,.15),(-.42,.29),(-.34,.38),(-.25,.42),
         (-.16,.39),(-.09,.31),(-.035,.275),(.035,.27),(.10,.30),
         (.18,.355),(.27,.365),(.35,.33),(.415,.25),(.465,.15),
         (.48,.08),(.475,.049),(.438,.035),(.427,.01)]


def _key(p): return tuple(round(float(x),8) for x in p)


def _weights(obj,name):
    group=obj.vertex_groups.get(name)
    return [next((float(g.weight) for g in v.groups if group and g.group==group.index),0.) for v in obj.data.vertices]


def _skin(api,lod):
    c=api.Cage(); around=48 if lod==0 else 24
    rings=[]; starts=[]
    for row,(y,radius) in enumerate(PROFILE):
        ring=[]
        for j in range(around):
            a=math.tau*j/around
            relief=1+.009*math.cos(12*a)*math.exp(-(y/.35)**4)
            ring.append(c.vertex((radius*math.cos(a)*relief,y,radius*math.sin(a)*relief)))
        if rings: starts.append(len(c.faces)); c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0]))); c.faces.append(tuple(rings[-1]))
    c.group("posterior_lobe",sum(rings[1:6],[])); c.group("anterior_lobe",sum(rings[9:16],[]))
    c.group("equatorial_waist",sum(rings[6:10],[])); c.group("oral_vestibule",sum(rings[16:],[]))
    c.group("gold_boundary",rings[15],.26)
    for i in range(12):
        row=6 if i%2==0 else 8
        sector=i*around//12
        face=c.inset(starts[row]+sector,.12)
        ids=c.faces[face]
        base=tuple(sum(c.vertices[v][k] for v in ids)/len(ids) for k in range(3))
        a=math.atan2(base[2],base[0]); r=math.hypot(base[0],base[2]); tier=-1 if i%2==0 else 1
        centers=[]
        for t in (.2,.45,.7,1.):
            angle=a+.12*t*t
            centers.append(((r+.20*t)*math.cos(angle),base[1]+tier*.065*t*t,
                            (r+.20*t)*math.sin(angle)))
        c.extrude(face,centers,(.008,.006,.0035,.0009),group="cilium_%d"%i,region="cilia")
    return c


def build_objects(api,col,lod,seed):
    skin=api.make_object("Skin",_skin(api,lod),col,1 if lod==0 else 0,"continuous_skin")
    objects=[skin]
    for name,center,radii in [("HostMacronucleus",(.035,-.245,.015),(.096,.077,.083)),
                             ("HostMicronucleus",(-.060,-.125,.008),(.028,.029,.027)),
                             ("RetainedPreyNucleus",(.012,.215,-.015),(.084,.098,.070))]:
        cage=api.ellipsoid_cage(center,radii,seed+len(objects)*31,3 if lod==0 else 2)
        cage.group("nuclear_membrane",range(len(cage.vertices)))
        objects.append(api.make_object(name,cage,col,0,"internal_organ"))
    # Dense, flattened, slightly unequal packets form an archipelago around
    # the retained nucleus. They are chloroplast-like compartments, never
    # daughter colonies. Their radial orbit is the existing authored motion.
    for index in range(16):
        tier=index//8; a=(index%8)*math.tau/8+tier*.37
        radius=.225 if tier==0 else .20
        center=(radius*math.cos(a),-.26 if tier==0 else .23,radius*math.sin(a))
        cage=api.ellipsoid_cage((0,0,0),(.066,.029,.044),seed+101+index,2 if lod==0 else 1)
        ca,sa=math.cos(a),math.sin(a)
        cage.vertices=[(center[0]+x*ca-z*sa,center[1]+y,center[2]+x*sa+z*ca) for x,y,z in cage.vertices]
        cage.group("retained_plastid",range(len(cage.vertices)))
        objects.append(api.make_object("Plastid_%02d"%index,cage,col,0,"internal_organ"))
    for obj in objects:
        gold=_weights(obj,"gold_boundary"); cilia=_weights(obj,"cilia")
        phase=[0.]*len(obj.data.vertices)
        for index in range(12): phase=[max(x,y) for x,y in zip(phase,_weights(obj,"cilium_%d"%index))]
        semantics=[]; phases={}
        for v in obj.data.vertices:
            p=tuple(api.gd(v.co)); x,y,z=p; phases[_key(p)]=phase[v.index]
            interior=obj.name!="Skin"
            window=0.
            if not interior:
                window=.78*math.exp(-((y+.06)/.38)**6)*max(0.,1-((abs(x)-.27)/.22)**2)*(1-cilia[v.index])
            wire=gold[v.index]
            if obj.name.startswith("Plastid_"):
                wire=.12+.08*(.5+.5*math.sin(x*22+y*13+z*11))
            semantics.append((wire,window,2 if interior else 4 if cilia[v.index]>.15 else 5 if window>.35 else 1))
        _SEMANTICS[obj.name]=semantics; _PHASE[obj.name]=phases
    return objects


def deform(point,law,phase,object_name):
    x,y,z=(float(v) for v in point)
    if object_name.startswith("Plastid_"):
        a=math.tau*max(0.,min(1.,law)); ca,sa=math.cos(a),math.sin(a)
        return (x*ca-z*sa,y,x*sa+z*ca)
    weight=_PHASE.get(object_name,{}).get(_key(point),0.)
    if weight:
        angle=math.atan2(z,x)
        bend=.015*phase*weight*weight
        x-=math.sin(angle)*bend; z+=math.cos(angle)*bend
        y+=.006*phase*weight*weight
    return (x,y,z)


def vertex_semantics(obj): return list(_SEMANTICS[obj.name])
def rig_specs():
    return [("DEF_posterior",(0,-.48,0),(0,-.04,0)),
            ("DEF_anterior",(0,-.04,0),(0,.47,0))]


def metadata(species,objects):
    if species!="mesodinium": raise ValueError("wrong species")
    return {"parts":[{"object":o.name,"role":o["anatomy_role"],"topology":"closed",
                      "container":None if o.name=="Skin" else "Skin"} for o in objects],
            "attachments":[],
            "required_regions":[{"object":"Skin","vertex_group":g,"min_vertices":3} for g in
                ("posterior_lobe","anterior_lobe","equatorial_waist","oral_vestibule","cilia")]
                +[{"object":"RetainedPreyNucleus","vertex_group":"nuclear_membrane","min_vertices":3},
                  {"object":"Plastid_00","vertex_group":"retained_plastid","min_vertices":3}]}
