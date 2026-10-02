# Baseline screenshots, 2026-10-02

The first in-Studio look at the grey-box slice, before any visual pass. Retake these from the same spots after each art change to compare.

**How to reproduce:** Play, then F2 → `seed 1800820264` → `start` → `skip`. That builds the same 15-room house with Counterfeit. For the stalker shots also run `tier 2`. Shots use `screen_capture` with a camera position and a look-at target (studs). The debug panel is open in 04, 12 and 13.

| File | Camera → look-at | What it shows |
| --- | --- | --- |
| 01_hub_first_launch | player view | First-launch settings over the hub menu |
| 02_hub | player view | Hub, third person |
| 03_hub_wide | (25, 12, 1425) → (-8, 3, 1385) | Hub room: pedestals, rug, contract table |
| 04_arrival_debug | player view | Arrival phase, HUD and debug overlay |
| 05_foyer | (-16, 6, -16) → (12, 3, 14) | Room01 foyer, warm lamp, Companion |
| 06_dining_room | (-64, 6, 24) → (-90, 2.5, 50) | Room05 dining room, ceiling panel |
| 07_kitchen | (-64, 6, -24) → (-92, 2.5, -52) | Room10 kitchen, ceiling panel + lamp |
| 08_nursery | (-24, 6, -24) → (-52, 2.5, -52) | Room06 nursery, blue window light |
| 09_master_bedroom | (56, 6, -16) → (28, 2.5, 14) | Room08 master bedroom, warm lamp |
| 10_living_room | (96, 6, 24) → (68, 2.5, 52) | Room15 living room, TV light, no flashlight |
| 11_living_room_flashlight | (88.7, 5.7, 29.3) → (66, 3, 52) | Same room, player eye height, flashlight on |
| 12_stalker_tier2_28studs | (92, 5.5, -12) → (72, 3.5, 8) | The Guest at tier 2, about 28 studs away |
| 13_stalker_tier2_close | (79, 5.2, 1) → (72, 4.2, 8) | The Guest, about 10 studs away |
| 14_hud | (88.7, 5.7, 29.3) → (70, 3.5, 46) | In-run HUD, flashlight on |

## What the run showed

- **Console:** no errors or warnings from game code. Expected lines only: DataStores unavailable (unpublished place) and one anti-cheat snap-back caused by a test teleport.
- **Performance:** client at 60 fps in Studio outside screenshot moments (the overlay dips to ~15 fps while a capture renders). The level is ~1,600 instances; the ~49,500 instance count in the overlay is mostly Studio itself.
- **Lighting:** each room has one key light from three recipes (warm lamp 255,190,130; blue window SurfaceLight 140,160,230; cool ceiling panel). All 17 lights cast shadows, above the doc's 4–6 starting budget (section 8). Without the flashlight most rooms are more than half black.
- **Flashlight:** lasts 5 minutes (`FlashlightBatterySeconds = 300`) and only recharges in a lit Lantern room. Since most rooms are dark without it, room brightness and battery need tuning together.
- **Stalker:** default R15 body, black clothes, faceless tan head. The head is the most visible part at 28 studs; the silhouette does not read (doc section 8 wants it readable at 30 studs).
- **Text:** the Witness Camera description says "6 shots" but solo runs get 8 (`Config.Tools.CameraFilmSolo`). Roblox's chat hint overlaps the CONSENSUS title in the hub.
