# Consensus: Design Doc & Development Roadmap

Oct 2, 2026 · @Sheamus

## 1. Concept

Consensus is a 2–4 player co-op horror game built on one rule: reality only holds when at least two people agree on it. The squad's job is to find the single anomaly corrupting a location and neutralise it, while a learning stalker exploits every disagreement between them.

That rule is what turns your list of ideas into one game instead of a pile of features. Every system below is an expression of it.

| Element | In the fiction | Mechanically | The player feels |
| --- | --- | --- | --- |
| Divergence | The place shows each Witness a slightly different version of itself | The server gives each client a personal list of perception rules (hidden doors, fake objects, wrong sounds) | "I can't trust my eyes" |
| Anomaly | The hidden thing unmooring the location; one of 12 types | Chosen per run; spawns the evidence and defines the resolution ritual | "What is this, and how do we stop it?" |
| Stalker | A predator that is only fully real to someone watching alone | AI that escalates through tiers, hunts, retreats and adapts to the squad | "It's learning us" |
| Witnessing | Two people confirming the same thing makes it real | Players Witness one object within a short window to anchor it; anchored things are stable and stalker-proof | "Stay close and say what you see" |
| Drift | How far the place has come unmoored | A 0–100 pressure meter driving stalker aggression and divergence intensity | "We're running out of time" |
| Proximity voice | How Witnesses compare realities | Spatial chat, with ping and quick-chat fallbacks | "Wait, do you see that?" |

### Four pillars

1. **Doubt before danger.** Fear comes first from not trusting your senses or your friends, and only second from being chased.
2. **Talk is the mechanic.** Every system rewards describing, comparing and confirming, and punishes splitting up in silence.
3. **A predator that learns.** The stalker's intelligence is felt through specific, memorable adaptations, not through bigger numbers.
4. **Every run is a new mystery.** The location layout, anomaly, evidence and stalker personality recombine each time.

### One run in a paragraph

You and two friends enter a suburban house. Within minutes your friend insists there is a door in the hallway; you see only wallpaper. A figure stands at the end of the corridor, perfectly still, and only you can see it. When you call it out and your friend turns to look, it is gone. Over the next twenty minutes you collect evidence, argue about what is real, get hunted twice, and finally commit to a verdict about what is wrong with the house.

### Decisions that make the original idea hold together

- **One hidden anomaly per run** (two on hard difficulty), drawn from 12 types. Finding and identifying it is the objective.
- **One stalker per location.** All stalkers share one AI framework and differ by an archetype configuration, which keeps scope sane.
- **The stalker obeys the Witnessing rule.** It can advance when unobserved or watched by one player alone, and must retreat when two players watch it together. This explains why it stares, why it moves once detected, and why splitting up is deadly.
- **Pressure comes from Drift, not an arbitrary timer.** Stalling raises Drift, progress lowers it, and thresholds unlock stalker tiers. That is your "consequence for not progressing".
- **Hand-built rooms, procedural arrangement.** Procedural layouts are assembled from polished prefab rooms, because hand-lit rooms are what make a Roblox game look great.
- **Getting caught is not elimination.** You are downed and can be revived by a teammate, which keeps friends playing together.

### Out of scope for version 1

Open world, PvP or traitor roles, a long story campaign, and VR. A short, replayable, well-lit game beats a big unfinished one.

## 2. Core loop and run structure

A run lasts about 25 minutes across six phases, and a rising Drift meter makes sure it can never stall.

1. **Briefing (about 2 min).** In the hub the squad picks a contract (location and difficulty), chooses a tool kit and cosmetics, and readies up. Voice is live in the hub so friends are already talking.
2. **Arrival (3–4 min).** Drift is low, the stalker is dormant and divergences are mild and harmless. This teaches Witnessing and lets players learn the layout before it turns on them.
3. **Investigation (12–15 min).** Players search rooms, collect Evidence and pin it to the shared Case Board, which narrows the 12 anomaly types. Drift rises, the stalker climbs tiers, and the first hunts begin.
4. **Verdict (1–3 min).** At the Deliberation Table the squad must agree unanimously on which anomaly it is. A wrong verdict spikes Drift and triggers a hunt, and arguing burns time because Drift keeps climbing.
5. **Resolution (3–5 min).** Each anomaly has its own ritual (section 4), performed while the stalker runs a final, extended hunt.
6. **Extraction and debrief.** Players reach the exit, then see a Dossier of what the stalker learned about them: favorite hiding spots, habits, closest calls. It is shareable and a strong reason to replay.

### The moment-to-moment loop

Explore, notice something wrong, say it out loud, Witness it together, pin the evidence, narrow the suspects, survive the pressure, and repeat until the squad is confident enough to commit to a verdict.

### Drift: the pressure clock

Drift is a shared 0–100 meter that answers your "consequence for not progressing" requirement. All numbers here are starting hypotheses to tune in playtests.

| Drift | State | Stalker tier (section 5) | What changes in the world |
| --- | --- | --- | --- |
| 0–20 | Calm | 0–1 | Only harmless divergences; the game calibrates players |
| 20–40 | Uneasy | 1 | Divergences start touching useful objects such as doors and items |
| 40–60 | Fraying | 2 | First intrusions; mislocated sounds; light flicker |
| 60–80 | Breaking | 3, first hunt | Rooms rearrange behind you; anchoring costs more Focus |
| 80–99 | Collapsing | 3–4, hunt about every 2 min | Heavy divergence; false-consensus events |
| 100 | Collapse | n/a | The run fails for everyone |

| Event | Drift change | Design reason |
| --- | --- | --- |
| Baseline | +2.5 per minute | Stalling always costs something; no progress hits 100 at about 40 min |
| A player more than \~25 studs from all teammates for 20+ s | +1 per minute per isolated player | Splitting up is punished |
| Wrong verdict | +15 | Guessing is expensive |
| Player downed | +10 | Failure feeds the place |
| Evidence confirmed by two players | −6 | Real progress is rewarded |
| Successful anchor on a divergence | −2 (max 3 per minute) | Rewards talking without allowing spam |
| Surviving a hunt | −10, and the stalker retreats | The release after the peak |

### Win, lose and getting caught

- **Win:** the anomaly is resolved and at least one Witness extracts. Rewards scale with how many extract and how low Drift stayed.
- **Lose:** Drift reaches 100 (Collapse), or every Witness is Lost.
- **Downed:** a caught player bleeds out in 15 seconds unless a teammate revives them by holding the interaction for about 4 seconds. A second catch while downed makes them Lost. *(2026-10-03: the owner cut this from 45 s so the squad has to drop everything. The downed player sees a red rim closing in and hears their heartbeat slow; teammates get a marker with the seconds left and hear them gasping.)*
- **Lost players** become Echoes. They keep talking with the squad and can ping one hint per minute, so nobody sits in a dead lobby.
- **Failing forward:** every run, win or lose, grants progression currency and Dossier entries, so a Collapse still feels like it taught you something.

## 3. Procedural generation

Generate the arrangement, not the art: hand-built rooms are assembled by a seeded graph generator, and a validator guarantees every run is solvable, loopable and fair. Fully procedural rooms look cheap, while hand-lit prefabs are what give a Roblox game its graphical edge.

| Layer | What varies per run | Hard constraint |
| --- | --- | --- |
| Contract | Location (fixed per contract), anomaly (1 of 12), difficulty modifiers | The anomaly must be supported by the location |
| Layout | Which 10–16 rooms appear and how they connect | At least 2 loops; every room reachable |
| Evidence | 3–4 true tells plus 1–2 red herrings | The true tells must narrow the field to 2 or fewer suspects |
| Perception profiles | Each player's personal list of divergence rules | Every player has divergences a teammate can disprove |
| Stalker personality | Weights for patience, aggression, curiosity and mimicry | Values stay inside a fair band per difficulty |
| Event schedule | The Director's "scare deck" and its cooldowns | No two big scares inside the minimum gap |

### Layout generation

1. Seed a `Random` object. The seed is logged with the run so any bug or great moment can be reproduced.
2. Pick 10–16 room prefabs from a pool of 20 or more per location. Each prefab has door sockets and tagged slots (hiding spots, evidence, possible Source position).
3. Grow a spanning tree outward from the start room, placing the exit and the Deliberation Table on the critical path.
4. Add 2–3 extra connections to create loops of 4–8 rooms. Loops are what make hide-and-loop chase gameplay possible.
5. Assign functional slots: hiding spots, evidence, the Source, and one or two Lantern rooms where an anchored squad is safe.
6. Run the validator. On failure, retry with the next seed, up to about 10 attempts, then fall back to a known-good authored layout.

### The fairness contract (validator checklist)

- A true route exists between all rooms without relying on divergent-only geometry.
- At least 2 loops exist, and the shortest is 4 or more rooms, so a chase is survivable.
- There is roughly one hiding spot per two rooms, and no dead-end chain longer than 2 rooms except deliberate trap rooms.
- Every true tell can be reached and confirmed from at least two players' perspectives.
- Every player's divergence set includes something a teammate can independently disprove, so deduction is always possible.
- Divergences never decide life or death. The stalker's reach is server truth, and no one is ever required to disbelieve their own eyes within a second to survive.

### Evidence and deduction

Each anomaly defines 5–6 tells in data. A run spawns 3–4 true tells and borrows 1–2 red herrings from other anomalies that share the same perception channel. The Case Board maps each pinned tell to the list of candidate anomalies, so naming the anomaly is an elimination puzzle, not a guess. The design target is that three confirmed tells leave two or fewer suspects.

### Pacing, not randomness

Rooms carry mood tags such as tight, open and watched. The generator avoids three similar rooms in a row and tries to place a tight room just before a hunt-prone open area. The Director draws scares from a shuffled deck with cooldowns rather than rolling dice every second, which prevents both droughts and pile-ups.

### Keep it data-driven

Anomalies, rooms, tells, stalker archetypes and the validator's thresholds should all live in data modules. Adding anomaly 9 or a fourth location then means authoring content, not rewriting the generator. Generation runs on the server behind a loading screen and should take one to three seconds.

## 4. The 12 anomalies

Each anomaly attacks a different channel of perception, leaves its own set of tells, and ends with a unique resolution ritual that needs the whole squad. Together they cover space, time, identity, sound, light, memory, topology, objects, attention, absence, environment and scale.

| # | Anomaly | Channel | Tells players can find | Resolution ritual | Build cost |
| --- | --- | --- | --- | --- | --- |
| 1 | Phantom Architecture | Space | Doors, walls and stairs exist for some players only; footprints end at walls | Triangulate: each player marks where the "seam" appears on the shared map, and the marks intersect at the Source | Low |
| 2 | The Echo | Time | Clocks disagree; sounds arrive before their cause; one player sees actions seconds late | Synchronise: perform linked actions in the order each player hears the countdown | Medium |
| 3 | Mimic | Identity | Head counts differ; name tags glitch; an extra set of footsteps | Interrogate: players hold private facts only they can see, ask questions the copy cannot answer, then Witness it together | Medium |
| 4 | Dead Air | Sound | Footsteps from the wrong side; a squadmate's voice drops out only in certain rooms | Tune the radio to the Source frequency by comparing what each player hears | Medium |
| 5 | Umbra | Light | Shadows with no owner; a flashlight reveals writing others cannot see | Overlap two or more light beams so the shadows converge on the Source | Medium |
| 6 | Redaction | Memory and interface | Your notes, map pins and tasks rewrite themselves; your log contradicts others | Reconcile a shared ledger; an entry is accepted only when two logs match | Low |
| 7 | Loop Corridor | Topology | The same painting repeats; teammates see you walk through a dead end | Stamp a marker at each junction, compare markers to find where paths diverge, and break the loop there | High |
| 8 | Counterfeit | Objects | Item descriptions differ between players; some keys and fuses fail | Cross-check inventories to find the one genuine item among copies, then use it on the Source | Low |
| 9 | Gaze | Attention | Objects change when unobserved; a portrait's eyes follow one player | Stare-down: every player holds eyes on the Source at once while the stalker closes in | Low–Medium |
| 10 | Hollow | Absence | One player cannot see a squadmate; held items float in mid-air | Map the boundary where the missing person reappears; the Source sits on it | Medium |
| 11 | Tide | Environment | Indoor rain, breath fog, wet footprints; water that is real for only some | Follow the water and close two valves in distant rooms at the same moment | Medium |
| 12 | Proportion | Scale | A squadmate looks giant or tiny; doorways feel wrong; corridor walk-times differ | Everyone measures the same objects with the rope; the one object all agree on is the Source | Medium |

### Rules every anomaly must follow

1. **Deducible.** At least three distinct tells, and at least one can be confirmed with the Witness Camera tool so a lone player still has a way to check.
2. **Social.** At least half the tells only become meaningful when two players compare what they perceive.
3. **Overlapping.** Each anomaly shares at least one tell with two others, so the Case Board is a real puzzle and not a lookup.
4. **Ritual under pressure.** Resolution takes 60–120 seconds, needs every living player, and is staged so the stalker's final hunt interacts with it (for example, Gaze forces everyone to look at the Source while the stalker approaches).
5. **Comfort-safe.** No anomaly relies on camera tilt, roll, or strobing. The player's own movement has a head bob with a Camera motion slider (0 is off); it moves only the camera's position and roll, never its aim. Younger and motion-sensitive players are a large share of Roblox.
6. **Stalker synergy.** Each anomaly gives the stalker one small twist, such as Mimic sending false pings or Dead Air making its footsteps misleading.

### Ship order

You do not need all 12 on day one. A staged release also gives you a content drop to market each month.

| Stage | Anomalies | Why |
| --- | --- | --- |
| Vertical slice | Phantom Architecture, Counterfeit, Gaze | Cheapest to build and the most visually obvious in clips |
| Alpha | Add Redaction, Dead Air, Mimic (6 total) | Introduces audio, UI and identity systems |
| Launch | Add Umbra, The Echo (8 total) | Enough variety that repeat runs feel different |
| Post-launch | Hollow, Tide, Proportion, Loop Corridor, one per monthly update | Each is a marketing beat and keeps veterans returning |

## 5. The Stalker

The stalker will feel intelligent because of three separate layers, not because it cheats or uses machine learning: a Director that paces it, a Tactician that picks smart moves from a learned profile of the squad, and a Body that perceives and moves fairly.

### Design principle: legible intelligence

Players should be able to say "it learned that we always hide in lockers", never "it knows where we are". The stalker only acts on what it has seen, heard or remembered, plus the public pressure of Drift. There are no hidden wallhacks. When it loses track of you it searches using inference from your habits, which is what a clever hunter would do.

### Three layers

1. **Director (pacing).** Reads Drift, time since the last hunt, and squad stress signals such as recent downs and anchor use. It sets the target tier and schedules hunts and retreats. This is why the game has peaks and valleys instead of constant chasing.
2. **Tactician (decisions).** Given the tier, it scores a menu of 12–15 tactics with a utility system using the squad profile, then picks among the top three at random so it is never fully predictable.
3. **Body (execution).** Vision, hearing, memory, pathfinding and animation, plus the fair-play rules below.

### The observation rule

This is the rule that makes your staring idea mechanical:

- **Watched by nobody:** the stalker can reposition freely.
- **Watched by one player:** at tier 1 it is gone the moment you've clearly seen it; at tier 2 it holds still and stares, moving closer only once you look away; at tier 3 it keeps creeping towards you, very slowly, even while you stare.
- **Watched by two or more players:** it is frozen and cannot advance, or lunge. If they hold the stare together for about 3 seconds using Focus, it backs away.

A stalker is "watched" when it sits inside a player's view cone with a clear raycast for more than about 0.3 seconds. Since divergences can hide it from some players, the squad has to talk to establish who can see it.

### Escalation tiers

| Tier | Name | What it does | What players experience | Fairness rule |
| --- | --- | --- | --- | --- |
*Revised 2026-10-03 (owner).* The Guest is physically in the house from the end of the quiet start: three knocks at the front door, and he's inside. He never teleports, parks or dissolves after that, and never turns his back on you. Who can see him changes only while they aren't looking, so he never pops in or out in front of anyone. Code: `Stalker/Stalk.luau`, rules in `Logic/StalkRules.luau`.

| Tier | Name | What it does | What players experience | Fairness rule |
| --- | --- | --- | --- | --- |
| 0 | Dormant | In the house, far from the squad, seen by nobody, and silent: you only hear him walk while he's visible to you | "Something is off" | Nothing in the first 90 seconds |
| 1 | Watching | Seen only by the Witness he's watching. Peeks round door frames and stands in the doorway you just walked through; yanked out of sight, still facing you, the moment you've clearly seen him | A face at the edge of a doorway that's gone when you look properly | Never closer than 25 studs, unless you walk up to him: within about 5 studs of a Guest you can see he lunges at once (see below) |
| 2 | Closing | Seen by all. Creeps closer only while nobody watches, faster behind a turned back, timed to your habits; holds and stares while watched; backs away when stared at up close | It is closer every time you look. Sometimes it's right behind you, breathing | Never attacks unprovoked. Frozen whenever two players watch it. Walk right up to him (about 5 studs) and he lunges at once |
| 3 | Intruding | Creeps even while one player watches, sneaks up behind turned backs out of everyone's sight, and lunges from about 6 studs: a down | Slow, deadly; never let it get close | Two watchers freeze it and cancel a lunge. A breath, a creak or the sight of it first (at least 1.5 s). No lunge at hidden, downed or safe-room players, near a fresh down or revive, or on cooldown (150 s per player, 60 s squad) |
| 4 | Hunting | Active pursuit using learned tactics; lasts 45–90 seconds | A real chase with hide and loop play | 3–5 second telegraph, starting from wherever he is, out of sight and 25+ studs away; at least 3 viable escapes |

**Close contact (owner, 2026-10-03).** From tier 1, a player who gets within about 5 studs of a Guest they can currently see is lunged at straight away (a 0.15 s wind-up): no warning, no run-time wait, none of the lunge cooldowns, because rushing him is your own choice. Counters: two players watching him freeze him; hidden, downed and safe-room players are exempt; nobody is lunged at again within 20 s of a nearby down or 8 s of a miss. If the victim was alone he races out of sight and stays gone for 25 to 40 seconds while their friends come to help; if others were near he backs away facing them. Code: `StalkRules.contact`, `Stalk:_contactVictim`, `MOVES.Withdraw`.

After every hunt or stare-down he backs away, still watching you, until nobody can see him; Drift drops by 10 after a hunt, and the tier falls back to 1 for at least 90 seconds. After the final hunt he bows as you leave. Hunts never start in the first 3 minutes, within 20 seconds of a revive, or while the squad stands in a Lantern room.

### Perception model (the Body)

- **Vision:** a cone of roughly 100 degrees. Range depends on light: about 40 studs in lit rooms and about 15 in darkness, unless a flashlight beam hits the target. Line of sight uses raycasts.
- **Hearing:** noise events with radii, such as sprinting, slammed doors and dropped items. Walking is quiet (and slow: 8 studs/s against a sprint of 19) and holding breath reduces noise further. Do not rely on microphone loudness; Roblox does not clearly expose it to developers (verify before planning around it).
- **Memory:** a last-known position for each player with a confidence value that decays over about 30 seconds. Searching expands outward from that point, weighted by the squad profile.
- **Pathfinding:** a strategic layer on the room graph (see section 7) decides where to go, and Roblox pathfinding handles movement inside rooms.

### Adaptation: the squad profile

The profile is a set of counters per squad per run, each with exponential decay so recent behavior matters most. The Tactician multiplies each tactic's base weight by the matching profile signal, then applies cooldown and fairness checks. Every adaptation is paired with a counter-counter, so players can respond to a stalker that has learned.

| Observed habit | How it is measured | Stalker counter | Player counter-counter |
| --- | --- | --- | --- |
| Hides in the same kind of spot | Uses per hiding-spot category | Checks favorite spot types first; fakes leaving, then returns | Vary spots; bait with noise elsewhere |
| Repeats the same loop | Route history on the room graph | Pre-positions on the far side of the favorite loop or cuts through a shortcut | Break the pattern; cross between loops |
| Sticks together | Average pairwise distance | Waits for a split, then targets the straggler | Rotate who scouts; use Lantern rooms |
| Holds gaze to freeze it | Seconds spent watching it | Approaches from behind or from a teammate's blind spot | Cover each other's blind spots |
| Leans on the flashlight | Share of time the light is on | Kills nearby lights; strikes from just outside the beam | Spot-check dark corners; save battery |
| Anchors reflexively | Anchor count and cooldown timing | Waits for Focus to run out, then moves | Save Focus for emergencies |
| Calls out with pings | Ping counts and positions | Fakes pings to lure players | Confirm pings by voice |
| Camps in one room | Time stationary | Escalates sooner against stationary squads | Keep moving |
| Rarely looks behind (per player) | Seconds between rear checks, from each camera | Creeps up on whoever checks least, right after they've checked | Look back often, at uneven times |
| Always looks over the same shoulder (per player) | Left vs right rear checks | Approaches on the other side | Check over both shoulders |
| Stares at it, or runs (per player) | What you do when you see it | Peeks for starers, stares down runners | Get a second Witness on it |

You do not need real machine learning. A well-chosen set of 12–15 tactics, decent memory and clear telegraphing reads as high intelligence. A cross-run version, where the Dossier remembers an individual's habits across sessions, is a good post-launch feature.

### Hide mechanics

- **Spots:** lockers, beds, wardrobes, curtains and under-table gaps. Each has capacity (1–2), a peek slot, and a noise value.
- **Hold breath:** a short meter that drains while a hunter is nearby. Run out and you gasp, which makes noise.
- **Spot heat:** every reuse of a spot raises its chance of being inspected, which is how the stalker "remembers" your favorites.
- **No cheap hiding:** you cannot enter a spot while the stalker has direct line of sight to you.

### Loop mechanics

- **Guaranteed loops:** the generator ensures at least two loops of 4–8 rooms.
- **Doors:** a closed door costs the stalker 1.5–3 seconds to open and makes noise. Players can also lock some doors for a short time.
- **Vaults and shortcuts:** windows and low gaps save time but make noise.
- **Pace:** the stalker runs at about 90–95% of sprint speed, and sprinting drains stamina, so a chase has rhythm and nobody can sprint forever. Walking is deliberately slow (8 studs/s, owner 2026-10-03) so running feels like running for your life; out of stamina you stagger at 10, not walking pace.
- **Loop fatigue:** each lap of the same circuit raises the stalker's prediction of it. After about two laps it cuts the loop off, so loops buy time, not safety.

### Stalker archetypes per location

One AI framework runs every stalker. An archetype is a data configuration (perception profile, movement rule, signature ability, tactic weights) plus one or two custom scripts. This is how "different locations have different stalkers" stays affordable.

| Location | Stalker | Archetype rule | Signature ability | Counterplay |
| --- | --- | --- | --- | --- |
| The Halfway House (suburban home) | The Guest | Watcher: moves only between sightlines, polite posture | Mimics domestic sounds such as knocks and a voice behind a door | Do not answer knocks; Witness the door together |
| St. Odile Ward (abandoned hospital) | The Orderly | Patroller: follows a schedule it breaks as it learns | Kills lights; checks rooms in order of your habits | Learn the patrol; use Lantern rooms |
| Hush Motel (sleep clinic) | The Sleeper | Blind hunter: reacts only to sound | Huge hearing radius; any noise draws it | Move slowly; hold breath; sneak |
| Meridian Mall (closed retail) | The Window Dresser | Statue: swaps itself with a mannequin | Reappears inside mannequin clusters; copies poses | Count mannequins; Witness suspicious ones |
| Drowned Line (flooded metro) | The Tidewalker | Ambusher: travels through water and reflections | Shows in puddle reflections before arriving; fast in water | Stay out of the water; watch reflections |

Build The Guest first for the vertical slice, then The Orderly. The remaining three can follow in launch and post-launch updates.

### Testing the intelligence

- Log every tactic choice with the profile values that drove it, so you can see why it did what it did.
- Add a debug overlay showing tier, target, memory and profile bars.
- Run bot squads with scripted habits (always hides, always loops, always groups) and check the stalker adapts within 2–3 minutes.
- Ask every playtester one question: "Did it ever feel like it cheated?" A yes means a telegraph or fairness rule is missing.

## 6. Social design and proximity voice

Voice is the game's main instrument, so every system should give players a reason to describe what they perceive, plus a non-voice way to do the same. Roblox voice is not default: players must be 13 or older, complete an age check (ID or facial age estimation), opt in, and are matched for voice with users of similar age groups ([Roblox Help](https://en.help.roblox.com/hc/en-us/articles/34506487825428-How-do-I-turn-on-Voice-Chat)). A large share of your audience will not have voice, which makes the fallbacks below essential. Voice is switched on per experience in Studio under Experience Settings, Communication, and it needs a place capped at 100 players or fewer.

### What the Roblox audio stack allows

With `VoiceChatService.UseAudioApi` set to Enabled, each voice-eligible player gets an `AudioDeviceInput`, their character gets an `AudioEmitter`, and the camera gets an `AudioListener` ([Roblox voice docs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/chat/voice-chat.md)). Because these are wired objects, you can route voices through effects or control who hears whom. That unlocks:

- **Dead Air:** muffle or mute one speaker for selected listeners.
- **Hollow:** keep a hidden teammate's voice audible while their body is invisible.
- **Radio:** a long-range channel whose static grows with Drift.
- **Room acoustics:** reverb and low-pass filtering by room size and walls.

Two cautions. Never record or replay players' real voices for mimicry; use generic whisper assets instead. And treat detecting whether someone is speaking, or how loudly, as an unverified experiment, because the developer forum discussion on it is unresolved. No core feature should depend on it.

### The Witness mechanic (anchoring)

Holding Witness on an object starts a 4-second window. If a second player Witnesses the same object inside it, the object is Anchored for about 90 seconds: divergences on it collapse to the true state for everyone, any evidence on it is logged as confirmed, and a stalker caught in it freezes.

Witnessing costs Focus. Each player has 100 Focus, Witnessing costs about 20, and Focus regenerates much faster within 10 studs of a teammate than alone. That is your "social sanity" system: isolation makes you easier to fool and easier to hunt.

### Tools that make players depend on each other

Each player picks one primary tool in the briefing. Different tools give different information, so nobody can solve a run alone.

| Tool | What it does | Why it creates conversation |
| --- | --- | --- |
| Witness Camera | Photographs the true state of one object; 6 shots per run | Film is scarce, so players ask a teammate to confirm before spending it |
| Lantern | Wide light that also recharges Focus in Lantern rooms | The Lightkeeper decides where the squad can rest |
| Radio | Long-range comms and tuning; static grows with Drift | Required for some rituals; stalker interference makes it unreliable |
| Plumb Line | Points roughly at the Source once two tells are confirmed; noisy | Two lines from different spots triangulate the Source |

### Voice and non-voice parity

- **Ping wheel:** Look here, Anchor this, Danger, Wrong, Clear, Follow me.
- **Structured callouts:** pick an object type (door, figure, item, sound) and a clock direction. Teammates see it as a claim, "Alex says: door at 10 o'clock", which they may or may not perceive. That keeps divergence intact for text-only players.
- **No custom free-text chat.** Use Roblox's built-in chat. Building your own makes you responsible for filtering and moderating it.

### Social dynamics worth designing for

- **Disagreement without blame.** The fiction says the place is lying, not your friends. There is no PvP, no traitor role, and no friendly fire.
- **Verdict pressure.** 2-player squads need unanimity. At 3–4 players, a majority carries after 90 seconds of debate, which prevents one stubborn player stalling the run while Drift climbs.
- **Soft roles.** Tools create natural jobs: photographer, lightkeeper, operator and surveyor. Nobody is locked into one.
- **Strangers.** The tutorial run and structured callouts need to work for strangers with no mic. Match by age band so voice works inside the group.
- **Griefing controls.** Players pass through each other (no body-blocking doorways), AFK players are removed after about 60 seconds, and mute and report are one tap away.

### Cold-start population

A game that needs three or four players dies when concurrent players are low. Allow 1–4 players per run. Private servers and friend invites carry the early weeks, and a post-alpha Companion Witness (an NPC that counts as a second witness but has limited information) lets solo players play at all.

## 7. Technical architecture on Roblox

Keep the server authoritative for everything that decides an outcome, and let each client change only how its own player sees the world. Changes a client makes to its own copy of the world are not replicated to others, which makes per-player divergence cheap on Roblox. The one thing to prove first is how locally changed collision behaves with character physics, which is why section 10 starts with a two-client prototype.

&#91;embedded content: architecture · 11 server services, 4 client controllers, 2 network flows\]

The highlighted pair creates divergence: the server sends rules, not world state, and each client applies them to its own copy of the place. The Director, Tactician and Stalker Body chain is the AI described in section 5.

### Key technical decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Authority | The server decides verdicts, hits, ritual success, Drift and stalker position | Clients cannot cheat outcomes, and divergence cannot be exploited into wins |
| Divergence | The server sends each client a profile of rule ids, parameters and a seed; a client controller applies it to tagged parts | Tiny network cost and no duplicated world |
| Phantoms | The server tells one client to spawn a local-only figure or object | Visible to one player, absent from server state |
| Stalker replication | The stalker is a server-owned NPC; clients show or hide it per their profile | Smooth, exploit-resistant, and supports "only you can see it" |
| Pathfinding | A\* on the room graph for strategy, Roblox pathfinding with modifiers inside rooms | Cheap, and it enables the loop cutoffs that make the AI look smart |
| Level assembly | The server clones room prefabs by seed; keep levels to 10–16 rooms | Avoids heavy streaming complexity and keeps mobile memory low |
| Places | A hub place for lobby and store, a run place for the game | Short-lived 1–4 player servers fit private runs |
| Matchmaking | MemoryStore queues, then reserved servers via TeleportService with the seed and contract as teleport data | Standard pattern for session-based games |
| Player data | A session-locked profile store for currency, unlocks and stats | Prevents data loss and duplication |
| Determinism | Every random choice uses a seeded `Random`, and the seed is logged | Reproducible bugs and daily contracts |

### Server modules

Name modules to avoid clashing with Roblox services (for example `RunOrchestrator`, not `RunService`). Each module owns one job and talks through signals, not shared globals.

- **RunOrchestrator:** phases, win and lose, timers.
- **LevelGenerator** and **Validator:** seeded layout and the fairness contract.
- **AnomalyService:** picks the anomaly, spawns tells, runs rituals.
- **DriftService:** the 0–100 meter and its events.
- **WitnessService:** anchoring windows, Focus, pings.
- **DivergenceService:** builds and sends profiles, and spawns Phantoms.
- **DirectorService, TacticianService, StalkerBody:** the three stalker layers.
- **SquadProfileService:** habit counters with decay.
- **DataService, MonetizationService, AnalyticsService:** profiles, purchases, events.

### Client controllers

- **PerceptionController:** applies the view profile to tagged parts (visibility, collision, size, materials) and to audio.
- **WitnessController:** input for hold, ping and callouts.
- **AudioController:** room acoustics, Drift layers, radio and voice filters.
- **UIController:** HUD, ping wheel, Case Board and settings.
- **EffectsController:** grain, fog and color changes driven by the Drift level.

### Performance and platform notes

- **Targets to verify:** 60 FPS on a mid-range phone and a stable 30 on low-end devices. Profile with the MicroProfiler and Developer Console from the first grey-box.
- **Server tick:** run stalker movement at 10–20 Hz, Tactician decisions at about 1–2 Hz, and time-slice pathfinding so no frame spikes.
- **Replication:** send rule ids and small deltas, not world state, and throttle anything not time-critical.
- **Interaction checks:** the server must tolerate players standing where the server's true geometry has a wall, because a divergent door may let them walk through it.

### Anti-exploit stance

Validate the type, range and rate of every remote. Send hidden truth to a client only when it has been earned, such as a confirmed tell. Accept that an exploiter can strip their own divergences, and design so that does not decide anyone else's outcome.

### Testing and tooling

- Unit-test pure Luau logic (generator, validator, Drift, utility scoring) outside the engine.
- Run bot squads with scripted habits to test the Director and Tactician.
- Keep a debug overlay for seed, tier, profile values and Drift sources, and a console command to force any anomaly or tier.
- Use Studio's multi-client test mode daily; per-player divergence bugs only show up with at least two clients.

## 8. Art, lighting and audio direction

Spend the art budget on lighting, composition and sound before polygons. A few hand-lit hero rooms will read as "great graphics for Roblox" far more than a large number of detailed assets.

### Where the visual budget goes

1. **Lighting.** The biggest multiplier by far.
2. **Materials.** PBR textures through `SurfaceAppearance`, plus hand-placed grime and wear decals.
3. **Composition.** Sightlines that let a stalker silhouette sit at the end of a hall, and rooms framed for screenshots.
4. **Prop density.** Last, and only in hero areas.

### Lighting and rendering

- Use Future lighting as the target look, and test the fallback on lower graphics settings and a low-end phone. A large share of Roblox players are on mobile.
- Light every room with one motivated key source (a lamp, a window, a television) over low ambient light and strong contrast.
- Enable shadows only on lights that matter, and treat roughly 4–6 simultaneous shadow-casting lights as a starting budget to verify with the MicroProfiler.
- Layer per-location fog and atmosphere, a subtle ColorCorrection and Bloom, light depth of field, and a vignette. Film grain can be an animated noise overlay in the UI.
- **Drift-driven degradation:** tie saturation, contrast, grain, light-flicker rate and audio filtering to Drift so the world visibly decays as the run progresses.

### Models, textures and assets

- Build a modular kit in Blender (walls, trims, doors, windows), then assemble 20 or more room prefabs per location from it.
- Use free CC0 texture libraries such as Poly Haven and ambientCG, and keep a licensing sheet for every external asset.
- Do not drop unaudited Creator Store models into the game. Models can carry hidden scripts, so inspect or avoid them.
- Prefer MeshParts over Unions for detail, and merge static decor to keep instance counts down.
- Plan 10–15 hero props per location that sell the fiction, such as family photos, a hospital chart or a wet footprint trail.

### The stalker and character design

- **Silhouette first.** It must read instantly at 30 studs in low light.
- **Wrongness through animation.** Stillness, a head tilt slightly off human, joints that bend a little too far, and movement in short bursts.
- **Implication over gore.** Keep scares inside the Mild fear tier of Roblox's questionnaire (section 9). Fear comes from what you almost see. *(2026-10-02: the owner chose Moderate as the ceiling; see section 9. Implication still leads, and gore is held back for late escalation.)*
- Budget 6–10 custom animations per stalker: idle-watch, turn, stalk-walk, run, peek, intrude, grab, retreat.

### UI and accessibility

- Make the interface diegetic where possible. The Case Board is a physical corkboard in the Arrival room, and Drift is shown in the world and not as a bar. The HUD holds only the Focus ring, current tool and ping wheel.
- A first-launch screen offers reduce flicker, reduce grain and camera motion, subtitles for key audio cues, colorblind-safe ping icons, and an FOV slider. Strobing effects are a real photosensitivity risk and should be opt-out at minimum.

### Audio direction

Audio does at least half the work in psychological horror, and it is cheaper than art.

- **Layers:** room tone beds per location, Drift layers (sub-bass, tinnitus, heartbeat), diegetic stingers, and deliberate silence.
- **Silence as a weapon:** the Director drops ambient sound for a second or two before an intrusion.
- **Space:** reverb zones sized to each room, occlusion by raycast with low-pass filtering behind walls, and distance falloff on every emitter.
- **Voice integration:** teammates' voices pick up room reverb, Dead Air filters them, and the radio gets static that scales with Drift.
- **Sourcing:** commission a composer and sound designer for the stalker and Drift layers, supplement with CC0 libraries such as Freesound, and check Roblox's current audio upload rules and costs before you plan the pipeline.
- **Mix:** design for headphones first, then verify on phone speakers.

### Marketing visuals from day one

Build three "thumbnail moments" during the vertical slice: a figure at the end of a hall, two players seeing different doors, and a squad crowded in a Lantern room. They become your icon, thumbnails and trailer.

## 9. Monetization and economy

Sell comfort, expression and social convenience, and never sell safety from the core threat. Cosmetics and private servers should carry launch revenue, with a season pass added later. Pay-to-survive would destroy the tension players came for.

### How Roblox pays you

- You receive 70% of the Robux spent in your experience, and Roblox keeps a 30% marketplace fee ([Creator Hub](https://create.roblox.com/docs/get-started/monetization)).
- Earned Robux cash out through DevEx at $0.0038 per Robux, with a 30,000 Robux minimum ($114), and a higher $0.0054 rate for eligible purchases by age-verified US players aged 18+ ([Roblox Help](https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page)).
- Roblox Plus subscribers can create paid private servers for free, and you earn up to 100 Robux per subscriber each month for time they spend in them ([Creator Hub](https://create.roblox.com/docs/production/monetization/roblox-plus)). This suits friend-group horror well.
- Creator Rewards pay a fixed 5 Robux when an Active Spender plays 10 or more minutes, and a 35% revenue share on the first $100 spent by new or returning users who arrive through a link or search. Your 25-minute runs suit this. Programs change often, so re-check the Creator Hub monetization pages before you build the store.

A worked example: a player spends 1,000 Robux, you earn 700, and DevEx pays about $2.66 for those 700.

### A sanity-check revenue model

Monthly earned Robux are roughly monthly players × paying share × average spend per payer × 0.7. These inputs are illustrative assumptions, not benchmarks: 50,000 monthly players × 3% paying × 500 Robux × 0.7 = 525,000 Robux, which is about $2,000 through DevEx. Most Roblox games earn far less than that, so plan the project as a craft investment with upside, not a salary.

### Product catalog

Prices are starting hypotheses to test, in Robux.

| Product | Type | Starting price | Why it fits | Ships |
| --- | --- | --- | --- | --- |
| Paid private server | Private server | You set it | Friend groups want private runs; Plus subscribers also generate payouts | Launch |
| Tool skins (flashlight, camera, radio) | Pass or product | 100–300 | Cosmetic only, visible to teammates | Launch |
| Ping effects and callout icons | Product | 50–150 | Social expression with no gameplay effect | Launch |
| Case Board pins, hub decor, Dossier frames | Product | 50–200 | Personalization and flexing in the hub | Launch |
| Supporter pack | Pass | 500–1,000 | Cosmetic bundle plus a name in the credits | Launch |
| Season pass ("Case Files") | Pass or subscription | 400–800 per season | Free and paid reward tracks, cosmetics only, 8–10 weeks long | 2–3 months after launch |
| Hub-only ads | Immersive ads | n/a | Optional; never inside a run | After launch, if at all |

### What never to sell

- Extra lives, instant revives, stalker slows or stuns, bonus evidence, extra Focus, Drift reduction or hints. All of these are pay-to-survive.
- Random paid item boxes. They add policy and ethics risk and you do not need them.
- Anything that makes a squad's run easier than a free squad's run.

### Free progression loop

- **Marks:** soft currency earned every run, win or lose, spent on free tool variants and cosmetics.
- **Clearance levels 1–50:** unlock new contracts, locations and optional difficulty modifiers.
- **Daily contract:** a fixed seed for everyone, so players compare runs and share clips.
- **Dossier:** collectible entries about each stalker and anomaly, discovered through play.
- **Challenges:** optional goals such as "extract without using the camera" or "survive three hunts without hiding".

### Content rating

Your label comes from your honest answers to Roblox's questionnaire, so choose your content ceiling on purpose. Mild fear covers heavy breathing, screaming, creepy-looking NPCs, jump scares, ominous music and suspense, which is what implication-driven horror uses. Moderate fear is triggered by realistic blood, visible organs, open wounds or bleeding eyes ([Creator Docs](https://create.roblox.com/docs/production/promotion/content-maturity)).

Keep the stalker free of that imagery and the game most likely lands at Mild, which is eligible for Roblox Kids (ages 5–8) and Roblox Select (ages 9–15) once extra publishing requirements are met. Choosing Moderate imagery limits reach to Select and standard Roblox (ages 16 and up).

> **Decision (2026-10-02): target Moderate.** The owner chose Moderate so the late game can reach P.T.'s level of dread (see `docs/ART.md`). That gives up Roblox Kids (5–8) only. The ceiling is Moderate's: realistic blood, bleeding eyes, disfigured faces and wounds are allowed; severed body parts, dismemberment and anything else in Restricted are not.

- Retake the questionnaire whenever an update changes an answer. A missing or inaccurate label can restrict playability for everyone.
- Avoid free-form drawing or writing by players, including chalk marks and Case Board notes. Free-form user creation limits access to players 16 and older, so use stamped markers and preset labels.
- Disclose paid random items if you ever add them. This plan does not use them.

## 10. Development roadmap

The plan has six build phases plus live operations, and every build phase ends at a gate that tests fun and stability, not a feature checklist. Durations assume a core team of three at 15–20 hours a week each, about 58 weeks in total. A solo developer should plan for roughly double that, or use the lean launch in section 11.

&#91;embedded content: roadmap · 7 phases, 6 gates, 58 weeks to launch\]

If a gate fails, stay in the phase and fix the cause. The costliest mistake in this plan is building content on top of a core that has not passed Gate 2.

### Phase 0 · Foundations (weeks 1–4)

Remove the biggest unknowns before committing to anything.

- Set up Roblox Studio, VS Code, Rojo, Git and a task board.
- Build the two-client prototype: a door that only one player's client renders and collides with, tested in Studio's multi-client mode.
- Publish a private place, enable voice, set `UseAudioApi` to Enabled, and route one voice through a low-pass filter.
- Re-read the current Creator Hub pages on maturity labels, voice and monetization, since policies move.
- Write the one-page pitch, check the name, and play the ten most popular Roblox horror games with notes.

### Phase 1 · Grey-box prototype (weeks 5–12)

Prove the core loop with ugly art.

- Project architecture: modules, signals, config, a run state machine.
- LevelGenerator v0 with 6–8 grey-box rooms, loops and a first validator.
- WitnessService with hold, ping, anchor and Focus.
- DriftService using the sources and sinks in section 2.
- Stalker v0: vision, hearing, pathfinding, tiers 0–4 and the observation rule, plus basic hiding spots.
- One anomaly end to end: Phantom Architecture with four tells and the Triangulate ritual.
- A debug overlay, logged seeds, and weekly sessions with three friends.

### Phase 2 · Vertical slice (weeks 13–26)

One location that is as good as the final game.

- Build The Halfway House with 12–20 hand-lit room prefabs and final materials.
- Stalker: The Guest archetype, the Director tuned, a first set of about six tactics, full hunt, hide, loop and retreat.
- Anomalies: add Counterfeit and Gaze for three in total, plus the Case Board, Deliberation Table and verdict flow.
- Audio: bring in the sound designer for Drift layers, room acoustics and stalker audio.
- UI pass, tutorial v0 and the accessibility settings screen.
- Capture the three thumbnail moments and cut a first trailer test.
- Publish a Prologue demo to start collecting followers.

### Phase 3 · Alpha (weeks 27–42)

Widen the content and build the systems around it.

- Second location (St. Odile Ward) and The Orderly archetype.
- Anomalies: add Redaction, Dead Air and Mimic for six in total.
- Squad Profile and the full tactic menu of 8–15 with their counters.
- Hub place, MemoryStore matchmaking, reserved servers and private servers.
- Player data: Marks, clearance levels, unlocks, and the daily contract.
- Tutorial run, onboarding tuning, store scaffolding with the first cosmetics, and analytics events with a dashboard.
- A closed alpha run through Discord, with a weekly build.

### Phase 4 · Beta (weeks 43–54)

Harden, tune and prepare to be seen.

- Third location (Hush Motel) and anomalies Umbra and The Echo, for eight in total.
- Mobile performance pass with graphics-tier fallbacks.
- Complete accessibility options and photosensitivity protections.
- Economy tuning from alpha data, the supporter pack and store polish.
- Marketing: trailer, icon, thumbnails, press kit and a creator contact list.
- Open beta, server stress testing, and a fix pass on the top bugs.
- Final Maturity and Compliance Questionnaire and policy review.

### Phase 5 · Launch (weeks 55–58)

- A soft launch with no paid ads, watched for 7–10 days.
- Wide launch with creator seeding, the trailer, a Discord event and a small ads test.
- Daily monitoring and hotfixes within 24–48 hours.

### Phase 6 · Live operations

The monthly cadence, content order and seasonal plan are in section 12.

## 11. Team, tools, budget and scope control

The plan assumes a core team of three working part-time (about 15–20 hours a week each), which lands at roughly 14 months to launch. Solo, expect around double that, or ship the lean version described under scope control.

### Roles

| Role | Responsibility | If you are solo |
| --- | --- | --- |
| Gameplay and AI programmer | Run state, Drift, divergence, networking, stalker | You |
| Systems and level designer | Room kit, prefabs, generator rules, anomaly data | You, kit-bashing a small room set |
| Lighting and environment artist | Hero rooms, lighting, materials | Learn lighting yourself; buy or commission hero props |
| Animator and character artist | Stalker models and animation | Commission one stalker at a time |
| Sound designer and composer | Ambience, stingers, Drift layers | Commission this first; best return per dollar |
| UI and UX | Case Board, HUD, hub, accessibility | Simple diegetic UI built in Figma first |
| Producer and community | Roadmap, Discord, playtests, marketing | You |

### Tool stack

- **Roblox Studio** with Team Create for building and lighting.
- **VS Code, Rojo and Git** so code lives in files and in version control, not only inside Studio. Add Luau LSP, StyLua and Selene for editor support and linting.
- **Wally** for packages, plus a small set of libraries: a signal and promise library, and a session-locking data library such as ProfileStore (check its current maintenance status).
- **Testing:** a Luau test framework such as Jest-Lua for generator, Drift and Director logic.
- **Art and audio:** Blender, a texture workflow based on CC0 libraries, and Reaper or Audacity.
- **Design and planning:** Figma for UI, plus Notion, Linear or Trello for the backlog.
- **Community:** Discord, from the first alpha.
- **Analytics:** Roblox's built-in Creator analytics, plus custom events and funnels if your account has them. Verify the current feature set early.

### Rough budget

These are planning ranges, not quotes, and depend heavily on whether you build or buy.

| Item | Range (USD) | Notes |
| --- | --- | --- |
| Sound design and music | 500–3,000 | Outsource; the biggest quality jump per dollar |
| Stalker model and animation | 300–1,500 per stalker | Or learn the Blender pipeline yourself |
| Textures and asset packs | 0–300 | CC0 libraries first |
| Trailer, key art, icon and thumbnails | 200–1,000 | Needs the hero rooms finished |
| Roblox ads test | 500–3,000 | Only after soft launch proves retention |
| Tools and subscriptions | 0–50 per month | Mostly free tiers |

### Scope control

| Priority | Items |
| --- | --- |
| Must (never cut) | Witnessing and anchoring; Drift; stalker tiers 0–4; hide and loop play; one fully polished location; 6 anomalies; lighting and audio pass; tutorial; private servers |
| Should | Adaptation system with at least 8 tactics; second location; progression; daily contract; accessibility options |
| Could | Third location; Companion Witness; deeper cosmetic catalog; season pass; Echo hint system |
| Won't (version 1) | Open world, PvP or traitor roles, story campaign, VR, player-built levels |

If you fall behind, cut in this order: third location, anomalies from 8 to 6, tactics from 15 to 8, Companion Witness, season pass, cosmetic count. Never cut lighting, audio, Witnessing or the tutorial.

**Lean launch for a solo developer:** 2 locations, 6 anomalies, 8 tactics, cosmetics and private servers only. That is a complete, shippable game.

### Fun gates

Every phase in section 10 ends with a playtest question, not a feature checklist. If the core is not fun with friends at a gate, stop adding systems and fix the core.

## 12. Launch, live ops and growth

Treat launch as a ladder of staged tests, each proving one thing, then use the first month of real data to decide where to spend. The biggest single timing decision is Halloween: today is October 2, 2026, and a roughly 14-month plan reaches launch readiness around late 2027, so the realistic target is a soft launch in September 2027 and a wide launch for Halloween 2027, protected by cutting scope early rather than slipping.

### The playtest ladder

1. **Friends and family** (phases 1–2): 5–10 sessions. The test is whether people say "I don't see that!" unprompted.
2. **Prologue demo** (end of phase 2): a short, free, single-location experience that builds followers and tests onboarding and voice stability.
3. **Closed alpha** (phase 3): 30–100 players from Discord. Tests balance, matchmaking and data saving.
4. **Open beta** (phase 4): public and labeled Beta. Stress-tests servers, mobile performance and the first store.
5. **Soft launch** (phase 5): publish quietly with no paid ads and watch 7–10 days of data.
6. **Wide launch:** coordinated creator seeding, trailer and optional paid ads.

### Metrics to instrument from the first alpha

Targets are hypotheses. Compare them against your own Creator analytics and Roblox's benchmarks as they become available.

| Metric | Why it matters | Starting target |
| --- | --- | --- |
| Tutorial completion | Onboarding clarity | Over 70% |
| Run completion (start to debrief) | Pacing and frustration | 40–60% |
| Win rate per anomaly | Fairness and deducibility | 35–55%, never below 25% or above 65% |
| Median run length | Pacing | 22–30 minutes |
| Wrong-verdict rate | Are tells readable? | 25–40% |
| Quit points (phase, Drift level, after a hunt) | Where frustration lives | Review every build |
| Day-1 and day-7 retention | Stickiness | Track and beat each build |
| Payer conversion and spend per payer | Monetization health | Track by product |
| Ping and voice usage | Is the social loop working? | Rising over alpha |

### Safety, moderation and compliance checklist

- Complete the Maturity and Compliance Questionnaire, and retake it when content changes.
- Review Roblox Community Standards for scary-content rules: no real-world tragedies, no graphic gore, no depictions that cross the line for the label you chose.
- Use Roblox's chat and voice systems only. Do not record voices, and do not build free-text chat.
- Keep data collection minimal, and design purchase prompts so they never pressure younger players.
- Ship photosensitivity options and a warning screen.
- Server authority for every outcome that matters, rate-limited remotes, a report pipeline and a ban list.
- Check the name "Consensus" for trademark and existing Roblox titles before building your brand around it, and keep a licensing sheet for every external asset.

### Discovery and marketing

- **Store page:** a strong icon, 3–5 thumbnails and a one-line hook such as "Your friends see something different." Test icon and thumbnail variants one at a time and compare click-through in Creator analytics.
- **Clip engine:** design clip-friendly moments, make the Dossier screen shareable, and give players easy ways to record their best arguments.
- **Creator seeding:** contact 30–50 small and mid-size horror creators on YouTube and TikTok two to three weeks before launch with private-server access and a press kit (trailer, key art, FAQ, tips). Disclose any paid sponsorships.
- **Community:** Discord from the first alpha, weekly dev logs and a public roadmap.
- **Paid acquisition:** only after retention is proven. Start small and compare ad spend against the Robux a new player earns you.

### Live ops cadence

- **Weeks 1–2:** daily monitoring, hotfixes within 24–48 hours, community Q&A.
- **Every 2 weeks:** a patch for bugs and balance.
- **Monthly:** a content drop, such as a new anomaly, room set or cosmetic line.
- **Quarterly:** a larger update, such as a new location and stalker.
- **Seasonal events:** Halloween and December, with limited cosmetics and a themed daily contract.

### First six post-launch months

1. **Month 1:** anomaly 9 (Hollow) and a balance pass from launch data.
2. **Month 2:** season pass one and daily contract improvements.
3. **Month 3:** location 4 with a new stalker archetype.
4. **Month 4:** anomaly 10 (Tide).
5. **Month 5:** Companion Witness for solo players, and anomaly 11 (Proportion).
6. **Month 6:** anomaly 12 (Loop Corridor), a Nightmare mode, and a review of retention and revenue against your hypotheses to decide where to invest next.

## 13. Risks and next steps

The two risks most likely to sink the project are scope creep and an empty queue at launch, so both have explicit mitigations built into the plan.

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Scope creep | High | High | Fun gates, the Must/Should/Could list, and the fixed cut order in section 11 |
| Too few players to fill a squad at launch | High | High | Allow 1–4 players, private servers, friend invites, creator seeding, later Companion Witness |
| Divergence feels confusing instead of scary | Medium | High | Start with 3 anomalies, keep every tell verifiable, give the Witness Camera as a safety net, playtest early |
| Stalker feels cheap or dumb | Medium | High | Mandatory telegraphs, paired counter-counters, decision logs, bot-squad simulations |
| Mobile performance | Medium | High | Lighting and instance budgets, early testing on a low-end phone, fallback quality tier |
| Voice limited to age-checked players 13+ | High | Medium | Ping wheel and structured callouts give full parity without a mic |
| Per-client geometry behaves badly with physics or network ownership | Medium | High | Prove it in the phase 0 prototype before building anything on top |
| Rating or moderation problems | Low–Medium | High | Choose the content ceiling on purpose, avoid realistic gore, retake the questionnaire when content changes |
| Exploiters ruin runs or reveal hidden info | Medium | Medium | Server authority, send truth only when earned, rate-limited remotes, accept some client-side cheating |
| Burnout or team churn | Medium | High | Part-time sustainable hours, small milestones, visible progress, scope cuts instead of crunch |
| A similar game launches first | Medium | Medium | Ship the vertical slice and prologue early, build community, lean into the unique Witnessing rule |
| Roblox monetization or policy changes | Medium | Medium | Cosmetics-led model, re-check Creator Hub pages each quarter |

### Do this week

- [ ] Decide solo or team and your weekly hours; this chooses between the full plan and the lean launch
- [ ] Install Roblox Studio, VS Code, Rojo and Git, and create the repository
- [ ] Build the two-client prototype: one door visible to one player only, with local collision, tested in Studio's multi-client test
- [ ] Publish a private test place, enable voice with `UseAudioApi`, and route one friend's voice through a low-pass filter
- [ ] Play the ten most popular Roblox horror experiences and note their retention hooks, monetization and gaps
- [ ] Write a one-page pitch and check the name "Consensus" for conflicts
- [ ] Create a backlog board seeded with phase 0 and phase 1 tasks
- [ ] Sketch the three thumbnail moments
- [ ] Line up five friends as the first playtesters

## Sources

These Roblox pages were opened for the figures and rules above, as of 2026-10-02. Programs and policies change, so re-check them before you build the store or submit the questionnaire.

- [Developer Exchange help page](https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page): DevEx rates and the 30,000 Robux minimum.
- [Creator Hub: How do I make money?](https://create.roblox.com/docs/get-started/monetization): the 70/30 split, Creator Rewards, subscriptions.
- [Creator Hub: Roblox Plus](https://create.roblox.com/docs/production/monetization/roblox-plus): paid private server payouts.
- [Creator Hub: Content maturity and compliance](https://create.roblox.com/docs/production/promotion/content-maturity): labels, fear tiers, audience tiers, free-form creation.
- [Roblox Help: How do I turn on Voice Chat?](https://en.help.roblox.com/hc/en-us/articles/34506487825428-How-do-I-turn-on-Voice-Chat): age check and opt-in rules.
- [Roblox voice chat docs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/chat/voice-chat.md): proximity default, `UseAudioApi`, per-listener access lists.

Prices, budgets, targets and timings elsewhere in this document are planning assumptions, not sourced figures.
