-- The house's fixtures (R2c interactables): flush a toilet, leave a tap or a
-- bath running, turn up a television's static or a radio, and a light
-- switch by the door of every room. Each fixture's noise is a lure he hears
-- with no source (Services/NoiseService): the way to send him somewhere
-- you aren't. Switches put the room's light out or back on through the one
-- light rule (WorldService:SetLightCause "switch"): a dark room hides you
-- from his eyes, and you from yours.
--
-- Built at the start of each run (Begin, after the house is dressed, so the
-- decor radios are there) into the run's content: Gate A never sees it. The
-- sounds that run are looped on each client from attributes (the SoundLoop
-- tag, Controllers/AudioController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Interactables = require(Shared.Data.Interactables)
local PropFactory = require(Shared.World.PropFactory)
local RoomRects = require(Shared.Logic.RoomRects)
local Sfx = require(Shared.Lib.Sfx)
local SwitchSpots = require(Shared.Logic.SwitchSpots)

local I = Config.Interact

local InteractService = {}

function InteractService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.fixtures = {} -- every fixture: { info, part, position, running, next, usedAt }
	self.switches = {} -- room id -> { plate, nub, off }
end

function InteractService:Start()
	self.World.Cleared:Connect(function()
		table.clear(self.fixtures)
		table.clear(self.switches)
	end)
	-- A fixture left running: heard again every so often.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fixture in self.fixtures do
			if fixture.running and now >= fixture.next and fixture.part.Parent then
				fixture.next = now + fixture.info.every
				self.Noise:Emit(fixture.position, fixture.info.lure, nil, "lure")
			end
		end
	end)
end

function InteractService:Begin()
	local world = self.World.World
	if not world then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Fixtures"
	folder.Parent = self.World.content
	self.folder = folder
	for _, prop in world.props or {} do
		local info = Interactables[prop.kind]
		if info and prop.model.Parent then
			self:_fixture(prop.model, info)
		end
	end
	for _, model in self.services.DecorService.decor or {} do
		if model.Name == "Radio" and model.Parent then
			self:_fixture(model, Interactables.Radio)
		end
	end
	self:_switches(world)
end

-- Fixtures ----------------------------------------------------------------------------

local function mainPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best, size = nil, -1
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local volume = p.Size.X * p.Size.Y * p.Size.Z
			if volume > size then
				best, size = p, volume
			end
		end
	end
	return best
end

function InteractService:_fixture(model: Model, info)
	local part = mainPart(model)
	if not part then
		return
	end
	local fixture = {
		info = info,
		part = part,
		position = model:GetBoundingBox().Position,
		running = false,
		next = 0,
		usedAt = -math.huge,
	}
	table.insert(self.fixtures, fixture)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FixturePrompt"
	prompt.ActionText = info.action
	prompt.ObjectText = info.object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = I.Reach
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 40)
	prompt.Parent = part
	fixture.prompt = prompt
	prompt.Triggered:Connect(function(player)
		if self.PlayerState:CanAct(player) then
			self:Use(fixture, player)
		end
	end)
end

-- Work a fixture: a one-shot (a flush), or start or stop one that runs.
function InteractService:Use(fixture, _player: Player?)
	local info = fixture.info
	local now = os.clock()
	if info.on then
		Sfx.play(info.on, fixture.position, 0.4, 1)
	end
	if info.loop then
		fixture.running = not fixture.running
		local part = fixture.part
		if fixture.running then
			part:SetAttribute("LoopVolume", info.volume)
			part:SetAttribute("LoopPitch", info.pitch or 1)
			part:SetAttribute("LoopRange", info.lure * 3)
			part:SetAttribute("Loop", info.sound)
			CollectionService:AddTag(part, Constants.Tags.SoundLoop)
			-- Heard at once, then every so often while it runs.
			fixture.next = now
		else
			part:SetAttribute("Loop", nil)
		end
		fixture.prompt.ActionText = fixture.running and info.off or info.action
		return
	end
	if now - fixture.usedAt < (info.cooldown or 0) then
		return
	end
	fixture.usedAt = now
	Sfx.play(info.sound, fixture.position, info.volume, info.pitch or 1)
	for _, at in info.once or { 0 } do
		task.delay(at, function()
			if fixture.part.Parent then
				self.Noise:Emit(fixture.position, info.lure, nil, "lure")
			end
		end)
	end
end

-- Light switches ------------------------------------------------------------------------

-- The doorway you come into a room by: from the hall along the shortest way
-- (the hall's own: the one to the dining room, or any).
function InteractService:_wayIn(world, roomId: number)
	local start = world.layout.start
	if roomId == start then
		local seam = world.layout.deliberation and self.World:SeamBetween(start, world.layout.deliberation)
		if seam and seam.connected then
			return seam
		end
		for _, other in self.World:Neighbours(start) do
			local any = self.World:SeamBetween(start, other)
			if any and any.connected then
				return any
			end
		end
		return nil
	end
	local path = self.World:Path(start, roomId)
	local previous = path and path[#path - 1]
	local seam = previous and self.World:SeamBetween(previous, roomId)
	return seam and seam.connected and seam or nil
end

function InteractService:_switches(world)
	local o = Config.Level.Origin
	local rects = {}
	for _, rect in RoomRects.ofLayout(world.layout, Config.Level) do
		rects[rect.id] = rect
	end
	for _, roomId in self.World:RoomIds() do
		local room = world.rooms[roomId]
		local rect = rects[roomId]
		local seam = rect and room.light and self:_wayIn(world, roomId)
		if seam then
			local into = roomId == seam.b and seam.normal or -seam.normal
			local spot = SwitchSpots.place({
				x0 = o.x + rect.x,
				z0 = o.z + rect.z,
				x1 = o.x + rect.x + rect.w,
				z1 = o.z + rect.z + rect.d,
			}, { x = seam.floorPosition.X, z = seam.floorPosition.Z }, { x = into.X, z = into.Z }, I.Switch)
			if spot then
				local at = Vector3.new(spot.x, seam.floorPosition.Y + I.SwitchHeight, spot.z)
				self:_buildSwitch(roomId, CFrame.lookAt(at, at + Vector3.new(into.X, 0, into.Z)))
			end
		end
	end
end

-- A cream plate with a toggle, its face along `cf.LookVector` (into the room).
function InteractService:_buildSwitch(roomId: number, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "LightSwitch"
	local plate = PropFactory.part(
		model,
		"Plate",
		Vector3.new(0.38, 0.6, 0.05),
		cf * CFrame.new(0, 0, -0.025),
		Color3.fromRGB(226, 218, 196),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false }
	)
	local nub = PropFactory.part(
		model,
		"Toggle",
		Vector3.new(0.1, 0.18, 0.08),
		cf * CFrame.new(0, 0.06, -0.08) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(236, 230, 214),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false }
	)
	model.Parent = self.folder
	local switch = { plate = plate, nub = nub, cf = cf, off = false }
	self.switches[roomId] = switch
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SwitchPrompt"
	prompt.ActionText = "Switch the light off"
	prompt.ObjectText = "Light switch"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = I.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	switch.prompt = prompt
	prompt.Triggered:Connect(function(player)
		if self.PlayerState:CanAct(player) then
			self:Flip(roomId, not switch.off, player)
		end
	end)
end

-- A room's switch, off or on (F2 `switch`, and anyone at it).
function InteractService:Flip(roomId: number, off: boolean, player: Player?)
	local switch = self.switches[roomId]
	if not switch then
		return
	end
	switch.off = off
	switch.nub.CFrame = switch.cf
		* CFrame.new(0, off and -0.06 or 0.06, -0.08)
		* CFrame.Angles(math.rad(off and 20 or -20), 0, 0)
	switch.prompt.ActionText = off and "Switch the light on" or "Switch the light off"
	Sfx.play("FlashlightClick", switch.plate.Position, 0.45, 0.8)
	self.Noise:Emit(switch.plate.Position, I.SwitchNoise, player, "switch")
	self.World:SetLightCause(roomId, "switch", off)
end

return InteractService
