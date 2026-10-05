-- Your hands (docs/plans/gameplay-rework.md section 4): what a player's bare
-- hands may take hold of, checked here on the server.
--   * Doors, dragged Amnesia-style (Controllers/HandsController streams where
--     the hand wants the door; DoorService turns it).
--   * Small things (Data/Physical: mugs, books, the telephone, chairs...):
--     carried at arm's length and thrown. Each one stays anchored until it's
--     first grabbed, so the house builds the same every time and nothing
--     settles at load. Grabbed, it's welded into one body that the holder's
--     client simulates (network ownership); let go or thrown, the server
--     simulates it; once it lies still it's anchored again where it lies.
--
-- Every message is checked: the player can act, the thing is within reach
-- of their head and nothing solid stands between. While someone holds a
-- thing, every frame the server checks it is still near their head, not
-- moving faster than a hand could, and hasn't crossed a wall; if any fails
-- it's put back and dropped. Held and thrown things never touch players or
-- The Guest (the Held and Prop collision groups): a throw's hit on him is
-- worked out here from the path it flew (Logic/Throw, Thrown/Moved signals).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Inventory = require(Shared.Logic.Inventory)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)
local Throw = require(Shared.Logic.Throw)

local H = Config.Hands
local Groups = Constants.CollisionGroups
local States = Constants.PlayerStates

local HandsService = {
	-- (thing, thrower): a throw just left someone's hands.
	Thrown = Signal.new(),
	-- (thing, from, to): a thrown thing moved this step (the stun's hit test).
	Moved = Signal.new(),
}

function HandsService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Doors = services.DoorService
	self.PlayerState = services.PlayerStateService
	self.Witness = services.WitnessService
	self.Noise = services.NoiseService
	self.Tools = services.ToolService
	self.things = {} -- id -> thing
	self.awake = {} -- thing -> true while unanchored
	self.held = {} -- player -> thing
end

function HandsService:Start()
	Net.onServer("Drag", {
		interval = 1 / (H.DragSendHz + 10),
		burst = H.DragSendHz + 15,
		types = { "string", "number" },
	}, function(player, id, value)
		self:_drag(player, id, value)
	end)
	Net.onServer("Grab", { interval = 0.15, burst = 6, types = { "string" } }, function(player, id)
		self:Grab(player, id)
	end)
	Net.onServer("Release", { interval = 0.1, burst = 8, types = {} }, function(player)
		self:Release(player)
	end)
	Net.onServer("Throw", { interval = 0.3, burst = 3, types = { "Vector3" } }, function(player, aim)
		self:Throw(player, aim)
	end)
	self.World.Built:Connect(function(world)
		self:_register(world)
	end)
	self.World.Cleared:Connect(function()
		table.clear(self.things)
		table.clear(self.awake)
		table.clear(self.held)
	end)
	-- Downed, lost, out of the house or gone: whatever was in their hands falls.
	self.PlayerState.StateChanged:Connect(function(player, state)
		if state ~= States.Active then
			self:Release(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)
end

-- Doors -----------------------------------------------------------------------

-- Something within reach of the player's head, with a clear line to it.
function HandsService:_canReach(player: Player, position: Vector3, reach: number, ignore: Instance): boolean
	local head = self.PlayerState:Head(player)
	if not head then
		return false
	end
	if (head.Position - position).Magnitude > reach then
		return false
	end
	return self.Witness:ClearLine(head.Position, position, { ignore })
end

function HandsService:_drag(player: Player, id: string, value: number)
	local world = self.World.World
	if not world or not self.PlayerState:CanAct(player) then
		return
	end
	local door = world.doors[id]
	if not door or not door.slab.Parent then
		return
	end
	if not self:_canReach(player, door.slab.Position, H.DragReach, door.model) then
		return
	end
	self.Doors:Drag(door, value, player)
end

-- Small things ----------------------------------------------------------------

-- Give every small thing in the new house an id, and make it something your
-- hand can find (queries on; it still doesn't collide while it sleeps). The
-- class and label ride on the model for the client.
function HandsService:_register(world)
	local count = 0
	local function add(model: Model, info)
		if model:GetAttribute("Grab") then
			return
		end
		local parts = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = true
				table.insert(parts, p)
			end
		end
		if #parts == 0 then
			return
		end
		count += 1
		local id = "thing:" .. count
		model:SetAttribute("Grab", id)
		model:SetAttribute("Label", info.label)
		model:SetAttribute("Class", info.class)
		CollectionService:AddTag(model, Constants.Tags.Grabbable)
		self.things[id] = {
			id = id,
			model = model,
			parts = parts,
			class = Physical.Classes[info.class],
			home = model:GetPivot(),
			state = "rest",
		}
	end
	-- The house's own furniture by kind (not a clue built like a chair).
	for _, prop in world.props or {} do
		local info = Physical.Furniture[prop.kind]
		if info and prop.model.Parent then
			add(prop.model, info)
		end
	end
	for _, d in self.World.folder:GetDescendants() do
		local info = d:IsA("Model") and Physical.Dressing[d.Name]
		if info then
			add(d, info)
		end
	end
	world.things = self.things
end

-- The first time it's grabbed: one welded body, heavy as its class.
function HandsService:_prepare(thing)
	if thing.root then
		return
	end
	local root, best = nil, -1
	for _, p in thing.parts do
		local volume = p.Size.X * p.Size.Y * p.Size.Z
		if volume > best then
			root, best = p, volume
		end
	end
	local class = thing.class
	for _, p in thing.parts do
		if p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = root
		end
		p.CanCollide = true
		p.CanTouch = false
		p.Massless = false
		p.CustomPhysicalProperties = PhysicalProperties.new(class.density, 0.5, 0.15)
	end
	-- Never something for The Guest's navmesh to walk round.
	local modifier = Instance.new("PathfindingModifier")
	modifier.PassThrough = true
	modifier.Parent = root
	thing.root = root
	thing.model.PrimaryPart = root
end

function HandsService:_setGroup(thing, group: string)
	for _, p in thing.parts do
		p.CollisionGroup = group
	end
end

function HandsService:_wake(thing)
	self:_prepare(thing)
	for _, p in thing.parts do
		p.Anchored = false
	end
	self.awake[thing] = true
end

function HandsService:_sleep(thing)
	self.awake[thing] = nil
	thing.state = "rest"
	thing.thrower = nil
	if thing.root and thing.root.Parent then
		thing.root.AssemblyLinearVelocity = Vector3.zero
		thing.root.AssemblyAngularVelocity = Vector3.zero
		for _, p in thing.parts do
			p.Anchored = true
		end
	end
end

-- What a player has in their hands, if anything.
function HandsService:Held(player: Player)
	return self.held[player]
end

function HandsService:Grab(player: Player, id: string)
	local thing = self.things[id]
	if not thing or thing.holder or not thing.model.Parent or not self.PlayerState:CanAct(player) then
		return
	end
	local position = thing.model:GetPivot().Position
	if not self:_canReach(player, position, H.Reach + 1.5, thing.model) then
		return
	end
	if self.held[player] then
		self:Release(player)
	end
	self:_wake(thing)
	self:_setGroup(thing, Groups.Held)
	thing.root:SetNetworkOwner(player)
	thing.state = "held"
	thing.holder = player
	thing.thrower = nil
	thing.lastValid = thing.root.CFrame
	self.held[player] = thing
	thing.model:SetAttribute("HeldBy", player.UserId)
	-- Taking hold of something puts your hands in your hands (slot 4).
	self.Tools:SelectSlot(player, Inventory.HANDS_SLOT)
	Sfx.play("Cloth", position, 0.25, 1.25)
end

-- Let go of whatever is in their hands: it falls where it is.
function HandsService:Release(player: Player)
	local thing = self.held[player]
	if not thing then
		return nil
	end
	self.held[player] = nil
	thing.holder = nil
	thing.model:SetAttribute("HeldBy", nil)
	if thing.root and thing.root.Parent then
		self:_setGroup(thing, Groups.Prop)
		thing.root:SetNetworkOwner(nil)
	end
	thing.state = "free"
	thing.freeAt = os.clock()
	thing.stillSince = nil
	thing.lastSpeed = nil
	return thing
end

function HandsService:Throw(player: Player, aim: Vector3)
	local thing = self.held[player]
	local head = self.PlayerState:Head(player)
	if not thing or not head or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return
	end
	self:Release(player)
	-- Out of the hand the server thinks it's in, not where the holder's client
	-- had it a moment ago, and never inside a wall.
	local direction = aim.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, thing.model }
	params.CollisionGroup = Groups.Held
	local reach = 2
	local hit = Workspace:Raycast(head.Position, direction * (reach + 0.6), params)
	if hit then
		reach = math.max(0.4, hit.Distance - 0.6)
	end
	local start = head.Position + direction * reach
	thing.model:PivotTo(CFrame.new(start) * thing.root.CFrame.Rotation)
	local root = self.PlayerState:Root(player)
	local carried = root and root.AssemblyLinearVelocity * 0.5 or Vector3.zero
	thing.root.AssemblyLinearVelocity = Throw.velocity(direction, thing.class.throwSpeed, carried)
	thing.root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12
	thing.state = "flying"
	thing.thrower = player
	thing.thrownAt = os.clock()
	thing.lastPos = start
	Sfx.play("Whoosh", start, 0.25, 1.3)
	self.Thrown:Fire(thing, player)
end

-- Every frame: held things stay honest; thrown and dropped things land with a
-- sound, and fall asleep once they lie still.
function HandsService:_tick(dt: number)
	local now = os.clock()
	for player, thing in self.held do
		self:_checkHeld(player, thing, dt)
	end
	local floor = Config.Level.Origin.y - H.FallLimit
	for thing in self.awake do
		local root = thing.root
		if not root or not root.Parent then
			self.awake[thing] = nil
		elseif thing.state ~= "held" then
			local position = root.Position
			local speed = root.AssemblyLinearVelocity.Magnitude
			if thing.state == "flying" then
				self.Moved:Fire(thing, thing.lastPos or position, position)
				thing.lastPos = position
				if now - thing.thrownAt > H.FlightSeconds then
					thing.state = "free"
					thing.freeAt = now
				end
			end
			-- A hard stop from speed: it landed. Nobody's position: a lure.
			if thing.lastSpeed and thing.lastSpeed >= H.ImpactSpeed and speed < thing.lastSpeed * 0.45 then
				local class = thing.class
				Sfx.play(class.sound, position, math.clamp(thing.lastSpeed / 40, 0.25, 1), class.pitch)
				self.Noise:Emit(position, class.noise, nil, "impact")
			end
			thing.lastSpeed = speed
			if position.Y < floor then
				-- Out of the house: back where it was found.
				thing.model:PivotTo(thing.home)
				self:_sleep(thing)
			elseif thing.state == "free" then
				if speed < 0.4 then
					thing.stillSince = thing.stillSince or now
				else
					thing.stillSince = nil
				end
				if
					(thing.stillSince and now - thing.stillSince > H.RestSeconds)
					or now - thing.freeAt > H.RestMaxSeconds
				then
					self:_sleep(thing)
				end
			end
		end
	end
end

-- A held thing near its holder's head, moving like a hand moved it, and not
-- through a wall since last frame. Anything else is put back where it last
-- was and dropped; drifting slowly out of reach (snagged on a door frame as
-- you walk off) just drops it where it is.
function HandsService:_checkHeld(player: Player, thing, dt: number)
	local root = thing.root
	local head = self.PlayerState:Head(player)
	if not root or not root.Parent or not head or not self.PlayerState:CanAct(player) then
		self:Release(player)
		return
	end
	local position = root.Position
	local last = thing.lastValid
	local crossed, jumped = false, false
	if last then
		local delta = position - last.Position
		-- Faster than a hand could move it this frame (velocity can be faked; distance can't).
		jumped = delta.Magnitude > H.CarryMaxSpeed * dt + 1
		if delta.Magnitude > 0.05 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { thing.model, player.Character }
			params.CollisionGroup = Groups.Held
			params.RespectCanCollide = true
			crossed = Workspace:Raycast(last.Position, delta, params) ~= nil
		end
	end
	if crossed or jumped or root.AssemblyLinearVelocity.Magnitude > H.CarryMaxSpeed then
		local telemetry = self.services.Telemetry
		if telemetry then
			telemetry:Log("HeldRejected", { player = player.UserId, crossed = crossed, jumped = jumped })
		end
		self:Release(player)
		root.AssemblyLinearVelocity = Vector3.zero
		thing.model:PivotTo(last or thing.home)
		return
	end
	if (position - head.Position).Magnitude > H.CarryDrop then
		self:Release(player)
		return
	end
	thing.lastValid = root.CFrame
end

return HandsService
