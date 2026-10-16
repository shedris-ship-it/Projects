# The lobby rework, LB5: the arcade and the diner's records

The owner, away from their computer: "Lets build LB5". The plan (`docs/plans/lobby-rework.md`, "Arcade", "The diner", "The arcade's games and scores") had every decision already: HOUSE CALL first, a play for 5 R or 100 Marks, one free play a day, a 10-play bundle, a 250 R unlimited pass, high scores all-time and weekly, spectating, the replay check, the prize counter closed; and the diner's two boards (Normal and Hard; fastest and longest; solo and squad; the short night; real runs only). Built in one pass, build .217.

## HOUSE CALL (`src/shared/Logic/Arcade/HouseCall.luau`)

The Guest's three rules as a maze game, so the arcade teaches the run:

- **You take the family's silver** from a dark house (21 x 15, a corridor ring round his room, a tunnel at the sides) while he stalks you.
- **Face him and he freezes:** your torch's line runs seven cells down the way you face. Hold the button to stop and look; the stick then only turns you.
- **Don't pester him:** stare at him about three seconds and he hunts.
- **When he hunts,** your look doesn't stop him and he's quicker: break his sight round a corner, or get to a lantern in a corner, whose light he never steps into. Getting away is worth 100. He also hunts every 45 seconds or so, sooner in later houses.
- **Touch him and he has you.** Three lives, one more at 10,000. The family's heirloom shows twice a house for a bonus. Clear the silver and the next house is faster.

It's pure and seeded with a fixed 20-tick step, so a game is its seed and its presses. Tuned with four bots (`tools/_arcadebot.luau`, scratch):

| Bot | Plays like | Mean score | Mean length |
| --- | --- | --- | --- |
| careful | keeps two cells from him, looks at him when he's close, runs for a lantern in a hunt | 16,572 (6,450 to 39,450) | 6.7 min (3.4 to 12.5) |
| fair | takes the nearest silver, glances at him | 2,344 | 1.4 min |
| greedy | only the silver | 2,733 | 1.2 min |
| random | wanders | 407 | 0.8 min |

Skill counts a great deal, as an arcade game should: a careless first game is about a minute; a careful player gets a few houses deep for a 5 R play.

## Paying (`Logic/Arcade/Credits.luau`)

E at a cabinet plays at once with the unlimited pass, then the day's free play (midnight UTC), then a play bought for Robux. With none of those, the coin card (`UI/Arcade`): one play for 100 Marks, or the Robux plays and the pass, marked SOON until the owner makes the products in Creator Hub and their ids go in `Data/Products`. Profile version 5 adds the day of your last free play.

## The cabinets (`Services/ArcadeService`, `Controllers/ArcadeController`)

- Each HOUSE CALL cabinet (`Data/Mall` blocks with `game`) has a screen over the mesh's own, a blue glow, and a Play prompt on its panel.
- **Idle,** its attract mode: the title, and every six seconds his rules, this week's best, the best ever; the bottom line blinks your free play or INSERT COIN.
- **Playing,** you're stood at the cabinet and the camera settles on its screen: arrows or WASD (a gamepad's D-pad or stick), hold Space (A) to look, Backspace (B) walks away and the score so far counts. On a phone, arrow, Look and Leave buttons.
- **Watching:** anyone within 24 studs sees the same game a moment behind, run from the presses the server passes on, with the player's name at its foot.
- The screen is drawn with frames in a SurfaceGui (the maze's walls and their blue edges, the silver, the lanterns, you and your torch's line, him, the HUD, scanlines), not an EditableImage as the plan first said: crisp at any distance and no image memory. It runs on Heartbeat, not RenderStepped: a 20-tick game needs no more, and it keeps working while Studio's window isn't drawing.

**The replay check:** your client sends its presses in batches as you play (in order, well formed, never ahead of the server's clock by more than 3 s), and at the end the server replays the game from its seed for the score. A score the replay doesn't give is dropped.

## The boards (`Services/BoardService`, `Logic/Leaderboard.luau`)

Every board is one DataStore key holding its whole list, best first, with the names. The plan said OrderedDataStores; one key per board is simpler and cheaper here:

- only the top few ever show;
- the names come with the list (an OrderedDataStore holds only numbers, so it would need a second store for them);
- a write happens only when an entry makes the board, through UpdateAsync, so two servers posting at once both land.

The arcade keeps this week's (from Monday, midnight UTC) and the all-time board, top ten, one entry a player. Lobbies read the boards they show every two minutes. Studio uses its own store (`ConsensusBoards_v1_Studio`), and without DataStores the boards live in memory for the session.

## The diner's records (`Services/RecordsService`, `Logic/Records.luau`)

- **A real run's time:** from the arrival to the last of the squad out of the front door, measured by the server (`RunOrchestrator`).
- **Which runs count:** a completed escape on the short night only; never from Studio, never one any F2 command touched (`DebugService.used`, the bot's runs too).
- **Where it goes:** onto its board's fastest and longest list, solo or squad by how many started it. The squad is told where it landed ("On the diner's board: the 2nd fastest squad, 18:41, on the menu board").
- **The two boards:** white letters on the boards' felt over the back bar. "THE SHORT NIGHT · OUT OF THE FRONT DOOR" runs across the top, then four lists of five. A squad's lines name everyone; its columns are wider, and a long line shrinks a little before it's cut short.

The prize counter is unchanged: shut under its dust sheet, PRIZES · CLOSED.

## F2

- `arcade` alone: how your next play is paid.
- `arcade play [n]`: play at cabinet n.
- `arcade free`: today's free play back.
- `arcade credits <n>`: set your bought plays.
- `arcade score <n> [name]`: put a score on the boards.
- `arcade bot [cheat]`: a scripted game through the replay check and onto the boards as BOT; `cheat` claims 1,000 more than it scored.
- `arcade clear`: empty the high score boards.
- `record` alone: each list's top line.
- `record count`: the next run counts even in Studio.
- `record add <normal|hard> <fast|long> <solo|squad> <seconds> [names]`: put an entry on a board.
- `record clear`: empty the diner's boards.

## Checked

- **Tests:** 16 new (`Records.spec`, `Arcade.spec`). They cover the boards' sorting, ties and one-a-player rule, and which runs count. They also check that every cell of the maze can be reached, that a replay scores the same as the game, freezing and the hunt, the lantern, being caught, a watcher's late presses, the press checks, a fair bot's games ending, and paying.
- **In Studio,** solo (the display was asleep, so no screenshots):
  - the two boards built and lettered, entries landing in place, every line fitting once the squad columns were widened;
  - both cabinets: the attract screen with this week's scores and INSERT COIN after the free play;
  - `arcade play`: stood at the cabinet, anchored, the camera on the screen, the game running, then GAME OVER, the client's end reported, the replay matched (two games, score 0: the test tool's key presses don't reach a window that isn't drawing), the player let go, the camera back, the attract screen again;
  - paying: free play first, then bought plays, then the coin card (every line fitting) and a play for 100 Marks (150 to 50);
  - `arcade bot`: 710 and 770 posted, the better replacing the worse; `arcade bot cheat` dropped ("replay 350, client 1350");
  - a whole run: `record count`, then `botrun` on seed 1800820264 escaped, and it went on the menu board's fastest and longest solo at 4:10, the run's own "out 4:10";
  - no script errors.
- **Not checked:** playing by hand with real keys (TC-334), watching with two clients (TC-336), a gamepad and a phone (TC-337), live boards across servers (TC-338), and how it all looks (screenshots, once the display is on).

TC-331 to TC-338.
