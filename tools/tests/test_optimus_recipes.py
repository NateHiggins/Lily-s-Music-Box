"""Every Optimus recipe manifest keeps the schema in tools/optimus_recipes/README.md (order w56fcf305624f).

A recipe is the whole of what Optimus may run for a job, so a malformed one must fail here, before any
worker loads it: a recipe is always a pre-check, its argument list is fixed with only the declared tool and
output placeholders, and it states its limits.
"""
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / "tools" / "optimus_recipes"
FIELDS = {"schema", "recipe", "role", "source", "tools", "argv", "env", "timeout_seconds", "outputs", "needs",
          "exit_meaning", "acceptance"}
PLACEHOLDER = re.compile(r"\{([^{}]*)\}")


def manifests():
    return sorted(RECIPES.glob("*.json"))


def problems(path: Path) -> list[str]:
    found = []
    try:
        recipe = json.loads(path.read_text(encoding="utf-8"))
    except ValueError as error:
        return [f"{path.name}: not JSON ({error})"]
    missing = FIELDS - set(recipe)
    extra = set(recipe) - FIELDS
    if missing:
        found.append(f"{path.name}: missing {sorted(missing)}")
    if extra:
        found.append(f"{path.name}: unknown fields {sorted(extra)}")
    if recipe.get("schema") != "optimus.recipe.v1":
        found.append(f"{path.name}: schema is not optimus.recipe.v1")
    if recipe.get("recipe") != path.stem:
        found.append(f"{path.name}: recipe name {recipe.get('recipe')!r} is not the file stem")
    if recipe.get("role") != "precheck":
        found.append(f"{path.name}: role must be precheck (Optimus never makes a canonical gate result)")
    if (recipe.get("source") or {}).get("tree") not in ("whole", "text"):
        found.append(f"{path.name}: source.tree must be whole or text")
    tools = recipe.get("tools")
    if not isinstance(tools, list) or not all(isinstance(name, str) and name.isidentifier() for name in tools):
        found.append(f"{path.name}: tools must be a list of tool names")
        tools = []
    argv = recipe.get("argv")
    if not isinstance(argv, list) or not argv or not all(isinstance(word, str) for word in argv):
        found.append(f"{path.name}: argv must be a non-empty list of strings")
        argv = []
    allowed = set(tools) | {"out"}
    for word in argv:
        for name in PLACEHOLDER.findall(word):
            if name not in allowed:
                found.append(f"{path.name}: argv placeholder {{{name}}} is not a declared tool or out")
    if argv and PLACEHOLDER.fullmatch(argv[0]) is None:
        found.append(f"{path.name}: argv must start with a declared tool, not a bare program")
    if not isinstance(recipe.get("env"), dict):
        found.append(f"{path.name}: env must be an object")
    timeout = recipe.get("timeout_seconds")
    if not isinstance(timeout, int) or not 1 <= timeout <= 7200:
        found.append(f"{path.name}: timeout_seconds must be an integer from 1 to 7200")
    outputs = recipe.get("outputs")
    if not isinstance(outputs, list) or any(not isinstance(name, str) or "/" in name or "\\" in name or name.startswith(".")
                                            for name in outputs):
        found.append(f"{path.name}: outputs must be plain file names in the job's output folder")
    needs = recipe.get("needs") or {}
    if not isinstance(needs.get("ram_gb"), (int, float)) or not isinstance(needs.get("disk_gb"), (int, float)) \
            or not isinstance(needs.get("gpu"), bool):
        found.append(f"{path.name}: needs must give ram_gb, disk_gb and gpu")
    return found


class RecipeTests(unittest.TestCase):
    def test_the_recipes_exist(self):
        self.assertTrue(manifests(), "tools/optimus_recipes holds no recipe")

    def test_every_recipe_keeps_the_schema(self):
        found = [problem for path in manifests() for problem in problems(path)]
        self.assertEqual(found, [])

    def test_a_bad_recipe_is_caught(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            bad = Path(folder) / "bad-recipe.json"
            bad.write_text(json.dumps({"schema": "optimus.recipe.v1", "recipe": "other", "role": "gate",
                                       "source": {"tree": "all"}, "tools": ["python"], "argv": ["cmd", "/c", "{shell}"],
                                       "env": {}, "timeout_seconds": 0, "outputs": ["../x"], "needs": {},
                                       "exit_meaning": "", "acceptance": ""}), encoding="utf-8")
            text = "\n".join(problems(bad))
        for expected in ("not the file stem", "role must be precheck", "source.tree", "{shell}",
                         "start with a declared tool", "timeout_seconds", "outputs", "needs"):
            self.assertIn(expected, text)


if __name__ == "__main__":
    sys.exit(unittest.main(verbosity=2))
