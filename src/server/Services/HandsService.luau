-- Your hands (docs/plans/gameplay-rework.md section 4): what a player's bare
-- hands may take hold of, checked here on the server.
--   * Doors, drawers, cupboard doors and lids, dragged Amnesia-style
--     (Controllers/HandsController streams where the hand wants it; DoorService
--     or FurnitureService moves it, with momentum once you let go).
--   * Small things (Data/Physical: mugs, books, the telephone, chairs...):
--     carried at arm's length and thrown. Each one stays anchored until it's
--     first grabbed, so the house builds the same every time and nothing
--     settles at load. Grabbed, it's welded into one body that the holder's
--     client simulates (network ownership).
--
-- The physics feel pass (R2c; the owner: "unnatural and somewhat laggy,
-- momentum should be improved"):
--   * A thrown or dropped thing stays with the client that held it while it
--     flies and lands, so it leaves the hand exactly as it was moving, with no
--     jump back to a server-side hand. The client launches a throw itself and
--     says how (where from, how fast); this checks it against the class and
--     where the thing really is. Keys, heirlooms and anything else that
--     matters to the escape are taken back on release (they can't be
--     steered), and a player keeps at most OwnedPerPlayer things at once.
--   * Every frame a client-simulated thing is checked: near its holder while
--     held, never faster than its class allows, never through a wall. A stun
--     on The Guest counts only on the throw's first arc (Logic/Throw.onArc),
--     so nothing can be steered into him.
--   * It sleeps (anchored again) once it really lies still: not mid-roll,
--     not in mid-air, and the server takes it back a moment before, so
--     nobody sees it snap.
--
-- Held and thrown things never touch players or The Guest (the Held and Prop
-- collision groups): a throw's hit on him is worked out from the path it flew
-- (Logic/Throw, the Thrown/Moved signals).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Heft = require(Shared.Logic.Heft)
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
	-- (player, thing): someone took hold of a small thing (a key goes on their
	-- ring instead: Services/ItemService).
	Grabbed = Signal.new(),
	-- (thing, thrower): a throw just left someone's hands.
	Thrown = Signal.new(),
	-- (player, thing): it left someone's hands (dropped, thrown, or taken).
	Released = Signal.new(),
	-- (thing, from, to): a thrown thing moved this step (the stun's hit test).
	Moved = Signal.new(),
}

function HandsService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Doors = services.DoorService
	self.Furniture = services.FurnitureService
	self.PlayerState = services.PlayerStateService
	self.Witness = services.WitnessService
	self.Noise = services.NoiseService
	self.Tools = services.ToolService
	self.things = {} -- id -> thing
	self.count = 0
	self.awake = {} -- thing -> true while unanchored
	self.held = {} -- player -> thing
	self.owned = {} -- player -> { things their client still simulates, oldest first }
end

function HandsService:Start()
	Net.onServer("Drag", {
		interval = 1 / 60,
		burst = 60,
		types = { "string", "number" },
	}, function(player, id, value)
		self:_drag(player, id, value, nil)
	end)
	Net.onServer(
		"DragRelease",
		{ interval = 0.05, burst = 10, types = { "string", "number", "number" } },
		function(player, id, value, velocity)
			self:_drag(player, id, value, velocity)
		end
	)
	Net.onServer("Grab", { interval = 0.15, burst = 6, types = { "string" } }, function(player, id)
		self:Grab(player, id)
	end)
	Net.onServer("Release", { interval = 0.1, burst = 8, types = {} }, function(player)
		self:Release(player)
	end)
	Net.onServer(
		"Throw",
		{ interval = 0.3, burst = 3, types = { "Vector3", "number?", "Vector3?", "Vector3?" } },
		function(player, aim, charge, position, velocity)
			self:Throw(player, aim, charge, position, velocity)
		end
	)
	self.World.Built:Connect(function(world)
		self:_register(world)
	end)
	self.World.Cleared:Connect(function()
		table.clear(self.things)
		self.count = 0
		table.clear(self.awake)
		table.clear(self.held)
		table.clear(self.owned)
	end)
	-- Downed, lost, out of the house or gone: whatever was in their hands falls.
	self.PlayerState.StateChanged:Connect(function(player, state)
		if state ~= States.Active then
			self:Release(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
		for _, thing in self.owned[player] or {} do
			self:_reclaim(thing)
		end
		self.owned[player] = nil
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

-- `release` (a velocity) is the hand letting go.
function HandsService:_drag(player: Player, id: string, value: number, release: number?)
	local world = self.World.World
	if not world or not self.PlayerState:CanAct(player) then
		return
	end
	-- The client lets go beyond DragReach + 1 from your eye; a little more here
	-- for the slab's middle and the network.
	local reach = H.DragReach + 1.5
	local door = world.doors[id]
	if door and door.slab.Parent then
		if self:_canReach(player, door.slab.Position, reach, door.model) then
			self.Doors:Drag(door, value, player, release)
		end
		return
	end
	local piece = self.Furniture:Piece(id)
	if piece and piece.primary.Parent then
		if self:_canReach(player, piece.primary.Position, reach, piece.prop.model) then
			self.Furniture:Drag(piece, value, player, release)
		end
	end
end

-- Small things ----------------------------------------------------------------

-- Make a small thing something your hand can find and carry: an id, queries
-- on (it still doesn't collide while it sleeps), the class and label on the
-- model for the client. FurnitureService adds what it finds in drawers.
function HandsService:AddThing(model: Model, info)
	if model:GetAttribute("Grab") then
		return nil
	end
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = true
			table.insert(parts, p)
		end
	end
	if #parts == 0 or not Physical.Classes[info.class] then
		return nil
	end
	self.count += 1
	local id = "thing:" .. self.count
	model:SetAttribute("Grab", id)
	model:SetAttribute("Label", info.label)
	model:SetAttribute("Class", info.class)
	CollectionService:AddTag(model, Constants.Tags.Grabbable)
	local thing = {
		id = id,
		model = model,
		parts = parts,
		class = Physical.Classes[info.class],
		home = model:GetPivot(),
		state = "rest",
	}
	self.things[id] = thing
	return thing
end

-- Every small thing in the new house.
function HandsService:_register(world)
	-- The house's own furniture by kind (not a clue built like a chair).
	for _, prop in world.props or {} do
		local info = Physical.Furniture[prop.kind]
		if info and info.class and prop.model.Parent then
			self:AddThing(prop.model, info)
		end
	end
	for _, d in self.World.folder:GetDescendants() do
		local info = d:IsA("Model") and Physical.Dressing[d.Name]
		if info then
			self:AddThing(d, info)
		end
	end
	world.things = self.things
end

-- The root a thing is welded to: its biggest part. Controllers/HandsController
-- picks the same one, so its hold takes effect the moment it's handed over.
function HandsService.rootOf(parts: { BasePart }): BasePart?
	local root, best = nil, -1
	for _, p in parts do
		local volume = p.Size.X * p.Size.Y * p.Size.Z
		if volume > best then
			root, best = p, volume
		end
	end
	return root
end

-- The first time it's grabbed: one welded body, heavy as its class.
function HandsService:_prepare(thing)
	if thing.root then
		return
	end
	local root = HandsService.rootOf(thing.parts)
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
	-- Out of its drawer or cupboard for good (FurnitureService).
	thing.rides = nil
	thing.inside = nil
	thing.model:SetAttribute("RidesOn", nil)
	thing.model:SetAttribute("RideOffset", nil)
	for _, p in thing.parts do
		p.Anchored = false
	end
	self.awake[thing] = true
end

-- Take a thing back from whichever client simulates it.
function HandsService:_reclaim(thing)
	local owner = thing.owner
	thing.owner = nil
	if owner then
		local list = self.owned[owner]
		local at = list and table.find(list, thing)
		if at then
			table.remove(list, at)
		end
	end
	if thing.root and thing.root.Parent and not thing.root.Anchored then
		thing.root:SetNetworkOwner(nil)
	end
end

function HandsService:_sleep(thing)
	self:_reclaim(thing)
	self.awake[thing] = nil
	thing.state = "rest"
	thing.thrower = nil
	thing.launch = nil
	thing.settleAt = nil
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
	self:_reclaim(thing)
	self:_wake(thing)
	self:_setGroup(thing, Groups.Held)
	thing.root:SetNetworkOwner(player)
	local now = os.clock()
	thing.state = "held"
	thing.holder = player
	thing.thrower = nil
	thing.launch = nil
	thing.settleAt = nil
	thing.grabbedAt = now
	thing.lastValid = thing.root.CFrame
	thing.lastValidAt = now
	self.held[player] = thing
	thing.model:SetAttribute("HeldBy", player.UserId)
	-- Taking hold of something puts your hands in your hands (slot 4).
	self.Tools:SelectSlot(player, Inventory.HANDS_SLOT)
	Sfx.play("Cloth", position, 0.25, 1.25)
	self.Grabbed:Fire(player, thing)
end

-- A thing leaves the house's physics for good (a key put on a ring, an
-- heirloom set at the table): out of anyone's hands, no longer tracked.
function HandsService:Forget(thing, destroy: boolean?)
	if thing.holder then
		self:Release(thing.holder)
	end
	self:_reclaim(thing)
	self.things[thing.id] = nil
	self.awake[thing] = nil
	thing.state = "gone"
	CollectionService:RemoveTag(thing.model, Constants.Tags.Grabbable)
	thing.model:SetAttribute("Grab", nil)
	if destroy then
		thing.model:Destroy()
	end
end

-- Things the escape needs (a key, an heirloom, the music box) are never left
-- for a client to fly: the server takes them back as they leave your hands.
local function precious(thing): boolean
	return thing.model:GetAttribute("Item") ~= nil or thing.model:GetAttribute("Precious") == true
end

-- Leave a just-released thing with its holder's client (smooth for them),
-- unless it's precious or they already fly too many.
function HandsService:_keepOwner(player: Player, thing): boolean
	if precious(thing) or not player.Parent then
		return false
	end
	local list = self.owned[player] or {}
	self.owned[player] = list
	while #list >= H.OwnedPerPlayer do
		self:_reclaim(list[1])
	end
	table.insert(list, thing)
	thing.owner = player
	return true
end

-- Let go of whatever is in their hands: it carries on as it was moving.
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
		if not self:_keepOwner(player, thing) then
			thing.root:SetNetworkOwner(nil)
		end
	end
	thing.state = "free"
	thing.freeAt = os.clock()
	thing.stillSince = nil
	thing.lastSpeed = nil
	thing.lastPos = thing.root and thing.root.Position
	self.Released:Fire(player, thing)
	return thing
end

-- A throw. The holder's client launched it already (from where it was in
-- their hands, at `velocity`); this checks that launch against the class and
-- where the thing really is. A client that says nothing (older, or a touch
-- tap) gets a throw from the thing's own position along `aim`.
function HandsService:Throw(player: Player, aim: Vector3, charge: number?, position: Vector3?, velocity: Vector3?)
	local thing = self.held[player]
	local head = self.PlayerState:Head(player)
	if not thing or not head or not thing.root or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return
	end
	local class = thing.class
	local root = thing.root
	local body = self.PlayerState:Root(player)
	local holderVelocity = body and body.AssemblyLinearVelocity or Vector3.zero
	local power = math.clamp(charge or 1, H.ChargeLow, 1)
	-- The fastest an honest throw of this thing can leave the hand.
	local cap = class.throwSpeed + holderVelocity.Magnitude * H.ThrowCarry + class.carry.maxSpeed * H.ThrowCarry + 5
	local launch = velocity
	-- The client's own launch stands only if it's one an honest throw could be.
	local clientLaunched = typeof(launch) == "Vector3" and launch.Magnitude <= cap
	if not clientLaunched then
		launch = Throw.velocity(aim, class.throwSpeed * power, holderVelocity * H.ThrowCarry)
			+ Vector3.new(0, class.throwSpeed * power * H.ThrowLift, 0)
	end
	-- Where it leaves from: where the thing is, if the client's word agrees
	-- with it and nothing solid lies between it and the thrower's head.
	local from = root.Position
	if typeof(position) == "Vector3" and (position - from).Magnitude < 3 then
		from = position
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, thing.model }
	params.CollisionGroup = Groups.Held
	params.RespectCanCollide = true
	local blocked = Workspace:Raycast(head.Position, from - head.Position, params)
	if blocked or (from - head.Position).Magnitude > H.CarryDrop then
		-- Somewhere it can't be thrown from: out of the head instead.
		local direction = aim.Unit
		local reach = 2
		local hit = Workspace:Raycast(head.Position, direction * (reach + 0.6), params)
		if hit then
			reach = math.max(0.4, hit.Distance - 0.6)
		end
		from = head.Position + direction * reach
		thing.model:PivotTo(CFrame.new(from) * root.CFrame.Rotation)
	end
	self:Release(player)
	if thing.owner and not clientLaunched then
		self:_reclaim(thing)
	end
	if not thing.owner then
		-- The server flies it (precious, or the client's say wasn't used).
		root.AssemblyLinearVelocity = launch
		local spin = aim.Unit:Cross(Vector3.yAxis)
		root.AssemblyAngularVelocity = spin * (6 / class.density)
	end
	thing.state = "flying"
	thing.thrower = player
	thing.thrownAt = os.clock()
	thing.lastPos = from
	thing.launch = { from = from, velocity = launch, at = os.clock() }
	thing.bounced = false
	Sfx.play("Whoosh", from, 0.25 + 0.15 * power, 1.3)
	self.Thrown:Fire(thing, player)
end

-- Is this point on the thing's first arc (a stun may count)?
function HandsService:OnArc(thing, at: Vector3): boolean
	local launch = thing.launch
	if not launch or thing.bounced then
		return false
	end
	local t = os.clock() - launch.at
	return Throw.onArc(launch.from, launch.velocity, Vector3.new(0, -Workspace.Gravity, 0), t, at, H)
end

-- It hit him: the server takes it back to bounce it off (a velocity set on a
-- client-simulated part would be ignored).
function HandsService:BounceOff(thing)
	self:_reclaim(thing)
	thing.bounced = true
	if thing.root and thing.root.Parent then
		thing.root.AssemblyLinearVelocity *= -0.3
	end
end

-- Every frame: held things stay honest; thrown and dropped things land with a
-- sound, and fall asleep once they lie still.
function HandsService:_tick(_dt: number)
	local now = os.clock()
	for player, thing in self.held do
		self:_checkHeld(player, thing, now)
	end
	local floor = Config.Level.Origin.y - H.FallLimit
	for thing in self.awake do
		local root = thing.root
		if not root or not root.Parent then
			self.awake[thing] = nil
		elseif thing.state ~= "held" then
			local position = root.Position
			local speed = root.AssemblyLinearVelocity.Magnitude
			if thing.owner and not self:_checkFlying(thing, position, speed) then
				continue
			end
			if thing.state == "flying" then
				self.Moved:Fire(thing, thing.lastPos or position, position)
				if now - thing.thrownAt > H.FlightSeconds then
					thing.state = "free"
					thing.freeAt = now
				end
			end
			thing.lastPos = position
			-- A hard stop from speed: it landed. Nobody's position: a lure.
			if thing.lastSpeed and thing.lastSpeed >= H.ImpactSpeed and speed < thing.lastSpeed * 0.45 then
				local class = thing.class
				thing.bounced = true
				Sfx.play(class.sound, position, math.clamp(thing.lastSpeed / 40, 0.25, 1), class.pitch)
				self.Noise:Emit(position, class.noise, nil, "impact")
			end
			thing.lastSpeed = speed
			if position.Y < floor then
				-- Out of the house: back where it was found.
				self:_reclaim(thing)
				thing.model:PivotTo(thing.home)
				self:_sleep(thing)
			elseif thing.state == "free" then
				self:_settle(thing, now, speed)
			end
		end
	end
end

-- Lying still (not rolling, not spinning, not falling) for RestSeconds: the
-- server takes it back, then a moment later anchors it where it lies.
function HandsService:_settle(thing, now: number, speed: number)
	local root = thing.root
	if thing.settleAt then
		if now >= thing.settleAt then
			self:_sleep(thing)
		end
		return
	end
	local spin = root.AssemblyAngularVelocity.Magnitude
	local still = speed < 0.4 and spin < H.RestSpin
	if still then
		thing.stillSince = thing.stillSince or now
	else
		thing.stillSince = nil
	end
	local free = now - thing.freeAt
	local rested = thing.stillSince and now - thing.stillSince > H.RestSeconds
	-- After RestMaxSeconds it sleeps once it's slow and on something; after
	-- the hard limit, whatever it's doing.
	local slowEnough = free > H.RestMaxSeconds and speed < 2 and self:_grounded(thing)
	if rested or slowEnough or free > H.RestHardMaxSeconds then
		self:_reclaim(thing)
		thing.settleAt = now + H.SettleSeconds
	end
end

-- Is there something under it?
function HandsService:_grounded(thing): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { thing.model }
	params.CollisionGroup = Groups.Prop
	params.RespectCanCollide = true
	return Workspace:Raycast(thing.root.Position, Vector3.new(0, -1.5 - thing.root.Size.Magnitude / 2, 0), params)
		~= nil
end

-- A thing a client flies after letting go: never faster than its throw
-- allows, never through a wall. False when it was taken back.
function HandsService:_checkFlying(thing, position: Vector3, speed: number): boolean
	local cap = thing.class.throwSpeed * H.FlightSpeedScale + H.CarrySpeedMargin
	local last = thing.lastPos
	local crossed = false
	if last and (position - last).Magnitude > 0.05 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { thing.model }
		params.CollisionGroup = Groups.Prop
		params.RespectCanCollide = true
		-- Through, not just touching: grazing the table it lands on leaves it
		-- on the near side of the surface; passing through a wall doesn't.
		local hit = Workspace:Raycast(last, position - last, params)
		local depth = math.min(thing.root.Size.X, thing.root.Size.Y, thing.root.Size.Z) / 2 + 0.25
		crossed = hit ~= nil and (position - hit.Position):Dot(hit.Normal) < -depth
	end
	if speed <= cap and not crossed then
		return true
	end
	local telemetry = self.services.Telemetry
	if telemetry then
		telemetry:Log("ThrowRejected", { owner = thing.owner and thing.owner.UserId, crossed = crossed, speed = speed })
	end
	self:_reclaim(thing)
	thing.bounced = true
	thing.root.AssemblyLinearVelocity = Vector3.zero
	if crossed and last then
		thing.model:PivotTo(CFrame.new(last) * thing.root.CFrame.Rotation)
	end
	thing.lastPos = thing.root.Position
	return false
end

-- A held thing near its holder's head, moving like a hand moved it, and not
-- through a wall. Replication arrives in bursts, so movement is judged over
-- the time since the last sample that actually moved. Through a wall: put
-- back where it last was and dropped. Too fast: dropped where it is.
-- Drifting out of reach (snagged on a door frame as you walk off): dropped.
function HandsService:_checkHeld(player: Player, thing, now: number)
	local root = thing.root
	local head = self.PlayerState:Head(player)
	if not root or not root.Parent or not head or not self.PlayerState:CanAct(player) then
		self:Release(player)
		return
	end
	local position = root.Position
	local last = thing.lastValid
	local body = self.PlayerState:Root(player)
	local holderSpeed = body and body.AssemblyLinearVelocity.Magnitude or 0
	local cap = Heft.speedCap(thing.class.carry.maxSpeed, holderSpeed, H.CarrySpeedMargin)
	local crossed, jumped = false, false
	if last then
		local delta = position - last.Position
		if delta.Magnitude > 0.05 then
			local elapsed = math.max(now - (thing.lastValidAt or now), 1 / 60)
			jumped = delta.Magnitude > cap * elapsed + 2
			if now - (thing.grabbedAt or 0) > H.GrabGraceSeconds then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { thing.model, player.Character }
				params.CollisionGroup = Groups.Held
				params.RespectCanCollide = true
				-- Through a wall, not brushing past a table: it must end up
				-- beyond the surface it met.
				local hit = Workspace:Raycast(last.Position, delta, params)
				local depth = math.min(root.Size.X, root.Size.Y, root.Size.Z) / 2 + 0.25
				crossed = hit ~= nil and (position - hit.Position):Dot(hit.Normal) < -depth
			end
		end
	end
	if crossed or jumped or root.AssemblyLinearVelocity.Magnitude > cap then
		local telemetry = self.services.Telemetry
		if telemetry then
			telemetry:Log("HeldRejected", { player = player.UserId, crossed = crossed, jumped = jumped })
		end
		self.held[player] = nil
		thing.holder = nil
		thing.model:SetAttribute("HeldBy", nil)
		self:_setGroup(thing, Groups.Prop)
		root:SetNetworkOwner(nil)
		root.AssemblyLinearVelocity = Vector3.zero
		if crossed then
			thing.model:PivotTo(last or thing.home)
		end
		thing.state = "free"
		thing.freeAt = now
		thing.stillSince = nil
		thing.lastSpeed = nil
		thing.lastPos = root.Position
		self.Released:Fire(player, thing)
		return
	end
	if (position - head.Position).Magnitude > H.CarryDrop then
		self:Release(player)
		return
	end
	if not last or (position - last.Position).Magnitude > 0.05 then
		thing.lastValid = root.CFrame
		thing.lastValidAt = now
	end
end

return HandsService
