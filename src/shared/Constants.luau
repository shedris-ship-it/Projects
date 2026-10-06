-- Names shared between server and client: CollectionService tags, attribute
-- keys and collision groups. Keeping them here avoids typo drift.

local Constants = {}

Constants.Tags = {
	Object = "ConsensusObject", -- anything with a CId attribute
	Seam = "ConsensusSeam",
	Door = "ConsensusDoor",
	Articulated = "ConsensusArticulated", -- a door's or a furniture piece's main part (Controllers/MotionController)
	HidingSpot = "ConsensusHidingSpot",
	TellSite = "ConsensusTellSite",
	RoomLight = "ConsensusRoomLight",
	LanternShrine = "ConsensusLanternShrine",
	Stalker = "ConsensusStalker",
	Companion = "ConsensusCompanion",
	Item = "ConsensusItem",
	Photo = "ConsensusPhoto", -- a family photo the client ages with Drift
	Blood = "ConsensusBlood", -- a hidden stain the client reveals at its attribute BloodAt (Drift)
	Window = "ConsensusWindow", -- a window or mirror pane The Guest can show in (attribute Kind)
	Level = "ConsensusLevel",
	Railing = "ConsensusRailing", -- an invisible railing collider (no queries: sight passes between balusters)
	Grabbable = "ConsensusGrabbable", -- a small thing your hands can carry and throw (attribute Grab = its id)
	SoundLoop = "ConsensusSoundLoop", -- a part that plays a looped sound while its Loop attribute is set (Controllers/AudioController)
}

Constants.Attributes = {
	CId = "CId", -- stable id the server and clients use to refer to objects
	Label = "Label", -- what the Witness reticle shows when you aim at it
	RoomId = "RoomId",
	SeamId = "SeamId",
	SeamTrim = "SeamTrim", -- trim that flips with a seam: the seam's id
	SeamTrimRole = "SeamTrimRole", -- "wall" (shown while it's a wall) or "door"
	Connected = "Connected",
	Category = "Category",
	Lit = "Lit",
	LampGlow = "LampGlow", -- a glowing part of a light fixture; dims and reddens with its light
}

-- Attributes on the ReplicatedStorage.RunState folder.
Constants.RunState = {
	Phase = "Phase",
	Drift = "Drift",
	DriftState = "DriftState",
	-- How bad the house is (Logic/Dread): Drift or the act's floor, whichever
	-- is worse. Every escalation clients draw reads this, and its word.
	Dread = "Dread",
	DreadState = "DreadState",
	Seed = "Seed",
	Tier = "Tier",
	StalkerMode = "StalkerMode",
	Hunting = "Hunting",
	RunTime = "RunTime",
	PhaseEndsAt = "PhaseEndsAt",
	Difficulty = "Difficulty",
	SquadSize = "SquadSize",
	LobbyCountdown = "LobbyCountdown",
	Objective = "Objective", -- the HUD's one-line objective (Logic/Objectives)
}

-- Attributes on each Player.
Constants.PlayerAttributes = {
	State = "RunState", -- "Lobby", "Active", "Downed", "Lost", "Extracted"
	-- The tool in your hands right now, or nil with the torch or empty hands
	-- (so everything that reads "your tool" still works with found tools).
	Tool = "Tool",
	-- The four inventory slots (Logic/Inventory): ids, "" when empty, and
	-- which one is in your hands (1 to 4). Slot 1 is always the flashlight and
	-- slot 4 your bare hands ("Hands").
	Slots = { "Slot1", "Slot2", "Slot3", "Slot4" },
	ActiveSlot = "ActiveSlot",
	Battery = "Battery",
	Flashlight = "Flashlight",
	-- The torch is clipped to your shirt (anything but slot 1 in your hands):
	-- a weak light where your body faces instead of the beam in your hand.
	TorchClipped = "TorchClipped",
	-- Alone, your full beam is holding him frozen (Config.Stare): the battery
	-- drains faster while it does.
	BeamHold = "BeamHold",
	-- F2 `botrun` is driving this character from the server (Services/
	-- BotService): the client's movement and walk speed stand aside.
	BotDriven = "BotDriven",
	Hidden = "Hidden",
	DownedUntil = "DownedUntil",
	Ready = "Ready",
	Carrying = "Carrying",
	IsEcho = "IsEcho",
	-- The keys on your ring (the escape, Services/LockService): their names,
	-- one a line.
	Keys = "Keys",
	KeyRing = "KeyRing", -- "token=label" per line: the journal's Drop buttons
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
	-- Physical props (docs/plans/gameplay-rework.md section 4.2).
	Prop = "ConsensusProp", -- small things, resting or thrown
	Held = "ConsensusHeld", -- small things being carried
	Heavy = "ConsensusHeavy", -- furniture you push
}

Constants.StalkerModes = {
	Dormant = "Dormant",
	Watching = "Watching",
	Closing = "Closing",
	Intruding = "Intruding",
	Telegraph = "Telegraph",
	Hunting = "Hunting",
	Retreating = "Retreating",
	Departing = "Departing", -- after the final hunt: he bows you out
}

return Constants
