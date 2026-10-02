"""Shared dimensions for the bodega's independent electrical service fabric.

The existing registered shop and fitted receiving room supply every datum.
The inlet ends at this building's concealed property boundary. It does not
assert a municipal route, connect to Orison, or create an electrical control.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def dimensions():
    document = json.loads((ROOT/'game/data/orison_v2/exterior/exterior_geometry.json').read_text())
    shop = next(row for row in document['templates'] if row['id']=='TEMPLATE_BODEGA_CELL_V1')
    boxes = {row['id']: row for row in shop['boxes']}
    floor = boxes['shop_floor']
    start = floor['position_m'][2] - floor['size_m'][2]/2
    end = start-2.0
    partition = boxes['back_wall_right']
    x = partition['position_m'][0]
    ceiling = boxes['shop_ceiling']['position_m'][1]-boxes['shop_ceiling']['size_m'][1]/2
    height = ceiling-.05
    assert partition['yaw_degrees']==0 and partition['size_m'][1]>height+.025
    fittings = {name: boxes['ceiling_practical_'+name] for name in ['front','middle','back']}
    endpoints = {name: [row['size_m'][0]/2-.075,
        row['position_m'][1]+row['size_m'][1]/2-.005, row['position_m'][2]]
        for name,row in fittings.items()}
    # Side connection enters the right face of the existing ceiling casting.
    endpoints['receiving'] = [.735,3.10,end+1.13]
    return dict(start=start,end=end,half=floor['size_m'][0]/2,x=x,
        height=height,ceiling=ceiling,box=[x,1.70,end+.065],
        rear_port=[x,1.70,end-.08],partition_port=[x,height,partition['position_m'][2]],
        endpoints=endpoints)
