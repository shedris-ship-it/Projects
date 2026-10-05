# Visual audit, round 1: floors, windows and furniture that clipped

The owner's screenshots (2026-10-04): "weird clipping in doorways and in rooms on the floor, window curtains look weird, there is also still clipping in some of the furniture such as the bed and the couch chair."

All shots are seed `1316117598`, the mansion.

**Floor stripes** (`01`, the owner's shot; `02` after).
- Cause: every ground-floor wall rose to exactly the height of the upstairs floor's top (11 studs). Wherever a room upstairs sat over a wall downstairs, the wall's top showed through that floor as a flickering stripe. Two rooms' walls sit side by side, so the stripe came out light and dark.
- This house had 18 of them, for example the kitchen and den walls across the upper corridor, and the pantry and laundry walls across a guest room.
- Fix: ground-floor walls stop 0.25 studs inside the slab (`MansionBuilder`, `SLAB_TUCK`). Double-height rooms are unchanged.
- Checked in Studio: no part's top is level with any floor anywhere in the house.

**Window curtains** (`03` before, `04` after).
- Cause: a window that lights its room carried its moonlight on the glass itself, half a stud behind the curtain. That lit the curtain like a lampshade and outlined the casing in light. The moon's floor spill on other windows had the same problem.
- Fix: both lights now leave from an invisible `LightPane` 0.7 studs into the room, in front of every covering (`PropFactory.buildDecor`).

**Bed** (`05` before, `06` after).
- Cause: the blanket and the drape poked through the footboard, and the frame shared faces with the head and foot boards, so they flickered. The pillows floated 0.1 studs above the mattress.
- Fix: the footboard is lower and the blanket runs over it, then hangs down in front of it. The frame and mattress stop at the boards. The pillows sit in the mattress.

**Armchair and sofa.**
- Cause: the arms, base and arm rolls shared face planes, so their sides flickered. The back cushion poked through the back and out over its top.
- Fix: the base sits between the arms, the arms stand on the feet, the rolls stand 0.05 proud of the arm fronts, and the back cushion leans against the back without entering it.

**Same kind of fix, found by a scan of every prop in the house:**
- the bathtub's rim, which flickered along its sides and corners;
- the standalone floor-length curtains (overlapping folds);
- the rug's three layers, which were only 0.007 studs apart;
- the crib, whose top was one solid board like a lid. It's now a rail frame with its bars reaching it (`07`).

What's left in that scan is faces pressed against a wall or the floor, which can't be seen.

**Not changed (noticed in passing):**
- The torch's switch glows as a large orange blob when the torch is on. The owner asked for the glow; it could be smaller.
- The torch beam is a 48° cone, so the floor right at your feet stays outside it while you look ahead. That's a choice, not a bug.
