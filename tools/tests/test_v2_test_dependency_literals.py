"""Keep runtime and offline transitive binders aligned on complete literals."""
import ast
import re
import sys
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from v2_surface_evidence import test_dependency_paths


class DependencyLiterals(unittest.TestCase):
    def test_runtime_recognizes_complete_missing_files_but_not_prefixes(self):
        text=(ROOT/'game/tests/v2_spatial_access_cohort.gd').read_text()
        literal=re.search(r'references\.compile\((".*")\)',text).group(1)
        pattern=ast.literal_eval(literal)
        sample='''preload("res://tests/a.gd") "res://tests/missing.json" "res://tests/fixtures/orison_"+kind+".json" "res://tests/fixtures/"+name'''
        self.assertEqual(re.findall(pattern,sample),['res://tests/a.gd','res://tests/missing.json'])

    def test_offline_follows_the_same_literal_chain(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);tests=root/'game/tests';tests.mkdir(parents=True)
            entry=tests/'entry.gd';helper=tests/'helper.gd';fixture=tests/'data.json'
            entry.write_text('preload("res://tests/helper.gd")\n"res://tests/fixtures/orison_"+name+".json"')
            helper.write_text('"res://tests/data.json"');fixture.write_text('{}')
            self.assertEqual(test_dependency_paths(root,[entry]),{entry,helper,fixture})


if __name__=='__main__':unittest.main()
