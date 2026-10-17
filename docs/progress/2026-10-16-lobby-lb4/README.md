# The lobby rework, LB4: the torch's looks and the car bits

The owner, away from their computer while LB3's wardrobe batch waits to be imported: "Lets do lb4 sketches." The plan (`docs/plans/lobby-rework.md`, "Electronics" and "The garage"): the torch's first three looks, sketched for the owner to swap any before they're modelled; and the pegboard of car bits. `sheet.jpg` has both.

## The torch's looks (`tools/blender/kitlib/toolkit.py`)

Sold for Marks in electronics, looks only (the plan): each keeps today's lens (its opening 0.4 across at the front, `World/ToolModel`), the switch on top and the body round the grip just behind it, so the beam, the switch's glow and your hand are exactly as they are, and nothing on it glows.

| Look | Price | As sketched |
| --- | --- | --- |
| Yellow rubber work torch | 1,000 Marks | Safety-yellow rubber, a little chunkier, ribbed where the hand goes, a black rubber bumper round the head, a black tail cap and lanyard loop, a black boot round the switch |
| Brass torch | 1,500 Marks | Someone's grandfather's: aged brass, engraved bands at either end, a knurled band to hold it by, a domed head with a rolled lip, a brass slide round the switch, a domed end cap and its ring |
| Long chrome torch | 2,000 Marks | The one you show off: a long polished barrel, knurled where it's held, a wide head behind a crisp ring, a black rubber tail. Longer than today's only toward you |

- `torch_above.jpg`, `torch_three_quarter.jpg`, `torch_tails.jpg`.
- Stand-ins show where the game's lens and switch go.
- The warm three-quarter light mutes the yellow; seen from above it's the bright yellow it is.

## The car bits (`tools/blender/kitlib/carbits.py`): a proposal

The plan names the pegboard's bits only by example (wood panelling, paint, fuzzy dice, the radio station that plays), priced 300 to 1,000 Marks. What can go on a car is limited by the car itself: the wagon's windows are dark glass with nothing behind them. So nothing inside a car would show (no fuzzy dice), and every bit is on the outside.

| Bit | Proposed price | Notes |
| --- | --- | --- |
| A paint job: cream, sky blue, forest green or black | 600 Marks each | Today's maroon stays the free one. Needs the car exported again with a body that can be tinted (one import) |
| Woodgrain sides | 400 Marks | Today every car has them. Sold as a bit, the free car would be plain (`car_front.jpg`: the blue and black wagons) |
| Whitewall tyres | 400 Marks | A white band round each tyre's wall |
| Roof rack and luggage | 800 Marks | Chrome crossbars, two strapped suitcases and a duffel |
| Spotlight and CB aerial | 1,000 Marks | The investigators' kit: a spotlight on the driver's pillar, a whip aerial off the back bumper |
| Bumper sticker, "I BRAKE FOR GHOSTS" | 300 Marks | On the tailgate; more slogans later. No brands, no band names |
| A radio station | 300 Marks each | What plays in your car while you wait: an 80s pop station, oldies, late-night talk, static. Sound only |

- **Whose bits show:** the car's driver's, while they drive it. The whole lobby sees them as the squad waits and as it leaves, and a car empties back to the plain one.
- `car_front.jpg`, `car_rear.jpg` and the close-ups: the five wagons are today's maroon and the four paints, wearing the bits between them.
- `house.car` takes another paint and leaves the woodgrain off on request; its defaults build the car as imported, unchanged.

## The owner's answer

"I'll go with your suggestions for now, until I can review it all." So LB4 is built on the proposal above as it stands: the three torches at their prices, all the bits at theirs, woodgrain a bit (the free car is plain), and the driver's bits on the car they drive. Every pick and price is still theirs to change: the prices are data (`Data/TorchLooks`, `Data/CarBits`), and a piece dropped later only leaves the shelf.

## Built (build .216)

- **The rules,** `Logic/Catalog` (spec'd, 5 tests): four kinds (torch, paint, car bit, radio), what's yours, prices, buying for Marks (never a free one, never twice, never short), the torch you carry, the paint, fitting or taking off a bit, tuning the radio, your car as the lobby sees it (only what's yours). Profile version 4 adds `Car` (paint, bits, radio), sanitised on load.
- **The electronics counter and the garage's pegboard** (`Services/ShopService`, `UI/Wares`): E "Look" opens a card with a turning preview (the torch, or a wagon in your bits), the price, and BUY, then CARRY, PAINT, FIT or TAKE OFF, TUNE. The server decides prices and ownership; a buy uses what it bought at once. The card closes when you walk away or a run starts.
- **Your torch,** wherever you are: `PA.TorchLook` is set from your profile on every server, so it goes into the run. Your own hand's view model and the hotbar's icon show it.
- **Everyone else's torch:** until now the squad saw only another's beam. `Controllers/HeldTorchController` welds their look of it into their left hand while it's up, its lens lit with their beam, and `PoseController` raises the arm (`Config.Pose.TorchArm`).
- **The cars** (`World/CarDress`, `Services/CarService`): each car wears its driver's bits while they drive it, for the whole lobby, and plays their station while anyone's in it (`Assets.Mall.Stations`: the hits, oldies, static between stations); empty, it's the plain car again.
- **F2 `ware`:** alone, the torch you carry and your car; `ware <kind> <id>` makes one yours and uses it; `ware none` takes them all back; `ware open counter|pegboard` opens a card.

Checked in Studio, server side: `ware` gives and uses each kind; car 3 dressed in 16 grey-box bit parts; the radio playing the hits; the counter's and the pegboard's cards drawn with every text fitting; buying the whitewalls through the remote (2,500 to 2,100 Marks) fitted them; taking off the roof rack; buying the chrome torch carried it. No script errors in the log. **Not seen yet:** the client side (the display was asleep while the owner was away): your torch in first person, the hotbar's icon, another's torch in their hand (two clients), the card's preview turning. TC-325 to TC-330.

## The batch, for the owner to import

Two files, both checked for holes (rendered with every face seen from behind in red; the whitewalls' open inner rim was closed):

| File | Pieces | Triangles |
| --- | --- | --- |
| `build\kit\wardrobe\wardrobe_lb4.glb` | `ToolTorchRubber`, `ToolTorchBrass`, `ToolTorchChrome` | 5,016 / 5,848 / 3,948 |
| `build\kit\mall4\mall4.glb` | `MallCarBody` (the paint, a neutral grey the game tints), `MallCarTrim` (glass, chrome, tyres, lamps), `MallCarWood` (the woodgrain bit), `CarWhitewalls`, `CarRoofRack`, `CarSpotlight` | 1,216 / 3,200 / 400 / 768 / 2,028 / 476 |

- Their measures are filed already (`Data/Kit` `Parts` and `Tools` without ids; `Data/KitWear` for the torches): once imported, each needs only its id and its maps' SurfaceAppearance (`assets/kit/<name>.model.json`).
- Each car piece is built in the car's own frame, so it sits where the old car mesh did (`at` from the body's middle).
- The paint's map is a pale grey (230), so `CarDress` asks for each paint that much brighter: a SurfaceAppearance's colour can only darken its map.
- The spotlight moved to the driver's side (the sketch had it on the passenger's: Blender's front is -y, so the driver's side is +x), and up over the wing mirror.

`batch.jpg` is the hole check's renders.

## Imported (build .219)

The owner, home the same day: "Imported all 3 files you sent", and "Lb4 looks good enough to start too". All 38 pieces (LB3's 29 garment pieces, the 3 torches, mall4's 6) are filed: ids in `Data/Kit` (Wear, Tools, Parts), looks in `assets/kit` (a right side wears its left side's maps). 370 kit meshes load. Seen in play:
- the six garments in the fitting room (biker, ringer, sweatshirt, denim jacket; parachute pants, high-tops), nothing poking through;
- the chrome torch in first person, held behind its switch;
- car 3 in cream with every bit (woodgrain, roof rack, spotlight on the driver's pillar, sticker, aerial), the other cars plain maroon.

The whitewalls read as part of the hubcap in the garage's light, so they're widened, with black tyre either side, in the next batch (`story`).

