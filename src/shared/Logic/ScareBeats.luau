-- Scares he sets up on purpose (the squad playtest, 2026-10-08: "guest needs
-- to deliberately scare people and give people reasons to be afraid"). Now
-- and then, between hunts, he picks the player he has frightened least
-- lately and stages something for them alone: he's behind you when you turn
-- round, he's closer when the lights come back, or his hand is at your
-- shoulder. None of it ever downs anyone; the hunts and crowding him do that
-- (StalkerService:_beat). Pure (tests/specs/ScareBeats.spec).

local ScareBeats = {}

ScareBeats.Kinds = { "behind", "dark", "hand" }

-- Who gets the next one: the player scared longest ago, if that's at least
-- cfg.BeatGap seconds, and nobody protected. players: { { id, scaredAt
-- (time or nil), hidden, graced, safeRoom, nearDown (a down near them
-- within cfg.BeatDownGap) } }. Returns the chosen entry or nil.
function ScareBeats.pick(players, now: number, cfg)
	local best, bestAt = nil, math.huge
	for _, p in players do
		local at = p.scaredAt or -math.huge
		if not p.hidden and not p.graced and not p.safeRoom and not p.nearDown and now - at >= cfg.BeatGap then
			if at < bestAt then
				best, bestAt = p, at
			end
		end
	end
	return best
end

-- Which beat, weighted by what fits: `canBehind` (room behind them, unseen),
-- `canDark` (he's in their sight now, close enough to come closer).
function ScareBeats.kind(canBehind: boolean, canDark: boolean, roll: number): string?
	local options = {}
	if canDark then
		table.insert(options, "dark")
	end
	if canBehind then
		table.insert(options, "behind")
		table.insert(options, "hand")
	end
	if #options == 0 then
		return nil
	end
	return options[math.clamp(math.floor(roll * #options) + 1, 1, #options)]
end

return ScareBeats
