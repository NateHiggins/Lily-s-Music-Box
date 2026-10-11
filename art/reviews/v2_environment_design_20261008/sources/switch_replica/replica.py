"""Independent static replica of the V2 wall finish stack around every light switch.
Usage: python -I replica.py <repo> <blockout.json> [outlet_z_centre] [out.json]
Reads only; mirrors orison_v2_blockout.gd, millwork.gd, door_casings.gd, window_joinery.gd."""
import sys, json, math, re
sys.path.insert(0, __file__.rsplit('\\', 1)[0] if '\\' in __file__ else '.')
import numpy as np
from glb import load, acc, walk

REPO = sys.argv[1]
BO = json.load(open(sys.argv[2]))
OUTLET_ZC = float(sys.argv[3]) if len(sys.argv) > 3 else -0.011
OUT = sys.argv[4] if len(sys.argv) > 4 else None
T = float(BO['dimensions']['partition_wall'])
CLEAR = float(BO['dimensions']['clear_height'])
F2F = float(BO['dimensions']['floor_to_floor'])
LY = {l['id']: float(l['y']) for l in BO['levels']}
SP = {s['id']: s for s in BO['spaces']}

def isclose(a, b): return abs(a - b) <= 1e-5 * max(1.0, abs(a), abs(b))

# ---------- meshes ----------
def mesh_tris(path, name):
    js, b = load(path)
    for i, p, M, n in walk(js):
        if n.get('name') == name:
            m = js['meshes'][n['mesh']]
            out = []
            for prim in m['primitives']:
                v = acc(js, b, prim['attributes']['POSITION'])
                idx = acc(js, b, prim['indices']).ravel()
                vw = (M @ np.c_[v, np.ones(len(v))].T).T[:, :3]
                out.append(vw[idx].reshape(-1, 3, 3))
            return np.concatenate(out)
    raise KeyError(name)
PROF = REPO + '/game/assets/props/millwork_profile.glb'
CASING = mesh_tris(PROF, 'DoorCasing')
SCASING = mesh_tris(PROF, 'ServiceCasing')
FRAME = mesh_tris(PROF, 'WainscotFrame')
WJ = mesh_tris(REPO + '/game/assets/props/window_joinery.glb', 'WindowJoinery')

def box_tris(lo, hi):
    lo = np.asarray(lo, float); hi = np.asarray(hi, float)
    c = np.array([[lo[0], lo[1], lo[2]], [hi[0], lo[1], lo[2]], [hi[0], hi[1], lo[2]], [lo[0], hi[1], lo[2]],
                  [lo[0], lo[1], hi[2]], [hi[0], lo[1], hi[2]], [hi[0], hi[1], hi[2]], [lo[0], hi[1], hi[2]]])
    f = [(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6), (0, 4, 5), (0, 5, 1), (3, 2, 6), (3, 6, 7), (0, 3, 7), (0, 7, 4), (1, 5, 6), (1, 6, 2)]
    return c[np.array(f)]

def roty(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rotz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def xform(tris, B, o):
    return tris @ B.T + o

# ---------- generated spans ----------
gen = open(REPO + '/game/scripts/generated/v2_exterior_masonry.gd').read()
def spans(name):
    blk = gen.split('const ' + name + ' := {')[1].split('}')[0]
    return {k: (float(a), float(b)) for k, a, b in re.findall(r'"(\w+)": Vector2\(([-\d.]+),([-\d.]+)\)', blk)}
WSPANS = spans('WINDOW_SPANS'); DSPANS = spans('DOOR_SPANS')

# ---------- elements: list of (kind, owner, tris) ----------
ELEM = []
BOXES = []
def add(kind, owner, tris):
    t = np.asarray(tris, float); ELEM.append((kind, owner, t))
    if kind in ('wall','skin','wainscot','riser','fixture','reveal') and len(t) == 12:
        BOXES.append((kind, owner, t.reshape(-1,3).min(0), t.reshape(-1,3).max(0)))

def subtract(box, cut):
    (blo, bhi), (clo, chi) = box, cut
    if any(bhi[i] <= clo[i] or chi[i] <= blo[i] for i in range(3)): return [box]
    olo = [max(blo[i], clo[i]) for i in range(3)]; ohi = [min(bhi[i], chi[i]) for i in range(3)]
    res = []; mlo = list(blo); mhi = list(bhi)
    for ax in range(3):
        if olo[ax] - mlo[ax] > 1e-5:
            lo = list(mlo); hi = list(mhi); hi[ax] = olo[ax]; res.append((lo, hi))
        if mhi[ax] - ohi[ax] > 1e-5:
            lo = list(mlo); hi = list(mhi); lo[ax] = ohi[ax]; res.append((lo, hi))
        mlo[ax] = olo[ax]; mhi[ax] = ohi[ax]
    return res

WALLS = []  # dicts: space,label,axis,fixed,start,finish,y,h,pieces,intact
def wall_segment(space, name, axis, fixed, start, finish, y, h):
    c = (start + finish) / 2
    if axis == 'x': lo = [start, y, fixed - T / 2]; hi = [finish, y + h, fixed + T / 2]
    else: lo = [fixed - T / 2, y, start]; hi = [fixed + T / 2, y + h, finish]
    pieces = [(lo, hi)]
    for op in BO.get('wall_service_openings', []):
        if op['space'] != space['id'] or not name.startswith('Wall' + op['side'].capitalize()): continue
        b = op['bounds']; cut = ([b[0], b[1], b[2]], [b[3], b[4], b[5]])
        np_ = []
        for p in pieces: np_ += subtract(p, cut)
        pieces = np_
    intact = len(pieces) == 1 and pieces[0] == (lo, hi)
    WALLS.append(dict(space=space['id'], name=name, axis=axis, fixed=fixed, at=[(lo[i] + hi[i]) / 2 for i in range(3)],
                      size=[hi[i] - lo[i] for i in range(3)], pieces=pieces, intact=intact, cls=space.get('class', 'unresolved')))
    for p in pieces: add('wall', space['id'] + '/' + name, box_tris(*p))
    far_face_skin(space, name, axis, fixed, (lo, hi), pieces)

def far_face_skin(owner, name, axis, fixed, bounds, pieces):
    r = owner['rect']; cls = owner.get('class', 'unresolved')
    cf = (r[1] + r[3]) / 2 if axis == 'x' else (r[0] + r[2]) / 2
    outward = 1.0 if fixed > cf else -1.0
    lo, hi = bounds
    start = lo[0] if axis == 'x' else lo[2]; finish = hi[0] if axis == 'x' else hi[2]
    neighbour = ''; wet = []
    for s in BO['spaces']:
        if s['level'] != owner['level'] or s['id'] == owner['id']: continue
        q = s['rect']
        edge = (q[1] if outward > 0 else q[3]) if axis == 'x' else (q[0] if outward > 0 else q[2])
        if not isclose(edge, fixed): continue
        a = q[0] if axis == 'x' else q[1]; b = q[2] if axis == 'x' else q[3]
        if b <= start + .05 or a >= finish - .05: continue
        found = s.get('class', 'private')
        if not neighbour: neighbour = found
        if found == 'wet': wet.append((max(a, start), min(b, finish)))
    if not neighbour: return
    if cls == 'wet':
        if neighbour == cls: return
    else:
        if not wet: return
    shift = outward * (T / 2 + .002)
    spans_ = wet if cls != 'wet' else [(-1e9, 1e9)]
    for p in pieces:
        for s0, s1 in spans_:
            plo = list(p[0]); phi = list(p[1])
            ax = 0 if axis == 'x' else 2
            c0 = max(plo[ax], s0); c1 = min(phi[ax], s1)
            if cls != 'wet':
                if c1 - c0 < .01: continue
                plo[ax] = c0; phi[ax] = c1
            n = 2 if axis == 'x' else 0
            plo[n] = fixed + shift - .002; phi[n] = fixed + shift + .002
            add('skin', owner['id'] + '/' + name + '_FarSkin', box_tris(plo, phi))

def wall_with_openings(space, label, axis, fixed, start, finish, y, h):
    ops = []
    for d in BO['doors']:
        if space['id'] not in d['connects']: continue
        on = isclose(d['center'][1], fixed) if axis == 'x' else isclose(d['center'][0], fixed)
        if on: ops.append(dict(c=d['center'][0] if axis == 'x' else d['center'][1], w=d['width'], h=d['height'], sill=0.0))
    omitted = set()
    for o in BO.get('openings', []):
        if space['id'] not in o['connects'] or o['axis'] != axis: continue
        if 'shared_wall_owner' in o and o['shared_wall_owner'] != space['id']:
            om = shared_omission(o, space, axis, fixed)
            if om:
                k = (axis, round(om['c'], 4), round(om['w'], 4))
                if k not in omitted: ops.append(om); omitted.add(k)
            continue
        fv = o['center'][1] if axis == 'x' else o['center'][0]
        if isclose(fv, fixed): ops.append(dict(c=o['center'][0] if axis == 'x' else o['center'][1], w=o['width'], h=o['height'], sill=o.get('sill', 0.0)))
    for wdw in BO.get('windows', []):
        if wdw['space'] != space['id'] or wdw['axis'] != axis: continue
        fv = wdw['center'][1] if axis == 'x' else wdw['center'][0]
        if isclose(fv, fixed): ops.append(dict(c=wdw['center'][0] if axis == 'x' else wdw['center'][1], w=wdw['width'], h=wdw['height'], sill=wdw['sill']))
    ops.sort(key=lambda o: o['c'])
    cur = start; part = 0
    for o in ops:
        lo = max(start, o['c'] - o['w'] / 2); hi = min(finish, o['c'] + o['w'] / 2)
        if hi <= lo + .001: continue
        if lo > cur + .001:
            wall_segment(space, 'Wall%s_%02d' % (label, part), axis, fixed, cur, lo, y, h); part += 1
        if o['sill'] > .001:
            wall_segment(space, 'Wall%s_Sill%02d' % (label, part), axis, fixed, lo, hi, y, o['sill']); part += 1
        hb = o['sill'] + o['h']; hh = h - hb
        if hh > .001:
            wall_segment(space, 'Wall%s_Head%02d' % (label, part), axis, fixed, lo, hi, y + hb, hh); part += 1
        cur = max(cur, hi)
    if cur < finish - .001:
        wall_segment(space, 'Wall%s_%02d' % (label, part), axis, fixed, cur, finish, y, h)

def shared_boundary(a, b):
    ar, br = a['rect'], b['rect']
    zs = max(ar[1], br[1]); zf = min(ar[3], br[3])
    if zf - zs > .001 and isclose(ar[2], br[0]): return dict(axis='z', fixed=ar[2], start=zs, finish=zf)
    if zf - zs > .001 and isclose(ar[0], br[2]): return dict(axis='z', fixed=ar[0], start=zs, finish=zf)
    xs = max(ar[0], br[0]); xf = min(ar[2], br[2])
    if xf - xs > .001 and isclose(ar[3], br[1]): return dict(axis='x', fixed=ar[3], start=xs, finish=xf)
    if xf - xs > .001 and isclose(ar[1], br[3]): return dict(axis='x', fixed=ar[1], start=xs, finish=xf)
    return None
def shared_omission(o, space, axis, fixed):
    c = o['connects']
    if len(c) != 2: return None
    other = SP.get(c[1] if c[0] == space['id'] else c[0])
    if not other: return None
    b = shared_boundary(space, other)
    if not b or b['axis'] != axis or not isclose(b['fixed'], fixed): return None
    return dict(c=(b['start'] + b['finish']) / 2, w=b['finish'] - b['start'], h=CLEAR, sill=0.0)

def wall_edge(rect, side):
    return {'west': (rect[0], rect[1], rect[3]), 'east': (rect[2], rect[1], rect[3]),
            'south': (rect[1], rect[0], rect[2]), 'north': (rect[3], rect[0], rect[2])}[side]

for s in BO['spaces']:
    if s.get('open_shell'): continue
    y = LY[s['level']]; r = s['rect']
    h = F2F if s.get('no_ceiling') else CLEAR
    sides = s.get('wall_sides', ['south', 'north', 'west', 'east'])
    for side, axis, fixed, a, b in (('south', 'x', r[1], r[0], r[2]), ('north', 'x', r[3], r[0], r[2]),
                                    ('west', 'z', r[0], r[1], r[3]), ('east', 'z', r[2], r[1], r[3])):
        if side in sides: wall_with_openings(s, side.capitalize(), axis, fixed, a, b, y, h)
    for i, e in enumerate(s.get('wall_extensions', [])):
        f, _, _ = wall_edge(r, e['side'])
        wall_with_openings(s, e['side'].capitalize() + 'Extension%02d' % i, 'z' if e['side'] in ('west', 'east') else 'x', f, e['start'], e['end'], y, h)

# ---------- single-owner opening reveal frames ----------
for o in BO.get('openings', []):
    if 'shared_wall_owner' not in o: continue
    cx, cz = o['center']; y = LY[o['level']]; w = o['width']; h = o['height']; d = T + .04; rw = .09
    if o['axis'] == 'x':
        for sx in (-1, 1):
            c = [cx + sx * (w / 2 + rw / 2), y + h / 2, cz]; sz = [rw, h, d]
            add('reveal', o['id'] + ('/RevealA' if sx < 0 else '/RevealB'), box_tris([c[i] - sz[i] / 2 for i in range(3)], [c[i] + sz[i] / 2 for i in range(3)]))
        c = [cx, y + h + rw / 2, cz]; sz = [w + 2 * rw, rw, d]
    else:
        for sx in (-1, 1):
            c = [cx, y + h / 2, cz + sx * (w / 2 + rw / 2)]; sz = [d, h, rw]
            add('reveal', o['id'] + ('/RevealA' if sx < 0 else '/RevealB'), box_tris([c[i] - sz[i] / 2 for i in range(3)], [c[i] + sz[i] / 2 for i in range(3)]))
        c = [cx, y + h + rw / 2, cz]; sz = [d, rw, w + 2 * rw]
    add('reveal', o['id'] + '/RevealHead', box_tris([c[i] - sz[i] / 2 for i in range(3)], [c[i] + sz[i] / 2 for i in range(3)]))

# ---------- risers ----------
for rz in BO['risers']:
    r = rz['rect']; lo = [r[0], rz['from_y'], r[1]]; hi = [r[2], rz['to_y'], r[3]]
    pieces = [(lo, hi)]
    for op in BO.get('riser_openings', []):
        if op['riser'] != rz['id']: continue
        b = op['bounds']; np_ = []
        for p in pieces: np_ += subtract(p, ([b[0], b[1], b[2]], [b[3], b[4], b[5]]))
        pieces = np_
    if rz.get('solid', True):
        for wdw in BO['windows']:
            ax = wdw['axis'] == 'x'; fixed = wdw['center'][1 if ax else 0]
            st = r[1 if ax else 0]; fi = r[3 if ax else 2]
            if fixed < st - .001 or fixed > fi + .001: continue
            al = wdw['center'][0 if ax else 1]
            if al + wdw['width'] / 2 <= r[0 if ax else 1] or al - wdw['width'] / 2 >= r[2 if ax else 3]: continue
            low = LY[wdw['level']] + wdw['sill']
            if not (low < rz['to_y'] and low + wdw['height'] > rz['from_y']): continue
            if ax: cut = ([al - wdw['width'] / 2, low, r[1]], [al + wdw['width'] / 2, low + wdw['height'], r[3]])
            else: cut = ([r[0], low, al - wdw['width'] / 2], [r[2], low + wdw['height'], al + wdw['width'] / 2])
            np_ = []
            for p in pieces: np_ += subtract(p, cut)
            pieces = np_
    for p in pieces: add('riser', rz['id'], box_tris(*p))

# ---------- blockout fixtures ----------
for f in BO.get('fixtures', []):
    p = f['position']; s = f['size']; y = LY[f['level']]
    c = [p[0], y + p[1], p[2]]
    add('fixture', f['id'], box_tris([c[i] - s[i] / 2 for i in range(3)], [c[i] + s[i] / 2 for i in range(3)]))

# ---------- window joinery ----------
def window_span(wdw):
    ax = wdw['axis'] == 'x'; fixed = wdw['center'][1 if ax else 0]
    sp = WSPANS.get(wdw['id'], (fixed - T / 2, fixed + T / 2))
    sp = list(sp)
    for rz in BO['risers']:
        if not rz.get('solid', True): continue
        r = rz['rect']; st = r[1 if ax else 0]; fi = r[3 if ax else 2]
        if fixed < st - .001 or fixed > fi + .001: continue
        al = wdw['center'][0 if ax else 1]
        if al + wdw['width'] / 2 <= r[0 if ax else 1] or al - wdw['width'] / 2 >= r[2 if ax else 3]: continue
        low = LY[wdw['level']] + wdw['sill']
        if not (low < rz['to_y'] and low + wdw['height'] > rz['from_y']): continue
        sp[0] = min(sp[0], r[1 if ax else 0]); sp[1] = max(sp[1], r[3 if ax else 2])
    return sp
WIN_TRIS = {}
for wdw in BO['windows']:
    if wdw['id'] == 'B1_BOILER_AIR_E': continue
    sp = window_span(wdw); ax = wdw['axis'] == 'x'
    at = [wdw['center'][0], LY[wdw['level']] + wdw['sill'] + wdw['height'] / 2, wdw['center'][1]]
    at[2 if ax else 0] = (sp[0] + sp[1]) / 2
    B = roty(0.0 if ax else math.pi / 2) @ np.diag([wdw['width'], wdw['height'], (sp[1] - sp[0]) / .35])
    t = xform(WJ, B, np.array(at)); WIN_TRIS[wdw['id']] = t
    add('window', wdw['id'] + '/FittedWindowJoinery', t)

# ---------- door casings (cased kinds only) ----------
KINDS = json.load(open(__file__.rsplit('\\', 1)[0] + '\\door_kinds.json' if '\\' in __file__ else 'door_kinds.json'))
for d in BO['doors']:
    k = KINDS.get(d['id'])
    if k not in ('apartment_entry', 'apartment_interior', 'service'): continue
    w = d['width']; h = d['height']
    sp = DSPANS.get(d['id'], (-T / 2, T / 2)); depth = sp[1] - sp[0]; cen = (sp[0] + sp[1]) / 2
    P = roty(d['yaw']); O = np.array([d['center'][0], LY[d['level']], d['center'][1]])
    mesh = SCASING if k == 'service' else CASING
    parts = {'FrameLeft': ([-w / 2 - .045, h / 2, 0], [.09, h, .10]), 'FrameRight': ([w / 2 + .045, h / 2, 0], [.09, h, .10]),
             'FrameHead': ([0, h + .045, 0], [w + .18, .09, .10])}
    for part, (pos, size) in parts.items():
        fc = np.array(pos) + np.array([0, 0, cen])
        for side in (-1.0, 1.0):
            at = fc + np.array([0, 0, side * (depth / 2 + .009)])
            R = roty(0 if side > 0 else math.pi)
            dims = [size[0], size[1], .018]
            if part != 'FrameHead':
                R = R @ rotz(math.pi / 2 * side * (1 if part == 'FrameLeft' else -1))
                dims = [size[1], size[0], .018]
            Bl = R @ np.diag(dims)
            t = xform(mesh, Bl, at)            # door-local
            add('casing', d['id'] + '/DoorCasings/' + part, xform(t, P, O))

# ---------- millwork (public backing + stiles; private has nothing 0.17-2.15 m) ----------
def casing_boxes(room, floor_y):
    boxes = []
    for d in BO['doors']:
        if room['id'] not in d['connects']: continue
        w = d['width']; h = d['height']; P = roty(d['yaw']); O = np.array([d['center'][0], floor_y, d['center'][1]])
        for side in (-1.0, 1.0):
            z = side * (T / 2 + .009)
            for x in (-w / 2 - .045, w / 2 + .045):
                boxes.append(aabb_x(P, O, [x, h / 2, z], [.09, h, .018]))
            boxes.append(aabb_x(P, O, [0, h + .045, z], [w + .18, .09, .018]))
    return boxes
def aabb_x(P, O, c, s):
    c = np.array(c); s = np.array(s)
    corners = np.array([[c[0] + sx * s[0] / 2, c[1] + sy * s[1] / 2, c[2] + sz * s[2] / 2] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
    w = corners @ P.T + O
    return (w.min(0), w.max(0))
def window_boxes(room):
    out = []
    for wdw in BO['windows']:
        if wdw['space'] != room['id'] or wdw['id'] not in WIN_TRIS: continue
        for t in WIN_TRIS[wdw['id']]:
            out.append((t.min(0) - .0002, t.max(0) + .0002))
    return out
def height_bands(low, high, cas):
    edges = [low, high]
    for lo, hi in cas:
        for e in (lo[1], hi[1]):
            if low + .001 < e < high - .001: edges.append(e)
    edges.sort(); res = []; st = low
    for e in edges:
        if e - st > .001: res.append((st, e)); st = e
    return res
def clear_runs(start, finish, low, high, nlo, nhi, along_x, cas):
    runs = [(start, finish)]
    for lo, hi in cas:
        if min(high, hi[1]) - max(low, lo[1]) < .0001: continue
        back = lo[2] if along_x else lo[0]; front = hi[2] if along_x else hi[0]
        if min(nhi, front) - max(nlo, back) < .0001: continue
        left = lo[0] if along_x else lo[2]; right = hi[0] if along_x else hi[2]
        rem = []
        for a, b in runs:
            if right <= a or left >= b: rem.append((a, b))
            else:
                if left - a > .001: rem.append((a, left))
                if b - right > .001: rem.append((right, b))
        runs = rem
    return runs
MILL_PUBLIC = []
for room in BO['spaces']:
    if room.get('class') not in ('private', 'public') or room.get('open_shell'): continue
    if room.get('class') != 'public': continue
    fy = LY[room['level']]; r = room['rect']
    cas = casing_boxes(room, fy) + window_boxes(room)
    for wl in WALLS:
        if wl['space'] != room['id'] or not wl['intact']: continue
        lab = wl['name']
        if not any(lab.startswith('Wall' + s) for s in ('North', 'South', 'West', 'East')): continue
        along_x = lab.startswith('WallNorth') or lab.startswith('WallSouth')
        at = wl['at']; size = wl['size']
        wlow = at[1] - size[1] / 2; whigh = at[1] + size[1] / 2
        fixed = at[2] if along_x else at[0]
        centre = (r[1] + r[3]) / 2 if along_x else (r[0] + r[2]) / 2
        inward = math.copysign(1.0, centre - fixed) if centre != fixed else 0.0
        prof = (.743, 1.154, .016)
        plow = max(fy + prof[0] - prof[1] / 2, wlow); phigh = min(fy + prof[0] + prof[1] / 2, whigh)
        if phigh - plow < .001: continue
        for low, high in height_bands(plow, phigh, cas):
            along = at[0] if along_x else at[2]; length = size[0] if along_x else size[2]
            pad = T / 2 + (0.0 if along_x else prof[2])
            start = max(along - length / 2, r[0 if along_x else 1] + pad)
            finish = min(along + length / 2, r[2 if along_x else 3] - pad)
            if finish - start < .001: continue
            na = fixed + inward * T / 2; nb = na + inward * prof[2]
            for a, b in clear_runs(start, finish, low, high, min(na, nb), max(na, nb), along_x, cas):
                face_lo = fixed + inward * T / 2; face_hi = face_lo + inward * prof[2]
                n0, n1 = min(face_lo, face_hi), max(face_lo, face_hi)
                if along_x: lo = [a, low, n0]; hi = [b, high, n1]
                else: lo = [n0, low, a]; hi = [n1, high, b]
                add('wainscot', room['id'] + '/PublicWainscot<' + lab + '>', box_tris(lo, hi))
                MILL_PUBLIC.append((room['id'], lab, a, b, low, high))
                sl = max(fy + .226, low); sh = min(fy + 1.240, high)
                if sh - sl < .001 or b - a < .15: continue
                count = max(1, math.ceil((finish - start) / .72))
                for i in range(count + 1):
                    al = (start + .038) + ((finish - .038) - (start + .038)) * i / count
                    if al - .018 < a or al + .018 > b: continue
                    sf = fixed + inward * (T + .036) / 2
                    pos = np.array([al, (sl + sh) / 2, sf]) if along_x else np.array([sf, (sl + sh) / 2, al])
                    ang = (0.0 if inward > 0 else math.pi) if along_x else (math.pi / 2 if inward > 0 else -math.pi / 2)
                    Bs = roty(ang) @ rotz(math.pi / 2) @ np.diag([sh - sl, .036, .036])
                    add('stile', room['id'] + '/PublicWainscotFrames<' + lab + '>', xform(FRAME, Bs, pos))

# ---------- ray casting ----------
ALL = [(k, o, t) for k, o, t in ELEM]
BBOX = [(t.reshape(-1, 3).min(0), t.reshape(-1, 3).max(0)) for _, _, t in ALL]
def raycast(origins, d, cand):
    """origins (N,3), d (3,) -> nearest t (N,), owner index"""
    best = np.full(len(origins), np.inf); who = np.full(len(origins), -1)
    for ci in cand:
        tris = ALL[ci][2]
        a = tris[:, 0]; e1 = tris[:, 1] - a; e2 = tris[:, 2] - a
        h = np.cross(d, e2); det = (e1 * h).sum(1)
        ok = np.abs(det) > 1e-14
        if not ok.any(): continue
        a, e1, e2, h, det = a[ok], e1[ok], e2[ok], h[ok], det[ok]
        f = 1 / det
        s = origins[:, None, :] - a[None]
        u = f[None] * (s * h[None]).sum(2)
        q = np.cross(s, e1[None])
        v = f[None] * (q * d).sum(2)
        t = f[None] * (q * e2[None]).sum(2)
        hit = (u >= -1e-7) & (u <= 1 + 1e-7) & (v >= -1e-7) & (u + v <= 1 + 1e-7) & (t > 0)
        t = np.where(hit, t, np.inf).min(1)
        better = t < best
        best[better] = t[better]; who[better] = ci
    return best, who

rl = json.load(open(REPO + '/game/data/orison_v2/room_lighting.json'))
ci = json.load(open(REPO + '/game/data/orison_v2/completion_interiors.json'))
recs = [dict(s, src='room_lighting') for s in rl['switches']] + [dict(s, src='completion') for s in ci['lighting']['switches']]
A = {a['id']: a for a in BO['anchors']}
import os
OV = json.load(open(os.environ['OVERRIDES'])) if os.environ.get('OVERRIDES') else {}
for k, v in OV.items():
    A[k] = dict(A[k]); A[k]['position'] = v['position']; A[k]['yaw'] = v.get('yaw', A[k].get('yaw', 0.0))
results = []
START = 0.20
for rec in recs:
    an = A[rec['id']]; yaw = float(an.get('yaw', 0.0))
    O = np.array([an['position'][0], LY[an['level']] + an['position'][1], an['position'][2]])
    dz = np.array([math.sin(yaw), 0, math.cos(yaw)]); dx = np.array([math.cos(yaw), 0, -math.sin(yaw)]); dy = np.array([0, 1.0, 0])
    room = SP[rec['room']]; r = room['rect']
    cen = np.array([(r[0] + r[2]) / 2, 0, (r[1] + r[3]) / 2])
    R = O + dx * .115; L = O - dx * .115
    side = 1.0 if np.hypot(*(R - cen)[[0, 2]]) <= np.hypot(*(L - cen)[[0, 2]]) else -1.0
    cand = [i for i, (lo, hi) in enumerate(BBOX) if np.all(lo <= O + .7) and np.all(hi >= O - .7)]
    bx = [b for b in BOXES if np.all(b[2] <= O + .7) and np.all(b[3] >= O - .7)]
    def grid(cx, hw, hh, nx, ny, zr):
        pts = []; lat = []
        for gx in np.linspace(-hw, hw, nx):
            for gy in np.linspace(-hh, hh, ny):
                pts.append(O + dx * (cx + gx) + dy * gy + dz * (zr - START)); lat.append((cx + gx, gy))
        return np.array(pts), lat
    out = {}
    for nm, cx, hw, hh, zr in (('plate', 0.0, .058, .088, -.008), ('rim', 0.0, .06, .09, -.009), ('outlet', side * .115, .035, .0575, OUTLET_ZC + .003), ('outlet_other', -side * .115, .035, .0575, OUTLET_ZC + .003), ('wide', 0.0, .30, .09, -.008)):
        nx = int(round(2*hw/0.001)) + 1
        ny = 3 if nm == 'wide' else 7
        pts, lat = grid(cx, hw, hh, nx, ny, zr)
        t, who = raycast(pts, dz, cand)
        gap = t - START  # + = standing off, - = sunk (surface in front of rear plane)
        owners = [ALL[w][1] if w >= 0 else None for w in who]
        kinds = [ALL[w][0] if w >= 0 else None for w in who]
        mid = pts + dz * (START - .011)   # 3 mm in front of the rear face, inside the plate body
        emb = []
        for pnt in mid:
            hit = ''
            for k, ow, lo, hi in bx:
                if np.all(pnt > lo + 1e-6) and np.all(pnt < hi - 1e-6): hit = k + ':' + ow; break
            emb.append(hit)
        out[nm] = dict(gap=gap.tolist(), lat=lat, owners=owners, kinds=kinds, emb=emb)
    results.append(dict(id=rec['id'], room=rec['room'], src=rec['src'], pos=an['position'], level=an['level'], yaw=yaw, side=side, data=out))

def summ(o):
    g = np.array(o['gap']); fin = np.isfinite(g)
    return (float(np.min(g[fin])) if fin.any() else None, float(np.max(g[fin])) if fin.any() else None, int((~fin).sum()))
rows = []
for r_ in results:
    p = summ(r_['data']['plate']); q = summ(r_['data']['outlet']); m = summ(r_['data']['rim'])
    kinds = sorted(set(k for k in r_['data']['plate']['kinds'] if k))
    okinds = sorted(set(k for k in r_['data']['outlet']['kinds'] if k))
    rows.append((r_['id'], r_['src'], r_['pos'], round(r_['yaw'], 4), p, m, q, kinds, okinds, r_['side']))
if OUT:
    json.dump(dict(results=results), open(OUT, 'w'))
for row in rows:
    print(json.dumps(row))
