# Godot 4.7.1 renderer, audio and Windows export repairs

The official 4.7.1 renderer leaves the reflection atlas color buffer alive.
Its six dependent face views account for the other six leaked Texture RIDs.
This reproduces without tentacles, lamp fields, or a composed world.

This directory retains the three-line upstream fix from
https://github.com/godotengine/godot/pull/124743 (29d351f9eb0dd7582469ad38e215e9902204df12).
The source report is https://github.com/godotengine/godot/issues/122498.
Freeing the parent buffer also frees its dependent views; do not free them twice.

The companion audio patch drains stopped playbacks and both generations of
retired bus details after all drivers finish. The editor and release-template
builds use the same two checked-in patches.

Build on Windows with Python and SCons installed:

    python tools/build_godot_reflection_fix.py

The script verifies the original engine/toolchain archives and patch, builds an
isolated Vulkan editor binary, and writes the ignored checkout-local
.godot-engine.json. It does not replace the installed official engine. The native
lane checks the engine and console-wrapper hashes before every launch. Explicit
ORISON_GODOT_EXE selects a diagnostic control engine; absent either setting,
the existing official 4.7.1 executable remains the fallback.

The backport uses portable LLVM MinGW. D3D12, WinRT and AccessKit are disabled
because their SDKs are not present on this build host; qualification is Vulkan.
Other default editor features and the 4.7.1 GDExtension API remain enabled.
A fresh checkout must build/configure its local engine before claiming the RID
fix. Never suppress the official-engine warning or disable room reflections.

## Windows release exports

The editor pin does not select the executable shipped in an export. Build the
same patched source as a release template before using the friends exporter:

    python tools/build_godot_reflection_fix.py --target template_release

An existing verified archive/compiler cache can be reused without making another
copy of the toolchain. On the current host, the explicit cache command is:

    python tools/build_godot_reflection_fix.py --target template_release --archive-directory C:/devkit/tentacle-engine-fix --compiler-directory C:/devkit/tentacle-engine-fix/llvm-mingw-20261020-ucrt-x86_64 --jobs 8

This is CPU compilation, not a Godot launch. Coordinate its completion with the
performance owner before timed captures. It keeps the editor pin and installed
official templates unchanged. Only the exact LLVM x86_64 release outputs are
staged in the ignored `game/.godot/orison_templates/` cache. The Windows release
preset names that local runtime explicitly; there is no stock-template fallback.

    python tools/build_godot_reflection_fix.py --check-template

This read-only check requires both runtime and console hashes, the pinned source
archives and both current patches. `tools/export_friends_build.ps1` checks it
before and after export and records template provenance alongside the exported
EXE/PCK hashes. Each attempt gets a fresh log and receipt. Preserve failed attempts.
Warm the exact source checkout through `tools/warm_release_checkout.ps1` as usual.
Deleting the Godot cache requires rebuilding/staging the local template again;
`--configure-only --target template_release` can restage existing compiled outputs
when the verified archives are supplied. Compilation/staging is not package or
renderer qualification: the actual exported game still needs a FIFO-lane smoke
and shutdown check on the hidden desktop. Android and Windows debug exports are
outside this release-template qualification.

Run the minimal control only through the Godot lane:

    pwsh -File tools/lane.ps1 run -Scene res://tests/ReflectionAtlasRetirementTest.tscn -Windowed -TimeoutSeconds 90 -LogPath tmp/atlas.log -ShotDir tmp/atlas

Compare the complete shutdown stderr, not only the test's owner-retirement
contract. The installed-world and surface runs must also finish cleanly.
