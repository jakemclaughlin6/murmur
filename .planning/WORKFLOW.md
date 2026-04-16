# Workflow — how to start a new session

This project moved off GSD to the **superpowers** skills on 2026-04-16. Invoke skills through the `Skill` tool. Do not use `/gsd-*` slash commands — GSD state was removed.

## Starting Phase 4 (TTS Engine & Playback Foundation)

The existing `04-00-PLAN.md` … `04-09-PLAN.md` files are in GSD's XML `<task type="auto">` format — they are **detailed specs, not superpowers plans**. Convert first.

1. **Verify the stack hasn't drifted.** The Phase 4 plans pin `sherpa_onnx ^1.12.36`, written ~3 weeks ago. Check pub.dev for the current version — Risk #1 in `CLAUDE.md` calls this out. If there's a newer patch, decide whether to bump before consolidating.
2. **Invoke `writing-plans`** via the `Skill` tool. Point it at the 10 existing files as source specs:
   - `.planning/phases/04-tts-engine-playback-foundation/04-CONTEXT.md`
   - `.planning/phases/04-tts-engine-playback-foundation/04-RESEARCH.md`
   - `.planning/phases/04-tts-engine-playback-foundation/04-VALIDATION.md`
   - `.planning/phases/04-tts-engine-playback-foundation/04-00-PLAN.md` … `04-09-PLAN.md`
   - Have it produce one consolidated checkbox plan at `.planning/phases/04-tts-engine-playback-foundation/PLAN.md`.
3. **Execute** with `subagent-driven-development` (preferred — fresh subagent per task, review between) or `executing-plans` (inline, batch with checkpoints).
4. **Before claiming done**, run `verification-before-completion`.
5. **Wrap up** with `finishing-a-development-branch`.

## Starting Phase 5+ (or any new feature)

1. `brainstorming` — produces a spec, saves to `.planning/phases/NN-name/SPEC.md`. Get user approval before anything is built.
2. `writing-plans` — converts the spec into a checkbox `PLAN.md` under the same directory.
3. `subagent-driven-development` or `executing-plans` — execute the plan.
4. `verification-before-completion` — before saying "done".
5. `finishing-a-development-branch` — wrap up, PR or merge.

## Bugs / unexpected behavior

Start with `systematic-debugging`. Don't jump to fixes.

## Quick fixes / trivial edits

Skills are for multi-step work. Typos, one-line tweaks, doc nits: just edit.

## Writing or modifying code that needs tests

Use `test-driven-development`.

## File locations

- `.planning/PROJECT.md` — project constraints and value (still canonical)
- `.planning/ROADMAP.md` — 7-phase plan (still canonical)
- `.planning/REQUIREMENTS.md` — numbered requirements (still canonical)
- `.planning/STATE.md` — **frozen at 2026-04-13**, do not update
- `.planning/research/` — architecture, stack, pitfalls reference
- `.planning/phases/NN-*/` — existing phases' context + plans + summaries
- `.planning/phases/NN-*/SPEC.md` + `PLAN.md` — new specs/plans go here (not under `docs/superpowers/`)

## Red flags

- A session loads more than one plan file at a time → stop, you're back in GSD mode.
- CLAUDE.md's `## Workflow` section says to run `/gsd-*` → someone reverted the edit; re-apply.
- A new skill creates files under `docs/superpowers/` → redirect it to `.planning/phases/NN-*/`.
