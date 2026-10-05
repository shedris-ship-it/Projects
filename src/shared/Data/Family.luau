-- The family who lived here (docs/plans/level-design.md section 11, L3.1;
-- Logic/Family makes one a run). Each member has a name, the rooms that were
-- theirs, the charm on their keyring (a mark, Data/Marks: the doors into
-- their part of the house carry it), the heirlooms that were theirs, and a
-- voice their notes are written in (Data/Notes).
--
--   calls     how the family says them and how they sign ("Dad"); nil: by
--             their first name (the children), or "Mrs. " and their surname
--             (`formal`, the housekeeper)
--   names     first names (or the housekeeper's surname), drawn one a run
--   marks     the charms they might carry, best first
--   rooms     room templates that are theirs when the house has them
--   heirlooms Items.Heirlooms kinds that were theirs
--   needs     room templates the house must have for them to live here
--   voice     whose notes they write (Data/Notes voices)

return {
	Surnames = { "Ashford", "Caldwell", "Hollis", "Lindqvist", "Marsh", "Penrose", "Pryor", "Whitcombe" },
	Members = {
		{
			id = "dad",
			calls = "Dad",
			names = { "Richard", "Gary", "Douglas", "Ronald", "Dennis", "Walter" },
			marks = { "phone", "star" },
			rooms = { "study", "garage", "workshop", "den", "wine_cellar", "master_bedroom" },
			heirlooms = { "PocketWatch" },
			voice = "dad",
		},
		{
			id = "mom",
			calls = "Mom",
			names = { "Linda", "Carol", "Susan", "Diane", "Karen", "Janet" },
			marks = { "flower", "heart" },
			rooms = { "master_bedroom", "music_room", "sunroom", "living_room", "nursery" },
			heirlooms = { "Locket", "Candlestick" },
			voice = "mom",
		},
		{
			id = "daughter",
			names = { "Jennifer", "Amy", "Heather", "Melissa", "Nicole", "Laura" },
			marks = { "heart", "star", "cloud" },
			rooms = { "kids_bedroom", "playroom" },
			heirlooms = { "Doll" },
			needs = { "kids_bedroom", "playroom", "nursery" },
			voice = "child",
		},
		{
			id = "son",
			names = { "Michael", "Jason", "Kevin", "Brian", "Danny", "Timothy" },
			marks = { "sun", "cloud", "star" },
			rooms = { "kids_bedroom", "playroom", "nursery" },
			heirlooms = { "Cup" },
			needs = { "kids_bedroom", "playroom", "nursery" },
			voice = "child",
		},
		{
			id = "grandma",
			calls = "Grandma",
			names = { "Edith", "Dorothy", "Mildred", "Ruth", "Agnes" },
			marks = { "scissors", "note" },
			rooms = { "sewing_room", "guest_room", "box_room", "lumber_room" },
			heirlooms = { "Candlestick", "Cup" },
			needs = { "sewing_room", "guest_room" },
			voice = "grandma",
		},
		{
			id = "housekeeper",
			formal = true,
			names = { "Novak", "Alvarez", "Brennan", "Okafor", "Lund" },
			marks = { "umbrella", "note" },
			rooms = {
				"kitchen",
				"pantry",
				"laundry",
				"mudroom",
				"servants_room",
				"boiler_room",
				"storeroom",
				"cold_store",
				"tank_room",
			},
			heirlooms = {},
			needs = { "kitchen", "servants_room" },
			voice = "housekeeper",
		},
	},
	-- How likely a second child is when the house has room for only one.
	SecondChild = 0.5,
}
