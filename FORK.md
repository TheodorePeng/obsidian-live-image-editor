# FORK.md — what this fork is, and what it may change

This repository is a **personal maintenance fork** of
[`Britz/obsidian-live-image-editor`](https://github.com/Britz/obsidian-live-image-editor) by
[TheodorePeng](https://github.com/TheodorePeng).

The original project is MIT licensed. **The license, its copyright line (`Copyright (c) 2026 Britz`)
and the upstream authorship are unchanged and must stay unchanged.** This fork claims no authorship
of the original work.

Why fork: upstream's non-destructive editing model is good, but the plugin perturbs the layout of
existing notes. The fork exists to fix that on a private branch without waiting on upstream release
cadence — see [`docs/fork/layout-assessment.md`](docs/fork/layout-assessment.md).

---

## 1. Identity: deliberately identical to upstream

| Layer | Value |
|---|---|
| GitHub repository | `TheodorePeng/obsidian-live-image-editor-peng` (the fork's own name) |
| Plugin ID | `live-image-editor` — **same as upstream** |
| Plugin display name | `Live Image Editor` — **same as upstream** |
| Author / authorUrl | `britz` / `https://github.com/Britz` — **same as upstream** |
| npm package name | `obsidian-live-image-editor` — **same as upstream** |

An earlier revision of this fork renamed all of the above to `…-peng`. That was **reverted on
purpose**. The current decision: keep the plugin identity byte-identical to upstream so this build is
a **drop-in replacement** — same folder, same settings file, same command ids, same CSS snippet name.
Installing it over an existing upstream install needs no migration, and notes written by either side
render the same way.

### The one real cost of this choice

Because the id matches, **this build and the upstream plugin cannot both be enabled in one vault.**
Both claim `.obsidian/plugins/live-image-editor/`, so whichever is copied in last wins, and they share
one `data.json`. Treat them as mutually exclusive:

- To test the fork, use a vault that has no upstream install — `vault-peng/` exists for exactly this.
- To go back to upstream, delete the fork's folder and reinstall from the community directory.

The upside: `main` differs from `upstream/main` only in documentation, so upstream merges carry
**zero identity conflicts**.

### Notes are safe either way

Crop/scale/rotate parameters are serialized into the **note's Markdown** as a trailing attr_list
block, e.g.:

```markdown
![[photo.png]]{aspect-ratio=1.7777 transform="translate(-12.5%, -8%) scale(2.4)" width=320}
```

The keys are plain CSS/HTML names, and CSS classes use the `lie-*` prefix. Nothing in that format is
derived from the plugin ID — which is why swapping between upstream and this fork never invalidates
an edited note.

---

## 2. Remotes and branches

```
origin    https://github.com/TheodorePeng/obsidian-live-image-editor-peng.git   (fetch + push)
upstream  https://github.com/Britz/obsidian-live-image-editor.git              (fetch only)
upstream  push URL is set to `no_push_this_remote_is_read_only`                (guard)
```

| Branch | Role |
|---|---|
| `main` | **Pure mirror of `upstream/main`. Never commit here.** |
| `personal` | All fork work. This is the repository's default branch. |

The local checkout folder is `obsidian-live-image-editor/` while the GitHub repository is
`obsidian-live-image-editor-peng` — a folder name is local, a repository name is public; they are
allowed to differ.

---

## 3. Files this fork is allowed to diverge on

Treat this as an allowlist. Anything outside it should stay identical to upstream.

| File | Allowed divergence |
|---|---|
| `README.md` | One fork banner paragraph at the top; the rest is upstream's |
| `AGENTS.md` | One "Fork overrides" block at the top |
| `FORK.md`, `docs/fork/**` | Fork-owned; upstream has no equivalent |
| `.gitignore` | `vault-peng/` entry |
| `package.json` | The `dev:vault` script path only (points at `vault-peng/`) |

That is the entire list. It is intentionally tiny.

## 4. Files this fork must NOT touch

| Do not touch | Why |
|---|---|
| `manifest.json` (`id`, `name`, `author`, `authorUrl`) | Frozen to upstream — see §1 |
| `package.json` `name`, `package-lock.json` `name` | Frozen to upstream |
| `src/brand-icon.ts`, `src/bundled-snippet.ts`, `src/editing-toolbar-integration.ts`, `src/main.ts` | Contain the id / snippet-name constants; they must keep upstream's values |
| `scripts/**`, `tests/cdp/**` | Reference the plugin id; must keep upstream's values |
| `styles.css`, every `lie-*` class name | Cosmetic identity, unrelated to the id; changing it breaks rendered notes |
| `src/transforms.ts`, `src/link-format.ts`, the attr_list format | This is the on-disk data format. Changing it invalidates every existing note. |
| `lie-runtime.js`, `dist/lie-runtime.js` filenames | Public release artifact names (jsDelivr embed paths) |
| `__LIE_DEV__`, `PREFIX = "lie"` | Internal constants |
| `LICENSE` | MIT + upstream copyright must survive verbatim |
| `docs/development/{methodology,requirements,architecture,test-plan}.md` | Upstream declares these inviolable (see `CLAUDE.md`); the fork does not get to bend them |
| `vault-image-toolbar/**` | Upstream's committed example vault; keep it pristine to avoid merge noise |
| `.github/workflows/*` | Left in place for future upstream merges; disabled at repo level instead |

---

## 5. Versioning

`package.json` is the single source of truth for `version`. `manifest.json` and `versions.json` are
generated from it by `npm run version` (`version-bump.mjs`), which only rewrites `version` and leaves
identity fields alone.

This fork currently sits at **0.6.17**, matching upstream. Fork-side fixes should keep following
upstream's patch-only rule and bump only when a real release is cut.

---

## 6. Upstream sync

See [`docs/fork/upstream-sync.md`](docs/fork/upstream-sync.md). Short version:

```bash
git fetch upstream --tags
git switch personal
git merge upstream/main        # merge, never rebase (no force pushes)
npm ci && npm run build && npm test && npm run lint
```

Because identity matches upstream, conflicts should be limited to the README banner, the AGENTS.md
block, and the `dev:vault` line — all "keep ours" one-liners.

---

## 7. Known, intentional deviations from upstream statements

- `mkdocs.yml` and `docs/development/README.md` point at `britz.github.io` / `github.com/Britz/...`.
  Left as-is: the fork deploys no docs site, and those are upstream links.
- `scripts/dev-install.sh` prints "Building (inside devcontainer)" even when it builds on the host
  (the no-podman branch). Cosmetic only.
- `CLAUDE.md` requires German replies, forbids agent commits, and forbids host builds. **Superseded
  for this fork** — see the override block at the top of `AGENTS.md`.
