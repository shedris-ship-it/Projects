-- What you hold: the tool builders live in shared World/ToolModel (so the
-- tool on the table and the one in your hand are the same model); this adds
-- your arms and tidy-up. Each model is anchored, non-colliding and local to
-- this client, and Controllers/ViewModelController moves it with the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("ToolModel"))

local ViewModel = {}

ViewModel.torch = ToolModel.torch
ViewModel.setTorchOn = ToolModel.setTorchOn
ViewModel.tool = ToolModel.tool

-- Your own arm (the owner, 2026-10-12: "make sure ... your arm is actually your
-- arm and matches your avatar instead of just being a default hand"): copies
-- of your character's upper arm, forearm and hand on `side` ("Left" or
-- "Right"), with whatever they wear (their colours, meshes and look, and the
-- shirt's clothing through a Humanoid of their own), sized by `scale` and
-- slimmed by `thickness` across. The parts keep their names (a shirt maps onto
-- them by name). Returns the model and its { upper, lower, hand }. Controllers/ViewModelController
-- bends them from an off-screen shoulder to what the hand holds. Nil if the
-- character has no such arm.
function ViewModel.armFrom(character: Model, side: string, scale: number, thickness: number)
	local sources = {
		upper = character:FindFirstChild(side .. "UpperArm"),
		lower = character:FindFirstChild(side .. "LowerArm"),
		hand = character:FindFirstChild(side .. "Hand"),
	}
	for _, source in sources do
		if not (source and source:IsA("BasePart")) then
			return nil, nil
		end
	end
	local model = Instance.new("Model")
	model.Name = side .. "Arm"
	local bones = {}
	for key, source in sources do
		local copy = (source :: BasePart):Clone()
		for _, child in copy:GetChildren() do
			-- Only what it looks like: no joints, attachments, welds or scripts.
			if not (child:IsA("SurfaceAppearance") or child:IsA("DataModelMesh") or child:IsA("Decal")) then
				child:Destroy()
			end
		end
		bones[key] = copy
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Massless = true
		copy.LocalTransparencyModifier = 0
		local size = (source :: BasePart).Size
		copy.Size = Vector3.new(size.X * scale * thickness, size.Y * scale, size.Z * scale * thickness)
		copy.Parent = model
	end
	-- A shirt or a skin tone the character wears as clothing draws on its
	-- arm only inside a Humanoid's model.
	local clothes = {}
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("BodyColors") then
			table.insert(clothes, child:Clone())
		end
	end
	if #clothes > 0 then
		local humanoid = Instance.new("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.Parent = model
		for _, item in clothes do
			item.Parent = model
		end
	end
	model.PrimaryPart = bones.hand
	return model, bones
end

-- What the copied arm was made from, to tell when it needs making again (the
-- outfit painted after the copy, a new character).
function ViewModel.armLook(character: Model, side: string): string
	local parts = {}
	for _, name in { "UpperArm", "LowerArm", "Hand" } do
		local p = character:FindFirstChild(side .. name)
		if p and p:IsA("BasePart") then
			table.insert(parts, p.Color:ToHex() .. tostring(p.Size))
		end
	end
	return table.concat(parts, "|")
end

function ViewModel.destroy(model: Instance?)
	if model then
		model:Destroy()
	end
end

return ViewModel
