-- Our own 1988 posters for the lobby mall's ad frames (LB6; Data/Mall
-- `Ads`, Logic/Ads): what a frame shows a player who can't be shown ads, and
-- what its ad unit shows while no ad runs (the AdGui's FallbackImage), so the
-- mall looks the same to everyone. The mall's own ads from the year it died,
-- still in their lightboxes; the video store's last COMING SOON; a TV off the
-- air. The owner kept all seven (none names a map or a real brand).
--
-- Drawn from code, seeded, by tools/posters.py into assets/posters/ (1024 x
-- 576, 16:9). `image`: the uploaded id (the seven kept as drawn and uploaded
-- with the owner's OK, 2026-10-16). A poster without one shows its lit
-- blank (`Blank`), and its frame gets no AdGui (Logic/Ads.serving).

local Posters = {}

Posters.Posters = {
	-- the court's lightboxes: the mall's own ads
	Mayfields = {
		file = "mayfields.jpg",
		image = "rbxassetid://117963762996495",
		says = "MAYFIELD'S: everything must go",
	},
	PineHollow = {
		file = "pine_hollow.jpg",
		image = "rbxassetid://74633721390556",
		says = "Pine Hollow Estates: a home that grows with you",
	},
	Portraits = {
		file = "portraits.jpg",
		image = "rbxassetid://72845488951023",
		says = "Portraits by Lorraine, second floor",
	},
	SparkleCola = {
		file = "sparkle_cola.jpg",
		image = "rbxassetid://132174375950759",
		says = "Sparkle Cola: home in time for dinner",
	},
	-- the video store's COMING SOON
	DontLookAway = {
		file = "dont_look_away.jpg",
		image = "rbxassetid://94939229828620",
		says = "DON'T LOOK AWAY, on videocassette",
	},
	Suppertime = {
		file = "suppertime.jpg",
		image = "rbxassetid://114130845497556",
		says = "SUPPERTIME, on videocassette",
	},
	-- the electronics window's big screen
	StandBy = { file = "stand_by.jpg", image = "rbxassetid://104424610100210", says = "Colour bars: PLEASE STAND BY" },
}

-- A frame's lit blank, by kind, until its poster is uploaded: what an empty
-- frame in a dead mall shows (World/AdPoster draws it).
Posters.Blank = {
	lightbox = { big = "THIS SPACE\nAVAILABLE", small = "LEASING · ENQUIRE AT THE MALL OFFICE" },
	film = { big = "NEW TITLES\nEVERY FRIDAY", small = "RESERVE YOURS AT THE COUNTER" },
	screen = { bars = true, big = "PLEASE STAND BY" },
}

return Posters
