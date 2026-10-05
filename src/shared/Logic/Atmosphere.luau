-- Each Witness's own unsettling moments (owner, 2026-10-04: divergence stays
-- as atmosphere only, never as something to solve; docs/plans/
-- gameplay-rework.md section 2). The server sends each client a few
-- perception rules and the client applies them to its own copy of the house
-- (Controllers/PerceptionController), so friends genuinely see slightly
-- different houses: a portrait's eyes that follow only you, words in your
-- own torch beam, a door slamming that only you heard, a friend you glimpse
-- a moment late, an ornament in a colour nobody else saw.
--
-- Pure (tests/specs/Atmosphere.spec). The promise it keeps: nothing here
-- touches anything you play with. It only ever targets portraits, bare wall
-- spots, floor spots and fixed furniture it is handed; never a door, an
-- item, a note, a puzzle station, the table or anything you can carry or
-- push. No fake walls or doorways, no phantom objects, and no figure: the
-- only Guest you see is the real one (owner, 2026-10-03).
--
-- input = {
--   players    sorted player ids (strings)
--   portraits  { { id, position } }       the house's portraits (CIds)
--   walls      { { position, normal } }   free wall spots for writing
--   fixed      { { id } }                 fixed furniture that may change colour
--   floor      { { position } }           free floor spots for sounds and ghosts
--   content    Data/Atmosphere
--   config     Config.Atmosphere
--   rng        a Lib/Rng
-- }
-- Positions and normals are { x, y, z } tables so this runs outside Roblox.
-- Returns { profiles = { [playerId] = { rules } } }; a rule is
-- { id, kind, target, minDrift, params }.

local Atmosphere = {}

-- The only kinds this may ever make (the client has a handler for each).
Atmosphere.Kinds = {
	PortraitEyes = true,
	HiddenWriting = true,
	PhantomSound = true,
	GhostTrail = true,
	Recolor = true,
}

function Atmosphere.plan(input)
	local rng, cfg, content = input.rng, input.config, input.content
	local players = input.players
	local profiles = {}
	for _, id in players do
		profiles[id] = {}
	end
	local serial = 0
	local function add(playerId, kind, target, minDrift, params)
		serial += 1
		table.insert(profiles[playerId], {
			id = "atmo:" .. serial,
			kind = kind,
			target = target,
			minDrift = minDrift,
			params = params or {},
		})
	end

	local portraits = rng:Shuffle(table.clone(input.portraits or {}))
	local walls = rng:Shuffle(table.clone(input.walls or {}))
	local fixed = rng:Shuffle(table.clone(input.fixed or {}))
	local floor = rng:Shuffle(table.clone(input.floor or {}))
	local writing = rng:Shuffle(table.clone(content.Writing))
	local colors, sounds = content.Colors, content.Sounds
	local nextFloor = 1
	local function takeFloor()
		local spot = floor[nextFloor]
		nextFloor += 1
		return spot
	end

	for index, id in players do
		-- An ornament in a colour only you see, from the first second.
		local prop = fixed[index]
		if prop then
			add(id, "Recolor", prop.id, 0, { color = rng:Pick(colors) })
		end
		-- A portrait whose eyes follow you, a different one for each Witness
		-- while there are enough.
		if #portraits > 0 then
			local portrait = portraits[(index - 1) % #portraits + 1]
			add(id, "PortraitEyes", portrait.id, cfg.EyesMinDrift)
		end
		-- Words on a wall in your torch beam.
		local wall = walls[index]
		if wall then
			add(id, "HiddenWriting", "atmo:writing:" .. index, cfg.WritingMinDrift, {
				position = wall.position,
				normal = wall.normal,
				text = writing[(index - 1) % #writing + 1],
			})
		end
		-- A sound from where nothing made it.
		local spot = takeFloor()
		if spot then
			add(id, "PhantomSound", "atmo:sound:" .. index, cfg.SoundMinDrift, {
				sound = rng:Pick(sounds),
				position = spot.position,
				ambient = true,
			})
		end
	end

	-- With company: you glimpse a friend where they were a moment ago.
	if #players >= 2 then
		for index, id in players do
			local spot = takeFloor()
			if spot then
				local subject = players[index % #players + 1]
				add(id, "GhostTrail", "atmo:ghost:" .. index, cfg.GhostMinDrift, {
					subject = subject,
					position = spot.position,
				})
			end
		end
	end
	return { profiles = profiles }
end

return Atmosphere
