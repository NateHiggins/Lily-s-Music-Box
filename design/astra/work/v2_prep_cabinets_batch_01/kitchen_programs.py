"""Reconcile all four detailed kitchens against installed runtime source owners."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def build():
    layout = load("game/data/orison_v2_blockout.json")
    anchors = {r["id"]: r for r in layout["anchors"]}
    furniture = load("game/data/orison_v2/domestic_furniture.json")["furniture"]
    fittings = load("game/data/orison_v2/domestic_fittings.json")["fittings"]
    programs = []
    for unit in ["2A", "2B", "3B", "4B"]:
        room = "F0" + unit[0] + "_" + unit[1] + "_KITCHEN"
        owners = {}
        for category, rows in [("fitting", fittings), ("furniture", furniture)]:
            for record in rows:
                if anchors[record["id"]]["space"] != room:
                    continue
                kind = record["kind"]
                assert kind not in owners, ("duplicate kitchen role", unit, kind)
                owners[kind] = dict(id=record["id"], source_owner=category)
                if category == "fitting":
                    assert record["unit"] == unit
        assert {"sink", "stove", "fridge", "cupboard", "prep_cabinet"} <= owners.keys(), unit
        prep = next(r for r in furniture if r["id"] == owners["prep_cabinet"]["id"])
        assert prep["mechanism"] == {"unit": unit}
        programs.append(dict(unit=unit, room=room, installed_roles=owners,
                             legacy_aggregate=unit + "_k" if unit != "4B" else None,
                             disposition="Role coverage replaced by separate working fittings, upper cupboard and dry preparation cabinet. Legacy lower aggregate mesh is not installed.",
                             runtime_status="NOT_RUN"))
    result = dict(status="SOURCE_ROLE_ROSTERS_COMPLETE_RUNTIME_PENDING", godot="NOT_RUN", kitchens=programs,
                  limits="Role coverage does not establish cooking, usable inventory, plumbing topology, saved cabinet state, complete apartment content or physical/visual acceptance. Raw legacy assembly omissions remain listed in apartment_inventory.json.")
    (OUT / "kitchen_programs.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: all four kitchen rosters include sink, stove, fridge, upper cupboard and operable prep cabinet")


if __name__ == "__main__":
    build()
