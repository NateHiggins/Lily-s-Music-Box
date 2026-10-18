"""Validate platform-backed public programmes without treating voids as floor."""
import math


def programme_errors(layout, space):
    if not any(k in space for k in ['landing_core','floor_platforms','programme_anchors']):
        return []
    errors = []
    try:
        floor = space['level']
        core = next((s for s in layout['spaces'] if s['id'] == space.get('landing_core')),None)
        if not core or core['level'] != floor or core.get('class') != 'core' or core['id'] != floor+'_PUBLIC_CORE':
            errors.append('existing same-floor public core required')
        if space.get('class') != 'public' or not all(space.get(k) is True for k in ['open_shell','no_floor','no_ceiling']):
            errors.append('open externally supported landing construction required')
        rows = {p['id']:p for p in layout['platforms']}
        ids = space.get('floor_platforms')
        expected = {p for p in rows if p.startswith(floor+'_PUBLIC_LANDING_')}
        if not isinstance(ids,list) or not ids or any(not isinstance(p,str) for p in ids) or len(set(ids)) != len(ids) or set(ids) != expected:
            errors.append('complete unique landing platform ownership required')
            return errors
        rects = [rows[p]['rect'] for p in ids]
        if any(rows[p]['level'] != floor for p in ids):
            errors.append('foreign-floor platform')
        if any(len(r)!=4 or not all(type(v) in (int,float) and math.isfinite(v) for v in r) or r[0]>=r[2] or r[1]>=r[3] for r in rects):
            errors.append('positive finite platform rectangles required')
            return errors
        bounds = [min(r[0] for r in rects),min(r[1] for r in rects),max(r[2] for r in rects),max(r[3] for r in rects)]
        if len(space['rect'])!=4 or any(abs(a-b)>.00001 for a,b in zip(space['rect'],bounds)):
            errors.append('landing envelope differs from physical supports')
        if core:
            c=core['rect']
            if bounds[0]<c[0] or bounds[1]<c[1] or bounds[2]>c[2] or bounds[3]>c[3]:
                errors.append('landing exceeds its core')
        anchors = {a['id']:a for a in layout['anchors']}
        landmarks = space.get('programme_anchors')
        if not isinstance(landmarks,list) or not landmarks or any(not isinstance(a,str) for a in landmarks) or len(set(landmarks))!=len(landmarks):
            errors.append('unique physical landmarks required')
        else:
            for identity in landmarks:
                a=anchors.get(identity,{})
                if a.get('level')!=floor or a.get('space')!=space.get('landing_core') or a.get('kind')!='furniture':
                    errors.append('same-core physical landmark required')
        if floor not in {s.get(k) for s in layout.get('stairs',[]) for k in ['from','to']} | {s.get('level') for s in layout.get('lift_landings',[])}:
            errors.append('existing vertical entrance required')
    except (KeyError,TypeError,ValueError,IndexError,AttributeError) as exc:
        errors.append('malformed landing programme: '+str(exc))
    return errors


def rectangles(layout,space):
    if not any(k in space for k in ['floor_platforms','landing_core','programme_anchors']):
        return [space['rect']]
    if programme_errors(layout,space):
        return []
    return [r['rect'] for r in layout['platforms'] if r['id'] in space['floor_platforms']]


def contains(layout,space,x,z):
    return any(r[0]<=x<=r[2] and r[1]<=z<=r[3] for r in rectangles(layout,space))
