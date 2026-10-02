# Corridor prototype, focus markers, dust v2

Baseline seed (`seed 1800820264`). The hallway is Room 13, centred at (80, 0).

- `corridor_from_west_doorway.jpg`: the prototype corridor (closets in the corners, a 14-stud-wide plus), seen from its west doorway. The grandfather clock's face ("XII") is on the left, the ceiling light over the junction, the bench in the dead-end east alcove, a painting on a closet wall, and the new dust motes drifting in the light.
- `marker_door.jpg`: no crosshair. Looking at the foyer door from about 7 studs shows its marker: the brass ring, "Door", and `[E] Open` and `[Q] Witness`.
- `marker_hub_pedestal.jpg`: the same marker style replacing Roblox's prompt box on a hub pedestal ("Lightkeeper", `[E] Take Lantern`, behind the avatar's head). The hub now uses a higher bloom threshold, so the avatar's wings no longer glow.

**Stalker test, tier 2.**
- With the player hidden in the corridor's dead-end arm, back turned, The Guest walked in through the west doorway to the junction and back several times.
- 60 samples, 0 inside a closet, closest approach 8.4 studs.
- While the player looked down the corridor, it waited out of sight at the south doorway, as the observation rule says.
- Across another 189 samples elsewhere in the house, it was never inside a closet either.

**Rojo:** served through `tools/serve-mirror.sh` with zero crashes across every edit in this step.
