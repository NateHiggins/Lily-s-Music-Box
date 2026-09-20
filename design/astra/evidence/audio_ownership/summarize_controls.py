from pathlib import Path
import hashlib
import json

out = Path(__file__).resolve().parent
cases = [
    ("shared_raw", 0, "Two cycles: real service set idle plus watch-register refusal; no weak-reference retention or shutdown diagnostic."),
    ("printing_raw", 0, "Two cycles: real service-set feed interrupted during playback; no weak-reference retention or shutdown diagnostic."),
    ("m08f_probe", 0, "INVALID INSTRUMENT: RefCounted playback incorrectly typed Resource; script errors make exit zero inadmissible."),
    ("m08f_probe2", 1, "Valid weak-reference instrument identifies surviving NightRegister paper cue in AudioPolicy slot 0."),
    ("night_register_red", 1, "Original owner: eight failed lifetime checks across two cycles."),
    ("night_register_green", 1, "Owner-only repair detaches pool streams, but pending playback weak references survive."),
    ("night_register_green2", 1, "Synchronous observation helpers do not change the pending-playback failure."),
    ("night_register_green3", 0, "Owner and pooled-slot retirement pass eighteen checks; no diagnostics."),
    ("m08f_green", 0, "Owner-only repair clears the original composed M08F shutdown defect; twenty-nine checks."),
    ("off_tree_red", 1, "Late WorkOrders callback reacquires a detached owner's cue; nineteen of twenty checks pass and an off-tree transform error is retained."),
    ("off_tree_green", 0, "Off-tree guard preserves the live neighbor and passes all twenty lifetime checks without diagnostics."),
    ("night_suite_verbose", 0, "Original synchronous fixture exits after 148 checks with twenty-two Ogg objects and six resources still retained; functional exit is not a clean lifecycle result."),
    ("night_suite_green", 0, "Explicit fixture retirement preserves all 148 assertions and clears every verbose shutdown diagnostic."),
    ("m08f_final_guard", 0, "Final production guard and pool implementation: twenty-nine composed checks and clean verbose shutdown."),
]
runs = []
for name, code, scope in cases:
    files = {}
    for suffix in [".stdout.log", ".stdout.log.stderr"]:
        path = out / (name + suffix)
        files[path.name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
    runs.append({"case": name, "observed_runner_exit": code, "scope": scope, "files": files})
report = {
    "schema_version": 1,
    "head_when_controls_started": "cc95005d2c24b6be5cb04e728c5229c5d416954b",
    "source_provenance": "red_sources.json, archived source snapshots, and owner_controls_v2/owner_controls.json bind exact tested bytes. This was an uncommitted repair over the accepted merge.",
    "runs": runs,
    "final_same_fixture_controls": "owner_controls_v2/owner_controls.json",
    "final_process_validation": "../audio_repair_runtime/receipt.json",
    "final_matrix_validation": "../audio_repair_runtime/matrix_directory_green/verbose_launch/receipt.json",
    "initial_control_runner_failure": "owner_controls.json records zero runs and source restoration. The first Python command did not launch Godot because PowerShell -File argument binding failed. The v2 runner uses explicit array binding and retains actual process results.",
    "no_service_set_change": True,
    "no_global_muting_or_skipped_interaction": True,
    "scope_limit": "Headless memory/source lifetime evidence only; no listening or human visual acceptance.",
    "engine_source": "https://raw.githubusercontent.com/godotengine/godot/a13da4feb/scene/3d/audio_stream_player_3d.cpp",
    "engine_observation": "play stores setplayback; stop resets setplay and clears internal playbacks without unrefing setplayback. The normal physics start unrefs it only when setplay remains nonnegative. Destroying the retired pooled player releases this pending reference.",
}
root = out.parents[3]
report["final_source_hashes"] = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in [
    "game/scripts/audio/audio_policy.gd", "game/scripts/props/night_register_prop.gd",
    "game/tests/night_register_audio_lifecycle_test.gd", "game/tests/night_register_test.gd",
    "game/tests/orison_v2_m08f_runtime_test.gd", "game/tests/orison_v2_two_root_matrix_test.gd",
]}
(out / "receipt.json").write_text(json.dumps(report, indent=2) + "\n")
