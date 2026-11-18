"""Pure metre-space closed stocks for the existing arcade native producer.

Input/output coordinates are PLAN (u, v, height), never Blender/Godot/world.
Every stock is independently closed, coarse and editable. Shared partitions,
UVs, preview optics, collision and export remain the existing producer's job.
"""
import hashlib
import json
import math


def source_digest(plan):
    return hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(',', ':'),
                                    allow_nan=False).encode()).hexdigest()


def _need(condition, message):
    if not condition:
        raise ValueError(message)


def _add(a, b):
    return [x + y for x, y in zip(a, b)]


def _sub(a, b):
    return [x - y for x, y in zip(a, b)]


def _cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def _dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def _unit(a):
    length = math.sqrt(_dot(a, a))
    _need(length > 1e-12, 'zero stock axis')
    return [x/length for x in a]


def volume(vertices, faces):
    # Translate before summation: thin panes far from origin remain stable.
    origin = vertices[0]
    return sum(_dot(_sub(vertices[a], origin), _cross(_sub(vertices[b], origin),
               _sub(vertices[c], origin)))/6 for a, b, c in faces)


def stocks(plaza_plan, roof_plan):
    """Return closed triangle stocks; refuse changed fabrication/profile inputs."""
    p, r = plaza_plan, roof_plan
    _need(r.get('schema') == 'orison.v2.arcade-roof-plan.v1', 'roof schema')
    _need(source_digest(p) == r.get('plaza_source_canonical_sha256'), 'plaza source changed')
    _need(r['materials']['roof_glazing'] == p['materials']['glazing'], 'registered glazing changed')
    _need(p['hall_rect_m'] == [0, 0, 25.64, 29.3], 'surveyed hall changed')
    _need(p['source_origin_blender_m'] == [1.18, -38.6, 0.0], 'source frame changed')
    _need(len(p['shops']) == 11 and len({s['id'] for s in p['shops']}) == 11, 'shop inventory')
    _need(r['support_footprint_max_m'] == .12 and 0 < r['column_radius_m'] <= .05,
          'bounded support footprint')
    _need(r['column_sides'] >= 6, 'column profile')
    for profile in [r['nave'], r['court']]:
        _need(7.0 <= profile['spring_m'] < profile['crown_m'] <= 9.9,
              'tall arcade profile')
        _need(profile['arch_segments'] >= 6 and 0 < profile['bay_max_m'] <= 2,
              'incomplete arch/bay profile')
    _need(r['nave']['u_span_m'] == [9.65, 15.99] and r['nave']['v_span_m'] == [0, 29.3],
          'nave coverage changed')
    _need(0 < r['glass_vertical_thickness_m'] <= .02 and
          0 < r['rib_depth_below_m'] <= .2 and 0 < r['rib_depth_above_m'] <= .1 and
          0 < r['rib_width_m'] <= .12, 'roof stock dimensions')
    result, names = [], set()

    def emit(name, owner, material, vertices, faces, role, probe=None):
        _need(name not in names and material in r['materials'], 'duplicate stock or material')
        vertices = [[float(x) for x in v] for v in vertices]
        faces = [list(f) for f in faces]
        if volume(vertices, faces) < 0:
            faces = [[c, b, a] for a, b, c in faces]
        _need(volume(vertices, faces) > 1e-12, 'zero volume: ' + name)
        for a, b, c in faces:
            n = _cross(_sub(vertices[b], vertices[a]), _sub(vertices[c], vertices[a]))
            _need(_dot(n, n) > 1e-22, 'degenerate stock: ' + name)
        stock = dict(name=name, owner=owner, material=material, vertices=vertices,
                     faces=faces, role=role)
        if material == 'roof_glazing':
            _need(probe is not None, 'glass probe missing')
            stock['pane_probe'] = probe
        result.append(stock)
        names.add(name)

    def prism(name, polygon, delta, role, owner='public', material='roof_steel', probe=None):
        n = len(polygon)
        vertices = polygon + [_add(v, delta) for v in polygon]
        faces = []
        for i in range(1, n-1):
            faces += [[0, i+1, i], [n, n+i, n+i+1]]
        for i in range(n):
            j = (i+1) % n
            faces += [[i, j, n+j], [i, n+j, n+i]]
        emit(name, owner, material, vertices, faces, role, probe)

    def box(name, rect, low, high, role, owner='public', material='roof_steel'):
        a, b, c, d = rect
        _need(c > a and d > b and high > low, 'invalid box ' + name)
        prism(name, [[a,b,low],[c,b,low],[c,d,low],[a,d,low]], [0,0,high-low],
              role, owner, material)

    def beam(name, a, b, width, depth, role, material='roof_steel', owner='public', width_axis=None):
        axis = _unit(_sub(b, a))
        side = _unit(width_axis) if width_axis is not None else _unit(_cross(axis, [0,0,1] if abs(axis[2]) < .9 else [1,0,0]))
        _need(abs(_dot(axis,side)) < 1e-9, 'beam width must be perpendicular')
        up = _unit(_cross(side, axis))
        ring = [_add(a, [side[i]*width*x/2 + up[i]*depth*y/2 for i in range(3)])
                for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        prism(name, ring, _sub(b,a), role, owner, material)

    def cylinder(name, u, v, low, high, radius, role, material='roof_iron', sides=None):
        n = sides or r['column_sides']
        ring = [[u+radius*math.cos(2*math.pi*i/n),v+radius*math.sin(2*math.pi*i/n),low]
                for i in range(n)]
        prism(name, ring, [0,0,high-low], role, material=material)

    def support(name, u, v, spring, forward):
        box(name+'_plate', [u-.06,v-.06,u+.06,v+.06], 0,.018, 'support_baseplate')
        cylinder(name+'_foot',u,v,.018,.18,.055,'support_cast_foot')
        cylinder(name+'_shaft',u,v,.12,spring-.08,r['column_radius_m'],'support_column')
        cylinder(name+'_collar',u,v,spring-.25,spring-.12,.055,'support_collar')
        # End capitals broaden above openings, clipped to their measured prism.
        vf,vb = (0,29.3) if name.startswith('Nave') else (p['court_rect_m'][1],p['court_rect_m'][3])
        box(name+'_capital',[u-.12,max(vf,v-.12),u+.12,min(vb,v+.12)],spring-.12,spring,
            'support_capital',material='roof_iron')
        for i,(x,y) in enumerate([(-1,-1),(-1,1),(1,-1),(1,1)]):
            cylinder(name+'_bolt%d'%i,u+x*.037,v+y*.037,.018,.028,.008,
                     'support_fastener',material='roof_steel',sides=6)
        # A real diagonal knee connects the post to the longitudinal eave girder.
        beam(name+'_knee',[u,v,spring-.85],[u,v+forward*.7,spring-.04],.04,.06,
             'support_bracket',material='roof_iron')

    z = r['shop_roof']
    _need(abs(z['ceiling_bottom_m'] + z['ceiling_thickness_m'] - p['wall_height_m']) < 1e-10
          and p['wall_height_m'] == 3.3 and
          z['joist_depth_m'] > 0 and 0 < z['joist_width_m'] <= .12 and
          0 < z['joist_max_pitch_m'] <= .75 and
          all(0 < z[k] <= .06 for k in ['ceiling_thickness_m','deck_thickness_m','bitumen_thickness_m']),
          'shop ceiling profile')
    ceiling_top = p['wall_height_m']
    deck_bottom = ceiling_top + z['joist_depth_m']
    deck_top = deck_bottom + z['deck_thickness_m']
    roof_top = deck_top + z['bitumen_thickness_m']

    def low_roof(name, rect, owner):
        a,b,c,d = rect
        box(name+'_ceiling',rect,z['ceiling_bottom_m'],ceiling_top,'shop_ceiling' if owner!='public' else 'public_side_ceiling',owner,'roof_ceiling')
        # Full-span joists bear on both outer walls; ends remain within the slab.
        count = max(1,math.ceil((d-b-z['joist_width_m'])/z['joist_max_pitch_m']))
        for i in range(count+1):
            y=b+z['joist_width_m']/2+(d-b-z['joist_width_m'])*i/count
            box(name+'_joist%02d'%i,[a,y-z['joist_width_m']/2,c,y+z['joist_width_m']/2],
                ceiling_top,deck_bottom,'shop_joist',owner,'roof_timber')
        # Continuous rim stocks explain the joist end bearings/closure.
        for suffix,rr in [('w',[a,b,a+.06,d]),('e',[c-.06,b,c,d])]:
            box(name+'_rim_'+suffix,rr,ceiling_top,deck_bottom,'roof_rim',owner,'roof_timber')
        box(name+'_deck',rect,deck_bottom,deck_top,'roof_deck',owner,'roof_timber')
        box(name+'_bitumen',rect,deck_top,roof_top,'weather_roof',owner,'roof_bitumen')

    for shop in p['shops']:
        low_roof(shop['id'],shop['rect_m'],shop['id'])
    low_roof('WestPublicAlcove',[0,18.8,9.65,22.3],'public')
    low_roof('EastPublicCross',[15.99,20.3,25.64,22.3],'public')

    def elevation(u, span, profile):
        a,b=span
        t=(2*u-a-b)/(b-a)
        return profile['spring_m']+(profile['crown_m']-profile['spring_m'])*math.sqrt(max(0,1-t*t))

    def stations(a,b,maximum):
        n=math.ceil((b-a)/maximum)
        return [a+(b-a)*i/n for i in range(n+1)]

    def sheet(name, polygon, delta, role):
        n=_unit(_cross(_sub(polygon[1],polygon[0]),_sub(polygon[2],polygon[0])))
        centre=[sum(v[i] for v in polygon)/len(polygon)+delta[i]/2 for i in range(3)]
        prism(name,polygon,delta,role,material='roof_glazing',
              probe={'centre':centre,'normal':n})

    def vault(name, span, vspan, profile):
        a,b=span;front,back=vspan
        xs=[a+(b-a)*i/profile['arch_segments'] for i in range(profile['arch_segments']+1)]
        ys=stations(front,back,profile['bay_max_m'])
        for j,(v,w) in enumerate(zip(ys,ys[1:])):
            for i,(u,x) in enumerate(zip(xs,xs[1:])):
                h,k=elevation(u,span,profile),elevation(x,span,profile)
                sheet(name+'_pane%02d_%02d'%(j,i),[[u,v,h],[x,v,k],[x,w,k],[u,w,h]],
                      [0,0,r['glass_vertical_thickness_m']],'vault_glazing')
        for j,y in enumerate(ys):
            # Keep frame depth in the measured prism at terminal edges.
            v=max(front,min(back-r['rib_width_m'],y-r['rib_width_m']/2))
            for i,(u,x) in enumerate(zip(xs,xs[1:])):
                h,k=elevation(u,span,profile),elevation(x,span,profile)
                prism(name+'_rib%02d_%02d'%(j,i),
                      [[u,v,h-r['rib_depth_below_m']],[x,v,k-r['rib_depth_below_m']],
                       [x,v,k+r['rib_depth_above_m']],[u,v,h+r['rib_depth_above_m']]],
                      [0,r['rib_width_m'],0],'arch_rib')
        for i,u in enumerate(xs):
            h=elevation(u,span,profile)
            # Square-section purlins sit inside end bounds, with pane contact.
            x=max(a+.025,min(b-.025,u))
            box(name+'_purlin%02d'%i,[x-.025,front,x+.025,back],h-.025,h+.025,'roof_purlin')
        for side,u in [('w',a+.05),('e',b-.05)]:
            box(name+'_eave_'+side,[u-.05,front,u+.05,back],profile['spring_m']-.08,
                profile['spring_m']+.04,'eave_girder')
        return xs,ys

    nave=r['nave'];court=r['court']
    nx,ny=vault('Nave',nave['u_span_m'],nave['v_span_m'],nave)
    ca,cf,cb,cr=p['court_rect_m']
    cx,cy=vault('Court',[ca,cb],[cf,cr],court)

    # Narrow neck is a continuous loft from the wide court profile to the nave.
    # Every station uses the SAME polygonal profiles as its receiving vault.
    def linear_profile(u,xs,span,profile):
        for a,b in zip(xs,xs[1:]):
            if a-1e-10<=u<=b+1e-10:
                t=(u-a)/(b-a)
                return elevation(a,span,profile)*(1-t)+elevation(b,span,profile)*t
        raise ValueError('profile outside receiver')

    na,nf,nb,nr=p['court_join_rect_m']
    # Include court breakpoints as well as nave's: no chord/diagonal crack.
    neck_x=sorted(set(nx+[x for x in cx if na<x<nb]))
    for i,(u,x) in enumerate(zip(neck_x,neck_x[1:])):
        a,b=[linear_profile(t,cx,[ca,cb],court) for t in [u,x]]
        c,d=[linear_profile(t,nx,nave['u_span_m'],nave) for t in [u,x]]
        sheet('Neck_pane%02d'%i,[[u,nf,a],[x,nf,b],[x,nr,d],[u,nr,c]],
              [0,0,r['glass_vertical_thickness_m']],'neck_weather_glazing')
        # Metal seam caps follow each profile edge, receiving every neck pane.
        seam_u=max(na+.02,min(nb-.02,u))
        # Closely spaced court/nave breakpoints create two 16.7 mm panels.
        # Size their seam caps to the adjacent real stock, rather than bury
        # the complete narrow pane under two overlapping 25 mm metal strips.
        adjacent = [x-u]
        if i: adjacent.append(u-neck_x[i-1])
        seam_width = min(.025, .35*min(adjacent))
        beam('Neck_seam%02d'%i,[seam_u,nf+.04,a],[seam_u,nr-.04,c],seam_width,.035,'neck_seam',width_axis=[1,0,0])
    for side,u in [('w',na),('e',nb)]:
        h=linear_profile(u,cx,[ca,cb],court);k=linear_profile(u,nx,nave['u_span_m'],nave)
        # Side infill seals the triangular height change, above all circulation.
        sheet('Neck_side_'+side,[[u,nf,roof_top],[u,nr,roof_top],[u,nr,k],[u,nf,h]],
              [.008 if side=='w' else -.008,0,0],'neck_side_glazing')

    def clerestory(name,u,front,back,spring,inward):
        ys=stations(front,back,1.9)
        for j,(a,b) in enumerate(zip(ys,ys[1:])):
            sheet(name+'_pane%02d'%j,[[u,a,roof_top],[u,b,roof_top],[u,b,spring],[u,a,spring]],
                  [inward*.008,0,0],'clerestory_glazing')
        for j,y in enumerate(ys):
            # Mullions stay inside the explicit source rectangle.
            v=max(front,min(back-.035,y-.0175))
            box(name+'_mullion%02d'%j,[u if inward>0 else u-.035,v,u+.035 if inward>0 else u,v+.035],
                roof_top,spring,'clerestory_mullion')
        box(name+'_sill',[u if inward>0 else u-.05,front,u+.05 if inward>0 else u,back],
            roof_top-.025,roof_top+.025,'clerestory_sill')

    clerestory('NaveWest',9.65,0,29.3,nave['spring_m'],1)
    clerestory('NaveEast',15.99,0,29.3,nave['spring_m'],-1)
    clerestory('CourtWest',ca,cf,cr,court['spring_m'],1)
    clerestory('CourtEast',cb,cf,cr,court['spring_m'],-1)

    def gable(name,y,xs,span,profile,skip=None):
        # Explicit breaks around the neck opening retain weather continuity.
        xx=sorted(set(xs+([] if skip is None else list(skip))))
        for i,(a,b) in enumerate(zip(xx,xx[1:])):
            if skip and skip[0]<=a and b<=skip[1]:continue
            h=linear_profile(a,xs,span,profile);k=linear_profile(b,xs,span,profile)
            sheet(name+'_glass%02d'%i,[[a,y,roof_top],[b,y,roof_top],[b,y,k],[a,y,h]],
                  [0,.008 if y<0 else -.008,0],'gable_glazing')
        beam(name+'_sill',[span[0],y,roof_top],[span[1],y,roof_top],.04,.05,'gable_sill')

    # Front court remains open below the high screen: both route directions clear.
    gable('CourtFront',cf+.025,cx,[ca,cb],court)
    gable('CourtRear',cr-.025,cx,[ca,cb],court,(na,nb))
    gable('NaveRear',29.275,nx,nave['u_span_m'],nave)
    # At the neck/nave seam the low gap beneath both roof profiles needs a sill,
    # not a ground-level wall or invented entrance leaf.
    for side,u,ys in [('West',9.59,[.06,5.6,11.7,15.8,18.74,29.24]),
                      ('East',16.05,[.06,6,11.5,15.2,20.24,29.24])]:
        for i,v in enumerate(ys):
            support('Nave'+side+'Support%02d'%i,u,v,nave['spring_m'],1 if i==0 else -1)
        # A continuous vertical-depth girder carries the unequal side bay spacing;
        # rear bay crosses above shop ceilings, never through apparatus at floor.
        box('Nave'+side+'LongitudinalGirder',[u-.035,0,u+.035,29.3],
            nave['spring_m']-.28,nave['spring_m']-.04,'support_longitudinal_girder')
    for side,u in [('West',ca+.12),('East',cb-.12)]:
        for end,v,direction in [('Front',cf+.12,1),('Rear',cr-.12,-1)]:
            support('Court'+side+end,u,v,court['spring_m'],direction)
    # Tie girders physically join court support capitals across both end frames.
    for end,v in [('Front',cf+.12),('Rear',cr-.12)]:
        beam('Court'+end+'Tie',[ca+.12,v,court['spring_m']-.08],
             [cb-.12,v,court['spring_m']-.08],.1,.14,'court_tie_girder')

    # Final hard envelope check includes every bolt/capital, not only roof sheets.
    domains=[p['hall_rect_m'],p['court_rect_m'],p['court_join_rect_m']]
    for stock in result:
        for u,v,h in stock['vertices']:
            _need(math.isfinite(u+v+h) and -.000000001<=h<=10,
                  'height/nonfinite stock '+stock['name'])
            _need(any(a-1e-9<=u<=c+1e-9 and b-1e-9<=v<=d+1e-9 for a,b,c,d in domains),
                  'outside surveyed prisms '+stock['name'])
    return result
