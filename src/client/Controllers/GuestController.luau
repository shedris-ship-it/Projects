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
local PlayerPose = require(Shared.Logic.PlayerPose)
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
local disguise = nil -- { clone, joints, phase, last } while he wears a friend's look for you

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
			setModifier(guest.model, (visible and not disguise) and 0 or 1)
		end
		if disguise then
			setModifier(disguise.clone, visible and 0 or 1)
		end
	end)
	-- His disguise: the friend's look follows his body and stands wrong.
	RunService.Stepped:Connect(function(_, dt)
		if disguise then
			local ok, err = pcall(self._disguiseFrame, self, dt)
			if not ok then
				warn("[Consensus] disguise failed: " .. tostring(err))
				self:_undisguise(false)
			end
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

	-- His drawn-out neck follows where the joints actually put his head.
	RunService.RenderStepped:Connect(function()
		if guest and guest.neck and guest.model.Parent then
			self:_neck()
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
	Crawl = 1.0, -- clawing at the floor
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
		form = model:GetAttribute("GuestForm") or 0,
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
		self:_grow(form)
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
-- His disguise (StalkerService:_disguise; the squad playtest, 2026-10-08:
-- "maybe the guest should shapeshift", the owner's choice: a teammate). For
-- you alone, his body hidden and a friend's look in its place: a copy of
-- their character, everything that isn't the body stripped (no torch, no
-- light, no name, no sound), standing wrong (Logic/PlayerPose.wrong). Go
-- close and it falls away (the server says reveal).
local STRIP = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	ProximityPrompt = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Sound = true,
	BillboardGui = true,
	SurfaceGui = true,
	ParticleEmitter = true,
}

function GuestController:_disguise(friendId: number?)
	self:_undisguise(false)
	local friend = friendId and Players:GetPlayerByUserId(friendId)
	local source = friend and friend.Character
	if not guest or not source then
		return
	end
	local archivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = archivable
	if not clone then
		return
	end
	clone.Name = "Guest's friend"
	for _, d in clone:GetDescendants() do
		-- (A model inside a character is a tool in their hands, their torch.)
		local held = d:IsA("Model") and not d:FindFirstChildOfClass("Humanoid") and not d:IsA("Accessory")
		if STRIP[d.ClassName] or held then
			d:Destroy()
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.PlatformStand = true
		humanoid.EvaluateStateMachine = false
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy()
		end
	end
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		clone:Destroy()
		return
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.LocalTransparencyModifier = visible and 0 or 1
		end
	end
	-- Feet on his floor: his root rides higher than a person's.
	root.CFrame = guest.root.CFrame * CFrame.new(0, -(GuestPose.Rig.rootY - PlayerPose.Rig.rootY), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = guest.root
	weld.Part1 = root
	weld.Parent = root
	clone.Parent = Workspace
	local joints = {}
	for _, d in clone:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and PlayerPose.Rig[d.Name] then
			joints[d.Name] = d
		end
	end
	disguise = { clone = clone, joints = joints, phase = 0, last = guest.root.Position }
	setModifier(guest.model, 1)
end

function GuestController:_undisguise(reveal: boolean)
	local had = disguise
	disguise = nil
	if had then
		had.clone:Destroy()
	end
	if guest then
		setModifier(guest.model, visible and 0 or 1)
	end
	if reveal and had then
		-- The look falls away: his own shape, your torch stutters, the lights
		-- round you shudder.
		self.controllers.ActionController:StutterTorch(1.2)
		local effects = self.controllers.EffectsController
		if effects then
			effects:FlickerNear(25, 1)
		end
		self.controllers.AudioController:Caption("[that isn't them]")
	end
end

function GuestController:_disguiseFrame(dt: number)
	if not guest or not disguise.clone.Parent then
		self:_undisguise(false)
		return
	end
	-- Keep his own body hidden (anything that shows him again this frame).
	if visible then
		setModifier(guest.model, 1)
	end
	local here = guest.root.Position
	local moved = Vector3.new(here.X - disguise.last.X, 0, here.Z - disguise.last.Z).Magnitude
	disguise.last = here
	disguise.phase += moved * 1.8
	local values = PlayerPose.wrong(disguise.phase, math.clamp(moved / math.max(dt, 1e-3) / 3, 0, 1))
	for name, joint in disguise.joints do
		local v = values[name]
		if v then
			joint.Transform = CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
		end
	end
end

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
	if kind == "disguise" then
		if event.on then
			self:_disguise(event.friend)
		else
			self:_undisguise(event.reveal == true)
		end
	elseif kind == "knock" then
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

-- Caught. Two ways (Config.Guest.Catch): "rush", his finger bones hook round
-- the edges of your view and his face grinning wide open rushes in between
-- them to fill your screen, then black; "quiet", black and a breath in
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
	local form = guest.model:GetAttribute("GuestForm") or 0
	-- His hands first (2026-10-07): long finger bones curl round the edges of
	-- your view, then his face comes between them. At Breaking the mask splits
	-- down the middle as the head jerks.
	local hands = self:_screenHands(viewport, form)
	local split = form >= 2 and self:_catchSplit(viewport, headCF) or nil
	local lead = quiet and 0 or G.CatchHandsLead
	local started = os.clock()
	local last = started
	local connection
	local stung = false
	-- (The player attribute DebugCatchAt freezes the catch at that second for
	-- eight seconds, for screenshots.)
	local freeze = player:GetAttribute("DebugCatchAt")
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local t = now - started
		if type(freeze) == "number" then
			t = if t < freeze + 8 then math.min(t, freeze) else 99
		end
		local dt = now - last
		last = now
		if quiet then
			-- Black and a breath; from 0.4 s his face resolves out of the dark
			-- over a second, farther off and drifting closer, no tremble, his
			-- fingers closing on the edges of your view; at 1.5 s the sting and
			-- a hard cut to black, which holds, then lifts.
			local reveal = math.clamp((t - 0.4) / 1.0, 0, 1)
			local distance = 7.5 - 1.3 * reveal
			local cf = CFrame.new(0.1, 0.25, -distance) * CFrame.Angles(0, math.pi, math.rad(-9))
			for _, piece in pieces do
				piece.part.CFrame = cf * piece.rel
			end
			hands:Update(math.clamp((t - 0.3) / 0.6, 0, 1), math.clamp((t - 0.6) / 0.6, 0, 1), 0, dt)
			if split then
				split:Update(cf, math.clamp((t - 1.0) / 0.4, 0, 1))
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
		-- His fingers hook round the edges of your view; then his face rushes
		-- in over 0.3 s, and holds, shuddering, in your face; half a second in,
		-- the head jerks over, as far as a neck shouldn't go.
		hands:Update(math.clamp(t / 0.18, 0, 1), math.clamp((t - 0.08) / 0.22, 0, 1), t > 0.3 and 0.012 or 0, dt)
		local f = t - lead
		local rush = math.clamp(f / 0.3, 0, 1)
		local distance = 10 - 8.4 * (1 - (1 - rush) ^ 3)
		local tremble = f > 0.3 and 0.05 or 0
		local jerk = f > 0.5 and math.rad(-38) or math.rad(-16)
		local cf = CFrame.new((math.random() - 0.5) * tremble, 0.12 + (math.random() - 0.5) * tremble, -distance)
			* CFrame.Angles(0, math.pi, jerk)
		for _, piece in pieces do
			piece.part.CFrame = cf * piece.rel
		end
		if split then
			split:Update(cf, math.clamp((f - 0.5) / 0.12, 0, 1))
		end
		black.BackgroundTransparency = f < 0.55 and 0.35 or math.max(0, 0.35 - (f - 0.55) * 3)
		if f > 0.75 then
			viewport.ImageTransparency = math.min(1, (f - 0.75) * 6)
		end
		if f > 1.6 then
			black.BackgroundTransparency = math.min(1, (f - 1.6) * 1.5)
		end
		if f > 2.4 then
			connection:Disconnect()
			gui:Destroy()
		end
	end)
end

-- His hands at the edges of your view in the catch: bone fingers sliding in
-- from beyond each edge (`slide` 0..1) and hooking round towards you (`grip`
-- 0..1), drawn in the jumpscare's viewport by hand (no joints there).
function GuestController:_screenHands(viewport: ViewportFrame, form: number)
	local camera = viewport.CurrentCamera :: Camera
	local depth = 3.0
	local size = viewport.AbsoluteSize
	local aspect = size.Y > 0 and size.X / size.Y or 16 / 9
	local halfH = math.tan(math.rad(camera.FieldOfView / 2)) * depth
	local halfW = halfH * aspect
	local k = 1.15 * G.FingerScale[math.clamp(form, 0, 2) + 1]
	local bone = Color3.fromRGB(176, 170, 158)
	local function piece(shape: Enum.PartType, size3: Vector3, ball: boolean?): BasePart
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size3
		p.Color = bone
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		if ball then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.Parent = viewport
		return p
	end
	local sides = {}
	for _, side in { -1, 1 } do
		local hand = { side = side, fingers = {} }
		hand.palm = piece(Enum.PartType.Block, Vector3.new(0.5, 0.26, 0.09), true)
		-- Four fingers across the hand, top to bottom, and a thumb below.
		-- (y across the hand, length, fan: each finger splays a little.)
		for i, spec in
			{ { 0.1, 1.0, 9 }, { 0.035, 1.08, 3 }, { -0.035, 1.0, -3 }, { -0.1, 0.86, -9 }, { -0.17, 0.7, -22 } }
		do
			local l1, l2 = 0.38 * k * spec[2], 0.34 * k * spec[2]
			table.insert(hand.fingers, {
				y = spec[1],
				thumb = i == 5,
				fan = math.rad(spec[3]),
				l1 = l1,
				l2 = l2,
				s1 = piece(Enum.PartType.Cylinder, Vector3.new(l1, 0.05, 0.05)),
				s2 = piece(Enum.PartType.Cylinder, Vector3.new(l2, 0.044, 0.044)),
				k1 = piece(Enum.PartType.Ball, Vector3.one * 0.066),
				k2 = piece(Enum.PartType.Ball, Vector3.one * 0.058),
				tip = piece(Enum.PartType.Ball, Vector3.one * 0.044),
				jitter = (i * 0.37) % 0.3,
			})
		end
		table.insert(sides, hand)
	end
	local hands = {}
	function hands:Update(slide: number, grip: number, tremble: number, _dt: number)
		for _, hand in sides do
			local side = hand.side
			local inward = Vector3.new(-side, 0, 0)
			local shake = Vector3.new(0, (math.random() - 0.5) * tremble, (math.random() - 0.5) * tremble)
			-- From well beyond the edge to just past it: only the fingers show.
			local palm = Vector3.new(side * (halfW + 0.6 - 0.42 * slide), 0.05, -depth) + shake
			hand.palm.CFrame = CFrame.fromMatrix(palm, inward, Vector3.yAxis)
			for _, finger in hand.fingers do
				local root = palm + inward * 0.24 + Vector3.new(0, finger.y, 0)
				if finger.thumb then
					root -= inward * 0.12
				end
				-- Long fingers reaching in, fanned a little, the joints hooking
				-- slightly towards you as they grip.
				local reach = inward * math.cos(finger.fan) + Vector3.yAxis * math.sin(finger.fan)
				local a1 = grip * (0.3 + finger.jitter)
				local a2 = a1 + grip * (0.55 + finger.jitter)
				local d1 = reach * math.cos(a1) + Vector3.zAxis * math.sin(a1)
				local d2 = reach * math.cos(a2) + Vector3.zAxis * math.sin(a2)
				local mid = root + d1 * finger.l1
				local tip = mid + d2 * finger.l2
				finger.s1.CFrame = CFrame.lookAt(root + d1 * finger.l1 / 2, root + d1 * finger.l1)
					* CFrame.Angles(0, math.pi / 2, 0)
				finger.s2.CFrame = CFrame.lookAt(mid + d2 * finger.l2 / 2, mid + d2 * finger.l2)
					* CFrame.Angles(0, math.pi / 2, 0)
				finger.k1.CFrame = CFrame.new(root)
				finger.k2.CFrame = CFrame.new(mid)
				finger.tip.CFrame = CFrame.new(tip)
			end
		end
	end
	hands:Update(0, 0, 0, 0)
	return hands
end

-- At Breaking, the catch splits his mask: a jagged black split from brow to
-- chin that opens as his head jerks (`open` 0..1), the dark beneath showing.
function GuestController:_catchSplit(viewport: ViewportFrame, headCF: CFrame)
	local mask = guest.face.mask
	local rel = headCF:ToObjectSpace(mask.CFrame)
	local a, b, c = mask.Size.X / 2, mask.Size.Y / 2, mask.Size.Z / 2
	-- A zigzag down the face, between the eyes and through the mouth (u, v
	-- across and up the mask, -1..1).
	local path = {
		{ 0.05, 0.95 },
		{ -0.13, 0.72 },
		{ 0.09, 0.46 },
		{ -0.11, 0.2 },
		{ 0.1, -0.08 },
		{ -0.08, -0.42 },
		{ 0.06, -0.66 },
		{ -0.03, -0.93 },
	}
	local function surface(u: number, v: number): Vector3
		local zz = 1 - u * u - v * v
		return Vector3.new(u * a, v * b, -c * math.sqrt(math.max(zz, 0.02)) - 0.006)
	end
	local strips = {}
	for i = 1, #path - 1 do
		local p1, p2 = surface(path[i][1], path[i][2]), surface(path[i + 1][1], path[i + 1][2])
		local along = p2 - p1
		local strip = Instance.new("Part")
		strip.Anchored = true
		strip.CanCollide = false
		strip.CastShadow = false
		strip.Material = Enum.Material.Neon
		strip.Color = Color3.new(0, 0, 0)
		strip.Size = Vector3.new(0.004, along.Magnitude + 0.02, 0.01)
		strip.Transparency = 1
		strip.Parent = viewport
		local up = along.Unit
		local out = Vector3.new(0, 0, -1)
		local right = up:Cross(out).Unit
		table.insert(strips, {
			part = strip,
			rel = rel * CFrame.fromMatrix((p1 + p2) / 2, right, up),
			length = along.Magnitude + 0.02,
		})
	end
	local split = {}
	function split:Update(cf: CFrame, open: number)
		for _, strip in strips do
			strip.part.Transparency = open > 0 and 0 or 1
			strip.part.Size = Vector3.new(0.006 + 0.034 * open, strip.length, 0.01)
			strip.part.CFrame = cf * strip.rel
		end
	end
	return split
end

-- He grows wrong as the night goes on (docs/ART.md "The Guest", 2026-10-07):
-- his fingers lengthen from Fraying; at Breaking his coat hangs in tatters,
-- his neck draws out of his collar (Logic/GuestPose.neckStretch, which the
-- server knows too) and his knees bend the wrong way (GuestPose).
function GuestController:_grow(form: number)
	if guest.grownFor == form then
		return
	end
	guest.grownFor = form
	local scale = G.FingerScale[math.clamp(form, 0, 2) + 1]
	for _, hand in guest.hands do
		GuestFace.setFingerScale(hand, scale)
	end
	if form >= 2 and not guest.tatters then
		guest.tatters = self:_tatters()
	end
	for _, part in guest.tatters or {} do
		part.Transparency = form >= 2 and 0 or 1
	end
	if form >= 2 and not guest.neck then
		local neck = Instance.new("Part")
		neck.Name = "NeckDrawn"
		neck.Shape = Enum.PartType.Cylinder
		neck.Color = Color3.fromRGB(7, 6, 8)
		neck.Material = Enum.Material.SmoothPlastic
		neck.Anchored = true
		neck.CanCollide = false
		neck.CanQuery = false
		neck.CanTouch = false
		neck.CastShadow = false
		neck.Size = Vector3.new(0.1, 0.3, 0.3)
		neck.Transparency = 1
		neck.Parent = guest.model
		guest.neck = neck
	end
end

-- The neck between his collar and his head, when it has drawn out: from the
-- neck joint on his chest to where the neck meets his head.
function GuestController:_neck()
	local neck = guest.neck
	local upper = guest.model:FindFirstChild("UpperTorso")
	if not upper then
		return
	end
	local from = (upper :: BasePart).CFrame:PointToWorldSpace(
		Vector3.new(0, Rig.neckY - Rig.waistY - Rig.upperTorsoSize[2] / 2 - 0.1, 0)
	)
	local to = guest.head.CFrame:PointToWorldSpace(Vector3.new(0, -(Rig.neckLength + Rig.headSize[2] / 2) + 0.2, 0))
	local along = to - from
	local length = along.Magnitude
	if (guest.grownFor or 0) < 2 or length < 0.35 then
		neck.Transparency = 1
		return
	end
	neck.Transparency = 0
	local x = along.Unit
	local y = math.abs(x.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
	local z = x:Cross(y).Unit
	neck.Size = Vector3.new(length, 0.3, 0.3)
	neck.CFrame = CFrame.fromMatrix(from + along / 2, x, z:Cross(x))
end

-- Rags hanging from his coat's hem (Breaking), on the coat's own joints; the
-- same rags for everyone.
function GuestController:_tatters(): { BasePart }
	local parts = {}
	for _, side in { "Left", "Right" } do
		local bone = guest.model:FindFirstChild(side .. "CoatTail")
		if bone and bone:IsA("BasePart") then
			local sx = side == "Left" and -1 or 1
			for i = 1, 8 do
				-- Round the outside of the hem (not the side facing the other leg).
				local theta = math.rad(-110 + i * 30)
				local length = 0.5 + ((i * 37 + (sx > 0 and 11 or 0)) % 9) / 9 * 0.9
				local rag = Instance.new("Part")
				rag.Name = "Tatter"
				rag.Color = Color3.fromRGB(18, 17, 20)
				rag.Material = Enum.Material.Fabric
				rag.MaterialVariant = "CoatWool"
				rag.CanCollide = false
				rag.CanQuery = false
				rag.CanTouch = false
				rag.CastShadow = false
				rag.Massless = true
				rag.Size = Vector3.new(0.1 + (i % 3) * 0.04, length, 0.03)
				local x = sx * (0.02 + math.cos(theta) * 0.34)
				local z = 0.06 + math.sin(theta) * 0.38
				local weld = Instance.new("Weld")
				weld.Part0 = bone
				weld.Part1 = rag
				weld.C0 = CFrame.new(x, G.CoatHem - Rig.hipY - length / 2 + 0.06, z)
					* CFrame.Angles(0, math.atan2(sx * math.cos(theta), math.sin(theta)), 0)
					* CFrame.Angles(math.rad((i % 2 == 0) and 5 or -4), 0, 0)
				weld.Parent = rag
				rag.Parent = bone
				table.insert(parts, rag)
			end
		end
	end
	return parts
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
