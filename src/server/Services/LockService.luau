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
end

function LockService:Start()
	self.Doors.LockHandler = function(door, player)
		self:_try(door, player)
	end
	self.World.Cleared:Connect(function()
		self:_clear()
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
end

function LockService:Active(): boolean
	return self.plan ~= nil
end

function LockService:_clear()
	self.plan = nil
	table.clear(self.locks)
	table.clear(self.seen)
	table.clear(self.reach)
	for player in self.rings do
		if player.Parent then
			player:SetAttribute(PA.Keys, nil)
		end
	end
	table.clear(self.rings)
end

-- A small plate on both faces of a locked door: a keyhole for a key, a
-- padlock on a hasp for a code, a bolt on the side it slides from.
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
		else
			p.Size = Vector3.new(0.3, 0.6, 0.05)
			p.CFrame = face * CFrame.new(0, 0.6, side * 0.03)
		end
		p.Parent = folder
	end
	folder.Parent = door.model
	-- It swings with the door (DoorService moves every part of the model).
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
		if door then
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

-- Rooms the squad can walk to now (from the start, through every doorway
-- that isn't locked).
function LockService:_updateReach()
	table.clear(self.reach)
	local world = self.World.World
	local start = world.layout.start
	self.reach[start] = true
	local queue, head = { start }, 1
	while head <= #queue do
		local room = queue[head]
		head += 1
		for _, seam in world.seams do
			if seam.connected and not (seam.door and seam.door.locked) then
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
	local names = {}
	for _, label in self.rings[player] or {} do
		table.insert(names, label)
	end
	table.sort(names)
	player:SetAttribute(PA.Keys, #names > 0 and table.concat(names, "\n") or nil)
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
	elseif lock.kind == "padlock" then
		local puzzles = self.services.PuzzleService
		if puzzles and puzzles:OpenPadlock(player, door.lockId) then
			return
		end
		self:_rattle(door)
		notify(player, "A padlock. It needs a code.")
	end
	self.Noise:Emit(door.position, 6, player, "door")
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
	self.Unlocked:Fire(seamId, entry.lock, player)
	return true
end

-- Every lock in the house (the dinner springs them all).
function LockService:UnlockAll(except: { [string]: boolean }?)
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
