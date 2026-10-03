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

-- Full-screen film grain texture (a tiling noise image). The default is a 32 px
-- noise tile that ships with every Roblox client, so nothing needs uploading.
Assets.GrainTexture = "rbxasset://textures/noise.dds"

-- Soft round blob for the dust drifting in lamp light (ships with the client).
-- It has no alpha, so it's drawn additively: black adds nothing.
Assets.DustTexture = "rbxasset://textures/shadowblurmask.png"

-- Surface textures for the house (docs/ART.md, step 4). Drawn by
-- tools/textures.py (sources in assets/textures/) and uploaded to the owner's
-- account on 2026-10-02. Greyscale and seamless: the part's Color tints them.
-- Data/Materials turns them into MaterialVariants.
Assets.Textures = {
	WallpaperSprig = { color = "rbxassetid://122400107467062", normal = "rbxassetid://72310186404605" },
	WallpaperStripe = { color = "rbxassetid://128681149883555", normal = "rbxassetid://139959827277558" },
	Plaster = { color = "rbxassetid://103639715760016", normal = "rbxassetid://139387863577845" },
	Popcorn = { color = "rbxassetid://111220994454967", normal = "rbxassetid://106713356000616" },
	WoodFloor = { color = "rbxassetid://131264369009367", normal = "rbxassetid://74016382701051" },
	WoodPanel = { color = "rbxassetid://93586193315738", normal = "rbxassetid://118515640314780" },
	Carpet = { color = "rbxassetid://105120771211069", normal = "rbxassetid://76115866578536" },
	Linoleum = { color = "rbxassetid://138425394516162", normal = "rbxassetid://86453271657573" },
	HexTile = { color = "rbxassetid://89596429873713", normal = "rbxassetid://121778616853454" },
	Concrete = { color = "rbxassetid://93657982194767", normal = "rbxassetid://130961398154099" },
}

-- Uniform roughness maps (8 px): matte for paper, plaster and carpet, satin
-- for wood, linoleum and tile.
Assets.Roughness = {
	Matte = "rbxassetid://106957634858063",
	Satin = "rbxassetid://122371022318068",
}

-- Grime decals, one shared set so the whole house ages the same way.
Assets.Grime = {
	WaterStain = "rbxassetid://91472851924184",
	RustStreak = "rbxassetid://97626397773359",
	Scuffs = "rbxassetid://133627015851658",
	PictureGhost = "rbxassetid://91613317867163",
}

return Assets
