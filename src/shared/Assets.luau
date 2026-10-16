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
	-- APM "HORROR SCREAM 10" (Epic Score, Horror Tools): a hunt opens (the squad
	-- playtest, 2026-10-08). Not yet heard by the owner; PSE "Creature Roar Mix Of
	-- Animals Gate Creaks 1" 9113985717 is the other candidate.
	GuestScream = "rbxassetid://9043346099",
	GuestGiggle = "rbxassetid://9114571545", -- PSE "Ghost Giggle Breathy Cu Creepy Possessed 9": a playful Guest, now and then
	GuestSniff = "rbxassetid://9119305469", -- PSE "Sniff Breathe In 9": he's lost you and sniffs the air
	GuestKeys = "rbxassetid://9113849492", -- PSE "Coins Or Keys Jingle 6": his key ring at a locked door
	GuestCrack = "rbxassetid://9113542363", -- PSE "Bone Cracks 10" (dry): his knuckles, his neck tipping too far
	GuestExhale = "rbxassetid://9113586144", -- PSE "Breath Exhale 17", pitched down: let go after a long stare
	-- His takedown (the visual rework V8, Logic/Takedown): licensed Pro Sound
	-- Effects library audio chosen by description, not yet heard by anyone:
	-- swap by ear here. The bite is two layered: a squishy crunch and a dry
	-- crack (Bone Cracks 15, 9113542645, the other candidate for the second).
	TakedownBite = "rbxassetid://9113660777", -- PSE "Cactus Crunches 3": hits, crunches, squishes
	TakedownCrunch = "rbxassetid://9113542694", -- PSE "Bone Cracks 16": short to medium, crackly, dry
	-- The scream, cut off on the bite; by the body (Data/Wardrobe). Others:
	-- male 9125652432, 9125652949; female 9114399356, 9114400180.
	TakedownScreamMale = "rbxassetid://9125652466", -- PSE "Male Scream Short Yelling Bursts Death Cries 3"
	TakedownScreamFemale = "rbxassetid://9114399323", -- PSE "Female Voices 2 Women Short Screams Yells 9"
	TakedownDrag = "rbxassetid://9118767462", -- PSE "Sand Bag Slide 5": a heavy body dragged on boards (or 9118767717)
	-- The storm (the visual rework V2, Controllers/WeatherController): licensed
	-- Pro Sound Effects library audio, chosen by description, not yet heard by
	-- the owner: swap by ear here.
	RainBed = "rbxassetid://9112853287", -- PSE "Rain Heavy 1": interior, heavy, dripping, loop
	RainGlass = "rbxassetid://9112857056", -- PSE "Rain On Window 2": medium heavy on glass, loop
	ThunderNear1 = "rbxassetid://9120020295", -- PSE "Thunder Lightning 4": huge crack, rumble tail
	ThunderNear2 = "rbxassetid://9120020308", -- PSE "Thunder Lightning 5"
	ThunderNear3 = "rbxassetid://9120016256", -- PSE "Thunder Cracks Big Rumbling Blasts Booming 3"
	ThunderFar1 = "rbxassetid://9120021540", -- PSE "Thunder Sharp Booming Strikes Rumbling 1"
	ThunderFar2 = "rbxassetid://9120021794", -- PSE "... Rumbling 4"
	ThunderFar3 = "rbxassetid://9120021237", -- PSE "Thunder Rumbling 1": crashing, long decays
	-- The living room's fire (Controllers/FireController; the visual rework V3):
	-- PSE "Fireplace Constant Burning Flame 4", crackly, loop. Alternatives: 9112780193,
	-- 9112780438, 9112780212 (the same family).
	FireCrackle = "rbxassetid://9112780462",
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

-- The lobby mall's sounds (Controllers/MallController; the owner's ask,
-- 2026-10-15). A shortlist per role; the first plays. The owner picked each
-- by ear on 2026-10-15 (from Roblox's store pages), and the picks are first;
-- the rest stay to swap back with F2 `mallsound <role> <n>` (Hum, Buzz,
-- Drip, Radio, Arcade, Sputter). Pro Sound Effects and APM are licensed
-- library audio; the rest is free Creator Store audio. Nothing uploaded.
Assets.Mall = {
	Hum = { -- the investigators' generator, idling in the garage
		"rbxassetid://71482635231754", -- TheGoldCube "Diesel engine idle loop" (the owner's pick)
		"rbxassetid://4350214335", -- ZombieLordCell123 "GE Idle"
		"rbxassetid://9112890980", -- PSE "Ups Sorting Facility 1": fluttering machine, motor, compressor
	},
	Buzz = { -- the two fluorescents still working
		"rbxassetid://9112823813", -- PSE "Light Bulb Buzz 2": close, constant tone, loop (the owner's pick)
		"rbxassetid://619993906", -- Dekimus "Buzzing Fluorescent Light"
		"rbxassetid://9112889082", -- PSE "Transformer Hum 1": steady buzz, loop
	},
	Drip = { -- the leak into the bucket, one drop at a time
		"rbxassetid://9112895345", -- PSE "Water Drip Single Drops Into Tin Bucket 117" (the owner's pick)
		"rbxassetid://9112899667", -- PSE "... Tin Bucket 54"
		"rbxassetid://9120520174", -- PSE "Water Drip Into Wood Bowl Light Blip 17" (the house's)
	},
	Radio = { -- the CB radio in the investigators' corner
		"rbxassetid://9120457641", -- PSE "Walkie Talkie 7": futzed voices (the owner's pick)
		"rbxassetid://9112851363", -- PSE "Radio Light Chatter 1": chatter, whine, loop
		"rbxassetid://8028069841", -- NoobMatthew3 "Radio Static Loop" (the house's)
	},
	Arcade = { -- the cabinets' attract mode (no arcade loop in the libraries)
		"rbxassetid://82693415549955", -- DistroKid "Save Game" (the owner's pick)
		"rbxassetid://135444413435483", -- DistroKid "World 1-1: Dingo Drivers" (chiptune)
		"rbxassetid://9112814647", -- PSE "Las Vegas Casino 2": video poker blips (has crowd walla)
	},
	Sputter = { -- the generator coughing in a brownout
		"rbxassetid://9125346931", -- PSE "1988 Chevy Pickup Truck Rough Start Turn Off 4": sputtering failures (the owner's pick)
		"rbxassetid://9125657802", -- PSE "Mercedes-Benz 280 SL Failed Starts Engine Start 2"
		"rbxassetid://9112970895", -- PSE "1979 Mack Semi Truck 2": failed starts, whirring, clanking
	},
	-- The party cars' radio stations (LB4, Data/CarBits Radio; Services/
	-- CarService plays the first of each while anyone's in the car; not yet
	-- heard, swap by ear).
	Stations = {
		Hits = {
			"rbxassetid://90409233638163", -- DistroKid "Glass Cities: 80s Synth Pop, Cold Neon Aesthetic"
			"rbxassetid://94768360138586", -- DistroKid "Light in the Dark (80s Synth-Pop)"
			"rbxassetid://77875465950412", -- DistroKid "TicToc (synth-pop) 80s Magic Records"
		},
		Oldies = {
			"rbxassetid://1846282214", -- APM "Rock Cafe"
		},
		Night = {
			"rbxassetid://9112851363", -- PSE "Radio Light Chatter 1": chatter, whine, loop
			"rbxassetid://8028069841", -- NoobMatthew3 "Radio Static Loop" (the house's)
		},
	},
	Horn = { -- a party car's driver honks to go (LB2, Services/CarService)
		"rbxassetid://9114886932", -- PSE "Jeep Horn Doubles Triples Various Versions 1" (2.5 s; the owner's pick)
		-- (Turned down by ear, 2026-10-16, "just obnoxious": diman's group "Car
		-- horn 5" 98887155647851, AmikkuHedgehog "Generic car horn" 75630569167524.)
	},
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
-- The squad playtest (2026-10-08) wanted hunts with music: two picked from
-- those, still to be heard by the owner (swap freely): APM "Tension Repeat
-- Drones 29" under the stalking, "Rhythm Drone 34" for the hunt. Others:
-- "Terror" 1837226983, "Tension Repeat Drones 10" 1843736088, "Approaching
-- Hordes (A)" 1840900109. The calm stays silent (P.T.).
Assets.Music = {
	Calm = "", -- a thin, almost-not-there bed for the house between his visits
	Stalking = "rbxassetid://1843867314", -- from tier 2 or Dread 40: a pulse under the quiet
	Hunt = "rbxassetid://1843775810", -- the chase
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

-- The lens (the visual rework V1, 2026-10-12: P.T. on 35mm film), drawn by
-- tools/lens.py and uploaded with the owner's OK. Controllers/LensController.
Assets.Lens = {
	-- Film grain, 512 px seamless frames shown one texel to a screen pixel and
	-- flipped at 24 a second. Each holds dark specks (black) and fainter light
	-- ones (white); alpha is the strength.
	Grain = {
		"rbxassetid://92891459123910",
		"rbxassetid://91123355776843",
		"rbxassetid://129176190810488",
		"rbxassetid://125887897250309",
		"rbxassetid://140097820014085",
		"rbxassetid://116456630070350",
		"rbxassetid://120026429885487",
		"rbxassetid://105665780834642",
	},
	GrainSize = 512, -- pixels across a frame
	Vignette = "rbxassetid://135713679847886", -- dithered, so it never bands
	Glare = "rbxassetid://128745649799331", -- warm core, amber halo, a red rim (halation)
	GlareStreak = "rbxassetid://110530427197843",
	Dirt = "rbxassetid://139050197609707", -- smudges and specks on the lens
}

-- The interface's paper (V7, the diegetic 1988 interface), drawn by
-- tools/paper.py (sources in assets/paper/) and uploaded with the owner's OK
-- on 2026-10-14. Lib/Ui lays them out: `slice` is the nine-slice margin in
-- pixels (the corners and torn edges keep their shape), `tile` the size a
-- tiled one is drawn at.
Assets.Paper = {
	Sheet = { image = "rbxassetid://129215802709384", size = { 768, 1024 }, slice = 48 }, -- typing paper
	Slip = { image = "rbxassetid://93891500076081", size = { 768, 256 }, slice = 40 }, -- torn off a notepad
	Folder = { image = "rbxassetid://75368764681170", size = { 1024, 768 }, slice = 64 }, -- manila case folder
	Graph = { image = "rbxassetid://105302061922117", size = { 512, 512 }, tile = 256 }, -- the map's
	Notebook = { image = "rbxassetid://117768510809064", size = { 768, 1024 }, slice = 48 }, -- the journal's
	Tape = { image = "rbxassetid://76700521185652", size = { 320, 96 } },
	Shadow = { image = "rbxassetid://113681928800155", size = { 160, 160 }, slice = 40 },
	Scanlines = { image = "rbxassetid://106584581093865", size = { 256, 256 }, tile = 128 },
}

-- Soft round blob for the dust drifting in lamp light (ships with the client).
-- It has no alpha, so it's drawn additively: black adds nothing.
Assets.DustTexture = "rbxasset://textures/shadowblurmask.png"

-- Surface textures for the house (docs/ART.md, step 4). Drawn by
-- tools/textures.py (sources in assets/textures/) and uploaded to the owner's
-- account on 2026-10-02. Greyscale and seamless: the part's Color tints them.
-- Data/Materials turns them into MaterialVariants.
Assets.Textures = {
	-- The house's surfaces (tools/surfaces.py, the visual rework V4a), each with
	-- a roughness map of its own, uploaded by the owner's import of kit.py
	-- surfaces (on its swatches), 2026-10-15. The first ten rebuilt, then the
	-- new ones for what the house drew in Roblox's own materials.
	WallpaperSprig = {
		color = "rbxassetid://73463151140217",
		normal = "rbxassetid://113250405469031",
		rough = "rbxassetid://107502940991982",
	},
	WallpaperStripe = {
		color = "rbxassetid://111519075424092",
		normal = "rbxassetid://75547032593809",
		rough = "rbxassetid://130307778925160",
	},
	Plaster = {
		color = "rbxassetid://83812514924417",
		normal = "rbxassetid://72779224611917",
		rough = "rbxassetid://98518007156261",
	},
	Popcorn = {
		color = "rbxassetid://110029150557925",
		normal = "rbxassetid://81107933428469",
		rough = "rbxassetid://139997466857773",
	},
	WoodFloor = {
		color = "rbxassetid://114683402288401",
		normal = "rbxassetid://85593359580066",
		rough = "rbxassetid://124075294565472",
	},
	WoodPanel = {
		color = "rbxassetid://104166371749038",
		normal = "rbxassetid://111201923957070",
		rough = "rbxassetid://75180545532960",
	},
	Carpet = {
		color = "rbxassetid://122198871332189",
		normal = "rbxassetid://126189991063037",
		rough = "rbxassetid://130530997059584",
	},
	Linoleum = {
		color = "rbxassetid://104910921783241",
		normal = "rbxassetid://136495732888784",
		rough = "rbxassetid://111297776043868",
	},
	HexTile = {
		color = "rbxassetid://136549469775197",
		normal = "rbxassetid://139082524317929",
		rough = "rbxassetid://87287121441953",
	},
	Concrete = {
		color = "rbxassetid://84827151910253",
		normal = "rbxassetid://74118763493686",
		rough = "rbxassetid://132050042091744",
	},
	-- New in V4a: the cellar's brick, rough boards (attic floors, cellar and attic
	-- ceilings), bathroom wall tile, flagstones, quarry tile, the clapboard
	-- outside, the drive's gravel.
	Brick = {
		color = "rbxassetid://85353285415307",
		normal = "rbxassetid://93343049000370",
		rough = "rbxassetid://79319155697674",
	},
	RoughBoards = {
		color = "rbxassetid://140260182940873",
		normal = "rbxassetid://87863503248156",
		rough = "rbxassetid://136857957936167",
	},
	BathTile = {
		color = "rbxassetid://112947527965000",
		normal = "rbxassetid://97666152951757",
		rough = "rbxassetid://90910202302060",
	},
	Flagstone = {
		color = "rbxassetid://99937968686550",
		normal = "rbxassetid://74362245319520",
		rough = "rbxassetid://116028594845275",
	},
	QuarryTile = {
		color = "rbxassetid://84955444444785",
		normal = "rbxassetid://83232043240335",
		rough = "rbxassetid://99405401577688",
	},
	-- (Redrawn and uploaded again 2026-10-15, its peeling paint scattered
	-- evenly: one big patch repeated tile by tile read as a stamp.)
	Clapboard = {
		color = "rbxassetid://73823839011190",
		normal = "rbxassetid://113742807893355",
		rough = "rbxassetid://89591082180907",
	},
	Gravel = {
		color = "rbxassetid://99849356467908",
		normal = "rbxassetid://83756498519809",
		rough = "rbxassetid://110774701402121",
	},
	-- The golden area's surfaces (the visual rework V3; tools/textures.py, ONLY=golden),
	-- uploaded by the owner's import of kit.py golden2 (on its swatches), each with a
	-- roughness map of its own.
	Damask = {
		color = "rbxassetid://117970108473050",
		normal = "rbxassetid://91542375873880",
		rough = "rbxassetid://136342603443370",
	},
	FloralStripe = {
		color = "rbxassetid://133532414792551",
		normal = "rbxassetid://103833348594909",
		rough = "rbxassetid://82640829423827",
	},
	Parquet = {
		color = "rbxassetid://106099641586986",
		normal = "rbxassetid://132229840322224",
		rough = "rbxassetid://80419864582955",
	},
}

-- Grime decals, one shared set so the whole house ages the same way.
Assets.Grime = {
	WaterStain = "rbxassetid://91472851924184",
	RustStreak = "rbxassetid://97626397773359",
	Scuffs = "rbxassetid://133627015851658",
	PictureGhost = "rbxassetid://91613317867163",
}

-- The Guest's porcelain mask (Lib/GuestFace), drawn by tools/textures.py
-- (guest_masks) and uploaded 2026-10-07 with the owner's OK: a decal on the
-- mask's front, under the eyes, brows and mouth. Calm; worn at Fraying;
-- broken at Breaking (the owner: "even more cracked and fucked up").
Assets.GuestMask = {
	calm = "rbxassetid://118378389246082",
	worn = "rbxassetid://82781140864416",
	broken = "rbxassetid://134283397249825",
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
