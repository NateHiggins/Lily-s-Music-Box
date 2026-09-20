"""Read-only evaluated anatomy checks; no export, source save or generation.

blender --background --factory-startup --disable-autoexec --python SCRIPT --
    --blend specimen.blend --out NEW_REPORT.json

Requires scene['dream_critter_contract'] JSON. Structural results are not
biological/artistic acceptance or Blender-to-runtime deformation parity.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import sys

SCHEMA = "dream_critter_anatomy.v1"
NAMES = ("seam_grazer", "crystal_listener", "fold_crab", "tardigrade", "stentor",
         "lacrymaria", "vorticella", "euplotes", "spirostomum", "heliozoan",
         "euglena", "volvox", "noctiluca", "bacillaria", "salpingoeca", "mesodinium")


class ContractError(ValueError):
    pass


def need(condition, message):
    if not condition:
        raise ContractError(message)


def script_arguments(argv=None):
    args = list(sys.argv if argv is None else argv)
    return args[args.index("--") + 1:] if "--" in args else args[1:]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def strict_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            need(key not in result, "duplicate JSON key: " + key)
            result[key] = value
        return result
    def invalid(value):
        raise ContractError("nonfinite JSON number: " + value)
    return json.loads(text, object_pairs_hook=pairs, parse_constant=invalid)


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def read_contract(scene):
    raw = scene.get("dream_critter_contract")
    need(isinstance(raw, str), "missing scene dream_critter_contract JSON string")
    c = strict_json(raw)
    required = {"schema", "species_id", "species_name", "seed", "units", "collection",
                "body", "rig", "poses", "parts", "attachments", "required_regions"}
    need(isinstance(c, dict) and required <= c.keys(), "missing anatomy contract fields")
    need(not c.keys() - required - {"provenance", "limits"}, "unknown anatomy contract fields")
    need(c["schema"] == SCHEMA, "unsupported anatomy schema")
    kind = c["species_id"]
    need(type(kind) is int and 0 <= kind < len(NAMES), "invalid species_id")
    need(c["species_name"] == NAMES[kind], "species name/id mismatch")
    need(type(c["seed"]) is int and c["units"] == "m", "integer seed and metre units required")
    for key in ("collection", "body"):
        need(isinstance(c[key], str) and c[key], "missing " + key)
    need(c["rig"] is None or isinstance(c["rig"], str), "rig must be name or null")
    for key in ("poses", "parts", "attachments", "required_regions"):
        need(isinstance(c[key], list), key + " must be an array")
    need(len(c["poses"]) >= 3, "neutral and two motion poses required")
    names = set()
    for p in c["poses"]:
        need(isinstance(p, dict) and set(p) <= {"name", "shape_keys", "bones"}, "invalid pose fields")
        name = p.get("name")
        need(isinstance(name, str) and name and name not in names, "unique pose names required")
        need(all(x.isalnum() or x == "_" for x in name), "unsafe pose filename")
        names.add(name)
        need(isinstance(p.get("shape_keys", {}), dict) and isinstance(p.get("bones", {}), dict), "invalid pose maps")
        for obj, keys in p.get("shape_keys", {}).items():
            need(isinstance(obj, str) and isinstance(keys, dict), "invalid shape map")
            for key, value in keys.items():
                need(isinstance(key, str) and key != "Basis" and finite(value) and 0 <= value <= 1, "invalid normalized shape value")
                if name == "neutral": need(value == 0, "neutral cannot activate shape keys")
        for bone, values in p.get("bones", {}).items():
            need(isinstance(bone, str) and isinstance(values, dict) and values, "invalid bone pose")
            need(set(values) <= {"rotation_euler", "location", "scale"}, "unsupported bone channel")
            for key, value in values.items():
                need(isinstance(value, list) and len(value) == 3 and all(finite(x) for x in value), "invalid bone vector")
                if key == "scale": need(all(x > 0 for x in value), "bone scale must be positive")
                if name == "neutral": need(value == ([1, 1, 1] if key == "scale" else [0, 0, 0]), "neutral bone pose must be identity")
    need("neutral" in names, "neutral pose required")
    declared = set()
    for p in c["parts"]:
        need(isinstance(p, dict) and set(p) == {"object", "role", "topology", "container"}, "invalid part fields")
        need(isinstance(p["object"], str) and p["object"] and p["object"] not in declared, "unique part names required")
        declared.add(p["object"])
        need(p["role"] in {"continuous_skin", "internal_organ", "external_organ", "support", "cilia"}, "unknown part role")
        need(p["topology"] in {"closed", "sheet"}, "unknown topology")
        need(p["container"] is None or isinstance(p["container"], str), "invalid container")
        if p["role"] == "internal_organ": need(p["container"] is not None, "internal organ needs container")
    bodies = [p for p in c["parts"] if p["role"] == "continuous_skin"]
    need(len(bodies) == 1 and bodies[0]["object"] == c["body"] and bodies[0]["topology"] == "closed"
         and bodies[0]["container"] is None, "one closed continuous skin required")
    parents = {p["object"]: p["container"] for p in c["parts"]}
    for name in parents:
        visited = set()
        while name is not None:
            need(name in parents and name not in visited, "unknown/cyclic container")
            visited.add(name)
            name = parents[name]
    regions = set()
    for r in c["required_regions"]:
        need(isinstance(r, dict) and set(r) == {"object", "vertex_group", "min_vertices"}, "invalid region fields")
        need(r["object"] in declared and isinstance(r["vertex_group"], str), "unknown region object/group")
        need(type(r["min_vertices"]) is int and r["min_vertices"] > 0, "nonempty region required")
        regions.add((r["object"], r["vertex_group"]))
    need(len(regions) == len(c["required_regions"]), "duplicate region declarations")
    expected = (["leg_root_%d" % i for i in range(8)] + ["mouth"]) if kind == 3 else (
        ["holdfast", "stalk", "bell", "oral_rim"] if kind == 6 else [])
    need({(c["body"], name) for name in expected} <= regions, "pilot required anatomical regions missing")
    for r in c["attachments"]:
        need(isinstance(r, dict) and set(r) == {"object", "vertex_group", "target", "max_gap_fraction", "max_drift_fraction"}, "invalid attachment")
        need(r["object"] in declared and r["target"] in declared and r["object"] != r["target"], "attachment requires separate parts")
        need(isinstance(r["vertex_group"], str) and r["vertex_group"], "attachment group required")
        need(finite(r["max_gap_fraction"]) and 0 <= r["max_gap_fraction"] <= .01, "gap tolerance exceeds 1%")
        need(finite(r["max_drift_fraction"]) and 0 <= r["max_drift_fraction"] <= .001, "drift tolerance exceeds 0.1%")
    return c


def load_source(path):
    import bpy
    path = Path(path).resolve(strict=True)
    need(path.suffix.lower() == ".blend", "input must be .blend")
    before = sha256(path)
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
    need(not bpy.data.libraries, "linked libraries are not admitted")
    c = read_contract(bpy.context.scene)
    collection = bpy.data.collections.get(c["collection"])
    need(collection is not None, "declared collection missing")
    objects = {obj.name: obj for obj in collection.all_objects}
    declared = {p["object"] for p in c["parts"]}
    actual = {name for name, obj in objects.items() if obj.type == "MESH"}
    need(actual == declared, "mesh census mismatch: " + str(sorted(actual ^ declared)))
    need(all(o.type in {"MESH", "ARMATURE", "EMPTY"} for o in objects.values()), "unrealized geometry or scene rig in anatomy collection")
    for p in c["parts"]:
        obj = objects[p["object"]]
        need(obj.get("species_id") == c["species_id"] and obj.get("species_name") == c["species_name"], obj.name + ": identity mismatch")
        need(obj.get("anatomy_role") == p["role"], obj.name + ": role mismatch")
        need(obj.matrix_world.determinant() > 0, obj.name + ": singular/mirrored transform")
        need(not obj.constraints and not (obj.animation_data and obj.animation_data.drivers), obj.name + ": unbaked constraint/driver")
        if obj.data.shape_keys:
            need(not (obj.data.shape_keys.animation_data and obj.data.shape_keys.animation_data.drivers), obj.name + ": shape driver")
        need(all(m.type == "ARMATURE" for m in obj.modifiers), obj.name + ": topology modifiers must be baked")
    rig = objects.get(c["rig"]) if c["rig"] else None
    need(c["rig"] is None or (rig is not None and rig.type == "ARMATURE"), "armature missing")
    if rig:
        need(not rig.constraints and not (rig.animation_data and rig.animation_data.drivers), "unbaked rig constraints/drivers")
        need(all(not b.constraints for b in rig.pose.bones), "unbaked bone constraints")
    for p in c["poses"]:
        for name, keys in p.get("shape_keys", {}).items():
            need(name in declared and objects[name].data.shape_keys is not None, "pose has unknown/unkeyed mesh")
            need(all(k in objects[name].data.shape_keys.key_blocks for k in keys), name + ": missing shape key")
        need(not p.get("bones") or rig is not None, "bone pose without rig")
        if rig: need(all(n in rig.pose.bones for n in p.get("bones", {})), "unknown pose bone")
    units = bpy.context.scene.unit_settings
    need(units.system == "METRIC" and abs(units.scale_length - 1.0) < 1e-9, "metric metre scene required")
    return path, before, c, objects, rig


def apply_pose(contract, objects, rig, pose):
    import bpy
    for obj in objects.values():
        if obj.animation_data: obj.animation_data_clear()
        if obj.type == "MESH" and obj.data.shape_keys:
            if obj.data.shape_keys.animation_data: obj.data.shape_keys.animation_data_clear()
            for key in obj.data.shape_keys.key_blocks: key.value = 0.0
    if rig:
        for bone in rig.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler, bone.location, bone.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
    for name, keys in pose.get("shape_keys", {}).items():
        for key, value in keys.items(): objects[name].data.shape_keys.key_blocks[key].value = value
    for name, values in pose.get("bones", {}).items():
        for key, value in values.items(): setattr(rig.pose.bones[name], key, value)
    bpy.context.view_layer.update()


def pose_samples(contract):
    """Authored states plus bounded samples of the pilot runtime morph envelope."""
    samples = list(contract["poses"])
    poses = {p["name"]: p for p in samples}
    law_names = ["neutral"] + ["law_half" if i == 8 else "law_full" if i == 16 else "law_%02d" % i for i in range(1, 17)]
    names = set(law_names + ["gait_a", "gait_b"])
    if not names <= poses.keys():
        need(contract["species_id"] not in {3, 6}, "pilot requires all17 law states and gait_a/gait_b")
        return samples
    need(all(not p.get("bones") for p in poses.values()), "runtime morph sampling requires baked shape poses, not bone interpolation")
    def mix(name, weighted):
        shape_keys = {}
        for pose, weight in weighted:
            for obj, keys in pose.get("shape_keys", {}).items():
                target = shape_keys.setdefault(obj, {})
                for key, value in keys.items(): target[key] = target.get(key, 0.0) + value * weight
        return {"name": name, "shape_keys": shape_keys, "bones": {}}
    for i in range(16):
        samples.append(mix("sample_law_mid_%02d" % i, [(poses[law_names[i]], .5), (poses[law_names[i + 1]], .5)]))
    for law, name in ((0.0, "neutral"), (.5, "law_half")):
        for phase in ("gait_a", "gait_b"):
            samples.append(mix("sample_%s_plus_%s" % (name, phase), [(poses[name], 1.0), (poses[phase], .35 * (1.0 - law))]))
    return samples


def evaluated_geometry(obj, depsgraph):
    from mathutils.bvhtree import BVHTree
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
    try:
        mesh.calc_loop_triangles()
        points = [evaluated.matrix_world @ v.co for v in mesh.vertices]
        triangles = [tuple(t.vertices) for t in mesh.loop_triangles]
        groups = defaultdict(list)
        for v in mesh.vertices:
            for group in v.groups:
                if group.weight > .5 and group.group < len(obj.vertex_groups):
                    groups[obj.vertex_groups[group.group].name].append(v.index)
        return {"points": points, "triangles": triangles, "polygons": [tuple(p.vertices) for p in mesh.polygons],
                "vertex_normals": [v.normal.copy() for v in mesh.vertices],
                "edges": [tuple(e.vertices) for e in mesh.edges], "groups": dict(groups),
                "bvh": BVHTree.FromPolygons(points, triangles, all_triangles=True) if triangles else None}
    finally:
        evaluated.to_mesh_clear()


def bounds_of(geometries):
    from mathutils import Vector
    points = [v for g in geometries for v in g["points"]]
    need(points and all(all(math.isfinite(c) for c in p) for p in points), "empty/nonfinite geometry")
    return (Vector(tuple(min(v[i] for v in points) for i in range(3))),
            Vector(tuple(max(v[i] for v in points) for i in range(3))))


def topology(g, scale):
    points, triangles, polygons = (g[k] for k in ("points", "triangles", "polygons"))
    edges, vertex_faces = defaultdict(list), defaultdict(set)
    adjacency = [set() for _ in points]
    for fi, polygon in enumerate(polygons):
        for i, a in enumerate(polygon):
            b = polygon[(i + 1) % len(polygon)]
            edges[tuple(sorted((a, b)))].append((fi, 1 if a < b else -1))
            adjacency[a].add(b)
            adjacency[b].add(a)
            vertex_faces[a].add(fi)
    components, unseen = 0, set(range(len(points)))
    while unseen:
        components += 1
        stack = [unseen.pop()]
        while stack:
            for n in adjacency[stack.pop()]:
                if n in unseen:
                    unseen.remove(n)
                    stack.append(n)
    fans = defaultdict(lambda: defaultdict(set))
    for (a, b), owners in edges.items():
        for f, _ in owners:
            for other, _ in owners:
                if f != other:
                    fans[a][f].add(other)
                    fans[b][f].add(other)
    bad_fans = 0
    for v, faces in vertex_faces.items():
        todo = set(faces)
        stack = [todo.pop()]
        while stack:
            for f in fans[v][stack.pop()]:
                if f in todo:
                    todo.remove(f)
                    stack.append(f)
        bad_fans += bool(todo)
    epsilon = max(scale * 1e-8, 1e-10)
    return {"vertices": len(points), "triangles": len(triangles), "components": components,
            "invalid_vertex_normals": sum(not all(math.isfinite(x) for x in n) or abs(n.length - 1.0) > 1e-4 for n in g["vertex_normals"]),
            "boundary_edges": sum(len(v) == 1 for v in edges.values()),
            "nonmanifold_edges": sum(len(v) > 2 for v in edges.values()), "nonmanifold_vertices": bad_fans,
            "loose_vertices": sum(not v for v in adjacency),
            "loose_edges": sum(tuple(sorted(e)) not in edges for e in g["edges"]),
            "winding_conflicts": sum(len(v) == 2 and v[0][1] == v[1][1] for v in edges.values()),
            "degenerate_triangles": sum((points[b] - points[a]).cross(points[c] - points[a]).length <= epsilon ** 2 for a, b, c in triangles),
            "signed_volume_m3": sum(points[a].dot(points[b].cross(points[c])) / 6 for a, b, c in triangles)}


def triangle_contact(a, b, tolerance):
    ea = [a[(i + 1) % 3] - a[i] for i in range(3)]
    eb = [b[(i + 1) % 3] - b[i] for i in range(3)]
    na, nb = ea[0].cross(ea[1]), eb[0].cross(eb[1])
    axes = [na, nb] + [x.cross(y) for x in ea for y in eb] + [na.cross(x) for x in ea + eb]
    for axis in axes:
        if axis.length_squared < 1e-24: continue
        axis = axis.normalized()
        pa, pb = [p.dot(axis) for p in a], [p.dot(axis) for p in b]
        if max(pa) < min(pb) - tolerance or max(pb) < min(pa) - tolerance: return False
    return True


def surface_intersections(first, second, same=False, tolerance=1e-8):
    need(first["bvh"] is not None and second["bvh"] is not None, "empty intersection surface")
    candidates = first["bvh"].overlap(second["bvh"])
    need(len(candidates) <= 500000, "intersection budget exceeded; no pass issued")
    contacts = []
    for a, b in candidates:
        if same and a >= b: continue
        ta, tb = first["triangles"][a], second["triangles"][b]
        if same and set(ta) & set(tb): continue
        if triangle_contact([first["points"][i] for i in ta], [second["points"][i] for i in tb], tolerance):
            contacts.append((a, b))
            if len(contacts) >= 20: break
    return {"count_at_least": len(contacts), "first_pairs": contacts, "candidate_pairs": len(candidates)}


def inside_surface(point, geometry, tolerance):
    from mathutils import Vector
    nearest = geometry["bvh"].find_nearest(point)
    if nearest[0] is None: return False
    if nearest[3] <= tolerance: return True
    votes = 0
    for axis in ((1, .371, .113), (-.273, 1, .419), (.213, -.317, 1)):
        direction, origin, count = Vector(axis).normalized(), point.copy(), 0
        for _ in range(len(geometry["triangles"]) + 1):
            hit, _normal, _index, _distance = geometry["bvh"].ray_cast(origin, direction)
            if hit is None: break
            count += 1
            origin = hit + direction * tolerance
        else: raise ContractError("containment ray budget exceeded")
        votes += count % 2
    return votes >= 2


def rig_metadata(c, objects, rig):
    result = {"rig": rig.name if rig else None, "bones": [b.name for b in rig.data.bones] if rig else [], "objects": {}, "issues": []}
    for p in c["parts"]:
        obj = objects[p["object"]]
        row = {"uv_layers": [uv.name for uv in obj.data.uv_layers],
               "color_attributes": [a.name for a in obj.data.color_attributes],
               "shape_keys": [k.name for k in obj.data.shape_keys.key_blocks] if obj.data.shape_keys else [],
               "unweighted": 0, "over_four_weights": 0, "unnormalized": 0}
        if rig:
            mods = [m for m in obj.modifiers if m.type == "ARMATURE"]
            if len(mods) != 1 or mods[0].object != rig: result["issues"].append(obj.name + ": incorrect armature binding")
            bone_groups = {g.index for g in obj.vertex_groups if g.name in rig.data.bones}
            for v in obj.data.vertices:
                weights = [g.weight for g in v.groups if g.group in bone_groups and g.weight > 1e-7]
                row["unweighted"] += not weights
                row["over_four_weights"] += len(weights) > 4
                row["unnormalized"] += abs(sum(weights) - 1) > 1e-4
            if any(row[k] for k in ("unweighted", "over_four_weights", "unnormalized")):
                result["issues"].append(obj.name + ": invalid export bone weights")
        if not row["uv_layers"]: result["issues"].append(obj.name + ": no export UV")
        if not row["color_attributes"]: result["issues"].append(obj.name + ": no anatomical color attribute")
        result["objects"][obj.name] = row
    return result


def attachment_frame(points, indices):
    """Triangle material frame; local coordinates follow the same skin patch."""
    from mathutils import Matrix
    a, b, c = (points[i] for i in indices)
    e1, e2 = b - a, c - a
    normal = e1.cross(e2)
    need(normal.length > 1e-16, "degenerate attachment target triangle")
    # Geometric-mean normal scale gives rigid/affine in-plane tracking and
    # uniform scale tracking for a small, nonzero root offset from the skin.
    normal = normal.normalized() * math.sqrt(normal.length)
    return a, Matrix((e1, e2, normal)).transposed()


def validate_loaded(c, objects, rig):
    import bpy
    checks = []
    def check(label, value, details=None):
        checks.append({"check": label, "passed": bool(value), "details": details})
    metadata = rig_metadata(c, objects, rig)
    check("export rig/UV/anatomy metadata", not metadata["issues"], metadata["issues"])
    results, rest_points, rest_gaps, rest_bindings, scale = [], {}, {}, {}, None
    samples = pose_samples(c)
    for pose in sorted(samples, key=lambda p: p["name"] != "neutral"):
        apply_pose(c, objects, rig, pose)
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
        geometry = {p["object"]: evaluated_geometry(objects[p["object"]], deps) for p in c["parts"]}
        lo, hi = bounds_of(geometry.values())
        if scale is None: scale = max(hi - lo)
        need(scale > 1e-6, "degenerate specimen scale")
        row = {"pose": pose["name"], "controls": pose, "bounds": {"min": list(lo), "max": list(hi)},
               "topology": {}, "containment": {}, "attachments": {}, "regions": {}}
        for p in c["parts"]:
            name, g = p["object"], geometry[p["object"]]
            facts = topology(g, scale)
            row["topology"][name] = facts
            valid = facts["vertices"] > 3 and facts["triangles"] > 1
            valid = valid and not any(facts[k] for k in ("invalid_vertex_normals", "nonmanifold_edges", "nonmanifold_vertices", "loose_vertices",
                                                        "loose_edges", "winding_conflicts", "degenerate_triangles"))
            if p["topology"] == "closed": valid = valid and facts["boundary_edges"] == 0 and facts["signed_volume_m3"] > scale ** 3 * 1e-12
            if name == c["body"]: valid = valid and facts["components"] == 1
            check(pose["name"] + ": topology " + name, valid, facts)
            contacts = surface_intersections(g, g, same=True, tolerance=scale * 1e-8)
            facts["self_contacts"] = contacts
            check(pose["name"] + ": no nonadjacent self-contact " + name, contacts["count_at_least"] == 0)
            if pose["name"] == "neutral": rest_points[name] = g["points"]
            if p["container"]:
                container = geometry[p["container"]]
                cp = next(q for q in c["parts"] if q["object"] == p["container"])
                need(cp["topology"] == "closed", "containment target must be closed")
                outside = [i for i, point in enumerate(g["points"]) if not inside_surface(point, container, scale * 1e-6)]
                crossing = surface_intersections(g, container, tolerance=scale * 1e-8)
                row["containment"][name] = {"container": p["container"], "checked_vertices": len(g["points"]),
                    "outside_count": len(outside), "outside_first": outside[:20], "surface_contacts": crossing}
                check(pose["name"] + ": contained organ " + name, not outside and crossing["count_at_least"] == 0)
        for region in c["required_regions"]:
            indices = geometry[region["object"]]["groups"].get(region["vertex_group"], [])
            key = region["object"] + "/" + region["vertex_group"]
            row["regions"][key] = len(indices)
            check(pose["name"] + ": integrated region " + key, len(indices) >= region["min_vertices"])
        for index, root in enumerate(c["attachments"]):
            g, target = geometry[root["object"]], geometry[root["target"]]
            indices = g["groups"].get(root["vertex_group"], [])
            need(indices, "empty attachment vertex group")
            nearest = [target["bvh"].find_nearest(g["points"][i]) for i in indices]
            gaps = [hit[3] for hit in nearest]
            need(all(gap is not None for gap in gaps), "unmeasurable attachment")
            if pose["name"] == "neutral":
                rest_gaps[index] = dict(zip(indices, gaps))
                rest_bindings[index] = {}
                for vertex, hit in zip(indices, nearest):
                    triangle = target["triangles"][hit[2]]
                    origin, frame = attachment_frame(target["points"], triangle)
                    rest_bindings[index][vertex] = (triangle, frame.inverted() @ (g["points"][vertex] - origin))
            need(set(indices) == set(rest_gaps[index]), "attachment membership changed")
            drift = 0.0
            for vertex in indices:
                triangle, local = rest_bindings[index][vertex]
                need(triangle in target["triangles"], "attachment target topology changed")
                origin, frame = attachment_frame(target["points"], triangle)
                drift = max(drift, (g["points"][vertex] - (origin + frame @ local)).length)
            gap = max(gaps)
            row["attachments"][str(index)] = {"vertices": len(indices), "max_gap_m": gap, "max_binding_drift_m": drift,
                "max_gap_drift_m": max(abs(gap - rest_gaps[index][i]) for i, gap in zip(indices, gaps))}
            check(pose["name"] + ": attachment %d" % index, gap <= root["max_gap_fraction"] * scale and drift <= root["max_drift_fraction"] * scale)
        if pose["name"] != "neutral":
            moved = 0.0
            for name, g in geometry.items():
                need(len(g["points"]) == len(rest_points[name]), "pose changes vertex count")
                moved = max(moved, max((a - b).length for a, b in zip(g["points"], rest_points[name])))
            row["max_displacement_m"] = moved
            check(pose["name"] + ": pose deforms geometry", moved > scale * 1e-7)
        results.append(row)
    return {"checks": checks, "failures": sum(not c["passed"] for c in checks), "poses": results,
            "pose_sampling": {"authored": len(c["poses"]), "evaluated": len(samples),
                "policy": "All authored poses; complete17-law-key sets add16 midpoints and ±phase maxima at law0/.5 with weights .35/.175. Finite samples, not a continuum proof."},
            "specimen_scale_m": scale, "rig_export_metadata": metadata}


def provenance(path, before, contract):
    import bpy
    return {"blend": str(path), "blend_sha256": before, "tool": str(Path(__file__).resolve()), "tool_sha256": sha256(__file__),
            "contract_sha256": hashlib.sha256(json.dumps(contract, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest(),
            "blender": bpy.app.version_string, "blender_build": bpy.app.build_hash.decode(),
            "species_id": contract["species_id"], "species_name": contract["species_name"], "seed": contract["seed"]}


def write_report(path, report):
    path = Path(path).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, indent=2, allow_nan=False)
        handle.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--blend", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(script_arguments() if argv is None else argv)
    if args.out.exists(): parser.error("report exists; use a new evidence path")
    if args.out.resolve() == args.blend.resolve(): parser.error("report cannot replace source")
    report = {"schema": "dream_critter_anatomy_check.v1", "evidence_class": "INERT", "status": "ERROR",
              "limitations": ["Structural diagnostics, not biological/artistic acceptance.",
                  "No export or runtime round-trip parity performed.",
                  "Self-contact checks exclude triangles sharing vertices; no continuum soft-body proof.",
                  "Containment uses every evaluated vertex and surface triangle contacts with scale-relative tolerance.",
                  "Attachment drift tracks the neutral target triangle, including tangential slip; no collision-free path proof between poses."]}
    source, before = None, None
    try:
        source, before, c, objects, rig = load_source(args.blend)
        report["source"] = provenance(source, before, c)
        report.update(validate_loaded(c, objects, rig))
        report["status"] = "PASS" if report["failures"] == 0 else "FAIL"
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
    finally:
        if source is not None:
            report["source_unchanged"] = sha256(source) == before
            if not report["source_unchanged"]: report["status"] = "ERROR"
    write_report(args.out, report)
    print("[DREAM CRITTER ANATOMY]", report["status"], "report=" + str(args.out))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
