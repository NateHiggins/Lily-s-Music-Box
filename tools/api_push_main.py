"""Land local main on origin without pushing a pack.

Every blob is already on the remote (reachable from tmp-push-chunks).
The HTTPS transport rejects the 1.3 GB pack a normal push builds, so:
recreate the missing trees and the two commits SHA-exactly through the
Git Data API, then fast-forward refs/heads/main. Sanity first: recreate
the existing remote head commit and require the API to return its own
sha, proving our serialization is byte-perfect.
"""
import json
import re
import subprocess
import sys
import urllib.request

REPO = "NateHiggins/Lily-s-Music-Box"
ROOT = "C:/PleaseRemainOnTheLine"
BASE = "282a4d0"
COMMITS = []  # filled from git rev-list below

TOKEN = subprocess.run(["gh", "auth", "token"], capture_output=True,
                       text=True).stdout.strip()


def git(args, binary=False):
    r = subprocess.run(["git", "-C", ROOT] + args, capture_output=True,
                       text=not binary)
    if r.returncode != 0:
        sys.exit("git %s failed: %s" % (args, r.stderr))
    return r.stdout


def api(method, path, payload=None):
    req = urllib.request.Request(
        "https://api.github.com/repos/%s/%s" % (REPO, path),
        data=json.dumps(payload).encode() if payload is not None else None,
        method=method,
        headers={"Authorization": "Bearer " + TOKEN,
                 "Accept": "application/vnd.github+json",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as err:
        sys.exit("API %s %s -> %s: %s"
                 % (method, path, err.code, err.read().decode()[:500]))


def iso(ts, tz):
    return "%s%s:%s" % (
        __import__("datetime").datetime.utcfromtimestamp(
            int(ts) + (1 if tz[0] == "+" else -1)
            * (int(tz[1:3]) * 3600 + int(tz[3:5]) * 60)
        ).strftime("%Y-%m-%dT%H:%M:%S"), tz[:3], tz[3:5])


def create_commit(sha):
    raw = subprocess.run(
        ["git", "-C", ROOT, "cat-file", "commit", sha],
        capture_output=True).stdout
    header, message = raw.split(b"\n\n", 1)
    tree = parents = None
    parents = []
    author = committer = None
    for line in header.split(b"\n"):
        text = line.decode()
        if text.startswith("tree "):
            tree = text[5:]
        elif text.startswith("parent "):
            parents.append(text[7:])
        elif text.startswith(("author ", "committer ")):
            kind, rest = text.split(" ", 1)
            m = re.match(r"(.*) <(.*)> (\d+) ([+-]\d{4})$", rest)
            person = {"name": m.group(1), "email": m.group(2),
                      "date": iso(m.group(3), m.group(4))}
            if kind == "author":
                author = person
            else:
                committer = person
    made = api("POST", "git/commits", {
        "message": message.decode(), "tree": tree, "parents": parents,
        "author": author, "committer": committer})
    return made["sha"]


def main():
    # ---- sanity: the remote head must round-trip to its own sha
    base_full = git(["rev-parse", BASE]).strip()
    got = create_commit(base_full)
    if got != base_full:
        sys.exit("SERIALIZATION MISMATCH on %s -> %s; aborting before "
                 "touching anything" % (base_full, got))
    print("serialization proven byte-exact on", base_full[:7])

    commits = git(["rev-list", "--reverse", "%s..main" % BASE]).split()

    # ---- trees the remote lacks, bottom-up
    have = set()  # objects known to exist remotely
    for line in git(["rev-list", "--objects", BASE,
                     "tmp-push-chunks"]).splitlines():
        if line.strip():
            have.add(line.split()[0])

    def ensure_blob(oid):
        if oid in have:
            return
        import base64
        raw = subprocess.run(["git", "-C", ROOT, "cat-file", "blob", oid],
                             capture_output=True).stdout
        made = api("POST", "git/blobs", {
            "content": base64.b64encode(raw).decode(),
            "encoding": "base64"})
        if made["sha"] != oid:
            sys.exit("BLOB MISMATCH %s -> %s" % (oid, made["sha"]))
        have.add(oid)
        print("blob", oid[:7], "uploaded (%d bytes)" % len(raw))

    def ensure_tree(tree_oid):
        if tree_oid in have:
            return
        entries = []
        for line in git(["ls-tree", tree_oid]).splitlines():
            meta, name = line.split("\t", 1)
            mode, otype, oid = meta.split()
            if otype == "tree":
                ensure_tree(oid)
            elif otype == "blob":
                ensure_blob(oid)
            entries.append({"path": name, "mode": mode,
                            "type": otype, "sha": oid})
        made = api("POST", "git/trees", {"tree": entries})
        if made["sha"] != tree_oid:
            sys.exit("TREE MISMATCH %s -> %s" % (tree_oid, made["sha"]))
        have.add(tree_oid)
        print("tree", tree_oid[:7], "created")

    for sha in commits:
        ensure_tree(git(["rev-parse", sha + "^{tree}"]).strip())
        got = create_commit(sha)
        if got != sha:
            sys.exit("COMMIT MISMATCH %s -> %s" % (sha, got))
        print("commit", sha[:7], "recreated exactly")

    # ---- fast-forward main (no force: bail if the remote moved)
    tip = commits[-1]
    api("PATCH", "git/refs/heads/main", {"sha": tip, "force": False})
    print("refs/heads/main ->", tip[:7])


if __name__ == "__main__":
    main()
