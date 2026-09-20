"""Prepare a named navigation selection; --stage consumes it without committing.

Preparation and staging are separate invocations. No engine is launched and no
production source or historical receipt is edited. Run after lane release.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OWN_FILES = ("prepare_checkpoint.py", "test_prepare_checkpoint.py", "scope.json", "README.md", "package_seal.json")
FORBIDDEN = {"appdata", "userdata", "runtime_userdata", "profile", "profiles", ".godot", "__pycache__", ".pytest_cache", "cache", "caches"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(*args, data=None):
    result = subprocess.run(["git", "-C", str(ROOT), *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(result.returncode == 0, "git failed: " + " ".join(args) + "\n" + result.stderr.decode(errors="replace"))
    return result.stdout


def safe_relative(value):
    require(isinstance(value, str) and value and not any(c in value for c in "\\\x00\r\n:"), "unsafe path")
    p = PurePosixPath(value)
    require(not p.is_absolute() and all(s not in {"", ".", ".."} for s in value.split("/")), "unsafe path: " + value)
    require(not any(s.lower() in FORBIDDEN or s.lower().startswith(("userdata", "appdata")) for s in p.parts), "profile/cache path: " + value)
    require(p.suffix.lower() not in {".pyc", ".pyo"}, "compiled cache: " + value)
    return value


def local_file(relative):
    safe_relative(relative)
    p = ROOT / relative
    require(p.is_file() and not p.is_symlink() and p.resolve().is_relative_to(ROOT.resolve()), "missing/linked/outside file: " + relative)
    require(p.stat().st_mode & 0o170000 == 0o100000, "not a regular file: " + relative)
    return p


def hashes(path, require_lf=False):
    """One streaming read: raw SHA256 and Git's raw blob SHA1, no Git subprocess."""
    before = path.stat()
    raw = hashlib.sha256()
    blob = hashlib.sha1(b"blob " + str(before.st_size).encode("ascii") + b"\0")
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            require(not require_lf or b"\r" not in chunk, "review text is not plain LF; needs explicit clean-filter review: " + str(path))
            raw.update(chunk)
            blob.update(chunk)
    after = path.stat()
    require((before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), "file changed during hash: " + str(path))
    return {"raw_sha256": raw.hexdigest(), "git_blob": blob.hexdigest(), "bytes": before.st_size}


def payload(paths):
    require(len(paths) == len(set(paths)), "duplicate payload path")
    return b"\0".join(safe_relative(p).encode("utf-8") for p in sorted(paths)) + b"\0"


def parse_index(raw):
    result = {}
    for item in raw.split(b"\0"):
        if not item:
            continue
        header, path = item.split(b"\t", 1)
        mode, oid, stage = header.decode("ascii").split()
        require(stage == "0", "unmerged index entry")
        key = path.decode("utf-8")
        require(key not in result, "duplicate index entry")
        result[key] = {"mode": mode, "blob": oid}
    return result


def head_map():
    result = {}
    for item in git("ls-tree", "-r", "-z", "HEAD").split(b"\0"):
        if item:
            header, path = item.split(b"\t", 1)
            mode, kind, oid = header.decode("ascii").split()
            result[path.decode("utf-8")] = {"mode": mode, "blob": oid, "kind": kind}
    return result


def require_head_index(heads, index):
    expected = {p: {"mode": r["mode"], "blob": r["blob"]} for p, r in heads.items()}
    require(index == expected, "index differs from HEAD, including intent-to-add or mode-only entries")


def empty_index():
    require(not git("diff", "--cached", "--name-only", "-z"), "index must start empty")


def attribute_map(paths):
    raw = git("check-attr", "-z", "--stdin", "text", "filter", "working-tree-encoding", "ident", data=payload(paths))
    items = raw.split(b"\0")[:-1]
    require(len(items) % 3 == 0, "malformed attribute response")
    result = {}
    for i in range(0, len(items), 3):
        p, attribute, value = [x.decode("utf-8") for x in items[i:i + 3]]
        result.setdefault(p, {})[attribute] = value
    require(set(result) == set(paths), "attribute coverage differs from selection")
    return result


def clean_hashes(paths):
    # A single batch invokes the actual clean filters for normal source files.
    require(all("\n" not in p and '"' not in p for p in paths), "unsafe stdin-paths name")
    lines = git("hash-object", "--stdin-paths", data=("\n".join(paths) + "\n").encode()).decode().splitlines()
    require(len(lines) == len(paths), "clean hash result count differs")
    return dict(zip(paths, lines))


def read_json(relative):
    return json.loads(local_file(relative).read_text(encoding="utf-8"))


def scope():
    seal = json.loads((HERE / "package_seal.json").read_text())
    require(set(seal["files"]) == set(OWN_FILES) - {"package_seal.json"}, "package seal file set differs")
    for name, expected in seal["files"].items():
        require(hashes(HERE / name)["raw_sha256"] == expected, "sealed checkpoint instrument changed: " + name)
    config = json.loads((HERE / "scope.json").read_text())
    require(len(config["owned_sources"]) == 8, "exactly eight navigation source paths required")
    require(len(config["package_roots"]) == 4, "exactly four reviewed package roots required")
    return config


def named_files(config):
    roots = config["package_roots"]
    raw = git("ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", *roots)
    names = set()
    for item in raw.split(b"\0"):
        if not item:
            continue
        p = item.decode("utf-8")
        # Git can list __pycache__ that the old reproduction package did not ignore.
        # Explicitly exclude profiles/cache; never pass them to Git add.
        try:
            safe_relative(p)
        except ValueError:
            if any(s.lower() in FORBIDDEN or s.lower().startswith(("userdata", "appdata")) for s in PurePosixPath(p).parts) or p.endswith((".pyc", ".pyo")):
                continue
            raise
        require(any(p.startswith(r + "/") for r in roots), "Git returned an unnamed package")
        names.add(p)
    for root in roots:
        require(any(p.startswith(root + "/") for p in names), "empty reviewed package: " + root)
    names.update(config["owned_sources"])
    names.update(config["reviews"])
    names.update((HERE / p).relative_to(ROOT).as_posix() for p in OWN_FILES)
    require({p for p in names if p.startswith("game/")} == set(config["owned_sources"]), "production scope widened")
    require(not any(p.startswith(("tools/", "art/")) for p in names), "tool or protected art unexpectedly selected")
    return sorted(names)


def selected_rows(names, config):
    attributes = attribute_map(names)
    normal = set(config["owned_sources"])
    reviews = set(config["reviews"])
    rows = {}
    for position, name in enumerate(names, 1):
        a = attributes[name]
        require(all(a[k] in {"unspecified", "unset"} for k in ("filter", "working-tree-encoding", "ident")), "unexpected filter/encoding/ident: " + name)
        if name not in normal and name not in reviews:
            require(a["text"] == "unset", "byte-bound evidence/work must have -text: " + name)
        if name in reviews:
            require(a["text"] in {"unspecified", "unset", "set", "auto"}, "unsupported review text attribute")
        rows[name] = {"path": name, **hashes(local_file(name), require_lf=name in reviews)}
        if position % 5000 == 0:
            print("Hashed %d/%d named navigation files" % (position, len(names)), flush=True)
    for name, blob in clean_hashes(sorted(normal)).items():
        rows[name]["git_blob"] = blob
        require(rows[name]["raw_sha256"] == config["owned_sources"][name], "live owned source differs from final tested bytes: " + name)
    return rows


def protected_proof(config, heads, index):
    binding = config["protected_binding"]
    p = local_file(binding["path"])
    require(hashes(p)["raw_sha256"] == binding["sha256"], "protected reference changed")
    refs = json.loads(p.read_text())["protected_paths"]
    names = [r["path"] for r in refs]
    require(len(names) == len(set(names)) == 17, "seventeen distinct protected paths required")
    observed = clean_hashes(names)
    result = []
    for row in refs:
        path, wanted = row["path"], row["current_blob"]
        require(heads.get(path, {}).get("blob") == index.get(path, {}).get("blob") == observed[path] == wanted, "protected HEAD/index/current blob changed: " + path)
        result.append({"path": path, "head_blob": wanted, "index_blob": wanted, "working_clean_blob": wanted})
    return result


def validate_evidence(rows, config):
    final = config["final_aggregate"]
    require(rows[final["path"]]["raw_sha256"] == final["sha256"], "sealed final aggregate changed")
    aggregate = read_json(final["path"])
    require(aggregate["status"] == "DECLARED_CONTROLS_COMPLETE_SOURCE_BOUND", "navigation aggregate is incomplete")
    require(aggregate["final_tested_owned_sources"] == config["owned_sources"], "aggregate owned map differs")
    require(len(aggregate["runs"]) == 9 and len(aggregate["retained_fixture_failures"]) == 2, "final run/failure set incomplete")
    for key in ("current_prepared_package", "independent_review", "artifact_inventory"):
        ref = aggregate[key]
        require(rows[ref["path"]]["raw_sha256"] == ref["sha256"], "final aggregate linked receipt differs: " + key)
    previous = config["previous_aggregate"]
    require(rows[previous["path"]]["raw_sha256"] == previous["sha256"], "historical waiting aggregate changed")
    for run in read_json(previous["path"])["runs"]:
        require(rows[run["result"]]["raw_sha256"] == run["result_sha256"], "historical waiting result differs")
    for run in aggregate["runs"]:
        require(run["control_acceptance_exit"] == 0, "declared nav control not accepted")
        require(rows[run["result"]]["raw_sha256"] == run["result_sha256"], "final result binding differs")
    for run in aggregate["retained_fixture_failures"]:
        require(rows[run["result"]]["raw_sha256"] == run["result_sha256"], "historical failed result binding differs")
    for phase in aggregate["phases"].values():
        require(phase["status"] == "COMPLETE" and rows[phase["path"]]["raw_sha256"] == phase["sha256"], "phase binding/completion differs")
        if phase.get("restoration"):
            require(phase["restoration"]["exact_bytes_restored"] is True, "omission source restoration absent")
    results = artifacts = 0
    for name in rows:
        if not name.endswith("/result.json") or not name.startswith("design/astra/evidence/"):
            continue
        receipt = read_json(name)
        entries = receipt.get("artifacts", receipt.get("artifact_hashes"))
        if entries is None:
            continue
        if isinstance(entries, dict):
            pairs = entries.items()
        else:
            require(isinstance(entries, list), "unsupported artifact map: " + name)
            pairs = [(r["path"], r["sha256"]) for r in entries]
        for relative, digest in pairs:
            safe_relative(relative)
            path = (PurePosixPath(name).parent / relative).as_posix()
            require(path in rows and rows[path]["raw_sha256"] == digest, "retained artifact changed/missing from selection: " + path)
            artifacts += 1
        results += 1
    require(results >= 19 and artifacts >= 26023, "historical evidence coverage unexpectedly small")
    return {"result_artifact_maps_verified": results, "artifact_references_verified": artifacts,
            "final_declared_runs": 9, "retained_new_fixture_failures": 2,
            "policy": "Historical failures stay byte-bound; selection does not turn failed tests or diagnostic debt into acceptance."}


def dump(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def staged_issues(rows, heads, before_index, after_index, staged):
    expected_changed = sorted(p for p in rows if heads.get(p, {}).get("blob") != rows[p]["git_blob"])
    issues = []
    if staged != expected_changed:
        issues.append("staged changed paths differ from exact expected changes")
    for path, row in rows.items():
        if after_index.get(path, {}).get("blob") != row["git_blob"]:
            issues.append("staged blob differs: " + path)
        if after_index.get(path, {}).get("mode") != heads.get(path, {}).get("mode", "100644"):
            issues.append("staged file mode differs: " + path)
    for path in set(before_index) | set(after_index):
        if path not in rows and before_index.get(path) != after_index.get(path):
            issues.append("unselected index entry changed: " + path)
    return expected_changed, issues


def prepare(name):
    config = scope()
    empty_index()
    dest = HERE / name
    require(not dest.exists(), "fresh selection name required")
    head = git("rev-parse", "HEAD").decode().strip()
    index = parse_index(git("ls-files", "-s", "-z"))
    heads = head_map()
    require_head_index(heads, index)
    names = named_files(config)
    rows = selected_rows(names, config)
    evidence = validate_evidence(rows, config)
    protected = protected_proof(config, heads, index)
    # Whitespace checks apply only to actual game/tool changes, never historical
    # evidence, mixed-line-ending source copies or patch files.
    git("diff", "--check", "--", *sorted(config["owned_sources"]))
    require(git("rev-parse", "HEAD").decode().strip() == head, "HEAD changed during preparation")
    require(named_files(config) == names, "named package membership changed during preparation")
    empty_index()
    dest.mkdir()
    proof = {"schema": "astra.resident-nav-checkpoint.scope.v1", "head": head,
             "owned_source_count": 8, "production_owner_count": 2, "fixture_count": 6,
             "package_roots": config["package_roots"], "reviews": config["reviews"],
             "protected": protected, "evidence": evidence, "final_aggregate": config["final_aggregate"],
             "excluded_live_scope": ["BuildingRoot", "ApartmentEncroachment", "StreetCoreVisibilityTest", "PassageVisibilityTest", "material/renderer packages", "all protected assets"],
             "historical_overlay_policy": "Copied historical runtime sources remain evidence only; they do not adopt unrelated production overlays.",
             "human_or_release_acceptance": False, "staged": False}
    proof_path = dest / "scope_proof.json"
    dump(proof_path, proof)
    rel = proof_path.relative_to(ROOT).as_posix()
    rows[rel] = {"path": rel, **hashes(proof_path)}
    selection = {"schema": "astra.resident-nav-checkpoint.selection.v1", "head": head,
                 "named_files": names, "selected_rows": [rows[p] for p in sorted(rows)],
                 "scope_proof": rel, "selection_self_policy": "selection.json is additionally named; its raw/blob digest is calculated by the separate staging verifier.",
                 "staging_manifest_policy": "staging_manifest.json and paths.nul are local execution receipts, not selected commit content."}
    target = dest / "selection.json"
    dump(target, selection)
    with (dest / "paths.nul").open("xb") as stream:
        stream.write(payload([*rows, target.relative_to(ROOT).as_posix()]))
    print(json.dumps({"prepared": str(dest), "selected_paths_including_selection": len(rows) + 1, **evidence, "staged": False}))


def stage(name):
    config = scope()
    empty_index()
    dest = HERE / name
    selection_path = dest / "selection.json"
    selection = json.loads(selection_path.read_text())
    require(not (dest / "staging_manifest.json").exists(), "staging receipt already exists")
    require(git("rev-parse", "HEAD").decode().strip() == selection["head"], "HEAD changed since preparation")
    require(named_files(config) == selection["named_files"], "named package membership changed since review")
    rows = selected_rows(selection["named_files"], config)
    validate_evidence(rows, config)
    proof_path = selection["scope_proof"]
    require(proof_path == (dest / "scope_proof.json").relative_to(ROOT).as_posix(), "scope proof path differs")
    rows[proof_path] = {"path": proof_path, **hashes(local_file(proof_path))}
    require([rows[p] for p in sorted(rows)] == selection["selected_rows"], "selected bytes/blob map changed since review")
    heads = head_map()
    before_index = parse_index(git("ls-files", "-s", "-z"))
    require_head_index(heads, before_index)
    protected = protected_proof(config, heads, before_index)
    require(protected == read_json(proof_path)["protected"], "protected proof differs")
    own = selection_path.relative_to(ROOT).as_posix()
    rows[own] = {"path": own, **hashes(selection_path)}
    names = sorted(rows)
    spec = dest / "paths.nul"
    require(spec.read_bytes() == payload(names), "literal NUL payload differs from reviewed exact paths")
    git("diff", "--check", "--", *sorted(config["owned_sources"]))
    empty_index()
    command = ["git", "-C", str(ROOT), "--literal-pathspecs", "add", "--pathspec-from-file=" + str(spec), "--pathspec-file-nul"]
    completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    # One full staged map; never spawn a Git process per evidence file.
    after_index = parse_index(git("ls-files", "-s", "-z"))
    staged = sorted(p.decode() for p in git("diff", "--cached", "--name-only", "-z").split(b"\0") if p)
    expected_changed, issues = staged_issues(rows, heads, before_index, after_index, staged)
    if completed.returncode:
        issues.append("git add returned nonzero")
    for row in protected:
        if after_index.get(row["path"], {}).get("blob") != row["index_blob"]:
            issues.append("protected index blob changed")
    if git("rev-parse", "HEAD").decode().strip() != selection["head"]:
        issues.append("HEAD changed during stage")
    receipt = {"schema": "astra.resident-nav-checkpoint.stage.v1", "status": "VERIFIED" if not issues else "FAILED_REVIEW_REQUIRED",
               "head": selection["head"], "command": command, "git_add_exit": completed.returncode,
               "git_add_stdout": completed.stdout.decode(errors="replace"), "git_add_stderr": completed.stderr.decode(errors="replace"),
               "selected_paths": len(names), "expected_changed_paths": expected_changed, "actual_staged_paths": staged,
               "selected_rows": [rows[p] for p in names], "protected": protected, "issues": issues,
               "committed": False, "policy": "No automatic reset after failure. Inspect the exact index; historical receipts and source files were never rewritten."}
    dump(dest / "staging_manifest.json", receipt)
    require(not issues, "; ".join(issues[:8]))
    print(json.dumps({"staged": True, "selected_paths": len(names), "changed_paths": len(staged), "committed": False, "receipt": str(dest / "staging_manifest.json")}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("--stage", action="store_true")
    args = parser.parse_args()
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", args.name) is not None, "plain bounded receipt name required")
    stage(args.name) if args.stage else prepare(args.name)


if __name__ == "__main__":
    main()
