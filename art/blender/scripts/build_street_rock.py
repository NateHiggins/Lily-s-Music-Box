"""Build the original street stone mesh. Run Blender in background with -- <output.glb>."""
import random
import sys
from pathlib import Path

import bpy
import io_scene_gltf2

output = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1)
rock = bpy.context.object
rock.name = "StreetStone"
mesh = rock.data
rng = random.Random(1929)
for vertex in mesh.vertices:
    p = vertex.co.copy()
    uneven = rng.uniform(0.86, 1.13)
    vertex.co = (
        p.x * 0.064 * uneven + 0.012 * p.z,
        p.y * 0.051 * uneven - 0.007 * p.x,
        max(-0.031, p.z * 0.042 * uneven) + 0.006 * p.x,
    )

# Per-face metric charts keep the seam away from the lighting calculation.
uv = mesh.uv_layers.active or mesh.uv_layers.new(name="StoneUV")
mesh.update()
for face in mesh.polygons:
    a, b, _ = (mesh.vertices[i].co for i in face.vertices)
    u = (b - a).normalized()
    v = face.normal.cross(u).normalized()
    offset_u = rng.random()
    offset_v = rng.random()
    for loop in face.loop_indices:
        p = mesh.vertices[mesh.loops[loop].vertex_index].co
        uv.data[loop].uv = (offset_u + p.dot(u), offset_v + p.dot(v))
    face.use_smooth = False

material = bpy.data.materials.new("limestone")
rock.data.materials.append(material)
# The bundled exporter flips V and retains Blender's bitangent sign.
class ExportUVHandedness:
    def gather_attribute_change(self, attribute, data, normalized, export_settings):
        if attribute == "TANGENT":
            data["data"][:, 3] *= -1


io_scene_gltf2.glTF2ExportUserExtension = ExportUVHandedness
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(output), export_format="GLB", export_tangents=True, export_materials="EXPORT"
)
