-- Utility scoring for the Tactician (doc section 5). Each tactic's score is
-- base weight x habit signal x feasibility x archetype weight; the stalker
-- then picks among the top three at random so it is never fully predictable.

local UtilityAI = {}

function UtilityAI.score(tactic, signals, feasibility: number, archetypeWeight: number?): number
	if feasibility <= 0 then
		return 0
	end
	local signal = tactic.signal and (signals[tactic.signal] or 0) or 0.5
	return tactic.base * (0.4 + 1.2 * signal) * feasibility * (archetypeWeight or 1)
end

-- tactics: Data/Tactics list. feasibility: id -> 0..1 (missing = 0).
-- lastUsed: id -> time. Returns chosen id and the scored list (for logs).
function UtilityAI.choose(tactics, signals, feasibility, lastUsed, now: number, rng, archetypeWeights, topN: number?)
	local scored = {}
	for _, tactic in tactics do
		local f = feasibility[tactic.id] or 0
		local last = lastUsed[tactic.id]
		if last and now - last < tactic.cooldown then
			f = 0
		end
		local score = UtilityAI.score(tactic, signals, f, archetypeWeights and archetypeWeights[tactic.id])
		if score > 0 then
			table.insert(scored, { id = tactic.id, score = score })
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.id < b.id
	end)
	if #scored == 0 then
		return nil, scored
	end
	local top = {}
	for i = 1, math.min(topN or 3, #scored) do
		top[i] = scored[i]
	end
	local pick = rng:WeightedPick(top, function(entry)
		return entry.score
	end)
	return pick.id, scored
end

return UtilityAI
