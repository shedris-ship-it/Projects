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
