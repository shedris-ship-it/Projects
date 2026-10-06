-- Debug console and overlay feed (doc section 7, "Testing and tooling": a
-- debug overlay for seed, tier, profile values and Drift sources, and
-- commands to force states). Available in Studio, or to user ids listed in
-- Config.Debug.AllowedUserIds on live servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Build = require(Shared.Build)
local Net = require(Shared.Net)
local FloorPlan = require(Shared.Logic.FloorPlan)
local HouseMetrics = require(Shared.Logic.HouseMetrics)
local RoomPurpose = require(Shared.Logic.RoomPurpose)
local Acts = require(Shared.Logic.Acts)
local LockPlanner = require(Shared.Logic.LockPlanner)
local Tools = require(Shared.Data.Tools)
local ClipScan = require(script.Parent.Parent.World.ClipScan)
local PartDump = require(script.Parent.Parent.World.PartDump)

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
	if RunService:IsStudio() then
		-- For the Studio bridge below: the last reply, readable from the
		-- command bar or Studio's MCP tools.
		ServerStorage:SetAttribute("DebugReply", text)
	end
end

local HELP = table.concat({
	"overlay on|off · drift <0-100> · tier <0-4|off> · hunt · seed <n> · layout cells|mansion|default · squad <1-4|auto> · watch (the stare right now)",
	"start · end · skip (to Investigation) · resolve (serve the dinner) · summary (the run in numbers, to Output)",
	"act (the run's act, dread, and any woken hunt) · arm [seconds] [false] (wake a hunt, or only its telegraph) · goto <room> | <x> <y> <z>",
	"scent (his heirlooms and his errand) · table (he waits at the table) · tidy (lying heirlooms count as left long ago)",
	"lights on|off · perf · gatea (the builder's part hash) · steps (tests footstep sounds) · clip (lists props that overlap) · down [name] · revive [name]",
	"chute [here] (down the laundry chute, from its hatch or from where you stand)",
	"guest here [studs] · walk · pose <name> · form <0-2> · smile <0-1> · lean <-1..1> · move <name> · peeks · arrive · off",
	"plan (house plan to Output) · house (why this house: its score, the adventure, every room's reason) · where · navtest [fast]",
	"block <room> <room> (shut that doorway to everyone) · block off · door <room> <room> <angle 0-100|use> · doors [open] · plans [read] · saferoom · use [name] · bell [room] · monitor · landmarks · fling <room> <room> <speed>",
	"event <id> (a house event where you stand: radioOn, phoneRings, lightsDie, overhead, doorAjar, knockInside, clockStrikes)",
	"botrun [fast] [flee|hide] (the bot plays the run with your character; again stops it) · botrun plan (the steps, to Output)",
	"inspect <Service.field.key...> (a live server table, to Output: inspect LockService.reach · inspect WorldService.World.seams.seam:2-3)",
	"drag <right> <away> (studs: your hand on the door you're looking at, as if with the mouse)",
	"stun [seconds] (as if hit by a throw) · throwat (throw what you carry at him) · lure [radius] (a noise where you look)",
	"furniture open|shut [all] (drawers, cupboard doors and lids within 20 studs, or in the whole house)",
	"push <dx> <dz> [people 1] [seconds 1.5] (the nearest pushable furniture, as if that many pushed it that way)",
	"locks (the locks to Output) · unlock <seam|all> · try <seam|piece> (as if you pressed on it) · give <token> · items · solve [puzzle]",
	"leads [go <token> [note]] · puzzle [kind] (stand at it, open it) · ui map|journal|close · switch [list]",
	"crank [go|up] · grab [id] · piece [id|show] · throwat [case] · barricade [here [piece]|squeeze|shove|scan]",
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
	-- Studio only: a command written to ServerStorage's "DebugCommand"
	-- attribute (from the command bar, or Studio's MCP tools, which can't fire
	-- remotes) runs as the first player, so tests needn't type into the F2 box.
	-- Clients can't write ServerStorage, and live servers never listen.
	if RunService:IsStudio() then
		ServerStorage:GetAttributeChangedSignal("DebugCommand"):Connect(function()
			local text = ServerStorage:GetAttribute("DebugCommand")
			local player = Players:GetPlayers()[1]
			if typeof(text) == "string" and text ~= "" and player then
				ServerStorage:SetAttribute("DebugCommand", nil)
				local ok, err = pcall(self.Run, self, player, text)
				if not ok then
					ServerStorage:SetAttribute("DebugReply", "error: " .. tostring(err))
				end
			end
		end)
	end
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

-- Commands that only read: they don't count against the finish line's
-- "no F2" (Logic/RunStats.finishLine).
local READ_ONLY = {
	help = true,
	inspect = true,
	botrun = true, -- the measuring tool itself (Services/BotService)
	[""] = true,
	overlay = true,
	summary = true,
	watch = true,
	where = true,
	act = true,
	perf = true,
	plan = true,
	house = true,
	locks = true,
	items = true,
	landmarks = true,
	saferoom = true,
	doors = true,
	scent = true,
	gatea = true,
	steps = true,
	clip = true,
	switch = true,
	crank = true,
	leads = true,
	barricade = true,
	piece = true,
	seed = true,
	layout = true,
	squad = true,
}

local function short(value): string
	local kind = typeof(value)
	if kind == "table" then
		local n = 0
		for _ in value do
			n += 1
		end
		return string.format("table(%d)", n)
	elseif kind == "Instance" then
		return value:GetFullName()
	elseif kind == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

-- F2 `inspect Service.field.key...`: walks the live services table and
-- prints what it finds (a table's entries, sorted, at most 80).
function DebugService:_inspect(path: string?): string
	if not path or path == "" then
		local names = {}
		for name in self.services do
			table.insert(names, name)
		end
		table.sort(names)
		print("[debug] services: " .. table.concat(names, " "))
		return string.format("%d services (listed in Output)", #names)
	end
	local value = self.services
	local walked = {}
	for part in string.gmatch(path, "[^%.]+") do
		if type(value) ~= "table" then
			return string.format("%s is %s, not a table", table.concat(walked, "."), short(value))
		end
		local nextValue = value[part]
		if nextValue == nil and tonumber(part) then
			nextValue = value[tonumber(part)]
		end
		if nextValue == nil then
			return string.format("no %s in %s", part, #walked > 0 and table.concat(walked, ".") or "services")
		end
		value = nextValue
		table.insert(walked, part)
	end
	if type(value) ~= "table" then
		print(string.format("[debug] %s = %s", path, short(value)))
		return string.format("%s = %s", path, short(value))
	end
	local lines = {}
	for k, v in value do
		table.insert(lines, string.format("  %s = %s", tostring(k), short(v)))
	end
	table.sort(lines)
	local total = #lines
	if total > 80 then
		lines = table.move(lines, 1, 80, 1, {})
		table.insert(lines, string.format("  ... %d more", total - 80))
	end
	print(string.format("[debug] %s (%d entries):\n%s", path, total, table.concat(lines, "\n")))
	return string.format("%s: %d entries (listed in Output)", path, total)
end

function DebugService:Run(player: Player, text: string)
	local services = self.services
	local args = string.split(string.lower(text), " ")
	local command = args[1]
	local orchestrator = services.RunOrchestrator
	-- (`leads go`, `crank go|up`, `barricade here|...`, `switch <n>` and
	-- `piece <id>` change things; their bare forms only list.)
	local changes = not READ_ONLY[command]
		or (
			args[2] ~= nil
			and (
				command == "leads"
				or command == "crank"
				or command == "barricade"
				or command == "switch"
				or command == "piece"
			)
		)
	if changes and services.RunLogService then
		services.RunLogService:F2(command)
	end
	if command == "help" or command == "" then
		reply(player, HELP)
	elseif command == "overlay" then
		watchers[player] = args[2] ~= "off" or nil
		reply(player, "overlay " .. (watchers[player] and "on" or "off"))
	elseif command == "watch" then
		-- The stare right now: who counts, in what light (Config.Stare).
		local state = services.StalkerService:DebugState()
		if not state then
			reply(player, "no stalker: start a run first")
		else
			reply(
				player,
				string.format(
					"%s · tier %d · watchers %d · %s · costare %.1f",
					state.mode,
					state.tier,
					state.watchers,
					tostring(state.watch),
					state.coStare
				)
			)
		end
	elseif command == "event" then
		-- A house event where you stand (Services/HouseEventService): `event
		-- radioOn|phoneRings|lightsDie|overhead|doorAjar|knockInside|clockStrikes`.
		local pos = services.PlayerStateService:Position(player)
		local id = args[2]
		if not id then
			reply(player, "event radioOn|phoneRings|lightsDie|overhead|doorAjar|knockInside|clockStrikes")
		elseif not pos then
			reply(player, "no character")
		else
			local ok = services.HouseEventService:Play(id, player, pos)
			if ok then
				services.RunLogService:Scare(id)
			end
			reply(player, string.format("%s: %s", id, ok and "played" or "nothing to play it on here"))
		end
	elseif command == "botrun" then
		-- The bot (Services/BotService): the loop played and measured.
		reply(
			player,
			services.BotService:Run(player, args, function(text)
				reply(player, text)
			end)
		)
	elseif command == "summary" then
		-- The run in numbers so far (Logic/RunStats), to the Output window.
		local lines = services.RunLogService:SummaryLines()
		if #lines == 0 then
			reply(player, "no run")
		else
			print("[Consensus:summary] so far")
			for _, line in lines do
				print("[Consensus:summary]   " .. line)
			end
			reply(player, table.concat(lines, "\n"))
		end
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
	elseif command == "squad" then
		-- The squad size the next mansion is built for (docs/plans/level-design.md
		-- section 5.2), so a solo test can build a four-player house.
		local size = tonumber(args[2])
		size = size and math.clamp(math.floor(size), 1, #Config.Mansion.BySquad) or nil
		orchestrator:SetSquadSize(size)
		reply(player, "next mansion built for a squad of " .. (size and tostring(size) or "however many play"))
	elseif command == "locks" then
		local lines = services.LockService:Describe()
		print("[debug] locks:\n  " .. table.concat(lines, "\n  "))
		reply(player, #lines > 0 and (#lines .. " locks (listed in Output)") or "no locks (no run, or an open house)")
	elseif command == "unlock" then
		local target = args[2] or ""
		if target == "all" then
			-- Every lock, and every crank shutter up and latched (as the dinner
			-- does), so tests like navtest walk the whole house.
			services.LockService:UnlockAll()
			services.CrankService:LatchAll()
			reply(player, "every lock open, every shutter latched up")
		else
			-- Seam ids are lower case already ("seam:2-3").
			reply(
				player,
				services.LockService:Unlock(target, player, nil) and ("unlocked " .. target) or "no such lock"
			)
		end
	elseif command == "try" then
		-- Press on a locked door from wherever you are, with whatever you hold
		-- (a key turns, a double lock takes one key at a time).
		local target = args[2] or ""
		local entry = services.LockService.locks[target]
		local piece = services.LockService.pieceLocks[target]
		if piece and not piece.open then
			-- A step's chest or fridge: one hold, as its prompt does.
			services.LockService:_tryPiece(target, player)
			reply(player, target .. (piece.open and " opened" or (" still shut, " .. piece.state.left .. " to go")))
		elseif entry and not entry.open then
			services.LockService:_try(entry.door, player, "prompt")
			reply(player, target .. (entry.open and " opened" or " still locked"))
		else
			reply(player, entry and (target .. " is already open") or "no such lock")
		end
	elseif command == "give" then
		-- A key onto your ring, or an heirloom at your feet.
		local token = args[2] or ""
		local plan = services.LockService.plan
		-- (The console lower-cases what's typed: "tool:crowbar".)
		for id in plan and plan.tokens or {} do
			if string.lower(id) == token then
				token = id
			end
		end
		local info = plan and plan.tokens[token]
		-- Any tool by id (`give tool:Salts`), planned or not (Data/Tools).
		local toolId = string.match(token, "^tool:(.+)$")
		if not info and toolId then
			for id in Tools.ById do
				if string.lower(id) == toolId then
					toolId = id
				end
			end
			if Tools.ById[toolId] then
				reply(player, services.ToolService:DebugGive(player, toolId))
				return
			end
		end
		if not info then
			reply(player, "usage: give <token> (key:1, heirloom:2, tool:Crowbar, ...)")
		elseif info.kind == "key" then
			services.LockService:GiveKey(player, token, info.label)
			reply(player, "on your ring: " .. info.label)
		elseif info.kind == "tool" then
			reply(player, services.ToolService:DebugGive(player, info.tool))
		else
			local position = services.PlayerStateService:Position(player)
			if position then
				local floor = services.WorldService:FloorBase(position.Y)
				services.ItemService:_make(token, CFrame.new(position.X + 2, floor, position.Z))
				reply(player, "at your feet: " .. services.ItemService:Label(token))
			end
		end
	elseif command == "solve" then
		reply(player, services.PuzzleService:DebugSolve(player, args[2]))
	elseif command == "barricade" then
		reply(player, services.PushService:DebugBarricade(player, args[2], args[3]))
	elseif command == "crank" then
		-- The crank doors; `crank up` rolls up and latches the nearest.
		local cranks = services.CrankService
		local position = services.PlayerStateService:Position(player)
		local lines, nearest, best = {}, nil, math.huge
		for id, crank in cranks.cranks do
			table.insert(
				lines,
				string.format(
					"%s: %.1f up%s%s, crank in room %d",
					id,
					crank.height,
					crank.latched and ", latched" or "",
					crank.ratchet and ", ratchet set" or "",
					crank.outer
				)
			)
			local d = position and crank.crankAt and (crank.crankAt - position).Magnitude or math.huge
			if d < best then
				nearest, best = crank, d
			end
		end
		if args[2] == "up" and nearest then
			cranks:Latch(nearest)
			reply(player, "latched " .. nearest.id)
		elseif args[2] == "go" and nearest then
			services.PlayerStateService:MarkTeleport(player)
			player.Character:PivotTo(CFrame.new(nearest.crankAt + nearest.wheelAt.LookVector * 3))
			reply(player, "at the crank of " .. nearest.id)
		else
			reply(player, #lines > 0 and table.concat(lines, "\n") or "no crank doors in this house")
		end
	elseif command == "switch" then
		-- Flip the light switch of the room you're in; `switch list` counts them.
		local interact = services.InteractService
		if args[2] == "list" then
			local rooms = 0
			for _ in interact.switches do
				rooms += 1
			end
			reply(player, rooms .. " switches, " .. #interact.fixtures .. " fixtures")
			return
		end
		local position = services.PlayerStateService:Position(player)
		local roomId = position and services.WorldService:RoomAt(position)
		local switch = roomId and interact.switches[roomId]
		if not switch then
			reply(player, "no switch in this room")
		else
			interact:Flip(roomId, not switch.off, player)
			local causes = {}
			for cause in services.WorldService:LightCauses(roomId) do
				table.insert(causes, cause)
			end
			reply(
				player,
				"switch "
					.. (switch.off and "off" or "on")
					.. "; dark because: "
					.. (#causes > 0 and table.concat(causes, ", ") or "nothing")
			)
		end
	elseif command == "puzzle" then
		-- Stand at a puzzle's station (the first of `kind`, or any) and open it.
		reply(player, services.PuzzleService:DebugVisit(player, args[2]))
	elseif command == "items" then
		local plan = services.LockService.plan
		if not plan then
			reply(player, "no run")
			return
		end
		local lines = {}
		local items = services.ItemService
		for id, token in plan.tokens do
			local where = token.producer.kind == "puzzle" and ("puzzle " .. token.producer.id)
				or ("room " .. table.concat(LockPlanner.producerRooms(plan, token), "+"))
			-- The furniture it waits in, if any (Services/ItemService.bySpace).
			local kept = ""
			for space, held in items.bySpace do
				if held == id then
					kept = string.format(
						" · kept in %s (%s%s, spot %s, filled %s%s)",
						space.id,
						space.prop.kind,
						space.lead and (", lead " .. space.lead) or "",
						typeof(space.spot) == "CFrame" and "yes" or "NO",
						tostring(space.filled),
						items.decoys[space] and ", DECOY" or ""
					)
				end
			end
			table.insert(
				lines,
				string.format("%s (%s) %s%s%s", id, token.kind, where, items.found[id] and ", found" or "", kept)
			)
		end
		table.sort(lines)
		print("[debug] items:\n  " .. table.concat(lines, "\n  "))
		reply(player, #lines .. " items (listed in Output)")
	elseif command == "ui" then
		-- Open a screen on your client: `ui map`, `ui journal`, `ui close`.
		player:SetAttribute("DebugUi", (args[2] or "map") .. ":" .. os.clock())
		reply(player, "ui " .. (args[2] or "map"))
	elseif command == "leads" then
		-- How each key and heirloom is found (Logic/Leads), the notes' text,
		-- and the cases; `leads go <token> [note]` takes you to its room (or
		-- its note's).
		local items = services.ItemService
		local leadOf, notes, cases = items:Leads()
		if args[2] == "go" then
			local lead = leadOf[args[3] or ""]
			local character = player.Character
			if not lead or not character then
				reply(player, "usage: leads go <token> [note] (F2 leads lists them)")
				return
			end
			local room = (args[4] == "note" and lead.noteRoom) or lead.room
			local spot = services.WorldService:RandomPointIn(room, Random.new())
			services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
			reply(player, "in room " .. room)
			return
		end
		local lines = {}
		for token, lead in leadOf do
			table.insert(
				lines,
				string.format(
					"%s: %s in room %d%s%s",
					token,
					lead.kind,
					lead.room,
					lead.noteRoom and (", note in room " .. lead.noteRoom) or "",
					lead.wanted and (" (wanted " .. lead.wanted .. ")") or ""
				)
			)
		end
		table.sort(lines)
		for _, note in notes do
			local text = string.gsub(note.text, "\n", " / ")
			table.insert(lines, string.format("%s in room %d: %s", note.id, note.room, text))
		end
		for _, case in cases do
			local what = (case.token or "decoy") .. (case.open and ", open" or "")
			table.insert(lines, string.format("%s in room %d: %s", case.id, case.room, what))
		end
		print("[debug] leads:\n  " .. table.concat(lines, "\n  "))
		reply(player, #lines .. " lines (listed in Output)")
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
	elseif command == "house" then
		-- Why this house was kept (docs/plans/level-design.md section 5): the
		-- search's scores, the scorecard, the adventure, every room's reasons.
		local found = orchestrator.run and orchestrator.run.house
		if not found then
			reply(player, "no mansion this run (the old house isn't searched)")
		else
			local lines = {
				string.format(
					"house %d of %d kept, score %.1f (all: %s), in %.2fs",
					found.index,
					#found.scores,
					found.score,
					table.concat(
						(function()
							local out = {}
							for _, score in found.scores do
								table.insert(out, string.format("%.1f", score))
							end
							return out
						end)(),
						" "
					),
					found.seconds or 0
				),
			}
			for _, line in HouseMetrics.describe(found.card) do
				table.insert(lines, line)
			end
			local wings = found.layout.wings
			if wings and found.plan.stats.wings then
				for _, r in wings.order do
					local beat = wings.beats[r]
					local parts = {}
					for key in beat do
						table.insert(parts, key)
					end
					table.sort(parts)
					table.insert(
						lines,
						("region %d: %d rooms, gate %s %s"):format(
							r,
							#wings.regions[r].rooms,
							wings.gates[r],
							#parts > 0 and ("(" .. table.concat(parts, ", ") .. ")") or ""
						)
					)
				end
			end
			for _, room in found.layout.rooms do
				local name = services.WorldService:Room(room.id)
				table.insert(
					lines,
					("  %d %s: %s"):format(
						room.id,
						name and name.name or room.template,
						RoomPurpose.describe(found.purposes[room.id])
					)
				)
			end
			print("[debug] house:\n  " .. table.concat(lines, "\n  "))
			reply(player, string.format("house %d of %d, score %.1f (Output)", found.index, #found.scores, found.score))
		end
	elseif command == "inspect" then
		-- A live service table by dotted path, read-only, to Output (the MCP
		-- command bar can't see game scripts' tables: its `shared` is its own).
		local path = string.match(text, "^%s*%S+%s+(.-)%s*$")
		reply(player, self:_inspect(path))
	elseif command == "where" then
		reply(player, services.StalkerService:DebugWhere(player))
	elseif command == "stun" then
		local seconds = services.StalkerService:Stun(tonumber(args[2]) or 1.2, player)
		reply(
			player,
			seconds > 0 and string.format("guest stunned for %.2fs", seconds)
				or "he shrugged it off (immune or retreating)"
		)
	elseif command == "grab" then
		-- Take a thing into your hands: the one named (`grab thing:12`), or the nearest.
		local hands = services.HandsService
		local head = services.PlayerStateService:Head(player)
		local id = args[2]
		if not id and head then
			local best = math.huge
			for thingId, thing in hands.things do
				local d = (thing.model:GetPivot().Position - head.Position).Magnitude
				if d < best then
					id, best = thingId, d
				end
			end
		end
		local thing = id and hands.things[id]
		if not thing then
			reply(player, "usage: grab [thing id] (nothing near)")
		else
			hands:Grab(player, id)
			local held = hands:Held(player)
			reply(player, held and ("holding " .. thing.model.Name) or "couldn't take it (too far?)")
		end
	elseif command == "throwat" then
		-- Throw what you carry straight at his chest, as if you'd aimed it
		-- (`throwat case`: at the nearest locked display case's glass); with
		-- empty hands, take the nearest thing within reach first.
		local hands = services.HandsService
		local head = services.PlayerStateService:Head(player)
		if not hands:Held(player) and head then
			local best, bestDistance = nil, math.huge
			for id, thing in hands.things do
				local d = (thing.model:GetPivot().Position - head.Position).Magnitude
				if d < bestDistance and not thing.model:GetAttribute("Item") then
					best, bestDistance = id, d
				end
			end
			if best then
				hands:Grab(player, best)
			end
		end
		local held = hands:Held(player)
		local target
		if args[2] == "case" and head then
			local nearest = math.huge
			for _, case in services.ItemService.cases do
				local at = case.cover:GetBoundingBox().Position
				local d = (at - head.Position).Magnitude
				if not case.open and d < nearest then
					target, nearest = at, d
				end
			end
		else
			local guest = services.StalkerService:GetPosition()
			target = guest and guest + Vector3.new(0, 1.5, 0)
		end
		if not held or not target or not head then
			reply(player, "pick something up first (and he must be in the house, or a case nearby)")
		else
			services.HandsService:Throw(player, (target - head.Position).Unit, 1)
			reply(player, "thrown")
		end
	elseif command == "lure" then
		-- A noise nobody made where you're looking (up to 25 studs off), as
		-- if something fell there. He comes to look if he's lost you.
		local head = services.PlayerStateService:Head(player)
		local view = services.WitnessService:GetView(player)
		if not head or not view then
			reply(player, "no view yet")
		else
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			local hit = workspace:Raycast(head.Position, view.LookVector * 25, params)
			local spot = hit and hit.Position - view.LookVector * 0.5 or head.Position + view.LookVector * 25
			services.NoiseService:Emit(spot, tonumber(args[2]) or 40, nil, "lure")
			reply(player, string.format("a noise at (%.0f, %.0f, %.0f)", spot.X, spot.Y, spot.Z))
		end
	elseif command == "push" then
		reply(
			player,
			services.PushService:DebugPush(
				player,
				tonumber(args[2]) or 0,
				tonumber(args[3]) or 0,
				math.clamp(math.floor(tonumber(args[4]) or 1), 1, 6),
				math.clamp(tonumber(args[5]) or 1.5, 0.1, 10)
			)
		)
	elseif command == "furniture" then
		local open = args[2] ~= "shut"
		local here = args[3] ~= "all" and services.PlayerStateService:Position(player) or nil
		local count = 0
		for _, piece in services.FurnitureService.pieces do
			if not here or (piece.primary.Position - here).Magnitude <= 20 then
				services.FurnitureService:SetOpen(piece, open)
				count += 1
			end
		end
		reply(player, string.format("%s %d pieces", open and "opened" or "shut", count))
	elseif command == "door" then
		local door = services.DoorService:DoorBetween(tonumber(args[2]) or 0, tonumber(args[3]) or 0)
		local angle = tonumber(args[4])
		if door and args[4] == "use" then
			-- As its prompt does, for you where you stand.
			services.DoorService:Toggle(door, player)
			reply(player, door.id .. " used")
		elseif not door or not angle then
			reply(player, "usage: door <room> <room> <angle|use>; no door between those rooms")
		else
			local ok = services.DoorService:SetAngle(door, angle)
			reply(player, string.format("%s to %d degrees%s", door.id, angle, ok and "" or " (locked: it rattles)"))
		end
	elseif command == "use" then
		-- The nearest fixture (or one by name: `use kettle`, `use toy`).
		reply(player, services.InteractService:DebugUse(player, args[2]))
	elseif command == "bell" then
		-- The bell board (`bell <room>` rings that room's bell).
		local room = tonumber(args[2])
		if room then
			reply(player, services.BellBoardService:Ring(room) and ("rang " .. room) or "no bell for that room")
		else
			reply(player, services.BellBoardService:Describe())
		end
	elseif command == "landmarks" then
		reply(player, services.LandmarkService:Describe())
	elseif command == "monitor" then
		reply(player, services.MonitorService:Describe())
	elseif command == "saferoom" then
		-- Where the safe room is and what's in it.
		reply(player, services.SafeRoomService:Describe())
	elseif command == "plans" then
		-- Where the house plans are, or (`plans read`) read them from anywhere.
		local plan = services.LockService.plan
		local plans = plan and plan.housePlans
		if not plans then
			reply(player, "no house plans this run")
		elseif args[2] == "read" and services.ItemService.plansSheet then
			local fresh = services.MapService:RevealStorey(plans.storey)
			reply(player, string.format("storey %d on the map%s", plans.storey, fresh and "" or " (already)"))
		else
			reply(player, string.format("house plans in room %d, for storey %d", plans.room, plans.storey))
		end
	elseif command == "doors" then
		-- Every unlocked door that furniture stops before it's open enough to
		-- walk through (PushService:SwingStop); `doors open` swings them all.
		local world = services.WorldService.World
		local stuck, count = {}, 0
		for _, door in world and world.doors or {} do
			if door.state and not door.locked then
				count += 1
				local stop, piece = services.PushService:SwingStop(door, door.state.value, Config.Doors.OpenAngle)
				if stop and stop < Config.Doors.PassAngle then
					table.insert(
						stuck,
						string.format(
							"%s (%d/%d) stops at %.0f on %s",
							door.id,
							door.a,
							door.b,
							stop,
							piece and piece.prop.kind or "?"
						)
					)
				end
				if args[2] == "open" then
					services.DoorService:SetOpen(door, true)
				end
			end
		end
		table.sort(stuck)
		reply(player, string.format("%d doors, %d stopped by furniture: %s", count, #stuck, table.concat(stuck, "; ")))
	elseif command == "piece" then
		-- The nearest drawer, cupboard door or closet door (or `piece piece:17`):
		-- toggled (`piece show`: not), and how it stands.
		local furniture = services.FurnitureService
		local position = services.PlayerStateService:Position(player)
		local best, nearest = furniture.pieces[args[2] or ""], math.huge
		for _, piece in best and {} or furniture.pieces do
			local d = position and (piece.primary.Position - position).Magnitude or math.huge
			if d < nearest then
				best, nearest = piece, d
			end
		end
		if not best then
			reply(player, "no furniture piece near")
		else
			if args[2] ~= "show" then
				furniture:Toggle(best, player)
			end
			task.wait(1)
			local s = best.state
			reply(
				player,
				string.format(
					"%s (%s on %s): %s, value %.2f, target %.2f, max %.2f, mode %s%s",
					best.id,
					best.label,
					best.prop.kind or "?",
					best.joint.kind,
					s.value,
					s.target,
					s.max,
					tostring(s.mode),
					s.locked and ", locked" or ""
				)
			)
		end
	elseif command == "fling" then
		-- A hand lets go of a door at a speed (degrees a second): it swings on.
		local door = services.DoorService:DoorBetween(tonumber(args[2]) or 0, tonumber(args[3]) or 0)
		local speed = tonumber(args[4])
		if not door or not speed then
			reply(player, "usage: fling <room> <room> <degrees a second, minus to shut>")
		else
			services.DoorService:Drag(door, door.state.value, player, speed)
			reply(player, string.format("%s let go at %d degrees a second from %.0f", door.id, speed, door.state.value))
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
	elseif command == "chute" then
		-- The laundry chute (docs/plans/level-design.md section 10.5): `chute`
		-- takes you to its hatch and down it; `chute here` tries it from where
		-- you stand.
		local chute = services.ChuteService:Get()
		if not chute then
			reply(player, "this house has no laundry chute")
		elseif args[2] == "here" then
			reply(player, services.ChuteService:Use(player))
		else
			local character = player.Character
			if character then
				services.PlayerStateService:MarkTeleport(player)
				local at = chute.stand
				character:PivotTo(CFrame.lookAt(at, at - chute.into))
			end
			task.wait(0.3)
			reply(player, services.ChuteService:Use(player))
		end
	elseif command == "goto" then
		-- Step into a room (its middle, or a free spot near it), for testing;
		-- or `goto <x> <y> <z>` to a spot (feet).
		local id = tonumber(args[2])
		local room = id and services.WorldService:Room(id)
		local character = player.Character
		local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
		if character and x and y and z then
			services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(CFrame.new(x, y + 3, z))
			reply(player, string.format("at (%.0f, %.0f, %.0f)", x, y, z))
		elseif not room or not character then
			reply(player, "usage: goto <room id> (F2 plan lists them)")
		else
			local spot = services.WorldService:RandomPointIn(id, Random.new())
			services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
			reply(player, "in " .. tostring(room.name) .. " (room " .. id .. ")")
		end
	elseif command == "scent" or command == "table" or command == "tidy" then
		-- The Guest and his heirlooms (R2c).
		local stalker = services.StalkerService
		local items = services.ItemService
		if not stalker.stalk then
			reply(player, "no run")
			return
		end
		if command == "table" then
			-- Wait at the table now, whoever holds what.
			local finale = services.FinaleService
			stalker.stalk.errand = {
				id = "WaitAtTable",
				started = os.clock(),
				at = finale.head,
				look = finale.tableFrame.Position,
				forced = true,
			}
			stalker.director:Disarm()
			reply(player, "he goes to wait at the head of the table")
			return
		elseif command == "tidy" then
			-- Pretend the heirlooms lying about were left long ago.
			local count = 0
			for _, state in items.heirlooms do
				if state.thing and not state.holder and not state.set then
					state.droppedAt = os.clock() - Config.Scent.TidySeconds - 1
					count += 1
				end
			end
			stalker.tidyCooldownUntil = 0
			reply(player, count .. " heirloom(s) left lying long enough for him to tidy")
			return
		end
		local lines = {}
		for _, h in items:Heirlooms() do
			table.insert(
				lines,
				string.format(
					"%s %s%s%s",
					h.token,
					h.set and "set" or h.holder and ("held by " .. h.holder.DisplayName) or "lying",
					h.hidden and " (hiding)" or "",
					h.droppedAt and string.format(", dropped %ds ago", os.clock() - h.droppedAt) or ""
				)
			)
		end
		local errand = stalker.stalk.errand
		local spot = errand and (errand.at or errand.position)
		local from = spot and stalker.stalk.body.root.Position
		table.insert(
			lines,
			"errand: "
				.. (errand and errand.id or "none")
				.. (errand and errand.arrived and " (arrived)" or "")
				.. (
					from
						and string.format(
							", %.1f studs from its spot",
							(Vector3.new(spot.X, from.Y, spot.Z) - from).Magnitude
						)
					or ""
				)
		)
		reply(player, table.concat(lines, "\n"))
	elseif command == "act" then
		-- The run's arc (Logic/Acts) and any hunt progress has woken.
		local director = services.StalkerService.director
		if not director then
			reply(player, "no run")
		else
			local facts = director:Facts()
			local due = director.armedAt and (director.armedAt - os.clock())
			reply(
				player,
				string.format(
					"act %d · dread %.0f (drift %.0f) · progress %.0f%% (gates %d/%d, heirlooms found %d/%d, places %d/%d) · %s",
					director.act,
					services.DriftService:Dread(),
					services.DriftService:Value(),
					Acts.progress(facts) * 100,
					facts.gatesOpened,
					facts.gates,
					facts.heirloomsFound,
					facts.heirlooms,
					facts.placesSet,
					facts.places,
					due and string.format("hunt woken (%s), due in %.0fs", tostring(director.armedReason), due)
						or "no hunt woken"
				)
			)
		end
	elseif command == "arm" then
		local director = services.StalkerService.director
		if director then
			local seconds = tonumber(args[2]) or 10
			-- `arm 5 false`: only the telegraph (a false alarm), the real one after.
			local falseAlarm = args[3] == "false"
			director:ArmIn(seconds, falseAlarm)
			reply(
				player,
				string.format(
					"%s is woken, due in %ds (still waits out the usual rules)",
					falseAlarm and "a false alarm" or "a hunt",
					seconds
				)
			)
		end
	elseif command == "gatea" then
		-- Gate A: the builder's parts, hashed (World/PartDump). Run it before
		-- opening anything: an opened drawer moves parts.
		local level = services.WorldService.folder
		if not level then
			reply(player, "no house built")
		else
			local parts, hash = PartDump.hash(level)
			reply(player, string.format("parts %d, hash %d", parts, hash))
		end
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
	return {
		phase = runState:GetAttribute(Constants.RunState.Phase),
		seed = runState:GetAttribute(Constants.RunState.Seed),
		drift = services.DriftService:Value(),
		driftSources = sources,
		stalker = services.StalkerService:DebugState(),
		stats = services.RunLogService:OverlayLines(),
		signals = signals,
		version = Build.id,
		buildSeconds = services.WorldService.lastBuildSeconds,
		serverHeartbeatMs = Stats.HeartbeatTimeMs,
		instances = Stats.InstanceCount,
	}
end

return DebugService
