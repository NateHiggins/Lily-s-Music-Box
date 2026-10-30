"""Closed source-fitted commercial fronts; called by build_city_elevations.py.

Germania, Robbins & Appleton and Scheffel are explicit architectural adaptations.
The caller retains registration, physical roof bearings, materials and collision.
No gameplay, access, clock or save authority is created here.
"""
import bisect,math,re
import bpy,bmesh
from mathutils import Vector,Matrix

class CommercialFronts:
    def __init__(self, profiles, records, original, rings, helpers, detail_level=0):
        assert detail_level in [0,1]
        self.profile_steps = [12,6][detail_level]
        self.crown_steps = [16,8][detail_level]
        self.oculus_steps = [24,12][detail_level]
        self.scroll_steps = [36,12][detail_level]
        self.plans = profiles
        self.records = records
        self.original = original
        self.rings = rings
        for name, function in helpers.items():
            setattr(self, name, function)
        self.window_samples = []
        self.window_rows = []
        self.portal_rows = []
        self.copied_stock_diagnostics = []
        self.building_rows = []
        self.specs = {}
        for name, profile in profiles.items():
            architecture = profile.get('architecture', {})
            if architecture.get('type') != 'commercial_front':
                continue
            heights = profile['floor_heights'][:architecture['front_floor_count']]
            self.specs[name] = dict(style=architecture['style'], wall=profile['wall_key'],
                tint=profile['wall_tint'], front_heights=heights, widths=[profile['window_width']],
                front_bays=architecture['front_bays'], eave=sum(heights),
                roof_depth=architecture['roof_depth_m'])

    def local_box(self, name, key, origin, tangent, out, lo, hi):
        x, y, z = lo
        X, Y, Z = hi
        assert X > x and Y > y and (Z > z), (name, key, lo, hi)
        vv = [tuple(origin + tangent * a + out * b + Vector((0, 0, c))) for a, b, c in [(x, y, z), (X, y, z), (X, Y, z), (x, Y, z), (x, y, Z), (X, y, Z), (X, Y, Z), (x, Y, Z)]]
        ff = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        if tangent.cross(out).z < 0:
            ff = [tuple(reversed(f)) for f in ff]
        self.add(name, key, vv, ff)

    def original_stock(self, name, key, obj, cut_y=None):
        mesh = obj.data.copy()
        mesh.transform(obj.matrix_world)
        if cut_y is not None:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-07, plane_co=(0, cut_y, 0), plane_no=(0, 1, 0), clear_inner=True)
            boundary = [e for e in bm.edges if e.is_boundary]
            if boundary:
                bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(mesh)
            bm.free()
            assert min((v.co.y for v in mesh.vertices)) >= cut_y - 1e-06
        vv = [tuple(v.co) for v in mesh.vertices]
        ff = [tuple(p.vertices) for p in mesh.polygons]
        self.copied_stock_diagnostics.append({'building': name, 'source': obj.name, 'cut_y': cut_y, 'bounds': [min((v[i] for v in vv)) for i in range(3)] + [max((v[i] for v in vv)) for i in range(3)], 'faces': len(ff)})
        self.add(name, key, vv, ff)
        bpy.data.meshes.remove(mesh)

    def record_window(self, name, origin, u, out, left, right, low, high, probe_height, bay):
        # A real pane sample stays clear of paired mullions and transom bars.
        actual = origin + u * ((left + right) / 2 + (right-left)*.22) + out * (-.419) + Vector((0, 0, probe_height))
        nominal = actual + out * .219
        side = 0 if out.y < -.5 else 2 if out.y > .5 else 1 if out.x > 0 else 3
        levels = [0.]
        for height in self.specs[name]['front_heights']:
            levels.append(levels[-1] + height)
        floor = max(0, bisect.bisect_right(levels, low) - 1)
        self.window_samples.append(dict(building=name,point=list(actual),normal=list(out),finish='mirror_aged'))
        self.window_rows.append(dict(building=name,side=side,floor=floor,bay=bay,
            center=list(origin + u * ((left + right) / 2) + out * (-.20) + Vector((0, 0, (low + high) / 2))),
            width=right-left,height=high-low,recess_m=.175,pane_sample=list(nominal)))

    def opening(self, name, wall, origin, u, out, left, right, z0, z1, low, high, shape='rect', door=False, trim='limestone', wall_fill=True, bay=0):
        """A genuine pierced wall, deep jambs, closed pane/door and attached joinery."""
        back, front = (-0.48, -0.2)
        if wall_fill:
            self.local_box(name, wall, origin, u, out, (left, back, z0), (right, front, low))
        if shape == 'segment':
            rise = 0.23
            spring = high - rise
            top = [((left + right) / 2 - (right - left) / 2 * math.cos(i * math.pi / self.profile_steps), spring + rise * math.sin(i * math.pi / self.profile_steps)) for i in range(self.profile_steps+1)]
        elif shape == 'shoulder':
            spring = high - 0.25
            top = [(left, spring)] + [(left + 0.15 + (right - left - 0.3) * i / self.profile_steps, high - 0.12 + 0.12 * math.sin(i * math.pi / self.profile_steps)) for i in range(self.profile_steps+1)] + [(right, spring)]
        else:
            spring = high
            top = [(left, high), (right, high)]
        if wall_fill:
            self.profile_stock(name, wall, origin, u, out, top + [(right, z1), (left, z1)], back, front)
        poly = [(left, low), (right, low)] + list(reversed(top))
        key = 'door_paint' if door else 'mirror_aged'
        if door:
            rail = min(low + 2.35, high - 0.38)
            self.local_box(name, key, origin, u, out, (left, -0.47, low), (right, -0.38, rail))
            self.local_box(name, key, origin, u, out, (left, -0.44, rail), (right, -0.31, rail + 0.08))
            self.profile_stock(name, 'mirror_aged', origin, u, out, [(left, rail + 0.08), (right, rail + 0.08)] + list(reversed(top)), -0.425, -0.419)
            self.record_window(name,origin,u,out,left,right,rail+.08,high,(rail+.08+high)/2,bay)
            side=0 if out.y<-.5 else 2 if out.y>.5 else 1 if out.x>0 else 3
            self.portal_rows.append(dict(building=name,side=side,
                point=list(origin+u*(left+.08)+out*(-.20)+Vector((0,0,low+1.2))),front=-.18))
            for a, b in [(left + 0.12, (left + right) / 2 - 0.035), ((left + right) / 2 + 0.035, right - 0.12)]:
                self.local_box(name, key, origin, u, out, (a, -0.4, low + 0.18), (b, -0.35, rail - 0.16))
                for lo, hi in [(low + 0.18, low + 0.22), (rail - 0.2, rail - 0.16)]:
                    self.local_box(name, key, origin, u, out, (a - 0.015, -0.37, lo), (b + 0.015, -0.32, hi))
            handle_x = right - 0.12
            for z in [low + 1.0, low + 1.17]:
                self.local_box(name, key, origin, u, out, (handle_x - 0.025, -0.38, z), (handle_x + 0.025, -0.29, z + 0.035))
            self.local_box(name, key, origin, u, out, (handle_x - 0.018, -0.31, low + 1.015), (handle_x + 0.018, -0.25, low + 1.19))
        else:
            self.profile_stock(name, key, origin, u, out, poly, -0.425, -0.419)
            # Closed dark recess; a timber-coloured sheet reads as boarded glazing.
            self.profile_stock(name, 'wood_dark', origin, u, out, poly, -0.49, -0.47)
            pattern=bay+int(round(low*7))+int(abs(origin.x)*3)
            if low>.3 and (pattern%5==0 if name=='site_nw3' else pattern%5!=0):
                drop=[.32,.55,.78][pattern%3]
                shade_top=spring-.04
                shade_bottom=max(low+.08,shade_top-(spring-low)*drop)
                self.local_box(name,'linen',origin,u,out,(left+.035,-.466,shade_bottom),(right-.035,-.458,shade_top))
            self.record_window(name,origin,u,out,left,right,low,high,(low+spring)/2+.15,bay)
        for x in [left, right - 0.055]:
            self.local_box(name, 'door_paint', origin, u, out, (x, -0.42, low), (x + 0.055, -0.32, spring))
        for z in [low, low + (spring - low) * 0.52]:
            self.local_box(name, 'door_paint', origin, u, out, (left, -0.42, z), (right, -0.32, z + 0.055))
        if shape == 'segment':
            self.arch_stock(name, trim, origin, u, out, (left + right) / 2, spring, (right - left) / 2, 0.23, 0.12, -0.26, -0.04, self.profile_steps)
        else:
            for a, b in zip(top, top[1:]):
                direction = Vector((b[0] - a[0], b[1] - a[1]))
                normal = Vector((-direction.y, direction.x)).normalized() * 0.09
                self.profile_stock(name, trim, origin, u, out, [a, b, (b[0] + normal.x, b[1] + normal.y), (a[0] + normal.x, a[1] + normal.y)], -0.28, -0.05)
        for x in [left - 0.12, right]:
            self.local_box(name, trim, origin, u, out, (x, -0.28, low - 0.06), (x + 0.12, -0.05, spring))
        self.local_box(name, 'limestone' if wall == 'arcade_brick_bond' else trim, origin, u, out, (left - 0.16, -0.3, low - 0.12), (right + 0.16, -0.02, low))

    def register(self, name, wall, origin, u, out, width, z0, z1, bays, opening_width, shape='rect', ground=False, trim='limestone', attic=False):
        pitch = width / bays
        for bay in range(bays):
            center = (bay + 0.5) * pitch
            left = center - opening_width / 2
            right = center + opening_width / 2
            low = z0 + (0.18 if ground or attic else 0.64)
            high = z1 - 0.52
            self.local_box(name, wall, origin, u, out, (bay * pitch, -0.48, z0), (left, -0.2, z1))
            self.local_box(name, wall, origin, u, out, (right, -0.48, z0), ((bay + 1) * pitch, -0.2, z1))
            self.opening(name, wall, origin, u, out, left, right, z0, z1, low, high, shape, ground and bay == 0, trim, bay=bay)
            if ground and bay > 0:
                rail = low + 2.35
                self.local_box(name, 'door_paint', origin, u, out, (left, -0.42, rail), (right, -0.3, rail + 0.07))
                for i in [1, 2]:
                    at = left + (right - left) * i / 3
                    self.local_box(name, 'door_paint', origin, u, out, (at - 0.025, -0.42, rail + 0.07), (at + 0.025, -0.32, high))

    def cornice(self, name, origin, u, out, width, z, key='limestone', depth=0.16):
        for low, high, front in [(z - 0.18, z - 0.09, -0.12), (z - 0.09, z + 0.015, -0.045), (z + 0.015, z + 0.1, 0.0)]:
            self.local_box(name, key, origin, u, out, (0.02, -0.48, low), (width - 0.02, front, high))

    def dormer(self, name, origin, width, bottom, shoulder, peak, rear_y, rear_z, style='rect', bays=1):
        """Opening, closed cheek stocks, a two-sided roof and seated rear return."""
        u = Vector((1, 0, 0))
        out = Vector((0, -1, 0))
        wall = self.specs[name]['wall']
        self.register(name, wall, origin, u, out, width, bottom, shoulder, bays, width / bays - 0.38, style, False, 'door_paint', True)
        self.profile_stock(name, 'door_paint', origin, u, out, [(0, shoulder), (width, shoulder), (width / 2, peak)], -0.45, -0.12)
        y0 = origin.y + 0.2
        depth = rear_y - y0
        for x, sign in [(origin.x, -1), (origin.x + width, 1)]:
            at = Vector((x, y0, 0))
            self.profile_stock(name, 'galvanized_roof', at, Vector((0, 1, 0)), Vector((sign, 0, 0)), [(0, bottom), (depth, rear_z - 0.1), (depth, rear_z), (0, shoulder)], -0.045, 0.045)
        cx = origin.x + width / 2
        for x in [origin.x, origin.x + width]:
            self.roof_panel(name, 'city_slate', [(x, y0, shoulder), (cx, y0, peak), (cx, rear_y, rear_z + peak - shoulder), (x, rear_y, rear_z)])
        self.profile_stock(name, wall, Vector((origin.x, rear_y, 0)), u, Vector((0, 1, 0)), [(0, rear_z - 0.1), (width, rear_z - 0.1), (width, rear_z), (width / 2, rear_z + peak - shoulder), (0, rear_z)], -0.04, 0.04)

    def build(self, name):
        spec = self.specs[name]
        rr = [r for r in self.records if r['id'].startswith(name + '_')]
        bodies = sorted([r for r in rr if re.search('_s\\d+$', r['id'])], key=lambda r: r['z0'])
        first, last = (bodies[0], bodies[-1])
        dx = first['registration_offset_x']
        x, y, X, Y = first['rect']
        x += dx
        X += dx
        rect = [x, y, X, Y]
        width = X - x
        depth = Y - y
        top = last['z0'] + last['h']
        eave = spec['eave']
        back_roof = y + spec['roof_depth']
        capid = name + '_c' + last['id'].rsplit('_s', 1)[1]
        for r in rr:
            suffix = r['id'][len(name) + 1:]
            if suffix.startswith(('bulk', 'hut')):
                self.original_stock(name, r['key'], self.original[r['id']])
            elif r['id'] == capid:
                self.original_stock(name, 'roof_bitumen', self.original[r['id']], None if name == 'site_nw3' else back_roof)
        self.original_stock(name, spec['wall'], self.rings[name], None if name == 'site_nw3' else back_roof)
        self.box(name, 'concrete', (x, y, -0.12), (X, Y, 0.0))
        origin = Vector((x, y, 0))
        u = Vector((1, 0, 0))
        out = Vector((0, -1, 0))
        base = 0
        for floor, height in enumerate(spec['front_heights']):
            z = base + height
            self.register(name, 'door_paint' if name == 'site_nw1' and floor == 0 else spec['wall'], origin, u, out, width, base, z, spec['front_bays'], spec['widths'][0], 'shoulder' if name == 'site_nw3' else 'segment' if name == 'site_nw1' and floor > 0 else 'rect', floor == 0, 'door_paint' if name == 'site_nw3' or (name == 'site_nw1' and floor == 0) else 'terracotta' if name == 'site_nw4' else 'arcade_brick_bond')
            self.cornice(name, origin, u, out, width, z, 'door_paint' if name == 'site_nw3' else 'terracotta' if name == 'site_nw4' else 'limestone')
            if name == 'site_nw1' and floor > 0:
                for i in range(24):
                    self.local_box(name, 'limestone', origin, u, out, (0.15 + i * (width - 0.3) / 24, -0.14, z - 0.32), (0.25 + i * (width - 0.3) / 24, -0.03, z - 0.2))
            if name in ['site_nw3', 'site_nw4']:
                for bay in range(spec['front_bays'] + 1):
                    at = max(0.2, min(width - 0.2, bay * width / spec['front_bays']))
                    if name == 'site_nw3':
                        self.turned_stock(name, 'door_paint', origin + u * at + out * -0.11, [(base + 0.12, 0.13), (base + 0.25, 0.13), (base + 0.34, 0.09), (z - 0.46, 0.09), (z - 0.3, 0.15), (z - 0.18, 0.15)], self.profile_steps)
                    else:
                        self.local_box(name, 'terracotta', origin, u, out, (at - 0.12, -0.22, base + 0.2), (at + 0.12, -0.045, z - 0.28))
                        for lo, hi, w in [(base + 0.12, base + 0.32, 0.19), (z - 0.38, z - 0.18, 0.2)]:
                            self.local_box(name, 'terracotta', origin, u, out, (at - w, -0.26, lo), (at + w, -0.015, hi))
            base = z
        for at, tangent, normal in [(Vector((X, y, 0)), Vector((0, 1, 0)), Vector((1, 0, 0))), (Vector((x, y, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0)))]:
            self.local_box(name, 'arcade_brick_bond', at, tangent, normal, (0, -0.32, 0), (depth, 0, eave))
            if name != 'site_nw3':
                points = [(0, eave), (spec['roof_depth'], top + 0.16), (depth, top + 0.16), (depth, eave)]
                self.profile_stock(name, 'arcade_brick_bond', at, tangent, normal, points, -0.32, 0)
        rear = Vector((X, Y, 0))
        base = 0
        for height in spec['front_heights']:
            self.register(name, 'arcade_brick_bond', rear, Vector((-1, 0, 0)), Vector((0, 1, 0)), width, base, base + height, 3, 1.05)
            base += height
        if name != 'site_nw3':
            self.local_box(name, 'arcade_brick_bond', rear, Vector((-1, 0, 0)), Vector((0, 1, 0)), (0, -0.32, eave), (width, 0, top))
        cuts = []
        if name == 'site_nw1':
            w = 3.15
            left = x + (width - w) / 2
            cuts = [[left - 0.06, y - 0.01, left + w + 0.06, back_roof + 0.01]]
            self.dormer(name, Vector((left, y + 0.08, 0)), w, eave, 15.35, 16.05, back_roof, top + 0.26, bays=3)
        elif name == 'site_nw3':
            for fraction, w, bays in [(0.2, 1.75, 1), (0.5, 2.25, 2), (0.8, 1.75, 1)]:
                left = x + width * fraction - w / 2
                cuts.append([left - 0.06, y - 0.01, left + w + 0.06, back_roof + 0.01])
                self.dormer(name, Vector((left, y + 0.08, 0)), w, eave, 18.6, 19.18, back_roof, top + 0.26, 'segment', bays)
        else:
            cx = width / 2
            controls = [Vector((0, eave + 0.3)), Vector((1.2, eave + 0.25)), Vector((1.5, eave + 1.8)), Vector((2.4, eave + 1.9))]
            curve = []
            for i in range(self.profile_steps+1):
                t = i / self.profile_steps
                curve.append((1 - t) ** 3 * controls[0] + 3 * (1 - t) ** 2 * t * controls[1] + 3 * (1 - t) * t * t * controls[2] + t ** 3 * controls[3])
            profile = [(0, eave), (width, eave)] + [(width - v.x, v.y) for v in curve] + [(cx + 1.15 * math.cos(i * math.pi / self.crown_steps), eave + 1.9 + 0.6 * math.sin(i * math.pi / self.crown_steps)) for i in range(self.crown_steps+1)] + [tuple(v) for v in reversed(curve)]
            h = 0.95
            wl = cx - 0.75
            wr = cx + 0.75
            low = eave + 0.38
            high = low + h
            remaining = [Vector((a, b, 0)) for a, b in profile]
            for axis, limit, greater in [(0, wl, True), (0, wr, False), (1, low, True), (1, high, False)]:
                outside = self.clip_roof_polygon(remaining, axis, limit, not greater)
                if len(outside) >= 3:
                    points = [(v.x, v.y) for v in outside]
                    area = abs(sum((a * B - A * b for (a, b), (A, B) in zip(points, points[1:] + points[:1]))))
                    if area > 1e-08:
                        self.profile_stock(name, 'terracotta', origin, u, out, points, -0.5, -0.2)
                remaining = self.clip_roof_polygon(remaining, axis, limit, greater)
            self.opening(name, 'terracotta', origin, u, out, wl, wr, low - 0.05, high + 0.05, low, high, 'rect', False, 'terracotta', False)
            self.local_box(name, 'door_paint', origin, u, out, (cx - 0.035, -0.42, low), (cx + 0.035, -0.3, high))
            center_z = eave + 2.15
            for i in range(self.oculus_steps):
                a = i * math.tau / self.oculus_steps
                b = (i + 1) * math.tau / self.oculus_steps
                points = [(cx + r * math.cos(t), center_z + r * math.sin(t)) for r, t in [(0.135, a), (0.135, b), (0.21, b), (0.21, a)]]
                self.profile_stock(name, 'terracotta', origin, u, out, points, -0.22, -0.12)
            self.profile_stock(name, 'terracotta', origin, u, out, [(cx + 0.135 * math.cos(i * math.tau / self.oculus_steps), center_z + 0.135 * math.sin(i * math.tau / self.oculus_steps)) for i in range(self.oculus_steps)], -0.23, -0.17)
            for sign in [-1, 1]:
                center = Vector((0.82 if sign < 0 else width - 0.82, eave + 0.65))
                path = []
                for i in range(self.scroll_steps+1):
                    t = i / self.scroll_steps
                    angle = math.pi * 0.25 + t * math.pi * 2.3
                    r = 0.4 - 0.28 * t
                    path.append(center + Vector((sign * math.cos(angle) * r, math.sin(angle) * r)))
                left = []
                right = []
                for i, p in enumerate(path):
                    tangent2 = (path[min(i + 1, self.scroll_steps)] - path[max(i - 1, 0)]).normalized()
                    n = Vector((-tangent2.y, tangent2.x)) * 0.035
                    left.append(tuple(p + n))
                    right.append(tuple(p - n))
                self.profile_stock(name, 'terracotta', origin, u, out, left + list(reversed(right)), -0.24, -0.03)
            cuts = [[x + wl - 0.1, y - 0.01, x + wr + 0.1, y + 0.62]]
        if name == 'site_nw3':
            l, b, r, t = last['rect']
            l += dx
            r += dx
            for lo, hi in [((l, b, eave), (r, b + 0.25, top)), ((l, t - 0.25, eave), (r, t, top)), ((l, b + 0.25, eave), (l + 0.25, t - 0.25, top)), ((r - 0.25, b + 0.25, eave), (r, t - 0.25, top))]:
                self.box(name, 'arcade_brick_bond', lo, hi)
            outside = [(x, y, eave), (X, y, eave), (X, Y, eave), (x, Y, eave)]
            inside = [(l, b, top + 0.26), (r, b, top + 0.26), (r, t, top + 0.26), (l, t, top + 0.26)]
            for i in range(4):
                j = (i + 1) % 4
                self.roof_panel(name, 'city_slate', [outside[i], outside[j], inside[j], inside[i]], cuts if i == 0 else ())
        else:
            self.roof_panel(name, 'city_slate', [(x + 0.02, y + 0.03, eave), (X - 0.02, y + 0.03, eave), (X - 0.02, back_roof, top + 0.26), (x + 0.02, back_roof, top + 0.26)], cuts)
        self.building_rows.append({'id': name, 'style': spec['style'], 'registered_rect': rect, 'assembly_translation_m': self.plans[name].get('assembly_translation_m', [0, 0, 0]), 'eave': eave, 'body_top': top, 'roof_deck_top': top + 0.26})
