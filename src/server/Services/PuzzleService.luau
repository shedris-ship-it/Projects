-- The escape's puzzles (docs/plans/gameplay-rework.md section 7). Each kind
-- is a registry entry (R2c): its pure rules in Logic/Puzzles/* (listed in
-- Logic/PuzzleKinds) and its station in the house in server/Puzzles/*. This
-- runs any of them for one player at a time (UI/Puzzle draws it) and keeps
-- the answer here: clients only ever get the screen and what their own
-- inputs did.
--
-- A telegraphed hunt closes every open puzzle screen (CloseAll): you look
-- up from the puzzle when he's coming.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local PuzzleKinds = require(Shared.Logic.PuzzleKinds)
local Props = require(Shared.Data.Props)
local Signal = require(Shared.Lib.Signal)

local Stations = script.Parent.Parent.Puzzles
local KINDS = {}
for _, module in Stations:GetChildren() do
	KINDS[string.lower(module.Name)] = require(module)
end

local REACH = 9 -- studs from the station an operator may stand

local PuzzleService = {
	-- (puzzle id, player): solved.
	Solved = Signal.new(),
}

function PuzzleService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.Noise = services.NoiseService
	self.Hands = services.HandsService
	self.Locks = services.LockService
	self.Drift = services.DriftService
	self.plan = nil
	self.sessions = {} -- puzzle id -> session
	self.padlocks = {} -- seam id -> puzzle id
end

function PuzzleService:Start()
	Net.onServer("PuzzleInput", {
		interval = 0.08,
		burst = 14,
		types = { "string", "string", "string?", "number?", "number?" },
	}, function(player, id, action, word, a, b)
		self:_input(player, id, action, word, a, b)
	end)
	Net.onServer("PuzzleLeave", { interval = 0.1, types = { "string" } }, function(player, id)
		local session = self.sessions[id]
		if session and session.operator == player then
			self:_close(session)
		end
	end)
	self.World.Cleared:Connect(function()
		for _, session in self.sessions do
			if session.operator and session.operator.Parent then
				Net.get("PuzzleClose"):FireClient(session.operator, session.id)
			end
		end
		self.plan = nil
		table.clear(self.sessions)
		table.clear(self.padlocks)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, session in self.sessions do
			if session.operator == player then
				session.operator = nil
			end
		end
	end)
	-- Walked off, downed or caught: you're not at it any more.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		for _, session in self.sessions do
			local player = session.operator
			if player and not self:_near(player, session) then
				self:_close(session)
			end
			local kind = KINDS[session.kind]
			if kind and kind.tick then
				kind.tick(self, session, elapsed)
			end
		end
	end)
end

-- Stations --------------------------------------------------------------------------

-- The top of a desk (or anything with a top) in a room, as { frame, size,
-- kind }: where a puzzle's station stands.
function PuzzleService:Surface(roomId: number)
	local best
	for _, prop in self.World.World.props do
		local kind = Props.Kinds[prop.kind]
		if prop.roomId == roomId and prop.frame and kind and kind.top and prop.model.Parent then
			if not best or prop.kind == "Desk" then
				best = { frame = prop.frame, size = kind.size, kind = prop.kind }
			end
		end
	end
	return best
end

-- The E prompt that opens a station's puzzle.
function PuzzleService:Prompt(session, parent: Instance, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PuzzlePrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player)
		self:_open(session, player)
	end)
	return prompt
end

function PuzzleService:Begin(plan, _rng)
	self.plan = plan
	table.clear(self.sessions)
	table.clear(self.padlocks)
	local ids = {}
	for id in plan.puzzles do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local puzzle = plan.puzzles[id]
		local kind = KINDS[puzzle.kind]
		if kind and kind.create then
			self.sessions[id] = kind.create(self, id, puzzle)
		else
			warn("[Consensus] no station for puzzle kind " .. tostring(puzzle.kind))
		end
	end
	-- Locks opened by a puzzle at the door itself (a padlock): after the
	-- puzzles whose tokens they take.
	for _, kind in KINDS do
		if kind.fromLocks then
			kind.fromLocks(self, plan)
		end
	end
end

-- Running ---------------------------------------------------------------------------

function PuzzleService:_near(player: Player, session): boolean
	local position = self.PlayerState:Position(player)
	return position ~= nil
		and session.station ~= nil
		and session.station.Parent ~= nil
		and (position - session.station.Position).Magnitude <= (session.reach or REACH)
		and self.PlayerState:CanAct(player)
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

local function public(session)
	return PuzzleKinds[session.kind].public(session.state, os.clock())
end

function PuzzleService:_open(session, player: Player): boolean
	if KINDS[session.kind].noScreen or not self:_near(player, session) then
		return false
	end
	if session.operator and session.operator ~= player and session.operator.Parent then
		notify(player, "Someone's already at it.")
		return false
	end
	if session.state.solved and not KINDS[session.kind].reusable then
		notify(player, KINDS[session.kind].done or "It's done.")
		return false
	end
	if session.closedUntil and os.clock() < session.closedUntil then
		notify(player, "Not now. Something's coming.")
		return false
	end
	session.operator = player
	local view = PuzzleKinds[session.kind].view(session.spec)
	Net.get("PuzzleOpen"):FireClient(player, session.id, session.kind, view, public(session))
	return true
end

function PuzzleService:_close(session)
	local player = session.operator
	session.operator = nil
	if player and player.Parent then
		Net.get("PuzzleClose"):FireClient(player, session.id)
	end
end

-- A hunt is coming (StalkerService's telegraph): everyone looks up from what
-- they were doing, and nobody starts again for `seconds`.
function PuzzleService:CloseAll(why: string?, seconds: number?)
	for _, session in self.sessions do
		local player = session.operator
		if player then
			self:_close(session)
			if why and player.Parent then
				notify(player, why, "danger")
			end
		end
		if seconds then
			session.closedUntil = os.clock() + seconds
		end
	end
end

-- A player tried a padlocked door: its padlock opens in front of them.
function PuzzleService:OpenPadlock(player: Player, seamId: string): boolean
	local id = self.padlocks[seamId]
	local session = id and self.sessions[id]
	return session ~= nil and self:_open(session, player)
end

function PuzzleService:_input(player: Player, id: string, action: string, word: string?, a: number?, b: number?)
	local session = self.sessions[id]
	if not session or session.operator ~= player or not self:_near(player, session) then
		return
	end
	local rules = PuzzleKinds[session.kind]
	local input = rules.parse(action, word, a, b, os.clock())
	if not input then
		return
	end
	local wasSolved = rules.solved(session.state)
	local _, events = rules.step(session.spec, session.state, input)
	local position = session.station.Position
	local kind = KINDS[session.kind]
	for _, event in events do
		if kind.event then
			kind.event(self, session, event, player, position)
		end
	end
	Net.get("PuzzleState"):FireClient(player, session.id, public(session), events)
	if not wasSolved and rules.solved(session.state) then
		self:_solved(session, player)
	end
end

-- Tell the operator what changed without an input of theirs (a dial left to
-- settle, a box winding down).
function PuzzleService:Push(session, events)
	local player = session.operator
	if player and player.Parent then
		Net.get("PuzzleState"):FireClient(player, session.id, public(session), events or {})
	end
end

function PuzzleService:_solved(session, player: Player?)
	self.Drift:Apply("PuzzleSolved")
	self.Solved:Fire(session.id, player)
	local kind = KINDS[session.kind]
	if not kind.reusable then
		task.delay(1.6, function()
			if session.operator and session.operator == player then
				self:_close(session)
			end
		end)
	end
	if kind.solved then
		kind.solved(self, session, player)
	end
end

-- F2 `puzzle [kind]`: stand at the station of the first puzzle of that kind
-- (or any) and open it.
function PuzzleService:DebugVisit(player: Player, kind: string?): string
	local ids = {}
	for id, session in self.sessions do
		if (kind == nil or session.kind == kind) and session.station and session.station.Parent then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local session = self.sessions[ids[1]]
	local character = player.Character
	if not session or not character then
		return "no such puzzle in this house"
	end
	local station = session.station
	-- Stations face +Z (their Back face), like the computer's screen.
	local out = session.front or -station.CFrame.LookVector
	local spot = station.Position + Vector3.new(out.X, 0, out.Z).Unit * 3
	local floor = self.World:FloorBase(station.Position.Y)
	self.PlayerState:MarkTeleport(player)
	character:PivotTo(
		CFrame.lookAt(
			Vector3.new(spot.X, floor + 3, spot.Z),
			Vector3.new(station.Position.X, floor + 3, station.Position.Z)
		)
	)
	task.delay(0.4, function()
		self:_open(session, player)
	end)
	return "at " .. session.id
end

-- A mechanism with no screen says it's done (the dumbwaiter: its heirloom
-- taken out of the car).
function PuzzleService:MarkSolved(session, player: Player?)
	if session.state.solved then
		return
	end
	session.state.solved = true
	self:_solved(session, player)
end

-- F2 `solve [id]`: the puzzle you're at (or the one named, or the first
-- unsolved one) is solved as if you'd done it right.
function PuzzleService:DebugSolve(player: Player, id: string?): string
	local session = id and self.sessions[id]
	if not session then
		local ids = {}
		for sessionId in self.sessions do
			table.insert(ids, sessionId)
		end
		table.sort(ids)
		for _, sessionId in ids do
			local s = self.sessions[sessionId]
			if s.operator == player then
				session = s
				break
			end
		end
		if not session then
			for _, sessionId in ids do
				local s = self.sessions[sessionId]
				if not s.state.solved and s.kind ~= "padlock" then
					session = s
					break
				end
			end
		end
	end
	if not session then
		return "no puzzle (none in this house)"
	end
	if session.state.solved then
		return session.id .. " is already solved"
	end
	PuzzleKinds[session.kind].solve(session.spec, session.state, os.clock())
	local kind = KINDS[session.kind]
	if kind.event then
		kind.event(self, session, { kind = "solved" }, player, session.station.Position)
	end
	self:_solved(session, player)
	return "solved " .. session.id
end

return PuzzleService
