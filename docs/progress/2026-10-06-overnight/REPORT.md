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

### B1. The stare has a cost (commit `66e1a3c`, build `2026-10-06.102`)
Audit Finding 3. `Config.Stare`, `Logic/StalkRules.litFor` and `huntHold`, `Stalker/Perception:Watchers`:
- A look counts only while he is **in that player's light**: the room he stands in is lit, their full beam reaches him (42 studs, within 28° of the camera's centre), their clip light does (16 studs, where the body faces), a lit Lantern in hand (22 studs), or arm's length (4 studs). So the dark, the battery and his KillLights tactic now matter. `LitOnly = false` restores the old rule.
- **In a hunt the stare holds him 4 s at a time** (the hunt's clock pauses with him, as it does for a stun), then he comes on at about a walk (×0.45 of his sprint) while two still watch, until they lose him for 1.5 s. The 3 s co-stare still backs him off between hunts; it never ends a hunt (`CoStareEndsHunt = false`).
- **The Companion no longer counts as a watcher.** Alone (one active player), a full beam held steady on him for 0.6 s counts as the second pair of eyes and drains the battery ×3 while it does (`PA.BeamHold`). Solo keeps its threat and its counter.
- Captions the first two times per player: "[caught in your light, it stops]" / "[watched by two of you, it stops]" and, when the hold is spent in a hunt, "[the light isn't enough any more. It comes on]".
- F2 `watch` prints the stare right now; the overlay has the same line ("watch: lit 1 · dark 0 · beam 1 · room dark · hold 4.1 spent").
- Studio (seed 61, solo, tier 2, him 10 studs in front): a lit room counted (watchers 1); lights off and torch off counted nothing (dark 1); torch on in the dark counted double after 0.6 s (watchers 2, beam 1) with the battery draining faster; `tier 4`: the hold ran 4.1 s and was spent, then he came on. Not checked: two clients; the clip light and the Lantern cases (specs cover the rule).

### B2. Fear follows progress; hunts off the clock (build `2026-10-06.103`)
Audit Finding 2. `Logic/Dread` (pure): **Dread** = the greater of Drift (the failure clock) and the act's floor (`Config.Pacing.ActDread = { 0, 40, 60, 75 }`, eased in over `DreadRamp` 90 s). Drift still ends the run at 100; Dread never does. Hard adds `DreadFloor = 20` (uneasy from the start, tier 1 from minute 1.5) and `TelegraphScale = 0.7`.
- Everything that escalates now reads Dread: his tier (`DirectorModel.tierFor`; `ActHeat` is gone), his face (`StalkerService:_form`), the window face's cutoff, the scare deck's gaps and card thresholds, each player's atmosphere rules, the flicker, grade, photos and blood, the drones and the muffle, the HUD's word (`RS.Dread`, `RS.DreadState`; `DriftService:Dread()`, `SetAct`).
- Hunts: `ArmDelay` widened to 45–150 s; the gap after a hunt is drawn afresh each time (`MinHuntGap` 180 ± 40%); **false alarms** (`FalseAlarmChance` 0.3): a woken hunt that is only its telegraph (the hum rises and fades; nothing comes) with the real one 30–80 s later; **returns** (`ReturnChance` 0.25): after a survived hunt he sometimes comes straight back 40–75 s later, gap or no gap. F2 `arm <s> false` wakes a false alarm; F2 `act` shows dread.
- `Pacing.spec` rewritten on Dread: the steady three-region run now meets tier 2 at minute 5.5 and **tier 3 at minute 17.5 of 23** with Dread 60 at the dinner, while its Drift peaks at 10; a stalled squad still collapses at minute 35 with 6 hunts; no hunt before minute 3.

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
