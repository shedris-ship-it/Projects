# The visual rework, V5: the Guest remodelled (builds `2026-10-13.191`, `2026-10-14.192`)

The owner: "Lets do V5, the guest, make him look as unsettling and creepy as possible while staying within the moderate rating, it would be cool if his face could be animated really nicely in blender too with a smooth transition between his phases if possible."

Then, during the work:
- "Could we make sure he still has his glowing pinpoint pupils unless you think not having them works better."
- "I think the pupils are too big, make them small but readable."
- "I want the pupils to be tiny, like uncanny and clearly inhuman."
- "I actually want to eventually put in an animation for getting downed instead of just a jumpscare so keep that in mind and maybe make a note but you can treat the jumpscare as a placeholder or it can be repurposed."

He was the last thing in the house still built from blocks: a body of ~60 primitives (`1_before_old_front.jpg`, `1_before_blocks.jpg`) and a face of ~200 tiny parts.

## The design

The same Guest (docs/ART.md "The Guest"): the dinner guest who stayed far too long, a porcelain mask over the dark, the long black overcoat, the bony hands. His proportions and every joint are the game's (Logic/GuestPose's Rig), so nothing in the gameplay moves: sight, his head's place, poses, the crawl.

**The body** (`kitlib/guestbody`):
- a long wool overcoat to below the knee with folds in the skirt (two halves that part as he walks), the collar turned up round a long black neck;
- a dead carnation in the lapel, a grubby shirt and a dark tie in the V, horn buttons, a half-belt at the back;
- sleeves a little short over thin bony wrists;
- long knuckled fingers with long yellowed nails;
- thin trousers, cracked old dress shoes;
- a black head like a stocking pulled over a skull;
- rags at the hem from Breaking.

**The face** (`kitlib/guestmask`): a porcelain doll's mask, held to the face by nothing. It has round black eye holes with painted lashes and a fine line round them, thin brows arched too high (one higher), rouge, a small nose, and a little painted rosebud mouth. Across it, cheek to cheek, runs a hairline the porcelain will tear along. No blood anywhere: it stays within Moderate.

## Animated in Blender, blended in the game

The mask has 40 bones, and the porcelain moves on them, which porcelain mustn't:
- **The grin** tears open along the hairline as wide as `GuestPose.smile` says. Each of 15 columns of the lips parts by its share, past the painted mouth. The teeth stay put, so the lips draw back off two rows of small, uneven, clenched teeth.
- **The jaw:** past 60% open, everything under the hairline drops like a ventriloquist dummy's jaw. A giggle makes it chatter.
- **The poses** were set in Blender (`kitlib/guestmask.POSES`) and carried into the game (`Data/GuestRig` Face.poses):
  - Smile: the cheeks bunch and squeeze the eye holes into crescents.
  - BrowUp and BrowDown: his mood (Curious, Playful and Host lift them; Irritated and Stalking press them down). Held, he looks more and more delighted.
  - Wide: held, the holes stare wider the longer you look; the catch.
  - Droop: Breaking. His left eye droops and runs, the other stares, the jaw hangs crooked.
  - JawOpen.
- **Easing:** `Lib/GuestMask` weighs the poses and eases every weight, so the face never jumps. Now and then a cheek twitches.
- **The phases blend:**
  - Calm to Fraying: crazing, a fracture over the brow, flakes and grimy tear-tracks creep over the glaze in about 2.5 s (a shell over the mask fading in).
  - Fraying to Breaking: it cracks at once. Fractures and stains from two blows show (a second shell), three pieces come away and fall from his face to the floor, where they lie a while before fading, and the mask slips askew. A dry crack and a little breaking glass sound.
- **His pupils:** a pinprick of light in each black hole that follows you. They're tiny ("uncanny and clearly inhuman", the owner's pick) but never smaller on your screen than about a pixel and a half, so they still read across a room (`9_pupils_across_the_hall.jpg`). They're faint in the dark whenever he faces you and bright in your torch.
- **The fingers** have four bones each: they bend at the knuckle and the middle joint, and the stretch bones let them still grow by form (1, 1.22, 1.45) with the segments lengthening evenly.

Blender previews: `0_blender_face.jpg` (Calm, Fraying, Breaking, the catch, side on, from a player's eye height) and `0_blender_body.jpg`.

## How he gets into the game

- `tools/blender/guest.py` builds him, skinned to 97 bones. Each bone rests at the game's own joint with no turn: they're read from GuestPose's Rig, and the export checks it ("furthest from the rig 0.00000 studs, most turned 0.000 deg").
- The bake makes one atlas for the body and one for the mask. The mask's front is laid out by its paint, so the shells' paint is drawn straight into the same layout.
- It exports `build/kit/guest/guest.glb` and writes `src/shared/Data/GuestRig.luau`: where each bone rests, which part each piece rides, the grin's columns, the poses and the fingers. `--only=A,B` exports just some pieces for a re-import. `--preview` renders him posed by `Logic/GuestPose` (scratch `tools/_guestposes.luau` dumps the poses).
- Before building anything, I tested the route on the owner's own avatar's skinned parts, so no test upload was needed. A mesh built from its id with `CreateMeshPartAsync` stays skinned. It bends with parts joined by Motor6Ds, and with Bones a script makes.
- The importer turns the model 180° on its root bone and keeps every other bone square to it. So each mesh keeps its place against its bones, and the game's own bones put him the right way round.
- `Stalker/GuestSkin` dresses the rig: the same invisible joint parts and Motor6Ds, with 23 skinned meshes welded on, and the Bones made from `Data/GuestRig`. The mask hangs on its own weld (`MaskWeld`), which each client turns and slips. It's all or nothing: until every mesh is in, he's built from primitives as before.
- `Data/Kit` has a Guest group (the 23 ids), and `World/Kit` preloads it. The looks are `assets/kit/GuestBody`, `GuestMask`, `GuestMaskWorn` and `GuestMaskBroken`; the shells have `AlphaMode` Transparency. The dark behind the eye holes and the grin is its own mesh, drawn black Neon, so it's a void even in your torch.

## In Studio (builds .191, .192)

The owner imported `guest.glb` (23 meshes, 8 maps), then `guest_GuestMask_GuestMaskBroken_GuestMaskWorn.glb` for the fixes below. Seed 1800820264, solo, a clean console, all 23 meshes loaded:
- **Calm** (`2_calm.jpg`): the doll's face on his tilted head, the hairline grin through the painted mouth, the pinprick pupils.
- **Fraying** (`3_fraying.jpg`): crazing, the fracture and the tear-tracks; the grin open on the clenched teeth, the jaw parted.
- **Breaking** (`4_breaking.jpg`, `5_body_breaking.jpg`): fractures and stains, the forehead piece gone, the droop, the slip, the rags. The three pieces fell and landed on the floor (y 0.02), then faded.
- **Moving:**
  - the Reach at Breaking (`6_reach.jpg`): grown fingers spread like a spider's, the neck stretched long out of the collar;
  - the crawl (`7_crawl.jpg`);
  - the clasp. Every joint bends smoothly.
- **The catch** (`8_catch.jpg`): his face rushes in, the jaw dropped, eyes wide with pinprick pupils.
- **Gate A** is unchanged: parts 2451, hash 2057680657.

**Fixed along the way:**
- **The crack shells didn't show.** They were lifted only 0.0016 and 0.0032 studs off the glaze, and the glaze won. They're now 0.007 and 0.012 (one re-import).
- **The teeth baked nearly black:** at rest they're shut inside the porcelain, so the occlusion bake darkened them. The mask's occlusion is now light (same re-import).
- **The pupils were buried.** The mask's eye surface sits right on the black head, so pins set behind it were inside the head. They now sit at the hole's surface, opaque and dimmed by colour (a see-through Neon pin vanished in front of the black).
- **The catch's copy of him carried his tag.** The controller attached to the copy instead of him, and lost him when the copy went: later catches never showed, and his face stopped. Copies are untagged now, and the controller attaches only to him in the world.
- **Copies in viewports** (the catch, his reflection, his face at a window):
  - A Bone's pose isn't cloned, so the catch got his rest face. The copy takes his pose now.
  - With his joints stripped, every skinned piece drew rigid (the sleeves came apart at the elbows), because a skinned mesh bends only with bones on parts joined to it. The copy keeps his joints in a WorldModel, is moved by its root (his client's DrawnRoot) and follows his joints, bones and mask weld (`10_copy_in_glass.jpg`: the copy in a viewport, the Reach, skinned).
  - A viewport doesn't draw the shells' see-through cracks, only dark patches, so they're left out of copies.
- **The catch is a placeholder** (the owner will want a downed animation instead). His copy's own arms rise into his Reach round your face and his fingers hook, in place of the old stick-finger hands at the edges of the view. They mostly reach in out of frame.

**Not checked in Studio:**
- his reflection in a mirror or dark window: the copy in a viewport was checked (`10_copy_in_glass.jpg`), but not the pane itself;
- his face at a window: it came up with its meshes and no errors, but I couldn't frame it for a shot;
- the pupils in your torch beam (the bright, smaller pin);
- several players at once, each seeing his face ease differently by distance;
- the falling pieces landing on stairs;
- every mood's brows by eye.

They're in TC-295.

## Checks

628 tests (`GuestRig.spec`, new: the bones hang where the rig can make them and rest at its joints; the pieces are the kit's, the grin's columns and poses are whole, four bones down every finger), compile, selene 0 errors and 0 warnings, `rojo build`.

## Next

- **A downed animation** in place of the jumpscare (the owner, 2026-10-14). He takes you down rather than a screen-filling face: a short animation of his own, the catch kept as a placeholder until then.
- The rest of the plan: V4a materials and V4b architecture (one more import), V2's PBR light recipes, V6 bodies and 80s clothing and the torch, V7 the UI, V8 cutscenes, V9 polish.
