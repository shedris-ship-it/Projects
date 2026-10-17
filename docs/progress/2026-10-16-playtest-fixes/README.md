# Playtest fixes after publishing build .231

The owner published build .231 and playtested. Their notes: "trying to play house call forces the camera into a spot where my head blocks everything and I dont know how to get out of it ... going up to the racks in the boutique made the camera look at me through the racks and I couldnt see my character ... other players could be temporarily invisible while you're in the wardrobe menu ... light would pour into the grand entrance from another room at a farther distance away and would fix itself when I got closer to the source wall". All four are fixed in build .232, under the standing OK for gameplay fixes. The fitting room's invisibility is the owner's own request.

## HOUSE CALL: your head in the way, and no way out shown

- **The cause:** playing, the camera stands 2.6 studs in front of the screen, square on it. The server stands you at the cabinet, and your head sits between that camera and the screen. The scripted camera doesn't fade you the way Roblox's own does, so you saw the inside of your own head (`arcade-before.jpg`). Backspace was the only way out, and nothing said so.
- **The fix** (`Controllers/ArcadeController`):
  - While you play, your body is hidden on your own screen, set after the camera scripts each frame. It comes back when you leave.
  - A paper slip under the screen gives the controls and a LEAVE (BACKSPACE) button you can click (`arcade-after.jpg`).
  - The hub panel (`UI/Lobby`) and the prompts (`ActionController`, as in a car or the fitting room) are put away while you play.
- **Checked in Studio:** F2 `arcade play 1` shows the maze with the slip under it. Backspace then gives back the camera, your body, the panel and the prompts.

## The boutique's racks: the mirror inside the rack

- **The cause:** the fitting room's camera is a mirror's view, 8.5 studs in front of you looking back. At the booth you're turned to face out. At a rack you face the rack, so the camera stood in or behind it and looked at you through it.
- **The fix:**
  - At a rack, the server turns you to face open floor before it holds you still (`ShopService:_mirrorTurn`).
  - It tries the turns in `Config.Fitting.Turns` in order: as you stood, then about-face, then each side in 30-degree steps. It takes the first whose line to the camera is clear, cast from your middle in a strip 1.2 studs wide (`Logic/Closet.mirrorTurn`, spec'd). If none is clear, it takes the one with the most room.
  - The camera's placement is in `Config.Fitting` now, shared by the server and `UI/Boutique`.
- **Checked in Studio:** at the Tops rack, facing it (F2 `shop rack top`), you're turned 150 degrees and the mirror shows you whole, with the rack behind you (`rack-after.jpg`).

## Everyone else hidden in the fitting room

While you're in the fitting room (booth or rack), everyone else is hidden on your screen, with their clothes, torches and names. They come back when you leave by Done. Only your screen changes: they still see you (`UI/Boutique`, `_hideOthers` and `_showOthers`). It's re-applied four times a second, for someone who arrives or changes. Not checked: it needs a second player (TC-353).

## Light through the walls

- **The cause:**
  - Shadows are the costly part of a dark house of many lamps, so a lamp casts them only within 62 to 74 studs of the camera (`Config.ShadowRadius`).
  - Without shadows, Roblox's light passes through walls. The house's lamps reach 27 to 44 studs, so a far lamp lit the rooms next to its own. Walking near brought its shadows back, and with them the walls.
  - In this place's own house (seed 1800820264), no lamp that reaches the grand hall is ever that far from it, so the leak was a larger house's. The cause is the same.
- **The fix** (`Controllers/EffectsController`):
  - Beyond the radius, a lamp stays lit, with its shadows, only while you can see it or the floor under it.
  - One you can't see fades out over about a third of a second, keeping its shadows until it's out.
  - The check: `canSee`, with rays from the camera to the lamp and to its floor. Walls and floors block them; glass, the lamp's own shade, players and the hidden blocks under the kit's models (props, doors) don't. Six far lamps are checked a frame (`checks`).
  - Counting something as seen when it isn't only costs a lamp's shadows, so the check leans that way.
  - The pendants' ceiling glow follows its lamp, as before.
- **Checked in Studio** (seed 1800820264, from five places across the house): every lamp beyond the radius was out of sight, and every one was out. No lamp you could see was dark. The lobby's lights aren't this controller's, and all stayed lit. The window moonbeams are separate lights this controller doesn't manage, and they always keep their shadows.
- **Not checked:** a long view to a far lamp you can see; this house has none. The owner's larger houses, by eye (TC-354).

## Checks

stylua, selene (0 errors and 0 warnings), `lune run tests/compile`, `rojo build`, and `lune run tests/run`, with one new spec in `Closet.spec`. No game errors in play.

## For the owner

- TC-351 to TC-354: the arcade and the rack by hand, the fitting room with a friend, and a big house's grand entrance.
- Publish when you're happy with them.
