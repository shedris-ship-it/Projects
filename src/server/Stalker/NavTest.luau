-- F2 `navtest` and `where` (docs/plans/mansion-generation.md, M3; the gate is
-- 0 stuck, 0 falls and 0 phases on 3 seeds). The Guest tours the house:
-- every room, and both storeys of the hall and of each stairwell, nearest
-- first, with the stuck nudge off so a stuck leg shows as a failure instead
-- of a hidden shove. Each leg is printed to Output; a summary comes back as
-- a message.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local GuestPose = require(Shared.Logic.GuestPose)
local NavGraph = require(Shared.Logic.NavGraph)

local Poses = GuestPose.Poses
local Modes = Constants.StalkerModes

local NavTest = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- One spot per room and storey: an ordinary room's middle; for the hall and
-- a stairwell, the point of each storey's walk shape nearest the middle.
local function spotsOf(worldService)
	local nav, world = worldService.nav, worldService.World
	local spots = {}
	for _, id in NavGraph.roomIds(nav) do
		local room = nav.rooms[id]
		local cx, cz = room.rect.x + room.rect.w / 2, room.rect.z + room.rect.d / 2
		local regions = room.tall and { "ground", room.tall == "hall" and "gallery" or "upper" } or { "room" }
		for _, region in regions do
			local best, bestDistance = nil, math.huge
			for _, nodeId in room.nodes do
				local node = nav.nodes[nodeId]
				local wanted = room.tall and (node.kind == "tall" and node.region == region)
					or (not room.tall and node.kind == "centre")
				local d = math.abs(node.x - cx) + math.abs(node.z - cz)
				if wanted and d < bestDistance then
					best, bestDistance = node, d
				end
			end
			if best then
				local record = world.rooms[id]
				table.insert(spots, {
					room = id,
					label = string.format(
						"%s #%d%s",
						record and record.name or "room",
						id,
						room.tall and (" " .. region) or ""
					),
					position = worldService.FromLayout(best),
				})
			end
		end
	end
	return spots
end

-- Where you and The Guest are: room, storey, and the walk region there.
function NavTest.where(service, player: Player): string
	local worldService = service.services.WorldService
	local nav = worldService.nav
	local function describe(name: string, position: Vector3?): string
		if not position then
			return name .. ": nowhere"
		end
		local id = worldService:RoomAt(position)
		local record = id and worldService:Room(id)
		local storey = worldService.FloorAt(position.Y - Config.Level.Origin.y)
		local region = "-"
		if nav and id and nav.rooms[id] then
			local best = math.huge
			for _, nodeId in nav.rooms[id].nodes do
				local node = nav.nodes[nodeId]
				local d = (worldService.FromLayout(node) - position).Magnitude
				if d < best then
					best, region = d, node.region
				end
			end
		end
		return string.format(
			"%s: %s #%s, storey %d, %s (%.0f, %.0f, %.0f)",
			name,
			record and record.name or "outside",
			tostring(id or "-"),
			storey,
			region,
			position.X,
			position.Y,
			position.Z
		)
	end
	local root = service.services.PlayerStateService:Root(player)
	local lines = { describe("you", root and root.Position) }
	if service.active and service.body and not service.parked then
		table.insert(lines, describe("guest", service.bodyCtl.root.Position))
	end
	return table.concat(lines, "\n")
end

-- F2 `navtest [fast]`.
function NavTest.run(service, args, report: (string) -> ()): string
	if not service.active or not service.body then
		return "no stalker: start a run first"
	end
	if service.navTesting then
		service.navTesting = false
		return "navtest stopped"
	end
	if service.mode == Modes.Hunting or service.mode == Modes.Telegraph then
		return "not during a hunt"
	end
	local worldService = service.services.WorldService
	if not worldService.nav or not worldService.World then
		return "no house built"
	end
	local fast = args[2] == "fast" or args[4] == "fast"
	local speed = fast and 19 or 8
	local body, walker = service.bodyCtl, service.navigator
	local offset = service.body.groundOffset
	local spots = spotsOf(worldService)
	-- `navtest room <id> [fast]`: one room, traced every half second.
	local trace = false
	if args[2] == "room" then
		local id = tonumber(args[3])
		local only = {}
		for _, spot in spots do
			if spot.room == id then
				table.insert(only, spot)
			end
		end
		if #only == 0 then
			return "no room " .. tostring(args[3])
		end
		spots = only
		trace = true
	end

	service.navTesting = true
	service.debugHold = true
	service.parked = false
	service.arrived = true
	service:_setVisible("all")
	task.spawn(function()
		local ok, err = pcall(function()
			-- Start in the hall if he isn't in the house yet.
			if not worldService:RoomAt(body.root.Position) then
				for _, room in worldService.World.layout.rooms do
					if room.role == "start" then
						body:Place(worldService.World.rooms[room.id].center)
					end
				end
				task.wait(0.5)
			end
			walker.allowNudge = false
			local stats0 = table.clone(walker.stats)
			local phases0 = body.phases
			local started = os.clock()
			local failures, falls, legs = {}, 0, 0
			local remaining = table.clone(spots)
			while #remaining > 0 and service.navTesting do
				local here = body.root.Position
				local pick, pickDistance = 1, math.huge
				for i, spot in remaining do
					local d = worldService:Separation(here, spot.position)
					if d < pickDistance then
						pick, pickDistance = i, d
					end
				end
				local spot = table.remove(remaining, pick)
				body:FaceMovement()
				body:SetGaze(nil)
				body:SetPose(fast and Poses.Run or Poses.Walk)
				body:Go(spot.position, speed)
				local legStart = os.clock()
				local lastY = body.root.Position.Y
				local fell = false
				-- Generous: closed doors cost him 1.5-3 s each to open.
				local timeout = math.max(25, pickDistance / speed * 3 + 20)
				local traced = 0
				while os.clock() - legStart < timeout and service.navTesting do
					task.wait(0.2)
					if trace and os.clock() - traced > 0.5 then
						traced = os.clock()
						print(string.format("[navtest]   %.1fs %s", os.clock() - legStart, walker:Describe()))
					end
					local y = body.root.Position.Y
					if y < lastY - 5 then
						fell = true
					end
					lastY = y
					if walker:Arrived() then
						break
					end
				end
				legs += 1
				local feet = body.root.Position - Vector3.new(0, offset, 0)
				local short = (flat(feet) - flat(spot.position)).Magnitude
				local arrived = short <= 3 and math.abs(feet.Y - spot.position.Y) <= 4
				if fell then
					falls += 1
				end
				local line = string.format(
					"%-30s %s in %.1fs",
					spot.label,
					arrived and "ok" or string.format("STUCK %.1f studs short", short),
					os.clock() - legStart
				) .. (fell and ", FELL" or "")
				print("[navtest] " .. line)
				if not arrived then
					print("[navtest]   " .. walker:Describe())
				end
				if not arrived or fell then
					table.insert(failures, line)
				end
			end
			body:Hold()
			body:SetPose(Poses.Idle)
			local stats = walker.stats
			local summary = string.format(
				"navtest%s: %d legs, %d failed · %d falls · %d phases · %d stuck moments, %d side-steps, %d re-plans, %d navmesh fallbacks · %.0fs",
				fast and " fast" or "",
				legs,
				#failures,
				falls,
				body.phases - phases0,
				stats.stuck - stats0.stuck,
				stats.sidesteps - stats0.sidesteps,
				stats.replans - stats0.replans,
				stats.fallbacks - stats0.fallbacks,
				os.clock() - started
			)
			print("[Consensus] " .. summary)
			report(
				summary .. (#failures > 0 and ("\n" .. table.concat(failures, "\n", 1, math.min(5, #failures))) or "")
			)
		end)
		walker.allowNudge = true
		service.navTesting = false
		if not ok then
			warn("[Consensus] navtest failed: " .. tostring(err))
			report("navtest failed: " .. tostring(err))
		end
	end)
	return string.format(
		"navtest: touring %d spots%s; results in Output (navtest again stops it, guest off ends the hold)",
		#spots,
		fast and " at a run" or ""
	)
end

return NavTest
