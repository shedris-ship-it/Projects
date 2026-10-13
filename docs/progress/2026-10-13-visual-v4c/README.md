# The visual rework, V4 (part 3): the bedrooms, the bathroom, the kitchen, the utility rooms, the car and the front door

The owner, after the living-room batch: "Go ahead with the next batch." With it came two notes for later, both now in CLAUDE.md's Studio findings:
- **The piano puzzle doesn't work in play:** only a push prompt shows on the piano, never "Play". The owner has confirmed the computer and breaker puzzles work.
- **The curtains hang against bare wall:** they aren't in front of windows, which feels odd.

This third batch, `kit5`, dresses every furniture kind that was still grey-box, and the front door.

## The batch (`tools/blender/kit.py kit5`, `kitlib/house`)

| Piece | Size (studs) | For |
| --- | --- | --- |
| Bed | 7 × 5.05 × 10.14 | a walnut headboard with turned posts, pillows, a dusty-rose candlewick spread falling to the hem on both sides and the foot |
| Closet, ClosetDoor | 6 × 9 × 4; 3.1 × 8.2 | a painted walk-in closet, its rail and shelf, coats at the ends (the middle clear to stand in); its bypass doors framed round the game's mirror |
| Crib | 5 × 4.1 × 3 | chipped white spindles, a mattress and a worn blanket |
| Locker, LockerDoor | 3 × 8 × 3; 2.94 × 7.7 | green-grey steel, pressed vents, louvres at the eye, a number plate |
| TallCupboard, TallCupboardDoor | 3 × 8 × 3; 2.94 × 7.7 | the same in pine, raised panels |
| Toilet | 2.4 × 3.87 × 3.38 | old white porcelain, a wooden seat, its lid up |
| Sink | 3 × 4.1 × 2.5 | a vanity: an oak cabinet, a cultured-marble top and basin, chrome taps |
| Bathtub | 8.05 × 10 × 4.01 | a roll-top tub on brass claws, the game's water in it; a vinyl curtain on a rail along its front, parted in the middle |
| Counter, CounterDoor | 12 × 4.8 × 3; 2.26 × 2.89 | five open oak bays (what's kept in them shows), a speckled laminate top, a steel sink and tap, white tiles behind |
| Fridge, FridgeDoorTop, FridgeDoorBottom | 4 × 8 × 3.5 | almond enamel, a white liner, glass shelves; its doors with woodgrain-trimmed handles and bins inside |
| Stove | 4 × 4.9 × 3.75 | an almond range: coil rings on chrome pans, an oven window, a backguard with a clock and knobs |
| Washer | 3.5 × 4 × 3.7 | a white front-loader, a chrome-ringed porthole |
| WaterHeater | 3.22 × 7 × 3.07 | a rust-streaked jacket, the gas control and the pilot's window (it glows), pipes, the flue's hood |
| Workbench | 10 × 8.6 × 3.5 | a scarred top, a vice (at the game's keepout), a pegboard with a saw, a hammer, spanners and rope |
| Car | 7.45 × 4.76 × 14.4 | a 1980s station wagon (below) |
| Boiler | 6 × 10.8 × 5.09 | a riveted drum on brick, a firebox door whose grille the game's glowing bars show through, the flue through the ceiling |
| WineRack | 6 × 8 × 2 | an oak grid of cubbies, eight across and ten up, a bottle lying in most |
| WaterTank | 8.1 × 6.35 × 5.1 | a galvanised cistern with riveted seams, rust streaks, on brick piers |
| Shrine | 3 × 5 × 3 | the lantern's stone pedestal and an iron lantern round the game's glass |
| FrontDoor | 6 × 8 × 1.22 | bottle green, six raised panels, a brass knob and letter flap, a knocker and peephole outside |

**The owner's notes on the previews, fixed before the import:**
- **The car "doesn't really look like a car, it looks like it has a table cloth on the hood":** the dust sheet is gone. Its body is now drawn from its side's profile and swept across it (`shapes.moulding`): a sloped hood, a raked windscreen, the long wagon roof on its pillars, a near-upright tail, and the wheels in arches cut into its foot. The cabin is glass. It has woodgrain panels framed in chrome, roof rails, wing mirrors, chrome bumpers, square quad headlamps and a grille. Windscreen wipers were tried and taken off: they read as a moustache.
- **The wine rack "is like a web of shelves that doesn't connect where the actual wine bottles are":** the diamond lattice is gone. It's a grid of cubbies now, each bottle lying in its own cell with its neck to the front.

**Fixed on the way:**
- **Moved by the wrong amount:** a cloth joined from several sheets kept its first sheet's origin, so moving it afterwards moved it wrong. The bed measured 11.8 deep. `_settle` now bakes the origin back to the world's first.
- **The wine rack's first lattice:** it was trimmed in its boards' own coordinates and came out 20 wide.
- **The bath's cut:** cutting out its bowl left an empty material slot, and the bake stopped on it.
- **The toilet's lid:** it was the size of a board.

## In the game

**The hiding places keep the game's gaps:**
- the bed's spread falls to `ClothHem`;
- the bath's curtain parts as `ShowerCurtainL` and `ShowerCurtainR` do;
- the lockers' and cupboards' louvres sit at the standing eye (0.2 + `STAND_EYE`), six slats at the game's tilt.

**Moving pieces:**
- the closet's two doors (one mesh for both tracks);
- the locker's and the tall cupboard's doors, hung on the leaf below the louvres;
- the counter's five doors;
- the fridge's two doors.

**What stays the game's (`keep`):** the bath's water, the boiler's glowing bars, the shrine's glass and the closet's mirror.

**The front door:** `World/Kit.dressFront` hangs the mesh under the door part, so `FinaleService:_openFront` swings it open whole at the end.

**Data/Kit `rises`:** the bed, the toilet, the vanity, the bath, the counter, the range, the workbench, the boiler and the shrine stand over their kinds' heights.

## Imported and seen in Studio (build .186)

The owner imported `kit5.glb` (26 meshes); the console printed 81 kit meshes loaded and no errors. Seen in four houses: seed 3 (one player, the short night), the old house (Gate A), and seeds 8 and 6 built for a squad of four on a full night (F2 `squad 4`, `night full`), which bring in the garage, the cellar's rooms and the attic. A test light at the camera (client-side only) stood in for the room lights in most shots.

**The kitchen** (1 to 3): the counter with its sink and tiles, the range, the fridge. F2 `furniture open` swung the counter's five doors and the fridge's two: whatever's kept in the bays shows, and the fridge's lamp lights its glass shelves.

**The bedrooms** (4 to 7): the master bed and the kids' bed, the lantern shrine (its light was off: the game lights it), the closet's bypass doors, the crib, a tall cupboard in the foyer.

**The utility rooms** (8 to 10, 13 to 17): the mudroom's and the laundry's lockers, the washer and dryer, the workbench, the wine rack's cubbies, the boiler's firebox glowing through its grille, the attic's tank on its piers. From inside a locker in the boiler room you see the room between the louvres (17).

**The bathroom** (11): the clawfoot bath on its brass feet behind the parted curtain, the vanity and the toilet, its lid up.

**The car** (12): a station wagon from every side: the hood, the raked windscreen, the pillars and roof rails, the woodgrain between the arches.

**The front door** (18): bottle green in the hall's casing, its brass knob and letter flap.

**The closet's mirrors:** the doors' panels look like pale paint. With the kit door hidden the game's glass looks just the same, so the frame doesn't cover it; that's how the game's mirror material renders.

**Fixed after the import: the water heaters faced their walls** (8, then 9 and 15). The grey-box heater is a round tank, so its two places in `Data/Rooms` never gave it a turn, and the kit's gas control and pilot stood against the wall. The laundry's heater is turned 180 and the boiler room's 90, so both face the room. This changes no gameplay: the grey-box is round.

**Gate A** re-baselined: parts 2441, hash 1845087318 (was 2412 and 1055006600 at .185). The kit's new pieces and the turned heaters moved it.

**F2 `perf`** on seed 6 for a squad of four (29 rooms): server heartbeat 0.6 ms, 61,651 instances. Frame rate in the kitchen and the garage is in TC-290 for the owner, with a focused Studio window.

## For later (CLAUDE.md's Studio findings)

- **The kitchen's lone sink** (19): the `Sink` kind is now the bathroom's vanity, and a kitchen's lure `sink` stands by itself next to the counter. A kitchen wants a utility sink, or the counter's own sink as the lure. It's a placement question, like the curtains.
- **The Water Tank Room without its tank:** the mansion builds it 20 x 20 and `RoomFit` drops the 8 x 5 tank when the doorways leave no room. Seeds 6 and 9 (squad of four) keep it; seeds 1 and 5 don't.
- **The tank's rust** came out as even orange stripes (16). Irregular streaks would need one more import of that piece.

## Checks

616 tests, compile, selene 0 errors and 0 warnings, `rojo build`. TC-290.
