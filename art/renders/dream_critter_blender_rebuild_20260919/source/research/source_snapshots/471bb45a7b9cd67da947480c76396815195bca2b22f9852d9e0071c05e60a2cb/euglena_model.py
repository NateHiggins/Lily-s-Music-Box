"""Continuous Euglena pellicle, anterior reservoir and rooted flagellum.

Mechanism references: https://pmc.ncbi.nlm.nih.gov/articles/PMC6522345/ and
https://pmc.ncbi.nlm.nih.gov/articles/PMC3497777/ . Pellicle sliding and traveling
metaboly guide a common deformation cage, not a molecular or isometric model.
The existing controller's law.x is the only clock. Body lookup is 1.7*phase;
flagellum lookup is phase. Root translation comes from actual source anchors.
An eyespot is visible anatomy, not a claim of implemented directional sensing.
Original proposed geometry/material masks; no image tracing or asset reuse.
"""
import math

SPECIES_ID=10
MOTION_PROFILE='euglena_metaboly'
CILIUM_BRANCH_COUNT=1
LAW_CYCLE_CLOSED=True
NEUTRAL_PHASE_KEYS=True
_SEMANTICS={}
_BINDINGS={}
_PARAMETERS={}
ROOT=(0.,0.,.505)
PROFILE=[(-.52,.010),(-.49,.060),(-.43,.160),(-.34,.260),(-.20,.355),
         (0.,.40),(.16,.35),(.29,.26),(.38,.16),(.43,.12),(.47,.10),
         (.48,.073),(.465,.040),(.405,.030),(.394,.012)]


def _key(p):return tuple(round(float(x),8) for x in p)
def _weights(obj,name):
    group=obj.vertex_groups.get(name)
    return [next((float(g.weight) for g in v.groups if group and g.group==group.index),0.) for v in obj.data.vertices]


def _body(p,angle):
    x,y,z=p;twist=z*2.3;wave=.11*math.sin(angle+z*6.)
    scale=(.72+.28*math.cos(z*math.pi/2))*(1+wave)
    return ((x*math.cos(twist)-y*math.sin(twist))*scale+wave*(1-z*z),
            (x*math.sin(twist)+y*math.cos(twist))*scale,z)


def _flag_center(t,angle):
    root=_body(ROOT,angle)
    return (root[0]+.216*t+.13*t*math.cos(15*t+angle),
            root[1]+.175*t+.13*t*math.sin(15*t+angle),root[2]+1.35*t)


def _skin(api,lod):
    c=api.Cage();around=32 if lod==0 else 16;rings=[]
    for row,(z,radius) in enumerate(PROFILE):
        ring=[]
        for j in range(around):
            a=math.tau*j/around;relief=1+.012*math.cos(a*8+z*7)*(1 if row<11 else 0)
            ring.append(c.vertex((radius*math.cos(a)*relief,radius*math.sin(a)*relief,z)))
        if rings:c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    c.group('pellicle',sum(rings[:11],[]));c.group('reservoir',sum(rings[11:],[]));c.group('reservoir_floor',rings[-1]);c.group('gold_boundary',rings[11],.23)
    # Root is the actual reservoir floor ring. The flagellum closes that tissue
    # without a separate disconnected tube or a capped membrane over its base.
    previous=rings[-1]
    # The protected basal shaft follows the body cage through the reservoir.
    # The independent external beat begins at the actual exposed shaft ring;
    # that zero-weight ring is the GPU's measured cilium root anchor.
    for z in (.410,.435,.46,.485,.505):
        ring=[c.vertex((.0075*math.cos(math.tau*j/around),.0075*math.sin(math.tau*j/around),z)) for j in range(around)]
        c.connect(previous,ring);c.group('flagellum',ring);previous=ring
    c.group('cilium_0_root',previous)
    count=48 if lod==0 else 24
    for step in range(1,count+1):
        t=step/count;root0=_body(ROOT,0);center=_flag_center(t,0)
        # Authoring points for this branch are already in the neutral body frame.
        radius=.0075*(1-t)+.0012
        ring=[c.vertex((center[0]+radius*math.cos(math.tau*j/around),center[1]+radius*math.sin(math.tau*j/around),center[2])) for j in range(around)]
        c.connect(previous,ring);c.group('cilium_0',ring,t);c.group('flagellum',ring);previous=ring
    c.faces.append(tuple(previous))
    return c


def _evaluate(parameter,angle):
    if parameter[0]=='body':return _body(parameter[1],angle)
    _,t,offset=parameter;center=_flag_center(t,angle)
    return tuple(center[i]+offset[i] for i in range(3))


def build_objects(api,col,lod,seed):
    skin=api.make_object('Skin',_skin(api,lod),col,0,'continuous_skin');objects=[skin]
    for index in range(8):
        angle=math.tau*index/8+.17;z=(-.22 if index%2==0 else .13)
        center=(.22*math.cos(angle),.22*math.sin(angle),z)
        cage=api.ellipsoid_cage(center,(.052,.046,.12),seed+index+10,2 if lod==0 else 1)
        # Flatten each plastid across its local radial direction.
        for i,p in enumerate(cage.vertices):
            delta=[p[j]-center[j] for j in range(3)];dot=delta[0]*math.cos(angle)+delta[1]*math.sin(angle)
            cage.vertices[i]=(p[0]-.48*dot*math.cos(angle),p[1]-.48*dot*math.sin(angle),p[2])
        objects.append(api.make_object('Plastid_%02d'%index,cage,col,0,'internal_organ'))
    for name,center,radius,offset in [('Nucleus',(0.,.0,-.065),(.098,.089,.115),1),('Eyespot',(.17,-.035,.29),(.040,.023,.042),2),('Paramylon_A',(-.08,.09,-.31),(.033,.026,.046),3),('Paramylon_B',(.09,-.10,-.30),(.030,.029,.047),4),('Paramylon_C',(.10,.10,.13),(.029,.023,.038),5)]:
        objects.append(api.make_object(name,api.ellipsoid_cage(center,radius,seed+offset+80,2 if lod==0 else 1),col,0,'internal_organ'))
    for obj in objects:
        flags=_weights(obj,'cilium_0');gold=_weights(obj,'gold_boundary');parameters={};semantics=[];bindings=[]
        for vertex in obj.data.vertices:
            original=tuple(api.gd(vertex.co));weight=flags[vertex.index]
            if weight>1e-7:
                center=_flag_center(weight,0);parameter=('flag',weight,tuple(original[i]-center[i] for i in range(3)))
                point=_evaluate(parameter,0);binding=(-2,weight)
            else:parameter=('body',original);point=_evaluate(parameter,0);binding=(-1,0.)
            vertex.co=api.bl(point);realized=tuple(api.gd(vertex.co));parameters[_key(realized)]=parameter;bindings.append(binding)
            window=0.
            if obj.name=='Skin' and not weight:
                window=.73*max(0.,1.-((original[0]+.12)/.24)**2-((original[2]+.06)/.38)**2)*min(1.,max(0.,-original[1]/.25))
            region=2 if obj.name!='Skin' else 4 if weight else 5 if window>.35 else 1
            semantics.append((.38 if obj.name=='Eyespot' else gold[vertex.index],window,region))
        obj.data.update();_PARAMETERS[obj.name]=parameters;_SEMANTICS[obj.name]=semantics;_BINDINGS[obj.name]=bindings
    return objects


def deform(point,law,phase,object_name):
    parameter=_PARAMETERS[object_name].get(_key(point))
    if parameter is None:raise ValueError('Missing realized Euglena parameter')
    angle=0. if law<=0 or law>=1 else math.tau*law
    return _evaluate(parameter,angle)


def rig_specs():return [('DEF_cortex',(0,0,-.5),ROOT)]+[('DEF_flag_%02d'%i,(0,0,.394+i*.27),(0,0,.394+(i+1)*.27)) for i in range(5)]
def vertex_semantics(obj):return list(_SEMANTICS[obj.name])
def vertex_bindings(obj):return list(_BINDINGS[obj.name])
def metadata(species,objects):
    if species!='euglena':raise ValueError('Wrong Euglena species')
    return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
            'attachments':[], 'required_regions':[{'object':'Skin','vertex_group':g,'min_vertices':3} for g in ('pellicle','reservoir','cilium_0_root','flagellum')]}
