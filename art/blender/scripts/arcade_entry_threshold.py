"""Source-owned walkable transition from the original pavement to the new court."""

import math


def build(layout, plan, street):
    floor, = [f for f in layout["floors"] if f["id"] == "F01"]
    aisle, = [r for r in floor["furniture"] if r["id"] == "site_passage_aisle_floor"]
    pavement, = [r for r in floor["furniture"] if r["id"] == "site_sidewalk_s_w"]
    west, _, east, north = aisle["rect"]
    entry_z = -north
    source_x, source_y, source_height = plan["source_origin_blender_m"]
    court_x0, court_v0, court_x1, _ = plan["court_rect_m"]
    entry_v = entry_z + source_y
    if not math.isclose(entry_z, street["arcade_building_line_z"] + street["source_threshold_z"], abs_tol=1e-8):
        raise ValueError("Original aisle and registered street line disagree")
    if pavement["rect"][1] != north or not pavement["rect"][0] <= west < east <= pavement["rect"][2]:
        raise ValueError("Missing continuous pavement receiver")
    if not court_x0 <= west-source_x < east-source_x <= court_x1 or not entry_v < court_v0:
        raise ValueError("Court edge does not accept the full old aisle")
    top = pavement["z0"] + pavement["h"]
    if not math.isclose(top, aisle["z0"]+aisle["h"], abs_tol=1e-8) or not 0 < top <= .02:
        raise ValueError("Original pavement/aisle bearing changed")
    # The foot of the stock uses the court foundation base. The top is a
    # single planar transition from original .01 m pavement to the new deck.
    bottom = source_height - plan["floor_slab_m"]
    world = [(x, z, y) for y0, y1 in ((bottom,bottom),(top,source_height))
             for z,y in ((entry_z,y0),(court_v0-source_y,y1)) for x in (west,east)]
    return {
        "name": "ArcadeGatewayThreshold",
        "source_rows": {"aisle": aisle, "pavement": pavement},
        "godot_vertices": [(x,y,z) for x,z,y in world],
        "faces": [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],
        "surfaces": {"street_edge_z": entry_z, "court_edge_z": court_v0-source_y,
                     "street_height": top, "court_height": source_height},
    }
