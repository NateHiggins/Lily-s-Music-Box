"""Original Heliozoan cortex/ray authoring; controller owns selected-ray capture.

Kinoshita et al.2001 (PMID11596916) observed contractile tubules and granulation
in Actinophrys axopodia. The twelve-ray count and indexed 1.25â†’.48 contraction
are the existing game's abstraction. This mesh adds no prey simulation.
Source law keys retract every ray for structural testing; the runtime applies
that law only to the ray selected by round(law.y*11), using explicit bindings.
"""
import math

SPECIES_ID=9
DIRECTIONS=[]
for _index in range(12):
    _y=1.-2.*(_index+.5)/12.;_r=math.sqrt(1.-_y*_y);_a=_index*math.pi*(3.-math.sqrt(5.))
    DIRECTIONS.append((math.cos(_a)*_r,_y,math.sin(_a)*_r))
_BIND={};_SEM={};_UV={};_ROOTS=[]


def _key(p):return tuple(round(float(v),8) for v in p)
def _add(a,b):return tuple(x+y for x,y in zip(a,b))
def _mul(a,b):return tuple(x*b for x in a)
def _dot(a,b):return sum(x*y for x,y in zip(a,b))
def _length(a):return math.sqrt(_dot(a,a))
def _unit(a):return _mul(a,1./_length(a))
def _mean(points):return tuple(sum(p[i] for p in points)/len(points) for i in range(3))
def _weights(obj,name):
    group=obj.vertex_groups.get(name)
    if group is None:return [0.]*len(obj.data.vertices)
    return [next((g.weight for g in v.groups if g.group==group.index),0.) for v in obj.data.vertices]


def _skin(api,col,lod,seed):
    cage=api.ellipsoid_cage((0.,0.,0.),(.54,.52,.53),seed,1)
    original_faces=list(cage.faces);used=set()
    for index,direction in enumerate(DIRECTIONS):
        candidates=[]
        for fi,face in enumerate(original_faces):
            if fi in used:continue
            center=_mean([cage.vertices[i] for i in face])
            candidates.append((_dot(_unit(center),direction),fi))
        _,fi=max(candidates);used.add(fi)
        # Inset each sheath insertion; surrounding cortex remains continuous.
        fi=cage.inset(fi,.30)
        root=_mean([cage.vertices[i] for i in cage.faces[fi]])
        bend=_mul(_unit((direction[2],.13,-direction[0])),.035)
        centers=[_add(_add(root,_mul(direction,1.25*u)),_mul(bend,math.sin(math.pi*u))) for u in (.12,.28,.46,.65,.84,1.)]
        cage.extrude(fi,centers,(.020,.015,.012,.009,.006,.003),group='ray_%d'%index,region='rays')
    obj=api.make_object('Skin',cage,col,2 if lod==0 else 1,'continuous_skin')
    return obj


def _record(obj,api,code=-1,weights=None):
    ray_weights=[_weights(obj,'ray_%d'%i) for i in range(12)] if obj.name=='Skin' else []
    rows={};uv=[];sem=[]
    for v in obj.data.vertices:
        point=tuple(api.gd(v.co));which=code;weight=weights[v.index] if weights is not None else 0.
        if ray_weights:
            values=[row[v.index] for row in ray_weights];weight=max(values)
            which=-2-values.index(weight) if weight>1e-7 else -1
        if which<=-2:
            ray=-2-which
            weight=max(0.,min(1.,_dot(tuple(point[i]-_ROOTS[ray][i] for i in range(3)),DIRECTIONS[ray])/1.25))
        rows[_key(point)]=(which,weight)
        uv.append((which,weight))
        if obj.name=='Skin':
            window=.70 if which==-1 else .46
            sem.append((.07*max(0.,1.-weight),window,5))
        else:sem.append((.09 if obj.name.startswith('Axoneme') else .02,.04,2))
    _BIND[obj.name]=rows;_UV[obj.name]=uv;_SEM[obj.name]=sem


def _cores(api,col,skin,lod):
    result=[]
    for index in range(12):
        weights=_weights(skin,'ray_%d'%index);groups={}
        for v,w in zip(skin.data.vertices,weights):
            if .06<w<.97:groups.setdefault(round(w,5),[]).append(tuple(api.gd(v.co)))
        sections=[]
        for weight,points in sorted(groups.items()):
            if len(points)<3:continue
            center=_mean(points)
            radius=min(_length(tuple(p[i]-center[i] for i in range(3))) for p in points)*.10
            if radius<.00015:continue
            if sections and _length(tuple(center[i]-sections[-1][1][i] for i in range(3)))<.001:continue
            sections.append((weight,center,min(.0018,radius)))
        if len(sections)<4:raise ValueError('Heliozoan actual ray has too few interior sections')
        sides=6 if lod==0 else 4
        cage=api.tube_cage([row[1] for row in sections],[row[2] for row in sections],sides)
        obj=api.make_object('Axoneme_%02d'%index,cage,col,0,'internal_organ')
        # No topology-changing modifier; tube vertices retain station order.
        table=[]
        for v in obj.data.vertices:
            p=tuple(api.gd(v.co))
            station=min(range(len(sections)),key=lambda k:sum((p[i]-sections[k][1][i])**2 for i in range(3)))
            table.append(sections[station][0])
        _record(obj,api,-2-index,table);result.append(obj)
    return result


def build_objects(api,col,lod,seed):
    if lod not in (0,1):raise ValueError('Heliozoan LOD must be0 or1')
    skin=_skin(api,col,lod,seed)
    _ROOTS.clear()
    for index in range(12):
        values=_weights(skin,'ray_%d_root'%index);total=sum(values)
        _ROOTS.append(tuple(sum(api.gd(v.co)[axis]*w for v,w in zip(skin.data.vertices,values))/total for axis in range(3)))
    _record(skin,api)
    objects=[skin]+_cores(api,col,skin,lod)
    # Receiving vacuoles cluster behind particular ray roots; the center is
    # deliberately spacious instead of evenly filled with identical beads.
    for i,(ray,radius,depth) in enumerate(((0,.090,.28),(2,.080,.25),(4,.110,.24),(5,.065,.30),(8,.105,.24),(10,.075,.27))):
        center=_mul(DIRECTIONS[ray],depth)
        obj=api.make_object('ReceivingVacuole_%02d'%i,api.ellipsoid_cage(center,(radius,radius*.82,radius*.94),seed+20+i,2 if lod==0 else 1),col,0,'internal_organ')
        _record(obj,api);objects.append(obj)
    obj=api.make_object('EccentricNucleus',api.ellipsoid_cage((-.065,.020,.060),(.105,.095,.125),seed+50,2 if lod==0 else 1),col,0,'internal_organ')
    _record(obj,api);objects.append(obj)
    return objects


def deform(point,law,phase,object_name):
    p=tuple(float(v) for v in point);binding=_BIND.get(object_name,{}).get(_key(p))
    if binding is None:raise ValueError('Build Heliozoan before sampling deformation')
    code,weight=binding
    if code<=-2:p=_add(p,_mul(DIRECTIONS[-2-code],-.77*float(law)*weight))
    # One very small shared pulse carries cortex, receiving spaces and cores.
    return _mul(p,1.+float(phase)*.003)


def vertex_semantics(obj):return list(_SEM[obj.name])
def vertex_bindings(obj):return list(_UV[obj.name])
def rig_specs():
    return [('DEF_cortex',(0.,-.05,0.),(0.,.05,0.))]+[
        ('DEF_ray_%02d'%i,_mul(d,.40),_mul(d,1.65)) for i,d in enumerate(DIRECTIONS)]
def metadata(species,objects):
    if species!='heliozoan':raise ValueError('Wrong Heliozoan species')
    return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
      'attachments':[],
      'required_regions':[{'object':'Skin','vertex_group':'ray_%d_root'%i,'min_vertices':3} for i in range(12)],
      'runtime_fields':{'motion_profile':'heliozoan_capture'}}
