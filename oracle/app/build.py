"""Build the phone app: one page, and the Android package that carries it.

    python -m oracle.app.build [--out DIR] [--no-apk]

Step one writes `blank_deck.html`: the touch screen (`web/app.html`, `app.css`, `app.js`), the
engine (`web/engine.js`) and every authored room, in one file that needs nothing else and asks
the network for nothing. The rooms are exported from the same loader the Python program uses,
so they are the same rooms.

Step two wraps that page in an Android app with the Android SDK's own tools (aapt2, javac, d8,
zipalign, apksigner). No Gradle, nothing downloaded. When the SDK or a Java kit is not on this
machine the step says so and the page is still written.

The package is signed with a key made on this machine and kept in the program's data folder
(`~/.blank-deck/android/debug.keystore`), so that a later build installs over an earlier one.
It is a debug key: good for your own phone, not for a store. `--keystore` names another.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

from .. import __version__
from ..content import Registry, load_registry
from ..session import data_dir

HERE = Path(__file__).resolve().parent
WEB = HERE / "web"
ANDROID = HERE / "android"

TITLE = "The Blank Deck"
HTML_NAME = "blank_deck.html"
APK_NAME = "blank_deck.apk"
APP_ID = "org.blankdeck.app"                 # the package the app installs as; the Java package stays as written
MIN_SDK, TARGET_SDK = 26, 34
DEBUG_ALIAS = "blankdeck"
DEBUG_PASSWORD = "android"                   # the Android convention for a debug key; it protects nothing
PASSWORD_ENV = "BLANK_DECK_KEYSTORE_PASSWORD"
VERSION_EPOCH = 1767225600                   # 2026-01-01: version codes count minutes from here, so they only rise

# What the engine in the page never reads: notes for a narrating model, and notes for authors.
_SEED_SKIP = {"premise", "reads", "motifs"}

# The standalone page may run nothing it did not arrive with, and may reach nothing at all.
CONTENT_POLICY = ("default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; "
                  "base-uri 'none'; form-action 'none'")
# Inside a viewer the frame pads for the phone's bars; the standalone page does it itself.
STANDALONE_CSS = ("html { box-sizing: border-box; padding-top: env(safe-area-inset-top, 0px); }\n"
                  ":root { --safe-bottom: env(safe-area-inset-bottom, 0px); }")
# Last on the page, in the oldest JavaScript there is: if the game's own scripts could not even be
# read by this browser, say so instead of showing a dead screen.
TOO_OLD = ('if (!window.BLANK_DECK_STARTED) { var b = document.getElementById("broken"); '
           'if (b && b.hidden) { b.hidden = false; b.textContent = "The house cannot open here: this browser is too old '
           'for it. On Android, update Android System WebView (or Chrome) in the Play Store, then open the app again."; } }')


class BuildError(Exception):
    """The page or the package could not be built."""


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------
def export_content(registry: Registry) -> dict:
    """The authored content as the page's engine reads it: validated by the Python loader, with
    its labels already made into words, and without the parts only a narrating model would use."""
    seeds = {sid: {k: v for k, v in seed.items() if k not in _SEED_SKIP} for sid, seed in registry.seeds.items()}
    signals = {sid: {k: v for k, v in signal.items() if k != "desc" or not signal.get("seen")}
               for sid, signal in registry.signals.items()}
    return {
        "version": __version__,
        "dims": {dim.id: dataclasses.asdict(dim) for dim in registry.dims.values()},
        "seeds": seeds,
        "skins": registry.skins,
        "signals": signals,
        "implications": {k: v for k, v in registry.implications.items() if k not in ("meta", "schema_version")},
        "reading": {k: v for k, v in registry.reading.items() if k not in ("meta", "schema_version")},
        "texts": {"build_prompt": registry.texts["build_prompt"]},
    }


def _source(name: str) -> str:
    """A file of the page, with the line endings the repository holds (not the checkout's)."""
    return (WEB / name).read_bytes().decode("utf-8").replace("\r\n", "\n").strip()


def _inline_data(data: dict) -> str:
    """The content as a JavaScript value that cannot end the script element it sits in."""
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    return (text.replace("</", "<\\/").replace("<!--", "<\\u0021--")
                .replace("\u2028", "\\u2028").replace("\u2029", "\\u2029"))


def _script(code: str) -> str:
    low = code.lower()
    if "</script" in low or "<!--" in low:
        raise BuildError("a script of the page contains text that would end its own element")
    return "<script>\n" + code + "\n</script>"


def build_html(registry: Registry | None = None) -> dict:
    """The game as one page. Returns two forms of the same thing:

    `document`: a whole HTML file, for the Android app and for opening in any browser.
    `fragment`: the page without its outer skeleton, for a viewer that supplies its own.
    """
    registry = registry or load_registry()
    css, markup = _source("app.css"), _source("app.html")
    content = "window.BLANK_DECK_CONTENT = " + _inline_data(export_content(registry)) + ";"
    scripts = "\n".join(_script(code) for code in (content, _source("engine.js"), _source("app.js"), TOO_OLD))
    fragment = f"<title>{TITLE}</title>\n<style>\n{css}\n</style>\n{markup}\n{scripts}\n"
    document = "\n".join([
        "<!doctype html>",
        '<html lang="en">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, '
        'interactive-widget=resizes-content">',
        f'<meta http-equiv="Content-Security-Policy" content="{CONTENT_POLICY}">',
        '<meta name="color-scheme" content="dark">',
        '<meta name="theme-color" content="#07140f">',
        f"<title>{TITLE}</title>",
        f"<style>\n{css}\n{STANDALONE_CSS}\n</style>",
        "</head>",
        "<body>",
        markup,
        scripts,
        "</body>",
        "</html>",
        "",
    ])
    return {"document": document, "fragment": fragment, "version": __version__}


# ---------------------------------------------------------------------------
# The tools on this machine
# ---------------------------------------------------------------------------
@dataclasses.dataclass
class Toolchain:
    sdk: Path
    build_tools: Path
    android_jar: Path
    aapt2: Path
    zipalign: Path
    d8_jar: Path
    apksigner_jar: Path
    java: str
    javac: str
    keytool: str

    def describe(self) -> str:
        return f"build-tools {self.build_tools.name}, {self.android_jar.parent.name}"


def _numbers(name: str) -> tuple:
    return tuple(int(part) for part in re.findall(r"\d+", name))


def _sdk_roots() -> list[Path]:
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    if os.environ.get("LOCALAPPDATA"):
        roots.append(str(Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk"))
    roots += [str(Path.home() / "Android" / "Sdk"), str(Path.home() / "Library" / "Android" / "sdk")]
    return [Path(root) for root in roots if root]


def _java_tool(name: str) -> str | None:
    exe = name + (".exe" if os.name == "nt" else "")
    home = os.environ.get("JAVA_HOME")
    if home and (Path(home) / "bin" / exe).is_file():
        return str(Path(home) / "bin" / exe)
    return shutil.which(name)


def find_toolchain() -> tuple[Toolchain | None, str]:
    """The Android SDK's tools and a Java kit, or None and the reason, in words a person can act on."""
    exe = ".exe" if os.name == "nt" else ""
    sdk = next((root for root in _sdk_roots() if (root / "build-tools").is_dir()), None)
    if sdk is None:
        return None, ("no Android SDK was found (looked at ANDROID_HOME, ANDROID_SDK_ROOT and the usual folders). "
                      "Android Studio installs one; so do the SDK command-line tools.")
    build_tools = None
    for folder in sorted((p for p in (sdk / "build-tools").iterdir() if p.is_dir()), key=lambda p: _numbers(p.name),
                         reverse=True):
        needed = (folder / f"aapt2{exe}", folder / f"zipalign{exe}", folder / "lib" / "d8.jar",
                  folder / "lib" / "apksigner.jar")
        if all(path.is_file() for path in needed):
            build_tools = folder
            break
    if build_tools is None:
        return None, f"the Android SDK at {sdk} has no complete build-tools (aapt2, zipalign, d8, apksigner)."
    platforms = sdk / "platforms"
    jars = sorted((p for p in platforms.glob("android-*/android.jar") if _numbers(p.parent.name)[:1] >= (TARGET_SDK,)),
                  key=lambda p: _numbers(p.parent.name)) if platforms.is_dir() else []
    if not jars:
        return None, f"the Android SDK at {sdk} has no platform android-{TARGET_SDK} or later."
    java, javac, keytool = _java_tool("java"), _java_tool("javac"), _java_tool("keytool")
    if not (java and javac and keytool):
        return None, "no Java development kit was found (java, javac and keytool; set JAVA_HOME or put them on PATH)."
    return Toolchain(sdk=sdk, build_tools=build_tools, android_jar=jars[0], aapt2=build_tools / f"aapt2{exe}",
                     zipalign=build_tools / f"zipalign{exe}", d8_jar=build_tools / "lib" / "d8.jar",
                     apksigner_jar=build_tools / "lib" / "apksigner.jar", java=java, javac=javac, keytool=keytool), ""


def _run(step: str, command: list, cwd: Path, env: dict | None = None) -> str:
    try:
        done = subprocess.run([str(part) for part in command], cwd=str(cwd), env=env, capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=600)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise BuildError(f"{step} could not run: {exc}") from exc
    if done.returncode != 0:
        said = (done.stdout + "\n" + done.stderr).strip()
        raise BuildError(f"{step} failed (exit {done.returncode}):\n{said[-3000:]}")
    return done.stdout + done.stderr


# ---------------------------------------------------------------------------
# The package
# ---------------------------------------------------------------------------
def default_keystore() -> Path:
    return data_dir() / "android" / "debug.keystore"


def _ensure_debug_key(tools: Toolchain, keystore: Path, work: Path) -> None:
    if keystore.is_file():
        return
    keystore.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, **{PASSWORD_ENV: DEBUG_PASSWORD})
    _run("keytool", [tools.keytool, "-genkeypair", "-keystore", keystore, "-storetype", "PKCS12",
                     "-alias", DEBUG_ALIAS, "-keyalg", "RSA", "-keysize", "2048", "-validity", "10950",
                     "-dname", "CN=The Blank Deck debug key, O=Built on this machine",
                     "-storepass:env", PASSWORD_ENV, "-keypass:env", PASSWORD_ENV], work, env)


def inspect_apk(tools: Toolchain, apk: Path, work: Path | None = None) -> dict:
    """What a built package says about itself, read with the SDK's own tools."""
    work = work or apk.parent
    badging = _run("aapt2 dump", [tools.aapt2, "dump", "badging", apk], work)
    package = re.search(r"package: name='([^']*)' versionCode='([^']*)' versionName='([^']*)'", badging)
    if not package:
        raise BuildError("the package does not describe itself:\n" + badging[:800])
    minimum = re.search(r"(?m)^(?:minSdkVersion|sdkVersion):'(\d+)'", badging)      # older tools say sdkVersion
    target = re.search(r"(?m)^targetSdkVersion:'(\d+)'", badging)
    label = re.search(r"(?m)^application-label:'([^']*)'", badging)
    verified = _run("apksigner verify", [tools.java, "-jar", tools.apksigner_jar, "verify", "--print-certs",
                                         "--min-sdk-version", str(MIN_SDK), apk], work)
    digest = re.search(r"certificate SHA-256 digest: ([0-9a-f]+)", verified)
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        stored = {info.filename: info.compress_type == zipfile.ZIP_STORED for info in archive.infolist()}
        page = archive.read("assets/index.html") if "assets/index.html" in names else b""
    return {
        "package": package.group(1), "version_code": int(package.group(2)), "version_name": package.group(3),
        "min_sdk": int(minimum.group(1)) if minimum else None, "target_sdk": int(target.group(1)) if target else None,
        "label": label.group(1) if label else "",
        "permissions": re.findall(r"(?m)^uses-permission(?:-sdk-\d+)?: name='([^']*)'", badging),
        "certificate_sha256": digest.group(1) if digest else "",
        "files": names, "resources_stored": stored.get("resources.arsc", False), "page": page,
    }


def build_apk(document: str, out: Path, *, tools: Toolchain | None = None, app_id: str = APP_ID,
              version_code: int | None = None, keystore: Path | None = None, alias: str | None = None) -> dict:
    """Wrap the page in an Android package, sign it, and check what was made. Returns what it is."""
    if tools is None:
        tools, reason = find_toolchain()
        if tools is None:
            raise BuildError(reason)
    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", app_id):
        raise BuildError(f"{app_id!r} is not a package name (lower-case words joined by dots, like {APP_ID}).")
    if version_code is None:
        version_code = max(1, int(time.time() - VERSION_EPOCH) // 60)
    own_key = keystore is None
    keystore = Path(keystore) if keystore else default_keystore()
    if not own_key:
        if not keystore.is_file():
            raise BuildError(f"no keystore at {keystore}.")
        if not os.environ.get(PASSWORD_ENV):
            raise BuildError(f"to sign with {keystore}, put its password in the environment variable {PASSWORD_ENV}.")
    env = dict(os.environ) if not own_key else dict(os.environ, **{PASSWORD_ENV: DEBUG_PASSWORD})
    page = document.encode("utf-8")

    with tempfile.TemporaryDirectory(prefix="blank-deck-apk-") as tmp:
        work = Path(tmp)
        shutil.copytree(ANDROID / "res", work / "res")
        (work / "assets").mkdir()
        (work / "assets" / "index.html").write_bytes(page)
        manifest = (ANDROID / "AndroidManifest.xml").read_bytes().decode("utf-8")
        if manifest.count(f'package="{APP_ID}"') != 1:
            raise BuildError("the manifest no longer names its package the way the build expects.")
        (work / "AndroidManifest.xml").write_bytes(manifest.replace(f'package="{APP_ID}"', f'package="{app_id}"')
                                                   .encode("utf-8"))
        if own_key:
            _ensure_debug_key(tools, keystore, work)

        _run("aapt2 compile", [tools.aapt2, "compile", "--dir", "res", "-o", "compiled.zip"], work)
        _run("aapt2 link", [tools.aapt2, "link", "-o", "linked.apk", "-I", tools.android_jar,
                            "--manifest", "AndroidManifest.xml", "-A", "assets",
                            "--min-sdk-version", str(MIN_SDK), "--target-sdk-version", str(TARGET_SDK),
                            "--version-code", str(version_code), "--version-name", __version__, "compiled.zip"], work)

        sources = sorted((ANDROID / "src").rglob("*.java"))
        (work / "classes").mkdir()
        _run("javac", [tools.javac, "-source", "8", "-target", "8", "-Xlint:-options", "-encoding", "UTF-8",
                       "-bootclasspath", tools.android_jar, "-d", "classes", *sources], work)
        classes = sorted((work / "classes").rglob("*.class"))
        (work / "dex").mkdir()
        _run("d8", [tools.java, "-cp", tools.d8_jar, "com.android.tools.r8.D8", "--release",
                    "--min-api", str(MIN_SDK), "--lib", tools.android_jar, "--output", "dex", *classes], work)

        with zipfile.ZipFile(work / "linked.apk", "a") as archive:
            entry = zipfile.ZipInfo("classes.dex", date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, (work / "dex" / "classes.dex").read_bytes())
        _run("zipalign", [tools.zipalign, "-f", "-p", "4", "linked.apk", "aligned.apk"], work)
        _run("apksigner sign", [tools.java, "-jar", tools.apksigner_jar, "sign", "--ks", keystore,
                                "--ks-key-alias", alias or DEBUG_ALIAS, "--ks-pass", f"env:{PASSWORD_ENV}",
                                "--key-pass", f"env:{PASSWORD_ENV}", "--out", "signed.apk", "aligned.apk"], work, env)

        facts = inspect_apk(tools, work / "signed.apk", work)
        problems = []
        if facts["permissions"]:
            problems.append("it asks for permissions: " + ", ".join(facts["permissions"]))
        if facts["page"] != page:
            problems.append("the page inside it is not the page that was built")
        if not facts["resources_stored"]:
            problems.append("its resource table is compressed, which Android 11 and later refuse")
        if "classes.dex" not in facts["files"]:
            problems.append("it has no code")
        if facts["package"] != app_id or facts["min_sdk"] != MIN_SDK or facts["target_sdk"] != TARGET_SDK:
            problems.append(f"it describes itself as {facts['package']} for SDK {facts['min_sdk']} to {facts['target_sdk']}")
        if problems:
            raise BuildError("the package was built wrong: " + "; ".join(problems) + ".")
        out = Path(out)
        try:
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(work / "signed.apk", out)
        except OSError as exc:
            raise BuildError(f"could not write {out}: {exc}") from exc

    del facts["page"]
    facts.update({"path": out, "bytes": out.stat().st_size, "keystore": keystore, "debug_key": own_key,
                  "toolchain": tools.describe()})
    return facts


# ---------------------------------------------------------------------------
# The command
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m oracle.app.build", description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", default="build", help="the folder to write into (default: build)")
    parser.add_argument("--no-apk", action="store_true", help="write the page only")
    parser.add_argument("--fragment", metavar="FILE",
                        help="also write the page without its outer skeleton, for a viewer that supplies its own")
    parser.add_argument("--package", default=APP_ID, help=f"the name the app installs as (default: {APP_ID})")
    parser.add_argument("--version-code", type=int, help="the package's version number (default: from the clock)")
    parser.add_argument("--keystore", help=f"sign with this keystore; its password is read from {PASSWORD_ENV}")
    parser.add_argument("--alias", help="the key's name in that keystore")
    args = parser.parse_args(argv)

    out = Path(args.out)
    try:
        page = build_html()
        out.mkdir(parents=True, exist_ok=True)
        html = out / HTML_NAME
        html.write_bytes(page["document"].encode("utf-8"))
        print(f"The page: {html.resolve()} ({html.stat().st_size:,} bytes). It opens in any browser and needs nothing else.")
        if args.fragment:
            fragment = Path(args.fragment)
            fragment.parent.mkdir(parents=True, exist_ok=True)
            fragment.write_bytes(page["fragment"].encode("utf-8"))
            print(f"The page without its skeleton: {fragment.resolve()}")
        if args.no_apk:
            return 0
        tools, reason = find_toolchain()
        if tools is None:
            print(f"The Android package was NOT built: {reason}", file=sys.stderr)
            return 1
        made = build_apk(page["document"], out / APK_NAME, tools=tools, app_id=args.package,
                         version_code=args.version_code, keystore=Path(args.keystore) if args.keystore else None,
                         alias=args.alias)
    except (BuildError, OSError) as exc:
        print(f"Not built: {exc}", file=sys.stderr)
        return 1
    asks = ", ".join(made["permissions"]) or "none"
    print(f"The Android package: {made['path'].resolve()} ({made['bytes']:,} bytes)")
    print(f"  {made['label']} {made['version_name']} (build {made['version_code']}), installs as {made['package']}")
    print(f"  Android {MIN_SDK_NAME} or later. Permissions it asks for: {asks}.")
    print(f"  Built with {made['toolchain']}. Signature checked; signed with "
          f"{'the debug key at' if made['debug_key'] else 'the key in'} {made['keystore']}")
    print("  To put it on a phone: copy the file over and open it there (the phone will ask whether to allow the")
    print("  install), or, with the phone connected and USB debugging on:  adb install -r " + str(made["path"]))
    return 0


MIN_SDK_NAME = "8.0"                           # what Android calls API level 26

if __name__ == "__main__":
    sys.exit(main())
