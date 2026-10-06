-- The bot (docs/progress/2026-10-07-loop/REPORT.md, WP1): F2 `botrun` plays
-- the escape on the server with the caller's own character, from the front
-- door to the dinner and out, using the real server entry points the prompts
-- use (a drawer's Toggle, a Grab, a lock's try, a crank, a puzzle solved as
-- if played, a place set), and reports what a human would have hit: time to
-- the first door, the dinner and the way out, steps that had no way or got
-- stuck, hints the house emitted, hunts and how each ended, downs, torch
-- deaths, silent minutes. It is the yardstick for every rule change: run it
-- on a few seeds before and after.
--
-- The body: the player's HumanoidRootPart is taken by the server for the
-- run (SetNetworkOwner(nil)) and walked by Stalker/Walker the way the
-- Companion once was; the client's movement input does nothing meanwhile
-- (PA.BotDriven). An heirloom the bot carries is pinned at its head each
-- Heartbeat (HandsService ServerCarry), since only a client carries what it
-- picked up itself.
--
--   botrun [fast] [flee|hide]   play (fast: at a sprint; flee: run from a
--                               hunt; hide: hide from one); botrun again stops
--   botrun plan                 print the steps without moving

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotPlan = require(Shared.Logic.BotPlan)
local Config = require(Shared.Config)
local LockPlanner = require(Shared.Logic.LockPlanner)
local Constants = require(Shared.Constants)
local Props = require(Shared.Data.Props)

local Walker = require(script.Parent.Parent.Stalker.Walker)

local PA = Constants.PlayerAttributes
local States = Constants.PlayerStates
local B = Config.Bot

local BotService = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A puzzle's station is a part (the fuse box's face, the dumbwaiter's wheel)
-- or a record with a position or a frame (server/Puzzles/*).
local function stationPosition(station): Vector3?
	if typeof(station) == "Instance" then
		return station:IsA("BasePart") and station.Position or (station:IsA("Model") and station:GetPivot().Position)
	elseif type(station) == "table" then
		if typeof(station.position) == "Vector3" then
			return station.position
		elseif typeof(station.frame) == "CFrame" then
			return station.frame.Position
		elseif typeof(station.Position) == "Vector3" then
			return station.Position
		end
	end
	return nil
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BotService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.active = false
	self.player = nil
end

function BotService:Start()
	local services = self.services
	services.WorldService.Cleared:Connect(function()
		if self.active then
			self:Stop("the house was cleared")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if self.active and player == self.player then
			self:Stop("the player left")
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not self.active then
			return
		end
		local ok, err = pcall(self._heartbeat, self)
		if not ok then
			warn("[Consensus] botrun heartbeat failed: " .. tostring(err))
		end
	end)
end

-- Every frame: walk, and keep a carried heirloom at the bot's head.
function BotService:_heartbeat()
	local now = os.clock()
	if self.walker and self.walker.destination then
		self.walker:Step(now)
	end
	-- A down, a revive or a teleport hands the body back to the client:
	-- take it again, or the server's MoveTo moves nothing.
	if now - (self.ownedAt or 0) > 1 then
		self.ownedAt = now
		local root = self.PlayerState:Root(self.player)
		if root and not root.Anchored then
			pcall(function()
				if root:GetNetworkOwner() ~= nil then
					root:SetNetworkOwner(nil)
				end
			end)
		end
	end
	local thing = self.carry
	if thing and thing.root and thing.root.Parent and thing.holder == self.player then
		local head = self.PlayerState:Head(self.player)
		if head then
			thing.root.CFrame = head.CFrame * CFrame.new(0.5, -0.6, -1.6)
			thing.lastValid = thing.root.CFrame
			thing.lastValidAt = now
		end
	elseif thing then
		self.carry = nil
	end
end

-- Starting and stopping ----------------------------------------------------------

function BotService:Run(player: Player, args: { string }, report: (string) -> ()): string
	if self.active then
		self:Stop("stopped by F2")
		return "botrun stopped"
	end
	local services = self.services
	local run = services.RunOrchestrator.run
	local world = self.World.World
	local plan = world and world.layout and world.layout.progression
	if not run or not world or not plan then
		return "no run: start one first"
	end
	if args[2] == "plan" then
		return self:_dryRun(plan)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return "no character"
	end
	self.player = player
	self.report = report
	self.fast = table.find(args, "fast") ~= nil
	self.onHunt = table.find(args, "hide") and "hide" or table.find(args, "flee") and "flee" or "work"
	self.speed = self.fast and B.SprintSpeed or B.WalkSpeed
	self.started = os.clock()
	self.blocked = {}
	self.failures = {} -- step key -> count
	self.stuckPoints = {}
	self.noWays = 0
	self.steps = 0
	self.cheated = 0
	self.lines = {}
	self.carry = nil
	self.result = nil
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	player:SetAttribute(PA.BotDriven, true)
	self.PlayerState:SetFlashlight(player, true)
	self.walker = Walker.new(services, {
		model = character,
		humanoid = humanoid,
		root = root,
		groundOffset = humanoid.HipHeight + root.Size.Y / 2,
		group = Constants.CollisionGroups.Players,
		halfWidth = 1,
		path = Walker.CompanionPath,
		opensDoors = "companion",
		who = "player",
		player = player, -- doors swing away from the body (Stalker/Walker)
	}, Random.new(run.seed or 1))
	self.active = true
	task.spawn(function()
		local ok, err = pcall(self._main, self)
		if not ok then
			warn("[Consensus] botrun failed: " .. tostring(err))
			self:Stop("error: " .. tostring(err))
		end
	end)
	return string.format(
		"botrun: playing%s, %s through hunts (botrun again stops it)",
		self.fast and " at a run" or "",
		self.onHunt
	)
end

function BotService:Stop(reason: string)
	if not self.active then
		return
	end
	self.active = false
	self.result = self.result or reason
	local player = self.player
	if self.walker then
		self.walker:Stop()
		self.walker = nil
	end
	local thing = self.carry
	if thing then
		self.carry = nil
		if thing.root and thing.root.Parent and thing.state == "held" then
			thing.serverCarried = nil
			thing.root.Anchored = false
		end
	end
	if player and player.Parent then
		player:SetAttribute(PA.BotDriven, nil)
		local root = self.PlayerState:Root(player)
		if root then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
	end
	self:_report(reason)
end

-- The main loop ---------------------------------------------------------------------

function BotService:_log(text: string)
	local line = string.format("%s %s", clock(os.clock() - self.started), text)
	print("[botrun] " .. line)
	table.insert(self.lines, line)
	if #self.lines > 200 then
		table.remove(self.lines, 1)
	end
end

function BotService:_alive(): string?
	local player = self.player
	if not player or not player.Parent then
		return "the player left"
	end
	local state = self.PlayerState:State(player)
	if state == States.Lost then
		return "lost"
	elseif state == States.Extracted then
		return "extracted"
	end
	local run = self.services.RunOrchestrator.run
	if not run or run.ending then
		return "the run ended"
	end
	return nil
end

function BotService:_main()
	local services = self.services
	local plan = self.World.World.layout.progression
	self:_log("start" .. (self.fast and " (fast)" or ""))
	while self.active do
		local over = self:_alive()
		if over then
			self.result = over
			break
		end
		-- Downed: wait to be up (the crawl rules are the house's), then go on.
		if self.PlayerState:State(self.player) == States.Downed then
			self.walker:Stop()
			task.wait(0.5)
			continue
		end
		if self.onHunt ~= "work" and services.StalkerService:IsHunting() then
			self:_hunt()
			continue
		end
		local state = self:_state()
		local step = BotPlan.next(plan, state)
		if not step then
			self:_log("nothing left to do")
			self:_dumpState(plan, state)
			self.result = services.FinaleService.served and "served, no way out found" or "stuck: no step left"
			break
		end
		self.steps += 1
		local began = os.clock()
		local ok, why = self:_do(step)
		local took = os.clock() - began
		self:_log(string.format("%s %s: %s in %.1fs", step.kind, self:_name(step), ok and "ok" or why, took))
		if not ok then
			if why == "hunt" or why == "down" or why == "key not held" then
				-- Interrupted, not failed: the step comes round again.
				self:_log("   interrupted: " .. why)
				continue
			end
			self.failures[step.key] = (self.failures[step.key] or 0) + 1
			if why == "no way" then
				self.noWays += 1
			end
			if self.failures[step.key] >= 2 or why == "no way" then
				self.blocked[step.key] = true
				local room = self.World:RoomAt(self.PlayerState:Position(self.player) or Vector3.zero)
				table.insert(self.stuckPoints, {
					at = clock(os.clock() - self.started),
					step = step.key,
					why = why,
					room = room and self.World:Room(room).name or "?",
				})
			end
		end
		task.wait(0.2)
	end
	self:Stop(self.result or "done")
end

-- Why the bot stopped: what it could reach and what it had (to Output).
function BotService:_dumpState(plan, state)
	local function keys(t)
		local out = {}
		for k, v in t or {} do
			if v then
				table.insert(out, tostring(k))
			end
		end
		table.sort(out)
		return table.concat(out, " ")
	end
	local needed = {}
	for id in BotPlan.needed(plan, state.opened, state.pieceOpen) do
		if not state.had[id] then
			local token = plan.tokens[id]
			local rooms = token and LockPlanner.producerRooms(plan, token) or {}
			local where = {}
			for _, room in rooms do
				table.insert(where, string.format("%d%s", room, state.reachable[room] and "" or " (out of reach)"))
			end
			table.insert(needed, string.format("%s in %s", id, table.concat(where, ",")))
		end
	end
	table.sort(needed)
	print(
		string.format(
			"[botrun] state: reach %s · had %s · made %s · held %s · opened %s · blocked %s · still needed: %s",
			keys(state.reachable),
			keys(state.had),
			keys(state.made),
			tostring(state.held),
			keys(state.opened),
			keys(state.blocked),
			table.concat(needed, "; ")
		)
	)
end

function BotService:_name(step): string
	local plan = self.World.World.layout.progression
	local room = step.room and self.World:Room(step.room)
	local where = room and (" in the " .. room.name) or ""
	if step.kind == "door" or step.kind == "toolDoor" or step.kind == "crank" then
		return string.format("%s (%s)%s", step.seam, step.lockKind or step.kind, where)
	elseif step.kind == "puzzle" then
		return string.format("%s%s", step.id, where)
	elseif step.kind == "piece" then
		return string.format("%s%s", step.piece, where)
	elseif step.token then
		local label = plan.tokens[step.token] and plan.tokens[step.token].label
		return string.format("%s%s%s", step.token, label and (" " .. label) or "", where)
	end
	return ""
end

-- What the squad has, as Logic/BotPlan reads it.
function BotService:_state()
	local services = self.services
	local locks, items, tools, puzzles =
		services.LockService, services.ItemService, services.ToolService, services.PuzzleService
	local plan = self.World.World.layout.progression
	local player = self.player
	local had, made, opened, pieceOpen, set, seams = {}, {}, {}, {}, {}, {}
	-- Found once is not held now: a down drops the ring where you fall
	-- (ItemService), so a key counts only while it is on someone's ring.
	for token in items.found do
		local info = plan.tokens[token]
		if info and info.kind ~= "key" then
			had[token] = true
		end
	end
	for _, held in locks:HeldKeys() do
		had[held.token] = true
	end
	-- Every doorway (a crank door is CrankService's, not LockService's).
	for seamId, seam in self.World.World.seams do
		seams[seamId] = { a = seam.a, b = seam.b }
	end
	for seamId, entry in locks.locks do
		if entry.open then
			opened[seamId] = true
		end
	end
	for seamId, lock in plan.locks do
		if lock.kind == "crank" then
			local crank = services.CrankService:Get(seamId)
			if crank and not crank.blocked then
				opened[seamId] = true -- up: passable now
			end
		end
	end
	for id, entry in locks.pieceLocks do
		if entry.open then
			pieceOpen[id] = true
		end
	end
	-- Things lying in the house that the plan wants: take them.
	local thingOf = {}
	for _, thing in services.HandsService.things do
		local token = thing.model and thing.model:GetAttribute("Item")
		if token and plan.tokens[token] and thing.model.Parent and thing.state ~= "gone" then
			thingOf[token] = thing
			if not thing.holder then
				made[token] = true
			end
		end
	end
	self.thingOf = thingOf
	local heldThing = services.HandsService:Held(player)
	local held = heldThing and heldThing.model:GetAttribute("Item") or nil
	for id, token in plan.tokens do
		if token.kind == "tool" then
			if tools:Carries(player, token.tool) then
				had[id] = true
			end
		elseif token.producer.kind == "puzzle" then
			local session = puzzles.sessions[token.producer.id]
			local solved = session and session.state and session.state.solved
			if solved and token.kind ~= "bulky" and token.kind ~= "heirloom" then
				had[id] = true
			end
		end
		if token.kind == "bulky" or token.kind == "heirloom" then
			-- Had only once in hand or set (a puzzle's heirloom lies there first).
			local state = items.heirlooms[id]
			had[id] = (state ~= nil and (state.set or state.holder ~= nil)) or held == id
			if had[id] then
				made[id] = nil
			end
		end
	end
	for _, place in services.FinaleService.places do
		if place.token then
			set[place.token] = true
			had[place.token] = true
		end
	end
	return {
		reachable = locks.reach,
		had = had,
		made = made,
		held = held,
		opened = opened,
		pieceOpen = pieceOpen,
		set = set,
		seams = seams,
		served = services.FinaleService.served == true,
		blocked = self.blocked,
	}
end

-- Walking ----------------------------------------------------------------------------

-- Walk to a point. Returns "ok", "no way", "stuck", "down" (caught on the
-- way) or "hunt" (interrupted).
function BotService:_walkTo(target: Vector3, within: number?, maxSeconds: number?): string
	local walker = self.walker
	local here = self.PlayerState:Position(self.player)
	if not here then
		return "stuck"
	end
	local reach = within or 2.5
	if (flat(here) - flat(target)).Magnitude <= reach and math.abs(here.Y - target.Y) < 6 then
		return "ok"
	end
	walker:SetDestination(target, { speed = self.speed, force = true })
	local route = self.World:Route(here, target, { who = "player" })
	local length = math.max((here - target).Magnitude, route and route.cost or 0)
	local timeout = maxSeconds or math.max(B.LegTimeout, length / self.speed * 3 + 15)
	local began = os.clock()
	local noWaySince = nil
	local bestDistance, bestAt = math.huge, began
	while self.active and os.clock() - began < timeout do
		task.wait(0.2)
		if self.onHunt ~= "work" and self.services.StalkerService:IsHunting() then
			walker:Stop()
			return "hunt"
		end
		if self.PlayerState:State(self.player) ~= States.Active then
			walker:Stop()
			return "down"
		end
		local pos = self.PlayerState:Position(self.player)
		local distance = pos and (flat(pos) - flat(target)).Magnitude or math.huge
		if pos and distance <= reach and math.abs(pos.Y - target.Y) < 6 then
			walker:Stop()
			return "ok"
		end
		-- Close, and no closer for a while (furniture between): near enough
		-- for a hand's reach (Grab 9.5, a pickup 6, a prompt).
		if distance < bestDistance - 0.3 then
			bestDistance, bestAt = distance, os.clock()
		elseif os.clock() - bestAt > 5 and distance <= reach + 3 and pos and math.abs(pos.Y - target.Y) < 6 then
			walker:Stop()
			return "ok"
		end
		if walker:Arrived() then
			walker:Stop()
			local at = self.PlayerState:Position(self.player)
			if at and (flat(at) - flat(target)).Magnitude <= reach + 2 then
				return "ok"
			end
			return "stuck"
		end
		if walker:Unreachable() then
			noWaySince = noWaySince or os.clock()
			if os.clock() - noWaySince > 3 then
				walker:Stop()
				return "no way"
			end
		else
			noWaySince = nil
		end
	end
	self:_log("   " .. walker:Describe())
	walker:Stop()
	return "stuck"
end

-- A clear spot on the floor beside something (a pickup on a dresser, a case,
-- a chest, a station), the way a player stands to reach it: a ring of
-- candidates around it, each checked for furniture in the body's space and
-- for being inside the room; the nearest to the bot wins. Falls back to the
-- floor under the thing.
function BotService:_standNear(target: Vector3, room: number?, ignore: { Instance }?): Vector3
	local floorY = self.World:FloorBase(target.Y)
	local here = self.PlayerState:Position(self.player)
	local params = OverlapParams.new()
	local exclude = { self.player.Character }
	for _, instance in ignore or {} do
		table.insert(exclude, instance)
	end
	params.FilterDescendantsInstances = exclude
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best, bestScore = nil, math.huge
	for _, radius in { 2.6, 3.4, 4.2 } do
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			local candidate =
				Vector3.new(target.X + math.cos(angle) * radius, floorY, target.Z + math.sin(angle) * radius)
			local roomHere = self.World:RoomAt(candidate)
			if roomHere == nil or (room and roomHere ~= room) then
				continue
			end
			local body = CFrame.new(candidate + Vector3.new(0, 2.6, 0))
			local blocked = false
			for _, part in workspace:GetPartBoundsInBox(body, Vector3.new(1.8, 4.4, 1.8), params) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				local score = radius + (here and (flat(here) - flat(candidate)).Magnitude * 0.1 or 0)
				if score < bestScore then
					best, bestScore = candidate, score
				end
			end
		end
	end
	return best or Vector3.new(target.X, floorY, target.Z)
end

-- A spot to stand in front of a piece of furniture (its frame faces out of
-- its front), on the floor, inside the room.
function BotService:_frontOf(frame: CFrame, kind: string?, room: number?): Vector3
	local size = kind and Props.Kinds[kind] and Props.Kinds[kind].size
	local depth = size and size[3] or 2
	local point = frame.Position + frame.LookVector * (depth / 2 + 2.2)
	point = Vector3.new(point.X, self.World:FloorBase(frame.Position.Y), point.Z)
	if self.World:RoomAt(point) == nil and room then
		local back = frame.Position - frame.LookVector * (depth / 2 + 2.2)
		back = Vector3.new(back.X, point.Y, back.Z)
		if self.World:RoomAt(back) ~= nil then
			return back
		end
		return self.World:Room(room).center
	end
	return point
end

function BotService:_floor(position: Vector3): Vector3
	return Vector3.new(position.X, self.World:FloorBase(position.Y), position.Z)
end

-- The steps ----------------------------------------------------------------------------

-- Returns ok, and why not.
function BotService:_do(step): (boolean, string?)
	local kind = step.kind
	if kind == "extract" then
		return self:_extract()
	elseif kind == "set" then
		return self:_set(step)
	elseif kind == "take" then
		return self:_take(step.token)
	elseif kind == "door" or kind == "toolDoor" then
		return self:_door(step)
	elseif kind == "crank" then
		return self:_crank(step)
	elseif kind == "piece" then
		return self:_piece(step)
	elseif kind == "tool" then
		return self:_tool(step)
	elseif kind == "puzzle" then
		return self:_puzzle(step)
	elseif kind == "look" then
		return self:_look(step)
	end
	return false, "unknown step " .. tostring(kind)
end

function BotService:_door(step): (boolean, string?)
	local services = self.services
	local entry = services.LockService.locks[step.seam]
	if not entry or not entry.door then
		return false, "no such lock"
	end
	if entry.open then
		return true
	end
	local seam = entry.seam
	local far = step.room == seam.a and seam.b or seam.a
	local at = self.World:ApproachPoint(step.room, far, 3)
	local walked = self:_walkTo(at, 3)
	if walked ~= "ok" then
		return false, walked
	end
	local player = self.player
	local kind = entry.lock.kind
	if
		(kind == "key" or kind == "pocket" or kind == "double") and not services.LockService:HasKey(player, step.token)
	then
		return false, "key not held" -- dropped on the way (a down): back for it first
	end
	services.LockService:_try(entry.door, player, "prompt")
	if kind == "padlock" then
		-- The padlock's wheels, turned as if the code were read.
		task.wait(0.6)
		services.PuzzleService:DebugSolve(player, "padlock:" .. step.seam)
		self.cheated += 1
	elseif step.kind == "toolDoor" then
		-- Pry or cut, one hold at a time.
		local work = entry.work or {}
		local holds = (work.steps or 4) + 2
		for _ = 1, holds do
			if entry.open or not self.active then
				break
			end
			task.wait((work.seconds or 1.5) + 0.3)
			services.LockService:_try(entry.door, player, "prompt")
		end
	end
	task.wait(1.2)
	if not entry.open then
		return false, "the lock would not open"
	end
	-- Through it, so the next route starts on the far side (briefly: the
	-- next step routes from wherever this ends).
	self:_walkTo(self.World:ApproachPoint(far, step.room, 3), 3, 12)
	return true
end

function BotService:_crank(step): (boolean, string?)
	local services = self.services
	local crank = services.CrankService:Get(step.seam)
	if not crank then
		return false, "no crank"
	end
	if crank.latched then
		return true
	end
	local stand = crank.wheelAt and (crank.wheelAt.Position + crank.wheelAt.LookVector * 2.5) or crank.crankAt
	stand = self:_floor(stand)
	local walked = self:_walkTo(stand, 3)
	if walked ~= "ok" then
		return false, walked
	end
	-- The ratchet set, the crank held: it rises slowly and holds itself.
	crank.ratchet = true
	crank.crankers[self.player] = true
	local began = os.clock()
	while self.active and crank.height < Config.Crank.OpenAt and os.clock() - began < 45 do
		task.wait(0.25)
	end
	crank.crankers[self.player] = nil
	if crank.height < Config.Crank.OpenAt then
		return false, "the shutter never rose"
	end
	task.wait(0.5)
	-- Pinned open from inside, as a player would latch it (walking through
	-- first, so the route knows which side we're on).
	services.CrankService:Latch(crank)
	task.wait(0.5)
	return true
end

function BotService:_piece(step): (boolean, string?)
	local services = self.services
	local entry = services.LockService.pieceLocks[step.piece]
	if not entry then
		return false, "no such chest"
	end
	if entry.open then
		return true
	end
	local anchor = entry.anchor
	local room = self.World:Room(step.room)
	local at = anchor and anchor.Position or room.center
	local stand = self:_standNear(at, step.room, { anchor })
	local walked = self:_walkTo(stand, 2.5)
	if walked ~= "ok" then
		return false, walked
	end
	local work = entry.work or {}
	for _ = 1, (work.steps or 4) + 2 do
		if entry.open or not self.active then
			break
		end
		services.LockService:_tryPiece(step.piece, self.player)
		task.wait((work.seconds or 1.5) + 0.3)
	end
	if not entry.open then
		return false, "the chest would not open"
	end
	return true
end

function BotService:_tool(step): (boolean, string?)
	local services = self.services
	local holder = self.World.content and self.World.content:FindFirstChild("ToolPickups")
	local pickup = nil
	for _, model in holder and holder:GetChildren() or {} do
		if model:GetAttribute("ToolId") == step.tool and model.PrimaryPart then
			pickup = model
			break
		end
	end
	if not pickup then
		if services.ToolService:Carries(self.player, step.tool) then
			return true
		end
		return false, "no " .. tostring(step.tool) .. " lying anywhere"
	end
	local stand = self:_standNear(pickup.PrimaryPart.Position, step.room, { pickup })
	local walked = self:_walkTo(stand, 2.5)
	if walked ~= "ok" then
		return false, walked
	end
	local uid = string.match(pickup.Name, "^Pickup_(.+)$")
	services.ToolService:_take(self.player, uid)
	task.wait(0.4)
	if not services.ToolService:Carries(self.player, step.tool) then
		return false, "could not pick it up"
	end
	return true
end

function BotService:_puzzle(step): (boolean, string?)
	local services = self.services
	local session = services.PuzzleService.sessions[step.id]
	if not session then
		return false, "no such puzzle"
	end
	if session.state and session.state.solved then
		return true
	end
	local room = self.World:Room(step.room)
	local at = stationPosition(session.station) or room.center
	local stand = self:_standNear(at, step.room)
	local walked = self:_walkTo(stand, 2.5)
	if walked ~= "ok" then
		return false, walked
	end
	-- Solved as if played right: the bot measures walking and finding, not
	-- puzzle skill.
	services.PuzzleService:DebugSolve(self.player, step.id)
	self.cheated += 1
	task.wait(2.5)
	if not (session.state and session.state.solved) then
		return false, "would not solve"
	end
	return true
end

-- Where the plan keeps a token: a drawer, a keepsake box, a display case, a
-- key rack. Opened, then taken.
function BotService:_look(step): (boolean, string?)
	local services = self.services
	local items, furniture = services.ItemService, services.FurnitureService
	local token = step.token
	-- Already lying there (a rack, a floor spot, a case someone opened)?
	if self.thingOf and self.thingOf[token] and not self.thingOf[token].holder then
		return self:_take(token)
	end
	-- A display case?
	for _, case in items.cases do
		if case.token == token and not case.open then
			local stand = self:_standNear(case.model:GetPivot().Position, step.room, { case.model })
			local walked = self:_walkTo(stand, 2.5)
			if walked ~= "ok" then
				return false, walked
			end
			if case.piece then
				furniture:SetLocked(case.piece, false)
				furniture:SetOpen(case.piece, true)
			end
			items:_openCase(case, self.player, "bot")
			task.wait(0.8)
			return self:_take(token)
		end
	end
	-- A drawer, cupboard or box.
	local space = nil
	for s, kept in items.bySpace do
		if kept == token then
			space = s
			break
		end
	end
	if not space then
		return false, "nowhere to find it"
	end
	local prop = space.prop
	local stand = prop.frame and self:_frontOf(prop.frame, prop.kind, prop.roomId)
		or self:_standNear(prop.model:GetPivot().Position, prop.roomId, { prop.model })
	local walked = self:_walkTo(stand, 3)
	if walked ~= "ok" then
		return false, walked
	end
	local piece = space.pieces[1]
	if piece and piece.state.target < piece.state.max / 2 then
		furniture:Toggle(piece, self.player)
	end
	local began = os.clock()
	while self.active and not space.filled and os.clock() - began < 5 do
		task.wait(0.25)
	end
	task.wait(0.4)
	return self:_take(token)
end

-- Pick a thing up by its token. A key goes to the ring; an heirloom is carried.
function BotService:_take(token: string): (boolean, string?)
	local services = self.services
	local thing = nil
	for _, t in services.HandsService.things do
		if t.model and t.model:GetAttribute("Item") == token and t.model.Parent and not t.holder then
			thing = t
			break
		end
	end
	if not thing then
		return false, "nothing to take"
	end
	local at = thing.model:GetPivot().Position
	local here = self.PlayerState:Position(self.player)
	if not here or (here - at).Magnitude > 7 then
		local stand = self:_standNear(at, self.World:RoomAt(at), { thing.model })
		local walked = self:_walkTo(stand, 2.5)
		if walked ~= "ok" then
			return false, walked
		end
	end
	services.HandsService:Grab(self.player, thing.id)
	task.wait(0.3)
	if thing.holder == self.player then
		-- Carried by the server (the client only carries what it asked for).
		thing.serverCarried = true
		thing.root.Anchored = true
		self.carry = thing
		return true
	end
	if thing.state == "gone" then
		return true -- a key: on the ring now
	end
	return false, "could not take hold of it"
end

function BotService:_set(step): (boolean, string?)
	local services = self.services
	local finale = services.FinaleService
	local place = nil
	for _, p in finale.places do
		if not p.token then
			place = p
			break
		end
	end
	if not place then
		return false, "no empty place"
	end
	local plan = self.World.World.layout.progression
	local dining = self.World:Room(plan.finale.table)
	local at = place.at and place.at.Position or dining.center
	local stand = self:_standNear(at, plan.finale.table)
	local walked = self:_walkTo(stand, 2.5)
	if walked ~= "ok" then
		-- The place itself may be unreachable (against a wall): the room will do.
		walked = self:_walkTo(dining.center, 4)
		if walked ~= "ok" then
			return false, walked
		end
	end
	finale:_set(place, self.player)
	task.wait(0.5)
	if place.token ~= step.token then
		return false, "the place would not take it"
	end
	self.carry = nil
	return true
end

function BotService:_extract(): (boolean, string?)
	local world = self.World.World
	local exit = world and world.exit
	local zone = exit and exit.zone
	if not zone then
		return false, "no front door"
	end
	-- To just inside the doorway (the walker knows the house; the porch
	-- is outside it), then straight out through the open door.
	local roomId = exit.roomId or world.layout.exit
	local room = roomId and self.World:Room(roomId)
	local doorPos = exit.door and exit.door.Position or zone.Position
	local inward = room and flat(room.center - doorPos) or Vector3.zero
	local inside = inward.Magnitude > 0.1 and (doorPos + inward.Unit * 3.5) or doorPos
	local walked = self:_walkTo(self:_floor(inside), 3)
	if walked ~= "ok" then
		return false, walked
	end
	self.walker:Stop()
	local humanoid = self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "no character"
	end
	humanoid.WalkSpeed = self.speed
	local target = zone.Position
	local began, lastMove = os.clock(), 0
	while self.active and os.clock() - began < 30 do
		if self.PlayerState:State(self.player) == States.Extracted then
			return true
		end
		-- (MoveTo gives up after 8 s on its own: asked again every 2 s.)
		if os.clock() - lastMove > 2 then
			lastMove = os.clock()
			humanoid:MoveTo(target)
		end
		task.wait(0.25)
	end
	if self.PlayerState:State(self.player) == States.Extracted then
		return true
	end
	local pos = self.PlayerState:Position(self.player)
	return false, string.format("never reached the door (%.0f studs short)", pos and (pos - target).Magnitude or -1)
end

-- Hunts ------------------------------------------------------------------------------

-- `flee`: away from him, to the reachable room farthest from where he is;
-- `hide`: into the nearest free hiding spot, out again when it's over.
function BotService:_hunt()
	local services = self.services
	local stalker = services.StalkerService
	self.walker:Stop()
	if self.onHunt == "hide" then
		local here = self.PlayerState:Position(self.player)
		local best, bestId, bestDistance = nil, nil, math.huge
		for id, spot in self.World.World.hidingSpots or {} do
			if #spot.occupants < spot.capacity and spot.frontPosition and here then
				local d = self.World:Separation(here, spot.frontPosition)
				if d < bestDistance then
					best, bestId, bestDistance = spot, id, d
				end
			end
		end
		if best and self:_walkTo(best.frontPosition, 2.5) == "ok" then
			services.HidingService:Enter(self.player, best)
			self:_log("hiding in " .. tostring(bestId))
			while self.active and stalker:IsHunting() do
				task.wait(0.5)
			end
			task.wait(3)
			services.HidingService:Leave(self.player)
			return
		end
	end
	-- Flee (or no spot to hide in): the farthest reachable room from him.
	local guest = stalker:GetPosition()
	local reach = services.LockService.reach
	local best, bestDistance = nil, -1
	for id in reach do
		local room = self.World:Room(id)
		if room and guest then
			local d = self.World:Separation(guest, room.center)
			if d > bestDistance then
				best, bestDistance = room, d
			end
		end
	end
	if best then
		self:_log("fleeing to the " .. best.name)
		self:_walkTo(best.center, 4)
	end
	local began = os.clock()
	while self.active and stalker:IsHunting() and os.clock() - began < 120 do
		task.wait(0.5)
	end
end

-- The report --------------------------------------------------------------------------

function BotService:_report(reason: string)
	local services = self.services
	local summary = services.RunLogService:Summary()
	local lines = {}
	local elapsed = os.clock() - (self.started or os.clock())
	table.insert(
		lines,
		string.format(
			"botrun %s: %s in %s · %d steps, %d failed, %d with no way, %d stuck points · %d puzzles solved as if played",
			self.fast and "(fast)" or "",
			reason,
			clock(elapsed),
			self.steps or 0,
			(function()
				local n = 0
				for _, count in self.failures or {} do
					n += count
				end
				return n
			end)(),
			self.noWays or 0,
			#(self.stuckPoints or {}),
			self.cheated or 0
		)
	)
	for _, stuck in self.stuckPoints or {} do
		table.insert(lines, string.format("  stuck %s at %s: %s (%s)", stuck.step, stuck.at, stuck.why, stuck.room))
	end
	if summary then
		for _, line in services.RunLogService:SummaryLines() do
			table.insert(lines, "  " .. line)
		end
	end
	for _, line in lines do
		print("[Consensus:botrun] " .. line)
	end
	if self.report then
		self.report(table.concat(lines, "\n", 1, math.min(#lines, 6)))
	end
	services.Telemetry:Log("BotRun", {
		reason = reason,
		seconds = math.floor(elapsed),
		fast = self.fast,
		steps = self.steps,
		noWays = self.noWays,
		stuck = #(self.stuckPoints or {}),
		cheated = self.cheated,
		firstDoor = summary and summary.firstDoorAt and math.floor(summary.firstDoorAt) or nil,
		dinner = summary and summary.servedAt and math.floor(summary.servedAt) or nil,
		out = summary and summary.extractedAt and math.floor(summary.extractedAt) or nil,
		hints = summary and summary.hints or nil,
		downs = summary and summary.downs or nil,
		torchDead = summary and summary.torchDead or nil,
		silent = summary and math.floor(summary.silentTotal) or nil,
	})
end

-- F2 `botrun plan`: the steps, without moving (Logic/BotPlan.walk).
function BotService:_dryRun(plan): string
	local seams = {}
	for seamId, seam in self.World.World.seams do
		seams[seamId] = { a = seam.a, b = seam.b }
	end
	local steps, tableSet = BotPlan.walk(plan, seams, plan.regions[0].rooms, 120)
	local words = {}
	for i, step in steps do
		table.insert(words, string.format("%d. %s %s", i, step.kind, self:_name(step)))
	end
	print("[botrun] plan:\n" .. table.concat(words, "\n"))
	return string.format(
		"botrun plan: %d steps, the table %s; printed to Output",
		#steps,
		tableSet and "set" or "NOT set"
	)
end

return BotService
