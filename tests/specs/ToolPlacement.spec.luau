-- Where tools are left in the house (Logic/ToolPlacement).
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rng = require(Shared.Lib.Rng)
	local Tools = require(Shared.Data.Tools)
	local ToolPlacement = require(Shared.Logic.ToolPlacement)

	local C = Config.Tools

	-- Twelve rooms, a few tops in each, 0 to 5 rooms from the start.
	local KINDS = { "Desk", "Dresser", "Table", "Bench", "Workbench", "Counter", "Piano", "Chest" }
	local function house()
		local surfaces = {}
		for room = 1, 12 do
			for i = 0, 2 do
				local kind = KINDS[(room + i * 3) % #KINDS + 1]
				table.insert(surfaces, {
					key = room .. ":" .. kind .. i,
					room = room,
					kind = kind,
					steps = (room - 1) % 6,
					free = 3,
				})
			end
		end
		return surfaces
	end

	local function plan(seed: number, squad: number?, surfaces)
		local supply = ToolPlacement.supply(squad or 2, Tools.Ids, C)
		return ToolPlacement.plan(Rng.new(seed), surfaces or house(), supply, Tools.Homes, C), supply
	end

	test("one of each tool, with extra Cameras and Lanterns for bigger squads", function()
		local function counts(squad)
			local n = {}
			for _, id in ToolPlacement.supply(squad, Tools.Ids, C) do
				n[id] = (n[id] or 0) + 1
			end
			return n
		end
		for _, squad in { 1, 2 } do
			local n = counts(squad)
			check.equal(n.Camera, 1, "one camera for a squad of " .. squad)
			check.equal(n.Lantern, 1, "one lantern")
			check.equal(n.Radio, 1, "one radio")
			check.equal(n.PlumbLine, 1, "one plumb line")
		end
		for _, squad in { 3, 4 } do
			local n = counts(squad)
			check.equal(n.Camera, 2, "two cameras for a squad of " .. squad)
			check.equal(n.Lantern, 2, "two lanterns")
			check.equal(n.Radio, 1, "still one radio")
			check.equal(n.PlumbLine, 1, "still one plumb line")
		end
	end)

	test("the Camera is always first in the supply", function()
		for _, squad in { 1, 3 } do
			check.equal(ToolPlacement.supply(squad, Tools.Ids, C)[1], "Camera", "camera first")
		end
	end)

	test("every tool is placed, on a different surface", function()
		for seed = 1, 30 do
			local placed, supply = plan(seed, 4)
			check.equal(#placed, #supply, "all placed")
			local seen = {}
			for _, p in placed do
				check.truthy(not seen[p.surface.key], "two tools on " .. p.surface.key)
				seen[p.surface.key] = true
			end
		end
	end)

	test("tools go on furniture that makes sense for them when the house has it", function()
		for seed = 1, 30 do
			for _, p in plan(seed, 4) do
				local ok = false
				for _, kind in Tools.Homes[p.tool] do
					if kind == p.surface.kind then
						ok = true
					end
				end
				check.truthy(ok, p.tool .. " left on a " .. p.surface.kind)
			end
		end
	end)

	test("tools are spread over different rooms when there are enough rooms", function()
		for seed = 1, 30 do
			local rooms = {}
			for _, p in plan(seed, 2) do
				check.truthy(not rooms[p.surface.room], "two tools in room " .. p.surface.room)
				rooms[p.surface.room] = true
			end
		end
	end)

	test("the Camera is within reach of the start, so a solo player can find it", function()
		for seed = 1, 50 do
			local placed = plan(seed, 1)
			check.equal(placed[1].tool, "Camera", "camera first")
			check.atMost(placed[1].surface.steps, C.CameraMaxSteps, "camera too far from the start")
		end
	end)

	test("a Camera is still placed when nothing is near the start", function()
		local far = {}
		for _, s in house() do
			s.steps = 5
			table.insert(far, s)
		end
		local placed = plan(3, 1, far)
		check.equal(placed[1].tool, "Camera", "camera placed anyway")
	end)

	test("a house with none of a tool's furniture still places it somewhere", function()
		local desksOnly = {}
		for room = 1, 6 do
			table.insert(desksOnly, { key = room .. ":d", room = room, kind = "Piano", steps = 1, free = 2 })
		end
		local placed = plan(5, 2, desksOnly)
		check.equal(#placed, 4, "all four tools found a top")
	end)

	test("surfaces with no free place are never used", function()
		local surfaces = house()
		for _, s in surfaces do
			if s.room <= 6 then
				s.free = 0
			end
		end
		for seed = 1, 20 do
			for _, p in plan(seed, 4, surfaces) do
				check.truthy(p.surface.room > 6, "used a full surface in room " .. p.surface.room)
			end
		end
	end)

	test("the same seed places the same tools, and seeds differ", function()
		local a, b = plan(11), plan(11)
		for i = 1, #a do
			check.equal(a[i].surface.key, b[i].surface.key, "same place for " .. a[i].tool)
		end
		local different = false
		for seed = 12, 40 do
			local c = plan(seed)
			if c[1].surface.key ~= a[1].surface.key then
				different = true
			end
		end
		check.truthy(different, "other seeds put the camera elsewhere")
	end)

	test("with no surfaces at all, nothing is placed and nothing breaks", function()
		local placed = plan(1, 2, {})
		check.equal(#placed, 0, "nothing placed")
	end)
end
