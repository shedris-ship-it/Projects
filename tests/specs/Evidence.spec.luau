return function(test, check, Shared, require)
	local Anomalies = require(Shared.Data.Anomalies)
	local Tells = require(Shared.Data.Tells)
	local Config = require(Shared.Config)
	local Rng = require(Shared.Lib.Rng)
	local EvidencePlanner = require(Shared.Logic.EvidencePlanner)
	local CaseBoard = require(Shared.Logic.CaseBoard)
	local PerceptionPlanner = require(Shared.Logic.PerceptionPlanner)

	local function options(squadSize)
		return {
			trueTells = Config.Evidence.TrueTells,
			redHerrings = Config.Evidence.RedHerrings,
			maxSuspects = Config.Evidence.MaxSuspectsAfterThree,
			squadSize = squadSize,
		}
	end

	test("every anomaly: 3-4 true tells, deducible, one camera tell, 1-2 herrings", function()
		for _, anomaly in Anomalies.List do
			for seed = 1, 100 do
				local squad = (seed % 4) + 1
				local plan = EvidencePlanner.plan(anomaly, Anomalies.List, Tells, Rng.new(seed), options(squad))
				check.atLeast(#plan.trueTells, 3, anomaly.id .. " true tells")
				check.atMost(#plan.trueTells, 4, anomaly.id .. " true tells")
				local suspects = CaseBoard.suspects(Anomalies.List, plan.trueTells)
				check.truthy(table.find(suspects, anomaly.id), "true anomaly eliminated by its own tells")
				check.atMost(#suspects, 2, anomaly.id .. " suspects")
				check.atMost(CaseBoard.worstCaseSuspects(Anomalies.List, plan.trueTells, 3), 2, "any three tells")
				local camera = false
				for _, id in plan.trueTells do
					camera = camera or Tells[id].camera
					check.truthy((Tells[id].minPlayers or 1) <= squad, "tell needs more players than the squad has")
				end
				check.truthy(camera, "no camera tell")
				check.atLeast(#plan.redHerrings, 1, "herrings")
				check.atMost(#plan.redHerrings, 2, "herrings")
				for _, id in plan.redHerrings do
					check.truthy(not table.find(anomaly.tells, id), "herring belongs to the true anomaly")
				end
			end
		end
	end)

	local function fakeSites(tellIds)
		local sites = {}
		for i, tellId in tellIds do
			local site = { id = "tell:" .. i, tellId = tellId, position = { x = i, y = 0, z = 0 }, roomId = i }
			if Tells[tellId].presentation == "SeamFlip" then
				site.seamId = "seam:" .. i .. "-" .. (i + 1)
				site.connected = false
			end
			table.insert(sites, site)
		end
		return sites
	end

	local allTells = {}
	for id in Tells do
		table.insert(allTells, id)
	end
	table.sort(allTells)

	local function planFor(players, seed)
		local spots, props, seams = {}, {}, {}
		for i = 1, 12 do
			table.insert(spots, { position = { x = i * 3, y = 0, z = 5 }, roomId = i })
			table.insert(props, { id = "prop:" .. i, position = { x = i, y = 0, z = 9 } })
			table.insert(seams, { id = "seam:x" .. i, connected = i % 2 == 0 })
		end
		local names = {}
		for _, id in players do
			names[id] = "Player" .. id
		end
		return PerceptionPlanner.plan({
			players = players,
			names = names,
			sites = fakeSites(allTells),
			calibrationProps = props,
			floorSpots = spots,
			seams = seams,
			tells = Tells,
			config = Config.Divergence,
			rng = Rng.new(seed),
		})
	end

	test("perception: social tells are perceived by some but not all Witnesses", function()
		for seed = 1, 50 do
			local players = { "1", "2", "3" }
			local result = planFor(players, seed)
			for i, tellId in allTells do
				local tell = Tells[tellId]
				local site = "tell:" .. i
				if tell.social and tell.presentation ~= "VariantProp" then
					local who = result.perceivers[site]
					check.atLeast(#who, 1, tellId .. " perceived by nobody")
					check.atMost(#who, #players - 1, tellId .. " perceived by everyone")
				end
			end
		end
	end)

	test("perception: variant props show at least two different states", function()
		local players = { "1", "2", "3", "4" }
		local result = planFor(players, 7)
		for i, tellId in allTells do
			if Tells[tellId].presentation == "VariantProp" then
				local values = {}
				for _, rules in result.profiles do
					for _, rule in rules do
						if rule.target == "tell:" .. i then
							values[tostring(rule.params.value)] = true
						end
					end
				end
				local distinct = 0
				for _ in values do
					distinct += 1
				end
				local truthValue = tostring(result.truths["tell:" .. i])
				check.truthy(distinct >= 2 or not values[truthValue], tellId .. " looks the same to everyone")
			end
		end
	end)

	test("perception: every Witness has a divergence a teammate can disprove", function()
		for squad = 1, 4 do
			for seed = 1, 40 do
				local players = {}
				for p = 1, squad do
					table.insert(players, tostring(p))
				end
				local result = planFor(players, seed)
				check.truthy(
					PerceptionPlanner.everyoneDisprovable(result, players),
					"squad " .. squad .. " seed " .. seed
				)
				for _, id in players do
					check.atLeast(#result.profiles[id], 2, "too few rules for player " .. id)
				end
			end
		end
	end)

	test("perception: solo players get shifting variants and no teammate-based tells", function()
		local result = planFor({ "1" }, 3)
		for _, rule in result.profiles["1"] do
			check.truthy(rule.kind ~= "GhostTrail" and rule.kind ~= "HiddenTeammate", "solo got a teammate tell")
			if rule.kind == "VariantProp" then
				check.truthy(rule.params.shift, "solo variant does not shift")
			end
		end
	end)

	test("perception: the same seed gives the same rules", function()
		local a = planFor({ "1", "2" }, 11)
		local b = planFor({ "1", "2" }, 11)
		for id, rules in a.profiles do
			check.equal(#rules, #b.profiles[id], "rule count")
			for i, rule in rules do
				check.equal(rule.kind, b.profiles[id][i].kind, "kind")
				check.equal(rule.target, b.profiles[id][i].target, "target")
			end
		end
	end)
end
