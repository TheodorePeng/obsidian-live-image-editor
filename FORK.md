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

## 1. The three identities (do not conflate them)

| Layer | Value | Where it is set | Notes |
|---|---|---|---|
| GitHub repository | `TheodorePeng/obsidian-live-image-editor-peng` | GitHub | Fork of the upstream repo |
| Plugin ID | `live-image-editor-peng` | `manifest.json` → `id` | Decides the install folder `.obsidian/plugins/live-image-editor-peng/`, the `data.json` location, and the command-id prefix |
| Plugin display name | `Live Image Editor Peng` | `manifest.json` → `name` | Shown in Settings → Community plugins |

The ID was renamed **on purpose**, so this build can be installed next to the upstream plugin without
either overwriting the other. A folder named `live-image-editor/` belongs to upstream and will never
load this build.

### Renaming the ID does not break notes

Crop/scale/rotate parameters are serialized into the **note's Markdown**, as a trailing attr_list
block, e.g.:

```markdown
![[photo.png]]{aspect-ratio=1.7777 transform="translate(-12.5%, -8%) scale(2.4)" width=320}
```

The keys are plain CSS/HTML names; nothing in that block is derived from the plugin ID. CSS classes
use the `lie-*` prefix (`styles.css` contains no occurrence of `live-image-editor`). So a note
written by upstream still renders identically under this fork, and vice versa.

What **does** change with the ID — all vault-local, all expected:

- Settings live in `.obsidian/plugins/live-image-editor-peng/data.json`, not shared with upstream's.
- The bundled CSS snippet is written as `.obsidian/snippets/live-image-editor-peng.css`.
- Commands registered into Editing Toolbar are prefixed `live-image-editor-peng:`.

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

Keeping `main` byte-identical to upstream is what makes `git merge upstream/main` tractable: any
conflict is then genuinely about our edits, never about accumulated drift.

---

## 3. Files this fork is allowed to diverge on

Treat this as an allowlist. Anything outside it should stay identical to upstream.

**Identity / config**

- `manifest.json` — `id`, `name`, `author`, `authorUrl` (never `version` by hand; see §5)
- `package.json` — `name`, the `dev:vault` script path
- `package-lock.json` — the two `name` fields
- `.gitignore` — `vault-peng/` entry

**Source (one token each)**

- `src/brand-icon.ts` — `BRAND_ICON_ID`
- `src/bundled-snippet.ts` — `BUNDLED_SNIPPET_FILE`
- `src/editing-toolbar-integration.ts` — `PLUGIN_ID` (+ two comments naming the command prefix)
- `src/main.ts` — one `console.error` log prefix only

**Tooling**

- `scripts/dev-install.sh`, `scripts/obsidian-debug.mjs`, `scripts/shoot-docs.mjs` — plugin ID
- `scripts/mkdocs_hooks.py` — `_GH` repository URL
- `tests/cdp/*.mjs` — plugin ID inside CDP eval strings and vault paths

**Docs (fork-owned only)**

- `README.md` — fork banner, install section
- `FORK.md`, `AGENTS.md` (override block), `docs/fork/**`
- `scripts/peng-reapply-rename.sh`

## 4. Files this fork must NOT touch

| Do not touch | Why |
|---|---|
| `styles.css`, every `lie-*` class name | Cosmetic identity, unrelated to the plugin ID; changing it breaks rendered notes |
| `src/transforms.ts`, `src/link-format.ts`, the attr_list format | This is the on-disk data format. Changing it invalidates every existing note. |
| `lie-runtime.js`, `dist/lie-runtime.js` filenames | Public release artifact names (jsDelivr embed paths), not the plugin ID |
| `__LIE_DEV__`, `PREFIX = "lie"` | Internal constants, not plugin identity |
| `LICENSE` | MIT + upstream copyright must survive verbatim |
| `docs/development/{methodology,requirements,architecture,test-plan}.md` | Upstream declares these inviolable (see `CLAUDE.md`); the fork does not get to bend them |
| `vault-image-toolbar/**` | Upstream's committed example vault; keep it pristine to avoid merge noise |
| `.github/workflows/*` | Left in place for future upstream merges; disabled at repo level instead |

---

## 5. Versioning

`package.json` is the single source of truth for `version`. `manifest.json` and `versions.json` are
generated from it by `npm run version` (`version-bump.mjs`) — that script **only rewrites `version`
and preserves `id`/`name`**, which is why hand-editing the identity fields is safe while hand-editing
the version is not.

This fork currently sits at **0.6.17**, matching upstream. Fork-side fixes should keep following
upstream's patch-only rule and bump only when a real release is cut.

---

## 6. Upstream sync

See [`docs/fork/upstream-sync.md`](docs/fork/upstream-sync.md). Short version:

```bash
git fetch upstream
git switch personal
git merge upstream/main            # merge, never rebase (no force pushes)
# resolve: identity lines always keep OURS
bash scripts/peng-reapply-rename.sh --check
npm ci && npm run build && npm test
```

---

## 7. Known, intentional deviations from upstream statements

These are stale-by-design in the fork. Do not "fix" them by rewriting upstream docs.

- `docs/development/release-compliance.md` still says the plugin id is `live-image-editor` and the
  name is `Live Image Editor`. It is upstream's audit record; our identity differs.
- `mkdocs.yml` still points `site_url` / `repo_url` at `britz.github.io` / `Britz/...`. The fork does
  not deploy a docs site, so the config is only relevant for local previews.
- `docs/development/README.md` links to `github.com/Britz/...` for dev-workflow files. Upstream links,
  left as-is.
- `scripts/dev-install.sh` prints "Building (inside devcontainer)" even when it builds on the host
  (the no-podman branch). Cosmetic only.
- `CLAUDE.md` requires German replies, forbids agent commits, and forbids host builds. **Superseded
  for this fork** — see the override block at the top of `AGENTS.md`.
