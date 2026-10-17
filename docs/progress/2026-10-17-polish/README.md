# Polish before the public release (2026-10-17)

The owner, after publishing build .231 and the playtest fixes (.232): "Theres still some more polish I want to do before publishing", with a public release by the end of the weekend. Each item below is one piece of that polish.

## The piano: the puzzle wasn't broken, but most pianos only pushed

**The owner, 2026-10-13:** "the piano shows only a push prompt, never Play". On 2026-10-17 they thought it might have been fixed since.

**What was found:**
- Nothing fixed it after 10-13, and nothing needed fixing in the puzzle. The music box's piano works in the code:
  - its Play prompt is on from the start (`Puzzles/MusicBox`);
  - the hands offer a pushable thing's own short prompt as the tap and the push as the hold (`Logic/FocusActions`; the spec "the piano: tap plays it, hold pushes it", since 10-08).
- Every Music Room has a piano, and the music box puzzle is rare. Of 40 houses from the planner (seeds 1 to 20, squads of 1 and 4; scratch `tools/_pianos.luau`):
  - 21 had a Music Room without the music box, its piano plain furniture: E offered only Push;
  - 2 had the music box in the Music Room;
  - 17 had no Music Room.
  The 10-13 run was almost certainly one of the 21.

**The fix (the owner: "Yes, make the furniture piano playable as a lure"):**
- A piano that isn't the music box's is a lure (`Data/Interactables` `Piano`). Tap E: a hand runs down six of its keys, in the puzzle piano's own out-of-tune note, and the Guest hears it 36 studs off, twice in a second. Its cooldown is 10 s. Hold E still pushes it.
- The music box's own piano keeps its Play. `Logic/RoomPurpose.puzzleTakes` (spec'd) says a puzzle in the room takes the piano for itself, so `InteractService:Begin(plan)` gives it no lure prompt.
- No plan changes: the Music Room was already a room with a reason (the piano's a landmark). The full suite and `tools/completable` agree.
- F2 `use piano` plays the nearest one.
- The note is the music box's, as the puzzle's piano has always played. A real piano sound can be picked by ear later (`Assets.luau`).

**Checked:** see Checks below. **Not checked in Studio:** Claude's Studio connection was off. TC-355 is the owner's.

## Checks

- stylua and selene: 0 errors, 0 warnings.
- `lune run tests/compile` and `rojo build`.
- `lune run tests/run`: 753 passed, with one new spec in `RoomPurpose.spec`.
- `lune run tools/completable`: 1,152 houses, none that can't be finished; the music box in 181 of them.
- Not seen in Studio (TC-355).
