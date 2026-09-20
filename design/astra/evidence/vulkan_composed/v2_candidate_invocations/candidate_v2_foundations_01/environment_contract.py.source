"""Explicit child environment; reject inherited material overrides, never hide them."""
from pathlib import Path
import ast
import hashlib
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
WRAPPER = ROOT / "design/astra/work/vulkan_composed/run_case.py"
WRAPPER_SHA = "8cb42f642262ccf416f0993699d7a3dff7b8cd3fa42631f6a33c0a8d0d1c6ad9"
NORMAL = {"ENCROACH": "1", "ENCROACH_FORCE": "", "ENCROACH_DEBUG_VIEW": "0",
          "ENCROACH_DEBUG": "0", "LIVING": "1", "LIVING_ALL": "0"}


def prepare_environment(inherited):
    selected = {key: inherited.get(key) for key in NORMAL}
    problems = []
    for key, target in NORMAL.items():
        allowed = {None, "", target}
        if selected[key] not in allowed:
            problems.append(f"{key} has an inherited nondefault value; refusing instead of clearing it")
    unknown = [key for key in inherited if key.startswith("ENCROACH") and key not in NORMAL]
    if unknown:
        problems.append("undeclared inherited ENCROACH variable(s): " + ", ".join(sorted(unknown)))
    if problems:
        raise ValueError("; ".join(problems))
    child = dict(inherited)
    child.update(NORMAL)
    return child, {"inherited_material_environment": selected, "explicit_wrapper_material_environment": NORMAL,
                   "policy": "Reject nondefault inherited material/field controls before launch; never change runtime case facts or bypass fixture preconditions"}


def actual_wrapper_environment(inherited, profile, frames, root="v1", scope="full"):
    """Evaluate only the exact saved wrapper's child-env AST, with no I/O/engine."""
    raw = WRAPPER.read_bytes()
    if hashlib.sha256(raw).hexdigest() != WRAPPER_SHA:
        raise ValueError("reviewed runtime wrapper changed")
    module = ast.parse(raw.decode())
    main = next(node for node in module.body if isinstance(node, ast.FunctionDef) and node.name == "main")
    start = next(i for i, node in enumerate(main.body) if isinstance(node, ast.Assign)
                 and any(isinstance(t, ast.Name) and t.id == "env" for t in node.targets))
    nodes = main.body[start:start + 3]
    # Exact three statements: env copy, selected-key removal, explicit update.
    if [type(node).__name__ for node in nodes] != ["Assign", "For", "Expr"]:
        raise ValueError("reviewed child-environment block changed")
    scope_values = {"os": SimpleNamespace(environ=dict(inherited)), "profile": Path(profile), "frames": Path(frames),
                    "args": SimpleNamespace(root=root, variant="candidate", scope=scope)}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(WRAPPER), "exec"), scope_values)
    return scope_values["env"]
