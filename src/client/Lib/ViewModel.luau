-- What you hold: the tool builders now live in shared World/ToolModel (so the
-- tool on the table and the one in your hand are the same model); this adds the
-- sleeved arms and tidy-up. Each model is anchored, non-colliding and local to
-- this client, and Controllers/ViewModelController moves it with the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("ToolModel"))

local ViewModel = {}

ViewModel.torch = ToolModel.torch
ViewModel.setTorchOn = ToolModel.setTorchOn
ViewModel.tool = ToolModel.tool

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
