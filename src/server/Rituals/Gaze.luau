-- Gaze — "Stare-down" (doc section 4).
--
-- One of the house's portraits is the Source. When the ritual begins its eyes
-- burn red. Every active Witness must hold their eyes on it at the same time;
-- the stare builds while everyone looks and slips while anyone looks away.
-- Meanwhile the stalker's final hunt comes for your backs — and staring at
-- the portrait means nobody is watching it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)
local PropFactory = require(Shared.World.PropFactory)

local REQUIRED_SECONDS = 25
local LOOK_CONE = 34
local LOOK_RANGE = 55

local Ritual = {}
Ritual.__index = Ritual

function Ritual.prepare(ctx)
	local rng = ctx.rng:Fork("staredown")
	local portrait = rng:Pick(ctx.portraits)
	if not portrait then
		-- No decorative portraits fit; hang one in the farthest room.
		local worldService = ctx.services.WorldService
		local world = worldService.World
		local distances = worldService:Distances(world.layout.start)
		local best, bestDistance = nil, -1
		for id in world.rooms do
			if (distances[id] or 0) > bestDistance and id ~= world.layout.exit then
				best, bestDistance = id, distances[id] or 0
			end
		end
		local slot = worldService:TakeWallSlot(best, rng)
		local cf = slot and slot.cframe or CFrame.new(world.rooms[best].center + Vector3.new(0, 6, 0))
		local model = PropFactory.buildTellBase("Portrait", cf, ctx.folder)
		portrait = {
			id = "portrait:source",
			model = model,
			cframe = cf,
			position = cf.Position + cf.LookVector * 0.4,
			roomId = best,
		}
	end
	return {
		position = portrait.position,
		portrait = portrait,
	}
end

function Ritual.new(ctx, source)
	return setmetatable({
		ctx = ctx,
		source = source,
		progress = 0,
		seconds = 0,
		done = false,
		text = nil,
		Completed = Signal.new(),
	}, Ritual)
end

function Ritual:Start()
	local portrait = self.source.portrait
	for _, name in { "EyeL", "EyeR" } do
		local eye = portrait.model:FindFirstChild(name)
		if eye then
			eye.Material = Enum.Material.Neon
			eye.Color = Color3.fromRGB(255, 40, 30)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 60, 40)
			light.Range = 10
			light.Brightness = 1.5
			light.Parent = eye
		end
	end
	self.ctx.services.WitnessService:Register("source", {
		kind = "source",
		position = portrait.position,
		label = "The portrait",
		radius = 4,
	})
	local room = self.ctx.services.WorldService:Room(portrait.roomId)
	Net.get("RitualState"):FireAllClients({
		anomaly = "Gaze",
		position = portrait.position,
		room = room and room.name or "?",
	})
	self.text =
		string.format("Stare-down: all eyes on the portrait in the %s. Don't look away.", room and room.name or "house")
end

function Ritual:Update(dt: number)
	if self.done then
		return
	end
	local services = self.ctx.services
	local active = services.PlayerStateService:ActivePlayers()
	if #active == 0 then
		return
	end
	local looking = 0
	for _, player in active do
		if
			services.WitnessService:IsLookingAt(
				player,
				self.source.portrait.position,
				LOOK_CONE,
				LOOK_RANGE,
				{ self.source.portrait.model }
			)
		then
			looking += 1
		end
	end
	if looking == #active then
		self.seconds = math.min(REQUIRED_SECONDS, self.seconds + dt)
	else
		self.seconds = math.max(0, self.seconds - dt * 0.5)
	end
	self.progress = self.seconds / REQUIRED_SECONDS
	self.text = string.format("Stare-down: %d/%d Witnesses holding the portrait's gaze.", looking, #active)
	if self.seconds >= REQUIRED_SECONDS then
		self.done = true
		self.progress = 1
		self.text = "The portrait's eyes close."
		for _, name in { "EyeL", "EyeR" } do
			local eye = self.source.portrait.model:FindFirstChild(name)
			if eye then
				eye.Color = Color3.fromRGB(20, 16, 14)
				eye.Material = Enum.Material.SmoothPlastic
				local light = eye:FindFirstChildOfClass("PointLight")
				if light then
					light:Destroy()
				end
			end
		end
		self.Completed:Fire()
	end
end

function Ritual:SyncPlayer(player: Player)
	if not self.done then
		Net.get("RitualState"):FireClient(player, { anomaly = "Gaze", position = self.source.portrait.position })
	end
end

function Ritual:Photograph(_, entry)
	if entry.id == "source" then
		return "In the photo the portrait is looking straight at the camera."
	end
	return nil
end

function Ritual:Destroy()
	self.ctx.services.WitnessService:Unregister("source")
end

return Ritual
