# Overnight run, 2026-10-06: the foundation

Branch `claude/overnight-foundation`, from `b8e7891` (build `2026-10-05.49`). Builds `2026-10-06.101` to `.109`. Kept current as the night went on; the newest entries are at the bottom of each section.

## Baseline (before any change)

- Checks at the start: `lune run tests/run` 414 passed, 0 failed. C: had 6.2 GB free, A: 579 GB.
- Studio open on `Consensus.rbxlx` in Edit mode with build `2026-10-05.49`; the Rojo mirror from the previous session (`tools/serve-mirror.sh`, started 23:27) was still serving `.rojo-mirror` on port 34872, so this session used it rather than start a second one. Live sync confirmed (a new module appeared in Studio within seconds).
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

### B2. Fear follows progress; hunts off the clock (commit `3c5bffd`, build `2026-10-06.103`)
Audit Finding 2. `Logic/Dread` (pure): **Dread** = the greater of Drift (the failure clock) and the act's floor (`Config.Pacing.ActDread = { 0, 40, 60, 75 }`, eased in over `DreadRamp` 90 s). Drift still ends the run at 100; Dread never does. Hard adds `DreadFloor = 20` (uneasy from the start, tier 1 from minute 1.5) and `TelegraphScale = 0.7`.
- Everything that escalates now reads Dread: his tier (`DirectorModel.tierFor`; `ActHeat` is gone), his face (`StalkerService:_form`), the window face's cutoff, the scare deck's gaps and card thresholds, each player's atmosphere rules, the flicker, grade, photos and blood, the drones and the muffle, the HUD's word (`RS.Dread`, `RS.DreadState`; `DriftService:Dread()`, `SetAct`).
- Hunts: `ArmDelay` widened to 45–150 s; the gap after a hunt is drawn afresh each time (`MinHuntGap` 180 ± 40%); **false alarms** (`FalseAlarmChance` 0.3): a woken hunt that is only its telegraph (the hum rises and fades; nothing comes) with the real one 30–80 s later; **returns** (`ReturnChance` 0.25): after a survived hunt he sometimes comes straight back 40–75 s later, gap or no gap. F2 `arm <s> false` wakes a false alarm; F2 `act` shows dread.
- `Pacing.spec` rewritten on Dread: the steady three-region run now meets tier 2 at minute 5.5 and **tier 3 at minute 17.5 of 23** with Dread 60 at the dinner, while its Drift peaks at 10; a stalled squad still collapses at minute 35 with 6 hunts; no hunt before minute 3.
- Studio (seed 61 solo): after `unlock all` (act 3) Dread rose 40 → 50 → 60 over 90 s, the HUD word went Fraying → Breaking, he reached tier 3 (Intruding) with his cracked face (form 2) at 3:17 with Drift 8; the act-3 woken hunt came as a false alarm (Telemetry `FalseAlarm`), the real one after. Console clean.

### C4. The words of the escape (commit `4cf36e2`, build `2026-10-06.104`)
Audit Finding 4. Lobby tagline "A table laid for something already inside. Set its places, then run."; Hard "uneasy from the start, more locked wings, quicker hunts"; HUD phases LOCKED IN / THE HOUSE / THE DINNER / GET OUT; game over "Nobody got out."; counters say "watch ... in the light" instead of "Witness"; the first-launch how-to is three bullets. Seen in Studio (the first-launch screen).

### C1. The house's own scares (commit `053c920`, build `2026-10-06.105`)
Audit Findings 2, 7 and 8. `Services/HouseEventService`, cards in `Stalker/Director` with `house = true`, drawn by act and Dread (`ScareDeck` gained `minAct` and `once`; a card with nothing to play on is unplayed, no cooldown):

| Card | What | From |
| --- | --- | --- |
| doorAjar | a shut door in the next room swings ajar while nobody looks | act 1 |
| radioOn | a radio in an empty room near you turns itself on for 20 s | Dread 10 |
| overhead | his real footsteps through the floor when he is above or below you, from where he really is | act 2 |
| knockInside | three knocks from inside a wardrobe or locker nearby, with nobody in it | act 2 |
| lightsDie | the rooms ahead of you go dark one by one (corridors first), for 40 s | act 2 |
| phoneRings | the telephone rings 14 s; "Answer" (E) and something breathes on the line, and he hears you pick up | act 2 |
| clockStrikes | the grandfather clock strikes thirteen | act 3, once |
| returnChanged (not a card) | stepping back into a wing nobody has been in for 150 s: a door inside it has moved and a room has gone dark for 60 s | act 1 |

- Every noise is a lure he hears too; every change happens where nobody is looking (`Perception:AnyoneLookingAt`, 80°).
- A house the dressing left without a telephone gets one on a free top in the hall, a corridor or any living room (`Dressing.telephone` made public), so the phone can ring anywhere. (Seed 61 for one player had none.)
- Sounds: PSE "Phone Ring Electronic Consumer Phone 1" (9117305259) and APM "Tubular Bell Sounds (b)" (1842312951) in `Assets.luau`, chosen from descriptions, not heard: swap by ear.
- F2 `event <id>` plays one where you stand. New client scare kinds: `overhead`, `phone`, `caption`.
- Studio (seed 61 solo): radioOn, knockInside, lightsDie, clockStrikes played; overhead played from the hall with him on the gallery above; doorAjar played from the hallway. phoneRings: no telephone in that house (the fallback was written after; not yet seen placing one). Console clean.

### C2. Stuck-assist (commit `ee0c32a`, build `2026-10-06.106`)
Audit Finding 7 and the finish line ("never wonder what to do next for more than two minutes"). `Logic/Assist` (pure, `Assist.spec` walks a real house to the dinner by hints alone), `Config.Assist`, `FinaleService:_assist`, `MapService` `hint`, the map's ring:
- After `HintAfter` 150 s without progress the objective line gains one sentence from the plan's next step: an heirloom in hand ("Carry mom's locket to its place at the table."), a door you already hold the opener for ("You already hold what opens a door in the Hall."), a station in reach ("Try the computer in the Study."), a room in reach where something needed is kept ("Something you need is still in the Study."). Never a token only an optional lock wants.
- After `LampAfter` 240 s the hint room's lights stutter every 30 s and the map rings it. Progress lifts both.
- Studio (seed 61 solo, standing still): at 2:30 the line read "The table is laid for a guest, with two empty places. Try the computer in the Study." (Telemetry `Assist` kind puzzle, room 11). The lamp and the map ring not seen (client handlers are the existing flicker scare and the map's ring).

### C3. Teaching in the house (build `2026-10-06.107`)
Audit Finding 5. `UI/Tips`: one short line when the thing it teaches first comes up, once a session, never two within 20 s, none during a hunt bar the hunt's own: your hands (12 s), the map (50 s), a locked door's mark (when the line mentions one), your first key, the first time he shows himself, the first telegraph, your beam holding him, a dying torch. Settings: "Show tips in the house" (default on, saved). The first-launch screen is the three bullets of C4 (the panel grew to 640 tall).
- Studio: the "map" tip appeared at 51 s; the toggle and the three bullets seen on the first-launch screen.

### C5. Music states, ready for three stems (build `2026-10-06.107`)
`Assets.Music = { Calm, Stalking, Hunt }` (empty: silence), `Config.Music`, `AudioController:_updateMusic`: the hunt stem while he hunts, the stalking stem from tier 2 or Dread 40, the calm stem after the first 20 s, crossfaded (2.5 s in, 1.8 s out), a Music group with its own slider in Settings (saved). Free APM candidates found on the Creator Store, not heard, listed in `Assets.luau`: "Tension Repeat Drones 23/29/39", "Cinematic Tension 16 I/J", "Deliberate Pain (Alt Key Bass)". The owner chooses by ear.

### C6. A quieter catch, as an option (build `2026-10-06.107`)
`Config.Guest.Catch = "rush"` (the default stays as built) or `"quiet"`: black and a breath in your ear, then his face resolving slowly out of the dark over a second, farther off and lit dimly from below, then the sting and a hard cut to black. F2 `guest scare quiet|rush` previews either. See PROPOSALS.

## Evidence

- Checks before every commit: `stylua`, `selene` (0 errors, 0 warnings), `lune run tests/compile`, `lune run tests/run` (414 → 428 tests), `rojo build`.
- Studio play sessions on seed 61 (solo, one client) for A, B1, B2, C1, C2, C3; every console clean of errors.
- Readouts: the baseline above; after B2, 3:17 into an `unlock all` run: tier score 2.39, 39% of his time at tier 3, Dread 60 (Drift 8), 5 scares, 1 false alarm.
- **navtest fast** on seed 61 (solo house, build `.106`) after `unlock all`: 26 legs, 0 failed, 0 with no way, 0 falls, 0 phases, 0 stuck moments, 0 side-steps, 0 re-plans, 0 navmesh fallbacks, 135 s. (Before `unlock all`, 7 legs reported "no way": the rooms behind locks, as designed: a lock is a wall to him.)
- **The quiet catch's timeline** (client-side sampling of the jumpscare GUI, F2 `guest scare quiet`): black from 0 s; the face resolving from 0.4 s (transparency 0.99 → 0.10 by 1.6 s); the cut at 1.5 s (face 1.0, black 0); black lifting from 2.6 s, gone at 3.6 s. The screenshots missed the one-second window; the sampling confirms the shape.
- **End of a run** (build `.108`, seed 61): F2 `resolve` served the dinner (Extraction, the final hunt, "The front door is open. Get out."), F2 `end` ended it: the Dossier showed THE HOUSE and THE NIGHT IN NUMBERS ("Hunts: 1 · 1 at 0:22 (final): lost after 0:08"), Output had the `[Consensus:summary]` block and a `RunSummary` event. Console clean. (A dinner served before his knock didn't count as his arrival for the tier clock; fixed in build `.109`: `PlaceAt` and `_forceArrive` now tell the numbers he's in.)
- **The Guest's AI and the recent room features**, checked by reading: the kettle, washing machine, record player, car horn, wind-up toys, the bell board and the baby monitor all emit sourceless `lure` noises (or none), which his `Investigate` move and tactic treat as lures with wariness; the safe room's steel door is an ordinary power lock to his passage model; the bathroom bolt holds him 4 s like a brace. The house events use the same `lure` kind, so nothing new reaches him by any other channel. Nothing found that needed a change.

## UNREQUESTED changes

| What | Why | Confidence | Revert |
| --- | --- | --- | --- |
| A telephone is put in every house that the dressing left without one (`HouseEventService:_ensureTelephone`) | The phone event can't ring without one; seed 61's house for one player had none | High that it is harmless; its placement (a free top in the hall, a corridor or a living room) is not yet seen in Studio | Delete the call in `HouseEventService:Begin` |
| The settings panel is 640 tall (was 560) | The new toggle and slider pushed Done below the panel | High | `Settings.luau`, `Size = UDim2.fromOffset(860, 560)` |
| `RunStats:Tick` counts no tier time before he arrives | The first readout counted 2 minutes of "tier 0" before arrival | High | n/a (a fix) |
| F2 lowercases its words, so `HouseEventService:Play` matches ids case-insensitively | `event doorAjar` arrived as `doorajar` | High | n/a |

## PROPOSALS not done

- **Make the quiet catch the default** (`Config.Guest.Catch = "quiet"`). The audit found the rush cartoonish; the quiet one reads as a face in a cellar. Your call by eye: F2 `guest scare quiet`, then `guest scare rush`.
- **Music stems**: pick three from the candidates in `Assets.Music` (or others), paste the ids, and set `Config.Music.Volume` by ear.
- **House-event sounds** by ear: the phone ring and the clock strike in `Assets.luau`.
- **A new stalk move for presence between hunts** ("hallway stand": standing at the far end of a corridor, backlit, until you look away) was not written; the house events carry presence tonight instead.
- **Dread ramp from the current value** rather than from the previous act's floor, so a squad that opens three doors at once (F2 `unlock all`) doesn't jump to 40 in a second. Real play goes act by act, so it was left.
- **The Guest's silhouette and `generate_mesh`**: not attempted tonight (judged a day's work with screenshots to earn its place; the catch got the quiet option instead).
- **Touch controls for the hands** and **the lobby starting on a majority or a timer**: not touched (platform decisions are yours).

## Not verified, and what to watch for in play

- Anything with **two clients**: the lit two-watcher freeze (TC-114), the hunt hold and the "it comes on" (TC-116), return-to-wing changes with a second player in the wing.
- **By ear**: the phone ring, the clock strikes, the breath on the line, the quiet catch's breath, the music crossfades.
- **By eye**: the lamp stutter at 240 s and the map's ring (C2), the telephone the fallback places, `lightsDie` from a corridor, the quiet catch at the right moment (the screenshots landed before or after the one-second reveal).
- **Tuning to watch** (all in Config): `Stare.HuntHoldSeconds` 4 and `HuntWatchedSpeedScale` 0.45 (does a hunt still feel like a chase when two stare?); `Stare.BeamDrainScale` 3 (does a solo run run out of battery?); `Pacing.ActDread` and `DreadRamp` (is tier 3 too early for a fast squad?); `Pacing.FalseAlarmChance` 0.3 and `ReturnChance` 0.25; `Assist.HintAfter` 150 (too soon for a squad that is merely walking?); `HouseEvents.ReturnAfter` 150.
- F2 to use: `watch`, `summary`, `act`, `arm 5 false`, `event <id>`, `guest scare quiet`, `tier 2` + `guest here 10` + `guest off` for the stare.

## Open questions for the owner

1. The quiet catch as the default, or the rush? (`Config.Guest.Catch`)
2. Which three music stems? (`Assets.Music`)
3. Should the Companion still help push and revive (it does) now that it no longer counts as a watcher, or should solo get a brighter beam instead of a partner at all?
4. Is 150 s the right patience before the line starts helping? Your finish line says two minutes; the hint comes at two and a half.

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
