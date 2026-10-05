-- The Guest wants his dinner (docs/plans/gameplay-rework.md, R2c): the
-- heirlooms are his, and he always knows roughly where one is while someone
-- carries it. A declared rule, not a wallhack: every pickup is cued (a chair
-- scrapes at the table, a faint music box from the heirloom itself), and the
-- squad learns it plays as an escort. He learns the carrier's room, not the
-- spot. Hiding pauses it; drop it and he loses it a few seconds later.
--
-- Pure (tests/specs/Scent.spec). Each heirloom is
--   { holder? (a player), hidden? (the holder is hiding), droppedAt?,
--     lastHolder?, position, set? (laid at the table) }
-- and Scent.targets answers what he senses now: a list of
-- { player, position } (the position is where to place his memory: the
-- carrier's, or where it was dropped).

local Scent = {}

function Scent.targets(heirlooms, now: number, cfg)
	local out = {}
	for _, h in heirlooms do
		if h.set then
			continue
		end
		if h.holder then
			if not h.hidden then
				table.insert(out, { player = h.holder, position = h.position })
			end
		elseif h.droppedAt and h.lastHolder and now - h.droppedAt < cfg.Linger then
			-- Just let go: for a moment he still knows where it is.
			table.insert(out, { player = h.lastHolder, position = h.position })
		end
	end
	return out
end

-- Is this player carrying one right now (a hunt's favourite target)?
function Scent.carrying(heirlooms, player): boolean
	for _, h in heirlooms do
		if h.holder == player and not h.set then
			return true
		end
	end
	return false
end

-- Has the squad got hold of every heirloom still to set (each carried by
-- someone)? Then he goes to wait at the table.
function Scent.allInHand(heirlooms): boolean
	local left = 0
	for _, h in heirlooms do
		if not h.set then
			left += 1
			if not h.holder then
				return false
			end
		end
	end
	return left > 0
end

-- Should he go and put this one back? Lying (not carried, not set) for long
-- enough, and nobody near it.
function Scent.wantsTidy(h, now: number, nearestPlayer: number, cfg): boolean
	return not h.set
		and not h.holder
		and h.droppedAt ~= nil
		and now - h.droppedAt >= cfg.TidySeconds
		and nearestPlayer >= cfg.TidyClear
end

return Scent
