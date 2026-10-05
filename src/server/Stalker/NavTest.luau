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

-- F2 `navtest retreat [n]`: n back-aways from awkward places (in front of a
-- doorway, a room's corner, the gallery), each from a stand-in player six
-- studs away towards the middle of the room. Counts phases (he crossed a
-- wall), wall brushes (a wall came within reach of his back), corners held,
-- and the distance he gained.
function NavTest.retreat(service, args, report: (string) -> ()): string
	local worldService = service.services.WorldService
	local nav = worldService.nav
	local body, walker = service.bodyCtl, service.navigator
	local count = math.clamp(tonumber(args[3]) or 12, 1, 60)
	local rng = Random.new(7)
	-- Candidate spots, with the way into their room.
	local spots = {}
	for _, id in NavGraph.roomIds(nav) do
		local room = nav.rooms[id]
		local cx, cz = room.rect.x + room.rect.w / 2, room.rect.z + room.rect.d / 2
		for _, nodeId in room.nodes do
			local node = nav.nodes[nodeId]
			if node.kind == "approach" or (node.kind == "tall" and node.region == "gallery") then
				table.insert(spots, { node = node, cx = cx, cz = cz, label = node.kind })
			end
		end
		if not room.tall then
			-- A corner, 2.5 studs from both walls.
			local hx, hz = room.rect.w / 2 - 3, room.rect.d / 2 - 3
			local sx, sz = rng:NextInteger(0, 1) * 2 - 1, rng:NextInteger(0, 1) * 2 - 1
			table.insert(spots, {
				node = { x = cx + sx * hx, y = room.storey * nav.pitch, z = cz + sz * hz },
				cx = cx,
				cz = cz,
				label = "corner",
			})
		end
	end
	service.navTesting = true
	service.debugHold = true
	service.parked = false
	service.arrived = true
	service:_setVisible("all")
	task.spawn(function()
		local ok, err = pcall(function()
			walker.allowNudge = false
			local phases0, brushes0 = body.phases, body.backBlocks
			local episodes, held, gained, skipped = 0, 0, 0, 0
			local byKind = {}
			for _ = 1, count * 4 do
				if episodes >= count or not service.navTesting then
					break
				end
				local spot = spots[rng:NextInteger(1, #spots)]
				local position = worldService.FromLayout(spot.node)
				if body:Fits(position) then
					local toward = Vector3.new(spot.cx - spot.node.x, 0, spot.cz - spot.node.z)
					toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)
					local stand = position + toward * 6 + Vector3.new(0, 3, 0)
					body:Place(position, stand)
					service.retreat:Reset()
					task.wait(0.3)
					local start = worldService:Separation(stand, body.root.Position)
					local brushes = body.backBlocks
					local phases = body.phases
					local began = os.clock()
					while os.clock() - began < 6 and service.navTesting do
						service.retreat:Step(nil, { stand })
						task.wait(0.1)
					end
					local gain = worldService:Separation(stand, body.root.Position) - start
					local cornered = service.retreat:Cornered()
					episodes += 1
					gained += gain
					if cornered then
						held += 1
					end
					local kind = byKind[spot.label] or { n = 0, brushes = 0, phases = 0 }
					kind.n += 1
					kind.brushes += body.backBlocks - brushes
					kind.phases += body.phases - phases
					byKind[spot.label] = kind
					print(
						string.format(
							"[navtest] retreat from %-9s %s: gained %.1f studs%s, %d wall brushes, %d phases",
							spot.label,
							worldService:Room(worldService:RoomAt(position) or 0)
									and worldService:Room(worldService:RoomAt(position)).name
								or "?",
							gain,
							cornered and " (held: cornered)" or "",
							body.backBlocks - brushes,
							body.phases - phases
						)
					)
				else
					skipped += 1
				end
			end
			body:Hold()
			body:SetPose(Poses.Idle)
			local kinds = {}
			for label, kind in byKind do
				table.insert(kinds, string.format("%s %d (%d brushes)", label, kind.n, kind.brushes))
			end
			table.sort(kinds)
			local summary = string.format(
				"navtest retreat: %d back-aways · %d phases · %d wall brushes · %d held when cornered · %.1f studs gained on average · %s",
				episodes,
				body.phases - phases0,
				body.backBlocks - brushes0,
				held,
				episodes > 0 and gained / episodes or 0,
				table.concat(kinds, ", ")
			)
			print("[Consensus] " .. summary)
			report(summary)
		end)
		walker.allowNudge = true
		service.navTesting = false
		if not ok then
			warn("[Consensus] navtest retreat failed: " .. tostring(err))
			report("navtest retreat failed: " .. tostring(err))
		end
	end)
	return string.format("navtest retreat: %d back-aways; results in Output", count)
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
	if args[2] == "retreat" then
		return NavTest.retreat(service, args, report)
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
			local failures, falls, legs, noWays = {}, 0, 0, 0
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
				-- Generous: closed doors cost him 1.5-3 s each to open. Measured
				-- along his route where there is one (a shut shutter can send
				-- him the long way round), else as the crow walks.
				local route = worldService:Route(here, spot.position)
				local length = math.max(pickDistance, route and route.cost or 0)
				local timeout = math.max(25, length / speed * 3 + 20)
				local traced = 0
				local noWaySince = nil
				local noWay = false
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
					-- Every way there is shut (F2 block, a lock): not a stuck
					-- walk, so say so and go on.
					if walker:Unreachable() then
						noWaySince = noWaySince or os.clock()
						if os.clock() - noWaySince > 3 then
							noWay = true
							break
						end
					else
						noWaySince = nil
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
					arrived and "ok"
						or noWay and "NO WAY (every doorway there is shut)"
						or string.format("STUCK %.1f studs short", short),
					os.clock() - legStart
				) .. (fell and ", FELL" or "")
				print("[navtest] " .. line)
				if noWay then
					noWays += 1
				elseif not arrived then
					print("[navtest]   " .. walker:Describe())
				end
				if (not arrived and not noWay) or fell then
					table.insert(failures, line)
				end
			end
			body:Hold()
			body:SetPose(Poses.Idle)
			local stats = walker.stats
			local summary = string.format(
				"navtest%s: %d legs, %d failed, %d with no way · %d falls · %d phases · %d stuck moments, %d side-steps, %d re-plans, %d navmesh fallbacks · %.0fs",
				fast and " fast" or "",
				legs,
				#failures,
				noWays,
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
