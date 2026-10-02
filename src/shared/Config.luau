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
	WallHeight = 12,
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
