import bpy
import glob
import json
import math
import os


def edge_key(a, b):
    return (a, b) if a < b else (b, a)


def audit_mesh(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    edge_use = {}
    directed = {}
    duplicate_faces = 0
    degenerate = 0
    slivers = 0
    diagonal = obj.dimensions
    relative_area_epsilon = max(diagonal.length_squared * 1.0e-14, 1.0e-20)
    seen_faces = set()
    for tri in mesh.loop_triangles:
        vertices = tuple(tri.vertices)
        canonical = tuple(sorted(vertices))
        if canonical in seen_faces:
            duplicate_faces += 1
        seen_faces.add(canonical)
        a, b, c = vertices
        area = ((mesh.vertices[b].co - mesh.vertices[a].co).cross(
            mesh.vertices[c].co - mesh.vertices[a].co)).length * 0.5
        if len(set(vertices)) < 3 or area == 0.0:
            degenerate += 1
        elif area < relative_area_epsilon:
            slivers += 1
        for start, end in ((a, b), (b, c), (c, a)):
            key = edge_key(start, end)
            edge_use[key] = edge_use.get(key, 0) + 1
            directed[(start, end)] = directed.get((start, end), 0) + 1
    inconsistent = 0
    for (a, b), count in edge_use.items():
        if count == 2 and (directed.get((a, b), 0) != 1 or directed.get((b, a), 0) != 1):
            inconsistent += 1
    tangents_ok = True
    try:
        if mesh.uv_layers:
            mesh.calc_tangents()
        else:
            tangents_ok = False
    except RuntimeError:
        tangents_ok = False
    return {
        "object": obj.name,
        "vertices": len(mesh.vertices),
        "triangles": len(mesh.loop_triangles),
        "boundary_edges": sum(1 for count in edge_use.values() if count == 1),
        "non_manifold_edges": sum(1 for count in edge_use.values() if count > 2),
        "inconsistent_winding_edges": inconsistent,
        "duplicate_triangles": duplicate_faces,
        "degenerate_triangles": degenerate,
        "subpixel_sliver_triangles": slivers,
        "tangents_valid": tangents_ok,
        "tangents_required": bool(mesh.uv_layers),
        "negative_transform_determinant": obj.matrix_world.to_3x3().determinant() < 0.0,
        "scale": [round(value, 6) for value in obj.scale],
    }


root = os.environ["S2_LOD_DIR"]
report = {"audit": "DREAM-SURFACE-S2I", "files": []}
for filepath in sorted(glob.glob(os.path.join(root, "*.glb"))):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=filepath)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    entry = {"file": os.path.basename(filepath), "objects": [audit_mesh(obj) for obj in meshes]}
    entry["totals"] = {
        key: sum(item[key] for item in entry["objects"])
        for key in ("vertices", "triangles", "boundary_edges", "non_manifold_edges",
                    "inconsistent_winding_edges", "duplicate_triangles", "degenerate_triangles",
                    "subpixel_sliver_triangles")
    }
    entry["all_tangents_valid"] = all(item["tangents_valid"] for item in entry["objects"])
    entry["all_transforms_positive"] = not any(item["negative_transform_determinant"] for item in entry["objects"])
    report["files"].append(entry)
with open(os.environ["S2_AUDIT_OUT"], "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
print("[S2I AUDIT] %d GLBs -> %s" % (len(report["files"]), os.environ["S2_AUDIT_OUT"]))
