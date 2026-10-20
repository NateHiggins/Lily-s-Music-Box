"""Readable stock admission: original corpus, native source and licensed type."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))

class ReadableLibraryTests(unittest.TestCase):
    def test_every_library_identity_has_its_own_featured_spread(self):
        library=read("game/data/library.json")
        content=read("game/data/orison_v2/book_spreads.json")
        stock=read("game/data/orison_v2/readable_library.json")
        identities={book["id"] for book in library["books"]}
        self.assertEqual(identities,set(content["spreads"]))
        self.assertEqual(identities,set(stock["books"]))
        self.assertTrue(content["authorship"])
        bodies=[]
        for identity,spread in content["spreads"].items():
            self.assertEqual(spread["page"]%2,0,identity)
            self.assertGreaterEqual(spread["page"],2)
            for side in ("left","right"):
                page=spread[side]
                self.assertTrue(page["heading"].strip(),identity)
                self.assertGreaterEqual(len(page["body"].split()),20,identity)
                self.assertLessEqual(len(page["body"].split()),90,identity)
                bodies.append(page["body"])
                if "illustration" in page:
                    self.assertIn(page["illustration"],stock["illustrations"],identity)
        self.assertEqual(len(bodies),len(set(bodies)),"Repeated filler is not a distinct authored spread")

    def test_native_stock_is_closed_and_binds_current_source(self):
        report=read("art/blender/readable_library_construction.json")
        stock=read("game/data/orison_v2/readable_library.json")
        self.assertEqual(report["export"]["status"],"PASS")
        self.assertEqual(set(report["parts"]),set(stock["parts"]))
        self.assertEqual({row["part"] for row in report["closed_stocks"]},set(stock["parts"]))
        for row in report["closed_stocks"]:
            self.assertTrue(row["closed"],row["part"])
            self.assertGreater(row["volume_m3"],0,row["part"])
        for path,digest in report["source_bindings"].items():
            data=(ROOT/path).read_bytes()
            if Path(path).suffix in (".py",".json"): data=data.replace(b"\r\n",b"\n")
            self.assertEqual(hashlib.sha256(data).hexdigest(),digest,path)

        for path,digest in report["outputs"].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),digest,path)

    def test_committed_review_logs_keep_the_captured_bytes(self):
        # Receipts contain absolute original capture locations, but the review
        # packet carries portable sibling copies. Check those bytes on any clone.
        for folder in ("v2_readable_library_20261020", "v2_library_handling_20261020"):
            packets=list((ROOT/"art/reviews"/folder).rglob("*.receipt.json"))
            self.assertTrue(packets,folder)
            for packet in packets:
                receipt=json.loads(packet.read_text(encoding="utf-8"))
                for stream in ("stdout", "stderr"):
                    name=Path(receipt["log"][stream]).name
                    captured=packet.parent/name
                    self.assertTrue(captured.is_file(),str(captured))
                    self.assertEqual(hashlib.sha256(captured.read_bytes()).hexdigest(),
                                     receipt["log"][stream+"_sha256"],str(captured))

    def test_typeface_is_pinned_and_keeps_its_license(self):
        folder=ROOT/"game/assets/fonts/eb_garamond"
        provenance=json.loads((folder/"provenance.json").read_text())
        self.assertEqual(len(provenance["commit"]),40)
        for name,record in provenance["files"].items():
            self.assertEqual(hashlib.sha256((folder/name).read_bytes()).hexdigest(),record["sha256"],name)
            self.assertIn(provenance["commit"],record["source"])
        self.assertIn("SIL OPEN FONT LICENSE",(folder/"OFL.txt").read_text())

if __name__=="__main__": unittest.main()
