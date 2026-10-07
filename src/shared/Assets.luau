-- Asset ids in one place. The rbxasset:// paths ship with every Roblox client,
-- so the game makes sound out of the box; swap them for commissioned audio
-- (doc section 8) by changing the ids here. Empty strings are skipped.

local Assets = {}

Assets.Sounds = {
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Snap = "rbxasset://sounds/snap.wav",
	-- The Guest's and stalker's steps: a wooden step (the same set the players
	-- walk on), pitched down by the caller.
	Footstep = "rbxassetid://136507037003210", -- Diman_x86 "Black Laboratory wood plank footstep 1"
	-- Heavy things: a body hitting a mat, for landings, sprint thumps and slams.
	Thud = "rbxassetid://9120977010", -- PSE "Wrestling Pad 10"
	-- Doors (Services/DoorService, through Lib/Sfx).
	DoorOpen = "rbxassetid://9114135701", -- PSE "Door Door Open With Squeak 1"
	DoorClose = "rbxassetid://9114748105", -- PSE "Half Glass Door 8": wood, open and close
	DoorLatch = "rbxassetid://9116238259", -- PSE "Latch Movement 3"
	DoorSlam = "rbxassetid://9114129572", -- PSE "Door Bang Rattle 8"
	DoorBang = "rbxassetid://9114129501", -- PSE "Door Bang Rattle 7": a heavy bang on a braced door
	Knock = "rbxassetid://9119907907", -- PSE "Table Hit Hand Smacks On Wood Table 1": a hollow knock
	-- Interface and hands.
	UIClick = "rbxassetid://9113145819", -- PSE "Apple Keyboard 76": a key press
	UIHover = "rbxassetid://9113145639", -- PSE "Apple Keyboard 73"
	FlashlightClick = "rbxassetid://129708861232883", -- Art1em12 "lightswitchon"
	Shutter = "rbxassetid://9113025793", -- PSE "35 Mm Still Camera 3": the Witness camera
	Cloth = "rbxassetid://136224586361044", -- IzZDEMONZzI "Clothes Movement": hiding, pickups
	Drawer = "rbxassetid://9120844977", -- PSE "Wood Drawer 4": a wardrobe or locker door
	Match = "rbxassetid://4510176414", -- WaddelsG "Matchstick SFX": the Lantern
	Stamp = "rbxassetid://9119909107", -- PSE "Table Hit 10": a verdict, an anchor locking in
	-- Scares and tells.
	Whisper = "rbxassetid://9114170094", -- PSE "Dream Weirdness Constant 6": whispers and scrapes
	Drip = "rbxassetid://9120520174", -- PSE "Water Drip Into Wood Bowl Light Blip 17"
	Whoosh = "rbxassetid://8893801865", -- shlexr "Audio/WhooshEffect" (the stock swoosh.wav is not approved)
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
	-- The Guest rework (2026-10-07): licensed library audio chosen by its
	-- description, not yet heard by the owner: swap by ear here.
	GuestRasp = "rbxassetid://9114571155", -- PSE "Ghost Giggle Breathy Cu Creepy Possessed 3": he has seen you, in a hunt
	GuestGiggle = "rbxassetid://9114571545", -- PSE "Ghost Giggle Breathy Cu Creepy Possessed 9": a playful Guest, now and then
	GuestSniff = "rbxassetid://9119305469", -- PSE "Sniff Breathe In 9": he's lost you and sniffs the air
	GuestKeys = "rbxassetid://9113849492", -- PSE "Coins Or Keys Jingle 6": his key ring at a locked door
	GuestCrack = "rbxassetid://9113542363", -- PSE "Bone Cracks 10" (dry): his knuckles, his neck tipping too far
	GuestExhale = "rbxassetid://9113586144", -- PSE "Breath Exhale 17", pitched down: let go after a long stare
	-- Your own breath, looped: it follows stamina (Controllers/AudioController).
	PlayerBreath = "rbxassetid://124832136911190", -- Creator Store "Breathing and Tired" (Maz_Rx1)
	-- Loops for the Drift layers and room tone. Fill these with real assets.
	RoomTone = "rbxassetid://9118747859", -- PSE "Rumble Ambience Interior Wind Turbo Shaft 4": a low house hum
	DriftBass = "rbxassetid://9125898973", -- PSE "Sci Fi Transformation Synth Tones Slow Swirling 1": a low drone
	DriftTinnitus = "rbxassetid://87380384768764", -- Oddsock833 "EarRinging"
	Heartbeat = "rbxassetid://9043365727", -- APM "HEARTBEAT 01 96BPM" (Horror Tools), loops
	RadioStatic = "rbxassetid://8028069841", -- NoobMatthew3 "Radio Static Loop"
	HuntSting = "rbxassetid://9113436052", -- PSE "Big Low-End Impacts 3": a resonant hit
	MusicBox = "rbxassetid://9043210085", -- APM "Music Box 6" (Conroy): a carried heirloom, faintly (R2c)
	GlassBreak = "rbxassetid://9114593513", -- PSE "Glass Breaks 21": a display case smashed (R2c)
	LockClick = "rbxassetid://9125343042", -- PSE "Door Lock Button Clicks 1": picking a small lock
	Flush = "rbxassetid://9120106611", -- PSE "Toilet Flush Two Flushes Gushing Water 1" (R2c interactables)
	Tap = "rbxassetid://9113368238", -- PSE "Bathroom Faucet Running Water 1": a tap left running, looped
	-- Rooms' own lures and features (docs/plans/level-design.md section 4,
	-- L3.6): licensed library audio chosen by its description, not yet heard:
	-- swap by ear here.
	KettleWhistle = "rbxassetid://9117259669", -- PSE "Pealess Whistle Referee Fox 40 1": a long burst, looped as the kettle's shriek
	WashingMachine = "rbxassetid://1839026975", -- APM "Washing Machine OL"
	Record = "rbxassetid://1835561411", -- APM "Seventies Swing": a record on the player
	CarHorn = "rbxassetid://9114402468", -- PSE "Ferrari 308 Car Honking Dual Air Horns 6"
	ServiceBell = "rbxassetid://9125485591", -- PSE "Desk Bell Counter Service Single Ringing Ding 1": a servants' bell
	ToyWindUp = "rbxassetid://9120219910", -- PSE "Toy Plastic Feet Wind Up 2": wound, then walking
	MusicBoxNote = "rbxassetid://9117042092", -- PSE "Music Box Swan Lake Single Notes 3": one note, pitched per key
	-- House events (Services/HouseEventService, 2026-10-06), not yet heard: swap by ear.
	PhoneRing = "rbxassetid://9117305259", -- PSE "Phone Ring Electronic Consumer Phone 1" (a two-tone 1980s ring): the hall telephone, looped while it rings
	ClockChime = "rbxassetid://1842312951", -- APM "Tubular Bell Sounds (b)": one strike of the grandfather clock
}

-- Player footsteps by surface (Data/Footsteps, Controllers/FootstepController).
-- Free Creator Store audio ("feel free to use in your games"): carpet by
-- iLoveSwiss_0, wood, tile and concrete by Diman_x86. Nothing was uploaded.
-- A surface with no ids, or none that load (FootstepController drops ids that
-- never load), falls back to StockFootstep, which ships with the client.
-- Music (Controllers/AudioController, 2026-10-06): three looping stems the
-- house crossfades between, calm / stalking / hunt. Empty ids play nothing:
-- the owner chooses by ear. Free APM candidates found on the Creator Store
-- (not yet heard): "Tension Repeat Drones 23" 1843866957, "... 29" 1843867314,
-- "... 39" 1843739491, "Cinematic Tension 16 I" 82017171529095, "... 16 J"
-- 102730546164558, "Deliberate Pain (Alt Key Bass)" 1837843263.
Assets.Music = {
	Calm = "", -- a thin, almost-not-there bed for the house between his visits
	Stalking = "", -- from tier 2 or Dread 40: a pulse under the quiet
	Hunt = "", -- the chase
}

Assets.StockFootstep = "rbxasset://sounds/action_footsteps_plastic.mp3"

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
