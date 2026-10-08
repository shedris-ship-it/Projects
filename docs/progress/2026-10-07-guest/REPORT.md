# The Guest rework, 2026-10-07: a mind of his own, his house, his face

Branch `claude/overnight-foundation` (continued), from `688aba6` (build `2026-10-06.121`), builds `2026-10-06.122` to `.124`. The plan: `C:\Users\Owner\.claude\plans\i-want-to-rework-fuzzy-cook.md`.

**What you asked for:** a Guest more menacing and scary, still fair, and more unpredictable.

**Your choices (2026-10-06):**
- the mask over the dark
- keys and secret ways
- frozen but alive
- one pass, the AI first

**What you added while watching (2026-10-07):**
- round, lidless eyes
- "make him extremely scary, don't hold back", kept within the Moderate rating you chose
- the eyes as bare dots, not a glow

**The rule for everything below:** unpredictable in when, where and how; legible in his rules. Every new behaviour has a tell, a counter and a Dossier line. None of the fairness gates changed (the observation rule, tells before a down, telegraphed hunts, no popping in or out, no traps).

## What was done

### WP0. His numbers
`Logic/RunStats` now counts, for F2 `summary`, the overlay's fifth line and the Dossier:
- **parked time:** between hunts, standing still beside a still player
- **cheap downs:** a catch with no sign of him (a look at him, a tell, his steps heard) in the 3 s before it; contact lunges and searched hiding places don't count
- moves by kind and repeats in a row, his temperament and moods, and "things he did" (making way, keys, host actions, losing you)

The "before" column below is the loop pass's bot runs at build .121/.117. Parked time and cheap downs weren't measured then.

### WP1. Moods and a temperament each night
- **The temperament** (`Data/Temperaments`): Patient, Restless, Playful or Hungry. One is drawn per run from the seed.
- **The moods** (`Logic/GuestMood`): Curious, Stalking, Host, Playful, Patient, Irritated. A mood lasts 1–3 minutes, and what you do shifts it:
  - a stun or a barricade he had to shove makes him Irritated, and so do two lures that came to nothing
  - a stare-down makes him Patient or Irritated
  - a taken heirloom sets him Stalking
  - a catch makes him the Host again
  - 90 s seeing nobody makes him Curious or Playful
- **Weights:** the temperament and mood weights fold into both menus, his moves and his hunt tactics.
- **The limit:** his creep speed leans 0.8–1.2× but never past the tier's fastest. No mood touches a fairness gate.
- **The Dossier** opens with "Tonight he was patient. He waited where you were going to be."
- **F2:** `guest mood [id|off]`, `guest temperament [id]`.

### WP2. After you (no more parking)
- **The bot's main finding:** between hunts he stood at arm's length and held, and walking into him was the contact lunge. The bot had to wait for him 12–39 times a run.
- **What he does now:** walk his way, or stand beside him 6 s, and he steps aside as far as the walls let him (`Stalk` `MakeWay`). He bows, holds out an open hand ("[it steps aside, and holds out a hand: after you]" the first two times), and never lunges at you while he does.
- **The contact lunge** is now for running at him: a walk or a winded stagger is not rushing him.
- **A presence budget** (`StalkRules.parkBudget`): at most 12 s within 8 studs of one player in any minute. When it's spent he backs out of sight.
- **The bot** walks on past when he ushers. That's what a player who has learnt the promise does.

### WP3. New ways between hunts
- **FingersPeek:** his long fingers curl round the frame first. From tier 2 his face follows them out while you look.
- **HallwayStand:** at the far end of your corridor, facing you; closer each time you look back (twice at most, never nearer than 12 studs).
- **BehindTheDoor:** behind the shut door you're heading for. You see his feet's shadow under it, sometimes hear three slow knocks, and hear a creak if you come close. At tier 3 those were your warning.
- **HostAction:** he sets the radio, the television or the record player going, puts out the light of the room he's in, or eases a door ajar. These are honest clues: a radio he started is no lure to him.
- **MimicVoice** (squads only): a friend's line from at least a minute ago, spoken from behind a door in their voice. It's filtered again for the listener (`ChatService:RecentLine`, `SpeakAs`).
- **Tier-1 recoils vary** by mood: the yank, a slow withdrawal still staring, or a sudden duck.
- **Fixed on the way:** an old bug where, unseen between tier-1 appearances, he restarted Search every tick and never moved (55 "repeats" in one run, now 0).

### WP4. Hunts in phases (`Logic/HuntPhases`)
- **Prowl:** a fast walk (0.6 of his run), doors slammed open, a stop to listen every 6–10 s.
- **Chase:** when he sees you. A "spotted" cue: a breathy giggle, and "[it sees you]" the first times. Then his run.
- **Lost:** he goes back to where he last saw you, stands listening (a long sniff), then searches the nearest hiding places.
- **Kinds,** chosen by his mood: prowl, sweep (the rooms you use, the hiding places you like) and silent (no slams, a walk until he sees you).
- After 30 s of seeing nobody he widens his options (KillLights, MimicKnock, FakePing).
- Unchanged: the telegraph, the length, the hold chain, the catch rules.

### WP5. His keys and secret ways (`Logic/GuestKeys`)
- **What he can pass:** a still-locked key, pocket, double or padlock door, or a servants' passage's hidden door.
- **How it plays:**
  - You hear his keys first: at least 1.5 s, 2.5 s between hunts.
  - He only passes with nobody within 20 studs and nobody looking at the door; otherwise he turns back and goes another way.
  - While it's open for him, the doorway stays barred to players (a blocker in the Door collision group).
  - It locks again behind him.
  - A hidden door he comes out of stays found: he showed you the passage. One leading into a wing not yet opened shuts behind him.
- **What stops him:** boards, chains, crank shutters, power doors and the dinner's seal, always.
- **Before and after:** before, a locked door was a wall at your back. Now it's a door he might come through, and you'll hear him first.

### WP6. Stairs and stuck points
The loop pass's wedge on seed 1's Back Stairs (15 nudges) didn't happen again in this pass. The seed 1 bot run had 0 nudges and 0 stuck points. Seed 21's run had 20 nudges, but those were the bot's own walker in a four-player house during hunts, not him. I didn't change the walker for it. F2 `navtest fast` on seed 1 (build .127, keys and passages on):
- **locked as dealt:** 21 legs, 0 failed, 0 falls, 0 phases, 0 stuck. The 8 "no way" legs are rooms behind locks his keys don't open (a crank shutter, boards).
- **with `unlock all`:** 21 legs, all clean, the Back Stairs' cellar flight included (13.9 s). Same as the loop pass.

### WP7. The look: the mask over the dark
Pictures are in this folder.
- **The head is black, under a porcelain mask.** The mask is smaller than the head and set low, so the dark dome and the mask's rim show (`Lib/GuestFace`). The first try read as an egg again (`01_mask_first_try.jpg`); the smaller mask fixed it (`02_mask_calm.jpg`).
- **Round, lidless eyes** (your idea, `04_round_eyes.jpg`):
  - holes onto the black, each with a pin of light that follows you
  - in the dark, two pinpoints whenever he faces you, brighter at Fraying and Breaking, bright in your torch (`05_eyes_in_the_dark.jpg`)
  - I tried a faint glow halo round them and took it out at your word: the bare dots are scarier
- **Fraying:** the mouth opens on small uneven teeth, with hairline crazing in the glaze.
- **Breaking:** the mask has cracked and slipped askew, and pieces have come away to the black beneath. There's no blood (`03_mask_breaking.jpg`).
- **The body:** a longer neck carried forward, a slight hunch, narrow sloping shoulders, slimmer sleeves, coat tails, sleeves a little short so bony wrists show.
- **The motion:**
  - stop-motion stutters in your torch, and at Breaking always
  - the head snaps to your light before the body turns
  - **frozen but alive:** held, not a stud of movement, but the head tips to about 70°, the fingers drum, the smile widens, the neck cracks past 5 s, and a long breath out when let go
  - unfolding to full height past a door frame
  - from Fraying, up close, the mouth hangs open
  - mood idles: Curious tips his head, Stalking hangs low, Playful nods, Patient doesn't breathe, Irritated twitches
  - new poses: Usher, FingersPeek, Duck, Listen
- **The catch** uses the new mask automatically. It now stares dead into you, shudders harder and jerks its head over mid-hold.

### WP8. His sounds
All licensed Pro Sound Effects library audio, picked by description. **You haven't heard any of it yet**; swap ids in `Assets.Sounds` by ear.

| Key | Sound | When |
| --- | --- | --- |
| `GuestRasp` | breathy possessed giggle | he spots you |
| `GuestGiggle` | breathy giggle | a Playful Guest, now and then |
| `GuestSniff` | sniff | he's lost you |
| `GuestKeys` | key jingle | at a locked door |
| `GuestCrack` | dry bone crack | an Irritated Guest; his neck tipping too far |
| `GuestExhale` | breath out, pitched down | let go after a long stare |

No hum for the Host mood: nothing suitable turned up.

### After the report (build `.125` and `.126`, the owner's answers)
- **The map on Tab again.** Roblox's player list binds Tab ahead of any game action, so it's switched off now (`ActionController`). I couldn't press Tab from my tools (Roblox reserves it), so check it yourself.
- **The cursor on the puzzle screens** (and the map, notes, settings). A Modal button frees the mouse, but Roblox still reports it as locked to the centre, so the cursor rule hid it. `Ui.modal` keeps a registry, and `Ui.modalOpen` tells the cursor rule (`FocusMarkers`) when a menu that frees the mouse is showing. Checked: the cursor shows on the terminal and the map, and hides again when they close.
- **The voice trick is on Hard only** (`Config.Difficulty.Hard.MimicVoice`).
- **The catch picks its own style** (`Config.Guest.Catch` "auto", `StalkerService:_catchStyle`):
  - rush when you were looking at him, or when he ran you down in a lit chase
  - quiet when he took you from behind, in the dark, or out of a hiding place
- **The textured mask** (uploaded with your OK: calm `133187355603598`, worn `118770058549049`): a glaze decal under the geometry features (`06_textured_calm.jpg`, `07_textured_breaking.jpg`). On the way:
  - the eye holes, the mouth's inside and the broken pieces became black Neon (true voids even in your torch)
  - the eye rims went near-black
  - the torch shine became a pinpoint (the larger dot stays for the dark)
  - the teeth became thinner, yellowed, some missing
  - the broken-away pieces became narrow cracks instead of a black bar
- **The mask at its worst** (your note: "even more cracked and fucked up at his more aggressive forms"): three glazes now.
  - **Calm:** ivory, patchy crazing.
  - **Fraying:** crazing everywhere, a first fracture over the brow, flakes of glaze gone to the grey bisque, tear-tracks.
  - **Breaking:** thick fractures from two blows, at the brow and the jaw (where the mask's geometry pieces are gone), with webs round them, angular holes to the black, flaked glaze, heavy stains.
  - Uploaded: calm `118378389246082`, worn `82781140864416`, broken `134283397249825`. Picture: `08_textured_broken.jpg`.
- **The smile is a deep crescent** (your note: "not curved enough, makes him look like a muppet"). It's low in the middle, and the corners keep climbing up the cheeks towards the eyes instead of levelling off round them (`GuestPose.mouth`). The before and after are `06_textured_calm.jpg` and `07_textured_breaking.jpg` against `04_round_eyes.jpg`.

### The body (build `.128`, your note: "his body doesn't really look very good")
You chose the code rebuild (no uploads). What made him look like a puppet (`09_body_before_front.jpg`, `10_body_before_side.jpg`, `11_hands_before.jpg`):
- a pale bent neck with a ring round it, like a bendy straw
- arms like flat planks with lumps on top for shoulders
- the suit's Fabric material glittered like granite in the torch
- a rectangle for a torso and posts for legs
- hands like two shrimps: a thick oval palm (it was built thick and narrow, the wrong way round) and needle fingers fanning out

What he is now (`13_body_after_front.jpg` at the game's light; `14_body_after_side_lit.jpg`, `15_walk_lit.jpg`, `16_usher_lit.jpg` and `17_lunge_lit.jpg` under a test lamp by the camera, to show the shapes):
- **A long black overcoat**, matte (a new `CoatWool` material from textures already uploaded: the carpet's pile, small; smooth plastic shone like latex). A chest that narrows to the waist, round shoulders, a stoop, three buttons, a grubby shirt V and tie.
- **A black neck in a turned-up collar**, so the mask floats on the dark.
- **The coat flares as he walks.** Its skirt hangs on joints of its own that follow each thigh 60% of the way (`Config.Guest.CoatSwing`, `GuestController`); fully on the thighs it split into two wide trouser legs.
- **Bony hands** (`12_hands_after.jpg`): flat palms, finger bones as cylinders with knuckles. In the clasp the hands turn their backs to you and the fingers fold over each other (`GuestPose` clasp).
- Tapering sleeves and shins, a knob at each wrist, dress shoes with a heel and a rounded toe.

Not checked: how the coat and hands look in a real chase at speed, and whether he still reads at 30 studs against a lit doorway in every room (TC-153).

## Evidence

**Checks:** every commit passed the five (`stylua`, `lune run tests/run`, `lune run tests/compile`, `selene` 0/0, `rojo build` into the scratchpad, since your Studio had the repo's `Consensus.rbxlx` open). Tests went from 445 to **464**: GuestMood, HuntPhases and GuestKeys specs, plus Stalk.spec (after you, the presence budget, the creep scale) and RunStats.spec (his numbers).

**The bot** (F2 `botrun`, the yardstick):

| Seed (squad) | Before (loop pass) | After (this pass) |
| --- | --- | --- |
| 61 (1) | build .121: out 5:06, **12 waits for him**, 0 stuck, 0 downs | build .122 (WP0–2): out 4:37, **0 waits**, 0 stuck, 0 nudges, 1 down (a hunt's catch, crawled out of), 0 cheap downs, 3 made way. Hungry |
| 1 (1) | build .121: out 6:32, **14 waits**, 15 nudges (the Back Stairs wedge), 2 downs | build .122 (+WP3): out 3:41, **1 wait**, 0 stuck, **0 nudges**, 1 down, 0 cheap downs; 8 kinds of move, 0 repeats. Hungry |
| 165547210 (1) | build .117: out 7:22, **39 waits**, 2 downs | build .122 (+WP4–5): out 4:47, **1 wait**, 0 stuck, 1 down, 0 cheap downs; 3 key passes (hidden passages), 1 passage revealed, a silent hunt, lost you once. Playful |
| 21 (4, one player) | build .121: out 9:00, **37 waits**, 1 down | build .123 (+ the fixes below): **out**, 0 downs, **3 waits**, 0 cheap downs; 12 kinds of move; 3 made way; he put out two lights by their switches and eased a door ajar; four hunts (a silent one, an Irritated prowl), all survived. The run took 13:11, about five minutes of it the bot standing at a pried fridge it never opened (a bot fault, fixed in `BotService._piece`; I opened the furniture with one F2 to finish the measurement). An earlier try at this seed was lost at 3:52: see "Fixed on the way" |

The bot knows the plan and solves puzzles as if played, so its times are a floor. The yardstick is the change between builds.

**Studio:** every package was played with a clean console. Screenshots are in this folder.

**Fixed on the way (found by the bot):**
- A chase's grace moment asked for an unseen player's position (`stalker update failed`).
- With the only player down, his Search had no target and every tick failed ("table index is nil" in `Stalk:_belief`), so he froze while they bled out. On seed 21's first try the bot's crawl to the light failed and it was Lost 9 s after its first down, with him frozen nearby. Fixed in build .124 (Search and the belief map guard against no target).
- The bot pried a nailed fridge but never opened its door, so the key inside was out of reach (`BotService._piece` now opens what it unlocked, as a player would).

**A note on the numbers:** "repeats" counts the same move twice in a row. His Search runs room after room while he's unseen at tier 1, so it adds most of them. That's searching, not churn: I checked him walking from room to room.

## Unrequested changes (within your standing OK)
- **The contact lunge now needs running at him.** Walking his way makes him step aside instead. This was part of "after you" and keeps its promise.
- **The tier-1 Search bug** (restarted every tick, never moved) is fixed.
- **The bot walks past** when he ushers (`BotService`).
- **His creep** obeys the mood scale but never exceeds the tier's fastest (`StalkRules.creepSpeed` `scale`).

## Not verified, and what to watch for in play
- **Anything by ear:** every new sound, the Host's silence, how loud the giggle is.
- **Two clients:** MimicVoice (TC-144); after-you with a squad; the door shadow seen from both sides; your beam's stutter seen only by you.
- **"Closer each time you look back"** in HallwayStand was checked later (seed 61, Hallway 7): he stood at the far end 37 studs off; one look and one look away, and he was 21 studs off. After that the move handed over to a creep from behind rather than waiting for a second look.
- **Key passes:** seen in telemetry on seed 165547210, three of them, all hidden passages. A key-door pass and its relock haven't been watched by eye.
- **Whether the new ways come up often enough.** They're all in the menu, weighted by mood: in the bot's runs FingersPeek and HostAction appeared, MakeWay often.
- **Whether a squad of four finds him too much,** with keys and hunts that track you down.

## Open questions for you
1. **The sounds:** listen to the giggle, the sniff, the keys and the crack (TC-145 to TC-150), and tell me which to swap.
2. **The Host mood is silent.** Do you want a hummed tune? I couldn't find a licensed one; it may need recording, which is yours to decide.
3. **MimicVoice uses your squad's own typed lines.** It's on for squads. Keep it, or Hard only?
4. **The catch default** (`Config.Guest.Catch`), now that the face is the mask: rush or quiet?
5. **A painted mask texture** (crazing, faded paint) would need an upload to your account. The geometry mask may be enough; your call.

## Git
Branch **`claude/overnight-foundation`**.

```
8ac5eb6 The Guest rework: a mind of his own, his house, his face (build .122)
1b01437 The Guest, scarier: lidless eyes, his sounds (build .123)
        The Guest rework documented; no target, no freeze; the bot opens what it pries (build .124)
        The map on Tab, the cursor on puzzles, the voice on Hard, the catch by circumstance (build .125)
        The textured mask; true voids; the smile a deep crescent (build .126)
        The mask at its worst: broken and worn glazes (build .127)
        His body: a long black coat, a black neck, bony hands folded (build .128)
```

```powershell
# in A:\111- Projects\Github\Projects
git fetch
git checkout claude/overnight-foundation
git pull
```
