# Art direction: The Halfway House

> **Status:** draft for the owner's OK (2026-10-02). Nothing below is built yet. The before-shots it refers to are in [`baseline/2026-10-02`](baseline/2026-10-02/README.md).

This is the short guide every visual change follows. It applies design doc section 8: spend on **lighting first, then materials, then composition, then props**, and keep the stalker's silhouette readable.

## The look in one line

**A lived-in suburban home, about 1988, at two in the morning: someone left a few lamps on, and the house is pretending nothing is wrong.**

The late-80s setting gives us patterned wallpaper, wood panelling, brass fixtures, a CRT TV and a grandfather clock. The room list already includes a sewing room, a music room and a den, so the props fit. The house should feel ordinary first. The horror comes from small things being wrong, not from the house looking haunted.

## Rules that beat everything else

1. **Dark, but readable.** At default settings and *without* the flashlight, a player standing in any room can see its doorways and the shapes of its furniture. Aim for no more than about a third of the frame in pure black. The flashlight is for reading details such as notes, clocks and faces, not for finding the exit. (The baseline fails this: most rooms are more than half black.)
2. **Art never hides evidence.** Tell props must be readable at 6 studs under the flashlight. Keep PropFactory's child names (`Dial/Face/Time`, `Paper/Writing/Text`, …) when restyling.
3. **Seams must be invisible.** Seam panels, fake walls and phantom doors use exactly the same material, colour and trim as the wall around them. If a texture lines up badly on a seam, players learn to spot divergences by texture. That would break the core mechanic.
4. **Exits always read.** Door frames get lighter trim than the walls, and a real doorway never sits in pure black (doc section 3, the fairness contract).
5. **Mild fear only** (doc section 9). No blood, wounds or gore. Wrongness comes from proportion, stillness and implication.

## Palette

| Role | Hex | Notes |
| --- | --- | --- |
| Wall base, "nicotine plaster" | `#8C7B63` | Default wall tone; wallpapers sit near it |
| Wallpaper: faded sage | `#6E7462` | Study, guest room, hallways |
| Wallpaper: dusty rose | `#8A6C6C` | Dining room, sewing room, master bedroom |
| Wallpaper: ink blue | `#4A5468` | Nursery, kids' bedroom, music room |
| Wood, dark walnut | `#4A3324` | Trim, formal furniture, panelling |
| Wood, honey oak | `#7A5536` | Floors, kitchen cabinets |
| Fabric: mustard / rust / bottle green | `#8F7434` `#7A3F2C` `#34473A` | Sofas, curtains, rugs: muted, never bright |
| Light: tungsten lamp | `#FFB878` | Every warm practical light |
| Light: moonlight | `#7896DC` | Windows only |
| Light: fluorescent | `#D7EBE1` | Utility rooms; slightly green on purpose |
| Light: CRT glow | `#8CAAFF` | TVs |
| Light: Lantern (safe) | `#FFBE6E` | Lit Lantern rooms; the warmest light in the game |

**Reserved colours.** These carry meaning, so the house never uses them as decoration:
- **Brass `#C4965C`:** truth and the interface: anchored objects, Case Board pins, the Witness Camera flash, UI accents (already `Ui.Theme.accent`).
- **Hunt red `#B8322A`:** only the hunt telegraph. Never on props or lights.
- **Decay green-grey `#CDE1D7`:** what Drift pulls the image towards (already `EffectsController`'s tint target).

## Materials

- **Walls:** patterned wallpaper in three families (sage, rose, blue) plus plain plaster. Formal rooms get a dark wood **dado rail and wainscot** on the lower third. Every room gets **baseboards and crown moulding**; trim catching light is the cheapest way to make a box read as a room.
- **Floors:** worn oak planks in living spaces, low-pile carpet with faint stains in bedrooms, checkerboard linoleum in the kitchen and laundry, small hex tile in the bathroom, stained concrete in the garage.
- **Ceilings:** popcorn plaster slightly darker than the walls, with a water stain in a few rooms.
- **Grime layer:** one shared set of decals (water stains, scuffs by door frames, dust shadows where pictures hung), so the whole house ages consistently.
- **How they're made:** `generate_material` makes about 8–10 `MaterialVariant`s for the whole house (3 wallpapers, plaster, 2 woods, carpet, linoleum, tile, concrete). Hero props get `SurfaceAppearance`. Textures are 1024 px at most. Every external asset goes in a licensing note, and asset ids go in `Assets.luau`.

## Lighting mood by room family

Every room keeps **one motivated key light** that casts shadows, as the doc requires. Fill lights don't cast shadows. The 22 templates fall into five families:

| Family | Rooms | Key light | Mood |
| --- | --- | --- | --- |
| **Lamp-lit living** | foyer, living room, den, dining room, study, music room, sewing room | Shaded tungsten lamps, 1–2 pools | Warm pools with soft falloff and darkness between them. "Someone left the lamps on." |
| **Moonlit bedrooms** | master, guest, kids', nursery | Moonlight through the window, plus a small warm night-light or bedside lamp | Cool/warm split: blue floor shapes from the window, one small warm point. Quietest rooms. |
| **Utility** | kitchen, bathroom, laundry, pantry, mudroom, garage | Overhead fluorescent tube or a bare bulb | Flat, harsh, slightly green. The place lights flicker first as Drift rises. |
| **Corridors** | hallway, hallway runner, attic landing | Small sconces, with light spilling in from the far room | The darkest family. Framed so a figure at the far end is backlit: the doc's first "thumbnail moment". |
| **Big windows** | sunroom, playroom | Moonlight, large window shapes across the floor (light shafts) | The most open and eerie rooms, where the outside feels close. |

**Mood tags adjust the recipe.** *Open* rooms get a second pool of light; *tight* rooms get one closer, dimmer source; *watched* rooms get a light behind or across the room, so silhouettes read.

**The run's arc** (already wired to Drift in `EffectsController`; this sets the target look):

| Drift | Look |
| --- | --- |
| Calm (0–20) | Warm and clean. The house looks ordinary. |
| Uneasy (20–40) | Slightly cooler and less saturated. |
| Fraying (40–60) | Utility lights start flickering; grain becomes visible. |
| Breaking (60–80) | Contrast up, colour drains towards decay green-grey, the vignette closes in. |
| Collapsing (80–99) | Nearly monochrome. Only Lantern rooms keep their warmth: islands of safety. |

**Hub:** the one warm, fully lit, safe-feeling space. It should feel like an investigators' field office, the opposite of the house. Signs get consistent text sizes, and the menu shouldn't collide with Roblox's chat hint.

## The Guest

**Concept:** a dinner guest who stayed far too long. Polite, patient and wrong.

- **Silhouette first.** Tall (8.4 studs, already in `Archetypes`) and thin, with arms a little too long, narrow shoulders and a small head. It must read at 30 studs against a lit doorway (doc section 8). The baseline fails this: today the head is the only visible part.
- **Clothes:** a dated, slightly too-big dark suit (`#121114`, already set). The cuffs and collar of a pale shirt give the body edges you can see in low light.
- **Face:** a pale, smooth, porcelain oval (`#C4BEB2`, already set) with only the *suggestion* of features: shallow eye hollows and no mouth. The face is the one light point on the body. When the flashlight hits it, two faint eye-shine points appear, so being looked at by it is felt. Nothing gory.
- **Posture:** hands clasped in front, a slight bow, the head tilted 14° (already set). "Polite posture" is the archetype's rule.
- **Movement:** stillness, then short bursts. Joints bend a little too far. Budget 6–10 animations, as the doc says: idle-watch, turn, stalk-walk, run, peek, intrude, grab, retreat.
- **Build:** a custom **R15 rig** made from generated meshes (`generate_mesh`), not one static mesh, so it can be animated and the existing code keeps working.

## Performance budget

- 4–6 shadow-casting lights visible at once (doc section 8). Today all 17 room lights cast shadows; fill lights will be shadowless.
- About 8–10 MaterialVariants for the house, with textures of 1024 px or less.
- Merge static trim per room so the instance count stays low.
- Low-end mode turns off grain and depth of field and drops fill lights. Every lighting change gets checked at low graphics quality too.

## How the visual pass will run

Each step is small, gets before and after screenshots from the baseline angles, then passes the checks before it's committed:

1. **Lighting and exposure:** the five family light recipes, and fixing the too-dark rooms (rule 1).
2. **Trim kit:** baseboards, crown moulding, door and window frames, wainscot. Window panes get a moonlit glass look instead of flat colour.
3. **Materials:** wallpapers, floors and ceilings through `generate_material`, plus the grime decals.
4. **Fixtures and atmosphere:** real lamp, sconce and tube models, dust particles, window light shafts.
5. **The Guest:** model, then animations.
6. **Hub polish:** signs, layout, the chat-hint overlap.
