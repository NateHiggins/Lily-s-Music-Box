"""Generate six-home bath fittings. Pure geometry; never starts an engine."""
import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
TARGET = 'game/data/orison_v2/bath_details.json'
UNITS = ['2A', '2B', '3A', '3B', '4A', '4B']


def load(path):
    return json.loads((ROOT/path).read_text(encoding='utf-8'))


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class Mesh:
    def __init__(self):
        self.surfaces = {}

    def quad(self, material, a, b, c, d):
        surface = self.surfaces.setdefault(material, dict(material=material, vertices=[], normals=[]))
        for p, q, r in [(a, b, c), (a, c, d)]:
            u, v = [[k[i]-p[i] for i in range(3)] for k in [q, r]]
            n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
            length = math.sqrt(sum(x*x for x in n))
            if length < 1e-12:
                continue
            n = [x/length for x in n]
            # Godot front faces use clockwise winding; normals face outward.
            for vertex in [p, r, q]:
                surface['vertices'].extend(vertex)
                surface['normals'].extend(n)

    def box(self, material, lo, hi):
        for axis in range(3):
            u, v = (axis+1) % 3, (axis+2) % 3
            for side in [0, 1]:
                points = []
                for a, b in [(0, 0), (1, 0), (1, 1), (0, 1)]:
                    p = [0., 0., 0.]
                    p[axis], p[u], p[v] = [lo, hi][side][axis], [lo, hi][a][u], [lo, hi][b][v]
                    points.append(p)
                self.quad(material, *(points if side else points[::-1]))

    def tube_x(self, material, x0, x1, y, z, radius, inner=0., segments=24):
        for i in range(segments):
            a, b = i*math.tau/segments, (i+1)*math.tau/segments
            def p(x, angle, r):
                return [x, y+r*math.cos(angle), z+r*math.sin(angle)]
            self.quad(material, p(x0, a, radius), p(x0, b, radius), p(x1, b, radius), p(x1, a, radius))
            if inner:
                self.quad(material, p(x1, a, inner), p(x1, b, inner), p(x0, b, inner), p(x0, a, inner))
            for x, reverse in [(x0, True), (x1, False)]:
                points = [p(x, a, inner), p(x, a, radius), p(x, b, radius), p(x, b, inner)]
                self.quad(material, *(points[::-1] if reverse else points))

    def record(self, unit, kind, support):
        surfaces = list(self.surfaces.values())
        vertices = [s['vertices'][i:i+3] for s in surfaces for i in range(0, len(s['vertices']), 3)]
        return dict(id=unit+'_'+kind, unit=unit, kind=kind, support=support,
                    position=[0, 0, 0], yaw=0,
                    bounds=[[min(v[i] for v in vertices) for i in range(3)],
                            [max(v[i] for v in vertices) for i in range(3)]], surfaces=surfaces)


def manifest():
    rows = []
    for unit in UNITS:
        sink = 'F0'+unit[0]+'_'+unit+'_SINK_01'
        m = Mesh()
        # Two screws/arms seated on the actual lavatory back (z=.1825).
        for x in [-.278, -.202]:
            m.box('chrome', [x-.006, .842, .10], [x+.006, .853, .1825])
            m.box('chrome', [x-.006, .842, .1765], [x+.006, .865, .1825])
        m.box('porcelain_fixture', [-.292, .853, .064], [-.188, .864, .166])
        for lo, hi in [([-.292,.864,.064],[-.283,.875,.166]),
                       ([-.197,.864,.064],[-.188,.875,.166]),
                       ([-.283,.864,.064],[-.197,.875,.073]),
                       ([-.283,.864,.157],[-.197,.875,.166])]:
            m.box('porcelain_fixture', lo, hi)
        # A plain bar sits inside the dish using an existing opaque finish.
        m.box('enamel', [-.275,.864,.086], [-.205,.887,.145])
        rows.append(m.record(unit, 'soap_dish', sink))
        m = Mesh()
        # Collar follows the tapered pedestal at y=.55, centred at z=.06.
        radius = .11+(.085-.11)*(.55-.08)/(.66-.17)
        for i in range(32):
            a, b = i*math.tau/32, (i+1)*math.tau/32
            p = lambda angle, y, r: [r*math.cos(angle), y, .06+r*math.sin(angle)]
            for r, reverse in [(radius, True), (radius+.004, False)]:
                q = [p(a,.539,r),p(a,.561,r),p(b,.561,r),p(b,.539,r)]
                m.quad('chrome', *(q[::-1] if reverse else q))
            for y, reverse in [(.539, True),(.561, False)]:
                q = [p(a,y,radius),p(b,y,radius),p(b,y,radius+.004),p(a,y,radius+.004)]
                m.quad('chrome', *(q[::-1] if reverse else q))
        for x in [-.045,.045]:
            contact_z = .06-math.sqrt(radius*radius-x*x)
            m.box('chrome', [x-.004,.543,-.265], [x+.004,.557,contact_z+.002])
        m.tube_x('chrome', -.14,.14,.55,-.265,.008,segments=16)
        # Thin folded linen: real pleats and a doubled hanging leaf.
        for i in range(24):
            x0, x1 = -.12+i*.01, -.12+(i+1)*.01
            z0, z1 = [-.277+.003*math.cos(x*math.tau/.04) for x in [x0,x1]]
            m.quad('linen',[x0,.560,z0],[x1,.560,z1],[x1,.245,z1],[x0,.245,z0])
            m.quad('linen',[x0,.245,z0+.003],[x1,.245,z1+.003],[x1,.560,z1+.003],[x0,.560,z0+.003])
            m.quad('linen',[x0,.245,z0+.003],[x1,.245,z1+.003],[x1,.245,z1],[x0,.245,z0])
            m.quad('linen',[x0,.560,-.255],[x1,.560,-.255],[x1,.560,z1],[x0,.560,z0])
            m.quad('linen',[x0,.29,-.255],[x1,.29,-.255],[x1,.560,-.255],[x0,.560,-.255])
            m.quad('linen',[x0,.560,-.258],[x1,.560,-.258],[x1,.29,-.258],[x0,.29,-.258])
        rows.append(m.record(unit, 'hand_towel', sink))
        m = Mesh()
        # Removable tank-lid clips: no drill hole or invented wall backing.
        for x in [-.064,.064]:
            m.box('chrome',[x-.005,.770,.114],[x+.005,.777,.26])
            m.box('chrome',[x-.005,.64,.114],[x+.005,.777,.119])
            m.box('chrome',[x-.005,.636,.035],[x+.005,.647,.119])
        m.tube_x('chrome',-.07,.07,.642,.035,.009,segments=16)
        m.tube_x('paper',-.055,.055,.642,.035,.048,inner=.014)
        m.box('paper',[-.054,.49,-.014],[.054,.64,-.012])
        rows.append(m.record(unit, 'toilet_roll', unit+'_wc'))
    return dict(schema_version=1, props=rows)


def check(data):
    geo = module('design/astra/work/v2_storage_tables_boards_batch_01/build.py', 'bath_geo')
    layout = load('game/data/orison_v2_blockout.json')
    anchors = {a['id']: a for a in layout['anchors']}
    furniture = load('game/data/orison_v2/domestic_furniture.json')['furniture']
    obstacles = geo.obstacles(layout, furniture)
    materials = load('game/data/runtime_material_sets.json')['materials']
    assert len(data['props']) == 18 and len({r['id'] for r in data['props']}) == 18
    volumes = []
    world_triangles = []
    triangles = 0
    for row in data['props']:
        assert row['position'] == [0,0,0] and row['yaw'] == 0
        a = anchors[row['support']]
        volume = geo.volume(row['bounds'], a)
        for identity, level, b in obstacles:
            if identity not in [row['support'],row['id']] and level == a['level']:
                assert not geo.overlap(volume,b), ('detail overlaps another owner',row['id'],identity)
        # Preserve the support's current footprint except the towel's 20mm hem.
        limit = [[-.33,0,-.285],[.33,1.2,.24]] if row['kind'] != 'toilet_roll' else [[-.27,0,-.4],[.27,.84,.36]]
        for axis in range(3):
            assert limit[0][axis] <= row['bounds'][0][axis] < row['bounds'][1][axis] <= limit[1][axis]
        for surface in row['surfaces']:
            assert surface['material'] in materials
            v,n = surface['vertices'],surface['normals']
            assert len(v) == len(n) and len(v) % 9 == 0 and all(math.isfinite(x) for x in v+n)
            triangles += len(v)//9
            for i in range(0,len(v),9):
                p,q,r = [v[i+j:i+j+3] for j in [0,3,6]]
                world_triangles.append((a['level'], [transform(a,t) for t in [p,q,r]]))
                u,w = [[t[k]-p[k] for k in range(3)] for t in [q,r]]
                cross = [u[1]*w[2]-u[2]*w[1],u[2]*w[0]-u[0]*w[2],u[0]*w[1]-u[1]*w[0]]
                assert sum(cross[k]*n[i+k] for k in range(3)) < -1e-12
        volumes.append((row['id'],a['level'],volume))
    routes,doors = geo.check_routes_and_doors(layout,volumes)
    rays = 0
    for unit in UNITS:
        sink = 'F0'+unit[0]+'_'+unit+'_SINK_01'
        for support,local_targets in [(sink,[[-.09,.91,.109],[.09,.91,.109]]),
                                      (unit+'_wc',[[0,.782,.235]])]:
            a = anchors[support]
            stance_id = 'F04_4B_SINK_STANCE' if support == 'F04_4B_SINK_01' else support+'_STANCE'
            stance = anchors[stance_id]['position']
            eye = [stance[0],stance[1]+1.41,stance[2]]
            for target in local_targets:
                goal = transform(a,target)
                assert not any(segment_hits(eye,goal,t) for level,t in world_triangles if level == a['level']), ('detail obscures control',support,target)
                rays += 1
    return dict(assemblies=18,homes=6,triangles=triangles,material_batches=sum(len(r['surfaces']) for r in data['props']),route_samples=routes,door_sweeps=doors,control_sightlines=rays)


def transform(anchor, p):
    c,s = math.cos(anchor['yaw']),math.sin(anchor['yaw'])
    return [anchor['position'][0]+c*p[0]+s*p[2],anchor['position'][1]+p[1],anchor['position'][2]-s*p[0]+c*p[2]]


def segment_hits(start, end, triangle):
    sub = lambda a,b: [a[i]-b[i] for i in range(3)]
    dot = lambda a,b: sum(a[i]*b[i] for i in range(3))
    cross = lambda a,b: [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    a,b,c = triangle
    direction,e1,e2 = sub(end,start),sub(b,a),sub(c,a)
    h = cross(direction,e2)
    det = dot(e1,h)
    if abs(det)<1e-12: return False
    s = sub(start,a)
    u = dot(s,h)/det
    if u<0 or u>1: return False
    q = cross(s,e1)
    v = dot(direction,q)/det
    if v<0 or u+v>1: return False
    return 0<dot(e2,q)/det<1


def build(apply=False):
    assert segment_hits([0,0,1],[0,0,-1],[[-1,-1,0],[1,-1,0],[0,1,0]])
    assert not segment_hits([2,0,1],[2,0,-1],[[-1,-1,0],[1,-1,0],[0,1,0]])
    data = manifest()
    result = check(data)
    assert data == manifest(), 'nondeterministic generation'
    # Meaningful geometry red control: put one towel in another fixture.
    bad = copy.deepcopy(data)
    bad['props'][1]['bounds'] = [[-10,0,-10],[10,2,10]]
    try:
        check(bad)
    except AssertionError:
        result['intrusive_geometry_rejected'] = True
    else:
        raise AssertionError('intrusive geometry accepted')
    encoded = (json.dumps(data,separators=(',',':'))+'\n').encode('utf-8')
    if apply:
        (ROOT/TARGET).write_bytes(encoded)
    else:
        assert (ROOT/TARGET).read_bytes() == encoded, 'bath detail manifest drift'
    result.update(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',sha256=hashlib.sha256(encoded).hexdigest())
    (OUT/'checks.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
    print(json.dumps(result))


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('--apply',action='store_true')
    build(args.parse_args().apply)
