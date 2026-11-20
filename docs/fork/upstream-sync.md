# Upstream sync — procedure and conflict conventions

Goal: pull in upstream fixes without losing fork-side work, and without ever force-pushing.

## Model

`main` is a **pure mirror** of `upstream/main` and never receives a commit. All work lives on
`personal`, which is the repository's default branch. Because `main` never drifts, a merge into
`personal` produces conflicts only where the fork genuinely edited something.

Since the fork keeps the plugin identity identical to upstream (see `FORK.md` §1), the number of
fork-edited files is tiny, so merges are normally trivial.

## Routine sync

```bash
git fetch upstream --tags
git switch personal
git merge upstream/main          # merge — never rebase, never force-push
npm ci && npm run build && npm test && npm run lint
```

If `npm ci` is blocked by this machine's bulk-delete guard, use `npm install` instead — see
`baseline.md` for the detail.

## Conflict conventions, by file

| File | Convention |
|---|---|
| `README.md` | Keep **ours** in the top banner; take **theirs** everywhere else |
| `AGENTS.md` | Keep **ours** in the "Fork overrides" block; take **theirs** everywhere else |
| `package.json` | Keep **ours** on the `dev:vault` line; take **theirs** on `version` and every dependency |
| `package-lock.json` | Take **theirs** wholesale, then `npm install` |
| `dist/lie-runtime.js` | Take **theirs**, then `npm run build` to regenerate |
| `CHANGELOG.md`, `docs/development/{implementation-plan,issues}.md` | Take **theirs**, no fork entries |
| `docs/development/{methodology,requirements,architecture,test-plan}.md` | Take **theirs** — inviolable upstream |
| `manifest.json`, `src/**`, `scripts/**`, `tests/**`, `styles.css` | Take **theirs** — the fork does not edit these |
| `FORK.md`, `docs/fork/**` | Ours — upstream has no equivalent |
| `vault-image-toolbar/**` | Take **theirs** — kept pristine on purpose |

## After every sync, verify identity has not drifted

```bash
git diff upstream/main -- manifest.json src/ scripts/ tests/ styles.css   # expect: empty
```

An empty diff there means the fork is still a clean drop-in replacement. If upstream ever renames the
plugin, that command is how you notice.

## When to sync

Sync at upstream **release points**, not per commit. Upstream rewrites its changelog, plan and issue
registry every release, so per-commit syncing means constant conflict resolution for no benefit.

## Never

- Never push to `upstream` (its push URL is `no_push_this_remote_is_read_only`).
- Never force-push `personal`.
- Never open a PR against the upstream repository.
- Never commit to `main`.
