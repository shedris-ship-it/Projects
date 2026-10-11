# The owner's playtest of 2026-10-11, and an audit before the next phase

Builds `2026-10-11.160` onwards, branch `claude/overnight-foundation`. The owner's seven notes, all fixed, then a pass through the game for anything else in the way of moving on.

## The seven notes

**1. "Right clicking changes difficulty at the table and should just be E."** Reproduced in Studio: a right click *anywhere* in the hub changed the contract. The cause was bigger than the table. On a keyboard every E prompt gives up its own key (so E goes to the one thing you look at), and it gave it up to `KeyCode.Unknown`. Roblox's prompts match `Unknown` to a mouse button, because a click's KeyCode is Unknown, so every prompt Roblox was showing fired on a click or a right click, and took the click. Now a prompt gives up its key to one no keyboard sends (`HandsController` `NO_KEY`). Checked: right clicks do nothing at the table, E changes it.

This one root cause explains several older notes too: "the click arrived marked processed" (build `.154`), the note's Put it down opening the note again (`.148`), and note 6 below.

Also: Roblox reports the first input of a session as "Focus", which the hands read as a gamepad, so prompts kept E and Roblox's own choice until the mouse moved. Focus now keeps whatever the device was (a keyboard if there is one). And in the hub, where the camera looks over your shoulder, E takes the nearest prompt in reach; the marker says "E Change difficulty".

**2. "Wind up toys have no gravity and can float off the stairs."** The toy walked by moving its model along, at the same height whatever was under it. It now falls (`ToyService:_step`, the world's gravity). Off a stair step it lands and walks on; off anything higher than 1.6 studs (a table, the gallery) it lands on its side with a clatter he can hear, and stops. Winding it again stands it up. Checked in Studio with a 1.2-stud drop (walks on) and a 3-stud drop (on its side).

**3. "Revive is unintuitive and has no indicator."** The revive prompt sits on the downed player's root, inside the body, so looking at the body found nothing, and the prompt's line of sight ran through the body. Now any part of a downed friend is the thing you look at: the focus says "Hold E Revive" and its bar fills while you hold. Their marker says the seconds left and the distance, then "Look at them, hold E (4 s)" once you're close. While someone holds E, the downed player reads "NAME IS PULLING YOU UP" with a green bar under the red one, and the rest of the squad sees "NAME is pulling them up · 60%". The toast when someone goes down says what to do. This needs two clients to see (TC-256).

**4. "Make jumping slower and more realistic like traditional horror games."** A Roblox jump was a 3-stud hop over in a third of a second. Now it's a low hop of about 2.2 studs under a gentler gravity than the world's, a little quicker coming down than going up: about 0.6 s in the air (measured in Studio: peak 2.4, 0.6 s). It rests for 0.6 s after landing, costs some stamina, and there's no jump while crouched or winded. Falling off a ledge is as fast as before. The numbers are `Config.Player.Jump*`; the maths is `Logic/Feel` with a spec.

**5. "Useless items kinda suck."** Drawers held a cassette, matches, letters, a candle, thread or a pill bottle, and none of them did anything but get thrown. Now most of what a drawer holds does something when you look at it and press E (the click still picks it up):

- **Batteries:** a third of a torch back. With a full torch they stay put for someone else.
- **Painkillers** (rare: one a run alone or for two, two for three or four): one of your downs forgiven. With no downs they stay.
- **Old letters:** someone went through them before you and pencilled a note to themself, which points at what the run wants next (the stuck-assist's line, on demand), and the map rings that room for 90 s. The keepsake boxes' decoy letters are these too.
- **Matches:** two in your pocket. Hold E at an unlit lantern shrine and it lights in 2 s with one (bare hands take 5 s), as the Lantern does.
- **A cassette, a candle, thread:** for throwing: a lure, and a hit stuns him.

Data/Finds lists them (and how many a run); Logic/Finds picks (spec); Services/FindService gives each its use. F2 `find <name>` puts one in front of you. Checked in Studio: the painkillers after a down, the letters, the matches at a shrine.

**6. "Fuse box step back button still doesn't work on my playtest, pressing Esc for it is weird bc it opens the roblox menu."** The same root cause as note 1: the click on Step back also fired the fuse box's own prompt, still showing, which opened the screen again at once. Fixed with note 1, and checked with the prompt showing. E now steps back from every puzzle screen too (the button says "Step back (E)"), and the E or the click that puts a screen or a note away can never reach your hands and open it again (`Ui.dismissed`). Escape still works, but nothing tells you to use it.

**7. "Lets make the down timer 30 seconds."** Done, alone or with friends (alone was 20). The last 10 seconds turn red and urgent (was 6).

## Found on the way

**A third of the lantern rooms had no shrine (fixed).** The house picks one or two lantern rooms (the safe rooms, where your torch charges and you can crawl to the light). In the mansion it could pick a corridor, and corridors have no place for a shrine. Upstairs the shrine was then put in the middle of the corridor, in the walking lane. On the ground floor its facing was worked out as "away from the room's middle" while standing on the middle, which is no direction at all, and Roblox moved the whole shrine a million studs down: that lantern room never existed. Over 160 houses, 74 of 231 lantern rooms were corridors and 40 of them lost their shrine. Lantern rooms are now only rooms with a shrine spot (`MansionGen`), and the builder never makes a shrine facing nowhere. This changes which houses are built (the lanterns move), so every house was checked again: `tools/completable`, 1152 houses, all finish. Gate A (the old house) is unchanged: parts 2269, hash 1553234744.

**Working a puzzle made you idle (fixed).** With two or more players, a minute without moving or turning the camera makes you Lost ("idle too long"). Working the safe's dial or the computer with the mouse doesn't move the camera, so a careful player could be made Lost mid-puzzle. Now anything you do (every remote the server accepts: a puzzle click, a door, a drawer, a tool, a line said) counts as being there.

**Text that ran off (fixed).** The hub panel's "Difficulty: Hard (uneasy, more wings, quicker hunts)" ran off its button; Hard's meaning is now a line under it. The ready line was cut off. In a run, a long objective line with the stuck-assist's sentence was cut mid-word; it now wraps.

**The how-to** mentions jumping, E to leave a puzzle or note, and that a friend has 30 seconds to hold E on you.

## Checks

562 unit tests (5 new: the jump, the finds). stylua, selene, compile and the build are clean. `tools/completable`: 1152 houses, 0 can't be finished. Studio, no console errors through two full bot runs (F2 `botrun fast`):

- seed 1800820264, alone: out at 5:47, 12 steps, none failed; caught once in a hunt while carrying the last heirloom, crawled 12 studs to a lit lantern and got up.
- seed 4242, a house for four: out at 4:52, 20 steps, none failed, no downs, 5 scares in the first ten minutes.

One number to watch: the bot stopped to let him pass 20 and 16 times (the last report's run: 5). He was seen 2.7 times a minute between hunts. Nothing in this pass touches how he moves, and the bot runs at double speed and so meets him more, but after "rarer and deadlier" that's worth a look in your next playtest: does he get in your way too often?

## For the owner

TC-254 to TC-263 in `docs/TESTING.md`. Reviving (TC-256) and the idle rule (TC-261) need two clients.
