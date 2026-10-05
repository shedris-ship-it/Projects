-- The escape's keys and heirlooms (docs/plans/gameplay-rework.md section
-- 5.6). The plan (Logic/LockPlanner) says which room each is kept in; this
-- picks a drawer or cupboard in that room for it (or, with none, a spot on
-- the floor) and puts it there the first time that space is opened, so
-- nothing is sent to anyone before it's found (Services/FurnitureService
-- asks through `Filler`).
--
-- Both are things your hands can take (Services/HandsService). A key goes
-- straight onto the taker's ring (Services/LockService); it falls where its
-- holder goes down, is Lost or leaves. An heirloom is carried to the dining
-- table (Services/FinaleService) and falls like anything else you carry.
--
-- How each is found is its lead (R2c, "leads, not rummaging"; Logic/Leads):
-- a note somewhere already open that says which drawer, a keepsake box on a
-- top, a locked glass case (pick the lock, or throw something through the
-- glass), or a key rack. A note's text is made here and sent only to a
-- player who reads it (NoteText), so nothing in the world gives it away.
--
-- The heirlooms are his (R2c, "the Guest wants his dinner"): this keeps each
-- one's state (who holds it, since when it lies about, whether it's set) for
-- his scent (Logic/Scent, StalkerService), and its home: where it was kept,
-- so he can put it back (`Tidy`). Later producers (a safe, the music box)
-- give their own homes with SetHome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Rooms = require(Shared.Data.Rooms)
local NoteText = require(Shared.Logic.NoteText)
local Throw = require(Shared.Logic.Throw)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)

local Dressing = require(script.Parent.Parent.World.Dressing)
local Items = require(script.Parent.Parent.World.Items)
local Junk = require(script.Parent.Parent.World.Junk)
local LeadProps = require(script.Parent.Parent.World.LeadProps)

local L = Config.Leads

local ItemService = {
	-- (player, token, kind): someone found something the escape needs.
	Found = Signal.new(),
	-- (player, token): someone picked an heirloom up (every time).
	HeirloomTaken = Signal.new(),
	-- (token): an heirloom left someone's hands.
	HeirloomDropped = Signal.new(),
	-- (token, label): he put one back where it was kept.
	Tidied = Signal.new(),
	-- (player, note): someone read a note.
	NoteRead = Signal.new(),
	-- (player?, case, how "picked" | "smashed"): a display case was opened.
	CaseOpened = Signal.new(),
}

function ItemService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Furniture = services.FurnitureService
	self.Hands = services.HandsService
	self.Locks = services.LockService
	self.PlayerState = services.PlayerStateService
	self.plan = nil
	self.bySpace = {} -- furniture space -> token kept there
	self.heirloomKinds = {} -- token -> an entry of Items.Heirlooms
	self.found = {} -- token -> true once someone has taken it
	-- token -> { token, home, thing?, holder?, lastHolder?, droppedAt?, set }
	self.heirlooms = {}
	-- Leads (Logic/Leads): where each token was actually put, and how.
	self.leadOf = {} -- token -> { kind, room, noteRoom? }
	self.notes = {} -- note id -> { id, token, text, room, model, sheet }
	self.cases = {} -- display cases: { id, model, panes, cover, piece, token?, shown?, room, open }
	self.racks = {} -- room id -> { model, hangs, used }
	self.decoys = {} -- space -> true: a keepsake box with nothing of his in it
	self.folder = nil
end

function ItemService:Start()
	self.Furniture.Filler = function(space, at)
		return self:_fill(space, at)
	end
	self.Hands.Grabbed:Connect(function(player, thing)
		self:_grabbed(player, thing)
	end)
	self.Hands.Released:Connect(function(player, thing)
		local token = thing.model:GetAttribute("Item")
		local state = token and self.heirlooms[token]
		if state and state.holder == player then
			state.holder = nil
			state.lastHolder = player
			state.droppedAt = os.clock()
			self.HeirloomDropped:Fire(token)
		end
	end)
	-- Something thrown through a display case's glass breaks it.
	self.Hands.Moved:Connect(function(thing, from: Vector3, to: Vector3)
		self:_thrownMoved(thing, from, to)
	end)
	self.World.Cleared:Connect(function()
		self.plan = nil
		table.clear(self.bySpace)
		table.clear(self.heirloomKinds)
		table.clear(self.found)
		table.clear(self.heirlooms)
		table.clear(self.leadOf)
		table.clear(self.notes)
		table.clear(self.cases)
		table.clear(self.racks)
		table.clear(self.decoys)
		self.folder = nil
	end)
end

-- Where each kept thing goes: by its lead (Logic/Leads, planned with its
-- own fork), a box, a case or a rack in its room, else a drawer or cupboard
-- there (with a note elsewhere when its lead is a note). `leads` may be nil
-- (everything in drawers). Placement draws from its own fork, `rng`'s
-- "leadplace", so the drawers chosen for the rest don't move.
function ItemService:Begin(plan, rng, leads)
	self.plan = plan
	table.clear(self.bySpace)
	self.folder = Instance.new("Folder")
	self.folder.Name = "Leads"
	self.folder.Parent = self.World.content
	local place = rng:Fork("leadplace")
	local world = self.World.World
	self.named = NoteText.rooms(world.layout, world.layout.mode == "Mansion" and Rooms.MansionById or Rooms.ById)
	local usedTemplates = {}
	local kinds = rng:Shuffle(table.clone(Items.Heirlooms))
	local heirlooms = 0
	local ids = {}
	for id in plan.tokens do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local token = plan.tokens[id]
		if token.kind == "heirloom" then
			heirlooms += 1
			self.heirloomKinds[id] = kinds[(heirlooms - 1) % #kinds + 1]
			self.heirlooms[id] = { token = id, set = false, home = { room = token.producer.room } }
		end
		if token.producer.kind == "container" then
			local room = token.producer.room
			local lead = leads and leads.tokens[id] or { kind = "drawer" }
			local placed = false
			if lead.kind == "keepsake" then
				placed = self:_placeKeepsake(id, room, place)
			elseif lead.kind == "display" then
				placed = self:_placeDisplay(id, room, place)
			elseif lead.kind == "hook" then
				placed = self:_placeHook(id, room, place)
			end
			if placed then
				self.leadOf[id] = { kind = lead.kind, room = room }
			else
				-- A drawer, and a note saying which (also when a box, case or
				-- rack found no place: the note is the fallback lead).
				local space = self:_keep(id, room, rng)
				local kind = lead.noteRoom and "note" or "drawer"
				self.leadOf[id] = { kind = kind, room = room, wanted = lead.kind ~= kind and lead.kind or nil }
				if lead.noteRoom then
					self:_placeNote(id, lead.noteRoom, room, space, place, usedTemplates)
					self.leadOf[id].noteRoom = lead.noteRoom
				end
			end
		end
	end
	for _, decoy in leads and leads.decoys or {} do
		if decoy.kind == "keepsake" then
			self:_placeKeepsake(nil, decoy.room, place)
		elseif decoy.kind == "display" then
			self:_placeDisplay(nil, decoy.room, place)
		end
	end
end

-- A drawer or cupboard in its room for a token (the old way, and a note's
-- target). Returns the space, or nil when it lies on the floor.
function ItemService:_keep(id: string, room: number, rng)
	local spaces = {}
	for _, space in self.Furniture.spaces do
		if space.prop.roomId == room and not space.filled and not self.bySpace[space] and not space.lead then
			table.insert(spaces, space)
		end
	end
	table.sort(spaces, function(a, b)
		return a.id < b.id
	end)
	local state = self.heirlooms[id]
	if #spaces > 0 then
		local space = rng:Pick(spaces)
		self.bySpace[space] = id
		if state then
			state.home.space = space
		end
		return space
	end
	-- Nowhere to keep it: lying on the floor in that room.
	local at = self.World:RandomPointIn(room, rng)
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if state then
		state.home.cframe = cf
	end
	self:_make(id, cf)
	return nil
end

function ItemService:Label(token: string): string
	local info = self.plan and self.plan.tokens[token]
	if info and info.kind == "heirloom" then
		return self.heirloomKinds[token].label
	end
	return info and info.label or token
end

-- Build what a token is, lying at `at`, as a thing your hands can take.
function ItemService:_make(token: string, at: CFrame)
	local info = self.plan.tokens[token]
	local folder = self.World.content
	local model
	if info.kind == "key" then
		model = Items.key(at, info.label, folder)
	elseif info.kind == "heirloom" then
		model = Items.heirloom(self.heirloomKinds[token].id, at, folder)
	else
		return nil
	end
	model:SetAttribute("Item", token)
	local thing = self.Hands:AddThing(model, {
		class = Physical.Dressing[model.Name].class,
		label = self:Label(token),
	})
	local state = self.heirlooms[token]
	if state then
		-- His: clients play a faint music box from it while it's carried.
		model:SetAttribute("Heirloom", true)
		state.thing = thing
	end
	return model, thing
end

-- Each heirloom's state, for his scent (Logic/Scent): holder, hidden,
-- droppedAt, lastHolder, position, set.
function ItemService:Heirlooms()
	local list = {}
	local hiding = self.services.HidingService
	for _, state in self.heirlooms do
		local thing = state.thing
		local model = thing and thing.model
		local position = model and model.Parent and model:GetPivot().Position or nil
		table.insert(list, {
			token = state.token,
			holder = state.holder,
			hidden = state.holder ~= nil and hiding:IsHidden(state.holder),
			droppedAt = state.droppedAt,
			lastHolder = state.lastHolder,
			position = position,
			set = state.set,
			thing = thing,
		})
	end
	return list
end

-- Where an heirloom was kept: { room, space? (a drawer or cupboard), cframe?
-- (on the floor), station? (a puzzle that held it) }.
function ItemService:HomeOf(token: string)
	local state = self.heirlooms[token]
	return state and state.home
end

-- A producer that isn't a drawer (the safe, the music box) says where its
-- heirloom lives.
function ItemService:SetHome(token: string, home)
	local state = self.heirlooms[token]
	if state then
		state.home = home
	end
end

-- Laid at the table (Services/FinaleService): his for good.
function ItemService:MarkSet(token: string)
	local state = self.heirlooms[token]
	if state then
		state.set = true
		state.holder = nil
		state.thing = nil
	end
end

-- He puts it back where it was kept (Stalker/Stalk's Tidy errand): out of
-- the world, and kept there again, the drawer or cupboard shut on it.
function ItemService:Tidy(token: string): boolean
	local state = self.heirlooms[token]
	local thing = state and state.thing
	if not state or state.set or state.holder or not thing then
		return false
	end
	local home = state.home
	self.Hands:Forget(thing, true)
	state.thing = nil
	state.droppedAt = nil
	if home.space then
		local space = home.space
		space.filled = false
		self.bySpace[space] = token
		for _, piece in space.pieces do
			self.Furniture:SetOpen(piece, false)
		end
	elseif home.station and home.station.Restore then
		home.station.Restore(token)
	else
		local at = home.cframe or CFrame.new(self.World:Room(home.room).center)
		self:_make(token, at)
	end
	self.Tidied:Fire(token, self:Label(token))
	return true
end

-- FurnitureService opening a space for the first time: what's kept here?
-- A keepsake box with nothing of his in it holds old letters, or nothing.
function ItemService:_fill(space, at: CFrame)
	local decoy = self.decoys[space]
	if decoy then
		self.decoys[space] = nil
		if decoy == "letters" then
			return Junk.build("Letters", at, self.World.content)
		end
		return false
	end
	local token = self.bySpace[space]
	if not token or not self.plan then
		return nil
	end
	self.bySpace[space] = nil
	return self:_make(token, at)
end

-- Leads ----------------------------------------------------------------------------

-- A free spot on a top in `room` (World/Dressing), turned so +Z is the
-- furniture's front. Nil when every top there is full.
function ItemService:_top(room: number, rng): CFrame?
	local world = self.World.World
	local options = {}
	for _, s in world.surfaces or {} do
		if s.record.id == room and s.prop.model.Parent and Dressing.free(s) > 0 then
			table.insert(options, s)
		end
	end
	local s = rng:Pick(options)
	local spot = s and Dressing.claim(s)
	return spot and spot * CFrame.Angles(0, math.pi, 0)
end

-- A free wall spot in `room`, turned so +Z faces into the room, at about
-- eye height (wall slots are for pictures, a little higher).
function ItemService:_wall(room: number, rng): CFrame?
	local slot = self.World:TakeWallSlot(room, rng)
	return slot and slot.cframe * CFrame.new(0, -L.WallDrop, 0) * CFrame.Angles(0, math.pi, 0)
end

-- A keepsake box on a top: `token` inside (or, a decoy, nothing of his).
function ItemService:_placeKeepsake(token: string?, room: number, rng): boolean
	local at = self:_top(room, rng)
	if not at then
		return false
	end
	local model = LeadProps.keepsake(at, self.folder, rng:NextInteger(1, #LeadProps.KeepsakeLooks))
	local id = "keepsake:" .. (#self.folder:GetChildren())
	local spaces = self.Furniture:AddProp({ id = id, model = model, roomId = room, kind = "Keepsake" })
	local space = spaces[1]
	if not space or space.filled then
		-- Its lid couldn't open (something over it): not a box after all.
		model:Destroy()
		return false
	end
	space.lead = "keepsake"
	if token then
		self.bySpace[space] = token
		local state = self.heirlooms[token]
		if state then
			state.home.space = space
		end
	else
		self.decoys[space] = rng:Chance(0.6) and "letters" or "empty"
	end
	return true
end

-- A display case on a top, `token` in plain sight behind locked glass (or,
-- a decoy, a porcelain figure). Pick the lock, or break the glass.
function ItemService:_placeDisplay(token: string?, room: number, rng): boolean
	local at = self:_top(room, rng)
	if not at then
		return false
	end
	local model, spot, panes, plate = LeadProps.displayCase(at, self.folder)
	local id = "case:" .. (#self.cases + 1)
	local spaces = self.Furniture:AddProp({ id = id, model = model, roomId = room, kind = "DisplayCase" })
	local space = spaces[1]
	local piece = space and space.pieces[1]
	if not piece then
		model:Destroy()
		return false
	end
	space.filled = true -- what's in it is made now, in plain sight
	space.lead = "display"
	self.Furniture:SetLocked(piece, true)
	-- What's inside, for show until the case is open.
	local shown
	local inside = spot * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
	if token then
		local info = self.plan.tokens[token]
		if info.kind == "key" then
			shown = Items.key(inside, info.label, model)
		else
			shown = Items.heirloom(self.heirloomKinds[token].id, inside, model)
		end
		local state = self.heirlooms[token]
		if state then
			state.home.cframe = inside
		end
	else
		shown = LeadProps.figurine(inside, model)
	end
	shown.Name = "Shown"
	for _, p in shown:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	-- Where the inside is, kept relative to the felt: the case may ride a
	-- pushed dresser (Services/PushService).
	local felt = model:FindFirstChild("Felt") :: BasePart
	local case = {
		id = id,
		model = model,
		panes = panes,
		cover = piece.model,
		piece = piece,
		token = token,
		shown = shown,
		felt = felt,
		offset = felt.CFrame:ToObjectSpace(inside),
		room = room,
		open = false,
	}
	table.insert(self.cases, case)
	self:_pickPrompt(case, plate)
	return true
end

-- Hold E at the lock to pick it: a rattle every so often while you work,
-- heard nearby.
function ItemService:_pickPrompt(case, plate: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickPrompt"
	prompt.ActionText = "Pick the lock"
	prompt.ObjectText = "Display case"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = L.PickSeconds
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	local picking = {}
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if case.open or not self.PlayerState:CanAct(player) then
			return
		end
		local token = {}
		picking[player] = token
		task.spawn(function()
			local clicks = 0
			while picking[player] == token and not case.open and plate.Parent do
				clicks += 1
				Sfx.play("LockClick", plate.Position, 0.35, 1.6 + (clicks % 3) * 0.12)
				self.services.NoiseService:Emit(plate.Position, L.PickNoise, player, "pick")
				task.wait(L.PickRattle)
			end
		end)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		picking[player] = nil
	end)
	prompt.Triggered:Connect(function(player)
		picking[player] = nil
		local position = self.PlayerState:Position(player)
		if case.open or not position or (position - plate.Position).Magnitude > 9 then
			return
		end
		if not self.PlayerState:CanAct(player) then
			return
		end
		Sfx.play("LockClick", plate.Position, 0.6, 0.9)
		self.Furniture:SetLocked(case.piece, false)
		self.Furniture:SetOpen(case.piece, true)
		self:_openCase(case, player, "picked")
	end)
	case.prompt = prompt
end

-- Open: what's inside becomes something your hands can take.
function ItemService:_openCase(case, player: Player?, how: string)
	if case.open then
		return
	end
	case.open = true
	if case.prompt then
		case.prompt.Enabled = false
	end
	local at = case.felt.CFrame * case.offset
	if case.shown then
		case.shown:Destroy()
		case.shown = nil
	end
	if case.token then
		local state = self.heirlooms[case.token]
		if state then
			state.home.cframe = at
		end
		self:_make(case.token, at)
	else
		local figure = LeadProps.figurine(at, self.World.content)
		self.Hands:AddThing(figure, { class = "light", label = "Porcelain figure" })
	end
	self.CaseOpened:Fire(player, case, how)
end

-- Something thrown on its first arc, fast enough, through a case's glass.
function ItemService:_thrownMoved(thing, from: Vector3, to: Vector3)
	if #self.cases == 0 or not thing.thrower or thing.state ~= "flying" then
		return
	end
	local root = thing.root
	local speed = math.max(root and root.AssemblyLinearVelocity.Magnitude or 0, thing.lastSpeed or 0)
	if speed < L.SmashSpeed then
		return
	end
	-- The thing's middle stops short of the glass by its own half-size.
	if not thing.halfSize then
		local extents = thing.model:GetExtentsSize()
		thing.halfSize = math.max(extents.X, extents.Y, extents.Z) / 2
	end
	local pad = thing.halfSize + 0.15
	for _, case in self.cases do
		if not case.open and case.model.Parent then
			local cf, size = case.cover:GetBoundingBox()
			if Throw.segmentBox(from, to, cf, size, pad) and self.Hands:OnArc(thing, to) then
				self:_smash(case, thing.thrower, to)
				return
			end
		end
	end
end

function ItemService:_smash(case, by: Player?, at: Vector3)
	for _, p in case.cover:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	-- A few shards on the felt and the top around it.
	local rng = Rng.new(Rng.hash(case.id))
	local base = case.felt.CFrame * case.offset
	for _ = 1, 7 do
		local offset = Vector3.new(rng:NextNumber(-0.9, 0.9), 0.01, rng:NextNumber(-0.7, 0.7))
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Glass
		shard.Color = Color3.fromRGB(200, 214, 220)
		shard.Transparency = 0.5
		shard.Size = Vector3.new(rng:NextNumber(0.08, 0.25), 0.02, rng:NextNumber(0.06, 0.2))
		shard.CFrame = base * CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		shard.Parent = case.model
	end
	Sfx.play("GlassBreak", at, 0.9, 1)
	self.services.NoiseService:Emit(at, L.SmashNoise, by, "smash")
	self.Furniture:SetLocked(case.piece, true) -- the frame stays put
	self:_openCase(case, by, "smashed")
end

-- A key on a rack on a wall of its room (one rack a room).
function ItemService:_placeHook(token: string, room: number, rng): boolean
	local rack = self.racks[room]
	if not rack then
		local at = self:_wall(room, rng)
		if not at then
			return false
		end
		local model, hangs = LeadProps.keyRack(at, self.folder)
		rack = { model = model, hangs = hangs, used = 0 }
		self.racks[room] = rack
	end
	if rack.used >= #rack.hangs then
		return false
	end
	rack.used += 1
	self:_make(token, rack.hangs[rack.used])
	return true
end

-- A note in `noteRoom` saying where `token` is kept: lying on a top, else
-- pinned to a wall, else on the floor.
function ItemService:_placeNote(token: string, noteRoom: number, room: number, space, rng, used): boolean
	local onWall = false
	local at = self:_top(noteRoom, rng)
	if not at then
		at = self:_wall(noteRoom, rng)
		onWall = at ~= nil
	end
	if not at then
		local point = self.World:RandomPointIn(noteRoom, rng)
		at = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	local info = self.plan.tokens[token]
	local item = info.kind == "heirloom" and string.lower(self:Label(token)) or info.label
	local where = space and NoteText.place(space.prop.kind, space.group) or "plain sight"
	local template = NoteText.pick(rng, info.kind, used)
	local text = NoteText.write(template, { item = item, place = where, room = NoteText.roomPhrase(self.named, room) })
	local id = "note:" .. (#self.folder:GetChildren() + 1)
	local model, sheet = LeadProps.note(at, self.folder, onWall, rng:NextInteger(1, 2 ^ 30))
	model:SetAttribute("NoteId", id)
	local note = { id = id, token = token, text = text, room = noteRoom, model = model, sheet = sheet }
	self.notes[id] = note
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReadPrompt"
	prompt.ActionText = "Read"
	prompt.ObjectText = "Note"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = L.ReadRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = sheet
	prompt.Triggered:Connect(function(player)
		self:ReadNote(player, id)
	end)
	return true
end

-- Someone reads a note: its text goes to them alone.
function ItemService:ReadNote(player: Player, id: string)
	local note = self.notes[id]
	local position = self.PlayerState:Position(player)
	if not note or not position or not note.sheet.Parent then
		return
	end
	if (position - note.sheet.Position).Magnitude > L.ReadRange + 3 then
		return
	end
	Sfx.play("Cloth", note.sheet.Position, 0.25, 1.6)
	Net.get("NoteText"):FireClient(player, { id = id, text = note.text })
	self.NoteRead:Fire(player, note)
end

-- For F2 `leads`: how each token is found, and where the decoys are.
function ItemService:Leads()
	return self.leadOf, self.notes, self.cases
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

-- A key taken by hand goes on your ring.
function ItemService:_grabbed(player: Player, thing)
	local token = thing.model:GetAttribute("Item")
	local info = token and self.plan and self.plan.tokens[token]
	if not info then
		return
	end
	if not self.found[token] then
		self.found[token] = true
		self.services.DriftService:Apply("ItemFound")
		self.Found:Fire(player, token, info.kind)
	end
	if info.kind == "key" then
		local position = thing.model:GetPivot().Position
		self.Hands:Forget(thing, true)
		self.Locks:GiveKey(player, token, info.label)
		Sfx.play("Knock", position, 0.15, 2.2)
		notify(player, "You take the " .. info.label .. ".", "good")
	elseif info.kind == "heirloom" then
		local state = self.heirlooms[token]
		local first = state and state.everTaken ~= true
		if state then
			state.holder = player
			state.droppedAt = nil
			state.everTaken = true
		end
		if first then
			notify(
				player,
				"The " .. self:Label(token) .. ". It belongs at the table. Somewhere, a chair scrapes: he knows."
			)
		end
		self.HeirloomTaken:Fire(player, token)
	end
end

-- Keys from a ring that fell: scattered on the floor where its holder was.
function ItemService:DropKeys(player: Player, ring)
	if not self.plan then
		return
	end
	local position = self.PlayerState:Position(player)
	if not position then
		return
	end
	local floor = self.World:FloorBase(position.Y)
	local i = 0
	for token in ring do
		i += 1
		local angle = i * 2.1
		local at = CFrame.new(position.X + math.cos(angle) * 1.2, floor, position.Z + math.sin(angle) * 1.2)
			* CFrame.Angles(0, angle, 0)
		self:_make(token, at)
	end
end

return ItemService
