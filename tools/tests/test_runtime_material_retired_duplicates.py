"""Regenerate after storage retirement using exact authoring bytes only."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("runtime_retired",ROOT/"art/tools/generate_runtime_materials.py")
gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)

class RetiredDuplicateTests(unittest.TestCase):
    def fixture(self,root):
        textures=root/"game/assets/building/textures";textures.mkdir(parents=True)
        author=root/"art/textures/procedural/retired";author.mkdir(parents=True)
        for channel,name in enumerate(["albedo","roughness","normal"]):
            data=("original-channel-%d"%channel).encode()
            (textures/("T_ai_materials_surviving_%s.png"%["albedo","rough","normal"][channel])).write_bytes(data)
            (author/(name+".png")).write_bytes(data)
        catalog=root/"catalog.json";mapping=root/"mapping.json"
        catalog.write_text(json.dumps({"surviving":{},"retired":{}}))
        mapping.write_text(json.dumps({k:"procedural/retired" for k in ["surviving","retired"]}))
        (author/"material.json").write_text('{"meters_per_tile":2}')
        return textures,author,catalog,mapping

    def build(self,root,fixture):
        textures,author,catalog,mapping=fixture
        with patch.multiple(gen,ROOT=root,GODOT_TEXTURES=textures,CATALOG=catalog,MAPPING=mapping,
                            RUNTIME_POLICY={"surviving":{},"retired":{}},VISUAL_LOCKS={}):
            return gen.build_contract()

    def test_retired_copy_resolves_by_exact_bytes_without_generated_manifest(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);f=self.fixture(root);contract=self.build(root,f)
            self.assertEqual(contract["materials"]["retired"]["files"],contract["materials"]["surviving"]["files"])
            self.assertEqual(len(list(f[0].glob("*.png"))),3)

    def test_changed_source_is_not_replaced_with_a_similar_finish(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);f=self.fixture(root);(f[1]/"roughness.png").write_bytes(b"new roughness")
            self.assertEqual(self.build(root,f)["materials"]["retired"]["files"][1],"T_ai_materials_retired_rough.png")

    def test_missing_authoring_source_stays_missing(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);f=self.fixture(root);(f[1]/"normal.png").unlink()
            self.assertEqual(self.build(root,f)["materials"]["retired"]["files"][2],"T_ai_materials_retired_normal.png")

    def test_bytes_in_another_channel_are_not_accepted(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);f=self.fixture(root);(f[1]/"roughness.png").write_bytes((f[1]/"normal.png").read_bytes())
            self.assertEqual(self.build(root,f)["materials"]["retired"]["files"][1],"T_ai_materials_retired_rough.png")

if __name__=="__main__":unittest.main()
