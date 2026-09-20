"""External Lacrymaria authoring module; no import-time Blender mutations.

A continuous trunk/pleated neck/head enclosure samples a deployable membrane.
The axial search is owned by the existing controller and runtime curve, not
this module. Source law keys preserve the existing 1.2..6.4 body-length reach.

Mechanism reference: Flaum/Prakash 2024, Science, PMID38843314; the authors'
microscopy dataset doi:10.5061/dryad.4xgxd25g0 describes curved-crease cortical
origami and repeated membrane deployment. This is an original, bounded visual
analogue. It does not reproduce their microscopy or solve cellular mechanics.
Neck lateral area is constrained numerically in normalized authoring space;
individual morph anisotropy and actual GPU bending need native verification.
"""
import math
import struct
from functools import lru_cache

SPECIES_ID = 5
NECK_ROOT = (0., .03, .37)
NECK_REACH = (1.2, 6.4)
HEAD_BACK = -.11
ROOT_RADIUS = .040
FOLDS = 12
POINTS = {}
SEMANTICS = {}
BINDINGS = {}


def _smooth(value):
    value=max(0.,min(1.,value)); return value*value*(3.-2.*value)


def _key(point):
    return tuple(round(float(value),8) for value in point)


def _reach(law):
    return NECK_REACH[0]+(NECK_REACH[1]-NECK_REACH[0])*law


def _amplitude(law):
    return .080*(1.-law)**1.5


def _neck_area(mean,law):
    # Surface-of-revolution metric including the helical angular derivative.
    total=0.; ns,na=96,24
    amp=_amplitude(law); length=_reach(law)+HEAD_BACK
    for i in range(ns):
        u=(i+.5)/ns; envelope=math.sin(math.pi*u)**2
        derivative=math.pi*math.sin(math.tau*u)
        for j in range(na):
            angle=(j+.5)*math.tau/na
            phase=math.tau*FOLDS*u+2.*angle
            wave=mean-ROOT_RADIUS+amp*math.cos(phase)
            radius=ROOT_RADIUS+envelope*wave
            ds=derivative*wave-envelope*amp*math.tau*FOLDS*math.sin(phase)
            da=-envelope*amp*2.*math.sin(phase)
            total+=math.sqrt((radius*ds)**2+length*length*(radius*radius+da*da))
    return total*math.tau/(ns*na)


@lru_cache(maxsize=128)
def _mean_radius(law):
    if law==0.: return .120
    target=_neck_area(.120,0.)
    low=_amplitude(law)+.012; high=.30
    if _neck_area(low,law)>target or _neck_area(high,law)<target:
        raise ValueError('Lacrymaria membrane area has no positive-radius solution')
    for _ in range(28):
        mid=(low+high)*.5
        if _neck_area(mid,law)<target: low=mid
        else: high=mid
    return (low+high)*.5


def _radius(u,angle,law):
    envelope=math.sin(math.pi*u)**2
    return ROOT_RADIUS+envelope*(_mean_radius(law)-ROOT_RADIUS+
        _amplitude(law)*math.cos(math.tau*FOLDS*u+2.*angle))


def _neck_point(u,angle,law,fraction=1.,offset=0.):
    radius=_radius(u,angle,law)*fraction+offset
    return (radius*math.cos(angle),NECK_ROOT[1]+radius*math.sin(angle),
            NECK_ROOT[2]+(_reach(law)+HEAD_BACK)*u)


# Body stops at the exact root circle. The neck shares that vertex ring.
BODY = ((-.65,.025,.030),(-.61,.15,.13),(-.51,.30,.25),
        (-.36,.41,.34),(-.17,.44,.37),(.02,.36,.32),
        (.18,.24,.23),(.29,.125,.135),(.37,ROOT_RADIUS,ROOT_RADIUS))
# Head center is exactly root+reach. A rolled feeding lip turns inward to a
# genuine invagination; its deep floor closes the anatomical tissue volume.
HEAD = ((HEAD_BACK,ROOT_RADIUS),(-.075,.105),(-.025,.137),(.035,.142),
        (.085,.115),(.115,.080),(.125,.058),(.112,.039),(.075,.025),(.049,.008))


def _evaluate(parameter,law,phase):
    kind=parameter[0]
    if kind=='body':
        _,row,angle=parameter; z,rx,ry=BODY[row]
        breathing=1.+phase*.008*math.sin(math.pi*row/(len(BODY)-1))**2
        cy=NECK_ROOT[1]*_smooth((z+.25)/.62)
        return (rx*math.cos(angle)*breathing,cy+ry*math.sin(angle)*breathing,z)
    if kind=='neck': return _neck_point(parameter[1],parameter[2],law)
    if kind=='head':
        _,row,angle=parameter; z,radius=HEAD[row]
        return (radius*math.cos(angle),NECK_ROOT[1]+radius*.90*math.sin(angle),
                NECK_ROOT[2]+_reach(law)+z)
    if kind=='conduit':
        _,domain,axial,angle,inner=parameter
        radius=.006 if inner else .014
        if domain=='body':
            return (radius*math.cos(angle),NECK_ROOT[1]+radius*math.sin(angle),axial)
        z=NECK_ROOT[2]+(_reach(law)+HEAD_BACK)*axial if domain=='neck' else NECK_ROOT[2]+_reach(law)+axial
        return (radius*math.cos(angle),NECK_ROOT[1]+radius*math.sin(angle),z)
    if kind=='support':
        _,u,angle=parameter; theta=math.tau*2.*u+.3
        center=_neck_point(u,theta,law,.55)
        return (center[0]+.0025*math.cos(angle),center[1]+.0025*math.sin(angle),center[2])
    if kind=='static': return parameter[1]
    raise ValueError('Unknown Lacrymaria anatomical parameter')


def _binding(parameter):
    kind=parameter[0]
    if kind in ('neck','support'): return (-2,parameter[1])
    if kind=='head': return (-3,1.)
    if kind=='conduit' and parameter[1]=='neck': return (-2,parameter[2])
    if kind=='conduit' and parameter[1]=='head': return (-3,1.)
    return (-1,0.)


class Geometry:
    def __init__(self,name):
        self.name=name; self.vertices=[]; self.parameters=[]; self.faces=[]
        self.groups={}; self.semantics=[]
    def vertex(self,p,groups=(),semantic=(0.,0.,2)):
        index=len(self.vertices); self.parameters.append(p)
        self.vertices.append(_evaluate(p,0.,0.)); self.semantics.append(semantic)
        for group in groups: self.groups.setdefault(group,{})[index]=1.
        return index
    def connect(self,a,b):
        for i in range(len(a)):
            self.faces.append((a[i],a[(i+1)%len(a)],b[(i+1)%len(b)],b[i]))


def _skin(lod):
    g=Geometry('Skin'); sides=24 if lod==0 else 12
    axial=192 if lod==0 else 96; previous=None
    for row in range(len(BODY)):
        groups=('body','neck_root') if row==len(BODY)-1 else ('body',)
        ring=[]
        for j in range(sides):
            angle=j*math.tau/sides
            window=.62*max(0.,1.-((BODY[row][0]+.18)/.34)**2)*max(0.,math.cos(angle-.7))**6
            semantic=(.08 if row==len(BODY)-1 else .015,window,5 if window>.35 else 1)
            ring.append(g.vertex(('body',row,angle),groups,semantic))
        if previous is None: g.faces.append(tuple(reversed(ring)))
        else: g.connect(previous,ring)
        previous=ring
    for i in range(1,axial+1):
        u=i/axial
        groups=('neck','head_root') if i==axial else ('neck',)
        ring=[g.vertex(('neck',u,j*math.tau/sides),groups,(.01,.72,5)) for j in range(sides)]
        g.connect(previous,ring); previous=ring
    # HEAD[0] is the shared neck endpoint, so begin at the next row.
    for row in range(1,len(HEAD)):
        groups=('head','mouth') if row>=5 else ('head',)
        ring=[g.vertex(('head',row,j*math.tau/sides),groups,
              (.60 if row in (5,6,7) else .025,.35 if row<5 else .1,3 if row in (5,6,7) else 1)) for j in range(sides)]
        g.connect(previous,ring); previous=ring
    g.faces.append(tuple(previous))
    return g


def _conduit(lod):
    g=Geometry('FeedingConduit'); sides=8 if lod==0 else 4
    axial=96 if lod==0 else 48
    stations=[('body',z) for z in (-.30,-.10,.12,NECK_ROOT[2])]+[('neck',i/axial) for i in range(1,axial+1)]+[('head',z) for z in (-.055,.0,.04)]
    shells=[]
    for inner in (False,True):
        rings=[]
        for domain,value in stations:
            ring=[g.vertex(('conduit',domain,value,j*math.tau/sides,inner),('lumen',),(0.,.08,2)) for j in range(sides)]
            if rings:
                before=len(g.faces);g.connect(rings[-1],ring)
                if inner: g.faces[before:]=[tuple(reversed(f)) for f in g.faces[before:]]
            rings.append(ring)
        shells.append(rings)
    outer,inner=shells
    for i in range(sides):
        j=(i+1)%sides
        g.faces.append((outer[0][j],outer[0][i],inner[0][i],inner[0][j]))
        g.faces.append((outer[-1][i],outer[-1][j],inner[-1][j],inner[-1][i]))
    return g


def _support(lod):
    g=Geometry('CorticalRibbon'); sides=6 if lod==0 else 4
    axial=192 if lod==0 else 96; previous=None
    for i in range(axial+1):
        # All actual reserve-pleat knots are sampled by the contained ribbon.
        ring=[g.vertex(('support',i/axial,j*math.tau/sides),('cortical_support',),(.10,.03,2)) for j in range(sides)]
        if previous is None:g.faces.append(tuple(reversed(ring)))
        else:g.connect(previous,ring)
        previous=ring
    g.faces.append(tuple(previous))
    return g


def build_objects(api,col,lod,seed):
    if lod not in (0,1): raise ValueError('Lacrymaria LOD must be0 or1')
    objects=[]
    for model in (_skin(lod),_conduit(lod),_support(lod)):
        cage=api.Cage();cage.vertices=model.vertices;cage.faces=model.faces;cage.groups=model.groups
        obj=api.make_object(model.name,cage,col,0,'continuous_skin' if model.name=='Skin' else 'internal_organ')
        if len(obj.data.vertices)!=len(model.vertices): raise ValueError('Lacrymaria realized topology changed')
        original={_key(struct.unpack('3f',struct.pack('3f',*point))):i for i,point in enumerate(model.vertices)}
        parameters={};semantics=[];bindings=[]
        for vertex in obj.data.vertices:
            point=tuple(api.gd(vertex.co));index=original.get(_key(point))
            if index is None: raise ValueError('Lacrymaria realized parameter vertex is missing')
            parameter=model.parameters[index];parameters[_key(point)]=parameter
            semantics.append(model.semantics[index]);bindings.append(_binding(parameter))
        POINTS[obj.name]=parameters;SEMANTICS[obj.name]=semantics;BINDINGS[obj.name]=bindings;objects.append(obj)
    for name,center,radius,offset in (
        ('Macronucleus',(-.09,.07,-.23),(.115,.13,.20),1),
        ('FoodVacuole_A',(.19,.045,-.08),(.060,.077,.081),2),
        ('FoodVacuole_B',(.09,-.13,-.35),(.067,.055,.061),3),
        ('PosteriorVacuole',(-.17,-.055,-.40),(.064,.072,.069),4)):
        obj=api.make_object(name,api.ellipsoid_cage(center,radius,seed+offset,2 if lod==0 else 1),col,0,'internal_organ')
        POINTS[name]={_key(api.gd(v.co)):('static',tuple(api.gd(v.co))) for v in obj.data.vertices}
        SEMANTICS[name]=[(.025,.05,2)]*len(obj.data.vertices);BINDINGS[name]=[(-1,0.)]*len(obj.data.vertices);objects.append(obj)
    return objects


def deform(point,law,phase,object_name):
    parameter=POINTS.get(object_name,{}).get(_key(point))
    if parameter is None: raise ValueError('Build Lacrymaria before evaluating an anatomical parameter')
    return _evaluate(parameter,max(0.,min(1.,float(law))),max(-1.,min(1.,float(phase))))


def vertex_semantics(obj): return list(SEMANTICS[obj.name])
def vertex_bindings(obj): return list(BINDINGS[obj.name])


def rig_specs():
    return [('DEF_trunk',(0.,.03,-.45),NECK_ROOT)]+[
        ('DEF_neck_%02d'%i,(0.,.03,.37+i*.13625),(0.,.03,.37+(i+1)*.13625)) for i in range(8)]+[
        ('DEF_head',(0.,.03,1.46),(0.,.03,1.70))]


def metadata(species,objects):
    if species!='lacrymaria': raise ValueError('Wrong Lacrymaria metadata species')
    return {
        'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
        'attachments':[],
        'required_regions':[{'object':'Skin','vertex_group':g,'min_vertices':3} for g in ('body','neck_root','neck','head_root','head','mouth')]+
            [{'object':'FeedingConduit','vertex_group':'lumen','min_vertices':3},{'object':'CorticalRibbon','vertex_group':'cortical_support','min_vertices':3}],
        'runtime_fields':{'motion_profile':'lacrymaria_search','neck_root':list(NECK_ROOT),'neck_reach':list(NECK_REACH)},
    }
