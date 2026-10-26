# Godot 4.7.1 reflection-atlas retirement

The official 4.7.1 renderer leaves the reflection atlas color buffer alive.
Its six dependent face views account for the other six leaked Texture RIDs.
This reproduces without tentacles, lamp fields, or a composed world.

This directory retains the three-line upstream fix from
https://github.com/godotengine/godot/pull/124743 (29d351f9eb0dd7582469ad38e215e9902204df12).
The source report is https://github.com/godotengine/godot/issues/122498.
Freeing the parent buffer also frees its dependent views; do not free them twice.

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

Run the minimal control only through the Godot lane:

    pwsh -File tools/lane.ps1 run -Scene res://tests/ReflectionAtlasRetirementTest.tscn -Windowed -TimeoutSeconds 90 -LogPath tmp/atlas.log -ShotDir tmp/atlas

Compare the complete shutdown stderr, not only the test's owner-retirement
contract. The installed-world and surface runs must also finish cleanly.
