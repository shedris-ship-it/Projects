-- Chooses which tells a run spawns (doc section 3): 3-4 true tells from the
-- anomaly plus 1-2 red herrings borrowed from other anomalies, preferring
-- tells on the same perception channels. The true tells must be deducible:
-- any three of them leave at most two suspects on the Case Board, and at
-- least one can be confirmed with the Witness Camera.

local CaseBoard = require(script.Parent.CaseBoard)

local EvidencePlanner = {}

local function hasCameraTell(tellIds, tells): boolean
	for _, id in tellIds do
		if tells[id].camera then
			return true
		end
	end
	return false
end

local function usable(tell, squadSize: number): boolean
	return (tell.minPlayers or 1) <= squadSize
end

-- options: { trueTells = {min, max}, redHerrings = {min, max},
--            maxSuspects = 2, squadSize = n }
function EvidencePlanner.plan(anomaly, anomalyList, tells, rng, options)
	local squadSize = options.squadSize or 1
	local candidates = {}
	for _, id in anomaly.tells do
		if usable(tells[id], squadSize) then
			table.insert(candidates, id)
		end
	end
	assert(#candidates >= 3, anomaly.id .. " has fewer than three usable tells")

	local count = math.min(rng:NextInteger(options.trueTells[1], options.trueTells[2]), #candidates)
	local chosen = nil
	for _ = 1, 60 do
		local subset = rng:Sample(candidates, count)
		local worst = CaseBoard.worstCaseSuspects(anomalyList, subset, 3)
		if worst <= options.maxSuspects and hasCameraTell(subset, tells) then
			chosen = subset
			break
		end
	end
	if chosen == nil then
		-- Deterministic fallback: the camera tell first, then the rest in order.
		chosen = {}
		for _, id in candidates do
			if tells[id].camera and #chosen == 0 then
				table.insert(chosen, id)
			end
		end
		for _, id in candidates do
			if #chosen >= count then
				break
			end
			if not table.find(chosen, id) then
				table.insert(chosen, id)
			end
		end
	end
	table.sort(chosen)

	-- Red herrings: tells this anomaly never produces, same channel first.
	local channels = {}
	for _, id in chosen do
		channels[tells[id].channel] = true
	end
	local sameChannel, otherChannel = {}, {}
	local ids = {}
	for id in tells do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local tell = tells[id]
		if not table.find(anomaly.tells, id) and usable(tell, squadSize) then
			if channels[tell.channel] then
				table.insert(sameChannel, id)
			else
				table.insert(otherChannel, id)
			end
		end
	end
	rng:Shuffle(sameChannel)
	rng:Shuffle(otherChannel)
	local herringCount = rng:NextInteger(options.redHerrings[1], options.redHerrings[2])
	local herrings = {}
	for _, pool in { sameChannel, otherChannel } do
		for _, id in pool do
			if #herrings >= herringCount then
				break
			end
			table.insert(herrings, id)
		end
	end
	table.sort(herrings)

	return {
		trueTells = chosen,
		redHerrings = herrings,
	}
end

return EvidencePlanner
