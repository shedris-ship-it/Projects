# Step 6c: how The Guest stalks you

The owner's brief (2026-10-03):
- smart and adapting;
- always physically somewhere in the house;
- peeks from doorways;
- flees fast when spotted early;
- creeps up while your back is turned;
- deadly up close at high Drift;
- backs away slowly without ever looking away.

Rules: `Logic/StalkRules` (tested). Brain: `Stalker/Stalk`. Body: `Stalker/Body`. What the squad can see: `Stalker/Sight`.

**Checked in Studio** (seed `1800820264`, one client plus the Companion):
- **Arrival:** three knocks at the front door (the knock sound ends with the door creaking open), then he's inside, entering only where nobody can see.
- **Tier 0:** he walks the far rooms, pausing at closed doors to open them. Seen by nobody.
- **Tier 1:** he walked about 100 studs across the house, unseen, to an open doorway 28 studs behind the player, then leaned his head round the jamb, watching (`02_peek_tier1_doorway.jpg`: the pale edge of his face at the left of the dark doorway). When the player looked at him he was yanked back behind the wall and hidden for a while. Closed doors are never used for peeks.
- **Tier 2:** with the player's back turned he walked over, then crept the last 20 studs in short bursts at about 1.8 studs/s, and stood 2.5 studs behind them. Turning round (`01_turn_around_tier2.jpg`): he holds, looking down at you. He then backed away more than 40 studs at 3.5 studs/s, facing the player the whole way (`03_after_backing_away.jpg`: gone into the dark room).
- **Tier 3:** he crept up behind a turned back. The client received a breath and a creak at 20.6 s, another breath at 24.1 s, then the lunge at 25.6 s from 6.0 studs, a hit, and the catch: the player went down. Then he backed away. The Companion revived the player.
- **Watched in plain view at tier 2:** he held still and stared, and only moved again once out of sight.
- Server heartbeat 0.3 ms with all of this running. No console errors.

**Not checked yet (needs the owner):**
- Two clients: two watchers freezing him, and the lunge being cancelled by a second Witness.
- Only the target seeing him at tier 1.
- Nobody ever seeing him pop in or out.
- The jumpscare. `guest scare` previews it, but it wasn't captured here.
- How the creep, back-away and peek poses look in motion.
