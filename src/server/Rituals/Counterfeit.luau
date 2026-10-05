-- Counterfeit — "Cross-check" (doc section 4).
--
-- Four identical keys appear around the house. Each Witness reads a
-- description on every key; the genuine key reads the same to everyone,
-- copies read differently to each Witness. The squad compares descriptions,
-- carries the genuine key to the Source strongbox, and turns it with every
-- active Witness present. A copy crumbles, spikes Drift and rings out
-- through the house (the stalker twist).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Joint = require(Shared.Lib.Joint)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)
local Rng = require(Shared.Lib.Rng)
local PropFactory = require(Shared.World.PropFactory)

local KEY_COUNT = 4
local GATHER_RADIUS = 24

local METALS = { "Brass", "Iron", "Silver", "Copper" }
local TAGS = { "CELLAR", "ATTIC", "ROOM 4", "STUDY", "GARAGE", "NURSERY" }
local TEETH = { "two teeth", "three teeth", "four teeth" }

local Ritual = {}
Ritual.__index = Ritual

local function describe(metal, tagText, teeth)
	return string.format("%s key · tag '%s' · %s", metal, tagText, teeth)
end

function Ritual.prepare(ctx)
	local services = ctx.services
	local worldService = services.WorldService
	local world = worldService.World
	local rng = ctx.rng:Fork("crosscheck")
	local layout = world.layout
	local distances = worldService:Distances(layout.start)
	local rooms = {}
	for id in world.rooms do
		if id ~= layout.start and id ~= layout.exit then
			table.insert(rooms, id)
		end
	end
	table.sort(rooms, function(a, b)
		if distances[a] ~= distances[b] then
			return (distances[a] or 0) > (distances[b] or 0)
		end
		return a < b
	end)
	-- Strongbox among the farther half of the house.
	local far = {}
	for i = 1, math.max(1, math.floor(#rooms / 2)) do
		table.insert(far, rooms[i])
	end
	local boxRoom = rng:Pick(far)
	local boxSlot = worldService:TakeFloorSlot(boxRoom, rng)
	local keySlots = {}
	local others = {}
	for _, id in rooms do
		if id ~= boxRoom then
			table.insert(others, id)
		end
	end
	rng:Shuffle(others)
	for _, id in others do
		if #keySlots >= KEY_COUNT then
			break
		end
		local slot = worldService:TakeFloorSlot(id, rng)
		if slot then
			table.insert(keySlots, { cframe = slot.cframe, roomId = id })
		end
	end
	local genuineLabel = describe(rng:Pick(METALS), rng:Pick(TAGS), rng:Pick(TEETH))
	return {
		position = boxSlot and boxSlot.position or world.rooms[boxRoom].center,
		boxCFrame = boxSlot and boxSlot.cframe or CFrame.new(world.rooms[boxRoom].center),
		boxRoom = boxRoom,
		keySlots = keySlots,
		genuine = rng:NextInteger(1, #keySlots),
		genuineLabel = genuineLabel,
	}
end

function Ritual.new(ctx, source)
	return setmetatable({
		ctx = ctx,
		source = source,
		progress = 0,
		done = false,
		text = "Cross-check: find the key that reads the same to every Witness. Bring it to the glowing strongbox, together.",
		Completed = Signal.new(),
		keys = {},
		carriers = {}, -- player -> key
		connections = {},
	}, Ritual)
end

function Ritual:_services()
	return self.ctx.services
end

-- A different random description for each Witness and copy.
function Ritual:_labelFor(player: Player, key)
	if key.genuine then
		return self.source.genuineLabel
	end
	local rng = Rng.new(Rng.hash(player.UserId .. ":" .. key.id .. ":" .. self.ctx.rng.Seed))
	local label
	repeat
		label = describe(rng:Pick(METALS), rng:Pick(TAGS), rng:Pick(TEETH))
	until label ~= self.source.genuineLabel
	return label
end

function Ritual:_sendLabels(player: Player)
	local labels = {}
	local solo = #self.ctx.players == 1
	for _, key in self.keys do
		if key.revealed then
			labels[key.id] = {
				label = key.genuine and ("GENUINE · " .. self.source.genuineLabel)
					or "COPY · it reads differently to each of you",
			}
		elseif solo and not key.genuine then
			-- Nobody to compare with: a copy's description won't hold still.
			local shift = {}
			for i = 1, 3 do
				local rng = Rng.new(Rng.hash(player.UserId .. key.id .. i))
				table.insert(shift, describe(rng:Pick(METALS), rng:Pick(TAGS), rng:Pick(TEETH)))
			end
			labels[key.id] = { label = shift[1], shift = shift }
		else
			labels[key.id] = { label = self:_labelFor(player, key) }
		end
	end
	Net.get("ItemLabels"):FireClient(player, labels)
end

function Ritual:_broadcastLabels()
	for _, player in self.ctx.players do
		if player.Parent then
			self:_sendLabels(player)
		end
	end
end

function Ritual:_setKeyVisible(key, visible: boolean, cframe: CFrame?)
	if cframe then
		key.part.CFrame = cframe
	end
	key.part.Transparency = visible and 0 or 1
	key.part.CanQuery = visible
	key.prompt.Enabled = visible
	key.light.Enabled = visible
end

function Ritual:Start()
	local services = self:_services()
	local folder = self.ctx.folder
	-- The Source strongbox.
	local boxModel = PropFactory.build(
		"Chest",
		self.source.boxCFrame,
		folder,
		{ name = "SourceStrongbox", color = Color3.fromRGB(60, 50, 44) }
	)
	local lock = PropFactory.part(
		boxModel,
		"Lock",
		Vector3.new(0.9, 0.9, 0.3),
		self.source.boxCFrame * CFrame.new(0, 2.2, 1.65),
		Color3.fromRGB(255, 150, 60),
		PropFactory.material("Neon"),
		{ collide = false }
	)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 60)
	glow.Range = 16
	glow.Brightness = 2
	glow.Parent = lock
	local unlock = Instance.new("ProximityPrompt")
	unlock.ActionText = "Turn the key"
	unlock.ObjectText = "Strongbox"
	unlock.HoldDuration = 1.5
	unlock.MaxActivationDistance = 8
	unlock.RequiresLineOfSight = false
	unlock.Parent = lock
	unlock.Triggered:Connect(function(player)
		self:_tryUnlock(player)
	end)
	self.box = { model = boxModel, lock = lock, glow = glow }
	services.WitnessService:Register("source", {
		kind = "source",
		position = lock.Position,
		label = "Strongbox",
		radius = 5,
	})

	-- The keys.
	for i, slot in self.source.keySlots do
		local cf = slot.cframe * CFrame.new(0, 3, 0)
		local part = PropFactory.part(
			folder,
			"Key",
			Vector3.new(0.4, 1.4, 0.15),
			cf,
			Color3.fromRGB(205, 170, 90),
			PropFactory.material("Metal"),
			{ collide = false }
		)
		local id = "item:" .. i
		part:SetAttribute(Constants.Attributes.CId, id)
		part:SetAttribute(Constants.Attributes.Label, "Key")
		game:GetService("CollectionService"):AddTag(part, Constants.Tags.Item)
		local light = Instance.new("PointLight")
		light.Range = 6
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 220, 140)
		light.Parent = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up"
		prompt.ObjectText = "Key"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		local key =
			{ id = id, part = part, prompt = prompt, light = light, home = cf, genuine = i == self.source.genuine }
		prompt.Triggered:Connect(function(player)
			self:_pickUp(player, key)
		end)
		table.insert(self.keys, key)
		services.WitnessService:Register(id, {
			kind = "item",
			position = function()
				return key.part.Position
			end,
			label = "Key",
			radius = 4,
			divergent = true,
		})
	end
	table.insert(
		self.connections,
		services.WitnessService.Anchored:Connect(function(id)
			for _, key in self.keys do
				if key.id == id and not key.revealed then
					key.revealed = true
					Net.get("Notify"):FireAllClients(
						key.genuine and "Anchored: that key is GENUINE." or "Anchored: that key is a COPY.",
						key.genuine and "good" or "warning"
					)
					self:_broadcastLabels()
				end
			end
		end)
	)
	self:_broadcastLabels()
end

function Ritual:_drop(player: Player, at: Vector3?)
	local key = self.carriers[player]
	if not key then
		return
	end
	self.carriers[player] = nil
	player:SetAttribute(Constants.PlayerAttributes.Carrying, nil)
	local cf = at and CFrame.new(at + Vector3.new(0, 1, 0)) or key.home
	self:_setKeyVisible(key, true, cf)
end

function Ritual:_pickUp(player: Player, key)
	local services = self:_services()
	if not services.PlayerStateService:CanAct(player) or self.done then
		return
	end
	if self.carriers[player] then
		self:_drop(player, services.PlayerStateService:Position(player))
	end
	self.carriers[player] = key
	player:SetAttribute(Constants.PlayerAttributes.Carrying, key.id)
	self:_setKeyVisible(key, false)
	if not key.genuine then
		-- Stalker twist: a copy rings out through the house.
		services.NoiseService:Emit(key.part.Position, 45, player, "lure")
	end
end

function Ritual:_tryUnlock(player: Player)
	local services = self:_services()
	if self.done or not services.PlayerStateService:CanAct(player) then
		return
	end
	local key = self.carriers[player]
	if not key then
		Net.get("Notify"):FireClient(player, "You need a key.", "warning")
		return
	end
	local missing = 0
	for _, other in services.PlayerStateService:ActivePlayers() do
		local pos = services.PlayerStateService:Position(other)
		if not pos or not services.WorldService:Together(pos, self.box.lock.Position, GATHER_RADIUS) then
			missing += 1
		end
	end
	if missing > 0 then
		Net.get("Notify"):FireAllClients(
			string.format("The lock won't turn until every Witness is here (%d missing).", missing),
			"warning"
		)
		return
	end
	self.carriers[player] = nil
	player:SetAttribute(Constants.PlayerAttributes.Carrying, nil)
	if key.genuine then
		self.done = true
		self.progress = 1
		self.text = "The strongbox opens. Whatever was in it is gone."
		self.box.lock.Color = Color3.fromRGB(180, 230, 255)
		self.box.glow.Color = Color3.fromRGB(180, 230, 255)
		-- The lid is a piece on its hinge (World/PropFactory, Lib/Joint).
		local lid = self.box.model:FindFirstChild("Lid")
		local primary = lid and lid:IsA("Model") and lid.PrimaryPart
		local joint = primary and Joint.read(primary)
		if primary and joint then
			local open = Joint.pose(joint, 70)
			for _, p in lid:GetDescendants() do
				if p:IsA("BasePart") then
					TweenService:Create(p, TweenInfo.new(1), { CFrame = open * primary.CFrame:ToObjectSpace(p.CFrame) })
						:Play()
				end
			end
		end
		self.Completed:Fire()
	else
		key.part:Destroy()
		for i, k in self.keys do
			if k == key then
				table.remove(self.keys, i)
				break
			end
		end
		services.WitnessService:Unregister(key.id)
		services.DriftService:Apply("CounterfeitUsed")
		services.NoiseService:Emit(self.box.lock.Position, 45, player, "lure")
		Net.get("Notify"):FireAllClients("The key crumbles to rust in the lock. A copy.", "danger")
	end
end

function Ritual:Update()
	-- Downed or Lost carriers drop what they hold.
	local services = self:_services()
	for player, _ in self.carriers do
		if not player.Parent then
			self:_drop(player)
		elseif not services.PlayerStateService:IsActive(player) then
			self:_drop(player, services.PlayerStateService:Position(player))
		end
	end
end

function Ritual:SyncPlayer(player: Player)
	self:_sendLabels(player)
end

function Ritual:Photograph(_, entry)
	for _, key in self.keys do
		if key.id == entry.id then
			return key.genuine and "In the photo the key looks exactly as you see it. Genuine."
				or "In the photo the key is a smear of rust. A copy."
		end
	end
	if entry.id == "source" then
		return "The photo shows the strongbox, and a keyhole that isn't quite there."
	end
	return nil
end

function Ritual:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	for player in self.carriers do
		if player.Parent then
			player:SetAttribute(Constants.PlayerAttributes.Carrying, nil)
		end
	end
	self.carriers = {}
	local witness = self:_services().WitnessService
	witness:Unregister("source")
	for _, key in self.keys do
		witness:Unregister(key.id)
	end
end

return Ritual
