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
-- The heirlooms are his (R2c, "the Guest wants his dinner"): this keeps each
-- one's state (who holds it, since when it lies about, whether it's set) for
-- his scent (Logic/Scent, StalkerService), and its home: where it was kept,
-- so he can put it back (`Tidy`). Later producers (a safe, the music box)
-- give their own homes with SetHome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Sfx = require(Shared.Lib.Sfx)
local Signal = require(Shared.Lib.Signal)

local Items = require(script.Parent.Parent.World.Items)

local ItemService = {
	-- (player, token, kind): someone found something the escape needs.
	Found = Signal.new(),
	-- (player, token): someone picked an heirloom up (every time).
	HeirloomTaken = Signal.new(),
	-- (token): an heirloom left someone's hands.
	HeirloomDropped = Signal.new(),
	-- (token, label): he put one back where it was kept.
	Tidied = Signal.new(),
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
	self.World.Cleared:Connect(function()
		self.plan = nil
		table.clear(self.bySpace)
		table.clear(self.heirloomKinds)
		table.clear(self.found)
		table.clear(self.heirlooms)
	end)
end

-- Where each kept thing goes: a drawer or cupboard in its room.
function ItemService:Begin(plan, rng)
	self.plan = plan
	table.clear(self.bySpace)
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
			local spaces = {}
			for _, space in self.Furniture.spaces do
				if space.prop.roomId == room and not space.filled and not self.bySpace[space] then
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
			else
				-- Nowhere to keep it: lying on the floor in that room.
				local at = self.World:RandomPointIn(room, rng)
				local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				if state then
					state.home.cframe = cf
				end
				self:_make(id, cf)
			end
		end
	end
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
function ItemService:_fill(space, at: CFrame)
	local token = self.bySpace[space]
	if not token or not self.plan then
		return nil
	end
	self.bySpace[space] = nil
	return self:_make(token, at)
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
