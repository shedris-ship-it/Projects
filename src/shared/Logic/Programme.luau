-- The adventure picks the rooms (docs/plans/level-design.md section 5.4).
-- Before any room is placed, a run draws its adventure deck: the kinds of
-- lock and keeper it wants (the computer's padlock, the fuse box, the safe,
-- the music box, a crank door, the dumbwaiter), a few, different ones. Then
-- the room list: first the rooms the deck needs (a desk for the computer, a
-- piano for the music box), then rooms with something in them to go for (a
-- landmark, a lure) ahead of plain ones, within each template's limits.
-- Logic/MansionGen places the list in order (a room that fits nowhere drops
-- out); Logic/LockPlanner favours the deck's kinds. Pure.

local LockPlanner = require(script.Parent.LockPlanner)

local Programme = {}

-- Which rooms each kind of the deck needs: a template id, or nil when every
-- house already has one (a service room for the fuse box, a homely room for
-- the safe, the service corridor for the dumbwaiter, any door for a crank).
Programme.Needs = {
	padlock = "study", -- the computer stands on its desk
	musicbox = "music_room", -- its tune is played back on the piano
}

-- The deck: `count` different kinds, drawn by weight among those switched on.
function Programme.deck(rng, cfg, enabled, count: number): { [string]: boolean }
	local options = {}
	for _, kind in cfg.Kinds do
		if enabled[kind] and (cfg.Weights[kind] or 0) > 0 then
			table.insert(options, kind)
		end
	end
	local deck = {}
	for _ = 1, math.min(count, #options) do
		local pick = rng:WeightedPick(options, function(kind)
			return cfg.Weights[kind]
		end)
		deck[pick] = true
		table.remove(options, table.find(options, pick))
	end
	return deck
end

-- Whether a template has something to go for by itself (a landmark or a lure).
function Programme.draws(template): boolean
	local offers = LockPlanner.offers(template, true)
	return offers.landmark or offers.lure
end

-- The room list for each storey: { [0] = { template ids }, [1] = { ... },
-- [-1] = the cellar's, [2] = the attic's }, needed rooms first, then a
-- weighted order (template weight, more for rooms with a draw), never more of
-- a template than its `max`, or on one floor than its `perFloor`.
function Programme.rooms(rng, general, deck, cfg)
	local floors = { [-1] = {}, [0] = {}, [1] = {}, [2] = {} }
	local counts, perFloor = {}, { [-1] = {}, [0] = {}, [1] = {}, [2] = {} }
	local function fits(template, floor: number): boolean
		local m = template.mansion
		return table.find(m.floors, floor) ~= nil
			and (counts[template.id] or 0) < (m.max or 1)
			and (perFloor[floor][template.id] or 0) < (m.perFloor or math.huge)
	end
	local function add(template, floor: number)
		table.insert(floors[floor], template.id)
		counts[template.id] = (counts[template.id] or 0) + 1
		perFloor[floor][template.id] = (perFloor[floor][template.id] or 0) + 1
	end
	local byId = {}
	for _, template in general do
		byId[template.id] = template
	end
	-- What the deck needs, on the first floor it can stand on.
	local needed = {}
	for _, kind in cfg.Kinds do
		local id = deck[kind] and Programme.Needs[kind]
		if id and byId[id] and not table.find(needed, id) then
			table.insert(needed, id)
		end
	end
	for _, id in needed do
		local template = byId[id]
		for _, floor in template.mansion.floors do
			if fits(template, floor) then
				add(template, floor)
				break
			end
		end
	end
	-- The rest, in a weighted order per floor (long enough for any quota):
	-- the main floors first, then the cellar and the attic.
	for _, floor in { 0, 1, -1, 2 } do
		while true do
			local options = {}
			for _, template in general do
				if fits(template, floor) then
					table.insert(options, template)
				end
			end
			if #options == 0 then
				break
			end
			local pick = rng:WeightedPick(options, function(t)
				return (t.mansion.weight or 1) * (Programme.draws(t) and cfg.DrawBonus or 1)
			end)
			add(pick, floor)
		end
	end
	return floors
end

-- The whole programme: { deck, floors }.
function Programme.draw(rng, general, cfg, enabled, squad: number?)
	local count = cfg.DeckSize[math.clamp(squad or #cfg.DeckSize, 1, #cfg.DeckSize)]
	local deck = Programme.deck(rng:Fork("deck"), cfg, enabled, count)
	return { deck = deck, floors = Programme.rooms(rng:Fork("rooms"), general, deck, cfg) }
end

return Programme
