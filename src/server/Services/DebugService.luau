-- Debug console and overlay feed (doc section 7, "Testing and tooling": a
-- debug overlay for seed, tier, profile values and Drift sources, and
-- commands to force states). Available in Studio, or to user ids listed in
-- Config.Debug.AllowedUserIds on live servers.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Build = require(Shared.Build)
local Net = require(Shared.Net)
local FloorPlan = require(Shared.Logic.FloorPlan)
local HouseMetrics = require(Shared.Logic.HouseMetrics)
local RoomPurpose = require(Shared.Logic.RoomPurpose)
local Acts = require(Shared.Logic.Acts)
local LockPlanner = require(Shared.Logic.LockPlanner)
local Catalog = require(Shared.Logic.Catalog)
local Credits = require(Shared.Logic.Arcade.Credits)
local HouseCall = require(Shared.Logic.Arcade.HouseCall)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Progression = require(Shared.Logic.Progression)
local Records = require(Shared.Logic.Records)
local Closet = require(Shared.Logic.Closet)
local Locations = require(Shared.Data.Locations)
local Lore = require(Shared.Data.Lore)
local Products = require(Shared.Data.Products)
local Wardrobe = require(Shared.Data.Wardrobe)
local LookSpots = require(Shared.Data.LookSpots)
local Mall = require(Shared.Data.Mall)
local MallLayout = require(Shared.Logic.MallLayout)
local Tools = require(Shared.Data.Tools)
local Kit = require(Shared.World.Kit)
local ClipScan = require(script.Parent.Parent.World.ClipScan)
local MallBuilder = require(script.Parent.Parent.World.MallBuilder)
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
	"act (the run's act, dread, and any woken hunt) · arm [seconds] [false] (wake a hunt, or only its telegraph) · goto <room> | <x> <y> <z> · look <spot> | look save <name> (fixed shots, Data/LookSpots)",
	"scent (his heirlooms and his errand) · table (he waits at the table) · tidy (lying heirlooms count as left long ago)",
	"lights on|off · perf · gatea (the builder's part hash) · steps (tests footstep sounds) · clip (lists props that overlap) · down [name] · revive [name]",
	"crowd <n>|clear (n dressed stand-ins over the mall, for a full lobby's cost with perf)",
	"car [in [n]|out|honk|set <key> <value>] (the party cars) · tape [location|none] (a rental tape in your hand)",
	"marks <n> · shop [booth|rack] [top|bottom|shoes] | shop done (the fitting room) · own [garment|none] · gift <product> · starter [again] (the boutique)",
	"ware [<torch|paint|carbit|radio> <id>|none|open counter|pegboard] (LB4's torch looks and car bits, yours and on)",
	"arcade [play [n]|free|credits <n>|score <n> [name]|bot [cheat]|clear] (HOUSE CALL: play at cabinet n, today's free play back, plays bought, a high score, a scripted game through the replay check, empty the boards)",
	"buy <product|pass> (a test purchase through the game's own receipt handling, no Robux)",
	"lore [<id>] (the lobby's things to read: list them, or read one where you stand)",
	"record [count|add <normal|hard> <fast|long> <solo|squad> <seconds> [names]|clear] (the diner's boards: the next run counts in Studio, an entry, empty them)",
	"beat [behind|dark|hand] (a scare he sets up, on you) · disguise [name|self] (him as a friend, for you)",
	"chute [here] (down the laundry chute, from its hatch or from where you stand)",
	"find <name> (a drawer find in front of you: SpareBatteries, PillBottle, Letters, Matchbox, ...)",
	"hide [bed|table|desk|curtain|bathtub] (into the nearest place you hide in by E)",
	"guest here [studs] · walk · reel [beat|stop] (every way he moves, near you; or one, over and over) · pose <name> · form <0-2> · smile <0-1> · lean <-1..1> · move <name> · peeks · arrive · off",
	"plan (house plan to Output) · house (why this house: its score, the adventure, every room's reason) · where · navtest [fast]",
	"block <room> <room> (shut that doorway to everyone) · block off · door <room> <room> <angle 0-100|use> · doors [open] · plans [read] · saferoom · use [name] · bell [room] · monitor · landmarks · fling <room> <room> <speed>",
	"event <id> (a house event where you stand: radioOn, phoneRings, lightsDie, overhead, doorAjar, knockInside, clockStrikes)",
	"botrun [fast] [flee|hide] (the bot plays the run with your character; again stops it) · botrun plan (the steps, to Output)",
	"night full|short (the next run's length: the squad's house, or one wing and two heirlooms)",
	"role (this server's job: lobby, run or both; Services/PlaceService)",
	"mallsound <Hum|Buzz|Drip|Radio|Arcade|Sputter> [n] (hear the n-th candidate, Assets.Mall) · brownout · mallstrike (the lobby mall's)",
	"ads [ad|poster|live|deny|allow|policy] (the mall's ad frames: their state; every AdGui up; our posters; back to the rule; you as a player who can't, or can, be shown ads; back to PolicyService)",
	"stepvolume [share] (steps seen from outside, yours in the lobby and everyone else's: a share of full volume for everyone; none: back to Config.Feel FootstepVolumeSeen)",
	"inspect <Service.field.key...> (a live server table, to Output: inspect LockService.reach · inspect WorldService.World.seams.seam:2-3)",
	"drag <right> <away> (studs: your hand on the door you're looking at, as if with the mouse)",
	"stun [seconds] (as if hit by a throw) · throwat (throw what you carry at him) · lure [radius] (a noise where you look)",
	"furniture open|shut [all] (drawers, cupboard doors and lids within 20 studs, or in the whole house)",
	"push <dx> <dz> [people 1] [seconds 1.5] (the nearest pushable furniture, as if that many pushed it that way)",
	"locks (the locks to Output) · unlock <seam|all> · try <seam|piece> (as if you pressed on it) · give <token> · items · valuables · solve [puzzle]",
	"leads [go <token> [note]] · puzzle [kind] (stand at it, open it) · ui map|journal|close · switch [list]",
	"crank [go|up] · grab [id] · piece [id|show] · throwat [case] · barricade [here [piece]|squeeze|shove|burst|scan]",
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
	valuables = true,
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
	role = true,
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
	-- (A run an F2 command touched, or the bot played, never goes on the
	-- diner's boards.)
	if changes or command == "botrun" then
		self.used = true
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
	elseif command == "night" then
		-- The next run's length: "full" or a Config.Mansion.Profiles name ("short").
		local name = args[2] or "full"
		if orchestrator:SetNight(name) then
			reply(player, "next run: a " .. name .. " night")
		else
			reply(player, "usage: night full|short")
		end
	elseif command == "cutscene" then
		-- Plays one of the three cutscenes to you (Logic/Cutscene), without what
		-- goes with it in the run: `cutscene arrival|dinner|escape`. The
		-- dinner seats him at the head of the table. Pin a moment for stills
		-- with the player attribute DebugCutsceneAt.
		local world = services.WorldService.World
		local exit = world and world.exit
		local finale = services.FinaleService
		local kind = args[2] or "arrival"
		local now = Workspace:GetServerTimeNow()
		if (kind == "arrival" or kind == "escape") and exit and exit.outward then
			Net.get("Cutscene"):FireClient(player, {
				kind = kind,
				start = now,
				door = exit.door,
				doorway = exit.zone.Position - exit.outward * 3.5,
				outward = exit.outward,
				hall = services.WorldService:Room(world.layout.start).center,
			})
			reply(player, "cutscene: " .. kind)
		elseif kind == "dinner" and finale.tableFrame and finale.head then
			Net.get("Cutscene"):FireClient(player, {
				kind = "dinner",
				start = now,
				table = finale.tableFrame,
				head = finale.head,
				tableModel = world and world.deliberationTable,
			})
			task.delay(1.4, function()
				services.StalkerService:PlaceAt(finale.head, finale.tableFrame.Position, 4)
			end)
			reply(player, "cutscene: dinner")
		else
			reply(player, "no run, or no " .. tostring(kind) .. " here")
		end
	elseif command == "takedown" then
		-- The Guest's takedown on you (Logic/Takedown), without the down:
		-- `takedown [taste|taking] [front|behind|hiding] [hold]`, `takedown
		-- stop`. He's put in front of you (behind you; a few steps off, for a
		-- hiding place's haul). `hold` keeps it going for stills.
		reply(player, services.StalkerService:DebugTakedown(player, args[2], args[3], args[4]))
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
			services.LockService:_tryPiece(target, player, "work")
			reply(player, target .. (piece.open and " opened" or (" still shut, " .. piece.state.left .. " to go")))
		elseif entry and not entry.open then
			services.LockService:_try(entry.door, player, "work")
			reply(player, target .. (entry.open and " opened" or " still locked"))
		else
			reply(player, entry and (target .. " is already open") or "no such lock")
		end
	elseif command == "give" then
		-- A key onto your ring, or an heirloom at your feet.
		local token = args[2] or ""
		local plan = services.LockService.plan
		-- One of the family's valuables at your feet (`give valuable:1`).
		if services.ItemService:IsValuable(token) then
			local position = services.PlayerStateService:Position(player)
			local state = services.ItemService.valuables[token]
			if position and not state.thing and not state.banked then
				local floor = services.WorldService:FloorBase(position.Y)
				services.ItemService:_make(token, CFrame.new(position.X + 2, floor, position.Z))
				reply(player, "at your feet: " .. services.ItemService:Label(token))
			else
				reply(player, token .. " is already out in the house (F2 valuables), or carried out")
			end
			return
		end
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
	elseif command == "hide" then
		-- Into the nearest place you hide in by E (of a kind: bed, table,
		-- desk, curtain, bathtub), as if you'd walked up and pressed E.
		local world = services.WorldService.World
		local root = services.PlayerStateService:Root(player)
		local want = args[2] and string.lower(args[2]) or nil
		local best, bestD = nil, math.huge
		for _, spot in world and world.hidingSpots or {} do
			local label = string.lower(tostring(spot.label))
			if not spot.physical and (not want or label == want or spot.category == want) then
				local d = root and (spot.frontPosition - root.Position).Magnitude or 0
				if d < bestD then
					best, bestD = spot, d
				end
			end
		end
		if not best or not root then
			reply(player, "no hiding place like that here")
			return
		end
		services.PlayerStateService:MarkTeleport(player)
		root.CFrame = CFrame.new(best.frontPosition + Vector3.new(0, 3, 0))
		task.wait(0.2)
		services.HidingService:Enter(player, best)
		reply(player, "hidden in the " .. tostring(best.label) .. " (" .. best.id .. ")")
	elseif command == "valuables" then
		-- The family's valuables (push your luck): each and where it is.
		local lines = services.ItemService:ValuableLines()
		for _, line in lines do
			print("[valuables] " .. line)
		end
		reply(player, #lines > 0 and table.concat(lines, " · ") or "none this run")
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
	elseif command == "seen" then
		-- `seen all`: the whole house on the map, as if someone had been
		-- everywhere (Services/MapService:DebugSeeAll).
		reply(player, services.MapService:DebugSeeAll() .. " rooms marked seen")
	elseif command == "outfit" then
		-- `outfit <n>`: wear squad member n's clothes; `outfit lineup`: both
		-- bodies in every outfit in a row in front of you; `outfit clear`
		-- (Services/OutfitService).
		local outfits = services.OutfitService
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if args[2] == "lineup" and root then
			-- (Level, where you stand: their roots at your root's height.)
			local look = root.CFrame.LookVector
			local at = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
			reply(player, outfits:DebugLineup(at) .. " dressed in a row")
		elseif args[2] == "clear" then
			outfits:DebugLineup(nil)
			reply(player, "lineup cleared")
		elseif tonumber(args[2]) then
			reply(player, "wearing " .. outfits:DebugWear(player, tonumber(args[2]) :: number))
		else
			reply(player, "usage: outfit <n> | lineup | clear")
		end
	elseif command == "crowd" then
		-- `crowd <n>`: n dressed stand-ins over the mall's open floor, about
		-- half in the court, a quarter in the garage, the rest in the shops,
		-- for LB1b's 50-player measurement (with `perf`); `crowd clear`.
		local n = math.clamp(math.floor(tonumber(args[2]) or 0), 0, 99)
		if args[2] == "clear" or n == 0 then
			services.OutfitService:DebugCrowd(nil)
			reply(player, "crowd cleared")
		else
			local o = Config.Level.LobbyOrigin
			local origin = Vector3.new(o.x, o.y, o.z)
			local shares = {
				court = 0.5,
				garage = 0.25,
				diner = 0.07,
				video = 0.05,
				arcade = 0.05,
				boutique = 0.04,
				electronics = 0.04,
			}
			local order = { "court", "garage", "diner", "video", "arcade", "boutique", "electronics" }
			local spots = {}
			local left = n
			for k, room in order do
				local want = k == #order and left or math.min(left, math.round(n * shares[room]))
				local open = MallLayout.openSpots(Mall, room, 4, 1.5)
				-- (Spread through the room: every few spots, not the first few.)
				local stride = math.max(1, #open / math.max(want, 1))
				for i = 1, math.min(want, #open) do
					local p = open[math.floor((i - 1) * stride) + 1]
					local turn = math.rad((#spots * 137.5) % 360)
					table.insert(spots, CFrame.new(origin + Vector3.new(p[1], 0, p[2])) * CFrame.Angles(0, turn, 0))
				end
				left = n - #spots
			end
			reply(player, services.OutfitService:DebugCrowd(spots) .. " stand-ins in the mall")
		end
	elseif command == "car" then
		-- The party cars (LB2; Services/CarService): `car` lists them; `car in
		-- [n]` gets you in (car n, or the first free); `car out`; `car set
		-- <key> <value>` (difficulty Hard, night full, friendsOnly true);
		-- `car honk`.
		local cars = services.CarService
		local sub = args[2]
		if sub == "in" then
			local id = tonumber(args[3])
			if not id then
				for i, car in cars.cars do
					if not car.away and require(Shared.Logic.Cars).count(car) < #car.seats then
						id = i
						break
					end
				end
			end
			local ok, why = cars:Board(player, id or 1)
			reply(player, ok and ("in car " .. tostring(id)) or ("can't: " .. tostring(why)))
		elseif sub == "out" then
			cars:Leave(player, true)
			reply(player, "out")
		elseif sub == "honk" then
			cars:Honk(player)
			reply(player, "honk")
		elseif sub == "set" and args[3] then
			cars:Set(player, args[3], args[4] or "")
			reply(player, "set " .. args[3])
		else
			local lines = {}
			for i, car in cars.cars do
				table.insert(
					lines,
					string.format(
						"%d %s: %s · tape %s · %s %s%s%s",
						i,
						cars.bodies[i].name,
						table.concat(require(Shared.Logic.Cars).riders(car), ","),
						tostring(car.tape),
						car.difficulty,
						car.night,
						car.friendsOnly and " · friends only" or "",
						car.away and " · away" or ""
					)
				)
			end
			reply(player, table.concat(lines, " | "))
		end
	elseif command == "tape" then
		-- `tape [location]`: a rental tape in your hand (LB2), or `tape none`.
		if args[2] == "none" then
			services.RentalService:Take(player)
			reply(player, "no tape")
		else
			-- (Args come lowercased: matched to a location's id.)
			local id = Locations.Default
			for _, location in Locations.List do
				if string.lower(location.id) == (args[2] or "") then
					id = location.id
				end
			end
			services.RentalService:Give(player, id)
			reply(player, "holding " .. id)
		end
	elseif command == "marks" then
		-- `marks <n>`: your Marks set to n (the boutique, LB3).
		local data = services.DataService:Get(player)
		local n = tonumber(args[2])
		if data and n then
			data.Marks = math.clamp(math.floor(n), 0, 1e9)
			services.DataService:Send(player)
			reply(player, "marks " .. data.Marks)
		else
			reply(player, "marks <n>")
		end
	elseif command == "shop" then
		-- `shop [booth|rack] [slot]`: into the boutique's fitting room from
		-- anywhere in the hub (`shop done` out).
		if args[2] == "done" then
			services.ShopService:Done(player)
			reply(player, "out of the fitting room")
		else
			local slots = { bottom = "Bottom", shoes = "Shoes", hair = "Hair", colour = "Colour", face = "Face" }
			local slot = slots[args[3] or ""] or "Top"
			services.ShopService:Open(player, args[2] == "rack" and "rack" or "booth", slot)
			reply(player, "fitting room: " .. tostring(player:GetAttribute(Constants.PlayerAttributes.Trying)))
		end
	elseif command == "face" then
		-- `face <scared|hold|wince|off>`: your face holds a pose for everyone
		-- (Controllers/FaceController), to check the faces without a hunt.
		local pose = args[2] ~= "off" and args[2] or nil
		player:SetAttribute("DebugFace", pose)
		reply(player, "face: " .. tostring(pose or "its own"))
	elseif command == "own" then
		-- `own <garment>` puts it in your wardrobe; `own none` empties it
		-- (the free set stays everyone's); `own` lists what you have.
		local data = services.DataService:Get(player)
		if not data then
			reply(player, "no profile")
		elseif args[2] == "none" then
			data.Owned.garment = {}
			data.Wearing = {}
			services.OutfitService:Redress(player)
			reply(player, "owns only the free set")
		elseif args[2] then
			local found
			for id in Wardrobe.Garments do
				if string.lower(id) == args[2] then
					found = id
				end
			end
			if found then
				Closet.give(data, found)
				reply(player, "owns " .. found)
			else
				reply(player, "own <garment>|none")
			end
		else
			local list = {}
			for id in Wardrobe.Garments do
				if Closet.owns(data, id) then
					table.insert(list, id)
				end
			end
			table.sort(list)
			reply(player, "owns " .. table.concat(list, ", ") .. " · Marks " .. data.Marks)
		end
	elseif command == "ware" then
		-- `ware <kind> <id>`: a torch look, paint, car bit or station yours
		-- and in use (LB4: torch Brass, paint Cream, carbit RoofRack, radio
		-- Hits); `ware none` takes LB4's back; `ware` lists yours.
		local data = services.DataService:Get(player)
		if not data then
			reply(player, "no profile")
		elseif args[2] == "open" then
			-- `ware open counter|pegboard`: its card, as its prompt opens it.
			services.ShopService:Wares(player, args[3] == "pegboard" and "pegboard" or "counter")
			reply(player, "opened " .. (args[3] or "counter"))
		elseif args[2] == "none" then
			for kind in Catalog.Kinds do
				data.Owned[kind] = nil
			end
			data.Wearing.torch = nil
			data.Car = { bits = {} }
			services.ShopService:_show(player)
			reply(player, "LB4's wares taken back")
		elseif args[2] and args[3] then
			local kind, found = args[2], nil
			local k = Catalog.Kinds[kind]
			for id in k and k.items or {} do
				if string.lower(id) == args[3] then
					found = id
				end
			end
			if found then
				data.Owned[kind] = data.Owned[kind] or {}
				data.Owned[kind][found] = true
				services.ShopService:WareUse(player, kind, found, true, "debug", true)
				reply(player, kind .. " " .. found .. " yours and on")
			else
				reply(player, "ware <torch|paint|carbit|radio> <id>|none")
			end
		else
			reply(
				player,
				string.format(
					"torch %s · car %s",
					Catalog.torchOf(data),
					game:GetService("HttpService"):JSONEncode(Catalog.carOf(data))
				)
			)
		end
	elseif command == "arcade" then
		-- HOUSE CALL (LB5; Services/ArcadeService).
		local data = services.DataService:Get(player)
		local arcade = services.ArcadeService
		local all, week = "Arcade_HouseCall_All", "Arcade_HouseCall_W" .. Leaderboard.week(os.time())
		if not data then
			reply(player, "no profile")
		elseif args[2] == "play" then
			arcade:Approach(player, tonumber(args[3]) or 1)
			reply(player, "at cabinet " .. (args[3] or "1"))
		elseif args[2] == "free" then
			data.ArcadeFreeDay = 0
			services.DataService:Send(player)
			reply(player, "today's free play is yours again")
		elseif args[2] == "credits" then
			data.ArcadeCredits = math.max(0, math.floor(tonumber(args[3]) or 0))
			services.DataService:Send(player)
			reply(player, "plays bought: " .. data.ArcadeCredits)
		elseif args[2] == "score" and tonumber(args[3]) then
			task.spawn(function()
				local entry = {
					value = math.floor(tonumber(args[3]) :: number),
					key = args[4] or tostring(player.UserId),
					name = args[4] and string.upper(args[4]) or player.DisplayName,
					at = os.time(),
				}
				local w = services.BoardService:Post(week, entry, Config.Arcade.BoardSize, false, true)
				local a = services.BoardService:Post(all, entry, Config.Arcade.BoardSize, false, true)
				reply(player, string.format("score %d: week %s, all-time %s", entry.value, tostring(w), tostring(a)))
			end)
		elseif args[2] == "clear" then
			services.BoardService:Clear(week)
			services.BoardService:Clear(all)
			reply(player, "the high scores emptied")
		elseif args[2] == "bot" then
			-- A game of random presses through the server's own check and the
			-- boards, as BOT; `bot cheat` claims 1,000 more than it scored.
			local seed = Random.new():NextInteger(1, 2147483646)
			local rng = Random.new(seed)
			local s = HouseCall.new(seed)
			local events, value, last = {}, 0, -1
			while not s.over do
				if s.tick % 10 == 0 then
					value = rng:NextInteger(1, 4)
				end
				if value ~= last then
					table.insert(events, s.tick + 1)
					table.insert(events, value)
					last = value
				end
				HouseCall.step(s, value)
			end
			local claim = args[3] == "cheat" and s.score + 1000 or s.score
			local why = arcade:Check(seed, events, s.tick, claim)
			if why then
				reply(player, string.format("BOT's %d dropped: %s", claim, why))
			else
				task.spawn(function()
					local w, a = arcade:PostScore("bot", "BOT", s.score)
					reply(
						player,
						string.format(
							"BOT scored %d in %d presses: week %s, all-time %s",
							s.score,
							#events / 2,
							tostring(w),
							tostring(a)
						)
					)
				end)
			end
		else
			local today = Progression.day(os.time())
			reply(
				player,
				string.format(
					"a play now: %s · free today %s · plays bought %d · Marks %d",
					Credits.how(data, today, arcade:_pass(player)) or "the coin card",
					tostring(Credits.freeToday(data, today)),
					data.ArcadeCredits,
					data.Marks
				)
			)
		end
	elseif command == "lore" then
		-- The lobby's things to read (Data/Lore): `lore` lists them, `lore <id>`
		-- reads one to you wherever you are (drafts too, for the owner's look).
		local found
		for _, entry in Lore do
			if args[2] and string.lower(entry.id) == args[2] then
				found = entry
			end
		end
		if found then
			services.LoreService:Read(player, found)
			reply(player, "reading " .. found.id)
		else
			local ids = {}
			for _, entry in Lore do
				table.insert(ids, entry.id .. (entry.draft and " (draft)" or ""))
			end
			reply(player, "lore <id>: " .. table.concat(ids, ", "))
		end
	elseif command == "record" then
		-- The diner's boards (LB5; Services/RecordsService).
		local records = services.RecordsService
		if args[2] == "count" then
			records.forceNext = true
			reply(player, "the next run counts for the boards (Studio's)")
		elseif args[2] == "clear" then
			for _, difficulty in Records.Difficulties do
				for _, list in Records.Lists do
					services.BoardService:Clear(Records.board(difficulty, list.id))
				end
			end
			reply(player, "the diner's boards emptied")
		elseif args[2] == "add" and tonumber(args[6]) then
			local difficulty = args[3] == "hard" and "Hard" or "Normal"
			local fast = args[4] ~= "long"
			local solo = args[5] ~= "squad"
			local names = {}
			for i = 7, #args do
				table.insert(names, string.upper(args[i]))
			end
			if #names == 0 then
				table.insert(names, player.DisplayName)
			end
			local id = (fast and "Fast" or "Long") .. (solo and "Solo" or "Squad")
			local entry = {
				value = math.floor((tonumber(args[6]) :: number) * 10),
				names = solo and { names[1] } or names,
				size = solo and 1 or math.max(2, #names),
				at = os.time(),
			}
			task.spawn(function()
				local rank = services.BoardService:Post(Records.board(difficulty, id), entry, Records.Size, fast)
				reply(player, string.format("%s %s: place %s", difficulty, id, tostring(rank)))
			end)
		else
			local lines = {}
			for _, difficulty in Records.Difficulties do
				for _, list in Records.Lists do
					local top = services.BoardService:Get(Records.board(difficulty, list.id))[1]
					table.insert(lines, difficulty .. " " .. list.id .. ": " .. Records.line(top, list.solo))
				end
			end
			reply(player, table.concat(lines, " · ") .. (records.forceNext and " (the next run counts)" or ""))
		end
	elseif command == "buy" then
		-- `buy <product|pass>`: a purchase as Roblox sends it after "Buy" (a
		-- test receipt through the game's own handler, no Robux), or a pass as
		-- if just bought: to test what each grants.
		local found
		for name in Products.Products do
			if string.lower(name) == (args[2] or "") then
				found = name
			end
		end
		for name in Products.Passes do
			if string.lower(name) == (args[2] or "") then
				found = name
			end
		end
		if found then
			task.spawn(function()
				reply(player, services.MonetizationService:TestBuy(player, found))
			end)
		else
			reply(player, "buy <MarksSmall|MarksMedium|MarksLarge|ArcadePlay|ArcadeTen|StarterPack|ArcadeUnlimited>")
		end
	elseif command == "gift" then
		-- `gift <product>`: a gift to yourself as if a friend had bought it
		-- (MarksSmall, ArcadeTen...): granted, its wrapped box at your feet.
		local found = "MarksSmall"
		for name in Products.Products do
			if string.lower(name) == (args[2] or "") then
				found = name
			end
		end
		reply(player, services.ShopService:DebugGift(player, found))
	elseif command == "starter" then
		-- `starter`: the starter pack's slip, as after a first run (once
		-- only, unless `starter again`).
		local data = services.DataService:Get(player)
		if data then
			if args[2] == "again" then
				data.StarterOffered = false
			end
			data.RunsPlayed = math.max(data.RunsPlayed, 1)
			services.ShopService:CheckOffer(player)
			reply(player, data.StarterOffered and "offered (or not on sale yet: no product id)" or "not offered")
		end
	elseif command == "ui" then
		-- Open a screen on your client: `ui map|journal|note|dossier|settings|
		-- title|toasts|close` (Controllers/UIController:_debugUi).
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
	elseif command == "disguise" then
		-- Him wearing a friend's look, for you (StalkerService:_disguise).
		reply(player, services.StalkerService:DebugDisguise(player, args[2]))
	elseif command == "beat" then
		-- A scare he sets up for you (StalkerService:_beat): behind|dark|hand.
		reply(player, services.StalkerService:DebugBeat(player, args[2]))
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
	elseif command == "find" then
		-- A drawer find in front of you (Data/Finds): `find PillBottle`.
		reply(player, services.FindService:DebugMake(player, args[2]))
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
			-- Things hung on walls outside the rooms' own models (the Decor
			-- folder's clocks and portraits, puzzle boxes, racks), by the room
			-- they stand in.
			local extras = {}
			local content = services.WorldService.content
			local function add(model: Model)
				local id = services.WorldService:RoomAt(model:GetPivot().Position)
				if id then
					extras[id] = extras[id] or {}
					table.insert(extras[id], model)
				end
			end
			-- (Fixed to a wall or a door by design, or overhead: not worth a line.)
			local onWalls =
				{ Lever = true, BellBoard = true, Boards = true, Chain = true, PuzzleLamp = true, CrankDoor = true }
			for _, child in content and content:GetChildren() or {} do
				if child:IsA("Folder") then
					for _, model in child:GetChildren() do
						if model:IsA("Model") and not onWalls[model.Name] then
							add(model)
						end
					end
				elseif child:IsA("Model") and not onWalls[child.Name] then
					-- Run things kept loose in the content (the home computer, an
					-- heirloom, a key, a toy): the progression audit found the
					-- computer and the music box on one spot, unseen by this scan.
					add(child)
				end
			end
			for _, id in services.WorldService:RoomIds() do
				local room = services.WorldService:Room(id)
				if room and room.model then
					for _, line in ClipScan.room(room.name or ("room " .. id), room.model, extras[id]) do
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
	elseif command == "storm" then
		-- The storm (Services/WeatherService, Logic/Storm): `storm 0|1|2` holds a
		-- stage, `storm auto` gives it back to Dread, `storm strike` strikes now.
		local weather = services.WeatherService
		local arg = args[2]
		if arg == "strike" then
			reply(player, weather:StrikeNow() and "lightning" or "no run")
		elseif arg == "auto" then
			weather.forced = nil
			reply(player, "the storm follows Dread again")
		elseif tonumber(arg) and tonumber(arg) >= 0 and tonumber(arg) <= 2 then
			weather.forced = tonumber(arg)
			reply(player, "storm held at " .. arg .. " (0 still, 1 rain, 2 thunder)")
		else
			reply(
				player,
				"storm: "
					.. tostring(ReplicatedStorage.RunState:GetAttribute(Constants.RunState.Storm))
					.. " (storm 0|1|2|auto|strike)"
			)
		end
	elseif command == "kit" and not args[2] then
		-- Which modelled pieces are in (World/Kit, Data/Kit).
		local names, failed = Kit.preload()
		reply(
			player,
			("kit: %d loaded (%s)%s"):format(
				#names,
				table.concat(names, ", "),
				#failed > 0 and (", failed: " .. table.concat(failed, ", ")) or ""
			)
		)
	elseif command == "kit" and args[2] == "probe" then
		-- The visual rework's V0 question: can a game script build a kit
		-- piece from asset ids alone (a mesh, then a SurfaceAppearance's
		-- maps)? `kit probe <mesh id> [image id]`, placed in front of you.
		local AssetService = game:GetService("AssetService")
		local meshId = tonumber(args[3])
		local imageId = tonumber(args[4]) or 128745649799331 -- the lens's glare, any image will do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not meshId or not root then
			reply(player, "usage: kit probe <mesh id> [image id]")
			return
		end
		local lines = {}
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. meshId))
		end)
		table.insert(lines, "CreateMeshPartAsync: " .. (ok and "ok" or tostring(part)))
		if ok and part then
			part.Anchored = true
			part.CFrame = root.CFrame * CFrame.new(0, 0, -6)
			part.Name = "KitProbe"
			local appearance = Instance.new("SurfaceAppearance")
			local set = pcall(function()
				appearance.ColorMapContent = Content.fromUri("rbxassetid://" .. imageId)
			end)
			table.insert(lines, "SurfaceAppearance.ColorMapContent: " .. (set and "ok" or "refused"))
			local legacy = pcall(function()
				(appearance :: any).ColorMap = "rbxassetid://" .. imageId
			end)
			table.insert(lines, "SurfaceAppearance.ColorMap: " .. (legacy and "ok" or "refused"))
			appearance.Parent = part
			part.Parent = workspace
		end
		print("[Consensus] kit probe: " .. table.concat(lines, " · "))
		reply(player, table.concat(lines, " · "))
	elseif command == "look" then
		-- The visual rework's fixed shots (Data/LookSpots): `look <name>` puts
		-- you and your view on a spot of this house; `look save <name>` prints
		-- where you stand and look, to paste into Data/LookSpots.
		local key = (services.RunOrchestrator.layoutMode or Config.Level.Mode)
			.. ":"
			.. tostring(ReplicatedStorage.RunState:GetAttribute(Constants.RunState.Seed))
		local spots = LookSpots[key] or {}
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if args[2] == "save" and args[3] and root then
			local view = services.WitnessService:GetView(player)
			local look = view and (view.Position + view.LookVector * 12)
				or (root.Position + root.CFrame.LookVector * 12)
			local line = string.format(
				"%s = { at = { %.1f, %.1f, %.1f }, look = { %.1f, %.1f, %.1f } },",
				args[3],
				root.Position.X,
				root.Position.Y - 3,
				root.Position.Z,
				look.X,
				look.Y,
				look.Z
			)
			print("[Consensus] look spot for " .. key .. ":  " .. line)
			reply(player, "printed to Output: " .. line)
			return
		end
		local spot = spots[args[2] or ""]
		if not spot or not character then
			local names = {}
			for name in spots do
				table.insert(names, name)
			end
			table.sort(names)
			reply(player, key .. " spots: " .. (#names > 0 and table.concat(names, ", ") or "none (look save <name>)"))
			return
		end
		services.PlayerStateService:MarkTeleport(player)
		character:PivotTo(CFrame.new(spot.at[1], spot.at[2] + 3, spot.at[3]))
		player:SetAttribute("DebugLookAt", nil)
		player:SetAttribute("DebugLookAt", Vector3.new(spot.look[1], spot.look[2], spot.look[3]))
		if spot.guest then
			self:Run(player, "guest here " .. spot.guest)
		end
		reply(player, "look: " .. args[2] .. " (" .. key .. ")")
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
	elseif command == "role" then
		local places = services.PlaceService
		reply(player, places and places:Describe() or "no PlaceService")
	elseif command == "mallsound" then
		-- Audition the lobby mall's sounds (Assets.Mall): the role's n-th
		-- candidate plays for everyone at once (Controllers/MallController).
		local role
		for name, list in Assets.Mall do
			-- (A role is a list of sounds; Stations is a table of them.)
			if string.lower(name) == args[2] and #list > 0 then
				role = name
			end
		end
		if not role then
			reply(player, "mallsound <Hum|Buzz|Drip|Radio|Arcade|Sputter|Horn> [n]")
		else
			local list = Assets.Mall[role]
			local n = math.clamp(tonumber(args[3]) or 1, 1, #list)
			ReplicatedStorage.RunState:SetAttribute(Constants.RunState.MallSound .. role, n)
			if role == "Sputter" and services.MallService then
				services.MallService:BrownoutNow()
			end
			local character = player.Character
			if role == "Horn" and character then
				services.CarService:Sound(nil, character:GetPivot().Position)
			end
			reply(player, string.format("%s: candidate %d of %d (%s)", role, n, #list, list[n]))
		end
	elseif command == "stepvolume" then
		-- Tune the steps seen from outside by ear (Controllers/FootstepController).
		local share = tonumber(args[2])
		share = share and math.clamp(share, 0, 2)
		ReplicatedStorage.RunState:SetAttribute(Constants.RunState.StepVolume, share)
		reply(
			player,
			share and string.format("steps seen from outside at %.2f of full volume", share)
				or string.format("steps seen from outside back to %.2f (Config)", Config.Feel.FootstepVolumeSeen)
		)
	elseif command == "ads" then
		-- The lobby mall's ad frames (LB6; Logic/Ads): their state, or every
		-- frame's AdGui up (Studio shows its grey card where no poster of ours
		-- is uploaded), ours on every frame, or back to the rule; `deny` and
		-- `allow` answer for you as PolicyService would (Controllers/AdController).
		local mode = args[2]
		if mode == "deny" or mode == "allow" or mode == "policy" then
			local answer = nil
			if mode ~= "policy" then
				answer = mode == "allow"
			end
			player:SetAttribute("DebugAdsAllowed", answer)
		elseif mode == "ad" or mode == "poster" or mode == "live" then
			local slots = {}
			for _, slot in Mall.Ads do
				slots[slot.slot] = slot
			end
			for _, face in CollectionService:GetTagged(Constants.Tags.AdFace) do
				local slot = slots[face:GetAttribute("AdSlot")]
				if slot then
					MallBuilder.dressAd(face, slot, mode ~= "live" and mode or nil)
				end
			end
		elseif mode ~= nil then
			reply(player, "ads [ad|poster|live|deny|allow|policy]")
			return
		end
		local lines = {}
		for _, face in CollectionService:GetTagged(Constants.Tags.AdFace) do
			local gui = face:FindFirstChildOfClass("AdGui")
			table.insert(
				lines,
				string.format(
					"%s: %s%s",
					tostring(face:GetAttribute("AdSlot")),
					gui and "AdGui up" or "our poster",
					gui and (" (" .. gui.Status.Name .. ")") or ""
				)
			)
		end
		table.sort(lines)
		local forced = player:GetAttribute("DebugAdsAllowed")
		table.insert(
			lines,
			"you: "
				.. (
					type(forced) == "boolean" and (forced and "allowed (forced)" or "denied (forced)")
					or "as PolicyService says"
				)
		)
		print("[debug] ads\n" .. table.concat(lines, "\n"))
		reply(player, table.concat(lines, " · "))
	elseif command == "brownout" then
		if services.MallService then
			services.MallService:BrownoutNow()
			reply(player, "the generator coughs")
		end
	elseif command == "mallstrike" then
		if services.MallService then
			services.MallService:StrikeNow()
			reply(player, "lightning over the mall")
		end
	elseif command == "perf" then
		-- (The server's side; the F2 overlay adds your client's, Ui/DebugOverlay.)
		local lights, shadows, meshes, people = 0, 0, 0, #Players:GetPlayers()
		for _, d in Workspace:GetDescendants() do
			if d:IsA("Light") and d.Enabled then
				lights += 1
				if d.Shadows then
					shadows += 1
				end
			elseif d:IsA("MeshPart") then
				meshes += 1
			end
		end
		local crowd = Workspace:FindFirstChild("DebugCrowd")
		reply(
			player,
			string.format(
				"server heartbeat %.1f ms · %d instances · %.0f MB · %d lights (%d shadows) · %d meshes · %d players + %d stand-ins",
				Stats.HeartbeatTimeMs or 0,
				Stats.InstanceCount,
				Stats:GetTotalMemoryUsageMb(),
				lights,
				shadows,
				meshes,
				people,
				crowd and #crowd:GetChildren() or 0
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
