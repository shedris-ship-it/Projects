# Hair and faces: the sketches (2026-10-17)

The players had no hair and Roblox's default dot face, which broke the 1988 look. The owner approved hair and faces: "Go with your list and prices: the four free styles, the four paid ones, and faces that blink and react. Start with the sketches for me to look at." This is phase 1: the sketches for their picks. Nothing reaches the game yet.

## The faces: Roblox's own heads

The first plan was faces drawn from code (decals, a frame per expression). While those rendered, the owner asked whether Roblox's animated faces would do ("I'm not sure we have to reinvent the wheel"). After seeing them they chose that: "I like the dynamic heads, they already move the mouth when talking through voice chat and blink ... I want 6 free faces to start out with and no paid options just yet". They also asked that "the faces/head is the only thing changed when selecting faces": the Boy and Girl bodies stay for every garment. The drawn faces were dropped; their script and sheet are kept outside the repo (`build/scratch/hair-faces/drawn/`).

What Studio showed (2026-10-17, Edit mode, a Boy body built from a HumanoidDescription with only its `Head` changed):
- **Today's head is already a dynamic head.** The default head (`Head = 0`) has FaceControls and no face decal.
- **Nine free Roblox heads keep the classic shape:** Man Face, Woman Face, Check It, Silly Fun, Stevie, Dennis, Lindsey, Kenneth and Cindy (bundles 949, 948, 968, 299652, 946, 605, 607, 608, 606). Each is 1.1606 x 1.1815 studs. Rays cast at precise copies of Man Face's head and the default head measure the same shape: a round cylinder 0.58 in radius, its top and bottom edges rounded at 0.3. One fit of each hair style suits all of them.
- **Devon, Dylan, Denny, Oliver and Linlin don't:** smaller, taller or human-shaped heads. Left out.
- **They sit 0.084 studs lower on the neck** than today's head (1.394 over the UpperTorso, not 1.478). The clothes' collars are fitted round the head at today's height. Phase 2 raises the head's neck attachment to today's height, so collars, the first-person eye and the poses stay as measured.
- **They react when the game sets their FaceControls** (scriptable, 0 to 1): eyes shut, squints, brows up or knitted, the jaw dropped, a grimace. `faces_candidates.jpg` has each at rest, scared (`UpperLidRaiser`, `InnerBrowRaiser`, `JawDrop`, `LipStretcher`) and downed (`EyeClosed`, `BrowLowerer`, `NoseWrinkler`, `CheekRaiser`, `LipStretcher`, `UpperLipRaiser`). Man Face and Lindsey keep their smirks in every pose.

**Claude's six:** Dennis, Kenneth, Man Face, Lindsey, Cindy and Woman Face: the ones with real eyes and brows. The other three are Roblox's dot faces (Stevie is the face everyone has today).

## The hair: eight styles

`tools/blender/kitlib/hair.py`, previewed with `tools/blender/hair_preview.py`. Every style is a thin cap over the scalp (its edge the hairline) and tapered locks laid over it. Each lock is walked over the measured head from its root along the style's combing, held at its height over the scalp, so it never goes through the head. Below the head a lock falls straight and flares out a little, clear of the collars and shoulders. The ponytails' caps run from the hairline up to the tie. The crew cut is the cap alone, and the perm a deep cap of curl clumps.

| Style | Price | As sketched | Triangles |
| --- | --- | --- | --- |
| Crew cut | free | Short back and sides, a little longer on top | 4.9k |
| Side part | free | Parted on the left, combed over with a wave at the front | 4.3k |
| Shoulder length | free | A middle part, straight down both sides and the back to the shoulders, the ends turned out | 10.3k |
| High ponytail | free | Pulled up to a pink scrunchie high at the back, the tail falling to the shoulders | 7.6k |
| Feathered flip | 800 | Parted in the middle, the sides swept back in layers, the ends flipped out at the jaw | 8.7k |
| Side ponytail | 1,000 | Pulled over to a teal scrunchie on one side, the fringe teased up and rolled back | 7.9k |
| Mullet | 1,500 | Short and full on top, short sides, long at the back over the collar | 6.2k |
| Big perm | 2,000 | A cloud of curls, high and out past the jaw, open at the face | 9.4k |

**Hair colours** (the owner: "I also want the hair color to be adjustable, if possible"): the baked map is grey and the game tints it (SurfaceAppearance.Color, as the cars' paint does). So any style comes in any colour at no cost: nine natural shades are proposed (`kitlib/hair.py` `COLOURS`). The scrunchies are pieces of their own, so the hair's tint never reaches them.

## Sheets

| File | What it shows |
| --- | --- |
| `hair_sheet.jpg` | Every style on both bodies from the front, with the six faces; the nine colours on two styles |
| `hair_angles.jpg` | The same from three-quarters and from behind |
| `faces_candidates.jpg` | The nine heads at rest, scared and downed, Claude's six marked |
