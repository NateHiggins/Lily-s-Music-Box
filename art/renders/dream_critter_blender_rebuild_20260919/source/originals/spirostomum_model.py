"""Source-only Spirostomum module for the shared Blender builder adapter.

One continuous cortex, rooted longitudinal cilia, contained moniliform nucleus,
vacuoles and a continuous peripheral reticular tube share the same invertible
contraction map.  All motion is sampled from the existing law.z/phase packet.
No ecology clock, stimulus receptor or runtime owner is introduced here.
"""
import math

SPECIES_ID = 8
MOTION_PROFILE = "spirostomum_contractile_spindle"
CILIUM_BRANCH_COUNT = 36
LAW_KEYS = ("Basis", "law_01", "law_02", "law_03", "law_04", "law_05",
            "law_06", "law_07", "law_half", "law_09", "law_10", "law_11",
            "law_12", "law_13", "law_14", "law_15", "law_full")
PHASE_KEYS = ("gait_a", "gait_b")
_API = None
_BINDINGS = {}


def _smooth(x):
    x = max(0., min(1., x))
    return x*x*(3.-2.*x)


def _normalize(p):
    length = math.sqrt(sum(x*x for x in p))
    return tuple(x/length for x in p)


def _weights(obj, name):
    group = obj.vertex_groups.get(name)
    if group is None:
        return [0.] * len(obj.data.vertices)
    return [next((entry.weight for entry in vertex.groups if entry.group == group.index), 0.)
            for vertex in obj.data.vertices]


def _skin(api, lod):
    cage = api.Cage()
    around, bands = (48, 28) if lod == 0 else (24, 14)
    rings = []
    for band in range(1, bands):
        theta = math.pi * band / bands
        z = -.5 * math.cos(theta)
        radius = .405 * math.sin(theta)
        ring = []
        for column in range(around):
            phi = math.tau * column / around
            first = abs(math.sin(phi * 6. + z * 17.))
            second = abs(math.sin(phi * 6. - z * 17.))
            fishnet = math.exp(-min(first, second)**2 / .022)
            # The cortical network is a shallow continuous relief, not paint
            # or intersecting independent rods through the membrane.
            r = radius + .007 * fishnet * math.sin(theta)**2
            angular = abs(math.atan2(math.sin(phi-math.pi*.5), math.cos(phi-math.pi*.5)))
            oral = math.exp(-(angular/.22)**4) * _smooth((z-.13)/.15) * (1.-_smooth((z-.42)/.06))
            r -= .032 * oral
            point = (r*math.cos(phi), r*math.sin(phi), z)
            index = cage.vertex(point)
            cage.group("cortex", [index])
            cage.group("myoneme_fishnet", [index], fishnet)
            cage.group("oral_channel", [index], oral)
            ring.append(index)
        rings.append(ring)
    posterior = cage.vertex((0., 0., -.5))
    for column in range(around):
        cage.faces.append((posterior, rings[0][(column+1)%around], rings[0][column]))
    for first, second in zip(rings, rings[1:]):
        cage.connect(first, second)
    anterior = cage.vertex((0., 0., .5))
    for column in range(around):
        cage.faces.append((rings[-1][column], rings[-1][(column+1)%around], anterior))
    # Each row owns three short rooted shafts.  Distinct root anchors permit
    # the existing10..12 row count to retract a whole row without pulling its
    # distant shafts into one arbitrary centroid.
    step = around // 12
    for row in range(12):
        for along, fraction in enumerate((.27, .50, .73)):
            band = max(0, min(len(rings)-2, round((len(rings)-2)*fraction)))
            column = row * step
            face_index = around + band * around + column
            original = cage.faces[face_index]
            center = tuple(sum(cage.vertices[index][axis] for index in original)/4.
                           for axis in range(3))
            normal = _normalize((center[0], center[1], center[2]*.35))
            patch = []
            for index in original:
                point = tuple(center[axis] + (cage.vertices[index][axis]-center[axis])*.12
                              for axis in range(3))
                patch.append(cage.vertex(point))
            cage.faces[face_index] = ()
            for corner in range(4):
                following = (corner+1)%4
                cage.faces.append((original[corner], original[following], patch[following], patch[corner]))
            root_face = len(cage.faces)
            cage.faces.append(tuple(patch))
            branch = row*3+along
            centers = [tuple(center[axis]+normal[axis]*distance
                             + (distance*.20 if axis==2 else 0.) for axis in range(3))
                       for distance in (.005, .025, .048)]
            made, _ = cage.extrude(root_face, centers, [.0042,.0025,.00065],
                                  group="cilium_%d"%branch, region="cilia")
            cage.group("ciliary_rows", made+patch)
    return cage


def build_objects(api, col, lod, seed):
    global _API
    _API = api
    skin = api.make_object("Skin", _skin(api,lod), col, 0, "continuous_skin")
    objects = [skin]
    # A single beaded nucleus connected by real narrow bridges.
    points, radii = [], []
    for index in range(25):
        z = -.27 + index*.54/24.
        points.append((.025*math.sin(index*.45), -.025, z))
        radii.append(.029 + .029*math.sin(math.pi*index/4.)**2)
    nucleus = api.make_object("MoniliformNucleus", api.tube_cage(points,radii,12 if lod==0 else 8),
                              col, 0, "internal_organ")
    objects.append(nucleus)
    for name, center, radius in (
            ("ContractileVacuole", (.015,.010,-.385), (.058,.065,.047)),
            ("FoodVacuole_A", (-.16,.12,-.115), (.067,.065,.068)),
            ("FoodVacuole_B", (.16,-.12,.135), (.064,.070,.060))):
        objects.append(api.make_object(name,api.ellipsoid_cage(center,radius,seed+len(objects),
                                                              3 if lod==0 else 2),col,0,"internal_organ"))
    points=[]
    count=73 if lod==0 else 37
    for index in range(count):
        t=index/(count-1)
        angle=math.tau*3.*t+.32
        points.append((.295*math.cos(angle),.295*math.sin(angle),-.24+.48*t))
    objects.append(api.make_object("PeripheralReticulum",api.tube_cage(points,[.0085]*count,
                                                                       8 if lod==0 else 6),
                                   col,0,"internal_organ"))
    _BINDINGS.clear()
    for obj in objects:
        bindings = vertex_bindings(obj)
        _BINDINGS[obj.name] = {tuple(round(float(x),8) for x in api.gd(v.co)): bindings[v.index]
                               for v in obj.data.vertices}
    return objects


def vertex_bindings(obj):
    result=[(-1,0.) for _ in obj.data.vertices]
    if obj.name != "Skin":
        return result
    for branch in range(CILIUM_BRANCH_COUNT):
        weights=_weights(obj,"cilium_%d"%branch)
        for index,weight in enumerate(weights):
            if weight>1e-7:
                result[index]=(-2-branch,weight)
    return result


def deform(point, law, phase, object_name):
    x,y,z = (float(component) for component in point)
    law=max(0.,min(1.,float(law)))
    phase=max(-1.,min(1.,float(phase)))
    binding=_BINDINGS.get(object_name,{}).get(tuple(round(float(c),8) for c in point),(-1,0.))
    if binding[0] < -1:
        amount=.065*phase*binding[1]
        x,y=x-y*amount,y+x*amount
    # Monotonic axial map (derivative stayspositive even at full contraction)
    # plus an invertible rotation/scale on eachcross-section. Every contained
    # structure shares it; internals cannot remain extended through a shortbody.
    axial=(1.-.69*law)*z+.12*law*(1.-law)*(z*z-.25)
    angle=law*(2.2+.30*z)
    radial=(1.+.48*law)*(1.+.035*law*(1.-law)*math.sin(math.tau*z))
    radial*=1.+.003*phase
    cp,sp=math.cos(angle),math.sin(angle)
    return ((x*cp-y*sp)*radial+.025*law*math.sin(math.tau*z),
            (x*sp+y*cp)*radial, axial)


def vertex_semantics(obj):
    if obj.name != "Skin":
        return [(.12 if obj.name=="PeripheralReticulum" else .015,0.,2)
                for _ in obj.data.vertices]
    net=_weights(obj,"myoneme_fishnet")
    cilia=_weights(obj,"cilia")
    oral=_weights(obj,"oral_channel")
    result=[]
    for vertex in obj.data.vertices:
        x,y,z=_API.gd(vertex.co)
        window=math.exp(-((z+.025)/.31)**6)*_smooth((abs(x)-.14)/.20)*(1.-cilia[vertex.index])
        result.append((min(1.,.08+.52*net[vertex.index]+.28*oral[vertex.index]),
                       window,4 if cilia[vertex.index]>.1 else 1))
    return result


def rig_specs():
    return [("DEF_axis_%02d"%i,(0.,0.,-.45+i*.15),(0.,0.,-.30+i*.15)) for i in range(6)]


def metadata(species,objects):
    if species!="spirostomum":
        raise ValueError("Wrong species for Spirostomum module")
    return {"parts":[{"object":obj.name,"role":obj["anatomy_role"],"topology":"closed",
                       "container":None if obj.name=="Skin" else "Skin"} for obj in objects],
            "attachments":[],
            "required_regions":[{"object":"Skin","vertex_group":name,"min_vertices":3}
                                for name in ("cortex","myoneme_fishnet","oral_channel","ciliary_rows")
                                +tuple("cilium_%d_root"%i for i in range(CILIUM_BRANCH_COUNT))]}
