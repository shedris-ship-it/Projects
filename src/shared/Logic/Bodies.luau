-- Players collide (the squad playtest, 2026-10-08: "add collision between
-- players"), but nobody can body-block a doorway (DesignDoc section 3's
-- griefing rule, the reason they passed through each other before). Two
-- players pressed together for a moment stop colliding with each other
-- ("ghost") until they've stepped apart; a downed or hidden player, and one
-- just moved by the game (out of a hiding place, squeezed past a barricade,
-- down the chute, revived), is never solid to anyone. Services/
-- PlayerStateService applies it to each root's collision group. Pure
-- (tests/specs/Bodies.spec).

local Bodies = {}

function Bodies.new()
	return { contact = {}, ghostUntil = {}, ghost = {}, now = 0 }
end

local function pairKey(a, b): string
	local sa, sb = tostring(a), tostring(b)
	if sa < sb then
		return sa .. "|" .. sb
	end
	return sb .. "|" .. sa
end

-- One step. bodies: { [id] = { position = Vector3, always = boolean? } }
-- (`always`: ghost no matter what). Returns { [id] = true } for the ghosts.
-- cfg: ContactRadius, ContactSeconds, GhostSeconds, ClearRadius.
function Bodies.step(state, bodies, dt: number, cfg)
	state.now += dt
	local now = state.now
	local ids = {}
	for id in bodies do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local touching = {}
	local nearest = {}
	for i = 1, #ids do
		local a = ids[i]
		local pa = bodies[a].position
		for j = i + 1, #ids do
			local b = ids[j]
			local pb = bodies[b].position
			local offset = pa - pb
			local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
			local apart = math.abs(offset.Y) > 4 and math.huge or flat
			nearest[a] = math.min(nearest[a] or math.huge, apart)
			nearest[b] = math.min(nearest[b] or math.huge, apart)
			if apart <= cfg.ContactRadius then
				local key = pairKey(a, b)
				touching[key] = true
				state.contact[key] = (state.contact[key] or 0) + dt
				if state.contact[key] >= cfg.ContactSeconds then
					-- Pressed together long enough: they give way to each other.
					state.ghostUntil[a] = now + cfg.GhostSeconds
					state.ghostUntil[b] = now + cfg.GhostSeconds
				end
			end
		end
	end
	for key in state.contact do
		if not touching[key] then
			state.contact[key] = nil
		end
	end
	local ghosts = {}
	for _, id in ids do
		local body = bodies[id]
		local ghost = body.always == true or now < (state.ghostUntil[id] or -math.huge)
		-- Once a ghost, solid again only clear of everyone (never inside a friend).
		if not ghost and state.ghost[id] and (nearest[id] or math.huge) < cfg.ClearRadius then
			ghost = true
		end
		if ghost then
			ghosts[id] = true
		end
	end
	for id in state.ghost do
		if not bodies[id] then
			state.ghostUntil[id] = nil
		end
	end
	state.ghost = ghosts
	return ghosts
end

return Bodies
