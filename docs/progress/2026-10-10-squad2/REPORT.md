# The second squad playtest: the fixes (2026-10-10)

Branch `claude/overnight-foundation`, builds `2026-10-10.148` and `.149`, from `2026-10-09.147` (published that day).

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

**Not checked by Claude:** anything with two clients (TC-204, TC-211, TC-215), the hold-click on tools (TC-207), and whether the Guest now feels rarer and deadlier (TC-212 to TC-214: the fast bot never leaves the five-minute intro).

## For later

- **The Guest's animations** (the owner's choice: after these fixes). Smoother motion, ducking under door frames, gripping a frame as he peeks round it.
- Run 1's "we all died": worth a look once the squad plays `.149`. The deadlier crowding could push it either way.
