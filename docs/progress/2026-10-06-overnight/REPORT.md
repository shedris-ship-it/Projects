# Overnight run, 2026-10-06: the foundation

Branch `claude/overnight-foundation`, from `b8e7891` (build `2026-10-05.49`). Kept current as the night goes on; the newest entries are at the bottom of each section.

## Baseline (before any change)

- Checks at the start: `lune run tests/run` 414 passed, 0 failed. C: had 6.2 GB free, A: 579 GB.
- Studio open on `Consensus.rbxlx` in Edit mode with build `2026-10-05.49`; the Rojo mirror from the previous session (`tools/serve-mirror.sh`, started 23:27) was still serving `.rojo-mirror` on port 34872, so this session uses it rather than start a second one. Live sync confirmed (a new module appeared in Studio within seconds).
- The audit (Claude Doc, tabs "Plan on a page" and "Full audit") was read in full.
- **Baseline run** (seed 61, solo, the player standing still at the spawn for 7:19, build `.49` behaviour with only the new measurement added), read with F2 `summary`:
  - tier score 0.72, time by tier: t0 2:00 (pre-arrival, since fixed to not count), t1 5:18, t2 0, t3 0, hunting 0
  - silent 1.6 min in stretches of a minute or more; longest quiet 1:33
  - 10 scares (distant steps ×3, flicker ×3, knock ×2, cold spot, window face); no hunts (no progress wakes one; Drift 25 by minute 7 because the squad stalled)
  - **19 stare-downs and 20 freezes for 1:09** from a player who never moved: the idle first-person camera plus the Companion counted as two watchers every time he peeked into view. This is the free win the audit described, measured.

## What was done

### A. Measure (commit `6c38a8d`, build `2026-10-06.101`)
- `Logic/RunStats` (pure, `tests/specs/RunStats.spec`): the act, a time-weighted tier score from his arrival (0 Dormant to 4 Hunting) and the share of time at tier 3 or hunting, silent minutes (stretches of `Config.Stats.SilentSeconds` = 60 s with no beat), scares by kind, each hunt with what woke it and how it ended (survived, stared down, escaped, lost), false alarms, stare-downs, freezes and their seconds, sightings, downs, catches, time to first progress and since the last.
- A "beat" (breaks the quiet): a scare card, a house event, a sighting (he becomes visible to someone), a breath or a creak heard, a hunt's telegraph, progress (a lock, a region, a puzzle, a find, a place set), an act change.
- Shown: three lines at the bottom of the F2 overlay (the panel grew to 600×640); F2 `summary` prints the full block to Output mid-run; the Dossier gets THE NIGHT IN NUMBERS; `RunOrchestrator:EndRun` prints `[Consensus:summary]` lines and logs a `RunSummary` Telemetry event. A hunt still on when the run ends is closed as "escaped" or "lost".
- Checked in Studio: F2 `summary` mid-run on seed 61 (above); console clean.

## Evidence

(checks, play tests, before and after readouts)

## UNREQUESTED changes

Each with what, why, confidence and how to revert.

## PROPOSALS not done

## Not verified, and what to watch for in play

## Open questions for the owner

## Git

```powershell
# in A:\111- Projects\Github\Projects
git fetch
git checkout claude/overnight-foundation
# to merge into your branch:
git checkout claude/quirky-gauss-cfc8my
git merge claude/overnight-foundation
# to discard:
git branch -D claude/overnight-foundation
```
