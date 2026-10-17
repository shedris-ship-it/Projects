# Footsteps without warnings, and the lobby's "echoing footsteps" (builds .223 and .224, 2026-10-16)

Two things, in Studio play on the local `Consensus.rbxlx`:

1. Studio's Output showed "ContentId: rbxassetid://... failed due to: Asset type does not match requested type" for the footsteps (reported by the lobby session).
2. The owner: "also look into echoing footsteps in the lobby", then: "I meant weird echos that are there and shouldnt be, like following footsteps".

## 1. The footstep warnings: the warm-up, not the sounds

All 23 footstep samples (7 wood, 6 carpet, 6 tile, 4 concrete; `Assets.Footsteps`, and `Assets.Sounds.Footstep`, the Guest's, which is wood #1) warned in play, not only wood and carpet. None of them is broken:

- `MarketplaceService:GetProductInfo` lists every one as Audio (asset type 3), by Diman_x86 and iLoveSwiss_0 as before.
- Each one loads and plays in a Sound on the client (`IsLoaded`, a length, `AssetFetchStatus.Success`).
- The cause is `FootstepController:Start`'s warm-up: `ContentProvider:PreloadAsync` was given the ids as bare strings, and Roblox fetches a bare string as an image. Tried in play: a string preload of a footstep id and of a mall sound that had never warned both failed with this exact warning; the same ids through Sound instances came back Success with no warning.
- It mattered a little beyond the noise: a failed fetch marks the id `Failure`, and `judge` drops a sample whose fetch failed if its Sound hasn't loaded 2.5 s after a step. On a slow connection that could have dropped good samples, and with every sample on a surface dropped, that surface plays the stock plastic step.

The fix: the warm-up preloads a Sound for each id, then destroys them. No new sounds were needed, so there's no shortlist for the footsteps and nothing for the owner to pick there.

Checked in play (build .223 code, before the id bump): no footstep warnings; in the house's hall, all 7 wood samples loaded and played on WoodPlanks; in the upper hall (room 13), all 6 carpet samples on Carpet; in the lobby, the tile set on the court's marble and the concrete set in the garage. No "footstep sample never loaded" lines.

Other warnings seen, not this task's:
- `rbxassetid://203785492`, "Pop Close Sound" by Zyleak: no Sound, image or attribute in the place uses it, and it comes with Roblox's core interface warnings (UIBlox), so it's Roblox's own.
- `127810179737709` and `72889849302079`: texture packs the owner imported today (created 12:57 on 2026-10-16), "pending moderation". They should clear on their own once Roblox reviews them.

## 2. Footsteps that seem to follow you in the lobby

**A misreading first (build .223, taken out at .224).** The first message read as a wish for the mall to echo, so .223 gave each mall room a reverb kind with a shortlist (Court Hangar, Shop Room, Diner Room, Garage ParkingLot) and F2 `mallecho`. The owner then said they meant unwanted echoes, so .224 takes all of that out: the lobby is `LivingRoom` everywhere again, as before .223 (a fairly dry preset). No `mallecho`, no `Mall.Echoes`, no `MallLayout.roomAt`.

**What was looked for, solo in Studio play, in the court (build .223 code, the character walking):**
- Every sound that started anywhere in the game while walking: only your own steps (one sound per stride, on the tile set over the court's marble), the drip into the tin bucket (7 to 16 studs off, every 1.4 to 4 s, `Config.Mall.Sounds.Drip`) and a thunderclap. No second step, nothing behind you.
- The footstep samples' own shape (loudness every 0.05 s): each is one hit that's quiet within about 0.25 s, so there's no echo baked into them. Two have a heel and toe 0.1 s apart (concrete 3, carpet 1).
- Roblox's own character sounds: still replaced by the empty `RbxCharacterSounds` (no looping step of theirs).
- The always-on loops (the Drift layers, the heartbeat, the breath, radio static): all at volume 0 in the lobby.
- SoundService: no acoustic simulation, no echo or reverb effects on the groups, Doppler at the default.
- The house's "footsteps behind you" phantom (`PerceptionController`, a Drift rule) only fires within 35 studs of its spot in the house, 1,400 studs from the mall, and shows a caption.
- Walking (speed 12) is under the sprint threshold (15), so no thud is layered under each lobby step unless you sprint.

**Likely cause: Studio's multi-client test.** With Test → Clients and Servers, every client window plays its own audio through the same speakers. Your character's steps play in your window, then again a moment later in each other window (where you're a remote player, its position a beat behind), from a different place. That sounds like an echo trailing your steps, or someone following. In the live game each player hears only their own client, so it wouldn't happen there. Asked the owner how they heard it (solo or several clients in Studio, or live); if it was solo or live, that's a lead this pass didn't find, and the next step is to listen for it together.

### The diner's steps (a gameplay fix under the standing OK)

The lobby's floors were checked for which step set they get. The diner's black and white check is a kit mesh over a grey floor part, and that part was SmoothPlastic, which `Data/Footsteps` doesn't list, so the diner played wooden steps. Its floor part is Marble now (the court's material), unseen under the kit (screenshot checked), so the diner sounds like tile.

Left as they are, for the owner: the electronics store and the dead shop are plain SmoothPlastic floors too, so they also play wooden steps. Changing them to Plastic (the lino) or Marble would show (Roblox's base materials aren't overridden here), so that's the owner's call.

## Checks

`stylua`, `lune run tests/run` (733 tests at .224; 735 with .223's two echo specs), `lune run tests/compile`, `selene`, `rojo build`; Studio play solo, as above. Not checked: with two or more clients, or on the live game.
