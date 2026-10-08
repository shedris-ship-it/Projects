-- Every tunable number in one place. Values marked "(doc)" come straight from
-- the design doc; the rest are starting guesses to tune in playtests.

local Config = {}

Config.Run = {
	MinPlayers = 1,
	-- The lobby starts on a majority or a timer (the owner, 2026-10-06): once
	-- at least half the hub is ready and this long has passed since the
	-- first Ready, the ready ones go in and the rest stay in the hub (Logic/
	-- LobbyRules). Everyone ready still starts at once.
	LobbyMajoritySeconds = 30,
	-- The length of the night (docs/progress/2026-10-07-loop/REPORT.md, WP8):
	-- "full" is the squad's house; "short" lays Config.Mansion.Profiles.short
	-- over it (a dinner in about ten minutes: a first run, a late night). The
	-- lobby's Night button and F2 `night` pick it for the next run.
	Night = "full",
	MaxPlayers = 4,
	LobbyCountdown = 5,
	ArrivalSeconds = 180, -- (doc) 3-4 min
	NoHuntBeforeSeconds = 180, -- (doc) hunts never start in the first 3 minutes
	StalkerDormantSeconds = 90, -- (doc) nothing appears in the first 90 seconds
	-- Downed players bleed out fast so the squad has to drop everything
	-- (owner, 2026-10-03; the doc's first draft said 45 s).
	DownedSeconds = 15,
	BleedWarnSeconds = 6, -- the last seconds get louder and redder
	ReviveHoldSeconds = 4, -- (doc)
	-- Downs matter (docs/progress/2026-10-07-loop/REPORT.md, WP2; the owner,
	-- 2026-10-06): this many downs in a run and you're Lost (Hard: see
	-- Config.Difficulty), and a player just pulled up can't be caught again
	-- for a moment, so a revive is never a second catch.
	DownsBeforeLost = 3,
	ReviveGraceSeconds = 8,
	-- Alone there is nobody to pull you up (the Companion is gone, the
	-- owner's choice of 2026-10-06): you bleed a little longer, and the light
	-- (a lit Lantern room) or a hiding place's mouth, crawled to, pulls you
	-- up; smelling salts (Data/Tools) bring you round where you fell.
	SoloDownedSeconds = 20,
	CrawlReach = 3, -- studs from a hiding place's mouth
	SaltsSeconds = 3,
	-- A lit Lantern room protects you with this much company in it, by the
	-- size of the squad (index = players in the run): alone, your own company
	-- is enough (the owner's RE save room, 2026-10-06); with friends it takes two.
	LanternCompany = { 1, 2, 2, 2 },
	HeartbeatBpm = 96, -- tempo of Assets.Sounds.Heartbeat at normal speed
	BleedHeartbeat = { 1, 0.45 }, -- heartbeat speed from just downed to gone
	ExtractionSeconds = 120,
	DebriefSeconds = 30,
	AfkSeconds = 60, -- (doc)
	EchoHintCooldown = 60, -- (doc) Echoes ping one hint per minute
	DownedCrawlSpeed = 3,
}

Config.Drift = {
	Max = 100,
	BaselinePerMinute = 2.5, -- (doc)
	IsolationDistance = 25, -- (doc)
	IsolationGraceSeconds = 20, -- (doc)
	IsolationPerMinute = 1, -- (doc) per isolated player
	-- Stalling (R2c): this long with no progress and the house grows restless,
	-- rising this much faster a minute until something gives.
	StallGraceSeconds = 240,
	StallPerMinute = 2,
	-- The events that count as progress (and end a stall).
	ProgressEvents = { LockOpened = true, PuzzleSolved = true, ItemFound = true, RegionEntered = true },
	Events = {
		PlayerDowned = 10, -- (doc)
		HuntSurvived = -10, -- (doc)
		-- The escape (docs/plans/gameplay-rework.md section 8): progress calms
		-- the house; fumbling a puzzle doesn't.
		LockOpened = -5, -- (rework)
		PuzzleSolved = -8, -- (rework)
		ItemFound = -2, -- (rework)
		PuzzleFailed = 3, -- (rework)
		RegionEntered = -4, -- (rework) the first step into a newly opened part of the house
	},
	-- Times a minute an event counts at most (DriftModel:Apply).
	Caps = {
		ItemFound = 3, -- (rework)
	},
	States = {
		{ name = "Calm", min = 0 },
		{ name = "Uneasy", min = 20 },
		{ name = "Fraying", min = 40 },
		{ name = "Breaking", min = 60 },
		{ name = "Collapsing", min = 80 },
	},
}

-- Watching (doc section 6): what the squad's eyes do now that Witness
-- windows and Focus have retired (R2c).
Config.Witness = {
	MaxRange = 45, -- studs a ping or callout aims
	CoStareSeconds = 3, -- (doc) two players holding a stare make him back away
}

-- The stare (the owner's audit of 2026-10-06, Finding 3; Logic/StalkRules,
-- Stalker/Perception): two of you watching him freezes him, but only while
-- he is in the light, so the dark, the battery and his KillLights matter;
-- in a hunt the stare holds him for a few seconds at a time and never ends
-- the chase; alone, a steady full beam stands in for the second pair of
-- eyes, at a cost in battery.
Config.Stare = {
	LitOnly = true, -- off: the old rule, any clear look counts
	DarkWatchRange = 4, -- at arm's length you see him whatever the light
	BeamRange = 42, -- the head beam's reach (PlayerStateService: SpotLight range 42, angle 50)
	BeamHalfAngle = 28, -- degrees off the camera's centre that the beam still lights him
	ClipRange = 16, -- the torch clipped to your shirt (Config.Hands.ClipLight)
	ClipHalfAngle = 40, -- ... points where your body faces
	LanternRange = 22, -- a lit Lantern in your hand lights him this far
	SoloBeam = true, -- alone (one active player), your full beam on him counts double
	SoloBeamSeconds = 0.6, -- ... once held steady this long
	BeamDrainScale = 3, -- and drains the battery this many times faster while it does
	HuntHoldSeconds = 4, -- in a hunt two watchers hold him this long at a time...
	HoldDecay = 0.5, -- ...then half as long each time within one hunt (4, 2, 1 s)...
	HoldMin = 0.5, -- ...never less than this
	HoldResetSeconds = 1.5, -- a hold is over once nobody has watched him for this long
	HuntWatchedSpeedScale = 0.45, -- how fast he comes on while two still watch (about a walk)
	CoStareEndsHunt = false, -- the old rule: a 3 s co-stare ended a hunt
	Cues = 2, -- how many times a run each player is told "[it stops in the light]" and the like
}

Config.Social = {
	PingCooldown = 0.8,
	PingLifetime = 7,
	CalloutCooldown = 2,
}

Config.Player = {
	WalkSpeed = 8, -- slow, in true horror fashion (owner, 2026-10-03); sprint stays fast
	LobbyWalkSpeed = 12, -- the hub stays brisk
	WindedSpeed = 10, -- out of stamina: a stagger, a little above a walk
	JumpHeight = 3, -- heavier jumps (was 4)
	SprintSpeed = 19,
	StaminaMax = 100,
	StaminaDrainPerSecond = 16,
	StaminaRegenPerSecond = 11,
	StaminaRecoverThreshold = 25,
	BreathMax = 100,
	BreathDrainPerSecond = 12,
	BreathRegenPerSecond = 25,
	-- Light is the stare's cost, not a walking cost (docs/progress/2026-10-07-loop/
	-- REPORT.md, WP3; the outside playtest's torch died at 6 and 13 minutes):
	-- twelve minutes of walking light, a tenth of that drain while it's
	-- clipped to your shirt, three times while your beam alone holds him
	-- (Config.Stare.BeamDrainScale), and a lit Lantern room recharges it on or off.
	FlashlightBatterySeconds = 720,
	ClipDrainScale = 0.1,
	FlashlightRechargePerSecond = 4, -- inside a lit Lantern room
	SprintNoiseRadius = 28,
	WalkNoiseRadius = 6,
	-- On boards that creak (the attic's), a step that makes noise also sets a
	-- board creaking this often (heard by everyone; creeping is silent).
	CreakChance = 0.35,
	WalkSpeedThreshold = 4, -- studs/s; below this you're creeping and silent
	FlashlightClickRadius = 8,
	JumpNoiseRadius = 14,
	SprintSpeedThreshold = 15,
}

-- What the stalker hears when players talk or type (Logic/VoiceNoise). Hiding
-- doesn't muffle it: a loud mouth in a locker gets found.
Config.Voice = {
	TalkLevel = 0.03, -- mic RMS (0..1) that counts as talking
	LoudLevel = 0.12, -- ... as shouting
	Hysteresis = 0.7, -- drop to a lower bucket only below this share of its threshold
	TalkRadius = 14,
	LoudRadius = 30,
	ReportInterval = 0.4, -- client -> server, seconds
	TextBaseRadius = 8,
	TextPerChar = 0.25,
	TextMaxRadius = 26,
	ShoutScale = 1.6, -- ALL CAPS
	ExclaimScale = 0.15, -- per "!" (up to 3)
	WhisperScale = 0.4, -- "/w text"
	MaxChars = 100,
	HearRange = 60, -- teammates this close get the line and its text-to-speech
	SayInterval = 1.5,
}

Config.Level = {
	CellSize = 40,
	WallHeight = 10, -- about 3.2 m: closer to a real house, so rooms feel tight (docs/ART.md, Scale)
	WallThickness = 0.5,
	DoorWidth = 6,
	DoorHeight = 8,
	Origin = { x = 0, y = 0, z = 0 },
	LobbyOrigin = { x = 0, y = 0, z = 1400 },
	RoomCount = { 10, 16 }, -- (doc)
	ExtraEdges = { 2, 3 }, -- (doc)
	MaxExtraEdges = 4,
	LoopLength = { 4, 8 }, -- (doc)
	MinLoops = 2, -- (doc)
	MaxDeadEndChain = 2, -- (doc)
	LanternRooms = { 1, 2 }, -- (doc)
	MaxAttempts = 10, -- (doc)
	DoorChance = 0.65,
	LaneHalfWidth = 4, -- doorway-to-centre lanes kept clear of furniture
	BandDepth = 8, -- furniture lives within this many studs of a wall
	-- Which generator builds the house: "Cells" (Logic/LevelGraph, the old
	-- house) or "Mansion" (Logic/MansionGen). The owner wanted the mansion when
	-- readying up normally (2026-10-04); F2 `layout cells` brings the old one back.
	Mode = "Mansion",
}

-- The mansion generator (docs/plans/mansion-generation.md). Rooms are
-- rectangles on a 10-stud lattice over two floors; the front of the house
-- faces south (+z) and nothing is built past the front line (z = 0).
Config.Mansion = {
	RoomCount = { 18, 24 }, -- owner, 2026-10-04: rooms over both floors, hallways and stairwells included
	-- The house follows the squad (owner, 2026-10-05; docs/plans/level-design.md
	-- section 5.2): each player covers about the same ground. Logic/HouseSize
	-- puts these over RoomCount and the lock planner's Regions and FinaleItems
	-- for a run. Hard adds a region, as before.
	-- `mansion` overrides more of this table: a small house has fewer
	-- hallways, so it isn't half corridor.
	-- `rooms` counts the main floors; the cellar's and the attic's come on
	-- top, each a wing more (`storeys`: one of them for one or two players,
	-- both for three or four; docs/plans/level-design.md section 10).
	-- Profiles laid over the squad's entry (Logic/HouseSize.config): the
	-- short night (WP8): one locked wing, two heirlooms, no pockets, tools or
	-- steps, neither the cellar nor the attic, the plainest plan.
	Profiles = {
		short = {
			rooms = { 13, 15 },
			regions = 1,
			heirlooms = { 2, 2 },
			pockets = { 0, 0 },
			maxTools = 0,
			wingSteps = { 0, 0 },
			storeys = { cellar = 0, attic = 0, onlyOne = true },
			mansion = { Stairwells = { 1, 1 }, RearCorridorChance = 0, TurnChance = 0, StackChance = 0 },
		},
	},
	BySquad = {
		{
			rooms = { 15, 18 },
			regions = 2,
			heirlooms = { 2, 2 },
			-- Side rooms behind the house key (docs/plans/level-design.md
			-- section 11, L3.2): fewest and most a house.
			pockets = { 0, 1 },
			maxTools = 1, -- one tool kind a run
			-- Steps inside a wing (section 11, L3.4): none for one or two.
			wingSteps = { 0, 0 },
			storeys = { cellar = 1, attic = 1, onlyOne = true },
			mansion = { Stairwells = { 1, 1 }, RearCorridorChance = 0.15, TurnChance = 0.15, StackChance = 0.15 },
		},
		{
			rooms = { 17, 20 },
			regions = 2,
			heirlooms = { 2, 3 },
			pockets = { 1, 1 },
			maxTools = 1,
			wingSteps = { 0, 0 },
			storeys = { cellar = 1, attic = 1, onlyOne = true },
			mansion = { RearCorridorChance = 0.3, TurnChance = 0.25, StackChance = 0.2 },
		},
		-- Three or four: one door may want two keys from two far rooms.
		{
			rooms = { 17, 20 },
			regions = 3,
			heirlooms = { 3, 3 },
			pockets = { 1, 2 },
			maxTools = 2,
			wingSteps = { 0, 1 },
			storeys = { cellar = 1, attic = 1 },
			flavours = { double = 1.5 },
		},
		{
			rooms = { 19, 22 },
			regions = 3,
			heirlooms = { 3, 3 },
			pockets = { 2, 2 },
			maxTools = 2,
			wingSteps = { 1, 2 },
			storeys = { cellar = 1, attic = 1 },
			flavours = { double = 1.5 },
		},
	},
	Lattice = 10,
	FloorPitch = 11, -- WallHeight plus a 1-stud floor
	MinShared = 20, -- shared wall that makes two rooms neighbours (a seam)
	DoorCornerClear = 7, -- door half-width 3 plus lane half-width 4
	Porch = { along = 14, out = 12 }, -- kept clear outside the front and exit doors
	FrontLine = 0,
	Hall = { x = -20, z = -50 }, -- the grand hall's north-west corner; its size comes from the template
	CorridorWidth = 20, -- closets and alcoves (phase M4) narrow the walkway to about 10-14
	CorridorLength = { 30, 60 },
	TurnLength = { 30, 50 },
	TurnChance = 0.35, -- the public corridor turns once
	RearCorridorChance = 0.5,
	StackChance = 0.3, -- a public or rear corridor is repeated upstairs (the service corridor always is)
	Stairwells = { 1, 2 }, -- owner: the grand stair plus 1-2 stairwells
	MinExitRooms = 4, -- doorways from the hall to the exit, at least (the service wing's depth)
	StairStuds = 30, -- path length of one flight, when measuring loops
	-- Loops in studs, not just rooms: a chase loop counts if it is this long,
	-- and at least one (the loop between the floors, in practice) must be
	-- LongLoopStuds. Four 40-stud rooms made 160; four mansion rooms round the
	-- hall's corner make 100-140. Retune after a playtest (M3/M5).
	MinLoopStuds = 100,
	LongLoopStuds = 200,
	ExtraEdges = { 3, 5 },
	MaxExtraEdges = 8,
	-- The adventure decides the doors (Logic/Wings; docs/plans/level-design.md
	-- section 5.3). Regions comes from the squad (Logic/HouseSize), else from
	-- the room count; Stage is Config.Progression (set below), whose
	-- region-0 and dead-end rules every kept partition already passes.
	Wings = {
		MinWing = 3, -- rooms in a wing, at least
		MaxWing = 7,
		R0Share = { 0.25, 0.4 }, -- of the house open from the start
		Tries = 4, -- partitions tried for each number of wings, best first
		Cores = 3, -- loops region 0 may be built round, tried (Wings.coreLoops)
		CoreMax = 7, -- rooms in region 0's loop, at most
		NearKey = 0.7, -- a wing's key lies in the region opened just before it, this often
		ParallelFrom = 3, -- squads this big get two wings opening side by side
		BacktrackChance = 0.4, -- a wing is entered from an older region, its near door bolted
		ShortcutStuds = 60, -- a doorway home must save this much walking to be added
		KeyStuds = { 40, 300 }, -- walking studs from a key to its door: never closer, rarely further
	},
	-- The adventure picks the rooms (Logic/Programme; docs/plans/level-design.md
	-- section 5.4): a deck of lock and keeper kinds drawn first, the rooms they
	-- need placed first, rooms with a landmark or a lure ahead of plain ones.
	-- Enabled is Config.Progression.Enabled (set below).
	Programme = {
		Kinds = { "padlock", "power", "crank", "safe", "musicbox", "dumbwaiter", "boards", "chain" }, -- in draw order
		-- (The dumbwaiter was 0.5 while the planner could pick a wall that furniture
		-- then filled; it now only picks spots clear of the fitted furniture.
		-- Boards and chains: docs/plans/level-design.md section 11, L3.3.)
		Weights = {
			padlock = 3,
			power = 2,
			crank = 1.5,
			safe = 2,
			musicbox = 2,
			dumbwaiter = 1.5,
			boards = 3,
			chain = 2,
		},
		DeckSize = { 2, 2, 3, 3 }, -- kinds a run wants, by squad size
		DrawBonus = 2, -- a room with a landmark or a lure comes up this much more
		Always = { "laundry" }, -- rooms every house wants (the laundry chute's bottom)
		DeckBoost = 10, -- the lock planner's weight for a kind in the deck
	},
	-- The cellar and the attic (docs/plans/level-design.md sections 10.2 and
	-- 10.3): which a house has and how many rooms each, counted in its room
	-- band. A squad's own goes over this (BySquad[n].mansion.Storeys).
	Storeys = {
		Cellar = {
			Chance = 1,
			Rooms = { 2, 3 },
			StairPull = 0.1, -- the cellar stair's placement score per stud from the back stairs (a longer loop)
			FirstApart = 40,
			FirstPull = 0.3,
			Beside = 0,
		},
		Attic = {
			Chance = 1,
			Rooms = { 2, 3 },
			StairPull = 0.1, -- the attic stair's placement score per stud from the back stairs
			-- Placed before the attic's rooms: this far from the back stairs
			-- (studs, middle to middle), losing FirstPull a stud off it.
			FirstApart = 40,
			FirstPull = 0.3,
			Beside = 6, -- placed off the upper hall the back stairs open into
		},
		OnlyOne = false, -- one of the two at most, by their chances
		-- They hold what the run needs (owner, 2026-10-05: "tie into the
		-- gameplay loop"): the lock planner's weight for keeping a key there,
		-- and for an heirloom's region being one of them.
		Keep = 3,
		Heirloom = 4,
		Tries = 8, -- packings of its rooms tried until they join its stairs into one piece
	},
	-- The laundry chute (docs/plans/level-design.md section 10.5): a hatch in
	-- an upstairs room over the laundry. Its spot is found like the
	-- dumbwaiter's (Logic/Dumbwaiter.spots), with its own size.
	Chute = {
		Uppers = { bath = 1, private = 2 }, -- rooms a hatch may be in, the first first
		Width = 2.6, -- along the wall
		Depth = 2.8, -- out from it (the basket below reaches this far)
		Inset = 0.1,
		CrankSide = 0,
		EndClear = 1.5,
		DoorClear = 5,
		Step = 2,
		FurnitureClear = 0.25,
		Wall = Config.Level.WallThickness,
		FloorMargin = 4, -- a trapdoor (no wall to share) keeps this far inside both rooms
		HatchHeight = 3.2, -- the hatch's middle above its floor
		HatchSize = 2.2,
		MouthHeight = 7.4, -- the chute's mouth below
		MouthDepth = 1.2,
		Basket = { 2.6, 1.6, 2 }, -- the basket below (width, height, depth)
		Hold = 0.6,
		Reach = 6,
		SlideSeconds = 0.6,
		LandNoise = 24, -- landing in the basket, heard this far
		DropNoise = 12, -- something dropped down it
	},
	-- House types (docs/plans/level-design.md section 10.6): the plan's
	-- outline, so the runs don't share one shape. A type changes the site the
	-- rooms are packed into: `site` (rectangles the house stays inside, from
	-- the hall at the front middle; mirrored east-west by chance),
	-- `courtyard` (a rectangle kept open on every floor: the house wraps
	-- round it), `serviceSide` (the side the service wing takes: along the
	-- L's arm). The hall stays at the front in the middle in every type.
	Types = {
		{ name = "centre", weight = 2 },
		{ name = "courtyard", weight = 1.5, courtyard = { x = -20, z = -100, w = 40, d = 50 } },
		{
			name = "L",
			weight = 1.5,
			site = { { x = -90, z = -70, w = 200, d = 70 }, { x = 20, z = -150, w = 90, d = 150 } },
			serviceSide = "E",
			mirror = true,
		},
		{ name = "wide", weight = 1, site = { { x = -130, z = -80, w = 260, d = 80 } } },
		{ name = "deep", weight = 1, site = { { x = -60, z = -160, w = 120, d = 160 } } },
	},
	-- Archways (docs/plans/level-design.md section 10.7): pairs of rooms that
	-- open into each other through a wide arch instead of a door, inside one
	-- wing. Width matches the furniture's doorway lanes (half-width 4).
	Arches = {
		Width = 8,
		Chance = 0.85,
		Most = 2,
		Pairs = {
			["living_room+den"] = true,
			["living_room+music_room"] = true,
			["living_room+sunroom"] = true,
			["living_room+dining_room"] = true,
			["den+study"] = true,
			["music_room+sunroom"] = true,
			["kitchen+pantry"] = true,
			["kids_bedroom+playroom"] = true,
			["master_bedroom+nursery"] = true,
		},
	},
	-- Servants' passages (docs/plans/level-design.md section 10.4): a narrow
	-- way behind the walls of a wing, between two of its rooms by hidden
	-- doors, where it saves this much walking.
	Passages = {
		Chance = 0.8, -- a house has one, if somewhere fits
		Width = 10,
		Lengths = { 30, 40, 50, 60 },
		MinSaves = 40,
		Jitter = 20,
		-- Rooms a hidden door may open into (not a bathroom, the hall, a stair).
		Zones = { public = true, dining = true, kitchen = true, service = true, private = true },
		SearchReach = 4.5, -- a hidden door's "Search" shows only this close (and in sight)
	},
	LoopLength = { 4, 8 }, -- (doc)
	MinLoops = 2, -- (doc)
	MaxDeadEndChain = 2, -- (doc)
	LanternRooms = { 1, 2 }, -- (doc)
	MaxAttempts = 10, -- (doc)
	DoorChance = 0.65,
	UpperShare = 0.5, -- share of the general rooms that go upstairs
	SiteHalfWidth = 100, -- wings stay within this many studs east and west of the hall's centre
	SiteDepth = 130, -- and this far behind the front line
	-- Candidate scoring when packing rooms (Logic/MansionGen).
	-- Wall sconces in the double-height rooms, whose one ceiling light can't
	-- reach the gallery or a stairwell's landings.
	Sconce = { range = 18, brightness = 1.1, height = 6.2 },
	-- Joists under a cellar's ceiling (templates with `joists`).
	Joists = { every = 4, width = 0.6, depth = 0.7 },
	-- The attic's roof (templates with `rafters`): it slopes from `knee` studs
	-- up on the long walls to the ceiling at the ridge.
	Rafters = { knee = 7, every = 4, width = 0.5, depth = 0.6 },
	Placement = {
		Top = 6, -- weighted pick among this many best candidates
		Contact = 1, -- per extra neighbour a door could join
		Loop = 5, -- per neighbour a door would close a 4-8 room loop with
		Fill = 2, -- joined to a corridor that has nothing off it yet
		Near = 3, -- per neighbour the template wants to be near
		Corridor = 1.5, -- joined to a corridor or the hall rather than through another room
		Chain = 2, -- per room the parent already is from a corridor (dead-end chains)
		Bridge = 6, -- upstairs: touches both the gallery's side and the back stairs' side (more in the cellar and attic)
		Toward = 0.15, -- cellar and attic: per stud from the other stair's foot, until they join
		Under = 3, -- a cellar room under the kitchen side (its stair comes up there)
		Chute = 4, -- an upstairs bathroom or room over the laundry (the laundry chute)
		Spread = 0.03, -- per stud from the house's middle (keeps it compact)
		Jitter = 1,
	},
}

-- Walking the house (docs/plans/mansion-generation.md, M3): the graph that
-- picks the way (Logic/NavGraph), the walker that follows it on the navmesh
-- (Stalker/Walker) and the sweeps that keep every move out of the walls
-- (Stalker/Clearance). The Guest and the bot (F2 `botrun`) share all of it.
Config.Nav = {
	Approach = 3.5, -- studs into a room in front of a doorway
	Clearance = 1.2, -- half the Guest's width plus a margin: routes keep this far from furniture
	DoorCost = 12, -- studs a closed door is worth (opening it takes 1.5-3 s)
	AttachRise = 5, -- a point (a floor spot or a body's root) joins graph nodes no further above or below than this
	SeenCost = 25, -- studs a doorway or stair someone is looking at is worth when he's sneaking
}

-- Room lighting (docs/ART.md, "Lighting mood by room family"). Every room has
-- one motivated key light that casts shadows (doc section 8), with a long reach
-- so it throws a pool of light that fades into real darkness. Values tuned in
-- Studio against the baseline screenshots and the owner's playtest notes.
Config.Lighting = {
	Lamp = { 232, 194, 126 }, -- sickly tungsten, yellower than a cosy orange
	Moonlight = { 120, 150, 220 },
	Fluorescent = { 215, 235, 225 }, -- slightly green on purpose
	Screen = { 140, 170, 255 }, -- CRT glow
	HuntRed = { 184, 50, 42 }, -- (doc) reserved: the house's lamps during a hunt
	HuntEase = 1.2, -- how fast lamps turn red and back (higher is faster)
	LampRange = 44,
	LampBrightness = 2.4,
	WindowRange = 40,
	WindowBrightness = 2.25,
	ScreenRange = 40,
	ScreenBrightness = 3.1,
	SurfaceAngle = 120,
	CeilingRangeScale = 1.5, -- on top of each template's light range
	CeilingMaxRange = 40,
	CeilingBrightnessScale = 1.3,
	-- Ceiling fixtures throw their light downward from a SpotLight instead of a
	-- PointLight (owner, 2026-10-04: a hard square patch on the ceiling that
	-- "doesn't match the rest of the lighting"). A point light sat 0.02 studs
	-- under the pendant's shade, inside the shadow map's near plane, so the
	-- ceiling was lit through the shade in a crisp quadrilateral. A downward
	-- cone never reaches the ceiling at all, which keeps it dark like every
	-- other ceiling. Set CeilingSpot to false to get the old point lights back.
	CeilingSpot = true,
	CeilingSpotAngle = 175, -- degrees; 180 is a full hemisphere, a hair less keeps clear of the limit
	-- A room lit only by a window or TV gets a soft bounce light in front of
	-- it, standing in for light off the walls. It casts shadows so it can't
	-- leak through into the next room.
	BounceRange = 34,
	BounceBrightness = 0.5,
	BounceOffset = 3, -- studs into the room from the window or screen
	-- Ceiling-light colour per room family.
	Families = {
		living = { ceiling = "Lamp" },
		corridor = { ceiling = "Lamp" },
		bedroom = { ceiling = "Lamp" },
		utility = { ceiling = "Fluorescent" },
		windows = { ceiling = "Lamp" },
		attic = { ceiling = "Lamp" },
	},
}

-- The exit door's house side (owner, 2026-10-04: the EXIT letters were drawn
-- across the whole slab, over the knob and the panels). Everything is a
-- fraction of the slab, measured as the door looks from inside the house, so
-- World/LevelBuilder and tests/specs/Exit.spec read the same numbers.
Config.Exit = {
	-- The sign: a band across the top of the door, well clear of the details.
	Sign = { x = 0.11, y = 0.08, w = 0.78, h = 0.2, ppu = 40 },
	-- Two raised lower panels (size as a fraction of the slab; centre as a
	-- fraction from the slab's middle, x either side, y negative is down).
	PanelSize = { 0.36, 0.3 },
	PanelOffset = { 0.22, -0.2 },
	-- The knob plate (studs) and where it sits, as a fraction from the middle.
	KnobPlate = { 0.4, 1.1 },
	KnobOffset = { 0.36, -0.04 },
	KickPlateHeight = 0.8, -- studs, resting 0.6 above the bottom edge
}

-- The potted plant's leaves (owner, 2026-10-04: the old one was a pot with a few
-- huge balls of speckled foliage that clipped furniture and walls). Leaves are
-- thin blades fanned round a stem; Logic/PlantLeaves lays them out and keeps every
-- corner within Props.Kinds.Plant.reach of the plant's middle.
Config.Plant = {
	Count = { 8, 10 },
	Length = { 1.2, 1.8 }, -- studs
	Width = { 0.36, 0.52 },
	Tilt = { 8, 28 }, -- degrees out from straight up
	BaseRadius = { 0.08, 0.22 }, -- where a leaf leaves the soil, from the middle
	Margin = 0.05, -- kept this far inside the reach
}

-- What you see through the windows (owner, 2026-10-04: the painted night was
-- "cartoony", with the same goofy moon in every window). One moon a run, in a
-- fixed compass direction: a window shows it only if it looks that way, and
-- where it sits in the pane follows the angle. The sky is near-black with a
-- soft dim glow, never a hard disc. Most panes are partly covered by a real
-- 3D curtain, blind or boards (World/PropFactory), always leaving a clear
-- part of the glass so The Guest's reflection and his face at the glass still
-- read. Logic/WindowView decides, from the seed; Logic/WindowView.spec tests it.
Config.Window = {
	MoonElevation = { 20, 46 }, -- degrees above the horizon, one per run
	MoonHalfView = 70, -- degrees either side of straight out a window still shows the moon
	-- Chances of each covering for a window (they're normalised).
	Covers = { bare = 0.28, sheer = 0.32, blinds = 0.25, boards = 0.15 },
	-- Moonlight spilling in through a window that looks at the moon (a faint,
	-- shadowless patch on the floor); windows with their own key light don't get it.
	SpillRange = 16,
	SpillBrightness = 0.3,
	SpillAngle = 110,
}

-- Trim and doors (docs/ART.md, step 3). Baseboards and crown moulding catch
-- the light and make a box read as a room; door and window casings are
-- painted lighter than any wall, so exits read even in a dark room (rule 4).
Config.Trim = {
	-- A gate into a wing has glass in its upper half (docs/plans/
	-- level-design.md section 10.7): you see into the wing before you can get
	-- in. Mansion doors only.
	GlassDoor = {
		Kinds = { key = true, double = true, padlock = true, power = true },
		Sill = 4.4, -- solid this high (it still stops anyone walking through)
		Stile = 0.7,
		Rail = 0.5,
		Transparency = 0.55,
	},
	Wood = { 74, 51, 36 }, -- dark walnut (palette): baseboards, crown, door slabs
	Paint = { 196, 188, 168 }, -- casings and window frames, lighter than every wall
	Knob = { 150, 128, 84 }, -- tarnished brass, kept off the reserved brass (palette)
	BaseboardHeight = 0.7,
	BaseboardDepth = 0.14,
	CrownHeight = 0.45,
	CrownDepth = 0.3,
	CasingWidth = 0.55,
	CasingDepth = 0.18, -- a little proud of the baseboard, which butts into it
	LiningDepth = 0.08, -- lines the sides and top of a doorway's opening
	-- Wainscot in formal rooms: panelling on the lower third under a dado rail,
	-- kept below window sills (3.3).
	Wainscot = { material = "Panelling", color = { 92, 64, 46 } },
	WainscotHeight = 3,
	WainscotDepth = 0.06,
	DadoHeight = 0.2,
	DadoDepth = 0.12,
	-- Some real doors rest slightly open with darkness behind them (the P.T.
	-- bathroom door). An ajar door still blocks the way until it's opened.
	AjarChance = 0.3,
	AjarAngle = 16, -- degrees
}

-- Decorative copies of tell props (docs/ART.md, Hero props). Clue clocks and
-- clue radios are built by the same builder as these, so a clock or a radio
-- on its own is never a giveaway.
Config.Props = {
	DecorClocks = 3, -- wall clocks per house, in wall slots no tell used
	DecorRadios = 2, -- radios per house, in free floor slots of living and bedroom rooms
}

-- Small things on furniture tops (World/Dressing): photos and a telephone.
Config.Dressing = {
	Telephones = 1, -- per house, in a hall, corridor or the foyer
	TelephoneChance = 0.6, -- per suitable surface, until one is placed
	MaxPhotos = 6,
	PhotoChance = 0.45, -- per suitable surface
	PhotoKinds = { Dresser = true, Chest = true, Piano = true, Desk = true },
	-- Everyday clutter on tops (mugs, plates, books, vases, magazines): a
	-- handful of believable objects, never evidence.
	MaxClutter = 24, -- per house
	ClutterPerSurface = 2,
	ClutterChance = 0.7, -- per surface
	SpotWidth = 1.4, -- studs of tabletop per item
	Jitter = 18, -- degrees each item is turned off square
	-- Photos age with Drift (docs/ART.md, the run's arc): normal, then the
	-- faces blur from Breaking, then they're gone from Collapsing.
	PhotoBlurAt = 60,
	PhotoFacelessAt = 80,
}

-- The grime layer (World/Grime): shared decals placed from the seed.
Config.Grime = {
	-- Blood: from Breaking, dark stains appear on some walls, shared by every
	-- player at the same Drift (ART.md, the run's arc). The server places them
	-- hidden; the client reveals each at its own Drift.
	BloodChance = 0.5, -- per room
	BloodAt = { 60, 88 }, -- Drift at which a stain shows
	BloodSize = { 1.4, 2.4 },
	BloodFade = 0.3, -- decal transparency once fully shown
	CeilingStainChance = 0.4, -- per room
	CeilingStainSize = { 4, 9 }, -- studs across
	RustUnderWindowChance = 0.5,
	UtilityRustChance = 0.6,
	Scuffs = { 0, 2 }, -- per room
	PictureGhostChance = 0.25,
	Fade = { 0.05, 0.35 }, -- decal transparency, for variety
	-- Fairness (docs/ART.md rules 3 and 6): wall grime keeps this far from the
	-- seam in the middle of a shared wall, and from wall slots and decor.
	SeamClearance = 8,
	SlotClearance = 4,
	WallOffset = 0.075, -- in front of the wall skin and wainscot, behind the dado rail
	CeilingOffset = 0.02,
}

-- Ceilings: popcorn plaster, a little darker than the walls and leaning
-- towards one shared off-white, so a rose room gets no pink ceiling.
Config.Ceiling = {
	material = "PopcornCeiling",
	color = { 134, 128, 112 },
	wallTint = 0.25, -- how much of the room's wall colour shows in its ceiling
}

-- Focus markers replace the crosshair: whatever you're close to and looking at
-- gets a small marker attached to it, with its name and actions (docs/ART.md,
-- "Interface").
Config.Focus = {
	FadeSeconds = 0.25,
	GazeFull = 0.97, -- dot product with the view: full strength when looked at this directly
	GazeNone = 0.8, -- ...and fading out by here
	PromptMinAlpha = 0.35, -- an action in reach stays faintly visible off-centre
	MaxDistance = 60, -- markers are never drawn beyond this
}

-- Post-processing and atmosphere on the client (docs/ART.md, "Softening the
-- image"). Subtle on purpose: heavy bloom and blur read as dreamy, not dreary.
Config.PostFX = {
	BloomThreshold = 1.15, -- lamps, windows and screens halo; lit pale surfaces (faces) do not
	BloomThresholdHub = 2.2, -- the hub is brightly lit, so only its brightest lights halo
	BloomIntensity = 0.7,
	BloomSize = 30,
	-- Depth of field: sharp out to about 40 studs, so the Guest still reads at
	-- 30 (doc section 8), softening beyond that like a real lens.
	FocusDistance = 16,
	InFocusRadius = 24,
	FarBlur = 0.3,
	GrainTile = 64, -- pixels per tile of the 32 px noise, so each grain is about 2 px
	GrainShade = 70, -- darkens the noise so grain adds texture without lifting blacks
	GrainCalm = 0.8, -- grain transparency at Drift 0
	GrainCollapse = 0.7, -- and at Drift 100
	-- Dust drifting in the light: soft additive motes lit by the scene, so they
	-- only show inside lamp and window light. Each room's dust gathers around
	-- its key light and drifts together on a slow, wandering air current.
	DustLifetime = { 8, 14 },
	DustSize = 0.08,
	DustSizeVariance = 0.04, -- each mote is DustSize plus or minus this
	DustHeight = 9.5, -- studs above the floor the dust can fill
	-- Nested layers around the light, from the core outwards: half-width in
	-- studs, motes per 1,000 cubic studs, and how bright that layer's motes
	-- get at their peak (0-1). They add up to dense, bright dust at the lamp
	-- thinning to faint at the edge, so the dust fades out with the light
	-- instead of stopping at the edge of a box (owner's playtest, 2026-10-02).
	-- Density, not a fixed count, so a lamp in a corner, whose layers the walls
	-- cut short, doesn't pack its motes tighter.
	DustLayers = {
		{ half = 4, density = 22, glow = 0.8 },
		{ half = 8, density = 15, glow = 0.55 },
		{ half = 13, density = 10, glow = 0.32 },
		{ half = 19, density = 7, glow = 0.14 },
	},
	DustSurfaceReach = 5, -- a window or TV's dust gathers this far in front of it
	DustCurrent = 0.03, -- strength of the drifting air current
	-- The Guest's presence: lights near its body sag, easing in and out.
	GuestDimRadius = 30, -- starts dimming lights this close
	GuestDimFull = 12, -- fully dimmed this close
	GuestDimTo = 0.55, -- fraction of normal brightness when fully dimmed
	GuestDimEase = 1.5, -- higher reacts faster
	-- Flashlight drag: the beam's aim trails the camera slightly on quick turns.
	-- Higher follows faster. The camera itself never moves (doc section 4).
	FlashlightFollow = 12,
}

-- The run's arc (Logic/Acts, Logic/DirectorModel; docs/plans/
-- gameplay-rework.md, R2c "pacing"): progress, not Drift, says which act the
-- run is in, and progress wakes hunts.
Config.Pacing = {
	Act2At = 0.15, -- of everything there is to do (Acts.progress)
	Act3At = 0.6,
	-- Dread's floor by act (Logic/Dread; the owner's audit of 2026-10-06): the
	-- deeper the squad goes, the worse the house gets, whatever Drift says.
	-- Act 2 (the first door opened) brings tier 2 and the first atmosphere;
	-- act 3 (most of the way) brings tier 3, his cracked face and every light
	-- flickering, so a clean run meets the lunge in its second half.
	ActDread = { 0, 40, 60, 75 },
	DreadRamp = 90, -- seconds a new act's floor takes to ease in
	ArmDelay = { 45, 150 }, -- seconds from the progress that wakes a hunt to the hunt
	MinHuntGap = 180, -- a woken hunt waits about this long after the last one ended...
	HuntGapJitter = 0.4, -- ...give or take this share, drawn afresh after every hunt, so they never come on a clock
	FalseAlarmChance = 0.3, -- a woken hunt that is only its telegraph: the hum rises, nothing comes...
	FalseAlarmFollow = { 30, 80 }, -- ...and the real one follows this much later
	ReturnChance = 0.25, -- after a hunt, he sometimes comes straight back...
	ReturnDelay = { 40, 75 }, -- ...this soon, gap or no gap
	LanternRelease = { 5, 15 }, -- leaving a Lantern room, a woken hunt waits this much more
	HuntDreadFull = 80, -- hunts last their longest from this Dread (Config.Stalker.HuntDuration)
	HuntJitter = 8, -- seconds either way
	ProwlBonus = 25, -- how much he favours the rooms a woken hunt is coming to (Stalk:_farPoint)
}

-- The bot (Services/BotService, F2 `botrun`): the loop played on the server
-- and measured.
Config.Bot = {
	WalkSpeed = 8, -- studs a second (a player's walk)
	SprintSpeed = 19, -- `botrun fast`
	LegTimeout = 25, -- seconds a leg may take at least (longer legs get longer)
	GiveWay = 9, -- studs: between hunts it stops and lets him move off rather than walk into him
}

-- Alone (docs/progress/2026-10-07-loop/REPORT.md, WP2): what the house
-- leaves a lone player instead of a partner.
Config.Solo = {
	SaltsChance = 0.6, -- one keepsake box in the house keeps smelling salts
}

-- Stuck-assist (Logic/Assist; Services/FinaleService): help rises with the
-- danger once the squad has made no progress for a while (the owner's audit
-- of 2026-10-06; the finish line: never wonder what to do for two minutes).
Config.Assist = {
	HintAfter = 150, -- seconds without progress before the objective line says what the plan wants next
	LampAfter = 240, -- ... and the lights there stutter and the map rings the room
	LampEvery = 30, -- how often the lights there stutter
}

-- The house's own scares (Services/HouseEventService; the owner's audit of
-- 2026-10-06): cards the Director draws by act and Dread, and the change a
-- squad finds coming back to an old wing.
Config.HouseEvents = {
	RadioRange = 45, -- a radio this near turns itself on, in a room nobody is in
	RadioSeconds = 20, -- and plays this long
	PhoneRange = 60, -- the telephone rings when one is this near
	PhoneSeconds = 14, -- for this long, unanswered
	PhoneLure = 30, -- how far he hears it (and hears you pick up)
	LightsRooms = 3, -- the rooms ahead that go dark, one by one...
	LightsStep = 1.2, -- ...this far apart
	LightsDark = 40, -- and stay dark this long
	OverheadRange = 35, -- his steps through the floor carry this far (planar)
	AjarDegrees = 22, -- a shut door swings this far ajar
	ChimeGap = 1.1, -- seconds between the clock's thirteen strikes
	ReturnAfter = 150, -- a wing left this long has changed when you come back
	ReturnCooldown = 180, -- not again for this long
	ReturnDark = 60, -- the room that went dark stays so this long
}

-- The run in numbers (Logic/RunStats; Services/RunLogService): the F2
-- overlay and the Dossier's "THE NIGHT IN NUMBERS".
Config.Stats = {
	SilentSeconds = 60, -- a stretch this long with nothing happening counts as silent minutes
	EarlySeconds = 600, -- the finish line counts scares in the first ten minutes
}

-- The Guest wants his dinner (Logic/Scent, Logic/Dinner; docs/plans/
-- gameplay-rework.md, R2c): the heirlooms are his.
Config.Scent = {
	Interval = 5, -- seconds between the times he senses which room a carried heirloom is in
	Confidence = 0.55, -- how sure that is (a sighting is 1, a noise 0.6)
	Linger = 8, -- seconds after a drop he still knows where it is
	TargetBonus = 0.8, -- added to a carrier's score as his target (Stalk:_pickTarget)
	HauntBonus = 20, -- how much he favours rooms holding heirlooms nobody has found yet
	HauntLinger = { 6, 10 }, -- seconds he lingers there
	TableWaitMax = 120, -- he waits at the table at most this long
	TableWaitCooldown = 60, -- and not again for this long after
	TableMargin = 2, -- every place is at least ContactRadius + this from his seat (Logic/Dinner)
	TidySeconds = 150, -- an heirloom left lying anywhere but its place this long, he puts back
	TidyClear = 20, -- only with nobody this close to it
	TidyGiveUp = 25, -- seconds he tries to reach it unseen before letting it be for a while
	TidyCooldown = 60,
	ErrandReach = 4, -- an errand's spot counts as reached within this many studs
}

-- Each Witness's own unsettling moments (Logic/Atmosphere): the Drift each
-- kind waits for.
Config.Atmosphere = {
	EyesMinDrift = 15, -- a portrait's eyes start following you
	WritingMinDrift = 30, -- words show in your torch beam
	SoundMinDrift = 40, -- (doc) mislocated sounds
	GhostMinDrift = 50, -- a friend glimpsed where they were a moment ago
}

Config.Stalker = {
	VisionConeDegrees = 100, -- (doc)
	VisionRangeLit = 40, -- (doc)
	VisionRangeDark = 15, -- (doc)
	WatchConeDegrees = 80, -- how wide a player's "looking at it" cone is
	WatchRange = 90,
	WatchedAfterSeconds = 0.3, -- (doc)
	MemorySeconds = 30, -- (doc)
	BodyHz = 15,
	TacticianHz = 1.5,
	WalkSpeed = 8,
	StalkSpeed = 5,
	SprintSpeedRatio = 0.92, -- (doc) 90-95% of player sprint
	CatchRadius = 3.6,
	Tier1MinDistance = 25, -- (doc)
	Tier1VisibleMaxSeconds = 12,
	Tier1Cooldown = { 20, 40 },
	Tier2Step = { 8, 15 }, -- (doc)
	Tier2MinDistance = 8,
	Tier2ReactionDelay = 1.8,
	IntrusionCooldownPerPlayer = 120, -- (doc)
	IntrusionHoldSeconds = { 4, 6 },
	ProvokeFlashlightSeconds = 2,
	HuntDuration = { 45, 90 }, -- (doc)
	TelegraphSeconds = { 3, 5 }, -- (doc)
	HuntIntervalBreaking = 210,
	HuntIntervalCollapsing = 120, -- (doc) ~every 2 min at 80+
	RetreatTierSeconds = 90, -- (doc)
	NoHuntAfterReviveSeconds = 20, -- (doc)
	DoorOpenSeconds = { 1.5, 3 }, -- (doc)
	AjarDoorSeconds = { 0.4, 0.9 }, -- a door left ajar only needs a push
	BracedDoorSeconds = 5,
	InspectSeconds = 1.8,
	HearingMultiplier = 1,
	SearchLookSeconds = 2,
	MemoryHeardConfidence = 0.6,
	ProfileHalfLife = 120,
	FloorNoiseScale = 0.5, -- owner, 2026-10-04: through a floor a noise carries half as far
}

-- The Guest's look and body language (docs/ART.md "The Guest"; owner
-- decisions 2026-10-03). Behaviour numbers join this block as they land.
Config.Guest = {
	FormDrift = { 40, 60 }, -- the smile opens at Fraying, the porcelain cracks at Breaking
	-- The catch (Controllers/GuestController): "rush", his grin rushing in to
	-- fill the screen (as built 2026-10-03); "quiet", black and a breath, then
	-- his face resolving slowly out of the dark, then the sting (the audit of
	-- 2026-10-06 found the rush cartoonish). The owner's choice: F2 `guest
	-- scare quiet|rush` previews either.
	-- "auto" (the owner, 2026-10-07: "either, dynamically based on
	-- circumstances"): rush when you were looking at him or he ran you down
	-- in a chase; quiet when he took you from behind, in the dark, or out of
	-- a hiding place (StalkerService:_catchStyle). "rush"/"quiet" force one.
	Catch = "auto",
	CatchFaceSeconds = 1, -- you looked at him this recently: face to face
	NeckYawMax = 160, -- his head keeps turning to watch you; a person manages about 80
	SmileCloseRange = { 4, 18 }, -- the smile widens from 18 studs in to arm's length
	EyeShineRange = 45, -- your torch catches his eyes within this range
	EyeShineCone = 24, -- half-angle of the torch beam, degrees
	FootstepVolume = { Walk = 0.45, Run = 0.9, Creep = 0.16, BackAway = 0.28 },
	-- The look (Controllers/GuestController, the mask over the dark).
	StutterSeconds = { 0.07, 0.14 }, -- in your beam his joints jump on this often (stop-motion)
	LightSnapSeconds = 0.12, -- his head snaps to your light this fast when it lands
	ExhaleAfter = 2, -- held longer than this, he breathes out when let go
	UnfoldSeconds = 0.5, -- straightening up past a door frame
	EyeGlow = { 0.45, 0.6, 0.8 }, -- his eyes glow this much in the dark when he faces you, by form (1 in your torch)
	EyeGlowRange = 30,
	GapeRange = 7, -- from Fraying, closer than this his mouth hangs open
	CoatSwing = 0.6, -- his coat's skirt follows each thigh this much of the way (a flare, not trouser legs)
	-- Wrong between looks (GuestController._maskBetweenLooks): look away and
	-- back, and his mask may have slid round his head; it turns back as you watch.
	MaskTurnChance = { 0.3, 0.5, 0.75 }, -- per look back, by form
	MaskTurnAwaySeconds = 1.2, -- you looked away at least this long
	MaskTurnRange = 35,
	MaskTurnLookCone = 30, -- degrees off your view's centre that count as looking at him
	MaskTurnYaw = { 18, 38 }, -- slid round his head (degrees)
	MaskTurnRoll = { 12, 32 }, -- turned on itself
	MaskTurnPitch = 10,
	MaskTurnHold = 0.6, -- seconds it stays wrong before it starts back
	MaskTurnBackSeconds = 2.4,
	-- His breath behind you makes your torch stutter (a tell), at most this often.
	TorchStutterSeconds = 0.6,
	TorchStutterGap = { 6, 11 },

	-- Arrival: three knocks at the front door when the quiet start ends.
	ArrivalKnockLead = 3, -- seconds from the knock until he's inside
	-- Moving.
	WalkSpeed = 6, -- unhurried, when nobody can see him
	CreepSpeedTier2 = { 1.6, 3.2 }, -- from your side to right behind your back
	CreepSpeedTier3 = { 0.9, 1.8 }, -- "really slow" (owner)
	CreepSpeedWatched = 0.7, -- tier 3, while one Witness stares at him
	BackAwaySpeed = 3.5,
	BackAwayMaxSeconds = 10,
	ChaseLead = 0.7, -- seconds ahead of a fleeing player he can see that he runs for
	ZoomSpeed = 55, -- the yank out of sight
	SpottedFleeSeconds = 0.45, -- tier 1: how long you see him before he's gone
	Tier1Cooldown = { 14, 30 }, -- tier 1: quiet between appearances
	StareBackAwaySeconds = 4, -- tier 2: watched this long up close, he backs off
	StareBackAwayRange = 16,
	PeekHoldSeconds = { 6, 14 },
	-- Peeking round a door frame (Logic/PeekSpots).
	PeekLateral = 4.6,
	PeekWallClearance = 1.2,
	PeekHideLateral = 8.2,
	PeekMinDistance = { [1] = 25, [2] = 12, [3] = 8 }, -- (doc) never closer than 25 at tier 1
	-- Being seen.
	ViewConeDegrees = 110, -- a Witness's field of view, wide
	BackTurnedDegrees = 110,
	StealthStep = 2.5, -- studs per steering step
	StealthSamples = 8,
	RayBudgetPerTick = 48,
	-- Warnings before a back attack (owner: subtle tells).
	TellRadius = 12,
	BreathInterval = { 2.5, 4 },
	CreakInterval = { 3, 6 },
	CloseBehind = 5.5, -- tier 2: as close as he comes, breathing on your neck (outside ContactRadius: his own approach is never a contact lunge)
	-- The lunge (tier 3+). Fairness gates live in Logic/StalkRules.
	LungeRadius = 6,
	LungeWindup = 0.32,
	LungeSpeed = 70,
	LungeReach = 4,
	LungeCooldownPerPlayer = 150,
	LungeCooldownSquad = 60,
	LungeMinRunSeconds = 240,
	LungeTellLeadSeconds = 1.5, -- you've heard or seen him at least this long before
	WarningMemorySeconds = 6,
	NoLungeNearDownSeconds = 20,
	NoLungeNearDownRadius = 30,
	-- Close contact (Logic/StalkRules.contact): within this many studs of a Guest
	-- you can see, he lunges at once. 5 is also where he senses you regardless
	-- of facing (Perception:CanSee).
	ContactRadius = 5,
	-- ...and only when they came at him: their own speed towards him, studs a
	-- second (the bot found him lunging at anyone he stood next to in a
	-- corridor, 2026-10-06). He may creep up to you; you have to walk into him.
	ContactApproachSpeed = 3,
	ContactWindup = 0.15,
	ContactCooldownPerPlayer = 8,
	ContactAloneRadius = 30, -- nobody he knows of this close to the victim: he withdraws
	WithdrawSeconds = { 25, 40 }, -- gone from sight while rescuers come
	WithdrawSpeed = 14,
	-- Hunts start from wherever he is, out of sight and this far away.
	HuntStartMinDistance = 25,
	HuntStartMaxWait = 6,
	-- How strongly nearby lights sag, by tier (tier 0 he's far and faint).
	PresenceDim = { [0] = 0.35, [1] = 0.6, [2] = 0.85, [3] = 1, [4] = 1 },
	-- Windows and mirrors (Lib/GuestReflection).
	ReflectionBodyRange = 16, -- his reflection shows when he's this close behind you
	ReflectionGlassRange = 14, -- and the pane is this close to you
	WindowFaceMaxDrift = 60, -- the face at the glass is an early-run divergence
	WindowFaceRange = 30,
	-- Targets.
	TargetStickSeconds = 25,
	TargetLostSeconds = 20, -- drops a target he can't find if he knows where someone else is

	-- Honest tracking: what he knows comes from sight, sound and habit, never
	-- from reading positions (Logic/BeliefMap).
	SeenFreshSeconds = 0.5, -- a sighting this recent counts as "seeing them now"
	TrackMinConfidence = 0.2, -- below this a memory is too stale to walk to
	CheckedRadius = 3, -- reaching a last-known spot without seeing them: they've gone
	BeliefDiffuse = 0.08, -- per second, mass leaks to neighbouring rooms
	BeliefRelax = 0.03, -- per second, back towards the squad's habits
	BeliefHeardStrength = 0.6,
	BeliefHeardSpread = 1, -- doors a noise's uncertainty reaches
	BeliefClearStrength = 0.85, -- a room he's checked and found empty
	BeliefPriorRefresh = 5, -- seconds between habit updates
	SearchPause = { 2, 4 }, -- looking round a room he's reached
	-- Lures (docs/plans/gameplay-rework.md section 4.9): a noise nobody made
	-- draws him when he doesn't know where you are.
	LureFreshSeconds = 15, -- older than this, he doesn't bother
	LureLookSeconds = { 2.5, 4 }, -- how long he stands and looks round when he gets there
	LureWaryWindow = 120, -- lures he followed this recently count against the next
	LureWaryFactor = 0.6, -- each one makes the next this much less tempting
	BrainHz = 4,

	-- The Guest rework's numbers (docs/progress/2026-10-07-guest).
	ParkRadius = 8, -- standing this close to a still player counts as parked
	CheapNoticeSeconds = 3, -- a catch with no sign of him this long before is a cheap down
	StepsHeardRange = 24, -- walking studs: his steps count as a sign of him this close
	-- His moods (Logic/GuestMood) and temperament (Data/Temperaments).
	MoodSeconds = { 60, 180 }, -- how long a mood lasts before he takes on another
	LonelySeconds = 90, -- seeing nobody this long makes him curious or playful
	-- "After you" (StalkRules.makesWay): between hunts he never parks in your way.
	ParkSeconds = 6, -- standing within ParkRadius of a player this long, he makes way
	MakeWayRange = 10, -- a player walking his way this close: he makes way
	MakeWayMaxSpeed = 11, -- walking (8, winded 10); faster than this at him is rushing him (a contact)
	MakeWayStep = { 2, 3, 4 }, -- how far aside he tries to step
	MakeWayMinStep = 1.1, -- a step aside shorter than this isn't one (he holds out his hand where he is)
	MakeWaySeconds = 8, -- he holds his hand out this long at most
	ParkBudget = 12, -- seconds within ParkRadius of one player...
	ParkWindow = 60, -- ...in any minute; spent, he moves off
	-- His ways between hunts (Data/StalkMoves, the Guest rework).
	FingersRevealSeconds = 3, -- watched this long, his face follows his fingers out
	HallwayStandSeconds = 40, -- at the end of your corridor at most this long
	BehindDoorInset = 2.2, -- how far behind the door he stands
	BehindDoorSeconds = 30, -- he waits behind it this long at most
	BehindDoorRange = 26, -- for a door within this of the target
	BehindDoorLeave = 40, -- walking studs: they've gone elsewhere, he gives up
	BehindDoorKnockChance = 0.35, -- three slow knocks instead of silence
	BehindDoorTell = { 3, 5 }, -- seconds between creaks for whoever comes close
	BehindDoorTellRadius = 10,
	MimicMinAge = 60, -- he only speaks lines someone said this long ago
	HostActionRange = 60, -- walking studs: something of his house to do, not far off
	HostDoorAjar = 28, -- degrees he eases a door open (walkable from PassAngle 55)
	HostDoorRate = 35, -- degrees a second: slowly
	SlowWithdrawSpeed = 3, -- tier 1, seen: backing out of sight, still staring
	DuckSeconds = 0.35, -- tier 1, seen: the drop before he glides away
	-- Hunts in phases (Logic/HuntPhases).
	ChaseGrace = 0.6, -- out of his sight this long in a chase, and he's lost you
	LostSeconds = { 1.5, 3 }, -- standing where he lost you, listening
	LostWalkSeconds = 6, -- at most this long getting back to where he last saw you
	WidenAfter = 30, -- a hunt this long without seeing anyone: he widens his options
	ListenEvery = { 6, 10 }, -- prowling, he stops to listen this often...
	ListenSeconds = 1.2, -- ...for this long
	SpottedCues = 2, -- "[it sees you]" captioned this many times a session
	-- His keys (Logic/GuestKeys; the owner's choice, 2026-10-06: "keys and secret ways").
	Keys = true,
	KeyKinds = { key = true, pocket = true, double = true, padlock = true, hidden = true },
	KeyPassCost = 40, -- studs a locked door costs his routes (the keys, the lock): open ways first
	KeyPassSeconds = 2.5, -- his keys heard this long before the door opens...
	KeyPassSecondsHunt = 1.8, -- ...or this in a hunt (never under 1.5 s)
	KeyPassClear = 20, -- walking studs: nobody this near the door, either side
	KeyRefusedSeconds = 12, -- turned back from a door (someone near): not that way for a while
	KeyThroughSeconds = 6, -- the door shuts behind him after this at most
}

-- Tool locks (Logic/ToolLocks, docs/plans/level-design.md section 11, L3.3):
-- by squad size, one to four. One player's work is shorter (nobody to keep
-- watch); everyone's is loud.
Config.ToolLocks = {
	Boards = {
		Planks = { 3, 4, 4, 4 }, -- a hold each
		PiecePlanks = 2, -- nailed across a chest or the fridge (a step inside a wing)
		Seconds = { 1.2, 1.5, 1.5, 1.5 }, -- each hold
		Noise = 35, -- studs each plank carries
	},
	Chain = {
		Seconds = { 1.2, 1.5, 1.5, 1.5 },
		Noise = 30, -- the snap
	},
}

Config.Tools = {
	LanternLightSeconds = 2, -- with the Lantern tool in hand
	LanternLightSecondsNoTool = 5, -- bare-handed (was 8: a hidden wait nobody was told about)
	RadioRange = 80,
	-- Tools are found around the house (owner, 2026-10-04): one of each, and
	-- squads of ExtraCopiesFromSquad or more get these extra copies as well.
	ExtraCopiesFromSquad = 3,
	ExtraCopies = { Lantern = 1 },
	NearStart = "Lantern", -- this tool lies within NearStartMaxSteps rooms of where you start, so a solo player finds it
	NearStartMaxSteps = 2,
	PickupRange = 9, -- studs; the server re-checks it on every pickup
	PickupScale = 0.8, -- a tool lying on a table is this size next to the one in your hand
}

-- Doors swing by angle on the server (Logic/Articulation; docs/plans/
-- gameplay-rework.md section 4.5). 0 is shut.
Config.Doors = {
	OpenAngle = 100, -- fully open, against the wall
	-- A bathroom door bolted from inside (docs/plans/level-design.md section
	-- 4, L3.6): it holds him this many seconds more, then gives; it can't be
	-- bolted again for a while.
	PrivacyHold = 4,
	PrivacyRelock = 60,
	PassAngle = 55, -- open this far or more and you (and he) can walk through
	LatchAngle = 3, -- swung back within this of shut, it snaps shut and latches
	SwingRate = 285, -- degrees a second: a full swing in about a third of a second
	SlamRate = 520,
	-- Walkable from PassAngle, and still walkable until it falls this far below
	-- it, so a door bouncing about the line doesn't flicker the passage model.
	PassHysteresis = 10,
	-- Let go of a door and it swings on (Logic/Articulation, R2c): friction
	-- (degrees a second, each second), bounce off the open stop, how fast
	-- coming home is a slam (and loud: SlamNoise), how hard against the stop
	-- knocks, below what it simply stops, and how keenly a held one follows.
	Motion = { friction = 260, restitution = 0.25, slamSpeed = 160, knockSpeed = 120, stopSpeed = 8, stiffness = 18 },
	SlamNoise = 25,
}

-- The escape's locks and keys (docs/plans/gameplay-rework.md section 5;
-- Logic/LockPlanner). Not the Marks and Clearance of Logic/Progression.
Config.Progression = {
	-- Regions opened one after another, by the house's room count.
	Regions = { { upTo = 16, count = 1 }, { upTo = 20, count = 2 }, { upTo = 99, count = 3 } },
	R0Share = { 0.25, 0.38 }, -- of the house open from the start
	LoopBonus = 2.5, -- region 0 favours rooms that close a loop
	BacktrackChance = 0.35, -- a gate leads from an older region instead of the newest
	NearProducer = 0.7, -- a gate's key lies in the region just before it, this often
	-- A puzzle gate whose station could only stand where its door can't be
	-- seen yet is drawn this much less (lock first: docs/plans/level-design.md
	-- section 11).
	UnseenStation = 0.3,
	DoorWeight = 3, -- a gate is a doorway with a door this many times more often
	Flavours = { key = 3, padlock = 2, power = 2, crank = 1, double = 0, boards = 1, chain = 0.7 }, -- what kind of lock a gate gets (weights; Logic/LockPlanner.Gates; double by squad)
	MaxTools = 2, -- tool kinds a house's tool locks use (docs/plans/level-design.md 11, L3.3; by squad)
	-- Steps inside a wing (section 11, L3.4): a wing's prize behind boards or a
	-- chain inside it, the tool across the wing or in its sibling. How many a
	-- house is by squad (none for one or two: Mansion.BySquad `wingSteps`).
	WingStepRooms = 4, -- rooms a wing needs for a step (wings of 5+ are one in ten)
	StepSibling = 0.5, -- the tool lies in the sibling wing (opened just after), this often
	StepToolStuds = { 40, 400 }, -- walking studs from the step's door to the tool: at least, and best up to
	-- With no side room to spare, a chest (or the fridge) chained or nailed
	-- shut instead (weights; not a hiding spot: nobody loses one).
	StepPieces = { Chest = 3, Fridge = 2 },
	PieceWall = Config.Level.WallThickness, -- the walls rooms are furnished inside (Logic/RoomFit)
	-- The safe room (docs/plans/level-design.md section 11.12): an optional
	-- objective, a side room behind a steel door the fuse box powers, holding
	-- things that help (Data/SafeRoom, Logic/SafeRoom).
	SafeRoom = {
		-- Rooms that make a good one (weights; any other side room OtherWeight).
		Templates = {
			storeroom = 4,
			pantry = 3,
			box_room = 3,
			cold_store = 2,
			wine_cellar = 2,
			sewing_room = 2,
			bathroom = 1.5,
		},
		OtherWeight = 0.3,
		EarlyBonus = 2, -- in the part of the house open from the start or the first wing
		Count = { 2, 2, 3, 3 }, -- things inside, by squad
	},
	-- The gate kinds and producers switched on (R2c adds each as it's built).
	Enabled = {
		key = true,
		padlock = true,
		power = true,
		safe = true,
		musicbox = true,
		crank = true,
		dumbwaiter = true,
		double = true,
		boards = true,
		chain = true,
	},
	Keepers = { container = 4, safe = 2, musicbox = 3, dumbwaiter = 2 }, -- what keeps an heirloom (weights; LockPlanner.Keepers)
	MaxPuzzles = 4,
	FinaleItems = { 2, 3 }, -- heirlooms to lay at the table
	Stage0Loop = 100, -- studs: region 0 has a loop at least this long to run round
	Stage0Hides = 2, -- and at least this many hiding spots
	MaxDeadEnd = 3, -- rooms deep any dead end may be, at every stage (its bolts open)
	RegionDepth = 4, -- rooms a newly opened region may run past its gate
	Attempts = 24, -- tries for each number of regions before trying one fewer
}

-- The house as a designed level (docs/plans/level-design.md): what a good
-- house measures (Logic/HouseMetrics) and how many to choose from.
-- Targets: { band = { lo, hi }, bySquad = { [squad] = { lo, hi } }?, weight,
-- scale }: outside its band a metric costs `weight` per `scale` it misses
-- by. Bands were set from tools/housestats over the generator as it stood
-- (section 5.1) and the plan's aims; retune after the playtest.
Config.LevelDesign = {
	Candidates = 12, -- houses built for each run; the best is played (Logic/HouseSearch)
	ShortcutStuds = 60, -- a bolt that saves less than this on the way back isn't a shortcut
	Targets = {
		-- Of the house open from the start; a small house's hall, dining room and
		-- loop are more of it.
		r0Share = {
			band = { 0.25, 0.4 },
			bySquad = { { 0.25, 0.45 }, { 0.25, 0.45 } },
			weight = 3,
			scale = 0.05,
		},
		-- Regions after the first: as many as the squad's house wants (Hard's
		-- extra one is welcome).
		regions = { band = { 3, 9 }, bySquad = { { 2, 9 }, { 2, 9 } }, weight = 5 },
		minRegion = { band = { 3, 99 }, weight = 4 }, -- rooms in the smallest region after the first
		maxRegion = { band = { 0, 8 }, weight = 2 },
		shortcutShare = { band = { 0.99, 1 }, weight = 3, scale = 0.34 }, -- regions of 4+ rooms with a real shortcut home
		returns = { band = { 1, 3 }, weight = 2 }, -- trips back to an older region to open a door
		stageLoop = { band = { 100, math.huge }, weight = 3, scale = 20 }, -- the shortest "longest loop" of any stage
		deadEnd = { band = { 0, 3 }, weight = 3 },
		hideReach = { band = { 0, 70 }, weight = 1, scale = 10 }, -- studs from any open room to a hiding spot
		corridorHeirlooms = { band = { 0, 0 }, weight = 4 },
		corridorTokens = { band = { 0, 0 }, weight = 1 },
		heirloomRegions = { band = { 2, 9 }, weight = 2 },
		keyWalkMin = { band = { 40, math.huge }, weight = 1, scale = 20 }, -- a key is never right by its door
		-- Lock first (docs/plans/level-design.md section 11): the share of keys,
		-- codes and power found once their door could be seen, and the studs
		-- walked holding one whose door nobody has seen.
		lockFirst = { band = { 0.6, 1 }, bySquad = { { 0.7, 1 } }, weight = 3, scale = 0.1 },
		heldKeyBlind = { band = { 0, 0 }, weight = 1, scale = 100 },
		-- Side rooms behind the house key (section 11, L3.2), by squad: a
		-- house that can't fit them costs a little.
		pockets = { band = { 1, 2 }, bySquad = { { 0, 1 }, { 1, 1 }, { 1, 2 }, { 1, 2 } }, weight = 2 },
		-- Boarded and chained doors (section 11, L3.3): loud work for a lookout.
		toolLocks = { band = { 1, 3 }, bySquad = { { 1, 2 }, { 1, 2 }, { 1, 3 }, { 2, 4 } }, weight = 1 },
		-- Steps inside a wing (section 11, L3.4): none for one or two players.
		wingSteps = { band = { 0, 2 }, bySquad = { { 0, 0 }, { 0, 0 }, { 0, 1 }, { 1, 2 } }, weight = 1 },
		safeRooms = { band = { 1, 1 }, weight = 1 }, -- the optional safe room (section 11.12)
		gateRepeats = { band = { 0, 0 }, weight = 1 },
		puzzles = { band = { 1, 9 }, weight = 2 },
		purposeless = { band = { 0, 0 }, weight = 2 }, -- rooms with no reason to go in (Logic/RoomPurpose)
		kitGaps = { band = { 0, 0 }, weight = 1 }, -- regions short of a hiding spot, a lure, a landmark or Lantern
		-- The cellar and the attic each a wing of its own behind a lock (owner,
		-- 2026-10-05): one that isn't costs more than anything else.
		storeyWings = { band = { 0, 0 }, weight = 20 },
		storeyIdle = { band = { 0, 0 }, weight = 6 }, -- a cellar or attic wing holding nothing the run needs
		storeyOneWay = { band = { 0, 0 }, weight = 6 }, -- a cellar or attic with one way in (a dead end, a trap)
		-- The squad's own wings, not counting the cellar's and the attic's.
		mainWings = { band = { 3, 9 }, bySquad = { { 2, 9 }, { 2, 9 } }, weight = 10 },
		passages = { band = { 1, 9 }, weight = 2 }, -- a servants' passage to find
		chutes = { band = { 1, 1 }, weight = 1.5 }, -- the laundry chute
		finaleRun = { band = { 120, 400 }, weight = 1, scale = 40 }, -- the run from the table to the front door
		walk = {
			band = { 900, 2200 },
			bySquad = { { 700, 1600 }, { 800, 1900 }, { 900, 2200 }, { 1000, 2400 } },
			perStorey = 250, -- more for each wing in the cellar or the attic
			weight = 1,
			scale = 200,
		},
	},
}

Config.Mansion.Wings.Stage = Config.Progression
Config.Mansion.Programme.Enabled = Config.Progression.Enabled

-- The marks on keys and lock plates (Data/Marks, docs/plans/level-design.md
-- section 11): a brass disc above the lock on both faces of a door.
Config.Marks = {
	DiscSize = 0.8, -- studs across: readable at about 6 studs by torchlight
	DiscHeight = 1.7, -- above the plate's centre line (stays on a glazed door's solid part)
}

-- How keys and heirlooms are found (R2c "leads, not rummaging"; Logic/Leads,
-- Services/ItemService): a note that says where, a keepsake box, a locked
-- glass case, a key rack.
Config.Leads = {
	Kinds = { "note", "keepsake", "display", "hook", "drawer" }, -- the order they're drawn in
	Weights = {
		key = { note = 3, keepsake = 3, display = 1, hook = 2, drawer = 0 },
		heirloom = { note = 3, keepsake = 3, display = 3, drawer = 0 },
	},
	Repeat = 0.5, -- each time a kind is given in a run, its weight halves
	DecoyKeepsakes = { 1, 2 }, -- empty boxes, a run
	DecoyDisplays = { 0, 1 }, -- cases with nothing of his inside
	ReadRange = 9, -- studs from a note to read it
	WallDrop = 1.6, -- studs below a picture's wall spot a pinned note or key rack goes
	PickSeconds = 8, -- holding E at a case's lock
	PickRattle = 1.5, -- seconds between rattles while you pick it
	PickNoise = 10,
	SmashSpeed = 12, -- a thrown thing at least this fast breaks a case's glass
	SmashNoise = 35,
}

-- Fixtures you can work and the lights' wall switches (Services/
-- InteractService, Data/Interactables, Logic/SwitchSpots).
-- The servants' bell board (docs/plans/level-design.md section 4, L3.6;
-- Services/BellBoardService).
Config.BellBoard = {
	Bells = 6, -- rooms with a bell pull, at most (two rows of three)
	DownSeconds = 8, -- a rung bell's flag stays down this long
	CheckSeconds = 0.3, -- how often it looks where he is
	DoorClear = 7, -- studs from any door's hinge (an open door lies back against the wall)
}

-- Landmarks on corridor walls (section 4, L3.6; Services/LandmarkService).
Config.Landmarks = {
	Clear = 6.5, -- studs from any doorway of its corridor (and so a door's swing)
	Height = 4.8, -- its middle above the floor
}

-- The children's drawings (section 4, L3.6; Services/ItemService): where
-- they hid, pinned up in their rooms.
Config.Drawings = {
	Rooms = { "kids_bedroom", "playroom", "nursery" },
	Count = 2, -- a house, at most (one a child's room)
}

-- The baby monitor (section 4, L3.6; Services/MonitorService).
Config.Monitor = {
	Range = 18, -- studs from the transmitter it hears his steps
	Storey = 6, -- and no further up or down than this
	Hz = 2, -- updates a second
}

-- Wind-up toys (docs/plans/level-design.md section 4, L3.6; Services/ToyService).
Config.Toys = {
	WindSeconds = 0.8, -- the hold to wind one
	WalkSeconds = 15, -- how long it walks
	Speed = 1.3, -- studs a second
	NoiseEvery = 2, -- seconds between its ticking being heard
	Lure = 16, -- studs its ticking carries
}

Config.Interact = {
	Reach = 7, -- studs from a fixture or switch to work it
	SwitchHeight = 4, -- studs above the floor
	Switch = { DoorWidth = 6, WallFace = 0.55, Beside = 0.9, Margin = 0.8 }, -- Logic/SwitchSpots
	SwitchNoise = 4, -- a light switch's click carries this far
}

-- The breaker panel (R2c; Logic/Circuits, Logic/Puzzles/Breaker, server/
-- Puzzles/Breaker): the house's lights on a handful of breakers.
Config.Breaker = {
	Count = { 6, 8 }, -- breakers, the hall's own included
	Capacity = { 3, 4 }, -- more than this many on at once trips the main
	SmudgeChance = 0.35, -- the door's breaker has lost its label
	DecoyChance = 0.5, -- another breaker is wrongly labelled with the door's room
	TripNoise = 30, -- the main tripping: a loud clunk, and every light out
	FlipNoise = 6,
	-- The one two-human step a run has (the owner, 2026-10-06): the panel
	-- shows numbers only; the family's labels, mistakes and all, are on a
	-- brass plate beside the door it powers. One reads, one flips. Alone,
	-- a long hold on the panel ("Trace the wiring") shows the labels there
	-- for a while. (Logic/Objectives' fuse-box line assumes this is on.)
	PlateAtDoor = true,
	RevealHold = 6, -- seconds held to trace the wiring (solo only)
	RevealSeconds = 20, -- how long the labels then show on the panel
}

-- The music box and the piano (R2c; Logic/Puzzles/MusicBox, server/Puzzles/
-- MusicBox). Both play the one music-box note (Assets MusicBoxNote),
-- pitched: the piano lower, like a toy piano gone out of tune.
Config.MusicBox = {
	NoteGap = 0.55, -- seconds between the box's notes
	BoxPitch = 1,
	BoxVolume = 0.6,
	PianoPitch = 0.5,
	PianoVolume = 0.85,
	Lure = 22, -- the box playing carries this far (a lure, from whoever winds or carries it)
	CarriedEvery = 7, -- carried, it plays its tune again this often
	LureEvery = 3,
	DiscordNoise = 35, -- (doc) a wrong note on the piano
}

-- Crank doors (R2c; Services/CrankService): a roller shutter on a crank.
Config.Crank = {
	Max = 7.6, -- studs its bottom edge rises (rolled up into the box over the doorway)
	OpenAt = 6.5, -- passable from here up
	ShutAt = 5.5, -- and shut again below here
	CrankRate = 2, -- studs a second, held at the crank
	RatchetRate = 0.6, -- with the ratchet set, or heaved from the inside
	FallRate = 6, -- let go (without the ratchet), it drops this fast
	ClickEvery = 0.5, -- the ratchet's teeth
	ClickNoise = 25,
	SlamNoise = 20, -- it hits the floor: heard, from nobody
	Reach = 6, -- studs from the crank or the latch to work it
	Beside = 3.5, -- the crank this far past the door's edge (about 7 studs from the doorway's middle)
	Clearance = 1.6, -- anyone this close to the doorway's line stops it dropping
}

-- The dumbwaiter (R2c; Logic/Dumbwaiter, server/Puzzles/Dumbwaiter): a
-- crank downstairs, an open hatch upstairs, the car between.
Config.Dumbwaiter = {
	EndClear = 1.5, -- studs from the end of the shared wall
	DoorClear = 5, -- and from any doorway on either floor
	Step = 2, -- spots tried along the wall this far apart
	-- The casing on each floor: this wide along the wall, this deep, its back
	-- this far out from the wall's line. Downstairs the crank and its jam box
	-- stand beside it, this much further along on its right as you face it.
	Width = 1.9,
	Depth = 1.7,
	Inset = 0.55,
	CrankSide = 0.8,
	-- The planner keeps it this far off the furniture each room will have
	-- (Logic/RoomFit; Logic/Dumbwaiter.spots), so the build finds it clear.
	FurnitureClear = 0.25,
	Wall = Config.Level.WallThickness, -- the rooms' walls, which that furniture stands inside
	Rise = 0.18, -- of the way up a second, cranked (about 5.5 s to the top)
	Fall = 0.35, -- of the way down a second, let go
	CreakNoise = 12, -- cranking it, heard from you
	Reach = 6,
}
Config.Progression.Dumbwaiter = Config.Dumbwaiter -- the planner looks for stacked rooms with these

-- Barricades (gameplay rework 4.7; Logic/Barricade, Services/PushService).
Config.Barricade = {
	LaneDepth = 5, -- studs into the room from the wall that count as the doorway's lane
	Cover = 0.4, -- a heavy piece covering this share of the lane's width bars it (or standing on his walking points: NodeClear, below Config.Push)
	MinWeight = 1, -- in people: lighter pieces don't bar anything
	ShoveSeconds = { 3, 6 }, -- he bangs this long before he shoves it clear (light to heavy)
	HuntScale = 0.8, -- quicker when hunting
	ShoveMax = 8, -- (doc) never longer
	ShoveTime = 0.4, -- seconds the heave takes
	Reach = 3.5, -- he starts on it this close to the piece (or at the doorway)
	BangEvery = 1.1,
	BangNoise = 22,
	SqueezeSeconds = 1.5, -- (doc) a player squeezing past
	SqueezeReach = 8,
	SqueezeNoise = 14,
	-- What getting through costs, in studs of walking (WorldService:SeamCost).
	PlayerCost = 20,
	GuestCost = 60,
	GuestHuntCost = 25,
}

-- The map (Services/MapService, UI/Map): what counts as seen.
Config.Map = {
	ScanSeconds = 0.5, -- how often who's where and what they look at is checked
	SendHz = 2, -- MapState at most this often (and only when it changed)
	SeenRange = 30, -- studs: a doorway or something lying about looked at this close is on the map
	LockSeenRange = 10, -- and its lock (a padlock, a keyhole, a bolt) this close
	ViewCone = 100, -- degrees across of a player's view that counts
}

-- The escape's puzzles (docs/plans/gameplay-rework.md section 7;
-- Services/PuzzleService, Logic/Puzzles/*).
Config.Puzzles = {
	LockoutNoise = 20, -- the computer's lockout beep carries this far
	RattleNoise = 10, -- a padlock pulled on the wrong code
}

-- Drawers, cupboard doors and lids (docs/plans/gameplay-rework.md section
-- 4.5): built as pieces by World/PropFactory, moved by Services/
-- FurnitureService, dragged like doors.
Config.Furniture = {
	DoorOpen = 105, -- degrees a wardrobe, cabinet, locker or fridge door opens
	CounterOpen = 100, -- a kitchen cupboard door, so the next one along still opens
	LidOpen = 95, -- a chest's lid, just past upright
	DoorRate = 240, -- degrees a second
	LidRate = 160,
	DrawerRate = 6, -- studs a second
	DoorLatch = 3, -- degrees: pushed back within this of shut, it clicks shut
	DrawerLatch = 0.06, -- studs
	SolidBelow = 15, -- degrees: a door is solid only this near shut, so nobody walks through a shut one and an opening one never shoves anyone
	FillAt = 0.5, -- opened this fraction of the way, whatever is kept inside is put there (never sent to clients before)
	JunkChance = 0.55, -- a drawer or cupboard holds some odd small thing this often (keys and items come with R2a)
	NoiseSpeed = 0.8, -- moved faster than this fraction of its rate: heard (a drawer slammed shut)
	NoiseRadius = 12,
	ClearStep = 8, -- degrees per step (a tenth of a stud for drawers) when finding how far it opens before it would hit something
	-- Momentum (Logic/Articulation, R2c), as for doors: hinges (cupboard doors,
	-- lids) in degrees, slides (drawers) in studs.
	Motion = {
		hinge = { friction = 300, restitution = 0.2, slamSpeed = 150, knockSpeed = 110, stopSpeed = 8, stiffness = 20 },
		slide = { friction = 9, restitution = 0.1, slamSpeed = 4.5, knockSpeed = 4, stopSpeed = 0.2, stiffness = 20 },
	},
	SlamNoise = 14,
}

-- Pushing furniture (docs/plans/gameplay-rework.md section 4.6; Logic/Push,
-- Services/PushService). Weights are in Data/Physical, counted in people.
Config.Push = {
	CreepBelow = 0.6, -- with less strength than this share of its weight it only creeps
	CreepSpeed = 0.25, -- studs a second
	MaxSpeed = 2.2,
	-- Momentum (R2c): studs a second gathered each second per person of weight
	-- (a heavy piece is slow to get going), and lost each second when nobody
	-- pushes (it coasts a moment, then stops).
	Accel = 6,
	Friction = 7,
	StepHz = 30, -- the server moves a pushed piece this often
	Reach = 4.5, -- studs from your middle to it
	ReachHeld = 6, -- once you're pushing (or pulling), it stays yours this far out
	WalkMargin = 1.2, -- while you push, you walk this much faster than it moves (you lean into it)
	WalkMin = 1.4, -- and never slower than this
	Window = 0.3, -- seconds a push counts after it's sent
	SendHz = 10,
	ScrapeNoise = 7, -- noise radius per unit of weight while it moves
	ScrapeEvery = 0.8, -- seconds between scrape noises
	SoloStrength = 1.6, -- alone, you push for this many people's worth (the Companion is gone, 2026-10-06)
	KeepClear = 1.6, -- never pushed within this of a point The Guest walks by (a room's middle, a doorway)
	DoorClear = 0.5, -- or into a door's swing
}

-- A barricade may stand on his walking points in a doorway (they're what
-- pushed furniture otherwise keeps clear of): Logic/Barricade.
Config.Barricade.NodeClear = Config.Push.KeepClear

-- Your hands (docs/plans/gameplay-rework.md section 4): slot 4, and the torch
-- clipped to your shirt while you hold anything but it.
Config.Hands = {
	-- Weak and short: enough to see what you're doing, not to search a room
	-- (slot 1 gives the full beam). Points where your body faces, not your eyes.
	ClipLight = { Range = 16, Angle = 70, Brightness = 0.8, Height = 1.2 },
	-- Dragging doors with the mouse (section 4.5): hold the button on a door
	-- and your hand moves with the mouse; the door turns to follow it.
	Reach = 8, -- studs from your eye to what you can take hold of
	DragReach = 11, -- the server lets go beyond this from the door's middle
	DragSensitivity = 0.018, -- studs your hand moves per pixel of mouse
	DragStickSpeed = 7, -- studs a second at full right stick
	DragStretch = 2.5, -- your hand never gets further than this ahead of a door that won't follow
	DragSendHz = 30,
	PredictDrag = true, -- the dragging client moves its own copy at once (off: wait for the server)
	HoldSeconds = 0.35, -- a door counts as held this long after your last drag message (then it swings on by itself)
	MotionHz = 20, -- how often something moving tells clients where it is (Controllers/MotionController)
	MotionBlend = 0.08, -- seconds a client takes to ease its copy into the server's
	ForcedSeconds = 1.2, -- once he forces a door you're holding, it's out of your hands this long
	DragNoiseSpeed = 160, -- degrees a second: swing faster than this and the door creaks loud enough to hear
	DragNoiseRadius = 14,
	GuestRadius = 1.1, -- a door swung into The Guest stops this far from his middle
	BodyRadius = 1.3, -- and this far from a player's
	-- Carrying and throwing small things (sections 4.3 and 4.4; Data/Physical).
	CarryDistance = { 2.2, 3.2, 5 }, -- nearest, where it starts, furthest: studs in front of your eye (wheel)
	CarryDrop = 7.5, -- further than this from your head, it slips out of your hands
	BulkySide = 1.1, -- studs to the right a big carried thing (a lamp, a plant) is held, to see past it
	CarryMaxSpeed = 80, -- (old flat cap; now each class's carry.maxSpeed plus the holder's speed plus CarrySpeedMargin)
	CarrySpeedMargin = 20, -- studs a second of slack for the network on top of a class's own speed
	GrabGraceSeconds = 0.5, -- just after taking hold (lifting it out of a drawer), passing through isn't checked
	-- Throwing (R2c): hold the right button to wind up. ChargeMin to ChargeFull
	-- seconds of holding goes from ChargeLow of the class's throw to all of it.
	ChargeMin = 0.15,
	ChargeFull = 0.7,
	ChargeLow = 0.35,
	ThrowLift = 0.08, -- a little upward lift on every throw
	ThrowCarry = 0.5, -- how much of its own swing (and your run) a throw keeps
	-- A stun counts only on a throw's first arc, within this of where it
	-- should be (studs, plus this a second): it can't be steered into him.
	ArcSlack = 2,
	ArcSlackPerSecond = 4,
	FlightSpeedScale = 1.3, -- a client-owned thing in flight faster than its throw speed times this (plus the margin) is taken back
	OwnedPerPlayer = 2, -- things a player's client may keep simulating after letting go
	SettleSeconds = 0.3, -- taken back by the server this long before it's put to sleep, so it doesn't snap
	RestSpin = 0.6, -- radians a second: turning faster than this isn't lying still
	RestHardMaxSeconds = 15, -- asleep after this however it's lying
	RestSeconds = 1.5, -- lying still this long after you let go, it's put back to sleep (anchored)
	RestMaxSeconds = 8, -- and asleep after this however it's lying
	FlightSeconds = 2.5, -- a throw is watched this long for a hit and a landing
	ImpactSpeed = 10, -- slowing hard from at least this fast is a landing: a sound and a noise
	FallLimit = 60, -- below the floor by this much, it goes back where it was found
	-- A throw that hits The Guest stops him for a moment (section 4.4): the
	-- class's stun (Data/Physical), halved for each stun in the last StunWindow
	-- seconds, never again within StunImmuneSeconds of one ending.
	StunMinSpeed = 28, -- slower than this and it just bumps off him
	StunRadius = 1.6, -- his body's reach plus a thrown thing's
	StunImmuneSeconds = 4,
	StunWindow = 60,
	StunFinalScale = 0.6, -- shorter in the final hunt
}

Config.Difficulty = {
	Normal = {
		Label = "Normal",
		DriftMultiplier = 1,
		StalkerSpeedMultiplier = 1,
		HuntIntervalMultiplier = 1,
	},
	Hard = {
		Label = "Hard",
		DriftMultiplier = 1.25,
		StalkerSpeedMultiplier = 1.04,
		HuntIntervalMultiplier = 0.8,
		-- Scarier, not only longer (the audit): the house starts uneasy, so
		-- the atmosphere is on from act 1, and his telegraphs are shorter.
		DreadFloor = 20,
		TelegraphScale = 0.7,
		DownsBeforeLost = 2,
		-- A friend's voice from behind a door (Stalk MimicVoice): Hard only
		-- (the owner, 2026-10-07).
		MimicVoice = true,
	},
}

Config.Camera = {
	FirstPersonInRun = true,
	LobbyMaxZoom = 14,
	FieldOfView = 70,
}

-- Shadow-casting is the expensive part of a dark house of many lamps, so a
-- room's lights only cast shadows while you're this close (EffectsController).
Config.ShadowRadius = { on = 62, off = 74 } -- studs from the camera, with hysteresis
Config.DriftArc = {
	UtilityFlickerAt = 40, -- Fraying: the fluorescents go first
	AllFlickerAt = 60, -- Breaking: everything else follows
	LampDimAt = 80, -- Collapsing: lamps sag towards LampDimTo
	LampDimTo = 0.5,
	MonochromeAt = 80, -- the grade drains to almost no colour by 100
	CollapseSaturation = -0.9,
}

Config.Audio = {
	UiVolume = 0.8, -- the interface group, relative to the master volume
	DriftMuffleDb = -18, -- how far the Ambient group's highs fall at full Drift
	HuntFadeSeconds = 0.6,
}

-- Music states (Controllers/AudioController; Assets.Music): which stem plays,
-- how loud, and how they cross.
Config.Music = {
	Volume = { Calm = 0.22, Stalking = 0.35, Hunt = 0.5 }, -- each stem, before the Music slider
	FadeIn = 2.5, -- seconds a stem takes to come up
	FadeOut = 1.8, -- ... and to go
	StalkingFromTier = 2, -- the stalking stem from this tier...
	StalkingFromDread = 40, -- ... or this Dread
	CalmFromSeconds = 20, -- no calm stem in the first seconds of a run: the house is quiet first
}

-- How movement feels (Logic/Feel, Controllers/FeelController and
-- FootstepController). All of the camera motion scales with the player's
-- "Camera motion" setting; 0 turns it off.
Config.Feel = {
	StrideWalk = 4.6, -- studs per step at walking pace: about 1.7 steps a second
	StrideSprint = 6.8, -- ... sprinting: about 2.8 steps a second
	-- Camera bob amplitudes in studs (vertical, sideways) and degrees of roll.
	BobWalk = { 0.06, 0.04, 0.25 },
	BobSprint = { 0.22, 0.14, 1.2 },
	BobEase = 6, -- per second, how fast the bob eases in and out
	TurnLean = 0.02, -- degrees of roll per degree/second of turning
	TurnLeanMax = 2.5,
	FovKick = 7, -- degrees added while sprinting
	FovEase = 6,
	LandMinSpeed = 18, -- fall speed (studs/s) that starts to dip the camera
	LandMaxSpeed = 70,
	LandDip = 0.45, -- studs at the hardest landing
	FootstepMinSpeed = 4, -- slower than this is a silent creep (matches PlayerState noise)
	-- Owner, 2026-10-04: "I don't think they're audible". The old 0.3 walk was
	-- about -10 dB (0.21 on carpet), quieter than the Guest's steps and the
	-- house hum. Sound.Volume goes to 10, so these are a plain multiplier.
	FootstepVolumeWalk = 0.85,
	FootstepVolumeSprint = 1.5,
	FootstepRollOffMin = 10, -- studs inside which a step isn't attenuated (was 6)
	FootstepPitchSpread = 0.07,
	FootstepVolumeSpread = 0.1,
	FootstepRange = 70, -- other players' steps are only played within this
	-- Breathing: your own breath follows stamina.
	BreathStartStamina = 0.7, -- below this share of stamina it becomes audible
	BreathSpeedMin = 0.9, -- tempo of the loop when fresh ...
	BreathSpeedMax = 1.25, -- ... and when spent: faster, but never higher (see BreathPitch)
	BreathPitch = 0.88, -- the voice's pitch, held steady by a pitch-shift as the tempo changes
	BreathGasp = { volume = 0.4, pitch = 0.82 }, -- the gasp when stamina runs out
}

-- What you hold (Controllers/ViewModelController, Lib/ViewModel).
Config.ViewModel = {
	-- The torch's button: dull red off, a hot neon glow on, with a tiny warm
	-- light so it reads on the dark body (owner, 2026-10-04).
	SwitchOff = { 190, 60, 50 },
	SwitchOn = { 255, 110, 80 },
	SwitchLightRange = 2,
	SwitchLightBrightness = 0.35,
	-- The beam starts a hair in front of the lens and is kept this far off any
	-- wall between your eye and it, so a torch tucked against a wall never puts
	-- its light inside the geometry (a shadow-casting light inside a wall is black).
	BeamWallGap = 0.15,
	Scale = 0.7, -- everything is built a little big for the screen; this brings it to size
	-- How each thing in your hands sits in the view (owner, 2026-10-04: "wonky",
	-- and the hands were off the bottom of the screen). Every number is in
	-- studs in the camera's frame (x right, y up) with `at` the item's distance
	-- ahead; `wrist` is measured from the item's middle, `back` toward you. Tune
	-- these in Studio; tests/specs/ViewFrame.spec checks the hands stay on screen
	-- at every field of view and aspect ratio.
	--   turn   = degrees: pitch (positive lifts the front), yaw, roll
	--   wrist  = where the right hand's wrist is; left = a second hand, if two-handed
	--   yaw    = how far the forearm swings out to the right (left hand: to the left)
	--   tilt   = how steeply the forearm rises towards the hand
	Poses = {
		Flashlight = {
			at = { 0.5, -0.32, 1.3 },
			turn = { 3, -4, 0 },
			wrist = { 0.03, -0.22, 0.3 },
			yaw = 14,
			tilt = 24,
		},
		Lantern = {
			at = { 0.42, -0.45, 1.25 },
			turn = { 0, 0, 0 },
			wrist = { 0, 0.3, 0.3 },
			yaw = 28,
			tilt = 30,
		},
		Radio = {
			at = { 0.3, -0.3, 1.25 },
			turn = { -15, 180, 0 }, -- turned round so the dial and grille face you
			wrist = { 0.12, -0.28, 0.22 },
			yaw = 22,
			tilt = 26,
		},
		Salts = {
			at = { 0.34, -0.3, 1.2 },
			turn = { -10, 0, 0 },
			wrist = { 0.1, -0.26, 0.24 },
			yaw = 20,
			tilt = 24,
		},
		-- The tools for tool locks (docs/plans/level-design.md section 11, L3.3).
		Crowbar = {
			at = { 0.48, -0.3, 1.3 },
			turn = { 15, -4, 0 },
			wrist = { 0.03, -0.2, 0.3 },
			yaw = 14,
			tilt = 24,
		},
		BoltCutters = {
			at = { 0.46, -0.3, 1.3 },
			turn = { 12, -4, 0 },
			wrist = { 0.03, -0.2, 0.32 },
			yaw = 14,
			tilt = 24,
		},
	},
	ArmHandForward = 0.18, -- the hand's middle sits this far (unscaled) in front of the wrist
}

Config.Debug = {
	AllowInStudio = true,
	SkipIntroInStudio = true, -- the first-launch settings dialog never blocks a Studio test
	AllowedUserIds = {}, -- add your user id to use debug commands on live servers
	LogTactics = false,
}

return Config
