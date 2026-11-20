#!/usr/bin/env bash
# peng-reapply-rename.sh — re-assert the fork's plugin identity after an upstream merge.
#
# Upstream rewrites many files that carry the plugin id (the CDP scripts especially), so a
# `git merge upstream/main` can silently restore `live-image-editor` where this fork needs
# `live-image-editor-peng`. This script re-applies the rename over an explicit allowlist.
#
# Usage:
#   bash scripts/peng-reapply-rename.sh            # apply
#   bash scripts/peng-reapply-rename.sh --check    # report only; exit 1 if residue found
#
# It is idempotent: already-renamed text is left alone.
#
# NEVER extend the allowlist to styles.css, src/transforms.ts, src/link-format.ts,
# vault-image-toolbar/**, or docs/development/** — see FORK.md §4 for the reasoning.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  "") ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

exec python3 - "$CHECK" "$ROOT" <<'PY'
import glob
import os
import re
import sys

check = sys.argv[1] == "1"
root = sys.argv[2]

OLD, NEW = "live-image-editor", "live-image-editor-peng"
# Negative lookahead so an already-renamed token is not matched twice.
PATTERN = re.compile(re.escape(OLD) + r"(?!-peng)")

ALLOWLIST = [
    "manifest.json",
    "package.json",
    "package-lock.json",
    "src/brand-icon.ts",
    "src/bundled-snippet.ts",
    "src/editing-toolbar-integration.ts",
    "src/main.ts",
    "scripts/dev-install.sh",
    "scripts/obsidian-debug.mjs",
    "scripts/shoot-docs.mjs",
    "scripts/mkdocs_hooks.py",
]
ALLOWLIST += sorted(os.path.relpath(p, root) for p in glob.glob(os.path.join(root, "tests/cdp/*.mjs")))

FORBIDDEN = (
    "styles.css",
    "src/transforms.ts",
    "src/link-format.ts",
    "vault-image-toolbar/",
    "docs/development/",
)

def is_forbidden(rel):
    return any(rel == f or rel.startswith(f) for f in FORBIDDEN)

residue, changed, missing = [], [], []

for rel in ALLOWLIST:
    if is_forbidden(rel):
        sys.exit(f"refusing: {rel} is on the do-not-touch list (FORK.md §4)")

    path = os.path.join(root, rel)
    if not os.path.exists(path):
        missing.append(rel)
        continue

    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    hits = PATTERN.findall(text)
    if not hits:
        continue

    residue.append((rel, len(hits)))

    if not check:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(PATTERN.sub(NEW, text))
        changed.append((rel, len(hits)))

if missing:
    print("skipped (not present): " + ", ".join(missing))

if check:
    if not residue:
        print("OK — no stale `live-image-editor` token in the allowlist.")
        sys.exit(0)
    print("STALE TOKEN FOUND — upstream likely restored it:")
    for rel, n in residue:
        print(f"  {rel}: {n}")
    print("\nRun `bash scripts/peng-reapply-rename.sh`, then review `git diff`.")
    sys.exit(1)

if not changed:
    print("Nothing to do — identity already consistent.")
    sys.exit(0)

print(f"Re-applied `{OLD}` -> `{NEW}`:")
for rel, n in changed:
    print(f"  {rel}: {n}")
print("\nReview with `git diff` before committing.")
PY
