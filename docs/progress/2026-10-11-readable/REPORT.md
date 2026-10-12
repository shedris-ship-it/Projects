# A Guest you can read, and reasons to play again

Builds `2026-10-11.162` to `.167`, branch `claude/overnight-foundation`. After your squad playtest of 2026-10-11 ("we did have some fun ... it just needs polish and more replay ability"), you picked five of my six suggestions: his three rules with a tell each, his moods taught, his temperament felt, the family's valuables, and a fuller short night as the default. Your answers to the plan's questions: his head turns, then one warning, then the reach; no guessing his temperament; valuables carried in your hands; the fuller short night; and, reviewing the plan, the voice trick for a playful Guest on Normal too.

## 1. His moods, taught

Every mood already had a tell drawn on his body and a counter written in `Logic/GuestMood`, but the counter never reached anyone. Now:

- **A tip the first time you watch him a moment in a mood** (1.5 s, standing, on screen, within 45 studs, nothing between you): its tell, its name and what to do. "His head tilts one way, then the other. He's curious. He's looking, not hunting: stay out of his way and keep quiet." Checked in Studio: switching him to curious showed its tip 2 s later.
- **The journal** (Tab, Journal) lists "His moods you've seen", a field guide that grows over a session.
- **The Dossier** lists HIS MOODS TONIGHT, each with its tell and counter. Checked: "Playing host (×2) ... Curious (×1) ...".
- **Found on the way:** the host's tell was "humming" and his counter "the hum carries: you can hear where he is", but no hum ever played (the sound was named in the data and never built). I looked for a library hum and found none that fit, so I made the tip true instead: playing host, he now gives a little bow (his face stays on you; seen from the side in Studio), and the counter points at what that mood really does more often: switching radios on and putting lights out, which tell you where he is.

## 2. His three rules

The how-to's third bullet, the tips and the README now say the same three rules:

1. **Watch him.** He only creeps closer while nobody's looking; two of you watching him in the light stop him (alone, your beam), until he's after someone.
2. **Don't pester him.** In his face or on his heels, his head turns: back off. Keep on and he warns you once, then comes for you with his hands out. Run at him and he lunges.
3. **When he hunts:** break his sight (shut a door, throw something), hide, or get to a lit lantern.

**Pestering is one rule now** (`StalkRules.pestering`, replacing crowding and tailing). Standing in his face, following him close as he backs off, and tailing him further off all fill one meter; the close part drains as fast as it fills (so walking past him never counts, even twice in a row), the tailing part slowly (so stop-start shadowing adds up), and the two add together.
- At 40% his head turns to you, and the first two times "[its head turns to follow you]", plus a tip.
- Full, the warning: his knuckles crack, he squares up to you for 1.6 s with "[it doesn't like that. Back off]", then backs off. A warning is never a down.
- Full again within 5 minutes, the reach (as before: both hands out, walking at 7 studs/s against your 8).
- The old crowding scare (lights out, he vanishes) and its instant grab are gone.

Checked in Studio: head turn at 46%, the warning, then he backed away; a second time while following him, the reach. **One change from testing:** the reach caught me the instant it began, because I was already inside its 3.6-stud grab. It now can't catch anyone in its first 0.7 s (`Config.Guest.ReachWindup`): 0.5 s still caught a test that backed off at once from 2 studs. Step back as his hands come up and you're clear; stay and it's a down.

**A hold you can see wearing thin** (rule one's tell). In a hunt, a two-watcher hold shrinks each time (4, 2, 1 s), and nothing showed it running out. Now the server publishes how much is left (`GuestHoldLeft`):
- A sharp breath in as eyes first stop him (any hold).
- Below half, his head shakes and his fingers twitch, harder as it runs out. Measured in Studio: 0.26° a frame held steady, 4° a frame with a tenth left.
- At 30%, his mask creaks.
- When it breaks, a crack and his head snaps up.

Between hunts a hold never wears out, so none of this shows there.

## 3. His temperament

Each of the four is now strongly itself (`Data/Temperaments`):

| Temperament | Lives in | First minutes | His behaviour | The Dossier's "Next time" |
| --- | --- | --- | --- | --- |
| Patient | waiting | stands in corridors and doorways ahead | waits on your route (Ambush, CutOffLoop ×2), fewer scares | take the other door, and move together |
| Restless | curious | roams, never still | stands beside any one of you half as long; doors ajar ×3, footsteps overhead ×2 | hide and let him pass: he never waits long |
| Playful | playful | his errands (radios, lights, doors), peeks | knocks in wardrobes and radios ×3, fake pings and knocks ×2, **a friend's voice from behind a door on Normal too** | don't chase every sound, and ask your friends where they are |
| Hungry | stalking one of you | searches, sniffing | the heirloom scent twice as often; a long sniff you can hear as he searches and smells one | pass the heirloom on, keep close to whoever carries it, and set it fast |

- His own mood holds most of the night: odds 6 to 1, and it lasts twice as long, because a new mood is never the one he's in, so by draws alone it could never pass half. The spec holds it to the longest and at least 40% of the night for all four.
- The voice trick: `StalkRules.voiceAllowed`, always needing two players (it uses a friend's voice), then Hard or a playful Guest.
- The Dossier: "Tonight he was patient. He waited where you were going to be. The sign: you'd find him standing dead still where you were heading. Next time: take the other door, and move together."
- No tell, cooldown or fairness gate changed.

**Measured in Studio:** one seed, alone, four minutes standing in the hall after he came in (his intro), one run each:

| Set to | His moods | His moves | Scares |
| --- | --- | --- | --- |
| Patient | waiting | Search ×9, DistantRoam ×4, HostAction ×3, Peek ×2 | cold spot, flicker, knock |
| Restless | curious, then waiting | **DistantRoam ×10**, HostAction ×3, Search ×2, Peek | cold spot, flicker |
| Playful | **playful** | DistantRoam ×6, **Peek ×5, HostAction ×4** (a fixture, a door, a light) | **knock ×2**, cold spot |
| Hungry | curious, then waiting | **Search ×8**, DistantRoam ×4, HostAction ×4 | flicker ×2, knock |

What this shows, honestly:
- Restless roams, Playful peeks and plays host, and Hungry searches, from the first minutes.
- **Patient's signature didn't show.** His stand "where you were heading" needs a route to read, and a character standing still in the hall gives him none.
- **Hungry's own mood didn't come up in that run**, for a test-only reason: I set the temperament with F2 after each run had started, so his first mood was drawn under the previous run's temperament, and four minutes holds only about two moods. In a later run where Hungry was set before he arrived, his first mood was stalking, as it should be.
- His sniff is called on schedule (checked on the server). It's heard only within 30 studs, so in a big house you hear it only when he's near: that's the sign.
- Four minutes standing still is a thin test. TC-270 asks you to play each one and say whether you could tell which he was before the Dossier said.

## 4. The family's valuables

Push your luck, carried in your hands as you chose:

- **What and how many.** A carriage clock, a jewellery box, a silver teapot and a cash box (nothing like an heirloom). Two for one or two players, two or three for three, three or four for four; two on the short night.
- **Where.** `Logic/Valuables` picks rooms off the way: side rooms first, then the cellar and the attic, then the furthest room in each wing; one a room, spread over the wings. Never the hall, the dining room, the way out, a corridor, a stair, a lantern room or the safe room. Each lies on a top, in a locked display case (40%: pick it or break the glass), or on the floor when the room has no top.
- **Optional.** Never on the objective line, the plan, a hint or the map's "done" ticks. Once seen lying, it shows on the map in silver.
- **Carried.** His scent follows you as with an heirloom (a hunt goes for the carrier), and he puts back one left lying, under the heirloom's unseen rules. The first pickup's toast says so, and a tip says it the first time you look at one.
- **Out of the front door** (only possible in the run out, after the dinner): "You got out with the carriage clock", 25 Marks each for everyone in the squad, and the Dossier lists THE FAMILY'S VALUABLES: what got out, who carried it, and how many were left.

**Checked in Studio:**
- F2 `valuables` lists them.
- Picking one up puts you in his scent list as its holder.
- Carried out of the front door in the run out: the toast, the Dossier line, and +254 Marks against +238 without.
- All four seen side by side (screenshot).

**Three fixes from testing:**
- The first house placed none at all: both rooms picked were bare side rooms with no top. They now fall back to the floor, as an heirloom with no drawer does, and the Output says where each went ("[Consensus] valuables: cash box in the downstairs Bathroom (floor), ...").
- Over the next few houses, most went on the floor of a laundry, a bathroom or the boiler room, and never in a case (a case needs a top). Among rooms as far off the way, one with furniture to set it on now ranks a little higher, so more sit on a dresser or in a locked case.
- The carriage clock read as a brass block from behind. It now has a dial (with hands) on both faces, a plinth and a cap.

**For you to judge:**
- **The Marks** (`Config.Valuables.Marks`, 25): I can't test that by myself.
- **Marks still buy nothing.** Until they do, the haul is a score, so the pull to go back for one comes mostly from the risk. When you want it, the next step for replay value is something to spend Marks on.

## 5. The default night

The short night is now the fuller one you chose:
- two wings and two heirlooms;
- one side room behind the house key, one tool kind;
- two valuables;
- no cellar or attic.

It's the default (`Config.Run.Night = "short"`). The hub's button reads "Night: Short (15 min)", or "Night: Full house" after one press (both fit the button, checked with `TextFits`).

`tools/housestats`, 30 houses alone:

| | Rooms | Wings | Side rooms | Tool locks | Walk to finish (studs, median) |
| --- | --- | --- | --- | --- | --- |
| Short night | 15-17 | 2 | 0-1 (median 1) | 0-2 (median 1) | 1,348 |
| Full night | 17-22, plus the cellar or attic | 3 | 0-1 (median 0) | 0-3 (median 1) | 1,865 |

For four players the short night's walk is 1,472 (median over 20 houses).

`tools/completable`: 1,152 houses (every squad, difficulty, night and candidate), all finish.

**The bot's runs** (it knows the plan and cheats the puzzles, so its time is a floor, not a human's):

| Seed (squad) | First door | Dinner | Out | Steps (failed) | Waits for him | His temperament |
| --- | --- | --- | --- | --- | --- | --- |
| 61 (1) | 0:21 | 1:02 | 1:23 | 10 (0) | 0 | the seed's |
| 1 (1) | 0:26 | 1:46 | 1:50 | 11 (0) | 1 | the seed's |
| 1800820264 (1) | 0:27 | 3:28 | 3:37 | 10 (0) | **24** | Playful |
| 4242 (4) | 0:25 | 2:23 | 2:48 | 9 (0) | 15 | Hungry (stalking the whole run) |

No stuck points, nothing it couldn't do, no torch dying. These are a floor: the bot walks straight to each thing and solves puzzles instantly, and on today's full night the same bot finished seed 1800820264 in 1:41. It can't say how long a squad that has to find, read and talk will take. The "about 15 minutes" on the button is my estimate; TC-274 asks you to time yours.

**One number to watch, again:** on seed 1800820264 the bot stopped to let him pass 24 times (the last report: 16 and 20). Nothing in this pass changed how he moves between hunts, but if he still feels in the way in your next playtest, that's the thing to look at next.

## Checks

- **Unit tests:** 576 pass (562 before this pass). New specs `Pester`, `Temperaments` and `Valuables`; extended `GuestMood`, `GuestMotion` and `HouseSearch`. `Crowding` and `Tailing` are folded into `Pester`.
- **stylua, selene** (0 errors and 0 warnings), **compile** and **rojo build**: clean.
- **`tools/completable`:** 1,152 houses, 0 can't be finished.
- **Gate A** (the old house, `layout cells`, seed 1800820264): unchanged, parts 2269, hash 1553234744. The old house keeps no valuables.
- **Studio:** every build was synced and checked by length against the repo, then played. No console errors in any session; the only red lines were the usual DataStore 403s (Studio's API access is off).
- **Not checked by me:**
  - anything that needs two clients (pestering seen by a friend, the playful voice, the shared haul);
  - the sounds by ear (the breath in, the creak, the crack, the sniff);
  - whether the moods and temperaments are actually readable to a player who doesn't know the code. That last one is the real question, and it needs your playtest.

## For you

TC-266 to TC-274 in `docs/TESTING.md`. Pestering seen by a friend (TC-268), the playful voice (TC-271) and the shared haul (TC-273) need two clients.
