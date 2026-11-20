# Agent Working Rules

## Fork overrides (Peng fork) — read before anything else

This repository is a personal fork; [`FORK.md`](FORK.md) is the authoritative description of it.
The following **override** conflicting instructions elsewhere in this repo (`CLAUDE.md` in particular):

1. **Language** — converse in Chinese (or English), not German. `CLAUDE.md`'s German rule targets
   upstream's maintainer and does not apply here.
2. **Host builds are allowed.** `npm ci` / `npm run build` / `npm test` / `npm run lint*` run natively
   on macOS with Node 22. No Dev Container, no Docker, no Podman. Do not install a container runtime.
3. **Committing is allowed**, with the user's explicit approval for that specific commit. Never push to
   `upstream`, never open a PR against the upstream repository, never force-push.
4. **Identity vs. behaviour.** Renaming the plugin identity (`manifest.json` `id`/`name`/`author`,
   `package.json` `name`) is *configuration*, not a behavioural change, and does not require the
   `implementation-plan.md` ritual. Any actual behaviour change still follows the top-down gate below.
5. **Branch discipline** — never commit to `main` (it mirrors `upstream/main`). Work lands on
   `personal`.

Everything below this block still applies unless it contradicts the five points above.

## Communication

- Always be brief, factual, and direct. Avoid essays, repeated explanations, and narrative status
  reports. If a normal response exceeds roughly 10–15 lines, reassess and shorten it unless the
  user explicitly requested detail or the extra length is required for safety.

## Token and cost discipline

- Treat model tokens as a limited, user-funded resource. Prefer the lowest-token workflow that
  can reliably complete the requested task.
- A long-running command is not inherently token-expensive. Keep it cheap by redirecting its full
  stdout and stderr to a uniquely named file under `/tmp`, waiting with the longest practical poll
  interval, and reading only the final exit status plus relevant result or error lines.
- Never ingest a complete verbose test, build, CDP, or differential log when targeted `rg`, `tail`,
  `sed`, `jq`, or equivalent extraction can answer the question. Preserve the `/tmp` log path for
  later inspection.
- Do not narrate unchanged polling cycles or produce summaries while a process is still running.
  Communicate once when starting, then only when there is a meaningful result, blocker, or required
  decision.
- Do not rerun a test or diagnostic unless a concrete intervening change or new hypothesis makes the
  rerun informative.
- Read complete files only when their full contents are genuinely required. Otherwise locate the
  relevant symbols with `rg` and read the smallest useful range.
- Inspect only relevant diff hunks and paths. Avoid broad repository diffs when a path-limited or
  context-limited diff is sufficient.
- Before any potentially token-intensive activity—broad audits, large matrices, repeated live runs,
  extensive log analysis, or long/expensive agent work—state its scope and obtain the user's explicit
  approval. This approval threshold is identical for agent and non-agent workflows.

## Subagents

- Cheap, tightly bounded subagents are permanently approved and preferred over doing suitable routine
  work in the primary model. Ask first only before a long-running, broad, or otherwise expensive agent.
- Use the smallest and least expensive available model that can handle the bounded subtask. The
  default is `codex-auto-review` with `low` reasoning, not the primary agent's frontier model.
- Give subagents no conversation history (`fork_turns: "none"`) or only the smallest necessary
  recent context. Put the exact files, evidence, constraints, and expected output in the task prompt.
- Keep every subagent task concrete, bounded, and single-purpose. Do not start duplicate agents for
  the same question.
- If the inexpensive model is insufficient, stop and ask the user before escalating the model,
  reasoning effort, context size, or number of agents.

## Scope and preservation

- Stay within the explicitly authorized bug or feature. Do not broaden implementation, testing, or
  refactoring scope without approval.
- Preserve completed work and user changes. Do not revert useful work merely because its cost has
  already been incurred.
- Prefer one focused implementation and one focused verification. Ask before launching a broader
  regression or differential campaign.
