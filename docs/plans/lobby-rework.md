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

## What's there today

- One place holds the hub and the run (`Services/LobbyService`, `Services/RunOrchestrator`). The hub is a 56 x 56 stud room: a contract table toggles the difficulty, everyone presses Ready, and a majority starts after 30 s (`Logic/LobbyRules`). Its screen is a case folder (`UI/Lobby`).
- Marks are earned every run, win or lose (`Logic/Progression.marksForRun`): about 100 for a lost run that got somewhere, about 300 for a good win. Every Mark earned also adds Clearance XP (`DataService`). Nothing spends Marks yet.
- The wardrobe (`Data/Wardrobe`, `Services/OutfitService`): eight garments (four tops, two bottoms, two shoes), and outfits are handed out by the order players arrive, so a squad always looks different at a glance. No prices, no ownership.
- No purchases, game passes or teleports exist anywhere in the code.
- Studio's API access is on since 2026-10-15 (the owner), so DataStores should work in Studio play tests now. Before that they failed with 403. Studio's play tests then share the live game's stores, so LB0 gives Studio its own.

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
- **Today's Ready button and majority timer go.** The car is the ready-up. `Logic/LobbyRules` stays for Studio's one-place mode (below) until the cars replace it there too.

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
  - **Which six:** the 80s looks the free set doesn't cover yet, proposed with sketches before the batch is built (the owner picks, as with V3's golden area). The starter pack's jacket is one of the two jackets.

### Electronics: the torch's looks

- **The torch is the one tool that's always yours** (on F, with your own arms), so its looks sell first: a chrome torch, a camping lantern, a rubber work light. The found tools (lantern, radio, crowbar, bolt cutters...) pass between hands in a run, so their looks would swap owners; they wait.
- **Later:** the ping and callout looks (design doc section 9).
- **The TV wall in the shop window** is where the video ads go (see Ads).

### Arcade

- **Machines you walk up to:** press E and the camera settles on the screen. Others can watch over your shoulder.
- **A play costs a credit.** The owner's prices: **5 Robux a play** and a **250 Robux unlimited arcade game pass**, plus a 10-play bundle for 40 Robux.
- **One free play a day** for everyone (the owner's yes), shown on each machine ("1 free play today"). It resets at midnight UTC.
- **Plays for Marks, priced to make Robux the better deal:** Claude suggests **75 Marks a play**, to tune. At the small pack's rate a 5 Robux play is worth 25 Marks, so 75 is three times that: supporting the game is clearly cheaper, yet a lost run (about 100 Marks) still earns a play and a good win (about 300) about four.
- **High scores on every machine,** all-time and weekly, across all players, shown on the cabinet's attract screen under Roblox display names (typed initials would need Roblox's text filter). A weekly prize waits until more customisation is planned (the owner).
- **The prize counter is there but closed down** (the owner): grille down, a "closed" sign, a dust sheet over the prizes. No tickets are given until it opens, so nothing piles up for a design that may change. When it opens, scores earn tickets for silly cosmetic prizes, and tickets are never sold.
- **The games are original,** never clones (the big names are trademarked). The first: **HOUSE CALL**, a maze where the Guest freezes while you face him, the game's first rule as an arcade game. Later: **NIGHT DRIVE**, a road dodger in the rain. Each machine is a small game of its own to build, so one comes first.

### The garage: the investigators' room

The cars, the payphone, and a pegboard of car bits (wood panelling, paint, fuzzy dice, the radio station that plays), which the squad and the whole lobby see. The case board shows your Clearance and what it unlocks next; the Dossier sits on a desk. Later, a practice run starts here (Next item 6, the tutorial).

### The diner: the run records

An 80s diner at the hall's end: booths, a counter with stools, neon in the window, the place a squad sits between runs. Its menu board holds the records (the owner's two):
- **The fastest completed runs,** from the arrival to the run out of the front door.
- **The longest completed runs:** the squads that held on longest and still got out. Stalling can't farm it, because a run that drags on reaches Drift 100 and the Reckoning, a hunt that never ends.

Each entry shows the squad's names, its size and the time. The time comes from the server, which already measures every run (`RunOrchestrator`, `run.started`), so these boards need no cheat check.

The house changes with the night (short or full: `Config.Mansion.Profiles`), the difficulty and the squad's size, so one list would compare different races. Claude suggests:
- lists for each difficulty on the default short night first, with the full night later;
- solo split from squads if solos turn out to dominate.

The daily contract, when it comes, is the fairest race of all (one house for everyone).

### The court

The fountain, benches, the mall directory ("you are here", which doubles as the lobby's map), and the photo booth. The booth takes a strip of your squad with ready-made frames and stickers, never drawing or typing: free-form player creation raises the minimum age (design doc section 9).

## Money

### Marks

- **One currency for cosmetics.** Marks are earned in runs and sold for Robux. Clothes, torch looks and car bits are priced in Marks, so free players can reach almost everything, and payers get there sooner.
- **Bought Marks never add Clearance XP.** Clearance unlocks contracts, and selling it would be selling progress. Today `DataService` adds a run's Marks to XP; a purchase adds Marks only.

### What's sold

Starting prices to test, not settled: the owner sets the final ones.

| Thing | Kind | Starting price | Notes |
| --- | --- | --- | --- |
| Marks, small | Developer product | 100 R for 500 Marks | About three runs' worth |
| Marks, medium | Developer product | 400 R for 2,200 Marks | 10% bonus |
| Marks, large | Developer product | 1,000 R for 6,000 Marks | 20% bonus |
| Starter pack | Developer product, once per player | 99 R: a jacket and 1,000 Marks | Shown once, after your first run; the jacket is from the first paid line |
| Arcade play | Developer product, or Marks | **5 R**, or 75 Marks (to tune) | The owner's price; one free play a day |
| Arcade, 10 plays | Developer product | 40 R | |
| Arcade unlimited | Game pass | **250 R** | The owner's price |
| Clothes | Marks | Shoes 300-600, bottoms 500-900, tops 800-1,500, jackets 1,500-2,500 | |
| Torch looks | Marks | 500-1,500 | The design doc's 100-300 R, in Marks |
| Car bits | Marks | 200-1,000 | |
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

### Two places

A 50-player lobby can't hold runs: each run builds its own house. So the universe gets two places:
- **The lobby** (the start place, 50 players).
- **The run** (4 players, reserved servers).

Both are published from the same Rojo build. Each server knows its role from `game.PlaceId` (`Config.Places`), and in Studio, or under an unknown place id, it plays both roles in one server as today, so Studio play tests keep working (teleports don't work in Studio).

- **Lobby to run:**
  - When the car leaves, `TeleportService:ReserveServer` reserves a run server.
  - The contract (location, difficulty, night, the squad's user ids) goes into a MemoryStore hash keyed by that server's private server id, and `TeleportService:TeleportAsync` sends the squad.
  - Teleport data passes through the client, so it's never trusted for the contract.
  - The run server waits for its squad (about 30 s, then starts with whoever came) and calls `RunOrchestrator:StartRun` as today.
- **Run to lobby:** the squad is teleported back together. A returning group lands in one lobby server (to be confirmed in a live test) and is given a car.
- **Failures:** a teleport that fails is retried, then the squad is put back in its car with a note.
- **Profiles:** both places share the universe's DataStores. `DataService`'s session lock has to hand over cleanly on a teleport (save and release on leaving; wait for it on arrival).
- **Roblox settings:** the lobby place at 50 players, with a few slots left for friends joining (the place's server-fill setting); the run place at 4.

This is CLAUDE.md's Next item 7 (the hub place, reserved servers), brought forward. MemoryStore matchmaking across lobbies isn't needed at first: 50 players in a lobby fill cars on their own.

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

- **LB0, foundations.** Studio's API access (on since 2026-10-15): checked in a play test that a profile saves and loads. Studio given its own DataStores (`DataService`'s store name with a Studio suffix), so play tests never touch live profiles. The second place (the owner publishes it in Creator Hub; Claude walks them through). Place roles with Studio's one-place mode. Profile version 2. `MonetizationService` with receipts. The contract handoff and the group teleports out and back, checked in a live test.
- **LB1, the mall's shell.** The court, the four shopfronts with grilles, the diner, the garage, the shutter (closed until the owner decides), the warm light and the rain on the skylight, the signs. A Blender batch for the mall (shopfronts, grilles, the fountain, benches, the diner's booths and counter, lightboxes, signs, the skylight), imported by the owner as before. The 50-player measurement.
- **LB2, parties and the video rental.** The cars, seats, the dashboard, the windscreen sign, friends-only, the honk, Roblox parties, the payphone, coming back to your car. The tape shelf.
- **LB3, the boutique and Marks.** Owning and wearing clothes, the changing booth, buying with Marks, gifts, the Marks packs and the starter pack. The first paid line: six garments, picked by the owner from sketches, in one wardrobe batch.
- **LB4, electronics and the car bits.** The torch's first three looks (a Blender batch), the car bits on the pegboard.
- **LB5, the arcade and the records.** HOUSE CALL, credits, the free daily play, plays for Marks, the pass, the bundle, the replay check, the boards, spectating, the closed prize counter. The diner's records of the fastest and longest escapes.
- **LB6, ads and the rest.** The ad lightboxes, posters and TV wall with our own posters as their fallback, the photo booth and its frames, the supporter pack.
- **After launch:** more clothes, opening the prize counter and the weekly arcade prize, NIGHT DRIVE, seasonal items, whatever the shutter becomes, real avatar items, the season pass, joining a party member in another lobby (`SocialService:GetPartyAsync` sees members across servers).

LB0 comes first because purchases and teleports both depend on it, and they can only be checked in the live game.

## What the owner will be asked

- ~~Turn on Studio's access to API services~~ (done, 2026-10-15).
- Make the second place in Creator Hub and publish to it; set the two places' player counts.
- Create the developer products and game passes in Creator Hub and send Claude their ids.
- Approve and import each Blender batch, as in the visual rework.
- Set the final prices.
- Run the live tests: teleports, purchases (Roblox's test purchases), parties with friends.
- For ads: ID verification with 2-step verification, the maturity questionnaire, and the game public at 2,000 monthly visitors.

## Open questions

1. **A play's price in Marks:** 75 is Claude's suggestion.
2. **How the run records split:** by difficulty on the short night first, and solo apart from squads? (Claude's suggestion; the diner section has why.)
3. **Which six garments and three torch looks** make the first paid line (sketches first, at LB3 and LB4).

Settled (the owner, 2026-10-15): the boutique opens with a small first paid line. For later: what the shutter becomes (closed until then), the mall's name (atmosphere first), the weekly arcade prize and the prize counter (closed until more customisation is planned).
