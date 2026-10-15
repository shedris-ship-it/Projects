# The visual rework, V7: the 1988 interface (build `2026-10-14.193`)

The owner: "Lets do V7", then "Show me what the new UI looks like afterwards so I can review". The plan (V7): a diegetic 1988 interface. The screen is nearly empty, and every menu is a thing from 1988: paper, a typewriter, pencil and ballpoint, a case folder, a notebook, a pencilled plan on graph paper, the computer's own screen. The owner approved uploading the paper textures during the pass.

Before, everything was flat dark panels in Gotham with brass outlines, and the objective was a purple line (`0_before_*.jpg`).

## The pieces (`Lib/Ui`)

- **The faces:**
  - Special Elite: typed, everywhere a screen asks for a font.
  - Kalam: handwriting, in pencil and blue ballpoint.
  - Accanthis: titles, an old book face.
  - Merriweather italic: film subtitles.
  - Inconsolata: the computer's green type.
  - All of them ship with Roblox, so nothing was uploaded for type.
- **The palette:**
  - New: typewriter ribbon, graphite, blue ballpoint, red pencil and rubber stamp, a green felt tip.
  - The purple "ritual" colour is retired; it's a pale parchment now, for the few old calls left.
  - Brass `#C4965C` is still the accent for what matters: a marker's ring, a button's hairline, the title card's rule.
- **The paper:** eight images drawn in code by `tools/paper.py` (numpy + Pillow, seeded, so they redraw the same) and uploaded (`Assets.Paper`):
  - a sheet of typing paper with a fold;
  - a slip torn off a notepad;
  - a manila folder with creases and a coffee ring;
  - tileable graph paper;
  - a ring-bound notebook page with holes and a red margin;
  - yellowed tape;
  - a soft shadow;
  - a CRT's scanlines.
- **The helpers:**
  - `Ui.paper(kind, props)` lays a paper on the screen with its shadow.
  - `Ui.tape`.
  - `Ui.typed`, `Ui.hand`, `Ui.title`, `Ui.subtitle`.
  - `Ui.stamp` (red rubber-stamp words).
  - `Ui.paperButton`: a typed word that gets a red-pencil underline when the mouse is on it.
  - `Ui.button`: pale typed words over the world with a brass hairline that draws out; `Plain` for a solid part of a thing (a piano key, a breaker).
  - `Ui.rule`.
  - `Ui.fit`, which shrinks a paper screen to a small window or a phone.
- **Found in Studio:**
  - **Paper is stretched whole, never nine-sliced.** Nine-sliced, Roblox drew the middle without the edges' yellowing, and a hard seam showed round every sheet. The screens are laid out near each paper's own proportions.
  - **A turned frame stops clipping its scrolling body,** so the map and the Dossier's report lie square. The other papers are turned a degree or so.
  - **Kalam draws at about two-thirds of the typed face's size,** so all handwriting is set larger.

## The screen in a run (`3_hud.jpg`)

- **The objective is a slip torn off a notepad,** taped up at the top. The phase and Drift's word are typed across its head ("LOCKED IN · calm"), and the objective is pencilled under it.
  - It fades in whenever any of that changes, with a rustle of paper, and fades away 14 s later (`Config.Interface`).
  - It stays during the run's last minutes (the escape clock) and the Reckoning.
  - The map has its own copy taped to its header (`5_map.jpg`), so it's never more than Tab away.
- **Stamina is the edges of your sight closing in** as you tire, breathing with you when you're spent, along with the gasp you already had.
- **The torch's charge is on its beam:** under 30% the beam dims and yellows, and under 8% it dips now and then (`Config.Torch.Low`, client only; the rules' beam is the server's).
- **"Show meters"** in Settings brings back two hairline meters (breath, torch) and keeps the tool slots up. It's off by default.
- **The tool slots** show while you switch, pick up or raise the torch, then fade (`HotbarHold`).
- **Notices** are pale typed lines over the world, a short stroke of their colour before each, with no boxes.
- **Captions** are film subtitles: italic, pale, a soft dark edge (`9b_computer.jpg`: "[a computer beeps]").
- **The key hints,** typed small at the bottom right, show for the first three minutes; the full list is on the how-to sheet (F1).
- **The squad list** shows only with a squad (alone, your own name was no news).
- **The focus markers:**
  - the brass ring on the thing;
  - its name in small typed capitals;
  - under the name a brass hairline that fills as you hold E;
  - keys in thin brass outlines.
- **The radio's static meter** is drawn in plain characters (`|||||.....`): the typewriter face has no block glyphs. Likewise the key ring says "keys:" instead of a key emoji, and the em dashes and the ellipsis went.

## The screens

- **The title card** (`1_title_card.jpg`): every night opens like a film: "T H E   H A L F W A Y   H O U S E", a brass rule, and the hour (from the run's seed, between 1 and 3 AM, the same for the whole squad).
  - While the house is built it sits on black ("Your friends will see something different.").
  - Then the black lifts and the card stays over the house for a few seconds.
- **The lobby** (`2_lobby.jpg`, `2b_lobby_ready.jpg`):
  - a manila case folder with a typed label taped on ("CASE 88-0412 / THE HALFWAY HOUSE") and the game's name in Accanthis;
  - the choices typed;
  - the difficulty's note and the countdown in pencil;
  - READY a red rubber stamp.
- **The note reader** (`4_note.jpg`): a sheet of notepaper, ruled with a red margin and taped at the top, written in blue ballpoint with one line of writing to each ruled line.
- **The map** (`5_map.jpg`): a plan pencilled on graph paper.
  - Rooms are outlined in graphite and named by hand; a lantern's room is shaded, and a done room gets a lighter outline and a green tick.
  - The room you're in is gone over with a highlighter.
  - Locks and marks are in coloured pencil; you are in red.
  - Rooms read from the house plans are in blue pencil.
- **The journal** (`6_journal.jpg`): a ring-bound notebook page. The writing starts at its red margin; headings are written twice and underlined, the rest in ballpoint; the notes you've read are pasted in.
- **Settings and how to play** (`7_settings.jpg`):
  - two typed sheets;
  - the how-to and the keys on the left;
  - the photosensitivity note in red pencil in its margin;
  - on the right, "FORM 88-2, tick what you need", with typed boxes, X'd.
  - The how-to's text is word for word as before (his three rules).
- **The Dossier** (`8_dossier.jpg`, `8b_dossier_lost.jpg`):
  - a police case file: an incident report typed on a sheet laid in a folder;
  - "CLOSED: GOT OUT" or "MISSING" stamped across it;
  - the night in numbers pencilled on a slip taped beside it.
- **The puzzles look like the things:**
  - **the computer** (`9b_computer.jpg`): a beige plastic set with its badge and LED; a curved green screen; phosphor type that glows; scanlines and the tube's dark edges;
  - **the fuse box** (`9_fusebox.jpg`): painted steel, riveted, a yellow warning sticker; each breaker a bakelite lever up or down with its lamp; masking-tape labels;
  - **the padlock** (`9c_padlock.jpg`): a brass body under a steel shackle, its wheels stamped steel;
  - **the safe and the piano:** they kept their looks, with the new type, plain arrows (the triangles were glyphs the face may not have) and solid keys. They weren't in these houses' shots.
- **Down, an echo, out** (`10_downed.jpg`): typed capitals and a subtitle over the world, with no box. The bleed-out and a friend's pull are hairlines.

## Debugging

- F2 `ui note|dossier|settings|title|toasts` opens each screen with made-up contents (`UIController:_debugUi`), alongside `ui map|journal|close`.
- `seen all` marks every room and doorway seen, so the map can be judged whole (`MapService:DebugSeeAll`).

## In Studio (build .193)

Every screen above was opened and shot in a play test (seeds 1800820264 and 3), with a clean console.

- **Text fit:** a scan of every visible label's `TextFits` on the HUD, settings, Dossier, note, map, journal and toasts found one overflow, the journal's one-line summary, now shortened.
- **Gate A** is unchanged: parts 2451, hash 2057680657.

**Not checked in Studio:**
- the safe's and the piano's screens (neither house had them);
- the ping wheel, the music box's tune strip and the speak box: they only took the new type;
- the stamina edges by eye while running;
- the torch's low-battery look;
- the "Show meters" setting turned on;
- the title card over black (the house builds in about a second, too quick to catch);
- a phone-sized window;
- several players (the squad list, the downed markers).

They're in TC-296.

## Left for later

- **Photos in the Dossier:** the plan's case file has photos. The folder has room on the right for a polaroid or two (a shot of the house, his mask) once there's a way to take them, maybe with V8's cutscenes.
- **The ping wheel, tune strip and speak box** could become things too (a radio's dial, a page of the music box's sheet music).
- **The notebook's holes** stretch into ovals on the wide journal. A landscape notebook page would keep them round (one more upload).
- **The Dossier stays open into the next run** until it's closed (as before); it could close itself when a new house starts.

## Checks

628 tests, compile, selene 0 errors and 0 warnings, `rojo build`.
