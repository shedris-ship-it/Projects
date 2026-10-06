-- The house's own scares (the owner's audit of 2026-10-06, Findings 2, 7 and
-- 8; docs/plans/gameplay-rework.md section 10, "house events"): authored
-- beats the Director's deck draws by act and Dread (Stalker/Director CARDS
-- with `house = true`), and the change a squad finds when it comes back to a
-- wing it left a while ago. Never something to solve and never a leak: each
-- is a sound or a change in a room nobody is watching, and every noise is
-- one he hears too (a lure), so the house and its guest keep the same rules.
--
--   radioOn      a radio in an empty room near you turns itself on
--   phoneRings   the hall telephone rings; answer it and something breathes
--   lightsDie    the rooms ahead of you go dark one by one, for a while
--   overhead     his footsteps through the floor, when he really is above
--                or below you (honest: where he is, not a phantom)
--   doorAjar     a shut door in the next room swings ajar, unseen
--   knockInside  three knocks from inside a wardrobe or locker nearby
--   clockStrikes the grandfather clock strikes thirteen (once a run, act 3)
--   returnChanged (not a card) coming back to a wing after a while: a door
--                has moved and a room has gone dark

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Interactables = require(Shared.Data.Interactables)
local Sfx = require(Shared.Lib.Sfx)

local Dressing = require(script.Parent.Parent.World.Dressing)

local E = Config.HouseEvents

local HouseEventService = {}

function HouseEventService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.active = false
end

function HouseEventService:Start()
	local services = self.services
	services.WorldService.Cleared:Connect(function()
		self.active = false
		self.phones = nil
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not self.active then
			return
		end
		accumulator += dt
		if accumulator >= 1 then
			accumulator = 0
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[Consensus] house events failed: " .. tostring(err))
			end
		end
	end)
end

function HouseEventService:Begin(rng)
	self.rng = rng
	self.lastIn = {} -- region -> when a player was last in it
	self.regionOf = {} -- player -> the region they were in last tick
	self.changedAt = {} -- region -> when it last changed behind their backs
	self.darkened = {} -- room id -> true while an event keeps it dark
	self.ringing = nil
	self.struck = false
	self.phones = nil
	self.active = true
	self:_ensureTelephone(rng)
end

-- A 1988 mansion has a telephone in the hall. The dressing places one by
-- chance on a hall-like top (World/Dressing); when it placed none, one goes
-- on a free top in the hall or a corridor, so the phone can ring in every
-- house.
function HouseEventService:_ensureTelephone(rng)
	if #self:_telephones() > 0 then
		return
	end
	local world = self.World.World
	if not world then
		return
	end
	-- The hall and the corridors first, then any room with a free top (a
	-- phone in the study or the kitchen is as 1988 as one in the hall).
	local first, rest = {}, {}
	for _, room in world.layout.rooms do
		local record = world.rooms[room.id]
		local role = record and (record.role or room.role)
		if record and (role == "start" or (record.template and record.template.family == "corridor")) then
			table.insert(first, room.id)
		elseif record and record.template and record.template.family ~= "utility" then
			table.insert(rest, room.id)
		end
	end
	table.sort(rest)
	for _, id in rest do
		table.insert(first, id)
	end
	for _, roomId in first do
		local record = world.rooms[roomId]
		local cf = self.services.ItemService:TopSpot(roomId, rng)
		if cf and record and record.model then
			Dressing.telephone(record.model, cf)
			self.phones = nil
			return
		end
	end
end

-- Helpers ----------------------------------------------------------------------------

function HouseEventService:_playersIn(): { [number]: number }
	local count = {}
	local ps = self.services.PlayerStateService
	for _, player in ps:LivingPlayers() do
		local pos = ps:Position(player)
		local room = pos and self.World:RoomAt(pos)
		if room then
			count[room] = (count[room] or 0) + 1
		end
	end
	return count
end

-- Nobody is looking that way (so a change there is only ever found).
function HouseEventService:_unseen(position: Vector3): boolean
	local stalker = self.services.StalkerService
	if stalker.perception and stalker.active then
		-- (About a first-person view's width: a door off to the side may move.)
		return not stalker.perception:AnyoneLookingAt(position, 80)
	end
	return true
end

function HouseEventService:_telephones()
	if self.phones then
		return self.phones
	end
	local phones = {}
	local folder = self.World.folder
	if folder then
		for _, model in folder:GetDescendants() do
			if model:IsA("Model") and model.Name == "Telephone" then
				local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				if part then
					table.insert(phones, { model = model, part = part, position = model:GetBoundingBox().Position })
				end
			end
		end
	end
	self.phones = phones
	return phones
end

-- A looping sound from a part, heard by every client (the SoundLoop tag,
-- Controllers/AudioController), or stopped.
local function loop(part: BasePart, key: string?, volume: number?, range: number?)
	if key then
		part:SetAttribute("LoopVolume", volume or 0.6)
		part:SetAttribute("LoopPitch", 1)
		part:SetAttribute("LoopRange", range or 60)
		part:SetAttribute("Loop", key)
		CollectionService:AddTag(part, Constants.Tags.SoundLoop)
	else
		part:SetAttribute("Loop", nil)
	end
end

-- The events ---------------------------------------------------------------------------

-- A radio in an empty room near `pos` turns itself on, and off again later.
function HouseEventService:_radioOn(pos: Vector3): boolean
	local interact = self.services.InteractService
	local inRoom = self:_playersIn()
	local best, bestDistance = nil, E.RadioRange
	for _, fixture in interact.fixtures or {} do
		if fixture.info == Interactables.Radio and not fixture.running and fixture.part.Parent then
			local room = self.World:RoomAt(fixture.position)
			local d = (fixture.position - pos).Magnitude
			if room and not inRoom[room] and d < bestDistance then
				best, bestDistance = fixture, d
			end
		end
	end
	if not best then
		return false
	end
	interact:Use(best)
	task.delay(E.RadioSeconds, function()
		if best.running and best.part.Parent then
			interact:_stop(best)
		end
	end)
	return true
end

-- The telephone rings. Answer it (E) and something breathes on the line; he
-- hears the ring, and he hears you pick up.
function HouseEventService:_phoneRings(pos: Vector3): boolean
	if self.ringing then
		return false
	end
	local inRoom = self:_playersIn()
	local best, bestDistance = nil, math.huge
	for _, phone in self:_telephones() do
		if phone.part.Parent then
			local room = self.World:RoomAt(phone.position)
			local d = (phone.position - pos).Magnitude
			-- Prefer a phone in a room nobody is in, within earshot.
			if room and not inRoom[room] then
				d -= 30
			end
			if d < bestDistance then
				best, bestDistance = phone, d
			end
		end
	end
	if not best or (best.position - pos).Magnitude > E.PhoneRange then
		return false
	end
	local services = self.services
	local phone = best
	self.ringing = phone
	loop(phone.part, "PhoneRing", 0.7, E.PhoneLure * 2)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AnswerPrompt"
	prompt.ActionText = "Answer"
	prompt.ObjectText = "Telephone"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = phone.part
	local answered = false
	local function stop()
		if self.ringing == phone then
			self.ringing = nil
		end
		loop(phone.part, nil)
		prompt:Destroy()
	end
	prompt.Triggered:Connect(function(player)
		if answered or not services.PlayerStateService:CanAct(player) then
			return
		end
		answered = true
		stop()
		-- He heard you pick up: your position, from the receiver, and you're told so.
		services.NoiseService:Emit(phone.position, E.PhoneLure, player, "lure")
		services.StalkerService:HeardYou(player, phone.position)
		services.DivergenceService:Scare(player, { kind = "phone", position = phone.position })
		services.RunLogService:Beat("phoneAnswered", player.DisplayName)
		services.Telemetry:Log("PhoneAnswered", {}, player)
	end)
	task.spawn(function()
		local rings = math.floor(E.PhoneSeconds / 3)
		for _ = 1, rings do
			if answered or self.ringing ~= phone or not phone.part.Parent then
				break
			end
			services.NoiseService:Emit(phone.position, E.PhoneLure, nil, "lure")
			task.wait(3)
		end
		if not answered then
			stop()
		end
	end)
	return true
end

-- The rooms ahead of you go dark one by one: the room you're heading for
-- and the ones past it, never the one you stand in, corridors first.
function HouseEventService:_lightsDie(pos: Vector3): boolean
	local world = self.World.World
	local here = self.World:RoomAt(pos)
	if not here or not world then
		return false
	end
	local inRoom = self:_playersIn()
	local chosen, seen = {}, { [here] = true }
	local frontier = { here }
	while #frontier > 0 and #chosen < E.LightsRooms do
		local next = {}
		local candidates = {}
		for _, id in frontier do
			for _, n in self.World:Neighbours(id) do
				if not seen[n] then
					seen[n] = true
					table.insert(candidates, n)
					table.insert(next, n)
				end
			end
		end
		-- Corridors first, then by id (so the choice is the same every time).
		table.sort(candidates, function(a, b)
			local ca, cb = world.rooms[a].corridor ~= nil, world.rooms[b].corridor ~= nil
			if ca ~= cb then
				return ca
			end
			return a < b
		end)
		for _, id in candidates do
			local room = world.rooms[id]
			if #chosen < E.LightsRooms and room.light and room.lightOn and not inRoom[id] and not self.darkened[id] then
				table.insert(chosen, id)
			end
		end
		frontier = next
	end
	if #chosen < 2 then
		return false
	end
	for i, id in chosen do
		self.darkened[id] = true
		task.delay((i - 1) * E.LightsStep, function()
			if self.active and self.World.World == world then
				self.World:SetLightCause(id, "event", true)
				local room = world.rooms[id]
				Sfx.play("FlashlightClick", room.center + Vector3.new(0, 8, 0), 0.5, 0.6)
			end
		end)
		task.delay(E.LightsDark + i * E.LightsStep, function()
			self.darkened[id] = nil
			if self.World.World == world then
				self.World:SetLightCause(id, "event", false)
			end
		end)
	end
	return true
end

-- His footsteps through the floor, for a player he is above or below right
-- now: where he really is, so the sound is a true tell.
function HouseEventService:_overhead(): boolean
	local services = self.services
	local guest = services.StalkerService:GetPosition()
	if not guest then
		return false
	end
	local guestFloor = self.World.FloorAt(guest.Y - Config.Level.Origin.y)
	local ps = services.PlayerStateService
	local best, bestDistance = nil, E.OverheadRange
	for _, player in ps:LivingPlayers() do
		local pos = ps:Position(player)
		if pos then
			local floor = self.World.FloorAt(pos.Y - Config.Level.Origin.y)
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(guest.X, 0, guest.Z)).Magnitude
			if floor ~= guestFloor and d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	if not best then
		return false
	end
	local pos = ps:Position(best)
	local below = guest.Y < pos.Y
	services.DivergenceService:Scare(best, { kind = "overhead", position = guest, below = below })
	return true
end

-- A shut door in the next room swings ajar while nobody is looking.
function HouseEventService:_doorAjar(pos: Vector3): boolean
	local world = self.World.World
	local here = self.World:RoomAt(pos)
	if not here or not world then
		return false
	end
	local near = { [here] = true }
	for _, n in self.World:Neighbours(here) do
		near[n] = true
	end
	local candidates = {}
	for _, door in world.doors do
		local touches = near[door.a] or near[door.b]
		if touches and not door.open and not door.locked and door.state and not door.state.holder then
			local d = (door.position - pos).Magnitude
			if d > 8 and d < 45 and math.abs(door.position.Y - pos.Y) < 6 and self:_unseen(door.position) then
				table.insert(candidates, door)
			end
		end
	end
	if #candidates == 0 then
		return false
	end
	table.sort(candidates, function(a, b)
		return a.position.X < b.position.X or (a.position.X == b.position.X and a.position.Z < b.position.Z)
	end)
	local door = self.rng:Pick(candidates)
	self.services.DoorService:SetAngle(door, E.AjarDegrees)
	Sfx.play("DoorOpen", door.position, 0.35, 0.8)
	return true
end

-- Three knocks from inside a wardrobe or locker nearby, with nobody in it.
function HouseEventService:_knockInside(pos: Vector3): boolean
	local world = self.World.World
	local here = self.World:RoomAt(pos)
	if not here or not world then
		return false
	end
	local near = { [here] = true }
	for _, n in self.World:Neighbours(here) do
		near[n] = true
	end
	local hiding = self.services.HidingService
	local candidates = {}
	for _, spot in world.hidingSpots do
		local anchor = spot.anchor
		if
			anchor
			and near[spot.roomId]
			and (spot.category == "wardrobe" or spot.category == "locker" or spot.category == "closet")
		then
			local d = (anchor.Position - pos).Magnitude
			if d > 6 and d < 40 and not (hiding.Occupied and hiding:Occupied(spot)) then
				table.insert(candidates, spot)
			end
		end
	end
	if #candidates == 0 then
		return false
	end
	table.sort(candidates, function(a, b)
		return a.id < b.id
	end)
	local spot = self.rng:Pick(candidates)
	local at = spot.anchor.Position
	task.spawn(function()
		for _ = 1, 3 do
			Sfx.play("Knock", at, 0.8, 0.9)
			task.wait(0.45)
		end
	end)
	self.services.NoiseService:Emit(at, 20, nil, "lure")
	return true
end

-- The grandfather clock strikes thirteen. Once a run.
function HouseEventService:_clockStrikes(): boolean
	if self.struck then
		return false
	end
	local world = self.World.World
	local clock
	for _, prop in world and world.props or {} do
		if prop.kind == "GrandfatherClock" and prop.model.Parent then
			clock = prop
			break
		end
	end
	if not clock then
		return false
	end
	self.struck = true
	local at = clock.model:GetBoundingBox().Position
	local services = self.services
	task.spawn(function()
		for i = 1, 13 do
			if not clock.model.Parent then
				break
			end
			Sfx.play("ClockChime", at, 0.8, 1)
			if i == 13 then
				for _, player in services.PlayerStateService:RunPlayers() do
					services.DivergenceService:Scare(
						player,
						{ kind = "caption", text = "[the clock strikes thirteen]" }
					)
				end
			end
			task.wait(E.ChimeGap)
		end
	end)
	services.NoiseService:Emit(at, 40, nil, "lure")
	return true
end

-- The Director drew a house card (Stalker/Director). Returns whether it
-- could be played here and now.
local HANDLERS = {
	radioon = "_radioOn",
	phonerings = "_phoneRings",
	lightsdie = "_lightsDie",
	overhead = "_overhead",
	doorajar = "_doorAjar",
	knockinside = "_knockInside",
	clockstrikes = "_clockStrikes",
}

function HouseEventService:Play(id: string, _victim: Player?, pos: Vector3?): boolean
	if not self.active or not pos then
		return false
	end
	-- (F2 lowercases its words, so ids match either way.)
	local handler = HANDLERS[string.lower(id)]
	if not handler then
		return false
	end
	return self[handler](self, pos)
end

-- Coming back to an old wing ---------------------------------------------------------

-- Once a second: who is in which region. Someone stepping back into a wing
-- the squad left a while ago finds it changed (docs/plans/level-design.md
-- section 3, part 6: "make going back dramatic").
function HouseEventService:_tick()
	local services = self.services
	local locks = services.LockService
	local plan = locks and locks.plan
	if not plan or not plan.roomRegion then
		return
	end
	local now = os.clock()
	local ps = services.PlayerStateService
	local present = {}
	for _, player in ps:LivingPlayers() do
		local pos = ps:Position(player)
		local room = pos and self.World:RoomAt(pos)
		local region = room and plan.roomRegion[room]
		if region then
			present[region] = true
			local before = self.regionOf[player]
			if before ~= region then
				self.regionOf[player] = region
				local away = self.lastIn[region] and now - self.lastIn[region] or 0
				local cooled = now - (self.changedAt[region] or -math.huge) >= E.ReturnCooldown
				if before ~= nil and away >= E.ReturnAfter and cooled and region ~= 0 then
					self.changedAt[region] = now
					self:_returnChanged(region, player, room)
				end
			end
		end
	end
	for region in present do
		self.lastIn[region] = now
	end
end

-- Somewhere in the wing nobody can see: a door that was shut stands open (or
-- one that was open is shut), and a room has gone dark.
function HouseEventService:_returnChanged(region: number, player: Player, enteredRoom: number)
	local services = self.services
	local world = self.World.World
	local plan = services.LockService.plan
	local rooms = plan.regions[region] and plan.regions[region].rooms or {}
	local inRoom = self:_playersIn()
	local inRegion = {}
	for _, id in rooms do
		inRegion[id] = true
	end
	local changed = 0
	-- A door inside the wing, unseen, not the one they just came through.
	local doors = {}
	for _, door in world.doors do
		if
			inRegion[door.a]
			and inRegion[door.b]
			and not door.locked
			and door.state
			and not door.state.holder
			and door.a ~= enteredRoom
			and door.b ~= enteredRoom
			and self:_unseen(door.position)
		then
			table.insert(doors, door)
		end
	end
	table.sort(doors, function(a, b)
		return a.position.X < b.position.X or (a.position.X == b.position.X and a.position.Z < b.position.Z)
	end)
	if #doors > 0 then
		local door = self.rng:Pick(doors)
		if door.open then
			services.DoorService:SetOpen(door, false, nil, false)
		else
			services.DoorService:SetAngle(door, Config.Doors.OpenAngle * 0.7)
		end
		changed += 1
	end
	-- A room of the wing nobody is in goes dark for a while.
	local dark = {}
	for _, id in rooms do
		local room = world.rooms[id]
		if room and room.light and room.lightOn and not inRoom[id] and not self.darkened[id] and id ~= enteredRoom then
			table.insert(dark, id)
		end
	end
	table.sort(dark)
	if #dark > 0 then
		local id = self.rng:Pick(dark)
		self.darkened[id] = true
		self.World:SetLightCause(id, "event", true)
		task.delay(E.ReturnDark, function()
			self.darkened[id] = nil
			if self.World.World == world then
				self.World:SetLightCause(id, "event", false)
			end
		end)
		changed += 1
	end
	if changed > 0 then
		services.RunLogService:Scare("returnChanged")
		services.Telemetry:Log("ReturnChanged", { region = region, changes = changed }, player)
	end
end

return HouseEventService
