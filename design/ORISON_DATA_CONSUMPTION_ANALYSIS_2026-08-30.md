# Orison data-consumption analysis — 2026-08-30

**audit_data_consumption.py** makes absence of a consumer visible. It proves
neither semantic correctness nor visual use: a production script must name a
data file, and a field token must occur in a reader of that same file. Prose in
the artifact and tests do not count.

The first live run is intentionally red. No finding was excepted or baselined.
The canonical durable failures are **building_stability** and
**reality_coherence**: both persist and feed their own monotonic writes, but no
production decision reads either value. That violates the virtual-environment
ethos because abstract scores cannot stand in for world consequences.

The audit also reports whole-file absence, field-level absence and malformed
JSON separately. Counts are evidence of authored debt, not a target to reduce
by suppression. A new data feature is landable only when its intended fields
have production readers or when a reviewed exception explains why data is
deliberately archival.
