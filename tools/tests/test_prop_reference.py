"""Fixture tests for tools/prop_reference. No network; every red is demonstrated."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.prop_reference import commons, manifest as mf, priority, sheets  # noqa: E402
from tools.prop_reference.brief import render_brief  # noqa: E402


def _page(pageid, title, licence, mime="image/jpeg", w=1200, h=900, index=1):
    return {
        "pageid": pageid, "title": title, "index": index,
        "imageinfo": [{
            "url": f"https://upload.example/{pageid}.jpg",
            "thumburl": f"https://upload.example/{pageid}-800.jpg",
            "descriptionurl": f"https://commons.example/wiki/{title}",
            "mime": mime, "width": w, "height": h,
            "extmetadata": {"LicenseShortName": {"value": licence},
                            "Artist": {"value": "<a href='x'>Someone</a>"},
                            "Credit": {"value": "Own work"},
                            "ImageDescription": {"value": "A <b>thing</b>"}},
        }],
    }


class LicenceTests(unittest.TestCase):
    def test_permissive_licences_pass(self):
        for name in ["Public domain", "CC BY-SA 3.0", "CC BY 2.0", "CC0", "PD-old",
                     "No restrictions", "CC BY-SA 4.0", "cc-by-sa-2.5"]:
            self.assertTrue(commons.licence_allowed(name), name)

    def test_restrictive_or_missing_licences_fail(self):
        for name in ["CC BY-NC 2.0", "CC BY-NC-SA 4.0", "CC BY-ND 3.0", "Fair use",
                     "Copyrighted", "", None, "Non-free"]:
            self.assertFalse(commons.licence_allowed(name or ""), repr(name))


class SearchParsingTests(unittest.TestCase):
    def test_hits_are_ranked_filtered_and_stripped(self):
        payload = {"query": {"pages": {
            "3": _page(3, "File:Third.jpg", "CC BY-NC 2.0", index=3),
            "1": _page(1, "File:First.jpg", "Public domain", index=1),
            "2": _page(2, "File:Second.svg", "CC BY 2.0", mime="image/svg+xml", index=2),
            "4": _page(4, "File:Tiny.jpg", "CC0", w=120, h=90, index=4),
        }}}
        hits = commons.parse_hits(payload, "q")
        self.assertEqual([h.title for h in hits],
                         ["File:First.jpg", "File:Second.svg", "File:Third.jpg", "File:Tiny.jpg"])
        self.assertTrue(hits[0].allowed)
        self.assertEqual(hits[0].artist, "Someone")
        self.assertEqual(hits[0].description, "A thing")
        self.assertIn("mime", hits[1].refused_reason)
        self.assertIn("licence", hits[2].refused_reason)
        self.assertIn("too small", hits[3].refused_reason)

    def test_choose_dedupes_across_queries_and_respects_per_query(self):
        seen = set()
        a = commons.parse_hits({"query": {"pages": {
            "1": _page(1, "File:A.jpg", "CC0", index=1),
            "2": _page(2, "File:B.jpg", "CC0", index=2),
            "3": _page(3, "File:C.jpg", "CC0", index=3)}}}, "q1")
        self.assertEqual([h.title for h in commons.choose(a, 2, seen)], ["File:A.jpg", "File:B.jpg"])
        b = commons.parse_hits({"query": {"pages": {
            "1": _page(1, "File:A.jpg", "CC0", index=1),
            "9": _page(9, "File:Z.jpg", "CC0", index=2)}}}, "q2")
        self.assertEqual([h.title for h in commons.choose(b, 2, seen)], ["File:Z.jpg"])


class FetchTests(unittest.TestCase):
    def test_fetch_writes_files_and_provenance_and_records_refusals(self):
        payload = {"query": {"pages": {
            "1": _page(1, "File:Good one.jpg", "CC BY-SA 4.0", index=1),
            "2": _page(2, "File:Bad.jpg", "CC BY-NC 2.0", index=2)}}}
        calls = []

        def fake_json(url):
            calls.append(url)
            return payload

        def fake_bytes(url):
            return b"\x89PNGfake" + url.encode()

        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / "WH_x_01"
            result = commons.fetch_specimen("WH_x_01", ["a query"], dest, per_query=3,
                                            fetch_json=fake_json, fetch_bytes=fake_bytes)
            self.assertEqual(len(result.downloaded), 1)
            self.assertEqual(result.downloaded[0]["licence"], "CC BY-SA 4.0")
            self.assertTrue((dest / result.downloaded[0]["file"]).exists())
            self.assertEqual(len(result.refused), 1)
            prov = json.loads((dest / "provenance.json").read_text(encoding="utf-8"))
            self.assertEqual(prov["downloaded"][0]["title"], "File:Good one.jpg")
            self.assertIn("gsrsearch=filetype%3Abitmap+a+query", calls[0])
            # A second run keeps the earlier file and does not download it again.
            downloads = []
            commons.fetch_specimen("WH_x_01", ["a query"], dest, per_query=3,
                                   fetch_json=fake_json,
                                   fetch_bytes=lambda u: downloads.append(u) or b"x")
            self.assertEqual(downloads, [])


    def test_max_files_caps_downloads_across_queries(self):
        payload = {"query": {"pages": {str(i): _page(i, f"File:P{i}.jpg", "CC0", index=i) for i in range(1, 6)}}}
        with tempfile.TemporaryDirectory() as td:
            result = commons.fetch_specimen("s", ["q1", "q2"], Path(td) / "s", per_query=3, max_files=4,
                                            fetch_json=lambda u: payload, fetch_bytes=lambda u: b"x")
            self.assertEqual(len(result.downloaded), 4)


    def test_fallback_queries_run_only_when_sparse_and_are_marked(self):
        empty = {"query": {"pages": {}}}
        full = {"query": {"pages": {str(i): _page(i, f"File:F{i}.jpg", "CC0", index=i) for i in range(1, 4)}}}
        seen = []

        def fake_json(url):
            seen.append(url)
            return full if "fallback" in url else empty

        with tempfile.TemporaryDirectory() as td:
            r = commons.fetch_specimen("s", ["authored phrase"], Path(td) / "s", per_query=3,
                                       fallbacks=["fallback one", "fallback two"],
                                       fetch_json=fake_json, fetch_bytes=lambda u: b"x")
            self.assertEqual(r.fallbacks_used, ["fallback one"])
            self.assertEqual(len(r.downloaded), 3)
            self.assertTrue(all(d["fallback_query"] for d in r.downloaded))
            self.assertEqual(len(seen), 2)
            # Not sparse any more: a second run never reaches the fallbacks.
            seen.clear()
            r2 = commons.fetch_specimen("s", ["authored phrase"], Path(td) / "s", per_query=3,
                                        fallbacks=["fallback one"], fetch_json=fake_json,
                                        fetch_bytes=lambda u: b"x")
            self.assertEqual(r2.fallbacks_used, [])
        self.assertEqual(commons.fallback_queries("Electric kettle (nickel)", "kettle")[0], "electric kettle 1920s")
        self.assertEqual(commons.fallback_queries("", "mail_bank")[-1], "mail bank")

    def test_network_error_is_recorded_not_raised(self):
        def boom(url):
            raise OSError("no route")
        with tempfile.TemporaryDirectory() as td:
            result = commons.fetch_specimen("s", ["q"], Path(td) / "s", fetch_json=boom,
                                            fetch_bytes=lambda u: b"")
            self.assertEqual(result.downloaded, [])
            self.assertEqual(len(result.errors), 1)


class ManifestTests(unittest.TestCase):
    def test_manifest_schema_is_enforced(self):
        with tempfile.TemporaryDirectory() as td:
            bad = Path(td) / "m.json"
            bad.write_text(json.dumps({"schema": "other", "specimens": []}), encoding="utf-8")
            with self.assertRaises(ValueError):
                mf.load_manifest(bad)
            good = Path(td) / "g.json"
            good.write_text(json.dumps({"schema": mf.MANIFEST_SCHEMA, "specimens": []}), encoding="utf-8")
            self.assertEqual(mf.load_manifest(good)["specimens"], [])

    def test_installed_counts_follow_marker_kinds(self):
        with tempfile.TemporaryDirectory() as td:
            layout = Path(td) / "layout.json"
            layout.write_text(json.dumps({"floors": [
                {"markers": [{"kind": "fridge", "room": "2A"}, {"kind": "fridge", "pos": [1, 2]},
                             {"kind": "lamp"}]}]}), encoding="utf-8")
            counts = mf.installed_counts(layout)
            self.assertEqual(counts["fridge"], 2)
            self.assertEqual(counts["lamp"], 0)

    def test_variant_queries_come_first_and_dedupe(self):
        queries = {"kinds": {"fridge": {"queries": ["icebox 1910s", "shared"], "variants": [
            {"label_match": "monitor-top", "queries": ["GE monitor top 1927", "shared"]},
            {"label_match": "icebox", "queries": ["oak icebox"]}]}}}
        record = {"kind": "fridge", "label": "fridge / 1927 monitor-top"}
        self.assertEqual(mf.resolve_queries(record, queries),
                         ["GE monitor top 1927", "shared", "icebox 1910s"])
        self.assertEqual(mf.resolve_queries({"kind": "nothing"}, queries), [])


    def test_specimen_id_is_kind_and_label_not_node_index(self):
        a = mf.specimen_id({"node": "WH_fridge_36", "kind": "fridge", "label": "fridge / 1927 monitor-top"})
        b = mf.specimen_id({"node": "WH_fridge_41", "kind": "fridge", "label": "fridge / 1927 monitor-top"})
        self.assertEqual(a, b)
        self.assertEqual(a, "fridge__1927_monitor_top")
        self.assertEqual(mf.specimen_id({"node": "WH_boiler_06", "kind": "boiler", "label": "boiler"}), "boiler")
        self.assertEqual(mf.specimen_id({"node": "F01_DOOR_06", "kind": "landmark_entry",
                                         "label": "landmark entry / the Orison front door"}),
                         "landmark_entry__landmark_entry_the_orison_front_door")


    def test_assign_ids_suffixes_only_collisions_in_manifest_order(self):
        specimens = [{"kind": "boxfan", "label": "boxfan"}, {"kind": "boiler", "label": "boiler"},
                     {"kind": "boxfan", "label": "boxfan"}]
        self.assertEqual(mf.assign_ids(specimens), ["boxfan__1", "boiler", "boxfan__2"])

    def test_tiers_cover_every_registered_kind(self):
        tiers = mf.load_tiers()
        registry = (mf.REPO_ROOT / "game/scripts/building/building_root.gd").read_text(encoding="utf-8")
        import re
        block = registry.split("const PROP_SCRIPTS := {", 1)[1].split("\n}", 1)[0]
        kinds = set(re.findall(r'^\s*"([a-z_]+)":\s*preload', block, re.M))
        self.assertGreater(len(kinds), 40)
        missing = kinds - set(tiers["kinds"])
        self.assertEqual(missing, set(), f"kinds without a tier: {sorted(missing)}")


class PriorityTests(unittest.TestCase):
    def _facts(self, **over):
        base = {"id": "x", "kind": "k", "tier_weight": 2.0, "installed_count": 4,
                "flat_colour_share": 0.2, "reviewed_before": False, "has_geometry": True}
        base.update(over)
        return base

    def test_more_installed_and_larger_gap_rank_higher(self):
        crit = {"axes": {a: 3 for a in priority.AXES}}
        low = priority.score(self._facts(installed_count=1), crit)["priority"]
        high = priority.score(self._facts(installed_count=40), crit)["priority"]
        self.assertGreater(high, low)
        small_gap = priority.score(self._facts(), {"axes": {a: 1 for a in priority.AXES}})["priority"]
        self.assertGreater(priority.score(self._facts(), crit)["priority"], small_gap)

    def test_reviewed_family_with_small_gap_is_discounted_but_large_gap_is_not(self):
        small = {"axes": {a: 1 for a in priority.AXES}}
        large = {"axes": {a: 4 for a in priority.AXES}}
        self.assertEqual(priority.score(self._facts(reviewed_before=True), small)["review_discount"], 0.6)
        self.assertEqual(priority.score(self._facts(reviewed_before=True), large)["review_discount"], 1.0)

    def test_empty_prop_and_flat_colour_are_loud(self):
        empty = priority.score(self._facts(has_geometry=False), None)
        self.assertTrue(empty["not_assessable"])
        self.assertEqual(empty["priority"], 0.0)
        ranked = priority.rank([self._facts(id="e", kind="e", has_geometry=False),
                                self._facts(id="g", kind="g")], {})
        self.assertEqual([r["id"] for r in ranked], ["g", "e"])
        self.assertGreater(priority.score(self._facts(flat_colour_share=1.0), None)["flat_bonus"], 0.0)
        self.assertEqual(priority.score(self._facts(flat_colour_share=0.3), None)["flat_bonus"], 0.0)

    def test_rank_is_stable_and_numbered(self):
        entries = [self._facts(id="b", kind="b"), self._facts(id="a", kind="a")]
        ranked = priority.rank(entries, {})
        self.assertEqual([r["id"] for r in ranked], ["a", "b"])
        self.assertEqual([r["rank"] for r in ranked], [1, 2])


class SheetAndBriefTests(unittest.TestCase):
    def test_sheet_builds_from_tiny_frames_and_survives_an_unreadable_reference(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            frame = td / "f.png"
            Image.new("RGB", (64, 48), (200, 100, 50)).save(frame)
            bad = td / "bad.jpg"
            bad.write_bytes(b"not an image")
            out = sheets.build_sheet({"kind": "kettle", "label": "nickel", "size_m": [0.2, 0.3, 0.2],
                                      "mount": "floor", "installed_count": 6, "tier": "touched_often",
                                      "reviewed_before": True, "triangles": 400, "surfaces": 9,
                                      "flat_colour_share": 0.5, "real_object": "an electric kettle"},
                                     [(frame, "front")], [(bad, "CC0 | broken")], td / "sheet.jpg")
            with Image.open(out) as image:
                self.assertGreater(image.width, 400)
                self.assertGreater(image.height, 600)
            small = sheets.downscale(frame, td / "small.jpg", width=32)
            with Image.open(small) as image:
                self.assertEqual(image.width, 32)

    def test_brief_lists_every_specimen_in_rank_order(self):
        ranked = [
            {"rank": 1, "kind": "boiler", "label": "coal", "installed_count": 1, "tier": "carries_game",
             "size_m": [1, 1, 1], "mount": "floor", "triangles": 10, "surfaces": 3, "flat_colour_share": 0.0,
             "real_object": "a boiler", "references": [{"title": "File:B.jpg", "licence": "CC0", "url": "u"}],
             "score": {"priority": 9.0, "gap": 3.0, "review_discount": 1.0},
             "critique": {"summary": "Too small.", "modelling": ["add gauges"], "texturing": ["cast iron"],
                          "effort_hours": 6, "confidence": "high", "references_used": ["File:B.jpg"]}},
            {"rank": 2, "kind": "darts", "label": "", "installed_count": 1, "tier": "leave_alone",
             "size_m": [0.5, 0.5, 0.1], "mount": "wall", "triangles": 5, "surfaces": 1, "flat_colour_share": 1.0,
             "real_object": "", "references": [{"title": "File:Cow.jpg", "licence": "CC0", "url": "u2"}],
             "score": {"priority": 1.0, "gap": 0.0, "review_discount": 1.0},
             "critique": {}},
            {"rank": 3, "kind": "porch_deck", "label": "porch_deck", "installed_count": 5, "tier": "leave_alone",
             "size_m": [0, 0, 0], "mount": "floor", "triangles": 0, "surfaces": 0, "flat_colour_share": 1.0,
             "real_object": "", "references": [],
             "score": {"priority": 0.0, "gap": 0.0, "review_discount": 1.0, "not_assessable": True},
             "critique": {"summary": "Audio only; the deck is baked by the layout pass."}},
        ]
        text = render_brief(ranked, "2026-09-18", preface="## Method" + chr(10) * 2 + "How it was made.")
        self.assertLess(text.index("## Method"), text.index("## Priority table"))
        self.assertLess(text.index("### 1. boiler"), text.index("### 2. darts"))
        self.assertIn("add gauges", text)
        self.assertIn("No critique recorded", text)
        self.assertIn("INERT", text)
        self.assertIn("File:B.jpg - CC0 - u", text)
        self.assertIn("1 plates on the sheet were off-topic", text.replace("the 1 plates", "1 plates"))
        self.assertNotIn("File:Cow.jpg - CC0", text)
        self.assertIn("## Not assessable in the shed", text)
        self.assertIn("Audio only", text)
        self.assertNotIn("### 3. porch_deck", text)


class CritiqueValidationTests(unittest.TestCase):
    def _good(self):
        return {"specimen": "boiler", "axes": {a: 1 for a in priority.AXES}, "effort_hours": 4,
                "confidence": "high", "summary": "Fine.", "modelling": ["x"], "texturing": []}

    def test_good_critique_has_no_errors(self):
        from tools.prop_reference.critiques import validate_critique
        self.assertEqual(validate_critique(self._good(), {"boiler"}), [])

    def test_each_contract_rule_is_enforced(self):
        from tools.prop_reference.critiques import validate_critique
        bad = self._good(); bad["axes"]["wear"] = 7
        self.assertTrue(any("wear" in e for e in validate_critique(bad, {"boiler"})))
        bad = self._good(); bad["axes"]["taste"] = 1
        self.assertTrue(any("unknown axes" in e for e in validate_critique(bad, {"boiler"})))
        bad = self._good(); bad["confidence"] = "sure"
        self.assertTrue(any("confidence" in e for e in validate_critique(bad, {"boiler"})))
        bad = self._good(); del bad["summary"]
        self.assertTrue(any("missing summary" in e for e in validate_critique(bad, {"boiler"})))
        self.assertTrue(any("not in the comparison index" in e
                            for e in validate_critique(self._good(), {"kettle"})))
        self.assertEqual(validate_critique("nope", set()), ["not a JSON object"])

    def test_directory_report_flags_name_mismatch_and_bad_json(self):
        from tools.prop_reference.critiques import validate_directory
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            (td / "boiler.json").write_text(json.dumps(self._good()), encoding="utf-8")
            wrong = self._good(); wrong["specimen"] = "kettle"
            (td / "toaster.json").write_text(json.dumps(wrong), encoding="utf-8")
            (td / "broken.json").write_text("{", encoding="utf-8")
            report = validate_directory(td, {"boiler", "toaster", "kettle"})
            self.assertEqual(report["boiler.json"], [])
            self.assertTrue(any("does not match" in e for e in report["toaster.json"]))
            self.assertTrue(any("invalid JSON" in e for e in report["broken.json"]))


if __name__ == "__main__":
    unittest.main(verbosity=1)
