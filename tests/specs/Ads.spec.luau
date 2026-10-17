-- Roblox's immersive ads in the lobby mall (Logic/Ads over Data/Mall `Ads`
-- and Data/Posters): only where a mall had ads, sized as Roblox serves them,
-- up only once our own poster can stand in, and never to a player who can't
-- be shown ads.
return function(test, check, Shared, require)
	local Ads = require(Shared.Logic.Ads)
	local Mall = require(Shared.Data.Mall)
	local Posters = require(Shared.Data.Posters)
	local Config = require(Shared.Config)
	local cfg = Config.Ads

	test("every frame is one Roblox can serve, where a mall had ads", function()
		local problems = Ads.problems(Mall, Posters, cfg)
		check.equal(#problems, 0, table.concat(problems, "; "))
		local kinds = {}
		for _, slot in Mall.Ads do
			kinds[Ads.kind(slot)] = (kinds[Ads.kind(slot)] or 0) + 1
		end
		check.equal(kinds.lightbox, 4, "the court's four lightboxes")
		check.equal(kinds.film, 2, "the video store's two COMING SOON frames")
		check.equal(kinds.screen, 1, "the electronics window's big screen")
	end)

	test("never in the garage, the arcade, the boutique or the run", function()
		for _, room in { "garage", "arcade", "boutique", "diner", "concourse" } do
			check.truthy(not Ads.allowedIn(room, cfg), room)
		end
		for _, room in Mall.Waiting.rooms do
			check.truthy(not Ads.allowedIn(room, cfg), "a run server's waiting room, the " .. room)
		end
		local moved = table.clone(Mall)
		moved.Ads = { table.clone(Mall.Ads[1]) }
		moved.Ads[1].room = "garage"
		check.equal(#Ads.problems(moved, Posters, cfg), 2, "the garage: no ads, and it's the run's waiting room")
	end)

	test("a face Roblox can serve: its sizes, near 16:9", function()
		check.truthy(Ads.fits(8, 4.5, cfg), "the smallest")
		check.truthy(Ads.fits(32, 18, cfg), "the largest")
		check.truthy(Ads.fits(11, 6.2, cfg), "the court's wide boxes")
		check.truthy(not Ads.fits(7.9, 4.5, cfg), "too narrow")
		check.truthy(not Ads.fits(8, 4.4, cfg), "too short")
		check.truthy(not Ads.fits(33, 18, cfg), "too wide")
		check.truthy(not Ads.fits(16, 16, cfg), "square: the ad would stretch")
		check.truthy(not Ads.fits(18, 6, cfg), "a strip")
	end)

	test("the frames' faults are named", function()
		local bad = table.clone(Mall)
		local slot = table.clone(Mall.Ads[1])
		slot.video = true
		slot.poster = "Nothing"
		slot.w = 6
		bad.Ads = { slot, table.clone(Mall.Ads[1]) }
		local problems = Ads.problems(bad, Posters, cfg)
		local text = table.concat(problems, "; ")
		check.truthy(text:find("can't carry an ad", 1, true) ~= nil, "too small")
		check.truthy(text:find("no poster of ours", 1, true) ~= nil, "no poster")
		check.truthy(text:find("isn't a screen", 1, true) ~= nil, "video on a lightbox")
		check.truthy(text:find("named twice", 1, true) ~= nil, "the same slot twice")
	end)

	test("an AdGui goes up only once its poster can stand in", function()
		local slot = { slot = "s", poster = "Mayfields" }
		local none = { Posters = { Mayfields = { image = "" } } }
		local some = { Posters = { Mayfields = { image = "rbxassetid://1" } } }
		check.truthy(not Ads.serving(slot, none, { Serve = true }), "no image yet: the lit blank, never Roblox's card")
		check.truthy(Ads.serving(slot, some, { Serve = true }), "uploaded: up")
		check.truthy(not Ads.serving(slot, some, { Serve = false }), "the owner's switch off")
		check.equal(Ads.image(slot, some), "rbxassetid://1", "its fallback image")
		check.equal(Ads.image(slot, none), nil, "none")
		check.equal(Ads.image({ slot = "x" }, some), nil, "a frame with no poster")
	end)

	test("each player sees the ad, or our poster in its place", function()
		check.equal(Ads.show(true, true), "ad", "allowed: the AdGui")
		check.equal(Ads.show(true, false), "poster", "not allowed: ours instead")
		check.equal(Ads.show(true, nil), "ad", "unknown: the AdGui, which shows ours to anyone it can't serve")
		check.equal(Ads.show(false, true), "poster", "no AdGui up: ours for everyone")
		check.equal(Ads.show(false, false), "poster", "and for anyone")
	end)

	test("every poster has its drawing and an id, and every kind a blank", function()
		for name, poster in Posters.Posters do
			check.truthy(type(poster.file) == "string" and poster.file:match("%.jpg$") ~= nil, name .. "'s file")
			check.equal(type(poster.image), "string", name .. "'s id is a string")
		end
		for kind in Ads.Kinds do
			check.truthy(Posters.Blank[kind] ~= nil, kind .. " has a blank")
		end
	end)
end
