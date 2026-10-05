-- The dumbwaiter (R2c, the two-person locks): a boxed shaft against a wall
-- shared by a ground-floor room and the room above it (Logic/Dumbwaiter).
-- Downstairs its hatch is stuck shut, a little window showing the car and
-- the heirloom in it; beside it, a crank. Hold E at the crank and the car
-- rises to the open hatch upstairs; let go and it slides back down. So one
-- cranks while another takes it upstairs. On your own: jam the crank with
-- something heavy you carry (Q at the jam box) and it holds the car wherever
-- you crank it to; then run up. Nothing is ever stranded: a car left
-- between floors slides back to the ground. Once its heirloom is taken it's
-- done (the station is solved), and he puts the heirloom back on the upper
-- hatch's shelf if it's left lying.
--
-- No screen (Logic/Puzzles/Dumbwaiter is only the registry's contract).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Dumbwaiter = require(Shared.Logic.Dumbwaiter)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local Sfx = require(Shared.Lib.Sfx)

local D = Config.Dumbwaiter
local part = PropFactory.part
local WOOD = Color3.fromRGB(92, 66, 44)
local HATCH_Y = 2.6 -- the car's floor at each hatch, above the room's floor
local WIDTH, DEPTH, CAR = 1.9, 1.7, 1.25

local Kind = {
	label = "Dumbwaiter",
	done = "",
	noScreen = true,
}

local function floorY(floor: number): number
	return Config.Level.Origin.y + floor * Config.Mansion.FloorPitch
end

function Kind.create(service, id: string, puzzle)
	local world = service.World.World
	local upper, ground = puzzle.rooms[1], puzzle.rooms[2]
	local byId = {}
	for _, room in world.layout.rooms do
		byId[room.id] = room
	end
	local token
	for tokenId, info in service.plan.tokens do
		if info.producer.kind == "puzzle" and info.producer.id == id then
			token = tokenId
		end
	end
	local session = {
		id = id,
		kind = "dumbwaiter",
		spec = {},
		state = { solved = false },
		room = ground, -- the crank's room: where it's worked
		token = token,
		reach = D.Reach,
		p = 0,
		crankers = {},
	}
	local o = Config.Level.Origin
	for _, spot in Dumbwaiter.spots(world.layout, byId[ground], byId[upper], D) do
		local into = Vector3.new(spot.into.x, 0, spot.into.z)
		local wall = Vector3.new(o.x + spot.x, 0, o.z + spot.z)
		if Kind._clear(wall, into, floorY(0)) and Kind._clear(wall, into, floorY(1)) then
			Kind.build(service, session, wall, into)
			break
		end
	end
	if not session.station then
		-- Nowhere clear on that wall: the heirloom is simply kept upstairs.
		warn("[Consensus] no room for the dumbwaiter between " .. ground .. " and " .. upper)
		if token then
			local at = service.World:RandomPointIn(upper, Random.new(puzzle.seed))
			service.services.ItemService:Make(token, CFrame.new(at))
		end
		session.state.solved = true
		return session
	end
	if token then
		local items = service.services.ItemService
		local model, thing = items:Make(token, session.carAt(0))
		session.item = { model = model, thing = thing }
		items:SetHome(token, {
			room = upper,
			station = {
				Restore = function(t)
					items:Make(t, session.carAt(1))
				end,
			},
		})
	end
	session.heartbeat = RunService.Heartbeat:Connect(function(dt)
		Kind.step(service, session, dt)
	end)
	return session
end

-- Is there room for the casing against this wall on a floor (no furniture)?
function Kind._clear(wall: Vector3, into: Vector3, y: number): boolean
	local center = wall + into * (0.6 + DEPTH / 2) + Vector3.new(0, y + 4.5, 0)
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local cf = CFrame.lookAt(center, center + into)
	-- Anything solid there (furniture, a radiator...) and it won't fit.
	return #Workspace:GetPartBoundsInBox(cf, Vector3.new(WIDTH, 8.4, DEPTH - 0.2), params) == 0
end

-- A wooden casing on one floor, against the wall, with its hatch: shut with
-- a little window (`shut`) or open on a shelf. `cf` faces into the room
-- (+Z), on the wall face at the room's floor.
local function casing(model: Model, cf: CFrame, shut: boolean)
	local wood = PropFactory.material("Wood")
	local h = Config.Level.WallHeight -- floor to ceiling (the slab hides the shaft between)
	for _, sx in { -1, 1 } do
		part(
			model,
			"Side",
			Vector3.new(0.15, h, DEPTH),
			cf * CFrame.new(sx * (WIDTH / 2 - 0.075), h / 2, DEPTH / 2),
			WOOD,
			wood
		)
	end
	-- Front, above and below the hatch opening (1.4 high, from HATCH_Y).
	part(model, "Front", Vector3.new(WIDTH, HATCH_Y, 0.12), cf * CFrame.new(0, HATCH_Y / 2, DEPTH - 0.06), WOOD, wood)
	local top = HATCH_Y + 1.4
	part(
		model,
		"Front",
		Vector3.new(WIDTH, h - top, 0.12),
		cf * CFrame.new(0, top + (h - top) / 2, DEPTH - 0.06),
		WOOD,
		wood
	)
	part(
		model,
		"Trim",
		Vector3.new(1.6, 0.12, 0.16),
		cf * CFrame.new(0, top + 0.06, DEPTH),
		PropFactory.shade(WOOD, 0.8),
		wood,
		{ collide = false }
	)
	if shut then
		local door = part(
			model,
			"Hatch",
			Vector3.new(WIDTH - 0.3, 1.4, 0.1),
			cf * CFrame.new(0, HATCH_Y + 0.7, DEPTH - 0.04),
			PropFactory.shade(WOOD, 1.1),
			wood
		)
		part(
			model,
			"Window",
			Vector3.new(0.7, 0.5, 0.12),
			cf * CFrame.new(0, HATCH_Y + 0.85, DEPTH - 0.03),
			Color3.fromRGB(190, 200, 205),
			PropFactory.material("Glass"),
			{ transparency = 0.55, castShadow = false }
		)
		return door
	end
	return nil
end

function Kind.build(service, session, wall: Vector3, into: Vector3)
	local folder = service.World.content
	local model = Instance.new("Model")
	model.Name = "Dumbwaiter"
	local base0 = CFrame.lookAt(
		Vector3.new(wall.X, floorY(0), wall.Z) + into * 0.55,
		Vector3.new(wall.X, floorY(0), wall.Z) + into * 2
	)
	local base1 = base0 + Vector3.new(0, floorY(1) - floorY(0), 0)
	-- lookAt points -Z at the target: turn half round so +Z is into the room.
	base0 *= CFrame.Angles(0, math.pi, 0)
	base1 *= CFrame.Angles(0, math.pi, 0)
	casing(model, base0, true)
	casing(model, base1, false)
	-- The car: a little box on its cable, the heirloom on its floor.
	local car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = model
	local carFloor = part(
		car,
		"CarFloor",
		Vector3.new(CAR, 0.1, CAR),
		base0 * CFrame.new(0, HATCH_Y + 0.05, DEPTH / 2),
		WOOD,
		PropFactory.material("Wood")
	)
	part(
		car,
		"CarBack",
		Vector3.new(CAR, 1.3, 0.08),
		base0 * CFrame.new(0, HATCH_Y + 0.7, DEPTH / 2 - CAR / 2),
		WOOD,
		PropFactory.material("Wood"),
		{ collide = false }
	)
	part(
		car,
		"CarTop",
		Vector3.new(CAR, 0.08, CAR),
		base0 * CFrame.new(0, HATCH_Y + 1.36, DEPTH / 2),
		WOOD,
		PropFactory.material("Wood"),
		{ collide = false }
	)
	car.PrimaryPart = carFloor
	-- The crank on the casing's side, and the jam box under it.
	local crankAt = base0 * CFrame.new(WIDTH / 2 + 0.1, 3.4, DEPTH - 0.4) * CFrame.Angles(0, math.pi / 2, 0)
	local wheel = part(
		model,
		"Wheel",
		Vector3.new(0.12, 0.8, 0.8),
		crankAt * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(110, 84, 54),
		PropFactory.material("Metal"),
		{ shape = Enum.PartType.Cylinder }
	)
	local jam = part(
		model,
		"JamBox",
		Vector3.new(0.7, 0.5, 0.7),
		base0 * CFrame.new(WIDTH / 2 + 0.45, 1.2, DEPTH - 0.4),
		Color3.fromRGB(70, 70, 70),
		PropFactory.material("Metal")
	)
	model.Parent = folder
	session.model, session.car, session.station = model, car, wheel
	session.front = into
	session.carBase = { base0, base1 }
	session.carAt = function(p: number)
		local y = floorY(0) + (floorY(1) - floorY(0)) * p + HATCH_Y + 0.12
		local at = base0 * CFrame.new(0, 0, DEPTH / 2)
		return CFrame.new(at.X, y, at.Z) * at.Rotation
	end
	-- Hold E at the crank: the car rises.
	local prompt = service:Prompt(session, wheel, "Crank (hold)", Kind.label)
	prompt.HoldDuration = 60
	prompt.MaxActivationDistance = D.Reach
	prompt.PromptButtonHoldBegan:Connect(function(player)
		session.crankers[player] = true
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		session.crankers[player] = nil
	end)
	-- Q at the jam box: wedge something heavy in the crank (it then holds).
	local jamPrompt = Instance.new("ProximityPrompt")
	jamPrompt.Name = "JamPrompt"
	jamPrompt.ActionText = "Jam the crank with what you carry"
	jamPrompt.ObjectText = "Jam box"
	jamPrompt.KeyboardKeyCode = Enum.KeyCode.Q
	jamPrompt.GamepadKeyCode = Enum.KeyCode.ButtonL1
	jamPrompt.HoldDuration = 0.4
	jamPrompt.MaxActivationDistance = D.Reach
	jamPrompt.RequiresLineOfSight = false
	jamPrompt.Parent = jam
	jamPrompt.Triggered:Connect(function(player)
		Kind.jam(service, session, player, jam)
	end)
	session.jamPrompt = jamPrompt
end

-- Wedge a heavy or bulky thing you carry into the jam box.
function Kind.jam(service, session, player: Player, box: BasePart)
	if session.jammed or not service.PlayerState:CanAct(player) then
		return
	end
	local hands = service.Hands
	local thing = hands:Held(player)
	local class = thing and thing.model:GetAttribute("Class")
	if class ~= "heavy" and class ~= "bulky" then
		Net.get("Notify"):FireClient(player, "It needs something heavy wedged in it.", "info")
		return
	end
	hands:Release(player)
	thing.model:PivotTo(box.CFrame * CFrame.new(0, 0.6, 0))
	session.jammed = thing
	session.jamPrompt.Enabled = false
	Sfx.play("Knock", box.Position, 0.6, 0.8)
end

-- The car rises while someone cranks; with the crank jammed it holds where
-- it is; otherwise it slides back down. The heirloom rides in it.
function Kind.step(service, session, dt: number)
	if not session.model or not session.model.Parent then
		if session.heartbeat then
			session.heartbeat:Disconnect()
		end
		return
	end
	-- Jammed with something someone has since taken back: not jammed.
	local jam = session.jammed
	if jam and (jam.holder or jam.state == "gone" or not jam.model.Parent) then
		session.jammed = nil
		session.jamPrompt.Enabled = true
	end
	local before = session.p
	local cranking = nil
	for player in session.crankers do
		local position = service.PlayerState:Position(player)
		if
			position
			and (position - session.station.Position).Magnitude <= D.Reach + 2
			and service.PlayerState:CanAct(player)
		then
			cranking = player
		else
			session.crankers[player] = nil
		end
	end
	if session.state.solved then
		session.p = 1
	elseif cranking then
		session.p = math.min(1, session.p + D.Rise * dt)
		local now = os.clock()
		if now >= (session.nextCreak or 0) and session.p < 1 then
			session.nextCreak = now + 1
			Sfx.play("Creak", session.station.Position, 0.5, 1.3)
			service.Noise:Emit(session.station.Position, D.CreakNoise, cranking, "puzzle")
		end
	elseif not session.jammed then
		session.p = math.max(0, session.p - D.Fall * dt)
	end
	if session.p ~= before then
		local at = session.carAt(session.p)
		session.car:PivotTo(at * CFrame.new(0, -0.07, 0))
		local item = session.item
		if item and item.thing and item.thing.state == "rest" and not item.thing.holder and item.model.Parent then
			item.model:PivotTo(at)
		end
		if session.p >= 1 and before < 1 then
			Sfx.play("Knock", at.Position, 0.7, 0.6)
		end
	end
	-- Taken out of the car: done.
	local item = session.item
	if item and not session.state.solved and item.thing and (item.thing.holder or item.thing.state ~= "rest") then
		service:MarkSolved(session, item.thing.holder)
	end
end

return Kind
