# The first squad playtest: the fixes (2026-10-08)

Branch `claude/overnight-foundation`, builds `2026-10-08.131` to `.144`, from `2026-10-06.130`.

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
