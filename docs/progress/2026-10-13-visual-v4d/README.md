# The visual rework, V4 (part 4): the escape's things

After the last furniture batch the owner said: "go ahead with the next batch."

What's left of V4 is the run's own objects, about 70 of them, built in code by seven modules (`World/Items`, `World/LeadProps`, `World/Dressing`, `World/Junk`, `World/LandmarkProps`, the puzzles' stations, `Services/LockService`). That's too many for one import, so they come in three batches:
- **`kit6`, the escape's things** (this one): what every run is played for and with.
- **`kit7`, the puzzle stations:** the computer and printer, the fuse box, the safe, the music box, the levers, the dumbwaiter, the crank shutter, the chute, the bell board, the radio and record player, the toy, the baby monitor.
- **`kit8`, the atmosphere:** the photo frames, telephone and clutter on tops (`World/Dressing`), the finds in drawers (`World/Junk`), the corridor landmarks, the outside's trees and lamp.

## The batch (`tools/blender/kit.py kit6`, `kitlib/things`)

29 pieces, each built in the game's own frame through `G()` and `S()`, round the same origin as the grey-box it dresses.

| Piece | For |
| --- | --- |
| Key | `World/Items.key`: an oval bow, a collar and bead, a round shank, a bit with three wards; the tag's string (the tag is the game's, written on) |
| Candlestick, PocketWatch, Locket, Doll, ChristeningCup | the heirlooms: a knopped silver candlestick with a half-burned candle; a gold watch lying face up with a drawn dial (numpy, `_dial_picture`) and its chain; an oval engraved locket on a loose chain; a porcelain doll in a wine velvet dress, painted eyes, curls; a silver cup with a scrolled handle |
| CarriageClock, JewelleryBox, SilverTeapot, CashBox | the valuables: a gilt carriage clock with a dial on both faces; a red lacquered box with gilt mounts; a Georgian teapot with an ebonised handle; a green enamelled cash box with a bail handle |
| KeepsakeWood/Tin/Velvet and their lids | `LeadProps.keepsake`'s three looks: walnut with brass corners, a blue biscuit tin with a red lid, a claret velvet case with its clasp; each lined |
| DisplayCase, DisplayCaseCover | the case's mahogany plinth and felt; the cover's frame with brass finials round the game's glass |
| Figurine | the porcelain shepherdess a case shows when it holds nothing of his |
| KeyRack | a pine rack, a crest with a brass plate, a shelf, four brass cup hooks |
| KeyPlate, KeyPlateDouble, Hasp, Bolt, PowerBox | the locks' plates on both faces of a door: a brass escutcheon; the double lock's long plate; a hasp and staple with a combination padlock; a black barrel bolt; a grey junction box round the power lock's lamp |
| Padlock | a laminated padlock for the chains, with its own shackle |
| Plank | the boards nailed across a door or a chest, fitted to each |
| DinnerPlate, TableCandle | a place at the dinner: a gold-rimmed plate; a candle in a silver chamberstick (the flame is the game's) |

Before the import, three previews were redone:
- **The doll:** its hair was a thin cap with round puffs over the ears, its collar a flat plate, its neck long. It now has a full head of hair with curls hanging behind, a capelet collar, a short neck and puffed sleeves.
- **The figurine:** its apron was a flat card floating in front. It now follows the skirt, and the bodice and arms are fuller.
- **The candles:** their drips stood up round the top like a crown; they now run down the side.

The teapot's spout was also slimmed, so it fits its footprint (Kit.spec holds every valuable to `Data/Valuables`' size).

## In the game

**`Data/Kit` `Things`, dressed by `World/Kit.dressThing`:**
- **Where:** each builder dresses its own model on the frame it was given: `Items.key`, `.heirloom` and `.valuable`, and `LeadProps.keepsake` (by look), `.displayCase`, `.figurine` and `.keyRack`.
- **Lids:** the keepsakes' and the case's lids are `pieces`.
- **How they carry:** the grey-box stays the body the hands carry. `Services/HandsService` already welds a kit mesh to a thing's root, weightless and never colliding. Its queries are turned on with the thing's (`AddThing`), and that's what the hands' aim finds, because they look past a hidden part that doesn't collide.

**The locks' hardware (`Services/LockService`):**
- **Plates:** each plate kind wears its model (`World/Kit.place`, its front out of its own face), the grey-box hidden. They're placed before the door adopts the plate's folder, so they swing with the door.
- **Planks:** `Kit.swap` puts a modelled plank in each plank's place, so prying one off and its step work as before.
- **Padlocks:** a chain's padlock is `Kit.dressPart`, with the new `fit = "scale"` (as wide as the game's) and `at` (its box rises over the body to take in the shackle). The grey-box shackle is hidden.

**The dinner (`Services/FinaleService`):** each place's plate and candle wear the kit's; the card and the flame are the game's.

**`World/Kit`:**
- `dressBody` is shared by props and things.
- `fitted` gained `"scale"`.
- Placed parts take an `at` offset.
- `Kit.hide` is public.

**Fixed for the models:**
- **The loose plank** pried off a door was resized, flat side down: a modelled plank would have been squashed. It is now turned onto its face instead, at its own size, and the clone drops the kit's marker so the hands carry it as a thing.
- **The dinner's shadow** of a wanted heirloom (`_ghost`) drops the model's SurfaceAppearance, so it stays one flat colour.
- **The display case keeps the game's lock plate**, where its pick prompt hangs. Hidden, the hands would have looked past it to the lid's prompt.

## Seen in Studio (build .187)

The owner imported `kit6.glb` (29 meshes); 110 kit meshes loaded and the console was clean. Seen on seed 6 and seed 1, each built for a squad of four on a full night (F2 `squad 4`, `night full`), with F2 `furniture open all` to make what's kept inside.

- **The dinner** (1): gold-rimmed plates, candles in chambersticks burning at their tops, the wanted heirlooms' shadows (the locket and its chain, the cup, the candlestick) one flat colour.
- **The keepsakes and heirlooms** (2, 3):
  - the velvet case open on its hinge, the locket on its satin, "Mom's locket · Pick up" when you look at it;
  - the candlestick in a blanket chest, "Mom's silver candlestick · Pick up".
  - F2 `grab` held it: the model stayed welded at the same offset from its parts.
- **The teapot** on the nursery floor (4).
- **The display case** (5), with the figurine on its felt, its lock plate the game's.
- **The key rack** (6), a key hanging from its first hook.
- **The locks:**
  - the power lock's box round its red lamp (7);
  - boards across a door (8): with a crowbar (`give tool:Crowbar`, the `ToolWork` remote), two strokes took two planks off each face. The one on the worker's side lay flat at their feet, a thing to pick up;
  - the chained door's padlock with its own shackle (9);
  - the code padlock's hasp (10);
  - the double lock's plate (11).
- **Gate A** unchanged: parts 2441, hash 1845087318. Everything in this batch is run content, which Gate A leaves out.

**Not checked in Studio:**
- carrying and throwing a dressed thing by hand: the debug grab doesn't drive the client's hold;
- picking the display case's lock;
- a chest nailed or chained shut (none in these houses);
- the dinner served.

They're in TC-291.

## For later

- **The figurine** is plain at close range: its bodice is a white cylinder.
- **The doll** reads more sweet than eerie.
- **The locket's chain** is the heaviest thing here (6,000 triangles).

## Checks

619 tests (Kit.spec now 10), compile, selene 0 errors and 0 warnings, `rojo build`. TC-291.
