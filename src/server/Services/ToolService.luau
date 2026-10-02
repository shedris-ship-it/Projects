-- Primary tools (doc section 6): Witness Camera, Lantern, Radio, Plumb Line.
-- Also lights Lantern shrines, which make a room safe to rest in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Assets = require(Shared.Assets)
local Net = require(Shared.Net)
local Rng = require(Shared.Lib.Rng)

local PA = Constants.PlayerAttributes

local ToolService = {}

local lastUse: { [Player]: number } = {}
local lanterns: { [Player]: PointLight } = {}

function ToolService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.Witness = services.WitnessService
	self.World = services.WorldService
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
			shrine.prompt = prompt
		end
	end)
	Net.onServer("UseTool", { interval = 0.25, types = { "string?", "Vector3?" } }, function(player, targetId, position)
		self:Use(player, targetId, position)
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
		for _, player in self.PlayerState:ActivePlayers() do
			if player:GetAttribute(PA.Tool) == "Radio" then
				local signal = 0
				local pos = self.PlayerState:Position(player)
				if stalkerPos and pos then
					local distance = (stalkerPos - pos).Magnitude
					signal = math.clamp(1 - distance / Config.Tools.RadioRange, 0, 1)
				end
				local noise = (math.random() - 0.5) * 0.3 * (drift / 100)
				player:SetAttribute("RadioSignal", math.clamp(signal + noise, 0, 1))
			end
		end
	end)
end

function ToolService:BeginRun(players: { Player })
	local solo = #players == 1
	for _, player in players do
		local tool = player:GetAttribute(PA.Tool)
		player:SetAttribute(
			PA.Film,
			tool == "Camera" and (solo and Config.Tools.CameraFilmSolo or Config.Tools.CameraFilm) or 0
		)
		player:SetAttribute("RadioSignal", nil)
		lastUse[player] = nil
	end
end

function ToolService:EndRun()
	for player, light in lanterns do
		light:Destroy()
		lanterns[player] = nil
		if player.Parent then
			player:SetAttribute("LanternOn", false)
		end
	end
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

function ToolService:Use(player: Player, targetId, position)
	if not self.PlayerState:CanAct(player) then
		return
	end
	local tool = player:GetAttribute(PA.Tool)
	local root = self.PlayerState:Root(player)
	if not root then
		return
	end
	if tool == "Camera" then
		self:_camera(player, targetId, position)
	elseif tool == "Lantern" then
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
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < 10 then
			return
		end
		lastUse[player] = now
		local count = 0
		for _, site in self.services.AnomalyService:Sites() do
			if (site.position - root.Position).Magnitude < 32 then
				count += 1
			end
		end
		notify(
			player,
			count == 0 and "The radio hisses. Nothing wrong close by."
				or string.format(
					"The radio crackles: %d wrong thing%s within a room of you.",
					count,
					count == 1 and "" or "s"
				),
			"info"
		)
	elseif tool == "PlumbLine" then
		self:_plumb(player, root)
	end
end

function ToolService:_camera(player: Player, targetId, position)
	local film = player:GetAttribute(PA.Film) or 0
	if film <= 0 then
		notify(player, "Out of film.", "warning")
		return
	end
	local entry = self.Witness:Resolve(player, targetId, position)
	if not entry then
		notify(player, "Nothing worth a photo there.", "info")
		return
	end
	local head = self.PlayerState:Head(player)
	local targetPos = self.Witness.PositionOf(entry)
	if (targetPos - head.Position).Magnitude > Config.Tools.CameraRange then
		notify(player, "Too far for the camera.", "warning")
		return
	end
	player:SetAttribute(PA.Film, film - 1)
	self.services.NoiseService:Emit(head.Position, 12, player, "tool")
	local caption = self.services.AnomalyService:Photograph(player, entry)
	Net.get("PhotoResult")
		:FireClient(player, { label = entry.label, caption = caption, film = film - 1, sound = Assets.Sounds.Shutter })
end

function ToolService:_plumb(player: Player, root: BasePart)
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < Config.Tools.PlumbLineCooldown then
		notify(player, "The plumb line is still swinging.", "info")
		return
	end
	local confirmed = #self.services.CaseBoardService:ConfirmedTells()
	if confirmed < Config.Tools.PlumbLineMinConfirmed then
		notify(
			player,
			string.format("The plumb line won't settle. Confirm %d tells first.", Config.Tools.PlumbLineMinConfirmed),
			"warning"
		)
		return
	end
	local source = self.services.AnomalyService:SourcePosition()
	if not source then
		return
	end
	lastUse[player] = now
	local errorRange = Config.Tools.PlumbLineErrorDegrees
	local t = math.clamp((confirmed - 2) / 3, 0, 1)
	local maxError = errorRange[1] + (errorRange[2] - errorRange[1]) * t
	local rng = Rng.new(Rng.hash(player.UserId .. ":" .. math.floor(now)))
	local errorAngle = math.rad(rng:NextNumber(-maxError, maxError))
	local flat = Vector3.new(source.X - root.Position.X, 0, source.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		flat = Vector3.new(0, 0, -1)
	end
	local direction = (CFrame.Angles(0, errorAngle, 0) * flat.Unit)
	Net.get("PlumbLine"):FireAllClients({
		name = player.DisplayName,
		origin = root.Position,
		direction = direction,
		duration = 30,
	})
end

return ToolService
