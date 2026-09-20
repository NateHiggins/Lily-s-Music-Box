"""Original Noctiluca anatomy: vacuolate cortex, sulcus, grooved capture arms.

Valiadi et al.2019 (PMC7351363) documents peripheral scintillons, including in
non-luminous strains. Region6 marks explicit anatomical sites; the existing
mechanical/debug response owns their flash. No new ordinary-play receptor or
prey simulation is asserted. A second, shorter capture arm preserves the
existing rare two-feeler game variant; the ordinary specimen exposes one.
"""
import math
import random

SPECIES_ID=12
CILIUM_BRANCH_COUNT=2
_BIND={};_UV={};_SEM={};_ROOTS=[]


def _key(p):return tuple(round(float(v),8) for v in p)
def _weights(obj,name):
    group=obj.vertex_groups.get(name)
    if group is None:return [0.]*len(obj.data.vertices)
    return [next((g.weight for g in v.groups if g.group==group.index),0.) for v in obj.data.vertices]


def _skin(api,col,lod):
    from mathutils import Vector
    cage=api.Cage();rings=[];segments=16
    for row in range(13):
        t=.045+(math.pi-.09)*row/12
        y=-math.cos(t)*.50
        radius=math.sin(t)*(.46+.045*(y+.50))
        ring=[]
        for j in range(segments):
            a=math.tau*j/segments
            # A structural feeding groove indents the front of the cortex.
            da=math.atan2(math.sin(a-math.pi*.5),math.cos(a-math.pi*.5))
            sulcus=.085*math.exp(-(da/.28)**2-((y+.11)/.26)**2)
            r=radius-sulcus
            ring.append(cage.vertex((r*math.cos(a)+.028*(1.-(y/.50)**2),y,r*.93*math.sin(a))))
        if rings:cage.connect(rings[-1],ring)
        rings.append(ring)
    cage.faces.append(tuple(reversed(rings[0])));cage.faces.append(tuple(rings[-1]))
    # One blind feeding vestibule is excavated into the sulcus. Tissue stays
    # closed and continuous around its rolled rim and invaginated floor.
    mouth_face=4*segments+4
    mouth_face=cage.inset(mouth_face,.50)
    center=sum((Vector(cage.vertices[i]) for i in cage.faces[mouth_face]),Vector())/4
    cage.extrude(mouth_face,[center+Vector((0.,0.,-.025)),center+Vector((0.,0.,-.060))],(.022,.013),group='feeding_sulcus',region='oral_lip')
    for branch,(face_index,flank,length) in enumerate(((4*segments+2,1.,.90),(4*segments+5,-1.,.54))):
        face_index=cage.inset(face_index,.30)
        root=list(cage.faces[face_index]);cage.faces[face_index]=()
        center=sum((Vector(cage.vertices[i]) for i in root),Vector())/4
        direction=Vector((flank*.52,-.22,1.)).normalized()
        side=Vector(cage.vertices[root[0]])-center;side=(side-direction*side.dot(direction)).normalized()
        other=direction.cross(side).normalized()
        if (Vector(cage.vertices[root[1]])-center).dot(other)<0:other=-other
        cage.group('cilium_%d_root'%branch,root)
        previous=root
        for step in range(1,9):
            u=step/8
            c=center+direction*(length*u)+Vector((flank*.055*math.sin(u*5.7)*u,0.,0.))
            radius=.035*(1.-u)+.009*u
            ring=[]
            for j in range(8):
                a=j*math.tau/8
                # A real longitudinal concavity, not a coloured stripe.
                groove=1.-.43*max(0.,math.cos(a))**6
                ring.append(cage.vertex(c+radius*groove*(side*math.cos(a)+other*math.sin(a))))
            cage.connect(previous,ring);cage.group('cilium_%d'%branch,ring,u);cage.group('capture_appendage',ring)
            previous=ring
        cage.faces.append(tuple(previous))
    return api.make_object('Skin',cage,col,2 if lod==0 else 1,'continuous_skin')


def _record(obj,api,region=2):
    branches=[_weights(obj,'cilium_%d'%i) for i in range(2)] if obj.name=='Skin' else []
    oral=_weights(obj,'oral_lip') if obj.name=='Skin' else [0.]*len(obj.data.vertices)
    bind={};uv=[];sem=[]
    for v in obj.data.vertices:
        p=tuple(api.gd(v.co));code=-1;weight=0.
        if branches:
            values=[row[v.index] for row in branches];weight=max(values)
            if weight>1e-7:code=-2-values.index(weight)
        if code<=-2:
            branch=-2-code;flank=1. if branch==0 else -1.
            direction=(flank*.52,-.22,1.);norm=math.sqrt(sum(x*x for x in direction))
            weight=max(0.,min(1.,sum((p[i]-_ROOTS[branch][i])*direction[i]/norm for i in range(3))/(.90 if branch==0 else .54)))
        bind[_key(p)]=(code,weight);uv.append((code,weight))
        if obj.name=='Skin':
            sem.append((.52*oral[v.index]+.025,.78 if code==-1 else .44,3 if oral[v.index]>.3 else 5))
        elif obj.name=='DominantVacuole':sem.append((0.,.92,5))
        elif region==6:sem.append((.02,.0,6))
        else:sem.append((.04,.06,2))
    _BIND[obj.name]=bind;_UV[obj.name]=uv;_SEM[obj.name]=sem


def build_objects(api,col,lod,seed):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    if lod not in (0,1):raise ValueError('Noctiluca LOD must be0 or1')
    skin=_skin(api,col,lod)
    _ROOTS.clear()
    for index in range(2):
        values=_weights(skin,'cilium_%d_root'%index);total=sum(values)
        _ROOTS.append(tuple(sum(api.gd(v.co)[axis]*w for v,w in zip(skin.data.vertices,values))/total for axis in range(3)))
    _record(skin,api);objects=[skin]
    for name,center,radius,offset,detail in (
        ('DominantVacuole',(.055,.02,.015),(.32,.315,.32),1,3 if lod==0 else 2),
        ('PeripheralNucleus',(-.335,.08,-.035),(.060,.080,.073),2,2 if lod==0 else 1)):
        obj=api.make_object(name,api.ellipsoid_cage(center,radius,seed+offset,detail),col,0,'internal_organ');_record(obj,api);objects.append(obj)
    # Original cytoplasmic paths occupy the peripheral sector beside the
    # dominant vacuole. No central opaque sphere or all-volume luminous fill.
    for i,(end_y,end_z) in enumerate(((.28,.16),(-.24,.19),(-.20,-.21))):
        points=[]
        for j in range(12):
            t=j/11
            points.append((-.335+.060*math.sin(t*math.pi*.7),.08+(end_y-.08)*t,-.035+(end_z+.035)*t))
        obj=api.make_object('CytoplasmicCord_%02d'%i,api.tube_cage(points,[.004]*(len(points)),6 if lod==0 else 4),col,0,'internal_organ');_record(obj,api);objects.append(obj)
    # Scintillon sites are anchored inward from the actual realized cortex.
    # Their separate region6 is the only newly authored flash-capable tissue.
    positions=[tuple(api.gd(v.co)) for v in skin.data.vertices]
    tree=BVHTree.FromPolygons([Vector(p) for p in positions],[tuple(p.vertices) for p in skin.data.polygons],all_triangles=True)
    rng=random.Random(seed+511)
    for i in range(24):
        y=1.-2.*(i+.5)/24;r=math.sqrt(max(0.,1.-y*y));a=i*math.pi*(3.-math.sqrt(5.))+rng.uniform(-.08,.08)
        direction=Vector((r*math.cos(a),y,r*math.sin(a))).normalized()
        hit,normal,_,_=tree.ray_cast(Vector(),direction,3.)
        if hit is None:raise ValueError('Noctiluca scintillon ray missed its containing cortex')
        center=hit-normal*.027
        obj=api.make_object('Scintillon_%02d'%i,api.ellipsoid_cage(center,(.009,.006,.007),seed+100+i,2 if lod==0 else 1),col,0,'internal_organ');_record(obj,api,6);objects.append(obj)
    return objects


def deform(point,law,phase,object_name):
    p=tuple(float(v) for v in point);binding=_BIND.get(object_name,{}).get(_key(p))
    if binding is None:raise ValueError('Build Noctiluca before sampling deformation')
    code,weight=binding;phase=float(phase)
    # law.z is a flash response; all law shape keys deliberately retain the
    # same geometry. Slow phase carries skin and all internal structures.
    q=[p[0]*(1.+phase*.010),p[1]*(1.-phase*.007),p[2]*(1.+phase*.006)]
    if code<=-2:
        flank=1. if code==-2 else -1.
        q[0]+=flank*phase*.11*weight*weight
        q[1]+=phase*.015*weight*(1.-weight)
    return tuple(q)


def vertex_semantics(obj):return list(_SEM[obj.name])
def vertex_bindings(obj):return list(_UV[obj.name])
def rig_specs():return [('DEF_cortex',(0.,-.30,0.),(0.,.30,0.)),('DEF_capture_0',(.25,-.16,.34),(.67,-.34,1.10)),('DEF_capture_1',(-.25,-.16,.34),(-.49,-.27,.80))]
def metadata(species,objects):
    if species!='noctiluca':raise ValueError('Wrong Noctiluca species')
    return {'parts':[{'object':o.name,'role':o['anatomy_role'],'topology':'closed','container':None if o.name=='Skin' else 'Skin'} for o in objects],
      'attachments':[],
      'required_regions':[{'object':'Skin','vertex_group':g,'min_vertices':3} for g in ('feeding_sulcus_root','cilium_0_root','cilium_1_root','capture_appendage')],
      'runtime_fields':{'motion_profile':'noctiluca_flash'}}
