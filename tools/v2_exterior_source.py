"""Independent source frames and concave capsule containment for exterior proof."""
import math


def vec(value):
    if not isinstance(value, (list, tuple)) or len(value) != 3 or not all(type(v) in (int, float) and math.isfinite(v) for v in value):
        raise ValueError('finite numeric vector required')
    return tuple(float(v) for v in value)


def add(a, b): return tuple(x+y for x, y in zip(a, b))
def sub(a, b): return tuple(x-y for x, y in zip(a, b))
def mul(a, scalar): return tuple(v*scalar for v in a)
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    length = math.sqrt(dot(a, a))
    if not math.isfinite(length) or length < 1e-6: raise ValueError('nonzero finite axis required')
    return mul(a, 1/length)


IDENTITY = ((1., 0., 0.), (0., 1., 0.), (0., 0., 1.))


def polygon(value):
    if not isinstance(value, list) or len(value) < 3: raise ValueError('simple region polygon required')
    points = []
    for point in value:
        if not isinstance(point, (list, tuple)) or len(point) != 2 or not all(type(v) in (int, float) and math.isfinite(v) for v in point): raise ValueError('finite polygon vertex required')
        points.append(tuple(float(v) for v in point))
    def turn(a, b, c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    def touches(a, b, c):
        return abs(turn(a,b,c))<1e-9 and min(a[0],b[0])-1e-9<=c[0]<=max(a[0],b[0])+1e-9 and min(a[1],b[1])-1e-9<=c[1]<=max(a[1],b[1])+1e-9
    edges = list(zip(points, points[1:]+points[:1]))
    if abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in edges))<1e-9 or any(math.dist(a,b)<1e-9 for a,b in edges): raise ValueError('positive polygon area and edges required')
    for i,(a,b) in enumerate(edges):
        for j,(c,d) in enumerate(edges):
            if j<=i or j==i+1 or (i==0 and j==len(edges)-1): continue
            if turn(a,b,c)*turn(a,b,d)<0 and turn(c,d,a)*turn(c,d,b)<0 or any([touches(a,b,c),touches(a,b,d),touches(c,d,a),touches(c,d,b)]): raise ValueError('self-intersecting region boundary')
    return points


def disc_inside(boundary, point, radius):
    points = polygon(boundary)
    if type(radius) not in (int,float) or not math.isfinite(radius) or radius<=0: raise ValueError('positive finite capsule radius required')
    if not isinstance(point,(list,tuple)) or len(point)!=2 or not all(type(v) in (int,float) and math.isfinite(v) for v in point): raise ValueError('finite planar point required')
    x,y=point;inside=False;distance=float('inf')
    for a,b in zip(points,points[1:]+points[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
        dx,dy=b[0]-a[0],b[1]-a[1]
        t=max(0.,min(1.,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)))
        distance=min(distance,math.hypot(x-a[0]-t*dx,y-a[1]-t*dy))
    return inside and distance>=radius+.005


def apply(basis, point):
    return tuple(sum(basis[j][i]*point[j] for j in range(3)) for i in range(3))


def compose(a, b): return tuple(apply(a, column) for column in b)


def yaw(degrees):
    if type(degrees) not in (int, float) or not math.isfinite(degrees): raise ValueError('finite yaw required')
    a = math.radians(degrees); c, s = math.cos(a), math.sin(a)
    return ((c, 0., -s), (0., 1., 0.), (s, 0., c))


def indexed(rows):
    if not isinstance(rows, list): raise ValueError('record array required')
    result = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('id'), str) or not row['id'] or row['id'] in result: raise ValueError('unique source identity required')
        result[row['id']] = row
    return result


class ExteriorSource:
    def __init__(self, source):
        if source.get('schema_version') != 1: raise ValueError('exterior source schema required')
        frame = source['frame']
        if frame['origin_identity'] != 'ORISON_FRONT_DOOR_THRESHOLD' or frame['unit'] != 'm' or frame['outward_axis'] != '+z': raise ValueError('ruled exterior frame required')
        self.root = frame['canonical_root_instance_id']
        self.regions = indexed(source['regions'])
        self.instances = indexed(source['instances'])
        self.templates = indexed(source['surface_templates'])
        self.routes = indexed(source['routes'])
        self.thresholds = indexed(source['thresholds'])
        self.cache = {}
        root = self.instances[self.root]
        if root['owner_instance_id'] != '' or vec(root['offset_uvn_m']) != (0., 0., 0.) or root['local_yaw_degrees'] != 0: raise ValueError('canonical root must remain at ruled origin/yaw')
        for identity in self.instances:
            row = self.instances[identity]
            if row['region_id'] not in self.regions or row['template_id'] not in self.templates: raise ValueError('unresolved exterior source owner')
            self.transform(identity)

    def surface_record(self, instance, identity):
        return indexed(self.templates[self.instances[instance]['template_id']]['surfaces'])[identity]

    def transform(self, identity, visited=frozenset()):
        if identity in visited: raise ValueError('exterior ownership cycle')
        if identity in self.cache: return self.cache[identity]
        row = self.instances[identity]; offset = vec(row['offset_uvn_m']); turn = yaw(row['local_yaw_degrees'])
        owner = row['owner_instance_id']
        if not owner:
            basis, origin = turn, (offset[0], offset[2], offset[1])
        else:
            parent, base = self.transform(owner, visited | {identity})
            surface = self.surface_record(owner, row['owner_surface_id'])
            point = add(base, apply(parent, vec(surface['point_m'])))
            u, v, n = (unit(apply(parent, vec(surface[k]))) for k in ['u_axis', 'v_axis', 'normal'])
            if max(abs(dot(u, v)), abs(dot(u, n)), abs(dot(v, n))) >= .0001 or dot(cross(u, n), v) <= 0: raise ValueError('right-handed orthogonal surface frame required')
            # Independent Gram-Schmidt matches the public Basis contract.
            orthogonal_n = unit(sub(n, mul(u, dot(n, u))))
            orthogonal_v = unit(cross(u, orthogonal_n))
            basis = compose((u, orthogonal_n, orthogonal_v), turn)
            origin = add(point, add(mul(u, offset[0]), add(mul(v, offset[1]), mul(n, offset[2]))))
        self.cache[identity] = basis, origin
        return basis, origin

    def surface(self, instance, identity):
        basis, origin = self.transform(instance); row = self.surface_record(instance, identity)
        size=row['size_m']
        if not isinstance(size,list) or len(size)!=2 or not all(type(v) in (int,float) and math.isfinite(v) and v>0 for v in size):raise ValueError('positive finite source surface dimensions required')
        return dict(point=add(origin, apply(basis, vec(row['point_m']))), u_axis=unit(apply(basis, vec(row['u_axis']))), v_axis=unit(apply(basis, vec(row['v_axis']))), normal=unit(apply(basis, vec(row['normal']))), kind=row['kind'],size_m=tuple(size))

    def placement(self, instance, identity):
        row = indexed(self.templates[self.instances[instance]['template_id']]['placements'])[identity]
        surface = self.surface(instance, row['surface_id']); offset = vec(row['offset_uvn_m'])
        return add(surface['point'], add(mul(surface['u_axis'], offset[0]), add(mul(surface['v_axis'], offset[1]), mul(surface['normal'], offset[2]))))

    def interior_transform(self, layout, connection):
        if connection['instance_id'] != self.root: raise ValueError('building connection must use canonical exterior root')
        doors = indexed(layout['doors']); rooms = indexed(layout['spaces']); levels = indexed(layout['levels'])
        door = doors[connection['door_id']]; inside = rooms[connection['inside_space_id']]; outside = rooms[connection['outside_space_id']]
        if set(door['connects']) != {inside['id'], outside['id']} or inside['level'] != door['level'] or outside['level'] != door['level'] or outside.get('open_shell') is not True: raise ValueError('building connection authority mismatch')
        x, z = door['center']; y = levels[door['level']]['y']; rect = inside['rect']; threshold = vec([x, y, z]); outward = sub(threshold, ((rect[0]+rect[2])/2, y, (rect[1]+rect[3])/2))
        surface = self.surface(connection['instance_id'], connection['surface_id']); normal = surface['normal']
        if abs(normal[1]) >= .0001 or math.hypot(outward[0], outward[2]) < 1e-6: raise ValueError('horizontal nonzero building entrance required')
        basis = yaw(math.degrees(math.atan2(normal[0], normal[2])-math.atan2(outward[0], outward[2])))
        return basis, sub(surface['point'], apply(basis, threshold))
