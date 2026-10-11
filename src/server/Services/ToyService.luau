-- Wind-up toys (docs/plans/level-design.md section 4, L3.6): a tin robot on
-- the floor of a child's bedroom or the playroom. Wind it up and set it down,
-- and it walks off ticking for a while, turning when it meets a wall: a lure
-- that moves. It's a small thing too (Services/HandsService): pick it up, carry
-- it where you want the noise, throw it. Picked up mid-walk, it stops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Interactables = require(Shared.Data.Interactables)
local Physical = require(Shared.Data.Physical)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local T = Config.Toys

local ToyService = {}

function ToyService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.toys = {} -- { thing, model, body, walking?, until, nextNoise, heading }
end

function ToyService:Start()
	self.World.Cleared:Connect(function()
		table.clear(self.toys)
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, toy in self.toys do
			if toy.walking then
				self:_step(toy, dt)
			end
		end
	end)
end

-- A tin robot, standing at `cf` (on the floor), facing its -Z.
local function robot(cf: CFrame, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "WindUpToy"
	local tin = Color3.fromRGB(176, 64, 46)
	local metal = PropFactory.material("Metal")
	local body = PropFactory.part(
		model,
		"Body",
		Vector3.new(0.45, 0.5, 0.32),
		cf * CFrame.new(0, 0.45, 0),
		tin,
		metal,
		{ collide = false }
	)
	PropFactory.part(
		model,
		"Head",
		Vector3.new(0.34, 0.3, 0.3),
		cf * CFrame.new(0, 0.85, 0),
		Color3.fromRGB(190, 190, 186),
		metal,
		{
			collide = false,
		}
	)
	for _, x in { -0.12, 0.12 } do
		PropFactory.part(
			model,
			"Leg",
			Vector3.new(0.12, 0.22, 0.14),
			cf * CFrame.new(x, 0.11, 0),
			Color3.fromRGB(60, 60, 64),
			metal,
			{ collide = false }
		)
		PropFactory.part(
			model,
			"Eye",
			Vector3.new(0.07, 0.07, 0.02),
			cf * CFrame.new(x * 0.7, 0.88, -0.16),
			Color3.fromRGB(240, 220, 120),
			PropFactory.material("Neon"),
			{ collide = false, castShadow = false }
		)
	end
	-- Its key, in its back.
	PropFactory.part(
		model,
		"Key",
		Vector3.new(0.3, 0.05, 0.05),
		cf * CFrame.new(0, 0.5, 0.22),
		Color3.fromRGB(196, 170, 90),
		metal,
		{
			collide = false,
		}
	)
	model.PrimaryPart = body
	model.Parent = parent
	return model, body
end

-- One in each child's room and playroom (Data/Interactables WindUpToy),
-- somewhere on its floor.
function ToyService:Begin(rng)
	local world = self.World.World
	if not world then
		return
	end
	local hands = self.services.HandsService
	for _, id in self.World:RoomIds() do
		local record = world.rooms[id]
		if record and record.template and table.find(Interactables.WindUpToy.placed.rooms, record.template.id) then
			local point = self.World:ClearFloorPoint(id, rng)
			local cf = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local model, body = robot(cf, self.World.content)
			local info = Physical.Dressing.WindUpToy
			local thing = hands and hands:AddThing(model, info)
			local toy = { thing = thing, model = model, body = body, walking = false, spawn = model:GetPivot() }
			table.insert(self.toys, toy)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "WindPrompt"
			prompt.ActionText = "Wind it up"
			prompt.ObjectText = "Wind-up toy"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = T.WindSeconds
			prompt.MaxActivationDistance = 6
			prompt.RequiresLineOfSight = false
			prompt.Parent = body
			prompt.Triggered:Connect(function(player)
				if self.PlayerState:CanAct(player) then
					self:Wind(toy, player)
				end
			end)
		end
	end
end

-- How high its body's middle (its pivot) stands above its feet.
local FOOT = 0.45

-- The top of whatever solid is under `position` (a floor, a stair's ramp),
-- or nil over nothing.
local function groundBelow(position: Vector3, ignore): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position, Vector3.new(0, -200, 0), params)
	return hit and hit.Position.Y or nil
end

-- Wound and let go: it walks the way it faces.
function ToyService:Wind(toy, _player: Player?)
	if toy.walking or not toy.model.Parent then
		return
	end
	if toy.thing and toy.thing.state ~= "rest" then
		return
	end
	toy.walking = true
	toy.untilAt = os.clock() + T.WalkSeconds
	toy.nextNoise = 0
	toy.fall, toy.fallFrom = nil, nil
	-- Stood back on its feet the way it faces (it may lie where it fell or
	-- was thrown; one standing on its head walks the way its back faced).
	local at = toy.model:GetPivot()
	local look = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
	if look.Magnitude < 0.2 then
		look = Vector3.new(at.UpVector.X, 0, at.UpVector.Z)
	end
	toy.heading = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
	local ground = groundBelow(at.Position + Vector3.new(0, 0.5, 0), { toy.model })
	local feet = ground or (at.Position.Y - FOOT)
	local stand = Vector3.new(at.Position.X, feet + FOOT, at.Position.Z)
	toy.model:PivotTo(CFrame.lookAt(stand, stand + toy.heading))
	local body = toy.body
	body:SetAttribute("LoopVolume", 0.6)
	body:SetAttribute("LoopPitch", 1)
	body:SetAttribute("LoopRange", T.Lure * 3)
	body:SetAttribute("Loop", "ToyWindUp")
	CollectionService:AddTag(body, Constants.Tags.SoundLoop)
end

function ToyService:_stop(toy)
	toy.walking = false
	toy.body:SetAttribute("Loop", nil)
	if toy.thing then
		toy.thing.home = toy.model:GetPivot()
	end
end

-- A little further along the floor, ticking; it turns off what it walks into,
-- and falls off what it walks off.
function ToyService:_step(toy, dt: number)
	local now = os.clock()
	local thing = toy.thing
	if not toy.model.Parent or now >= toy.untilAt or (thing and thing.state ~= "rest") then
		self:_stop(toy)
		return
	end
	local at = toy.model:GetPivot()
	local ahead = toy.heading * T.Speed * dt
	-- Anything solid where it's stepping, its whole height (a wall, a crib's
	-- legs and the bed's frame it would walk under): it turns back.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { toy.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local stalker = self.services.StalkerService
	local guest = stalker and stalker.body and stalker.body.model
	if guest then
		table.insert(ignore, guest)
	end
	params.FilterDescendantsInstances = ignore
	-- (The body's middle is 0.45 above the floor; the box runs 0.15 to 1.1.)
	local probe = CFrame.lookAt(at.Position, at.Position + toy.heading) * CFrame.new(0, 0.18, -0.45)
	local blocked = false
	for _, part in workspace:GetPartBoundsInBox(probe, Vector3.new(0.5, 0.95, 0.4), params) do
		if part.CanCollide then
			blocked = true
			break
		end
	end
	if blocked then
		-- Turned back the way it came, more or less.
		local turn = math.rad(Rng.new(math.floor(now * 1000)):NextNumber(120, 240))
		toy.heading = (CFrame.Angles(0, turn, 0) * toy.heading).Unit
		ahead = Vector3.zero
	end
	local position = at.Position + ahead
	-- Gravity: down to whatever is under it now, falling faster the longer it falls.
	local ground = groundBelow(position, ignore)
	local feet = position.Y - FOOT
	if not ground or feet > ground + 0.02 then
		toy.fallFrom = toy.fallFrom or feet
		toy.fall = (toy.fall or 0) + workspace.Gravity * dt
		feet = math.max(ground or -math.huge, feet - toy.fall * dt)
		if not ground and toy.fallFrom - feet > 40 then
			-- Over nothing at all (out through a gap in the house): back where it was kept.
			toy.model:PivotTo(toy.spawn)
			toy.fall, toy.fallFrom = nil, nil
			self:_stop(toy)
			return
		end
	end
	if ground and feet <= ground + 0.02 then
		local dropped = (toy.fallFrom or feet) - ground
		toy.fall, toy.fallFrom = nil, nil
		feet = ground
		if dropped > T.StepDrop then
			-- Off a landing or a table: on its side, clattering, done.
			local lying = CFrame.new(position.X, ground + 0.25, position.Z)
				* CFrame.lookAt(Vector3.zero, toy.heading).Rotation
				* CFrame.Angles(0, 0, math.pi / 2)
			toy.model:PivotTo(lying)
			Sfx.play("Knock", lying.Position, 0.5, 1.6)
			self.Noise:Emit(lying.Position, T.ClatterLure, nil, "lure")
			self:_stop(toy)
			return
		end
	end
	position = Vector3.new(position.X, feet + FOOT, position.Z)
	toy.model:PivotTo(CFrame.lookAt(position, position + toy.heading))
	if now >= toy.nextNoise then
		toy.nextNoise = now + T.NoiseEvery
		self.Noise:Emit(position, T.Lure, nil, "lure")
	end
end

-- F2 `use toy`: the nearest one wound.
function ToyService:DebugWind(position: Vector3): string
	local best, nearest = nil, math.huge
	for _, toy in self.toys do
		local d = (toy.model:GetPivot().Position - position).Magnitude
		if toy.model.Parent and d < nearest then
			best, nearest = toy, d
		end
	end
	if not best then
		return "no wind-up toy in this house"
	end
	self:Wind(best)
	return string.format("toy wound, %.0f studs away", nearest)
end

return ToyService
