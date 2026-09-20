"""Deterministic Blender anatomy pilots; no implicit repository writes.

blender --background --factory-startup --python build_dream_critter.py -- 
  --species tardigrade --output-root C:/explicit/output --seed 240304

The output tree mirrors art/blender/dream_critters and game/assets/dream/
critters_blender. LOD1 is the batch asset; LOD0 is the inspection reference.
Godot local coordinates are x side, y surface normal, z forward, normalized
by morph.wide/morph.tall/morph.length. Blender coordinates are (x,-z,y).
Soft appendages are extruded from skin faces; keratin hooks are separately
closed structures whose root rings are projected/bound to the actual pads.
Shape keys sample the SAME deformation for skin, organs, and foot anchors.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
import hashlib
import importlib.util
import json
import math
import random
import sys
from functools import lru_cache
from pathlib import Path
from types import SimpleNamespace

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

LAW_KEYS = ["Basis"] + ["law_half" if i == 8 else "law_full" if i == 16
                         else "law_%02d" % i for i in range(1, 17)]
PHASE_KEYS = ["gait_a", "gait_b"]
REGIONS = {"skin": 1, "internal": 2, "claw": 3, "cilia": 4, "window": 5, "scintillon": 6}
FOOT_ANCHORS = [(side * .72, -.54, .4 - row * .8 / 3)
                for side in (-1, 1) for row in range(4)]
SPECIES_IDS = {"tardigrade": 3, "stentor": 4, "lacrymaria": 5, "vorticella": 6, "euplotes": 7, "spirostomum": 8, "heliozoan": 9, "euglena": 10, "volvox": 11, "noctiluca": 12, "bacillaria": 13, "salpingoeca": 14, "mesodinium": 15}
EXTERNAL_MODELS = {
    "euplotes": ("euplotes_model.py", "euplotes_cirral_walk"),
    "euglena": ("euglena_model.py", "euglena_metaboly"),
    "stentor": ("stentor_model.py", "stentor_contractile_trumpet"),
    "lacrymaria": ("lacrymaria_model.py", "lacrymaria_search"),
    "volvox": ("volvox_model.py", "volvox_daughter_inversion"),
    "heliozoan": ("heliozoan_model.py", "heliozoan_capture"),
    "salpingoeca": ("salpingoeca_model.py", "salpingoeca_rosette"),
    "spirostomum": ("spirostomum_model.py", "spirostomum_contractile_spindle"),
    "noctiluca": ("noctiluca_model.py", "noctiluca_flash"),
    "bacillaria": ("bacillaria_model.py", "bacillaria_raphe_slide"),
    "mesodinium": ("mesodinium_model.py", "mesodinium_archipelago"),
}
MODEL_RUNTIME_FIELDS = {
    "euplotes": {"motion_profile":"euplotes_cirral_walk", "cirrus_controls":[0,0,1,1,2,2,3,3,4,4,5,5,6,7]},
    "heliozoan": {"motion_profile": "heliozoan_capture"},
    "noctiluca": {"motion_profile": "noctiluca_flash"},
    "lacrymaria": {"motion_profile": "lacrymaria_search", "neck_root": [0., .03, .37], "neck_reach": [1.2, 6.4]},
}


@lru_cache(maxsize=None)
def model_for(species):
    """Only explicitly registered adjacent model sources can enter this builder."""
    if species not in SPECIES_IDS: raise ValueError("Unsupported species: " + species)
    if species not in EXTERNAL_MODELS: return None
    filename, _profile = EXTERNAL_MODELS[species]
    path = Path(__file__).resolve().with_name(filename)
    if not path.is_file(): raise ValueError("Missing registered model: " + str(path))
    spec = importlib.util.spec_from_file_location("dream_model_" + species, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if module.SPECIES_ID != SPECIES_IDS[species]: raise ValueError("Model species identity mismatch")
    for hook in ("build_objects", "deform", "rig_specs", "metadata", "vertex_semantics"):
        if not callable(getattr(module, hook, None)): raise ValueError("Model lacks hook: " + hook)
    return module


def model_api():
    return SimpleNamespace(Cage=Cage, make_object=make_object, ellipsoid_cage=ellipsoid_cage,
                           tube_cage=tube_cage, hollow_tube_cage=hollow_tube_cage, bl=bl, gd=gd)


def model_metadata(model, species, objects):
    fields = model.metadata(species, objects)
    required = {"parts", "attachments", "required_regions"}
    if not isinstance(fields, dict) or not required <= fields.keys() or fields.keys() - required - {"runtime_fields"}:
        raise ValueError("Model metadata must declare exact anatomy fields")
    runtime = fields.get("runtime_fields", {})
    if runtime != MODEL_RUNTIME_FIELDS.get(species, {}):
        raise ValueError("Model runtime fields differ from the explicit species contract")
    return {key: fields[key] for key in required}, runtime


def model_shape_keys(obj, model):
    obj.shape_key_add(name="Basis")
    poses = [(name, index / 16, 0.) for index, name in enumerate(LAW_KEYS[1:], 1)]
    poses += [(name, 0., phase) for name, phase in zip(PHASE_KEYS, (-1., 1.))]
    for name, law, phase in poses:
        key = obj.shape_key_add(name=name)
        for vertex, target in zip(obj.data.vertices, key.data):
            point = tuple(model.deform(gd(vertex.co), law, phase, obj.name))
            if len(point) != 3 or not all(math.isfinite(v) for v in point):
                raise ValueError("Model produced invalid pose position: " + obj.name + "/" + name)
            target.co = bl(point)
    if callable(getattr(model, "vertex_bindings", None)):
        bindings = list(model.vertex_bindings(obj))
    else:
        tables = [weights_of(obj, "cilium_%d" % i) for i in range(12)]
        bindings = []
        for vertex in obj.data.vertices:
            values = [row[vertex.index] for row in tables]
            weight = max(values)
            bindings.append((-2 - values.index(weight), weight) if weight > 1e-7 else (-1, 0.))
    if len(bindings) != len(obj.data.vertices): raise ValueError("Model binding vertex count mismatch")
    branch_count = getattr(model, "CILIUM_BRANCH_COUNT", 12)
    if type(branch_count) is not int or not 0 <= branch_count <= 36: raise ValueError("Invalid declared ciliary branch count")
    if any(len(row) != 2 or not all(math.isfinite(v) for v in row) or int(row[0]) != row[0] or not -1 - branch_count <= row[0] <= -1 or not 0 <= row[1] <= 1 for row in bindings):
        raise ValueError("Invalid model vertex binding")
    return bindings


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def gd(p):
    return Vector((p[0], p[2], -p[1]))


def smooth(x):
    x = max(0., min(1., x))
    return x * x * (3. - 2. * x)


class Cage:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.groups = {}

    def vertex(self, point):
        self.vertices.append(tuple(point))
        return len(self.vertices) - 1

    def group(self, name, indices, weight=1.):
        table = self.groups.setdefault(name, {})
        for i in indices:
            table[i] = max(table.get(i, 0.), weight)

    def connect(self, first, second):
        if len(first)!=len(second):
            if len(second)!=2*len(first):
                raise ValueError('ring transition must be exactly 1:2')
            for i in range(len(first)):
                self.faces.append((first[i],first[(i+1)%len(first)],
                    second[(2*i+2)%len(second)],second[(2*i+1)%len(second)],second[2*i]))
            return
        for i in range(len(first)):
            self.faces.append((first[i], first[(i+1) % len(first)],
                               second[(i+1) % len(first)], second[i]))

    def inset(self,index,fraction):
        outer=list(self.faces[index]); self.faces[index]=()
        center=sum((Vector(self.vertices[i]) for i in outer),Vector())/len(outer)
        inner=[self.vertex(center.lerp(Vector(self.vertices[i]),fraction)) for i in outer]
        self.connect(outer,inner)
        self.faces.append(tuple(inner))
        return len(self.faces)-1

    def extrude(self, face_index, centers, radii, group=None, region=None):
        """Replace one face with a closed rooted branch, preserving shared root vertices."""
        root = list(self.faces[face_index])
        self.faces[face_index] = ()
        center = sum((Vector(self.vertices[i]) for i in root), Vector()) / len(root)
        axis = (Vector(centers[-1]) - center).normalized()
        a = Vector(self.vertices[root[0]]) - center
        a = (a - axis * a.dot(axis)).normalized()
        if a.length < .1:
            a = axis.cross(Vector((0, 0, 1))).normalized()
        b = axis.cross(a).normalized()
        # The incoming face can be clockwise in this branch frame (the
        # lathed bell is one such case). Match its cyclic order; blindly
        # choosing a right-handed circle twists the first extrusion band.
        if (Vector(self.vertices[root[1]])-center).dot(b) < 0:
            b = -b
        # Root order may oppose the generated frame. The final bmesh winding
        # repair handles orientation, but retain cyclic correspondence here.
        previous = root
        if group:
            self.group(group + "_root", root)
        made = []
        last_sides = []
        for step, (c, radius) in enumerate(zip(centers, radii)):
            c = Vector(c)
            ring = [self.vertex(c + radius * (a * math.cos(i*math.tau/len(root))
                        + b * math.sin(i*math.tau/len(root)))) for i in range(len(root))]
            first_face = len(self.faces)
            self.connect(previous, ring)
            last_sides = list(range(first_face, len(self.faces)))
            if group:
                self.group(group, ring, (step + 1) / len(centers))
            if region:
                self.group(region, ring)
            made.extend(ring)
            previous = ring
        self.faces.append(tuple(reversed(previous)))
        return made, last_sides


def skin_tardigrade():
    c = Cage()
    rings = []
    n = 12
    # Continuous cuticle: generous segment shoulders and shallow reserve folds.
    zs = [-.49 + i*.94/16 for i in range(17)]
    for z in zs:
        end = .18 + .82 * max(0., 1 - (abs(z)/.535)**3) ** .48
        fold = 1 - .105 * sum(math.exp(-((z-s)/.033)**2) for s in (-.29,-.04,.20))
        head = 1 - .35 * smooth((z-.25)/.20)
        ring = []
        for j in range(n):
            angle = math.tau*j/n
            x = .48 * end * fold * head * math.cos(angle)
            y = .43 * end * fold * math.sin(angle) + .035*smooth((z-.2)/.25)
            ring.append(c.vertex((x,y,z)))
        if rings:
            c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    # Closed oral invagination with a modeled lip and floor, not an open end.
    prev = rings[-1]
    mouth = []
    for z, radius in ((.495,.19),(.525,.155),(.53,.095),(.46,.075)):
        ring = [c.vertex((radius*math.cos(j*math.tau/n),
                         .07+radius*.8*math.sin(j*math.tau/n),z)) for j in range(n)]
        c.connect(prev,ring)
        mouth.extend(ring)
        prev = ring
    c.faces.append(tuple(prev))
    c.group("mouth",mouth)
    c.group("gold_boundary",mouth[:n*2], .8)
    # Eight lobopods are topology extrusions of eight distinct cuticle faces.
    for side_i, side in enumerate((-1,1)):
        for row in range(4):
            leg = side_i*4+row
            j = 7 if side < 0 else 10
            target_z = FOOT_ANCHORS[leg][2]
            i = min(range(16),key=lambda k:abs((zs[k]+zs[k+1])*.5-target_z))
            fi = i*n+j
            root = sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
            foot = Vector(FOOT_ANCHORS[leg]) + Vector((0,.065,0))
            centers = [root.lerp(foot,t) + Vector((side*.025*math.sin(t*math.pi),
                         .045*math.sin(t*math.pi),0)) for t in (.30,.58,.84,1.)]
            made,sides = c.extrude(fi,centers,(.14,.105,.14,.12),"leg_%d"%leg)
            # The terminal two loops are one substantial load-bearing pad,
            # rather than a taper visually mistaken for a single long claw.
            c.group("leg_%d"%leg,made[-8:])
            c.group("leg_root_%d"%leg,list(c.groups["leg_%d_root"%leg]))
    # Six actual soft oral lamellae grow from the lip, inside its envelope.
    # They are tissue, distinct from the two internal chitinous stylets.
    for k in range(6):
        face=c.inset(205+k*2,.48)
        base=sum((Vector(c.vertices[v]) for v in c.faces[face]),Vector())/4
        tip=base+Vector((base.x*.10,(base.y-.07)*.10,.035))
        made,_=c.extrude(face,[tip],[.013],region="mouth")
    return c


def skin_vorticella():
    c = Cage()
    # Base -> sheath -> bell cortex -> rolled oral rim -> invaginated lumen.
    profile = [(-.50,.08),(-.475,.145),(-.435,.028),(-.3975,.015),(-.36,.0105),
               (-.295,.010),(-.23,.0105),(-.165,.011),(-.10,.012),(-.04,.017),(.025,.065),(.075,.19),
               (.14,.31),(.27,.38),(.385,.415),(.435,.42),(.455,.36),
               (.425,.27),(.37,.22),(.305,.15),(.335,.105),(.35,.060),(.32,.022)]
    rings = []
    starts=[]
    for row,(y,radius) in enumerate(profile):
        n=12 if row<=10 else 24
        ring = []
        for j in range(n):
            a=j*math.tau/n
            # Asymmetric bell, broader oral shoulders; no decorative corrugation.
            organic = 1 + .025*math.cos(a*3+.3)*smooth((y-.03)/.25)
            ring.append(c.vertex((radius*math.cos(a)*organic,y,
                                  radius*.83*math.sin(a)*organic)))
        if rings:
            starts.append(len(c.faces))
            c.connect(rings[-1],ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    c.faces.append(tuple(rings[-1]))
    c.group("holdfast",rings[0]+rings[1])
    c.group("stalk",sum(rings[2:11],[]))
    c.group("bell",sum(rings[11:16],[]))
    c.group("oral_rim",sum(rings[15:19],[]))
    c.group("gold_boundary",rings[15]+rings[16],.72)
    # Twelve rooted ciliary bundles around the oral rim. Each is continuous
    # with cortex; a bundled export stands for the existing feeler envelope.
    for k in range(12):
        j=k*2
        fi=c.inset(starts[15]+j,.18)
        base=sum((Vector(c.vertices[v]) for v in c.faces[fi]),Vector())/4
        outward=Vector((base.x,0,base.z)).normalized()
        tip=base+outward*.105+Vector((0,.20,0))
        centers=[base.lerp(tip,t)+Vector((0,.02*math.sin(t*math.pi),0)) for t in (.42,1.)]
        c.extrude(fi,centers,(.009,.0018),group="cilium_%d"%k,region="cilia")
    return c


def make_object(name,cage,col,level,role):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([bl(p) for p in cage.vertices],[],[f for f in cage.faces if f])
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    col.objects.link(obj)
    for name,table in cage.groups.items():
        g=obj.vertex_groups.new(name=name)
        for vi,w in table.items():
            g.add([vi],w,'REPLACE')
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    if level:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        mod=obj.modifiers.new("ContinuousRetopology","SUBSURF")
        mod.levels=level; mod.render_levels=level
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
    for p in obj.data.polygons: p.use_smooth=True
    # Catmull-Clark can overshoot a constant weight by one float32 ULP.
    # Clamp semantic ranges before shape evaluation, source save and export;
    # never let the exporter silently repair different source geometry.
    for v in obj.data.vertices:
        for g in list(v.groups):
            if g.weight < 0. or g.weight > 1.:
                obj.vertex_groups[g.group].add([v.index],max(0.,min(1.,g.weight)),'REPLACE')
    # Realized triangulation makes the exported normal/tangent contract
    # explicit; ngons on intentionally closed organ ends are not left to an
    # importer or exporter-specific triangulator.
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data); bm.free()
    obj["anatomy_role"]=role
    return obj


def ellipsoid_cage(center,radius,seed,detail):
    bm=bmesh.new()
    bmesh.ops.create_icosphere(bm,subdivisions=detail,radius=1.)
    bm.verts.ensure_lookup_table()
    rng=random.Random(seed)
    phase=rng.random()*math.tau
    verts=[]
    for v in bm.verts:
        p=v.co
        wrinkle=1+.055*math.sin(p.x*4+phase)*math.sin(p.z*3+.3)
        verts.append((center[0]+p.x*radius[0]*wrinkle,
                      center[1]+p.y*radius[1]*wrinkle,
                      center[2]+p.z*radius[2]*wrinkle))
    c=Cage(); c.vertices=verts
    c.faces=[tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return c


def tube_cage(points,radii,sides=8):
    c=Cage(); prev=None
    for i,(point,radius) in enumerate(zip(points,radii)):
        p=Vector(point)
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        a=tangent.cross(Vector((0,1,0)))
        if a.length<.1: a=tangent.cross(Vector((1,0,0)))
        a.normalize(); b=tangent.cross(a).normalized()
        ring=[c.vertex(p+radius*(a*math.cos(j*math.tau/sides)+b*math.sin(j*math.tau/sides)))
              for j in range(sides)]
        if prev is not None: c.connect(prev,ring)
        else: c.faces.append(tuple(reversed(ring)))
        prev=ring
    c.faces.append(tuple(prev))
    return c


def hollow_tube_cage(points,radii,sides=8):
    # A real digestive lumen with thick closed walls and rounded end lips.
    c=Cage(); rings=[]
    rows=list(zip(points,radii))+list(zip(reversed(points),[r*.48 for r in reversed(radii)]))
    for point,radius in rows:
        p=Vector(point)
        ring=[c.vertex(p+Vector((radius*math.cos(j*math.tau/sides),radius*math.sin(j*math.tau/sides),0))) for j in range(sides)]
        if rings: c.connect(rings[-1],ring)
        rings.append(ring)
    c.connect(rings[-1],rings[0])
    return c


def claws(skin,col,lod):
    """Closed keratin hooks seated on the actual evaluated foot-pad surface."""
    mesh=skin.data
    mesh.calc_loop_triangles()
    coords=[gd(v.co) for v in mesh.vertices]
    triangles=[tuple(t.vertices) for t in mesh.loop_triangles]
    bvh=BVHTree.FromPolygons(coords,triangles,all_triangles=True)
    result=[]
    for leg,anchor in enumerate(FOOT_ANCHORS):
        side=-1 if leg<4 else 1
        weight_table=weights_of(skin,"leg_%d"%leg)
        for claw in range(2):
            wanted=Vector(anchor)+Vector((side*.06,.04,(-1 if claw else 1)*.045))
            root,normal,_,_=bvh.find_nearest(wanted)
            outward=Vector((side,.12,(-1 if claw else 1)*.25)).normalized()
            steps=7 if lod==0 else 5
            pts=[]; radii=[]
            for i in range(steps):
                t=i/(steps-1)
                pts.append(root+outward*(.085*t)+Vector((0,-.055*math.sin(t*math.pi*.85),0)))
                radii.append(.018*(1-t)**.7+.0015)
            sides=8 if lod==0 else 5
            cage=tube_cage(pts,radii,sides)
            for i in range(sides):
                at,_,tri,_=bvh.find_nearest(Vector(cage.vertices[i]))
                cage.vertices[i]=tuple(at)
                ids=triangles[tri]
                bary=barycentric_transform(at,*[coords[v] for v in ids],Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
                w=sum(bary[k]*weight_table[v] for k,v in enumerate(ids))
                cage.group("leg_%d"%leg,[i],max(0.,min(1.,w)))
            cage.group("leg_%d"%leg,range(sides,len(cage.vertices)))
            cage.group("claw_root",range(sides))
            cage.group("claw",range(len(cage.vertices)))
            obj=make_object("Claw_%d_%d"%(leg,claw),cage,col,0,"external_organ")
            result.append(obj)
    return result


def organs(species,col,lod,seed,skin):
    result=[]
    detail=2 if lod==0 else 1
    def blob(name,center,radius,offset):
        ob=make_object(name,ellipsoid_cage(center,radius,seed+offset,detail),col,0,"internal_organ")
        result.append(ob)
    def tube(name,points,radii):
        ob=make_object(name,tube_cage(points,radii,10 if lod==0 else 6),col,0,"internal_organ")
        result.append(ob)
    if species=="tardigrade":
        blob("Pharynx",(.015,.025,.305),(.10,.105,.095),1)
        steps=24 if lod==0 else 12
        pts=[(.020*math.sin(i/(steps-1)*math.tau*.7),.025+.008*math.sin(i/(steps-1)*math.tau*1.2),-.34+i*.54/(steps-1)) for i in range(steps)]
        gut=make_object("Gut",hollow_tube_cage(pts,[.080+.012*math.sin(i/(steps-1)*math.tau*.8)**2 for i in range(steps)],10 if lod==0 else 6),col,0,"internal_organ")
        result.append(gut)
        for side in (-1,1):
            pts=[(side*(.024+.028*math.sin(t*math.pi)),.075,.29+.13*t) for t in (0,.25,.5,.75,1)]
            tube("Stylet_L" if side<0 else "Stylet_R",pts,[.008,.009,.008,.005,.002])
        rng=random.Random(seed+719)
        for i in range(14):
            side=-1 if i%2 else 1
            z=-.33+(i//2)*.084+rng.uniform(-.008,.008)
            blob("StorageCell_%02d"%i,(side*rng.uniform(.185,.225),rng.uniform(-.01,.095),z),
                 (rng.uniform(.038,.052),rng.uniform(.04,.068),rng.uniform(.026,.033)),20+i)
    else:
        blob("Macronucleus",(.25,.27,-.025),(.045,.055,.050),1)
        for i in range(4):
            a=(i+.35)*math.tau/4
            blob("Vacuole_%02d"%i,(.255*math.cos(a),.29,.215*math.sin(a)),(.047,.054,.045),10+i)
        points=[(.0008,y,.0004) for y,_points in actual_sheath_rings(skin) if -.42<=y<=.057]
        tube("Spasmoneme",points,[.0012]*len(points))
    return result


def weights_of(obj,name):
    group=obj.vertex_groups.get(name)
    if group is None: return [0.]*len(obj.data.vertices)
    return [next((g.weight for g in v.groups if g.group==group.index),0.) for v in obj.data.vertices]


@lru_cache(maxsize=32)
def coil_radius(t):
    length=.335
    height=length*(1-.62*t)
    def arc(radius):
        points=[coil_center(i/128,height,radius) for i in range(129)]
        return sum((b-a).length for a,b in zip(points,points[1:]))
    lo=0.; hi=.2
    for _ in range(28):
        mid=(lo+hi)*.5
        if arc(mid)>length: hi=mid
        else: lo=mid
    return (lo+hi)*.5


def coil_center(s,height,radius):
    a=1.35*math.tau*s
    envelope=math.sin(math.pi*s)**2
    return Vector((radius*envelope*math.cos(a),-.395+height*s,
                   radius*envelope*math.sin(a)))


def coil(point,t):
    """Fixed holdfast; sampled constant arc; bell shares endpoint position/frame."""
    p=Vector(point)
    bottom=-.395; top=-.06; length=top-bottom
    u=max(0.,min(1.,(p.y-bottom)/length))
    turns=1.35
    angle=turns*math.tau
    # Helix pitch shrinks while radial excursion supplies the lost arc length.
    vertical=length*(1-.62*t)
    radius=coil_radius(t)
    def center(s):
        return coil_center(s,vertical,radius)
    if p.y<bottom:
        return p
    # Rotating the local sheath cross-section by the centerline frame keeps
    # its own thickness; upper bell and every organ use the same final frame.
    s=u
    envelope=math.sin(math.pi*s)**2
    deriv=math.pi*math.sin(math.tau*s)
    tangent=Vector((radius*(deriv*math.cos(angle*s)-envelope*angle*math.sin(angle*s)),vertical,
                    radius*(deriv*math.sin(angle*s)+envelope*angle*math.cos(angle*s)))).normalized()
    side=Vector((1,0,0))
    side=(side-tangent*side.dot(tangent)).normalized()
    forward=side.cross(tangent).normalized()
    local_y=max(0.,p.y-top)
    return center(s)+side*p.x+tangent*local_y+forward*p.z


def deform(species,point,law,leg=-1,weight=0.,phase=0.):
    p=Vector(point)
    if species=="tardigrade":
        # Coordinated shortening and widening carries every enclosed organ.
        q=Vector((p.x*(1+.15*law),p.y*(1+.13*law),p.z*(1-.30*law)))
        if leg>=0:
            side=-1 if leg<4 else 1
            q.x-=side*.14*law*weight
            q.y+=.11*law*weight
        # Breathing stays on dorsal tissue; all soles retain contact pose.
        q.y+=phase*.008*max(0.,p.y+.12)*(1-weight)
        return q
    q=coil(p,law)
    # Restrained oral pulse; held stalk/base remains still.
    q.x+=phase*.007*smooth((p.y-.1)/.35)
    if leg<=-2:
        angle=(-2-leg)*math.tau/12
        q+=Vector((math.cos(angle),0,math.sin(angle)))*(phase*.015*weight*weight)
    return q


def actual_sheath_rings(skin):
    grouped={}
    for vertex in skin.data.vertices:
        point=gd(vertex.co)
        if -.46<=point.y<=.08:
            grouped.setdefault(round(point.y,6),[]).append(point)
    rows=sorted((sum(p.y for p in points)/len(points),points)
                for points in grouped.values() if len(points)>=12)
    # Float32 subdivision can split one axial ring into 36+12 vertices at
    # y values separated by ~3e-8. They are one section, not two tube knots.
    # Merge numerical aliases only; the smallest real stalk step is >.009.
    merged=[]
    for height,points in rows:
        if merged and height-merged[-1][0]<5e-6:
            combined=merged[-1][1]+points
            merged[-1]=(sum(p.y for p in combined)/len(combined),combined)
        else: merged.append((height,points))
    return merged


def contained_stalk_deformer(skin):
    """Keep the contractile strand inside the realized LOD sheath chords.

    The low-LOD sheath samples a curved analytic stalk more sparsely than the
    internal tube. A separately sampled analytical core can therefore cut
    across its wall. Bind the core to centroids of actual neutral cross-section
    rings and interpolate those same posed ring chords at every law sample.
    This is a model binding, not a containment waiver or radius-only workaround.
    """
    rings=actual_sheath_rings(skin)
    heights=[row[0] for row in rings]
    if len(rings)<8: raise RuntimeError('insufficient actual sheath cross sections')
    posed={}
    def transform(point,law,phase):
        p=Vector(point)
        if not heights[0]<=p.y<=heights[-1]:
            raise RuntimeError('contractile strand extends beyond bound sheath rings')
        key=(law,phase)
        if key not in posed:
            posed[key]=[sum((deform('vorticella',v,law,phase=phase) for v in row[1]),Vector())/len(row[1]) for row in rings]
        upper=min(len(rings)-1,max(1,bisect_right(heights,p.y)))
        lower=upper-1
        fraction=(p.y-heights[lower])/(heights[upper]-heights[lower])
        centers=posed[key]
        # The tube includes EVERY sheath knot; no internal triangle may skip
        # a corner of the enclosing low-LOD polygonal centerline. At a knot its
        # radial plane shares the actual sheath's analytical frame.
        radial=coil(p,law)-coil(Vector((0.,p.y,0.)),law)
        return centers[lower].lerp(centers[upper],fraction)+radial
    return transform


def add_shape_keys(obj,species,skin):
    obj.shape_key_add(name="Basis")
    core_transform=contained_stalk_deformer(skin) if obj.name=="Spasmoneme" else None
    leg_tables=[weights_of(obj,"leg_%d"%i) for i in range(8)]
    cilium_tables=[weights_of(obj,"cilium_%d"%i) for i in range(12)] if species=="vorticella" else []
    leg_data=[]
    for v in obj.data.vertices:
        vals=[table[v.index] for table in leg_tables]
        w=max(vals)
        leg_data.append((vals.index(w) if w>1e-7 else -1,w))
        if cilium_tables:
            vals=[table[v.index] for table in cilium_tables]; w=max(vals)
            leg_data[-1]=(-2-vals.index(w),w) if w>1e-7 else (-1,0.)
    for index,name in enumerate(LAW_KEYS[1:],1):
        key=obj.shape_key_add(name=name)
        for v,k in zip(obj.data.vertices,key.data):
            leg,w=leg_data[v.index]
            k.co=bl(core_transform(gd(v.co),index/16,0.) if core_transform else deform(species,gd(v.co),index/16,leg,w))
    for name,phase in zip(PHASE_KEYS,(-1,1)):
        key=obj.shape_key_add(name=name)
        for v,k in zip(obj.data.vertices,key.data):
            leg,w=leg_data[v.index]
            k.co=bl(core_transform(gd(v.co),0.,phase) if core_transform else deform(species,gd(v.co),0,leg,w,phase))
    return leg_data


def attributes(obj,species,leg_data,model=None):
    mesh=obj.data
    uv=mesh.uv_layers.new(name="UVMap")
    binding=mesh.uv_layers.new(name="AnatomyBinding")
    colors=mesh.color_attributes.new(name="Anatomy",type="FLOAT_COLOR",domain="POINT")
    gold=weights_of(obj,"gold_boundary")
    claw=weights_of(obj,"claw")
    cilia=weights_of(obj,"cilia")
    internal=obj["anatomy_role"]=="internal_organ"
    semantic = model.vertex_semantics(obj) if model else None
    if semantic is not None and len(semantic) != len(mesh.vertices):
        raise ValueError("Model semantic vertex count mismatch: " + obj.name)
    for v in mesh.vertices:
        if semantic is not None:
            row = semantic[v.index]
            if len(row) != 3 or not all(type(value) in (int, float) and math.isfinite(value) for value in row):
                raise ValueError("Invalid model vertex semantics: " + obj.name)
            r, window, region = row
            if not 0. <= r <= 1. or not 0. <= window <= 1. or region not in REGIONS.values():
                raise ValueError("Out-of-range model vertex semantics: " + obj.name)
            colors.data[v.index].color=(r,window,region/255.,1.)
            continue
        p=gd(v.co); leg,w=leg_data[v.index]
        window=0.
        if not internal:
            # Two broad, bounded thin cortex windows, never alternating bands.
            if species=="tardigrade":
                window=math.exp(-((p.z+.035)/.34)**6-((abs(p.x)-.30)/.18)**4)*smooth((p.y+.05)/.24)
            else:
                window=math.exp(-((p.y-.245)/.16)**4)*smooth((abs(p.x)-.08)/.17)
        region=REGIONS["internal"] if internal else REGIONS["skin"]
        if claw[v.index]>.15: region=REGIONS["claw"]
        elif cilia[v.index]>.15: region=REGIONS["cilia"]
        elif window>.35: region=REGIONS["window"]
        r=max(gold[v.index],claw[v.index]*.92)
        if obj.name.startswith("Stylet") or obj.name=="Spasmoneme": r=.8
        colors.data[v.index].color=(r,window,region/255.,1.)
    mesh.color_attributes.active_color=colors
    for loop in mesh.loops:
        p=gd(mesh.vertices[loop.vertex_index].co)
        uv.data[loop.index].uv=((math.atan2(p.y,p.x)/math.tau+.5),p.z+.55)
        leg,w=leg_data[loop.vertex_index]
        # glTF exporter flips V. Imported TEXCOORD_1.y is therefore weight.
        binding.data[loop.index].uv=(float(leg),1.-w)
    # A global cylindrical projection degenerates on cap/limb triangles.
    # Unwrap substance UVs independently from semantic UV1. This is real
    # Blender UV authoring, preserved in the editable source and GLB.
    mesh.uv_layers.active_index=0
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(70),island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)


def material():
    m=bpy.data.materials.new("DreamAnatomicalTissue")
    if m.node_tree is None: m.use_nodes=True
    nodes=m.node_tree.nodes; links=m.node_tree.links
    p=nodes.get("Principled BSDF")
    attr=nodes.new("ShaderNodeVertexColor"); attr.layer_name="Anatomy"
    split=nodes.new("ShaderNodeSeparateColor"); links.new(attr.outputs["Color"],split.inputs["Color"])
    mix=nodes.new("ShaderNodeMixRGB"); mix.blend_type='MIX'
    mix.inputs[1].default_value=(.042,.006,.024,1)
    mix.inputs[2].default_value=(.58,.29,.052,1)
    links.new(split.outputs[0],mix.inputs[0]); links.new(mix.outputs[0],p.inputs["Base Color"])
    links.new(split.outputs[0],p.inputs["Metallic"])
    noise=nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value=22
    noise.inputs["Detail"].default_value=3.5
    rough=nodes.new("ShaderNodeMapRange")
    rough.inputs["From Min"].default_value=0; rough.inputs["From Max"].default_value=1
    rough.inputs["To Min"].default_value=.29; rough.inputs["To Max"].default_value=.53
    links.new(noise.outputs["Fac"],rough.inputs["Value"]); links.new(rough.outputs["Result"],p.inputs["Roughness"])
    p.inputs["Coat Weight"].default_value=.22
    p.inputs["Subsurface Weight"].default_value=.08
    p.inputs["Transmission Weight"].default_value=.12
    return m


def rig_objects(objects,col,species,model=None):
    data=bpy.data.armatures.new("CritterRig")
    rig=bpy.data.objects.new("CritterRig",data); col.objects.link(rig)
    bpy.context.view_layer.objects.active=rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    root=data.edit_bones.new("DEF_root"); root.head=bl((0,-.5,0)); root.tail=bl((0,-.35,0))
    specs=[]
    if model:
        specs = list(model.rig_specs())
        names = [row[0] for row in specs]
        if not specs or len(names) != len(set(names)) or "DEF_root" in names:
            raise ValueError("Invalid/duplicate model deform-bone names")
        for name, a, b in specs:
            if not name.startswith("DEF_") or len(a) != 3 or len(b) != 3 or not all(math.isfinite(v) for v in (*a,*b)) or (Vector(b)-Vector(a)).length < 1e-6:
                raise ValueError("Invalid model deform bone: " + name)
    elif species=="tardigrade":
        for i in range(5):
            a=(0,0,-.48+i*.20); b=(0,0,-.28+i*.20)
            specs.append(("DEF_body_%02d"%i,a,b))
        for leg,foot in enumerate(FOOT_ANCHORS):
            a=(foot[0]*.48,-.20,foot[2]); mid=Vector(a).lerp(Vector(foot),.52)
            specs.extend([("DEF_leg_%d_prox"%leg,a,mid),("DEF_leg_%d_dist"%leg,mid,foot)])
    else:
        for i in range(8):
            specs.append(("DEF_stalk_%02d"%i,(0,-.435+i*.46/8,0),(0,-.435+(i+1)*.46/8,0)))
        specs.append(("DEF_bell",(0,.025,0),(0,.43,0)))
    for name,a,b in specs:
        bone=data.edit_bones.new(name); bone.head=bl(a); bone.tail=bl(b); bone.parent=root
    bpy.ops.object.mode_set(mode='OBJECT'); rig.select_set(False)
    for obj in objects:
        # Kept separate from semantic groups; only named deform bones export.
        groups={name:obj.vertex_groups.new(name=name) for name,_,_ in specs}
        for v in obj.data.vertices:
            p=gd(v.co)
            candidates=specs
            if species=="tardigrade":
                legweights=[next((g.weight for g in v.groups if g.group==obj.vertex_groups["leg_%d"%i].index),0.)
                            if obj.vertex_groups.get("leg_%d"%i) else 0. for i in range(8)]
                leg=max(range(8),key=lambda i:legweights[i])
                if legweights[leg]>.2: candidates=[s for s in specs if s[0].startswith("DEF_leg_%d_"%leg)]
                else: candidates=specs[:5]
            elif species=="vorticella" and p.y>.025:
                candidates=[specs[-1]]
            values=[]
            for name,a,b in candidates:
                a=Vector(a); b=Vector(b); d=b-a
                nearest=a+d*max(0.,min(1.,(p-a).dot(d)/d.length_squared))
                values.append((1./max(.012,(p-nearest).length)**3,name))
            values=sorted(values,reverse=True)[:2]
            total=sum(w for w,_ in values)
            for w,name in values: groups[name].add([v.index],w/total,'REPLACE')
        mod=obj.modifiers.new("AnatomicalRig","ARMATURE"); mod.object=rig
        obj.parent=rig
    return rig


def anatomy_contract(species,seed,col,objects,model=None):
    body=objects[0]
    poses=[{"name":"neutral","shape_keys":{},"bones":{}}]
    for key in LAW_KEYS[1:]+PHASE_KEYS:
        poses.append({"name":key,"shape_keys":{o.name:{key:1.} for o in objects},"bones":{}})
    groups=["leg_root_%d"%i for i in range(8)]+["mouth"] if species=="tardigrade" else ["holdfast","stalk","bell","oral_rim"]
    contract = {"schema":"dream_critter_anatomy.v1","species_id":SPECIES_IDS[species],
            "species_name":species,"seed":seed,"units":"m","collection":col.name,
            "body":body.name,"rig":"CritterRig","poses":poses,
            "parts":[{"object":o.name,"role":o["anatomy_role"],"topology":"closed",
                      "container":body.name if o["anatomy_role"]=="internal_organ" else None} for o in objects],
            "attachments":[{"object":o.name,"vertex_group":"claw_root","target":"Skin","max_gap_fraction":.003,"max_drift_fraction":.001} for o in objects if o.name.startswith("Claw_")],
            "required_regions":[{"object":"Skin","vertex_group":g,"min_vertices":3} for g in groups]}
    if model:
        fields, _runtime = model_metadata(model, species, objects)
        contract.update(fields)
        contract["provenance"] = {"motion_profile": EXTERNAL_MODELS[species][1],
            "model_sha256": hashlib.sha256(Path(model.__file__).read_bytes()).hexdigest()}
    return contract


def build(species,seed,out,lod):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.
    col=bpy.data.collections.new("CRITTER_"+species); scene.collection.children.link(col)
    model = model_for(species)
    if model:
        objects = list(model.build_objects(model_api(), col, lod, seed))
        if not objects or objects[0].name != "Skin" or objects[0].get("anatomy_role") != "continuous_skin":
            raise ValueError("Model must return its continuous Skin first")
        if any(obj.type != "MESH" for obj in objects) or len({obj.name for obj in objects}) != len(objects):
            raise ValueError("Model must return unique mesh objects")
        skin = objects[0]
    else:
        cage=skin_tardigrade() if species=="tardigrade" else skin_vorticella()
        skin=make_object("Skin",cage,col,2 if lod==0 else 1,"continuous_skin")
        objects=[skin]+organs(species,col,lod,seed,skin)
        if species=="tardigrade": objects+=claws(skin,col,lod)
    mat=material()
    for obj in objects:
        obj["species_id"]=SPECIES_IDS[species]
        obj["species_name"]=species
        legs=model_shape_keys(obj,model) if model else add_shape_keys(obj,species,skin)
        attributes(obj,species,legs,model)
        obj.data.materials.append(mat)
    rig=rig_objects(objects,col,species,model)
    contract=anatomy_contract(species,seed,col,objects,model)
    scene["dream_critter_contract"]=json.dumps(contract,sort_keys=True)
    suffix="" if lod==0 else "_lod1"
    blend=out/"art/blender/dream_critters"/(species+suffix+".blend")
    assets=out/"game/assets/dream/critters_blender"/species
    blend.parent.mkdir(parents=True,exist_ok=True); assets.mkdir(parents=True,exist_ok=True)
    mesh_file=species+("_lod0" if lod==0 else "")+".glb"
    glb=assets/mesh_file
    tris=0
    for obj in objects:
        obj.data.calc_loop_triangles(); tris+=len(obj.data.loop_triangles)
    limit=20000 if lod==0 else 5000
    if tris>limit: raise RuntimeError(f"LOD{lod} triangles {tris} exceed {limit}")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    for obj in objects+[rig]: obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=False,export_normals=True,export_tangents=True,
        export_texcoords=True,export_attributes=False,export_materials='EXPORT',
        export_vertex_color='NAME',export_vertex_color_name='Anatomy',
        export_skins=True,export_all_influences=False,export_morph=True,
        export_morph_normal=True,export_morph_tangent=True,export_animations=False)
    manifest={"schema_version":1,"species_id":SPECIES_IDS[species],
              "mesh_file":mesh_file,"law_keys":LAW_KEYS,"phase_keys":PHASE_KEYS,
              "closed_body":"Skin","foot_anchors":[],"cilium_anchors":[]}
    if species=="tardigrade":
        manifest["foot_anchors"]=[[list(deform(species,p,t/16,i,1.)) for i,p in enumerate(FOOT_ANCHORS)] for t in range(17)]
        manifest["foot_anchors"].extend([[list(deform(species,p,0,i,1.,phase)) for i,p in enumerate(FOOT_ANCHORS)] for phase in (-1.,1.)])
    if species=="vorticella":
        # Root binding and local phase masks are per vertex. Deforming only a
        # neutral centroid is not equivalent to the evaluated attached root.
        root_weights=[weights_of(skin,"cilium_%d_root"%k) for k in range(12)]
        manifest["cilium_anchors"]=[]
        for name in LAW_KEYS+PHASE_KEYS:
            vertices=skin.data.shape_keys.key_blocks[name].data
            manifest["cilium_anchors"].append([
                list(sum((gd(v.co)*weight for v,weight in zip(vertices,weights)),Vector())/sum(weights))
                for weights in root_weights])
    if model:
        manifest["motion_profile"] = EXTERNAL_MODELS[species][1]
        _fields, runtime = model_metadata(model, species, objects)
        manifest.update(runtime)
        if getattr(model, "CILIUM_BRANCH_COUNT", 0) > 0:
            root_tables = [weights_of(skin, "cilium_%d_root" % index) for index in range(model.CILIUM_BRANCH_COUNT)]
            if any(sum(table) <= 0 for table in root_tables): raise ValueError("Model lacks declared ciliary branch roots")
            manifest["cilium_anchors"] = [[list(sum((gd(v.co) * weight for v, weight in zip(key.data, table)), Vector()) / sum(table))
                for table in root_tables] for key in skin.data.shape_keys.key_blocks]
    manifest_path=glb.with_suffix('.manifest.json')
    manifest_path.write_text(json.dumps(manifest,indent=2)+"\n",encoding='utf-8',newline='\n')
    audit={"species":species,"lod":lod,"triangles":tris,"mesh_objects":len(objects),
           "builder_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
           "blender_version":bpy.app.version_string,"blender_build":bpy.app.build_hash.decode(),
           "blend_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
           "glb_sha256":hashlib.sha256(glb.read_bytes()).hexdigest(),
           "manifest_sha256":hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
           "region_ids":REGIONS,"coordinate_frame":"Godot: side/up/forward; Blender: x/-z/y"}
    if model:
        audit["model_source"] = str(Path(model.__file__).resolve())
        audit["model_sha256"] = hashlib.sha256(Path(model.__file__).read_bytes()).hexdigest()
        audit["motion_profile"] = EXTERNAL_MODELS[species][1]
    (assets/(glb.stem+'.build.json')).write_text(json.dumps(audit,indent=2)+"\n",encoding='utf-8',newline='\n')
    print('[critter-build] '+json.dumps(audit,sort_keys=True),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    parser.add_argument('--species',required=True,choices=sorted(SPECIES_IDS))
    parser.add_argument('--output-root',required=True,type=Path)
    parser.add_argument('--seed',required=True,type=int)
    parser.add_argument('--lod',choices=['both','0','1'],default='both')
    argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    args=parser.parse_args(argv)
    if not args.output_root.is_absolute(): parser.error('output-root must be absolute')
    out=args.output_root.resolve()
    for lod in ([1,0] if args.lod=='both' else [int(args.lod)]):
        build(args.species,args.seed,out,lod)


if __name__=='__main__': main()
