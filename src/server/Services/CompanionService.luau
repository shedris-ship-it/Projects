-- Companion Witness (doc sections 6 and 12): for solo runs, an NPC that
-- counts as a second Witness but has limited information. It follows you,
-- joins your Witness windows when it can see what you're looking at, backs
-- up your stare, and pulls you up if you go down. It perceives only the true
-- house, so it can't confirm what only you see; it just agrees you're looking.
-- It keeps a little distance and carries no light, so it reads as a second
-- person searching the house with you, not a lamp at your heels.
--
-- It walks the house the way The Guest does (Stalker/Walker: the house graph,
-- the navmesh in each room), so it climbs the stairs, goes round the gallery
-- and opens doors (you hear it) to keep up or to reach you when you're down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local Walker = require(script.Parent.Parent.Stalker.Walker)

local CompanionService = {}

local FOLLOW_NEAR = 8 -- it stops this far away and lets you move
local FOLLOW_FAR = 16 -- beyond this it walks back towards you
local CATCH_UP = 40 -- beyond this (walking distance) it reappears behind you, out of view
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
			self:_animate()
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
	-- The next shirt after the squad's, in the same period clothes.
	self.services.OutfitService:Apply(model, 2)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Companion"
	humanoid.WalkSpeed = Config.Player.WalkSpeed
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
	model:PivotTo(spawnCFrame * CFrame.new(3, 0, 3))
	model.Parent = self.services.WorldService.folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	game:GetService("CollectionService"):AddTag(model, Constants.Tags.Companion)
	local groundOffset = humanoid.HipHeight + root.Size.Y / 2
	self.npc = {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		groundOffset = groundOffset,
		lastMove = os.clock(),
		reviveStart = nil,
		tracks = self:_loadTracks(humanoid),
		walker = Walker.new(self.services, {
			model = model,
			humanoid = humanoid,
			root = root,
			groundOffset = groundOffset,
			group = Constants.CollisionGroups.Players,
			halfWidth = 1,
			path = Walker.CompanionPath,
			opensDoors = "companion",
			who = "player",
		}, Random.new()),
	}
	self.player = players[1]
end

-- A model made from a HumanoidDescription has no Animate script, so it would
-- slide about in a T-pose. Roblox's default R15 idle, walk and run play on it.
local ANIMATIONS = { Idle = 507766388, Walk = 507777826, Run = 507767714 }

function CompanionService:_loadTracks(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			track.Looped = true
			tracks[name] = track
		end
	end
	return tracks
end

-- Idle when still, walk or run to match how fast it's moving.
function CompanionService:_animate()
	local npc = self.npc
	local tracks = npc and npc.tracks
	if not tracks then
		return
	end
	local velocity = npc.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local want = speed < 0.5 and "Idle" or (speed > Config.Player.SprintSpeedThreshold and "Run" or "Walk")
	for name, track in tracks do
		if name == want then
			if not track.IsPlaying then
				track:Play(0.2)
			end
			if name ~= "Idle" then
				track:AdjustSpeed(math.clamp(speed / (name == "Run" and 16 or 14), 0.3, 1.8))
			end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

function CompanionService:Stop()
	if self.npc then
		self.npc.walker:Stop()
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
	local now = os.clock()
	local walker = npc.walker
	-- How far it would have to walk: a Witness on the other floor is a
	-- staircase away, however close they are through the ceiling.
	local distance = services.WorldService:Separation(target, here)
	local sameFloor = math.abs(target.Y - here.Y) < 6
	local state = services.PlayerStateService:State(player)
	-- Out of the house (got out, or Lost): nobody to follow.
	if state == Constants.PlayerStates.Extracted or state == Constants.PlayerStates.Lost then
		walker:Stop()
		return
	end

	-- Pull a downed Witness back up after a short delay.
	if state == Constants.PlayerStates.Downed then
		if distance > 4 or not sameFloor then
			walker:SetDestination(target, { speed = Config.Player.SprintSpeed })
			walker:Step(now)
		else
			walker:Stop()
			npc.reviveStart = npc.reviveStart or now
			if now - npc.reviveStart >= Config.Run.CompanionReviveSeconds then
				npc.reviveStart = nil
				services.PlayerStateService:Revive(player, nil)
			end
		end
		return
	end
	npc.reviveStart = nil

	local view = services.WitnessService:GetView(player)
	if distance > CATCH_UP and not self:_inView(view, here) then
		-- Lost: reappear behind its Witness, where they aren't looking.
		local spot = self:_behind(player, target, view)
		if spot then
			walker:Stop()
			npc.model:PivotTo(CFrame.new(spot + Vector3.new(0, npc.groundOffset, 0)))
			npc.lastMove = now
			npc.following = false
			return
		end
	end
	if distance > FOLLOW_FAR or (npc.following and distance > FOLLOW_NEAR) or not sameFloor then
		-- Walk back towards its Witness (up the stairs if need be), and stop
		-- at the near edge of the band.
		npc.following = true
		local speed = distance > FOLLOW_FAR * 1.5 and Config.Player.SprintSpeed or Config.Player.WalkSpeed
		walker:SetDestination(target, { speed = speed })
		walker:Step(now)
		return
	end
	npc.following = false
	walker:Stop()

	-- Turn towards whatever its Witness is looking at, so it backs up a stare.
	if view then
		local focus = view.Position + view.LookVector * 20
		local flat = Vector3.new(focus.X - here.X, 0, focus.Z - here.Z)
		if flat.Magnitude > 0.1 then
			npc.root.CFrame = CFrame.lookAt(here, here + flat)
		end
	end
end

-- Whether a point is in its Witness's view.
function CompanionService:_inView(view: CFrame?, point: Vector3): boolean
	if not view then
		return false
	end
	local d = point - view.Position
	return d.Magnitude < 60 and view.LookVector:Dot(d.Unit) > math.cos(math.rad(60))
end

-- A floor point behind the Witness, short of any wall or railing in the
-- way, with floor under it (not the void over the hall): or nil.
function CompanionService:_behind(player: Player, target: Vector3, view: CFrame?): Vector3?
	local look = view and Vector3.new(view.LookVector.X, 0, view.LookVector.Z)
	local npc = self.npc
	local feet = target - Vector3.new(0, 3, 0)
	if not look or look.Magnitude < 0.1 then
		return feet
	end
	local back = -look.Unit * FOLLOW_NEAR
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc.model, player.Character }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(target, back, params)
	local reach = hit and math.max(hit.Distance - 1.5, 0) or FOLLOW_NEAR
	-- Railings can't be hit by rays: the walker's sweep knows them.
	local clearance = npc.walker.clearance
	local spot = clearance:Reach(target, target + back.Unit * reach)
	if (spot - target).Magnitude < 1 then
		return feet
	end
	if not clearance:Grounded(spot, 3) then
		return nil
	end
	return spot - Vector3.new(0, 3, 0)
end

return CompanionService
