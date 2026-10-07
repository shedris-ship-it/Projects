# Art direction: The Halfway House

> **Status:** approved (2026-10-02). The owner chose the 1988 setting, The Guest concept, P.T. as the reference, a **Moderate** content rating, and a narrow-corridor prototype. The before-shots it refers to are in [`baseline/2026-10-02`](baseline/2026-10-02/README.md).

> **Owner's decision (2026-10-04):** the house becomes an **old mansion, still lived in, in 1988**: the same era, props and P.T. mood, with grand architecture (a double-height entrance hall with a split staircase and gallery, panelling, chandeliers, portraits) over two floors. See [`plans/mansion-generation.md`](plans/mansion-generation.md). This guide is updated for the mansion in phase M4; until then its rules still apply room by room.

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
- **Camera tricks.** Revised 2026-10-03 (owner): head bob, a little roll sway and a sprint FOV kick are in, because movement should feel heavy (`Logic/Feel`, `Controllers/FeelController`). Comfort comes from the **Camera motion** slider in Settings (0 turns all of it off) and from the rules: only the camera's position and roll move, never its pitch or yaw, so aim, the flashlight and the server's view of where you look are unaffected. No tilt or roll is ever used by an anomaly. Grain, vignette and depth of field are fine, and players can turn grain off.
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
- **Brass `#C4965C`:** what matters and the interface: lock plates, key tags, the table's place cards and candles, UI accents (already `Ui.Theme.accent`). (Anchored objects, Case Board pins and the Witness Camera flash retired with the clue loop.)
- **Hunt red `#B8322A`:** hunts only. In the P.T. spirit, the house's **actual lamps** turn this red during a hunt, not just a screen tint.
- **Decay green-grey `#CDE1D7`:** what Drift pulls the image towards (already `EffectsController`'s tint target).

## Materials

- **Walls:** patterned wallpaper in three families (sage, rose, blue), plus dirty cream and nicotine plaster. Formal rooms get a dark wood **dado rail and wainscot** on the lower third. Every room gets **baseboards and crown moulding**; trim catching light is the cheapest way to make a box read as a room.
- **Floors:** worn oak planks in living spaces and corridors, low-pile carpet with faint stains in bedrooms, checkerboard linoleum in the kitchen and laundry, small hex tile in the bathroom, stained concrete in the garage.
- **Ceilings:** popcorn plaster slightly darker than the walls, with a water stain in a few rooms.
- **Doors:** dark panelled wood with tarnished brass knobs (kept off the reserved brass). Some real doors rest slightly ajar with darkness behind them (P.T.'s bathroom door). Casings are painted lighter than any wall, so exits read.
- **Trim:** dark walnut baseboards and crown moulding on every wall face. Where a wall has a seam, a baseboard piece across it shows while it's a wall and a doorway casing while it's a doorway, flipping with the seam for each player, so trim never gives a seam away.
- **Windows:** a painted casing and sill, and behind a faintly tinted pane the night sky glowing softly, lighter at the top, with dark muntins against it.
- **Grime layer:** one shared set of decals (water stains on ceilings, rust under windows and in utility rooms, scuffs low on walls, clean patches where pictures hung), placed from the seed so the whole house ages the same for everyone (`World/Grime.luau`). Wall grime keeps clear of seams and clue spots, so it's never read as evidence.
- **How they're made:** ten `MaterialVariant`s for the whole house (2 wallpapers, plaster, popcorn ceiling, oak boards, panelling, carpet, linoleum, hex tile, concrete), listed in `Data/Materials.luau`. The textures are drawn by `tools/textures.py`, since Studio's `generate_material` failed on every request. They're greyscale and seamless so the part colour tints them: one wallpaper covers the sage, rose and blue rooms. Textures are 1024 px at most and their ids go in `Assets.luau`. The variants live in the place as Rojo files (`assets/materials/`, written by `lune run tools/materials`), because game scripts can't create them. Hero props get `SurfaceAppearance`.
- **Patterned walls and seams:** a texture's pattern restarts on every part, so each seam gets a thin wall skin that flips with it (one piece while it's a wall, three around the opening while it's a doorway). Without it a hidden doorway would show as an outline in the wallpaper.

## Hero props

P.T. shows that a handful of believable everyday objects does more than a room full of furniture. These get real meshes and materials before anything else:

- **Radio** on a side table, with a muffled broadcast; it can be turned up as a lure (R2c fixtures) and ties into the Radio tool.
- **Clocks** (wall clock and grandfather clock), all with hands, showing times from `Data/ClockTimes` (the clue loop's clock tell is gone).
- **Family photos** in standing frames on dressers, chests, desks and the piano (`World/Dressing.luau`). As Drift rises the faces blur (60) and then go missing (80), for every player at once. Never Witnessable.
- **Ceiling pendant lamps, table lamps and sconces** with fabric shades: the light sources themselves.
- **Doors**, with frames, knobs and hinges.
- **Telephone** on a hallway table, for later scares.

The escape added props of its own (gameplay rework R2c), all built from code and due a pass in M4: the walk-in closet with mirrored sliding doors, keepsake boxes (brass-cornered wood, a painted tin, a velvet case), the glass display case, the key rack, the family's notes, the beige 1988 computer and dot-matrix printer, the fuse box, the wall safe behind a hinged painting, the music box, the crank door's roller shutter and wall crank, the dumbwaiter's boxed shaft and hatches, and the laid dining table with place cards and candles.

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
- **Flashlight:** its aim trails slightly behind quick turns, like a handheld torch. The camera only bobs with your steps (see Camera tricks).

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
- **The mask over the dark (the owner's choice, 2026-10-06; as built 2026-10-07, `Lib/GuestFace`):** his head is black; his face is a porcelain mask laid over it, smaller than the head and set low, so the dark dome of his head and the mask's rim show. The eyes are round and lidless (the owner, 2026-10-07: "like he doesn't have eyelids"), holes onto the black behind, each with a pin of light that follows you and shows as a pinpoint in the dark whenever he faces you (the owner preferred the bare dots to a glow halo), bright in your torch. Faint painted brows and rouge, hairline lips. The glaze is a painted decal on the mask's front (`Assets.GuestMask`, drawn by `tools/textures.py` `guest_masks`, uploaded 2026-10-07 with the owner's OK): ivory, patchy crazing, grime towards the rim; from Fraying a worn glaze with opened cracks and tear-tracks. The eye holes, the mouth's inside and the broken-away pieces are black Neon, so they stay voids even in your torch. Earlier the face was a porcelain oval: it read as an egg (`docs/progress/2026-10-07-guest/`).
- **Face (2026-10-03, superseded by the mask):** a pale, smooth, porcelain oval (`#C4BEB2`) with only the *suggestion* of features: shallow eye hollows and a smile that is far too wide.
- **The smile (owner, 2026-10-03, replacing "no mouth"):** it grows with Drift. At Calm it's a thin, closed line far too wide for the face. From Fraying (40) it stretches ear to ear and opens on too many small, uneven teeth. It also widens when he's close to you or backing away from you. One corner sits a little higher than the other.
- **Late form (Moderate):** from Breaking onwards, and in the final hunt, the mask is cracked and has slipped askew, and pieces have come away: behind them there is only black. No blood (2026-10-07: darker without it). Hairline crazing from Fraying. Earlier tiers keep the clean mask, so the change itself is a scare.
- **The body (2026-10-07):** a longer neck carried forward and a slight hunch, narrow sloping shoulders, coat tails, sleeves a little short so pale bony wrists show, thin legs.
- **The motion (2026-10-07, `Controllers/GuestController`):** in your torch he moves in stop-motion stutters (smooth in the dark; at Breaking, stutters always); the head snaps to your light before the body turns; held, he never moves a stud but his head tips to about 70° and his fingers drum, his neck cracks past five seconds and he breathes out when let go; from Fraying, up close, his mouth hangs open; each mood has its idle (Curious tips his head, Stalking hangs low, Playful nods, Patient doesn't breathe, Irritated twitches).
- **Posture:** hands clasped in front, a slight bow, the head tilted 14° (already set). "Polite posture" is the archetype's rule.
- **Movement:** stillness, then short bursts. Joints bend a little too far. He never turns his back on you: his head keeps turning to watch you up to 160°, about twice what a person can, while his body walks away. He ducks under every door frame, because he's taller than all of them. The doc's 6–10 animations are poses in `Logic/GuestPose`: idle (the polite clasp), hold (a frozen stare without breathing), walk, run, creep, back away, peek, zoom, lunge and bow, plus twitches.
- **In glass (2026-10-03, owner: both):** dark window glass and mirrors show his reflection when he's behind you, because he really is (`Lib/GuestReflection`, `Logic/MirrorMath`). Early in a run, one Witness may hear tapping and see his face at a window from outside while his body is elsewhere: the one deliberate divergence of him.
- **The catch:** a jumpscare drawn as a picture: his face, grinning wide open, eyes glinting, rushes in to fill the screen, lit from below on black, with a piano-string sting. The camera never moves.
- **P.T.'s lessons:** heard before it's seen (a breath or a floorboard right behind a lone player); rarely seen in full; standing in the doorway you just walked through; never runs into view in the early tiers. It is simply *there* when you turn around. Late in a run it appears closer, and in the light.
- **Build (2026-10-03):** a custom rig with R15 part and joint names, built in code from smooth primitives (`Stalker/StalkerModel`). Invisible joint parts carry welded clothes and porcelain. Each client builds the face, smile and long two-jointed fingers locally (`Lib/GuestFace`) and animates every joint itself every frame (`Controllers/GuestController`). Nothing was uploaded. Plan B, if the primitives ever look toy-like: `generate_mesh` for the head and hands.

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
3. **Trim and doors:** baseboards, crown moulding, door and window frames, wainscot, doors left ajar. Window panes get a moonlit glass look instead of flat colour. *(Done 2026-10-02, except the wainscot, which moves to step 4 with the wallpapers. Trim across a seam flips with it, see rule 3.)*
4. **Materials:** wallpapers, floors and ceilings, plus the grime decals. *(Done 2026-10-02, with textures drawn by `tools/textures.py` and the wainscot from step 3.)*
5. **Hero props and fixtures:** radio, clocks, photos, lamps, telephone; dust particles and window light shafts. *(Done 2026-10-02, except the light shafts: a beam without a purpose-made soft texture looked like a flat card. Decorative clocks and radios now share the clue builders, so neither gives a clue away.)*
6. **The Guest:** model, then animations. *(Model, face and procedural animation done 2026-10-03; the behaviour that uses them comes next. See [`progress/2026-10-03-step6b-guest-model`](progress/2026-10-03-step6b-guest-model/README.md).)*
7. **Hub polish:** signs, layout, the chat-hint overlap.
