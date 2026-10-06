# The solid loop, 2026-10-07: fixing every gameplay hole before the Guest-AI and visual rework

Branch `claude/overnight-foundation` (continued), from `5db62d3` (build `2026-10-06.109`). The plan: `C:\Users\Owner\.claude\plans\lets-fix-all-of-imperative-quilt.md` (its Context section records the owner's decisions of 2026-10-06: Drift 100 is the Reckoning, the breaker's labels live at the power door, the Companion goes, the lobby starts on a majority, light stays the stare's cost, solo Lantern rooms are safe except in the Reckoning, three downs and you're Lost, the dining table moves to the room's heart). Kept current as the work goes on.

## What was done

### WP0. The hold chain, and the finish line in numbers (build `2026-10-06.110`)
- `StalkRules.huntHold`: holds shrink within one hunt (`Config.Stare.HoldDecay` 0.5, `HoldMin` 0.5: 4, 2, 1, 0.5 s), and a hold let go early counts for the share of it used, so two torches can no longer blink him all the way to the front door (the exploit found after the overnight pass: hold 4 s, look away 1.5 s, repeat, gaining ~18 studs a cycle). `StalkRules.holdCap` for the overlay; F2 `watch` shows "hold 1.0/4.0 (0.0 used)".
- `RunStats` keeps the owner's finish line: first door, dinner, out, torch deaths, hints shown, the longest stretch without progress, scares in the first ten minutes, the first hunt, F2 commands that changed the run (read-only commands don't count). One more line in F2 `summary`, the Dossier and `RunSummary`; a fourth overlay line. Feeders: `FinaleService:Serve`, `RunOrchestrator:_onExtracted`, the battery-dead branch, the assist hint, `DebugService:Run`.
- Studio (seed 61, solo, `tier 4` with the beam on him): "+6s hold 1.0/4.0", "+9s hold 0.0/2.0 spent (1.0 used)" then he came on. `summary` printed "Finish line: first door never · dinner never · out never · torch dead 0 · hints 1 · longest without progress 2:59 · scares in the first 10 min 1 · first hunt 2:32 · F2 used 7".
- Specs: Stalk.spec (holds shrink; a half hold counts half), RunStats.spec (the finish line).

### WP1. The bot: F2 `botrun` (build `2026-10-06.111`)
- `Logic/BotPlan` (pure, spec over a hand-made plan, a pocket plan and seven real houses with squads of 1, 2 and 4): the next step a player who knows the plan would take, from what the squad has: extract once served, set an heirloom in hand, take a thing lying there, a door whose needs are held (boards and chains as `toolDoor`), a crank from its outer side, a nailed or chained chest with its tool, then what is still needed in reach (keys, codes and tools before heirlooms). Steps that failed are never offered again. `BotPlan.walk` simulates a plan for F2 `botrun plan` and the spec; a pocket (a side room behind the house key) waits for its own door even inside the start region.
- `Services/BotService`: the caller's own character, taken by the server (`SetNetworkOwner(nil)`, re-asserted every second because a down, a revive or a teleport hands it back) and walked by `Stalker/Walker` the way the Companion was; `PA.BotDriven` makes the client stand aside (`ActionController` stops writing the walk speed). Doors the walker opens for a player's body swing away from it like a door opened with E (`Walker` passes `agent.player` to `DoorService:SetOpen`), or they stopped on the bot and held it for a minute. An heirloom it carries is pinned at its head each frame (`HandsService` `serverCarried`: no client owner, `_checkHeld` leaves it alone, `Release` unpins). Steps go through the real server entry points: `LockService:_try`, `_tryPiece`, `CrankService` (the ratchet, then `Latch`), `FurnitureService:Toggle`, `ItemService:_openCase`, `HandsService:Grab`, `ToolService:_take`, `FinaleService:_set`; puzzles are solved as if played (`PuzzleService:DebugSolve`, counted as "solved as if played"), so the bot measures walking, finding and the plan's shape, not puzzle skill. A stand point beside furniture (`_standNear`: a ring of candidates checked for parts in the body's space and for being in the room) replaced walking at the thing itself, which left the bot five studs short at a dresser against a wall. A leg that gets no closer for five seconds within a hand's reach counts as arrived. A down interrupts a step without failing it. `botrun [fast] [flee|hide]`, `botrun plan`, `botrun` again to stop; the report prints each step with its time, then the stuck points, the run's `summary` lines and a `BotRun` Telemetry event.
- F2 `inspect <Service.field.key...>` reads any live server table to Output (`inspect LockService.reach`, `inspect WorldService.World.seams.seam:2-3`): the MCP command bar's `shared` is its own, so this is the only window into the running services from a tool. `botrun` and `inspect` don't count as F2 use in the finish line.
- What the bot found on seed 61 before it could finish (each fixed in the bot, not the game): a door opened by the walker swung into the body and stopped at 28°; the house's reach excludes a crank region until the shutter is up, and the bot's state only knew `LockService`'s seams, so a crank step was never offered; the extraction leg aimed at the room's centre and let `MoveTo` time out.
- What it found about the game (for the later packages): the contact lunge fires when the bot walks into him standing in a corridor (twice a run, tier 1 and 2); a down drops the crowbar and the heirloom, which cost the bot a trip back each time; an armed hunt that the final hunt supersedes is logged as "going on"; "Hunts: 1 at 4:25 (armed): going on after 2:12".
- Studio, seed 61 solo, build `.111`, `botrun` (walking pace, working through hunts): **extracted at 4:59**. 20 steps (terminal, padlock door, the crank from the back stairs, the umbrella key in the mudroom, the pocket door to the music room, the crowbar, the boards, the safe, two heirlooms set, out), 2 failed (the spent key searched for twice, fixed since), 0 with no way, 2 downs (both the contact lunge: the bot walked into him standing in a corridor at tier 1 and 2; each dropped the crowbar and the heirloom), 3 puzzles solved as if played. Finish line: first door 0:36 · dinner 4:49 · out 4:59 · torch dead 0 · hints 0 · longest without progress 0:44 · scares in the first 10 min 8 · first hunt 4:13 · F2 used 0. Hunts: one armed at 4:13 ("going on" when the final hunt took over, 1 caught), the final at 4:53 escaped after 0:06. Console clean. (The bot knows the plan and cheats the puzzles, so its times are the floor a human's reading and puzzle time sits on; the yardstick is the change between builds, not the clock.)

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
