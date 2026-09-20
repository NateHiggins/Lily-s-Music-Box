"""Salpingoeca: separate continuous cells joined through basal extracellular matrix.

Form-only reference: https://pubmed.ncbi.nlm.nih.gov/31896587/ (Larson et al.,
2020, doi:10.1073/pnas.1909447117). Basal ECM, outward collars and flagella
follow the paper's organization. Twelve cells and the slow cyclic opening
are authored presentation for the existing controller, not observed growth.
No reference pixels enter this model. Skin is the first cell's API alias;
the colony is explicitly twelve separately closed cells, never fused flesh.
"""
import math

SPECIES_ID = 14
MOTION_PROFILE = "salpingoeca_rosette"
REFERENCE_URLS = ("https://pubmed.ncbi.nlm.nih.gov/31896587/",)
_SEMANTICS = {}
_DIRECTIONS = {}
_PHASE = {}


def _add(a,b): return tuple(x+y for x,y in zip(a,b))
def _scale(a,s): return tuple(x*s for x in a)
def _dot(a,b): return sum(x*y for x,y in zip(a,b))
def _cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def _unit(a): return _scale(a,1/math.sqrt(_dot(a,a)))
def _key(p): return tuple(round(float(x),8) for x in p)


def _frame(index):
    y=1-2*(index+.5)/12
    r=math.sqrt(1-y*y); angle=index*2.399963229728653
    axis=(r*math.cos(angle),y,r*math.sin(angle))
    side=_unit(_cross(axis,(0,1,0) if abs(y)<.9 else (1,0,0)))
    return side,axis,_cross(side,axis)


def _world(p,frame):
    side,axis,other=frame
    return tuple(side[i]*p[0]+axis[i]*(p[1]+.29)+other[i]*p[2] for i in range(3))


def _cell(api,lod,index):
    c=api.Cage(); around=16 if lod==0 else 8
    profile=[(-.115,.014),(-.096,.035),(-.065,.059),(-.020,.075),
             (.027,.071),(.060,.052),(.074,.039),(.085,.025),(.089,.008)]
    rings=[]; starts=[]
    for row,(y,radius) in enumerate(profile):
        ring=[c.vertex((radius*math.cos(math.tau*j/around),y,
                        radius*math.sin(math.tau*j/around))) for j in range(around)]
        if rings: starts.append(len(c.faces)); c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    c.faces.append(tuple(rings[-1])); flagface=len(c.faces)-1
    c.group("basal_pole",rings[0]+rings[1])
    c.group("collar_root",rings[6])
    c.group("gold_boundary",rings[6],.30)
    # Each microvillus is actually rooted in the same apical cortex. Sparse
    # low LOD exemplars preserve a cage-like collar, not a solid flower cup.
    collar_count=8 if lod==0 else 6
    for j in range(collar_count):
        sector=j*around//collar_count
        face=c.inset(starts[5]+sector,.12)
        ids=c.faces[face]
        base=tuple(sum(c.vertices[v][i] for v in ids)/len(ids) for i in range(3))
        a=math.atan2(base[2],base[0])
        centers=[((.051+.022*t)*math.cos(a),.067+.075*t,
                  (.051+.022*t)*math.sin(a)) for t in (.45,1.)]
        c.extrude(face,centers,(.0026,.0012),group="microvillus_%d"%j,region="collar")
    steps=8 if lod==0 else 4
    centers=[(.011*math.sin(t*math.pi),.089+.20*t,.006*t*t) for t in [i/steps for i in range(1,steps+1)]]
    radii=[.0038*(1-i/(steps+1))+.0005 for i in range(1,steps+1)]
    c.extrude(flagface,centers,radii,group="flagellum",region="flagellum")
    frame=_frame(index)
    c.vertices=[_world(p,frame) for p in c.vertices]
    return c


def _weights(obj,group):
    vg=obj.vertex_groups.get(group)
    return [next((float(g.weight) for g in v.groups if vg and g.group==vg.index),0.) for v in obj.data.vertices]


def build_objects(api,col,lod,seed):
    objects=[]
    for index in range(12):
        name="Skin" if index==0 else "Cell_%02d"%index
        frame=_frame(index)
        cell=api.make_object(name,_cell(api,lod,index),col,0,"continuous_skin" if index==0 else "external_organ")
        objects.append(cell)
        _DIRECTIONS[name]=frame[0]
        for label,center,radius in [("Nucleus",(0,-.025,0),(.026,.029,.026)),
                                    ("Vacuole",(.029,.015,0),(.018,.019,.018))]:
            cage=api.ellipsoid_cage(center,radius,seed+index*13,2 if lod==0 else 1)
            cage.vertices=[_world(p,frame) for p in cage.vertices]
            cage.group(label.lower(),range(len(cage.vertices)))
            obj=api.make_object("%s_%02d"%(label,index),cage,col,0,"internal_organ")
            obj["cell_container"]=name
            objects.append(obj); _DIRECTIONS[obj.name]=frame[0]
    # The center is extracellular and cell-free. Basal ends enter this soft
    # matrix; no invented nucleus or organ is placed in its central space.
    matrix=api.ellipsoid_cage((0,0,0),(.205,.205,.205),seed+899,3 if lod==0 else 2)
    matrix.group("extracellular_matrix",range(len(matrix.vertices)))
    objects.append(api.make_object("BasalMatrix",matrix,col,0,"support"))
    for obj in objects:
        gold=_weights(obj,"gold_boundary"); flag=_weights(obj,"flagellum"); collar=_weights(obj,"collar")
        semantics=[]; phases={}
        for v in obj.data.vertices:
            p=tuple(api.gd(v.co)); phases[_key(p)]=flag[v.index]
            interior=obj["anatomy_role"]=="internal_organ"
            radial=math.sqrt(sum(x*x for x in p))
            window=0.
            if obj.name=="BasalMatrix": window=.82
            elif not interior:
                # Broad soft lateral windows bounded to each cell cortex.
                window=.65*max(0.,1-((radial-.285)/.065)**2)*(1-flag[v.index])*(1-collar[v.index])
            semantics.append((gold[v.index],window,2 if interior else 4 if flag[v.index]>.2 or collar[v.index]>.2 else 5 if window>.35 else 1))
        _SEMANTICS[obj.name]=semantics; _PHASE[obj.name]=phases
    return objects


def deform(point,law,phase,object_name):
    # Existing micro_state gently unfurls the colony. A uniform mapping keeps
    # basal ECM/cell contacts and contained organs coherent throughout.
    scale=1+.06*max(0.,min(1.,law)); result=_scale(point,scale)
    weight=_PHASE.get(object_name,{}).get(_key(point),0.)
    if weight:
        result=_add(result,_scale(_DIRECTIONS[object_name],.026*phase*weight*weight))
    return result


def vertex_semantics(obj): return list(_SEMANTICS[obj.name])
def vertex_bindings(obj): return [(-1,0.) for _ in obj.data.vertices]
def rig_specs():
    return [("DEF_cell_%02d"%i,_world((0,-.1,0),_frame(i)),_world((0,.09,0),_frame(i))) for i in range(12)]


def metadata(species,objects):
    if species!="salpingoeca": raise ValueError("wrong species")
    return {"parts":[{"object":o.name,"role":o["anatomy_role"],"topology":"closed",
                      "container":o.get("cell_container")} for o in objects],
            "attachments":[],
            "required_regions":[{"object":"Skin","vertex_group":g,"min_vertices":3} for g in ("basal_pole","collar_root","collar","flagellum")]
                +[{"object":"BasalMatrix","vertex_group":"extracellular_matrix","min_vertices":3}]}
