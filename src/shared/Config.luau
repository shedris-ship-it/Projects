-- Every tunable number in one place. Values marked "(doc)" come straight from
-- the design doc; the rest are starting guesses to tune in playtests.

local Config = {}

Config.Run = {
	MinPlayers = 1,
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
	CompanionReviveSeconds = 6, -- the solo Companion is slower than a friend
	HeartbeatBpm = 96, -- tempo of Assets.Sounds.Heartbeat at normal speed
	BleedHeartbeat = { 1, 0.45 }, -- heartbeat speed from just downed to gone
	ExtractionSeconds = 120,
	DebriefSeconds = 30,
	AfkSeconds = 60, -- (doc)
	EchoHintCooldown = 60, -- (doc) Echoes ping one hint per minute
	CompanionForSolo = true, -- Companion Witness so a solo player can anchor
	DownedCrawlSpeed = 3,
}

Config.Drift = {
	Max = 100,
	BaselinePerMinute = 2.5, -- (doc)
	IsolationDistance = 25, -- (doc)
	IsolationGraceSeconds = 20, -- (doc)
	IsolationPerMinute = 1, -- (doc) per isolated player
	AnchorCreditsPerMinute = 3, -- (doc) max anchor rewards per minute
	Events = {
		WrongVerdict = 15, -- (doc)
		PlayerDowned = 10, -- (doc)
		EvidenceConfirmed = -6, -- (doc)
		EvidencePhotographed = -3,
		Anchor = -2, -- (doc)
		HuntSurvived = -10, -- (doc)
		CounterfeitUsed = 8,
		RitualStage = -4,
	},
	States = {
		{ name = "Calm", min = 0 },
		{ name = "Uneasy", min = 20 },
		{ name = "Fraying", min = 40 },
		{ name = "Breaking", min = 60 },
		{ name = "Collapsing", min = 80 },
	},
}

Config.Witness = {
	HoldSeconds = 0.45, -- how long the key is held before a Witness is sent
	WindowSeconds = 4, -- (doc)
	AnchorSeconds = 90, -- (doc)
	StalkerAnchorSeconds = 8,
	FocusMax = 100, -- (doc)
	Cost = 20, -- (doc)
	CostMultiplierWhenBreaking = 1.5, -- (doc) anchoring costs more Focus at Breaking+
	RegenAlone = 1.2,
	RegenNearTeammate = 5,
	RegenLanternBonus = 6,
	TeammateRadius = 10, -- (doc)
	CompanionRadius = 16, -- the solo Companion keeps 8-16 studs back, so it counts as near across that band
	MaxRange = 45,
	ResolveRadius = 6,
	MinInterval = 0.35,
	CoStareSeconds = 3, -- (doc) two players holding a stare make it retreat
	CoStareFocusPerSecond = 8,
}

Config.Social = {
	PingCooldown = 0.8,
	PingLifetime = 7,
	CalloutCooldown = 2,
	VerdictMajorityAfter = 90, -- (doc)
	VerdictWindow = 120,
	VerdictRetryCooldown = 20,
	DeliberationRange = 14,
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
	FlashlightBatterySeconds = 300,
	FlashlightRechargePerSecond = 4, -- inside a lit Lantern room
	SprintNoiseRadius = 28,
	WalkNoiseRadius = 6,
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
	Placement = {
		Top = 6, -- weighted pick among this many best candidates
		Contact = 1, -- per extra neighbour a door could join
		Loop = 5, -- per neighbour a door would close a 4-8 room loop with
		Fill = 2, -- joined to a corridor that has nothing off it yet
		Near = 3, -- per neighbour the template wants to be near
		Corridor = 1.5, -- joined to a corridor or the hall rather than through another room
		Chain = 2, -- per room the parent already is from a corridor (dead-end chains)
		Bridge = 6, -- upstairs: touches both the gallery's side and the back stairs' side
		Spread = 0.03, -- per stud from the house's middle (keeps it compact)
		Jitter = 1,
	},
}

-- Walking the house (docs/plans/mansion-generation.md, M3): the graph that
-- picks the way (Logic/NavGraph), the walker that follows it on the navmesh
-- (Stalker/Walker) and the sweeps that keep every move out of the walls
-- (Stalker/Clearance). The Guest and the Companion share all of it.
Config.Nav = {
	Approach = 3.5, -- studs into a room in front of a doorway
	Clearance = 1.2, -- half the Guest's width plus a margin: routes keep this far from furniture
	DoorCost = 12, -- studs a closed door is worth (opening it takes 1.5-3 s)
	SeamFactor = 1.6, -- Phantom Architecture's twist: walking through a solid seam costs this much more
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
	WitnessDistance = 14, -- a Witnessable object shows its marker this close
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

Config.Evidence = {
	TrueTells = { 3, 4 }, -- (doc)
	RedHerrings = { 1, 2 }, -- (doc)
	MaxSuspectsAfterThree = 2, -- (doc)
}

Config.Divergence = {
	CalibrationPerPlayer = 2,
	UsefulObjectPerPlayer = { 1, 2 },
	UsefulObjectMinDrift = 20, -- (doc) divergences start touching doors and items
	SoundMinDrift = 40, -- (doc) mislocated sounds
	RearrangeMinDrift = 60, -- (doc) rooms rearrange behind you
	FalseConsensusMinDrift = 80, -- (doc)
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
	NeckYawMax = 160, -- his head keeps turning to watch you; a person manages about 80
	SmileCloseRange = { 4, 18 }, -- the smile widens from 18 studs in to arm's length
	EyeShineRange = 45, -- your torch catches his eyes within this range
	EyeShineCone = 24, -- half-angle of the torch beam, degrees
	FootstepVolume = { Walk = 0.45, Run = 0.9, Creep = 0.16, BackAway = 0.28 },

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
	CloseBehind = 3.5, -- tier 2: as close as he comes, breathing on your neck
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
}

Config.Tools = {
	CameraFilm = 6, -- (doc)
	CameraFilmSolo = 8,
	CameraRange = 40,
	PlumbLineCooldown = 20,
	PlumbLineMinConfirmed = 2, -- (doc)
	PlumbLineErrorDegrees = { 35, 8 }, -- error at 2 confirmed tells, shrinking to the second value
	LanternLightSeconds = 2,
	LanternLightSecondsNoTool = 8,
	RadioRange = 80,
	-- Tools are found around the house (owner, 2026-10-04): one of each, and
	-- squads of ExtraCopiesFromSquad or more get these extra copies as well.
	ExtraCopiesFromSquad = 3,
	ExtraCopies = { Camera = 1, Lantern = 1 },
	CameraMaxSteps = 3, -- the Camera is within this many rooms of where you start, so a solo player finds it
	PickupRange = 9, -- studs; the server re-checks it on every pickup
	PickupScale = 0.8, -- a tool lying on a table is this size next to the one in your hand
}

-- Doors swing by angle on the server (Logic/Articulation; docs/plans/
-- gameplay-rework.md section 4.5). 0 is shut.
Config.Doors = {
	OpenAngle = 100, -- fully open, against the wall
	PassAngle = 55, -- open this far or more and you (and he) can walk through
	LatchAngle = 3, -- swung back within this of shut, it snaps shut and latches
	SwingRate = 285, -- degrees a second: a full swing in about a third of a second
	SlamRate = 520,
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
}

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
	HoldSeconds = 0.35, -- a door counts as held this long after your last drag message
	ForcedSeconds = 1.2, -- once he forces a door you're holding, it's out of your hands this long
	DragNoiseSpeed = 160, -- degrees a second: swing faster than this and the door creaks loud enough to hear
	DragNoiseRadius = 14,
	GuestRadius = 1.1, -- a door swung into The Guest stops this far from his middle
	-- Carrying and throwing small things (sections 4.3 and 4.4; Data/Physical).
	CarryDistance = { 2.2, 3.2, 5 }, -- nearest, where it starts, furthest: studs in front of your eye (wheel)
	CarryDrop = 6.5, -- further than this from your head, it slips out of your hands
	CarryMaxSpeed = 80, -- faster than this while held is not something a hand did: put back
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
		RedHerrings = { 1, 2 },
		StalkerSpeedMultiplier = 1,
		HuntIntervalMultiplier = 1,
	},
	Hard = {
		Label = "Hard",
		DriftMultiplier = 1.25,
		RedHerrings = { 2, 2 },
		StalkerSpeedMultiplier = 1.04,
		HuntIntervalMultiplier = 0.8,
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
		Camera = {
			at = { 0.05, -0.3, 1.25 },
			turn = { 4, 0, 0 },
			wrist = { 0.38, -0.22, 0.28 },
			left = { -0.34, -0.24, 0.22 },
			yaw = 18,
			tilt = 22,
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
		PlumbLine = {
			at = { 0.38, -0.5, 1.25 }, -- hangs from the hand, so low: the bob may dip off a narrow screen
			turn = { 0, 0, 0 },
			wrist = { 0, 0.34, 0.28 },
			yaw = 24,
			tilt = 30,
		},
	},
	ArmHandForward = 0.18, -- the hand's middle sits this far (unscaled) in front of the wrist
}

Config.Debug = {
	AllowInStudio = true,
	AllowedUserIds = {}, -- add your user id to use debug commands on live servers
	LogTactics = false,
}

return Config
