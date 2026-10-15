# The visual rework, V8: the Guest's takedown and the three cutscenes (builds `2026-10-15.197` and `.198`)

The owner: "Lets do V8, before we start, as part of this I want to add the guest execution/down animation ... brutal and scary but stay in the moderate rating? I kinda liked how Threshold on roblox did it, the camera goes into 3rd person and you watch your character get mauled, the camera would have to be smart enough to avoid going somewhere you cant see the animation happen". Their picks: **the taste** on a down, **dragged away** when Lost, **light blood from Breaking**. Along the way: "Make sure the animations look alive and fluid ... when you finish up I want it to be when you feel confident about the animations and you believe I'll love them".

This replaces the catch's jumpscare, which was a placeholder since V5, and finishes the plan's V8.

## The takedown (`Logic/Takedown`, `Controllers/TakedownController`, `StalkerService:_takedown`)

One pure timeline, sampled on every client: each draws both bodies from it, the victim in the third person, everyone else where it happens. The server stages it (where, which opening, which way the slam and the drag go) and holds both bodies still for it.

- **The taste (a down, about 4 s).** His hand over your face, and you're lifted off your feet at arm's length, hands tearing at his wrist, legs kicking. He steps in to look you over: his head tips, three sniffs. The grin tears open, he shoves your head aside, coils and lunges at your shoulder, and your screen smash-cuts to black on the crunch. You come to on the floor, him standing over you wiping his mouth. Openings by how he caught you: face to face, from behind (yanked back and turned round), or hauled out of a hiding place by the collar.
- **The taking (Lost), the owner's own design.** After the first slam read as "a little mild" ("doesn't really read like an overwhelming force that makes you feel helpless"), the owner wrote: "he could bend down and grab you by the ankle and slam you to the ground and then drag you away, slamming would like ragdoll you on the ground with a heavy slam". So:
  1. He drops into a crouch and his hand clamps your ankle.
  2. One heave tears your feet from under you: you hang upside down from his raised hand, your arms reaching for the floor, twisting, while he turns to where you'll go down.
  3. He swings you up over his head, his other hand on your shin, and drives you down flat with his whole weight, down on one knee. Then a hit-stop (everything holds for a moment), a heavy jolt with the lens dropping, dust off the boards, your scream cut off by the floor, a thud on a deeper thud with a crack under them, a ringing only you hear, and your sight dimming for a moment.
  4. He stays bent over you a beat, then stands, turns his back, hauls you up by the leg and runs. You're dragged hips-up, shoulders on the boards, by his own way through the house to a dark room, too fast to chase. The body fades at the end and your Echo stands up there.
  `taking-sheet.jpg` shows it frame by frame from live play.
- **Alive, not keyframed.** Every move eases, snaps overshoot and settle, hits ring down. The taking's free limbs are damped pendulums worked out once per takedown, so they're flung on the swing, trail up through the slam and slap down on it. Arms are held to a shoulder's range, and every arm move goes by where the hand goes (never the long way round a turn). His feet are planted by leg IK through the crouch and the steps. A frame-by-frame analyzer (`tools/_takedown.luau`, scratch) found no pops: the biggest joint steps are at the grab and the impact, where a jolt is meant.
- **The camera (`Logic/ShotPicker`, `Controllers/CinemaController`).** Letterboxed, third person, never standing where it can't see: candidate spots are swept with a ball through anything solid, bodies count as blockers, faces are only filmed from the front, and the shot is re-checked five times a second and recut if something comes between. The taking is shot low and side on (wide lens, him towering): side on to how you're torn off your feet, then cut as you hang to side on to the slam. Then a low shot off his right side as you're dragged off.
- **His slam goes where there's room.** The server tries the slam's way against the room (his chest out to where your body swings and lands, and floor under where it lands). It prefers the way that lets him turn round and drag you down the route.
- **Moderate.** The brutality is force, sound, his face and the cut. No hand round the throat, no wound, nothing near the camera.
- **Light blood from Breaking (the owner's pick).** At Breaking, three to six small, dark drops on the floor where you fell: by your shoulder where he bit, or where your head hit the floor. They read as dark spots, only from a distance. Every client places the same ones.

## The three cutscenes (`Logic/Cutscene`, `Controllers/CutsceneController`)

Short, letterboxed, through the same cinema. Any key or button skips the rest of one, and **Skip cutscenes** in Settings skips them all. Never in a hunt, nor while you're being taken down. Your movement is paused while one plays.

| Cutscene | When | What you see |
| --- | --- | --- |
| The door locks behind you (5.4 s) | the run starts (`RunOrchestrator`) | From the dark drive, the front door standing open on the lit hall, under the night's title card; it swings shut on its own, faster and faster, and slams. Inside, close on the lock: a latch, a bolt. Then high over the door, you small in the hall facing the grand stair. `1_arrival_door_title.jpg`, `2_arrival_hall.jpg` |
| He takes his seat (3.3 s) | the dinner is served (`FinaleService:Serve`) | Every light in the house goes out. From the foot of the table, along it to the empty chair at its head; then on him, seated, his porcelain mask lit from below by the candles, his long hands on the cloth. Over before the final hunt is called (it begins with its 5-second telegraph). `3_dinner_seated.jpg` |
| The last shot (3.6 s) | you're out (`RunOrchestrator:_onExtracted`) | From the drive, low, on the open front door: you burst out and run past the lens into the storm, the house standing there with its door open, lit by lightning and thunder; then black, and the hub. `4_escape_last_shot.jpg` |

What went with them:

- **His chair at the head of the table.** It stands empty all night and he sits in it at the dinner: a new seated pose, `Sit`, too tall for the chair, his knees up under the edge. He's shown to everyone while he sits, like a takedown.
- **The escape keeps you 3.6 s before the hub** (`Config.Cinema.EscapeSeconds`): you're Extracted, so he has no business with you. The squad's end waits for anyone still on their way out.
- **The shots' cameras** try their own spot, then the far side, then higher, before coming in towards what they film (`Cutscene.variants`). They never hide the thing they're of (the front door, the laid table and his chair; `CinemaController:FadeFor`'s `keep`).
- **The dinner's key light:** the candles' warm light on his face, on each client for the shot. Decorative light never counts as lit for the rules.
- **The HUD now stands down while the cinema has the camera** (`UI/Hud`). It had been switching itself back on every frame, so the objective slip peeked under the top bar in every takedown and cutscene.

## Checks

- `lune run tests/run`: 657 pass, including the new specs Takedown (8), ShotPicker (8) and Cutscene (5), and the Guest spec's joint limits with the seated pose. `tests/compile`, `selene` (0/0) and `rojo build` all pass.
- Gate A unchanged: parts 2456, hash 116728396 (his chair is run content).
- In Studio, seed 7 for one player:
  - every beat of the taste and the taking held still and filmed;
  - a full live taking run through to the Echo;
  - the arrival live at the start of a run;
  - the dinner served (F2 `resolve`) with him seated;
  - a real escape out of the front door into the last shot, then the hub;
  - clean consoles on both sides.
  The F2 commands: `takedown taste|taking front|behind|hiding [hold]`, `cutscene arrival|dinner|escape`, and the attributes `DebugTakedownAt` / `DebugCutsceneAt` to hold a moment for stills.

## Not checked

- **By ear:** the takedown's sounds (the bite, the crunch, the screams, the drag, the ringing), the cutscenes' slam, lock and thunder. All are library sounds in `Assets.luau`; swap any that sound wrong.
- **With two or more clients:** a teammate watching a takedown from their own view, the dinner for the whole squad, one player's last shot while the others play on.
- By eye, in stills only: the from-behind and out-of-a-hiding-place versions of the taking (checked by the analyzer), the lock shot after its fix, the dust burst and the lightning in the last shot.
- A real catch during an ordinary hunt (they were triggered with F2 or caught by the final hunt).
- The Settings form with its new row, by eye (the row's text fits its column).
- A phone.

## Not done

- One of the picks' openings, "pinned to the wall when you pester him", wasn't built; the taste has three openings (face to face, from behind, out of a hiding place).
