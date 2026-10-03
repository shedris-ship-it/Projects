# Testing plan

Two layers: automated tests for the pure game logic, which run anywhere with Lune, and a manual multi-client checklist for everything that needs the engine. The doc's playtest ladder and fun gates (sections 10 and 12) sit on top of both.

## Automated

```sh
lune run tests/run        # 39 tests
lune run tests/compile    # every .luau file compiles
selene src tests          # lint: undefined globals, unused variables, shadowing…
```

| Spec | Covers |
| --- | --- |
| `LevelGraph.spec` | Same seed → same layout. Different seeds differ. **1,000 seeds all pass the fairness contract**; currently 86.5% pass on the first attempt with 0 fallbacks. Exit on the edge, Deliberation Table on the critical path, Lantern rooms spread out, seams match doorways, no three same-mood rooms in a row |
| `Rooms.spec` | Every prop kind exists. Furniture stays in the wall band and out of the doorway lanes (the stalker's navigation depends on this). No overlaps. Shrine spots are clear. Wall slots avoid doorways. Every role has a template |
| `Anomalies.spec` | Doc section 4 rules: 5–6 tells, a camera-confirmable tell, at least half social, overlaps with two or more other anomalies, any three tells leave ≤ 2 suspects, every tell is used |
| `Evidence.spec` | For every anomaly and squad size: 3–4 deducible true tells with a camera tell, 1–2 red herrings that aren't the anomaly's own. Perception: social tells are perceived by some but not all Witnesses, variant props differ, every Witness has something to disprove, solo players get shifting variants and no teammate-based tells, determinism |
| `Systems.spec` | RNG determinism and distribution. Clock directions. Drift: baseline collapses at ~40 min (doc), isolation, events, the anchor credit cap, hard multiplier. Verdict rules. Squad-profile decay. Utility AI responds to habits and cooldowns. Scare-deck spacing. Director tiers and hunt rules (no hunts in the first 3 min, none in Lantern rooms or within 20 s of a revive). Progression |

## Manual: Studio multi-client

Use **Test → Clients and Servers** with 2–4 players. A debug command is noted where it speeds up a check.

### Critical

| ID | Check | Pass |
| --- | --- | --- |
| TC-01 | Join, hub loads, profile loads | Lobby panel shows Clearance and Marks. Settings / how-to-play opens on first launch |
| TC-02 | Tool pick, difficulty, ready-up | All clients see each other's tool and ready state. The countdown cancels if someone un-readies |
| TC-03 | Generation | The loading screen shows. The house builds in 1–3 s (`perf`, overlay "build"). Everyone spawns in the Foyer |
| TC-04 | Divergence differs per client | Two clients look at the same clock, note or chair and see different things. A phantom door is walkable for one and solid for the other. A fake wall never blocks movement |
| TC-05 | Anchoring | Both clients hold Q on a divergent object within 4 s. It collapses to the same state for everyone, a marker shows "Anchored", Focus drops by 20 |
| TC-06 | Evidence | Anchoring a tell confirms it (Case Board ✔, Drift drops). Anchoring a herring debunks it. Witnessing alone adds a "?" claim (`reveal` shows which is which) |
| TC-07 | Observation rule | `tier 2`: The Guest holds still and stares when one client watches, is frozen when two watch, and backs away (still facing you) after a 3-second shared stare. He moves closer only when nobody is looking |
| TC-08 | Tier 1 | `tier 1`, `guest move peek`: his head leans out of a doorway for one client only; the other client sees nothing there. When that client looks at him he's yanked out of sight |
| TC-09 | Hunt | `drift 70`, `skip`, then wait for 3 minutes of run time, or use `tier 4`. The telegraph flickers the lights. The stalker chases what it can see, opens doors with a delay, inspects hiding spots, and downs on catch. A teammate revives with a 4-second hold |
| TC-10 | Hiding | Can't hide while it sees you. Holding breath drains the meter; a gasp makes noise. Inspection pulls you out |
| TC-11 | Verdict | A wrong verdict gives Drift +15 and a hunt. A correct one starts the ritual and the final hunt. Pairs must be unanimous; 3–4 players can win by majority after 90 s |
| TC-12 | Rituals | `anomaly <id>` then `resolve`. Triangulate: three seams, decoy flickers differ per client. Cross-check: key labels differ, only the genuine key works with everyone present. Stare-down: progress only builds while everyone looks |
| TC-13 | Extraction and Dossier | The exit opens, players extract, the Dossier shows evidence, habits, closest calls and Marks, and everyone returns to the hub |
| TC-14 | Lose states | `drift 100` collapses the run. All players Lost ends the run. Echoes can ping once a minute |
| TC-15 | Solo | The Companion follows, joins Witness windows, backs up stares and revives (within 6 s of reaching you) |
| TC-16 | Bleeding out | `down <name>` on one client. That client sees "YOU'RE BLEEDING OUT", a draining bar, a red rim and blur that close in, and hears a slowing heartbeat; after 15 s they're Lost. Every other client gets a toast, hears gasping from the body, and sees a pulsing marker with the name, seconds left and distance, stuck to the screen edge with an arrow when off-screen or behind. A 4 s hold on E revives |
| TC-17 | Lunge and its warnings | `tier 3`, `guest move creepbehind`, turn your back. You hear a breath (only you) and floorboard creaks, lights near him sag, then he lunges from about 6 studs: a jumpscare and you're down. With a second client watching him he freezes and can't lunge. Sprinting away at the edge escapes it |
| TC-18 | Arrival and presence | From `start`, about 90 s in: three knocks at the front door. After that he is always somewhere: he is silent while invisible (no footsteps through walls) and never pops in or out of view on any client (watch him through a doorway on two clients while the tier changes) |
| TC-19 | Backing away | Turn round on him at tier 2 when he's close: he holds, then backs away slowly, never turning his back. After a hunt ends he does the same instead of vanishing |
| TC-20 | Windows and mirrors | Stand facing a window or mirror with The Guest a few studs behind you (`guest here -6` with your back to the glass, then turn to it): his dim reflection shows in the pane. `guest window` near a window: tapping on the glass, then his face outside it for you alone (a second client sees nothing); it slides away once you've looked at it. Screenshots through the Studio MCP don't show client-made 3D GUIs, so this needs a real look |
| TC-26 | Close contact | `tier 1`, `tier 2`, then `tier 3`: walk right up to him (inside about 5 studs) while you can see him. He lunges at once, with no warning: jumpscare and you're down. If you were alone he vanishes within a second and stays gone for 25 to 40 s while teammates reach you (a second client sees him disappear, not pop away in front of them). With a teammate near you he backs away facing you instead. Two clients both staring at him freeze him: no lunge. A hidden or downed player next to him is left alone; nobody is lunged at again for 20 s after a nearby down |
| TC-27 | Footsteps | At tier 0 and 1 while he's invisible you hear no footsteps from him anywhere. When he becomes visible (tier 2, a peek, a hunt) his steps are audible again and stop when he stops |
| TC-21 | Jumpscare | `guest scare`: his face, grinning wide open with glinting eyes, rushes in to fill the screen with a piano sting, then black. It's a picture: nothing else moves the camera |
| TC-31 | Audio set | In a run: doors squeak open and thud shut, slams are heavy, a knock sounds like a knuckle on wood; buttons give a soft key press and hovering a quieter one; F clicks; hiding gives cloth and a wardrobe door; anchoring or a verdict gives a stamp; the Lantern strikes a match. Hunts start with a low hit; high Drift adds a low drone, a faint ringing and a muffled house; radios hiss. Door and Guest sounds follow the Effects slider and are muffled through walls |
| TC-32 | Period outfits | Each player and the Companion wear a faded shirt and jeans in different colours, no hats or hair accessories, with no modern avatars. The Companion idles and walks with animation (not a T-pose). Two clients see each other's shirt colours |
| TC-33 | Held items | In a run you see a torch in your right hand (it lags a hard turn, its lens lights when you press F) and your chosen tool in your left (camera, lantern, radio or plumb line) with sleeved arms in your shirt colour; no stock Roblox arms. Walk face-first into a wall: both pull back instead of clipping through. Nothing changes where Witness, pings and the light point |
| TC-34 | Drift arc | `drift 45`: only fluorescent (utility room) lights stutter. `drift 65`: all lights do, and dark stains show on some walls. `drift 90`: lamps are about 70% as bright, the picture is nearly colourless, every stain is showing. `drift 0` clears them again. Only lights near you cast shadows (watch a far room's shadows pop on as you approach) |
| TC-28 | Movement feel | In a run, walking is slow and heavy (8 studs/s) with a light head bob; holding Shift is a rush (19) with a strong bob, a wider field of view and ragged breathing as stamina drains; out of stamina you stagger at about 10 with a sloppier sway and a gasp; jumps are lower and landings dip the camera with a thud. The hub stays brisk (12). Aim, the flashlight and Witness behave exactly as before |
| TC-29 | Player footsteps | Roblox's default footsteps are gone. Your steps are slower walking than sprinting, come from each foot in turn, never repeat the same sound twice in a row, and change with the floor (wood, carpet, tile, concrete). Hard rooms (bathroom, stone) give an echo; carpet rooms stay dead. On two clients you hear your teammate's steps, muffled through walls, and creeping (very slow) is silent |
| TC-30 | Camera motion slider | F1 shows **Camera motion (head bob)**. At 100% bob, sway, FOV kick and the landing dip are full; at 0% the camera is perfectly still (the hum, breathing and footsteps stay). Witnessing, pinging and hiding peeks work the same at every setting. The house hum dips for a couple of seconds when the Guest first shows himself to you |

### Multiplayer robustness

- One client leaves mid-run: the run continues, their votes and windows drop, and an empty server ends the run.
- Respawn or reset mid-run puts the character back where it was.
- A client that joins mid-run waits in the hub with the lobby panel showing "in the house".
- Two runs in a row: nothing is left over (lights, phantoms, stalker, prompts, attributes).

### Security

- Remote flooding (Witness, Ping, UseTool) is capped by the interval and the sliding window, and junk arguments are ignored.
- A speed exploit (raise WalkSpeed from the client's command bar) gets snapped back.
- Debug commands do nothing on live servers for user ids that aren't allow-listed.
- Clients never receive which tells are red herrings, which key is genuine, or where the Source is before the ritual.

### Performance (doc section 7 targets, to verify)

- 60 FPS on a mid-range phone and a stable 30 on low-end devices. Try low-end mode, and watch FPS and memory in the overlay.
- Server heartbeat stays well under 16 ms with 4 players during a hunt (overlay `server heartbeat`).
- No frame spikes during generation (it runs server-side behind the loading screen).

## Playtesting

Ask every tester the doc's question: *"Did it ever feel like it cheated?"* A yes means a telegraph or fairness rule is missing. Track the doc's starting metrics with the `[Consensus:event]` log lines and AnalyticsService custom events: run completion, win rate per anomaly, wrong-verdict rate, median run length, and quit points.
