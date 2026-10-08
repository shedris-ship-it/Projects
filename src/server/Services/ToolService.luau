-- Tools (doc section 6; owner, 2026-10-04): the Lantern and the Radio are
-- found around the house, not picked in the hub. Each player has four slots
-- (Logic/Inventory): slot 1 is the flashlight, always, 2 and 3 hold found
-- tools, 4 is bare hands, one thing in your hands at a time (anything but the
-- torch clips it to your shirt). This service owns the inventories, the
-- pickups lying on tables, what each tool does, and Lantern shrines (which
-- make a room safe to rest in). The Witness Camera and the Plumb Line
-- retired with the clue loop (R2c).
--
-- Players are told only the slot ids and which slot is in their hands;
-- `PA.Tool` stays "the tool in your hands now" so everything that reads it
-- (pings, the Radio signal) keeps working.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Tools = require(Shared.Data.Tools)
local Inventory = require(Shared.Logic.Inventory)
local Signal = require(Shared.Lib.Signal)
local ToolPlacement = require(Shared.Logic.ToolPlacement)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local Dressing = require(script.Parent.Parent.World.Dressing)
local ToolPickups = require(script.Parent.Parent.World.ToolPickups)

local PA = Constants.PlayerAttributes

local ToolService = {
	ShrineLit = Signal.new(), -- (shrine): the map redraws the room as lit
}

local lastUse: { [Player]: number } = {}
local shrineHolds: { [Player]: number } = {} -- a hold on a shrine with the Lantern in hand: when it began
local lanterns: { [Player]: PointLight } = {}
local inventories: { [Player]: any } = {}
local pickups: { [string]: { item: any, model: Model } } = {} -- uid -> the tool lying in the house
local nextUid = 0

function ToolService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.Witness = services.WitnessService
	self.World = services.WorldService
	self.found = {} -- tool id -> true once anyone has taken one this run (the map's ticks)
end

local function notify(player, text, kind)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

function ToolService:Start()
	self.World.Built:Connect(function(world)
		for _, shrine in world.shrines do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ShrinePrompt"
			prompt.ActionText = "Light the lantern"
			prompt.ObjectText = "Lantern shrine"
			prompt.HoldDuration = Config.Tools.LanternLightSecondsNoTool
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = shrine.glass
			prompt.Triggered:Connect(function(player)
				if self.PlayerState:CanAct(player) then
					self:LightShrine(shrine, player)
				end
			end)
			-- With the Lantern in hand it lights in LanternLightSeconds, not the
			-- bare-handed hold (the Lightkeeper's one real power).
			prompt.PromptButtonHoldBegan:Connect(function(player)
				local inv = inventories[player]
				if not inv or Inventory.toolId(inv) ~= "Lantern" then
					return
				end
				local began = os.clock()
				shrineHolds[player] = began
				task.delay(Config.Tools.LanternLightSeconds, function()
					if shrineHolds[player] == began and not shrine.lit and self.PlayerState:CanAct(player) then
						shrineHolds[player] = nil
						self:LightShrine(shrine, player)
					end
				end)
			end)
			prompt.PromptButtonHoldEnded:Connect(function(player)
				shrineHolds[player] = nil
			end)
			shrine.prompt = prompt
		end
	end)
	Net.onServer("UseTool", { interval = 0.25, types = { "string?", "Vector3?" } }, function(player)
		self:Use(player)
	end)
	Net.onServer("SelectSlot", { interval = 0.08, burst = 8, types = { "number" } }, function(player, slot)
		self:SelectSlot(player, slot)
	end)
	Net.onServer("DropItem", { interval = 0.4, types = {} }, function(player)
		self:DropHeld(player)
	end)
	-- A player who goes down, is lost or leaves the house leaves their tools behind
	-- for the squad to pick up.
	self.PlayerState.Downed:Connect(function(player)
		self:_dropAll(player)
	end)
	self.PlayerState.Lost:Connect(function(player)
		self:_dropAll(player)
	end)
	self.PlayerState.Extracted:Connect(function(player)
		self:_dropAll(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_dropAll(player)
		inventories[player] = nil
		lastUse[player] = nil
	end)

	-- Radio static: how close the stalker is, muddied by Drift.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local stalker = self.services.StalkerService
		local stalkerPos = stalker and stalker:GetPosition()
		local drift = self.services.DriftService:Value()
		for player in inventories do
			if player:GetAttribute(PA.Tool) == "Radio" and self.PlayerState:IsActive(player) then
				local signal = 0
				local pos = self.PlayerState:Position(player)
				if stalkerPos and pos then
					local distance = (stalkerPos - pos).Magnitude
					signal = math.clamp(1 - distance / Config.Tools.RadioRange, 0, 1)
				end
				local noise = (math.random() - 0.5) * 0.3 * (drift / 100)
				player:SetAttribute("RadioSignal", math.clamp(signal + noise, 0, 1))
			elseif player:GetAttribute("RadioSignal") ~= nil then
				-- Put away, dropped or downed: the static stops (the client plays
				-- it for as long as the attribute is there).
				player:SetAttribute("RadioSignal", nil)
			end
		end
	end)
end

function ToolService:BeginRun(players: { Player }, rng)
	for _, player in players do
		inventories[player] = Inventory.new()
		player:SetAttribute("RadioSignal", nil)
		lastUse[player] = nil
		self:_publish(player)
	end
	table.clear(self.found)
	self:_spawnWorldTools(rng, #players)
end

function ToolService:EndRun()
	for player, light in lanterns do
		light:Destroy()
		lanterns[player] = nil
		if player.Parent then
			player:SetAttribute("LanternOn", false)
		end
	end
	for uid, entry in pickups do
		entry.model:Destroy()
		pickups[uid] = nil
	end
	for player in inventories do
		inventories[player] = nil
		if player.Parent then
			for _, name in PA.Slots do
				player:SetAttribute(name, nil)
			end
			player:SetAttribute(PA.ActiveSlot, nil)
			player:SetAttribute(PA.Tool, nil)
			player:SetAttribute(PA.TorchClipped, nil)
			self.PlayerState:RefreshFlashlight(player)
		end
	end
end

-- Inventory ---------------------------------------------------------------------

-- Is the flashlight what's in this player's hands? True outside a run, where
-- there is no inventory to say otherwise.
function ToolService:TorchHeld(player: Player): boolean
	local inv = inventories[player]
	return inv == nil or Inventory.torchHeld(inv)
end

-- Is the torch clipped to their shirt (anything else in their hands)? The
-- light still works, as a weak short light where the body faces
-- (PlayerStateService picks the head beam or the clip light).
function ToolService:TorchClipped(player: Player): boolean
	local inv = inventories[player]
	return inv ~= nil and Inventory.torchClipped(inv)
end

-- Tell the player what they carry. Their hands drive everything else: the held
-- tool id, and a lit lantern going out when it's put away.
function ToolService:_publish(player: Player)
	local inv = inventories[player]
	if not inv then
		return
	end
	for slot, id in Inventory.ids(inv) do
		player:SetAttribute(PA.Slots[slot], id)
	end
	player:SetAttribute(PA.ActiveSlot, inv.active)
	local held = Inventory.toolId(inv)
	player:SetAttribute(PA.Tool, held)
	player:SetAttribute(PA.TorchClipped, Inventory.torchClipped(inv))
	self.PlayerState:RefreshFlashlight(player)
	local light = lanterns[player]
	if light and held ~= "Lantern" then
		light:Destroy()
		lanterns[player] = nil
		player:SetAttribute("LanternOn", false)
	end
end

function ToolService:SelectSlot(player: Player, slot)
	local inv = inventories[player]
	if not inv or type(slot) ~= "number" or not self.PlayerState:CanAct(player) then
		return
	end
	-- The light stays as it was: changing slots only moves the torch between
	-- your hand and your shirt (_publish). Whatever you carry is put down when
	-- your hand takes a tool (the torch, or an empty slot, leaves it free).
	if Inventory.select(inv, slot) then
		if Inventory.isToolSlot(slot) and inv.slots[slot] then
			self.services.HandsService:Release(player)
		end
		self:_publish(player)
	end
end

-- F on the keyboard: the light on or off, wherever the torch is (in your hand,
-- or clipped to your shirt while you hold something else).
function ToolService:OnFlashlightRequest(player: Player, on: boolean)
	self.PlayerState:SetFlashlight(player, on)
end

function ToolService:DropHeld(player: Player)
	local inv = inventories[player]
	if not inv or not self.PlayerState:CanAct(player) or not Inventory.isToolSlot(inv.active) then
		return
	end
	local item = Inventory.drop(inv, inv.active)
	if item then
		self:_putDown(player, item)
		self:_publish(player)
	end
end

-- The tool in this player's hands goes somewhere else (down the laundry
-- chute): out of their slots, lying at `cframe`. Returns its id, or nil
-- when their hands hold no found tool.
function ToolService:SendHeld(player: Player, cframe: CFrame): string?
	local inv = inventories[player]
	if not inv or not Inventory.isToolSlot(inv.active) then
		return nil
	end
	local item = Inventory.drop(inv, inv.active)
	if not item then
		return nil
	end
	self:_makePickup(item, cframe, 0)
	self:_publish(player)
	return item.id
end

function ToolService:_dropAll(player: Player)
	local inv = inventories[player]
	if not inv then
		return
	end
	for _, item in Inventory.dropAll(inv) do
		self:_putDown(player, item)
	end
	self:_publish(player)
end

-- World pickups -----------------------------------------------------------------

local function newUid(): string
	nextUid += 1
	return "tool:" .. nextUid
end

-- Leave a tool lying somewhere: `cframe` is on the surface, `yaw` turns it.
function ToolService:_makePickup(item, cframe: CFrame, yaw: number)
	local folder = self.World.content
	if not folder then
		return
	end
	local holder = folder:FindFirstChild("ToolPickups")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "ToolPickups"
		holder.Parent = folder
	end
	local uid = item.uid
	local model = ToolPickups.make(holder, item, cframe, yaw, function(player)
		self:_take(player, uid)
	end)
	if model then
		pickups[uid] = { item = item, model = model }
	end
end

-- Where a put-down tool lands: on the floor a stride in front of the player,
-- stopping short of a wall.
function ToolService:_putDown(player: Player, item)
	local root = self.PlayerState:Root(player)
	if not root then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local feet = root.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	forward = forward.Magnitude > 0.1 and forward.Unit or Vector3.new(0, 0, -1)
	local reach = 2
	-- Several heights, so a bench or a chest below waist height stops it too (a
	-- single ray from the middle of the body passes over them).
	for _, height in { 0.4, 1.4, 2.6, (root.Position.Y - feet.Y) } do
		local hit = Workspace:Raycast(feet + Vector3.new(0, height, 0), forward * reach, params)
		if hit then
			reach = math.min(reach, math.max(0.4, hit.Distance - 0.5))
		end
	end
	-- Onto whatever floor is under that spot (a stair's slope, the gallery);
	-- over the void beside the gallery, at your feet instead.
	local point = feet + forward * reach
	local floor = Workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), params)
	if floor then
		point = floor.Position
	else
		point = feet
	end
	local spot = CFrame.new(point)
	self:_makePickup(item, spot, Rng.new(Rng.hash(item.uid)):NextNumber(0, math.pi * 2))
	Sfx.play("Cloth", root.Position, 0.5, 1)
	self.services.NoiseService:Emit(root.Position, 6, player, "tool")
end

function ToolService:_take(player: Player, uid: string)
	local entry = pickups[uid]
	local inv = inventories[player]
	if not entry or not inv or not self.PlayerState:CanAct(player) then
		return
	end
	local root = self.PlayerState:Root(player)
	local head = self.PlayerState:Head(player)
	local hit = entry.model.PrimaryPart
	if not root or not head or not hit or (root.Position - hit.Position).Magnitude > Config.Tools.PickupRange then
		return
	end
	-- A tool in the next room can't be taken through the wall (the prompt has no
	-- line-of-sight rule of its own, so the server holds it).
	if not self.Witness:ClearLine(head.Position, hit.Position + Vector3.new(0, 0.3, 0), { entry.model }) then
		return
	end
	local ok, slot, swapped = Inventory.pickup(inv, entry.item)
	if not ok then
		notify(player, "Your hands are full. Hold a tool to swap it, or press X to put one down.", "warning")
		return
	end
	pickups[uid] = nil
	self.found[entry.item.id] = true
	entry.model:Destroy()
	if swapped then
		self:_putDown(player, swapped)
	end
	self:_publish(player)
	local info = Tools.ById[entry.item.id]
	notify(
		player,
		string.format("Took the %s (slot %d). Press %d to hold it.", info and info.name or entry.item.id, slot, slot),
		"good"
	)
	Sfx.play("Cloth", root.Position, 0.5, 1.1)
end

-- Leave the house's tools on its tables: one of each, plus the extras bigger
-- squads get (Config.Tools), each on a piece of furniture it makes sense on, in
-- rooms spread across the house, from the seeded `rng`.
function ToolService:_spawnWorldTools(rng, squadSize: number)
	local world = self.World.World
	if not world or not rng then
		return
	end
	local start
	for id, record in world.rooms do
		if record.role == "start" then
			start = id
		end
	end
	local distances = start and self.World:Distances(start) or {}
	local surfaces = ToolPickups.surfaces(world, distances)
	local supply = ToolPlacement.supply(squadSize, Tools.Supply, Config.Tools)
	local placed = ToolPlacement.plan(rng, surfaces, supply, Tools.Homes, Config.Tools)
	for _, entry in placed do
		local spot = Dressing.claim(entry.surface.source)
		if spot then
			local item = { id = entry.tool, uid = newUid() }
			self:_makePickup(item, spot, rng:NextNumber(-0.5, 0.5))
		end
	end
end

-- The tools the escape plan needs (the crowbar and the bolt cutters for
-- tool locks: Logic/ToolLocks, docs/plans/level-design.md section 11, L3.3),
-- lying in plain sight on a top in the room the plan keeps them in (one it
-- makes sense on first), else on that room's floor.
function ToolService:PlacePlanned(plan, rng)
	local world = self.World.World
	if not world or not plan then
		return
	end
	local surfaces = ToolPickups.surfaces(world, {})
	local ids = {}
	for id, token in plan.tokens do
		if token.kind == "tool" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		local token = plan.tokens[id]
		local room = token.producer.room
		local homes, any = {}, {}
		for _, surface in surfaces do
			if surface.room == room and surface.free > 0 then
				table.insert(any, surface)
				if table.find(Tools.Homes[token.tool] or {}, surface.kind) then
					table.insert(homes, surface)
				end
			end
		end
		local pool = #homes > 0 and homes or any
		local spot = #pool > 0 and Dressing.claim(rng:Pick(pool).source) or nil
		if not spot then
			spot = CFrame.new(self.World:RandomPointIn(room, rng))
		end
		self:_makePickup({ id = token.tool, uid = newUid() }, spot, rng:NextNumber(-0.5, 0.5))
	end
end

-- F2 `give tool:Crowbar`: the house's one into your inventory, from wherever
-- it lies. Returns what happened.
function ToolService:DebugGive(player: Player, toolId: string): string
	local inv = inventories[player]
	for uid, entry in pickups do
		if entry.item.id == toolId and inv then
			local ok, _, swapped = Inventory.pickup(inv, entry.item)
			if not ok then
				return "your hands are full"
			end
			pickups[uid] = nil
			self.found[toolId] = true
			entry.model:Destroy()
			if swapped then
				self:_putDown(player, swapped)
			end
			self:_publish(player)
			return "in your inventory: " .. toolId
		end
	end
	-- None lying about (the salts, a tool the run didn't place): made from nothing.
	if inv and Tools.ById[toolId] then
		local ok, _, swapped = Inventory.pickup(inv, { id = toolId, uid = newUid() })
		if not ok then
			return "your hands are full"
		end
		self.found[toolId] = true
		if swapped then
			self:_putDown(player, swapped)
		end
		self:_publish(player)
		return "in your inventory: " .. toolId .. " (made)"
	end
	return "no " .. toolId .. " lying in the house"
end

-- A tool lying at `cframe` for anyone to take (the safe room's).
function ToolService:PlaceTool(toolId: string, cframe: CFrame)
	self:_makePickup({ id = toolId, uid = newUid() }, cframe, 0)
end

-- Spend a tool from any slot (the salts): gone, not dropped. Whether one was carried.
function ToolService:Consume(player: Player, toolId: string): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end
	for _, slot in Inventory.TOOL_SLOTS do
		local item = inv.slots[slot]
		if item and item.id == toolId then
			Inventory.drop(inv, slot)
			self:_publish(player)
			return true
		end
	end
	return false
end

-- Does this player carry this tool, in any slot?
function ToolService:Carries(player: Player, toolId: string): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end
	for _, id in Inventory.ids(inv) do
		if id == toolId then
			return true
		end
	end
	return false
end

-- Who carries this tool now, if anyone.
function ToolService:Holder(toolId: string): Player?
	for player in inventories do
		if player.Parent and self:Carries(player, toolId) then
			return player
		end
	end
	return nil
end

function ToolService:LightShrine(shrine, player: Player?)
	if shrine.lit then
		return
	end
	shrine.lit = true
	shrine.light.Enabled = true
	shrine.glass.Material = Enum.Material.Neon
	shrine.glass:SetAttribute("Lit", true)
	if shrine.prompt then
		shrine.prompt.Enabled = false
	end
	self.ShrineLit:Fire(shrine)
	local room = self.World:Room(shrine.roomId)
	Net.get("Notify"):FireAllClients(
		string.format(
			"%sThe %s is a Lantern room now: rest there, it can't start a hunt on you.",
			player and (player.DisplayName .. " lit a lantern. ") or "",
			room and room.name or "room"
		),
		"good"
	)
end

local function nearestShrine(world, position: Vector3, radius: number)
	local best, bestDistance = nil, radius
	for _, shrine in world.shrines do
		local d = (shrine.glass.Position - position).Magnitude
		if not shrine.lit and d <= bestDistance then
			best, bestDistance = shrine, d
		end
	end
	return best
end

function ToolService:Use(player: Player)
	if not self.PlayerState:CanAct(player) then
		return
	end
	local tool = player:GetAttribute(PA.Tool)
	local root = self.PlayerState:Root(player)
	if not root then
		return
	end
	if tool == "Lantern" then
		local shrine = self.World.World and nearestShrine(self.World.World, root.Position, 10)
		if shrine then
			self:LightShrine(shrine, player)
			return
		end
		local light = lanterns[player]
		if light and light.Parent then
			light:Destroy()
			lanterns[player] = nil
			player:SetAttribute("LanternOn", false)
		else
			light = Instance.new("PointLight")
			light.Name = "Lantern"
			light.Range = 24
			light.Brightness = 1.3
			light.Color = Color3.fromRGB(255, 196, 120)
			light.Shadows = true
			light.Parent = root
			lanterns[player] = light
			player:SetAttribute("LanternOn", true)
		end
	elseif tool == "Radio" then
		-- Listening hard: how loud the static is says how near he is.
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < 4 then
			return
		end
		lastUse[player] = now
		local signal = player:GetAttribute("RadioSignal") or 0
		notify(
			player,
			signal > 0.6 and "The static roars. He's very close."
				or signal > 0.25 and "The static rises and falls. He's somewhere near."
				or "Only a faint hiss. He's far off, for now.",
			"info"
		)
	end
end

return ToolService
