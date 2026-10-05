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
end

function ItemService:Start()
	self.Furniture.Filler = function(space, at)
		return self:_fill(space, at)
	end
	self.Hands.Grabbed:Connect(function(player, thing)
		self:_grabbed(player, thing)
	end)
	self.World.Cleared:Connect(function()
		self.plan = nil
		table.clear(self.bySpace)
		table.clear(self.heirloomKinds)
		table.clear(self.found)
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
			if #spaces > 0 then
				self.bySpace[rng:Pick(spaces)] = id
			else
				-- Nowhere to keep it: lying on the floor in that room.
				local at = self.World:RandomPointIn(room, rng)
				self:_make(id, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
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
	local folder = self.World.folder
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
	return model, thing
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
		self.Found:Fire(player, token, info.kind)
	end
	if info.kind == "key" then
		local position = thing.model:GetPivot().Position
		self.Hands:Forget(thing, true)
		self.Locks:GiveKey(player, token, info.label)
		Sfx.play("Knock", position, 0.15, 2.2)
		notify(player, "You take the " .. info.label .. ".", "good")
	elseif info.kind == "heirloom" then
		notify(player, "The " .. self:Label(token) .. ". It belongs at the table.")
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
