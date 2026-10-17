# The lobby's story: the foundation, the clutter sketched, and the new-map checklist

The owner, away from their computer, picked two of Claude's ideas for a more detailed mall: "Lets do 1 and 2, atleast build the foundation for it, I want input on the story, but please make a file for all the things in the lobby that need to change during new map updates". So:
1. the story clutter is sketched, not built;
2. the things to read are built as a foundation with draft texts;
3. the story itself is a set of questions for the owner;
4. `docs/NEW-MAP.md` is new.

## Things to read (`Data/Lore.luau`, `Services/LoreService.luau`)

- **Each one is a Read prompt on a piece already in the garage camp,** so nothing new had to be placed by eye:
  - the case file on the desk;
  - what's pinned on the case board;
  - Dot's radio log by the CB radio;
  - the first evidence box's list;
  - Ray's note on the spare cot.
- **E reads it on the note reader the run uses.** Files and lists are typewritten (smaller, so a page holds more); notes are in ballpoint. They stay out of the run's journal.
- **All five are drafts,** written from the options marked *Claude's pick* in `docs/plans/lobby-story.md`. They show only in Studio, so nothing reaches the live game until the owner settles the story and they're marked kept.
- **F2 `lore`** lists them; `lore <id>` reads one wherever you stand.
- **Spec'd** (`tests/specs/Lore.spec.luau`): each sits on a block that's there, is about a map that exists and fits its sheet, and no two prompts overlap.
- **Checked in Studio:** the five prompts stand where intended, and each opens with its text fitting the page (the case file 306 of 468 pixels, the longest). No errors.

## The story: questions for the owner (`docs/plans/lobby-story.md`)

What's already true in the game, then seven questions, each with options and Claude's pick:
1. who the investigators are;
2. why the dead mall;
3. what the Halfway House is;
4. who the Guest is;
5. the voices (Dot and Ray in the drafts);
6. the names not picked yet;
7. how much there is to read.

The biggest pick builds on something the run already does: every house is a different family's, drawn from eight surnames. So the drafts make the house one that moves. It's never on the same street twice, a different family's name is on the mailbox each time, and none of the families has been found.

## The story clutter, sketched (`tools/blender/kitlib/clutter.py`, kit.py `story`)

`sheet.jpg` has the four views; `camp.jpg`, `camp_close.jpg`, `board.jpg`, `papers.jpg` and `dead.jpg` are the full ones.

| For | Pieces |
| --- | --- |
| The camp | A green camp stove with its kettle and pot, on a crate of tins. A stack of pizza boxes with two coffee cups. A twin-deck boombox and its tapes. The TV cart: a woodgrain TV, the VCR, and the crews' tapes ("88-0412 CREW 3", "CH 19 NIGHTS"). Three yellow raincoats and a torch on a peg rail |
| The case board | A county map of sightings (SIGHTINGS 88-0412, red pins with dates, the mall and the quarry marked). Three newspaper clippings with draft headlines: HOUSE 'NOT THERE' BY MORNING; FAMILY MISSING, TABLE LEFT LAID; TRUCKER: 'SOMEONE WAS COMING TO DINNER' |
| The dead mall | A yellow wet-floor sign and a mop bucket (by the court's drip, say). A stack of food-court chairs (in the dead shop). A SALE banner fallen and crumpled on the floor (in the concourse behind the grille) |

- 14 pieces; each was built and measured in Blender, and the sketches were rendered faces-from-the-front-only, as Roblox draws them. That rendering caught the raincoats' outline crossing itself, now fixed.
- Nothing is baked or exported, and nothing is placed in `Data/Mall`: the owner picks what to keep first. Each kept piece is then laid out by hand in the grey box, as the shops were, and goes in one batch to import.
- The clippings' headlines, the sightings map and the tapes' labels are about The Halfway House and wait on the story's answers.

## The new-map checklist (`docs/NEW-MAP.md`)

Everything in the lobby that names a map, where it lives, what changes and what needs the owner, in six sections:
1. the map's own entry;
2. the video store: the tapes, their covers, the standee, the coming soon posters;
3. the garage: TONIGHT on the whiteboard, the case board's photos and plan, the red string, the readables, the clippings, the map of sightings, the tapes, the evidence boxes;
4. the court, shops and diner: the record boards, the arcade, the ads;
5. the run's screens that name the map;
6. a before-release list.

CLAUDE.md lists it with the docs to read first.

Two small changes so fewer of its rows need editing later:
- **The case number is data:** `Data/Locations` `case`. The case folder's label and the Dossier's header follow the location.
- **The diner's boards count only The Halfway House's runs** (`Records.Location`). A second map's runs can't land on them until it has boards of its own. Spec'd.

## Checked

- **Tests:** 733 pass (3 new).
- **Other checks:** compile, lint and the build all clean.
- **In Studio:** the readables, their text and the case label, with no errors.
- **Not seen in Studio:** how the prompts look in the camp. The display was asleep. TC-339 and TC-340.

## Kept, placed and baked (build .220)

The owner, home: "I approve the clutter". So:
- **Placed in the grey box** (`Data/Mall` blocks; `Data/Kit` Parts, ids to come):
  - in the camp: the stove on its crate of tins by the camp table, the boombox and the pizza boxes at the cots' feet, the TV cart facing the cots, the raincoats on the north wall over the bagged cot;
  - on the walls: the three clippings on the case board between the photos, the map of sightings over the evidence boxes;
  - in the court and the dead mall: the wet-floor sign and the mop bucket either side of the court's drip and its puddle, the chairs and the banner behind the grille.

  Checked from above and at eye level in Studio. Every piece is clear of everything else (a bounds check on each), and the mall's layout rules pass.
- **Baked:** `build/kit/story/story.fbx`, the 14 pieces and the car's whitewalls again (widened to 0.72 to 0.9 of the wheel, black tyre either side: in the garage's light the first ones read as the hubcap's edge).
- **The hole check** found three things, all fixed and checked again clean:
  - the crate's slats overlapped at the corners;
  - the chairs' bent leg tubes turned inside out at the bends (now straight square tubes);
  - the banner's lifted corner had no underside.

## Imported (build .221)

The owner imported `story.fbx`. All 15 pieces are filed (ids in `Data/Kit` Parts, looks in `assets/kit`), 384 kit meshes load, and every piece wears its mesh. Seen in play:
- the camp lived in: the TV cart facing the cots, the boombox, the pizza boxes and coffee cups, the raincoats;
- the map of sightings over the evidence boxes and the clippings among the photos;
- the wet-floor sign by the drip.

Behind the shutter's grille the chairs and the banner were lost in the dark, so they moved to the empty shop's front in the court. The fallen SALE banner now lies under the shop's own CLOSING DOWN banner, and the chairs are stacked just inside its grille.

The whitewalls still render as black rings, even plain white with no texture. Their faces point the right way in the export, so the likely cause is the ring's thinness (0.012 studs): the importer seems to weld its two faces' vertices, which cancels their normals. A 0.05-thick ring is exported for one more import.

**Fixed (build .222):** the owner imported the 0.05 ring (`story_CarWhitewalls.fbx`, id in `Data/Kit` Parts, size 7.01 x 1.8 x 10.8). It shows as a white band on both wheels.
