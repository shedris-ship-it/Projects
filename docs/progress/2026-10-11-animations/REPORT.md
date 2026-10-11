# The Guest's animations (2026-10-11)

Branch `claude/overnight-foundation`, build `2026-10-11.153`, from `2026-10-10.152`.

The second squad playtest asked for smoother movement, ducking under doorways and a hand on the frame when he peeks (`docs/progress/2026-10-10-squad2/REPORT.md`). The owner chose to do it as its own pass, to be looked over and then shown: "make them look really good ... look at them yourself and when you feel confident with it I want you to show me".

## The owner's choices (2026-10-11)

| Question | Choice |
| --- | --- |
| The torch stutter (he moved in stop-motion jerks the whole time your beam was on him) | **Rarer and deliberate.** Smooth by default. A burst of jerks for about half a second when your beam first lands on him, re-armed once it has been off him 2 s. At Breaking, a burst every 4–8 s, lit or not |
| How he walks | **Heavy and lurching.** A slow, weighty, slightly uneven gait, too tall for his own legs |
| (While watching) "strange movement with the bottom of his coat when he ducks under doorframes" | Fixed: below |

## What Studio showed on build `.152`

- **He skated.** Over 3.5 s of walking, a foot meant to be on the floor still slid at 2.7 studs/s, half his speed. The legs were sine pendulums with no tie to the floor.
- **Stiff.** No bob, sway or counter-motion. Moving sideways or turning on the spot, the legs didn't step.
- **Doorways.** He's 8.42 tall and an opening is 8. The stoop came too late and lowered his head about half a stud, so his head met the lintel.
- **Peeks.** The hand on the jamb was a fixed arm pose that never found the frame.
- **Pops** when one pose changed to the next.

## What changed

**Feet that stay planted** (`Logic/GuestGait`, new). A foot carrying him stays where it landed, in the world, so it can't slide. The other swings, heel to toe, to where it will be under him halfway through its next stance. A clock sets the rhythm from his speed. The step goes wherever he's going, so backing away and moving sideways are real steps. Standing, a foot that has drifted (he turned, leaned or stopped mid-stride) takes a step of its own, one foot at a time.
- Walk: 3-stud steps, each foot down 62% of the time (heavy). The right side drags a little: a longer stance, a shorter step and a lower lift (the limp).
- Run: 4.8-stud steps and a moment in the air every stride. Creep: short careful steps. Backing away: shorter, wider steps.
- Feet land on the floor under them (a raycast), so stairs work.

**The body** (`Logic/GuestPose`, `Logic/Kinematics` new):
- Joints follow critically damped springs, so nothing pops. The snaps (the lunge, the duck, the head snapping to your light) stay instant.
- The legs reach the gait's feet by two-bone IK. The lunge, stagger, duck and crawl keep their own leg poses and blend in and out, and the feet are planted wherever those left them.
- **The lurch:** his hips drop as far as the legs carrying him need to reach their feet (the bob, deeper with a longer stride), sway over the foot that carries him, and dip on the swinging side. The upper body rides it: a lurch forward as the hips fall, the shoulders rolling back. His head stays on you throughout.

**Doorways.** The client knows every doorway's opening from its seam panels. He stoops while his head is coming up to a frame, under it or just through it (faster at speed): hips down through bent knees, a forward bend, shoulders rolled, the head bowed with the face still up at you. After the frame he unfolds over half a second. Measured in Studio over 30 s of walking through one doorway and back: his head top stayed at 6.96–7.27 under the 8-stud frame.

**The coat** (the owner's note). Each side of the skirt followed its thigh one for one, so as the knees bent for a frame the skirt swung up. Now it follows a third of the thigh's swing, never more than 0.16 back or 0.3 forward, hangs level however his hips tip, and lags like heavy cloth (a spring).

**Peeking with his hand on the frame.**
- The server works out where the edge of the door frame is on your side of the wall, at hand height (`Stalk:_gripFor`): the wall's real thickness from its panels, plus the casing. It publishes that point as `GuestGrip`.
- His near arm reaches it by IK. His bony fingers curl round onto your side of the frame, his face leaning out above.
- The elbow hangs down by the frame with the forearm up along it. Out to the side, it stuck into the doorway like a stick (`peek-before-elbow-out.jpg`, then `peek-hand-on-frame.jpg`, `peek-from-the-room.jpg`).
- **Only his fingers** (FingersPeek): higher on the frame, with the elbow back inside the wall beside it, so nothing but the fingers shows (`fingers-before-arm-showed.jpg`, then `fingers-only.jpg`).

**The torch stutter**, as chosen: a burst when your light first lands on him, re-armed after 2 s off him, and at Breaking a burst every 4–8 s (`Config.Guest.StutterBurst`, `StutterRearm`, `BreakingBurstEvery`).

**F2 `guest reel`** (`Stalker/Reel`, new). He performs every way he moves, near you, one after another, with a caption each. There are 19 beats: standing, walking across you, walking up and stopping, turning on the spot, backing away, the creep, sideways, running, through a doorway, the peek, only fingers, listening, the bow, "after you", the stagger, the duck, the lunge's wind-up, yanked away, and on all fours. A lamp hangs over him so he can be seen, and nothing in the reel can catch anyone. `guest reel walk` (or `door`, `peek`, `fingers`, `run`, `crawl`, ...) plays one beat over and over. `guest reel stop` or `guest off` ends it.

## What reviewing it in Studio turned up (and fixed)

**His hips sank to the floor.** The server's walker sometimes pauses for a tenth of a second mid-walk. A foot that was stepping into place as he stopped landed where he'd stopped, its clock then kept it there a whole stance while he walked on, and his hips sank 3.5 studs to reach it. Three fixes:
- setting off, the clock starts from where the planted foot really is;
- a foot left too far behind (a stop, a turn, going back the way he came) steps at once, or hurries the other foot down first;
- his hips never drop more than 1.2 studs (`GuestPose.MaxDrop`).

A spec now walks him through every stop, turn and reversal, 0.4–1.4 s in, for 0.05–0.6 s. Straight on, his hips go no deeper than 0.69 at a walk, 0.78 at a run and 0.49 backing away. Studio, 30 s of doorway passes: 0.77 at most.

**He shuddered, and at a run his planted feet shivered.** His position reaches each client unevenly: walking, 0.03 to 0.15 studs a frame; running, 0.04 to 0.4. His body was drawn straight from it, so it jerked along, and since the engine moves him again between our joint update and the drawing, a planted foot shivered about 0.15 studs every frame. Now each client draws his body from a root of its own (`GuestController:_drawnRoot`). That root follows his real one on a smoothed path: it's carried on by his steadied velocity, pulled onto the real position, and braking hard as he slows so a stop isn't overshot (`Config.Guest.DrawnFollow`, `DrawnBrake`, `DrawnSnap`). Tried first on his recorded run: 4× steadier, 0.14 studs behind at a run, 0.1 overshoot at a stop. In Studio:
- running, a planted ankle was still in **83%** of frames (was 8–13%; the rest is the run's moment in the air);
- walking, **100%** of frames;
- his drawn speed at a run wobbles ±3.3 studs/s, where his real root wobbles ±5.5.

Everything that decides anything (where he is, what he sees, catches) still uses the server's root. Only the drawing is smoothed.

## Checked in Studio (seed 61)

Every beat of the reel, from fixed camera spots with a client-only lamp, plus a side view of the doorway with the wall beside it hidden on my client. Screenshots here:
- `approach.jpg`, `backing-away.jpg`, `creep.jpg`, `run.jpg`, `listen.jpg`, `crawl.jpg`
- `doorway-stooping.jpg`, `doorway-under-the-frame.jpg`
- the peek and fingers pairs above

The numbers are above. The console was clean apart from the usual DataStore 403s, and so was the bot's night (below).

**Not checkable by me:** how it all reads in motion, at full speed. That's the owner's look with `guest reel`. Also, how the smoothed drawing lines up between two clients (each draws him a fraction behind his real place; TC-232).

## The bot's night (seed 61, solo)

F2 `botrun` on the finished build. Out in 4:32, 13 steps, 0 failed, 0 stuck points, 0 nudges, 0 waits for him, 0 downs. First door 0:43, dinner 4:24, and the final hunt escaped in 4 s. He made 18 moves (Search, HostAction, DistantRoam, Peek, WaitAtTable). The Output had no animation errors.

## Tests

New specs: `Kinematics.spec` (7), `GuestGait.spec` (8) and `GuestMotion.spec` (5). The new specs cover:
- the feet: a planted foot slides under 0.3 studs/s whatever the gait, and the drawn foot is where the gait put it;
- the doorway: his head never goes through a door frame at any speed, either way, and he doesn't duck in the open;
- the peek: the hand reaches the frame and the head clears it;
- stops, turns and reversals never sink him.

`Guest.spec` lost its old stoop grid test (the stoop is now worked out at the frame).

## Waiting on the owner

- **Watch the reel**: TC-223 to TC-232 in `docs/TESTING.md`. In Studio, F2 `guest reel`; then `guest reel <beat>` for any one you want to watch closely.
- Anything that looks wrong in motion: say which beat and what.
- Not done in this pass: new art for his body (generated meshes for the coat and hands stay plan B, and would go on your account: ask first).
