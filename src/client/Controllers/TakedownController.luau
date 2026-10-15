-- The Guest's takedown, played on every client (the visual rework V8; the
-- owner's picks, 2026-10-15, after Threshold: "the camera goes into 3rd
-- person and you watch your character get mauled"). The server stages it
-- (StalkerService:_takedown) and every client draws both bodies from the same
-- timeline (Logic/Takedown): the one he caught on their own screen in the
-- third person, letterboxed, the camera standing only where it can see it
-- (Logic/ShotPicker, Controllers/CinemaController); everyone else sees it
-- happen where it happens. Nothing is uploaded: the joints are written each
-- frame like every other pose here (Controllers/PoseController,
-- GuestController asks GuestFrame for his).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local GuestPose = require(Shared.Logic.GuestPose)
local Net = require(Shared.Net)
local PlayerPose = require(Shared.Logic.PlayerPose)
local ShotPicker = require(Shared.Logic.ShotPicker)
local Takedown = require(Shared.Logic.Takedown)

local C = Config.Cinema
local GRig = GuestPose.Rig
local player = Players.LocalPlayer

local OWNER = "takedown"
local HANDBACK = 0.35 -- his own animation takes him back over this long (s)
local TAIL = 0.6 -- black after the taking, before your eyes come back as an Echo
local WATCH = 2.2 -- dragged away: how long you watch yourself go before the black
local FADE_OUT = 0.45 -- the body gone into the dark at the drag's end
local LIVE_MAX = 10 -- (a drag the server never ended: let it go)

local TakedownController = {}

local active = nil -- the takedown playing
local handback = nil -- his last pose as it ended, while his own takes over

-- Kinematics frames and CFrames.
local function toCFrame(f): CFrame
	local r, p = f.r, f.p
	return CFrame.new(p[1], p[2], p[3], r[1][1], r[1][2], r[1][3], r[2][1], r[2][2], r[2][3], r[3][1], r[3][2], r[3][3])
end

local function toFrame(cf: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } }, p = { x, y, z } }
end

local function v3(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function jointCFrame(v): CFrame
	return CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
end

-- A character's joints by name, and its root joint's two ends.
local function rigOf(character: Model)
	local joints = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and PlayerPose.Rig[d.Name] then
			joints[d.Name] = d
		end
	end
	local root = joints.Root
	if not root then
		return nil
	end
	local a0, a1
	if root:IsA("Motor6D") then
		a0, a1 = root.C0, root.C1
	else
		local att0, att1 = (root :: any).Attachment0, (root :: any).Attachment1
		if not att0 or not att1 then
			return nil
		end
		a0, a1 = att0.CFrame, att1.CFrame
	end
	return { joints = joints, a0 = a0, a1 = a1, rootPart = character:FindFirstChild("HumanoidRootPart") }
end

function TakedownController:Init(controllers)
	self.controllers = controllers
end

function TakedownController:Start()
	Net.get("GuestEvent").OnClientEvent:Connect(function(event)
		if type(event) == "table" and event.kind == "takedown" then
			local ok, err = pcall(self._begin, self, event)
			if not ok then
				warn("[Consensus] takedown failed to start: " .. tostring(err))
			end
		elseif type(event) == "table" and event.kind == "takedownEnd" then
			-- The drag is over where he stopped: the body goes into the dark.
			if active and active.victim == event.victim and not active.ending then
				active.ending = os.clock()
			end
		end
	end)
	-- Joints on Stepped, where the engine applies them (after the Animator).
	RunService.Stepped:Connect(function()
		local ok, err = pcall(self._step, self)
		if not ok then
			warn("[Consensus] takedown step failed: " .. tostring(err))
			active = nil
		end
	end)
	-- The camera for the one he caught, before the cinema puts it there.
	RunService:BindToRenderStep("ConsensusTakedownCamera", Enum.RenderPriority.Camera.Value + 4, function(dt)
		local ok, err = pcall(self._camera, self, dt)
		if not ok then
			warn("[Consensus] takedown camera failed: " .. tostring(err))
		end
	end)
end

-- Is this player's body the takedown's just now (PoseController stands aside)?
function TakedownController:Owns(who: Player): boolean
	return active ~= nil and active.victim == who
end

function TakedownController:_begin(event)
	local victim = event.victim
	local stage: CFrame = event.stage
	local rest: CFrame = event.rest
	if typeof(victim) ~= "Instance" or typeof(stage) ~= "CFrame" or typeof(rest) ~= "CFrame" then
		return
	end
	if active then
		self:_finish()
	end
	local character = victim.Character
	local rig = character and rigOf(character)
	local spec = table.clone(event.spec or {})
	if rig then
		-- The body's own measures: how high its pelvis stands, and where it
		-- lies downed (the pose PoseController holds after), on the stage.
		local standing = rest * rig.a0 * rig.a1:Inverse()
		spec.pelvis = stage:PointToObjectSpace(standing.Position).Y
		local prone = PlayerPose.prone(0, 0).Root
		local lying = rest * rig.a0 * jointCFrame(prone) * rig.a1:Inverse()
		spec.rest = toFrame(stage:ToObjectSpace(lying))
	end
	spec = Takedown.fill(spec)
	local length = Takedown.length(spec)
	active = {
		victim = victim,
		character = character,
		rig = rig,
		stage = stage,
		rest = rest,
		spec = spec,
		start = typeof(event.start) == "number" and event.start or Workspace:GetServerTimeNow(),
		length = length,
		marks = Takedown.marks(spec),
		cues = Takedown.cues(spec, event.voice),
		nextCue = 1,
		-- The taking ends in a drag he runs by his own way (StalkerService):
		-- the body follows him from then on, not the timeline.
		live = spec.live == true,
		-- (F2 checks: the attribute DebugTakedownOutside plays it as a bystander sees it.)
		mine = victim == player and not player:GetAttribute("DebugTakedownOutside"),
		shot = nil,
	}
	if active.mine then
		self.controllers.CinemaController:Begin(OWNER)
	end
end

-- Seconds into the one playing (F2 can pin it: the player attribute
-- DebugTakedownAt, for stills).
local function clock(): number
	local pinned = player:GetAttribute("DebugTakedownAt")
	if type(pinned) == "number" and active then
		return math.clamp(pinned, 0, active.length + (active.live and LIVE_MAX or 0))
	end
	return active and (Workspace:GetServerTimeNow() - active.start) or 0
end

-- The sample for this frame (shared by the joints, him and the camera).
function TakedownController:_sample()
	if not active then
		return nil
	end
	local t = clock()
	if active.sampledAt ~= t then
		active.sampledAt = t
		active.sample = Takedown.sample(active.spec, math.min(t, active.length))
	end
	return active.sample, t
end

-- A point on a trail of floor points, `back` studs behind its newest end,
-- and the way along it there (towards the newest end): the chord over a
-- stud each side, so a body pulled round a corner turns round it.
local function trailBack(trail, back: number): (Vector3, Vector3)
	local function at(d: number): Vector3
		local remaining = math.max(0, d)
		for i = #trail, 2, -1 do
			local a, b = trail[i - 1], trail[i]
			local length = (b - a).Magnitude
			if length >= remaining and length > 1e-4 then
				return b + (a - b) * (remaining / length)
			end
			remaining -= length
		end
		return trail[1]
	end
	local p = at(back)
	local ahead, behind = at(back - 1), at(back + 1)
	local way = Vector3.new(ahead.X - behind.X, 0, ahead.Z - behind.Z)
	if way.Magnitude < 1e-3 then
		local a, b = trail[1], trail[#trail]
		way = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	end
	return p, way.Magnitude > 1e-3 and way.Unit or Vector3.new(0, 0, -1)
end

-- Dragged by his own way (the taking's end): your ankle in his hand at his
-- side, your body behind him along the trail his body leaves (so it's pulled
-- round corners after him), hips hauled up, shoulders on the boards.
function TakedownController:_liveBody(t: number): (CFrame, any)
	local live = active.liveState
	if not live then
		-- From where you landed, to where he stood with your ankle.
		local s0 = Takedown.sample(active.spec, active.length)
		local p = active.stage * v3(s0.victim.pelvis.p)
		local g = s0.guest.root
		local h = active.stage * Vector3.new(g.x, 0, g.z)
		local floorY = active.stage.Position.Y
		local landed = Vector3.new(p.X, floorY, p.Z)
		local held = Vector3.new(h.X, floorY, h.Z)
		live = { trail = { landed, held }, gap = (held - landed).Magnitude }
		active.liveState = live
	end
	local level = Workspace:FindFirstChild("ConsensusLevel")
	local guest = level and level:FindFirstChild("Stalker")
	local anchor = guest and guest:FindFirstChild("DrawnRoot")
	local hold = Takedown.Drag.hold
	local hand = nil
	if anchor then
		local floor = anchor.Position - Vector3.new(0, GRig.rootY, 0)
		if (floor - live.trail[#live.trail]).Magnitude > 0.12 then
			table.insert(live.trail, floor)
			if #live.trail > 600 then
				table.remove(live.trail, 1)
			end
		end
		hand = anchor.CFrame * Vector3.new(hold[2], hold[3] - GRig.rootY, hold[1])
	end
	local _, way = trailBack(live.trail, live.gap)
	if not hand then
		hand = live.trail[#live.trail] - way * hold[1] + Vector3.new(0, hold[3], 0)
	end
	-- (The timeline's clock stood still a moment at the slam: so does this.)
	local frame, joints = Takedown.dragBody({ hand.X, hand.Y, hand.Z }, -way.X, -way.Z, t - Takedown.HitStop)
	local pelvis = toCFrame(frame)
	live.pelvis = pelvis
	live.ankle = { hand.X, hand.Y, hand.Z }
	return pelvis, joints
end

function TakedownController:_step()
	if not active then
		return
	end
	local sample, t = self:_sample()
	local pinned = player:GetAttribute("DebugTakedownAt") ~= nil
	if active.live then
		local faded = active.ending and os.clock() - active.ending >= FADE_OUT + (active.mine and TAIL or 0)
		if faded or (not pinned and t > active.length + LIVE_MAX) then
			self:_finish()
			return
		end
	elseif t >= active.length + (active.spec.kind == "taking" and TAIL or 0) and not pinned then
		self:_finish()
		return
	end
	-- The body.
	local rig = active.rig
	local rootPart = rig and rig.rootPart
	if rig and rootPart and rootPart.Parent then
		local pelvis, joints, fade
		if active.live and t >= active.length then
			pelvis, joints = self:_liveBody(t)
			fade = active.ending and math.clamp((os.clock() - active.ending) / FADE_OUT, 0, 1) or 0
		else
			pelvis = active.stage * toCFrame(sample.victim.pelvis)
			joints = sample.victim.joints
			fade = sample.victim.fade or 0
		end
		for name, joint in rig.joints do
			if name == "Root" then
				joint.Transform = (rootPart.CFrame * rig.a0):Inverse() * pelvis * rig.a1
			else
				local v = joints[name]
				if v then
					joint.Transform = jointCFrame(v)
				end
			end
		end
		-- Taken: gone into the dark (for everyone else; you see black).
		if not active.mine then
			if fade > 0 or active.faded then
				active.faded = true
				for _, d in active.character:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = fade
					end
				end
			end
		end
	end
	-- The floor where you hit it: a burst of dust.
	if active.spec.kind == "taking" and not active.dusted and t >= active.marks.slam then
		active.dusted = true
		if t - active.marks.slam < 0.5 then
			local L = Takedown.layout(active.spec).L
			self:_dust(active.stage * Vector3.new(L[1], 0.1, L[2]))
		end
	end
	-- At Breaking, a little blood where you fell (the owner's pick: light,
	-- only seen from a distance; Moderate).
	if (active.spec.form or 0) >= 2 and not active.bled then
		local at = active.spec.kind == "taking" and active.marks.slam or active.marks.wake
		if at and t >= at then
			active.bled = true
			if t - at < 1 then
				self:_bleed()
			end
		end
	end
	-- What's heard.
	local audio = self.controllers.AudioController
	while active.cues[active.nextCue] and active.cues[active.nextCue][1] <= t do
		local cue = active.cues[active.nextCue]
		active.nextCue += 1
		if cue[3] == "ears" then
			-- (Only in your own ears: a ringing after the slam.)
			if active.mine and audio and t - cue[1] < 0.5 then
				audio:PlayFor(cue[2], nil, cue[4], cue[5], cue[6] or 2)
			end
		elseif t - cue[1] < 0.5 then
			local at
			if cue[3] == "guest" or cue[3] == "mouth" then
				at = active.stage * v3(sample.guest.face)
			else
				at = active.stage * v3(sample.points.head)
			end
			local carrier = cue[3] == "body" and active.character and active.character:FindFirstChild("LowerTorso")
			local sound
			if carrier and audio then
				sound = audio:PlayOn(cue[2], carrier, Vector3.zero, cue[4], cue[5], false)
			elseif audio then
				sound = audio:PlayAt(cue[2], at, cue[4], cue[5], false)
			end
			if sound and cue[6] then
				task.delay(cue[6], function()
					if sound.Parent then
						sound:Stop()
					end
				end)
			end
		end
	end
end

-- A few dark drops on the floor (every client the same: seeded by where it
-- happened): by your shoulder where he bit, or where your head hit the floor.
function TakedownController:_bleed()
	local spec, stage = active.spec, active.stage
	local centre
	if spec.kind == "taking" then
		local layout = Takedown.layout(spec)
		centre = stage * Vector3.new(layout.L[1] + layout.u1[1] * 2.1, 0, layout.L[2] + layout.u1[2] * 2.1)
	else
		local points = Takedown.victimPoints(spec.rest, PlayerPose.prone(0, 0))
		centre = stage * Vector3.new(points.shoulder[1], 0, points.shoulder[3])
	end
	local level = Workspace:FindFirstChild("ConsensusLevel") or Workspace
	local random = Random.new(math.floor(centre.X * 7.3 + centre.Z * 13.1) % 100000)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { level }
	params.RespectCanCollide = true
	for _ = 1, random:NextInteger(C.Blood.drops[1], C.Blood.drops[2]) do
		local angle = random:NextNumber(0, math.pi * 2)
		local out = random:NextNumber(0, C.Blood.spread)
		local where = centre + Vector3.new(math.cos(angle) * out, 0, math.sin(angle) * out)
		local hit = Workspace:Raycast(where + Vector3.new(0, 2, 0), Vector3.new(0, -3.5, 0), params)
		if hit then
			local size = random:NextNumber(C.Blood.size[1], C.Blood.size[2])
			local drop = Instance.new("Part")
			drop.Name = "TakedownDrop"
			drop.Shape = Enum.PartType.Cylinder
			drop.Size = Vector3.new(0.02, size, size * random:NextNumber(0.8, 1.2))
			drop.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.012, 0)) * CFrame.Angles(0, angle, math.pi / 2)
			drop.Color = Color3.fromRGB(C.Blood.color[1], C.Blood.color[2], C.Blood.color[3])
			drop.Material = Enum.Material.SmoothPlastic
			drop.Reflectance = 0.06
			drop.Anchored, drop.CanCollide, drop.CanQuery, drop.CanTouch = true, false, false, false
			drop.CastShadow = false
			drop.Parent = level
		end
	end
end

-- Dust thrown up off the boards where a body hits them (everyone sees it).
function TakedownController:_dust(at: Vector3)
	local part = Instance.new("Part")
	part.Name = "TakedownDust"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(3.6, 0.2, 1.6)
	part.CFrame = CFrame.new(at)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Assets.DustTexture
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(75, 75)
	emitter.Speed = NumberRange.new(3, 9)
	emitter.Drag = 5
	emitter.Acceleration = Vector3.new(0, -1.5, 0)
	emitter.Lifetime = NumberRange.new(0.7, 1.5)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.6) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 138, 120))
	emitter.LightInfluence = 1
	emitter.Enabled = false
	emitter.Parent = part
	part.Parent = Workspace
	emitter:Emit(36)
	Debris:AddItem(part, 2.5)
end

-- His pose while it plays (GuestController draws him from this): where his
-- root is, his joints, his face and hands. After it, a moment's hand-back.
function TakedownController:GuestFrame()
	if active and active.live and clock() >= active.length then
		-- The drag: he runs by his own legs; his right hand back on your ankle.
		local live = active.liveState
		local let = active.ending and math.clamp((os.clock() - active.ending) / FADE_OUT, 0, 1) or 0
		-- (His last pose of the timeline gives way to his run over a moment.)
		local from = active.lastFrame
		local into = math.clamp((clock() - active.length) / 0.35, 0, 1)
		into = into * into * (3 - 2 * into)
		handback = nil
		return {
			live = true,
			weight = 1,
			smile = 1,
			open = 0.35,
			catch = true,
			curl = { Left = 0.55, Right = 1.1 },
			spread = { Left = 0.75, Right = 0.35 },
			look = live and live.pelvis and live.pelvis.Position or nil,
			adjust = function(values, anchorCF: CFrame)
				if from and into < 1 then
					values = Takedown.blend(from.values, values, into)
				end
				if not live or not live.ankle or let >= 1 then
					return values
				end
				local ankle = v3(live.ankle)
				local target = anchorCF:PointToObjectSpace(ankle + Vector3.new(0, 0.5, 0))
				local toward = anchorCF:VectorToObjectSpace((ankle - anchorCF.Position) * Vector3.new(1, 0, 1))
				toward = toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(0, 0, 1)
				Takedown.reachLocal(
					values,
					"Right",
					{ target.X, target.Y, target.Z },
					{ toward.X, toward.Y, toward.Z },
					{ 0, -1, 0 },
					{ 0.7, -0.8, 0.6 },
					1 - let
				)
				return values
			end,
		}
	end
	if active then
		local sample = self:_sample()
		local g = sample.guest
		local anchor = active.stage * CFrame.new(g.root.x, GRig.rootY, g.root.z) * CFrame.Angles(0, g.root.yaw, 0)
		local frame = {
			anchor = anchor,
			values = g.joints,
			smile = g.smile,
			open = g.open,
			catch = g.catch,
			curl = g.curl,
			spread = g.spread,
			look = active.stage * v3(sample.points.head),
			weight = 1,
		}
		handback = { frame = frame, at = os.clock() }
		active.lastFrame = frame
		return frame
	end
	if handback then
		local k = (os.clock() - handback.at) / HANDBACK
		if k >= 1 then
			handback = nil
			return nil
		end
		local frame = table.clone(handback.frame)
		frame.weight = 1 - k * k * (3 - 2 * k)
		frame.handback = true
		return frame
	end
	return nil
end

-- The camera ------------------------------------------------------------------------

-- Where the camera stands for a shot of the takedown (world space), and
-- what it looks at each frame.
function TakedownController:_frameShot(kind: string, sample)
	local cinema = self.controllers.CinemaController
	local stage = active.stage
	local clear = cinema:ClearFunction()
	local face = stage * v3(sample.guest.face)
	local chest = stage * v3(sample.points.collar)
	local head = stage * v3(sample.points.head)
	local floorY = stage.Position.Y
	local ceiling = cinema:CeilingAbove(stage.Position + Vector3.new(0, 1, 0), 30)
	local function arr(p: Vector3)
		return { p.X, p.Y, p.Z }
	end
	-- (Your head and his hide each other: neither may stand in the way.)
	local blockers = { { arr(head), 0.85 }, { arr(face), 0.6 } }
	local function bearing(x: number, z: number)
		local w = stage:VectorToWorldSpace(Vector3.new(x, 0, z))
		local flat = Vector3.new(w.X, 0, w.Z).Unit
		return { flat.X, flat.Z }
	end
	local pick
	if kind == "face" then
		local spec = C.Face
		local turn = math.rad(spec.turn)
		-- (Where his face points: at yours, wherever he has shoved it.)
		local victimFace = stage * v3(sample.points.face)
		local gaze = Vector3.new(victimFace.X - face.X, 0, victimFace.Z - face.Z)
		gaze = gaze.Magnitude > 0.05 and gaze.Unit or stage:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local front = { gaze.X, gaze.Z }
		local c, sn = math.cos(turn), math.sin(turn)
		local beside = { gaze.X * c - gaze.Z * sn, gaze.X * sn + gaze.Z * c }
		local heights = {}
		for _, r in spec.rise do
			table.insert(heights, face.Y + r)
		end
		pick = ShotPicker.pick({
			focus = arr(face),
			centre = arr(face),
			subjects = { arr(face) },
			radii = spec.radii,
			heights = heights,
			angles = spec.angles,
			floor = floorY,
			ceiling = ceiling,
			prefer = beside,
			preferRadius = spec.radii[1],
			preferHeight = face.Y,
			avoid = arr(head),
			avoidRadius = 0.75,
			blockers = blockers,
			-- (His face from in front of it, never the back of his head.)
			cone = { front[1], front[2], math.cos(math.rad(70)) },
			clear = clear,
		})
	elseif kind == "floor" then
		-- You're down: a low, wide shot, your body on the floor nearest the
		-- lens, him standing over it wiping his mouth (from right under him
		-- his coat filled the frame).
		local spec = C.Floor
		local restHead = stage * v3(Takedown.victimPoints(active.spec.rest, PlayerPose.prone(0, 0)).head)
		local restPelvis = stage * v3(active.spec.rest.p)
		local g = sample.guest.root
		local standing = stage * Vector3.new(g.x, 0, g.z)
		local mid = restPelvis:Lerp(standing, 0.5)
		pick = ShotPicker.pick({
			focus = arr(face:Lerp(restHead, 0.55)),
			centre = arr(Vector3.new(mid.X, floorY + 1.4, mid.Z)),
			subjects = { arr(face), arr(restHead) },
			radii = spec.radii,
			heights = { floorY + spec.heights[1], floorY + spec.heights[2] },
			angles = spec.angles,
			floor = floorY,
			ceiling = ceiling,
			prefer = bearing(-1, 0.45),
			preferRadius = spec.radii[1],
			avoid = arr(Vector3.new(standing.X, floorY + 2, standing.Z)),
			avoidRadius = 2,
			blockers = { { arr(face), 0.5 } },
			clear = clear,
		})
	elseif kind == "slam" or kind == "grab" then
		-- From the side and low: all of it in frame (your feet torn away, you
		-- hanging, swung up, driven down), him towering over the lens. Side
		-- on to the way you go: torn off your feet towards him (the grab), or
		-- slammed down away from him.
		local spec = C.Slam
		local layout = Takedown.layout(active.spec)
		local u = kind == "grab" and layout.u0 or layout.u1
		local from = stage * Vector3.new(layout.S0[1], 0, layout.S0[2])
		local landing = kind == "grab" and stage * Vector3.new(u[1] * 2.5, 0, u[2] * 2.5)
			or stage * Vector3.new(layout.L[1], 0, layout.L[2])
		local mid = from:Lerp(landing, 0.42) + Vector3.new(0, 3.6, 0)
		local right, left = bearing(-u[2], u[1]), bearing(u[2], -u[1])
		local opts = {
			focus = arr(mid),
			centre = arr(mid),
			subjects = { arr(face), arr(head), arr(landing + Vector3.new(0, 0.6, 0)) },
			radii = spec.radii,
			heights = { floorY + spec.heights[1], floorY + spec.heights[2] },
			angles = spec.angles,
			floor = floorY,
			ceiling = ceiling,
			preferRadius = spec.radii[1],
			-- (Never where you'll land.)
			avoid = arr(landing + Vector3.new(0, 1, 0)),
			avoidRadius = 3.5,
			clear = clear,
		}
		-- From the side, so the swing reads across the frame: on his right
		-- (the side your ankle's held on), else his left, else anywhere.
		for _, side in { right, left } do
			opts.prefer = side
			opts.cone = { side[1], side[2], spec.side }
			pick = ShotPicker.pick(opts)
			if pick then
				break
			end
		end
		if not pick then
			opts.cone = nil
			pick = ShotPicker.pick(opts)
		end
	elseif kind == "drag" then
		-- Low, off his right side (the side he holds you on), clear of where
		-- you lay: hauled up by the leg, then dragged off past the lens.
		local spec = C.Drag
		local path = active.spec.path
		local first = stage * Vector3.new(path[1][1], 1, path[1][2])
		local last = stage * Vector3.new(path[#path][1], 1, path[#path][2])
		local way = active.spec.way or { 0, -1 }
		local lay = Takedown.layout(active.spec).L
		local landed = stage * Vector3.new(lay[1], 0.6, lay[2])
		pick = ShotPicker.pick({
			focus = arr(first:Lerp(last, 0.3)),
			centre = arr(first),
			subjects = { arr(first), arr(last + Vector3.new(0, 3, 0)) },
			radii = spec.radii,
			heights = { floorY + spec.heights[1], floorY + spec.heights[2] },
			angles = spec.angles,
			floor = floorY,
			ceiling = ceiling,
			prefer = bearing(-way[2], way[1]),
			preferRadius = spec.radii[1],
			avoid = arr(landed),
			avoidRadius = 2.6,
			clear = clear,
		})
	end
	if not pick then
		-- The two of you (and the fallback for any shot that found nowhere).
		local spec = C.Pair
		local centre = face:Lerp(chest, 0.5)
		-- (On his right: the hand over your face is between you and the lens,
		-- his face beyond it; stage -X is his right.)
		local turn = -math.rad(spec.turn)
		local heights = {}
		for _, r in spec.rise do
			table.insert(heights, centre.Y + r)
		end
		local opts = {
			focus = arr(centre),
			centre = arr(centre),
			subjects = { arr(face), arr(chest) },
			radii = spec.radii,
			heights = heights,
			angles = spec.angles,
			floor = floorY,
			ceiling = ceiling,
			prefer = bearing(math.sin(turn), math.cos(turn)),
			preferRadius = spec.radii[1],
			preferHeight = centre.Y + 0.4,
			blockers = blockers,
			clear = clear,
		}
		pick = ShotPicker.pick(opts)
		if not pick then
			-- Nowhere sees you both: anywhere that sees him.
			opts.subjects = { arr(face) }
			opts.radii = { 4, 3, 2.5 }
			pick = ShotPicker.pick(opts)
		end
		if not pick then
			-- Nowhere at all (a cupboard): straight down from under the ceiling.
			local above = Vector3.new(centre.X, math.min(ceiling - 0.6, centre.Y + 3), centre.Z)
			pick = { position = arr(above + (stage.LookVector * 0.01)), focus = arr(centre) }
		end
	end
	return v3(pick.position)
end

-- What a shot looks at this frame.
local function focusOf(kind: string, sample)
	local stage = active.stage
	local face = stage * v3(sample.guest.face)
	if kind == "face" then
		return face
	elseif kind == "floor" then
		local rest = active.spec.rest.p
		return face:Lerp(stage * Vector3.new(rest[1], rest[2], rest[3]), 0.55)
	elseif kind == "slam" or kind == "grab" then
		-- (Between his chest and your middle: it follows you up and down.)
		local g = sample.guest.root
		local chest = stage * Vector3.new(g.x, 5.4, g.z)
		local p = sample.victim.pelvis.p
		return chest:Lerp(stage * Vector3.new(p[1], p[2], p[3]), 0.5)
	elseif kind == "drag" then
		local live = active.liveState
		if live and live.pelvis then
			return live.pelvis.Position + Vector3.new(0, 0.4, 0)
		end
		local p = sample.victim.pelvis.p
		return stage * Vector3.new(p[1], p[2] + 0.4, p[3])
	end
	return face:Lerp(stage * v3(sample.points.collar), 0.5)
end

function TakedownController:_camera(dt: number)
	if not active or not active.mine then
		return
	end
	local cinema = self.controllers.CinemaController
	local sample, t = self:_sample()
	local kind, black = Takedown.shot(active.spec, math.min(t, active.length))
	if active.live and t >= active.length then
		-- Watching yourself dragged away, a few seconds, then the dark.
		kind = "drag"
		black = math.clamp((t - active.length - WATCH) / 0.6, 0, 1)
		if active.ending then
			black = 1
		end
	elseif t > active.length then
		black = 1
	end
	cinema:Black(black)
	if kind == "black" then
		return
	end
	local shot = active.shot
	local now = os.clock()
	if not shot or shot.kind ~= kind or (now >= shot.checkAt and not shot.ok) then
		local position = self:_frameShot(kind, sample)
		shot = { kind = kind, position = position, aim = focusOf(kind, sample), checkAt = now + 0.25, ok = true }
		active.shot = shot
		cinema:FadeFor(position, { focusOf(kind, sample), active.stage * v3(sample.guest.face) })
	end
	-- Keep an eye on it: if something comes between (a wall, or your own
	-- head in front of his face), cut to a new place.
	local want = focusOf(kind, sample)
	if now >= shot.checkAt then
		shot.checkAt = now + 0.2
		local face = active.stage * v3(sample.guest.face)
		local head = active.stage * v3(sample.points.head)
		local hidden = (kind == "pair" or kind == "face")
			and ShotPicker.hidden(
				{ shot.position.X, shot.position.Y, shot.position.Z },
				{ face.X, face.Y, face.Z },
				{ { { head.X, head.Y, head.Z }, 0.8 } }
			)
		shot.ok = cinema:Clear(shot.position, want) and not hidden
	end
	shot.aim = shot.aim:Lerp(want, math.clamp(dt * C.Track, 0, 1))
	-- Alive, not locked off: a slow push in on the two of you, and a faint
	-- handheld drift (as much as Camera motion in Settings allows).
	local state = self.controllers.StateController
	local motion = state
			and state.settings
			and type(state.settings.cameraMotion) == "number"
			and math.clamp(state.settings.cameraMotion, 0, 1)
		or 1
	shot.held = (shot.held or 0) + dt
	local push = kind == "pair" and math.min(shot.held * 0.22, 0.9)
		or (kind == "face" and math.min(shot.held * 0.3, 0.35) or 0)
	if kind == "slam" or kind == "grab" then
		push = math.min(shot.held * 0.35, 1.6)
	end
	local toward = shot.aim - shot.position
	local at = shot.position + (toward.Magnitude > 0.01 and toward.Unit * push or Vector3.zero)
	local clock = os.clock()
	local drift = Vector3.new(
		math.sin(clock * 0.9) * 0.6 + math.sin(clock * 2.3 + 1) * 0.4,
		math.sin(clock * 1.1 + 2) * 0.6 + math.sin(clock * 2.9) * 0.4,
		math.sin(clock * 0.7 + 4) * 0.6 + math.sin(clock * 1.9 + 3) * 0.4
	) * (C.Handheld * motion)
	-- The force of it: the lens jolts as his hand hits your face, and hard as
	-- you're slammed into the floor, dying away.
	local jolt = 0
	local dip = 0
	for _, hit in Takedown.impacts(active.spec) do
		local since = t - hit[1]
		if since >= 0 then
			jolt += hit[2] * math.exp(-since * 9)
			-- (A heavy one drops the lens with it, and it comes back up.)
			if hit[2] >= 0.3 then
				dip += hit[2] * (1 - math.exp(-since * 40)) * math.exp(-since * 4)
			end
		end
	end
	if jolt > 0.001 then
		drift += Vector3.new(math.sin(clock * 61), math.sin(clock * 53 + 1), math.sin(clock * 47 + 2)) * (jolt * motion)
	end
	drift -= Vector3.new(0, dip * motion, 0)
	-- (The taking takes a wider lens: all of it has to be in frame.)
	local wide = (kind == "slam" or kind == "grab") and C.Slam.fov or nil
	cinema:Shoot(CFrame.lookAt(at + drift, shot.aim + drift * 0.5), wide)
end

function TakedownController:_finish()
	local ended = active
	active = nil
	if not ended then
		return
	end
	if ended.mine then
		self.controllers.CinemaController:End(OWNER)
	end
	-- The body's own poses take over from where it lies.
	local pose = self.controllers.PoseController
	if pose and pose.Settle and ended.character then
		pose:Settle(ended.victim, ended.character)
	end
	if ended.faded and ended.character then
		task.delay(0.1, function()
			for _, d in ended.character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end)
	end
end

return TakedownController
