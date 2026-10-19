"""Build/verify the Windows numerical extension. No Godot process is launched.

Requires CMake, Ninja, Zig, and a clean godot-cpp checkout at SDK_COMMIT.
Dependencies are explicit local paths; this tool performs no downloads.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "game/native/hose_math"
SDK_COMMIT = "27d9dd23c83871e0619fca5dc2cddfbfd69e926a"
MANIFEST = MODULE / "build_manifest.json"
BINARY = MODULE / "bin/orison_hose_math.windows.x86_64.dll"
SOURCES = [Path(__file__).resolve(), MODULE / "CMakeLists.txt", MODULE / "build_profile.json", *sorted((MODULE / "src").glob("*.cpp"))]

def digest(path: Path, text: bool = False) -> str:
    raw = path.read_bytes()
    if text:
        raw = raw.replace(b"\r\n", b"\n")
    return hashlib.sha256(raw).hexdigest()

def bindings() -> dict:
    return {p.relative_to(ROOT).as_posix(): digest(p, True) for p in SOURCES}

def verify() -> dict:
    value = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if value.get("schema") != "orison.hose-math-build.v1" or value.get("sdk_commit") != SDK_COMMIT:
        raise ValueError("Unknown native build manifest")
    if value.get("sources") != bindings() or value.get("binary_sha256") != digest(BINARY):
        raise ValueError("Native source/binary binding is stale; rebuild before qualification")
    return value

def run(*args) -> None:
    subprocess.run([str(a) for a in args], check=True)

def configure(source: Path, directory: Path, options: list[str], compiler: Path) -> None:
    fresh = False
    cache = directory / "CMakeCache.txt"
    if cache.exists():
        fields = {}
        for line in cache.read_text(encoding="utf-8").splitlines():
            if ":" in line and "=" in line and not line.startswith(("#", "//")):
                key, value = line.split("=", 1)
                fields[key.split(":", 1)[0]] = value
        if Path(fields.get("CMAKE_HOME_DIRECTORY", "")).resolve() != source.resolve():
            raise ValueError("Refusing to reuse a build directory owned by another source tree")
        fresh = Path(fields.get("CMAKE_CXX_COMPILER", "")).resolve() != compiler.resolve()
    # --fresh only clears the verified CMake build cache when its compiler
    # changes; otherwise a reset can silently discard the supplied SDK paths.
    run("cmake", *(["--fresh"] if fresh else []), "-S", source, "-B", directory, *options)

def build(args) -> None:
    sdk, sdk_build, build_dir, zig = [Path(p).resolve() for p in (args.sdk_source, args.sdk_build, args.build_dir, args.zig)]
    commit = subprocess.check_output(["git", "-C", str(sdk), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(sdk), "status", "--porcelain"], text=True).strip()
    if commit != SDK_COMMIT or dirty:
        raise ValueError("godot-cpp must be clean at the pinned commit")
    driver = build_dir / "driver"
    driver.mkdir(parents=True, exist_ok=True)
    for filename, command in [("cxx", "c++ -target x86_64-windows-gnu"), ("ar", "ar"), ("ranlib", "ranlib")]:
        (driver / (filename + ".cmd")).write_text(f'@echo off\n"{zig}" {command} %*\n', encoding="utf-8")
    # A compiler-wrapper path has no adjacent llvm-ar. Override the normal
    # variables after project()/compiler detection, not only their cache entries.
    override = driver / "archive_tools.cmake"
    override.write_text(f'set(CMAKE_AR "{(driver / "ar.cmd").as_posix()}")\nset(CMAKE_RANLIB "{(driver / "ranlib.cmd").as_posix()}")\n', encoding="utf-8")
    common = ["-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release",
              f"-DCMAKE_PROJECT_INCLUDE:FILEPATH={override.as_posix()}",
              f"-DCMAKE_CXX_COMPILER:FILEPATH={(driver / 'cxx.cmd').as_posix()}",
              f"-DCMAKE_AR:FILEPATH={(driver / 'ar.cmd').as_posix()}",
              f"-DCMAKE_RANLIB:FILEPATH={(driver / 'ranlib.cmd').as_posix()}",
              f"-DCMAKE_CXX_COMPILER_AR:FILEPATH={(driver / 'ar.cmd').as_posix()}",
              f"-DCMAKE_CXX_COMPILER_RANLIB:FILEPATH={(driver / 'ranlib.cmd').as_posix()}"]
    sdk_options = [*common, "-DGODOTCPP_TARGET=template_release", f"-DGODOTCPP_BUILD_PROFILE={(MODULE / 'build_profile.json').as_posix()}"]
    # CMake clears cache options when the compiler path changes. Configure
    # again before building, then confirm that the small release profile won.
    configure(sdk, sdk_build, sdk_options, driver / "cxx.cmd")
    configure(sdk, sdk_build, sdk_options, driver / "cxx.cmd")
    cache = (sdk_build / "CMakeCache.txt").read_text(encoding="utf-8")
    expected_profile = (MODULE / "build_profile.json").as_posix()
    if not any(line.startswith("GODOTCPP_BUILD_PROFILE:") and line.split("=", 1)[-1] == expected_profile for line in cache.splitlines()):
        raise ValueError("SDK build profile was not retained by CMake")
    if "GODOTCPP_TARGET:STRING=template_release" not in cache:
        raise ValueError("SDK release configuration was not retained")
    if "CMAKE_AR-NOTFOUND" in (sdk_build / "CMakeFiles/rules.ninja").read_text(encoding="utf-8"):
        raise ValueError("SDK archive driver was not retained")
    run("cmake", "--build", sdk_build, "--parallel", args.jobs)
    configure(MODULE, build_dir, [*common, f"-DGODOT_CPP_SOURCE={sdk.as_posix()}", f"-DGODOT_CPP_BUILD={sdk_build.as_posix()}"], driver / "cxx.cmd")
    run("cmake", "--build", build_dir, "--parallel", args.jobs)
    value = {
        "schema": "orison.hose-math-build.v1", "sdk_commit": SDK_COMMIT,
        "zig_version": subprocess.check_output([str(zig), "version"], text=True).strip(),
        "sdk_library_sha256": digest(sdk_build / "bin/libgodot-cpp.windows.template_release.x86_64.a"),
        "sources": bindings(), "binary_sha256": digest(BINARY),
        "scope": "Numerical build binding only; not runtime or appearance acceptance.",
    }
    MANIFEST.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    verify()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--sdk-source")
    parser.add_argument("--sdk-build")
    parser.add_argument("--build-dir")
    parser.add_argument("--zig")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    if not args.verify:
        if not all([args.sdk_source, args.sdk_build, args.build_dir, args.zig]) or not 1 <= args.jobs <= 16:
            parser.error("Build requires --sdk-source, --sdk-build, --build-dir, --zig and 1..16 jobs")
        build(args)
    else:
        verify()
    print("Native hose source/binary binding: PASS")
