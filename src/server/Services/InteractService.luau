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
local Rooms = require(Shared.Data.Rooms)
local RoomPurpose = require(Shared.Logic.RoomPurpose)
local Dressing = require(script.Parent.Parent.World.Dressing)
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
	-- A fixture left running: heard again every so often, and stopped when
	-- its run is up (a wash, a record's side).
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fixture in self.fixtures do
			if fixture.running and fixture.part.Parent then
				if fixture.stopAt and now >= fixture.stopAt then
					self:_stop(fixture)
				elseif now >= fixture.next then
					fixture.next = now + fixture.info.every
					-- One he started himself (Stalk's HostAction) is no lure to him.
					self.Noise:Emit(fixture.position, fixture.info.lure, nil, fixture.byGuest and "guest" or "lure")
				end
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
	self:_placed(world)
	self:_switches(world)
	-- Bathroom doors bolt from inside (docs/plans/level-design.md section 4).
	for _, roomId in self.World:RoomIds() do
		local record = world.rooms[roomId]
		if record and record.template and record.template.id == "bathroom" then
			for _, other in self.World:Neighbours(roomId) do
				local seam = self.World:SeamBetween(roomId, other)
				if seam and seam.connected and seam.door then
					self.services.DoorService:AddPrivacy(seam.door, roomId)
				end
			end
		end
	end
end

-- Rooms' own fixtures that aren't furniture (docs/plans/level-design.md
-- section 4, L3.6): a kettle on every stove (else on a kitchen's counter),
-- and the house's one record player on a top in a living room, a den, a
-- sunroom or the music room (Logic/RoomPurpose.placedRooms, best first).
function InteractService:_placed(world)
	local kettled = {}
	for _, prop in world.props or {} do
		if prop.kind == "Stove" and prop.model.Parent and prop.frame then
			kettled[prop.roomId] = true
			self:_fixture(self:_kettle(prop.frame * CFrame.new(0.8, 3.6, 0.3)), Interactables.Kettle)
		end
	end
	local function topIn(roomId: number, size: { number }): CFrame?
		for _, s in world.surfaces or {} do
			if s.record.id == roomId and s.prop.model.Parent and Dressing.free(s, size[1]) > 0 then
				return Dressing.claim(s, size[1], size[2])
			end
		end
		return nil
	end
	for _, roomId in self.World:RoomIds() do
		local record = world.rooms[roomId]
		if
			not kettled[roomId]
			and record
			and record.template
			and record.template.id == Interactables.Kettle.placed.room
		then
			local spot = topIn(roomId, Config.Dressing.Sizes.Kettle)
			if spot then
				kettled[roomId] = true
				-- (Side on, its spout showing.)
				self:_fixture(self:_kettle(spot * CFrame.Angles(0, math.pi / 2, 0)), Interactables.Kettle)
			end
		end
	end
	local templates = world.layout.mode == "Mansion" and Rooms.MansionById or Rooms.ById
	for _, roomId in RoomPurpose.placedRooms(world.layout, templates, "RecordPlayer") do
		local spot = topIn(roomId, Config.Dressing.Sizes.RecordPlayer)
		if spot then
			self:_fixture(self:_recordPlayer(spot), Interactables.RecordPlayer)
			break
		end
	end
end

-- A stovetop kettle, red enamel: a squat body under a domed top, a black
-- knob, the spout out front (+Z) and an arched handle over it.
function InteractService:_kettle(cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Kettle"
	local red = Color3.fromRGB(150, 36, 30)
	local black = Color3.fromRGB(24, 22, 22)
	local enamel = PropFactory.material("SmoothPlastic")
	local quiet = { collide = false }
	local body = PropFactory.part(
		model,
		"Body",
		Vector3.new(0.55, 1, 1),
		cf * CFrame.new(0, 0.275, 0) * CFrame.Angles(0, 0, math.pi / 2),
		red,
		enamel,
		{ collide = false, shape = Enum.PartType.Cylinder }
	)
	PropFactory.part(model, "Dome", Vector3.new(0.92, 0.92, 0.92), cf * CFrame.new(0, 0.5, 0), red, enamel, {
		collide = false,
		shape = Enum.PartType.Ball,
	})
	PropFactory.part(model, "Knob", Vector3.new(0.16, 0.16, 0.16), cf * CFrame.new(0, 0.98, 0), black, enamel, {
		collide = false,
		shape = Enum.PartType.Ball,
	})
	PropFactory.part(
		model,
		"Spout",
		Vector3.new(0.55, 0.13, 0.13),
		cf * CFrame.new(0, 0.42, 0.55) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(35)),
		red,
		enamel,
		{ collide = false, shape = Enum.PartType.Cylinder }
	)
	for _, z in { -0.3, 0.3 } do
		PropFactory.part(model, "Post", Vector3.new(0.07, 0.4, 0.07), cf * CFrame.new(0, 1.0, z), black, enamel, quiet)
	end
	PropFactory.part(model, "Handle", Vector3.new(0.09, 0.09, 0.7), cf * CFrame.new(0, 1.2, 0), black, enamel, quiet)
	model.PrimaryPart = body
	model.Parent = self.folder
	return model
end

-- A portable record player in its open case, a record on the platter.
function InteractService:_recordPlayer(cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "RecordPlayer"
	local case = PropFactory.part(
		model,
		"Case",
		Vector3.new(1.5, 0.35, 1.2),
		cf * CFrame.new(0, 0.175, 0),
		Color3.fromRGB(120, 84, 56),
		PropFactory.material("Wood"),
		{ collide = false }
	)
	PropFactory.part(
		model,
		"Lid",
		Vector3.new(1.5, 1.2, 0.08),
		cf * CFrame.new(0, 0.85, -0.62) * CFrame.Angles(math.rad(-12), 0, 0),
		Color3.fromRGB(110, 76, 50),
		PropFactory.material("Wood"),
		{ collide = false }
	)
	PropFactory.part(
		model,
		"Record",
		Vector3.new(0.03, 0.95, 0.95),
		cf * CFrame.new(-0.12, 0.37, 0.04) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(18, 18, 20),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, shape = Enum.PartType.Cylinder }
	)
	PropFactory.part(
		model,
		"Arm",
		Vector3.new(0.05, 0.05, 0.7),
		cf * CFrame.new(0.5, 0.42, 0.05) * CFrame.Angles(0, math.rad(20), 0),
		Color3.fromRGB(180, 180, 176),
		PropFactory.material("Metal"),
		{ collide = false }
	)
	model.PrimaryPart = case
	model.Parent = self.folder
	return model
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
		uses = 0,
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

-- A sound looping from the fixture's part (every client plays it: the
-- SoundLoop tag), or stopped.
local function loop(fixture, key: string?)
	local info = fixture.info
	local part = fixture.part
	if key then
		part:SetAttribute("LoopVolume", info.volume)
		part:SetAttribute("LoopPitch", info.pitch or 1)
		part:SetAttribute("LoopRange", info.lure * 3)
		part:SetAttribute("Loop", key)
		CollectionService:AddTag(part, Constants.Tags.SoundLoop)
	else
		part:SetAttribute("Loop", nil)
	end
end

-- Stop one that runs (turned off, or its run is up).
function InteractService:_stop(fixture)
	fixture.running = false
	fixture.stopAt = nil
	loop(fixture, nil)
	if fixture.info.masks then
		self.Noise:Unmask(fixture)
	end
	fixture.prompt.ActionText = fixture.info.action
end

-- Work a fixture: a one-shot (a flush, the horn, the kettle set going), or
-- start or stop one that runs.
-- `byGuest`: he worked it himself (Stalker/Stalk HostAction): its noise is
-- his, and draws nobody but the squad.
function InteractService:Use(fixture, _player: Player?, byGuest: boolean?)
	local info = fixture.info
	local now = os.clock()
	fixture.byGuest = byGuest == true
	if info.uses and fixture.uses >= info.uses then
		return
	end
	if info.on then
		Sfx.play(info.on, fixture.position, 0.4, 1)
	end
	if info.loop then
		if fixture.running then
			self:_stop(fixture)
			return
		end
		fixture.running = true
		fixture.uses += 1
		loop(fixture, info.sound)
		-- Heard at once, then every so often while it runs.
		fixture.next = now
		fixture.stopAt = info.runFor and now + info.runFor or nil
		if info.masks then
			self.Noise:Mask(fixture, fixture.position, info.masks.radius, info.masks.factor)
		end
		fixture.prompt.ActionText = info.off
		return
	end
	if now - fixture.usedAt < (info.cooldown or 0) then
		return
	end
	fixture.usedAt = now
	fixture.uses += 1
	if info.uses and fixture.uses >= info.uses then
		fixture.prompt.Enabled = false
	end
	local function goOff()
		if not fixture.part.Parent then
			return
		end
		if info.ring then
			-- (The kettle: a shriek that goes on a while.)
			loop(fixture, info.sound)
			task.delay(info.ring, function()
				if fixture.part.Parent then
					loop(fixture, nil)
				end
			end)
		else
			Sfx.play(info.sound, fixture.position, info.volume, info.pitch or 1)
		end
		for _, at in info.once or { 0 } do
			task.delay(at, function()
				if fixture.part.Parent then
					self.Noise:Emit(fixture.position, info.lure, nil, "lure")
				end
			end)
		end
	end
	if info.delay then
		task.delay(info.delay, goOff)
	else
		goOff()
	end
end

-- F2 `use [name]`: the nearest fixture (whose name has `word`), worked as its
-- prompt does; `use toy` winds the nearest wind-up toy.
function InteractService:DebugUse(player: Player, word: string?): string
	local position = self.PlayerState:Position(player)
	if not position then
		return "nowhere to stand"
	end
	if word == "toy" then
		return self.services.ToyService:DebugWind(position)
	end
	local best, nearest = nil, math.huge
	for _, fixture in self.fixtures do
		local name = string.lower(fixture.info.object or "")
		local d = (fixture.position - position).Magnitude
		if fixture.part.Parent and (not word or string.find(name, word, 1, true)) and d < nearest then
			best, nearest = fixture, d
		end
	end
	if not best then
		return "no fixture" .. (word and (" like " .. word) or "")
	end
	self:Use(best, player)
	return string.format("%s used, %.0f studs away", best.info.object, nearest)
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
