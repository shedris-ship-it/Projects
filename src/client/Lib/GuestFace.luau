-- The Guest's face and hands, built on each client and welded to the
-- replicated head and hand bones (docs/ART.md "The Guest"). Nothing here
-- replicates; it's driven only by the model's GuestForm attribute and the
-- GuestController, so every player sees the same face.
--
-- The mask over the dark (the owner's choice, 2026-10-06): his head is black
-- (Stalker/StalkerModel) and his face is a porcelain mask laid over it, a
-- shallower shell than the head, set forward, so its rim shows from the
-- side. Painted on it, faintly: brows, rouge, thin dark lips.
--
--   Calm      the mask, its eyes two holes onto the black behind, a closed
--             painted smile far too wide
--   Fraying   the smile stretches ear to ear and opens on small uneven
--             teeth; hairline crazing in the glaze
--   Breaking  the mask has cracked and slipped a little askew; pieces have
--             come away, and behind them there is only black, the eye-shine
--             floating in it. No blood (Moderate, and darker for it)
--
-- Everything is thin flat pieces laid on the mask's ellipsoid surface, from
-- the pure geometry in Logic/GuestPose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestPose = require(Shared.Logic.GuestPose)

local GuestFace = {}
GuestFace.__index = GuestFace

local COLUMNS = 32

local MASK = Color3.fromRGB(214, 206, 192)
local HOLE = Color3.fromRGB(0, 0, 0)
local HOLE_RIM = Color3.fromRGB(46, 40, 38)
local BROW = Color3.fromRGB(78, 68, 62)
local ROUGE = Color3.fromRGB(196, 126, 122)
local LIP = Color3.fromRGB(58, 30, 32)
local MOUTH = Color3.fromRGB(6, 4, 4)
local TOOTH = Color3.fromRGB(206, 196, 168)
local CRACK = Color3.fromRGB(66, 58, 54)
local SHARD = Color3.fromRGB(2, 2, 3) -- where the mask has come away: the dark beneath
local FINGER = Color3.fromRGB(184, 177, 164)

-- The mask's shell against the head's (half-sizes and how far forward).
local MASK_WIDE, MASK_TALL, MASK_DEEP, MASK_FORWARD, MASK_DROP = 0.94, 0.82, 0.7, 0.42, 0.07
-- At Breaking it has slipped: turned and dropped a little.
local SLIP = CFrame.new(0.015, -0.035, 0) * CFrame.Angles(0, 0, math.rad(6))

local function v(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function piecePart(parent: BasePart, name: string, color: Color3, ball: boolean?): (BasePart, Weld)
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = Vector3.new(0.05, 0.05, 0.01)
	if ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local weld = Instance.new("Weld")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p, weld
end

-- A flat piece's frame on the mask (mask space), lifted `offset` studs off
-- its surface.
local function localFrame(spec, offset: number): CFrame
	local c, n = spec.centre, spec.normal
	return CFrame.fromMatrix(
		Vector3.new(c[1] + n[1] * offset, c[2] + n[2] * offset, c[3] + n[3] * offset),
		v(spec.right),
		v(spec.up)
	)
end

function GuestFace.new(head: BasePart)
	local self = setmetatable({ head = head, statics = {}, crazing = {}, late = {}, parts = {} }, GuestFace)
	local size = head.Size
	self.a, self.b, self.c = size.X / 2 * MASK_WIDE, size.Y / 2 * MASK_TALL, size.Z / 2 * MASK_DEEP
	-- Lower than the head's middle, so the black dome of his head shows above it.
	self.centre = CFrame.new(0, -size.Y * MASK_DROP, -size.Z / 2 * MASK_FORWARD)
	self.maskCF = self.centre
	local a, b, c = self.a, self.b, self.c

	-- The mask itself.
	local mask, maskWeld = piecePart(head, "Mask", MASK, true)
	mask.Size = Vector3.new(a * 2, b * 2, c * 2)
	mask.Reflectance = 0.05
	mask.CastShadow = true
	self.mask, self.maskWeld = mask, maskWeld
	maskWeld.C0 = self.maskCF

	-- A piece fixed on the mask (moves with it when it slips).
	local function static(part: BasePart, weld: Weld, frame: CFrame)
		table.insert(self.statics, { weld = weld, frame = frame })
		weld.C0 = self.maskCF * frame
		table.insert(self.parts, part)
		return part
	end

	-- Eyes: round holes onto the black behind, wide and lidless (the owner,
	-- 2026-10-07: "like he doesn't have eyelids"), a darker rim round each,
	-- and a pin of light that only shows in a torch beam, floating in the dark.
	self.shine = {}
	self.eyes = {} -- each eye's pin of light, which follows you about
	for _, eye in GuestPose.Eyes do
		local spec = GuestPose.piece(a, b, c, eye[1] - 0.1, eye[2], eye[1] + 0.1, eye[2])
		local rim, rw = piecePart(head, "EyeRim", HOLE_RIM, true)
		rim.Size = Vector3.new(0.235, 0.235, 0.02)
		rim.Transparency = 0.35
		static(rim, rw, localFrame(spec, 0.002))
		local hole, hw = piecePart(head, "EyeHole", HOLE, true)
		hole.Size = Vector3.new(0.19, 0.19, 0.02)
		static(hole, hw, localFrame(spec, 0.004))
		local shine, shw = piecePart(head, "EyeShine", Color3.new(1, 1, 1), true)
		shine.Material = Enum.Material.Neon
		shine.Size = Vector3.new(0.055, 0.055, 0.02)
		shine.Transparency = 1
		local frame = localFrame(spec, 0.008)
		static(shine, shw, frame)
		table.insert(self.shine, shine)
		table.insert(self.eyes, { weld = shw, frame = frame, right = v(spec.right), up = v(spec.up) })
		-- A faint painted brow, arched, a little too high.
		local side = eye[1] >= 0 and 1 or -1
		local brow = GuestPose.piece(a, b, c, eye[1] - side * 0.13, eye[2] + 0.26, eye[1] + side * 0.12, eye[2] + 0.26)
		local bp, bw = piecePart(head, "Brow", BROW)
		bp.Size = Vector3.new(brow.length + 0.01, 0.012, 0.006)
		bp.Transparency = 0.7
		static(bp, bw, localFrame(brow, 0.003))
		-- Faded rouge on the cheek.
		local cheek = GuestPose.piece(a, b, c, side * 0.5, -0.2, side * 0.62, -0.2)
		local rp, rw2 = piecePart(head, "Rouge", ROUGE, true)
		rp.Size = Vector3.new(0.17, 0.1, 0.01)
		rp.Transparency = 0.72
		static(rp, rw2, localFrame(cheek, 0.002))
	end

	-- The mouth: per column, an upper and lower lip line, the dark inside,
	-- and a tooth hanging from each lip.
	self.columns = {}
	for i = 1, COLUMNS do
		local column = {}
		column.upper, column.upperWeld = piecePart(head, "LipUpper", LIP)
		column.lower, column.lowerWeld = piecePart(head, "LipLower", LIP)
		column.inside, column.insideWeld = piecePart(head, "Mouth", MOUTH)
		column.toothUp, column.toothUpWeld = piecePart(head, "Tooth", TOOTH, true)
		column.toothDown, column.toothDownWeld = piecePart(head, "Tooth", TOOTH, true)
		-- Uneven teeth, the same for everyone.
		column.jag = 0.75 + ((i * 37) % 11) / 22
		self.columns[i] = column
	end

	-- Crazing in the glaze (from Fraying), then cracks and the pieces that
	-- have come away (Breaking).
	local function polyline(points, name, color, width0, width1, offset, list)
		for i = 1, #points - 1 do
			local p1, p2 = points[i], points[i + 1]
			local spec = GuestPose.piece(a, b, c, p1[1], p1[2], p2[1], p2[2])
			local part, weld = piecePart(head, name, color)
			local t = (i - 1) / math.max(1, #points - 2)
			part.Size = Vector3.new(spec.length + 0.014, width0 + (width1 - width0) * t, 0.008)
			part.Transparency = 1
			static(part, weld, localFrame(spec, offset))
			table.insert(list, part)
		end
	end
	for _, crack in GuestPose.Cracks do
		polyline(crack, "Crack", CRACK, 0.016, 0.008, 0.0015, self.crazing)
	end
	for _, streak in GuestPose.Blood do
		-- (The old blood's paths: cracks running down from the eyes now.)
		polyline(streak, "EyeCrack", CRACK, 0.022, 0.01, 0.0018, self.late)
	end
	for _, shard in GuestPose.Shards do
		polyline(shard.path, "Missing", SHARD, shard.width, shard.width * 0.6, 0.0025, self.late)
	end

	self.width, self.open = -1, -1
	self:SetSmile(math.rad(62), 0)
	self:SetForm(0)
	return self
end

-- A frame on the mask as the head's weld wants it.
function GuestFace:_frame(spec, offset: number): CFrame
	return self.maskCF * localFrame(spec, offset)
end

-- Lay the smile out for a half-width (radians around the head) and an
-- opening (0..1). Cheap enough per frame, but skipped when nothing changed.
function GuestFace:SetSmile(halfWidth: number, open: number)
	if math.abs(halfWidth - self.width) < 0.004 and math.abs(open - self.open) < 0.01 then
		return
	end
	self.width, self.open = halfWidth, open
	local a, b, c = self.a, self.b, self.c
	local cols = GuestPose.mouth(halfWidth, open, COLUMNS)
	for i, column in self.columns do
		local c1, c2 = cols[i], cols[i + 1]
		local upper = GuestPose.piece(a, b, c, c1.theta, c1.upper, c2.theta, c2.upper)
		local lower = GuestPose.piece(a, b, c, c1.theta, c1.lower, c2.theta, c2.lower)
		column.upper.Size = Vector3.new(upper.length + 0.012, 0.013, 0.01)
		column.upperWeld.C0 = self:_frame(upper, 0.002)
		column.lower.Size = Vector3.new(lower.length + 0.012, 0.012, 0.01)
		column.lowerWeld.C0 = self:_frame(lower, 0.002)
		-- The inside of the mouth spans the gap between the lips.
		local midU, midL = (c1.upper + c2.upper) / 2, (c1.lower + c2.lower) / 2
		local midT = (c1.theta + c2.theta) / 2
		local qU = GuestPose.surface(a, b, c, midT, midU)
		local qL = GuestPose.surface(a, b, c, midT, midL)
		local gap = math.sqrt((qU[1] - qL[1]) ^ 2 + (qU[2] - qL[2]) ^ 2 + (qU[3] - qL[3]) ^ 2)
		local inside =
			GuestPose.piece(a, b, c, c1.theta, (c1.upper + c1.lower) / 2, c2.theta, (c2.upper + c2.lower) / 2)
		local shown = gap > 0.008
		column.inside.Transparency = shown and 0 or 1
		column.inside.Size = Vector3.new(inside.length + 0.014, math.max(gap, 0.002), 0.006)
		local cf = self:_frame(inside, -0.001)
		column.insideWeld.C0 = cf
		-- Small uneven teeth, from both lips.
		local tooth = gap * 0.38 * column.jag
		local teeth = shown and open > 0.05
		for _, t in { { column.toothUp, column.toothUpWeld, 1 }, { column.toothDown, column.toothDownWeld, -1 } } do
			t[1].Transparency = teeth and 0 or 1
			t[1].Size = Vector3.new(math.max(inside.length * 0.45, 0.008), math.max(tooth, 0.004), 0.012)
			t[2].C0 = cf * CFrame.new(0, t[3] * (gap / 2 - tooth / 2), 0.002)
		end
	end
end

-- 0 Calm, 1 Fraying, 2 Breaking: crazing from Fraying; at Breaking the mask
-- cracks, slips askew and loses pieces.
function GuestFace:SetForm(form: number)
	if self.form == form then
		return
	end
	self.form = form
	for _, part in self.crazing do
		part.Transparency = form >= 2 and 0 or (form >= 1 and 0.5 or 1)
	end
	for _, part in self.late do
		part.Transparency = form >= 2 and 0 or 1
	end
	self.maskCF = form >= 2 and self.centre * SLIP or self.centre
	self.maskWeld.C0 = self.maskCF
	for _, entry in self.statics do
		entry.weld.C0 = self.maskCF * entry.frame
	end
	-- The smile follows the mask.
	self.width = -1
	self:SetSmile(math.rad(62), 0)
end

-- The pins of light in his eyes: 0 none, then a faint glow in the dark,
-- 1 caught full in your torch.
function GuestFace:SetShine(level: number | boolean)
	local amount = level == true and 1 or (level == false and 0 or level :: number)
	for _, shine in self.shine do
		shine.Transparency = amount <= 0 and 1 or (1 - amount) * 0.85 + 0.05
	end
end

-- Lidless, and they follow you: each pin of light slides inside its eye
-- towards `point` (where you are).
function GuestFace:LookAt(point: Vector3)
	local rel = self.maskCF:PointToObjectSpace(self.head.CFrame:PointToObjectSpace(point))
	for _, eye in self.eyes do
		local base = eye.frame.Position
		local toward = rel - base
		if toward.Magnitude > 0.01 then
			local d = toward.Unit
			local reach = 0.05
			local offset = eye.right * math.clamp(d:Dot(eye.right) * 1.6, -1, 1) * reach
				+ eye.up * math.clamp(d:Dot(eye.up) * 1.6, -1, 1) * reach
			eye.weld.C0 = self.maskCF * CFrame.new(offset) * eye.frame
		end
	end
end

-- Hands ------------------------------------------------------------------------

-- Long two-jointed fingers on a hand bone, curling towards the palm
-- (which faces the body). Returns { motors, curl } for SetCurl.
function GuestFace.hand(hand: BasePart, side: string)
	local rig = GuestPose.Rig
	local inward = side == "Left" and 1 or -1
	local result = { fingers = {}, side = side }
	local length1, length2 = rig.finger[1], rig.finger[2]
	local base = -hand.Size.Y / 2 + 0.02
	local layout = {
		{ 0, base, -0.055, 1.0 },
		{ 0, base, -0.018, 1.08 },
		{ 0, base, 0.018, 1.0 },
		{ 0, base, 0.052, 0.86 },
		{ inward * 0.05, base + 0.2, -0.08, 0.72 }, -- thumb, in front
	}
	for i, spec in layout do
		local scale = spec[4]
		local segment1 = Instance.new("Part")
		segment1.Name = "Finger"
		segment1.Size = Vector3.new(0.05, length1 * scale, 0.05)
		local segment2 = Instance.new("Part")
		segment2.Name = "Finger"
		segment2.Size = Vector3.new(0.042, length2 * scale, 0.042)
		for _, p in { segment1, segment2 } do
			p.Color = FINGER
			p.Material = Enum.Material.SmoothPlastic
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		local knuckle = Instance.new("Motor6D")
		knuckle.Part0 = hand
		knuckle.Part1 = segment1
		knuckle.C0 = CFrame.new(spec[1], spec[2], spec[3])
			* (i == 5 and CFrame.Angles(math.rad(-25), 0, inward * math.rad(25)) or CFrame.identity)
		knuckle.C1 = CFrame.new(0, segment1.Size.Y / 2 - 0.02, 0)
		knuckle.Parent = segment1
		local middle = Instance.new("Motor6D")
		middle.Part0 = segment1
		middle.Part1 = segment2
		middle.C0 = CFrame.new(0, -segment1.Size.Y / 2 + 0.02, 0)
		middle.C1 = CFrame.new(0, segment2.Size.Y / 2 - 0.01, 0)
		middle.Parent = segment2
		segment1.Parent = hand
		segment2.Parent = hand
		table.insert(result.fingers, { knuckle = knuckle, middle = middle, curl = 0, offset = 0, inward = inward })
	end
	return result
end

-- Curl the fingers (0 straight, ~1.4 gripping, below 0 splayed back). Each
-- finger lags a little and twitches on its own; `random` is cosmetic.
-- `drum` (0..1): they drum one after another, impatient.
function GuestFace.curlHand(hand, curl: number, dt: number, random: () -> number, drum: number?)
	local alpha = 1 - math.exp(-10 * dt)
	local clock = os.clock()
	for i, finger in hand.fingers do
		if random() < dt * 0.6 then
			finger.offset = (random() - 0.5) * 0.5
		end
		finger.offset *= 1 - math.min(1, dt * 3)
		local tap = (drum or 0) > 0 and i <= 4 and drum * math.max(0, math.sin(clock * 9 - i * 0.9)) or 0
		local goal = curl + finger.offset + (i - 2.5) * 0.04 + tap
		finger.curl += (goal - finger.curl) * alpha
		local bend = finger.curl * finger.inward
		finger.knuckle.Transform = CFrame.Angles(0, (i - 2.5) * 0.05, bend * 0.55)
		finger.middle.Transform = CFrame.Angles(0, 0, bend * 0.75)
	end
end

return GuestFace
