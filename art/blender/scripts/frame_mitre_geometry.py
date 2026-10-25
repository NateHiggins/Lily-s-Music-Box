"""Shared closed 45-degree door-frame stock, in Blender's Z-up coordinates.

The opening stays clear_width x clear_height. All three members occupy the
same union as the former square jambs and full-width header. Only their
interface changes: both corners share a diagonal through the whole depth.
"""

def frame_parts(clear_width, clear_height, board_width, depth, head_width=None):
    if min(clear_width, clear_height, board_width, depth) <= 0:
        raise ValueError('Frame dimensions must be positive')
    half = clear_width / 2
    top = clear_height
    t = board_width
    head_width = t if head_width is None else head_width
    if head_width < t:
        raise ValueError('A taller head must retain the complete 45-degree cap')
    polygons = {
        'left': [(-half-t, 0), (-half, 0), (-half, top), (-half-t, top+t)],
        'right': [(half, 0), (half+t, 0), (half+t, top+t), (half, top)],
        'head': [(-half, top), (half, top), (half+t, top+t), (-half-t, top+t)],
    }
    if head_width > t:
        # A deep storefront/lift head can be taller than its jambs. Keep its
        # original outer envelope and the same 45-degree lower joint; the
        # extra height stays wholly in the head, not in overlapping jambs.
        polygons['head'] = [(-half,top),(half,top),(half+t,top+t),
                            (half+t,top+head_width),(-half-t,top+head_width),
                            (-half-t,top+t)]
    result = {}
    for name, polygon in polygons.items():
        count = len(polygon)
        faces = [tuple(reversed(range(count))),tuple(range(count,count*2))]
        faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
        result[name] = {'vertices': [(x,y,height) for y in [-depth/2,depth/2]
                                     for x,height in polygon], 'faces': faces}
    return result


def interface_points(parts):
    """Actual cap corners, for independent native/imported seam checks."""
    result = {}
    for name, side_indices, head_indices in [
            ('left', [2, 3, 6, 7], [0, 3, 4, 7]),
            ('right', [2, 3, 6, 7], [1, 2, 5, 6])]:
        side = sorted(parts[name]['vertices'][i] for i in side_indices)
        head = sorted(p for p in parts['head']['vertices'] if p in side)
        if side != head:
            raise ValueError('Miter cap vertices do not meet: ' + name)
        dx = max(p[0] for p in side) - min(p[0] for p in side)
        dz = max(p[2] for p in side) - min(p[2] for p in side)
        if abs(dx-dz) > 1e-12:
            raise ValueError('Miter must be 45 degrees: ' + name)
        result[name] = side
    return result
