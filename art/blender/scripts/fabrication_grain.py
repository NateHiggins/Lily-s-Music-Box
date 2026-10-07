"""Orient known wood maps along slender construction stocks without moving them."""
import numpy as np
from fabrication_uvs import chart_for_triangle

TEXTURE_AXES = {'T_ai_materials_timber_albedo.png': 0,
                'T_library_furniture_walnut_albedo.png': 1}


def stock_grain_frame(vertices, albedo):
    """Return a proper rotation and texture axis; broad panels keep their recipe."""
    axis = TEXTURE_AXES.get(albedo)
    if axis is None:
        return None
    points = np.asarray(vertices, dtype=np.float64)
    _, singular, basis = np.linalg.svd(points - points.mean(axis=0), full_matrices=False)
    if singular[1] <= 0 or singular[0] / singular[1] < 3:
        return None
    length = basis[0]
    if length[np.argmax(np.abs(length))] < 0:
        length = -length
    seed = np.eye(3)[np.argmin(np.abs(length))]
    lateral = np.cross(seed, length)
    lateral /= np.linalg.norm(lateral)
    frame = np.stack((lateral, np.cross(length, lateral), length))
    assert np.allclose(frame @ frame.T, np.eye(3)) and np.linalg.det(frame) > .999999
    return frame, axis


def stock_grain_chart(points, origin, tile, frame, original_long_grain=False):
    if frame is None:
        return chart_for_triangle(points, origin, tile, original_long_grain)
    rotation, texture_axis = frame
    normal, tangent, uv, fallback = chart_for_triangle(
        points @ rotation.T, origin @ rotation.T, tile, texture_axis == 0)
    return normal @ rotation, tangent @ rotation, uv, fallback
