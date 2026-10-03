-- The Guest's face and hands, built on each client and welded to the
-- replicated head and hand bones (docs/ART.md "The Guest"). Nothing here
-- replicates; it's driven only by the model's GuestForm attribute and the
-- GuestController, so every player sees the same face.
--
--   Calm      porcelain, shallow eye hollows, a closed line of a smile that
--             is far too wide
--   Fraying   the smile stretches ear to ear and opens on too many teeth
--   Breaking  the porcelain cracks and the eye hollows bleed (Moderate,
--             decided 2026-10-02; the smile decided 2026-10-03)
--
-- Everything is thin flat pieces laid on the head's ellipsoid surface, from
-- the pure geometry in Logic/GuestPose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestPose = require(Shared.Logic.GuestPose)

local GuestFace = {}
GuestFace.__index = GuestFace

local COLUMNS = 32

local LIP = Color3.fromRGB(34, 24, 24)
local MOUTH = Color3.fromRGB(12, 6, 6)
local TOOTH = Color3.fromRGB(196, 184, 152)
local CRACK = Color3.fromRGB(54, 46, 42)
local BLOOD = Color3.fromRGB(80, 6, 8)
local HOLLOW = Color3.fromRGB(122, 115, 105)
local SOCKET = Color3.fromRGB(30, 26, 25)
local FINGER = Color3.fromRGB(184, 177, 164)

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

-- CFrame of a flat piece on the head, lifted `offset` studs off the surface.
local function frameOf(spec, offset: number): CFrame
	local c, n = spec.centre, spec.normal
	return CFrame.fromMatrix(
		Vector3.new(c[1] + n[1] * offset, c[2] + n[2] * offset, c[3] + n[3] * offset),
		v(spec.right),
		v(spec.up)
	)
end

function GuestFace.new(head: BasePart)
	local self = setmetatable({ head = head, parts = {}, late = {} }, GuestFace)
	local size = head.Size
	self.a, self.b, self.c = size.X / 2, size.Y / 2, size.Z / 2

	-- Eye hollows: a shallow darker dish, a darker socket, and a pin of light
	-- that only shows in a torch beam.
	self.shine = {}
	for _, eye in GuestPose.Eyes do
		local spec = GuestPose.piece(self.a, self.b, self.c, eye[1] - 0.1, eye[2], eye[1] + 0.1, eye[2])
		local hollow, hw = piecePart(head, "EyeHollow", HOLLOW, true)
		hollow.Size = Vector3.new(0.24, 0.15, 0.03)
		hw.C0 = frameOf(spec, -0.006)
		local socket, sw = piecePart(head, "EyeSocket", SOCKET, true)
		socket.Size = Vector3.new(0.11, 0.07, 0.02)
		sw.C0 = frameOf(spec, -0.001)
		local shine, shw = piecePart(head, "EyeShine", Color3.new(1, 1, 1), true)
		shine.Material = Enum.Material.Neon
		shine.Size = Vector3.new(0.035, 0.035, 0.02)
		shine.Transparency = 1
		shw.C0 = frameOf(spec, 0.004)
		table.insert(self.shine, shine)
		table.insert(self.parts, hollow)
		table.insert(self.parts, socket)
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

	-- Late form: cracks and blood, hidden until Breaking.
	local function polyline(points, name, color, width0, width1, offset)
		for i = 1, #points - 1 do
			local p1, p2 = points[i], points[i + 1]
			local spec = GuestPose.piece(self.a, self.b, self.c, p1[1], p1[2], p2[1], p2[2])
			local part, weld = piecePart(head, name, color)
			local t = (i - 1) / math.max(1, #points - 2)
			part.Size = Vector3.new(spec.length + 0.012, width0 + (width1 - width0) * t, 0.008)
			weld.C0 = frameOf(spec, offset)
			part.Transparency = 1
			if name == "Blood" then
				part.Reflectance = 0.15
			end
			table.insert(self.late, part)
		end
	end
	for _, crack in GuestPose.Cracks do
		polyline(crack, "Crack", CRACK, 0.02, 0.012, 0.0015)
	end
	for _, streak in GuestPose.Blood do
		polyline(streak, "Blood", BLOOD, 0.055, 0.022, 0.003)
	end

	self.width, self.open = -1, -1
	self:SetSmile(math.rad(62), 0)
	self:SetForm(0)
	return self
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
		column.upper.Size = Vector3.new(upper.length + 0.012, 0.026, 0.01)
		column.upperWeld.C0 = frameOf(upper, 0.002)
		column.lower.Size = Vector3.new(lower.length + 0.012, 0.024, 0.01)
		column.lowerWeld.C0 = frameOf(lower, 0.002)
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
		local cf = frameOf(inside, -0.001)
		column.insideWeld.C0 = cf
		-- Too many teeth, narrow and uneven, from both lips.
		local tooth = gap * 0.42 * column.jag
		local teeth = shown and open > 0.05
		for _, t in { { column.toothUp, column.toothUpWeld, 1 }, { column.toothDown, column.toothDownWeld, -1 } } do
			t[1].Transparency = teeth and 0 or 1
			t[1].Size = Vector3.new(math.max(inside.length * 0.5, 0.008), math.max(tooth, 0.004), 0.012)
			t[2].C0 = cf * CFrame.new(0, t[3] * (gap / 2 - tooth / 2), 0.002)
		end
	end
end

-- 0 Calm, 1 Fraying, 2 Breaking: cracks and blood appear at Breaking.
function GuestFace:SetForm(form: number)
	if self.form == form then
		return
	end
	self.form = form
	for _, part in self.late do
		part.Transparency = form >= 2 and 0 or 1
	end
end

function GuestFace:SetShine(on: boolean)
	for _, shine in self.shine do
		shine.Transparency = on and 0.15 or 1
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
function GuestFace.curlHand(hand, curl: number, dt: number, random: () -> number)
	local alpha = 1 - math.exp(-10 * dt)
	for i, finger in hand.fingers do
		if random() < dt * 0.6 then
			finger.offset = (random() - 0.5) * 0.5
		end
		finger.offset *= 1 - math.min(1, dt * 3)
		local goal = curl + finger.offset + (i - 2.5) * 0.04
		finger.curl += (goal - finger.curl) * alpha
		local bend = finger.curl * finger.inward
		finger.knuckle.Transform = CFrame.Angles(0, (i - 2.5) * 0.05, bend * 0.55)
		finger.middle.Transform = CFrame.Angles(0, 0, bend * 0.75)
	end
end

return GuestFace
