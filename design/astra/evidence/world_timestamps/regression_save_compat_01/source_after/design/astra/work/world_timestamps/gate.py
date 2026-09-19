"""Scoped native/log acceptance; expected negative runs remain red."""
import re

MARKERS = {
    'timestamps': 'WORLD TIMESTAMPS:', 'jobs': 'MAINTENANCE JOB TEST:',
    'errand': 'MAINTENANCE ERRAND TEST:', 'register': 'NIGHT REGISTER TEST:',
    'incidents': 'ORGANISM INCIDENTS TEST:', 'calendar': 'CAMPAIGN CALENDAR:',
    'save_recovery': '[SAVE RECOVERY]', 'save_compat': '[SAVE COMPAT]',
}


def diagnostic_gate(mode, native_exit, source_unchanged, raw):
    reasons = []
    if native_exit != 0:
        reasons.append('native/runner exit ' + str(native_exit))
    if not source_unchanged:
        reasons.append('recorded inputs changed during execution')
    if not any(MARKERS[mode] in line and re.search(r'\bPASS\b', line) for line in raw.splitlines()):
        reasons.append('suite PASS footer absent')
    bad = [line for line in raw.splitlines() if re.search(
        r'ERROR:|SCRIPT ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|RID allocations|Unreferenced static string', line, re.I)]
    if bad:
        reasons.append('native error or retention diagnostics present')
    return {'exit': int(bool(reasons)), 'reasons': reasons, 'error_or_retention_lines': bad}
