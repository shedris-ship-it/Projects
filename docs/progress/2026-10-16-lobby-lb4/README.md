# The lobby rework, LB4: sketches of the torch's looks and the car bits

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

## For the owner

- The torches: keep the three, or swap any.
- The car bits: which of these, their prices, and whether woodgrain becomes a bit or stays on every car.

Then one Blender batch for what's kept: the three torches; the car again with a tintable body, if paint is kept; the bits. After that, the electronics counter, the pegboard, wearing a torch look in the run, and the driver's bits on the cars.
