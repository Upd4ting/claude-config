---
name: orchestrate
description: >-
  Break a request into deliverable units, dispatch each one to a fresh agent (Claude by
  default, Codex on request) running in its own isolated Orca worktree, and report progress
  back as PRs land. Use when the user asks to "orchestrate", "dispatch this", "split this
  across agents", "lance des agents sur...", or describes work spanning several repos or
  several independent deliverables. Do NOT use for work that one agent can finish in a
  single repo — do that directly instead.
---

# Orchestrate

You are the coordinator. You do not write the feature code yourself — you decompose,
dispatch, supervise, and report. Workers run in isolated Orca worktrees and each returns a PR.

Two rules carry most of this skill's value, and both are the ones most often skipped:

- **One PR = one worktree = one fresh agent** (§3.1). Never reuse a workspace that has
  already produced a PR, however convenient it looks.
- **Proactive report-back** (§5). The user should never have to ask "is it done yet?".

## Mechanics live elsewhere

This skill is policy, not plumbing. For the actual commands, load:

- `orca-cli` — worktree creation, spawning agents, reading/waiting on terminals.
- `orchestration` — task dispatch, DAGs, `worker_done`/escalation waits, coordinator loops.

Both resolve their reference from the `orca` binary itself. Never hardcode Orca command
syntax here; read the version-matched guide at run time.

## When NOT to orchestrate

Stop and do the work directly if the request touches one repo and one agent could finish it.
Say so in one line and proceed — don't spin up a worktree to change a config value.

## 1. Decompose

Split by **deliverable unit**, not by repo. A unit is a coherent, independently reviewable
change — one unit produces exactly one PR. It may span several repos when they form one
logical whole (e.g. an interface change plus its implementations).

For each unit, determine:

- **Scope** — what to change, and explicitly what is out of scope.
- **Repos** — every repo the unit touches.
- **Dependencies** — which units must land first. Units that touch the same repo cannot run
  in parallel; sequence them or merge them into one unit.
- **Acceptance criteria** — observable conditions that make the unit done.

## 2. Gate: get the plan approved

**Always present the plan and wait for approval before launching anything.** No exceptions.

Present it as a table: unit, repos, scope (one line), depends-on. Then state the wave order
(what runs in parallel, what waits), the worker agent and model/effort you will use (§3.2),
and ask for a go.

If the user changes the plan, re-present the revised table before launching.

## 3. Dispatch

### 3.1 One PR = one worktree = one fresh agent

**Every unit gets a brand-new worktree with a newly spawned agent. Always. No exceptions.**

A worktree is consumed by the unit it was created for. Once it has produced a PR — or once
its agent has been given a brief — it is off-limits for any other unit, in this run or any
later one. Reusing it poisons the next unit with a dirty tree, a stale branch, the previous
unit's conversation, and a PR that mixes two deliverables.

This is the failure this rule exists to prevent: on the second, third or tenth iteration of
a conversation, the coordinator remembers a worktree it created earlier, notices the repo
matches, and drops a new brief into the agent still sitting there. Don't. When a new unit
arrives, you create a new worktree, even if:

- the repo is the same as a previous unit's,
- a worktree you created earlier is idle and looks free,
- the new unit is a follow-up, a "small tweak", or "the same thing but for X",
- the previous worker is still alive and would answer instantly.

Before every launch, restate to yourself: *this unit has no worktree yet.* Check
`orca worktree list --json` for a name collision and suffix the slug (`-2`, or better, a
slug that names what is actually different) rather than landing on an existing worktree.

**The only work that stays in an existing worktree** is work on *that same PR*: answering
the user's reply to a blocker its worker raised, or addressing review feedback on the PR that
worktree opened. Same PR → same worktree. New PR → new worktree, always.

Never resolve a name collision by reusing. Never hand a new unit's brief to a running worker —
not via `orca terminal send`, not via `orchestration send`, not via `worker-start --terminal`.

### 3.2 Choose the worker agent, model and effort

The user picks; you never silently substitute.

- **Agent** — `claude` unless the user asks for `codex` (or another installed TUI agent).
  Claude is the default when nothing is said.
- **Model and effort** — **only pass them if the user specified them.** When the user says
  nothing, pass no model or effort flag at all, so the worker inherits whatever default is
  configured in Claude Code / Codex on this machine. Never invent a model name or an effort
  level to "be safe".

The user may state this per run ("lance des agents codex") or per unit ("celui-là en opus
xhigh"). A per-unit choice wins over the per-run one. If a request is ambiguous about which
units it covers, ask — it is one short question and it changes every launch.

Record the choice in the plan table (§2) so the user can correct it before the go.

### 3.3 Base every worktree on an up-to-date default branch

Before creating the worktrees for a wave, refresh the default branch in every repo the wave
touches. Don't assume it is called `main` — resolve it per repo (e.g.
`git symbolic-ref refs/remotes/origin/HEAD`), then:

    git -C <repo> fetch origin
    git -C <repo> checkout <default-branch>
    git -C <repo> pull --ff-only

Create each worktree from that refreshed branch, never from whatever branch happens to be
checked out. Re-run this before launching each subsequent wave — earlier units have landed
since, and a worker branching off a stale base produces conflicts or re-fixes work that is
already merged.

If `pull --ff-only` fails, the local default branch has diverged: stop and report it rather
than forcing it — dispatching on top of a diverged base is worse than a delayed wave.

### 3.4 Launch

Workers are launched as **supervised Orca workers** so they push their completion to you
instead of you polling their terminals. Bind one Run per orchestration, then one
`worker-start` per unit:

    orca orchestration run-create --objective "<overall objective>" --json
    orca orchestration worker-start --spec "<brief>" --task-title "<unit-slug>" \
      --worktree new-top-level --repo <selector> --name <type>/<unit-slug> \
      --base-branch <default-branch> --agent <claude|codex> [--model <id> [--effort <level>]] \
      --setup run --json

`worker-start` creates the worktree, spawns the agent, waits for its TUI to be ready and
injects the brief behind a preamble carrying the unit's Task and Dispatch IDs. That preamble
teaches the worker to send `worker_done` to your Run mailbox when it finishes and to use
`orchestration ask` for blocking questions — that is what lets you wake on events (§4).

**The worktree name *is* the branch name.** Always pass `--name` as `<type>/<unit-slug>`
using a conventional commit type — `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`, `test/`,
`perf/` — chosen from what the unit actually does, e.g. `feat/expose-layer-aliases`. A name
with no `/` gets prefixed with the user's git handle instead (`<handle>/expose-layer-aliases`),
which is not what we want. The slug stays short, lowercase and hyphenated. Check the branch in
the receipt after the first launch.

**Model and effort** — add `--model` (and `--effort`, which requires `--model`) only when the
user asked for them (§3.2). Compare `launch.requested` with `launch.effective` in the receipt
and report the effective values, never the requested ones.

Confirm the exact flags against `orca orchestration worker-start --help` before the first
launch; the CLI is authoritative and this snippet is only the shape.

Notes that matter:

- `worker-start` exits 0 only when the worker is `ready`. On a non-zero exit, **do not
  relaunch**: read `failedStage` and `residualResources` from the JSON, report the unit as
  not started, and follow `orca skills get orchestration --reference
  references/recovery-and-cleanup.md`.
- Write the brief in full — the agent gets no other context, and it cannot see this
  conversation.
- Keep the returned Run id, Task id, Dispatch id and worktree id. Every later read, message
  and cleanup is addressed by Dispatch id (`worker-show`, `worker-read`, `send --to
  dispatch:<id>`).
- Respect the dependency order: launch a wave, wait for it to land, then launch the next.
  Never launch two units that touch the same repo concurrently.

### 3.5 The brief

Give every worker a brief containing all of:

- **Objective** — what to build, in terms of outcome.
- **Scope and out-of-scope** — the explicit boundaries from the plan.
- **Acceptance criteria** — the conditions from the plan.
- **Validation before PR** — the repo's build, lint, and test commands must pass. Discover
  them from the repo (package.json scripts, Makefile, CI config); don't assume.
- **Branch name** — already created by the worktree as `<type>/<slug>`; tell the worker to
  commit on it and not to rename or re-branch.
- **PR** — conventional title (`<type>(<scope>): <summary>`, matching the branch type).
  **The body must follow the repo's own pull request template if one exists.** Tell the
  worker to look for it before writing the body — `.github/PULL_REQUEST_TEMPLATE.md`,
  `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, or the same
  names at the repo root or under `docs/` — and, if found, to fill every section of it
  (keeping its headings, checklists and comment markers intact, deleting nothing, marking a
  genuinely inapplicable section `N/A`) and open the PR with
  `gh pr create --title "<title>" --body-file <filled-body.md>`. Only when the repo has no
  template does the worker write a free-form body stating what changed and how it was
  validated. Either way: no agent attribution, no `Co-Authored-By`, no session URLs, no
  generated-with footers.
- **Completion signal** — when the PR is open, send `worker_done` exactly once with the
  command from the injected preamble, `--outcome succeeded`, the PR URL in the body, then
  stop. If the unit cannot be delivered, send `worker_done --outcome failed` with the blocker
  in the body. Never signal completion only in prose on screen — the coordinator is not
  watching the screen.
- **Escalation rule** — if blocked or facing an ambiguity the coordinator or user must
  resolve, use the preamble's `orchestration ask` command (it blocks until answered) rather
  than guessing, widening scope, or opening a local question prompt nobody will see.
- **Language rule** — all artifacts (code, comments, commits, branches, PR titles and
  bodies, docs) in English.

## 4. Supervise — never go idle while a worker runs

The failure mode this section exists to prevent: dispatching a wave, telling the user
"I'll report back", and then ending the turn. Nothing wakes you up, the worker finishes
into the void, and the user discovers it themselves minutes or hours later.

**Rule: you may not end a turn while a worker is running unless a blocking wait is armed
in the background.** "I'll keep an eye on it" is not a wait.

### Arm the wait in the same message as the dispatch

Workers push their events into the Run mailbox; you block on that mailbox. Right after
launching a wave, start **one** background wait for the whole Run (`run_in_background: true`).
Background Bash keeps running across turns and re-invokes you the moment it exits — the
instant any worker sends `worker_done`, an `escalation` or a `question`:

    orca orchestration check --wait --types "worker_done,escalation,question" \
      --timeout-ms 1800000 --json

Do not poll terminals with `orca terminal wait --for tui-idle` or `terminal read` loops: an
idle TUI is not a finished unit, and polling adds latency the mailbox does not have.

Give the wait a timeout longer than the unit plausibly needs, and treat a timeout as a
checkpoint to report, not as a result.

### On every wake-up, in the same turn

1. Read the returned Delivery. It is the whole FIFO batch — process **every** message in it,
   not just the one that woke you.
2. Classify each: **done** (`worker_done --outcome succeeded` with a PR URL), **failed**
   (`--outcome failed`), **question** or **escalation**. Validate that each `worker_done`
   comes from the Dispatch you expect for that unit; if in doubt,
   `orca orchestration worker-show --dispatch <id> --json`. To verify a PR claim, check it
   with `gh pr view` rather than trusting the summary.
3. For a settled worker, decide its terminal's fate before acknowledging:
   `orca orchestration worker-release --dispatch <id> --json` by default, or `worker-retain`
   if the user wants to keep the session. Never reuse it for another unit (§3.1).
4. Update the status table.
5. **Say something to the user.** Every wake-up produces a message: what finished, the PR
   URL, what is still running, what you need from them. Silent wake-ups defeat the point.
6. Re-arm in the background, acknowledging the batch you just processed:

       orca orchestration check --ack <delivery_id> --wait \
         --types "worker_done,escalation,question" --timeout-ms 1800000 --json

   Keep re-arming until every Dispatch of the wave has settled. If the finished unit unblocks
   the next wave, launch it — in **new** worktrees (§3.1) — before re-arming.

On a timeout, or after three consecutive empty waits, check the fleet instead of waiting
blindly: `orca orchestration worker-list --run <run_id> --json`, and act on each row's
`projection.attention` and `projection.nextAction`. Absence of news is not death — only
positive proof of exit (`exited` liveness) justifies treating a worker as gone; then load the
`recovery-and-cleanup` reference.

A wake-up that reports "still running, re-armed" is a valid outcome and costs the user
nothing. Going quiet is the only unacceptable one.

### Escalation

**Escalate immediately** when a worker blocks, asks a question, or fails. Report the blocker
with enough context for the user to decide, and wait for their answer. Do not retry silently,
do not reassign to another worker, and do not solve it yourself unless told to.

Answer a worker's `question` with `orca orchestration reply --id <message_id> --body
"<answer>" --json` — only with the user's answer or a fact from the plan, never a guess.
Relay other guidance on that same unit with `orca orchestration send --to dispatch:<id>`.
Never nudge a worker, and never hand it a different unit.

### Status table

Keep it live in the conversation and update it on every event:

| Unit | Repos | Agent | Worktree | Dispatch | Status | PR |
|------|-------|-------|----------|----------|--------|-----|

`Agent` records what was launched (`claude`, `codex opus xhigh`, …). `Worktree` records the
branch-name worktree, which makes an accidental reuse visible at a glance — the same worktree
must never appear on two rows.

Statuses: `queued`, `running`, `blocked`, `pr-open`, `merged`, `failed`.

Never invent a worker's result. If a worker hasn't sent `worker_done`, its status is
`running` — and the Run wait must be armed.

Before ending the orchestration, `orca orchestration worker-list --run <run_id>
--terminal-state reclaimable --json` must return nothing: every settled worker has been
released or explicitly retained.

## 5. Report

When a wave finishes, report per unit: what landed, the PR URL, what was validated, and
anything deliberately left out. If a unit was dropped or descoped, say so explicitly.

Remaining work is the user's call — surface it, don't silently queue it.
