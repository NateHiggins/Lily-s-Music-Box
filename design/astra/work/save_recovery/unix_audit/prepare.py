from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[4]
original = (ROOT / 'originals/audit_systemic_situation_authority.py').read_text(encoding='utf-8')
tool = original.replace('HOST_CALENDAR_RE = re.compile(',
    'HOST_UNIX_RE = re.compile(r"Time\\.get_unix_time_from_system\\(")\nHOST_CALENDAR_RE = re.compile(', 1)
tool = tool.replace('if HOST_CALENDAR_RE.search(body) and not filename_only:',
    'if (HOST_CALENDAR_RE.search(body) or HOST_UNIX_RE.search(body)) and not filename_only\n'.rstrip() + ' \\\n                    and not _pure_seed_entropy(rel, name, body):', 1)
tool = tool.replace('def _scan_host_clock(ctx, findings, line, scope, line_no):', '''def _pure_seed_entropy(rel, scope, body):
    # Exact existing entropy boundary. It does not return the timestamp or
    # write a durable fact; the random hexadecimal seed is the returned value.
    return (rel == "game/scripts/game/reality_game_state.gd" and
            scope == "_new_dream_seed" and
            len(HOST_UNIX_RE.findall(body)) == 1 and
            "RandomNumberGenerator.new()" in body and
            re.search(r"rng\\.seed\\s*=.*Time\\.get_unix_time_from_system\\(", body) and
            body.count("rng.randi()") == 2 and
            re.search(r"return[^\\n]*\\bencoded\\b", body) and
            not CALENDAR_DURABLE_RE.search(body))


def _scan_host_clock(ctx, findings, line, scope, line_no):''', 1)
tool = tool.replace('if civil_host_read and (ctx.rel, scope) in HOST_FILENAME_SCOPES and',
    'unix_host_read = HOST_UNIX_RE.search(line)\n    if _pure_seed_entropy(ctx.rel, scope, code_body):\n        return\n    if (civil_host_read or unix_host_read) and (ctx.rel, scope) in HOST_FILENAME_SCOPES and', 1)
tool = tool.replace('if campaign_owner or calendar_persistence or civil_host_read:',
    'if campaign_owner or calendar_persistence or civil_host_read or unix_host_read:', 1)
tool = tool.replace('"host calendar or unauthorized clock read can "',
    '"host Unix/civil time or unauthorized clock read can "', 1)
tool = tool.replace('"hour/minute once, without calendar fields or durable writes",',
    '"hour/minute once, without calendar fields or durable writes; "\n            "Unix host time is reserved for reviewed seed entropy or pure IDs",', 1)
tool = tool.replace('        else:\n            covered.append(finding)', '''        elif finding["tier"] == "production" and \\
                finding["disposition"] in ACTIONABLE and \\
                entry.get("disposition") not in ACTIONABLE:
            policy_violations.append(
                {"finding": finding, "entry": entry,
                 "why": "non-actionable baseline cannot suppress actionable finding"})
        else:
            covered.append(finding)''', 1)

tests = (ROOT / 'originals/test_systemic_situation_authority.py').read_text(encoding='utf-8')
tests = tests.replace('"game/scripts/ui/goal_banner.gd"):',
    '"game/scripts/ui/goal_banner.gd",\n                        "game/scripts/game/maintenance_inventory.gd"):', 1)
addition = '''
class HostUnixTests(HostCalendarTests):
    def test_unix_world_stamp_requires_fix_and_campaign_value_passes(self):
        for field in ("issued_at", "closed_at", "acquired_at", "consumed_at", "reported_at", "at"):
            source = ('func record():\\n\\tvar stamp := Time.get_unix_time_from_system()\\n'
                      '\\tvar facts := {"%s": stamp}\\n\\tRealityState.data.history = facts\\n' % field)
            hits = self._find(source, "game/scripts/props/night_register_prop.gd")
            self.assertTrue(hits)
            self.assertTrue(all(hit["disposition"] == "FIX" for hit in hits))
            self.assertEqual(self._find(source.replace('Time.get_unix_time_from_system()',
                'CampaignClock.new().elapsed_minutes()'), "game/scripts/props/night_register_prop.gd"), [])

    def test_unix_named_helper_taint_reaches_renamed_consumer(self):
        source = ('func sample():\\n\\treturn Time.get_unix_time_from_system()\\n'
                  'func pass_stamp():\\n\\treturn sample()\\n'
                  'func remember():\\n\\t_state.at = pass_stamp()\\n')
        hits = self._find(source, "game/scripts/game/other_clock.gd")
        self.assertEqual({hit["scope"] for hit in hits}, {"sample", "remember"})
        self.assertTrue(all(hit["disposition"] == "FIX" for hit in hits))

    def test_exact_seed_entropy_and_pure_ids_remain_allowed(self):
        source = ('func _new_dream_seed() -> String:\\n'
                  '\\tvar rng := RandomNumberGenerator.new()\\n'
                  '\\trng.seed = int(Time.get_unix_time_from_system() * 1000000.0)\\n'
                  '\\tvar high := int(rng.randi())\\n\\tvar low := int(rng.randi())\\n'
                  '\\tvar encoded := "%08x%08x" % [high, low]\\n\\treturn encoded\\n')
        path = "game/scripts/game/reality_game_state.gd"
        self.assertEqual(self._find(source, path), [])
        self.assertTrue(self._find(source.replace('\\treturn encoded',
            '\\tRealityState.data.at = Time.get_unix_time_from_system()\\n\\treturn encoded'), path))
        self.assertTrue(self._find(source.replace('_new_dream_seed', 'other_entropy'), path))
        for path, helper in (("game/scripts/songbook/songbook_store.gd", "_new_id"),
                             ("game/scripts/phoneos/phone_camera.gd", "_new_photo_id")):
            source = ('func %s() -> String:\\n\\treturn str(Time.get_unix_time_from_system())\\n'
                      'func capture():\\n\\tvar path := %s()\\n\\timg.save_png(path)\\n') % (helper, helper)
            self.assertEqual(self._find(source, path), [])

    def test_documented_old_stamp_cannot_suppress_new_fix(self):
        source = 'func stamp():\\n\\tRealityState.data.at = Time.get_unix_time_from_system()\\n'
        finding = self._find(source, "game/scripts/game/work_orders.gd")[0]
        entry = dict(finding, disposition="DOCUMENT")
        drift = audit.diff_baseline({"entries": [entry]}, [finding])
        self.assertEqual(len(drift["policy_violations"]), 1)

'''
tests = tests.replace('class BaselineTests(unittest.TestCase):', addition + '\nclass BaselineTests(unittest.TestCase):', 1)
tests = tests.replace('class HostUnixTests(HostCalendarTests):',
    'class HostUnixTests(unittest.TestCase):\n    _find = HostCalendarTests._find\n    CLOCK = HostCalendarTests.CLOCK', 1)
proposed = ROOT / 'proposed/tools'
proposed.mkdir(parents=True, exist_ok=True)
(proposed / 'tests/test_systemic_situation_authority.py').write_text(tests, encoding='utf-8', newline='\n')
(proposed / 'audit_systemic_situation_authority.py').write_text(tool, encoding='utf-8', newline='\n')
compile(tool, str(proposed / 'audit_systemic_situation_authority.py'), 'exec')
compile(tests, str(proposed / 'tests/test_systemic_situation_authority.py'), 'exec')
patch = []
for name, before, after in [('tools/audit_systemic_situation_authority.py', original, tool),
        ('tools/tests/test_systemic_situation_authority.py', (ROOT / 'originals/test_systemic_situation_authority.py').read_text(encoding='utf-8'), tests)]:
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile='a/' + name, tofile='b/' + name))
(ROOT / 'unix_audit.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
print('Prepared audit delta only; no live tools changed.')
