# Polish before the public release (2026-10-17)

The owner, after publishing build .231 and the playtest fixes (.232): "Theres still some more polish I want to do before publishing", with a public release by the end of the weekend. Each item below is one piece of that polish.

## The piano: the puzzle wasn't broken, but most pianos only pushed

**The owner, 2026-10-13:** "the piano shows only a push prompt, never Play". On 2026-10-17 they thought it might have been fixed since.

**What was found:**
- Nothing fixed it after 10-13, and nothing needed fixing in the puzzle. The music box's piano works in the code:
  - its Play prompt is on from the start (`Puzzles/MusicBox`);
  - the hands offer a pushable thing's own short prompt as the tap and the push as the hold (`Logic/FocusActions`; the spec "the piano: tap plays it, hold pushes it", since 10-08).
- Every Music Room has a piano, and the music box puzzle is rare. Of 40 houses from the planner (seeds 1 to 20, squads of 1 and 4; scratch `tools/_pianos.luau`):
  - 21 had a Music Room without the music box, its piano plain furniture: E offered only Push;
  - 2 had the music box in the Music Room;
  - 17 had no Music Room.
  The 10-13 run was almost certainly one of the 21.

**The fix (the owner: "Yes, make the furniture piano playable as a lure"):**
- A piano that isn't the music box's is a lure (`Data/Interactables` `Piano`). Tap E: a hand runs down six of its keys, in the puzzle piano's own out-of-tune note, and the Guest hears it 36 studs off, twice in a second. Its cooldown is 10 s. Hold E still pushes it.
- The music box's own piano keeps its Play. `Logic/RoomPurpose.puzzleTakes` (spec'd) says a puzzle in the room takes the piano for itself, so `InteractService:Begin(plan)` gives it no lure prompt.
- No plan changes: the Music Room was already a room with a reason (the piano's a landmark). The full suite and `tools/completable` agree.
- F2 `use piano` plays the nearest one.
- The note is the music box's, as the puzzle's piano has always played. A real piano sound can be picked by ear later (`Assets.luau`).

**Checked:** see Checks below. **Not checked in Studio:** Claude's Studio connection was off. TC-355 is the owner's. **Seen in Studio later the same day** (the walk below, seed 2, squad of 4): E on the Music Room's piano says Play; a tap plays its notes; a hold pushes it.

## Checks (the piano)

- stylua and selene: 0 errors, 0 warnings.
- `lune run tests/compile` and `rojo build`.
- `lune run tests/run`: 753 passed, with one new spec in `RoomPurpose.spec`.
- `lune run tools/completable`: 1,152 houses, none that can't be finished; the music box in 181 of them.
- Not seen in Studio (TC-355).

## The walk: the whole game in Studio, looking for what's wrong (build .234)

**The owner:** "go walk around and look and find things that dont look right or dont work right ... Im curious to see how much we could fix before adding the final touches." Claude walked the mall and two runs in Studio (seed 1800820264 solo, and seed 2 for a squad of 4): every shop, the fitting room, the till, renting, the cars and the dashboard, a run started from the car, the rooms, the Guest and a takedown, the cutscenes, the bot playing a whole run out of the front door, the report, and the ride home. Most of it is right. What wasn't, and what was done about it:

### Fixed (under the standing OK for gameplay fixes)

1. **Every run started looking at the floor.** The arrival's last shot looks down into the hall from high over the door, and the camera kept that tilt when it was handed back: you came into every house 36 degrees down at the boards. `CinemaController:End` now hands it back level, facing where the last shot looked (only when a shot moved the camera). Measured: after the arrival, a taste takedown and the dinner's cutscene, the camera is at 0 degrees. Before: `before-run-start-floor.jpg`. TC-356.
2. **Curtains on bare wall** (the owner, 2026-10-13). `Logic/Windows` counted a curtain as tall furniture against the wall, so a window could never go behind one. Now a curtain against an outer wall gets a window behind it, centred: a plain one (no radiator where you hide, no moonbeam or haze through the cloth, no face at its glass), not counted in the room's limit of three. `World/LevelBuilder` builds it so. Builder only: the planners don't read windows, the lock plans don't change (Gate A unchanged). A curtain on an inner wall stays on bare wall (the dining room's drapes in seed 1800820264): there's no outside behind it. Spec'd in `Windows.spec`. Seen: the hall's two curtains and seed 2's Music Room; hiding in one, the view out is as it was. `before-hall-curtains.jpg`, `after-hall-curtains.jpg`, `after-hall-curtain-close.jpg`, `after-music-room-curtain.jpg`. TC-357.
3. **HOUSE CALL: a red ball on the maze.** The cabinet mesh's joystick ball stands right on the screen's plane, and the game drew behind it: a red blob covered the bottom-left power pellet. The game's screen now sits 0.16 studs out from the bezel (`ArcadeService`), in front of the ball. `before-arcade-joystick.jpg`, `after-arcade-joystick.jpg`. TC-358.
4. **The hiding line read "... · E:".** "Right click: peek · Space: hold your breath · E: leave" was 435 pixels in a 420 box, so its end wrapped out of sight. The box is 560 (`UI/Hud`). `before-hide-hint.jpg`, `after-hide-hint.jpg`. TC-359.
5. **The shelf kept saying Rent.** With the tape in your hand, E on the shelf puts it back (`RentalService`), but the prompt still said Rent. It says Put back now, for you only (`UI/Lobby`). TC-360.
6. **Roblox's buttons on the case folder.** The hub's folder started 22 pixels down, under Roblox's menu and chat buttons (the topbar is 58), and the chat hint covered its title. It starts below the topbar now, and the run's squad list (top left, with friends) too. `before-hub.jpg`, `after-hub.jpg`. TC-361. (CLAUDE.md's known limitation "Roblox's chat hint still overlaps the hub's case folder title" is gone.)
7. **The video store's standee** (the owner, during the walk: "the stand is facing the wrong way and goes through the promotional image"). The easel's strut was tilted forward, through the poster, and its foot stuck out in front. Rebuilt in Blender (`kitlib/mall2` `standee`): the strut leans from the board's back, 1.4 up, to the floor 1.3 behind it. Previews: `after-standee-front.png`, `after-standee-behind.png` (Blender, no holes). Imported by the owner and filed at build .236, below. TC-362.

### Checked and fine

- The mall: the court and its four lightboxes, the fountain, the clutter; the boutique (the booth, a rack: the camera shows you whole; the till's card, every label fits); the video store, its COMING SOON frames, renting; the electronics window's PLEASE STAND BY screen, the counter's card; the garage, getting in, the dashboard, the horn and the countdown; the investigators' camp and its five things to read; the arcade (play, Leave); the diner and its boards.
- A run from the car, in place (Studio): the arrival, the rooms (hall, study, playroom, nursery, dining room, kitchen; seed 2's Music Room), the locks, keys and leads (`locks`, `items`, `leads`: no key behind its own lock), the light: no lamp seen through a wall.
- The Guest downed Claude once while it stood still taking pictures (fair), and the run ended as it should (THE HOUSE KEPT YOU). F2 `botrun fast` on seed 2 (squad of 4) played it out of the front door in 5:56: both heirlooms set, the twin levers and the safe solved, one down, "YOU GOT OUT", +252 Marks doubled for the first escape of the day, then back in the car. `bot-got-out.jpg`.
- The piano lure (TC-355): above.
- The console: no errors or warnings from our code. Roblox's own: a "Pop Close Sound" (203785492, its interface), its fonts' json read as images, two of our uploads "pending moderation" (Roblox's queue), and "DataStores unavailable" (this Studio copy is the local file).

### For the owner

- **Import the standee:** done (the owner: "I imported the fixed movie stand"); filed at build .236, below.
- **THE NIGHT IN NUMBERS on the incident report** (`report-numbers.jpg`): tier scores, time by tier, his moves, "F2 used 7". It's the playtest read-out (2026-10-06), shown to every player. **Decided** (the owner: "Show THE NIGHT IN NUMBERS only in Studio and to the debug allowlist, not to public players"): done in build .235, below.
- **The cabinets' joystick** sits on the screen in the mesh itself; the game is drawn in front of it now, so it doesn't show in play. Moving the stick forward in the mesh means three cabinet imports; not worth it before the release.
- **The camp's work lamp** (`camp-work-lamp.jpg`) throws its cage's shadows in big bars across the case board. Real, and moody; say if you'd rather it lit the board evenly.
- Still open from before: the kitchen's lone vanity sink (`kitchen-lone-sink.jpg`, seed 2), the kettle on the stove, the attic's water tank sometimes dropped, touch controls for phones (whether to launch PC-only).

### Small things seen, left

- The diner boards' "FASTEST · SOLO" headings measure a few pixels wider than their boxes but draw whole.
- The cables into the boutique and the arcade end just inside their doors.
- The fitting room at a taken booth (two players): the second player tries on at the booth's way in, where the booth's own mesh may stand between the mirror's camera and them (the mesh doesn't block the check's rays). Needs two players to see; part of TC-352/353.

## Checks (the walk)

- stylua and selene: 0 errors, 0 warnings. `lune run tests/compile`: 315 files. `rojo build` to `build/scratch`.
- `lune run tests/run`: 754 passed (one new in `Windows.spec`). (The last two edits, the topbar in `UI/Lobby` and `UI/Hud`, are client UI no spec reaches; seen in Studio.)
- `lune run tools/completable`: 1,152 houses, none that can't be finished (the same counts as at .233: the planners never read windows).
- Gate A (F2 `layout cells`, `seed 1800820264`, `gatea`): parts 2456, hash 116728396, unchanged.
- Seen in Studio: every fix above but the standee (not imported yet).

## The night in numbers for the debugger only (build .235)

**The owner, 2026-10-17:** "Show THE NIGHT IN NUMBERS only in Studio and to the debug allowlist, not to public players."

- `RunOrchestrator` sends each player their incident report with the numbers only when `DebugService:IsAllowed` (Studio, or a user id in `Config.Debug.AllowedUserIds`); everyone else's copy leaves `stats` out, and the report goes from THE FAMILY'S VALUABLES to WHAT IT LEARNED ABOUT YOU. His moods are still taught (they're `summary.moods`, not the numbers). The server's Output (`[Consensus:summary]`), F2 `summary`, the F2 overlay and the `RunSummary` telemetry keep them for every run, so a playtest can still be read back.
- `Config.Debug.AllowedUserIds` is empty: live, nobody sees the block. To see it in your own live runs, add your user id there (10608525 is your Studio test profile's).
- **Checked in Studio:** with `AllowInStudio` switched off for one play session (a local edit, not committed), a run's report had no numbers block; switched back on, it had. stylua, selene, `tests/compile`, `rojo build`, and `lune run tests/run` (754 passed). TC-363.

## The standee imported (build .236)

**The owner:** "I imported the fixed movie stand".

- Filed: `Data/Kit` Parts `Standee` (mesh 118671606670787, `size = { 2.6, 6.01, 1.58 }`, `at = { 0, -0.005, -0.54 }`, the build's measures, which the import matched), and its four maps in `assets/kit/Standee.model.json`.
- **Seen in Studio**, the same two angles: from the front, nothing crosses THE HALFWAY HOUSE poster any more (`before-standee.jpg`, `after-standee.jpg`); from the side, the strut leans from the board's back down to the floor behind it, where it used to cross the board and hang in the air (`before-standee-side.jpg`, `after-standee-side.jpg`). Its foot is on the floor (the mesh's bottom 0.01 below it).
- The import's own copy is still in Workspace (`Scene.Standee_Node`): the game builds the standee from its id, so it can go (with the owner's OK).
- Checks: stylua, selene, `tests/compile`, `rojo build`, `lune run tests/run` (754 passed).
