"""Export the service instruments from their editable stock, including the ledger refit."""

import argparse
import ast
from pathlib import Path
import sys

import bpy
import io_scene_gltf2
from io_scene_gltf2.io.com.constants import BufferViewTarget
from io_scene_gltf2.io.exp.binary_data import BinaryData
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_exported_tangents import validate


def corner(point):
    return (point.x, point.z, -point.y)


def final_rule_charts(stocks):
    result = {}
    for stock in stocks:
        indices = stock.get("signed_metric_repair_faces")
        if indices is None:
            continue
        mesh = stock.data
        uv_layer = mesh.uv_layers.active.data
        charts = {}
        for index in indices:
            face = mesh.polygons[index]
            points = [corner(mesh.vertices[vertex].co) for vertex in face.vertices]
            uv = [(uv_layer[loop].uv.x, -uv_layer[loop].uv.y) for loop in face.loop_indices]
            for start in range(3):
                charts[tuple(points[start:] + points[:start])] = uv[start:] + uv[:start]
        result[mesh.name] = charts
    expected = {f"M04_P{index:03d}" for index in range(34, 39)}
    if set(result) != expected or any(len(charts) != 30 for charts in result.values()):
        raise ValueError("Expected ten signed-chart repair faces on each of the five rules")
    return result


def export_instruments(output):
    recipe = Path(__file__).with_name("build_service_instruments.py")
    source = ast.parse(recipe.read_text(encoding="utf-8"))
    stock_hook = next(node for node in source.body if isinstance(node, ast.ClassDef)
                      and node.name == "ExportUVHandedness")
    namespace = {"np": np}
    exec(compile(ast.Module(body=[stock_hook], type_ignores=[]), str(recipe), "exec"),
         namespace)
    collection = bpy.data.collections["Runtime partitions"]
    collection.hide_viewport = False
    bpy.context.view_layer.update()
    charts = final_rule_charts(collection.objects)
    repaired = 0
    errors = []

    class RegisterExport(namespace["ExportUVHandedness"]):
        def gather_mesh_hook(self, mesh, *args):
            nonlocal repaired
            try:
                super().gather_mesh_hook(mesh, *args)
                if mesh.name in charts:
                    for primitive in mesh.primitives:
                        repaired += repair_rule(primitive, charts[mesh.name])
            except Exception as exc:
                errors.append((mesh.name, exc))
                raise

    io_scene_gltf2.glTF2ExportUserExtension = RegisterExport
    bpy.ops.object.select_all(action="DESELECT")
    for stock in collection.objects:
        stock.hide_set(False)
        stock.select_set(True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_yup=True, export_tangents=True, export_attributes=True,
        export_materials="PLACEHOLDER", export_animations=False)
    if "FINISHED" not in result or errors or repaired != 50:
        raise RuntimeError(f"Expected fifty repaired triangles, got {repaired}: {errors}")
    print(validate(output))


def repair_rule(primitive, charts):
    attributes = primitive.attributes

    def read(name, width):
        return np.frombuffer(attributes[name].buffer_view.data, dtype="<f4").reshape(-1, width)

    position = read("POSITION", 3)
    normal = read("NORMAL", 3)
    uv = read("TEXCOORD_0", 2).copy()
    tangent = read("TANGENT", 4).copy()
    index = primitive.indices
    triangles = np.frombuffer(
        index.buffer_view.data, dtype={5121: "u1", 5123: "<u2", 5125: "<u4"}[index.component_type]
    ).reshape(-1, 3)
    # Charted corners must never share a vertex with an unaffected triangle.
    use_count = np.bincount(triangles.flatten(), minlength=len(position))
    repaired = 0
    for triangle in triangles:
        points = position[triangle].astype(float)
        chart = charts.get(tuple(tuple(point) for point in points))
        if chart is None:
            continue
        if np.any(use_count[triangle] != 1):
            raise ValueError("Rule refit requires independent triangle corners")
        tex = np.asarray(chart, dtype=float)
        duv = tex[1:] - tex[0]
        det = np.linalg.det(duv)
        a, b = points[1:] - points[0]
        du = (a * duv[1, 1] - b * duv[0, 1]) / det
        dv = (b * duv[0, 0] - a * duv[1, 0]) / det
        n = normal[triangle].astype(float)
        n /= np.linalg.norm(n, axis=1)[:, None]
        t = du - n * np.sum(du * n, axis=1)[:, None]
        t /= np.linalg.norm(t, axis=1)[:, None]
        handed = np.sign(np.sum(np.cross(n, t) * dv, axis=1))
        uv[triangle] = tex
        tangent[triangle] = np.column_stack((t, handed))
        repaired += 1
    attributes["TEXCOORD_0"].buffer_view = BinaryData(uv.tobytes(), BufferViewTarget.ARRAY_BUFFER)
    attributes["TANGENT"].buffer_view = BinaryData(tangent.tobytes(), BufferViewTarget.ARRAY_BUFFER)
    return repaired


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    export_instruments(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output.resolve())
