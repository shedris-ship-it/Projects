-- Things to read in the lobby (the story's foundation; docs/plans/lobby-story.md):
-- the investigators' case file, what's pinned on their board, their radio
-- log, an evidence box's list, a note left on a cot. E on one reads it
-- (Services/LoreService, UI/Reader, as a note in the house is read).
--
-- Each sits on a piece already in the mall: `on` = { room, name, n }, the
-- nth Data/Mall block of that room and name, `offset` from its middle in its
-- own frame (studs), `size` the prompt's reach (a box). `action` and `object`
-- are its prompt's words. `style`: "hand" (ballpoint on a pad: short, 300
-- characters or so) or "typed" (a file, a list: longer).
--
-- `location`: the map it's about (Data/Locations), nil for the
-- investigators' own: a new map brings its own (docs/NEW-MAP.md).
--
-- `draft`: the story isn't settled (the owner wants a say, 2026-10-16), so
-- these are Claude's drafts from the options in docs/plans/lobby-story.md,
-- shown only in Studio until the owner keeps them (then `draft = false`).

return {
	{
		id = "CaseFile",
		on = { room = "garage", name = "Desk", n = 1 },
		offset = { 2, 1.8, 0 },
		size = { 2, 1, 2 },
		action = "Read",
		object = "The case file",
		style = "typed",
		location = "HalfwayHouse",
		draft = true,
		text = [[CASE 88-0412: THE HALFWAY HOUSE
Opened 12 April 1988. Still open.

A family house, two storeys, a cellar or an attic. Never on the same street twice. Never there by day. A different family's name on the mailbox every time. None of the families has been found.

Inside, the front door locks behind you. The dining table is laid for one more. He comes to dinner. He wears a mask.

The way out, every time: the family's heirlooms set back at the table. Then the front door opens.

On file: Ashford. Caldwell. Hollis. Lindqvist. Marsh. Penrose. Pryor. Whitcombe.

Whoever goes in comes back and writes it down.]],
	},
	{
		id = "CaseBoard",
		on = { room = "garage", name = "CaseBoard", n = 1 },
		offset = { 0, 0, 0.7 },
		size = { 6, 3, 1 },
		action = "Read",
		object = "The case board",
		style = "typed",
		location = "HalfwayHouse",
		draft = true,
		text = [[PINNED, LEFT TO RIGHT

The plan. Drawn from memory by the Pryor crew. Every crew's plan comes back different. The table is always in the middle of it.

The house at dusk, from the car. Nobody remembers turning onto that street.

An upstairs window. Somebody tall. Ray says he waved.

The same house, the other side of town, six weeks later. A different name on the mailbox.

The hall, blurred. Dot says don't look at it too long.

The porch. A place card on the step, in our handwriting.]],
	},
	{
		id = "RadioLog",
		on = { room = "garage", name = "CBRadio", n = 1 },
		offset = { 0, 0.6, 0 },
		size = { 1.6, 1, 1.4 },
		action = "Read",
		object = "The radio log",
		style = "hand",
		draft = true,
		text = [[Ch. 19, 2:10 am.
Trucker out by the quarry: lights on in a house that wasn't there Tuesday. He could see the table set through the window.
Sent the wagon.
- Dot]],
	},
	{
		id = "EvidenceBox",
		on = { room = "garage", name = "EvidenceBox", n = 1 },
		offset = { 0, 1.2, 0 },
		size = { 2.4, 1, 2.4 },
		action = "Read",
		object = "Evidence, 88-0412",
		style = "typed",
		location = "HalfwayHouse",
		draft = true,
		text = [[88-0412    BOX 1 OF 3

1 place card, cream: "for our guest", in fountain pen
1 pocket watch, stopped at 9:47 (came back with the Marsh crew)
1 photograph, the Penrose family, faces scratched out (not by us)
4 cassettes, CB recordings, channel 19
1 key, no lock found for it yet
1 napkin ring, silver, warm. Still warm.]],
	},
	{
		id = "CotNote",
		on = { room = "garage", name = "CotSpare", n = 1 },
		offset = { 2.5, 0.9, 0 },
		size = { 1.6, 1, 2 },
		action = "Read",
		object = "A note",
		style = "hand",
		draft = true,
		text = [[If you're reading this you're on my cot.
Fine. Boots off.
Generator on at dusk, off at dawn.
Don't go past the shutter.
- Ray]],
	},
}
