-- Everything about how The Guest looks and sounds on this client
-- (docs/ART.md "The Guest"). The server owns where he is and what he's doing
-- (the model's GuestPose, GuestGaze, GuestForm and GuestLean attributes);
-- this controller turns that into a body:
--   * every joint animated here, each frame, from Logic/GuestPose: no
--     uploaded animations, so his movement can be as wrong as we like
--   * his face and fingers (Lib/GuestFace), the smile and the eye-shine in
--     your torch beam
--   * who can see him (StalkerVisibility), covering parts added later
--   * footsteps from his real feet, muffled through walls

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local GuestPose = require(Shared.Logic.GuestPose)
local Net = require(Shared.Net)

local GuestFace = require(script.Parent.Parent.Lib.GuestFace)
local GuestReflection = require(script.Parent.Parent.Lib.GuestReflection)

local player = Players.LocalPlayer
local Rig = GuestPose.Rig
local G = Config.Guest

local GuestController = {}

local guest = nil -- the attached body, see _attach
local visible = false
local fade = nil -- { started, duration } while dissolving
local ushered = 0 -- times he stepped aside for you this session (captioned the first two)
local shadows = {} -- door id -> the shadow of his feet under it (Stalk BehindTheDoor)
local spottedTold = 0 -- "[it sees you]" captions so far
local torchStutterAt = 0 -- the torch stutters on his breath, at most this often

function GuestController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

local function setModifier(model: Instance, value: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = value
		end
	end
end

-- Can this player see him right now? (Other systems, like aiming, ask.)
function GuestController:IsVisibleLocally(): boolean
	return guest ~= nil and visible and not guest.parked
end

function GuestController:Model(): Model?
	return guest and guest.model
end

function GuestController:_detach()
	-- The face and fingers live inside the model, so they go with it.
	for id, shadow in shadows do
		shadow:Destroy()
		shadows[id] = nil
	end
	if guest then
		for _, connection in guest.connections do
			connection:Disconnect()
		end
		guest.reflection:Close()
	end
	guest = nil
end

function GuestController:_attach(model: Model)
	if guest and guest.model == model then
		return
	end
	self:_detach()
	local root = model:WaitForChild("HumanoidRootPart", 10)
	local head = model:WaitForChild("Head", 10)
	local leftHand = model:WaitForChild("LeftHand", 10)
	local rightHand = model:WaitForChild("RightHand", 10)
	if not (root and head and leftHand and rightHand) or not model.Parent then
		return
	end
	-- The server never animates him; make sure nothing here does either.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	guest = {
		model = model,
		root = root :: BasePart,
		head = head :: BasePart,
		feet = { Left = model:FindFirstChild("LeftFoot"), Right = model:FindFirstChild("RightFoot") },
		motors = motors,
		face = GuestFace.new(head :: BasePart),
		hands = {
			Left = GuestFace.hand(leftHand :: BasePart, "Left"),
			Right = GuestFace.hand(rightHand :: BasePart, "Right"),
		},
		pose = GuestPose.new(),
		reflection = GuestReflection.new(),
		paneClock = 0,
		parked = true,
		connections = {},
	}
	table.insert(
		guest.connections,
		model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = visible and 0 or 1
			end
		end)
	)
	setModifier(model, visible and 0 or 1)
end

function GuestController:Start()
	local tag = Constants.Tags.Stalker
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		task.spawn(function()
			self:_attach(model)
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		if guest and guest.model == model then
			self:_detach()
		end
	end)
	for _, model in CollectionService:GetTagged(tag) do
		task.spawn(function()
			self:_attach(model)
		end)
	end

	Net.get("StalkerVisibility").OnClientEvent:Connect(function(isVisible)
		visible = isVisible == true
		fade = nil
		if guest then
			setModifier(guest.model, visible and 0 or 1)
		end
	end)
	Net.get("HuntState").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.reckoning and payload.state == "telegraph" then
			self.controllers.AudioController:Caption("[the house has had enough]")
		end
		if payload.state == "dissolve" then
			fade = { started = os.clock(), duration = 1.5 }
		end
	end)
	Net.get("GuestEvent").OnClientEvent:Connect(function(event)
		local ok, err = pcall(self._event, self, event)
		if not ok then
			warn("[Consensus] guest event failed: " .. tostring(err))
		end
	end)

	-- Joints are written before the physics step, where the engine applies
	-- Motor6D transforms.
	RunService.Stepped:Connect(function(_, dt)
		if guest and guest.model.Parent then
			local ok, err = pcall(self._frame, self, dt)
			if not ok then
				warn("[Consensus] guest animation failed: " .. tostring(err))
			end
		end
	end)
end

-- Where he's looking: the camera if it's you, else that player's head.
local function gazeTarget(userId: number?): Vector3?
	if not userId or userId == 0 then
		return nil
	end
	if userId == player.UserId then
		return Workspace.CurrentCamera.CFrame.Position
	end
	local other = Players:GetPlayerByUserId(userId)
	local head = other and other.Character and other.Character:FindFirstChild("Head")
	return head and (head :: BasePart).Position or nil
end

local function blocked(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(from, to - from, params)
	return hit ~= nil and (hit.Position - to).Magnitude > 1
end

-- Each mood's sound (Logic/GuestMood's tells), every so many seconds.
local MOOD_SOUNDS = {
	Irritated = { key = "GuestCrack", volume = 0.5, pitch = 0.9, every = { 6, 12 } },
	Playful = { key = "GuestGiggle", volume = 0.4, pitch = 0.92, every = { 12, 24 } },
}

local FINGER_CURL = {
	Idle = 0.75,
	Hold = 0.5,
	Bow = 0.75,
	Walk = 0.7,
	Run = 0.45,
	Creep = 0.25,
	BackAway = 0.35,
	Peek = 0.4,
	Zoom = 0.05,
	Lunge = -0.25,
	Usher = -0.15, -- the open hand, "after you"
	Duck = 0.6,
	Listen = 0.1,
	Stagger = 0.2,
}

-- How far he ducks for a doorway in the mansion, whose doorways aren't on a
-- 40-stud grid: from the seam panels nearby (every seam, doorway or not, so
-- ducking never gives a tell away), like GuestPose.stoop does on the grid.
local seamPanels, seamPanelsAt = {}, -math.huge
local function mansionStoop(position: Vector3): number
	local now = os.clock()
	if now - seamPanelsAt > 2 then
		seamPanels = CollectionService:GetTagged(Constants.Tags.Seam)
		seamPanelsAt = now
	end
	local best = 0
	for _, panel in seamPanels do
		if panel:IsA("BasePart") and panel.Parent then
			local p, size = panel.Position, panel.Size
			if math.abs(position.Y - p.Y) < 8 then
				local lateral, depth
				if size.X > size.Z then
					lateral, depth = math.abs(position.X - p.X), math.abs(position.Z - p.Z)
				else
					lateral, depth = math.abs(position.Z - p.Z), math.abs(position.X - p.X)
				end
				if lateral <= Config.Level.DoorWidth / 2 + 1 then
					best = math.max(best, math.clamp(1 - depth / 3, 0, 1))
				end
			end
		end
	end
	return best
end

function GuestController:_frame(dt: number)
	local model, root = guest.model, guest.root
	local position = root.Position
	guest.parked = position.Y > 200
	if guest.parked then
		-- Not in the house: only a face at the glass can show (it doesn't
		-- need his body).
		if guest.reflection:Mode() == "face" then
			local camera = Workspace.CurrentCamera
			guest.reflection:UpdateFace(camera.CFrame.Position, camera.CFrame.LookVector, dt)
		end
		return
	end
	if fade then
		local t = math.clamp((os.clock() - fade.started) / fade.duration, 0, 1)
		setModifier(model, t)
		if t >= 1 then
			fade = nil
			visible = false
		end
	end

	local pose = model:GetAttribute("GuestPose") or "Idle"
	local forward = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	local gazeYaw, gazePitch = nil, nil
	local target = gazeTarget(model:GetAttribute("GuestGaze"))
	if target then
		local neck = root.CFrame * CFrame.new(0, Rig.neckY - Rig.rootY + 0.4, 0)
		local rel = neck:PointToObjectSpace(target)
		gazeYaw, gazePitch = GuestPose.gazeAngles(rel.X, rel.Y, rel.Z)
	end
	local origin = Config.Level.Origin
	local layout = self.state and self.state.layout
	local stoop = if layout and layout.mode == "Mansion"
		then mansionStoop(position)
		else GuestPose.stoop(
			position.X - origin.x,
			position.Z - origin.z,
			Config.Level.CellSize,
			Config.Level.DoorWidth / 2
		)
	local lean = model:GetAttribute("GuestLean") or 0
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local mood = model:GetAttribute("GuestMood")
	-- Your beam lands on him: his head snaps to it first, then the body
	-- follows; and while it's on him he moves in stutters (below).
	local beam = self:_beamOnHim(camera)
	if beam and not guest.inBeam then
		guest.snapUntil = now + G.LightSnapSeconds
	end
	guest.inBeam = beam
	-- Frozen but alive: how long he has been held still and staring.
	if pose == "Hold" then
		guest.heldFor = (guest.heldFor or 0) + dt
	else
		if (guest.heldFor or 0) > G.ExhaleAfter and (visible or fade ~= nil) then
			-- Let go: a long breath out.
			local audio = self.controllers.AudioController
			audio:PlayAt(
				"GuestExhale",
				guest.head.Position,
				0.6,
				0.72,
				blocked(camera.CFrame.Position, guest.head.Position, { model })
			)
		end
		guest.heldFor = 0
	end
	-- Unfolding to his full height once a door frame is behind him.
	if (guest.lastStoop or 0) > 0.4 and stoop < 0.05 then
		guest.unfoldUntil = now + G.UnfoldSeconds
	end
	guest.lastStoop = stoop
	local unfold = math.clamp(((guest.unfoldUntil or 0) - now) / G.UnfoldSeconds, 0, 1)
	local values, planted = GuestPose.step(guest.pose, {
		pose = pose,
		forward = forward,
		tilt = (model:GetAttribute("HeadTilt") or 14),
		lean = lean,
		stoop = stoop,
		gazeYaw = gazeYaw,
		gazePitch = gazePitch,
		neckYawMax = G.NeckYawMax,
		mood = mood,
		heldFor = guest.heldFor,
		snapNeck = now < (guest.snapUntil or 0),
		unfold = unfold,
		random = math.random,
	}, dt)

	local shown = visible or fade ~= nil
	if shown then
		-- In your light he moves like a stop-motion puppet: his joints only
		-- take their new places every so often. In the dark, smooth.
		local write = true
		local form = model:GetAttribute("GuestForm") or 0
		-- Broken (Breaking), he moves in stutters even in the dark.
		if beam or form >= 2 then
			if now < (guest.nextStutter or 0) then
				write = false
			else
				guest.nextStutter = now
					+ G.StutterSeconds[1]
					+ math.random() * (G.StutterSeconds[2] - G.StutterSeconds[1])
			end
		end
		if write then
			for name, value in values do
				local m = guest.motors[name]
				if m then
					m.Transform = CFrame.new(value[4], value[5], value[6]) * CFrame.Angles(value[1], value[2], value[3])
				end
			end
			-- His coat's skirt follows each thigh part of the way.
			for _, side in { "Left", "Right" } do
				local m, hip = guest.motors[side .. "Coat"], values[side .. "Hip"]
				if m and hip then
					m.Transform = CFrame.Angles(hip[1] * G.CoatSwing, 0, hip[3] * G.CoatSwing)
				end
			end
		end
		-- Fingers: the hand on the jamb grips it while he peeks; held, or
		-- playful, they drum.
		local curl = FINGER_CURL[pose] or 0.5
		local drum = ((pose == "Hold" and (guest.heldFor or 0) > 1.5) or (pose == "Idle" and mood == "Playful"))
				and 0.35
			or 0
		for side, hand in guest.hands do
			local grip = (pose == "Peek" or pose == "FingersPeek") and ((lean >= 0) == (side == "Right"))
			GuestFace.curlHand(hand, grip and 1.35 or curl, dt, math.random, drum)
		end
		-- The face.
		local distance = (guest.head.Position - camera.CFrame.Position).Magnitude
		local range = G.SmileCloseRange
		local closeness = 1 - math.clamp((distance - range[1]) / (range[2] - range[1]), 0, 1)
		-- The longer you hold him, the wider the smile.
		closeness = math.max(closeness, math.min(1, (guest.heldFor or 0) / 8))
		local width, open = GuestPose.smile(form, closeness, pose == "BackAway")
		local override = model:GetAttribute("GuestSmile")
		if override then
			width, open = GuestPose.smile(form, override, true)
		end
		-- From Fraying, up close, the mouth hangs open.
		if form >= 1 and distance < G.GapeRange then
			open = math.max(open, 0.6 + 0.4 * (1 - distance / G.GapeRange))
		end
		guest.face:SetForm(form)
		guest.face:SetSmile(width, open)
		self:_maskBetweenLooks(camera, form, distance, beam, dt)
		-- His eyes: caught in your torch, or a faint glow in the dark whenever
		-- he faces you; they follow you either way.
		local toFace = guest.head.Position - camera.CFrame.Position
		local facing = toFace.Magnitude > 0.5 and guest.head.CFrame.LookVector:Dot(-toFace.Unit) >= 0.3
		local glow = G.EyeGlow[math.clamp(form, 0, 2) + 1]
		guest.face:SetShine(self:_eyeShine(camera) and 1 or (facing and distance < G.EyeGlowRange and glow or 0))
		guest.face:LookAt(camera.CFrame.Position)
	end

	self:_glass(dt, camera, shown)

	-- His mood, by ear (Logic/GuestMood): an irritated Guest's knuckles and
	-- neck crack; a playful one giggles under his breath; and held past five
	-- seconds his neck creaks as it tips too far. Only while he's visible to
	-- you, like his steps.
	if shown then
		local audio = self.controllers.AudioController
		local head = guest.head.Position
		local muffle = blocked(camera.CFrame.Position, head, { model, player.Character })
		if pose == "Hold" and (guest.heldFor or 0) > 5 and not guest.neckCracked then
			guest.neckCracked = true
			audio:PlayAt("GuestCrack", head, 0.55, 0.8, muffle)
		elseif pose ~= "Hold" then
			guest.neckCracked = false
		end
		if now >= (guest.nextMoodSound or 0) then
			local sound = MOOD_SOUNDS[mood or ""]
			guest.nextMoodSound = now
				+ (sound and (sound.every[1] + math.random() * (sound.every[2] - sound.every[1])) or 4)
			if sound and pose ~= "Run" and pose ~= "Lunge" then
				audio:PlayAt(sound.key, head, sound.volume, sound.pitch + math.random() * 0.08, muffle)
			end
		end
	end

	-- You only hear him walk while he's visible to you (owner, 2026-10-03):
	-- steps from something you can't see felt unnatural. His breath and
	-- creaks behind you are server tells; the Director adds distant steps.
	if shown and #planted > 0 then
		local audio = self.controllers.AudioController
		local volume = G.FootstepVolume[pose] or 0.4
		local character = player.Character
		for _, side in planted do
			local foot = guest.feet[side]
			if foot then
				local ignore = { model }
				if character then
					table.insert(ignore, character)
				end
				local muffled = blocked(camera.CFrame.Position, foot.Position, ignore)
				audio:PlayAt("Footstep", foot.Position, volume, 0.78 + math.random() * 0.08, muffled)
			end
		end
	end
end

-- Sounds and moments the server decides (Stalker/Stalk): the knock at the
-- door, the warnings behind your back, the yank, the lunge, the catch.
function GuestController:_event(event)
	local audio = self.controllers.AudioController
	local kind = event.kind
	local camera = Workspace.CurrentCamera
	local function muffled(position: Vector3): boolean
		local ignore = {}
		if guest then
			table.insert(ignore, guest.model)
		end
		if player.Character then
			table.insert(ignore, player.Character)
		end
		return blocked(camera.CFrame.Position, position, ignore)
	end
	if kind == "knock" then
		audio:PlayAt("FrontDoorKnock", event.position, 1, 1, muffled(event.position))
		audio:Caption("[three knocks at the front door]")
	elseif kind == "breath" then
		-- Close behind you: only you hear it, and your torch stutters (not on
		-- every breath, so it stays a tell and not a strobe).
		audio:PlayAt("Breath", event.position, 0.9, 0.7 + math.random() * 0.08)
		audio:Caption("[breathing, right behind you]")
		local now = os.clock()
		if now >= torchStutterAt then
			torchStutterAt = now + G.TorchStutterGap[1] + math.random() * (G.TorchStutterGap[2] - G.TorchStutterGap[1])
			self.controllers.ActionController:StutterTorch(G.TorchStutterSeconds)
		end
	elseif kind == "creak" then
		local key = math.random() < 0.5 and "Creak" or "CreakAlt"
		audio:PlayAt(key, event.position, 0.75, 0.85 + math.random() * 0.2, muffled(event.position))
		audio:Caption("[a floorboard creaks]")
	elseif kind == "yank" then
		audio:PlayAt("Whoosh", event.position, 0.3, 0.4)
	elseif kind == "lunge" then
		audio:PlayAt("WindUp", event.position, 1, 0.5)
	elseif kind == "caught" then
		audio:PlayFor("Sting", event.position, 0.7, 1, 2)
		audio:Caption("[a strangled cry]")
	elseif kind == "held" then
		-- Your eyes (or your beam, alone) stopped him (Config.Stare).
		audio:Caption(event.beam and "[caught in your light, it stops]" or "[watched by two of you, it stops]")
	elseif kind == "unheld" then
		audio:Caption("[the light isn't enough any more. It comes on]")
	elseif kind == "graced" then
		-- Just pulled up with him right there (Config.Run.ReviveGraceSeconds).
		audio:Caption("[it lets you get up. Run.]")
	elseif kind == "heard" then
		audio:Caption("[he heard you pick up]")
	elseif kind == "keys" then
		-- His keys at a locked door (Logic/GuestKeys): the lock is about to turn.
		audio:PlayAt("GuestKeys", event.position, 0.8, 1, muffled(event.position))
		audio:Caption("[keys, at a locked door]")
	elseif kind == "spotted" then
		-- A hunt, and he has seen you (Logic/HuntPhases "chase").
		audio:PlayAt("GuestRasp", event.position, 0.9, 1, muffled(event.position))
		spottedTold += 1
		if spottedTold <= G.SpottedCues then
			audio:Caption("[it sees you]")
		end
	elseif kind == "sniff" then
		-- He lost you and stands listening, sniffing the air.
		audio:PlayAt("GuestSniff", event.position, 0.7, 1, muffled(event.position))
		audio:Caption("[a long, slow sniff]")
	elseif kind == "doorShadow" then
		self:_doorShadow(event)
	elseif kind == "usher" then
		-- He stepped aside for you (Logic/StalkRules.makesWay): said the first
		-- times, so the promise is learnt.
		ushered += 1
		if ushered <= 2 then
			audio:Caption("[it steps aside, and holds out a hand: after you]")
		end
	elseif kind == "catch" then
		self:_jumpscare(event.catch)
	end
end

-- His feet's shadow in the gap under a door he waits behind (Stalker/Stalk
-- BehindTheDoor): a dark band across the threshold on your side, darker
-- where his shoes are. It's really him; it goes when he does.
function GuestController:_doorShadow(event)
	local id = tostring(event.id)
	if shadows[id] then
		shadows[id]:Destroy()
		shadows[id] = nil
	end
	if not event.on or typeof(event.position) ~= "Vector3" or typeof(event.toward) ~= "Vector3" then
		return
	end
	local toward = Vector3.new(event.toward.X, 0, event.toward.Z)
	if toward.Magnitude < 0.1 then
		return
	end
	toward = toward.Unit
	local base = event.position + toward * 0.55 + Vector3.new(0, 0.03, 0)
	local cf = CFrame.lookAt(base, base + toward)
	local model = Instance.new("Model")
	model.Name = "GuestDoorShadow"
	local function piece(size: Vector3, at: CFrame, transparency: number)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = at
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.new(0, 0, 0)
		p.Transparency = transparency
		p.Parent = model
		return p
	end
	piece(Vector3.new(2.8, 0.02, 0.8), cf, 0.5)
	for _, x in { -0.42, 0.42 } do
		local foot = piece(Vector3.new(0.42, 0.02, 0.62), cf * CFrame.new(x, 0.004, 0.1), 0.2)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0.2, 1)
		mesh.Parent = foot
	end
	model.Parent = Workspace
	shadows[id] = model
end

-- Caught. Two ways (Config.Guest.Catch): "rush", his face grinning wide open
-- rushes in to fill your screen, then black; "quiet", black and a breath in
-- your ear, then his face resolving slowly out of the dark, lit from below,
-- then the sting and black. Either is a picture, not the camera: nothing
-- moves your view (comfort rule, doc section 4), and it works when he took
-- you from behind.
function GuestController:_jumpscare(mode: string?)
	local audio = self.controllers.AudioController
	mode = (mode == "quiet" or mode == "rush") and mode
		or ((G.Catch == "quiet" or G.Catch == "rush") and G.Catch)
		or "rush"
	local quiet = mode == "quiet"
	if quiet then
		audio:PlayFor("Breath", nil, 1, 0.55, 1.4)
	else
		audio:PlayFor("Sting", nil, 1, 1, 2.2)
	end
	if not guest or not guest.head.Parent then
		return
	end
	local head = guest.head
	guest.face:SetForm(math.max(guest.model:GetAttribute("GuestForm") or 0, 1))
	guest.face:SetSmile(math.rad(108), 1)
	guest.face:SetShine(1) -- his eyes catch the light, right in front of you
	-- Staring dead into you.
	guest.face:LookAt(guest.head.CFrame * Vector3.new(0, 0, -6))
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuestJumpscare"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = quiet and 0 or 0.35
	black.BorderSizePixel = 0
	black.Parent = gui
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	-- Dark, lit harshly from below (dimmer and lower still for the quiet one:
	-- a face in a cellar, not a mask under a lamp).
	viewport.Ambient = quiet and Color3.fromRGB(14, 12, 12) or Color3.fromRGB(34, 30, 28)
	viewport.LightColor = quiet and Color3.fromRGB(150, 128, 104) or Color3.fromRGB(215, 190, 160)
	viewport.LightDirection = quiet and Vector3.new(-0.1, 0.9, -0.4) or Vector3.new(-0.25, 0.75, -0.6)
	viewport.ImageTransparency = quiet and 1 or 0
	viewport.Parent = gui
	local cam = Instance.new("Camera")
	cam.FieldOfView = 45
	cam.CFrame = CFrame.identity
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Let the welds settle the wide-open smile, then copy the head.
	task.wait()
	local pieces = {}
	local headCF = head.CFrame
	local parts = { head }
	for _, d in head:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "NeckSkin" then
			table.insert(parts, d)
		end
	end
	for _, part in parts do
		local copy = part:Clone()
		for _, child in copy:GetChildren() do
			if not (child:IsA("SpecialMesh") or child:IsA("Decal")) then
				child:Destroy()
			end
		end
		copy.Anchored = true
		copy.LocalTransparencyModifier = 0
		copy.Parent = viewport
		table.insert(pieces, { part = copy, rel = headCF:ToObjectSpace(part.CFrame) })
	end
	local started = os.clock()
	local connection
	local stung = false
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if quiet then
			-- Black and a breath; from 0.4 s his face resolves out of the dark
			-- over a second, farther off and drifting closer, no tremble; at
			-- 1.5 s the sting and a hard cut to black, which holds, then lifts.
			local reveal = math.clamp((t - 0.4) / 1.0, 0, 1)
			local distance = 7.5 - 1.3 * reveal
			local cf = CFrame.new(0.1, 0.25, -distance) * CFrame.Angles(0, math.pi, math.rad(-9))
			for _, piece in pieces do
				piece.part.CFrame = cf * piece.rel
			end
			viewport.ImageTransparency = t < 1.5 and (1 - reveal * 0.9) or 1
			if t >= 1.5 and not stung then
				stung = true
				audio:PlayFor("Sting", nil, 0.85, 0.9, 2)
			end
			black.BackgroundTransparency = t > 2.6 and math.min(1, (t - 2.6) * 1.4) or 0
			if t > 3.4 then
				connection:Disconnect()
				gui:Destroy()
			end
			return
		end
		-- Rushes in over 0.3 s, then holds, shuddering, in your face; at half
		-- a second the head jerks over, as far as a neck shouldn't go.
		local rush = math.clamp(t / 0.3, 0, 1)
		local distance = 10 - 8.4 * (1 - (1 - rush) ^ 3)
		local tremble = t > 0.3 and 0.05 or 0
		local jerk = t > 0.5 and math.rad(-38) or math.rad(-16)
		local cf = CFrame.new((math.random() - 0.5) * tremble, 0.12 + (math.random() - 0.5) * tremble, -distance)
			* CFrame.Angles(0, math.pi, jerk)
		for _, piece in pieces do
			piece.part.CFrame = cf * piece.rel
		end
		black.BackgroundTransparency = t < 0.55 and 0.35 or math.max(0, 0.35 - (t - 0.55) * 3)
		if t > 0.75 then
			viewport.ImageTransparency = math.min(1, (t - 0.75) * 6)
		end
		if t > 1.6 then
			black.BackgroundTransparency = math.min(1, (t - 1.6) * 1.5)
		end
		if t > 2.4 then
			connection:Disconnect()
			gui:Destroy()
		end
	end)
end

-- Wrong between looks (docs/ART.md "The Guest", 2026-10-07): look away from
-- him and back, and sometimes his mask has slid round his head and turned on
-- itself; while you watch, it slowly turns back (in your beam, in jerks).
-- Only ever while you weren't looking, and only on this screen: a divergence
-- of atmosphere (two of you may not agree on what you saw). Cosmetic, so
-- math.random.
function GuestController:_maskBetweenLooks(camera: Camera, form: number, distance: number, beam: boolean, dt: number)
	local now = os.clock()
	if now >= (guest.lookCheckAt or 0) then
		guest.lookCheckAt = now + 0.1
		local toHead = guest.head.Position - camera.CFrame.Position
		local ignore = { guest.model }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		local looking = distance < G.MaskTurnRange
			and camera.CFrame.LookVector:Dot(toHead.Unit) > math.cos(math.rad(G.MaskTurnLookCone))
			and not blocked(camera.CFrame.Position, guest.head.Position, ignore)
		if looking and not guest.looking then
			local away = now - (guest.lookedAwayAt or now)
			-- (The player attribute DebugMaskTurn makes it every time, for tests;
			-- a number holds it wrong that many seconds.)
			local debug = player:GetAttribute("DebugMaskTurn")
			local chance = debug and 1 or G.MaskTurnChance[form + 1]
			if guest.lookedAwayAt and away >= G.MaskTurnAwaySeconds and math.random() < chance then
				local function side(range)
					local x = math.rad(range[1] + math.random() * (range[2] - range[1]))
					return math.random() < 0.5 and -x or x
				end
				guest.maskTurn = {
					yaw = side(G.MaskTurnYaw),
					roll = side(G.MaskTurnRoll),
					pitch = side({ 0, G.MaskTurnPitch }),
					amount = 1,
					holdUntil = now + (type(debug) == "number" and debug or G.MaskTurnHold),
					grated = false,
				}
			end
		elseif guest.looking and not looking then
			guest.lookedAwayAt = now
		end
		guest.looking = looking
	end
	local turn = guest.maskTurn
	if not turn then
		return
	end
	if guest.looking and now >= turn.holdUntil then
		if not turn.grated then
			-- Porcelain grating on bone as it starts back.
			turn.grated = true
			self.controllers.AudioController:PlayAt("Creak", guest.head.Position, 0.22, 1.7)
		end
		-- In your beam it clicks back in jerks, like the rest of him.
		if not beam or now >= (turn.nextStep or 0) then
			turn.nextStep = now + 0.12 + math.random() * 0.1
			turn.amount = math.max(0, turn.amount - (beam and 0.1 or dt / G.MaskTurnBackSeconds))
		end
	end
	local k = turn.amount * turn.amount * (3 - 2 * turn.amount)
	guest.face:SetTurn(turn.yaw * k, turn.roll * k, turn.pitch * k)
	if turn.amount <= 0 then
		guest.maskTurn = nil
		guest.face:SetTurn(nil)
	end
end

-- Windows and mirrors (Lib/GuestReflection): his reflection when he's
-- behind you, or (a divergence, for you alone) his face at the glass.
function GuestController:_glass(dt: number, camera: Camera, shown: boolean)
	local reflection = guest.reflection
	local eye = camera.CFrame.Position
	if reflection:Mode() == "face" then
		reflection:UpdateFace(eye, camera.CFrame.LookVector, dt)
		return
	end
	guest.paneClock += dt
	if guest.paneClock >= 1 / 8 then
		guest.paneClock = 0
		local best, bestModel = nil, nil
		local head = guest.head.Position
		if shown and (head - eye).Magnitude < G.ReflectionBodyRange then
			local bestDistance = G.ReflectionGlassRange
			for _, model in CollectionService:GetTagged(Constants.Tags.Window) do
				local glass = model:FindFirstChild("Glass")
				if glass and glass:IsA("BasePart") then
					local toGlass = glass.Position - eye
					local d = toGlass.Magnitude
					if
						d < bestDistance
						and d > 0.5
						and camera.CFrame.LookVector:Dot(toGlass.Unit) > 0.3
						and GuestReflection.inPane(glass, eye, head)
					then
						best, bestModel, bestDistance = glass, model, d
					end
				end
			end
		end
		if best then
			reflection:ShowReflection(best, guest.model, bestModel:GetAttribute("Kind") == "Mirror")
		elseif reflection:Mode() == "reflection" then
			reflection:Close()
		end
	end
	if reflection:Mode() == "reflection" then
		reflection:UpdateReflection(eye)
	end
end

-- The server's "windowFace" scare: his face pressed to a window, for you
-- alone, while his body is elsewhere. Tapping first, so you turn.
function GuestController:WindowFace(glass: BasePart?)
	if not guest or not glass or not glass.Parent or not guest.head.Parent then
		return
	end
	guest.reflection:ShowFace(glass, guest.head)
	local audio = self.controllers.AudioController
	audio:PlayAt("GlassTap", glass.Position, 0.8, 1)
	audio:Caption("[tapping on the window glass]")
end

-- Two pin-points of light in his eye hollows when your torch beam is on his
-- face and he's facing you.
function GuestController:_eyeShine(camera: Camera): boolean
	if not guest.inBeam then
		return false
	end
	local toFace = guest.head.Position - camera.CFrame.Position
	return toFace.Magnitude > 0.5 and guest.head.CFrame.LookVector:Dot(-toFace.Unit) >= 0.35
end

-- Your torch's beam is on him (on, in its cone, in range, nothing between).
function GuestController:_beamOnHim(camera: Camera): boolean
	if not visible or player:GetAttribute(Constants.PlayerAttributes.Flashlight) ~= true then
		return false
	end
	local head = guest.head
	local toFace = head.Position - camera.CFrame.Position
	local distance = toFace.Magnitude
	if distance > G.EyeShineRange or distance < 0.5 then
		return false
	end
	if camera.CFrame.LookVector:Dot(toFace.Unit) < math.cos(math.rad(G.EyeShineCone)) then
		return false
	end
	local ignore = { guest.model }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	return not blocked(camera.CFrame.Position, head.Position, ignore)
end

return GuestController
