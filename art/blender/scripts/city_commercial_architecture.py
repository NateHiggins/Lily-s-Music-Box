"""Closed source-fitted commercial fronts; called by build_city_elevations.py.

Germania, Robbins & Appleton and Scheffel are explicit architectural adaptations.
The caller retains registration, physical roof bearings, materials and collision.
No gameplay, access, clock or save authority is created here.
"""
import bisect,math,re
import bpy,bmesh
from mathutils import Vector,Matrix
from frame_mitre_geometry import frame_parts,interface_points

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

    def original_stock(self, name, key, obj, cut_y=None, retain_positive_y=True):
        mesh = obj.data.copy()
        mesh.transform(obj.matrix_world)
        if cut_y is not None:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-07, plane_co=(0, cut_y, 0), plane_no=(0, 1, 0), clear_inner=retain_positive_y, clear_outer=not retain_positive_y)
            boundary = [e for e in bm.edges if e.is_boundary]
            if boundary:
                bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(mesh)
            bm.free()
            assert (min(v.co.y for v in mesh.vertices)>=cut_y-1e-6 if retain_positive_y else max(v.co.y for v in mesh.vertices)<=cut_y+1e-6)
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
        if abs(out.x)>1e-6 and abs(out.y)>1e-6:
            self.window_rows[-1]['normal']=list(out)

    def opening(self, name, wall, origin, u, out, left, right, z0, z1, low, high, shape='rect', door=False, trim='limestone', wall_fill=True, bay=0, frame_finish='door_paint'):
        """A genuine pierced wall, deep jambs, closed pane/door and attached joinery."""
        back, front = (-0.48, -0.2)
        if wall_fill:
            self.local_box(name, wall, origin, u, out, (left, back, z0), (right, front, low))
        if shape in ['segment', 'round', 'ellipse']:
            rise = 0.23 if shape == 'segment' else (right-left)/2 if shape == 'round' else .88
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
            rail = min(low + 2.35, high - 0.38, spring-.10)
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
            self.local_box(name, frame_finish, origin, u, out, (x, -0.42, low), (x + 0.055, -0.32, spring))
        for z in [low, low + (spring - low) * 0.52]:
            inset=.055 if name in ['site_se3','site_sw3','site_far_nw'] else 0.
            self.local_box(name, frame_finish, origin, u, out, (left+inset, -0.42, z), (right-inset, -0.32, z + 0.055))
        if shape in ['segment', 'round', 'ellipse']:
            self.arch_stock(name, trim, origin, u, out, (left + right) / 2, spring, (right - left) / 2, rise, 0.12, -0.26, -0.04, self.profile_steps)
        else:
            for a, b in zip(top, top[1:]):
                direction = Vector((b[0] - a[0], b[1] - a[1]))
                normal = Vector((-direction.y, direction.x)).normalized() * 0.09
                self.profile_stock(name, trim, origin, u, out, [a, b, (b[0] + normal.x, b[1] + normal.y), (a[0] + normal.x, a[1] + normal.y)], -0.28, -0.05)
        for x in [left - 0.12, right]:
            self.local_box(name, trim, origin, u, out, (x, -0.28, low - 0.06), (x + 0.12, -0.05, spring))
        self.local_box(name, 'limestone' if wall == 'arcade_brick_bond' else trim, origin, u, out, (left - 0.16, -0.3, low - 0.12), (right + 0.16, -0.02, low))

    def register(self, name, wall, origin, u, out, width, z0, z1, bays, opening_width, shape='rect', ground=False, trim='limestone', attic=False, frame_finish='door_paint'):
        pitch = width / bays
        for bay in range(bays):
            center = (bay + 0.5) * pitch
            left = center - opening_width / 2
            right = center + opening_width / 2
            low = z0 + (0.18 if ground or attic else 0.64)
            high = z1 - 0.52
            self.local_box(name, wall, origin, u, out, (bay * pitch, -0.48, z0), (left, -0.2, z1))
            self.local_box(name, wall, origin, u, out, (right, -0.48, z0), ((bay + 1) * pitch, -0.2, z1))
            self.opening(name, wall, origin, u, out, left, right, z0, z1, low, high, shape, ground and bay == 0, trim, bay=bay,frame_finish=frame_finish)
            if ground and bay > 0:
                rail = low + 2.35
                self.local_box(name, frame_finish, origin, u, out, (left, -0.42, rail), (right, -0.3, rail + 0.07))
                for i in [1, 2]:
                    at = left + (right - left) * i / 3
                    self.local_box(name, frame_finish, origin, u, out, (at - 0.025, -0.42, rail + 0.07), (at + 0.025, -0.32, high))

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

    def bay_masonry_panel(self,name,origin,tangent,normal,length,z0,z1,floor):
        """A pierced brick bay skin with painted joinery and shallow glazing."""
        left,right=.18,length-.18;low,high=z0+.62,z1-.55
        for a,b in [(0,left),(right,length)]:
            self.local_box(name,'arcade_brick_bond',origin,tangent,normal,(a,-.16,z0),(b,0,z1))
        for a,b in [(z0,low),(high,z1)]:
            self.local_box(name,'arcade_brick_bond',origin,tangent,normal,(left,-.16,a),(right,0,b))
        frame=frame_parts(right-left,high-low,.05,.08);interface_points(frame)
        for stock in frame.values():
            vv=[tuple(origin+tangent*(length/2+a)+normal*(-.015+b)+Vector((0,0,low+c))) for a,b,c in stock['vertices']]
            self.add(name,'door_paint',vv,stock['faces'])
        self.local_box(name,'door_paint',origin,tangent,normal,(left,-.055,low-.05),(right,.025,low))
        rail=low+(high-low)*.52
        self.local_box(name,'door_paint',origin,tangent,normal,(left,-.055,rail),(right,.025,rail+.05))
        poly=[(left,low),(right,low),(right,high),(left,high)]
        self.profile_stock(name,'mirror_aged',origin,tangent,normal,poly,-.126,-.12)
        self.profile_stock(name,'wood_dark',origin,tangent,normal,poly,-.15,-.14)
        self.local_box(name,'limestone',origin,tangent,normal,(left-.10,-.18,low-.08),(right+.10,.029,low))
        if (floor+int(abs(origin.x)*3))%3!=0:
            bottom=high-(high-low)*[.35,.55,.75][floor%3]
            self.local_box(name,'linen',origin,tangent,normal,(left+.025,-.138,bottom),(right-.025,-.132,high-.025))
        sample=origin+tangent*(length/2+(right-left)*.18)+normal*(-.12)+Vector((0,0,low+(high-low)*.66))
        self.window_samples.append(dict(building=name,point=list(sample),normal=list(normal),finish='mirror_aged'))
        side=2 if normal.y>.5 else 0 if normal.y<-.5 else 1 if normal.x>0 else 3
        self.window_rows.append(dict(building=name,side=side,floor=floor,bay=len(self.window_rows),
            center=list(sample),width=right-left,height=high-low,recess_m=.12,pane_depth_m=.12,
            pane_sample=list(sample+normal*.12),normal=list(normal)))

    def hampton(self,name):
        """One broad five-storey Wells adaptation, not eleven copied houses."""
        spec=self.specs[name];rr=[r for r in self.records if r['id'].startswith(name+'_')]
        bodies=sorted([r for r in rr if re.search('_s\\d+$',r['id'])],key=lambda r:r['z0'])
        first,last=bodies[0],bodies[-1]
        x,y,X,Y=first['rect'];dx=first['registration_offset_x'];x+=dx;X+=dx
        width=X-x;depth=Y-y;top=last['z0']+last['h'];assert abs(top-16.7)<1e-6
        capid=name+'_c'+last['id'].rsplit('_s',1)[1];cap=next(r for r in rr if r['id']==capid)
        for r in rr:
            if r['id'][len(name)+1:].startswith(('bulk','hut')):
                self.original_stock(name,r['key'],self.original[r['id']])
            elif r['id']==capid:self.original_stock(name,'roof_bitumen',self.original[r['id']])
        # All rigging/tank seats belong to the original slab or bulkhead,
        # not the old generic inset parapet. Keep those exact bearing faces.
        l,b,r,t=cap['rect'];l+=dx;r+=dx
        for a,B,c,D in [(x,y,X,b),(x,t,X,Y),(x,b,l,t),(r,b,X,t)]:
            if c>a and D>B:self.box(name,'roof_bitumen',(a,B,top),(c,D,top+.26))
        self.box(name,'concrete',(x,y,-.12),(X,Y,0))
        origin=Vector((x,y+.35,0));u=Vector((1,0,0));out=Vector((0,-1,0));wall=spec['wall']
        centers=[2.2,5.1,12.1,16.,19.9,26.9,29.8]
        z0=0.
        for floor,height in enumerate(spec['front_heights']):
            z1=z0+height;cursor=0.
            for bay,c in enumerate(centers):
                door=floor==0 and c==16.;half=1.05 if door else .60;left,right=c-half,c+half
                self.local_box(name,wall,origin,u,out,(cursor,-.48,z0),(left,-.2,z1))
                self.opening(name,wall,origin,u,out,left,right,z0,z1,
                    .12 if door else z0+.65,3.30 if door else z1-.50,
                    'round' if door else 'rect',door,'limestone',bay=bay)
                cursor=right
            self.local_box(name,wall,origin,u,out,(cursor,-.48,z0),(width,-.2,z1))
            z0=z1
        for z in [3.5,top]:self.cornice(name,origin,u,out,width,z,'limestone')
        for c in [8.64,23.36]:
            contour=[(c-1.6,.55),(c-.95,.03),(c+.95,.03),(c+1.6,.55)]
            points=[Vector((x+a,y+b,0)) for a,b in contour]
            z0=0.
            for floor,height in enumerate(spec['front_heights']):
                z1=z0+height
                for i in range(3):
                    tangent=(points[i+1]-points[i]).normalized()
                    normal=tangent.cross(Vector((0,0,1))).normalized()
                    self.bay_masonry_panel(name,points[i],tangent,normal,(points[i+1]-points[i]).length,z0,z1,floor)
                z0=z1
            # The full concrete base and extended roof slab already cap
            # these in-parcel bays; avoid coincident duplicate top sheets.
        # Rear and side sash stay distinct from the three-faced front stacks.
        for at,tangent,normal,length,bays in [
            (Vector((X,Y,0)),Vector((-1,0,0)),Vector((0,1,0)),width,8),
            (Vector((x,Y,0)),Vector((0,-1,0)),Vector((-1,0,0)),depth,7),
            (Vector((X,y,0)),Vector((0,1,0)),Vector((1,0,0)),depth,7)]:
            z=0.
            for height in spec['front_heights']:
                self.register(name,wall,at,tangent,normal,length,z,z+height,bays,1.12)
                z+=height
        # An enclosing parapet replaces the earlier generic inset terrace.
        # Three stone panels have nine actual elliptical openings, not decals.
        seat=top+.26;crest=seat+.62
        for lo,hi in [((x,y+.43,seat),(x+.28,Y,crest)),
                      ((X-.28,y+.43,seat),(X,Y,crest)),
                      ((x+.28,Y-.28,seat),(X-.28,Y,crest))]:self.box(name,wall,lo,hi)
        front=Vector((x,y+.15,0));cursor=0.
        for c in [4.3,16.,27.7]:
            left,right=c-1.2,c+1.2
            self.local_box(name,wall,front,u,out,(cursor,-.28,seat),(left,0,crest))
            for lo,hi in [(seat,seat+.12),(seat+.50,crest)]:
                self.local_box(name,'limestone',front,u,out,(left,-.28,lo),(right,0,hi))
            center_z=seat+.31
            for k in range(3):
                cx=left+.4+k*.8
                corner=math.atan2(.19,.4)
                angles=sorted(set([i*math.tau/self.oculus_steps for i in range(self.oculus_steps)]+
                    [corner,math.pi-corner,math.pi+corner,math.tau-corner]))
                def outer(t):
                    c,s=math.cos(t),math.sin(t)
                    radius=min(.4/abs(c) if abs(c)>1e-8 else math.inf,
                               .19/abs(s) if abs(s)>1e-8 else math.inf)
                    return (cx+radius*c,center_z+radius*s)
                for a,b in zip(angles,angles[1:]+[math.tau]):
                    # The outer boundary is a full rectangular stone cell.
                    # Its top/bottom faces bear over finite areas on the bars.
                    poly=[(cx+.28*math.cos(a),center_z+.125*math.sin(a)),
                          (cx+.28*math.cos(b),center_z+.125*math.sin(b)),outer(b),outer(a)]
                    self.profile_stock(name,'limestone',front,u,out,poly,-.28,0)
            cursor=right
        self.local_box(name,wall,front,u,out,(cursor,-.28,seat),(width,0,crest))
        self.box(name,'limestone',(x,y+.12,crest),(X,y+.46,crest+.10))
        self.building_rows.append({'id':name,'style':spec['style'],'registered_rect':[x,y,X,Y],
            'assembly_translation_m':self.plans[name].get('assembly_translation_m',[0,0,0]),
            'eave':top,'body_top':top,'roof_deck_top':top+.26})

    def cant_sash(self,name,origin,tangent,normal,length,low=4.70,height=3.4):
        """Thin bronze bay joinery, not a thick masonry reveal at a corner."""
        clear=length-.12
        frame=frame_parts(clear,height,.06,.08)
        interface_points(frame)
        for stock in frame.values():
            vv=[tuple(origin+tangent*(length/2+a)+normal*(-.05+b)+Vector((0,0,low+c))) for a,b,c in stock['vertices']]
            self.add(name,'bronze_sheet',vv,stock['faces'])
        for a,b in [(low-.12,low-.06),(low+height+.06,low+height+.24)]:
            self.local_box(name,'bronze_sheet',origin,tangent,normal,(0,-.10,a),(length,0,b))
        self.local_box(name,'bronze_sheet',origin,tangent,normal,(0,-.09,low-.06),(length,-.01,low))
        rail=low+height*.50
        self.local_box(name,'bronze_sheet',origin,tangent,normal,(.06,-.09,rail),(length-.06,-.01,rail+.05))
        polygon=[(.06,low),(length-.06,low),(length-.06,low+height),(.06,low+height)]
        self.profile_stock(name,'mirror_aged',origin,tangent,normal,polygon,-.061,-.055)
        self.profile_stock(name,'wood_dark',origin,tangent,normal,polygon,-.08,-.07)
        sample=origin+tangent*(length/2+clear*.18)+normal*(-.055)+Vector((0,0,low+height*.60))
        self.window_samples.append(dict(building=name,point=list(sample),normal=list(normal),finish='mirror_aged'))
        side=2 if normal.y>.5 else 0 if normal.y<-.5 else 1 if normal.x>0 else 3
        self.window_rows.append(dict(building=name,side=side,floor=1,bay=len(self.window_rows),
            center=list(sample),width=clear,height=height,recess_m=.055,pane_depth_m=.055,
            pane_sample=list(sample+normal*.055),normal=list(normal)))

    def firehouse(self, name):
        """Gilbert double-bay firehouse adapted to the fixed 11.4 m parcel."""
        spec=self.specs[name]
        rr=[r for r in self.records if r['id'].startswith(name+'_')]
        bodies=sorted([r for r in rr if re.search('_s\\d+$',r['id'])],key=lambda r:r['z0'])
        first,last=bodies[0],bodies[-1]
        x,y,X,Y=first['rect'];dx=first['registration_offset_x'];x+=dx;X+=dx
        width=X-x;depth=Y-y;top=last['z0']+last['h'];wing_depth=spec['roof_depth'];cut=Y-wing_depth
        assert abs(width-11.4)<1e-6 and abs(top-18.5)<1e-6
        capid=name+'_c'+last['id'].rsplit('_s',1)[1]
        cap=next(r for r in rr if r['id']==capid)
        for r in rr:
            if r['id'][len(name)+1:].startswith(('bulk','hut')):
                self.original_stock(name,r['key'],self.original[r['id']])
            elif r['id']==capid:
                self.original_stock(name,'roof_bitumen',self.original[r['id']],cut,False)
        self.original_stock(name,spec['wall'],self.rings[name],cut,False)
        # Extend the bearing deck only outside the original cap. Original
        # tank/rigging contact faces survive without coincident replacement.
        l,b,r,t=cap['rect'];l+=dx;r+=dx;t=min(t,cut)
        for a,B,c,D in [(x,y,X,b),(x,b,l,t),(r,b,X,t),(x,t,X,cut)]:
            if c>a and D>B:self.box(name,'roof_bitumen',(a,B,top),(c,D,top+.26))
        self.box(name,'concrete',(x,y,-.12),(X,Y,0))
        origin=Vector((X,Y,0));u=Vector((-1,0,0));out=Vector((0,1,0))
        wall=spec['wall'];stone='limestone'
        # Two apparatus bays with a broad load-bearing middle pier. Doors
        # remain closed scenic timber, not modern red replacement shutters.
        gaps=[(1.15,4.15),(width-4.15,width-1.15)]
        edges=[(0,gaps[0][0]),(gaps[0][1],gaps[1][0]),(gaps[1][1],width)]
        for a,b in edges:
            self.local_box(name,stone,origin,u,out,(a,-.55,0),(b,-.2,4.5))
            for z in [.12,.66,1.20,1.74,2.28,2.82,3.36,3.90]:
                self.local_box(name,stone,origin,u,out,(a,-.24,z),(b,-.08,z+.13))
        for i,(a,b) in enumerate(gaps):
            self.opening(name,stone,origin,u,out,a,b,0,4.5,.16,3.92,'segment',True,stone,bay=i)
        self.cornice(name,origin,u,out,width,4.5,stone)
        # The second storey's backing is recessed behind the cant bays.
        self.local_box(name,wall,origin,u,out,(0,-1.15,4.5),(width,-1.,8.5))
        center=width/2
        for i,c in enumerate([center-.43,center+.43]):
            self.opening(name,wall,origin,u,out,c-.30,c+.30,4.5,8.5,5.30,7.85,'round',False,stone,bay=i)
        for c in [2.6,width-2.6]:
            contour=[(c-1.38,-.90),(c-.84,-.10),(c+.84,-.10),(c+1.38,-.90)]
            points=[origin+u*a+out*b for a,b in contour]
            for z in [4.58,8.42]:
                self.roof_panel(name,'bronze_sheet',[tuple(p+Vector((0,0,z))) for p in points])
            for i in range(3):
                tangent=(points[i+1]-points[i]).normalized()
                normal=tangent.cross(Vector((0,0,1))).normalized()
                length=(points[i+1]-points[i]).length
                self.cant_sash(name,points[i],tangent,normal,length)
            # Two plain bearing brackets support each projecting metal sill.
            for at in [c-.65,c+.65]:
                self.profile_stock(name,stone,origin+u*at, out, u,
                    [(-.92,4.12),(-.92,4.58),(-.13,4.58),(-.32,4.38)],-.10,.10)
        self.cornice(name,origin,u,out,width,8.5,stone)
        # Paired third-storey sash, with stone keys and substantial end piers.
        pitch=width/3
        for bay in range(3):
            c=(bay+.5)*pitch
            for a,b in [(bay*pitch,c-1.15),(c+1.15,(bay+1)*pitch)]:
                self.local_box(name,wall,origin,u,out,(a,-.48,8.5),(b,-.2,12.5))
            self.opening(name,wall,origin,u,out,c-1.15,c+1.15,8.5,12.5,9.08,11.89,'segment',False,stone,bay=bay)
            self.local_box(name,'door_paint',origin,u,out,(c-.045,-.42,9.08),(c+.045,-.30,11.66))
            self.local_box(name,stone,origin,u,out,(c-.13,-.28,11.85),(c+.13,-.01,12.19))
        self.cornice(name,origin,u,out,width,12.5,stone)
        # Five square steps each side and a narrow central crown; every
        # coping bears on closed brick and all roof strips have real depth.
        stops=[i*1.02 for i in range(6)]+[6.3+i*1.02 for i in range(6)]
        # The source mass's 18.5 m datum belongs to the retained plant deck.
        # A taller decorative front restores the Gilbert gable silhouette
        # above that AU service block without lifting a single plant bearing.
        heights=[15.3,16.2,17.1,18.,18.9,20.0,18.9,18.,17.1,16.2,15.3]
        assert abs(stops[-1]-width)<1e-6
        profile=[(0,12.5),(width,12.5),(width,heights[-1])]
        for i in reversed(range(len(heights))):
            profile.append((stops[i],heights[i]))
            if i:profile.append((stops[i],heights[i-1]))
        wl,wr=center-.90,center+.90;low,high=14.05,17.35
        remaining=[Vector((a,b,0)) for a,b in profile]
        for axis,limit,greater in [(0,wl,True),(0,wr,False),(1,low,True),(1,high,False)]:
            outside=self.clip_roof_polygon(remaining,axis,limit,not greater)
            if len(outside)>=3:
                self.profile_stock(name,wall,origin,u,out,[(v.x,v.y) for v in outside],-.48,-.2)
            remaining=self.clip_roof_polygon(remaining,axis,limit,greater)
        self.opening(name,wall,origin,u,out,wl,wr,low-.1,high+.1,low,high,'round',False,stone,False)
        # The gable was clipped around a rectangular aperture. Fill the two
        # upper corners outside its real arch, without filling the glazing.
        # Each strip is independently closed; peak duplicates become triangles.
        half=(wr-wl)/2;spring=high-half
        arc=[(center-half*math.cos(i*math.pi/self.profile_steps),spring+half*math.sin(i*math.pi/self.profile_steps)) for i in range(self.profile_steps+1)]
        for a,b in zip(arc,arc[1:]):
            polygon=[a,b,(b[0],high),(a[0],high)];clean=[]
            for point in polygon:
                if not clean or math.dist(point,clean[-1])>1e-9:clean.append(point)
            if len(clean)>2 and math.dist(clean[0],clean[-1])<1e-9:clean.pop()
            if len(clean)>=3:self.profile_stock(name,wall,origin,u,out,clean,-.48,-.2)
        self.local_box(name,'door_paint',origin,u,out,(center-.045,-.42,low),(center+.045,-.30,high-.9))
        crown=frame_parts(.76,.86,.17,.20);interface_points(crown)
        for stock in crown.values():
            vv=[tuple(origin+u*(center+a)+out*(-.18+b)+Vector((0,0,18.42+c))) for a,b,c in stock['vertices']]
            self.add(name,stone,vv,stock['faces'])
        self.local_box(name,stone,origin,u,out,(center-.55,-.28,18.25),(center+.55,-.08,18.42))
        self.local_box(name,wall,origin,u,out,(center-.38,-.27,18.42),(center+.38,-.15,19.25))
        self.local_box(name,stone,origin,u,out,(center-.82,-.35,19.40),(center+.82,0,19.48))
        self.arch_stock(name,stone,origin,u,out,center,19.45,.70,.28,.12,-.28,-.05,self.profile_steps)
        for i,h in enumerate(heights):
            a,b=stops[i],stops[i+1]
            self.local_box(name,stone,origin,u,out,(a,-.5,h),(b,0.,h+.12))
        # A real transverse pitched roof sits below the stepped front. The
        # retained higher plant deck belongs to the recessed rear service
        # block, not an array of metal visors above every gable step.
        ridge=19.25;eave=14.30
        for a,b,za,zb in [(0,width/2,eave,ridge),(width/2,width,ridge,eave)]:
            self.roof_panel(name,'galvanized_roof',[
                tuple(origin+u*a-out*.47+Vector((0,0,za))),
                tuple(origin+u*b-out*.47+Vector((0,0,zb))),
                tuple(origin+u*b-out*wing_depth+Vector((0,0,zb))),
                tuple(origin+u*a-out*wing_depth+Vector((0,0,za)))])
        self.local_box(name,wall,origin-out*wing_depth,u,out,(0,-.32,12.5),(width,0,top))
        half=(ridge-top)/(ridge-eave)*width/2
        self.profile_stock(name,wall,origin-out*wing_depth,u,out,
            [(center-half,top),(center+half,top),(center,ridge)],-.32,0)
        # Four rear registers and blank party-wall returns are separate from
        # the shallow stepped front; no extra yard extension is introduced.
        rear=Vector((x,y,0));z=0.
        for height in [4.5,4.,4.,4.5]:
            self.register(name,wall,rear,Vector((1,0,0)),Vector((0,-1,0)),width,z,z+height,3,1.05)
            z+=height
        self.local_box(name,wall,rear,Vector((1,0,0)),Vector((0,-1,0)),(0,-.48,z),(width,0,top))
        side_profile=[(0,0),(depth,0),(depth,top),(wing_depth,top),(wing_depth,eave),(0,eave)]
        for at,normal in [(Vector((x,Y,0)),Vector((-1,0,0))),(Vector((X,Y,0)),Vector((1,0,0)))]:
            self.profile_stock(name,wall,at,Vector((0,-1,0)),normal,side_profile,-.32,0)
        self.building_rows.append({'id':name,'style':spec['style'],'registered_rect':[x,y,X,Y],
            'assembly_translation_m':self.plans[name].get('assembly_translation_m',[0,0,0]),
            'eave':12.5,'body_top':top,'roof_deck_top':top+.26})

    def library(self, name):
        """Three-storey Schickel adaptation; flat plant roof and parcel retained."""
        spec=self.specs[name]
        rr=[r for r in self.records if r['id'].startswith(name+'_')]
        bodies=sorted([r for r in rr if re.search('_s\\d+$',r['id'])],key=lambda r:r['z0'])
        first,last=bodies[0],bodies[-1]
        x,y,X,Y=first['rect'];dx=first['registration_offset_x'];x+=dx;X+=dx
        top=last['z0']+last['h'];width=X-x;depth=Y-y
        assert abs(top-10.2)<1e-6 and abs(sum(spec['front_heights'])-top)<1e-6
        capid=name+'_c'+last['id'].rsplit('_s',1)[1]
        for r in rr:
            if r['id'][len(name)+1:].startswith(('bulk','hut')):
                self.original_stock(name,r['key'],self.original[r['id']])
            elif r['id']==capid:
                self.original_stock(name,'roof_bitumen',self.original[r['id']])
        # The front guy bears on the original parapet to within 2 mm of the
        # parcel edge. Preserve the complete stock, not a replacement crown.
        self.original_stock(name,spec['wall'],self.rings[name])
        self.box(name,'concrete',(x,y,-.12),(X,Y,0))
        origin=Vector((X,Y,0));u=Vector((-1,0,0));out=Vector((0,1,0))
        wall=spec['wall'];trim='terracotta';cx=width/2
        left,right=cx-2.7,cx+2.7
        for a,b in [(0,left),(right,width)]:
            self.local_box(name,wall,origin,u,out,(a,-.48,0),(b,-.2,3.4))
            # Recessed, unlettered panel stocks flank the broad entry arch.
            center=(a+b)/2
            self.local_box(name,'limestone',origin,u,out,(center-.39,-.23,.65),(center+.39,-.06,1.85))
            self.local_box(name,trim,origin,u,out,(a,-.28,0),(b,-.03,.16))
        self.opening(name,wall,origin,u,out,left,right,0,3.4,.16,3.12,'ellipse',False,trim,bay=0)
        # A 2.2 m closed pair of doors sits within the wider glazed arch.
        # Door leaves cover the backing pane; the original pane sample lies
        # outside their 1.1 m half-width and remains independently testable.
        dl,dr=cx-1.1,cx+1.1
        frame=frame_parts(1.96,2.07,.12,.13)
        interface_points(frame)
        for stock in frame.values():
            vv=[tuple(origin+u*(cx+a)+out*(-.345+b)+Vector((0,0,.16+c))) for a,b,c in stock['vertices']]
            # This helper's stock winding is inward in its source coordinates.
            # The +Y facade's (-X,+Y,+Z) reflection reverses it outward.
            # The lower producer independently checks every signed volume.
            ff=stock['faces']
            self.add(name,'door_paint',vv,ff)
        for lo,hi in [(.31,1.02),(1.12,2.23)]:
            self.local_box(name,'door_paint',origin,u,out,(cx-.045,-.41,lo),(cx+.045,-.28,hi))
        for lo,hi in [(.16,.31),(1.02,1.12)]:
            self.local_box(name,'door_paint',origin,u,out,(dl+.12,-.41,lo),(dr-.12,-.28,hi))
        for a,b in [(dl+.12,cx-.045),(cx+.045,dr-.12)]:
            self.local_box(name,'door_paint',origin,u,out,(a,-.41,.31),(b,-.31,1.02))
        for sign in [-1,1]:
            at=cx+sign*.15
            self.local_box(name,'bronze_sheet',origin,u,out,(at-.018,-.28,1.05),(at+.018,-.21,1.28))
        self.portal_rows.append(dict(building=name,side=2,
            point=list(origin+u*(dl+.06)+out*(-.2)+Vector((0,0,1.2))),front=-.08))
        # Three tall round-headed windows in each upper register; generous
        # masonry piers preserve the intentionally broadened AU proportion.
        for floor in [1,2]:
            z0=floor*3.4;z1=z0+3.4;pitch=width/3
            for bay in range(3):
                center=(bay+.5)*pitch;wl=center-.78;wr=center+.78
                for a,b in [(bay*pitch,wl),(wr,(bay+1)*pitch)]:
                    self.local_box(name,wall,origin,u,out,(a,-.48,z0),(b,-.2,z1))
                self.opening(name,wall,origin,u,out,wl,wr,z0,z1,z0+.43,z0+2.87,'round',False,trim,bay=bay)
                # Sparse separate voussoirs frame the arch. The lower LOD
                # retains every block, sash, pane and backing surface.
                spring=z0+2.87-.78
                for i in range(7):
                    angle=(i+.5)*math.pi/7
                    a=center-.99*math.cos(angle);h=spring+.99*math.sin(angle)
                    self.local_box(name,trim,origin,u,out,(a-.075,-.24,h-.075),(a+.075,-.01,h+.075))
        for z in [3.4,6.8,10.08]:self.cornice(name,origin,u,out,width,z,trim)
        # Strong upper corbel rhythm and horizontal friezes, without copied
        # lettering, dispensary portrait busts or new library gameplay.
        for i in range(24):
            at=.20+i*(width-.4)/24
            self.local_box(name,trim,origin,u,out,(at,-.22,9.96),(at+.14,0.,10.15))
        for side_origin,tangent,normal,length,bays in [
            (Vector((x,y,0)),Vector((1,0,0)),Vector((0,-1,0)),width,3),
            (Vector((x,Y,0)),Vector((0,-1,0)),Vector((-1,0,0)),depth,2),
            (Vector((X,y,0)),Vector((0,1,0)),Vector((1,0,0)),depth,2)]:
            for floor in range(3):
                self.register(name,wall,side_origin,tangent,normal,length,floor*3.4,(floor+1)*3.4,bays,1.12)
        self.building_rows.append({'id':name,'style':spec['style'],'registered_rect':[x,y,X,Y],
            'assembly_translation_m':self.plans[name].get('assembly_translation_m',[0,0,0]),
            'eave':top,'body_top':top,'roof_deck_top':top+.26})

    def mitered_course(self,name,key,rect,profile):
        """Four closed roof boards, joined at45 degrees through the profile.

        Each board remains a separate stock, so the shared timber charts can
        follow its long axis instead of treating an entire ring as one grain.
        """
        x,y,X,Y=rect
        for origin,tangent,out,length in [
            (Vector((x,y,0)),Vector((1,0,0)),Vector((0,-1,0)),X-x),
            (Vector((X,y,0)),Vector((0,1,0)),Vector((1,0,0)),Y-y),
            (Vector((X,Y,0)),Vector((-1,0,0)),Vector((0,1,0)),X-x),
            (Vector((x,Y,0)),Vector((0,-1,0)),Vector((-1,0,0)),Y-y)]:
            n=len(profile)
            vertices=[tuple(origin+tangent*((-depth) if end==0 else length+depth)+out*depth+Vector((0,0,z))) for end in [0,1] for depth,z in profile]
            faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
            faces.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
            self.add(name,key,vertices,faces)

    def faber(self,name):
        """Four-storey neo-Grec workshop; short3-bay/long8-bay proportions."""
        spec=self.specs[name]
        records=[r for r in self.records if r['id'].startswith(name+'_')]
        bodies=sorted([r for r in records if re.search('_s\\d+$',r['id'])],key=lambda r:r['z0'])
        first,last=bodies[0],bodies[-1]
        x,y,X,Y=first['rect'];dx=first['registration_offset_x'];x+=dx;X+=dx
        top=last['z0']+last['h'];width=X-x;depth=Y-y
        assert len(spec['front_heights'])==4 and abs(spec['eave']-top)<1e-6
        capid=name+'_c'+last['id'].rsplit('_s',1)[1]
        for record in records:
            if record['id'][len(name)+1:].startswith(('bulk','hut')):
                self.original_stock(name,record['key'],self.original[record['id']])
            elif record['id']==capid:
                self.original_stock(name,'roof_bitumen',self.original[record['id']])
        self.original_stock(name,spec['wall'],self.rings[name])
        self.box(name,'concrete',(x,y,-.12),(X,Y,0))
        levels=[0.]
        for height in spec['front_heights']:levels.append(levels[-1]+height)
        sides=[
            (Vector((x,y,0)),Vector((1,0,0)),Vector((0,-1,0)),width,3),
            (Vector((X,y,0)),Vector((0,1,0)),Vector((1,0,0)),depth,8),
            (Vector((X,Y,0)),Vector((-1,0,0)),Vector((0,1,0)),width,3),
            (Vector((x,Y,0)),Vector((0,-1,0)),Vector((-1,0,0)),depth,8)]
        for side,(origin,u,out,length,bays) in enumerate(sides):
            for floor,(z0,z1) in enumerate(zip(levels,levels[1:])):
                count=5 if side in [1,3] and floor==0 else bays
                if side==1:
                    # The adjoining NE2 wall is only0.6m away and ends2.5m
                    # before ours. Use a fire wall, with one genuine rear bay
                    # beyond that neighbour, rather than impossible borrowed
                    # light through a complete row of adjacent windows.
                    count=bays
                    for bay in range(count):
                        cell=length/count
                        if bay==count-1:
                            self.register(name,spec['wall'],origin+u*(bay*cell),u,out,cell,z0,z1,1,1.30,'rect',False,'terracotta')
                        else:
                            self.local_box(name,spec['wall'],origin,u,out,(bay*cell,-.48,z0),((bay+1)*cell,-.2,z1))
                            self.local_box(name,spec['wall'],origin,u,out,(bay*cell+.03,-.23,z0), (bay*cell+.18,-.12,z1))
                else:
                    self.register(name,spec['wall'],origin,u,out,length,z0,z1,count,1.30,'rect',floor==0,'terracotta')
                pitch=length/count
                for bay in range(count):
                    if side==1 and bay<count-1:continue
                    center=(bay+.5)*pitch;head=z1-.52
                    # Separate incised lintel fascia and bracketed sill stocks.
                    # Fired clay is an explicit AU substitute for brownstone;
                    # there is no trademark, copied lettering or photo texture.
                    self.local_box(name,'terracotta',origin,u,out,(center-.83,-.24,head),(center+.83,-.02,head+.22))
                    for sign in [-1,1]:
                        a=center+sign*.47
                        self.profile_stock(name,'terracotta',origin,u,out,[(a-.12,head+.045),(a+.12,head+.045),(a+.07,head+.12),(a-.07,head+.12)],-.02,.004)
                    if floor>0:
                        low=z0+.64
                        for sign in [-1,1]:
                            a=center+sign*.43
                            self.profile_stock(name,'terracotta',origin,u,out,[(a-.055,low-.12),(a+.055,low-.12),(a+.055,low-.27),(a-.025,low-.23)],-.22,-.035)
            self.local_box(name,'limestone',origin,u,out,(0,-.48,0),(length,-.18,.18))
            # Individual cornice consoles follow each face; all are retained
            # in the lower body, with reduced curve tessellation only.
            count=bays*2
            for i in range(count):
                center=(i+.5)*length/count
                points=[(-.22,top-.70),(-.22,top-.13),(.34,top-.13)]
                points += [(.34-.56*t,top-.13-.57*(1-math.cos(t*math.pi/2))) for t in [j/self.profile_steps for j in range(1,self.profile_steps)]]
                self.profile_stock(name,'wood_dark',origin+u*center,out,u,points,-.06,.06)
        # Thin built-up cap, moulded fascia, soffit and frieze boards leave
        # an actual cavity; this is not a metre-wide solid timber cornice.
        self.mitered_course(name,'wood_dark',[x,y,X,Y],[(-.48,top+.005),(.46,top+.005),(.46,top+.035),(-.48,top+.035)])
        self.mitered_course(name,'wood_dark',[x,y,X,Y],[(.33,top-.19),(.39,top-.19),(.46,top-.09),(.46,top+.005),(.42,top+.005),(.42,top-.07)])
        self.mitered_course(name,'wood_dark',[x,y,X,Y],[(-.48,top-.13),(.39,top-.13),(.39,top-.10),(-.48,top-.10)])
        self.mitered_course(name,'wood_dark',[x,y,X,Y],[(-.085,top-.68),(-.05,top-.68),(-.05,top-.13),(-.085,top-.13)])
        self.building_rows.append({'id':name,'style':spec['style'],'registered_rect':[x,y,X,Y],
            'assembly_translation_m':self.plans[name].get('assembly_translation_m',[0,0,0]),
            'eave':top,'body_top':top,'roof_deck_top':top+.26})

    def fulton(self,name):
        """Six-storey AU instrument house, preserving the real17.5m roof step."""
        spec=self.specs[name];wall=spec['wall']
        records=[r for r in self.records if r['id'].startswith(name+'_')]
        bodies=sorted([r for r in records if re.search('_s\\d+$',r['id'])],key=lambda r:r['z0'])
        first,last=bodies[0],bodies[-1]
        dx=first['registration_offset_x'];x,y,X,Y=first['rect'];x+=dx;X+=dx
        rx,ry,rX,rY=last['rect'];rx+=dx;rX+=dx
        width=X-x;depth=Y-y;top=last['z0']+last['h'];step=last['z0']
        levels=[0.]
        for height in spec['front_heights']:levels.append(levels[-1]+height)
        assert len(levels)==7 and abs(levels[-1]-top)<1e-6 and abs(levels[5]-step)<1e-6
        caps={r['id']:r for r in records if re.fullmatch(name+'_c\\d+',r['id'])}
        for record in records:
            suffix=record['id'][len(name)+1:]
            if suffix.startswith(('bulk','hut')):
                self.original_stock(name,record['key'],self.original[record['id']])
            elif record['id'] in caps:
                # Preserve both the real lower terrace and final plant deck.
                self.original_stock(name,'roof_bitumen',self.original[record['id']])
        self.original_stock(name,wall,self.rings[name])
        self.box(name,'concrete',(x,y,-.12),(X,Y,0))
        origin=Vector((x,y,0));u=Vector((1,0,0));out=Vector((0,-1,0));cx=width/2
        for floor in [0,1]:
            self.register(name,'iron_blackened',origin,u,out,width,levels[floor],levels[floor+1],3,2.05,
                'round' if floor==1 else 'rect',floor==0,'bronze_sheet',frame_finish='bronze_sheet')
        for at in [.16,width/3,width*2/3,width-.16]:
            self.turned_stock(name,'iron_blackened',origin+u*at+out*(-.06),
                [(.12,.14),(.28,.14),(.38,.085),(levels[2]-.40,.085),(levels[2]-.22,.15),(levels[2]-.10,.15)],self.profile_steps)
        self.cornice(name,origin,u,out,width,levels[2],'bronze_sheet')
        left,right=cx-1.90,cx+1.90
        for floor in [2,3]:
            a,b=levels[floor],levels[floor+1]
            self.register(name,wall,origin,u,out,left,a,b,1,.78,'rect',False,'terracotta',frame_finish='bronze_sheet')
            self.register(name,wall,origin+u*right,u,out,width-right,a,b,1,.78,'rect',False,'terracotta',frame_finish='bronze_sheet')
        self.opening(name,wall,origin,u,out,left,right,levels[2],levels[4],levels[2]+.30,levels[4]-.35,
            'round',False,'terracotta',bay=0,frame_finish='bronze_sheet')
        self.local_box(name,'bronze_sheet',origin,u,out,(left,-.42,levels[3]-.13),(right,-.28,levels[3]+.13))
        crown=levels[4]-.35
        self.profile_stock(name,'terracotta',origin,u,out,[(cx-.17,crown-.08),(cx+.17,crown-.08),(cx+.26,crown+.26),(cx-.26,crown+.26)],-.28,.02)
        for z in [levels[2]+.30,levels[4]-.35-1.90]:
            self.local_box(name,'terracotta',origin,u,out,(left-.15,-.26,z-.10),(right+.15,-.04,z))
        for floor in [2,3]:
            a,b=levels[floor],levels[floor+1]
            for at in [.08,width-.18]:
                self.local_box(name,'terracotta',origin,u,out,(at,-.24,a+.06),(at+.10,-.05,b-.08))
        # A fixed angle line defines both oriel storeys. The upper wall steps
        # back, exposing more of the same side facet rather than rotating it.
        rear=-(ry-y)-.48;front=.65;back_x=cx-2.4;front_x=cx-1.7
        def edge_at(depth):return back_x+(front_x-back_x)*(depth-rear)/(front-rear)
        def outline(depth):
            a=edge_at(depth)
            return [(a,depth),(front_x,front),(width-front_x,front),(width-a,depth)]
        def plate(depth,z,thickness,key='bronze_sheet'):
            self.roof_panel(name,key,[origin+u*a+out*b+Vector((0,0,z)) for a,b in outline(depth)],thickness=thickness)
        plate(-.48,levels[4],.16,'iron_blackened')
        lower_cap=caps[name+'_c'+first['id'].rsplit('_s',1)[1]]
        plate(y-lower_cap['rect'][1],step,.26,'iron_blackened')
        final_cap=caps[name+'_c'+last['id'].rsplit('_s',1)[1]]
        plate(y-final_cap['rect'][1],top+final_cap['h'],final_cap['h'])
        for floor in [4,5]:
            a,b=levels[floor],levels[floor+1]
            face_y=y if floor==4 else ry
            offset=y-face_y
            edge=edge_at(offset-.20)
            ox=x if floor==4 else rx;ex=X if floor==4 else rX
            for lo,hi in [(ox,x+edge),(X-edge,ex)]:
                self.local_box(name,wall,Vector((lo,face_y,0)),u,out,(0,-.48,a),(hi-lo,-.20,b))
                self.local_box(name,'terracotta',Vector((lo,face_y,0)),u,out,(.02,-.22,a+.06),(hi-lo-.02,-.07,a+.20))
            polygon=outline(offset-.20)
            for index,(p,q) in enumerate(zip(polygon,polygon[1:])):
                start=origin+u*p[0]+out*p[1];finish=origin+u*q[0]+out*q[1]
                tangent=(finish-start).normalized();normal=tangent.cross(Vector((0,0,1)))
                length=(finish-start).length
                self.cant_sash(name,start,tangent,normal,length,low=a+.32,height=b-a-.62)
                self.window_rows[-1]['floor']=floor
                self.local_box(name,'bronze_sheet',start,tangent,normal,(0,-.10,a),(length,.015,a+.26))
                self.local_box(name,'bronze_sheet',start,tangent,normal,(0,-.10,b-.20),(length,.02,b))
        # Forged consoles root in the solid arch spandrel below the oriel;
        # their front tips actually meet the projecting bay floor plate.
        for at in [cx-1.65,cx+1.65]:
            self.profile_stock(name,'iron_blackened',origin+u*at,out,u,
                [(-.43,levels[4]-.55),(-.43,levels[4]-.02),(.58,levels[4]-.02),(.20,levels[4]-.18),(-.18,levels[4]-.55)],-.10,.10)
        self.cornice(name,origin,u,out,width,levels[4],'terracotta')
        # Front balustrade is on the extended bay roof, while the exact old
        # inner plant parapet remains available to every retained guy anchor.
        roof=top+final_cap['h'];rail_top=roof+.62
        for p,q in zip(outline(y-final_cap['rect'][1]),outline(y-final_cap['rect'][1])[1:]):
            start=origin+u*p[0]+out*p[1];finish=origin+u*q[0]+out*q[1]
            tangent=(finish-start).normalized();normal=tangent.cross(Vector((0,0,1)));length=(finish-start).length
            self.local_box(name,'terracotta',start,tangent,normal,(0,-.075,roof),(length,.075,roof+.08))
            self.local_box(name,'terracotta',start,tangent,normal,(0,-.09,rail_top-.10),(length,.09,rail_top))
            count=max(2,round(length/.30))
            for i in range(count):
                point=start+tangent*((i+.5)*length/count)
                self.turned_stock(name,'terracotta',point,[(roof+.08,.045),(roof+.14,.045),(roof+.20,.027),(rail_top-.20,.032),(rail_top-.10,.045)],self.profile_steps)
        # Real rear and party-wall elevations retain the installed upper step.
        for floor in range(5):
            a,b=levels[floor],levels[floor+1]
            self.register(name,wall,Vector((X,Y,0)),Vector((-1,0,0)),Vector((0,1,0)),width,a,b,3,1.15,'rect',False,'terracotta')
            for side_origin,tangent,normal in [(Vector((X,y,0)),Vector((0,1,0)),Vector((1,0,0))),
                (Vector((x,Y,0)),Vector((0,-1,0)),Vector((-1,0,0)))]:
                exposed=(floor>=3 and normal.x>0) or floor==4
                if exposed:self.register(name,wall,side_origin,tangent,normal,depth,a,b,7,1.10,'rect',False,'terracotta')
                else:self.local_box(name,wall,side_origin,tangent,normal,(0,-.48,a),(depth,-.2,b))
        for side_origin,tangent,normal,length,bays in [
            (Vector((rX,rY,0)),Vector((-1,0,0)),Vector((0,1,0)),rX-rx,2),
            (Vector((rX,ry,0)),Vector((0,1,0)),Vector((1,0,0)),rY-ry,6),
            (Vector((rx,rY,0)),Vector((0,-1,0)),Vector((-1,0,0)),rY-ry,6)]:
            self.register(name,wall,side_origin,tangent,normal,length,step,top,bays,1.05,'rect',False,'terracotta')
        self.building_rows.append({'id':name,'style':spec['style'],'registered_rect':[x,y,X,Y],
            'assembly_translation_m':self.plans[name].get('assembly_translation_m',[0,0,0]),
            'eave':top,'body_top':top,'roof_deck_top':top+final_cap['h']})

    def build(self, name):
        if self.specs[name]['style'] == 'fulton':
            return self.fulton(name)
        if self.specs[name]['style'] == 'faber':
            return self.faber(name)
        if self.specs[name]['style'] == 'hampton':
            return self.hampton(name)
        if self.specs[name]['style'] == 'engine258':
            return self.firehouse(name)
        if self.specs[name]['style'] == 'ottendorfer':
            return self.library(name)
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
