-- Locked doors in the escape (docs/plans/gameplay-rework.md section 5): the
-- plan (Logic/LockPlanner, `layout.progression`) says which doorways are
-- locked and what opens them. This locks those doors and keeps every key a
-- player holds on their own ring.
--
--   * A gate opens with its key (on the opener's ring) or its padlock's code
--     (Services/PuzzleService runs the padlock).
--   * A bolt is a shortcut: it slides back from its own side only. From the
--     other side it won't move.
--   * A locked door is a wall to everyone, The Guest too (WorldService:
--     SeamCost), so a chase stays in the part of the house the squad can
--     reach, and he only ever arrives there (StalkerService asks Reachable).
--
-- Trying a locked door rattles it and says why; that's also how the squad
-- learns where the locks are (the objective line reads `Seen`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)

local PA = Constants.PlayerAttributes

local LockService = {
	-- (seamId, lock, player?): a lock came open.
	Unlocked = Signal.new(),
	-- (seamId, lock, player): someone tried a locked door.
	Tried = Signal.new(),
	-- (region, player, rooms): the first step anyone takes into a part of
	-- the house that was locked away (a set of its room ids). Progress: it
	-- calms Drift and wakes a hunt (Stalker/Director).
	RegionEntered = Signal.new(),
}

function LockService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Doors = services.DoorService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.plan = nil
	self.locks = {} -- seam id -> { lock, door, seam, open, plate }
	self.rings = {} -- player -> { [token id] = label }
	self.seen = {} -- seam id -> true once someone has tried it
	self.reach = {} -- room id -> true while the squad can get there
	self.entered = {} -- region -> true once someone has walked in
	self.quiet = false -- every lock opened at once (the dinner, F2): entering no longer counts
end

function LockService:Start()
	self.Doors.LockHandler = function(door, player)
		self:_try(door, player)
	end
	self.World.Cleared:Connect(function()
		self:_clear()
	end)
	Net.onServer("DropKey", { interval = 0.3, burst = 3, types = { "string" } }, function(player, token)
		self:DropKey(player, token)
	end)
	self.PlayerState.StateChanged:Connect(function(player, state)
		-- Downed, Lost or gone: the keys fall where they are (ItemService).
		if state ~= Constants.PlayerStates.Active and self.rings[player] and next(self.rings[player]) then
			local items = self.services.ItemService
			if items then
				items:DropKeys(player, self:TakeRing(player))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local items = self.services.ItemService
		if items and self.rings[player] and next(self.rings[player]) then
			items:DropKeys(player, self:TakeRing(player))
		end
		self.rings[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			if self.plan then
				self:_updateReach()
			end
			self:_checkRegions()
		end
	end)
end

-- Has anyone just stepped into a part of the house that was locked away?
function LockService:_checkRegions()
	local plan = self.plan
	if not plan or self.quiet then
		return
	end
	local finale = self.services.FinaleService
	if finale and finale.served then
		return
	end
	for _, player in self.PlayerState:ActivePlayers() do
		local position = self.PlayerState:Position(player)
		local room = position and self.World:RoomAt(position)
		local region = room and plan.roomRegion[room]
		if region and region ~= 0 and not self.entered[region] then
			self.entered[region] = true
			local rooms = {}
			for _, id in plan.regions[region].rooms do
				rooms[id] = true
			end
			self.services.DriftService:Apply("RegionEntered")
			self.RegionEntered:Fire(region, player, rooms)
			self:_updateReach()
		end
	end
end

function LockService:Active(): boolean
	return self.plan ~= nil
end

function LockService:_clear()
	self.plan = nil
	table.clear(self.locks)
	table.clear(self.seen)
	table.clear(self.reach)
	table.clear(self.entered)
	self.quiet = false
	for player in self.rings do
		if player.Parent then
			player:SetAttribute(PA.Keys, nil)
			player:SetAttribute(PA.KeyRing, nil)
		end
	end
	table.clear(self.rings)
end

-- A small plate on both faces of a locked door: a keyhole for a key, a
-- padlock on a hasp for a code, a bolt on the side it slides from, and for
-- an electric lock a box with a lamp (red until the fuse box powers it).
local function plate(door, lock)
	local slab = door.slab
	local brass = Color3.fromRGB(168, 138, 78)
	local folder = Instance.new("Model")
	folder.Name = "Lock"
	for _, side in { -1, 1 } do
		local face = slab.CFrame * CFrame.new(-slab.Size.X / 2 + 1.1, -0.1, side * (slab.Size.Z / 2 + 0.03))
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Metal
		p.Color = brass
		p.Name = "Plate"
		if lock.kind == "padlock" then
			p.Size = Vector3.new(0.5, 0.6, 0.18)
			p.CFrame = face * CFrame.new(0, 0.6, side * 0.09)
			p.Color = Color3.fromRGB(120, 122, 126)
		elseif lock.kind == "bolt" then
			p.Size = Vector3.new(1.4, 0.18, 0.12)
			p.CFrame = face * CFrame.new(0.3, 1.2, side * 0.06)
			p.Color = Color3.fromRGB(70, 70, 74)
		elseif lock.kind == "power" then
			p.Size = Vector3.new(0.5, 0.8, 0.16)
			p.CFrame = face * CFrame.new(0, 0.6, side * 0.08)
			p.Color = Color3.fromRGB(80, 84, 82)
			local lamp = Instance.new("Part")
			lamp.Name = "Lamp"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.CanTouch = false
			lamp.CastShadow = false
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(150, 24, 18)
			lamp.Shape = Enum.PartType.Ball
			lamp.Size = Vector3.new(0.16, 0.16, 0.16)
			lamp.CFrame = face * CFrame.new(0, 0.85, side * 0.17)
			lamp.Parent = folder
		elseif lock.kind == "double" then
			-- Two keyholes, one above the other.
			p.Size = Vector3.new(0.3, 1.3, 0.05)
			p.CFrame = face * CFrame.new(0, 0.6, side * 0.03)
		else
			p.Size = Vector3.new(0.3, 0.6, 0.05)
			p.CFrame = face * CFrame.new(0, 0.6, side * 0.03)
		end
		p.Parent = folder
	end
	-- Run content, though it lives in the door's model so it swings with it
	-- (DoorService moves every part of the model): Gate A leaves it out.
	folder:SetAttribute("RunContent", true)
	folder.Parent = door.model
	return folder
end

-- The plan's locks on the built house. Called by RunOrchestrator after the
-- house is built and DoorService has set up its doors.
function LockService:Begin(plan)
	self:_clear()
	self.plan = plan
	for seamId, lock in plan.locks do
		local seam = self.World.World.seams[seamId]
		local door = seam and seam.door
		if lock.kind == "crank" then
			-- A heavy shutter on a crank, not a door with a lock (Services/
			-- CrankService builds and runs it).
			continue
		elseif door then
			self.Doors:SetLocked(door, true)
			local entry = { lock = lock, door = door, seam = seam, open = false }
			door.lockId = seamId
			self.Doors:RefreshPrompt(door)
			entry.plate = plate(door, lock)
			self.Doors:Adopt(door, entry.plate)
			self.locks[seamId] = entry
		else
			warn("[Consensus] lock on " .. seamId .. " has no door")
		end
	end
	self:_updateReach()
end

-- Rooms the squad can walk to now: from the start and from wherever a
-- living player is, through every doorway that isn't locked. A crank door
-- counts as passable once it has been raised (someone may have gone through
-- and let it drop: they're still on the far side, and it can be raised again).
function LockService:_updateReach()
	table.clear(self.reach)
	local world = self.World.World
	local start = world.layout.start
	self.reach[start] = true
	local queue, head = { start }, 1
	for _, player in self.PlayerState:LivingPlayers() do
		local position = self.PlayerState:Position(player)
		local room = position and self.World:RoomAt(position)
		if room and not self.reach[room] then
			self.reach[room] = true
			table.insert(queue, room)
		end
	end
	local cranks = self.services.CrankService
	while head <= #queue do
		local room = queue[head]
		head += 1
		for _, seam in world.seams do
			local shut = (seam.door and seam.door.locked) or (cranks and cranks:Shut(seam.id))
			if seam.connected and not shut then
				local other = (seam.a == room and seam.b) or (seam.b == room and seam.a) or nil
				if other and not self.reach[other] then
					self.reach[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
end

-- Can the squad get to this room (or this point) right now? Always, outside the escape.
function LockService:Reachable(roomOrPoint): boolean
	if not self.plan then
		return true
	end
	local room = roomOrPoint
	if typeof(roomOrPoint) == "Vector3" then
		room = self.World:RoomAt(roomOrPoint)
	end
	return room ~= nil and self.reach[room] == true
end

-- Keys ------------------------------------------------------------------------------

function LockService:_publishRing(player: Player)
	local names, entries = {}, {}
	for token, label in self.rings[player] or {} do
		table.insert(names, label)
		table.insert(entries, token .. "=" .. label)
	end
	table.sort(names)
	table.sort(entries)
	player:SetAttribute(PA.Keys, #names > 0 and table.concat(names, "\n") or nil)
	-- With the tokens, for the journal's Drop buttons (UI/Map).
	player:SetAttribute(PA.KeyRing, #entries > 0 and table.concat(entries, "\n") or nil)
end

-- Take one key off your ring and leave it at your feet, for someone else.
function LockService:DropKey(player: Player, token: string)
	local ring = self.rings[player]
	local label = ring and ring[token]
	if not label or not self.PlayerState:CanAct(player) then
		return
	end
	ring[token] = nil
	self:_publishRing(player)
	local items = self.services.ItemService
	if items then
		items:DropKeys(player, { [token] = label })
	end
end

function LockService:GiveKey(player: Player, token: string, label: string?)
	self.rings[player] = self.rings[player] or {}
	local info = self.plan and self.plan.tokens[token]
	self.rings[player][token] = label or (info and info.label) or token
	self:_publishRing(player)
end

function LockService:HasKey(player: Player, token: string): boolean
	return self.rings[player] ~= nil and self.rings[player][token] ~= nil
end

-- Everything on a player's ring, taken off it: { [token] = label }.
function LockService:TakeRing(player: Player)
	local ring = self.rings[player] or {}
	self.rings[player] = {}
	if player.Parent then
		self:_publishRing(player)
	end
	return ring
end

-- Opening --------------------------------------------------------------------------

local function notify(player: Player?, text: string, kind: string?)
	if player then
		Net.get("Notify"):FireClient(player, text, kind or "info")
	end
end

function LockService:_rattle(door)
	Sfx.play("DoorBang", door.position, 0.25, 1.6)
	Sfx.play("DoorLatch", door.position, 0.4, 0.7)
end

-- Which side of a door a player stands on: the room id.
function LockService:_sideOf(entry, player: Player): number?
	local position = self.PlayerState:Position(player)
	if not position then
		return nil
	end
	local seam = entry.seam
	-- `normal` points from room A to room B.
	return (position - seam.floorPosition):Dot(seam.normal) < 0 and seam.a or seam.b
end

-- Someone pressed on or pulled a locked door.
function LockService:_try(door, player: Player?)
	local entry = door.lockId and self.locks[door.lockId]
	if not entry or entry.open then
		return
	end
	if not player then
		return
	end
	local lock = entry.lock
	self.seen[door.lockId] = true
	self.Tried:Fire(door.lockId, lock, player)
	if lock.kind == "bolt" then
		if self:_sideOf(entry, player) == lock.side then
			self:Unlock(door.lockId, player, "The bolt slides back.")
		else
			self:_rattle(door)
			notify(player, "Bolted from the other side.")
		end
		return
	elseif lock.kind == "key" then
		local token = lock.needs[1]
		if self:HasKey(player, token) then
			local label = self.rings[player][token]
			self.rings[player][token] = nil
			self:_publishRing(player)
			self:Unlock(door.lockId, player, "The " .. label .. " turns.")
		else
			self:_rattle(door)
			notify(player, "Locked. It needs a key.")
		end
		return
	elseif lock.kind == "double" then
		-- Two keyholes: each key turns in its own, whoever holds it; the
		-- second opens it (docs/plans/level-design.md section 5.3).
		entry.turned = entry.turned or {}
		local turnedNow = false
		for _, token in lock.needs do
			if not entry.turned[token] and self:HasKey(player, token) then
				self.rings[player][token] = nil
				entry.turned[token] = true
				turnedNow = true
			end
		end
		if turnedNow then
			self:_publishRing(player)
		end
		local all = true
		for _, token in lock.needs do
			all = all and entry.turned[token] == true
		end
		if all then
			self:Unlock(door.lockId, player, "The second key turns. The lock gives.")
		elseif turnedNow then
			Sfx.play("DoorLatch", door.position, 0.45, 1.2)
			notify(player, "One key turns. The other keyhole is still locked.")
		else
			self:_rattle(door)
			notify(player, "Two keyholes. It needs two keys.")
		end
		return
	elseif lock.kind == "padlock" then
		local puzzles = self.services.PuzzleService
		if puzzles and puzzles:OpenPadlock(player, door.lockId) then
			return
		end
		self:_rattle(door)
		notify(player, "A padlock. It needs a code.")
	elseif lock.kind == "power" then
		self:_rattle(door)
		notify(player, "An electric lock. The lamp by it is dark: no power.")
	elseif lock.kind == "seal" then
		self:_rattle(door)
		notify(player, "It won't move. Not that way.")
		return
	end
	self.Noise:Emit(door.position, 6, player, "door")
end

-- An electric lock's lamp: green with power, red without (the fuse box).
function LockService:SetPowered(seamId: string, on: boolean)
	local entry = self.locks[seamId]
	if not entry or not entry.plate then
		return
	end
	for _, lamp in entry.plate:GetChildren() do
		if lamp.Name == "Lamp" then
			lamp.Color = on and Color3.fromRGB(60, 220, 90) or Color3.fromRGB(150, 24, 18)
		end
	end
end

-- Open a lock for good (a key, a code, a bolt, F2, the dinner).
function LockService:Unlock(seamId: string, player: Player?, message: string?)
	local entry = self.locks[seamId]
	if not entry or entry.open then
		return false
	end
	entry.open = true
	self.Doors:SetLocked(entry.door, false)
	entry.door.lockId = nil
	self.Doors:RefreshPrompt(entry.door)
	if entry.plate then
		entry.plate:Destroy()
		self.Doors:Disown(entry.door, entry.plate)
		entry.plate = nil
	end
	Sfx.play("DoorLatch", entry.door.position, 0.6, 0.75)
	self.World:MarkPassageChanged(seamId, "unlocked")
	self:_updateReach()
	if message then
		notify(player, message, "good")
	end
	-- Getting through a locked door calms the house (a bolt is only a shortcut).
	if player and entry.lock.kind ~= "bolt" then
		self.services.DriftService:Apply("LockOpened")
	end
	self.Unlocked:Fire(seamId, entry.lock, player)
	return true
end

-- The dinner seals a doorway that was never locked (the dining room's door
-- to the hall): it slams shut and locks for good.
function LockService:LockSeam(seamId: string)
	local seam = self.World.World.seams[seamId]
	local door = seam and seam.door
	if not door or door.locked then
		return
	end
	self.Doors:SetLocked(door, true)
	door.lockId = seamId
	self.Doors:RefreshPrompt(door)
	self.locks[seamId] = { lock = { kind = "seal" }, door = door, seam = seam, open = false }
	Sfx.play("DoorSlam", door.position, 1, 0.85)
	self.Noise:Emit(door.position, 40, nil, "slam")
	self.World:MarkPassageChanged(seamId, "sealed")
	self:_updateReach()
end

-- Every lock in the house (the dinner springs them all).
function LockService:UnlockAll(except: { [string]: boolean }?)
	self.quiet = true
	for seamId, entry in self.locks do
		if not entry.open and not (except and except[seamId]) then
			self:Unlock(seamId, nil, nil)
		end
	end
end

-- For F2 `locks`: one line a lock.
function LockService:Describe(): { string }
	local lines = {}
	for seamId, entry in self.locks do
		local lock = entry.lock
		local what = lock.kind == "bolt" and ("bolt, opens from room " .. lock.side)
			or (lock.kind .. ", needs " .. table.concat(lock.needs or {}, " "))
		table.insert(lines, string.format("%s %s: %s", seamId, entry.open and "open" or "LOCKED", what))
	end
	table.sort(lines)
	return lines
end

LockService.Config = Config.Progression

return LockService
