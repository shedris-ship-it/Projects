# The first squad playtest: the fixes (2026-10-08)

Branch `claude/overnight-foundation`, builds `2026-10-08.131` to `.146`, from `2026-10-06.130`.

The owner ran the first squad playtest on build `.130` and sent 17 notes. Physics sync was praised. The rest are fixed here, one work package (WP) per build. The plan is in section 17 of `docs/plans/gameplay-rework.md`.

## The owner's decisions (2026-10-08)

| Note | Decision |
| --- | --- |
| "Make the hands universal for all slots" and "make everything grabbable with E" | **E does it all.** Slot 4 (bare hands) goes. From any slot: tap E to open, pick up or use; hold E and move the mouse to drag or push. While carrying, click to throw (hold to charge) and E to put it down. The torch stays at full beam. Hold-click grabbing still works. |
| "Players can mess around with the Guest and get in his personal space while he's backing away" | **A scare, then a down.** Crowd him once and he turns on you: lights out, his mask in your face, your torch dead, and he's gone. Do it again within about 3 minutes and he grabs you. Following him while he backs away counts. |
| "Maybe the Guest should shapeshift" | **A teammate only.** Late in the run, one player sometimes sees him far off wearing a teammate's look. Walk up to it and it's him. |
| "Hunting doesn't feel like a threat" | **As fast as your sprint.** The ways out are breaking his line of sight, shutting doors, a throw, hiding, or two of you staring, and a stare doesn't hold him at arm's reach. Also: a scream at the start, his wing's lights die, music, longer hunts, smarter search. |
| (mid-session) | "Fix everything in one go if possible", without lowering the quality. The piano puzzle itself is ambiguous: "even for me who knows it's there, I don't know how to do it", and a new player wouldn't realise the piano is a puzzle at all. |

## WP1 (build `.131`): no clock over a window, the solo bleed bar, a test that couldn't fail

**The clock over a window.** `RoomFit.fit` squeezes a 40×40 template into a mansion room, and it fitted windows and wall slots separately. A small room pulled both towards the middle of the same wall. The guest room, nursery and sewing room always hung a slot about 2.6 studs from a window's centre, when 4.2 was needed.

What changed:
- Wall items now keep clear of each other on their wall: `half + other.half + RoomFit.WallItemGap` (0.6).
- Decor is fitted first, so slots give way to windows, mirrors and paintings.
- Slots are `RoomFit.SlotHalf` (1.8) wide either side, which fits a portrait, the widest thing hung in a slot.
- `LevelBuilder.furnish` drops any slot that would still hang over a built window, mirror or painting.

Gate A can't move: the 40×40 templates already keep 2.5 studs clear, and the backstop needs 2.4. The F2 `clip` scan now also sees things hung on walls outside the rooms' models (the Decor folder, puzzle boxes, racks) and cylinders.

**The solo bleed-out bar.** It was scaled by the 15 s squad down, so a solo player's 20 s down drained the bar 5 s early. A `DownedSeconds` attribute now carries each down's real length.

**A contact test that couldn't fail.** `Stalk.spec`'s `touching()` left out `approachSpeed`, so it passed while the live code refused every walk. It now carries a run's speed, and a new case checks that a walk at 8 is not a contact.

**New tests:** TC-158 (no clock over a window) and TC-159 (the solo bleed bar).

## WP2 (build `.132`): the piano, made readable

The owner: "even for me who knows it's there, I don't know how to do it". A new player wouldn't realise the piano is a puzzle at all. The code reading found five more faults:
- The piano played an octave below the box, so the key that sounded like a note was the wrong one.
- Every wrong key reset the tune with a loud discord.
- Every note was muffled by its own prop.
- Number keys 1–3 also switched slots, which dropped a carried box.
- The comb only lit with subtitles on.

What changed:
- **One colour per note.** The box's comb and the piano's keys wear the same eight colours, a child's practice stickers (`Config.MusicBox.Colors`: red, orange, yellow, green, teal, blue, purple, pink). The comb is bigger. Its teeth light as each note plays, for everyone, always.
- **The tune on screen.** Anyone within 24 studs of the box as it plays sees the comb strip, `UI/TuneStrip`: one coloured slot per note, its name under it, fading 1.6 s after the last note. Say the colours to whoever is at the piano.
- **The piano says what it wants.** It has stickers on eight keys, and a sheet on its stand, "the box's song", with one blank note per note of the tune. The sheet fills with the tune's colours once it's played.
- **The screen.**
  - The keys wear the colours and their names, and sound the moment you press them.
  - The lights fill with the colours matched so far.
  - **Listen** winds the box when it's beside the piano.
- **No penalty for slips.** Wrong notes cost nothing. The piano opens the moment the last notes played are the tune (`MusicBox.matched`). Each key is a little noise instead (`KeyNoise` 12). Tunes are 4 or 5 notes (were 4 to 7), and the piano plays at the box's pitch.
- **Leads.**
  - The objective line says "The piano in the X is shut on something. It wants the music box's tune." until someone has heard the box, then "Play the music box's tune on the piano in the X. Its keys wear the colours of the comb's teeth."
  - A box seen first has its own line: "There's a music box in the X. Wind it and watch its comb."
  - The stuck-hint points at the box's room until it's heard.
  - The map marks the box once seen.
  - Two tips teach it.
- **Fixes.**
  - Sounds aren't muffled by their own prop: `AudioController:_behindWall` stops 1.5 studs short. This helps every positional sound.
  - Number keys don't change slots while a screen is up.
  - Fast presses aren't dropped (`PuzzleInput` 0.04 s, burst 20).
  - The carried heirloom's faint tune goes quiet within 30 studs of the clue box.
  - The heirloom lands on the piano's top wherever it has been pushed.

Dropped from the design doc: the discord rule (a wrong note was a loud noise and a restart).

**New tests:** TC-160 (a newcomer finds and solves it without help) and TC-161 (number keys at the piano).

## WP3 (build `.133`): the torch, wider and shorter

"Widen the light but shorten the distance." The beam's numbers were typed into three places (a 48° cone for your own light, 50° for the one others saw, both 42 studs), and the stare check had a fourth copy (`Config.Stare`, 28° either side of centre).

One table now, `Config.Torch`: a 72° cone (36° either side), 30 studs, brightness 2.6 for your own and 2.4 for the one others see, and the clip light 80° by 16 studs. It feeds:
- your torch, and the light on your head;
- the clip light;
- the stare's "he's in your light";
- his eye-shine;
- the writing that only shows in your beam.

A spec keeps the stare's beam equal to the torch's.

**Side effect, intended:** your beam holds him, and catches his eyes, only within 30 studs (was 42). His sight of a lit player stays 40, so in a long corridor he sees you before your light can hold him.

**Fix:** `ActionController` exposes its light part, so `ViewModelController` can move the beam to the torch's lens in the same frame. That line never ran before.

**New tests:** TC-162 (the beam's look; do the light you see and the one your friends see match?) and TC-163 (the stare at 25 and at 35 studs).

## WP4 (build `.134`): stronger throws

"Weak throws." A tap threw at 35% of the class's speed (17.5 studs/s for a bottle, under the 28 a stun needs). Roblox's gravity, about five times a real fall at this scale, pulled a full throw to the floor in about ten studs.

What changed:
- **Faster things.** Throw speeds are light 68, medium 58, heavy 46 and bulky 38 (were 50, 42, 34 and 30).
- **A quicker wind-up.** A tap is 55% (was 35%), and full power comes at 0.5 s (was 0.7). A tapped bottle or vase stuns; a heavy thing still wants a wind-up. `StunMinSpeed` is 30.
- **A flatter flight.** For its first half second a throw falls with a quarter of the gravity (`FlightLift` 0.75, `FlightLiftSeconds` 0.5). A light throw at a wall 25 studs off now lands about 2.3 studs below where it left, not on the floor.
  - A `Lib/ThrowLift` force does it on whichever machine flies the thing.
  - It comes off early if the thing slows hard, and when it bounces off him.
  - `Throw.predict` models the same lift, so the server's first-arc stun check still agrees.
- **Feel.** Winding up draws the thing back towards you (up to 0.8 studs). A full throw kicks the view out by 3° (scaled by the Camera motion setting). The whoosh is louder and higher the harder you throw.

**New test:** TC-164 (throws at a wall, at him, and a tap against a wind-up).

## WP5 and WP6 (build `.135`, one commit): the Guest off the furniture; players collide

### The Guest off the furniture

"Guest gets stuck on top furniture." His only colliding part was his root, riding 3.9 to 5.3 studs over his feet. Most furniture is lower (beds 3, tables 3.4), so the Humanoid took a table's top for floor and walked him up onto it. The clearance sweeps that guard his glides and yanks started at 3.5 studs and missed furniture too.

What changed:
- **A leg guard.** An invisible part from 1.2 to 3.9 studs over his feet (`StalkerModel` "Shins") stops at furniture like a wall, and still clears the stairs' ramps.
- **Knee-high sweeps.** His sweeps reach down to 1.3 studs over his feet, and a second ray checks his knees (`Clearance` `sweepLow` and `kneeDrop`, for the Guest only).
- **Recovery** (`Body:_checkAloft`). Found on a piece of furniture for 0.3 s, he goes to the nearest floor that fits him: straight there if nobody can see him, else by stepping down. It's logged as `GuestAloft`.
- **Peek spots checked on use.** They're re-checked for furniture pushed onto them since they were cached. A spot counts as reached only within 1.5 studs of height (`Config.Guest.ArriveDy`; was 3, so a bed next to a spot counted).
- **navtest counts it.** It reports moments on furniture.

**Studio, seed 18:**
- `navtest fast`: 21 legs, 0 failed, 3 with no way (locked doors), 0 falls, 0 phases, **0 on furniture**, 0 stuck moments.
- Placed on a bed by hand, he was on the floor beside it within 0.4 s (`GuestAloft {"on":"bed","seen":false}`).

### Players collide

"Add collision between players." Players passed through each other on purpose, so nobody could body-block a doorway (DesignDoc section 3).

Now players collide through their roots:
- The root is the player's body to the world: `CollisionGroups.PlayerBody`, solid to other players.
- The rest of the body collides with nothing, so a lying or crouched pose never fights the floor (WP7).
- **Nobody can block a doorway** (`Logic/Bodies`, `Config.Bodies`). Two players pressed together for 0.9 s give way to each other (`PlayerGhost`), for at least 1.5 s and until each is 3 studs from everyone, so nobody turns solid inside a friend.
- **Never solid:** the downed, the hidden, and anyone the game just moved (out of a hiding place, past a barricade, down the chute, revived).
- It runs four times a second for every player, in the hub too.
- The bot's sweeps use the ghost group, so they never treat a teammate as a wall.

**Studio checks:** a player still stands on floors, climbs the grand stair and stops at walls (a root's half-width short). Gate A holds (parts 2152, hash 1995746720). 480 tests pass.

**New tests:** TC-165 (the Guest and furniture), TC-166 (bumping into a friend), TC-167 (a friend in a doorway gives way within a second), TC-168 (a downed friend never blocks). TC-166 to TC-168 need two clients.

## WP7 and WP8 (build `.136`, one commit): the down, the crawl, crouching

### The down and the crawl

"There is no down animation." A downed player stood up and played the walk at 3 studs/s. Nothing in the game posed players. Nothing is uploaded now either: the poses are built in code like the Guest's.
- **`Logic/PlayerPose`** (pure, R15, read off this place's rig) has the crouch with its gait, prone with a crawl, and the kneel. `PlayerPose.spec` runs forward kinematics over the real body: feet stay on the floor crouched at every step, a downed body lies on the floor with its head lifted, the back knee touches the floor kneeling.
- **`Controllers/PoseController`** poses every character on every client from what the server says (downed, reviving, crouched, ducking into a hiding place).
  - It writes the joints after the default animation each frame, as `GuestController` does for him.
  - This place's rig uses `AnimationConstraint` joints, which take a `Transform` like a Motor6D.
  - Poses ease in and out: a 0.6 s fall, a 0.8 s rise, a 0.25 s crouch.
- **The rescuer kneels** while they hold E on you (a `Reviving` attribute from the prompt's hold).
- **The camera follows the body** (`FeelController`, position only): near the floor and at the head when downed, a stud lower crouched, 1.3 kneeling.

**Studio, seed 18:**
- A posed copy of the character, seen from the side: the crouch reads as a crouch, and the downed body lies face down, arms reaching out past the head, legs trailing.
- F2 `down`: the head is 1.8 studs under the root and 2.2 ahead, and the camera is 3.2 down.
- `revive`: the body is up in about 0.75 s, and the camera back to standing height.
- No console errors.

### Crouch

"No sneak/crouch control." Now:
- **Controls.** Hold Left Ctrl, or toggle it with a new setting. Gamepad B toggles it, and it's a touch button on phones.
- **A silent creep at 3.5 studs/s** (`Config.Player.CrouchSpeed`). That's under the 4 studs/s where steps and noise start, so it makes no footsteps and nothing he hears. `Feel.spec` keeps it under both thresholds.
- **Sprinting stands you up**, and you can't jump crouched.
- **The server decides** (`SetCrouch`, the `Crouched` attribute). It clears on a down, hiding, being Lost or the run ending.
- **He looks for you lower** (`PlayerStateService:SightPoint`): 1.6 studs lower while you creep (at walking speed or more it doesn't count), so a sofa or a table between you can hide you. In the dark, a creeping player is seen only within 0.7 of his dark range (10.5 studs, not 15). He still senses anyone within 5 studs.

**Studio:** holding Ctrl sets `Crouched`, a walk speed of 3.5 and no jump; letting go stands you up (walk 8, jump 3). 486 tests pass.

**New tests:** TC-169 (the fall, the crawl, the low camera), TC-170 (revived: back up; the rescuer kneels; two clients), TC-171 (crouch: silent, he sees you later in the dark, a sofa hides you).

## WP9 (build `.137`): E does it all

"Having to switch from flashlight to hold doors and objects doesn't feel good", and "make everything grabbable with E". Grabbing anything used to switch you to slot 4 (bare hands), which swapped the torch's beam for the weak shirt light.

**The owner's decision: E does it all.**
- **Three slots.** Slot 4 is gone (`Logic/Inventory`). Your hands work from any slot, and grabbing never changes your slot. With the torch out, it stays at full beam while you drag, carry or push. An empty tool slot is a free hand (the torch clips on), and the wheel goes round all three.
- **On a keyboard** (`HandsController:_onE`):
  - Tap E on a door or a drawer and it opens or shuts. A new `Tap` remote does the prompt's own job, with its reach and only while the prompt would work.
  - Hold E (0.22 s) on it, or on furniture, and your hand takes hold as the mouse button does.
  - Tap E on a small thing and you carry it: a click throws (hold it to wind up) and E puts it down. Hold-click carrying works as before.
  - The door and drawer prompts lose E on a keyboard, set locally on each client; gamepad and touch keep them. The hints say "E" and "Hold E".
- **What you look at wins.**
  - E is bound above the prompts. Aimed at a door next to a light switch, E opens the door; aimed at the switch, it works the switch.
  - A door that swung out of your aim still answers to E through its shown prompt, unless another E prompt is showing.
  - Furniture you hide in keeps E for hiding; its doors take the mouse.
  - A small thing with its own E prompt (the music box's "Wind it", a wind-up toy) keeps E for that.
- **Choosing a slot that holds a tool** puts down what you carry. The torch, or an empty slot, leaves your hand free.
- **Also changed:** the controls line, the Settings controls, the hands tip and the HUD's carrying line ("Click: throw · E: put down · wheel: nearer, further").

**Fixed on the way:** a door you shut stopped on you half way. Furniture beside a door makes it open towards you, and you, as its opener, were let through. Closing, it stopped against you, and the next tap read the half-shut door as "open it", so it could never be shut from where you stood. Now whoever swings a door, either way, isn't in its way (`DoorService:_bodyStop`).

**Studio, seed 18, the grand hall:**
- Tapping E opened the door and tapped again shut it from the same spot. The prompt's key was None on the keyboard, and the slot stayed 1.
- E picked up a magazine with the torch unclipped, and a click threw it 36.8 studs.
- Next to the hall's light switch: E aimed at the door opened it; aimed at the switch, it switched the light and the door stayed open.
- In Studio the client records its last E decision in a `DebugHandsE` attribute, for tests.

**New tests:** TC-172 (E on doors, drawers, things and furniture), TC-173 (gamepad and touch unchanged), TC-174 (the torch at full beam while carrying).

## WP10 (build `.138`): hiding, tucked in and peeking

"Hiding is kinda strange, could use a hiding animation, also be able to peek from the hiding spot instead of seeing everything perfectly." The camera used to snap to a point 0.35 studs *outside* the furniture, at full view and normal field of view.

What changed:
- **You duck in.** For 0.35 s everyone else sees you crouch into it (the `HideEnter` attribute, `PoseController`) before you vanish. You count as hidden from the first moment.
- **Your eye glides in** to the gap over 0.35 s, with no snap.
- **Tucked in**, you see through a slit shaped by what you're in (`Logic/HideRules.Slits`, `UI/HideView`):
  - a wardrobe's or cupboard's louvred gap;
  - a locker's five vents;
  - the strip of floor under a bed's skirt;
  - under a tablecloth's hem;
  - past a curtain's edge, the cloth in folds.

  The field of view is 58°, and you can look about only a little. Everything is frames and gradients, with nothing uploaded.
- **Hold right click (LT) to peek.** Your eye eases out to the gap, the field of view opens to 70°, you can look further, and the slit fades.
- **Peeking has a risk** (`HideRules.noticed`, `Config.Hide`). If he's closing in (tier 2) or hunting, within 14 studs, facing within 50° of the gap with a clear line, and you peek for 0.8 s, his head snaps to the door. He then knows you're in there, as if he'd heard you (`StalkerService:NoticePeek` → `HeardYou`): in a hunt he searches it first. He never sees through the doors; it's the peek that gives you away.
- **E hides you in hiding furniture**, even though E is now your hands'. Holding the mouse pushes it.

**Studio, seed 18, the grand hall's curtain:**
- E (a short hold) hid me.
- The view was the curtain's edge at 58°, the hall and stair past it. Holding right click opened it to the hall at 70°, and `Peeking` was set.
- E left. The view went back to 70°, the overlay went, and the camera returned to normal.

**Not checked in Studio:** his notice (it needs him at tier 2 facing a peek; the rule is specced) and others seeing the duck-in (two clients).

**New tests:** TC-175 (each kind's view, tucked and peeking), TC-176 (a friend ducks in; two clients), TC-177 (a peek he notices).

## WP11 (build `.139`): a subtler start

"Guest should be more subtle at the beginning of the game." He arrived at 1:33 and was at tier 1 by about 2:00. A quick squad's first door (the bot opens one at 0:29 to 1:06) raised Dread to 40, so tier 2 (visible to everyone) came about 90 s later, and a hunt could start at 3:00.

Now each night opens with **the intro** (`Config.Pacing.IntroSeconds` 300; 180 on the short night; ×0.6 on Hard):
- **Quiet.** Tier 1 at most, however fast the first door opens. No hunts and no false alarms (`DirectorModel`). Scare cards come 1.5× further apart, with none of the big ones (`ScareDeck` `quiet`).
- **Only glimpses** (`Config.Guest.Intro`):
  - He's seen only by peeking from a doorway, roaming far off, standing at the end of a corridor, searching, investigating a noise, or by what he does to the house (a radio on, a light off).
  - Never closer than 30 studs, a peek held 2–4 s (was 6–14), and 35–60 s unseen after each sighting (was 14–30).
- **Ending it early.** Only a house already Breaking (Drift 60) cuts the intro short.

**Specs:** `Pacing.spec` has a new test: a door at 0:30 still means tier 1 at most and no hunt before 5:00, and Hard's intro is shorter. A steady night now meets tier 2 at minute 5.5 and its first hunt at 5.6 (the 2–5 hunts and tier 3 in the second half still hold).

**New test:** TC-178 (the first five minutes: frightened, but only by glimpses and sounds).

## WP12 (build `.140`): hunts with teeth

"Hunting doesn't feel like a threat, hunts need to be more menacing." He ran at 17.5 against your sprint of 19. Two players staring froze his catch even at arm's length. Hunts lasted 45–90 s, and they had no music.

**The owner's decision: as fast as your sprint.** What changed:
- **The chase.** Chasing someone he can see, he runs at your full sprint (`Config.Stalker.ChaseSpeedRatio` 1.0; Hard's +4% is for his prowl only, the final hunt still ×0.85). Your sprint lasts about 6 s, so the ways out are:
  - breaking his line of sight;
  - shutting a door behind you;
  - a throw;
  - hiding;
  - two of you holding him at a distance.
- **No stare at arm's reach.** Within 6 studs of anyone the hold doesn't stop him (`StalkRules.holdsAt`, `Config.Stare.HoldMinDistance`), though its clock still runs.
- **The opening.**
  - A scream, heard through the house (`Assets.Sounds.GuestScream`, APM "HORROR SCREAM 10").
  - Up to 4 rooms within 50 walking studs of him go dark, never a Lantern room, until the hunt ends or is overtaken.
  - The house tells him which room the nearest of you is in, as if he'd heard you (`StalkerService:_huntOpens`, a declared rule the telegraph's hum cues), so no hunt fizzles in the far wing.
- **Longer hunts.** 60–120 s (were 45–90).
- **A sharper search.** Where he lost you he searches 3 hiding places (was 2) and listens for 2.5–4 s (was 1.5–3).
- **Music, at last.** The stalking stem is APM "Tension Repeat Drones 29" and the hunt stem APM "Rhythm Drone 34" (`Assets.Music`). The calm stays silent. **None heard by the owner yet:** swap freely; the other candidates are listed in `Assets.luau`.

**Kept:** the telegraph, a start out of sight 25+ studs away, revive grace, a catch only if he can see you, Lantern rooms.

**Studio, seed 61:**
- A forced hunt (`tier 4`) darkened rooms 10, 19 and 20, the three nearest him that aren't Lantern rooms.
- He caught a player standing still within 14 s.
- No console errors. The scream and the music are still to be heard.

**New tests:** TC-179 (the opening), TC-180 (each way out against a sprint-fast chase), TC-181 (length and search; does it feel like a threat now?).

## WP13 (build `.141`): crowding him, a scare then a down

"Players can mess around with the Guest and get in his personal space while he's backing away without consequences", and "the Guest needs to give people reasons to be afraid, especially if walking up to him". Today a walk at him always made him step aside. While he backed away, recoiled or retreated, every contact check was skipped, and only a sprint at him counted.

**The owner's decision: a scare, then a down.** The rule is `StalkRules.crowding` (pure, `Crowding.spec`):
- **How it builds.**
  - In his face (within 3.5 studs, looking at him) fills the pressure at 1/s.
  - Following him as he backs away, withdraws, retreats or makes way (within 7 studs, closing) fills it at 0.7/s.
  - Otherwise it drains.
- **What it costs.** At 1.2 s it's **the scare**. Again within 3 minutes, it's **the grab**.
- **Passers-by are safe.** A walk past spends about 0.9 s inside 3.5 studs, and his own approach never counts.
- **Never** in a hunt, at the table, under tier 1, while he's stunned or out of your sight, or for anyone hidden, downed, just revived, safe in a Lantern room, or on another floor.
- **No cover.** Two watchers and his "after you" don't protect you at arm's reach.

**The scare** (`StalkerService:_confrontBegin`), about 2.6 s:
1. He turns on you and lunges a stride towards your face, with a rasp.
2. Every light within 30 studs dies for you alone (a client `blackout`), and your torch dies with them (`PlayerStateService:CutTorch`; it comes back on by itself).
3. In the dark he goes far off, unless someone else is watching, in which case he backs away.
4. The lights come back. Once a run: "[it doesn't like you that close]".

**The grab:** a 0.5 s rasp and reach, then a face-to-face catch. It's a fair down: you were warned once already, so it doesn't count as a cheap down. Then he backs off.

The run checks every tick in every mode except hunts, which closes the gaps while he backs away and while he retreats.

**Studio, seed 61, tier 2:**
- I followed him at about 2 studs, looking at him. He stepped aside ("after you"), I kept on him, and it was the scare: he came in to 1.3 studs, then was 46 studs away.
- I brought him back and did it again within a minute: the grab, and I was Downed.
- The log shows `Crowded {"kind":"scare"}`, then `Crowded {"kind":"grab"}`.

**Not seen yet:** the blackout and the lean-in from the victim's eyes (TC-182).

**New tests:** TC-182 (the scare: frightening?), TC-183 (the grab), TC-184 (following him as he backs away). 495 tests pass.

## WP14 (build `.142`): scares he sets up on purpose

"The Guest needs to deliberately scare people and give people reasons to be afraid." His scares were peeks, stands and tells that happened along the way. Now he also stages them.

**The beat** (`Logic/ScareBeats`, `StalkerService:_beatStart`/`_updateBeat`) comes from a new Director card, `guestBeat` (weight 2, every 90 s at most, Dread 20+, act 2+, a big card, so never in the intro).
- **Who:** the player he has frightened least lately. At least 150 s since their last scare (beats and crowding scares both count), never anyone hidden, just revived, in a Lantern room, or near a down in the last 30 s.
- **What** is picked by what fits where they are:
  - **behind**: he's 4–6 studs behind you, where nobody can see, with a breath at your neck. Turn round and he's there. Seen, he holds 1.5 s with a crack of his neck; then your lights blink and he's gone. Unseen for 8 s, he goes unseen.
  - **hand**: the same, 2.2 studs behind you to one side, his open hand held out at your shoulder (the Usher pose).
  - **dark**: you're looking at him within 25 studs; your lights blink and he's 5–8 studs closer, staring. Only if nobody else is watching him.
- **Never a down.** Only hunts and crowding him do that.
- **F2 `beat [behind|dark|hand]`** stages one on you now.

**Studio, seed 61, tier 2:** `beat behind` while I faced away. 0.8 s later he was 5.1 studs behind me; turning round, there he stood in the doorway, mask lit (the screenshot is the report's). 498 tests pass.

**New test:** TC-185 (each beat: frightening, never unfair?).

## WP15 (build `.143`): his disguise, a friend's look

"Maybe the Guest should shapeshift."

**The owner's decision: a teammate.** Late in a bad night (Dread 60+, act 3+, tier 3, not in a hunt), a new Director card, `disguise`, can show one player who is alone (nobody within 30 studs) a friend standing 25–45 studs off. It isn't the friend.
- **The rules** (`Logic/Disguise`, pure, `Disguise.spec`):
  - The friend he copies is at least 40 studs away and out of the player's sight.
  - He starts unseen by everyone.
  - Twice a night at most, once per player, five minutes apart.
- **How it shows.**
  - It's for that player alone: a `GuestEvent` to their client only. `GuestController` hides his body and welds on a copy of the friend's character. The copy is stripped of everything that isn't the body: no torch or other light, no name over it, no sound, nothing in its hands.
  - The copy stands wrong (`PlayerPose.wrong`): the head tipped far over, the arms hanging dead, one shoulder high, a stiff-kneed walk.
  - On the server his sight points drop to a person's height while disguised, so who-sees-whom stays honest.
  - It's always his real body under the look: the only Guest anyone sees is the real one (the rule in `Logic/Atmosphere` stands).
- **The tells:** no light, no name, silence, the head. And if the real friend has a light on, it's somewhere else.
- **The reveal.** Go within 12 studs while looking and the look falls away. It's him, holding a stare for 1.5 s (he won't step aside), with a rasp. Your torch stutters, the lights round you shudder, and the caption reads "[that isn't them]". From there crowding him (WP13) applies as always.
- **The quiet end.** Otherwise it ends after 45 s, or when the real friend comes within 15 studs of the player, and only while nobody can see him.
- **F2 `disguise [name|self]`** shows it to you now; with `self` the friend is you.

**Studio, seed 61, tier 3, `disguise self`:**
- His body was hidden and a copy of my character stood by the stairs, head tipped over (screenshot).
- I walked at it and at 9 studs it was gone, and there he stood: the tall silhouette, pinpoint eyes.
- After that check he still stepped aside at once, so I added the stare.

504 tests pass.

**New test:** TC-186 (three clients: player A alone, player B far off; does A believe it's B? Do the tells give it away?).

## WP16 (build `.144`): the docs and a shorter controls line

- `docs/TESTING.md`: TC-158 to TC-186, and the header's test count (504 in 77 specs).
- `docs/plans/gameplay-rework.md` section 17, and six additions to the fairness contract (section 12): the intro, collision, the chase, crowding, peeking, beats and the disguise.
- README controls and the F2 list (`beat`, `disguise`), ARCHITECTURE (the torch numbers, the disguise), `CLAUDE.md`.
- The HUD's controls line was cut off at the right edge in my screenshots ("Tab: map · F1: settings" fell off). It's shorter now: "E: use · hold E: drag · R: tool · 1 2 3: slots · F: light · Ctrl: crouch · Shift: run · G: ping · Tab: map · F1: help".
- A red console error from before this session: a character that loads while the house is still being chosen (the search takes about a second) found no spawn (`RunOrchestrator:_onCharacter`). It now waits for `StartRun`, which places everyone once the house is built. Studio, seed 61: a clean console.

## The bot, before and after (seed 61, solo)

F2 `botrun` plays the whole night on the server: start, every lock, the dinner, the door.

| | Before (build `.138`, before the intro) | After (build `.143`) |
| --- | --- | --- |
| Out | 4:41 | 4:27 |
| Steps, failed, no way, stuck | 13, 0, 0, 0 | 13, 0, 0, 0 |
| Waits for him | 13 | 4 |
| Downs, caught | 0, 0 | 0, 0 |
| First door | 0:34 | 0:34 |
| Dinner | 4:33 | 4:19 |
| Hunts | 2 (1 armed at 4:07, overtaken; the final, escaped) and 1 false alarm | 1 (the final, escaped) |
| His time by tier | t1 0:51, t2 1:51, hunting 0:25 (tier score 1.99) | t1 2:53 (tier score 1.00) |
| Sightings | 3 (1.0 a minute) | 8 (2.7 a minute) |
| Scares in the first 10 min | 7 | 5 |

What it says:
- **Nothing broke.** The same 13 steps, no failures, no stuck points, the dinner and the door. The furniture guard, collision, E and the new hiding don't trip the bot's route.
- **The intro does what it should.** The bot is a fast player (a night in four and a half minutes), so its whole run falls inside the five-minute intro: tier 1 throughout, no hunt before the final one, and the hunt armed at the second act waited (`HuntArmed dueIn -75`). More, briefer sightings, far off.
- **Fewer waits for him** (13 to 4): at tier 1 he keeps his distance, so he rarely stands in the bot's way.
- **What the bot can't show.** The new hunts, crowding, the beats and the disguise all start after the intro, at tier 2 or 3, or late in a bad night. A human night (10–20 minutes) reaches them; the bot doesn't. Each was checked in Studio by F2 instead (the WP sections above). A slower bot is a fair next step if the owner wants numbers for those.
- **The intro's moves repeat** (Search 11 times of 18). That's the short list (`Config.Guest.Intro.Moves`) on a fast night. Worth a look if a human's first five minutes feel samey (TC-178).

## Defaults I took (each open to the owner)

- **Crouch:** hold Ctrl, with a setting to make it a toggle; B on a gamepad. A crouch-walk is fully silent.
- **Hard:** a chase runs exactly at your sprint (Hard's extra 4% is for his prowl only). Stamina is unchanged (about 6 s of sprint).
- **A hunt's opening:** he knows the room of the player nearest him, a declared rule cued by the telegraph's hum.
- **Carrying:** your hands work from any slot; your tool stays in its slot. On hiding furniture, E hides you and the doors take hold-click.
- **The piano:** a wrong note costs a soft noise and nothing else. This drops the design doc's discord rule.
- **Collision in the hub too,** with the same give-way rule.
- **By ear (nothing heard yet):** the scream (APM "HORROR SCREAM 10"), the stalking and hunt music (APM "Tension Repeat Drones 29", "Rhythm Drone 34"), the throw's whoosh. Alternatives are listed in `src/shared/Assets.luau`; swap any id there.
- **Nothing uploaded** to the owner's account: every pose, view and look is built in code.

## Waiting on the owner

- **TC-158 to TC-186** in `docs/TESTING.md`. These need two or three clients (Studio's **Test → Clients and Servers**), which MCP can't drive:
  - TC-166 to TC-168: bumping, doorways, the downed;
  - TC-170: getting up;
  - TC-176: the duck-in;
  - TC-182 to TC-184: crowding him;
  - TC-186: the disguise.
- **Not seen in Studio by me:**
  - his head snapping to a peek he notices (TC-177);
  - the blackout from the victim's own eyes;
  - the beats `dark` and `hand` (`behind` was checked);
  - the torch in a fully dark room (it was checked in a corridor and a big room).
- **By ear:** the scream, the two music stems, the whoosh, the piano's keys against the box.
- **The question that matters most:** after a real night, "did it ever feel like it cheated?", especially the sprint-fast chase and the crowding grab.

## The owner's solo playtest of `.145` (build `.146`)

The owner played `.145` alone in Studio and sent five notes. They also asked for two decisions (2026-10-08):
- **Puzzle signposts:** "Lit and heard".
- **A piece flung at you:** "Knocks you back".

Midway, about the locker: "I was thinking that the locker itself would have slits you can see through, I don't want it to just be an overlay on the screen."

(Before this, the owner had seen the fourth slot again. They had joined the **published** game, still build `.130`, through the Roblox app. Nothing here was published: that's theirs to do, from Studio's File → Publish to Roblox.)

### 1. "Doors next to light switches override the door"

**Why:** E's choice was two systems at once.
- My aim ray handled the door when it hit the door.
- Anywhere else (its frame, past reach) E fell back to whichever prompt Roblox was showing. Roblox picks the prompt nearest the middle of the screen, and that was the switch.
- Every prompt also got a marker of its own, so a door by a switch showed two.

**Now: one focus.**
- **What has your focus.** `HandsController:_resolveFocus` takes what your eye ray hits. Failing that, it takes the prompt nearest the middle of your view, within 7°, judged to the nearest point of its part (`Config.Focus.Cone`). A switch is small; a door is not. A note or a place at the table right by your aim (3.5°) wins over the furniture under it.
- **What tap and hold do.** `Logic/FocusActions` (pure, 14 tests) decides:
  - a door or drawer: tap opens or shuts it, hold drags it;
  - furniture with a use of its own (the piano, the washing machine): tap uses it, hold pushes it;
  - a hiding place: tap hides you, hold pushes it;
  - a long prompt (setting the table, the shrine): hold E is that, and the mouse pushes;
  - a small thing: tap picks it up (the music box: hold winds it).
- **How E fires it.** On a keyboard every E prompt gives up its key and always shows (Style Custom: nobody draws it), so E fires the one you look at, never Roblox's pick. Only prompts Roblox is showing are offered, since one it isn't can't be fired.
- **The markers.** One marker has words, the focus's. Other things you could use within 10 studs get a faint ring.
- **Gamepad and touch** keep Roblox's prompts as before.
- **Two traps found in Studio:**
  - Roblox drops instance keys from weak tables while the instance lives on. The list of claimed prompts emptied, and switching to the keyboard claimed nothing. It's a plain table now, emptied as prompts are destroyed.
  - A hiding place's prompt sat on a helper part 2.5 studs off the floor. Close to a locker it was below the screen, so Roblox never showed it and E opened the locker's door instead. It now hangs on an attachment at the top of that part (no part moved).
- **Where else this hit:** in `.145` E on any furniture was a push, so the piano, the washing machine and the dryer could only be pushed. Fixed by the same rules.

**Studio, seeds 61 and 18:**
- E at a door's frame beside the switch opened the door; E at the switch worked the switch, once.
- "Piano · E Play · Hold E Push": E opened the piano.
- "Locker · E Hide · Hold E Push": E hid me.

### 2. "Boltcutters and items like that should be held in the hand to be used"

- **Now:** the crowbar and the bolt cutters work their locks only from your hands. With one out (its slot), look at the boards or the chain and hold the click, or R.
  - The marker says "Hold click Pry". With the tool in another slot it says "2 Take the crowbar".
- **On the server:** `LockService:_workBegin` checks the tool is in your hands and that you're within 7 studs. Each stroke takes the lock's seconds; holding on goes on to the next plank, and letting go loses only the stroke under way.
- **In your hands:** the crowbar levers and the cutters bite (`ViewModelController`); the marker's hairline fills with each stroke.
- **E on them** only tries them: "Take the crowbar in your hands, then hold the click on it."
- **Chests** nailed or chained shut work the same way.
- **The bot** still uses the server path (`how` "work").
- **Studio, seed 61:**
  - R held with the crowbar out took the planks off ("A board screeches and comes away. 2 to go.") and opened the door.
  - The Studio test tool's mouse clicks never reach the game's click binding (they arrive as a Cancel), so the click itself is the owner's to try. It runs the same code as R.

### 3. "It would be cooler if you could see out of locker slits"

**First attempt (dropped):** I hid the doors in front of your eye for you alone and kept the slits drawn on the screen. The owner said no to an overlay.

**Now: real louvres.**
- Wardrobe, cabinet and locker doors have a band of tilted slats at the hiding eye (5.6 studs up): `PropFactory` `ventedLeaf`, used by the locker and `cupboard`.
- From outside you see the dark gaps; from inside you look out between the slats themselves. Nothing is drawn over the screen for these (beds, tables and curtains keep their drawn views).
- The eye sits a full stud behind the doors: Roblox draws nothing within half a stud of the camera, and the old eye point (0.15 behind) made the doors vanish.
- **Gate A re-baselined under the standing OK:** parts 2224, hash 1008106368, on two fresh runs (was 2152, 1995746720).
  - All 72 new parts are the louvred doors: 2 locker doors at +4 each and 8 cupboard doors at +8 each.
- **Studio, seed 61:**
  - From the mudroom locker's eye, slats cross the view with the lit room between them.
  - The cabinet's doors show their louvres from outside.

Also fixed: the hiding hint ran off its box ("...hold SPACE to hold your"). It's now "Right click: peek · SPACE: hold breath · E: leave". And a pushed hiding place's eye point now moves with it (`PushService:_move`).

### 4. "Table got stuck ... couldn't block the door completely" and the burst

**Why it stuck:** pushed furniture may never enter an open door's swing, so a table pushed at an open door stopped short, and the doorway stayed open.

**Now:**
- **Furniture shuts the door ahead of it.** The door gives as far as the piece lets it (`DoorService:Nudge`), and the piece goes on as it does. Pushed into place, the doorway says so: "The doorway's barred."
  - Studio: the kitchen table, pushed at the open kitchen door, swung it shut over about six seconds and ended up barring the doorway.
- **The bangs** (`PushService:Bang`): each blow heavier than the last.
  - The pieces shudder in the doorway and the door jumps in its frame.
  - Anyone within 30 studs feels it: the view shakes, and close by the lights near you blink.
  - The caption reads "[something pounds on the barricade]".
- **The burst** (`PushService:Burst`): the door slams open and each piece flies into the room in an arc, tipping, and lands square.
  - **Where it lands** (`_landing`): only where a pushed piece could stand: clear of walls and furniture, every doorway and his walking points, on its floor, never on anyone. Failing that, back where the house first put it. Failing that, a short throw to where the old shove went.
  - **Anyone in its path** is knocked aside out of it as its leading edge reaches them: a 0.22 s push and a 0.9 s stagger, never a down (the owner's choice).
  - The caption reads "[the door bursts open]".
- **The delay is unchanged:** 3–6 s by weight, ×0.8 in a hunt, never more than 8 s.
- **F2 `barricade burst`** plays three blows and the burst at the nearest barricade, as if he were on its far side.
- **Studio, seed 61:**
  - The kitchen table barring a doorway took three blows, then flew about 13 studs back to its own place in an arc (its top rose 2.3 studs).
  - I stood behind it and was knocked sideways into the wall beside me.

### 5. "The piano puzzle still feels super unintuitive ... no indicator"

**The piano:** E on it now plays it (above), and so does the washing machine. In `.145` it only pushed.

**Puzzles lit and heard** (the owner's choice):
- **The lamp.** A shaded lamp hangs from the ceiling over each puzzle: the piano, the computer, the fuse box, the safe, the dumbwaiter.
  - It's a warm pool of light in a dark room, plus a faint glow round the bulb so it reads from across the room (`Config.PuzzleLamp`).
  - Solved, its lamp goes out with a click, so the lamps still lit are the puzzles left.
- **The sound.** The first time anyone comes into its room within 18 studs, it makes a sound of its own, captioned:
  - "[a piano key sounds, on its own]"
  - "[a computer beeps]"
  - "[a fuse box crackles]"
  - "[a click, from a safe's dial]"
  - "[the dumbwaiter's rope creaks]"

  `Lib/Sfx.play` takes an optional caption for this.
- **Studio, seed 18:** walking into the music room gave the piano's caption. The piano stood in its own light: the wall behind, the sheet and the key stickers lit, the bulb glowing.

### The bot (seed 61, solo, after everything above)

Out at 4:55: the same 13 steps, 0 failed, 0 stuck points, 8 waits for him, 0 downs. The boarded door was opened through the new work path ("toolDoor ... ok in 14.6s"). No console errors.

### Not checked in Studio

- **By ear:** the bangs and the burst. The flight was checked by numbers, not watched in motion: the Studio test tool is too slow to film a half-second flight.
- **By hand:** the click on the boards (above).
- **Two players:**
  - a second player watching a burst from the far side;
  - a friend seeing the louvres from outside while someone hides.

**New tests:** TC-187 to TC-196.

## The owner's playtest of `.146`: wardrobes and lockers you walk into (build `.147`)

The owner tried `.146` (2026-10-09):
- "You weren't able to hide in closets with shelves before, I'm not the biggest fan of that option now ... I liked the old closet design more that you couldn't hide in because there are shelves."
- "I tested the wardrobe and I'm straight up stuck, can't get out."
- "I want wardrobes and lockers that you can open or slide the door and physically step into and close it."
- "Make sure the slits don't give an unfair line of sight to the guest also, the guest has to find them legitimately."

### Why you got stuck

Both traps were in the walk-in closets (12 of the 28 hiding places on seed 61 are corridor closets):
- **Hands off while hidden.** Since `.137` your hands ignored everything while you were hidden, and in a closet you count as hidden while you stand inside with its doors shut. So once shut in, E did nothing and the doors couldn't be opened from inside. (R2c's "you can still act in there" was only true on the server.)
- **The overlapping doors.** From inside, a closet's two sliding doors overlap: the one on the inner track hides the other. Once you'd opened the outer one, you could never reach it again to pull it shut.

Hiding by E (a bed, a table, a curtain) was fine: E got me out in Studio.

### Now

**Wardrobes and lockers you walk into** (`Data/Props` `physical`, like the closet):
- Open a door with E, step in, turn round and pull it shut with E on the door. Shut in with your light off, you're hidden, and your torch clicks off as you shut yourself in.
- You look out through the louvres with your own eyes, free to look round, the room between the slats. No overlay and no camera tricks.
- The louvres sit at a standing eye's height: measured at 4.53 studs above the floor. `.146`'s were at 5.6, above your eyes.
  - A wardrobe's two doors have 9 slats over 2 studs each.
  - A locker's door has 6 slats over 1.4 studs.
- E on the door in front gets you out; looking out through the slats counts as looking at the door. The HUD says "SPACE: hold breath · E on the door: get out".
- **Your torch on inside** shows through the slats: you're not hidden ("Your light shows through the slats."), and he notices if he's looking at it.
- **Your eye keeps 0.85 studs off the doors** (`FeelController:_standoff`). First person puts the camera half a stud ahead of your body, and pressed to the door the louvres would vanish.
- **No pushing** a wardrobe or a locker with someone standing in it (`HidingService:Within`).
- The breath bar and the hint no longer sit under the hotbar.

**Closets:** E on either sliding door shuts whichever one is open, and both say "Close" while one is open (`FurnitureService:_partnerOpen`, `_label`).

**Cabinets with shelves** are no longer hiding places, and their plain doors are back.
- Five mansion rooms had only a cabinet to hide in, and every room keeps somewhere to hide (a level-design rule, `RoomPurpose.spec`):
  - the dining room gets floor-length drapes;
  - the den gets a desk;
  - the pantry, the wine cellar and the cold store get a **tall cupboard** (new, `TallCupboard`): a wooden walk-in for one, built like the locker, louvred.
- The old house's foyer gets a tall cupboard too, so the old generator's houses stay exactly the same (`Golden.spec`).
- The house numbers over 40 houses each, for 2 and for 4 players, are unchanged within noise (hiding reach, dead ends, rooms with a purpose, the score).

**His sight** (the owner's last note):
- **The problem.** The slats aren't solid, and his eyes (`Stalker/Perception`) look past anything that isn't. So through a louvre band he'd have seen straight in.
- **The fix.** Each band now has a pane nobody sees, solid like the door. Your eyes and the room's light pass through it; his sight stops at it.
- **Checked in Studio:** with him 5 studs in front of a shut wardrobe, all three of his sight lines to me hit the pane. With the pane taken out, they reached me.
- **What he can still go on**, all legitimate:
  - he can't see you at all while you're hidden (as before);
  - if he saw you get in within 2 s of the doors shutting, he knows where you went (`Config.Hide.SeenGoingIn`);
  - a light on in there, if he's looking at the place;
  - your breathing when he's close (as before);
  - the squad's habits when he searches.

  His search opens the doors, as it always did for closets.

**Gate A re-baselined under the standing OK:** parts 2235, hash 1016524583, the same on two fresh runs (was 2224, 1008106368). The changes in the old house: the cabinets' doors are plain again, the wardrobes' and lockers' louvres are bigger and have their panes, and the foyer's new tall cupboard.

### Studio, seeds 61 and 1

- **The mudroom locker:**
  - E opened it, and I walked in (no teleport).
  - E on the open door shut it: hidden, torch off.
  - The view: the room between the slats.
  - Torch on: "Your light shows through the slats", not hidden. Off: hidden again.
  - E on the door: open, and I walked out.
- **A corridor closet:**
  - I opened the right door and walked in.
  - From inside, E on the left door (which hid the right one) shut the right one: hidden.
  - E on the door in front: open, and out.
- **The storeroom wardrobe** (seed 1):
  - From outside, the louvred doors with the handles below them.
  - In and shut, the view through both doors' louvres.
  - E looking straight out offered "Open".
- **His sight:** with him 5 studs in front of the shut wardrobe and my torch on, his sight was blocked by the pane, and he noticed the glow ("PeekNoticed").
- **Leaving a place hidden in by E** (the dining room's cabinet, before it stopped being one): fine.
- **The bot's night on seed 61:** out at 4:41, the same 13 steps, 0 failed, 0 stuck points, 0 downs, 10 waits for him (8 before). No console errors.

### Not checked in Studio

- **His search on a hidden player:** opening a wardrobe or a locker on someone inside. It's the closet's path, but it needs a hunt to find you.
- **Two players:**
  - two people in one wardrobe;
  - a friend opening the door on you;
  - a friend outside looking at the slats while you're in there.
- **The click:** only E and keys can be driven from the Studio test tool.

**New tests:** TC-197 to TC-201.
