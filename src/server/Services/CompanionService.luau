-- Companion Witness (doc sections 6 and 12): for solo runs, an NPC that
-- counts as a second Witness but has limited information. It follows you,
-- joins your Witness windows when it can see what you're looking at, backs
-- up your stare, and pulls you up if you go down. It perceives only the true
-- house, so it can't confirm what only you see; it just agrees you're looking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local CompanionService = {}

local FOLLOW_DISTANCE = 6
local WITNESS_DELAY = 1.3
local SIGHT_RANGE = 40

function CompanionService:Init(services)
	self.services = services
	self.npc = nil
	self.player = nil
end

function CompanionService:Start()
	self.services.WitnessService.WindowOpened:Connect(function(_, entry, witness)
		if not self.npc or witness ~= self.player then
			return
		end
		local position = self.services.WitnessService.PositionOf(entry)
		task.delay(WITNESS_DELAY, function()
			if self.npc and self:CanSee(position, entry.ignore) then
				self.services.WitnessService:AddWitness("companion", entry)
			end
		end)
	end)
	RunService.Heartbeat:Connect(function()
		if self.npc then
			self:_follow()
		end
	end)
end

function CompanionService:IsPresent(): boolean
	return self.npc ~= nil and self.npc.model.Parent ~= nil
end

function CompanionService:GetPosition(): Vector3?
	return self.npc and self.npc.root.Position
end

function CompanionService:CanSee(position: Vector3, ignore: { Instance }?): boolean
	if not self.npc then
		return false
	end
	local eye = self.npc.head.Position
	local offset = position - eye
	if offset.Magnitude > SIGHT_RANGE then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { self.npc.model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, instance in ignore or {} do
		table.insert(exclude, instance)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local result = Workspace:Raycast(eye, offset, params)
	return result == nil or (result.Position - position).Magnitude < 1.5
end

local function buildModel()
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(214, 200, 182)
		local coat = Color3.fromRGB(70, 84, 96)
		description.HeadColor = skin
		description.TorsoColor = coat
		description.LeftArmColor = coat
		description.RightArmColor = coat
		description.LeftLegColor = Color3.fromRGB(50, 50, 56)
		description.RightLegColor = Color3.fromRGB(50, 50, 56)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		return nil
	end
	return model
end

function CompanionService:Begin(players: { Player }, spawnCFrame: CFrame)
	self:Stop()
	if #players ~= 1 or not Config.Run.CompanionForSolo then
		return
	end
	local model = buildModel()
	if not model then
		warn("[Consensus] companion could not be created")
		return
	end
	model.Name = "Companion"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Companion"
	humanoid.WalkSpeed = Config.Player.SprintSpeed
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = Constants.CollisionGroups.Players
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Range = 10
	light.Brightness = 0.6
	light.Parent = root
	model:PivotTo(spawnCFrame * CFrame.new(3, 0, 3))
	model.Parent = self.services.WorldService.folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	game:GetService("CollectionService"):AddTag(model, Constants.Tags.Companion)
	self.npc =
		{ model = model, humanoid = humanoid, root = root, head = head, lastMove = os.clock(), reviveStart = nil }
	self.player = players[1]
end

function CompanionService:Stop()
	if self.npc then
		self.npc.model:Destroy()
	end
	self.npc = nil
	self.player = nil
end

function CompanionService:_follow()
	local npc = self.npc
	local player = self.player
	if not npc.model.Parent or not player or not player.Parent then
		self:Stop()
		return
	end
	local services = self.services
	local target = services.PlayerStateService:Position(player)
	if not target then
		return
	end
	local here = npc.root.Position
	local distance = (target - here).Magnitude
	local state = services.PlayerStateService:State(player)

	-- Pull a downed Witness back up after a short delay.
	if state == Constants.PlayerStates.Downed then
		if distance > 4 then
			npc.humanoid:MoveTo(target)
		else
			npc.reviveStart = npc.reviveStart or os.clock()
			if os.clock() - npc.reviveStart >= Config.Run.ReviveHoldSeconds * 2 then
				npc.reviveStart = nil
				services.PlayerStateService:Revive(player, nil)
			end
		end
		return
	end
	npc.reviveStart = nil

	if distance > 32 then
		-- Catch up out of sight rather than getting lost.
		local seen = services.StalkerService and services.StalkerService:GetPosition()
		npc.model:PivotTo(CFrame.new(target + Vector3.new(2, 0, 2)))
		npc.lastMove = os.clock()
		if seen then
			return
		end
	elseif distance > FOLLOW_DISTANCE then
		npc.humanoid:MoveTo(target)
	else
		npc.humanoid:MoveTo(here)
	end

	-- Face whatever its Witness is looking at, so it backs up a stare.
	local view = services.WitnessService:GetView(player)
	if view and distance <= FOLLOW_DISTANCE + 1 then
		local look = view.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.1 then
			npc.root.CFrame = CFrame.lookAt(here, here + flatLook)
		end
	end
end

return CompanionService
