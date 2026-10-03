# Visual pass step 3: trim, doors and windows

Step 3 of [`docs/ART.md`](../../ART.md). Baseline seed (`seed 1800820264`) and camera spots, so each file here compares directly with the one of the same name in [`before/`](before/), taken on the previous commit in the same session.

**What changed**
- **Baseboards and crown moulding** in dark walnut along every wall face, including corridor closets and filled arms (`World/Trim.luau`). Trim catching the light is what makes a box read as a room: compare the walls in `06_dining_room` and `07_kitchen`.
- **Door casings** painted lighter than any wall, on both faces of every doorway, with a lining through the opening. Exits now read even in dark rooms (ART.md rule 4): see the two doorways in `05_foyer` and the door at the end of `attic_landing_door`.
- **Doors** are dark walnut with four raised panels on each face and a tarnished knob. The knob stays clear of the reserved brass colour. About 30% of doors rest slightly ajar (16°) with darkness behind them (the kitchen door in `07_kitchen`). An ajar door still blocks the way until someone opens it. Which doors are ajar comes from its own random fork, so it changes nothing else a seed builds.
- **Windows** are something you look into rather than a picture of one: a painted casing and sill, and behind a faintly tinted pane the night sky glowing softly, lighter at the top, with dark muntins against it (`06_dining_room`, `10_living_room`). Roblox's Glass material hid the sky up close, and a reflective pane darkened whatever was behind it, so the pane is a plain faint tint.
- **Values** are in `Config.Trim`.

**Seams stay invisible (rule 3).** Every wall between two rooms has a hidden doorway-sized panel that a divergence can flip for one player. The trim flips with it: a baseboard piece across the panel shows while it's a wall, and the casing and lining show while it's a doorway. `PerceptionController` switches them together with the panel, so a phantom doorway is framed like a real one, and a hidden doorway leaves an unbroken baseboard.
- Checked in Studio: all 20 seams in the baseline house start in the right state, and no trim piece collides or blocks a raycast.
- In a Phantom Architecture run (`seed 1814498305`), the phantom doorway clue showed a real doorway as wall for the player. `hidden_doorway_as_wall.jpg` is what they saw: plain wall, baseboard and crown unbroken, no frame.

**Sealed window clue:** the bricks now sit just behind the glass, as if the window was bricked up from outside, and the sky glow switches off while it's bricked (it draws over anything just in front of it). The clue now only goes on outside walls. See `sealed_window_open.jpg` and `sealed_window_bricked.jpg`, from the same spot.

**Cost:** about 500 more parts in the house (about 2,200 instances in all). The build still takes 0.03 s. fps not yet measured in a focused Studio window; check F2 in the next playtest.

No errors in the console. The only red lines are DataStore writes, which Studio blocks until "Studio access to API services" is turned on for the published place.
