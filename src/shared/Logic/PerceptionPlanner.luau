-- Builds each Witness's perception profile (doc section 3 and 7): the server
-- sends rules, not world state, and each client applies its own rules to its
-- own copy of the house.
--
-- Guarantees:
--   * every social tell is perceived differently by at least two Witnesses
--     (when the squad has two or more), so comparing notes reveals it;
--   * every Witness has at least one divergence a teammate can disprove;
--   * no rule ever changes collision in a way that can trap someone: fake
--     walls are visual only (PerceptionController), phantom doors only open.
--
-- Positions are plain { x, y, z } tables so this module runs outside Roblox.

local PerceptionPlanner = {}

local CALIBRATION_COLORS = {
	{ 150, 40, 40 },
	{ 40, 90, 150 },
	{ 60, 120, 60 },
	{ 170, 150, 60 },
	{ 120, 60, 140 },
}

local PHANTOM_DECOR = { "Vase", "Chair", "Plant", "Stool" }

-- Split players into a perceiving subset. Social tells always leave at least
-- one Witness out so there is something to compare.
local function choosePerceivers(rng, playerIds, social: boolean)
	local n = #playerIds
	if n <= 1 then
		return table.clone(playerIds)
	end
	local maxCount = social and n - 1 or n
	local count = rng:NextInteger(1, maxCount)
	local shuffled = rng:Shuffle(table.clone(playerIds))
	local result = {}
	for i = 1, count do
		result[i] = shuffled[i]
	end
	table.sort(result)
	return result
end

-- input = {
--   players = { "userId", ... } (sorted),
--   names = { [userId] = displayName },
--   sites = { { id, tellId, position, normal?, seamId?, roomId } },
--   calibrationProps = { { id, position } },   -- real props safe to recolour
--   floorSpots = { { position, roomId } },      -- spots for harmless phantoms
--   seams = { { id, connected } },              -- seams not used by any site
--   tells = Data.Tells, config = Config.Divergence, rng = Rng,
-- }
function PerceptionPlanner.plan(input)
	local rng = input.rng
	local tells = input.tells
	local config = input.config
	local players = input.players
	local profiles = {}
	for _, id in players do
		profiles[id] = {}
	end
	local perceivers = {}
	local truths = {}
	local extraTargets = {}
	local nextRule = 0

	local function addRule(playerId, kind, target, minDrift, params)
		nextRule += 1
		table.insert(profiles[playerId], {
			id = "r" .. nextRule,
			kind = kind,
			target = target,
			minDrift = minDrift,
			params = params or {},
		})
	end

	-- Tell sites ----------------------------------------------------------
	for _, site in input.sites do
		local tell = tells[site.tellId]
		local presentation = tell.presentation
		if (tell.minPlayers or 1) > #players and tell.fallback then
			tell = tells[tell.fallback]
			presentation = tell.presentation
		end

		if presentation == "VariantProp" then
			local variants = table.clone(tell.variants)
			if tell.useSquadNames and #players >= 2 then
				variants = {}
				for _, id in players do
					table.insert(variants, string.upper(input.names[id] or id))
				end
				table.insert(variants, "UNKNOWN")
			end
			local picks = rng:Sample(variants, math.min(3, #variants))
			local truth = picks[1]
			truths[site.id] = truth
			local groupA = choosePerceivers(rng, players, true)
			local valueA = picks[2]
			local valueB = picks[3] or truth
			local seen = {}
			for _, id in players do
				local inA = table.find(groupA, id) ~= nil
				local value = inA and valueA or valueB
				addRule(id, "VariantProp", site.id, 0, {
					model = tell.model,
					value = value,
					truth = truth,
					-- A lone Witness has nobody to compare with, so the
					-- object visibly shifts between states while unwatched.
					shift = #players == 1,
					position = site.position,
					normal = site.normal,
				})
				if value ~= truth then
					table.insert(seen, id)
				end
			end
			perceivers[site.id] = seen
		elseif presentation == "GhostTrail" or presentation == "HiddenTeammate" then
			local order = rng:Shuffle(table.clone(players))
			local viewer, subject = order[1], order[2]
			addRule(viewer, presentation, site.id, 0, { subject = subject, position = site.position })
			perceivers[site.id] = { viewer }
		else
			local who = choosePerceivers(rng, players, tell.social)
			perceivers[site.id] = who
			local params = {
				model = tell.model,
				sound = tell.sound,
				follow = tell.follow,
				position = site.position,
				normal = site.normal,
			}
			if presentation == "HiddenWriting" then
				params.text = rng:Pick(tell.variants)
			elseif presentation == "SeamFlip" then
				params.connected = site.connected == true
			end
			local target = site.seamId or site.id
			for _, id in who do
				addRule(id, presentation, target, 0, params)
			end
		end
	end

	-- Calibration: harmless, unique per Witness, live from the first second.
	local props = rng:Shuffle(table.clone(input.calibrationProps))
	local spots = rng:Shuffle(table.clone(input.floorSpots))
	local propIndex, spotIndex = 1, 1
	for _, id in players do
		for c = 1, config.CalibrationPerPlayer do
			if c % 2 == 1 and props[propIndex] then
				local prop = props[propIndex]
				propIndex += 1
				addRule(id, "Recolor", prop.id, 0, { color = rng:Pick(CALIBRATION_COLORS) })
			elseif spots[spotIndex] then
				local spot = spots[spotIndex]
				spotIndex += 1
				local target = "decor:" .. spotIndex
				extraTargets[target] = { position = spot.position, label = "Out-of-place object" }
				addRule(id, "PhantomDecor", target, 0, {
					model = rng:Pick(PHANTOM_DECOR),
					position = spot.position,
					facing = rng:NextInteger(0, 3) * 90,
				})
			end
		end
	end

	-- Useful objects (Drift 20+): doorways that are and aren't there.
	local seams = rng:Shuffle(table.clone(input.seams))
	local seamIndex = 1
	for _, id in players do
		local count = rng:NextInteger(config.UsefulObjectPerPlayer[1], config.UsefulObjectPerPlayer[2])
		for _ = 1, count do
			local seam = seams[seamIndex]
			if not seam then
				break
			end
			seamIndex += 1
			addRule(id, "SeamFlip", seam.id, config.UsefulObjectMinDrift, { connected = seam.connected })
		end
	end

	-- Mislocated sounds (Drift 40+).
	for _, id in players do
		local spot = spots[spotIndex]
		if spot then
			spotIndex += 1
			addRule(id, "PhantomSound", "sound:" .. spotIndex, config.SoundMinDrift, {
				sound = rng:Pick({ "Footsteps", "Knock", "DoorSlam" }),
				position = spot.position,
				ambient = true,
			})
		end
	end

	-- Rooms rearranging behind you (Drift 60+): a seam that flips while unwatched.
	for _, id in players do
		local seam = seams[seamIndex]
		if not seam then
			break
		end
		seamIndex += 1
		addRule(id, "SeamFlip", seam.id, config.RearrangeMinDrift, { connected = seam.connected, dynamic = true })
	end

	-- False consensus (Drift 80+): two Witnesses agree on something unreal.
	if #players >= 2 then
		local spot = spots[spotIndex]
		if spot then
			spotIndex += 1
			local pair = rng:Sample(players, 2)
			local target = "consensus:" .. spotIndex
			extraTargets[target] = { position = spot.position, label = "Still figure" }
			for _, id in pair do
				addRule(id, "PhantomDecor", target, config.FalseConsensusMinDrift, {
					model = "Figure",
					position = spot.position,
					facing = 0,
				})
			end
		end
	end

	return {
		profiles = profiles,
		perceivers = perceivers,
		truths = truths,
		targets = extraTargets,
	}
end

-- True if every player has at least one rule whose target some teammate
-- perceives differently. Used by tests and as a runtime sanity check.
function PerceptionPlanner.everyoneDisprovable(result, players): boolean
	if #players < 2 then
		return true
	end
	local byTarget = {}
	for playerId, rules in result.profiles do
		for _, rule in rules do
			byTarget[rule.target] = byTarget[rule.target] or {}
			byTarget[rule.target][playerId] = rule.params.value or true
		end
	end
	for _, playerId in players do
		local ok = false
		for _, rule in result.profiles[playerId] do
			for _, other in players do
				if other ~= playerId then
					local theirs = byTarget[rule.target][other]
					local mine = byTarget[rule.target][playerId]
					if theirs == nil or theirs ~= mine then
						ok = true
					end
				end
			end
		end
		if not ok then
			return false
		end
	end
	return true
end

return PerceptionPlanner
