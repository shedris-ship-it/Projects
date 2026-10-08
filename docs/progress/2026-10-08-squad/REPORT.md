# The first squad playtest: the fixes (2026-10-08)

Branch `claude/overnight-foundation`, builds `2026-10-08.131` on, from `2026-10-06.130`.

The owner ran the first squad playtest on build `.130` and sent 17 notes. Physics sync was praised. The rest are fixed here, one work package (WP) per build. The plan is in section 17 of `docs/plans/gameplay-rework.md`.

## The owner's decisions (2026-10-08)

| Note | Decision |
| --- | --- |
| "Make the hands universal for all slots" and "make everything grabbable with E" | **E does it all.** Slot 4 (bare hands) goes. From any slot: tap E to open, pick up or use; hold E and move the mouse to drag or push. While carrying, click to throw (hold to charge) and E to put it down. The torch stays at full beam. Hold-click grabbing still works. |
| "Players can mess around with the Guest and get in his personal space while he's backing away" | **A scare, then a down.** Crowd him once and he turns on you: lights out, his mask in your face, your torch dead, and he's gone. Do it again within about 3 minutes and he grabs you. Following him while he backs away counts. |
| "Maybe the Guest should shapeshift" | **A teammate only.** Late in the run, one player sometimes sees him far off wearing a teammate's look. Walk up to it and it's him. |
| "Hunting doesn't feel like a threat" | **As fast as your sprint.** The ways out are breaking his line of sight, shutting doors, a throw, hiding, or two of you staring, and a stare doesn't hold him at arm's reach. Also: a scream at the start, his wing's lights die, music, longer hunts, smarter search. |
| (mid-session) | "Fix everything in one go if possible", without lowering the quality. The piano puzzle itself is ambiguous: "even for me who knows it's there, I don't know how to do it", and a new player wouldn't realise the piano is a puzzle at all. |

## WP1 (build `.131`): no clock over a window, the solo bleed bar, a test that couldn't fail

**The clock over a window.** `RoomFit.fit` squeezes a 40×40 template into a mansion room, and it fitted windows and wall slots separately. A small room pulled both towards the middle of the same wall. The guest room, nursery and sewing room always hung a slot about 2.6 studs from a window's centre, when 4.2 was needed.

What changed:
- Wall items now keep clear of each other on their wall: `half + other.half + RoomFit.WallItemGap` (0.6).
- Decor is fitted first, so slots give way to windows, mirrors and paintings.
- Slots are `RoomFit.SlotHalf` (1.8) wide either side, which fits a portrait, the widest thing hung in a slot.
- `LevelBuilder.furnish` drops any slot that would still hang over a built window, mirror or painting.

Gate A can't move: the 40×40 templates already keep 2.5 studs clear, and the backstop needs 2.4. The F2 `clip` scan now also sees things hung on walls outside the rooms' models (the Decor folder, puzzle boxes, racks) and cylinders.

**The solo bleed-out bar.** It was scaled by the 15 s squad down, so a solo player's 20 s down drained the bar 5 s early. A `DownedSeconds` attribute now carries each down's real length.

**A contact test that couldn't fail.** `Stalk.spec`'s `touching()` left out `approachSpeed`, so it passed while the live code refused every walk. It now carries a run's speed, and a new case checks that a walk at 8 is not a contact.

**New tests:** TC-158 (no clock over a window) and TC-159 (the solo bleed bar).

## WP2 (build `.132`): the piano, made readable

The owner: "even for me who knows it's there, I don't know how to do it". A new player wouldn't realise the piano is a puzzle at all. The code reading found five more faults:
- The piano played an octave below the box, so the key that sounded like a note was the wrong one.
- Every wrong key reset the tune with a loud discord.
- Every note was muffled by its own prop.
- Number keys 1–3 also switched slots, which dropped a carried box.
- The comb only lit with subtitles on.

What changed:
- **One colour per note.** The box's comb and the piano's keys wear the same eight colours, a child's practice stickers (`Config.MusicBox.Colors`: red, orange, yellow, green, teal, blue, purple, pink). The comb is bigger. Its teeth light as each note plays, for everyone, always.
- **The tune on screen.** Anyone within 24 studs of the box as it plays sees the comb strip, `UI/TuneStrip`: one coloured slot per note, its name under it, fading 1.6 s after the last note. Say the colours to whoever is at the piano.
- **The piano says what it wants.** It has stickers on eight keys, and a sheet on its stand, "the box's song", with one blank note per note of the tune. The sheet fills with the tune's colours once it's played.
- **The screen.**
  - The keys wear the colours and their names, and sound the moment you press them.
  - The lights fill with the colours matched so far.
  - **Listen** winds the box when it's beside the piano.
- **No penalty for slips.** Wrong notes cost nothing. The piano opens the moment the last notes played are the tune (`MusicBox.matched`). Each key is a little noise instead (`KeyNoise` 12). Tunes are 4 or 5 notes (were 4 to 7), and the piano plays at the box's pitch.
- **Leads.**
  - The objective line says "The piano in the X is shut on something. It wants the music box's tune." until someone has heard the box, then "Play the music box's tune on the piano in the X. Its keys wear the colours of the comb's teeth."
  - A box seen first has its own line: "There's a music box in the X. Wind it and watch its comb."
  - The stuck-hint points at the box's room until it's heard.
  - The map marks the box once seen.
  - Two tips teach it.
- **Fixes.**
  - Sounds aren't muffled by their own prop: `AudioController:_behindWall` stops 1.5 studs short. This helps every positional sound.
  - Number keys don't change slots while a screen is up.
  - Fast presses aren't dropped (`PuzzleInput` 0.04 s, burst 20).
  - The carried heirloom's faint tune goes quiet within 30 studs of the clue box.
  - The heirloom lands on the piano's top wherever it has been pushed.

Dropped from the design doc: the discord rule (a wrong note was a loud noise and a restart).

**New tests:** TC-160 (a newcomer finds and solves it without help) and TC-161 (number keys at the piano).
