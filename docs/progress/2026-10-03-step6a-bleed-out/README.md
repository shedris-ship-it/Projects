# Step 6a: bleeding out

The first part of step 6 (The Guest), done first because the new lunge downs players outside hunts. Owner decision (2026-10-03): a down should be much less forgiving, with a clear "you're bleeding out, help now" signal.

**What changed**
- **15 seconds, not 45** (`Config.Run.DownedSeconds`). This applies to every down. The solo Companion revives in 6 s once it reaches you (`CompanionReviveSeconds`).
- **The downed player** (`01_bleeding_out.jpg`, taken 3 s in):
  - "YOU'RE BLEEDING OUT" with a draining bar, switching to a pulsing "YOU'RE FADING" in the last 6 s (`BleedWarnSeconds`).
  - A dark red rim closes in with each heartbeat; blur thickens, colour drains and the screen darkens towards the end. Nothing moves the camera.
  - Their own heartbeat, loud, slowing from 96 to about 43 bpm.
- **Teammates:** a toast ("… is bleeding out! 15 seconds"), gasping from the body, and a pulsing red marker over them with the name, seconds left and distance. Off-screen or behind you, it sticks to the screen edge with an arrow pointing the way (`UI/DownedMarkers.luau`).
- **Sounds:** the first real audio in the game, from the Creator Store's licensed libraries (no uploads): an APM horror heartbeat and two Pro Sound Effects gasps. Ids in `Assets.luau`.
- **Debug:** `down [name]` and `revive [name]`.

**Checked in Studio:** `down` on the baseline seed shows the overlay, rim, blur and bar (screenshot). The Companion revived at 6 s. With the Companion removed, the player bled out to Lost at 15 s and the run ended as "AllLost". All new sounds load. No console errors apart from the usual DataStore 403s.

**Not checked (needs two clients):** the teammate marker, its edge arrow, and hearing the gasps from another player. This is TC-16 in `docs/TESTING.md`.
