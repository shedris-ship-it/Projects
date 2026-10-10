-- The baby monitor (docs/plans/level-design.md section 4, L3.6): in the
-- nursery, a transmitter and its receiver. The transmitter is a small thing
-- (Services/HandsService): leave it in a room. Whoever carries the receiver
-- hears that room: a hiss of static, and his footsteps when he comes near it.
-- One a house. The receiver drops where its holder falls or leaves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Interactables = require(Shared.Data.Interactables)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local PropFactory = require(Shared.World.PropFactory)
local Sfx = require(Shared.Lib.Sfx)

local M = Config.Monitor

local MonitorService = {}

function MonitorService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.transmitter = nil -- the Model, a small thing
	self.receiver = nil -- the Model lying somewhere, or nil while carried
	self.holder = nil
	self.sent = nil
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

function MonitorService:Start()
	self.World.Cleared:Connect(function()
		self:_setHolder(nil)
		self.transmitter = nil
		self.receiver = nil
	end)
	self.PlayerState.StateChanged:Connect(function(player, state)
		if player == self.holder and state ~= Constants.PlayerStates.Active then
			self:_dropFrom(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player == self.holder then
			self:_dropFrom(player)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / M.Hz then
			return
		end
		elapsed = 0
		self:_listen()
	end)
end

-- A plastic unit with a stub of an aerial; `cf` on a top or the floor.
local function unit(name: string, cf: CFrame, parent: Instance, color: Color3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local body = PropFactory.part(
		model,
		"Body",
		Vector3.new(0.45, 0.6, 0.25),
		cf * CFrame.new(0, 0.3, 0),
		color,
		PropFactory.material("SmoothPlastic"),
		{ collide = false }
	)
	PropFactory.part(
		model,
		"Aerial",
		Vector3.new(0.05, 0.35, 0.05),
		cf * CFrame.new(0.15, 0.78, 0),
		Color3.fromRGB(40, 40, 42),
		PropFactory.material("SmoothPlastic"),
		{ collide = false }
	)
	PropFactory.part(
		model,
		"Light",
		Vector3.new(0.08, 0.08, 0.02),
		cf * CFrame.new(-0.12, 0.45, -0.13),
		Color3.fromRGB(90, 220, 110),
		PropFactory.material("Neon"),
		{ collide = false, castShadow = false }
	)
	model.PrimaryPart = body
	model.Parent = parent
	return model, body
end

-- Both halves in the nursery (Data/Interactables BabyMonitor), on its tops
-- or its floor.
function MonitorService:Begin(rng)
	local world = self.World.World
	if not world then
		return
	end
	local items = self.services.ItemService
	for _, id in self.World:RoomIds() do
		local record = world.rooms[id]
		if record and record.template and table.find(Interactables.BabyMonitor.placed.rooms, record.template.id) then
			local function spot(): CFrame
				local top = items:TopSpot(id, rng)
				if top then
					return top
				end
				return CFrame.new(self.World:ClearFloorPoint(id, rng))
			end
			local transmitter = unit("BabyMonitor", spot(), self.World.content, Color3.fromRGB(230, 226, 214))
			self.services.HandsService:AddThing(transmitter, Physical.Dressing.BabyMonitor)
			self.transmitter = transmitter
			self:_placeReceiver(spot())
			return
		end
	end
end

-- The receiver lying at `cf`, to take.
function MonitorService:_placeReceiver(cf: CFrame)
	local model, body = unit("Receiver", cf, self.World.content, Color3.fromRGB(200, 214, 226))
	self.receiver = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take the receiver"
	prompt.ObjectText = "Baby monitor"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		if self.PlayerState:CanAct(player) and self.receiver == model and not self.holder then
			model:Destroy()
			self.receiver = nil
			self:_setHolder(player)
			Sfx.play("Cloth", body.Position, 0.4, 1.3)
			notify(
				player,
				"The receiver hisses. Leave the other half somewhere and you'll hear that room from anywhere.",
				"good"
			)
		end
	end)
end

function MonitorService:_setHolder(player: Player?)
	if self.holder and self.holder.Parent then
		self.holder:SetAttribute("Monitor", nil)
		Net.get("MonitorHear"):FireClient(self.holder, nil)
	end
	self.holder = player
	self.sent = nil
	if player then
		player:SetAttribute("Monitor", true)
	end
end

-- Its holder fell or left: the receiver lies where they were.
function MonitorService:_dropFrom(player: Player)
	local position = self.PlayerState:Position(player)
	self:_setHolder(nil)
	if position and self.World.World then
		local floor = self.World:FloorBase(position.Y)
		self:_placeReceiver(CFrame.new(position.X, floor, position.Z))
	end
end

-- What the transmitter hears, to whoever holds the receiver: 0 (only the
-- hiss) to 1 (he's right by it).
function MonitorService:_listen()
	local holder = self.holder
	if not holder or not holder.Parent then
		return
	end
	local level = 0
	local transmitter = self.transmitter
	local stalker = self.services.StalkerService
	local guest = stalker and stalker:GetPosition()
	if transmitter and transmitter.Parent and guest then
		local at = transmitter:GetPivot().Position
		local d = (guest - at).Magnitude
		if math.abs(guest.Y - at.Y) < M.Storey and d < M.Range then
			level = math.clamp(1 - d / M.Range, 0, 1)
		end
	end
	level = math.round(level * 10) / 10
	if level ~= self.sent then
		self.sent = level
		Net.get("MonitorHear"):FireClient(holder, level)
	end
end

-- For F2 `monitor`: where the halves are.
function MonitorService:Describe(): string
	if not self.transmitter then
		return "no baby monitor this run"
	end
	local at = self.transmitter:GetPivot().Position
	local room = self.World:RoomAt(at)
	return string.format(
		"transmitter in room %s; receiver %s",
		tostring(room),
		self.holder and ("with " .. self.holder.Name) or "lying in the house"
	)
end

return MonitorService
