-- Twin levers (the squad playtest, 2026-10-10; Logic/Puzzles/Levers): an
-- iron lever on the wall beside a locked door, its twin on a wall in another
-- room a walk away, each plate wearing the door's mark. Hold E on a lever and
-- it's down; let go and it springs back up after a moment. Both down at once
-- and the door's bolt shoots back for good. So one holds by the door and
-- the other at the twin, and someone says "now".
--
-- With one player left (alone, or the rest down or lost), a lever let go
-- stays down on its catch long enough to walk to its twin, ticking loud
-- enough for him to hear. Nothing to find; no screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levers = require(Shared.Logic.Puzzles.Levers)
local Marks = require(Shared.Data.Marks)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local RoomRects = require(Shared.Logic.RoomRects)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)
local SwitchSpots = require(Shared.Logic.SwitchSpots)

local L = Config.Levers
local part = PropFactory.part
local IRON = Color3.fromRGB(58, 58, 60)
local BRASS = Color3.fromRGB(176, 146, 84)
local UP, DOWN = math.rad(-35), math.rad(35) -- the arm's tilt from the plate's middle

local Kind = {
	label = "Lever",
	done = "",
	noScreen = true,
}

-- A spot on `room`'s wall beside the doorway, facing into the room (the
-- crank's way: Services/CrankService).
local function besideDoor(service, seam, room: number): CFrame?
	local world = service.World.World
	local o = Config.Level.Origin
	local rect
	for _, r in RoomRects.ofLayout(world.layout, Config.Level) do
		if r.id == room then
			rect = { x0 = o.x + r.x, z0 = o.z + r.z, x1 = o.x + r.x + r.w, z1 = o.z + r.z + r.d }
		end
	end
	if not rect then
		return nil
	end
	local dir = room == seam.b and seam.normal or -seam.normal
	for _, beside in { L.Beside, 1.2, 4.5 } do
		local cfg = { DoorWidth = Config.Level.DoorWidth, WallFace = 0.55, Beside = beside, Margin = 1 }
		local spot = SwitchSpots.place(
			rect,
			{ x = seam.floorPosition.X, z = seam.floorPosition.Z },
			{ x = dir.X, z = dir.Z },
			cfg
		)
		if spot then
			local at = Vector3.new(spot.x, seam.floorPosition.Y + 3.8, spot.z)
			return CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z))
		end
	end
	return nil
end

-- A spot on a wall of `room`, facing into it (a picture's slot, lower).
local function onWall(service, room: number, rng): CFrame
	local world = service.World
	local slot = world:TakeWallSlot(room, rng)
	if slot then
		-- Wall slots sit on the wall's face, looking out into the room.
		return slot.cframe * CFrame.new(0, -0.8, 0)
	end
	local at = world:Room(room).center
	return CFrame.new(at.X, world:FloorBase(at.Y) + 3.8, at.Z)
end

-- The arm's frame at a tilt, about the plate's middle (`at` faces into the room).
local function armFrame(at: CFrame, tilt: number): CFrame
	return at * CFrame.new(0, 0, -0.16) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0.45, -0.1)
end

function Kind.build(service, session, at: CFrame, name: string)
	local model = Instance.new("Model")
	model.Name = "Lever"
	local metal = PropFactory.material("Metal")
	local plate = part(model, "Plate", Vector3.new(0.8, 1.6, 0.14), at * CFrame.new(0, 0, -0.07), IRON, metal)
	local arm = part(model, "Arm", Vector3.new(0.13, 0.95, 0.13), armFrame(at, UP), BRASS, metal, { collide = false })
	local knob = part(
		model,
		"Knob",
		Vector3.new(0.26, 0.26, 0.26),
		armFrame(at, UP) * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(40, 32, 26),
		metal,
		{ collide = false, shape = Enum.PartType.Ball }
	)
	-- A small lamp: dark while up, amber on its catch, green once the door gives.
	local lamp = part(
		model,
		"Lamp",
		Vector3.new(0.16, 0.16, 0.16),
		at * CFrame.new(0, -0.62, -0.16),
		Color3.fromRGB(60, 40, 30),
		Enum.Material.SmoothPlastic,
		{ collide = false, castShadow = false, shape = Enum.PartType.Ball }
	)
	-- The door's mark, so whoever finds one knows which door it's for.
	if session.mark then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(80, 80)
		gui.LightInfluence = 1
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.5, 0.25)
		label.Position = UDim2.fromScale(0.25, 0.02)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.Arial
		label.TextColor3 = BRASS
		label.Text = session.mark.glyph
		label.Parent = gui
		gui.Parent = plate
	end
	model.Parent = service.World.content
	CollectionService:AddTag(plate, "ConsensusLever") -- (UI/Tips)
	local lever = {
		name = name,
		model = model,
		plate = plate,
		arm = arm,
		knob = knob,
		lamp = lamp,
		at = at,
		position = plate.Position,
		holders = {},
		held = false,
		releasedAt = nil,
		window = L.Grace,
		nextTick = 0,
		tilt = UP,
	}
	-- Hold E: it's down while you hold (a long hold, so the prompt reports the
	-- hold itself, as the crank's does).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pull it down (hold)"
	prompt.ObjectText = session.mark and ("Lever " .. session.mark.glyph) or "Lever"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 60
	prompt.MaxActivationDistance = L.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if session.state.solved or not service.PlayerState:CanAct(player) then
			return
		end
		lever.holders[player] = true
		Kind.pulled(service, session, lever, player)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		if lever.holders[player] then
			lever.holders[player] = nil
			Kind.letGo(service, session, lever, player)
		end
	end)
	lever.prompt = prompt
	return lever
end

function Kind.create(service, id: string, puzzle)
	local world = service.World.World
	local plan = service.plan
	local seamId, mark
	for _, token in plan.tokens do
		if token.producer.kind == "puzzle" and token.producer.id == id and token.opens then
			seamId = token.opens
			mark = token.mark and Marks.ById[token.mark]
		end
	end
	local lock = seamId and plan.locks[seamId]
	local seam = seamId and world.seams[seamId]
	if not lock or not seam then
		warn("[Consensus] twin levers " .. id .. " have no door")
		return nil
	end
	local rng = Rng.new(puzzle.seed)
	local session = {
		id = id,
		kind = "levers",
		spec = Levers.generate(rng, {}),
		state = Levers.start({}),
		room = puzzle.room,
		seam = seamId,
		mark = mark,
		reach = L.Reach + 2,
	}
	local outer = lock.side or seam.a
	local doorAt = besideDoor(service, seam, outer) or onWall(service, outer, rng:Fork("door"))
	local farAt = onWall(service, puzzle.room, rng:Fork("far"))
	session.door = Kind.build(service, session, doorAt, "door")
	session.far = Kind.build(service, session, farAt, "far")
	-- The far lever is the station (the map, the line, its lamp overhead).
	session.station = session.far.plate
	session.front = -farAt.LookVector
	session.apart = service.World:Separation(session.door.position, session.far.position)
	return session
end

-- Its arm and lamp as it is now.
local function show(lever, tilt: number, lamp: Color3, neon: boolean)
	if lever.tilt ~= tilt then
		lever.tilt = tilt
		lever.arm.CFrame = armFrame(lever.at, tilt)
		lever.knob.CFrame = armFrame(lever.at, tilt) * CFrame.new(0, 0.5, 0)
	end
	lever.lamp.Color = lamp
	lever.lamp.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
end

local function notify(player: Player, text: string)
	Net.get("Notify"):FireClient(player, text, "info")
end

function Kind.pulled(service, session, lever, player: Player)
	lever.held = true
	show(lever, DOWN, Color3.fromRGB(220, 150, 60), true)
	Sfx.play("DoorLatch", lever.position, 0.55, 0.7)
	service.Noise:Emit(lever.position, L.PullNoise, player, "puzzle")
	Kind.check(service, session, player)
end

function Kind.letGo(service, session, lever, player: Player)
	if next(lever.holders) ~= nil or session.state.solved then
		return
	end
	lever.held = false
	lever.releasedAt = os.clock()
	local players = #service.PlayerState:ActivePlayers()
	lever.window = Levers.window(players, session.apart or L.MinApart, L)
	if player.Parent then
		if players >= 2 then
			notify(player, "It springs back as you let go. Its twin must be held down with it.")
		else
			notify(player, "It catches with a click, and starts to tick. Its twin, quickly.")
		end
	end
end

-- Both down: the door gives.
function Kind.check(service, session, player: Player?)
	if session.state.solved then
		return
	end
	if Levers.together(session.door, session.far, os.clock()) then
		Levers.solve(session.spec, session.state, os.clock())
		service:_solved(session, player)
	end
end

-- Four times a second (Services/PuzzleService): holders who walked off or went
-- down let go; a lever on its catch ticks, then springs back up.
function Kind.tick(service, session, _dt: number)
	if session.state.solved then
		return
	end
	local now = os.clock()
	for _, lever in { session.door, session.far } do
		for player in lever.holders do
			local position = service.PlayerState:Position(player)
			local near = position and (position - lever.position).Magnitude <= L.Reach + 2
			if not near or not service.PlayerState:CanAct(player) or not player.Parent then
				lever.holders[player] = nil
				Kind.letGo(service, session, lever, player)
			end
		end
		if Levers.ticking(lever, now) then
			if now >= lever.nextTick then
				lever.nextTick = now + L.TickEvery
				Sfx.play("LockClick", lever.position, 0.7, 1.3)
				service.Noise:Emit(lever.position, L.TickNoise, nil, "lure")
			end
		elseif not Levers.down(lever, now) and lever.tilt ~= UP then
			show(lever, UP, Color3.fromRGB(60, 40, 30), false)
			Sfx.play("DoorLatch", lever.position, 0.5, 1.1)
		end
	end
	Kind.check(service, session, nil)
end

-- The door's bolt shoots back, for good; both levers stay down, lit green.
function Kind.solved(service, session, player: Player?)
	for _, lever in { session.door, session.far } do
		show(lever, DOWN, Color3.fromRGB(60, 220, 90), true)
		lever.prompt.Enabled = false
	end
	service.Locks:SetPowered(session.seam, true)
	service.Locks:Unlock(session.seam, player, "Both levers down: somewhere, a bolt shoots back.")
end

return Kind
