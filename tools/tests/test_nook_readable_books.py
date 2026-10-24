"""Retained loose-volume lineage, physical-copy identity and source bindings."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def read(path): return json.loads((ROOT/path).read_text(encoding="utf8"))
def digest(path):
    data=(ROOT/path).read_bytes()
    if Path(path).suffix in [".py",".json"]: data=data.replace(b"\r\n",b"\n")
    return hashlib.sha256(data).hexdigest()

class NookBooksTests(unittest.TestCase):
    def test_retained_volumes_have_distinct_physical_identities(self):
        data=read("game/data/orison_v2/nook_readable_books.json")
        old=read("art/blender/reading_nook_construction.json")
        expected={row["assembly"]+"__"+row["label"] for row in old["book_stock"]}|{"nook_cush1__Reader"}
        self.assertEqual(len(expected),61)
        self.assertEqual({r["id"] for r in data["copies"]},expected)
        self.assertEqual(len(data["copies"]),len(expected))
        self.assertEqual(set(data["books"]),expected)
        self.assertEqual({r["assembly"] for r in data["copies"]},{"nook_books","nook_pile","nook_cush1"})
        self.assertEqual(len(data["ends"]),6)
        self.assertEqual(len({r["id"] for r in data["ends"]}),6)

    def test_public_titles_do_not_copy_the_rare_personal_editions(self):
        data=read("game/data/orison_v2/nook_readable_books.json")
        library={r["id"]:r for r in read("game/data/library.json")["books"]}
        public=set(library)-{"prospectus","hymns","onefinger","minutes"}
        programme=read("art/data/reading_nook/book_programme.json")["copies"]
        editions=read("game/data/orison_v2/readable_library.json")
        self.assertEqual({r["id"]:r["title_id"] for r in data["copies"]},programme)
        self.assertTrue(set(programme.values())<=public)
        self.assertLess(len(public),len(data["copies"]),"Distinct physical copies may share a title")
        for copy in data["copies"]:
            self.assertLessEqual(library[copy["title_id"]]["year"],1928)
            book=data["books"][copy["id"]]
            edition=editions["books"][copy["title_id"]]
            self.assertEqual(book["native_title"],copy["title_id"])
            for field in ["width","height","thickness","binding","opening_style","format","layout","publisher","page_count"]:
                self.assertEqual(book[field],edition[field],(copy["id"],field))
            self.assertEqual(len(book["opening_keys"]),8)
            if book["opening_style"]=="paperback":
                wrappers=[p for p in book["parts"] if p.endswith("__continuous_wrap")]
                self.assertEqual(len(wrappers),1,"A paperback has one continuous flexible wrapper")

    def test_each_volume_keeps_its_own_dimensions_and_closed_native_parts(self):
        data=read("game/data/orison_v2/nook_readable_books.json")
        report=read("art/blender/nook_readable_books_construction.json")
        self.assertEqual(set(report["parts"]),set(data["parts"]))
        self.assertEqual({r["part"] for r in report["closed_stocks"]},set(data["parts"]))
        self.assertTrue(all(r["closed"] and r["volume_m3"]>0 for r in report["closed_stocks"]))
        self.assertEqual(data["asset"],"res://assets/props/readable_library.glb","Copies share the native edition buffers")
        sizes={"pocket":(.112,.178),"trade":(.140,.216),"reference":(.185,.254),"illustrated":(.210,.260),"pamphlet":(.130,.200)}
        for lineage in report["lineage"]:
            book=data["books"][lineage["id"]]
            self.assertEqual((book["width"],book["height"]),sizes[book["format"]])
            for field,value in zip(["width","height","thickness"],lineage["dimensions"]):
                self.assertAlmostEqual(book[field],value,places=6)
            self.assertEqual({data["parts"][p]["role"] for p in book["parts"]},{"left","right","fixed"})

    def test_manufactured_outputs_bind_current_source(self):
        report=read("art/blender/nook_readable_books_construction.json")
        self.assertEqual(report["export"]["status"],"PASS")
        for field in ["source_bindings","outputs"]:
            for path,expected in report[field].items():
                self.assertEqual(digest(path),expected,path)

if __name__=="__main__": unittest.main()
