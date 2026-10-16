# The lobby's story: drafts and questions for the owner

The owner, 2026-10-16: build the foundation for things to read in the lobby, "I want input on the story". So this is a draft to react to, not a decision. Pick an option for each question (or write your own), and Claude rewrites the texts to match.

The foundation is built: `Data/Lore.luau` holds each thing to read (where it is, the text, which map it's about), `Services/LoreService` puts them up, and E reads one on a sheet. Every text is marked `draft` and shows only in Studio, so nothing reaches the live game until you've settled it. Five drafts are in the garage now (the case file on the desk, the case board, the radio log, an evidence box, a note on a cot), written from the options marked *Claude's pick* below.

## What's already true in the game

These come from what's built, so the story should fit them:
- **1988.** A dead mall, closed off behind a shutter. A secret community of investigators lives in its lit corner on their own generator (the owner's words: "an abandoned mall with a secret community of investigators in it"). Their camp is in the garage: cots, a case board with photos and red string, a CB radio, evidence boxes. The mall's clock stopped at 9:47.
- **The case:** "CASE 88-0412, THE HALFWAY HOUSE", rented like a film from the video store, driven to in a station wagon. Its line: "A family house that locks you in and lays a place for its guest."
- **The house is different every run,** and so is its family. The surname comes from a list of eight: Ashford, Caldwell, Hollis, Lindqvist, Marsh, Penrose, Pryor, Whitcombe. The family's notes, heirlooms and marks are theirs.
- **The Guest:** a tall figure in a porcelain mask that cracks. He comes to dinner. The table is laid for him, and setting the family's heirlooms at it opens the front door.
- **The tone:** P.T. as the mood, "extremely scary" within the Moderate rating. Nothing gory in what's read.

## The questions

### 1. Who are the investigators?

- **A. People the house touched** (*Claude's pick*). Each of them saw it, lost someone to it, or got out of it. They found each other at night on CB channel 19, where truckers report a lit house that wasn't there yesterday. No badge, no funding, nobody believes them. This explains why they hide and why they send ordinary people (the players) in.
- **B. What's left of an official unit.** A shut-down state office for "unexplained residences", working on without permission, out of sight of the people who closed them.
- **C. A late-night radio show's listeners.** The host started taking calls about the house, and the callers became a crew.

### 2. Why the dead mall?

- **A. Off the map and on a generator** (*Claude's pick*). One of them (Ray, in the drafts) was its night guard and still has the keys. It's dark, empty and big enough for the cars. The shutter closes off the parts nobody should go into.
- **B. The mall is part of the case.** Every family the house took shopped there, and the mall died the year the first one went missing.
- **C. Something happened at the mall too,** behind the shutter (a way to use the shutter later, the owner's "to be discussed").

### 3. What is the Halfway House?

- **A. A house that moves** (*Claude's pick*). It appears for one night on a different street, with a different family's name on the mailbox, and is gone by morning. That's why every run's house and family are different, and why the case file lists eight families, none found.
- **B. One house, many families.** The same address, the families who lived there over the years; the house shows you a different decade each night.
- **C. Never explained.** The clippings and notes contradict each other.

### 4. Who is the Guest?

- **A. Never explained, only glimpsed** (*Claude's pick*): the table set for one more, the place card ("for our guest") in fountain pen, a photo of a tall figure at a window. Explaining him makes him less frightening.
- **B. A hint of who he was:** a lodger, a visitor who never left, a name the families all knew.
- **C. Something the house invites:** the dinner is the point, and the families were the hosts.

### 5. Who are the voices?

The drafts use two:
- **Dot,** who keeps the radio and the log;
- **Ray,** the mall's old night guard.

More would come with more things to read: a crew member who came back changed, someone who writes up each run. Keep these two, rename them, or leave the writers unnamed?

### 6. Names you haven't picked yet

- **The group's name:** none, or something like "the night shift" or "Channel 19".
- **The mall's name:** you said atmosphere first, no name yet.

### 7. How much should a player be able to read?

- **A. A handful of things, always there** (*Claude's pick* to start): the five in the garage, plus the clippings once the clutter batch is in.
- **B. More unlock as you play:** a new page after your first escape, at each Clearance level. That's a reason to come back, and the Dossier could keep them.

## The drafts

All five are in `src/shared/Data/Lore.luau`. Their gist:

| Where | What | Says (in short) |
| --- | --- | --- |
| The desk | The case file (typed) | Opened 12 April 1988. The house is never on the same street twice, never there by day, a different family's name each time, none found. The door locks, the table is laid for one more, he comes to dinner in a mask. The way out: the heirlooms at the table. The eight families on file |
| The case board | What's pinned (typed) | The plan, different from every crew; the house at dusk "nobody remembers turning onto that street"; somebody tall at a window ("Ray says he waved"); the same house across town six weeks later; the hall ("don't look at it too long"); a place card on the porch "in our handwriting" |
| The CB radio | Dot's log (handwritten) | A trucker on channel 19 at 2:10 am: a lit house that wasn't there Tuesday, the table set. "Sent the wagon." |
| An evidence box | Its list (typed) | A place card "for our guest"; a pocket watch stopped at 9:47 (the mall's clock too); a family photo with the faces scratched out "(not by us)"; CB cassettes; a key with no lock; a silver napkin ring, "still warm" |
| The spare cot | Ray's note (handwritten) | "If you're reading this you're on my cot. Fine. Boots off. Generator on at dusk, off at dawn. Don't go past the shutter." |

The story clutter batch (sketched with this pass, `docs/progress/2026-10-16-lobby-story/`) adds newspaper clippings for the case board. Their headlines wait on these answers.

Every map-specific piece of this, the case file and the clippings and the photos, is listed in `docs/NEW-MAP.md` for when the next map comes out.
