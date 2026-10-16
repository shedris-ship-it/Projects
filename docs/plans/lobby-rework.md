# The lobby rework (LB0 to LB6)

A draft from the owner's brainstorm (2026-10-15), with their answers to its first open questions from later the same day. Nothing here is built yet. Where it disagrees with the design doc about the hub (section 2's "Briefing", section 7's places, section 9's catalogue) or with `docs/ART.md`'s Hub, this plan wins once the owner approves it. Section 9's rules still stand: sell looks, expression and social convenience; never sell safety from the Guest.

## The owner's choices (2026-10-15)

- **A closed-off corner of a dead mall,** not a 1988 town strip: the strip "might feel too open and too annoying to get from place to place".
- **Four stores to start, and a garage with the investigator stuff.** The video rental store, where you pick what you play, opens straight into the garage, "where you can head out with your party".
- **A giant metal shutter closes off the rest of the mall,** "so it feels like a section of an abandoned mall rather than just a little tiny mall", and so the lobby can grow later. What happens with the shutter is to be talked through later.
- **The lobby has to be intuitive** and feel right, "not annoying or redundant".
- **The lobby is where the game makes money.** Marks, the currency runs already pay, are also sold for Robux.
- **An 80s clothing store** where you spend Marks.
- **An 80s arcade:** 5 Robux a play, a 250 Robux unlimited arcade game pass, and high scores on each machine on a leaderboard across all players.
- **Up to 50 players in one lobby,** so partying up has to work at that size.
- **Ideas the owner liked:** a starter pack, arcade bundles, a prize counter, gifts, seasonal limited items, real Roblox avatar items later, and ads in the dead mall, as long as they're immersive: "ads in places you might actually see ads inside of a mall".
- **Not for now:** a monthly membership, since the game has private servers too.

Their answers to the draft's open questions (later on 2026-10-15):
- **One free arcade play a day,** yes. **Plays for Marks too,** but "relatively expensive to encourage supporting the game, not a crazy amount though".
- **Electronics is the fourth shop.** And an **80s diner** at the end of the hall, on the unused wall beside the boutique's front and the electronics store, with leaderboards: **the fastest completed runs and the longest completed runs**.
- **The shutter stays closed** until the owner decides what to do with it.
- **No name for the mall** for now: "I just wanna focus on the atmosphere".
- **The boutique opens with a small first paid line:** about six garments, and three torch looks in electronics, "so Marks and the Marks packs have a point". The owner first leaned towards free outfits only, with more clothes after launch "to see if the game catches on", and took Claude's recommendation (the boutique below). More clothes come after launch.
- **The weekly arcade prize is undecided** until more customisation is planned. For now the prize counter is in the arcade, visible but clearly closed down.
- **Studio's API access is on** (the owner).
- **Runs pay about half the Marks, to make Marks worth more** (the owner; the shape below is Claude's, which they took):
  - about 150 for a strong escape, with the run's sums scaled down rather than capped;
  - Clearance XP kept at today's pace;
  - 10 Marks a Robux, with clothing pieces around 1,000 Marks (about 100 Robux) as the baseline;
  - a cheap first rung in the boutique, double Marks on your first escape of the day, and 100 Marks for an arcade play.

  The formula is retuned at LB3 with the bot's numbers.

## What's there today

- One place holds the hub and the run (`Services/LobbyService`, `Services/RunOrchestrator`). The hub is a 56 x 56 stud room: a contract table toggles the difficulty, everyone presses Ready, and a majority starts after 30 s (`Logic/LobbyRules`). Its screen is a case folder (`UI/Lobby`).
- Marks are earned every run, win or lose (`Logic/Progression.marksForRun`): about 100 for a lost run that got somewhere, about 300 for a good win, roughly 400 or more with every valuable carried out. Every Mark earned also adds Clearance XP (`DataService`). Nothing spends Marks yet. LB3 halves the Marks (see Money).
- The wardrobe (`Data/Wardrobe`, `Services/OutfitService`): eight garments (four tops, two bottoms, two shoes), and outfits are handed out by the order players arrive, so a squad always looks different at a glance. No prices, no ownership.
- No purchases, game passes or teleports exist anywhere in the code.
- Studio's API access is on since 2026-10-15 (the owner), and Studio's play tests save to stores of their own since build .199 (LB0, below). Before that, DataStores failed with 403 in Studio.

## The place: a corner of a dead mall

A mall that closed down. The investigators have the power back on in one corner: the court and the four shops round it are warm and fully lit, and the dark starts at the shutter. Rain drums on the skylight over the fountain, and the storm flashes through the mall's glass. The lobby stays the one safe, lit place (`docs/ART.md`, Hub); it just sits inside a much bigger dark.

### Layout

```
                              (to the house)
                                    ^
                   +----------- GARAGE ------------+
                   |  cars, case board, Dossier,   |
                   |  payphone, car bits           |
                   +---------------+---------------+
                                   | wide back door
               +----------+ +----------+ +----------+
               | BOUTIQUE | |  VIDEO   | |  ARCADE  |
               |          | |  RENTAL  | |          |
  +----------+ +----||----+ +----||----+ +----||----+
  |  DINER   |                                      |
  |  booths, ==   COURT: spawn, fountain,           |
  |  run     ==   photo booth, mall directory       |
  |  records |                                      |
  +----------+ +----||-----+========================+
               |ELECTRONICS|  GIANT SHUTTER (closed)|
               +-----------+  the rest of the mall  |
```

- **The court** is where you arrive the first time. Every shopfront is in view from the fountain.
- **The diner** closes the hall's far end, on the wall beside the boutique's front and the electronics store (the owner's place for it), so its neon faces you down the length of the court.
- **The way to a run is one straight line:** court, video rental, garage, out of the garage door. The shops sit beside that line, never on it, but in view of it.
- **Small:** players walk 12 studs a second (`Config.Player.LobbyWalkSpeed`), so every shopfront is within about 4 seconds of the fountain. The court is roughly 100 x 60 studs.

### The rules that keep it intuitive

- **One job per place, one place per job.** No menu or second place repeats what a shop does.

  | Place | Its one job |
  | --- | --- |
  | Court | Arrive, see everything, hang out |
  | Diner | The run records (the fastest and longest escapes); booths to sit in with your squad |
  | Video rental | Pick *what* you play (the location, later the daily contract) |
  | Garage | Your squad and your car: get in, pick *how* you play (difficulty, night length), leave; Clearance and the Dossier |
  | Boutique | Clothes |
  | Electronics | The torch's looks |
  | Arcade | Play, each machine's scores |

- **Each choice is made where the people it affects are.** One person picks the tape; the squad, sitting in the car together, settles the difficulty and the night.
- **Going again takes about 10 seconds.** After a run the squad comes back in its car in the garage, with the tape still in it, so "same case again" needs nothing. A new case is one step into the video store. Shopping is always a choice, never on the way.
- **Open shopfronts with roll-up grilles,** like a real mall, so 50 players never jam in a doorway. The video store's back door is wide for the same reason.
- **Neon signs, one text size,** readable from the fountain. The menu clears Roblox's chat hint (the old hub's known problem).
- **Physical, never overlays** (the owner's standing rule): you get in a car, take a tape off a shelf, step into a changing booth. Screens appear only where a real thing has one: the dashboard, a cabinet, the booth's mirror.

## Parties: the cars in the garage

The garage holds about six station wagons (the house's `Car` kit piece, given doors and seats). Cars come and go, so there's always an empty one.

- **Get in a seat and you're in that party.** The first in is the driver. A wagon seats four, the squad's size (`Config.Run.MaxPlayers`).
- **The driver** holds the tape and works the dashboard: difficulty, night length, and a lock for friends only. They honk to leave; a 5-second countdown follows, during which anyone can get out. If the driver gets out, the next passenger takes the wheel.
- **Strangers find a squad by the sign taped inside the windscreen** (the 1988 paper interface): the case, the difficulty and the seats left, readable from across the garage.
- **Solo:** get in alone and honk.
- **Friends who arrive as a Roblox party** (the app's party feature, `Player.PartyId`; `SocialService:GetPlayersByPartyId`) are offered a car together.
- **A payphone on the garage wall** opens Roblox's invite-a-friend prompt (`SocialService:PromptGameInvite`).
- **Leaving:** the car pulls out of the garage door, then a teleport screen shows the road at night through the windscreen, with rain and wipers. The run begins with the arrival cutscene the game already has.
- **Coming back:** the squad lands in the same lobby server and in a car again, still a party, with the run's Marks on a typed receipt slip.
- **Today's Ready button and majority timer go.** The car is the ready-up, in Studio's one-place mode too (*done* in LB2: `Logic/LobbyRules` is gone).

## The shops

### Video rental: picking a case

- One tape per location on the shelf: The Halfway House to rent; St. Odile Ward on the shelf with a "coming soon" tag (`Data/Locations`, `available`).
- Tapes the squad hasn't the Clearance for wait behind the counter with their level on a sticker (design doc section 9: Clearance unlocks contracts).
- Later, a "Tonight's special" tape: the daily contract, one seed for everyone (Next item 8 in CLAUDE.md).
- Take a tape and carry it to a car; the car shows it on the windscreen sign. The tape is the only way to pick a case.

### Boutique: clothes for Marks

- **Clothes by the piece** (a top, bottoms, shoes; later jackets and hats), so there's always something cheap to buy. Racks by slot.
- **The changing booth:** step in and the camera turns to face you. Flip through what you own and what's on the racks, see it on you, and buy it right there for Marks. Nothing you haven't bought leaves the shop on you.
- **What you wear is yours in the run too,** in first person and to your squad. His disguise clones a friend's character (`GuestController:_disguise`), so bought clothes carry over to it.
- **Today's eight garments become the free starter set:** four tops, two bottoms and two shoes mix into 16 looks. New players still get a squad-distinct outfit by arrival order until they choose their own.
- **It opens with a small first paid line** (the owner, 2026-10-15): about six garments (two jackets, two tops, a pair of bottoms, a pair of shoes), plus the torch's first three looks in electronics. More clothes come after launch.
  - **Why** (Claude's recommendation, which the owner took): with nothing to buy, Marks would only buy arcade plays. The Marks packs would sell a currency with almost no use, the starter pack would have no jacket to give, and the boutique would be a changing room with tills. Players notice a shop with nothing in it, and the first weeks are when a new game earns its reputation.
  - **The cost** is one wardrobe batch, as V6's eight garments were (`tools/blender/wardrobe.py`, `kitlib/wardrobe`, built round both bodies and checked with `wardrobe_visibility.py`), and one small batch of torches.
  - **Which six** (the owner, 2026-10-15, from Claude's picks): 80s at a glance, and different in silhouette from the free varsity jacket, windbreaker, flannel and cardigan. No logos, band names or brand stripes.

    | Piece | Slot | Price | Why |
    | --- | --- | --- | --- |
    | High-top sneakers | Shoes | 500 Marks | The cheap first rung; the most 80s shoe there is |
    | Ringer tee | Top | 800 Marks | A cheaper top, with contrast trim at the collar and cuffs |
    | Parachute pants | Bottom | 900 Marks | Iconic, and nothing like jeans or cords |
    | Colour-block sweatshirt | Top | 1,000 Marks | Big 80s colour against the muted free set |
    | Acid-wash denim jacket | Top | 1,500 Marks | The starter pack's jacket (the pack: about 250 R of value for 99 R) |
    | Leather biker jacket | Top | 2,000 Marks | The one people want, and see on others |

  - **Sketches first, at LB3:** a quick sheet of the six on both bodies for the owner to swap any before the batch is modelled.
  - **A jacket is a top** in today's wardrobe (`Data/Wardrobe` slots: Top, Bottom, Shoes), so it's worn instead of a shirt, not over one. Jackets over shirts would need a fourth slot, its pieces built over each top's: worth doing after launch, not for it.

### Electronics: the torch's looks

- **The torch is the one tool that's always yours** (on F, with your own arms), so its looks sell first. The found tools (lantern, radio, crowbar, bolt cutters...) pass between hands in a run, so their looks would swap owners; they wait.
- **The first three** (the owner, 2026-10-15, from Claude's picks):

  | Look | Price | Why |
  | --- | --- | --- |
  | Yellow rubber work torch | 1,000 Marks | Chunky and practical |
  | Brass torch | 1,500 Marks | An old torch from someone's grandfather's drawer; suits the family house |
  | Long chrome torch | 2,000 Marks | Sleek metal; the one you show off |

- **Looks only:** every torch keeps the beam, its brightness and range, and the hand's grip (`Config.ViewModel.Poses` `grip`) exactly as today, and the squad sees it. Nothing that glows or changes the light's shape (a lantern): teammates would read it as a different tool, and a glowing body would light you up in the dark.
- **Sketches first, at LB4,** for the owner to swap any before they're modelled.
- **Later:** the ping and callout looks (design doc section 9).
- **The TV wall in the shop window** is where the video ads go (see Ads).

### Arcade

- **Machines you walk up to:** press E and the camera settles on the screen. Others can watch over your shoulder.
- **A play costs a credit.** The owner's prices: **5 Robux a play** and a **250 Robux unlimited arcade game pass**, plus a 10-play bundle for 40 Robux.
- **One free play a day** for everyone (the owner's yes), shown on each machine ("1 free play today"). It resets at midnight UTC.
- **Plays for Marks, priced to make Robux the better deal: 100 Marks a play** (the owner). At 10 Marks a Robux a 5 Robux play is worth 50 Marks, so 100 is twice that. Supporting the game is clearly cheaper, but it isn't steep: a strong escape (about 150 Marks) buys a play with some left over.
- **High scores on every machine,** all-time and weekly, across all players, shown on the cabinet's attract screen under Roblox display names (typed initials would need Roblox's text filter). A weekly prize waits until more customisation is planned (the owner).
- **The prize counter is there but closed down** (the owner): grille down, a "closed" sign, a dust sheet over the prizes. No tickets are given until it opens, so nothing piles up for a design that may change. When it opens, scores earn tickets for silly cosmetic prizes, and tickets are never sold.
- **The games are original,** never clones (the big names are trademarked). The first: **HOUSE CALL**, a maze where the Guest freezes while you face him, the game's first rule as an arcade game. Later: **NIGHT DRIVE**, a road dodger in the rain. Each machine is a small game of its own to build, so one comes first.

### The garage: the investigators' room

The cars, the payphone, and a pegboard of car bits (wood panelling, paint, fuzzy dice, the radio station that plays), which the squad and the whole lobby see. The case board shows your Clearance and what it unlocks next; the Dossier sits on a desk. Later, a practice run starts here (Next item 6, the tutorial).

### The diner: the run records

An 80s diner at the hall's end: booths, a counter with stools, neon in the window, the place a squad sits between runs. It holds the records (the owner's two):
- **The fastest completed runs,** from the arrival to the run out of the front door.
- **The longest completed runs:** the squads that held on longest and still got out. Stalling can't farm it, because a run that drags on reaches Drift 100 and the Reckoning, a hunt that never ends.

**Two boards, as a diner has them** (the owner, 2026-10-15):
- **The menu board over the counter is Normal; the specials board beside it is Hard.**
- **Each board holds four lists, top five each:** the fastest solo, the fastest squad, the longest solo and the longest squad. Each entry shows the names, the squad's size and the time.
- **Solo is split from squads from day one.** The house grows with the squad (`Logic/HouseSize`), so solo houses are smaller and solo runs would top a mixed fastest list, pushing squads off the board, and squads are what the game is built for.
- **Short night only to start** (the default, `Config.Run.Night`), labelled on both boards. Full-night records can get a third board later if people play it (`Config.Mansion.Profiles`).
- **Only real runs count:** never one from Studio, and never one where an F2 debug command was used. Otherwise test runs would hold every record.

The time comes from the server, which already measures every run (`RunOrchestrator`, `run.started`), so the boards need no other cheat check.

The daily contract, when it comes, is the fairest race of all (one house for everyone).

### The court

The fountain, benches, the mall directory ("you are here", which doubles as the lobby's map), and the photo booth. The booth takes a strip of your squad with ready-made frames and stickers, never drawing or typing: free-form player creation raises the minimum age (design doc section 9).

## Money

### Marks

- **One currency for cosmetics.** Marks are earned in runs and sold for Robux. Clothes, torch looks and car bits are priced in Marks, so free players can reach almost everything, and payers get there sooner.
- **Bought Marks never add Clearance XP.** Clearance unlocks contracts, and selling it would be selling progress. Today `DataService` adds a run's Marks to XP; a purchase adds Marks only.

**What a run pays** (the owner, 2026-10-15: about half of today, "to make marks more valuable"):
- **About 150 for a strong escape,** and a lost run that got somewhere still about 20 to 60: every run pays something, win or lose (design doc section 9).
- **Scaled down, never capped.** Every sum in `Progression.marksForRun` comes down, so a strong escape lands near 150 on its own. A cap would make the family's valuables worthless once a squad reached it, breaking the push-your-luck choice (2026-10-11), so valuables stay a share you'd notice.
- **Clearance XP keeps today's pace.** XP gets its own sum (today's formula, as `Progression.xpForRun`), and only the Marks shrink. Halving both would quietly halve how fast players level and unlock contracts.
- **Double Marks on your first escape of the day** (midnight UTC, like the free arcade play): a reason to come back daily that doesn't raise what runs pay.
- **Retuned at LB3 with real runs:** F2 `botrun` plays a whole run and `summary` prints its numbers. The weights are set from those, against the 150 target and the 20 to 60 for a loss, before the shop opens. Nothing spends Marks until then, so nothing is lost by waiting.

**What that means for a piece:** at about 150 an escape, a 1,000-Mark piece is about 7 escapes in a row. A player who escapes about half the time makes about 95 a run, so 10 to 11 runs, or about 3 to 4 hours of play. That's on the long side for a baseline piece, but fair, and it makes Robux an obvious shortcut without being a wall. The cheap first rung (shoes at about 500) brings the first purchase into the first couple of hours, the moment a player decides the game rewards them.

### What's sold

Starting prices to test, not settled: the owner sets the final ones.

| Thing | Kind | Starting price | Notes |
| --- | --- | --- | --- |
| Marks, small | Developer product | 100 R for 1,000 Marks | 10 Marks a Robux (the owner): a baseline clothing piece |
| Marks, medium | Developer product | 400 R for 4,400 Marks | 10% bonus |
| Marks, large | Developer product | 1,000 R for 12,000 Marks | 20% bonus |
| Starter pack | Developer product, once per player | 99 R: a jacket and 1,000 Marks | About 250 R of value; shown once, after your first run; the jacket is from the first paid line |
| Arcade play | Developer product, or Marks | **5 R**, or **100 Marks** | The owner's prices; one free play a day |
| Arcade, 10 plays | Developer product | 40 R | |
| Arcade unlimited | Game pass | **250 R** | The owner's price |
| Clothes | Marks | Shoes 500-700, bottoms 800-1,000, tops 1,000, jackets 1,500-2,000 | Round the owner's baseline of about 1,000 (about 100 R); shoes are the cheap first rung |
| Torch looks | Marks | 1,000-2,000 | |
| Car bits | Marks | 300-1,000 | |
| Photo booth frames | Developer product | 50-200 R | Design doc: hub decor |
| Gifts | Any Robux item, bought for a friend in the same lobby | Same price | Delivered as a wrapped box they open |
| Supporter pack | Game pass | 500-1,000 R | Design doc: a cosmetic bundle and a name in the credits |
| Private servers | Roblox's own | The owner's | Already on (the owner) |
| Seasonal items | Marks or Robux | | Limited time; later, after launch |
| Real Roblox avatar items | Avatar items sold in the game | | Later: needs Roblox's item-creator eligibility and upload fees |
| Season pass ("Case Files") | Game pass | 400-800 R | Design doc: 2-3 months after launch |

For scale: the developer keeps 70% of the Robux spent, and DevEx pays about $0.0038 per Robux kept (design doc section 9). A 5 R play is worth about 1.3 cents; the 250 R pass about 67 cents.

### Immersive ads

Roblox's immersive ads, put where a mall really had ads:
- **Backlit poster lightboxes** on the court's walls and down the concourse towards the shutter (image ads).
- **Film poster frames** on the video store's front, "coming soon" (image ads).
- **The TV wall** in the electronics window (video ads; autoplay or click-to-play decided in a test).
- **Never in** the garage, on the arcade machines, in the boutique's booth, or anywhere in the run.
- **No portal ads** (they send players to another game, out of your lobby) and **no rewarded full-screen video** (not immersive).
- **Roblox's rules** (Creator Docs, Immersive ads): a billboard is an `AdGui` on the face of a part between 8 x 4.5 and 32 x 18 studs, with nothing in front of it and no other SurfaceGui on that face.
  - To be paid, the game must be public, the owner ID-verified with 2-step verification, the maturity questionnaire approved, and the game at 2,000 unique monthly visitors.
  - Players who can't be shown ads see a fallback. For them (`PolicyService:GetPolicyInfoForPlayerAsync`, `AreAdsAllowed`), each frame shows our own 1988 poster instead, so the mall looks the same to everyone.
  - Our posters need images uploaded to the owner's account, so ask first.

### Never sold

The design doc's section 9 list stands: no extra lives or revives, nothing that slows, stuns or hides you from the Guest, no hints, no Clearance, no paid random boxes, nothing that makes a squad's run easier than a free squad's.

## Under the hood

### One place, runs in reserved servers

A 50-player lobby can't hold runs: each run builds its own house. Runs go to **reserved servers of the same place** (the owner, 2026-10-15, over a second place):
- **Public servers are lobbies** (the place allows 60 players; the plan's 50 fits).
- **A reserved server is a run:** a private copy of the place that only the squad sent to it can enter.
- **A paid private server** (Roblox's own) **is a lobby** for its owner's friends, and its runs go to reserved servers too.
- **In Studio** a server is both, as today, so Studio play tests keep working (teleports don't work in Studio).

Why one place: one place to publish and one Rojo sync. With two, every update must be published to both, and a forgotten one runs old code: the "is it on the new build?" problem. The cost is small: one set of place settings and analytics for both, and a run server also holds the lobby's map (it serves as the squad's waiting room while they arrive).

- **Lobby to run:**
  - When the car leaves, `TeleportService:ReserveServer(game.PlaceId)` reserves a server.
  - The contract (location, difficulty, night, the squad's user ids) goes into a MemoryStore hash map keyed by that server's private server id, and `TeleportService:TeleportAsync` sends the squad with its access code.
  - Teleport data passes through the client, so it's never trusted for the contract.
  - The run server reads its contract by `game.PrivateServerId`, waits for its squad (about 30 s, then starts with whoever came), and calls `RunOrchestrator:StartRun` as today.
- **Run to lobby:** the squad is teleported back to a public server together. A group teleport should land in one server (to be confirmed in the live test); it's then given a car.
- **Failures:** a teleport that fails is retried, then the squad is put back in its car with a note (today: back in the hub).
- **Profiles:** every server shares the same DataStores. `DataService` hands a profile over before a teleport: it saves, releases the session lock and stops saving that player, so the arriving server can lock it at once.
- **Roblox settings:** none to change; the place allows 60 players and a reserved server only ever receives its squad.
- **A switch:** `Config.Places.ReservedRuns` turns it off, so a live problem can go back to runs in the lobby's own server without a code change.

This is CLAUDE.md's Next item 7 (the hub, reserved servers), brought forward. MemoryStore matchmaking across lobbies isn't needed at first: 50 players in a lobby fill cars on their own.

### Data (profile version 2)

`DataService`'s template grows, with a migration from version 1:
- `Owned` (garments, torch looks, car bits, frames);
- `Wearing` (top, bottom, shoes, torch);
- `ArcadeCredits`, `Tickets`;
- `StarterPack` (bought once);
- `Receipts` (recent purchase ids, so a purchase is never granted twice).

### Purchases

- `Services/MonetizationService` (named in design doc section 7) owns `MarketplaceService.ProcessReceipt`: it grants and saves before it reports the purchase granted, and grants each receipt once. It also checks game passes (`UserOwnsGamePassAsync`, and the purchase-finished signal).
- A `ShopService` spends Marks, with prices only on the server.
- Product and pass ids, created by the owner in Creator Hub, go in one data module (`Data/Products`).
- Purchases can be tested in Studio without spending Robux, once Studio's API access is on.

### The arcade's games and scores

- **Each game is pure, seeded logic with a fixed tick** (`Logic/Arcade/HouseCall`), spec'd under Lune like the rest of `Logic`.
- **The player's client runs and draws it** on the cabinet screen (an EditableImage, as the TV's static does) and sends its button presses when the game ends. The server replays them for the score, and a score the replay doesn't reproduce is dropped. A worldwide board gets fake scores within days without this.
- **Spectating comes for free:** nearby clients run the same game from the same presses.
- **Boards:** OrderedDataStores per machine, all-time and weekly.

### 50 players

- **The cost:** a dressed player is about 40k triangles, so 50 are about 2 million, unmeasured on a phone.
- **Far players drawn simply:** on each client, players beyond a distance drop their garment meshes and show their outfit's colours, the fallback OutfitService already has (`Logic/Outfit.palette`).
- **Measure from the first build of the shell:** F2 `perf`, extended as V9 planned, with a 50-dummy lineup. Look at StreamingEnabled for the lobby place.
- **Voice** stays proximity chat.

## Phases

Each phase ends as the others do: a report in `docs/progress/<date>-lobby-lb<n>/`, a section here, TCs at the end of `docs/TESTING.md`.

- **LB0, foundations.** *Done (2026-10-15, build .199):* Studio's API access checked. Studio given its own DataStores: `DataService.StoreName` adds `Config.Data.StudioSuffix` in Studio, and every new store goes through it, so play tests never touch live profiles. Checked in play, with a marker of 1234 Marks put in the Studio profile beforehand: the hub showed it (load); stopping play saved and released the lock; an immediate restart loaded at once; the live profile was untouched (last written three days before). TC-303. *Done (build .200):*
  - **Server roles** in place of a second place (the owner, 2026-10-15): `Logic/ServerRole`, `Services/PlaceService`, `Config.Places` with the `ReservedRuns` switch.
  - **The contract** through MemoryStore (`Logic/RunContract`).
  - **Profiles handed over** for each teleport (`DataService:HandOff`, `TakeBack`).
  - **Profile version 2** (`Logic/Profile`).
  - **`MonetizationService`** with receipts (`Data/Products`, no ids yet).
  - **F2 `role`,** and 14 new tests (671).
  - **Checked in Studio** with ServerStorage's `DebugRole` attribute:
    - the default role is `both` with no warnings, and the Studio profile upgraded to version 2;
    - `lobby`: Ready, then "The car wouldn't start" (Studio can't reserve servers: HTTP 403), Ready off (TC-305);
    - `run`: the contract left and read back, "1 of 1 of the squad here", the run started without Ready; after F2 `end` and the Dossier's 30 s the teleport back failed (none in Studio), and the server became a hub where Ready started a run in place; the profile was taken back and released on stop (TC-304).

  **Live, solo (the owner, 2026-10-15, build .200 published): "the teleporting works".** Report: `docs/progress/2026-10-15-lobby-lb0/`. *Left:* the same with friends (TC-306 with two or three clients), and purchases once the products exist in Creator Hub.
- **LB1, the mall's shell,** in two steps (Claude's suggestion, the owner's go-ahead 2026-10-15):
  - **LB1a, a walkable grey box,** *done* (build .201, `docs/progress/2026-10-15-lobby-lb1a/`):
    - the layout as data (`Data/Mall`, `World/MallBuilder`, rules in `Logic/MallLayout`, spec'd);
    - the court with its fountain and skylight, the four shopfronts with grilles and neon signs, the diner and the giant shutter at the hall's two ends, the chained glass doors, a dead shop;
    - the garage through the video store, with the contract table until LB2;
    - rough warm light, rain on the skylight;
    - a run server builds only the garage, as its waiting room;
    - walked in play: spawn to garage 7.9 s, the whole hall 9.6 s.

    For the owner to judge (the report): the fountain on the way to the video store, the shutter as a grille, the garage's light, the court's size.
  - **The story pass** (build .202; the owner: "it doesn't really read as an abandoned mall with a secret community of investigators in it ... dim the lights in there except from the stores and the ads, more environmental storytelling", the generator their idea): the mall's own lamps dead; light only from the shops, the ad lightboxes, the investigators' bulb strings and work lamps, all on their generator in the garage, its cables taped over the floor to each lit place; their cardboard signs and floor tape; the dead mall's dust sheets, dry fountain, fallen tiles, boarded doors; the shutter taped off. The report's "story pass" section and `story/` screenshots.
  - **The mall alive** (build .203; the owner's picks 1 to 3 of Claude's ideas): its sounds (the generator, fluorescents, a drip into the bucket, CB chatter, the arcade; shortlists in `Assets.Mall` the owner picks by ear with F2 `mallsound`), lightning over the mall through the skylight and the main doors, and the generator's brownouts. Ideas 4 to 8 (readable lore, the squads' photo wall, live screens, seeds for the shutter, the loading dock) wait.
  - **The grandeur pass** (build .205; the owner: it "felt a little small for a mall ... doesn't really have that encapsulating grandeur"):
    - grown up, not out, so the walks stay as short: the court two storeys high, with a dark gallery round three sides and the dead upper shops;
    - a glass barrel vault over the court, a dead chandelier, banners, the clock stopped at 9:47;
    - the east end a two-storey grille, with the dead concourse behind it two storeys and longer, its escalators stopped.

    The owner's calls settled the same day: the fountain stays where it is, and the shutter stays a see-through grille. On their note to keep the ad areas "intact and not messed up looking while still looking good and on theme":
    - the lightboxes are kept clear of columns and furniture, from straight on and up to 45 degrees off (spec'd in `MallLayout.adBlockers`), and the columns stand only between shopfronts (`columnClashes`);
    - the west boxes are larger;
    - the placeholder is a readable, yellowed "THIS SPACE AVAILABLE" panel instead of a Neon glare.

    The report's "grandeur pass" section and its `grandeur/` screenshots; TC-309.
  - **LB1b, the real look:** a Blender batch for the mall (shopfronts, grilles, the fountain, benches, the diner's booths and counter, lightboxes, signs, the skylight, and now the vault, the gallery and its rail, the chandelier, the escalators), imported by the owner as before; the lighting pass; the 50-player measurement. The owner walked .205 ("the height works") and started it the same day. In batches, as the house's kit went (kit.py, `kitlib/mall`):
    - **`mall1`, the court** (*done*, build .207: imported by the owner and seen in place), what every player sees close up each visit, 14 pieces:
      - the bench, the planter and its dead ficus;
      - the fountain's basin (drained, stepped into: `hollow`) and its centrepiece;
      - the directory, with the mall's map and YOU ARE HERE;
      - the photo booth and a shopping cart;
      - the two lightbox cases, each made round its ad's face so the bezel never covers it;
      - the shopfronts' grille box;
      - the gallery's column, its parapet with the handrail (laid in lengths along each run), and the dead chandelier.

      `World/MallBuilder` dresses each over its grey box once the meshes are in (Data/Mall `kit`, `Mall.KitGroups`; Data/Kit `Parts`).
    - **`mall2`, the shops** (*done*, build .209: imported by the owner and seen in place; started 2026-10-15; the owner: "be very deliberate with placement in the shops": each shop laid out by hand in the grey box first, checked from above and at eye level, kept honest by `MallLayout.misplaced`, then modelled to it; 31 pieces plus the house's dress form and coat rack):
      - the diner's booths, counter, stools and menu boards;
      - the video store's shelves and the NEW RELEASES wall;
      - the arcade's cabinets and the prize counter;
      - the electronics store's TVs;
      - the boutique's racks and the changing booth.
    - **`mall3`, the garage and the dead mall** (*done*, build .211: imported by the owner and seen in place; started 2026-10-16: the garage laid out by hand too, its desk, diesel and tyres; 33 pieces plus the house's car and workbench; the vault's ribs and ends, the escalators, real neon tubes for the five shop names, the roll-up shutter for every shutter):
      - the investigators' generator, cots, desk, case board and tool bench;
      - the payphone;
      - the vault's frame;
      - the escalators and the upper fronts;
      - the neon signs' letters.
    - **The lighting pass and the 50-player measurement** (*done*, build .212): the garage's way out lit (a strip over the bays, a caged lamp over the roll-up door), shadows following the preset, the lamps aimed; F2 `crowd <n>` (dressed stand-ins over `MallLayout.openSpots`), `perf` and the overlay's render line. A full lobby holds 60 fps on the owner's PC (about +2 ms CPU, +1 ms GPU, +12 MB); a phone and live networking are the owner's checks. **LB1b is done.**
- **LB2, parties and the video rental** (*done*, build .213, 2026-10-16; report `docs/progress/2026-10-16-lobby-lb2/`). The cars, seats, the dashboard, the windscreen sign, friends-only, the honk, Roblox parties, the payphone, coming back to your car. The tape shelf.
  - Built: `Logic/Cars` and `Logic/Homecoming` (spec'd), `Services/CarService`, `Services/RentalService`, `UI/Dashboard`. The Ready button, the majority timer and the contract table are gone.
  - The sign is in the rear window, which faces the dock where players walk in (the cars nose to their doors).
  - The cars are numbered, not coloured: the six are the house's one maroon wagon, its paint baked in. Painting them goes with the pegboard's paint jobs (LB4), which need a re-exported car with a tintable body.
  - A squad stranded on its run server goes back in a car there, its case in the deck.
  - Left for later: the teleport screen (the road at night through the windscreen, rain and wipers). Today the car drives out of its door and Roblox's own teleport screen follows.
- **LB3, the boutique and Marks** (*built*, build .215, 2026-10-16; report `docs/progress/2026-10-16-lobby-lb3/`; the six garments' meshes wait on the owner's look at the sketches, then one wardrobe batch to import). Owning and wearing clothes, the changing booth, buying with Marks, gifts, the Marks packs and the starter pack. The first paid line: the six garments (the boutique's table), sketched first for the owner to swap any, then one wardrobe batch. The new Marks: `marksForRun` scaled down to about 150 for a strong escape, set from `botrun` numbers; `xpForRun` at today's pace; double Marks on the first escape of the day.
  - Built: `Logic/Closet` (spec'd: owning, buying, wearing, trying on), profile version 3, `Services/ShopService` (the fitting room, the till, the starter pack's slip, gifts' wrapped boxes), `UI/Boutique`; `OutfitService` dresses everyone in what they own and chose; `Config.Pay` and `Logic/Progression` (Marks and XP as two sums, the daily double; spec'd).
  - The sketches (`tools/blender/kitlib/wardrobe.py`, the sheet in the report): every new top is worn out over the trousers and the parachute pants stay slim under the jackets' hems, so none of the eight free garments changed (every old piece's vertices hashed the same). High-tops are worn in place of the trousers' short shin piece (`over`): the shaft rises into the trouser thigh's foot. A shaft round the trousers' hems came out a bucket.
  - The fitting room stands you at the booth's curtain, not inside it: the drawn curtain hid you, and leaving pushed you out through its back.
  - The till shows each product's starting Robux price; Roblox's own prompt shows the real one. Nothing can be bought for Robux until the owner creates the products in Creator Hub and their ids go in `Data/Products`.
- **LB4, electronics and the car bits.** The torch's first three looks (electronics' table), sketched first, then a Blender batch. The car bits on the pegboard.
  - *Sketched* (2026-10-16, `docs/progress/2026-10-16-lobby-lb4/`): the three torches round today's lens, switch and grip (`kitlib/toolkit.py`), and a proposed first set of car bits, all outside the car since its windows are dark glass with nothing behind (`kitlib/carbits.py`: four paints, woodgrain sides, whitewalls, a roof rack and luggage, a spotlight and CB aerial, a bumper sticker, radio stations). Waiting on the owner's picks and prices, and whether woodgrain becomes a bit.
- **LB5, the arcade and the records.** HOUSE CALL, credits, the free daily play, plays for Marks, the pass, the bundle, the replay check, the boards, spectating, the closed prize counter. The diner's two boards (Normal and Hard; fastest and longest; solo and squad; short night; real runs only).
- **LB6, ads and the rest.** The ad lightboxes, posters and TV wall with our own posters as their fallback, the photo booth and its frames, the supporter pack.
- **After launch:** more clothes, opening the prize counter and the weekly arcade prize, NIGHT DRIVE, seasonal items, whatever the shutter becomes, real avatar items, the season pass, joining a party member in another lobby (`SocialService:GetPartyAsync` sees members across servers).

LB0 comes first because purchases and teleports both depend on it, and they can only be checked in the live game.

## What the owner will be asked

- ~~Turn on Studio's access to API services~~ (done, 2026-10-15).
- ~~Make a second place~~ (not needed: runs go to reserved servers of the one place, the owner's choice, 2026-10-15).
- Create the developer products and game passes in Creator Hub and send Claude their ids.
- Approve and import each Blender batch, as in the visual rework.
- Set the final prices.
- Run the live tests: teleports, purchases (Roblox's test purchases), parties with friends.
- For ads: ID verification with 2-step verification, the maturity questionnaire, and the game public at 2,000 monthly visitors.

## Open questions

None left before LB0. The sketches at LB3 and LB4 are the next choices the owner makes.

Settled (the owner, 2026-10-15): the boutique opens with a small first paid line (the six garments and three torch looks in their tables); the new Marks economy (Money) with 100 Marks an arcade play; the diner's two boards. For later: what the shutter becomes (closed until then), the mall's name (atmosphere first), the weekly arcade prize and the prize counter (closed until more customisation is planned).
