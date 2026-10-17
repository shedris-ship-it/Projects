# Footsteps without warnings, and the mall's echo (build .223, 2026-10-16)

Two things, in Studio play on the local `Consensus.rbxlx`:

1. Studio's Output showed "ContentId: rbxassetid://... failed due to: Asset type does not match requested type" for the footsteps (reported by the lobby session).
2. The owner: "also look into echoing footsteps in the lobby".

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

## 2. The lobby's echo

Before: the whole lobby used one reverb, `LivingRoom` (a small furnished room), because `AudioController` only knew the house's rooms. Steps in a two-storey marble court under a glass vault sounded like a lounge.

Now each mall room has a kind (`Data/Mall` rooms' `echo`): Court (the court and the dead concourse), Shop (the boutique, video store, arcade, electronics, the dead shop), Diner, Garage. Each kind has a shortlist of Roblox reverb presets (`Mall.Echoes`), Claude's suggestion first, the old `LivingRoom` last to compare:

| Kind | Candidates (1 plays) |
|---|---|
| Court | Hangar, Arena, Auditorium, ConcertHall, LivingRoom |
| Shop | Room, CarpettedHallway, Hallway, LivingRoom |
| Diner | Room, StoneRoom, Bathroom, LivingRoom |
| Garage | ParkingLot, StoneRoom, Hangar, LivingRoom |

- `Logic/MallLayout.roomAt` finds the room you're in (spec'd); on a doorway's line it returns none and the last room's echo stays, so it doesn't flicker.
- It's still the one global `SoundService.AmbientReverb`, so it colours every sound where you stand (the hum, the radio, the arcade, voices), not just the steps, and never adds a second reverb on the steps (the owner on 2026-10-03: two stacked reverbs were "weird in the bathroom").
- F2 `mallecho <Court|Shop|Diner|Garage> <n>` switches a kind's echo for everyone at once (RunState `MallEcho<Kind>`), like `mallsound`. Checked: the court went Hangar → Arena on `mallecho court 2`, the video store read Room, the garage ParkingLot.
- **Not yet heard by the owner.** The picks are theirs, by ear (TC-342).

### The diner's steps (a gameplay fix under the standing OK)

The lobby's floors were checked for which step set they get. The diner's black and white check is a kit mesh over a grey floor part, and that part was SmoothPlastic, which `Data/Footsteps` doesn't list, so the diner played wooden steps. Its floor part is Marble now (the court's material), unseen under the kit (screenshot checked), so the diner sounds like tile.

Left as they are, for the owner: the electronics store and the dead shop are plain SmoothPlastic floors too, so they also play wooden steps. Changing them to Plastic (the lino) or Marble would show (Roblox's base materials aren't overridden here), so that's the owner's call.

## Checks

`stylua`, `lune run tests/run` (735 tests), `lune run tests/compile`, `selene`, `rojo build`; Studio play solo, as above. Not checked: with two clients (the echo is per client, from where you stand, so nothing to sync but the picks), or on the live game.
