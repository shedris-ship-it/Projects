# The lobby rework, LB0: the foundations (builds `2026-10-15.199` and `.200`)

The owner: "Start LB0: check the Studio API access with a save in a play test, give Studio its own DataStores, then walk me through making the second place." Then, offered the choice: "Go with reserved servers of the one place, no second place." The plan is `docs/plans/lobby-rework.md`; this is its first phase.

## Studio's own stores (build .199)

The owner turned on Studio's API access on 2026-10-15. From then on a Studio play test would have saved into the live game's profiles, and a live server's session lock would have held the owner's profile in Studio.
- `DataService.StoreName` gives every store the game opens Studio's own name in Studio (`Config.Data.StudioSuffix`, `_Studio`): the profiles are `ConsensusProfiles_v1_Studio` there and unchanged live. New stores (the boards, the contracts) go through it too.
- **Checked in play.** A marker of 1234 Marks was put into the Studio profile beforehand, and the hub showed it (it loaded from the Studio store). Stopping play saved and released the lock. An immediate restart loaded in 0.3 s; that was the risk, since a lock left behind makes the next load wait and then come up blank. The live profile (535 Marks, 6 runs) was untouched, last written three days before. The marker was reset. TC-303.

## One place, runs in reserved servers (build .200)

Offered a second place for runs, the owner took Claude's recommendation instead: runs go to reserved servers of the same place. That means one place to publish and one Rojo sync, without the "is it on the new build?" trap of keeping two places in step.
- **Each server's job** (`Logic/ServerRole`): a public server, or a paid private server, is a lobby; a reserved server is a run; Studio is both, as before, since teleports don't work there. ServerStorage's `DebugRole` attribute (`lobby` or `run`) tries either role in a Studio test. `Config.Places.ReservedRuns` off puts runs back in the lobby's own server, a switch for a live problem.
- **Lobby to run** (`Services/PlaceService`):
  - When the hub's countdown ends, the lobby reserves a server of the same place.
  - It leaves the run's contract (the squad's user ids, difficulty, location, night; `Logic/RunContract`) in a MemoryStore hash map keyed by that server. Teleport data passes through the client, so it's never trusted for this.
  - It hands the squad's profiles over and teleports them.
  - The run server reads its contract, waits up to 30 s for the whole squad, and starts the run.
- **Run to lobby:** after the run the squad is back in the waiting room with its Dossier, and 30 s later (`Config.Places.ReturnSeconds`) everyone is teleported to a public lobby together. If that fails, the server becomes a hub, so nobody is stranded.
- **Profiles across a teleport:** `DataService:HandOff` saves, releases the lock and saves no more on that server, so the next one can lock the profile at once; `TakeBack` re-locks it when a teleport fails (also on Roblox's `TeleportInitFailed`).
- **Profile version 2** (`Logic/Profile`, which now holds the shape and upgrades `DataService` had): what you own and wear, arcade credits, tickets, the starter pack, and recent purchase receipts. A version 1 profile keeps everything and gains the new fields.
- **Purchases** (`Services/MonetizationService`, `Data/Products`): `ProcessReceipt` applies a grant and its receipt together, saves, and only then tells Roblox the purchase is granted. If the save fails, both are undone and Roblox asks again later, so nothing is granted twice or lost. Bought Marks never add Clearance XP. No product has an id yet, so nothing can be bought until the owner makes them in Creator Hub.
- F2 `role`. 14 new tests (671 in 102 specs).

## Checked

- **Studio, the default role:** `server role: both`, 42 services, no warnings; the Studio profile upgraded to version 2.
- **Studio, `DebugRole` lobby:** Ready, the countdown, then "The car wouldn't start. Ready up to try again." (Studio can't reserve servers: HTTP 403); Ready off; the profile kept. TC-305.
- **Studio, `DebugRole` run:**
  - the contract was left and read back, "1 of 1 of the squad here", and the run started with no Ready;
  - after F2 `end` and the Dossier's 30 s, the teleport back failed (there are none in Studio), and the server became a hub where Ready started a run in place;
  - the profile was taken back, and released when play stopped.

  TC-304. The attribute was removed afterwards.
- **Live, solo (the owner, 2026-10-15, after publishing build .200):** "the teleporting works".
- **Not yet:** the same with friends (TC-306 with two or three clients: the squad lands in one server and comes back together); purchases, once products exist.
- Gate A isn't affected (nothing in the builder changed) and wasn't re-run.

## Known limits, for the passes that follow

- The old hub still starts on half the server being ready (`Logic/LobbyRules`), which is awkward with many players in one lobby. LB2's cars replace it.
- A squad member who arrives after the 30 s wait sits in the run server's waiting room until the run ends.
- A run server also holds the lobby's map, as the squad's waiting room. When LB1's mall replaces the hub, a run server may want only a small waiting room.
