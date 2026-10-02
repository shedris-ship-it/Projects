-- Verdict rules (doc section 6): squads of one or two must be unanimous; at
-- three or four, a majority carries once debate has run past 90 seconds so
-- one stubborn player can't stall the run while Drift climbs.

local Verdict = {}

-- votes: { [voterId] = anomalyId }, voterCount: eligible voters.
-- Returns status ("pending" | "decided" | "deadlock"), choice, tally.
function Verdict.evaluate(votes, voterCount: number, elapsed: number, config)
	local tally = {}
	local cast = 0
	for _, choice in votes do
		tally[choice] = (tally[choice] or 0) + 1
		cast += 1
	end
	local leader, leaderVotes, tie = nil, 0, false
	local choices = {}
	for choice in tally do
		table.insert(choices, choice)
	end
	table.sort(choices)
	for _, choice in choices do
		local n = tally[choice]
		if n > leaderVotes then
			leader, leaderVotes, tie = choice, n, false
		elseif n == leaderVotes then
			tie = true
		end
	end

	if voterCount <= 0 then
		return "deadlock", nil, tally
	end
	if leader and leaderVotes == voterCount then
		return "decided", leader, tally
	end
	if voterCount >= 3 and elapsed >= config.VerdictMajorityAfter and leader and not tie then
		if leaderVotes > voterCount / 2 then
			return "decided", leader, tally
		end
	end
	if elapsed >= config.VerdictWindow then
		return "deadlock", nil, tally
	end
	return "pending", nil, tally, cast
end

return Verdict
