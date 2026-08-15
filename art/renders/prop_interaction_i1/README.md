# I1 production interaction inventory

Generated 2026-08-15 from the production `orison_root.tscn` at `b318d84`.
`live_inventory.json` is evidence for
`design/PROP_SET_INTERACTION_MATRIX.md`; it records facts and deliberately does
not encode design classification.

Run from the repository root, with no other Godot instance active:

```powershell
$env:INTERACTION_INVENTORY_OUT = 'C:\PleaseRemainOnTheLine\art\renders\prop_interaction_i1\live_inventory.json'
& 'C:\PleaseRemainOnTheLine\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\PleaseRemainOnTheLine\game' 'res://tests/InteractionInventory.tscn'
```

The run must finish inside 60 seconds and print:

```text
[INTERACTION INVENTORY] functional=203/21 nonfunctional=645/19 scripted_visual_families=22 set_systems=3 markers=44 assemblies=50 batches=15
```

Interpretation notes:

- The 645 non-Functional nodes include 260 `LightDebugHandle`s and 18 resident
  conversation owners, both outside the prop/set service-wire denominator.
- The remaining 367 nodes represent 366 logical prop/set targets because one
  `MailBankProp` intentionally owns a child `MailBoxZone` that forwards E.
- The six `InspectableZone`s return their service card from `interact()` rather
  than implementing `service_wire_card()`. The audit recognizes this contract
  without calling `interact()` and advancing their text cursor.
- `layout_render_batches` reads the current generator field `batch` and accepts
  the older diagnostic spelling `render_batch`.
- `scripted_set_systems` separately records the carried service set, batched
  traffic and weather field so a prop-only script scan cannot erase them.
- Counts are a snapshot, not frozen expectations. The later I6 proof gate owns
  failure thresholds after I4/I5 add and classify targets.
