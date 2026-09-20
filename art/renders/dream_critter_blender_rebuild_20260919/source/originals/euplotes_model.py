"""Euplotes cortex and fourteen cirri carried by eight existing gait groups.

Form/mechanism reference: https://pmc.ncbi.nlm.nih.gov/articles/PMC9474717/ .
Fourteen visible bundles mapped to eight render controls are an explicit game
abstraction, not a claim that this anatomy reproduces a measured specimen.
The controller has no Euplotes CPU foot-IK state. Its existing four discrete
postures are selected by mod(floor(law.x),4)/4; no new locomotion is introduced.
All geometry and material masks are original; reference pixels are not reused.
"""
import math

SPECIES_ID=7
MOTION_PROFILE='euplotes_cirral_walk'
CILIUM_BRANCH_COUNT=6
LAW_CYCLE_CLOSED=True
NEUTRAL_PHASE_KEYS=True
# Two cirri for groups0..5 and one for6..7: fourteen, with explicit ownership.
CIRRUS_CONTROLS=(0,0,1,1,2,2,3,3,4,4,5,5,6,7)
_SEMANTICS={}
_BINDINGS={}
_POINT_CONTROLS={}


def _key(p): return tuple(round(float(x),8) for x in p)
def _weights(obj,name):
    g=obj.vertex_groups.get(name)
    return [next((float(w.weight) for w in v.groups if g and w.group==g.index),0.) for v in obj.data.vertices]


def _cirrus(c,face,base,side,row,index,lod):
    root=list(c.faces[face]);c.faces[face]=();previous=root
    name='cirrus_%02d'%index;c.group(name+'_root',root)
    dy=c.vertices[root[0]][1]-base[1];dz=c.vertices[root[0]][2]-base[2];start=math.atan2(dz,dy)
    a=math.atan2(c.vertices[root[1]][2]-base[2],c.vertices[root[1]][1]-base[1]);direction=1 if math.sin(a-start)>0 else -1
    sides=8 if lod==0 else 4;steps=16 if lod==0 else 10
    for step in range(1,steps+1):
        t=step/steps;radius=.009*(1-t)+.0018
        center=(base[0]+side*(.34-.10*row/3)*t,base[1]-.30*t,base[2]+.12*t)
        ring=[c.vertex((center[0],center[1]+radius*math.cos(start+direction*math.tau*j/sides),center[2]+radius*math.sin(start+direction*math.tau*j/sides))) for j in range(sides)]
        c.connect(previous,ring);c.group(name,ring,t);c.group('cirri',ring);previous=ring
    c.faces.append(tuple(previous))


def _skin(api,lod):
    c=api.Cage();around=32 if lod==0 else 16;rings=[];rows=39 if lod==0 else 27
    for row in range(rows):
        a=-math.pi/2+.035+(math.pi-.07)*row/(rows-1);z=.52*math.sin(a);r=math.cos(a)
        width=.48*r*(.84+.16*(z/.52+1)/2);height=.16*r
        ring=[]
        for j in range(around):
            angle=math.tau*j/around;x=.035*r*r+width*math.cos(angle);y=height*math.sin(angle)
            # Fine dorsal cortical relief and a shallow ventral oral depression.
            if y>0:y+=.005*math.cos(angle*8+z*2)*r
            if y<0:y+=.020*math.exp(-((x+.09)/.15)**2-((z-.24)/.18)**2)
            ring.append(c.vertex((x,y,z)))
        if rings:c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])));c.faces.append(tuple(rings[-1]))
    c.group('cortex',sum(rings,[]));used=set();roots={}
    faces=list(range(len(c.faces)-2))
    for index,control in enumerate(CIRRUS_CONTROLS):
        side=-1 if control<4 else 1;row=control%4
        pair=[i for i,v in enumerate(CIRRUS_CONTROLS) if v==control]
        offset=0 if len(pair)==1 else (-.020 if index==pair[0] else .020)
        z_goal=.38-row*.76/3+offset
        goal=(side*.50*math.sqrt(max(.01,1-(z_goal/.52)**2)),-.020,z_goal)
        def distance(fi):
            center=[sum(c.vertices[v][a] for v in c.faces[fi])/len(c.faces[fi]) for a in range(3)]
            return (center[0]-goal[0])**2+(center[1]-goal[1])**2+20*(center[2]-goal[2])**2
        candidates=[fi for fi in faces if fi not in used and sum(c.vertices[v][1] for v in c.faces[fi])/len(c.faces[fi])<-.005]
        face=min(candidates,key=distance);used.add(face)
        face=c.inset(face,.15);base=tuple(sum(c.vertices[v][a] for v in c.faces[face])/len(c.faces[face]) for a in range(3))
        roots[index]=(base,side,row)
        _cirrus(c,face,base,side,row,index,lod)
        c.group('gold_boundary',c.groups['cirrus_%02d_root'%index].keys(),.32)
    # Six fine oral membranelle exemplars are rooted in the same ventral tissue.
    for index in range(6):
        goal=(-.13+index*.043,-.1,.32)
        def distance(fi):
            center=[sum(c.vertices[v][a] for v in c.faces[fi])/len(c.faces[fi]) for a in range(3)]
            return sum((center[a]-goal[a])**2 for a in range(3))
        face=min((fi for fi in faces if fi not in used),key=distance);used.add(face);face=c.inset(face,.09)
        base=tuple(sum(c.vertices[v][a] for v in c.faces[face])/len(c.faces[face]) for a in range(3))
        centers=[(base[0]-.016*t,base[1]-.035*t,base[2]+.09*t) for t in (.5,1.)]
        c.extrude(face,centers,(.003,.0008),group='cilium_%d'%index,region='oral_field')
    return c,roots


def build_objects(api,col,lod,seed):
    cage,roots=_skin(api,lod);skin=api.make_object('Skin',cage,col,0,'continuous_skin');objects=[skin]
    centers=[(.02+.15*math.cos(-2.35+4.7*i/28),.012,.26*math.sin(-2.35+4.7*i/28)) for i in range(29)]
    objects.append(api.make_object('Macronucleus',api.tube_cage(centers,[.024]*len(centers),8 if lod==0 else 6),col,0,'internal_organ'))
    for name,center,radius,offset in [('Micronucleus',(-.08,.015,-.08),(.030,.031,.028),1),('ContractileVacuole',(.20,.01,.18),(.050,.037,.048),2),('FoodVacuole',(-.20,.005,-.12),(.047,.039,.061),3)]:
        objects.append(api.make_object(name,api.ellipsoid_cage(center,radius,seed+offset,2 if lod==0 else 1),col,0,'internal_organ'))
    for obj in objects:
        tables=[_weights(obj,'cirrus_%02d'%i) for i in range(14)];gold=_weights(obj,'gold_boundary');oral=_weights(obj,'oral_field');oral_tables=[_weights(obj,'cilium_%d'%i) for i in range(6)];points={};semantics=[];bindings=[]
        for v in obj.data.vertices:
            p=tuple(api.gd(v.co));values=[t[v.index] for t in tables];w=max(values)
            if w>1e-7:
                index=values.index(w);base,side,row=roots[index]
                direction=(side*(.34-.10*row/3),-.30,.12)
                # Actual axial coordinate keeps tiny cap facets in one affine section.
                t=max(0.,min(1.,(p[0]-base[0])/direction[0]))
                control=CIRRUS_CONTROLS[index];lift=_lift(control,t,0)
                v.co=api.bl(tuple(p[a]+lift[a] for a in range(3)));points[_key(api.gd(v.co))]=(control,t)
            window=0.
            if obj.name=='Skin' and not w and p[1]>0:
                window=.72*max(0.,1.-((p[0]-.09)/.24)**2-((p[2]+.08)/.34)**2)
            region=2 if obj.name!='Skin' else 4 if w or oral[v.index]>.1 else 5 if window>.35 else 1
            semantics.append((gold[v.index],window,region))
            oral_values=[row[v.index] for row in oral_tables];oral_weight=max(oral_values)
            bindings.append((-2-oral_values.index(oral_weight),oral_weight) if oral_weight>1e-7 else (-1,0.))
        obj.data.update()
        _POINT_CONTROLS[obj.name]=points;_SEMANTICS[obj.name]=semantics;_BINDINGS[obj.name]=bindings
    return objects


def _lift(control,t,state):
    if (state+control)%4!=3:return (0.,0.,0.)
    u=max(0.,min(1.,(t-.12)/.20));attachment_envelope=u*u*(3-2*u)
    lift=math.sin(math.pi*t)*attachment_envelope
    # Existing lift/sweep terms with a fixed basal insertion until the shaft
    # clears the cortex. Terminal points and four-state ownership are unchanged.
    return (0.,.34*t*lift+.42*lift*math.sin(math.pi*t),-.24*t*lift)


def deform(point,law,phase,object_name):
    binding=_POINT_CONTROLS.get(object_name,{}).get(_key(point))
    if binding is None or law<=0 or law>=1:return tuple(point)
    control,t=binding;state=float(law)*4;i=int(state);f=state-i
    a=_lift(control,t,i);b=_lift(control,t,(i+1)%4);rest=_lift(control,t,0)
    return tuple(float(point[k])+a[k]*(1-f)+b[k]*f-rest[k] for k in range(3))


def rig_specs():return [('DEF_cortex',(0.,0.,-.45),(0.,0.,.45))]
def vertex_semantics(obj):return list(_SEMANTICS[obj.name])
def vertex_bindings(obj):return list(_BINDINGS[obj.name])
def metadata(species,objects):
    if species!='euplotes':raise ValueError('Wrong Euplotes species')
    return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
            'attachments':[], 'required_regions':[{'object':'Skin','vertex_group':'cirrus_%02d_root'%i,'min_vertices':3} for i in range(14)]+[{'object':'Skin','vertex_group':'oral_field','min_vertices':3}],
            'runtime_fields':{'motion_profile':MOTION_PROFILE,'cirrus_controls':list(CIRRUS_CONTROLS)}}
