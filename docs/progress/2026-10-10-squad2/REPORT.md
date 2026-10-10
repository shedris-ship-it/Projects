# The second squad playtest: the fixes (2026-10-10)

Branch `claude/overnight-foundation`, builds `2026-10-10.148` to `.151`, from `2026-10-09.147` (published that day).

The owner ran a squad playtest (three players, then two) and sent notes plus a tester's answers to the post-playtest questions. The verdict: "like Resident Evil", but players wandered without knowing what to look for, never needed each other, and found the Guest too present and easy to mess with. Run 1 ended with everyone Lost.

## The owner's decisions (2026-10-10)

| Note | Decision |
| --- | --- |
| "No team puzzles ... no necessary reason to use your team, but if people died mid run it shouldn't be impossible" | **Team puzzles, solo-safe.** Two people make it faster or safer; alone, or once only one is left, it still works, slower or riskier. |
| "He's too prevalent and you can still just kinda go up to him and fuck with him" | **Rarer and deadlier.** Fewer appearances between hunts; getting in his face downs you much sooner. |
| "Make the movement more smooth, work on his animations", ducking under doorways, gripping the frame on a peek | **After the fixes**, a separate pass the owner watches. Not in these builds. |

Fixes that build on the foundation went ahead under the owner's standing OK (2026-10-06).

## Build `.148`: the playtest's bugs

**Clicks fired prompts.** The root cause of three notes, found in Studio. A ProximityPrompt is clickable by default, so any click while one was shown fired it:
- a right click at the hub's contract table changed the difficulty;
- a click on a note's "Put it down" fired the note's own Read prompt, so the note opened again;
- the held click meant for the bolt cutters went to the door's prompt.

Now `HandsController` turns `ClickablePrompt` off on a keyboard (touch still taps prompts), and the hands' click passes while a screen is up (`Ui.modalOpen`). In first person the locked cursor never reaches a note's button, so a note also closes on any click. Checked in Studio: clicks at the contract change nothing and E does; the chain gave way to the bolt cutters held with R, which runs the same code as a held click (the MCP can't hold a click into the game, so the click itself waits on TC-207).

**Left behind at Ready.** The 30-second majority start took whoever was ready when the countdown began. Someone who readied during the 5-second countdown stayed in the hub. Now everyone ready when it ends goes in (`LobbyService`).

**The table.** Holding E with an heirloom never worked, because E while carrying means "put down". A tester also never knew the table wanted heirlooms. Now:
- each empty place's card names the heirloom it wants ("Mom's locket"), on plain card stock, facing whoever stands there to set it (it used to face across the table);
- a faint dark shape of that heirloom lies on its plate (`FinaleService:_ghost`, `Config.Dinner`);
- carrying one up to the table sets it at its own place, with no E (`_autoSet`, every half second);
- once someone has been near the table, the objective line says "The table still wants Mom's locket and Dad's pocket watch." (`Objectives.list`, the facts' `wanting`: only what's been seen);
- a tip the first time you pick one up.

Checked in Studio on seed 1800820264: walking up with Dad's pocket watch set it at its own place, its shadow went, and the line dropped it; the card reads clearly (screenshot).

**The map by floor.** It shows one floor at a time and opens on yours. Up/Down buttons (or the arrow keys, LB/RB) flip between the floors someone has seen. The frame stays the same between floors, so rooms keep their places. A teammate down on another floor is named in the line under MAP. Checked: ground floor, then the upper floor.

**Doors ajar give.** Walk into a door left part open from the side it opens away from, and it swings on to 80° ahead of you with a soft creak (`DoorService:_shoulder`, `Config.Doors.Shoulder`). Checked: a door at 25° went to 80° as the character walked through it.

**Voice chat.** Roblox's voice chat already puts an AudioListener on the camera. The typed-line speech added a second one in the same spot, so once anyone had typed a line, every voice played twice, a hair apart: muffled and inconsistent. Speech now uses Roblox's listener (`SpeechController`). Needs two clients with voice to hear (TC-211).

**Dropping.** "X: drop" shows under a held tool.

## Build `.149`: the Guest rarer and deadlier; twin levers

**Rarer.** After every time he's seen and backs off (a yank, a slow withdraw, a duck, backing away), he enters a lull at every tier. During the lull he only roams far off, minds his errands (the table, tidying) and follows lures. It lasts 40-70 s at tier 1, 30-55 s at tier 2 and 20-40 s at tier 3 (45-75 s in the intro) (`Config.Guest.Lull`, `Stalk:_choose`). Before this, only tier 1 had a gap after a sighting. Also: tier 1's gap is 30-55 s (was 14-30), and his set-up scares come at most every 210 s per player (was 150).

**Deadlier.**
- Crowding counts within 50° of looking at him (was 40°).
- Following him as he backs away fills it as fast as standing in his face (was 0.7×).
- The scare is a warning that holds for 7 minutes (was 3): crowd him again in that time and he grabs you.
- In a hunt he aims 1.1 s ahead of you (was 0.7), so a loop round a table loses him less.

The "walking past never counts" rule and its spec still hold.

**Team locks, solo-safe.** Two-person locks already existed (the crank door, the dumbwaiter, the breaker's labels at the door), but squad houses drew them rarely. Changes:
- **Twin levers**, a new gate kind and puzzle (`Logic/Puzzles/Levers`, `server/Puzzles/Levers`, `Config.Levers`). An iron lever sits beside the door, and its twin is on a wall in another room already open, 35-160 walking studs away (`LockPlanner`, `Where.levers`, `LeverApart`). Both plates wear the door's mark. Hold E on each: both down at once and the door's lamp goes green and it opens. With two or more players left, a lever let go springs back after 1.5 s, too short to run between them. With one player left, it stays down on a ticking catch for the walk at 10 studs/s plus 5 s. The ticking is a lure he hears. It's never in a solo house or the old house.
- Squads of two to four draw twin levers (weight 2) and crank doors (2, was 1) more often. `tools/lockstats` over 60 houses: two players about 0.6 team locks a run, three about 1.3; solo unchanged.
- The objective line, the map ("2 LEVERS", "LEVER"), the stuck-assist, the Dossier and a tip name them. The bot solves them like any puzzle.
- Specs: `Levers.spec` (the timings), `LeverPlans.spec` (never solo; the far lever in another room, a walk away; most squad houses have a team lock).

Checked in Studio on seed 2 for two (F2 `squad 2`): both levers built with clean consoles; screenshots of both; solo, the door's lever caught and stayed lit amber, its twin pulled in time opened the door. `botrun fast` solved the levers and went on (see below).

**The lull, measured (build `.150`).** `botrun fast` on seed 2 for two, three times on the same house: the lull as first built, no lull, then the lull with the fix:

| | first lull | no lull | lull, fixed (`.150`) |
| --- | --- | --- | --- |
| out in | 5:47 | 4:46 | 4:44 |
| waits for him | 45 | 36 | 33 |
| parked | 1:15 | 0:55 | 1:05 |
| sightings | 9 | 6 | 6 |

The first version made things worse. His "far" roam keeps about 45 studs from the nearest player and favours rooms where an unfound heirloom lies, which is where the squad is heading. So in a lull he hovered at the edge of sight. In a lull he now goes to the room furthest from everyone, up to `LullFar` (120 studs), with nothing drawing him back (`Stalk:_farPoint(away)`). The fast bot plays its whole night inside the five-minute intro, so it can't show whether he feels rarer later in a night: that's TC-212. Waits for him vary from 0 to 39 by house in earlier reports; this house is one of the high ones with or without the lull.

**Not checked by Claude:** anything with two clients (TC-204, TC-211, TC-215), the hold-click on tools (TC-207), and whether the Guest now feels rarer and deadlier (TC-212 to TC-214: the fast bot never leaves the five-minute intro).

## Build `.151`: the progression audit

The owner, after the playtest stalled at a chained door: "I just want to make sure all the progression systems work." The bot can't catch input bugs: it opens doors and solves puzzles from the server. So every lock and puzzle was checked twice, once by plan and once by real inputs.

**Every plan can be finished.** `tools/completable` builds houses exactly as a run does (Logic/HouseSize for squads 1-4, Normal and Hard, the full and the short night, every one of HouseSearch's 12 candidates) and walks each plan as the bot does, to the table and out of the front door. Result: **3,840 houses, 0 that can't be finished**, with every lock kind (key, double, padlock, power, crank, boards, chain, levers, pocket, bolt, hidden) and every puzzle (fuse box, computer, safe, music box, dumbwaiter, levers). `Completable.spec` keeps 64 of them in the test suite.

**Every mechanism through a player's own keys** (Studio, one client, on seeds 1800820264, 6, 3 and 11 solo and for four):

| Mechanism | Checked | Result |
| --- | --- | --- |
| Key door | took the key off a rack with E, E on its door | opened |
| Chain (bolt cutters) | cutters in slot 2, torch in hand, hold R on the door | the cutters came into the hands; cut |
| Nailed fridge (crowbar, a wing step) | crowbar in a slot, hold R | pried open; the planks lie on the floor |
| Crank door, alone | Q (ratchet), hold E | raised |
| Twin levers, alone | hold E on one, let go, hold E on its twin | opened |
| Bolt | E from its own side | opened |
| Hidden panel | E from the room side | found and opened |
| Padlock | E on its door | its wheels' screen |
| Fuse box, computer, piano | E | their screens |
| Music box | E | wound; its tune strip played |
| Dumbwaiter | hold E on its crank | the car rose to the upper floor |
| Wall safe | painting aside with E, E on the safe | **broken, fixed**: its screen now opens |
| The table | walked up carrying an heirloom | set (build `.148`) |

**Fixed:**
- **The wall safe couldn't be opened on a keyboard.** Its "Work the dial" prompt is on the safe's door, and E on a door-like piece always did the piece's own open/shut. The door is locked until solved, so E only rattled it. This has been the case since the one-focus change (`.146`). Now a quick prompt on a piece takes the tap (`Logic/FocusActions`, spec). The only other such prompt, the open/shut of furniture you hide in, does the same thing either way.
- **A tool in a slot did nothing at its lock.** The cutters only worked while in your hands, so carrying them in slot 2 and holding the click just rattled the door. That's a likely second cause of the playtest's stall, besides the click bug. Now holding the click or R on the lock takes the tool from whichever slot carries it (`ToolService:Equip`, `LockService:_workBegin`), and the marker says "Hold click" whenever you carry it.
- **A leaver's keys and tools could vanish.** Drops needed the character, which may already be gone when a player leaves. Now they fall where the player last stood (`PlayerStateService:LastPosition`).
- **Locked doors' labels.** Any small swing (a rattle, a door nudged ajar) relabelled a locked door "Open", so a hidden panel's "Search" gave itself away and locked doors stopped saying "Try" (`DoorService:_labelSwing`).

Not checkable here: the held click itself (the MCP's clicks reach the game only as a cancel, so R stood in, which runs the same code), entering a code on the padlock's wheels, and anything with two players.

## For later

- **The Guest's animations** (the owner's choice: after these fixes). Smoother motion, ducking under door frames, gripping a frame as he peeks round it.
- Run 1's "we all died": worth a look once the squad plays `.149`. The deadlier crowding could push it either way.
