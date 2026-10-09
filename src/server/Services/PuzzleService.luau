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
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local PuzzleKinds = require(Shared.Logic.PuzzleKinds)
local Props = require(Shared.Data.Props)
local Config = require(Shared.Config)
local Sfx = require(Shared.Lib.Sfx)
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
		-- Quick enough for a tune played fast (a repeated note, two keys at
		-- once); a dropped press read as the wrong note.
		interval = 0.04,
		burst = 20,
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
			self:_tell(session)
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
			local session = kind.create(self, id, puzzle)
			self.sessions[id] = session
			if session then
				self:_signpost(session)
			end
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
	-- Its lamp goes out: the lamps still lit are the puzzles left.
	local lamp = session.lamp
	if lamp and lamp.Parent then
		local bulb = lamp:FindFirstChild("Bulb")
		if bulb then
			bulb.Material = Enum.Material.SmoothPlastic
			bulb.Color = Color3.fromRGB(70, 64, 52)
			for _, light in bulb:GetChildren() do
				if light:IsA("Light") then
					light.Enabled = false
				end
			end
		end
		Sfx.play("FlashlightClick", lamp:GetPivot().Position, 0.5, 0.6)
	end
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

-- Every puzzle lit and heard (the owner's solo playtest, 2026-10-08: "there's
-- no indicator that there's an important puzzle in the room"; the owner's
-- choice: lit and heard). A shaded lamp hangs over each station, a warm pool
-- of light in a dark room, till it's solved; and the first time anyone comes
-- into its room near it, it makes a sound of its own, with a caption.
local TELLS = {
	musicbox = { sound = "MusicBoxNote", volume = 0.9, pitch = 0.6, caption = "[a piano key sounds, on its own]" },
	terminal = { sound = "Ping", volume = 0.5, pitch = 0.6, caption = "[a computer beeps]" },
	breaker = { sound = "Snap", volume = 0.6, pitch = 0.5, caption = "[a fuse box crackles]" },
	safe = { sound = "LockClick", volume = 0.7, pitch = 0.8, caption = "[a click, from a safe's dial]" },
	dumbwaiter = { sound = "Creak", volume = 0.7, pitch = 0.7, caption = "[the dumbwaiter's rope creaks]" },
}

local function lampPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- The lamp over a station: from the ceiling over it, a little into the room.
function PuzzleService:_signpost(session)
	local station = session.station
	local S = Config.PuzzleLamp
	if not station or not station.Parent or not TELLS[session.kind] then
		return
	end
	local roomId = self.World:RoomAt(station.Position)
	local room = roomId and self.World:Room(roomId)
	local toward = room and Vector3.new(room.center.X - station.Position.X, 0, room.center.Z - station.Position.Z)
	local at = station.Position + ((toward and toward.Magnitude > 0.1) and toward.Unit * S.Out or Vector3.zero)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local model = station:FindFirstAncestorWhichIsA("Model")
	params.FilterDescendantsInstances = { model or station }
	local up = Workspace:Raycast(at, Vector3.new(0, 14, 0), params)
	local ceiling = up and up.Position.Y or at.Y + 6
	local shadeY = math.max(ceiling - S.Drop, station.Position.Y + 2.5)
	local lamp = Instance.new("Model")
	lamp.Name = "PuzzleLamp"
	local cord = ceiling - shadeY
	local wire = lampPart(
		lamp,
		"Cord",
		Vector3.new(cord, 0.06, 0.06),
		CFrame.new(at.X, shadeY + cord / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(20, 18, 16),
		Enum.Material.SmoothPlastic
	)
	wire.Shape = Enum.PartType.Cylinder
	lampPart(
		lamp,
		"Shade",
		Vector3.new(1.1, 0.5, 1.1),
		CFrame.new(at.X, shadeY, at.Z),
		Color3.fromRGB(46, 58, 40),
		Enum.Material.Metal
	)
	local bulb = lampPart(
		lamp,
		"Bulb",
		Vector3.new(0.34, 0.34, 0.34),
		CFrame.new(at.X, shadeY - 0.3, at.Z),
		Color3.fromRGB(255, 214, 150),
		Enum.Material.Neon
	)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = S.Angle
	light.Range = S.Range
	light.Brightness = S.Brightness
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Shadows = true
	light.Parent = bulb
	local glow = Instance.new("PointLight")
	glow.Range = S.Glow.Range
	glow.Brightness = S.Glow.Brightness
	glow.Color = light.Color
	glow.Parent = bulb
	lamp.Parent = self.World.content or Workspace
	session.lamp = lamp
end

-- The first time anyone comes near it in its room: its sound.
function PuzzleService:_tell(session)
	local station = session.station
	local tell = TELLS[session.kind]
	if session.told or not tell or not station or not station.Parent then
		return
	end
	if session.state and session.state.solved then
		session.told = true
		return
	end
	local roomId = self.World:RoomAt(station.Position)
	for _, player in Players:GetPlayers() do
		local position = self.PlayerState:Position(player)
		if
			position
			and self.PlayerState:IsActive(player)
			and (position - station.Position).Magnitude < Config.PuzzleLamp.TellRange
			and math.abs(position.Y - station.Position.Y) < 6
			and self.World:RoomAt(position) == roomId
		then
			session.told = true
			Sfx.play(tell.sound, station.Position, tell.volume, tell.pitch, tell.caption)
			return
		end
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
	local _, events = PuzzleKinds[session.kind].solve(session.spec, session.state, os.clock())
	local kind = KINDS[session.kind]
	if kind.event then
		-- What solving it set off (the fuse box's safe room too), and solved.
		local said = false
		for _, event in events or {} do
			said = said or event.kind == "solved"
			kind.event(self, session, event, player, session.station.Position)
		end
		if not said then
			kind.event(self, session, { kind = "solved" }, player, session.station.Position)
		end
	end
	self:_solved(session, player)
	return "solved " .. session.id
end

return PuzzleService
