-- The escape's puzzles (docs/plans/gameplay-rework.md section 7): the home
-- computer and the padlock its printout opens (R2a); the breaker, the safe
-- and the music box come later (R2b). Each puzzle's rules are a pure module
-- (Logic/Puzzles/*). This puts its station in the house, runs it for one
-- player at a time (UI/Puzzle draws it), and keeps the answer here:
-- clients only ever get the screen and what their own inputs did.
--
-- The computer stands on a desk in the room the plan chose. Cracked, it
-- prints the padlock's code on a page anyone can pick up and read. A wrong
-- word costs a try; four, and it locks you out with a loud beep (noise, with
-- you as its source). A padlock's wrong pull rattles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Padlock = require(Shared.Logic.Puzzles.Padlock)
local Props = require(Shared.Data.Props)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)
local Terminal = require(Shared.Logic.Puzzles.Terminal)

local Items = require(script.Parent.Parent.World.Items)

local REACH = 9 -- studs from the station an operator may stand
local part = PropFactory.part
local BEIGE = Color3.fromRGB(196, 186, 162)
local PHOSPHOR = Color3.fromRGB(110, 255, 140)

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
		end
	end)
end

-- Stations --------------------------------------------------------------------------

-- The top of a desk (or anything with a top) in a room, as { cframe, size }.
function PuzzleService:_surface(roomId: number)
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

-- A 1988 home computer and a dot-matrix printer on a desk (or on the floor
-- of its room, with no desk).
function PuzzleService:_buildComputer(session, roomId: number)
	local folder = self.World.content
	local model = Instance.new("Model")
	model.Name = "HomeComputer"
	local surface = self:_surface(roomId)
	local top
	if surface then
		top = surface.frame * CFrame.new(0, surface.size[2], -surface.size[3] / 2 + 1.1)
	else
		local at = self.World:Room(roomId).center
		top = CFrame.new(at.X, self.World:FloorBase(at.Y), at.Z)
	end
	local plastic = PropFactory.material("SmoothPlastic")
	local monitor = top * CFrame.new(-1.2, 0, 0)
	part(model, "Monitor", Vector3.new(1.9, 1.6, 1.5), monitor * CFrame.new(0, 0.95, 0), BEIGE, plastic)
	part(
		model,
		"Stand",
		Vector3.new(1.2, 0.15, 1),
		monitor * CFrame.new(0, 0.075, 0),
		PropFactory.shade(BEIGE, 0.85),
		plastic
	)
	local screen = part(
		model,
		"Screen",
		Vector3.new(1.4, 1.05, 0.04),
		monitor * CFrame.new(0, 1, 0.76),
		Color3.fromRGB(14, 30, 18),
		PropFactory.material("Glass"),
		{ castShadow = false }
	)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color = PHOSPHOR
	glow.Brightness = 0.6
	glow.Range = 6
	glow.Angle = 70
	glow.Parent = screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(280, 210)
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = PHOSPHOR
	text.Font = Enum.Font.Code
	text.TextSize = 20
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = "HOMEWARE 64\nFAMILY FILES\n\nPASSWORD:\n> _"
	text.Parent = gui
	gui.Parent = screen
	part(
		model,
		"Keyboard",
		Vector3.new(1.7, 0.12, 0.6),
		top * CFrame.new(-1.2, 0.06, 1.15),
		PropFactory.shade(BEIGE, 0.92),
		plastic
	)
	local printer = top * CFrame.new(1.3, 0, 0.1)
	part(model, "Printer", Vector3.new(1.5, 0.5, 1), printer * CFrame.new(0, 0.25, 0), BEIGE, plastic)
	part(
		model,
		"PrinterSlot",
		Vector3.new(1.1, 0.04, 0.12),
		printer * CFrame.new(0, 0.48, -0.3),
		Color3.fromRGB(30, 28, 26),
		plastic,
		{ castShadow = false, collide = false }
	)
	model.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PuzzlePrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = "Computer"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = screen
	prompt.Triggered:Connect(function(player)
		self:_open(session, player)
	end)
	session.model = model
	session.station = screen
	session.screenText = text
	session.printerAt = printer * CFrame.new(0, 0.02, 1.0)
	session.prompt = prompt
end

function PuzzleService:Begin(plan, _rng)
	self.plan = plan
	table.clear(self.sessions)
	table.clear(self.padlocks)
	for id, puzzle in plan.puzzles do
		if puzzle.kind == "terminal" then
			local rng = Rng.new(puzzle.seed)
			local spec = Terminal.generate(rng:Fork("screen"), {})
			local session = {
				id = id,
				kind = "terminal",
				spec = spec,
				state = Terminal.start(spec),
				room = puzzle.room,
				-- The code it prints: the padlock its token opens.
				padlock = Padlock.generate(rng:Fork("padlock"), {}),
			}
			self.sessions[id] = session
			self:_buildComputer(session, puzzle.room)
		end
	end
	-- Each padlocked door: a padlock with the code its computer prints.
	for seamId, lock in plan.locks do
		if lock.kind == "padlock" then
			local token = plan.tokens[lock.needs[1]]
			local source = token and self.sessions[token.producer.id]
			if source then
				local id = "padlock:" .. seamId
				local door = self.World.World.seams[seamId].door
				self.sessions[id] = {
					id = id,
					kind = "padlock",
					spec = source.padlock,
					state = Padlock.start(source.padlock),
					seam = seamId,
					station = door and door.slab,
				}
				self.padlocks[seamId] = id
			end
		end
	end
end

-- Running ---------------------------------------------------------------------------

function PuzzleService:_near(player: Player, session): boolean
	local position = self.PlayerState:Position(player)
	return position ~= nil
		and session.station ~= nil
		and session.station.Parent ~= nil
		and (position - session.station.Position).Magnitude <= REACH
		and self.PlayerState:CanAct(player)
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

-- What a client may see of a session's state (never the answer).
local function public(session)
	if session.kind == "terminal" then
		local state = session.state
		return {
			tries = state.tries,
			removed = state.removed,
			used = state.used,
			log = state.log,
			lockedFor = math.max(0, state.lockedUntil - os.clock()),
			solved = state.solved,
		}
	end
	return { digits = session.state.digits, solved = session.state.solved }
end

function PuzzleService:_open(session, player: Player): boolean
	if not self:_near(player, session) then
		return false
	end
	if session.operator and session.operator ~= player and session.operator.Parent then
		notify(player, "Someone's already at it.")
		return false
	end
	if session.state.solved then
		notify(player, session.kind == "terminal" and "The screen just says ACCESS GRANTED." or "It's open.")
		return false
	end
	session.operator = player
	local view = session.kind == "terminal" and Terminal.view(session.spec) or Padlock.view(session.spec)
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
	local input
	if session.kind == "terminal" then
		if action == "word" and word and #word <= 12 then
			input = { kind = "word", word = word, now = os.clock() }
		elseif action == "bracket" and a then
			input = { kind = "bracket", index = a, now = os.clock() }
		end
	elseif session.kind == "padlock" then
		if action == "turn" and a and b then
			input = { kind = "turn", wheel = a, delta = b }
		elseif action == "pull" then
			input = { kind = "pull" }
		end
	end
	if not input then
		return
	end
	local module = session.kind == "terminal" and Terminal or Padlock
	local _, events = module.step(session.spec, session.state, input)
	local position = session.station.Position
	for _, event in events do
		if event.kind == "lockout" then
			-- Locked out: a loud beep that carries, and the house notices.
			self.Noise:Emit(position, Config.Puzzles.LockoutNoise, player, "puzzle")
			Sfx.play("Sting", position, 0.35, 2.4)
			self.Drift:Apply("PuzzleFailed")
		elseif event.kind == "likeness" then
			Sfx.play("UIClick", position, 0.25, 0.7)
		elseif event.kind == "rattle" then
			self.Noise:Emit(position, Config.Puzzles.RattleNoise, player, "puzzle")
			Sfx.play("DoorLatch", position, 0.5, 1.6)
		elseif event.kind == "turned" then
			Sfx.play("UIClick", position, 0.15, 1.4)
		end
	end
	Net.get("PuzzleState"):FireClient(player, session.id, public(session), events)
	if module.solved(session.state) then
		self:_solved(session, player)
	end
end

function PuzzleService:_solved(session, player: Player)
	self.Drift:Apply("PuzzleSolved")
	self.Solved:Fire(session.id, player)
	task.delay(1.6, function()
		if session.operator == player then
			self:_close(session)
		end
	end)
	if session.kind == "terminal" then
		session.screenText.Text = "HOMEWARE 64\n\nACCESS GRANTED\n\nPRINTING..."
		if session.prompt then
			session.prompt.ObjectText = "Computer (unlocked)"
		end
		-- The printer chatters out a page with the padlock's code on it.
		task.delay(1.2, function()
			if not self.plan or not session.model.Parent then
				return
			end
			for i = 0, 3 do
				task.delay(i * 0.3, function()
					Sfx.play("Shutter", session.printerAt.Position, 0.3, 0.55)
				end)
			end
			task.delay(1.3, function()
				if not self.plan then
					return
				end
				local text = "HOMEWARE 64\n\nNOTE TO SELF\nthe lock code\n\n  "
					.. Padlock.code(session.padlock)
					.. "\n\ndon't let HIM in"
				local page = Items.printout(session.printerAt, text, self.World.content)
				self.Hands:AddThing(page, { class = "light", label = "Printout" })
			end)
		end)
	else
		self.Locks:Unlock(session.seam, player, "The padlock springs open.")
	end
end

-- F2 `solve [id]`: the puzzle you're at (or the one named) is solved as if
-- you'd entered the answer.
function PuzzleService:DebugSolve(player: Player, id: string?): string
	local session = id and self.sessions[id]
	if not session then
		for _, s in self.sessions do
			if s.operator == player or (not session and s.kind == "terminal" and not s.state.solved) then
				session = s
			end
		end
	end
	if not session then
		return "no puzzle (not an escape run, or none in this house)"
	end
	if session.state.solved then
		return session.id .. " is already solved"
	end
	if session.kind == "terminal" then
		Terminal.step(session.spec, session.state, { kind = "word", word = session.spec.answer, now = os.clock() })
	else
		session.state.digits = table.clone(session.spec.answer)
		Padlock.step(session.spec, session.state, { kind = "pull" })
	end
	self:_solved(session, player)
	return "solved " .. session.id
end

return PuzzleService
