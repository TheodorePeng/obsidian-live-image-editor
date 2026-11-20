# Baseline — measured at fork initialization

Recorded at fork initialization, and re-confirmed after the identity decision was settled (the fork
keeps upstream's plugin identity — see `FORK.md` §1). Any later failure can therefore be classified as
an environment problem or a pre-existing upstream problem. Do not edit these numbers;
append a new dated section when the toolchain or the baseline legitimately changes.

## Environment

| Item | Value |
|---|---|
| Date | 2026-11-20 |
| macOS | 27.2.1 (build 26B131), arm64 |
| Node | v22.22.2 |
| npm | 10.9.7 |
| Container runtime | none installed (Docker/Podman absent) — builds run natively by design |
| Obsidian | 1.13.7 (upstream `minAppVersion` is 1.12.7) |
| Upstream commit at fork time | `515ccc7` — `chore(release): v0.6.17` |
| Version | 0.6.17 (unchanged by the fork init) |

## Dependency install — one deviation, explained

`npm ci` **fails in this sandbox**: it wipes `node_modules` in bulk, and the environment's safe-delete
guard rejects deletes above 50 files
(`[safe-delete][SAFE_DELETE_BULK_CONFIRM_REQUIRED] {"count":77,"threshold":50,...}` at
`npm/lib/commands/ci.js:94`). This is an environment guard, not a project defect.

`npm install` was used instead: it reconciles in place and completed with exit 0. Dependency versions
come from the lockfile either way.

**Pre-existing upstream drift found:** `package-lock.json` declared `version: 0.6.4` while
`package.json` declared `0.6.17`. `npm install` corrected the lock to `0.6.17`. Upstream will hit the
same correction the next time it installs. The fork keeps the correction.

## Gate results

Identical across every run to date.

| Command | Result |
|---|---|
| `npm run build` (`tsc -noEmit` + esbuild production) | PASS, exit 0 |
| `npm test` (`vitest run`) | **21 files / 403 tests passed**, ~2.8 s |
| `npm run lint` (`eslint src/`) | 0 problems |
| `npm run lint:obsidian` | 0 errors, **18 warnings** |
| `npm run lint:css` | 0 errors, **18 warnings** |

### `lint:obsidian` warning breakdown (18)

`obsidianmd/prefer-active-doc` ×7 · `@typescript-eslint/no-deprecated` ×6 ·
`obsidianmd/prefer-instanceof` ×4 · `import/no-nodejs-modules` ×1

Upstream `CLAUDE.md` says to expect "~11 documented warnings"; the actual count is 18. Treat **18** as
the number to hold, not 11.

## Build artifacts

- `npm run build` writes `main.js`, `lie-runtime.js` (both gitignored) and refreshes the **committed**
  `dist/lie-runtime.js`.
- `dist/lie-runtime.js` was **not modified** by a rebuild on the clean tree — the committed artifact is
  reproducible. Keep it that way: if a build dirties `dist/`, that is a finding worth reporting, not
  something to commit silently.
- The production bundle contains the upstream id `live-image-editor`, matching `manifest.json`. If a
  build ever emits a different id, identity has drifted — see `FORK.md` §1.

## Test layers

| Layer | Location | Runner | Needs a live Obsidian? |
|---|---|---|---|
| Unit / logic | `tests/unit/` (21 files, 403 tests) | `npm test` (vitest) | No |
| CDP / DOM geometry | `tests/cdp/verify-*.mjs` | `node tests/cdp/verify-all.mjs` | **Yes** — Obsidian + CDP relay on port 9223 |

The CDP layer was **not** run during initialization: it needs Obsidian started with a debugging port,
and the user's running instance must not be restarted. Treat it as unverified.

> When running CDP scripts against the fork's test vault, set `CDP_TARGET=vault-peng`. The scripts
> default to `vault-image-toolbar` (upstream's vault name) because that default was deliberately left
> untouched to minimise merge conflicts.

## Test vault

`vault-peng/` — a copy of upstream's `vault-image-toolbar/` with the plugin folder excluded, wholly
gitignored. Plugin installed at `vault-peng/.obsidian/plugins/live-image-editor/`
(`main.js`, `manifest.json`, `styles.css`), `manifest.json` id verified as `live-image-editor`.

This vault holds **only** the fork's build. Since the fork shares upstream's plugin id, never point
this vault at an upstream install as well — see `FORK.md` §1 for why they are mutually exclusive.

**GUI verification status: pending user confirmation.** The plugin has been installed and its manifest
verified on disk, but it has not been observed loading inside Obsidian, and no crop has been performed.
