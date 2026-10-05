-- Each Witness's own unsettling moments (Logic/Atmosphere): atmosphere only,
-- never on anything you play with.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rng = require(Shared.Lib.Rng)
	local Content = require(Shared.Data.Atmosphere)
	local Atmosphere = require(Shared.Logic.Atmosphere)

	local function input(players, seed)
		local walls, floor = {}, {}
		for i = 1, 12 do
			table.insert(walls, { position = { x = i, y = 5, z = 0 }, normal = { x = 0, y = 0, z = 1 } })
			table.insert(floor, { position = { x = i, y = 0, z = 4 } })
		end
		return {
			players = players,
			portraits = {
				{ id = "portrait:1", position = { x = 0, y = 6, z = 0 } },
				{ id = "portrait:2", position = { x = 9, y = 6, z = 0 } },
			},
			walls = walls,
			fixed = { { id = "3:sink" }, { id = "5:counter" }, { id = "8:bathtub" } },
			floor = floor,
			content = Content,
			config = Config.Atmosphere,
			rng = Rng.new(seed or 7),
		}
	end

	test("only harmless kinds, and only on what it was handed", function()
		for seed = 1, 40 do
			local given = input({ "1", "2", "3", "4" }, seed)
			local allowed = { ["portrait:1"] = true, ["portrait:2"] = true }
			for _, prop in given.fixed do
				allowed[prop.id] = true
			end
			local result = Atmosphere.plan(given)
			for id, rules in result.profiles do
				for _, rule in rules do
					check.truthy(Atmosphere.Kinds[rule.kind], "kind " .. rule.kind .. " for " .. id)
					local own = string.sub(rule.target, 1, 5) == "atmo:"
					check.truthy(own or allowed[rule.target], "targets something it wasn't given: " .. rule.target)
					check.truthy(rule.kind ~= "SeamFlip", "never a doorway")
				end
			end
		end
	end)

	test("every Witness gets their own, and a ghost needs a friend", function()
		local solo = Atmosphere.plan(input({ "1" }))
		local kinds = {}
		for _, rule in solo.profiles["1"] do
			kinds[rule.kind] = true
		end
		check.truthy(kinds.PortraitEyes and kinds.HiddenWriting and kinds.PhantomSound, "solo still gets atmosphere")
		check.truthy(not kinds.GhostTrail, "no ghost of a friend who isn't there")
		local squad = Atmosphere.plan(input({ "1", "2", "3" }))
		for _, id in { "1", "2", "3" } do
			local ghosts = 0
			for _, rule in squad.profiles[id] do
				if rule.kind == "GhostTrail" then
					ghosts += 1
					check.truthy(rule.params.subject ~= id, "a ghost of someone else")
				end
			end
			check.equal(ghosts, 1, "one ghost each")
		end
	end)

	test("rules wait for their Drift, and the same seed plans the same", function()
		local a = Atmosphere.plan(input({ "1", "2" }, 3))
		local b = Atmosphere.plan(input({ "1", "2" }, 3))
		for _, id in { "1", "2" } do
			check.equal(#a.profiles[id], #b.profiles[id], "same count")
			for i, rule in a.profiles[id] do
				check.equal(rule.target, b.profiles[id][i].target, "same target")
				if rule.kind == "PhantomSound" then
					check.equal(rule.minDrift, Config.Atmosphere.SoundMinDrift, "sounds wait (doc)")
				end
			end
		end
	end)

	test("an empty house plans nothing and breaks nothing", function()
		local result = Atmosphere.plan({
			players = { "1", "2" },
			content = Content,
			config = Config.Atmosphere,
			rng = Rng.new(1),
		})
		check.equal(#result.profiles["1"], 0, "nothing to haunt")
	end)
end
