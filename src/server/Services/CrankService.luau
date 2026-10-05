-- Crank doors (R2c, the two-person locks): a heavy shutter across a
-- doorway, raised by a crank on the wall of its outer side. Hold E at the
-- crank and it rises; let go and it drops, fast, but never onto anyone
-- standing under it. So one cranks and another goes through, and from the
-- far side pins it open with the latch. On your own: set the ratchet (Q)
-- and it winds up slowly, clicking loud enough for him to hear, and holds.
-- From the inside you can always heave it up slowly (the ratchet's way) and
-- latch it: nobody is ever shut in. The dinner raises and latches them all.
--
-- The passage follows the shutter (WorldService:SetSeamBlocked "crank"), with
-- a little give (open from OpenAt, shut again below ShutAt). Built at the
-- start of each run into the run's content (Gate A never sees it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local RoomRects = require(Shared.Logic.RoomRects)
local Sfx = require(Shared.Lib.Sfx)
local SwitchSpots = require(Shared.Logic.SwitchSpots)

local C = Config.Crank
local part = PropFactory.part
local DOOR_W = Config.Level.DoorWidth
local DOOR_H = Config.Level.DoorHeight

local CrankService = {}

function CrankService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.Noise = services.NoiseService
	self.cranks = {} -- seam id -> crank
end

function CrankService:Start()
	self.World.Cleared:Connect(function()
		table.clear(self.cranks)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, crank in self.cranks do
			crank.crankers[player] = nil
			crank.heavers[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, crank in self.cranks do
			self:_step(crank, dt)
		end
	end)
end

-- Queries ---------------------------------------------------------------------------

-- Is this doorway shut by a crank door nobody has ever raised? (A raised one
-- counts as passable for where the squad can get to: Services/LockService.)
function CrankService:Shut(seamId: string): boolean
	local crank = self.cranks[seamId]
	return crank ~= nil and crank.blocked and not crank.raisedOnce
end

function CrankService:Get(seamId: string)
	return self.cranks[seamId]
end

-- Building -------------------------------------------------------------------------

function CrankService:Begin(plan)
	local world = self.World.World
	local folder = Instance.new("Folder")
	folder.Name = "Cranks"
	folder.Parent = self.World.content
	self.folder = folder
	local o = Config.Level.Origin
	local rects = {}
	for _, rect in RoomRects.ofLayout(world.layout, Config.Level) do
		rects[rect.id] = {
			x0 = o.x + rect.x,
			z0 = o.z + rect.z,
			x1 = o.x + rect.x + rect.w,
			z1 = o.z + rect.z + rect.d,
		}
	end
	for seamId, lock in plan.locks do
		local seam = world.seams[seamId]
		if lock.kind == "crank" and seam then
			self:_build(seamId, seam, lock, rects)
		end
	end
end

-- Into `room` from the doorway's wall line.
local function into(seam, room: number): Vector3
	return room == seam.b and seam.normal or -seam.normal
end

-- A spot on `room`'s wall beside the doorway (Logic/SwitchSpots), `beside`
-- studs past the door's edge, `height` up, facing into the room.
local function wallSpot(seam, room: number, rect, beside: number, height: number): CFrame?
	local dir = into(seam, room)
	local cfg = { DoorWidth = DOOR_W, WallFace = 0.55, Beside = beside, Margin = 1 }
	local spot = rect
		and SwitchSpots.place(rect, { x = seam.floorPosition.X, z = seam.floorPosition.Z }, {
			x = dir.X,
			z = dir.Z,
		}, cfg)
	if not spot then
		return nil
	end
	local at = Vector3.new(spot.x, seam.floorPosition.Y + height, spot.z)
	return CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z))
end

function CrankService:_build(seamId: string, seam, lock, rects)
	local outer = lock.side
	local inner = seam.a == outer and seam.b or seam.a
	local normal = Vector3.new(seam.normal.X, 0, seam.normal.Z).Unit
	local along = Vector3.yAxis:Cross(normal)
	-- A roller shutter of dark slats: it rolls up into an iron box over the
	-- doorway (so raised, it's gone, not poking through the ceiling).
	local model = Instance.new("Model")
	model.Name = "CrankDoor"
	local base = CFrame.fromMatrix(seam.floorPosition, along, Vector3.yAxis)
	local slab = part(
		model,
		"Shutter",
		Vector3.new(DOOR_W + 0.6, DOOR_H + 0.1, 0.3),
		base * CFrame.new(0, (DOOR_H + 0.1) / 2, 0),
		Color3.fromRGB(64, 50, 38),
		PropFactory.material("WoodPlanks")
	)
	local bar = part(
		model,
		"BottomBar",
		Vector3.new(DOOR_W + 0.7, 0.3, 0.42),
		base * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(56, 56, 58),
		PropFactory.material("Metal"),
		{ collide = false }
	)
	part(
		model,
		"RollerBox",
		Vector3.new(DOOR_W + 1, 0.9, 1.1),
		base * CFrame.new(0, DOOR_H + 0.45, 0),
		Color3.fromRGB(60, 60, 62),
		PropFactory.material("Metal")
	)
	model.PrimaryPart = slab
	model.Parent = self.folder
	local crank = {
		id = seamId,
		seam = seam,
		model = model,
		base = base,
		slab = slab,
		bar = bar,
		height = 0,
		max = C.Max,
		blocked = true,
		raisedOnce = false,
		latched = false,
		ratchet = false,
		crankers = {},
		heavers = {},
		nextClick = 0,
		nextCreak = 0,
		outer = outer,
		inner = inner,
		along = along,
		normal = normal,
	}
	self.cranks[seamId] = crank
	self.World:SetSeamBlocked(seamId, "crank", true)
	-- The crank on the outer wall, a few strides from the doorway.
	local at = wallSpot(seam, outer, rects[outer], C.Beside, 3.6) or wallSpot(seam, outer, rects[outer], 1.2, 3.6)
	if at then
		self:_buildCrank(crank, at)
	else
		warn("[Consensus] no wall for the crank of " .. seamId)
	end
	-- The latch on the inside, by the doorway.
	local latchAt = wallSpot(seam, inner, rects[inner], 0.9, 4)
	if latchAt then
		self:_buildLatch(crank, latchAt)
	end
end

local function holdPrompt(parent: Instance, action: string, object: string, key: Enum.KeyCode, pad: Enum.KeyCode)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = pad
	prompt.MaxActivationDistance = C.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function CrankService:_buildCrank(crank, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "Crank"
	local metal = PropFactory.material("Metal")
	part(model, "Plate", Vector3.new(1.3, 1.3, 0.15), at * CFrame.new(0, 0, -0.07), Color3.fromRGB(70, 72, 70), metal)
	local wheel = part(
		model,
		"Wheel",
		Vector3.new(0.15, 1.1, 1.1),
		at * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(96, 70, 44),
		metal,
		{ shape = Enum.PartType.Cylinder }
	)
	local handle = part(
		model,
		"Handle",
		Vector3.new(0.12, 0.12, 0.4),
		at * CFrame.new(0.4, 0, -0.45),
		Color3.fromRGB(150, 130, 90),
		metal,
		{ collide = false }
	)
	model.Parent = self.folder
	crank.wheel, crank.handle, crank.wheelAt = wheel, handle, at
	crank.crankAt = at.Position
	-- Hold E: it rises. (A long hold, so the prompt reports the hold itself.)
	local prompt = holdPrompt(wheel, "Crank it up (hold)", "Crank", Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	prompt.HoldDuration = 60
	prompt.PromptButtonHoldBegan:Connect(function(player)
		crank.crankers[player] = true
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		crank.crankers[player] = nil
	end)
	crank.crankPrompt = prompt
	-- Q: the ratchet. Slow, loud, and it holds.
	local ratchet = holdPrompt(wheel, "Set the ratchet", "Crank", Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ratchet.HoldDuration = 0
	ratchet.UIOffset = Vector2.new(0, 72)
	ratchet.Triggered:Connect(function(player)
		if self.PlayerState:CanAct(player) then
			crank.ratchet = not crank.ratchet
			ratchet.ActionText = crank.ratchet and "Release the ratchet" or "Set the ratchet"
			Sfx.play("LockClick", crank.crankAt, 0.6, crank.ratchet and 0.7 or 0.9)
		end
	end)
	crank.ratchetPrompt = ratchet
end

function CrankService:_buildLatch(crank, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "Latch"
	local plate = part(
		model,
		"Plate",
		Vector3.new(0.5, 0.9, 0.12),
		at * CFrame.new(0, 0, -0.06),
		Color3.fromRGB(70, 72, 70),
		PropFactory.material("Metal")
	)
	part(
		model,
		"Lever",
		Vector3.new(0.12, 0.5, 0.12),
		at * CFrame.new(0, 0.1, -0.2),
		Color3.fromRGB(150, 130, 90),
		PropFactory.material("Metal"),
		{ collide = false }
	)
	model.Parent = self.folder
	crank.latchAt = at.Position
	-- Down: heave it up (hold). Up: latch it open.
	local prompt = holdPrompt(plate, "Heave it up (hold)", "Shutter", Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	prompt.HoldDuration = 60
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if crank.height < C.OpenAt then
			crank.heavers[player] = true
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		crank.heavers[player] = nil
	end)
	prompt.Triggered:Connect(function(player)
		if crank.height >= C.OpenAt and self.PlayerState:CanAct(player) then
			self:Latch(crank)
		end
	end)
	crank.latchPrompt = prompt
end

-- Running ----------------------------------------------------------------------------

local function near(self, player: Player, at: Vector3?): boolean
	local position = self.PlayerState:Position(player)
	return at ~= nil
		and position ~= nil
		and (position - at).Magnitude <= C.Reach + 2
		and self.PlayerState:CanAct(player)
end

-- Anyone (a player, him, the Companion) standing in the doorway.
function CrankService:_occupied(crank): boolean
	local points = {}
	for _, player in Players:GetPlayers() do
		local position = self.PlayerState:Position(player)
		if position then
			table.insert(points, position)
		end
	end
	local stalker = self.services.StalkerService
	local guest = stalker and stalker.GetPosition and stalker:GetPosition()
	if guest then
		table.insert(points, guest)
	end
	local companion = Workspace:FindFirstChild("Companion", true)
	if companion and companion:IsA("Model") then
		table.insert(points, companion:GetPivot().Position)
	end
	local floor = crank.seam.floorPosition
	for _, p in points do
		local d = p - floor
		if
			math.abs(d:Dot(crank.normal)) < C.Clearance
			and math.abs(d:Dot(crank.along)) < DOOR_W / 2 + 0.6
			and d.Y > -2
			and d.Y < DOOR_H + 2
		then
			return true
		end
	end
	return false
end

function CrankService:_step(crank, dt: number)
	if not crank.model.Parent then
		return
	end
	local now = os.clock()
	local before = crank.height
	if not crank.latched then
		local rate, slowBy = 0, nil
		for player in crank.crankers do
			if near(self, player, crank.crankAt) then
				local r = crank.ratchet and C.RatchetRate or C.CrankRate
				if r > rate then
					rate, slowBy = r, crank.ratchet and player or nil
				end
			else
				crank.crankers[player] = nil
			end
		end
		for player in crank.heavers do
			if near(self, player, crank.latchAt) then
				if C.RatchetRate > rate then
					rate, slowBy = C.RatchetRate, player
				end
			else
				crank.heavers[player] = nil
			end
		end
		if rate > 0 then
			crank.height = math.min(crank.max, crank.height + rate * dt)
			if slowBy and now >= crank.nextClick and crank.height < crank.max then
				-- The ratchet's teeth: loud, and from you.
				crank.nextClick = now + C.ClickEvery
				Sfx.play("LockClick", crank.crankAt or crank.latchAt, 0.8, 0.6)
				self.Noise:Emit(crank.crankAt or crank.latchAt, C.ClickNoise, slowBy, "crank")
			elseif not slowBy and now >= crank.nextCreak then
				crank.nextCreak = now + 0.9
				Sfx.play("Creak", crank.seam.position, 0.5, 0.7)
			end
			crank.falling = false
		elseif not crank.ratchet and crank.height > 0 then
			-- It drops, but never onto anyone in the doorway.
			if not self:_occupied(crank) then
				crank.height = math.max(0, crank.height - C.FallRate * dt)
				crank.falling = true
				if crank.height == 0 then
					Sfx.play("DoorSlam", crank.seam.position, 0.9, 0.7)
					self.Noise:Emit(crank.seam.position, C.SlamNoise, nil, "lure")
					crank.falling = false
				end
			end
		end
	end
	if crank.height ~= before then
		self:_place(crank)
	end
	-- The passage, with a little give.
	if crank.blocked and crank.height >= C.OpenAt then
		crank.blocked = false
		if not crank.raisedOnce then
			self.services.Telemetry:Log("CrankRaised", { ratchet = crank.ratchet == true })
		end
		crank.raisedOnce = true
		self.World:SetSeamBlocked(crank.id, "crank", false)
		crank.model.PrimaryPart.CanCollide = false
	elseif not crank.blocked and crank.height < C.ShutAt then
		crank.blocked = true
		self.World:SetSeamBlocked(crank.id, "crank", true)
		crank.model.PrimaryPart.CanCollide = true
	end
	if crank.latchPrompt then
		local up = crank.height >= C.OpenAt
		crank.latchPrompt.Enabled = not crank.latched
		crank.latchPrompt.ActionText = up and "Latch it open" or "Heave it up (hold)"
		crank.latchPrompt.HoldDuration = up and 0.5 or 60
	end
end

function CrankService:_place(crank)
	-- What's still unrolled: from its bottom edge (`height`) up to the box.
	local h = crank.height
	local tall = math.max(0.1, DOOR_H + 0.1 - h)
	crank.slab.Size = Vector3.new(DOOR_W + 0.6, tall, 0.3)
	crank.slab.CFrame = crank.base * CFrame.new(0, h + tall / 2, 0)
	crank.bar.CFrame = crank.base * CFrame.new(0, h + 0.15, 0)
	if crank.wheel then
		-- The wheel turns with the shutter.
		crank.wheel.CFrame = crank.wheelAt
			* CFrame.new(0, 0, -0.25)
			* CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(crank.height * 1.4, 0, 0)
		crank.handle.CFrame = crank.wheelAt * CFrame.Angles(0, 0, crank.height * 1.4) * CFrame.new(0.4, 0, -0.45)
	end
end

-- Pinned open for good.
function CrankService:Latch(crank)
	if crank.latched then
		return
	end
	crank.latched = true
	crank.height = crank.max
	self:_place(crank)
	Sfx.play("DoorLatch", crank.latchAt or crank.seam.position, 0.8, 0.6)
	if crank.crankPrompt then
		crank.crankPrompt.Enabled = false
		crank.ratchetPrompt.Enabled = false
	end
	Net.get("Notify"):FireAllClients("The shutter is latched open.", "good")
end

-- The dinner: every shutter up and latched (the final hunt has the whole house).
function CrankService:LatchAll()
	for _, crank in self.cranks do
		self:Latch(crank)
		self:_step(crank, 0)
	end
end

return CrankService
