# Footsteps without warnings, and the lobby's "echoing footsteps" (builds .223 to .228, 2026-10-16)

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

**Not the multi-client test.** A first guess was Studio's Clients and Servers test (every client window plays audio, so your steps would come again from the other window). The owner heard it solo in Studio and in the live game, so that wasn't it.

**The cause (build .225): the steps didn't keep time with the feet you see.** The walks above were short, because the scripted walk kept hitting the court's planters and stalled after half a stud. A proper walk along the clear lane (z −25) showed it. Step sounds were paced by distance, one every `Config.Feel` stride (4.6 studs at a walk, 6.8 at a sprint), the rhythm the owner tuned for first person, in time with the camera's bob. Roblox's walk animation lands a foot far more often:

| Speed | Feet you see land | Step sounds (before) |
|---|---|---|
| 8 (the house's walk) | every 0.31 s | every 0.57 s |
| 12 (the lobby's walk) | every 0.31 s | every 0.45 s |
| 19 (sprint) | every 0.24 s | every 0.36 s |

So most sounds fell between footfalls and drifted in and out of time with them, about two sounds for every three footfalls at the lobby's walk. In the house you're in first person and don't watch your feet. In the lobby's third person you do, so the steps read as somebody else's, trailing you. The same was true of every teammate's steps in the house.

The fix: a body seen from outside (yours in the lobby's third person, everyone else's always) steps when a foot touches down. `Logic/Feel.footDown` (spec'd) watches each foot's height under the body: once it has lifted 0.3 studs above its lowest (a walk lifts 0.57, a sprint 1.06), coming back within 0.1 of it is a landing, heard from that foot's sole. Your own steps in first person keep the stride, so the house's feel and the bob are unchanged. If a moving body's feet don't lift for 0.6 s (no walk playing on it), its steps fall back to the stride (`Feel.stepsFromFeet`). The feet keep animating with the body off screen (checked: 143 of 150 frames with the camera turned away), so teammates behind you are still heard. A seated body (in a car) has still feet, so it no longer plays steps while it rides.

Checked in Studio play, solo, in the lobby (third person): at 12 studs/s the feet landed at 0.50 0.83 1.11 1.46 1.75 2.08 2.36 2.71 3.00 s and the sounds came at 0.50 0.81 1.10 1.43 1.71 2.06 2.35 2.68 2.96; at a sprint, 0.28 0.48 0.75 0.95 1.22 1.42 1.68 1.88 against 0.27 0.47 0.72 0.93 1.18 1.38 1.65 1.85. In the house, first person, the stride as before (every 0.57 s at 8). Not heard by ear here: the owner's ear is the check (TC-346).

### Too loud, and not quite on the feet (build .228)

The owner on .225: "The weird echo thing is gone, but the footsteps feel really loud and also don't entirely match up with the footstep animations."

**Not quite on the feet.** .225 watched the middle of each foot. Against each foot's lowest point meeting the floor, the right foot's sound came within 20 ms but the left's about 100 ms early, so the steps limped (gaps alternating 0.29 and 0.33 s at the lobby's walk). Measured above the body's floor, frame by frame at 60 fps:
- a foot's lowest point rests 0.08 up when flat, swings 0.21 to 0.43 up at a walk and to 0.76 at a sprint, and dips 0.15 under as the foot rolls;
- its middle stands 0.39 up;
- in the slow walk (the house's 8 studs/s) the toe tips down to the floor mid-swing (lowest point 0.05 to 0.07) while the foot's middle is still 0.67 to 0.78 up.

So a landing is now the lowest point back within 0.12 of the floor while the middle is within 0.25 of where it stands (`Feel.footDown`, spec'd with the toe dip). That's the heel strike: in the 60 fps traces it fires a frame or two before the foot settles (at 0.85 s against 0.88 at the lobby's walk; 1.15 against 1.18 at 8), on both feet. The remembered lowest creeps up at 0.1 studs a second (0.25 let it climb far enough in the first swing to look like a body whose feet never reach the floor, and the first step came early).

A caveat about measuring: with Studio's window unfocused the game draws 15 frames a second while its logic runs at 60, and the animation only moves on a drawn frame. The feet then move in 67 ms jumps, and the step gaps alternate 4 and 5 frames (0.27 and 0.33 s) whatever the rule. The last timing runs here were at 15 fps, so they can't judge the rhythm: the owner's ear, in a focused window, is the check.

**Too loud.** Steps from the feet come 1.5 to 1.8 times as often as the stride did, at the same volume each, and the lobby's brisk walk (12 studs/s) already counts as a third of the way to a sprint's volume. Steps seen from outside (yours in the lobby, everyone else's anywhere) are now half volume (`Config.Feel.FootstepVolumeSeen = 0.5`): about 0.53 a step at the lobby's walk, from 1.08, and 0.74 at a sprint, from 1.5. Your own first-person steps in the house are unchanged. F2 `stepvolume <share>` sets the share for everyone at once (0 to 2; no number goes back to 0.5), so the owner can pick it by ear; the pick goes into Config.

### The diner's steps (a gameplay fix under the standing OK)

The lobby's floors were checked for which step set they get. The diner's black and white check is a kit mesh over a grey floor part, and that part was SmoothPlastic, which `Data/Footsteps` doesn't list, so the diner played wooden steps. Its floor part is Marble now (the court's material), unseen under the kit (screenshot checked), so the diner sounds like tile.

Left as they are, for the owner: the electronics store and the dead shop are plain SmoothPlastic floors too, so they also play wooden steps. Changing them to Plastic (the lino) or Marble would show (Roblox's base materials aren't overridden here), so that's the owner's call.

## Checks

`stylua`, `lune run tests/run` (741 tests at .228 with the monetization specs: five feet specs, two more than .225's three; 733 at .224), `lune run tests/compile`, `selene`, `rojo build` (into `build/scratch`, since the owner had the repo's `Consensus.rbxlx` open in Studio; .223 and .224's checks overwrote that file on disk); Studio play solo, as above. Not checked: with two or more clients, or on the live game.
