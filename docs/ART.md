# Art direction: The Halfway House

> **Status:** approved (2026-10-02). The owner chose the 1988 setting, The Guest concept, P.T. as the reference, a **Moderate** content rating, and a narrow-corridor prototype. The before-shots it refers to are in [`baseline/2026-10-02`](baseline/2026-10-02/README.md).

This is the short guide every visual change follows. It applies design doc section 8: spend on **lighting first, then materials, then composition, then props**, and keep the stalker's silhouette readable.

## The look in one line

**A lived-in suburban home in 1988, at two in the morning, shot like P.T.: dim, sickly lamplight, far too quiet, and every time you look back something is slightly different.**

The late-80s setting gives us patterned wallpaper, wood panelling, brass fixtures, a CRT TV, a radio and a grandfather clock. The house should feel ordinary first. The horror comes from small things being wrong, not from the house looking haunted.

## The reference: P.T.

P.T. (Kojima Productions, 2014) is the touchstone for mood. It fits Consensus unusually well: its whole idea is *the same ordinary place, slightly different each time you look*, which is our divergence mechanic.

**What we take (the method):**

1. **The mundane carries the horror.** An ordinary hallway, a radio, a clock, family photos, a bathroom door left ajar. Nothing looks like a horror set. It looks like somebody's house, and that's worse.
2. **Repetition makes small changes loud.** Because the place is so consistent, a photo that moved or a door that's open now is a jolt. Our dressing must be consistent and restrained, so that divergences and tells stand out.
3. **Few, weak, practical lights.** A hanging ceiling lamp, a table lamp, light spilling from a doorway. Sickly yellow-green tungsten, deep shadows, heavy film grain and a vignette.
4. **The presence behind you.** You mostly *hear* the threat first: breathing, a floorboard, footsteps that stop when you stop. Turning around is the scare. Our Guest already moves only when unobserved, which is the same idea.
5. **Silence as a tool.** Long stretches of near-silence, then a creak, a muffled broadcast, something from another room. Loud stingers are rare, so they land.
6. **Escalation by decay.** At first it's just uneasy. Later the place itself turns: darker, redder, photos gone wrong, the radio seemingly talking about *you*. This becomes our Drift arc (below).

**What we leave out:**

- **Anything past Moderate.** We target Roblox's **Moderate** rating (design doc section 9, decided 2026-10-02). It allows realistic blood (pools, smears, spatter), bleeding eyes, disfigured faces and wounds, so most of P.T.'s imagery is available. Severed body parts, dismemberment and the like are **Restricted** (18+ only), so P.T.'s bathroom sink scene stays out. Nothing that breaks Roblox's Community Standards either: no self-harm, and violence against family stays implied, never shown.
- **Gore up front.** Blood is a late-game escalation, not wallpaper. Early on the house is clean and ordinary. Gore that shows up from minute one stops being scary by minute five.
- **Camera tricks.** No head-bob, tilt or roll (doc section 4, comfort-safe). Grain, vignette and depth of field are fine, and players can turn grain off.
- **Copying.** We borrow the method, not the content: no recreating P.T.'s hallway layout, its ghost, its radio script or any of its assets. Copying a Konami game's specifics risks takedowns, and it would also make ours feel like a fan tribute instead of its own thing.

**Honest limit:** Roblox can't do P.T.'s photoreal detail. It *can* get close on mood: lighting, grade, composition, pacing and sound. Anything that looks "Roblox" breaks the spell, so the art avoids plastic, saturated colours, chunky block props and bright UI.

## Rules that beat everything else

1. **Pools of light, real darkness.** Each light source reaches far and fades gradually into true black, like a lamp in a real house at night, never a flat, evenly lit room (owner's playtest note, 2026-10-02). Corners and far walls may fall to black. What must stay readable without the flashlight is the lit path through the room and at least one way out. Where a room's darkness hides its doorways, fix it with lighter door trim or light spilling through from the next room, not by flattening the light.
2. **Art never hides evidence.** Tell props must be readable at 6 studs under the flashlight. Keep PropFactory's child names (`Dial/Face/Time`, `Paper/Writing/Text`, …) when restyling.
3. **Seams must be invisible.** Seam panels, fake walls and phantom doors use exactly the same material, colour and trim as the wall around them. If a texture lines up badly on a seam, players learn to spot divergences by texture. That would break the core mechanic.
4. **Exits always read.** Door frames get lighter trim than the walls, and a real doorway never sits in pure black (doc section 3, the fairness contract).
5. **Implication first, gore late** (Moderate ceiling, doc section 9). Wrongness comes from proportion, stillness, sound and things being slightly off. Blood appears only from Breaking onwards (see the Drift arc), and never past Moderate.
6. **Decay is shared; divergence is personal.** Drift-driven changes (photos going wrong, lights dimming, red hunt lamps) happen identically for every player, and they're never registered as things you can Witness. Only the divergence system makes players see different things. Otherwise atmosphere gets mistaken for evidence, and the design doc lists "divergence feels confusing instead of scary" as a top risk (section 13).

## Scale

Using a standard character (about 5.5 studs, so 1 stud ≈ 0.32 m):

| | Ours now | Real house |
| --- | --- | --- |
| Room | 40 studs ≈ 12.7 m square | 4–5 m; a hallway about 1.1 m wide |
| Ceiling | 12 studs ≈ 3.8 m | 2.4–2.7 m |
| Doorway | 6 × 8 studs ≈ 1.9 × 2.5 m | 0.9 × 2.0 m |

Roblox spaces are normally built about 1.5× real size so the camera and movement feel good. Ours are 2.5–3×, which is a big part of why the rooms feel like empty warehouses. P.T. lives on tightness.

- **Ceilings drop to about 10 studs** (3.2 m). This is visual only, and it also puts The Guest's head (8.4 studs) close to the ceiling, which is exactly the kind of wrong proportion we want. Doorways stay 6 × 8 studs for squads and chases.
- **Corridor rooms are real corridors** (all three corridor templates: Hallway, Back Hall and Attic Landing, since 2026-10-02). Inside the 40-stud cell, four closets fill the corners, leaving a plus-shaped hallway 14 studs wide (`corridor = { halfWidth = 7 }` in `Data/Rooms.luau`). An arm that ends at an outside wall is filled in too (`Logic/Corridor`), so the plus becomes a straight, L or T corridor that reads as a hallway. An arm stays open when it leads to another room (through a doorway, or to a solid wall where a phantom doorway can appear) or when it holds a window, a hiding spot, or a Lantern room's shrine. The closets and fills match the walls exactly. Furniture, floor slots and the shrine sit in the 3-stud strips between the doorway lanes and the closets; wall slots and paintings hang on the closet faces; anything in a filled arm is left out. The Attic Landing's window closes the end of its south arm, so when that arm faces outside the corridor ends in moonlight. Doorway lanes and the centre stay clear, and the stalker's standing spots sit inside the junction. Across 1,000 generated houses, 96% have at least one corridor (2.7 on average).
- **The 40-stud grid itself stays.** Shrinking it would touch the generator, the navigation and the tests. Too big for a visual pass.

## Palette

| Role | Hex | Notes |
| --- | --- | --- |
| Wall base, dirty cream | `#A39A82` | Hallways and the default wall; stained, never clean white |
| Wall base, nicotine plaster | `#8C7B63` | Living spaces |
| Wallpaper: faded sage | `#6E7462` | Study, guest room |
| Wallpaper: dusty rose | `#8A6C6C` | Dining room, sewing room, master bedroom |
| Wallpaper: ink blue | `#4A5468` | Nursery, kids' bedroom, music room |
| Wood, dark walnut | `#4A3324` | Doors, trim, formal furniture, panelling |
| Wood, honey oak | `#7A5536` | Floors, kitchen cabinets |
| Fabric: mustard / rust / bottle green | `#8F7434` `#7A3F2C` `#34473A` | Sofas, curtains, rugs: muted, never bright |
| Light: P.T. tungsten | `#E8C27E` | Every warm practical light. Yellower and sicklier than a cosy orange |
| Light: moonlight | `#7896DC` | Windows only |
| Light: fluorescent | `#D7EBE1` | Utility rooms; slightly green on purpose |
| Light: CRT glow | `#8CAAFF` | TVs |
| Light: Lantern (safe) | `#FFBE6E` | Lit Lantern rooms; the only truly warm, comforting light |
| Shadow tint | `#23261E` | Shadows lean olive, not neutral black (the P.T. grade) |

**Reserved colours.** These carry meaning, so the house never uses them as decoration:
- **Brass `#C4965C`:** truth and the interface: anchored objects, Case Board pins, the Witness Camera flash, UI accents (already `Ui.Theme.accent`).
- **Hunt red `#B8322A`:** hunts only. In the P.T. spirit, the house's **actual lamps** turn this red during a hunt, not just a screen tint.
- **Decay green-grey `#CDE1D7`:** what Drift pulls the image towards (already `EffectsController`'s tint target).

## Materials

- **Walls:** patterned wallpaper in three families (sage, rose, blue), plus dirty cream and nicotine plaster. Formal rooms get a dark wood **dado rail and wainscot** on the lower third. Every room gets **baseboards and crown moulding**; trim catching light is the cheapest way to make a box read as a room.
- **Floors:** worn oak planks in living spaces and corridors, low-pile carpet with faint stains in bedrooms, checkerboard linoleum in the kitchen and laundry, small hex tile in the bathroom, stained concrete in the garage.
- **Ceilings:** popcorn plaster slightly darker than the walls, with a water stain in a few rooms.
- **Doors:** dark panelled wood with brass knobs. Some real doors rest slightly ajar with darkness behind them (P.T.'s bathroom door).
- **Grime layer:** one shared set of decals (water and rust stains, scuffs by door frames, dust shadows where pictures hung), so the whole house ages consistently.
- **How they're made:** `generate_material` makes about 8–10 `MaterialVariant`s for the whole house (3 wallpapers, 2 plasters, 2 woods, carpet, linoleum, tile, concrete). Hero props get `SurfaceAppearance`. Textures are 1024 px at most. Every external asset goes in a licensing note, and asset ids go in `Assets.luau`.

## Hero props

P.T. shows that a handful of believable everyday objects does more than a room full of furniture. These get real meshes and materials before anything else:

- **Radio** on a side table, with a muffled broadcast. It ties into the Radio tool and the future Dead Air anomaly.
- **Clocks** (wall clock and grandfather clock). Decorative clocks show ordinary, varied times from the same pool as the "Clocks disagree" tell, so a clue clock can't be spotted by its time alone. Comparing with a teammate stays the only way.
- **Family photos** in frames on walls and side tables. As Drift rises, the faces turn away, blur or go missing.
- **Ceiling pendant lamps, table lamps and sconces** with fabric shades: the light sources themselves.
- **Doors**, with frames, knobs and hinges.
- **Telephone** on a hallway table, for later scares.

## Lighting mood by room family

Every room keeps **one motivated key light** that casts shadows, as the doc requires, with a long reach (lamps 44 studs) so it throws a pool that fades across the room. There are no flat fill lights: they made rooms look evenly lit, and because fills cast no shadows they leaked through walls. A room lit only by a window or TV gets one soft **bounce light** just in front of it, which does cast shadows. Ambient light is kept low, so darkness is real. Values live in `Config.Lighting`. The 22 templates fall into five families:

| Family | Rooms | Key light | Mood |
| --- | --- | --- | --- |
| **Corridors (the P.T. rooms)** | hallway, hallway runner, attic landing | One hanging pendant lamp, plus light spilling in from the next room | The signature space: narrow, dirty cream walls, one pool of sickly light, long sightlines. Framed so a figure at the far end is backlit (the doc's first "thumbnail moment"). |
| **Lamp-lit living** | foyer, living room, den, dining room, study, music room, sewing room | Shaded tungsten lamps, 1–2 pools | Pools of light with darkness between them. "Someone left the lamps on." |
| **Moonlit bedrooms** | master, guest, kids', nursery | Moonlight through the window, plus a small night-light or bedside lamp | Cool/warm split: blue floor shapes from the window, one small warm point. The quietest rooms. |
| **Utility** | kitchen, bathroom, laundry, pantry, mudroom, garage | Overhead fluorescent tube or a bare bulb | Flat, harsh, slightly green, with a fridge-hum feel. The first lights to flicker as Drift rises. |
| **Big windows** | sunroom, playroom | Moonlight, large window shapes across the floor (light shafts) | The most open and eerie rooms, where the outside feels close. |

**Mood tags adjust the recipe.** *Open* rooms get a second pool of light; *tight* rooms get one closer, dimmer source; *watched* rooms get a light behind or across the room, so silhouettes read.

**The run's arc**, with P.T.'s escalation mapped onto Drift (colour and flicker are already wired in `EffectsController`; this sets the target):

| Drift | Look | P.T. beat |
| --- | --- | --- |
| Calm (0–20) | Yellow-green tungsten grade, light grain. The house looks ordinary. | The first loop: it's just a hallway |
| Uneasy (20–40) | Slightly cooler and less saturated. | Small things moved; a door that was closed is ajar |
| Fraying (40–60) | Utility lights flicker; grain thickens. | Footsteps and breathing that aren't yours |
| Breaking (60–80) | Contrast up, colour drains towards decay green-grey, the vignette closes in. Photos go wrong; the first stains turn out to be blood. | The house turns on you |
| Collapsing (80–99) | Nearly monochrome except the blood; lamps dim. Only Lantern rooms keep their warmth. | The red-light loops |
| During any hunt | The house's lamps turn hunt red. | |

**Hub:** the one warm, fully lit, safe-feeling space: an investigators' field office, the opposite of the house. Signs get consistent text sizes, and the menu shouldn't collide with Roblox's chat hint.

## Softening the image

Roblox renders everything perfectly sharp, clean and evenly in focus, which reads as clinical. Four subtle layers take that edge off. Each is subtle on purpose, because heavy bloom and blur read as dreamy, not dreary. Values live in `Config.PostFX`.

- **Bloom:** threshold just above lit surfaces, so lamps, windows and screens halo but a lit face doesn't glow.
- **Film grain:** a fine animated noise over the image (the 32 px noise tile that ships with Roblox, so nothing to upload). The noise is darkened so it adds texture without lifting the blacks. It thickens as Drift rises, and "Reduce grain" turns it off.
- **Depth of field:** sharp out to about 40 studs, so The Guest still reads at 30, then softening like a real lens. The room beyond a doorway goes slightly soft.
- **Softer shadows:** `Lighting.ShadowSoftness` 0.6.
- **Atmosphere haze doesn't help indoors.** Roblox's Atmosphere is built for outdoor distances; even at double density it barely shows across a 40-stud room. Depth of field does that job instead.

The real cure for "clinical" is still geometry and materials: bevelled trim, worn textures and grime (steps 3–4 below). Post-processing can only soften what's there.

**Atmosphere effects in play:**
- **Dust:** soft round motes of varied size gather around each room's key light, in nested layers that are thick and bright at the lamp and thin to faint at the edge, so the dust fades out with the light instead of ending at a hard edge (owner's playtest). Each layer is set by density, so a lamp in a corner doesn't pack its dust tighter. They're drawn additively and lit by the scene, so they only show where light falls, and they glint as they drift. A slow, wandering air current carries each room's dust together. Roblox has no volumetric light, so these are what sell "dust in a lamp beam"; light shafts (step 5) will make them read even better.
- **Lights near The Guest:** lights within 30 studs of its body sag to as low as 55%, easing in and out, so you feel it before you see it.
- **Flashlight:** its aim trails slightly behind quick turns, like a handheld torch. The camera itself never moves.

## Interface

There's **no crosshair**. Whatever you're close to and looking at gets a small marker attached to the object itself (`UI/FocusMarkers`), so the screen stays clear and the house does the talking.

- **What a marker shows:** a thin brass ring on the object, its name in the typewriter font, and keycap hints for what you can do: `[E] Open`, `[Q] Witness`.
- **One marker per object:** a door's Open, Brace and Witness share one marker.
- **When it appears:** Witnessable objects show their marker within 14 studs when you look at them; holding Q shows it at any range. Prompts (doors, hiding spots, revives) show when Roblox says they're in reach, at full strength when you look straight at them and faint at the edge of view.
- **Hold progress** is a hairline under the actions.
- **Input:** keys match your input (keyboard, gamepad glyphs), and on touch the action rows are tappable.
- **Cursor:** the mouse cursor is hidden in first person; menus that free the mouse bring it back.
- **Accessibility:** a "Centre dot (aiming aid)" toggle in Settings, off by default.
- **Hub bloom:** the hub uses a higher bloom threshold than the house, because it's brightly lit.

## The Guest

**Concept:** a dinner guest who stayed far too long. Polite, patient and wrong.

- **Silhouette first.** Tall (8.4 studs, already in `Archetypes`) and thin, with arms a little too long, narrow shoulders and a small head. It must read at 30 studs against a lit doorway (doc section 8). The baseline fails this: today the head is the only visible part.
- **Clothes:** a dated, slightly too-big dark suit (`#121114`, already set). The cuffs and collar of a pale shirt give the body edges you can see in low light.
- **Face:** a pale, smooth, porcelain oval (`#C4BEB2`, already set) with only the *suggestion* of features: shallow eye hollows and no mouth. The face is the one light point on the body. When the flashlight hits it, two faint eye-shine points appear.
- **Late form (Moderate):** from Breaking onwards, and in the final hunt, the porcelain is cracked and the eye hollows bleed. The polite guest was never a guest. Earlier tiers keep the clean face, so the change itself is a scare.
- **Posture:** hands clasped in front, a slight bow, the head tilted 14° (already set). "Polite posture" is the archetype's rule.
- **Movement:** stillness, then short bursts. Joints bend a little too far. Budget 6–10 animations, as the doc says: idle-watch, turn, stalk-walk, run, peek, intrude, grab, retreat.
- **P.T.'s lessons:** heard before it's seen (a breath or a floorboard right behind a lone player); rarely seen in full; standing in the doorway you just walked through; never runs into view in the early tiers. It is simply *there* when you turn around. Late in a run it appears closer, and in the light.
- **Build:** a custom **R15 rig** made from generated meshes (`generate_mesh`), not one static mesh, so it can be animated and the existing code keeps working.

## Sound (for the later audio pass)

The design doc says audio does at least half the work, and P.T. proves it. That's a separate pass, but the art serves it: every hero prop that could make a sound (radio, clocks, fridge, phone, pipes) is placed so the sound has a believable source. The P.T. lessons for that pass: near-silence as the default, a muffled radio, creaks with a location, breathing behind a lone player, and rare loud stingers.

## Performance budget

- 4–6 shadow-casting lights visible at once (doc section 8). Every room has one; window and TV rooms have two (key plus bounce). That fits as long as only a few rooms are in view, but it still needs a MicroProfiler check in a focused Studio window (an unfocused Studio window is throttled to about 15 fps, so it can't be measured through the MCP tools).
- **Lighting changes take a few seconds to settle** in Future lighting. Any effect that changes a light's range or enables a light suddenly should expect a short delay; brightness flicker is fine.
- About 8–10 MaterialVariants for the house, with textures of 1024 px or less.
- Merge static trim per room so the instance count stays low.
- Low-end mode turns off grain, depth of field and light shadows. Every lighting change also gets checked at low graphics quality.

## How the visual pass will run

Each step is small, gets before and after screenshots from the baseline angles, then passes the checks before it's committed:

1. **Lighting, grade and scale:** the five family light recipes, the P.T. grade, fixing the too-dark rooms (rule 1), and lowering ceilings to about 10 studs.
2. **Corridors:** one hallway template rebuilt as a narrow corridor and tested with the stalker, then rolled out to every corridor template with dead-end arms filled. *(Done 2026-10-02.)*
3. **Trim and doors:** baseboards, crown moulding, door and window frames, wainscot, doors left ajar. Window panes get a moonlit glass look instead of flat colour.
4. **Materials:** wallpapers, floors and ceilings through `generate_material`, plus the grime decals.
5. **Hero props and fixtures:** radio, clocks, photos, lamps, telephone; dust particles and window light shafts.
6. **The Guest:** model, then animations.
7. **Hub polish:** signs, layout, the chat-hint overlap.
