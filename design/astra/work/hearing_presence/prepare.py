"""Prepare only; live game is frozen for a separate renderer trial."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ledger_path = 'game/scripts/reality/npc_observation_ledger.gd'
test_path = 'game/tests/orison_v2_presence_ledger_test.gd'
for relative in [ledger_path, test_path]:
    target = HERE / 'originals' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists(), 'Preparation must preserve its original input'
    target.write_bytes((ROOT / relative).read_bytes())

s = (ROOT / ledger_path).read_text(encoding='utf-8')
s = s.replace('## to see in-flat changes; invalid means assume home.',
    '## to see or hear in-flat events; invalid means assume home.')
s = s.replace('## carries it to, above threshold, hears it - nobody else.',
    '## carries it to, above threshold, can hear it while present at that unit.\n'
    '## An absent resident does not hear through an empty flat or learn on return.')
anchor = '\t\tif unit.is_empty() or not audible_units.has(unit):\n\t\t\tcontinue\n'
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + '\t\tif not _is_present(str(observer.npc)):\n\t\t\tcontinue\n', 1)
p = HERE / 'proposed' / ledger_path
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(s, encoding='utf-8', newline='\n')

s = (ROOT / test_path).read_text(encoding='utf-8')
s = s.replace('const CORRIDOR_MINUTE := 320.0',
    'const CORRIDOR_MINUTE := 320.0\nconst RETURN_MINUTE := 350.0')
s = s.replace('\t# The gate is sight-specific. Hearing travels the acoustic fabric to\n'
    '\t# whoever is on the riser and must not be silenced by presence.\n',
    '\t# The acoustic fabric reaches flats; their residents must be there.\n'
    '\t_check(world.resident_is_home(OMAR), "Omar is home to hear the riser at 05:20")\n')
s = s.replace('"hearing is not presence-gated: the riser still reaches 3B"',
    '"the riser still reaches the present resident of 3B"')
start = s.index('\t# PINNED, NOT ENDORSED.')
end = s.index('\n\t# --- the facts reconstruct', start)
s = s[:start] + '''\t_check(not heard.has(LENA) and not world.observation_ledger.has_learned(
\t\t\tLENA, "heard_riser_hammer_worsening"),
\t\t\t"the absent resident gains no in-home hearing belief")
\tclock.advance_to(RETURN_MINUTE - HOME_MINUTE)
\t_check(world.resident_is_home(LENA), "Lena is back in her flat at 05:50")
\t_check(not world.observation_ledger.has_learned(LENA, "heard_riser_hammer_worsening"),
\t\t\t"coming home does not retroactively reveal the missed event")
\tvar returned := world.observation_ledger.witness_audible_event(
\t\t\tRADIATOR_NODE, "hammer_after_return",
\t\t\t{"source_unit": "2B", "source": RADIATOR_NODE})
\tvar hearing := _belief(world.observation_ledger.beliefs(LENA), "heard_hammer_after_return")
\t_check(returned.has(LENA) and str(hearing.get("channel", "")) == "in_home_hearing"
\t\t\tand str(hearing.get("where", "")) == "2B"
\t\t\tand str(hearing.get("clock_basis", "")) == "campaign_absolute_minutes"
\t\t\tand absf(float(hearing.get("at_minutes", -1.0))
\t\t\t\t\t- absolute_home - RETURN_MINUTE + HOME_MINUTE) < 0.00001,
\t\t\t"a new sound after return earns a correctly dated local hearing belief")
''' + s[end:]
s = s.replace('\t_check(saved and _reconstructs_under("v2", expected, omar_expected),',
    '\t_check(saved and await _reconstructs_under("v2", expected, omar_expected),')
s = s.replace('\t_check(_reconstructs_under("v1", expected, omar_expected),',
    '\t_check(await _reconstructs_under("v1", expected, omar_expected),')
start = s.index('## Beliefs are RealityState facts, not composition state:')
end = s.index('\n\nfunc _belief', start)
s = s[:start] + '''## Instantiate each real root after reload and read its actual ledger.
## The previous helper accepted root_id but never used it to compose a world.
func _reconstructs_under(root_id: String, lena_expected: Array,
\t\tomar_expected: Array) -> bool:
\tRealityState.reset_campaign_for_tests()
\tRealityState.load_game()
\tSelector.reset_for_tests(root_id)
\tvar packed := load(Selector.scene_path()) as PackedScene
\tvar rebuilt := packed.instantiate() as Node3D
\tadd_child(rebuilt)
\tawait get_tree().physics_frame
\tvar ledger: NpcObservationLedger
\tif root_id == "v2":
\t\tledger = rebuilt.get("observation_ledger") as NpcObservationLedger
\telse:
\t\tvar ecosystem: Object = rebuilt.get("open_shift_ecosystem")
\t\tif ecosystem != null:
\t\t\tledger = ecosystem.get("ledger") as NpcObservationLedger
\tvar valid := not bool(rebuilt.get("startup_failed")) and is_instance_valid(ledger)
\tvar lena_back: Array = ledger.beliefs(LENA) if valid else []
\tvar omar_back: Array = ledger.beliefs(OMAR) if valid else []
\tvalid = valid and _same_beliefs(lena_back, lena_expected) \\
\t\t\tand _same_beliefs(omar_back, omar_expected) \\
\t\t\tand not _has(lena_back, "saw_tool_marks") \\
\t\t\tand not _has(lena_back, "heard_riser_hammer_worsening")
\tif rebuilt.has_method("shutdown_for_tests"):
\t\trebuilt.call("shutdown_for_tests")
\tremove_child(rebuilt)
\trebuilt.free()
\tpacked = null
\tawait get_tree().process_frame
\tawait get_tree().process_frame
\tawait get_tree().create_timer(0.1).timeout
\tPropAudio.clear_cache()
\treturn valid


func _same_beliefs(actual: Array, expected: Array) -> bool:
\tif actual.size() != expected.size():
\t\treturn false
\tfor i in range(actual.size()):
\t\tfor key in ["learned", "channel", "where", "clock_basis"]:
\t\t\tif actual[i].get(key) != expected[i].get(key):
\t\t\t\treturn false
\t\tif not is_equal_approx(float(actual[i].get("at_minutes", -1)),
\t\t\t\tfloat(expected[i].get("at_minutes", -2))):
\t\t\treturn false
\t\tif actual[i].get("evidence", {}) != expected[i].get("evidence", {}):
\t\t\treturn false
\treturn true
''' + s[end:]
p = HERE / 'proposed' / test_path
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(s, encoding='utf-8', newline='\n')

paths = [ledger_path, test_path, 'game/tests/npc_hearing_presence_test.gd',
    'game/tests/NpcHearingPresenceTest.tscn']
patch = ''
rows = []
for relative in paths:
    p = HERE / 'proposed' / relative
    original = ROOT / relative
    before = original.read_text(encoding='utf-8') if original.exists() else ''
    patch += ''.join(difflib.unified_diff(before.splitlines(True),
        p.read_text(encoding='utf-8').splitlines(True),
        fromfile='a/' + relative if original.exists() else '/dev/null', tofile='b/' + relative))
    rows.append({'path': relative, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
(HERE / 'hearing_presence.patch').write_text(patch, encoding='utf-8', newline='\n')
(HERE / 'preparation.json').write_text(json.dumps({'status': 'PREPARED_NOT_APPLIED_OR_RUN',
    'scope': 'Home-unit hearing presence and earned/missed belief reconstruction; actor-position/earshot outside the flat remains separate work',
    'files': rows}, indent=2) + '\n', encoding='utf-8')
print('Prepared four paths outside live game; no Godot run')
