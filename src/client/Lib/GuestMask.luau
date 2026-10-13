-- The Guest's face and hands when he wears his Blender model (V5, the Guest
-- remodelled; tools/blender/guest.py made him, Stalker/GuestSkin dressed
-- him). Nothing here replicates: each client moves the mask's and the
-- fingers' bones itself, as it moves every joint (Controllers/
-- GuestController), so every player sees the same face.
--
-- A porcelain doll's mask that moves, which porcelain must not
-- (docs/ART.md "The Guest"):
--   * the grin tears open along the hairline across the mask, as wide as
--     GuestPose.smile says: each column of the lips parts by its share of
--     the grin (Data/GuestRig Face.columns). The teeth stay where they are,
--     so the lips draw back off them, clenched;
--   * past half open, everything under the hairline drops like a
--     ventriloquist's dummy's jaw (JawOpen); a giggle makes it chatter;
--   * the grin bunches the cheeks and squeezes the eye holes into crescents
--     (Smile); his mood lifts or presses the brows (BrowUp, BrowDown); held,
--     the holes stare wider the longer you look (Wide); Breaking, his left
--     eye droops and the jaw hangs crooked (Droop). The poses were set in
--     Blender (Face.poses); this weighs them and eases every weight, so the
--     face never jumps;
--   * his forms blend (GuestForm): the worn shell's crazing and tear-tracks
--     creep over the glaze in a few seconds (Fraying); at Breaking it cracks
--     at once, the broken shell's fractures show, three pieces come away and
--     fall, and the mask slips askew.
-- The same calls as Lib/GuestFace's face, so GuestController drives either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestPose = require(Shared.Logic.GuestPose)
local GuestRig = require(Shared.Data.GuestRig)

local GuestMask = {}
GuestMask.__index = GuestMask

local Face = GuestRig.Face
local D2R = math.pi / 180

local function v(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Each pose: bone -> { move, turn (radians) }.
local POSES = {}
for name, pose in Face.poses do
	local out = {}
	for bone, spec in pose do
		out[bone] = { move = v(spec.move), turn = spec.turn and v(spec.turn) * D2R or Vector3.zero }
	end
	POSES[name] = out
end

local COLUMNS = {}
for k, col in Face.columns do
	COLUMNS[k] = {
		theta = col.theta,
		up = v(col.up),
		out = v(col.out),
		upper = string.format("fU%02d", k),
		lower = string.format("fL%02d", k),
	}
end

-- The mask's own frame (its centre: Face's places are from it), and where
-- its mesh's middle sits in it.
local MASK_CENTRE = Vector3.new(0, GuestPose.Rig.headY, 0) + v(Face.centre)
local TO_PART = CFrame.new(v(GuestRig.Pieces.GuestMask.centre) - MASK_CENTRE)
local MASK_ON_HEAD = CFrame.new(v(Face.centre))
-- At Breaking it has slipped: turned and dropped a little (as the old face).
local SLIP_MOVE = Vector3.new(0.015, -0.035, 0)
local SLIP_ROLL = math.rad(6)

-- How quickly each weight eases (per second), and the forms.
local EASE = { width = 6, open = 8, pose = 3.5, jaw = 10 }
local CREEP = 0.4 -- Calm to Fraying: the crazing creeps over in about 2.5 s
local CRACK = 2.5 -- to Breaking: at once

local MOODS = {
	Curious = { browUp = 0.7 },
	Playful = { browUp = 0.5 },
	Host = { browUp = 0.35 },
	Patient = {},
	Stalking = { browDown = 0.5 },
	Irritated = { browDown = 1 },
}

-- Is this head wearing the model?
function GuestMask.wears(head: BasePart): boolean
	return head:FindFirstChild("GuestMask") ~= nil
end

function GuestMask.new(head: BasePart, onEvent: ((string, Vector3) -> ())?)
	local mask = head:FindFirstChild("GuestMask") :: MeshPart
	local self = setmetatable({
		head = head,
		mask = mask,
		weld = mask:FindFirstChild("MaskWeld"),
		bones = {},
		pieces = {},
		shards = {},
		onEvent = onEvent,
		form = 0,
		formTarget = 0,
		shed = false,
		turn = nil,
		now = 0,
		chatterUntil = 0,
		nextTwitch = 0,
		twitch = nil,
		state = { width = math.rad(62), open = 0, browUp = 0, browDown = 0, wide = 0, droop = 0, jaw = 0 },
		target = { width = math.rad(62), open = 0, browUp = 0, browDown = 0, wide = 0 },
	}, GuestMask)
	for _, d in mask:GetDescendants() do
		if d:IsA("Bone") then
			self.bones[d.Name] = d
		elseif d:IsA("MeshPart") then
			self.pieces[d.Name] = d
		end
	end
	self.worn = self.pieces.GuestMaskWorn
	self.broken = self.pieces.GuestMaskBroken
	for name, piece in GuestRig.Pieces do
		if piece.shard and self.pieces[name] then
			self.shards[name] = { part = self.pieces[name], bone = piece.shard }
		end
	end
	-- His eyes: a pin of light deep in each hole that follows you, faint in
	-- the dark whenever he faces you, bright in your torch.
	self.shine = {}
	self.eyes = {}
	for _, side in { "L", "R" } do
		local at = v(Face.eyes[side])
		local pin = Instance.new("Part")
		pin.Name = "EyeShine"
		pin.Shape = Enum.PartType.Ball
		pin.Material = Enum.Material.Neon
		pin.Color = Color3.new(1, 1, 1)
		pin.Size = Vector3.one * 0.05
		pin.Transparency = 1
		pin.CanCollide = false
		pin.CanQuery = false
		pin.CanTouch = false
		pin.CastShadow = false
		pin.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = mask
		weld.Part1 = pin
		weld.C0 = TO_PART:Inverse() * CFrame.new(at)
		weld.Parent = pin
		pin.Parent = mask
		table.insert(self.shine, pin)
		table.insert(self.eyes, { weld = weld, at = at })
	end
	self:_write()
	return self
end

-- The grin: a half-width round the head (radians) and how open (0..1).
function GuestMask:SetSmile(width: number, open: number)
	self.target.width = width
	self.target.open = open
end

-- His mood, pose and how long he's been held, for the brows and the eyes.
function GuestMask:SetMood(mood: string?, pose: string?, heldFor: number?)
	local m = MOODS[mood or ""] or {}
	local held = pose == "Hold" and (heldFor or 0) or 0
	-- Held, he's delighted, and stares wider the longer you look.
	self.target.browUp = math.max(m.browUp or 0, math.min(1, held / 6))
	self.target.browDown = (held > 0) and 0 or (m.browDown or 0)
	self.target.wide = pose == "Catch" and 1 or math.min(0.8, math.max(0, held - 1.5) / 6)
end

-- 0 Calm, 1 Fraying, 2 Breaking: eases there (see Step).
function GuestMask:SetForm(form: number)
	self.formTarget = math.clamp(form, 0, 2)
end

-- Wrong between looks: the mask slid round his head and turned on itself.
function GuestMask:SetTurn(yaw: number?, roll: number?, pitch: number?)
	if not yaw or (math.abs(yaw) < 1e-3 and math.abs(roll or 0) < 1e-3 and math.abs(pitch or 0) < 1e-3) then
		self.turn = nil
	else
		self.turn = { yaw = yaw, roll = roll or 0, pitch = pitch or 0 }
	end
end

function GuestMask:SetShine(level: number | boolean)
	local amount = level == true and 1 or (level == false and 0 or level :: number)
	for _, pin in self.shine do
		pin.Transparency = amount <= 0 and 1 or (1 - amount) * 0.85 + 0.05
		local size = amount >= 1 and 0.03 or 0.05
		pin.Size = Vector3.new(size, size, size)
	end
end

-- Lidless, and they follow you.
function GuestMask:LookAt(point: Vector3)
	local frame = self.mask.CFrame * TO_PART:Inverse()
	local rel = frame:PointToObjectSpace(point)
	for _, eye in self.eyes do
		local toward = rel - eye.at
		if toward.Magnitude > 0.01 then
			local d = toward.Unit
			local reach = 0.045
			local offset = Vector3.new(math.clamp(d.X * 1.6, -1, 1) * reach, math.clamp(d.Y * 1.6, -1, 1) * reach, 0)
			eye.weld.C0 = TO_PART:Inverse() * CFrame.new(eye.at + offset)
		end
	end
end

-- His jaw chatters (a giggle) for a moment.
function GuestMask:Chatter(seconds: number)
	self.chatterUntil = math.max(self.chatterUntil, self.now + seconds)
end

-- Everything straight to where it's going (the catch copies the face).
function GuestMask:Snap()
	for key, value in self.target do
		self.state[key] = value
	end
	self.state.droop = math.clamp(self.formTarget - 1, 0, 1)
	self.state.jaw = smoothstep(0.5, 1, self.state.open)
	self.form = self.formTarget
	if self.form >= 2 and not self.shed then
		self:_shed(false)
	end
	self:_write()
end

function GuestMask:Step(dt: number)
	self.now += dt
	local s, t = self.state, self.target
	local function ease(key: string, rate: number, goal: number)
		s[key] += (goal - s[key]) * (1 - math.exp(-rate * dt))
	end
	ease("width", EASE.width, t.width)
	ease("open", EASE.open, t.open)
	ease("browUp", EASE.pose, t.browUp)
	ease("browDown", EASE.pose, t.browDown)
	ease("wide", EASE.pose, t.wide)
	-- The forms.
	if self.form < self.formTarget then
		local rate = self.form < 1 and CREEP or CRACK
		local before = self.form
		self.form = math.min(self.formTarget, self.form + rate * dt)
		if before < 1.02 and self.form >= 1.02 and self.formTarget >= 2 then
			-- The crack: pieces come away.
			self:_shed(true)
		end
	elseif self.form > self.formTarget then
		-- (Only back by the debug command.)
		self.form = self.formTarget
		if self.form < 2 then
			self:_unshed()
		end
	end
	ease("droop", EASE.pose, math.clamp(self.form - 1, 0, 1))
	local jaw = smoothstep(0.5, 1, s.open)
	if self.now < self.chatterUntil then
		jaw += 0.14 * (0.5 + 0.5 * math.sin(self.now * 30))
	end
	ease("jaw", EASE.jaw, jaw)
	-- Now and then a cheek twitches (alive under it).
	if self.now >= self.nextTwitch then
		self.nextTwitch = self.now + 2.5 + math.random() * 5
		self.twitch = { bone = math.random() < 0.5 and "fCheekL" or "fCheekR", until_ = self.now + 0.12 }
	end
	self:_write()
end

function GuestMask:_write()
	local s = self.state
	local moves: { [string]: Vector3 } = {}
	local turns: { [string]: Vector3 } = {}
	local function add(pose: string, k: number)
		if k <= 0.001 then
			return
		end
		for bone, spec in POSES[pose] do
			moves[bone] = (moves[bone] or Vector3.zero) + spec.move * k
			turns[bone] = (turns[bone] or Vector3.zero) + spec.turn * k
		end
	end
	local smile = math.clamp((s.width - math.rad(55)) / math.rad(45), 0, 1) * (0.55 + 0.45 * s.open)
	add("Smile", smile)
	add("BrowUp", s.browUp)
	add("BrowDown", s.browDown)
	add("Wide", s.wide)
	add("Droop", s.droop)
	add("JawOpen", s.jaw)
	-- The grin's columns: each parts by its share of the grin (as
	-- tools/blender/kitlib/guestmask.lip_pose).
	local retract = 0.0025 + 0.03 * math.min(1, s.open * 1.6)
	for _, col in COLUMNS do
		local u = math.abs(col.theta) / math.max(s.width, 1e-3)
		local share = u >= 1 and 0 or (1 - u * u) ^ 0.6 * smoothstep(1, 0.85, u)
		local g = retract * share
		moves[col.upper] = (moves[col.upper] or Vector3.zero) + col.up * (g * 0.7) + col.out * (g * 0.08)
		moves[col.lower] = (moves[col.lower] or Vector3.zero) - col.up * g + col.out * (g * 0.08)
	end
	local twitch = self.twitch
	if twitch and self.now < twitch.until_ then
		moves[twitch.bone] = (moves[twitch.bone] or Vector3.zero) + Vector3.new(0, 0.008, -0.004)
	end
	for name, bone in self.bones do
		local m, r = moves[name], turns[name]
		if m or r then
			r = r or Vector3.zero
			bone.Transform = CFrame.new(m or Vector3.zero) * CFrame.Angles(r.X, r.Y, r.Z)
		else
			bone.Transform = CFrame.identity
		end
	end
	-- The shells over the glaze, and the slip.
	if self.worn then
		self.worn.Transparency = 1 - math.clamp(self.form, 0, 1)
	end
	if self.broken then
		self.broken.Transparency = 1 - math.clamp(self.form - 1, 0, 1)
	end
	if self.weld then
		local k = math.clamp(self.form - 1, 0, 1)
		local slip = CFrame.new(SLIP_MOVE * k) * CFrame.Angles(0, 0, SLIP_ROLL * k)
		local turn = self.turn
		if turn then
			self.weld.C0 = CFrame.Angles(turn.pitch, turn.yaw, 0)
				* MASK_ON_HEAD
				* CFrame.Angles(0, 0, turn.roll)
				* slip
				* TO_PART
		else
			self.weld.C0 = MASK_ON_HEAD * slip * TO_PART
		end
	end
end

-- The pieces come away: if he's in view, each falls from his face and
-- breaks on the floor; the face behind them is the dark.
function GuestMask:_shed(falling: boolean)
	self.shed = true
	for _, shard in self.shards do
		local part = shard.part
		if part.Transparency < 1 then
			if falling then
				self:_fall(part, self.bones[shard.bone])
			end
			part.Transparency = 1
		end
	end
	if falling and self.onEvent then
		self.onEvent("crack", self.mask.Position)
	end
end

function GuestMask:_unshed()
	self.shed = false
	for _, shard in self.shards do
		shard.part.Transparency = 0
	end
end

-- A copy of a piece drops (client only): its own bone goes with it, so its
-- skin follows the copy (a skinned mesh bends with its bones by name, in
-- its own model).
function GuestMask:_fall(part: MeshPart, bone: Bone?)
	if not bone or not part:IsDescendantOf(Workspace) then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "GuestShardFalling"
	local copy = part:Clone()
	for _, child in copy:GetChildren() do
		if not child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	copy.Anchored = true
	copy.Transparency = 0
	copy.LocalTransparencyModifier = 0
	copy.Parent = holder
	local b = Instance.new("Bone")
	b.Name = bone.Name
	b.CFrame = copy.CFrame:ToObjectSpace(bone.TransformedWorldCFrame)
	b.Parent = copy
	holder.Parent = Workspace
	local away = (part.Position - self.head.Position)
	away = Vector3.new(away.X, 0, away.Z)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.zero
	local velocity = away * (1.2 + math.random()) + Vector3.new(0, 1.2, 0)
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
	local cf = copy.CFrame
	local landed = nil
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { holder, self.head.Parent }
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not holder.Parent then
			connection:Disconnect()
			return
		end
		if not landed then
			velocity += Vector3.new(0, -Workspace.Gravity * 0.3, 0) * dt
			local step = velocity * dt
			local hit = Workspace:Raycast(cf.Position, step + step.Unit * 0.05, params)
			if hit then
				cf = CFrame.new(hit.Position + hit.Normal * 0.02) * cf.Rotation
				landed = os.clock()
			else
				cf = (cf + step) * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
			end
			copy.CFrame = cf
		else
			-- Lie a while, then go.
			local t = os.clock() - landed
			if t > 6 then
				copy.Transparency = math.min(1, (t - 6) / 1.5)
				if t > 7.5 then
					holder:Destroy()
					connection:Disconnect()
				end
			end
		end
	end)
	task.delay(20, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- Hands -----------------------------------------------------------------------------

-- His hand's finger bones (four down each finger: Data/GuestRig Fingers),
-- for GuestFace.curlHand and setFingerScale.
function GuestMask.hand(handPart: BasePart, side: string)
	local result = { bones = true, fingers = {}, side = side }
	local inward = side == "Left" and 1 or -1
	for _, spec in GuestRig.Fingers do
		if spec.hand == side then
			local knuckle = handPart:FindFirstChild(spec.bones .. "1")
			local stretch = knuckle and knuckle:FindFirstChild(spec.bones .. "1e")
			local middle = stretch and stretch:FindFirstChild(spec.bones .. "2")
			local tip = middle and middle:FindFirstChild(spec.bones .. "3")
			if knuckle and stretch and middle and tip then
				table.insert(result.fingers, {
					knuckle = knuckle,
					stretch = stretch,
					middle = middle,
					tip = tip,
					tilt = CFrame.Angles(spec.tilt[1], spec.tilt[2], spec.tilt[3]),
					first = spec.first,
					second = spec.second,
					inward = inward,
					curl = 0,
					offset = 0,
				})
			end
		end
	end
	return result
end

-- The bones' turns for a finger's knuckle and middle joint (as the old
-- fingers' Motor6Ds turned, in the finger's own frame: the thumb's is tilted).
function GuestMask.bend(finger, knuckle: CFrame, middle: CFrame)
	local tilt = finger.tilt
	finger.knuckle.Transform = tilt * knuckle * tilt:Inverse()
	finger.middle.Transform = tilt * middle * tilt:Inverse()
end

-- His fingers grow (scale times their length): the first segment and the
-- second stretch evenly (their end bones move out along the finger).
function GuestMask.grow(hand, scale: number)
	for _, finger in hand.fingers do
		local first = (finger.first + 0.04) * scale - 0.04
		local second = (finger.second + 0.01) * scale - 0.01
		finger.stretch.CFrame = CFrame.new(finger.tilt:VectorToWorldSpace(Vector3.new(0, -first, 0)))
		finger.tip.CFrame = CFrame.new(finger.tilt:VectorToWorldSpace(Vector3.new(0, -second, 0)))
	end
end

return GuestMask
