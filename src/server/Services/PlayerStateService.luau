-- Per-Witness run state: Active, Downed, Lost (an Echo) or Extracted (doc
-- section 2, "Win, lose and getting caught"). Also tracks isolation for
-- Drift, movement noise, the flashlight and its battery, and AFK removal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Net)
local Sfx = require(Shared.Lib.Sfx)

local States = Constants.PlayerStates
local PA = Constants.PlayerAttributes

local PlayerStateService = {
	Downed = Signal.new(),
	Revived = Signal.new(),
	Lost = Signal.new(),
	Extracted = Signal.new(),
	StateChanged = Signal.new(),
}

local records: { [Player]: any } = {}

function PlayerStateService:Init(services)
	self.services = services
	self.Noise = services.NoiseService
	self.World = services.WorldService
	self.inRun = false
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

local function setGroup(character: Model, group: string)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

function PlayerStateService:_record(player: Player)
	local record = records[player]
	if not record then
		record = {
			player = player,
			state = States.Lobby,
			inRun = false,
			flashlight = false,
			battery = Config.Player.FlashlightBatterySeconds,
			lastActive = os.clock(),
			lastSprintNoise = 0,
			lastHint = -math.huge,
		}
		records[player] = record
	end
	return record
end

function PlayerStateService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_record(player)
		player:SetAttribute(PA.State, States.Lobby)
		player.CharacterAdded:Connect(function(character)
			self:_onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		self:_record(player)
		player:SetAttribute(PA.State, States.Lobby)
		player.CharacterAdded:Connect(function(character)
			self:_onCharacter(player, character)
		end)
		if player.Character then
			self:_onCharacter(player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local record = records[player]
		records[player] = nil
		if record and record.inRun then
			self.StateChanged:Fire(player, "Left")
		end
	end)

	Net.onServer("SetFlashlight", { interval = 0.15, types = { "boolean" } }, function(player, on)
		-- Through ToolService, which knows where the torch is (hand or shirt).
		self.services.ToolService:OnFlashlightRequest(player, on == true)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0
		self:_tick(step)
	end)
end

function PlayerStateService:_onCharacter(player: Player, character: Model)
	setGroup(character, Constants.CollisionGroups.Players)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			local record = records[player]
			d.CollisionGroup = (record and record.state == States.Lost) and Constants.CollisionGroups.Echo
				or Constants.CollisionGroups.Players
		end
	end)
	local head = character:WaitForChild("Head", 10)
	if head and not head:FindFirstChild("Flashlight") then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Angle = 50
		light.Range = 42
		light.Brightness = 2.4
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Face = Enum.NormalId.Front
		light.Enabled = false
		light.Parent = head
	end
	-- The torch clipped to your shirt while your hands hold something else
	-- (docs/plans/gameplay-rework.md section 4.1): weak and short, pointing
	-- where your body faces.
	local torso = character:WaitForChild("UpperTorso", 10) or character:FindFirstChild("Torso")
	if torso and not torso:FindFirstChild("ClipLight") then
		local clip = Config.Hands.ClipLight
		local light = Instance.new("SpotLight")
		light.Name = "ClipLight"
		light.Angle = clip.Angle
		light.Range = clip.Range
		light.Brightness = clip.Brightness
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Face = Enum.NormalId.Front
		light.Enabled = false
		light.Parent = torso
	end
	local record = self:_record(player)
	record.flashlight = false
	player:SetAttribute(PA.Flashlight, false)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.WalkSpeed = Config.Player.WalkSpeed
		humanoid.JumpHeight = Config.Player.JumpHeight
		if record.state == States.Lost then
			task.defer(function()
				self:_applyEcho(player)
			end)
		elseif record.state == States.Downed then
			humanoid.WalkSpeed = Config.Run.DownedCrawlSpeed
		end
	end
end

-- Accessors ---------------------------------------------------------------

function PlayerStateService:Get(player: Player)
	return records[player]
end

function PlayerStateService:State(player: Player): string
	local record = records[player]
	return record and record.state or States.Lobby
end

function PlayerStateService:Root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerStateService:Head(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Head") :: BasePart?
end

function PlayerStateService:Position(player: Player): Vector3?
	local root = self:Root(player)
	return root and root.Position
end

function PlayerStateService:RunPlayers(): { Player }
	local list = {}
	for player, record in records do
		if record.inRun and player.Parent then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function filterState(states: { [string]: boolean }): { Player }
	local list = {}
	for player, record in records do
		if record.inRun and states[record.state] and player.Parent then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

-- Able to move, Witness and interact.
function PlayerStateService:ActivePlayers(): { Player }
	return filterState({ [States.Active] = true })
end

-- Still in danger: Active or Downed.
function PlayerStateService:LivingPlayers(): { Player }
	return filterState({ [States.Active] = true, [States.Downed] = true })
end

function PlayerStateService:IsActive(player: Player): boolean
	return self:State(player) == States.Active
end

-- Active and not hidden in furniture: allowed to use prompts.
function PlayerStateService:CanAct(player: Player): boolean
	local record = records[player]
	-- Hidden in a walk-in closet you're only standing there: you can still
	-- slide its doors, pick things up (Services/HidingService's physical spots).
	local hidden = player:GetAttribute(PA.Hidden) and not player:GetAttribute("HidePhysical")
	return record ~= nil and record.state == States.Active and not hidden
end

-- Call before the server moves a character itself, so the speed check
-- doesn't mistake the teleport for an exploit.
function PlayerStateService:MarkTeleport(player: Player)
	local record = records[player]
	if record then
		record.teleportGrace = os.clock() + 1.5
		record.lastValid = nil
	end
end

function PlayerStateService:Touch(player: Player)
	local record = records[player]
	if record then
		record.lastActive = os.clock()
	end
end

-- Run lifecycle -------------------------------------------------------------

function PlayerStateService:BeginRun(players: { Player })
	self.inRun = true
	for _, player in players do
		local record = self:_record(player)
		record.inRun = true
		record.state = States.Active
		record.battery = Config.Player.FlashlightBatterySeconds
		record.isolatedSince = nil
		record.lastActive = os.clock()
		record.lastHint = -math.huge
		record.downs = 0
		player:SetAttribute(PA.State, States.Active)
		player:SetAttribute(PA.Battery, 1)
		player:SetAttribute(PA.IsEcho, false)
		player:SetAttribute(PA.DownedUntil, nil)
	end
end

function PlayerStateService:EndRun()
	self.inRun = false
	for player, record in records do
		if record.revivePrompt then
			record.revivePrompt:Destroy()
			record.revivePrompt = nil
		end
		if record.state == States.Lost then
			self:_clearEcho(player)
		end
		record.inRun = false
		record.state = States.Lobby
		self:SetFlashlight(player, false)
		player:SetAttribute(PA.State, States.Lobby)
		player:SetAttribute(PA.IsEcho, false)
		player:SetAttribute(PA.DownedUntil, nil)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Config.Player.WalkSpeed
		end
	end
end

function PlayerStateService:_setState(player: Player, state: string)
	local record = records[player]
	if not record then
		return
	end
	record.state = state
	player:SetAttribute(PA.State, state)
	self.StateChanged:Fire(player, state)
end

-- Caught by the stalker. A second catch while downed makes you Lost.
function PlayerStateService:Down(player: Player)
	local record = records[player]
	if not record or not record.inRun then
		return
	end
	if record.state == States.Downed then
		self:MakeLost(player, "caught again while down")
		return
	end
	if record.state ~= States.Active then
		return
	end
	self.services.HidingService:ForceLeave(player)
	record.downs = (record.downs or 0) + 1
	record.downedUntil = os.clock() + Config.Run.DownedSeconds
	self:_setState(player, States.Downed)
	player:SetAttribute(PA.DownedUntil, workspace:GetServerTimeNow() + Config.Run.DownedSeconds)
	self:SetFlashlight(player, false)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.Run.DownedCrawlSpeed
	end
	local root = self:Root(player)
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.Run.ReviveHoldSeconds
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(rescuer)
			if rescuer ~= player and self:CanAct(rescuer) then
				self:Revive(player, rescuer)
			end
		end)
		record.revivePrompt = prompt
	end
	local seconds = Config.Run.DownedSeconds
	notify(player, string.format("You're bleeding out. Someone has %d seconds to reach you.", seconds), "danger")
	for _, other in self:RunPlayers() do
		if other ~= player then
			notify(
				other,
				string.format("%s is bleeding out! %d seconds. Hold E on them.", player.DisplayName, seconds),
				"danger"
			)
		end
	end
	self.Downed:Fire(player)
end

function PlayerStateService:Revive(player: Player, rescuer: Player?)
	local record = records[player]
	if not record or record.state ~= States.Downed then
		return
	end
	if record.revivePrompt then
		record.revivePrompt:Destroy()
		record.revivePrompt = nil
	end
	self:_setState(player, States.Active)
	player:SetAttribute(PA.DownedUntil, nil)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
	self.lastRevive = os.clock()
	notify(player, rescuer and (rescuer.DisplayName .. " pulled you up.") or "You're back up.", "good")
	self.Revived:Fire(player, rescuer)
end

function PlayerStateService:_applyEcho(player: Player)
	local character = player.Character
	if not character then
		return
	end
	setGroup(character, Constants.CollisionGroups.Echo)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if d:GetAttribute("EchoOriginalTransparency") == nil then
				d:SetAttribute("EchoOriginalTransparency", d.Transparency)
				d:SetAttribute("EchoOriginalMaterial", d.Material.Name)
			end
			d.Transparency = 0.65
			d.Material = Enum.Material.ForceField
		end
	end
end

function PlayerStateService:_clearEcho(player: Player)
	local character = player.Character
	if not character then
		return
	end
	setGroup(character, Constants.CollisionGroups.Players)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local t = d:GetAttribute("EchoOriginalTransparency")
			if t ~= nil then
				d.Transparency = t
				local ok, material = pcall(function()
					return (Enum.Material :: any)[d:GetAttribute("EchoOriginalMaterial")]
				end)
				if ok and material then
					d.Material = material
				end
				d:SetAttribute("EchoOriginalTransparency", nil)
				d:SetAttribute("EchoOriginalMaterial", nil)
			end
		end
	end
end

-- Lost Witnesses become Echoes: they keep talking and can ping a hint once
-- a minute, so nobody sits in a dead lobby.
function PlayerStateService:MakeLost(player: Player, reason: string?)
	local record = records[player]
	if not record or not record.inRun or record.state == States.Lost or record.state == States.Extracted then
		return
	end
	self.services.HidingService:ForceLeave(player)
	if record.revivePrompt then
		record.revivePrompt:Destroy()
		record.revivePrompt = nil
	end
	self:_setState(player, States.Lost)
	player:SetAttribute(PA.IsEcho, true)
	player:SetAttribute(PA.DownedUntil, nil)
	self:SetFlashlight(player, false)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
	self:_applyEcho(player)
	notify(player, "You are Lost. As an Echo you can still talk, and ping one hint a minute.", "danger")
	for _, other in self:RunPlayers() do
		if other ~= player then
			notify(
				other,
				player.DisplayName .. " is Lost" .. (reason and (" (" .. reason .. ")") or "") .. ".",
				"danger"
			)
		end
	end
	self.Lost:Fire(player)
end

function PlayerStateService:Extract(player: Player)
	local record = records[player]
	if not record or record.state ~= States.Active then
		return
	end
	self.services.HidingService:ForceLeave(player)
	self:_setState(player, States.Extracted)
	self:SetFlashlight(player, false)
	notify(player, "You made it out.", "good")
	self.Extracted:Fire(player)
end

function PlayerStateService:CanEchoHint(player: Player): boolean
	local record = records[player]
	if not record or record.state ~= States.Lost then
		return false
	end
	return os.clock() - record.lastHint >= Config.Run.EchoHintCooldown
end

function PlayerStateService:MarkEchoHint(player: Player)
	local record = records[player]
	if record then
		record.lastHint = os.clock()
	end
end

-- Flashlight ----------------------------------------------------------------

function PlayerStateService:SetFlashlight(player: Player, on: boolean)
	local record = records[player]
	if not record then
		return
	end
	if on and (record.state ~= States.Active or record.battery <= 0) then
		on = false
	end
	if record.flashlight ~= on then
		local root = self:Root(player)
		if root and not player:GetAttribute(PA.Hidden) then
			self.Noise:Emit(root.Position, Config.Player.FlashlightClickRadius, player, "click")
		end
	end
	record.flashlight = on
	player:SetAttribute(PA.Flashlight, on)
	self:RefreshFlashlight(player)
end

-- Which light everyone else sees: the beam from your head while the torch is
-- in your hand, the weak clip light on your chest while you hold anything
-- else (ToolService:TorchClipped). Your own client draws its own copy.
-- A fresh set of batteries (the safe room's, docs/plans/level-design.md
-- section 11.12): the torch full again. Returns whether it was short.
function PlayerStateService:RefillBattery(player: Player): boolean
	local record = records[player]
	if not record then
		return false
	end
	local full = Config.Player.FlashlightBatterySeconds
	local short = record.battery < full - 1
	record.battery = full
	player:SetAttribute(PA.Battery, 1)
	return short
end

function PlayerStateService:RefreshFlashlight(player: Player)
	local record = records[player]
	local on = record ~= nil and record.flashlight
	local clipped = self.services.ToolService:TorchClipped(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local beam = head and head:FindFirstChild("Flashlight")
	if beam then
		beam.Enabled = on and not clipped
	end
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local clip = torso and torso:FindFirstChild("ClipLight")
	if clip then
		clip.Enabled = on and clipped
	end
end

function PlayerStateService:FlashlightOn(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.flashlight
end

-- Ticking -------------------------------------------------------------------

function PlayerStateService:IsolatedCount(): number
	if not self.inRun then
		return 0
	end
	local count = 0
	local now = os.clock()
	for _, player in self:LivingPlayers() do
		local record = records[player]
		if record.isolatedSince and now - record.isolatedSince >= Config.Drift.IsolationGraceSeconds then
			count += 1
		end
	end
	return count
end

function PlayerStateService:IsIsolated(player: Player): boolean
	local record = records[player]
	return record ~= nil
		and record.isolatedSince ~= nil
		and os.clock() - record.isolatedSince >= Config.Drift.IsolationGraceSeconds
end

function PlayerStateService:_tick(dt: number)
	if not self.inRun then
		return
	end
	local now = os.clock()
	local living = self:LivingPlayers()
	local positions = {}
	for _, player in living do
		positions[player] = self:Position(player)
	end

	for _, player in living do
		local record = records[player]
		local pos = positions[player]

		-- Downed timer
		if record.state == States.Downed and record.downedUntil and now >= record.downedUntil then
			self:MakeLost(player, "nobody reached them")
		end

		-- Isolation (only meaningful with teammates)
		if #living >= 2 and pos then
			-- A teammate on the other floor doesn't count as company (owner,
			-- 2026-10-04), unless you share the hall or a stairwell.
			local together = false
			for other, otherPos in positions do
				if
					other ~= player
					and otherPos
					and self.World:Together(otherPos, pos, Config.Drift.IsolationDistance)
				then
					together = true
					break
				end
			end
			if not together then
				record.isolatedSince = record.isolatedSince or now
			else
				record.isolatedSince = nil
			end
		else
			record.isolatedSince = nil
		end

		-- Movement sanity (doc section 7: server authority). Characters are
		-- client-simulated, so a speed exploit could outrun the stalker. A
		-- sustained speed far above sprint snaps the character back.
		local root = self:Root(player)
		if root and not root.Anchored and pos then
			local graceOver = now > (record.teleportGrace or 0)
			if record.lastValid and graceOver then
				local moved = Vector3.new(pos.X - record.lastValid.X, 0, pos.Z - record.lastValid.Z).Magnitude
				if moved / dt > Config.Player.SprintSpeed * 2.2 then
					record.strikes = (record.strikes or 0) + 1
					if record.strikes >= 2 then
						root.CFrame = CFrame.new(record.lastValid + Vector3.new(0, 3, 0))
						record.strikes = 0
						warn(string.format("[Consensus] %s moved %.0f studs/s; snapped back", player.Name, moved / dt))
					end
				else
					record.strikes = 0
					record.lastValid = pos
				end
			else
				record.lastValid = pos
			end
		end

		-- Movement noise and AFK
		if root and record.state == States.Active and not player:GetAttribute(PA.Hidden) then
			local velocity = root.AssemblyLinearVelocity
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if horizontal > 1 then
				record.lastActive = now
			end
			-- Boards that creak (the attic: docs/plans/level-design.md section
			-- 10.3): footsteps carry further, and now and then a board answers.
			-- Creeping stays silent.
			local creaks = self.World:CreaksAt(root.Position)
			local stepped = false
			if horizontal > Config.Player.SprintSpeedThreshold and now - record.lastSprintNoise > 0.5 then
				record.lastSprintNoise = now
				self.Noise:Emit(root.Position, Config.Player.SprintNoiseRadius * creaks, player, "sprint")
				stepped = true
			elseif velocity.Y > 12 and now - record.lastSprintNoise > 0.5 then
				record.lastSprintNoise = now
				self.Noise:Emit(root.Position, Config.Player.JumpNoiseRadius * creaks, player, "jump")
				stepped = true
			elseif horizontal > Config.Player.WalkSpeedThreshold and now - record.lastSprintNoise > 1 then
				-- Footsteps: quiet, but he can hear them from the next room's doorway.
				record.lastSprintNoise = now
				self.Noise:Emit(root.Position, Config.Player.WalkNoiseRadius * creaks, player, "walk")
				stepped = true
			end
			if stepped and creaks > 1 and math.random() < Config.Player.CreakChance then
				Sfx.play(math.random() < 0.5 and "Creak" or "CreakAlt", root.Position - Vector3.new(0, 2.5, 0), 0.7, 1)
			end
		end
		if player:GetAttribute(PA.Hidden) then
			record.lastActive = now -- holding still in a locker is a choice, not AFK
		end
		if #living >= 2 and record.state == States.Active and now - record.lastActive > Config.Run.AfkSeconds then
			notify(player, "You were idle too long and drifted away.", "danger")
			self:MakeLost(player, "idle")
		end

		-- Flashlight battery. Holding him frozen in your beam alone costs more
		-- (Config.Stare.BeamDrainScale; Stalker/Perception sets BeamHold).
		if record.flashlight then
			local scale = player:GetAttribute(PA.BeamHold) == true and Config.Stare.BeamDrainScale or 1
			record.battery = math.max(0, record.battery - dt * scale)
			if record.battery <= 0 then
				self:SetFlashlight(player, false)
				self.services.RunLogService:TorchDead()
				notify(player, "Your flashlight is dead. A lit Lantern room will recharge it.", "warning")
			end
		elseif pos and self.World:IsLanternRoom(self.World:RoomAt(pos)) then
			record.battery = math.min(
				Config.Player.FlashlightBatterySeconds,
				record.battery + Config.Player.FlashlightRechargePerSecond * dt
			)
		end
		player:SetAttribute(PA.Battery, record.battery / Config.Player.FlashlightBatterySeconds)
	end

	-- Downed players who are no longer "living" fall through above; Echo
	-- characters are re-ghosted if their character respawned.
end

return PlayerStateService
