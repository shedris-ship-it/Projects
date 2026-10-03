# Step 6b: The Guest's body, face and animation

Step 6 of [`docs/ART.md`](../../ART.md), seed `1800820264`. The "before" is [`baseline 12 and 13`](../../baseline/2026-10-02/README.md): a default R15 avatar, stretched and painted dark, with stock walk and idle animations. Today's shots were taken with `guest here 10` and the torch on.

**The body** (`01_full_body_torch.jpg`, `05_corner_moonlit.jpg`)
- 8.4 studs tall, tall enough to nearly brush the 10-stud ceiling.
- Arms long enough that the fingertips hang below the knees. The hands are clasped low in front, like an undertaker's.
- A dated suit a size too big: padded but narrow shoulders, lapels, and a jacket to the thigh.
- A pale collar and a narrow V of shirt with a dark tie, so the body still has edges in the dark.
- Long, white, two-jointed fingers.
- Built in code from smooth primitives: no uploads.

**The face** grows with Drift (owner, 2026-10-03):
- Calm (`02_face_calm.jpg`): a closed crescent far too wide for the face.
- Fraying (`03_face_fraying.jpg`): it opens ear to ear on rows of small, uneven teeth.
- Breaking (`04_face_breaking.jpg`): the porcelain cracks and both eye hollows bleed.
- When your torch is on his face, two pin-points of light show in the eye hollows.
- The smile widens further when he's close or backing away.

**Animation**: every joint is animated on each client, every frame, from `Logic/GuestPose` (tested). No uploaded animations.
- Poses: polite idle with breathing, a frozen hold without breathing, a walk that's slightly too slow, run, creep, back away, peek round a door frame, zoom, lunge and bow.
- Twitches: sudden jerks of the head or a shoulder that ease back.
- His head keeps turning to watch you up to 160°.
- He ducks under door frames.
- His fingers twitch, and grip the jamb while he peeks.
- His footsteps come from his real feet, muffled through walls.

**Debug:** `guest here [studs]`, `guest walk`, `guest pose <name>`, `guest form <0-2>`, `guest smile <0-1>`, `guest lean <-1..1>` and `guest off`.

**Checked in Studio:** the screenshots above. The walk was checked on a 24-stud path. No console errors.

**Not checked yet:** how the new poses look when the AI actually uses them (peek, back away, creep, lunge). Those come with the behaviour in the next steps. Footstep audibility on other clients also needs a two-client test.
