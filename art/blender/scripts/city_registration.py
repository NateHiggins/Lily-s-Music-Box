"""Derive city assembly registration from unchanged authored construction."""
import re

def derive_city_offsets(layout, v2, regions):
    rows=next(row for row in layout['floors'] if row['id']=='F01')['furniture']
    spaces={r['id']:r for r in v2['spaces']}
    instance=next(r for r in regions['instances'] if r['semantic_identity']=='SHOP_BODEGA')
    street=next(r for r in regions['surface_templates'] if r['id']=='TEMPLATE_STREET_SEGMENT_V1')
    pavement=next(r for r in street['surfaces'] if r['id']=='pavement')
    east=float(pavement['point_m'][0])+float(instance['offset_uvn_m'][0])-17.4
    west=-(spaces['F01_D_MAIN']['rect'][2]+2.35+.24+.08)-.08-(-15.2)
    ne=[r for r in rows if re.match(r'^site_ne\d+_',r['id']) and 'rect' in r and not r['id'].endswith('_beacon')]
    region=next(r for r in regions['regions'] if r['id']=='REGION_STREET')
    northeast=max(p[0] for p in region['boundary'])+.08-min(r['rect'][0] for r in ne)
    result={'site_nbr_e':east,'site_nbr_w':west}
    result.update({re.match(r'^(site_nw\d+)_',r['id']).group(1):west for r in rows if re.match(r'^site_nw\d+_',r['id'])})
    result.update({re.match(r'^(site_ne\d+)_',r['id']).group(1):northeast for r in ne})
    far=[r for r in rows if r['id'].startswith('site_far_sw_') and 'rect' in r and not r['id'].endswith('_beacon')]
    near=[r for r in rows if r['id'].startswith('site_sw3_') and 'rect' in r and not r['id'].endswith('_beacon')]
    # Keep every source dimension. Separate complete worked assembly envelopes,
    # allowing the two half-wall footing margins plus the existing 80 mm joint.
    clearance=float(v2['dimensions']['outer_wall'])+.08
    result['site_far_sw']=min(r['rect'][0] for r in near)-clearance-max(r['rect'][2] for r in far)
    return result
