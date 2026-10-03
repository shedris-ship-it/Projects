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
	-- Licensed library audio from the Creator Store (Pro Sound Effects and
	-- APM Music, free to use in Roblox experiences; nothing was uploaded).
	Gasp = "rbxassetid://9114555699", -- PSE "Gasp Trouble Breathing 3": a downed Witness
	GaspAlt = "rbxassetid://9114555843", -- PSE "Gasp Trouble Breathing 4"
	-- The Guest (Controllers/GuestController).
	FrontDoorKnock = "rbxassetid://9114141961", -- PSE "Door Knock 6": knocks, then the door creaks open
	Breath = "rbxassetid://9113586144", -- PSE "Breath Exhale 17": close, in your ear
	Creak = "rbxassetid://9125563505", -- PSE floorboard creak
	CreakAlt = "rbxassetid://9125563286", -- PSE floorboard creak
	WindUp = "rbxassetid://9114555843", -- the gasp, pitched far down: a sharp intake before the lunge
	Sting = "rbxassetid://9117322696", -- PSE "Piano Strings Attack 1": the jumpscare
	GlassTap = "rbxassetid://9119918673", -- PSE "Tap On Glass Window 1"
	-- Your own breath, looped: it follows stamina (Controllers/AudioController).
	PlayerBreath = "rbxassetid://124832136911190", -- Creator Store "Breathing and Tired" (Maz_Rx1)
	-- Loops for the Drift layers and room tone. Fill these with real assets.
	RoomTone = "rbxassetid://9118747859", -- PSE "Rumble Ambience Interior Wind Turbo Shaft 4": a low house hum
	DriftBass = "",
	DriftTinnitus = "",
	Heartbeat = "rbxassetid://9043365727", -- APM "HEARTBEAT 01 96BPM" (Horror Tools), loops
	RadioStatic = "",
	HuntSting = "",
}

-- Player footsteps by surface (Data/Footsteps, Controllers/FootstepController).
-- Free Creator Store audio ("feel free to use in your games"): carpet by
-- iLoveSwiss_0, wood, tile and concrete by Diman_x86. Nothing was uploaded.
-- A surface with no ids falls back to Sounds.Footstep.
Assets.Footsteps = {
	Wood = {
		"rbxassetid://136507037003210",
		"rbxassetid://95897689644876",
		"rbxassetid://86757586209661",
		"rbxassetid://85890435849962",
		"rbxassetid://102979601052590",
		"rbxassetid://103047715427883",
		"rbxassetid://113620422592627",
	},
	Carpet = {
		"rbxassetid://91882016473062",
		"rbxassetid://111131620367547",
		"rbxassetid://73343053773763",
		"rbxassetid://123224557798023",
		"rbxassetid://92103616531947",
		"rbxassetid://73871404556766",
	},
	Tile = {
		"rbxassetid://112733259097591",
		"rbxassetid://118048499719068",
		"rbxassetid://126965755395879",
		"rbxassetid://133063162472741",
		"rbxassetid://72966441854333",
		"rbxassetid://139267724392327",
	},
	Concrete = {
		"rbxassetid://120195545352847",
		"rbxassetid://108290664490396",
		"rbxassetid://112000835797556",
		"rbxassetid://106961831442199",
	},
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

-- Family photos (docs/ART.md, Hero props), drawn by tools/textures.py and
-- uploaded 2026-10-02. Each snapshot has three states the client swaps
-- between as Drift rises: normal, blurred, faces gone. Shared decay, never
-- Witnessable (rule 6).
Assets.Photos = {
	{
		normal = "rbxassetid://93593792403354",
		blurred = "rbxassetid://88847923447051",
		faceless = "rbxassetid://112610928737804",
	},
	{
		normal = "rbxassetid://79528651347044",
		blurred = "rbxassetid://110600633771474",
		faceless = "rbxassetid://138887055186799",
	},
	{
		normal = "rbxassetid://137179035919061",
		blurred = "rbxassetid://77790508697041",
		faceless = "rbxassetid://134121802581437",
	},
}

return Assets
