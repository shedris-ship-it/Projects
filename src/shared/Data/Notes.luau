-- The family's notes (R2c "leads"; Logic/NoteText fills them in): where a
-- key or an heirloom was put, in a 1988 family's everyday voice, with the
-- Guest at the edge of it. Within the Moderate rating (docs/plans/
-- gameplay-rework.md section 12): nothing graphic.
--
-- `key` and `heirloom` are for a house with no family (the old house):
-- {item} what it is ("Study key", "pocket watch"; {Item} with a capital),
-- {place} which drawer or cupboard ("the top drawer of the dresser"), {room}
-- which room ("the Study", "the upstairs Bathroom").
--
-- `voices` are the family's own (Data/Family, Logic/Family; docs/plans/
-- level-design.md section 11, L3.1), each written by one of them: {thing}
-- what it is ("phone key", "pocket watch"), {whose} whose it is from the
-- writer's side ("my", "Dad's", "the"; {Whose} with a capital), {sign} how
-- the writer signs ("Dad", "Heather", "Mrs. Novak"), and {place} and {room}
-- as above. A key is named by its mark, so a note says which door it fits.

return {
	key = {
		"Spare {item} is in {place} in {room}. Put it BACK this time.\n\n- Dad",
		"Honey,\nI moved the {item} to {place} in {room} so the kids stay out.\n\nLove, Mom",
		"{Item}: {place}, {room}.\nDon't leave it in the door again.",
		"If you need the {item}, it's in {place} in {room}.\nHe doesn't like that door left open.",
		"Note to self:\nthe {item} is in {place}, {room}.",
		"The {item} is in {place} in {room}. Please lock up before he comes for dinner.\n\n- Mom",
	},
	heirloom = {
		"Grandpa's {item} is in {place} in {room}. We set his place every Sunday, just how he likes it.",
		"Mom says the {item} stays in {place} in {room} until the guest comes to dinner.",
		"Kids -\nthe {item} lives in {place} in {room}. Don't play with it. It's HIS.",
		"Set the table properly this time. The {item} is in {place} in {room}.\nHe notices when something is missing.",
		"Found the {item} in {place} in {room} again.\nI didn't put it there.\n\n- D.",
		"When he comes, the {item} goes at his table. It's kept in {place} in {room}.",
	},
	voices = {
		dad = {
			key = {
				"{Whose} {thing} is in {place} in {room}. Put it BACK this time.\n\n- {sign}",
				"Whoever keeps taking {whose} {thing}: it lives in {place} in {room}. Leave it there.\n\n- {sign}",
				"Note to self: {whose} {thing}, {place}, {room}.\nDon't tell anyone where. He listens at the doors.",
			},
			heirloom = {
				"{Whose} {thing} stays in {place} in {room}. We set it out when he comes to dinner. Not before.\n\n- {sign}",
				"Moved {whose} {thing} to {place} in {room}. Somebody keeps moving it back.\n\n- {sign}",
				"{Whose} {thing} is in {place} in {room}.\nHe asked about it again tonight.",
			},
		},
		mom = {
			key = {
				"Honey,\nI moved {whose} {thing} to {place} in {room} so the kids stay out.\n\nLove, {sign}",
				"{Whose} {thing} is in {place} in {room}. Please lock up before he comes for dinner.\n\n- {sign}",
				"Kids, {whose} {thing} is NOT a toy. It's in {place} in {room} and it stays there.\n\n- {sign}",
			},
			heirloom = {
				"{Whose} {thing} is in {place} in {room}. Set the table properly this time.\nHe notices when something is missing.\n\n- {sign}",
				"Don't let your father near {whose} {thing}. It's in {place} in {room}.\n\n{sign}",
				"{Whose} {thing} goes at his place on Sunday. It's in {place} in {room}.\n\n- {sign}",
			},
		},
		child = {
			key = {
				"DO NOT go in my stuff. {whose} {thing} is in {place} in {room} and if its gone ill know.\n\n- {sign}",
				"i hid {whose} {thing} in {place} in {room}. its a secret dont tell\n{sign}",
				"{Whose} {thing} is in {place} in {room}. The man at dinner asked me where. I didnt tell him.\n\n{sign}",
			},
			heirloom = {
				"{Whose} {thing} is in {place} in {room}. Mom says we have to give it to him on Sunday. I dont want to.\n\n{sign}",
				"I put {whose} {thing} in {place} in {room} so he cant find it.\n\n{sign}",
				"{Whose} {thing}: {place}, {room}. dont touch!!\n- {sign}",
			},
		},
		grandma = {
			key = {
				"Dear,\n{whose} {thing} is in {place} in {room}, where it always was.\n\n{sign}",
				"{Whose} {thing}: {place}, {room}. I'm old, not foolish. Lock the doors at night.\n\n- {sign}",
				"If you're looking for {whose} {thing}, it's in {place} in {room}.\nDon't let him see you take it.\n\n{sign}",
			},
			heirloom = {
				"{Whose} {thing} is in {place} in {room}. My mother set it at his table, and her mother before her.\n\n{sign}",
				"We keep {whose} {thing} in {place} in {room} until he comes. We always have.\n\n- {sign}",
				"{Whose} {thing} is in {place} in {room}. Polish it before Sunday. He notices.\n\n{sign}",
			},
		},
		housekeeper = {
			key = {
				"{Whose} {thing} is kept in {place} in {room}. The family are not to borrow it.\n\n- {sign}",
				"Housekeeping: {whose} {thing}, {place}, {room}. Return after use.\n\n{sign}",
				"I have put {whose} {thing} in {place} in {room}.\nI will not go up there after dark again.\n\n- {sign}",
			},
			heirloom = {
				"{Whose} {thing} is in {place} in {room}, cleaned and ready for the guest.\n\n- {sign}",
				"Ma'am, I found {whose} {thing} in {place} in {room} again. I did not put it there.\n\n{sign}",
				"For Sunday: {whose} {thing}, {place}, {room}. He likes it set just so.\n\n- {sign}",
			},
		},
	},
	-- The children's crayon drawings (docs/plans/level-design.md section 4,
	-- L3.6; Services/ItemService): where they hid. {thing} is the hiding
	-- place ("wardrobe"), {room} its room, {name} the child.
	drawings = {
		"MY HIDING PLACE\n\nthe {thing} in {room}\n\nhe never finds me there\n\n{name}",
		"WHEN THE MAN COMES I GO IN THE {THING}\n\n({room})\n\nshhh\n\n{name}",
		"hide and seek champion!!\n\n{name} - in the {thing} in {room}\n\nnobody found me ALL DAY",
	},
}
