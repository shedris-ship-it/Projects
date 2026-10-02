-- Case Board deduction (doc section 3: "naming the anomaly is an elimination
-- puzzle, not a guess"). Pure functions over anomaly data.

local CaseBoard = {}

-- Anomalies whose tell list contains every confirmed tell.
function CaseBoard.suspects(anomalyList, confirmedTellIds: { string }): { string }
	local result = {}
	for _, anomaly in anomalyList do
		local all = true
		for _, tellId in confirmedTellIds do
			if not table.find(anomaly.tells, tellId) then
				all = false
				break
			end
		end
		if all then
			table.insert(result, anomaly.id)
		end
	end
	return result
end

-- For every subset of `size` tells drawn from `tells`, the worst-case number
-- of suspects. Used to check that any three confirmed tells narrow the field.
function CaseBoard.worstCaseSuspects(anomalyList, tells: { string }, size: number): number
	local worst = 0
	local chosen = {}
	local function visit(startIndex: number)
		if #chosen == size then
			worst = math.max(worst, #CaseBoard.suspects(anomalyList, chosen))
			return
		end
		for i = startIndex, #tells do
			table.insert(chosen, tells[i])
			visit(i + 1)
			table.remove(chosen)
		end
	end
	if #tells < size then
		return #CaseBoard.suspects(anomalyList, tells)
	end
	visit(1)
	return worst
end

-- Rank anomalies by how many of the claimed (unconfirmed) tells they match,
-- among the anomalies still consistent with the confirmed tells. Used as a
-- soft hint on the board for squads relying on solo reports.
function CaseBoard.rankByClaims(anomalyList, confirmedTellIds: { string }, claimedTellIds: { string })
	local suspects = CaseBoard.suspects(anomalyList, confirmedTellIds)
	local byId = {}
	for _, anomaly in anomalyList do
		byId[anomaly.id] = anomaly
	end
	local ranking = {}
	for _, id in suspects do
		local matches = 0
		for _, tellId in claimedTellIds do
			if table.find(byId[id].tells, tellId) then
				matches += 1
			end
		end
		table.insert(ranking, { id = id, matches = matches })
	end
	table.sort(ranking, function(a, b)
		if a.matches ~= b.matches then
			return a.matches > b.matches
		end
		return byId[a.id].index < byId[b.id].index
	end)
	return ranking
end

return CaseBoard
