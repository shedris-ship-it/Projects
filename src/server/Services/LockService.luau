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
--
-- Every door that takes something found carries a mark on its plate, on
-- both faces, and whatever opens it carries the same one (Data/Marks,
-- docs/plans/level-design.md section 11): "the phone key" fits the door with
-- a phone on it, and the squad can say so to each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Marks = require(Shared.Data.Marks)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Props = require(Shared.Data.Props)
local ToolLocks = require(Shared.Logic.ToolLocks)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)

local PA = Constants.PlayerAttributes
local M = Config.Marks

local LockService = {
	-- (seamId, lock, player?): a lock came open.
	Unlocked = Signal.new(),
	-- (seamId, lock, player): someone tried a locked door.
	Tried = Signal.new(),
	-- (player): what's on someone's key ring changed.
	RingChanged = Signal.new(),
	-- (region, player, rooms): the first step anyone takes into a part of
	-- the house that was locked away (a set of its room ids). Progress: it
	-- calms Drift and wakes a hunt (Stalker/Director).
	RegionEntered = Signal.new(),
	-- (piece lock id, player?): a chest a step shut came open; (id, player):
	-- someone tried it without its tool.
	PieceOpened = Signal.new(),
	PieceTried = Signal.new(),
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
	self.pieceLocks = {} -- piece lock id -> { lock, space, open, work, state, fixings, anchor }
	self.quiet = false -- every lock opened at once (the dinner, F2): entering no longer counts
end

function LockService:Start()
	self.Doors.LockHandler = function(door, player, how)
		self:_try(door, player, how)
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
	table.clear(self.pieceLocks)
	self.quiet = false
	for player in self.rings do
		if player.Parent then
			player:SetAttribute(PA.Keys, nil)
			player:SetAttribute(PA.KeyRing, nil)
		end
	end
	table.clear(self.rings)
end

-- The door's mark, engraved on a brass disc above the lock, facing out of
-- the door on `side`.
local function markDisc(folder, face: CFrame, side: number, markId: string)
	local mark = Marks.ById[markId]
	if not mark then
		return
	end
	local disc = Instance.new("Part")
	disc.Name = "Mark"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanTouch = false
	disc.CanQuery = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Metal
	disc.Color = Color3.fromRGB(176, 146, 84)
	disc.Size = Vector3.new(M.DiscSize, M.DiscSize, 0.05)
	-- Its front (-Z) looks out of the door on this side.
	disc.CFrame = face
		* CFrame.new(0, M.DiscHeight, side * 0.05)
		* (side > 0 and CFrame.Angles(0, math.pi, 0) or CFrame.identity)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Arial
	label.TextColor3 = Color3.fromRGB(46, 34, 20)
	label.Text = mark.glyph
	label.Parent = gui
	gui.Parent = disc
	disc.Parent = folder
end

-- A small plate on both faces of a locked door: a keyhole for a key, a
-- padlock on a hasp for a code, a bolt on the side it slides from, and for
-- an electric lock a box with a lamp (red until the fuse box powers it).
-- Above it, the door's mark.
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
		if lock.mark then
			markDisc(folder, face, side, lock.mark)
		end
	end
	-- Run content, though it lives in the door's model so it swings with it
	-- (DoorService moves every part of the model): Gate A leaves it out.
	folder:SetAttribute("RunContent", true)
	folder.Parent = door.model
	return folder
end

-- Boards nailed across a doorway on both faces (a tool lock, Logic/
-- ToolLocks): `steps` planks, with gaps to see through. They're on the frame,
-- not the door, so they don't swing. Each is tagged with its step (the
-- highest comes off first).
local function boards(door, steps: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Boards"
	local slab = door.slab
	local closed = door.closedCFrame
	local floorY = slab.Position.Y - slab.Size.Y / 2
	local spacing = 6.4 / steps
	for i = 1, steps do
		local y = floorY + 1.4 + (i - 1) * spacing
		for _, side in { -1, 1 } do
			local p = Instance.new("Part")
			p.Name = "Plank"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Material = Enum.Material.WoodPlanks
			p.Color = Color3.fromRGB(112, 84, 56)
			p.Size = Vector3.new(slab.Size.X + 1.4, 0.55, 0.14)
			local tilt = math.rad((i % 2 == 0 and 1 or -1) * 6)
			local at = Vector3.new(closed.Position.X, y, closed.Position.Z)
			p.CFrame = (closed.Rotation + at) * CFrame.new(0, 0, side * 0.66) * CFrame.Angles(0, 0, tilt)
			p:SetAttribute("Step", i)
			p.Parent = model
		end
	end
	model:SetAttribute("RunContent", true)
	model.Parent = parent
	return model
end

-- A chain through the handles on both faces, crossed, with a padlock.
local function chain(door, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Chain"
	local slab = door.slab
	local closed = door.closedCFrame
	local floorY = slab.Position.Y - slab.Size.Y / 2
	local centre = Vector3.new(closed.Position.X, floorY + 3.6, closed.Position.Z)
	local steel = Color3.fromRGB(96, 96, 100)
	for _, side in { -1, 1 } do
		for _, slope in { -1, 1 } do
			-- Overlapping links along the diagonal, each turned a quarter
			-- round the chain from the last (flat, edge-on, flat...).
			local angle = slope * math.atan(0.7)
			for k = -6, 6 do
				local link = Instance.new("Part")
				link.Name = "Link"
				link.Anchored = true
				link.CanCollide = false
				link.CanTouch = false
				link.CanQuery = false
				link.Material = Enum.Material.Metal
				link.Color = steel
				link.Size = Vector3.new(0.5, 0.2, 0.07)
				local along = k * 0.36
				link.CFrame = (closed.Rotation + centre)
					* CFrame.new(0, 0, side * 0.7)
					* CFrame.Angles(0, 0, angle)
					* CFrame.new(along, 0, 0)
					* CFrame.Angles((k % 2) * math.rad(90), 0, 0)
				link.Parent = model
			end
		end
		local lock = Instance.new("Part")
		lock.Name = "Padlock"
		lock.Anchored = true
		lock.CanCollide = false
		lock.CanTouch = false
		lock.CanQuery = false
		lock.Material = Enum.Material.Metal
		lock.Color = Color3.fromRGB(70, 70, 74)
		lock.Size = Vector3.new(0.5, 0.6, 0.25)
		lock.CFrame = (closed.Rotation + centre) * CFrame.new(0, -0.15, side * 0.82)
		lock.Parent = model
	end
	model:SetAttribute("RunContent", true)
	model.Parent = parent
	return model
end

-- A run of chain links from `at` (its middle, facing out of the front), at
-- `angle` across the face, `half` studs each way: overlapping links, each
-- turned a quarter round the chain from the last.
local function links(model: Model, at: CFrame, angle: number, half: number)
	local count = math.max(1, math.floor(half / 0.36))
	for k = -count, count do
		local link = Instance.new("Part")
		link.Name = "Link"
		link.Anchored = true
		link.CanCollide = false
		link.CanTouch = false
		link.CanQuery = false
		link.Material = Enum.Material.Metal
		link.Color = Color3.fromRGB(96, 96, 100)
		link.Size = Vector3.new(0.5, 0.2, 0.07)
		link.CFrame = at
			* CFrame.Angles(0, 0, angle)
			* CFrame.new(k * 0.36, 0, 0)
			* CFrame.Angles((k % 2) * math.rad(90), 0, 0)
		link.Parent = model
	end
end

-- A chest (or the fridge) a step shut (section 11, L3.4): a chain crossed
-- over its front with a padlock, or `steps` planks nailed across it, each
-- tagged with its step. `frame` is the piece's own (its front is +Z), at
-- the floor. Returns the model and the part its prompt hangs on.
local function pieceFixings(kind: string, frame: CFrame, size: Vector3, steps: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = kind == "boards" and "Boards" or "Chain"
	local w, h, d = size.X, size.Y, size.Z
	-- Across the doors' middle, or a chest's lid and front.
	local low, high = h * 0.4, h - 0.35
	if h > 5 then
		low, high = h * 0.3, h * 0.68
	end
	local face = d / 2 + 0.2
	local middle = frame * CFrame.new(0, (low + high) / 2, face)
	if kind == "boards" then
		for i = 1, steps do
			local plank = Instance.new("Part")
			plank.Name = "Plank"
			plank.Anchored = true
			plank.CanCollide = false
			plank.CanTouch = false
			plank.CanQuery = false
			plank.Material = Enum.Material.WoodPlanks
			plank.Color = Color3.fromRGB(150, 116, 78) -- fresh-cut: it reads in torchlight
			plank.Size = Vector3.new(w + 0.5, 0.5, 0.14)
			local y = steps == 1 and (low + high) / 2 or low + (high - low) * (i - 1) / (steps - 1)
			local tilt = math.rad((i % 2 == 0 and 1 or -1) * 5)
			plank.CFrame = frame * CFrame.new(0, y, face) * CFrame.Angles(0, 0, tilt)
			plank:SetAttribute("Step", i)
			plank.Parent = model
		end
	else
		local spanX, spanY = w * 0.4, (high - low) / 2
		local half = math.sqrt(spanX * spanX + spanY * spanY)
		for _, slope in { -1, 1 } do
			links(model, middle, slope * math.atan2(spanY, spanX), half)
		end
		local lock = Instance.new("Part")
		lock.Name = "Padlock"
		lock.Anchored = true
		lock.CanCollide = false
		lock.CanTouch = false
		lock.CanQuery = false
		lock.Material = Enum.Material.Metal
		lock.Color = Color3.fromRGB(70, 70, 74)
		lock.Size = Vector3.new(0.5, 0.6, 0.25)
		lock.CFrame = middle * CFrame.new(0, -0.2, 0.12)
		lock.Parent = model
	end
	-- Where its prompt hangs: its middle, just out from the front.
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = middle * CFrame.new(0, 0, 0.2)
	anchor.Parent = model
	model:SetAttribute("RunContent", true)
	model.Parent = parent
	return model, anchor
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
			if ToolLocks.is(lock.kind) then
				-- Boards or a chain, on the frame (Logic/ToolLocks); held work.
				local info = ToolLocks.Kinds[lock.kind]
				local orchestrator = self.services.RunOrchestrator
				local squad = orchestrator and orchestrator.run and orchestrator.run.squad
				entry.work = ToolLocks.work(lock.kind, squad, Config.ToolLocks)
				entry.state = ToolLocks.start(entry.work)
				local parent = self.World.content or workspace
				entry.fixings = lock.kind == "boards" and boards(door, entry.work.steps, parent) or chain(door, parent)
				door.lockText = { object = info.object, action = info.action }
				door.prompt.HoldDuration = entry.work.seconds
			else
				entry.plate = plate(door, lock)
				self.Doors:Adopt(door, entry.plate)
			end
			self.Doors:RefreshPrompt(door)
			self.locks[seamId] = entry
		else
			warn("[Consensus] lock on " .. seamId .. " has no door")
		end
	end
	self:_hidden(self.World.World.layout)
	self:_updateReach()
end

-- The servants' passages' hidden doors (docs/plans/level-design.md section
-- 10.4): shut from the room side until someone finds them (a wall to
-- everyone, The Guest too, till then); a latch on the passage side.
function LockService:_hidden(layout)
	for _, passage in layout.passages or {} do
		for _, seam in passage.seams do
			local record = self.World.World.seams[seam.id]
			local door = record and record.door
			if door then
				local kind = door.model:FindFirstChild("CaseBack") and "Bookcase" or "Panel"
				local lock = {
					kind = "hidden",
					side = passage.id,
					barred = seam.barred,
					disguise = kind,
					found = kind == "Bookcase" and "The bookcase gives, and swings out on a narrow passage."
						or "The panel gives under your hand: a door, onto a narrow passage.",
				}
				self.Doors:SetLocked(door, true)
				door.lockId = seam.id
				local entry = { lock = lock, door = door, seam = record, open = false, hidden = true }
				self.locks[seam.id] = entry
				-- Its prompt only shows close up, and names what it looks like.
				local prompt = door.prompt
				prompt.ObjectText = kind
				prompt.ActionText = "Search"
				prompt.MaxActivationDistance = Config.Mansion.Passages.SearchReach
				prompt.RequiresLineOfSight = true
				door.disguise = kind
			end
		end
	end
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

-- A key as the squad says it: its mark and its name ("☎ phone key").
function LockService:Display(token: string, label: string): string
	local info = self.plan and self.plan.tokens[token]
	local glyph = Marks.glyph(info and info.mark)
	return glyph ~= "" and (glyph .. " " .. label) or label
end

function LockService:_publishRing(player: Player)
	local names, entries = {}, {}
	local finale = self.services.FinaleService
	for token, label in self.rings[player] or {} do
		local shown = self:Display(token, label)
		table.insert(names, shown)
		-- With the token, for the journal's Drop buttons, and where its door
		-- is once someone has seen it (UI/Map).
		local place = finale and self:KeyPlace(token)
		table.insert(entries, token .. "=" .. shown .. "=" .. (place or ""))
	end
	table.sort(names)
	table.sort(entries)
	player:SetAttribute(PA.Keys, #names > 0 and table.concat(names, "\n") or nil)
	player:SetAttribute(PA.KeyRing, #entries > 0 and table.concat(entries, "\n") or nil)
	self.RingChanged:Fire(player)
end

-- Everyone's ring again (a door was seen: the journal says where it is).
function LockService:RefreshRings()
	for player in self.rings do
		if player.Parent then
			self:_publishRing(player)
		end
	end
end

-- Where a key's next door is, in words, once someone has seen it (the first
-- of its doors still shut that has been seen); nil until then.
function LockService:KeyPlace(token: string): (string?, string?)
	local finale = self.services.FinaleService
	for _, seamId in self:DoorsOf(token) do
		local entry = self.locks[seamId]
		if entry and not entry.open then
			local place = finale:DoorPlace(seamId)
			if place then
				return place
			end
		end
	end
	-- A step's chest it opens (a tool's), once anyone has been by it: the
	-- place, and what it is ("chest").
	local ids = {}
	for id in self.pieceLocks do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local entry = self.pieceLocks[id]
		if not entry.open and table.find(entry.lock.needs, token) and finale:PieceKnown(id) then
			return finale:RoomPlace(entry.lock.room), entry.lock.thing
		end
	end
	return nil
end

-- The doors a key opens: its own and, for the house key, its side rooms'.
function LockService:DoorsOf(token: string): { string }
	local info = self.plan and self.plan.tokens[token]
	local doors = {}
	if info and info.opens then
		table.insert(doors, info.opens)
	end
	for _, seamId in info and info.also or {} do
		table.insert(doors, seamId)
	end
	return doors
end

-- Every key the squad holds: { { token, label, holder } }, by token.
function LockService:HeldKeys()
	local held = {}
	for player, ring in self.rings do
		if player.Parent then
			for token, label in ring do
				table.insert(held, { token = token, label = label, holder = player })
			end
		end
	end
	table.sort(held, function(a, b)
		return a.token < b.token
	end)
	return held
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

-- "a star", "an umbrella", or nil for a door with no mark.
local function aMark(lock): string?
	local mark = lock.mark and Marks.ById[lock.mark]
	return mark and Marks.said(mark.name) or nil
end

-- Why a key door won't open for this player: what's on its plate, and that
-- the keys they carry don't fit (a playtest stood at the wrong door with
-- the right key, told only "it needs a key").
function LockService:_keyRefusal(player: Player, lock): string
	local mark = aMark(lock)
	local held = {}
	for token, label in self.rings[player] or {} do
		local info = self.plan and self.plan.tokens[token]
		if info and info.kind == "key" then
			table.insert(held, label)
		end
	end
	table.sort(held)
	local what = mark and (" This lock has " .. mark .. ".") or ""
	if #held == 1 then
		return "Your " .. held[1] .. " doesn't fit." .. what
	elseif #held > 1 then
		return "None of your keys fit." .. what
	end
	return mark and ("Locked. There's " .. mark .. " on the plate.") or "Locked. It needs a key."
end

-- The house key leaves the ring once every door with its mark is open.
function LockService:_spent(player: Player, token: string, label: string)
	for _, seamId in self:DoorsOf(token) do
		local entry = self.locks[seamId]
		if entry and not entry.open then
			self:_publishRing(player)
			return
		end
	end
	if self.rings[player] then
		self.rings[player][token] = nil
	end
	self:_publishRing(player)
	notify(player, "Nothing left for the " .. label .. ".")
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

-- One hold's work on a tool lock: a plank pried off (it falls at the
-- worker's feet, something to throw) or the chain cut. Loud either way.
function LockService:_toolStep(seamId: string, entry, player: Player)
	local info = ToolLocks.Kinds[entry.lock.kind]
	local door = entry.door
	local done = ToolLocks.step(entry.state)
	if entry.lock.kind == "boards" then
		local step = entry.state.left + 1
		local closed = door.closedCFrame
		local position = self.PlayerState:Position(player)
		local worker = position and (position - closed.Position):Dot(closed.LookVector) or 0
		for _, plank in entry.fixings and entry.fixings:GetChildren() or {} do
			if plank:GetAttribute("Step") == step then
				-- The one on the worker's side comes away into the room.
				if ((plank.Position - closed.Position):Dot(closed.LookVector) >= 0) == (worker >= 0) then
					self:_loosePlank(plank)
				end
				plank:Destroy()
			end
		end
		Sfx.play("CreakAlt", door.position, 1, 0.5)
		task.delay(0.25, function()
			Sfx.play("Thud", door.position, 0.8, 1.15)
		end)
	else
		if entry.fixings then
			entry.fixings:Destroy()
			entry.fixings = nil
		end
		Sfx.play("Snap", door.position, 1, 0.6)
		Sfx.play("DoorLatch", door.position, 0.7, 0.55)
	end
	self.Noise:Emit(door.position, entry.work.noise, player, entry.lock.kind == "boards" and "pry" or "snap")
	if done then
		self:Unlock(seamId, player, info.done)
	elseif info.step then
		notify(player, info.step .. " " .. entry.state.left .. " to go.")
	end
end

-- A board off a door, lying at its foot: a thing to pick up and throw.
function LockService:_loosePlank(plank: BasePart)
	local hands = self.services.HandsService
	local parent = self.World.content
	if not hands or not parent then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Plank"
	local copy = plank:Clone()
	copy:SetAttribute("Step", nil)
	copy.Size = Vector3.new(plank.Size.X * 0.8, 0.14, 0.55)
	local floor = plank.Position.Y
	local ray = workspace:Raycast(plank.Position, Vector3.new(0, -12, 0))
	if ray then
		floor = ray.Position.Y
	end
	copy.CFrame = CFrame.new(plank.Position.X, floor + 0.08, plank.Position.Z) * plank.CFrame.Rotation
	copy.Parent = model
	model.PrimaryPart = copy
	model.Parent = parent
	hands:AddThing(model, { class = Physical.Dressing.Plank.class, label = Physical.Dressing.Plank.label })
end

-- A chest (or the fridge) a step inside a wing shuts (docs/plans/level-
-- design.md section 11, L3.4): what's kept in its `space` (Services/
-- ItemService put it there) stays shut in until the tool's work is done.
function LockService:LockPiece(lockId: string, space)
	local info = self.plan and self.plan.pieces and self.plan.pieces[lockId]
	if not info or not space or self.pieceLocks[lockId] then
		return
	end
	-- Every door and lid on it (a fridge's freezer too: the planks cross both).
	local furniture = self.services.FurnitureService
	local pieces = {}
	for _, piece in furniture.pieces do
		if piece.prop == space.prop then
			furniture:SetLocked(piece, true)
			table.insert(pieces, piece)
		end
	end
	local orchestrator = self.services.RunOrchestrator
	local squad = orchestrator and orchestrator.run and orchestrator.run.squad
	local work = ToolLocks.work(info.kind, squad, Config.ToolLocks, true)
	local prop = space.prop
	local kind = Props.Kinds[prop.kind]
	local size = kind and Vector3.new(kind.size[1], kind.size[2], kind.size[3]) or Vector3.new(4, 3, 3)
	local fixings, anchor = pieceFixings(info.kind, prop.frame, size, work.steps, self.World.content or workspace)
	local parts = {}
	for _, p in fixings:GetChildren() do
		table.insert(parts, p)
	end
	local push = self.services.PushService
	if push then
		push:Fix(prop.model, parts)
	end
	local tool = ToolLocks.Kinds[info.kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ToolPrompt"
	prompt.ObjectText = (string.gsub(info.thing, "^%l", string.upper))
	prompt.ActionText = tool.action
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = work.seconds
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		self:_tryPiece(lockId, player)
	end)
	self.pieceLocks[lockId] = {
		lock = info,
		space = space,
		pieces = pieces,
		open = false,
		work = work,
		state = ToolLocks.start(work),
		fixings = fixings,
		parts = parts,
		anchor = anchor,
	}
end

-- One hold on a step's chest: with the tool, a plank off or the chain cut
-- (loud); without it, it won't budge and says what would do.
function LockService:_tryPiece(lockId: string, player: Player)
	local entry = self.pieceLocks[lockId]
	if not entry or entry.open or not self.PlayerState:CanAct(player) then
		return
	end
	local info = ToolLocks.Kinds[entry.lock.kind]
	local at = entry.anchor.Position
	local tools = self.services.ToolService
	if not (tools and tools:Carries(player, info.tool)) then
		Sfx.play("DoorLatch", at, 0.4, 0.8)
		notify(player, info.pieceRefuse)
		self.PieceTried:Fire(lockId, player)
		return
	end
	local done = ToolLocks.step(entry.state)
	if entry.lock.kind == "boards" then
		local step = entry.state.left + 1
		for _, plank in entry.fixings:GetChildren() do
			if plank:GetAttribute("Step") == step then
				local push = self.services.PushService
				if push then
					push:Unfix({ plank })
				end
				self:_loosePlank(plank)
				plank:Destroy()
			end
		end
		Sfx.play("CreakAlt", at, 1, 0.5)
		task.delay(0.25, function()
			Sfx.play("Thud", at, 0.8, 1.15)
		end)
	else
		Sfx.play("Snap", at, 1, 0.6)
	end
	self.Noise:Emit(at, entry.work.noise, player, entry.lock.kind == "boards" and "pry" or "snap")
	if done then
		self:UnlockPiece(lockId, player, info.done)
	elseif info.step then
		notify(player, info.step .. " " .. entry.state.left .. " left.")
	end
end

-- A step's chest comes open: its pieces move again and its fixings go.
function LockService:UnlockPiece(lockId: string, player: Player?, message: string?)
	local entry = self.pieceLocks[lockId]
	if not entry or entry.open then
		return
	end
	entry.open = true
	local furniture = self.services.FurnitureService
	for _, piece in entry.pieces do
		furniture:SetLocked(piece, false)
	end
	local push = self.services.PushService
	if push then
		push:Unfix(entry.parts)
	end
	entry.fixings:Destroy()
	if message then
		notify(player, message)
	end
	self.PieceOpened:Fire(lockId, player)
end

-- Someone pressed on or pulled a locked door (`how`: "prompt" or "pull").
function LockService:_try(door, player: Player?, how: string?)
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
			notify(player, "Bolted from the other side. There must be another way round.")
		end
		return
	elseif lock.kind == "key" or lock.kind == "pocket" then
		local token = lock.needs[1]
		if self:HasKey(player, token) then
			local label = self.rings[player][token]
			local info = self.plan and self.plan.tokens[token]
			if info and info.reusable then
				-- The house key (docs/plans/level-design.md section 11, L3.2):
				-- it stays on the ring while a door with its mark is still shut.
				self:Unlock(door.lockId, player, "The " .. label .. " turns.")
				self:_spent(player, token, label)
			else
				self.rings[player][token] = nil
				self:_publishRing(player)
				self:Unlock(door.lockId, player, "The " .. label .. " turns.")
			end
		else
			self:_rattle(door)
			notify(player, self:_keyRefusal(player, lock))
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
			local mark = aMark(lock)
			notify(
				player,
				mark and ("Two keyholes, each with " .. mark .. ". It needs two keys.")
					or "Two keyholes. It needs two keys."
			)
		end
		return
	elseif lock.kind == "padlock" then
		local puzzles = self.services.PuzzleService
		if puzzles and puzzles:OpenPadlock(player, door.lockId) then
			return
		end
		self:_rattle(door)
		local mark = aMark(lock)
		notify(
			player,
			mark and ("A padlock with " .. mark .. " on it. It needs a code.") or "A padlock. It needs a code."
		)
	elseif lock.kind == "power" then
		self:_rattle(door)
		local mark = aMark(lock)
		notify(
			player,
			"An electric lock"
				.. (mark and (" with " .. mark .. " on it") or "")
				.. ". The lamp by it is dark: no power."
		)
	elseif lock.kind == "hidden" then
		-- A servants' passage's door (docs/plans/level-design.md section 10.4):
		-- a latch on the passage side; on the room side, finding it is pulling
		-- on the right bookcase or panel.
		if self:_sideOf(entry, player) == lock.side then
			if lock.barred then
				-- Into a wing opened later: it won't give from in here.
				self:_rattle(door)
				notify(player, "It won't move from this side.")
				return
			end
			self:Unlock(door.lockId, player, "The latch lifts.")
		else
			self:Unlock(door.lockId, player, lock.found)
			self.Doors:SetOpen(door, true, player)
		end
		return
	elseif lock.kind == "seal" then
		self:_rattle(door)
		notify(player, "It won't move. Not that way.")
		return
	elseif ToolLocks.is(lock.kind) then
		-- Boards or a chain (section 11, L3.3): held work with the tool, a
		-- step a hold; pulling on it only rattles.
		local info = ToolLocks.Kinds[lock.kind]
		local tools = self.services.ToolService
		if how ~= "prompt" or not (tools and tools:Carries(player, info.tool)) then
			self:_rattle(door)
			notify(player, info.refuse)
			return
		end
		self:_toolStep(door.lockId, entry, player)
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
	if entry.fixings then
		-- (The dinner springs a tool lock too: the boards or the chain go.)
		entry.fixings:Destroy()
		entry.fixings = nil
	end
	if entry.work then
		entry.door.lockText = nil
		entry.door.prompt.HoldDuration = 0
		self.Doors:RefreshPrompt(entry.door)
	end
	if entry.hidden then
		-- Found: a door like any other from now on, for everyone (him too).
		entry.seam.found = true
		local prompt = entry.door.prompt
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 8, false
		self.Doors:RefreshPrompt(entry.door)
	end
	self.World:MarkPassageChanged(seamId, "unlocked")
	self:_updateReach()
	if message then
		notify(player, message, "good")
	end
	-- Getting through a locked door calms the house (a bolt or a hidden door
	-- is only a shortcut).
	if player and entry.lock.kind ~= "bolt" and entry.lock.kind ~= "hidden" then
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
	for id in self.pieceLocks do
		self:UnlockPiece(id, nil, nil)
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
	for id, entry in self.pieceLocks do
		local lock = entry.lock
		local what = string.format("%s on the %s, needs %s", lock.kind, lock.thing, table.concat(lock.needs, " "))
		table.insert(lines, string.format("%s %s: %s", id, entry.open and "open" or "LOCKED", what))
	end
	table.sort(lines)
	return lines
end

LockService.Config = Config.Progression

return LockService
