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
| TC-07 | Observation rule | `tier 2`: the figure holds still when one client watches, is frozen when two watch, and backs off after a 3-second shared stare. It relocates closer only when nobody is looking |
| TC-08 | Tier 1 | The figure appears to one client only and vanishes when the other turns to look |
| TC-09 | Hunt | `drift 70`, `skip`, then wait for 3 minutes of run time, or use `tier 4`. The telegraph flickers the lights. The stalker chases what it can see, opens doors with a delay, inspects hiding spots, and downs on catch. A teammate revives with a 4-second hold |
| TC-10 | Hiding | Can't hide while it sees you. Holding breath drains the meter; a gasp makes noise. Inspection pulls you out |
| TC-11 | Verdict | A wrong verdict gives Drift +15 and a hunt. A correct one starts the ritual and the final hunt. Pairs must be unanimous; 3–4 players can win by majority after 90 s |
| TC-12 | Rituals | `anomaly <id>` then `resolve`. Triangulate: three seams, decoy flickers differ per client. Cross-check: key labels differ, only the genuine key works with everyone present. Stare-down: progress only builds while everyone looks |
| TC-13 | Extraction and Dossier | The exit opens, players extract, the Dossier shows evidence, habits, closest calls and Marks, and everyone returns to the hub |
| TC-14 | Lose states | `drift 100` collapses the run. All players Lost ends the run. Echoes can ping once a minute |
| TC-15 | Solo | The Companion follows, joins Witness windows, backs up stares and revives (within 6 s of reaching you) |
| TC-16 | Bleeding out | `down <name>` on one client. That client sees "YOU'RE BLEEDING OUT", a draining bar, a red rim and blur that close in, and hears a slowing heartbeat; after 15 s they're Lost. Every other client gets a toast, hears gasping from the body, and sees a pulsing marker with the name, seconds left and distance, stuck to the screen edge with an arrow when off-screen or behind. A 4 s hold on E revives |

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
