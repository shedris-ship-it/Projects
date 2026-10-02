-- Names shared between server and client: CollectionService tags, attribute
-- keys and collision groups. Keeping them here avoids typo drift.

local Constants = {}

Constants.Tags = {
	Object = "ConsensusObject", -- anything with a CId attribute
	Seam = "ConsensusSeam",
	Door = "ConsensusDoor",
	HidingSpot = "ConsensusHidingSpot",
	TellSite = "ConsensusTellSite",
	RoomLight = "ConsensusRoomLight",
	LanternShrine = "ConsensusLanternShrine",
	Stalker = "ConsensusStalker",
	Companion = "ConsensusCompanion",
	Item = "ConsensusItem",
	Level = "ConsensusLevel",
}

Constants.Attributes = {
	CId = "CId", -- stable id the server and clients use to refer to objects
	Label = "Label", -- what the Witness reticle shows when you aim at it
	RoomId = "RoomId",
	SeamId = "SeamId",
	Connected = "Connected",
	Category = "Category",
	Lit = "Lit",
}

-- Attributes on the ReplicatedStorage.RunState folder.
Constants.RunState = {
	Phase = "Phase",
	Drift = "Drift",
	DriftState = "DriftState",
	Seed = "Seed",
	Tier = "Tier",
	StalkerMode = "StalkerMode",
	Hunting = "Hunting",
	RunTime = "RunTime",
	PhaseEndsAt = "PhaseEndsAt",
	Difficulty = "Difficulty",
	SquadSize = "SquadSize",
	LobbyCountdown = "LobbyCountdown",
	RitualProgress = "RitualProgress",
	RitualText = "RitualText",
	ConfirmedCount = "ConfirmedCount",
}

-- Attributes on each Player.
Constants.PlayerAttributes = {
	State = "RunState", -- "Lobby", "Active", "Downed", "Lost", "Extracted"
	Focus = "Focus",
	Tool = "Tool",
	Film = "Film",
	Battery = "Battery",
	Flashlight = "Flashlight",
	Hidden = "Hidden",
	DownedUntil = "DownedUntil",
	Ready = "Ready",
	Carrying = "Carrying",
	IsEcho = "IsEcho",
}

Constants.Phases = {
	Lobby = "Lobby",
	Generating = "Generating",
	Arrival = "Arrival",
	Investigation = "Investigation",
	Resolution = "Resolution",
	Extraction = "Extraction",
	Debrief = "Debrief",
}

Constants.PlayerStates = {
	Lobby = "Lobby",
	Active = "Active",
	Downed = "Downed",
	Lost = "Lost",
	Extracted = "Extracted",
}

Constants.CollisionGroups = {
	Players = "ConsensusPlayers",
	Stalker = "ConsensusStalker",
	Echo = "ConsensusEcho",
	Seam = "ConsensusSeam",
	Door = "ConsensusDoor",
	Phantom = "ConsensusPhantom",
}

Constants.StalkerModes = {
	Dormant = "Dormant",
	Watching = "Watching",
	Closing = "Closing",
	Intruding = "Intruding",
	Telegraph = "Telegraph",
	Hunting = "Hunting",
	Retreating = "Retreating",
}

return Constants
