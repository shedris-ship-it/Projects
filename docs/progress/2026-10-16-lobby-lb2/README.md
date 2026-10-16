# The lobby rework, LB2: parties and the video rental (build `2026-10-16.213`)

The owner asked: "Start LB2: parties and the video rental." The plan (`docs/plans/lobby-rework.md`, "Parties" and "Video rental") replaces the hub's Ready button and its majority timer with the cars in the garage: rent the case, get in a car, the driver honks.

## How a squad leaves now

1. **Rent the case in the video store.** Two boxes stand face out on the NEW RELEASES island's top shelf. E on The Halfway House rents it: the box goes in your right hand ("Take it to a car in the garage"). E again puts it back. St. Odile Ward says "isn't out on video yet. Coming soon." You keep the tape if you respawn.
2. **Take it to a car and get in.** E on a car, "Get in". The first one in drives. Four seats, the squad's size (`Config.Run.MaxPlayers`). Your tape goes into the deck and shows on the car's sign.
3. **The driver works the dashboard**, a trip sheet clipped to it (UI/Dashboard). It has three switches: Normal or Hard; Short night or Full house; Friends only on or off. It also has the **HONK** button. The others in the car see what's set, and who's driving.
4. **The honk** starts a 5-second countdown, shown on the sign and the dashboard ("LEAVING IN 5"). Anyone can get out until it ends: Space, or the dashboard's "Get out". If the driver gets out, the next passenger takes the wheel ("You've taken the wheel."). The last one out of a car takes the tape back out of the deck.
5. **The car leaves.** Its roll-up door rises and the car drives out of the garage.
   - Live: the squad teleports to a run server of its own, carrying the car's case, difficulty and night, and this lobby's id.
   - Studio: the run starts in this server.
6. **Coming back.** The run server sends the squad to the lobby they left (`TeleportOptions.ServerInstanceId`), or to any lobby if that one's gone or full. There they're seated together in an empty car, with their tape and settings, and a typed receipt slip with the run's Marks. In Studio they're back in the same seats of the same car. The slip stays 12 seconds, and waits while the Dossier is open.

A squad that's stranded on its run server (the teleport back failed) is seated in a car there too, with its case in the deck: a honk plays it again in that server. A run server only builds the garage, so there's no shelf to rent from there.

Solo is the same: get in alone and honk.

## Parties

- **Friends only:** the driver's switch. Only the driver's Roblox friends can get in ("That car is friends only.").
- **Roblox parties:** when two or more of a party are in the server, an empty car is kept for them for 90 seconds. Its sign says SAVED FOR A PARTY; strangers are told "That car is saved for a party that came together"; each member gets "Your party has car 3: get in together."
- **The payphone** on the garage wall: E "Call a friend" opens Roblox's invite prompt. If invites aren't open there (Studio), it says "No answer".
- **Finding a squad:** the sign in each car's rear window is readable from the garage's dock. It shows the case (or NO TAPE YET), the difficulty and night, the seats left (or LEAVING IN 5), FRIENDS ONLY or SAVED FOR A PARTY, and who's in.

## Decisions I made

- **The cars are numbered.** I first named them by colour (the red car, the blue car...). But the six are the house's one maroon wagon with its paint baked into the texture, and a tint only darkens it, so "the blue car" was maroon too. Each bay's number is now stencilled in road paint over its door, and the cars are "car 1" to "car 6". Painting them different colours needs a re-exported car with a tintable body; it belongs with the pegboard's paint jobs (LB4).
- **The seats sit low.** A seated player's head came through the wagon's roof (head top 5.4 studs, roof 4.76). The seats are a stud lower now: the head is at the windows (top 4.44), and nothing shows under the car.
- **The camera turns about the car** while you're in one, 13 to 24 studs out (`Config.Camera.CarZoom`), and follows it through the door. Before, it hung over the roof looking down at it. You can still turn it to watch the dock for friends.
- **Getting out puts you beside your seat**, between the cars. Your client can hold you in the seat a moment after the server lets go, and standing up from it put you on the roof, so you're set down again 0.3 s later if you're not there.
- **The tapes are sized and placed like the shelf's.** First built at twice a tape's size, floating in front of the shelf across two rows; now 0.72 x 1.12 (about 1.8 times a tape, a featured box), standing on the top shelf and leaning back on the row behind as the others do.
- **The dashboard's switches send text**, matched without regard to case. `Net.onServer` checks each argument's type, and the boolean "friends only" had been sent as a second type that no check accepts.
- **Teleport data is display only.** What the run server sends back passes through the client, so it could be forged. `Logic/Homecoming` checks and clamps it, and it only seats the squad in a car and shows the receipt. The Marks themselves are saved by the run server (`DataService`), never awarded from it.

## Removed

- The hub's Ready button and countdown.
- The majority timer (`Logic/LobbyRules` and its spec).
- The contract table in the garage.
- The `SetReady`, `SetDifficulty` and `SetNight` remotes.
- The `Ready` player attribute and the `LobbyCountdown`, `LobbyWaiting` and `LobbyStartsAt` run-state attributes.

The hub's case folder now shows the case, the three steps (tape, car, honk; each ticked as you do it) and who's where ("Shedris · in car 3").

## The code

| Where | What |
| --- | --- |
| `Logic/Cars` (spec, 8 tests) | A car's seats and rules: who may get in (away, already seated, full, held for a party, friends only), the wheel passing on, the dashboard (the driver only, not while leaving), the honk (needs a tape), the party hold, the first empty car, the sign's lines |
| `Logic/Homecoming` (spec, 2 tests) | What a run server sends back with its squad, and its checks on arrival (version, token, squad, the receipts clamped and only the squad's, a known case and settings) |
| `Logic/RunContract` (spec, 1 more test) | `lobby`, the lobby's server id, to come back to |
| `Services/CarService` | The six cars over the garage's bays: the wagon from the kit over a grey body, four seats, the rear-window sign, the "Get in" prompt, the horn; getting in and out, the dashboard, the honk and countdown, the door and the drive, sending the squad, coming home, arrivals, `Strand`, the payphone, the party hold |
| `Services/RentalService` | The tapes on the shelf (a box with its cover drawn on, a COMING SOON sticker), the tape in your hand |
| `UI/Dashboard` | The trip sheet, the receipt, the invite prompt |
| `UI/Lobby` | The case folder's steps and who's where |
| `Controllers/ActionController` | No prompts from inside a car; the car's camera |
| `Services/PlaceService`, `RunOrchestrator`, `LobbyService` | The lobby's id in the contract, the way back with the Homecoming data, the receipts, a stranded squad's car |
| `Data/Mall` | A roll-up door per bay (six), `Mall.Cars`, `Mall.Tapes`, the bay numbers, the CARS · TO THE HOUSE card, three dock lamps |
| `Config.Cars`, `Config.Camera.CarZoom` | Seats, countdown, drive, door, party hold, arrival wait, receipt, the dashboard's choices, the seat spots, the exit, the sign |
| `Assets.Mall.Horn` | The horn: Pro Sound Effects' jeep horn doubles and triples (2.5 s), the owner's pick by ear (build .214) over diman's "Car horn 5" and AmikkuHedgehog's "Generic car horn" ("just obnoxious"). F2 `mallsound horn` sounds the nearest car's |

F2:
- `car` lists the cars.
- `car in [n]` gets you in car n (or the first empty one).
- `car out` gets you out.
- `car honk` honks.
- `car set <difficulty|night|friendsonly> <value>` sets the dashboard.
- `tape [location|none]` puts a tape in your hand, or takes it away.

## Checked in Studio (solo)

- **The rules:** honk without a tape is refused ("No tape in the deck"). Getting out puts you beside the car, on the floor, not on its roof. The last one out takes the tape. A tape in hand goes into the deck when you get in.
- **The dashboard:** each switch changes the sign at once, both from the client's remote and from F2 (HARD · FULL HOUSE · FRIENDS ONLY, and back).
- **The whole trip:** tape, car, the full house, honk. The horn plays and the sign counts LEAVING IN 5. The door rises and the car drives out to z -138. The run starts with the car's night (`Night full`). Then F2 `end`: you're back in car 5's driver's seat with the tape and settings, the car in its bay. The receipt reads THE HALFWAY HOUSE, MARKS +40, and waits for the Dossier to close.
- **The camera:** on the car (13 studs behind it) in the hub; your own first-person in the run; back on the car afterwards.
- **A run server** (`DebugRole` = `run`, TC-304) builds the six cars in its garage and no tape shelf. Its trip back fails in Studio ("Invalid placeId"), and 30 s later you're in car 1's driver's seat with THE HALFWAY HOUSE in the deck. A honk there starts a new run in that server (F2 `role`: `both`).
- **No errors** from the game's scripts in the console.

Not checked here, the owner's (TC-314 to TC-319):
- two or more clients: friends only, the wheel passing on, a countdown someone gets out of;
- a Roblox party arriving together;
- the payphone's invite in the live game;
- the live teleport there and back into the same lobby, in a car.

The horn was picked by ear the same day (build .214): the jeep horn, candidate 1. The owner: "Definitely 1, the other horn sounds are just obnoxious."

## Shots

| Shot | What it shows |
| --- | --- |
| `garage_before.jpg` | Before: six maroon wagons named by colour, and my character standing on a roof after getting out |
| `garage_after.jpg` | After: the bays numbered over their doors, each car's sign readable from the dock, the dashboard of car 3 |
| `seated_low.jpg` | Seated lower: no head through the roof |
| `car_camera.jpg` | The camera on the car: its sign, its bay number, its door |
| `tapes_before.jpg`, `tapes_after.jpg` | The tapes, oversized in front of the shelf, then standing on its top shelf |
| `receipt.jpg` | The receipt slip and the dashboard after a run (the world is black only because the Studio test tool had reset the camera) |

**Next in the plan:** LB3, the boutique and Marks. It starts with sketches of the six garments for the owner to swap any.
