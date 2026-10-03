-- What you hold, built from parts (owner, 2026-10-03: "you hold nothing").
-- Each builder returns a Model whose PrimaryPart is its pivot; the model is
-- anchored, non-colliding and local to this client, and Controllers/
-- ViewModelController moves it with the camera. Everything points down -Z
-- (away from the viewer) with its middle at the pivot.

local ViewModel = {}

local function part(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.CFrame = root.CFrame * offset
	p.Parent = model
	return p
end

-- A cylinder lying along Z (a Cylinder part is long in X).
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local function newModel(name: string)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Pivot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.new(0, 500, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local METAL = Color3.fromRGB(46, 46, 50)
local DARK = Color3.fromRGB(26, 26, 28)

-- The torch in your right hand. `lens` glows while it's on.
function ViewModel.torch(): (Model, BasePart)
	local model, root = newModel("Torch")
	part(model, root, "Body", Vector3.new(1.1, 0.3, 0.3), ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	part(model, root, "Grip", Vector3.new(0.5, 0.33, 0.33), CFrame.new(0, 0, 0.2) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	part(model, root, "Head", Vector3.new(0.26, 0.46, 0.46), CFrame.new(0, 0, -0.6) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	part(model, root, "Cap", Vector3.new(0.06, 0.32, 0.32), CFrame.new(0, 0, 0.58) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	part(model, root, "Switch", Vector3.new(0.12, 0.07, 0.2), CFrame.new(0, 0.18, 0.05), {
		Color = Color3.fromRGB(190, 60, 50),
		Material = Enum.Material.SmoothPlastic,
	})
	local lens = part(model, root, "Lens", Vector3.new(0.04, 0.4, 0.4), CFrame.new(0, 0, -0.74) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(70, 66, 56),
		Material = Enum.Material.Glass,
	})
	return model, lens
end

function ViewModel.setTorchOn(lens: BasePart, on: boolean)
	lens.Material = on and Enum.Material.Neon or Enum.Material.Glass
	lens.Color = on and Color3.fromRGB(255, 240, 205) or Color3.fromRGB(70, 66, 56)
end

-- The Witness Camera: a 35mm body, top plate, lens and viewfinder.
local function camera(): Model
	local model, root = newModel("Camera")
	part(model, root, "Body", Vector3.new(0.95, 0.55, 0.42), CFrame.new(), {
		Color = Color3.fromRGB(70, 64, 60),
		Material = Enum.Material.Leather,
	})
	part(model, root, "Plate", Vector3.new(0.97, 0.12, 0.44), CFrame.new(0, 0.33, 0), {
		Color = Color3.fromRGB(176, 176, 172),
		Material = Enum.Material.Metal,
	})
	part(model, root, "Finder", Vector3.new(0.26, 0.14, 0.2), CFrame.new(0, 0.46, 0.06), {
		Color = Color3.fromRGB(150, 150, 146),
		Material = Enum.Material.Metal,
	})
	part(model, root, "Barrel", Vector3.new(0.42, 0.4, 0.4), CFrame.new(0, 0, -0.42) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(28, 28, 30),
		Material = Enum.Material.Metal,
	})
	part(model, root, "Glass", Vector3.new(0.04, 0.32, 0.32), CFrame.new(0, 0, -0.64) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(70, 90, 110),
		Material = Enum.Material.Glass,
		Reflectance = 0.3,
	})
	return model
end

-- The Lantern: a cage round a glowing core, with a handle.
local function lantern(): Model
	local model, root = newModel("Lantern")
	part(
		model,
		root,
		"Base",
		Vector3.new(0.08, 0.56, 0.56),
		CFrame.new(0, -0.38, 0) * CFrame.Angles(0, 0, math.rad(90)),
		{
			Shape = Enum.PartType.Cylinder,
			Color = METAL,
			Material = Enum.Material.Metal,
		}
	)
	part(model, root, "Glass", Vector3.new(0.62, 0.46, 0.46), CFrame.Angles(0, 0, math.rad(90)), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(255, 214, 150),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	part(model, root, "Core", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -0.05, 0), {
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(255, 190, 110),
		Material = Enum.Material.Neon,
	})
	part(model, root, "Top", Vector3.new(0.08, 0.5, 0.5), CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), {
		Shape = Enum.PartType.Cylinder,
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	part(model, root, "Handle", Vector3.new(0.05, 0.05, 0.5), CFrame.new(0, 0.5, 0), {
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		part(
			model,
			root,
			"Bar" .. i,
			Vector3.new(0.04, 0.62, 0.04),
			CFrame.new(math.cos(a) * 0.25, -0.02, math.sin(a) * 0.25),
			{
				Color = METAL,
				Material = Enum.Material.Metal,
			}
		)
	end
	return model
end

-- The Radio: a wooden case, a speaker grille, a dial and an aerial.
local function radio(): Model
	local model, root = newModel("Radio")
	part(model, root, "Case", Vector3.new(0.95, 0.58, 0.36), CFrame.new(), {
		Color = Color3.fromRGB(104, 72, 46),
		Material = Enum.Material.Wood,
	})
	part(model, root, "Grille", Vector3.new(0.5, 0.42, 0.04), CFrame.new(-0.17, 0, -0.19), {
		Color = Color3.fromRGB(32, 28, 24),
		Material = Enum.Material.Fabric,
	})
	part(model, root, "Dial", Vector3.new(0.22, 0.22, 0.04), CFrame.new(0.3, 0.1, -0.19), {
		Color = Color3.fromRGB(226, 214, 176),
		Material = Enum.Material.SmoothPlastic,
	})
	part(model, root, "Knob", Vector3.new(0.12, 0.12, 0.08), CFrame.new(0.3, -0.14, -0.2) * ALONG_Z, {
		Shape = Enum.PartType.Cylinder,
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	part(
		model,
		root,
		"Aerial",
		Vector3.new(0.03, 1.1, 0.03),
		CFrame.new(0.4, 0.8, 0.1) * CFrame.Angles(0, 0, math.rad(-12)),
		{
			Color = Color3.fromRGB(190, 190, 186),
			Material = Enum.Material.Metal,
		}
	)
	return model
end

-- The Plumb Line: a loop of cord and a brass bob hanging below your hand.
local function plumb(): Model
	local model, root = newModel("PlumbLine")
	part(model, root, "Grip", Vector3.new(0.3, 0.14, 0.14), CFrame.new(0, 0.5, 0), {
		Color = Color3.fromRGB(96, 70, 46),
		Material = Enum.Material.Wood,
	})
	part(model, root, "Cord", Vector3.new(0.02, 0.9, 0.02), CFrame.new(0, 0, 0), {
		Color = Color3.fromRGB(190, 176, 140),
		Material = Enum.Material.Fabric,
	})
	part(model, root, "Bob", Vector3.new(0.14, 0.3, 0.14), CFrame.new(0, -0.58, 0), {
		Color = Color3.fromRGB(176, 142, 70),
		Material = Enum.Material.Metal,
	})
	part(model, root, "Tip", Vector3.new(0.1, 0.12, 0.1), CFrame.new(0, -0.8, 0), {
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(176, 142, 70),
		Material = Enum.Material.Metal,
	})
	return model
end

local BUILDERS = { Camera = camera, Lantern = lantern, Radio = radio, PlumbLine = plumb }

function ViewModel.tool(id: string): Model?
	local builder = BUILDERS[id]
	return builder and builder() or nil
end

-- A sleeved forearm and a hand, as if reaching from below the screen. The
-- pivot is the wrist; the arm trails back towards +Z and down.
function ViewModel.arm(shirt: Color3, skin: Color3): Model
	local model, root = newModel("Arm")
	part(model, root, "Sleeve", Vector3.new(0.36, 0.36, 1.6), CFrame.new(0, -0.02, 0.9), {
		Color = shirt,
		Material = Enum.Material.Fabric,
	})
	part(model, root, "Cuff", Vector3.new(0.4, 0.4, 0.14), CFrame.new(0, -0.02, 0.1), {
		Color = shirt:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.Fabric,
	})
	part(model, root, "Hand", Vector3.new(0.32, 0.26, 0.4), CFrame.new(0, 0, -0.18), {
		Color = skin,
		Material = Enum.Material.SmoothPlastic,
	})
	return model
end

function ViewModel.destroy(model: Instance?)
	if model then
		model:Destroy()
	end
end

return ViewModel
