# The solid loop, 2026-10-07: fixing every gameplay hole before the Guest-AI and visual rework

Branch `claude/overnight-foundation` (continued), from `5db62d3` (build `2026-10-06.109`). The plan: `C:\Users\Owner\.claude\plans\lets-fix-all-of-imperative-quilt.md` (its Context section records the owner's decisions of 2026-10-06: Drift 100 is the Reckoning, the breaker's labels live at the power door, the Companion goes, the lobby starts on a majority, light stays the stare's cost, solo Lantern rooms are safe except in the Reckoning, three downs and you're Lost, the dining table moves to the room's heart). Kept current as the work goes on.

## What was done

### WP0. The hold chain, and the finish line in numbers (build `2026-10-06.110`)
- `StalkRules.huntHold`: holds shrink within one hunt (`Config.Stare.HoldDecay` 0.5, `HoldMin` 0.5: 4, 2, 1, 0.5 s), and a hold let go early counts for the share of it used, so two torches can no longer blink him all the way to the front door (the exploit found after the overnight pass: hold 4 s, look away 1.5 s, repeat, gaining ~18 studs a cycle). `StalkRules.holdCap` for the overlay; F2 `watch` shows "hold 1.0/4.0 (0.0 used)".
- `RunStats` keeps the owner's finish line: first door, dinner, out, torch deaths, hints shown, the longest stretch without progress, scares in the first ten minutes, the first hunt, F2 commands that changed the run (read-only commands don't count). One more line in F2 `summary`, the Dossier and `RunSummary`; a fourth overlay line. Feeders: `FinaleService:Serve`, `RunOrchestrator:_onExtracted`, the battery-dead branch, the assist hint, `DebugService:Run`.
- Studio (seed 61, solo, `tier 4` with the beam on him): "+6s hold 1.0/4.0", "+9s hold 0.0/2.0 spent (1.0 used)" then he came on. `summary` printed "Finish line: first door never · dinner never · out never · torch dead 0 · hints 1 · longest without progress 2:59 · scares in the first 10 min 1 · first hunt 2:32 · F2 used 7".
- Specs: Stalk.spec (holds shrink; a half hold counts half), RunStats.spec (the finish line).

## Evidence

## UNREQUESTED changes

## PROPOSALS not done

## Not verified, and what to watch for in play

## Open questions for the owner

## Git

```powershell
# in A:\111- Projects\Github\Projects
git fetch
git checkout claude/overnight-foundation
```
