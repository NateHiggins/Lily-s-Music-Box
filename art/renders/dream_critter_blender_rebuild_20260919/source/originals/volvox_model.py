"""External Volvox authoring module; not an admitted runtime asset.

Builder hooks: build_objects(api, collection, lod, seed),
deform(point, law, phase, object_name), vertex_semantics(obj), rig_specs(),
metadata(species, objects).  No bpy import, scene mutation, or export occurs at
module import.  The owning builder supplies Cage, make_object, and gd.

The daughter is one thick, connected cell sheet.  Two material sides meet at a
rounded phialopore rim; it has no open mesh edges and no face capping the lumen.
This is an authored geometric eversion, not a biomechanical simulation.  The
opening widens around a moving bend before narrowing on the inverted sheet.
The middle poses keep a raised annular fold rather than flattening the entire
sheet into a coincident disk.  Parent rotation belongs to the runtime owner.
"""

import math
import struct

SPECIES_ID = 11
MOTION_PROFILE = "volvox_daughter_inversion"
CILIUM_BRANCH_COUNT = 12
LAW_KEYS = ("Basis", "law_01", "law_02", "law_03", "law_04", "law_05",
            "law_06", "law_07", "law_half", "law_09", "law_10", "law_11",
            "law_12", "law_13", "law_14", "law_15", "law_full")
PHASE_KEYS = ("gait_a", "gait_b")
POSE_KEYS = LAW_KEYS + PHASE_KEYS
PARENT_RADIUS = .46
DAUGHTER_RADIUS = .058
OPENING_ANGLE = .40
THETA_MAX = math.pi - OPENING_ANGLE
DAUGHTERS = {
    "Daughter_A": ((-.175, .105, -.035), -.24, .10),
    "Daughter_B": ((.170, .100, .030), .29, -.18),
    "Daughter_C": ((-.010, -.185, -.005), -.10, -.12),
}
_BINDINGS = {}
_SEMANTICS = {}
_VERTEX_BINDINGS = {}


def _clamp(value, low=0., high=1.):
    return max(low, min(high, value))


def _smooth(value):
    value = _clamp(value)
    return value * value * (3. - 2. * value)


def _add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def _scale(a, value):
    return tuple(component * value for component in a)


def _unit(a):
    length = math.sqrt(sum(component * component for component in a))
    if length < 1e-12:
        raise ValueError("Volvox parameterization produced a zero direction")
    return _scale(a, 1. / length)


def _key(point):
    # Realized float32 Blender coordinates are recorded by build_objects.
    return tuple(round(float(component), 8) for component in point)


def _rotate(point, yaw, pitch):
    x, y, z = point
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    return (cy * x + sy * z,
            cp * y - sp * (-sy * x + cy * z),
            sp * y + cp * (-sy * x + cy * z))


def _seeds(count, seed):
    # A non-latitudinal cell mosaic, shared by both LODs and all poses.
    angle = (math.sqrt(5.) - 1.) * math.pi
    turn = (int(seed) % 997) * .017
    result = []
    for index in range(count):
        z = 1. - 2. * (index + .5) / count
        radius = math.sqrt(max(0., 1. - z * z))
        phi = index * angle + turn
        result.append((radius * math.cos(phi), radius * math.sin(phi), z))
    return result


def _cell_weights(direction, seeds):
    nearest = sorted((sum(direction[i] * seed[i] for i in range(3))
                      for seed in seeds), reverse=True)
    gap = nearest[0] - nearest[1]
    boundary = 1. - _smooth(gap / .026)
    dome = _smooth((nearest[0] - .87) / .13) * (1. - .35 * boundary)
    return dome, boundary


def _middle(u, phi, law):
    """Mid-surface position and its material-side normal in a daughter frame."""
    theta = u * THETA_MAX
    spread = math.sin(math.pi * law) ** 2
    radial = DAUGHTER_RADIUS * ((1. - spread) * math.sin(theta)
                               + spread * 1.82 * u)
    dr_du = DAUGHTER_RADIUS * ((1. - spread) * math.cos(theta) * THETA_MAX
                              + spread * 1.82)
    lobes = 1. + .065 * math.cos(4. * phi) * u ** 8
    dl_du = .52 * math.cos(4. * phi) * u ** 7
    dr_phi = radial * -.26 * math.sin(4. * phi) * u ** 8
    dr_du = dr_du * lobes + radial * dl_du
    radial *= lobes
    axial = -math.cos(math.pi * law) * DAUGHTER_RADIUS * (
        math.cos(theta) + math.cos(OPENING_ANGLE))
    dz_du = math.cos(math.pi * law) * DAUGHTER_RADIUS * math.sin(theta) * THETA_MAX
    # This bend exists only while radius is strictly increasing along the
    # meridian.  Outside that interval axial height is monotonic, so the
    # mid-surface never doubles back onto itself in either regime.
    if .30 < law < .70:
        bend = math.sin(math.pi * (law - .30) / .40) ** 2
        shift = .65 * (2. * law - 1.)
        wave = math.sin(math.pi * u) ** 2
        bias = 1. + shift * (2. * u - 1.)
        axial += DAUGHTER_RADIUS * .43 * bend * wave * bias
        dz_du += DAUGHTER_RADIUS * .43 * bend * (
            math.pi * math.sin(2. * math.pi * u) * bias + wave * 2. * shift)
    cp, sp = math.cos(phi), math.sin(phi)
    if u < 1e-10:
        normal = (0., 0., -1.)
    else:
        normal = _unit((dz_du * (dr_phi * sp + radial * cp),
                        dz_du * (radial * sp - dr_phi * cp),
                        -dr_du * radial))
    tangent = _unit((dr_du * cp, dr_du * sp, dz_du))
    return (radial * cp, radial * sp, axial), normal, tangent


def _daughter_point(name, parameter, law, phase):
    u, phi, side, dome, boundary = parameter
    middle, normal, tangent = _middle(u, phi, law)
    outer = .0018 + .0010 * dome + .00022 * boundary
    inner = .0016
    # Breathing alters tissue thickness gently; it never changes placement,
    # inversion phase, or topology and uses the existing authored phase keys.
    outer += .00016 * phase * dome
    if side == "outer":
        point = _add(middle, _scale(normal, outer))
    elif side == "inner":
        point = _add(middle, _scale(normal, -inner))
    else:
        # side is the rounded rim angle, 0 = outer and pi = inner.
        half = (outer + inner) * .5
        offset = (outer - inner) * .5 + half * math.cos(side)
        point = _add(_add(middle, _scale(normal, offset)),
                     _scale(tangent, half * math.sin(side)))
    center, yaw, pitch = DAUGHTERS[name]
    return _add(center, _rotate(point, yaw, pitch))


def _parent_point(parameter, phase):
    if parameter[0] == "flagellum":
        _, roots, relative, weight, tangent = parameter
        center = tuple(sum(_parent_point(root, phase)[axis] for root in roots) / len(roots)
                       for axis in range(3))
        return _add(_add(center, relative), _scale(tangent, .018 * phase * weight * weight))
    direction, dome, boundary = parameter
    radius = PARENT_RADIUS + .004 * dome - .001 * boundary
    radius += phase * .0005 * dome
    return _scale(direction, radius)


class _Geometry:
    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.parameters = []
        self.semantics = []
        self.bindings = []
        self.groups = {}

    def vertex(self, position, parameter, semantics, weights, binding=(-1., 0.)):
        index = len(self.vertices)
        self.vertices.append(position)
        self.parameters.append(parameter)
        self.semantics.append(semantics)
        self.bindings.append(binding)
        for name, weight in weights.items():
            if weight > 0.:
                self.groups.setdefault(name, {})[index] = _clamp(weight)
        return index

    def connect(self, first, second, reverse=False):
        for index in range(len(first)):
            following = (index + 1) % len(first)
            face = (first[index], first[following], second[following], second[index])
            self.faces.append(tuple(reversed(face)) if reverse else face)


def _parent(lod, seed):
    model = _Geometry("Skin")
    around, bands = (48, 24) if lod == 0 else (24, 12)
    seeds = _seeds(62, seed)

    def vertex(theta, phi):
        direction = (math.sin(theta) * math.cos(phi),
                     math.sin(theta) * math.sin(phi), math.cos(theta))
        dome, boundary = _cell_weights(direction, seeds)
        parameter = (direction, dome, boundary)
        return model.vertex(_parent_point(parameter, 0.), parameter,
                            (.02 + .30 * boundary ** 3, .72 * (1. - dome), 1),
                            {"cell_sheet": 1., "somatic_cells": dome,
                             "gold_boundary": boundary, "thin_window": 1. - dome,
                             "cytoplasmic_bridge": boundary})

    north = vertex(0., 0.)
    previous = None
    for band in range(1, bands):
        ring = [vertex(math.pi * band / bands, math.tau * index / around)
                for index in range(around)]
        if previous is None:
            for index in range(around):
                model.faces.append((north, ring[(index + 1) % around], ring[index]))
        else:
            model.connect(previous, ring)
        previous = ring
    south = vertex(math.pi, 0.)
    for index in range(around):
        model.faces.append((previous[index], previous[(index + 1) % around], south))
    model.faces = [tuple(reversed(face)) for face in model.faces]
    _somatic_flagella(model, seeds, seed)
    return model


def _somatic_flagella(model, cell_seeds, seed):
    """Twelve paired shafts grow from real parent faces, with one owner root per pair."""
    available = [index for index, face in enumerate(model.faces) if len(face) == 4]
    for branch, desired in enumerate(_seeds(CILIUM_BRANCH_COUNT, seed + 403)):
        def alignment(index):
            direction = _unit(tuple(sum(model.vertices[vertex][axis] for vertex in model.faces[index])
                                    / 4. for axis in range(3)))
            return sum(direction[axis] * desired[axis] for axis in range(3))
        face_index = max(available, key=alignment)
        available.remove(face_index)
        original = model.faces[face_index]
        center = tuple(sum(model.vertices[index][axis] for index in original) / 4.
                       for axis in range(3))
        patch = []
        for index in original:
            direction = _unit(tuple(center[axis] + (model.vertices[index][axis] - center[axis]) * .16
                                    for axis in range(3)))
            dome, boundary = _cell_weights(direction, cell_seeds)
            parameter = (direction, dome, boundary)
            patch.append(model.vertex(_parent_point(parameter, 0.), parameter,
                                      (.02 + .30 * boundary ** 3, .72 * (1. - dome), 1),
                                      {"cell_sheet": 1., "somatic_cells": dome,
                                       "cilium_%d_root" % branch: 1., "ciliary_field": 1.}))
        roots = tuple(model.parameters[index] for index in patch)
        center = tuple(sum(model.vertices[index][axis] for index in patch) / 4.
                       for axis in range(3))
        normal = _unit(center)
        tangent = _unit(tuple(model.vertices[patch[1]][axis] - model.vertices[patch[0]][axis]
                              for axis in range(3)))
        model.faces[face_index] = ()
        model.connect(original, patch)

        def bound_vertex(relative, weight):
            parameter = ("flagellum", roots, relative, weight, tangent)
            return model.vertex(_parent_point(parameter, 0.), parameter, (.10, .08, 4),
                                {"cilium_%d" % branch: weight, "ciliary_field": 1.},
                                (-2. - branch, weight))

        stem = []
        for index in patch:
            offset = _unit(tuple(model.vertices[index][axis] - center[axis] for axis in range(3)))
            stem.append(bound_vertex(_add(_scale(normal, .010), _scale(offset, .0048)), .09))
        model.connect(patch, stem)
        cap_center = bound_vertex(_scale(normal, .010), .09)
        for corner in range(4):
            base = (stem[corner], stem[(corner + 1) % 4], cap_center)
            if corner in (1, 3):
                model.faces.append(base)
                continue
            # Opposite triangles leave a genuine, connected bifurcation.
            # The two fine shafts share the rooted stem but never intersect.
            base_center = tuple(sum(model.vertices[index][axis] - center[axis] for index in base) / 3.
                                for axis in range(3))
            outward = _unit(tuple(base_center[axis] - normal[axis] * .010 for axis in range(3)))
            previous = base
            for along, (distance, radius) in enumerate(((.018, .0022), (.057, .0011), (.100, .0003))):
                relative_center = _add(_scale(normal, distance),
                                       _add(_scale(outward, .0032 + .050 * distance),
                                            _scale(tangent, .005 * math.sin(branch * .9) * distance / .1)))
                ring = []
                for index in base:
                    offset = _unit(tuple(model.vertices[index][axis] - center[axis] - base_center[axis]
                                         for axis in range(3)))
                    ring.append(bound_vertex(_add(relative_center, _scale(offset, radius)), distance / .100))
                model.connect(previous, ring)
                previous = ring
            model.faces.append(tuple(previous))
    model.faces = [face for face in model.faces if face]


def _daughter(name, lod, seed):
    model = _Geometry(name)
    around, bands = (40, 20) if lod == 0 else (20, 10)
    seeds = _seeds(26, seed)
    end_rings = {}

    def vertex(u, phi, side):
        theta = u * THETA_MAX
        direction = (math.sin(theta) * math.cos(phi),
                     math.sin(theta) * math.sin(phi), -math.cos(theta))
        dome, boundary = _cell_weights(direction, seeds)
        parameter = (u, phi, side, dome, boundary)
        rim = _smooth((u - .84) / .16)
        gold = .10 + .50 * boundary + .30 * rim
        window = .22 + .38 * (1. - dome)
        return model.vertex(_daughter_point(name, parameter, 0., 0.), parameter,
                            (_clamp(gold), window, 2),
                            {"cell_sheet": 1., "somatic_cells": dome,
                             "gold_boundary": max(boundary, rim),
                             "cytoplasmic_bridge": boundary,
                             "thin_window": 1. - dome, "phialopore_rim": rim,
                             "material_outer": 1. if side == "outer" else 0.,
                             "material_inner": 1. if side == "inner" else 0.})

    for side in ("outer", "inner"):
        pole = vertex(0., 0., side)
        previous = None
        for band in range(1, bands + 1):
            ring = [vertex(band / bands, math.tau * index / around, side)
                    for index in range(around)]
            if previous is None:
                for index in range(around):
                    face = (pole, ring[(index + 1) % around], ring[index])
                    model.faces.append(tuple(reversed(face)) if side == "inner" else face)
            else:
                model.connect(previous, ring, reverse=side == "inner")
            previous = ring
        end_rings[side] = previous
    previous = end_rings["outer"]
    for step in range(1, 4):
        ring = [vertex(1., math.tau * index / around, math.pi * step / 4.)
                for index in range(around)]
        model.connect(previous, ring)
        previous = ring
    model.connect(previous, end_rings["inner"])
    return model


def geometry(lod=1, seed=119):
    """Pure geometry for preflight; does not create Blender data or export."""
    if lod not in (0, 1):
        raise ValueError("Volvox LOD must be 0 or 1")
    return [_parent(lod, seed)] + [_daughter(name, lod, seed + index * 31)
                                  for index, name in enumerate(DAUGHTERS)]


def posed_vertices(model, law=0., phase=0.):
    law, phase = _clamp(float(law)), _clamp(float(phase), -1., 1.)
    if model.name == "Skin":
        return [_parent_point(parameter, phase) for parameter in model.parameters]
    return [_daughter_point(model.name, parameter, law, phase)
            for parameter in model.parameters]


def build_objects(api, col, lod, seed):
    """Create four un-subdivided meshes; builder owns all shapes/rig/export."""
    objects = []
    for model in geometry(lod, seed):
        cage = api.Cage()
        cage.vertices.extend(model.vertices)
        cage.faces.extend(model.faces)
        cage.groups.update(model.groups)
        role = "continuous_skin" if model.name == "Skin" else "internal_organ"
        obj = api.make_object(model.name, cage, col, 0, role)
        if len(obj.data.vertices) != len(model.vertices):
            raise ValueError("Volvox builder changed the fixed authoring topology")
        original = {_key(struct.unpack("3f", struct.pack("3f", *point))): index
                    for index, point in enumerate(model.vertices)}
        # Float32 realization can change the final decimals.  Use nearest
        # original point only once at authoring time, then exact realized keys.
        bindings, semantics, vertex_bindings = {}, [], []
        used = set()
        for vertex in obj.data.vertices:
            point = tuple(api.gd(vertex.co))
            index = original.get(_key(point))
            if index is None:
                distances = [sum((point[j] - candidate[j]) ** 2 for j in range(3))
                             for candidate in model.vertices]
                index = min(range(len(distances)), key=distances.__getitem__)
                if distances[index] > 1e-12:
                    raise ValueError("Volvox realized vertex escaped its parameter sample")
            if index in used:
                raise ValueError("Volvox authoring parameter sample was duplicated")
            used.add(index)
            bindings[_key(point)] = model.parameters[index]
            semantics.append(model.semantics[index])
            vertex_bindings.append(model.bindings[index])
        _BINDINGS[obj.name] = bindings
        _SEMANTICS[obj.name] = semantics
        _VERTEX_BINDINGS[obj.name] = vertex_bindings
        objects.append(obj)
    return objects


def deform(point, law, phase, object_name):
    if object_name not in _BINDINGS or _key(point) not in _BINDINGS[object_name]:
        raise ValueError("Build Volvox objects before evaluating their shape keys")
    parameter = _BINDINGS[object_name][_key(point)]
    if object_name == "Skin":
        return _parent_point(parameter, _clamp(phase, -1., 1.))
    return _daughter_point(object_name, parameter, _clamp(law), _clamp(phase, -1., 1.))


def vertex_semantics(obj):
    """COLOR R=gold, G=window, B=region/255; no spatial stripe fallback."""
    if obj.name not in _SEMANTICS:
        raise ValueError("Missing Volvox realized semantic binding")
    return list(_SEMANTICS[obj.name])


def vertex_bindings(obj):
    """UV1 branch code and axial weight; the twelve parent bundles own count variation."""
    if obj.name not in _VERTEX_BINDINGS:
        raise ValueError("Missing Volvox realized branch binding")
    return list(_VERTEX_BINDINGS[obj.name])


def rig_specs():
    specs = [("DEF_colony", (0., -.06, 0.), (0., .06, 0.))]
    for name, (center, _yaw, _pitch) in DAUGHTERS.items():
        specs.append(("DEF_" + name.lower(), center, _add(center, (0., .035, 0.))))
    return specs


def metadata(species, objects):
    if species != "volvox":
        raise ValueError("Volvox module cannot describe another species")
    return {
        "parts": [{"object": obj.name, "role": obj["anatomy_role"],
                   "topology": "closed", "container": None if obj.name == "Skin" else "Skin"}
                  for obj in objects],
        "attachments": [],
        "required_regions": [
            {"object": obj.name, "vertex_group": group, "min_vertices": 3}
            for obj in objects
            for group in (("cell_sheet", "somatic_cells", "cytoplasmic_bridge")
                          + tuple("cilium_%d_root" % index for index in range(CILIUM_BRANCH_COUNT))
                          + ("ciliary_field",) if obj.name == "Skin" else
                          ("cell_sheet", "material_outer", "material_inner", "phialopore_rim"))],
    }
