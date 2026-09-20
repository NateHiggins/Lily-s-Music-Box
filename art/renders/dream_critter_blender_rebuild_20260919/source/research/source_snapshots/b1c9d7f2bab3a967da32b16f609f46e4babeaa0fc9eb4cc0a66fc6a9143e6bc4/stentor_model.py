"""External Stentor authoring draft; no import-time scene changes or exports.

Builder hooks match the external Volvox module.  The builder owns shape keys,
rig weights, attribute encoding, source/export hashes and output paths.

Anatomical guidance: Huang/Pitelka 1973, doi:10.1083/jcb.57.3.704, describes
longitudinal cortical km fibers and myonemes. Rajan et al. 2023,
doi:10.1016/j.cub.2022.11.010, measures single-cell habituation. The existing
game's timed, progressively smaller contraction is an authored abstraction,
not that paper's stochastic change in response probability. This module does
not change the controller, sense mechanical stimuli, or implement learning.

Dossier D20 is a cilia-packing analogy, D44 adjacent Vorticella feeding-current
motion, D69/D85 artistic glass/enamel structure. None establishes Stentor's
exact geometry or colors. No reference image bytes, tracing or texture reuse.

All dimensions, organ counts and bundled cilia are proposed presentation
geometry. Shared monotone contraction moves cortex and contained organs;
the source must pass actual evaluated topology/containment gates before use.
"""
import math

SPECIES_ID = 4
CILIUM_BRANCH_COUNT = 12
REFERENCE_URLS = (
    "https://pmc.ncbi.nlm.nih.gov/articles/PMC2108994/",
    "https://pmc.ncbi.nlm.nih.gov/articles/PMC9877177/",
)
DOSSIER_REFERENCE_IDS = (20, 44, 69, 85)
_PHASE_WEIGHTS = {}
_SEMANTICS = {}

# Godot side/up/forward, normalized before the controller's morph dimensions.
# The profile goes up the outer cortex, over a rolled oral edge, then down
# a visible vestibule. Only its deep floor is capped; the mouth stays open.
PROFILE = (
    (-.50, .045), (-.485, .072), (-.460, .058), (-.420, .075),
    (-.350, .100), (-.250, .135), (-.150, .180), (-.020, .230),
    (.100, .280), (.230, .340), (.340, .395), (.430, .450),
    (.480, .472), (.500, .452), (.484, .409), (.455, .383),
    (.395, .320), (.310, .250), (.245, .180), (.180, .120),
    (.150, .060), (.145, .015),
)
AXIAL_RATIO = .46


def _smooth(value):
    value = max(0., min(1., value))
    return value * value * (3. - 2. * value)


def _key(point):
    return tuple(round(float(value), 8) for value in point)


def _outer_radius(y):
    outer = PROFILE[:14]
    if y <= outer[0][0]: return outer[0][1]
    for (a, ra), (b, rb) in zip(outer, outer[1:]):
        if y <= b:
            t = (y - a) / (b - a)
            return ra * (1. - t) + rb * t
    return outer[-1][1]


def _ring_tube(api, centers, radii, sides):
    """Horizontal rings avoid unstable local frames along a nearly axial tube."""
    c = api.Cage()
    rings = []
    for center, radius in zip(centers, radii):
        ring = [c.vertex((center[0] + radius * math.cos(math.tau * j / sides),
                          center[1], center[2] + radius * math.sin(math.tau * j / sides)))
                for j in range(sides)]
        if rings: c.connect(rings[-1], ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    c.faces.append(tuple(rings[-1]))
    return c


def _skin(api, lod):
    c = api.Cage()
    around = 48 if lod == 0 else 24
    rings, starts = [], []
    for row, (y, radius) in enumerate(PROFILE):
        ring = []
        for j in range(around):
            angle = math.tau * j / around
            # Shallow longitudinal cortical relief, actual tissue geometry.
            relief = 1. + .012 * math.cos(angle * 12.) * _smooth((y + .4) / .4)
            # A slight asymmetric vestibule is shared with its outer shoulder.
            shift = .025 * _smooth((y - .1) / .35)
            ring.append(c.vertex((radius * math.cos(angle) * relief + shift,
                                  y, AXIAL_RATIO * radius * math.sin(angle) * relief)))
        if rings:
            starts.append(len(c.faces))
            c.connect(rings[-1], ring)
        rings.append(ring)
    c.faces.append(tuple(reversed(rings[0])))
    c.faces.append(tuple(rings[-1]))
    c.group("holdfast", rings[0] + rings[1])
    c.group("trumpet_cortex", sum(rings[2:13], []))
    c.group("oral_rim", sum(rings[12:16], []))
    c.group("vestibule", sum(rings[16:], []))
    c.group("gold_boundary", rings[0], .22)
    c.group("gold_boundary", rings[13], .34)
    # Twenty-four fine rooted shafts represent twelve visual bundles. They
    # are one Skin mesh. They are not twenty-four new behavior/feeler channels.
    for index in range(24):
        sector = index * around // 24
        face = c.inset(starts[13] + sector, .075)
        vertices = c.faces[face]
        base = tuple(sum(c.vertices[v][axis] for v in vertices) / len(vertices) for axis in range(3))
        angle = math.atan2(base[2] / AXIAL_RATIO, base[0] - .025)
        radial = (math.cos(angle), 0., AXIAL_RATIO * math.sin(angle))
        tangent = (-math.sin(angle), 0., AXIAL_RATIO * math.cos(angle))
        centers = []
        for t in (.34, .70, 1.):
            bend = .022 * math.sin(math.pi * t * .8)
            centers.append((base[0] + radial[0] * .025 * t + tangent[0] * bend,
                            base[1] + .10 * t,
                            base[2] + radial[2] * .025 * t + tangent[2] * bend))
        c.extrude(face, centers, (.0037, .0025, .0006),
                  group="cilium_%d" % (index // 2), region="cilia")
    return c


def _organs(api, col, lod, seed):
    objects = []
    samples = 61 if lod == 0 else 37
    centers, radii = [], []
    for i in range(samples):
        t = i / (samples - 1)
        centers.append((.008 * math.sin(math.tau * t), -.31 + .37 * t,
                        -.010 + .003 * math.sin(math.tau * t * 1.5)))
        # One continuous moniliform nucleus with narrow connecting isthmuses.
        radii.append(.011 + .020 * (.5 + .5 * math.cos(math.tau * 5. * t)) ** 2)
    nucleus = _ring_tube(api, centers, radii, 10 if lod == 0 else 6)
    nucleus.group("nuclear_chain", range(len(nucleus.vertices)))
    objects.append(api.make_object("Macronucleus", nucleus, col, 0, "internal_organ"))
    vacuole = api.ellipsoid_cage((-.26, .245, .015), (.030, .036, .018), seed + 401, 2 if lod == 0 else 1)
    vacuole.group("contractile_vacuole", range(len(vacuole.vertices)))
    objects.append(api.make_object("ContractileVacuole", vacuole, col, 0, "internal_organ"))
    # Three sparse paired exemplars communicate subcortical organization.
    # They do not purport to reproduce the cell's full molecular fiber count.
    for index, angle in enumerate((.35, 2.5, 4.55)):
        for partner, delta, label in ((0, -.025, "Myoneme"), (1, .025, "KmFiber")):
            points = []
            count = 22 if lod == 0 else 14
            for step in range(count):
                y = -.345 + .665 * step / (count - 1)
                r = _outer_radius(y) * .86
                a = angle + delta + .06 * _smooth((y + .3) / .6)
                points.append((r * math.cos(a) + .025 * _smooth((y - .1) / .35),
                               y, AXIAL_RATIO * r * math.sin(a)))
            cage = _ring_tube(api, points, [.0033] * count, 6 if lod == 0 else 4)
            cage.group("subcortical_structure", range(len(cage.vertices)))
            objects.append(api.make_object("%s_%02d" % (label, index), cage, col, 0, "internal_organ"))
    return objects


def _group_weights(obj, name):
    group = obj.vertex_groups.get(name)
    if group is None: return [0.] * len(obj.data.vertices)
    return [next((float(g.weight) for g in v.groups if g.group == group.index), 0.) for v in obj.data.vertices]


def build_objects(api, col, lod, seed):
    if lod not in (0, 1): raise ValueError("Stentor LOD must be0 or1")
    skin = api.make_object("Skin", _skin(api, lod), col, 1 if lod == 0 else 0, "continuous_skin")
    objects = [skin] + _organs(api, col, lod, seed)
    for obj in objects:
        gold = _group_weights(obj, "gold_boundary")
        cilia = _group_weights(obj, "cilia")
        phase_weights = [0.] * len(obj.data.vertices)
        for bundle in range(12):
            values = _group_weights(obj, "cilium_%d" % bundle)
            phase_weights = [max(a, b) for a, b in zip(phase_weights, values)]
        phases, semantics = {}, []
        for v in obj.data.vertices:
            point = tuple(api.gd(v.co))
            phases[_key(point)] = phase_weights[v.index]
            window = 0.
            if obj.name == "Skin" and cilia[v.index] < .2:
                x, y, z = point
                # Two contained, uneven optical windows; no all-body striping.
                a = ((x + .04) / .16) ** 2 + ((y + .12) / .20) ** 2 + ((z + .070) / .075) ** 2
                b = ((x + .19) / .12) ** 2 + ((y - .24) / .13) ** 2 + ((z - .035) / .070) ** 2
                window = .70 * max(0., 1. - min(a, b))
            region = 2 if obj.name != "Skin" else 4 if cilia[v.index] > .2 else 5 if window > .35 else 1
            semantics.append((gold[v.index], window, region))
        _PHASE_WEIGHTS[obj.name] = phases
        _SEMANTICS[obj.name] = semantics
    return objects


def deform(point, law, phase, object_name):
    x, y, z = (float(value) for value in point)
    law, phase = max(0., min(1., float(law))), max(-1., min(1., float(phase)))
    if y <= -.46: return (x, y, z)  # Actual fixed holdfast, including its rim.
    u = y + .46
    t = min(1., u / .12)
    integral = .12 * (t ** 3 - .5 * t ** 4) if u < .12 else u - .06
    # dy'/dy >= .38, so the shared coordinate map cannot reverse longitudinal
    # order. This is a bounded authored compression, not volume conservation.
    out_y = y - .62 * law * integral
    flare = .67 * math.exp(-((y + .10) / .36) ** 2) - .34 * _smooth((y - .23) / .27)
    radial = 1. + law * flare * _smooth(u / .12)
    out_x, out_z = x * radial, z * radial
    weight = _PHASE_WEIGHTS.get(object_name, {}).get(_key(point), 0.)
    if weight:
        angle = math.atan2(z / AXIAL_RATIO, x)
        beat = .0042 * phase * weight * weight * (1. - .40 * law)
        out_x += -math.sin(angle) * beat
        out_z += AXIAL_RATIO * math.cos(angle) * beat
        out_y += .0012 * phase * weight * weight
    return (out_x, out_y, out_z)


def rig_specs():
    return [("DEF_holdfast", (0., -.50, 0.), (0., -.43, 0.))] + [
        ("DEF_cortex_%02d" % i, (0., -.43 + i * .18, 0.), (0., -.25 + i * .18, 0.))
        for i in range(5)]


def vertex_semantics(obj):
    if obj.name not in _SEMANTICS: raise ValueError("Build Stentor before reading semantic attributes")
    return list(_SEMANTICS[obj.name])


def metadata(species, objects):
    if species != "stentor": raise ValueError("Stentor module cannot describe another species")
    return {
        "parts": [{"object": obj.name, "role": obj["anatomy_role"], "topology": "closed",
                   "container": None if obj.name == "Skin" else "Skin"} for obj in objects],
        "attachments": [],
        "required_regions": [{"object": "Skin", "vertex_group": group, "min_vertices": 3}
            for group in ("holdfast", "trumpet_cortex", "oral_rim", "vestibule", "cilia")]
            + [{"object": "Macronucleus", "vertex_group": "nuclear_chain", "min_vertices": 3},
               {"object": "ContractileVacuole", "vertex_group": "contractile_vacuole", "min_vertices": 3}],
    }
