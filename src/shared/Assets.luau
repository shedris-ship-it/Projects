-- Asset ids in one place. The rbxasset:// paths ship with every Roblox client,
-- so the game makes sound out of the box; swap them for commissioned audio
-- (doc section 8) by changing the ids here. Empty strings are skipped.

local Assets = {}

Assets.Sounds = {
	Footstep = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Thud = "rbxasset://sounds/action_jump_land.mp3",
	Knock = "rbxasset://sounds/action_jump_land.mp3",
	DoorCreak = "rbxasset://sounds/action_get_up.mp3",
	Groan = "rbxasset://sounds/uuhhh.mp3",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Whoosh = "rbxasset://sounds/swoosh.wav",
	Snap = "rbxasset://sounds/snap.wav",
	Drip = "rbxasset://sounds/impact_water.mp3",
	Shutter = "rbxasset://sounds/clickfast.wav",
	-- Loops for the Drift layers and room tone. Fill these with real assets.
	RoomTone = "",
	DriftBass = "",
	DriftTinnitus = "",
	Heartbeat = "",
	RadioStatic = "",
	HuntSting = "",
}

-- Optional full-screen film grain texture (a tiling noise image).
Assets.GrainTexture = ""

return Assets
