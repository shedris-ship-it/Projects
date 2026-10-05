-- Debug console and overlay feed (doc section 7, "Testing and tooling": a
-- debug overlay for seed, tier, profile values and Drift sources, and a
-- command to force any anomaly or tier). Available in Studio, or to user ids
-- listed in Config.Debug.AllowedUserIds on live servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Anomalies = require(Shared.Data.Anomalies)
local Tells = require(Shared.Data.Tells)
local Build = require(Shared.Build)
local Net = require(Shared.Net)
local FloorPlan = require(Shared.Logic.FloorPlan)
local ClipScan = require(script.Parent.Parent.World.ClipScan)

local DebugService = {}

local watchers: { [Player]: boolean } = {}

function DebugService:Init(services)
	self.services = services
end

function DebugService:IsAllowed(player: Player): boolean
	if RunService:IsStudio() and Config.Debug.AllowInStudio then
		return true
	end
	return table.find(Config.Debug.AllowedUserIds, player.UserId) ~= nil
end

local function reply(player: Player, text: string)
	Net.get("Notify"):FireClient(player, "[debug] " .. text, "debug")
end

local HELP = table.concat({
	"overlay on|off · drift <0-100> · tier <0-4|off> · hunt · seed <n> · anomaly <id|off> · layout cells|mansion|default",
	"start · end · skip (to Investigation) · resolve (skip to the ritual) · reveal",
	"lights on|off · focus · perf · steps (tests footstep sounds) · clip (lists props that overlap) · down [name] · revive [name]",
	"guest here [studs] · walk · pose <name> · form <0-2> · smile <0-1> · lean <-1..1> · move <name> · peeks · arrive · off",
	"plan (house plan to Output) · where · navtest [fast] (the Guest walks every room; again to stop)",
	"block <room> <room> (shut that doorway to everyone) · block off · door <room> <room> <angle 0-100>",
	"drag <right> <away> (studs: your hand on the door you're looking at, as if with the mouse)",
	"stun [seconds] (as if hit by a throw) · throwat (throw what you carry at him)",
}, "\n")

-- A run player by (partial) display name, or the caller.
local function playerNamed(services, caller: Player, name: string?): Player?
	if not name or name == "" or name == "me" then
		return caller
	end
	for _, p in services.PlayerStateService:RunPlayers() do
		if string.find(string.lower(p.DisplayName), name, 1, true) then
			return p
		end
	end
	return nil
end

function DebugService:Start()
	Net.onServer("DebugCommand", { interval = 0.2, types = { "string" } }, function(player, text)
		if not self:IsAllowed(player) or #text > 200 then
			return
		end
		self:Run(player, text)
	end)
	Players.PlayerRemoving:Connect(function(player)
		watchers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if next(watchers) then
				local state = self:Snapshot()
				for player in watchers do
					if player.Parent then
						Net.get("DebugState"):FireClient(player, state)
					end
				end
			end
		end
	end)
end

function DebugService:Run(player: Player, text: string)
	local services = self.services
	local args = string.split(string.lower(text), " ")
	local command = args[1]
	local orchestrator = services.RunOrchestrator
	if command == "help" or command == "" then
		reply(player, HELP)
	elseif command == "overlay" then
		watchers[player] = args[2] ~= "off" or nil
		reply(player, "overlay " .. (watchers[player] and "on" or "off"))
	elseif command == "drift" then
		local value = tonumber(args[2])
		if value then
			services.DriftService:Set(math.clamp(value, 0, 100))
			reply(player, "drift set to " .. value)
		end
	elseif command == "tier" then
		local tier = tonumber(args[2])
		services.StalkerService:SetTierOverride(tier and math.clamp(tier, 0, 4) or nil)
		reply(player, "tier override " .. tostring(tier or "off"))
	elseif command == "hunt" then
		services.StalkerService:ForceHunt("debug")
		reply(player, "hunt forced (still respects the first-3-minutes and Lantern rules)")
	elseif command == "seed" then
		local seed = tonumber(args[2])
		orchestrator:SetNextSeed(seed)
		reply(player, "next run seed " .. tostring(seed))
	elseif command == "layout" then
		-- Which house the next run builds (docs/plans/mansion-generation.md).
		local mode = ({ cells = "Cells", mansion = "Mansion" })[args[2] or ""]
		orchestrator:SetLayoutMode(mode)
		reply(player, "next run layout " .. (mode or ("default (" .. Config.Level.Mode .. ")")))
	elseif command == "anomaly" then
		local wanted = args[2]
		local match = nil
		for _, anomaly in Anomalies.List do
			if string.lower(anomaly.id) == wanted then
				match = anomaly
			end
		end
		if match and not match.implemented then
			reply(player, match.name .. " has no ritual yet; pick PhantomArchitecture, Counterfeit or Gaze")
			return
		end
		orchestrator:SetForcedAnomaly(match and match.id or nil)
		reply(player, "next run anomaly " .. (match and match.id or "random"))
	elseif command == "start" then
		if orchestrator:Phase() == Constants.Phases.Lobby then
			orchestrator:StartRun(
				services.LobbyService:LobbyPlayers(),
				services.LobbyService.difficulty,
				services.LobbyService.location
			)
		end
	elseif command == "end" then
		orchestrator:EndRun(false, "Debug")
	elseif command == "skip" then
		orchestrator:SkipArrival()
	elseif command == "resolve" then
		orchestrator:SkipToResolution()
	elseif command == "reveal" then
		local anomaly = services.AnomalyService:Anomaly()
		if not anomaly then
			reply(player, "no run")
			return
		end
		local lines = { "anomaly: " .. anomaly.name }
		for _, site in services.AnomalyService:Sites() do
			table.insert(
				lines,
				string.format(
					"%s%s in %s",
					site.isRedHerring and "(herring) " or "",
					Tells[site.tellId].name,
					site.roomName
				)
			)
		end
		reply(player, table.concat(lines, "\n"))
	elseif command == "lights" then
		for _, id in services.WorldService:RoomIds() do
			services.WorldService:SetRoomLight(id, args[2] ~= "off")
		end
	elseif command == "guest" then
		reply(player, services.StalkerService:DebugGuest(player, args))
	elseif command == "plan" then
		local world = services.WorldService.World
		if not world then
			reply(player, "no house built")
		else
			print(FloorPlan.render(world.layout, world.layout.mode == "Mansion" and Config.Mansion or Config.Level))
			reply(player, "plan of seed " .. tostring(world.layout.seed) .. " printed to Output")
		end
	elseif command == "where" then
		reply(player, services.StalkerService:DebugWhere(player))
	elseif command == "stun" then
		local seconds = services.StalkerService:Stun(tonumber(args[2]) or 1.2, player)
		reply(
			player,
			seconds > 0 and string.format("guest stunned for %.2fs", seconds)
				or "he shrugged it off (immune or retreating)"
		)
	elseif command == "throwat" then
		-- Throw what you carry straight at his chest, as if you'd aimed it;
		-- with empty hands, take the nearest thing within reach first.
		local hands = services.HandsService
		local head = services.PlayerStateService:Head(player)
		if not hands:Held(player) and head then
			local best, bestDistance = nil, math.huge
			for id, thing in hands.things do
				local d = (thing.model:GetPivot().Position - head.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = id, d
				end
			end
			if best then
				hands:Grab(player, best)
			end
		end
		local held = hands:Held(player)
		local guest = services.StalkerService:GetPosition()
		if not held or not guest or not head then
			reply(player, "pick something up first (and he must be in the house)")
		else
			services.HandsService:Throw(player, (guest + Vector3.new(0, 1.5, 0) - head.Position).Unit)
			reply(player, "thrown at him")
		end
	elseif command == "door" then
		local door = services.DoorService:DoorBetween(tonumber(args[2]) or 0, tonumber(args[3]) or 0)
		local angle = tonumber(args[4])
		if not door or not angle then
			reply(player, "usage: door <room> <room> <angle>; no door between those rooms")
		else
			local ok = services.DoorService:SetAngle(door, angle)
			reply(player, string.format("%s to %d degrees%s", door.id, angle, ok and "" or " (locked: it rattles)"))
		end
	elseif command == "block" then
		local world = services.WorldService
		local a, b = tonumber(args[2]), tonumber(args[3])
		if args[2] == "off" then
			world:DebugBlock(nil, false)
			reply(player, "every doorway open again")
		elseif a and b and world:SeamBetween(a, b) then
			local seam = world:SeamBetween(a, b)
			world:DebugBlock(seam.id, true)
			reply(player, seam.id .. " shut to everyone (block off to undo)")
		else
			reply(player, "no seam between rooms " .. tostring(args[2]) .. " and " .. tostring(args[3]))
		end
	elseif command == "navtest" then
		reply(
			player,
			services.StalkerService:NavTest(args, function(text: string)
				reply(player, text)
			end)
		)
	elseif command == "down" or command == "revive" then
		local target = playerNamed(services, player, args[2])
		if not target then
			reply(player, "no run player called " .. tostring(args[2]))
		elseif command == "down" then
			services.PlayerStateService:Down(target)
			reply(player, target.DisplayName .. " downed")
		else
			services.PlayerStateService:Revive(target, nil)
			reply(player, target.DisplayName .. " revived")
		end
	elseif command == "clip" then
		-- Walks every built room for boxes that overlap; the full list goes to the
		-- server Output, the worst few to a message.
		task.spawn(function()
			local all = {}
			for _, id in services.WorldService:RoomIds() do
				local room = services.WorldService:Room(id)
				if room and room.model then
					for _, line in ClipScan.room(room.name or ("room " .. id), room.model) do
						table.insert(all, line)
					end
				end
				task.wait()
			end
			table.sort(all, function(a, b)
				return (tonumber(string.match(a, "^[%d%.]+")) or 0) > (tonumber(string.match(b, "^[%d%.]+")) or 0)
			end)
			for i, line in all do
				if i > 80 then
					break
				end
				print("[clip] " .. line)
			end
			if #all == 0 then
				reply(player, "clip: nothing overlaps (no run built?)")
			else
				local top = {}
				for i = 1, math.min(6, #all) do
					table.insert(top, all[i])
				end
				reply(
					player,
					string.format("clip: %d overlaps, worst first (all in Output)\n%s", #all, table.concat(top, "\n"))
				)
			end
		end)
	elseif command == "focus" then
		services.WitnessService:SetFocus(player, Config.Witness.FocusMax)
	elseif command == "perf" then
		reply(
			player,
			string.format(
				"server heartbeat %.1f ms · %d instances · %.0f MB",
				Stats.HeartbeatTimeMs or 0,
				Stats.InstanceCount,
				Stats:GetTotalMemoryUsageMb()
			)
		)
	else
		reply(player, "unknown command; try help")
	end
end

function DebugService:Snapshot()
	local services = self.services
	local runState = ReplicatedStorage.RunState
	local sources = {}
	for name, value in services.DriftService:Sources() do
		table.insert(sources, string.format("%s %+.1f", name, value))
	end
	table.sort(sources)
	local signals = {}
	for name, value in services.SquadProfileService:Signals() do
		table.insert(signals, string.format("%s %.2f", name, value))
	end
	table.sort(signals)
	local anomaly = services.AnomalyService:Anomaly()
	return {
		phase = runState:GetAttribute(Constants.RunState.Phase),
		seed = runState:GetAttribute(Constants.RunState.Seed),
		drift = services.DriftService:Value(),
		driftSources = sources,
		anomaly = anomaly and anomaly.id or "-",
		stalker = services.StalkerService:DebugState(),
		signals = signals,
		version = Build.id,
		buildSeconds = services.WorldService.lastBuildSeconds,
		serverHeartbeatMs = Stats.HeartbeatTimeMs,
		instances = Stats.InstanceCount,
	}
end

return DebugService
