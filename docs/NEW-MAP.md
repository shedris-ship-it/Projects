# When a new map comes out: what changes in the lobby

The owner asked for this on 2026-10-16: one place listing everything in the lobby that's about a particular map (a location: today The Halfway House, next St. Odile Ward), so a new map's release updates all of it and nothing is left saying the old one. Keep it current: when something new in the lobby names a map, add it here.

Each row says where the thing lives, what changes, and what it needs. **Owner** marks a step that needs the owner: an import to their account (Home → Import 3D), an image upload, or a product in Creator Hub.

## 1. The map itself

| What | Where | What changes | Needs |
| --- | --- | --- | --- |
| The location's entry | `src/shared/Data/Locations.luau` | `available = true`; check its `name`, `case` (the case number), `blurb` (the case folder's line), `stalker`, `templates`, `ambient` | |
| Its rooms, props, puzzles and stalker | the run's own data and code | (the map's own plan, not the lobby's) | |

Data-driven already, so nothing to edit once the entry is right: the car's rear-window sign, the dashboard, the receipt in the car, the case folder's line (`UI/Lobby`), the case number on the folder's label and on the Dossier (`case`), and the rental prompt ("X isn't out on video yet" until `available`).

## 2. The video store (renting the case)

| What | Where | What changes | Needs |
| --- | --- | --- | --- |
| The tape on the NEW RELEASES island | `Data/Mall.luau` `Mall.Tapes` (one per location: St. Odile's is there, COMING SOON) | Its spot stays; once `available`, the COMING SOON sticker goes by itself. A third map needs a third spot on the island's top shelf | |
| The tape's cover | `Services/RentalService.luau` `COVERS` (box colour, ink, accent band) | A cover for the new map (its colours) | |
| The standee in the window | `tools/blender/kitlib/mall2.py` `standee_poster` ("THE HALFWAY HOUSE · NOW ON VIDEO": the house at night, the masked figure) and `standee`; `Data/Mall` block `Standee` | A new poster for the new map: a second standee beside it, or this one swapped. Sketch, bake, export | **Owner:** import |
| The COMING SOON frames over the first tapes, either side of the way in | `Data/Mall.luau` `Mall.Ads` (`video-coming-west`, `video-coming-east`: their `poster`), `Data/Posters.luau`, `tools/posters.py` (LB6; today two made-up films) | One can tease the next map before it's out: draw its poster in `tools/posters.py`, add it to `Data/Posters`, name it in the frame's `poster`. Players allowed ads may see an ad there instead; everyone else sees ours | **Owner:** image upload |

## 3. The garage (the investigators' room)

| What | Where | What changes | Needs |
| --- | --- | --- | --- |
| TONIGHT on the whiteboard | `Data/Mall.luau` `Mall.Signs`: "TONIGHT: THE HALFWAY HOUSE" | The new map's name, or both maps ("TONIGHT: ..." for whichever case the lobby is on) | |
| The case board's photos | `kitlib/mall3.py` `snapshot("house")`, `snapshot("figure")` → `PhotoHouse`, `PhotoFigure`; five `Photo` blocks on the `CaseBoard` in `Data/Mall` | Photos of the new map's place and its stalker: new snapshot kinds, a second board or this one re-pinned | **Owner:** import |
| The plan pinned on it | `kitlib/mall3.py` `blueprint()` (headed "HALFWAY HOUSE") → `Blueprint`; `HousePlan` block | The new place's plan | **Owner:** import |
| The red string | `Data/Mall` `RedString` blocks between the pins | Re-strung to the new pins | |
| What's on the board to read | `Data/Lore.luau` entries with `location` (the case file, the photos' captions, the plan's notes) | The new map's entries: its case file, its clippings, its photos' captions (`Services/LoreService` puts them up) | Story: the owner's input |
| The clippings (once the story clutter batch is in) | `tools/blender/kitlib/clutter.py` `CLIPPINGS` (the headlines) → `ClippingA` to `ClippingC` | The new map's headlines | **Owner:** import |
| The map of sightings (the same batch) | `clutter.py` `sightings_art` ("SIGHTINGS 88-0412", the pins and their dates) → `SightingsMap` | The new case's map and pins | **Owner:** import |
| The crews' tapes on the TV cart (the same batch) | `clutter.py` `tv_cart`'s labels ("88-0412 CREW 3", ...) | Tapes for the new case beside the old | **Owner:** import |
| The evidence boxes | `Data/Mall` `EvidenceBox` (BankersBox, a label baked on: `kitlib/mall3.py` `box_label`) and `Data/Lore`'s inventory | A box for the new case, its label and inventory | **Owner:** import (the label) |

## 4. The court, the shops and the diner

| What | Where | What changes | Needs |
| --- | --- | --- | --- |
| The diner's record boards | `Logic/Records.luau` (`Records.Location = "HalfwayHouse"`: only its runs count), `Services/RecordsService.luau`; the boards' keys (`Records_Normal_FastSolo`, ...) have no location | Decide with the owner: boards of its own for the new map (a third board, or the menu and specials boards turning between maps), then key the lists by location and let its runs count | |
| The arcade | `Services/ArcadeService`: HOUSE CALL is the Guest's game | Nothing has to change. A cabinet for the new stalker's rules would be a game of its own (as NIGHT DRIVE is planned) | |
| The ad lightboxes and the TV wall | the plan's LB6 (our own posters as the fallback, video ads on the TV wall) | The new map's poster and trailer in the rotation | **Owner:** image and video upload |
| The case folder's title on screen | `UI/Lobby.luau` (from `Data/Locations` `case` and `name`) | Nothing: it follows the lobby's case | |

## 5. The run's screens that name the map

| What | Where | What changes | Needs |
| --- | --- | --- | --- |
| The night's title card | `UI/Overlays.luau` (the lobby's location name; "The Halfway House" when it has none) | Nothing once the location is right; its fallback stays the first map | |
| The Dossier | `UI/Dossier.luau` (the case number from the run's location) | Its stalker's pages (his moods, his rules) are The Guest's: a new stalker needs his own | |
| The how-to and the tips | `UI/Tips`, the how-to screen, README: The Guest's three rules, word for word | A new stalker's rules, said the same way everywhere | |

## 6. Before release

- Run the checks, play the new map from the video store to the car to the house and back, and look over every row above in the lobby.
- Add TCs to `docs/TESTING.md` for whatever changed.
- A new row here for anything new in the lobby that names a map.
