-- The Guest in glass (owner, 2026-10-03: windows do both).
--   * Reflection: dark window glass and mirrors show him standing behind
--     you, because he really is. Roblox's reflectance never shows moving
--     figures, so his mirror image is drawn in a ViewportFrame on the pane,
--     only when Logic/MirrorMath says it would really fall in the pane from
--     where you stand.
--   * Face at the glass: early in a run, one Witness may see his face
--     pressed to a window from outside while his body is elsewhere: a
--     divergence, so it's drawn for that player alone.
-- Nothing here replicates. One pane at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MirrorMath = require(Shared.Logic.MirrorMath)

local GuestReflection = {}
GuestReflection.__index = GuestReflection

local function t3(v: Vector3)
	return { v.X, v.Y, v.Z }
end

function GuestReflection.new()
	return setmetatable({ pairs = {}, pane = nil, mode = nil }, GuestReflection)
end

function GuestReflection:Mode(): string?
	return self.mode
end

function GuestReflection:Pane(): BasePart?
	return self.pane
end

function GuestReflection:Close()
	if self.gui then
		self.gui:Destroy()
	end
	self.gui, self.viewport, self.cam, self.pane, self.mode = nil, nil, nil, nil, nil
	self.pairs = {}
end

function GuestReflection:_open(glass: BasePart, mirror: boolean)
	self:Close()
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GuestReflection"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Adornee = glass
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	-- Faint and cool in night glass, clearer in a mirror.
	viewport.ImageTransparency = mirror and 0.1 or 0.3
	viewport.Ambient = mirror and Color3.fromRGB(90, 86, 82) or Color3.fromRGB(58, 62, 74)
	viewport.LightColor = mirror and Color3.fromRGB(190, 180, 165) or Color3.fromRGB(120, 130, 150)
	viewport.LightDirection = Vector3.new(-0.3, -0.6, -1)
	viewport.Parent = gui
	local cam = Instance.new("Camera")
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	gui.Parent = glass
	self.gui, self.viewport, self.cam, self.pane = gui, viewport, cam, glass
end

-- Copy the visible parts of `root` (the whole body, or just the head) into
-- the viewport. relative: also remember each part relative to `relativeTo`.
function GuestReflection:_copy(parts: { BasePart }, relativeTo: CFrame?)
	self.pairs = {}
	for _, part in parts do
		if part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
			local copy = part:Clone()
			for _, child in copy:GetChildren() do
				if not child:IsA("SpecialMesh") then
					child:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanQuery = false
			copy.LocalTransparencyModifier = 0
			copy.Parent = self.viewport
			table.insert(self.pairs, {
				from = part,
				to = copy,
				rel = relativeTo and relativeTo:ToObjectSpace(part.CFrame) or nil,
			})
		end
	end
end

-- Point the viewport's camera at the pane from your eye, so the pane shows
-- what's "beyond" it.
function GuestReflection:_aim(eye: Vector3)
	local pane = self.pane
	local centre = pane.Position
	local distance = math.max((centre - eye).Magnitude, 0.5)
	self.cam.CFrame = CFrame.lookAt(eye, centre, pane.CFrame.UpVector)
	self.cam.FieldOfView = math.clamp(math.deg(2 * math.atan(pane.Size.Y / 2 / distance)), 1, 120)
end

-- Would his reflection (a point on him) show in this pane from your eye?
function GuestReflection.inPane(glass: BasePart, eye: Vector3, point: Vector3): boolean
	local cf = glass.CFrame
	return (
		MirrorMath.inPane(
			t3(eye),
			t3(point),
			t3(cf.Position),
			t3(cf.LookVector),
			t3(cf.RightVector),
			t3(cf.UpVector),
			glass.Size.X / 2,
			glass.Size.Y / 2
		)
	)
end

-- Show his mirror image in a pane.
function GuestReflection:ShowReflection(glass: BasePart, model: Model, mirror: boolean)
	if self.mode == "reflection" and self.pane == glass then
		return
	end
	self:_open(glass, mirror)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	self:_copy(parts)
	self.mode = "reflection"
end

function GuestReflection:UpdateReflection(eye: Vector3)
	local pane = self.pane
	local origin, normal = pane.Position, pane.CFrame.LookVector
	local function reflect(v: Vector3): Vector3
		return v - normal * 2 * v:Dot(normal)
	end
	for _, pair in self.pairs do
		local cf = pair.from.CFrame
		local p = cf.Position
		local image = p - normal * 2 * (p - origin):Dot(normal)
		-- A mirror flips handedness; flipping X back keeps a proper rotation
		-- (his body is symmetric enough that nobody can tell).
		pair.to.CFrame =
			CFrame.fromMatrix(image, -reflect(cf.RightVector), reflect(cf.UpVector), reflect(-cf.LookVector))
		pair.to.Transparency = pair.from.Transparency
	end
	self:_aim(eye)
end

-- Show his face outside a window, looking in. Returns false if the head
-- isn't available.
function GuestReflection:ShowFace(glass: BasePart, head: BasePart)
	self:_open(glass, false)
	self.viewport.ImageTransparency = 0.05
	self.viewport.Ambient = Color3.fromRGB(70, 74, 88)
	self.viewport.LightColor = Color3.fromRGB(150, 160, 185)
	local parts = { head }
	for _, d in head:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "NeckSkin" then
			table.insert(parts, d)
		end
	end
	self:_copy(parts, head.CFrame)
	self.mode = "face"
	self.face = { started = os.clock(), seen = 0, leaving = nil }
	return true
end

-- Returns false once the face has gone.
function GuestReflection:UpdateFace(eye: Vector3, look: Vector3, dt: number): boolean
	local face = self.face
	local pane = self.pane
	local now = os.clock()
	local toPane = pane.Position - eye
	local looking = toPane.Magnitude < 40 and look:Dot(toPane.Unit) > math.cos(math.rad(25))
	if looking then
		face.seen += dt
	end
	if not face.leaving and (face.seen > 0.6 or now - face.started > 12) then
		face.leaving = now
	end
	local slide = face.leaving and math.clamp((now - face.leaving) / 0.3, 0, 1) * 1.6 or 0
	if face.leaving and slide >= 1.6 then
		self:Close()
		return false
	end
	local normal = pane.CFrame.LookVector
	-- Just outside the glass, a little low, tilted, looking in at you.
	local at = pane.Position - normal * 1.1 + Vector3.new(0, -0.2 - slide, 0)
	local headCF = CFrame.lookAt(at, at + Vector3.new(toPane.X, 0, toPane.Z).Unit * -1)
		* CFrame.Angles(0, 0, math.rad(16))
	for _, pair in self.pairs do
		pair.to.CFrame = headCF * pair.rel
	end
	self:_aim(eye)
	return true
end

return GuestReflection
