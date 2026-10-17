-- Roblox's immersive ads in the lobby mall (LB6; docs/plans/lobby-rework.md,
-- "Immersive ads"; the owner: "ads in places you might actually see ads
-- inside of a mall"): where a frame may hang, whether its AdGui goes up, and
-- what a player sees in it. Engine-free: Data/Mall `Ads` holds the frames,
-- Data/Posters our own 1988 posters, Config.Ads the numbers.

local Ads = {}

-- A frame's kind: a backlit lightbox (image ads), a video store's film
-- poster frame (image ads), or a screen (video ads too).
Ads.Kinds = { lightbox = true, film = true, screen = true }

function Ads.kind(slot): string
	return slot.kind or "lightbox"
end

-- Whether a face this size can carry an ad: Roblox serves one only to a face
-- between 8 x 4.5 and 32 x 18 studs (Creator Docs, Immersive ads), and the
-- ad scales to the face, so it stays near 16:9.
function Ads.fits(w: number, h: number, cfg): boolean
	if w < cfg.MinSize[1] or h < cfg.MinSize[2] or w > cfg.MaxSize[1] or h > cfg.MaxSize[2] then
		return false
	end
	local aspect = w / h
	return aspect >= cfg.Aspect[1] and aspect <= cfg.Aspect[2]
end

-- Whether a room may hold a frame: only where a mall really had ads (never
-- the garage, the arcade's machines, the boutique's booth, or the run).
function Ads.allowedIn(room: string, cfg): boolean
	return cfg.Rooms[room] == true
end

-- What's wrong with the mall's frames, for a test to show; none for good
-- ones. `mall` is Data/Mall, `posters` Data/Posters.
function Ads.problems(mall, posters, cfg): { string }
	local found = {}
	local seen = {}
	local waiting = {}
	for _, room in (mall.Waiting and mall.Waiting.rooms) or {} do
		waiting[room] = true
	end
	for i, slot in mall.Ads or {} do
		local name = slot.slot or ("frame " .. i)
		local kind = Ads.kind(slot)
		if not slot.slot then
			table.insert(found, name .. " has no slot name")
		elseif seen[slot.slot] then
			table.insert(found, name .. " is named twice")
		end
		seen[name] = true
		if not Ads.Kinds[kind] then
			table.insert(found, string.format("%s is an unknown kind, %s", name, kind))
		end
		if not Ads.fits(slot.w, slot.h, cfg) then
			table.insert(found, string.format("%s's face, %g x %g, can't carry an ad", name, slot.w, slot.h))
		end
		if not Ads.allowedIn(slot.room, cfg) then
			table.insert(found, string.format("%s is in the %s, where a mall had no ads", name, slot.room))
		end
		if waiting[slot.room] then
			table.insert(found, string.format("%s is in a run server's waiting room", name))
		end
		if not (slot.poster and posters.Posters[slot.poster]) then
			table.insert(found, string.format("%s has no poster of ours", name))
		end
		if slot.video and kind ~= "screen" then
			-- A backlit poster never moves: video belongs on a screen.
			table.insert(found, string.format("%s plays video but isn't a screen", name))
		end
		if not (posters.Blank and posters.Blank[kind]) then
			table.insert(found, string.format("%s has no blank for its kind", name))
		end
	end
	return found
end

-- The image id of a frame's poster, or nil until it's uploaded.
function Ads.image(slot, posters): string?
	local poster = slot.poster and posters.Posters[slot.poster]
	local image = poster and poster.image
	if type(image) == "string" and image ~= "" then
		return image
	end
	return nil
end

-- Whether a frame's AdGui goes up: the owner's switch on, and its own poster
-- uploaded. An ad unit with no ad to show shows its FallbackImage, or
-- Roblox's grey card without one, so it waits for ours.
function Ads.serving(slot, posters, cfg): boolean
	return cfg.Serve == true and Ads.image(slot, posters) ~= nil
end

-- What one player sees in a frame: "ad" (its AdGui: an ad, or our poster
-- while none runs) or "poster" (ours, drawn on the face). `allowed` is
-- PolicyService's AreAdsAllowed for them, nil when it couldn't be read: the
-- AdGui then stays, since Roblox shows its fallback, our poster, to anyone
-- it can't show ads to.
function Ads.show(serving: boolean, allowed: boolean?): string
	if serving and allowed ~= false then
		return "ad"
	end
	return "poster"
end

return Ads
