"""Pure fixed pavement hatch stocks and shallow public-finish receivers.

PLAN coordinates (u,v,height) only. The existing native producer applies the
source origin once and owns materials, UVs, export, installation and evidence.
No interaction, lock, cellar passage, delivery service or News hatch is added.
"""
import copy
import hashlib
import json
import math

# Five retained original source identities, never the News counter service hatch.
HATCHES = (
    ('storm_sf_model_laundry_hatch','shop_model_laundry',(1.1,21.25,2.4,22.15),'PublicFloor_02',90),
    ('storm_sf_luncheonette_hatch','shop_luncheonette',(23.,21.25,24.3,22.15),'PublicFloor_02',90),
    ('storm_sf_shoe_rebuilding_hatch','shop_shoe_rebuilding',(9.8,6.6,10.7,7.9),'PublicFloor_00',0),
    ('storm_sf_funeral_parlour_hatch','shop_funeral_parlour',(9.8,.6,10.7,1.9),'PublicFloor_00',0),
    ('storm_sf_photo_supplies_hatch','shop_photo_supplies',(14.94,.65,15.84,1.95),'PublicFloor_00',0),
)
SOURCE_RECTS = {
    'storm_sf_model_laundry_hatch':[11.7,-41.1,12.6,-39.800000000000004],
    'storm_sf_luncheonette_hatch':[15.4,-43.8,16.3,-42.5],
    'storm_sf_shoe_rebuilding_hatch':[11.7,-46.7,12.6,-45.4],
    'storm_sf_funeral_parlour_hatch':[11.7,-61.3,12.6,-60.0],
    'storm_sf_photo_supplies_hatch':[15.4,-63.39999999999999,16.3,-62.099999999999994],
}
FLOOR_RECTS = {'PublicFloor_00':[9.65,0,15.99,20.3], 'PublicFloor_02':[0,20.3,25.64,22.3]}
DEPTH = .004


def public_top_uv(source_floor, point, origin):
    """Keep the original whole-floor metre chart across new shallow receivers.

    Blender coordinates and UV convention, before glTF's V flip. Recharting
    every cut island independently would shift terrazzo by fractional tiles.
    """
    _need(source_floor in FLOOR_RECTS, 'unknown original public floor')
    x0, y0, x1, y1 = FLOOR_RECTS[source_floor]
    return [point[0] - math.floor(origin[0] + x0),
            point[1] - math.floor(origin[1] - y1)]
FACES = [(0,2,3),(0,3,1),(4,5,7),(4,7,6),(0,1,5),(0,5,4),
         (1,3,7),(1,7,5),(2,6,7),(2,7,3),(0,4,6),(0,6,2)]


def _need(ok,message):
    if not ok:raise ValueError(message)


def _digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()


def _rect(value):
    _need(isinstance(value,(list,tuple)) and len(value)==4 and all(type(v)in(int,float)and math.isfinite(v)for v in value),'finite rectangle required')
    _need(value[2]>value[0]and value[3]>value[1],'positive rectangle required')
    return list(value)


def area(rect):return(rect[2]-rect[0])*(rect[3]-rect[1])


def _intersection(a,b):
    r=[max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])]
    return r if r[2]>r[0]and r[3]>r[1]else None


def _inside(a,b):return a[0]>=b[0]and a[1]>=b[1]and a[2]<=b[2]and a[3]<=b[3]


def _subtract(rect,cut):
    overlap=_intersection(rect,cut)
    if overlap is None:return[list(rect)]
    x0,y0,x1,y1=rect;a,b,c,d=overlap
    return[r for r in [[x0,y0,a,y1],[c,y0,x1,y1],[a,y0,c,b],[a,d,c,y1]]if r[2]>r[0]and r[3]>r[1]]


def volume(stock):
    origin=stock['vertices'][0];result=0.
    for a,b,c in stock['faces']:
        p,q,r=[[stock['vertices'][i][j]-origin[j]for j in range(3)]for i in(a,b,c)]
        result+=(p[0]*(q[1]*r[2]-q[2]*r[1])+p[1]*(q[2]*r[0]-q[0]*r[2])+p[2]*(q[0]*r[1]-q[1]*r[0]))/6
    return result


def _box(name,owner,material,rect,bottom,top,**metadata):
    rect=_rect(rect);_need(type(bottom)in(int,float)and type(top)in(int,float)and math.isfinite(bottom)and math.isfinite(top)and top>bottom,'positive finite stock height required')
    x0,y0,x1,y1=rect
    row=dict(metadata,name=name,owner=owner,material=material,plan_rect_m=rect,bottom_m=bottom,top_m=top,
             vertices=[[x,y,z]for z in[bottom,top]for y in[y0,y1]for x in[x0,x1]],faces=[list(f)for f in FACES],
             area_m2=area(rect),closed_volume_m3=area(rect)*(top-bottom))
    _need(abs(volume(row)-row['closed_volume_m3'])<1e-10,'closed stock volume differs')
    return row


def _cuts():
    return[dict(source_record_id=identity,floor_stock_name=floor,plan_rect_m=list(rect),bottom_m=-DEPTH,top_m=0.,cut_depth_m=DEPTH,
                floor_plan_rect_m=list(FLOOR_RECTS[floor]),finish_bottom_m=-.04,finish_top_m=0.,
                role='SHALLOW_CLOSED_HATCH_RECEIVER_NOT_CELLAR_OPENING')for identity,cell,rect,floor,yaw in HATCHES]


def _validate_cuts(cuts):
    expected={row[0]:(list(row[2]),row[3])for row in HATCHES}
    _need(isinstance(cuts,list)and len(cuts)==5,'exact five hatch cuts required')
    _need(len({c['source_record_id']for c in cuts})==5 and {c['source_record_id']for c in cuts}==set(expected),'missing/duplicate/foreign hatch cut identity')
    for c in cuts:
        _rect(c['plan_rect_m']);_rect(c['floor_plan_rect_m'])
        _need((c['plan_rect_m'],c['floor_stock_name'])==expected[c['source_record_id']],'named hatch receiver placement changed')
        _need(c['floor_stock_name']in FLOOR_RECTS,'foreign public floor receiver')
        _need(c['cut_depth_m']==DEPTH and c['bottom_m']==-DEPTH and c['top_m']==0.,'hatch cut depth/top changed')
        _need(c['finish_top_m']==0. and c['finish_bottom_m']==-.04 and c['finish_bottom_m']<c['bottom_m'],'through-floor or changed finish bounds')
        _need(c['floor_plan_rect_m']==FLOOR_RECTS[c['floor_stock_name']],'public floor footprint changed')
        _need(_inside(c['plan_rect_m'],c['floor_plan_rect_m']),'hatch cut outside public finish')
    for i,a in enumerate(cuts):
        for b in cuts[i+1:]:_need(_intersection(a['plan_rect_m'],b['plan_rect_m'])is None,'hatch cuts overlap')
    for c in cuts:
        rect,floor=expected[c['source_record_id']]
        _need(c['plan_rect_m']==rect and c['floor_stock_name']==floor,'measured hatch cut anchor changed')
    return cuts


def cut_public_floor(stock,floor_cuts=None):
    """Return closed rectangular pieces; unrelated stocks remain exact copies.

    Input needs name/owner/material/plan_rect_m/bottom_m/top_m. Existing geometry
    and identity metadata may also be supplied. Only PublicFloor_00/_02 change.
    Optional cuts are the complete five-row build() output, never new authority.
    """
    source=copy.deepcopy(stock)
    if source.get('name')not in FLOOR_RECTS:return[source]
    cuts=_validate_cuts(copy.deepcopy(_cuts()if floor_cuts is None else floor_cuts))
    _need(source.get('owner')=='public'and source.get('material')=='public_floor','public finish owner/material changed')
    rect=_rect(source.get('plan_rect_m'));_need(rect==FLOOR_RECTS[source['name']],'public finish footprint changed')
    _need(source.get('bottom_m')==-.04 and source.get('top_m')==0.,'public finish vertical bounds changed')
    own=[c for c in cuts if c['floor_stock_name']==source['name']];regions=[rect]
    for cut in own:regions=[piece for region in regions for piece in _subtract(region,cut['plan_rect_m'])]
    metadata={k:copy.deepcopy(v)for k,v in source.items()if k not in{'name','owner','material','plan_rect_m','bottom_m','top_m','vertices','faces','area_m2','closed_volume_m3'}}
    metadata.update(source_stock_name=source['name'],source_stock_snapshot=source,source_stock_sha256=_digest(source))
    result=[]
    for i,region in enumerate(regions):
        result.append(_box(source['name']+'__hatch_outside_%02d'%i,source['owner'],source['material'],region,source['bottom_m'],source['top_m'],**metadata,hatch_cut_role='UNCHANGED_FULL_DEPTH_FINISH'))
    for cut in own:
        result.append(_box(source['name']+'__receiver_'+cut['source_record_id'],source['owner'],source['material'],cut['plan_rect_m'],source['bottom_m'],cut['bottom_m'],**metadata,hatch_cut_role='TRUE_BOTTOM_SUPPORT',receives_source_record_id=cut['source_record_id']))
    _need(abs(sum(r['area_m2']for r in result)-area(rect))<1e-9,'public floor footprint coverage changed')
    for i,a in enumerate(result):
        for b in result[i+1:]:_need(_intersection(a['plan_rect_m'],b['plan_rect_m'])is None,'public floor pieces overlap')
    expected=area(rect)*(source['top_m']-source['bottom_m'])-sum(area(c['plan_rect_m'])*c['cut_depth_m']for c in own)
    _need(abs(sum(volume(r)for r in result)-expected)<1e-9,'public floor cut volume differs')
    return result


def build(layout,plaza):
    """Return five fixed native stocks, exact source proof and finish-only cuts."""
    before=(_digest(layout),_digest(plaza))
    floors=[f for f in layout.get('floors',[])if f.get('id')=='F01'];_need(len(floors)==1,'unique original F01 required')
    records={}
    for record in floors[0]['furniture']:records.setdefault(record['id'],[]).append(record)
    _need(plaza.get('source_origin_blender_m')==[1.18,-38.6,0.0],'source origin changed')
    _need(plaza.get('finish_layer_m')==.04,'public finish layer changed')
    _need(plaza.get('front_frame_clear_m')==2.0 and plaza.get('door_height_m')==2.3,'paired doorway dimensions changed')
    public=plaza.get('public_floor_rects_m',[])
    _need(len(public)>=3 and public[0]==FLOOR_RECTS['PublicFloor_00']and public[2]==FLOOR_RECTS['PublicFloor_02'],'public finish receiver names/rectangles changed')
    shops={s['id']:s for s in plaza['shops']};_need(len(shops)==11,'eleven unique shop owners required')
    stocks=[];proof=[]
    for identity,cell,rect,receiver,yaw in HATCHES:
        _need(len(records.get(identity,[]))==1,'missing/duplicate original hatch: '+identity)
        source=records[identity][0]
        expected=dict(id=identity,rect=SOURCE_RECTS[identity],z0=.006,h=.004,mat='metal',batch=cell,zone='PASSAGE')
        _need(source==expected,'literal original hatch record changed: '+identity)
        shop=shops[cell];along=[rect[0],rect[2]]if yaw==90 else[rect[1],rect[3]]
        interval=shop['frontage']['display_clear_interval_m']
        _need(interval[0]<=along[0]<along[1]<=interval[1],'hatch leaves display bay')
        _need((shop['front']=='north')==(yaw==90),'hatch orientation/frontage changed')
        _need(all(abs(a-b)<1e-12 for a,b in zip(sorted([rect[2]-rect[0],rect[3]-rect[1]]),[.9,1.3])),'original hatch width/length changed')
        row=_box(identity,cell,'metal',rect,-DEPTH,0.,role='fixed_passive_pavement_delivery_hatch',source_record_id=identity,source_record=copy.deepcopy(source),source_record_sha256=_digest(source),
                 source_material='metal',original_gltf_material_name='M_metal_b',source_dimensions_m=[.9,1.3,DEPTH],orientation_yaw_deg=yaw,
                 receiver_floor_stock=receiver,interactive=False,disposal_authorized=False,
                 finish_upgrade='EXPLICIT_REGISTERED_METAL_GRAPHICS_UPGRADE_NOT_ORIGINAL_BAKED_PIXEL_EQUIVALENCE')
        stocks.append(row);proof.append(dict(source_id=identity,owner=cell,source_record=copy.deepcopy(source),source_record_sha256=_digest(source),
                                             target_rect_m=list(rect),bottom_m=-DEPTH,top_m=0.,rotation_about_height_deg=yaw,receiving_floor_stock=receiver))
    cuts=_validate_cuts(_cuts())
    for floor in FLOOR_RECTS:
        cut_public_floor(dict(name=floor,owner='public',material='public_floor',plan_rect_m=FLOOR_RECTS[floor],bottom_m=-.04,top_m=0.),cuts)
    _need((_digest(layout),_digest(plaza))==before,'input mutated')
    return dict(stocks=stocks,floor_cuts=cuts,proof=dict(evidence_class='INERT',classification='PURE_SOURCE_GEOMETRY_NOT_INSTALLED_OR_ART_ACCEPTED',
                source_layout_canonical_sha256=before[0],plaza_canonical_sha256=before[1],source_records=proof,
                counts=dict(hatches=5,hatch_triangles=60),materials={'metal':dict(catalog_key='metal',tint=[1,1,1,1],pigment=1.,normal=.18,roughness=1.)},
                receiving_depth_m=DEPTH,receiving_floor_top_m=-DEPTH,cap_top_m=0.,
                limits='Five fixed representations only; no cellar passage/delivery/lock/News changes. Registered metal is an explicit graphics upgrade, not original M_metal_b pixel equivalence. Floor receiver/contact/material/mipmap/art still require native/runtime intake.'))
