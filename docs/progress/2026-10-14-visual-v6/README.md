# The visual rework, V6: bodies, 80s clothes and the tools (build `2026-10-15.194`)

The owner: "Lets do V6". Their choices along the way:
- **The classic ROBLOX Boy and Girl bodies**, picked at first play and in Settings, labelled "Boy / Girl" (`0_bodies_compared.jpg`, `0_classic_on_base_bodies.jpg`).
- **3D clothes on the classic body** ("What about classic body with 3D clothes?"), Roblox's clothing templates downloaded for reference.
- **The quality rule:** "Make sure all the clothing is high quality with no clipping between layers ideally".
- **Shop-ready:** the clothes are data, so the lobby shop the owner plans can sell them later (no prices yet).
- Mid-pass, after the first import looked broken in Studio: "the clothes look pretty fucked up in studio lmao, see if we can make it all look good"; "the fit looks a bit unnatural due to the funnel-like nature of the shoes ... it flares out more than it needs to"; "The holding of the flashlight looks a bit unnatural", "the hand is going through the flashlight as opposed to actually holding it". All fixed below.

## Bodies (`Services/OutfitService`, `Data/Wardrobe`)

- Everyone spawns as **ROBLOX Boy or Girl** (`Data/Wardrobe` Bodies: the five classic part meshes each), through `LoadCharacterWithHumanoidDescription`, in their squad slot's skin tone (`Logic/Outfit.palette`).
- **Settings → Body: Boy / Girl** (the first item; the first-launch settings ask it). Picking the other one changes your body on the spot (`Humanoid:ApplyDescription`, `DataService.SettingsSaved`).
- A description's parts arrive after the character does and replace the painted ones, so each part is dressed as it arrives (`OutfitService:Apply`, ChildAdded).

## The clothes (`tools/blender/kitlib/wardrobe.py`, `World/Kit.wear`)

- **Four outfits**, one per squad member (`Data/Wardrobe` Outfits, `Logic/Outfit.wear`):
  1. a red flannel shirt tucked into stonewashed jeans, a brown belt, white sneakers;
  2. a green varsity jacket with cream leather sleeves and a chenille "C", jeans, sneakers;
  3. a teal windbreaker with a purple and white chevron, tan cords, sneakers;
  4. a mustard knit cardigan with suede elbow patches, cords, brown penny loafers.
- **Each garment is fitted pieces, one per body part** (a top: torso, upper and lower sleeves, a hem over the hips if it isn't tucked in; trousers: seat, thighs, shins; shoes), welded on the part, so it bends exactly as the body does. Real layered clothing wasn't possible: game scripts can't set a WrapLayer's cage ("lacking capability Plugin"), and a WrapLayer synced through Rojo crashed the Rojo plugin.
- **Built round both bodies' real shapes:** each part was measured in Studio (`kitlib/bodyshape.txt`: rings at 18 angles), and every piece encloses the larger of the two; the game stretches it to the part it's on (`Data/KitWear`, generated: each piece's size, where it sits, the size it was built at).
- **No clipping between layers:** each layer is shaped round the finished layer under it (`Piece.cover`, `tuck`), and `wardrobe.check()` measures every pair on both bodies: **worst 0.000** (`build/kit/wardrobe/report.txt`). That's at rest; when a knee or elbow bends, the pieces part where the body's own blocks do (`5d_studio_walking.jpg`).
- **The shoes** (the owner's note): the shoe now hugs the foot and its collar wraps the ankle; the trouser leg ends just over the shoe's top (`HEM_U`), a rolled cuff on the jeans, a plain hem on the cords (`1e_sneakers.jpg`, `1f_loafers.jpg`). Before, the trouser leg reached well down inside the shoe and the shoe flared round it like a funnel. Low-tops, because on the classic body the shin is as wide as the foot's top and a high-top's shaft came out a bucket.
- **Shop-ready:** `Data/Wardrobe` Garments (slot, pieces by body part) and Outfits; the meshes are `Data/Kit` Wear.

## What the first import showed, and the fixes

The first import (`3_first_import_*.jpg`) looked broken, though Blender's previews looked right. Three faults, all hidden by Blender drawing both sides of every face:
1. **Every right-side sleeve, leg and shoe was inside out.** Applying a negative scale already reverses the faces; `wardrobe.mirror` reversed them again. Roblox draws a face from the front only, so you saw the arm through the near side and the inside of the far wall.
2. **Everything baked nearly black.** All four outfits are built on the same body, and the ambient-occlusion bake counted the other outfits as cover. `bake.bake_piece(solo=True)` hides everything else while a piece bakes.
3. **Cuffs, hems and collars were see-through** from below or above: a single sheet of cloth has no inside. `shapes.line_open` gives every open surface an inside (a lining a cloth's thickness in, packed into its own 15% of the texture, and a rim on each open edge); closed solids (pockets, buttons, the "C") are left alone. In triangles first: a wavy quad split along the other diagonal in the lining bulged out between its corners.

The tools had the same fault: the torch's head showed through from the front (it now has a chrome reflector inside), and the lantern's bail and the radio's strap twisted inside out where their tubes turned upright (`toolkit._tube` carries its frame along the path).

**New checks, so this is caught before an import:**
- `tools/blender/wardrobe_visibility.py`: dresses both bodies in every outfit and looks from all round with rays; any face met from behind is a hole in Roblox. After the fixes: 0 on every piece (hems were 13%, cuffs 4-6%); the tools 0 (the torch was 7%).
- `tools/blender/wardrobe_preview.py` now shows the exported file itself (`wardrobe.glb`), faces drawn from the front only, as Roblox does (`--magenta` lights back faces instead: `4_back_faces_check.jpg`, none).

The fixed batch was imported again (43 meshes, their maps; ids in `Data/Kit` Wear and Tools, looks in `assets/kit`; a right side wears its left side's maps).

## The tools (`kitlib/toolkit.py`, `World/ToolModel`, `Kit.dressTool`)

A 1980s torch (knurled body, chrome head and reflector, rubber switch boot, lanyard ring), a hurricane lantern, a leather-cased transistor radio with a dial and aerial, a red crowbar, bolt cutters with orange grips, and a brown bottle of smelling salts (`2_tools.jpg`). What glows stays the game's (the torch's lens and switch, the lantern's flame). The server shares their meshes so your hands can hold them (`Kit.share`).

## In first person (`Lib/ViewModel`, `Controllers/ViewModelController`)

- **Your sleeves are on your arms.** They were welded on, but the arms live under the camera, where nothing is simulated, so the sleeves hung where the arm was made (`6_first_person_before.jpg`); now they're carried with the bones each frame (`ViewModel.carry`).
- **Your whole hand.** The arms were slimmed to 62% for the old block arms; the classic hand slimmed like that was a thin curved strip. Now it's whole (`Config.ViewModel.Arm.Thickness = 1`).
- **Your hand closes round what it holds** (`grip` in each pose, `fist()`): the fist's middle on the thing, the thing running through the fist (as a Roblox hand holds a tool), the wrist hanging off it toward your shoulder. The torch is held just behind its switch, a little further from your eye; the crowbar by its shaft, the bolt cutters by both handles, the lantern and the radio from above by the bail and the strap, the salts upright (`6b` to `6f`).

## F2

`outfit <n>` wears squad member n's clothes; `outfit lineup` stands both bodies in every outfit in a row in front of you (`5_studio_*.jpg`); `outfit clear`.

## Checks

- stylua, selene (0/0), compile (266 files), **635 tests in 96 specs** (the new `Wardrobe.spec`: bodies, garments and their slots, coverage by slot, outfits, every piece's fit), `rojo build`.
- In Studio: both bodies in all four outfits from the front, the back and walking; first person with the torch and every tool; a clean console through a run's start and the Guest's arrival. **Gate A unchanged: parts 2451, hash 2057680657.**

## Not checked, or open

- **Other players' view** of your clothes and tools with two or more clients (TC-297).
- **Weight:** about 40k triangles per dressed player (the linings doubled it); fine on PC, unmeasured on a phone.
- **The shoulders** sit a little above the torso, like 80s shoulder pads: the classic arm's top is level with the torso's, and the sleeve has to enclose it. The owner's call whether to flatten them.
- **Two imported `Scene` models** of the wardrobe sit in Workspace (the first import and the fixed one); the game builds everything from ids, so the owner can delete both.
- Extreme bends (a deep crouch, the crawl) show the pieces parting at the joints, as the body's own blocks do.

## Images

`0_*` the bodies; `1_*` the outfits as exported (Blender, faces from the front only); `2_tools`; `3_*` the first import in Studio (broken); `4_back_faces_check` (nothing seen from behind); `5_*` the fixed import in Studio; `6_*` first person, before and after.
