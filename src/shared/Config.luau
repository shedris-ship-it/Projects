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
	DownedSeconds = 45, -- (doc)
	ReviveHoldSeconds = 4, -- (doc)
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
	WalkSpeed = 12,
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
	JumpNoiseRadius = 14,
	SprintSpeedThreshold = 15,
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
	DecorRadios = 2, -- radios per house, in free floor slots of living rooms
}

-- The grime layer (World/Grime): shared decals placed from the seed.
Config.Grime = {
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
	BracedDoorSeconds = 5,
	InspectSeconds = 1.8,
	HearingMultiplier = 1,
	SearchLookSeconds = 2,
	MemoryHeardConfidence = 0.6,
	ProfileHalfLife = 120,
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

Config.Debug = {
	AllowInStudio = true,
	AllowedUserIds = {}, -- add your user id to use debug commands on live servers
	LogTactics = false,
}

return Config
