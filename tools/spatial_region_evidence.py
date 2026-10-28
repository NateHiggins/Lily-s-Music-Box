"""Validate genuine played exterior-region evidence; no runtime or human grant."""
import json
import math
import re
from pathlib import Path
import sys
import struct
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
sys.path.insert(0,str(ROOT/'tools'))
from spatial_access_evidence import validate as validate_rooms
from v2_exterior_source import ExteriorSource, vec, apply, add, sub, dot, disc_inside


def literal(text,name):
    match=re.search(rf'^const {name}\s*(?::\s*float)?\s*(?::=|=)\s*([0-9]+(?:\.[0-9]+)?)\s*(?:#.*)?$',text,re.M)
    if not match or float(match[1])<=0:raise ValueError('positive controller literal required: '+name)
    return float(match[1])


def index(value,size):
    if type(value) is not int or not 0<=value<size:raise ValueError('actual trace index required')
    return value


def controller_step_height(text):
    body=re.search(r'^func _try_step_up\([^\n]*\).*?:\n(.*?)(?=^func |\Z)',text,re.M|re.S)
    if not body:raise ValueError('bound controller curb-step source required')
    number=r'(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)'
    token=rf'(?:{number}|[A-Za-z_][A-Za-z_0-9]*)'
    lifted=re.findall(rf'^\s+global_position\.y\s*\+=\s*({token})\s*$',body[1],re.M)
    swept=re.findall(rf'^\s+var lift\s*:=\s*Vector3\.UP\s*\*\s*({token})\s*$',body[1],re.M)
    if len(lifted)!=1 or lifted!=swept:raise ValueError('unique source-bound swept curb-step height required')
    value=lifted[0]
    if not re.fullmatch(number,value):
        # Fixture contacts can request a larger lift. Exterior evidence gets
        # only the ordinary initialized curb height, never that upper bound.
        # A larger observed rise still fails consecutive_motion below.
        initial=re.findall(rf'^\s+var {re.escape(value)}\s*:=\s*({number})\s*$',body[1],re.M)
        if len(initial)!=1:raise ValueError('unique ordinary curb-step initializer required')
        value=initial[0]
    if float(value)<=0:raise ValueError('positive source-bound curb-step height required')
    return float(value)


def consecutive_motion(previous,current,step_height):
    a,b=vec(previous['actual']),vec(current['actual'])
    if current['physics_frame']!=previous['physics_frame']+1:return False
    if math.hypot(b[0]-a[0],b[2]-a[2])>.2:return False
    rise=b[1]-a[1]
    if abs(rise)<=.2:return True
    # The shipping controller directly raises its body by its swept step lift
    # before move_and_slide. This is not a horizontal relocation or missing
    # frame. Only its exact rise and floor transition qualify as an exception.
    return previous.get('on_floor') is True and current.get('on_floor') is False and abs(rise-step_height)<1e-6


def validate_regions(data,root,runtime_digest,surface_digest):
    """No capture, presence flag or source rectangle alone is spatial proof."""
    root=Path(root)
    try:
        errors=validate_rooms(data,root,runtime_digest,surface_digest)
    except (KeyError,TypeError,ValueError,OSError,AttributeError,IndexError,OverflowError) as exc:
        return ['malformed room proof: '+str(exc)]
    if errors:return errors
    try:
        def load(relative):return json.loads((root/relative).read_text(encoding='utf-8'))
        document=load('game/data/orison_v2/exterior/regions.json')
        layout=load('game/data/orison_v2_blockout.json')
        model=ExteriorSource(document)
        basis,origin=model.interior_transform(layout,load('game/data/orison_v2/world_connection.json'))
        player=(root/'game/scripts/player/player_controller.gd').read_text(encoding='utf-8')
        step_height=controller_step_height(player)
        # CapsuleShape3D properties use the engine's 32-bit real representation.
        # Compare its independently quantized source dimensions, allowing only
        # JSON's final decimal rounding, not a smaller test-body tolerance.
        radius,height=(struct.unpack('<f',struct.pack('<f',literal(player,name)))[0] for name in ['BODY_RADIUS','STANDING_HEIGHT'])
        def shape_value(value,expected):
            return type(value) in (int,float) and math.isfinite(value) and abs(value-expected)<1e-14
        contract=data['contracts']['region_access']
        if data['contracts']['teardown'].get('tracked_nodes',0)<3:return ['measured root/driver/observer retirement required']
        if contract.get('executed') is not True or contract.get('status')!='PASS' or contract.get('coordinate_frame')!='orison_blockout_local':return ['executed PASS region access in the authoritative interior frame required']
        claims=contract['regions']
        if not isinstance(claims,dict) or not claims:return ['played region claims required']
        if len(data['legs'])!=1:return ['one continuous exterior leg with one initial placement required']
        legs={leg['name']:leg['trace'] for leg in data['legs']}
        samples={leg['name']:leg['samples'] for leg in data['legs']}
        for name,trace in legs.items():
            observed=samples[name]
            if not isinstance(observed,list) or not observed:raise ValueError('consecutive observed physics samples required')
            previous=None
            for step in observed:
                position=vec(step['actual']);frame=step['physics_frame']
                if type(frame) is not int or frame<0:raise ValueError('actual physics frame required')
                if previous is not None and not consecutive_motion(previous,step,step_height):errors.append('consecutive collision-bearing exterior movement required')
                previous=step
            for step in trace+observed:
                if step.get('noclip') is not False or step.get('collision_mask')!=1 or type(step.get('collision_mask')) is not int or not shape_value(step.get('capsule_radius'),radius) or not shape_value(step.get('capsule_height'),height):errors.append('every exterior waypoint requires the normal standing controller')
            for step in trace:
                if vec(step['actual'])!=vec(observed[index(step['sample_index'],len(observed))]['actual']):errors.append('route endpoint differs from actual physics sample')
        def point(step,field='actual'):return add(origin,apply(basis,vec(step[field])))
        first_node=model.routes['ROUTE_ORISON_TO_SHOP_BODEGA']['nodes'][0]
        initial=model.placement(first_node['owner_instance_id'],first_node['placement_id'])
        actual_initial=point(next(iter(samples.values()))[0])
        if math.hypot(actual_initial[0]-initial[0],actual_initial[2]-initial[2])>=.18 or abs(actual_initial[1]-initial[1])>=.15:
            errors.append('one declared source street placement required before continuous movement')
        for identity,claim in claims.items():
            if identity not in model.regions or claim.get('id')!=identity:
                errors.append('unknown or aliased region identity: '+identity);continue
            instance=model.instances[claim['instance_id']]
            if instance['region_id']!=identity or claim.get('geometry_resident') is not True:
                errors.append('actual owning instance residency required: '+identity);continue
            observed=samples[claim['leg']];step=observed[index(claim['sample_index'],len(observed))]
            if claim.get('on_floor') is not True or step.get('on_floor') is not True or not isinstance(claim.get('floor_collider_path'),str) or not claim['floor_collider_path'].startswith('/root/'):
                errors.append('actual on-floor observation and collider provenance required: '+identity)
            if vec(claim['actual'])!=vec(step['actual']):errors.append('region witness differs from original trace: '+identity)
            actual=point(step)
            if not disc_inside(model.regions[identity]['boundary'],(actual[0],actual[2]),radius):errors.append('full standing capsule lies outside source region: '+identity)
            floor=model.surface(claim['instance_id'],claim['floor_surface_id'])
            if floor['kind']!='walkable' or floor['normal'][1]<.999 or abs(actual[1]-floor['point'][1])>=.15:errors.append('actual source floor height required: '+identity)
            offset=sub(actual,floor['point'])
            if any(abs(dot(offset,floor[axis]))+radius+.005>floor['size_m'][i]/2 for i,axis in enumerate(['u_axis','v_axis'])):errors.append('full capsule requires the actual authored floor surface: '+identity)
        routes=contract['routes']
        required={identity for identity,route in model.routes.items() if set(route['region_ids'])&claims.keys()}
        if not isinstance(routes,dict) or not required<=routes.keys() or not routes.keys()<=model.routes.keys():errors.append('all authored routes serving claimed regions required')
        for identity,claim in routes.items():
            route=model.routes[identity];nodes=claim['nodes']
            if len(nodes)!=len(route['nodes']):errors.append('complete source route node roster required: '+identity);continue
            trace=legs[claim['leg']];last=-1
            for source_node,observed in zip(route['nodes'],nodes):
                i=index(observed['trace_index'],len(trace))
                if i<=last or observed.get('id')!=source_node['id']:errors.append('ordered original source route indices required: '+identity)
                last=i
                expected=model.placement(source_node['owner_instance_id'],source_node['placement_id'])
                if math.dist(point(trace[i],'target'),expected)>1e-5:errors.append('played target differs from authoritative route placement: '+identity)
        controls=contract['threshold_controls']
        threshold_ids={t for identity in required for t in model.routes[identity]['threshold_ids']}
        if not isinstance(controls,dict) or set(controls)!=threshold_ids:return errors+['exact source route threshold roster required']
        for threshold_id in threshold_ids:
            source=model.thresholds[threshold_id];actions=controls.get(threshold_id,[])
            if not actions:errors.append('actual threshold manipulation required: '+threshold_id)
            for action in actions:
                angle,stop,before=action['actual_angle'],action['stop_angle'],action['before_angle']
                if action.get('owner_id')!=source['interactive_leaf_id'] or action.get('kind')!='grab_mouse_release' or any(action.get(field) is not True for field in ['released','follows_cursor','ready_for_passage']):errors.append('real source threshold grab/motion/release required: '+threshold_id)
                if any(type(value) not in (int,float) or not math.isfinite(value) for value in [angle,stop,before]) or abs(stop)<.5 or abs(angle-stop)>.01 or abs(angle-before)<.5:errors.append('physical threshold must actually move to its stop: '+threshold_id)
                observed=samples[action['leg']]
                first=index(action['before_sample_index'],len(observed));last=index(action['after_sample_index'],len(observed))
                if first>=last:errors.append('ordered original threshold manipulation samples required: '+threshold_id)
    except (KeyError,TypeError,ValueError,OSError,AttributeError,IndexError,OverflowError) as exc:
        errors.append('malformed region proof: '+str(exc))
    return errors
