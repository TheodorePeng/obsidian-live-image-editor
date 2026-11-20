# Upstream sync — procedure and conflict conventions

Goal: pull in upstream fixes without losing the fork's rename, and without ever force-pushing.

## Model

`main` is a **pure mirror** of `upstream/main` and never receives a commit. All work lives on
`personal`, which is the repository's default branch. Because `main` never drifts, a merge into
`personal` produces conflicts only where the fork genuinely edited something.

## Routine sync

```bash
git fetch upstream --tags
git switch personal
git merge upstream/main          # merge — never rebase, never force-push
```

Resolve, then always re-assert the fork identity and re-verify:

```bash
bash scripts/peng-reapply-rename.sh --check    # exits 1 if the old id leaked back in
npm ci && npm run build && npm test && npm run lint
```

If `--check` reports residue (upstream re-introduced the old id in a file it rewrote), re-apply:

```bash
bash scripts/peng-reapply-rename.sh
git diff                       # review before committing — never commit blind
```

## Conflict conventions, by file

| File | Convention | Why |
|---|---|---|
| `manifest.json` | Keep **ours** on `id` / `name` / `author` / `authorUrl`; take **theirs** on `version` | Identity is ours; version belongs to upstream |
| `package.json` | Keep ours on `name` and the `dev:vault` path; take theirs on `version` and every dependency | |
| `package-lock.json` | Take **theirs** wholesale, then `npm install` and re-apply the 2 `name` fields | A hand-merged lock is a latent bug |
| `src/{brand-icon,bundled-snippet,editing-toolbar-integration,main}.ts` | One line each; keep ours on the id constant, take theirs everywhere else | |
| `tests/cdp/*.mjs` | Take **theirs**, then run `peng-reapply-rename.sh` | Upstream rewrites these often; hand-merging 20 files is wasted effort |
| `dist/lie-runtime.js` | Take **theirs**, then `npm run build` to regenerate | It is a build artifact; never hand-resolve it |
| `CHANGELOG.md`, `docs/development/{implementation-plan,issues}.md` | Take **theirs**, no fork entries | Upstream rewrites them each release; fork notes live in `docs/fork/` |
| `docs/development/{methodology,requirements,architecture,test-plan}.md` | Take **theirs** | Inviolable upstream; the fork does not edit them |
| `README.md` | Keep ours in the fork banner and install section, take theirs elsewhere | |
| `vault-image-toolbar/**` | Take **theirs** | Kept pristine on purpose |
| `FORK.md`, `docs/fork/**`, `scripts/peng-reapply-rename.sh` | Ours — upstream has no equivalent | Fork-owned files |

## What the rename script does and does not touch

Allowlist only — `manifest.json`, `package.json`, `package-lock.json`, the four `src/` files, three
`scripts/` files, and `tests/cdp/*.mjs`. It rewrites the token `live-image-editor` →
`live-image-editor-peng` and skips anything already renamed, so it is idempotent.

It deliberately **never** touches `styles.css`, `src/transforms.ts`, `src/link-format.ts`,
`vault-image-toolbar/**`, or `docs/development/**` — see `FORK.md` §4 for why.

## When to sync

Sync at upstream **release points**, not per commit. Upstream rewrites its changelog, plan and issue
registry every release, so per-commit syncing means constant conflict resolution for no benefit.

## Never

- Never push to `upstream` (its push URL is `no_push_this_remote_is_read_only`).
- Never force-push `personal`.
- Never open a PR against the upstream repository.
- Never commit to `main`.
