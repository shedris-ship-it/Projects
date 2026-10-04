-- Tools lying around the house (owner, 2026-10-04): the pickup models, the
-- tops they are left on, and where a dropped one lands. Placement itself is the
-- pure Logic/ToolPlacement; this turns its answer into parts and prompts. The
-- model is shared with your hand (World/ToolModel), so what you find on the
-- desk is what you hold. Pickups are shared by everyone, and never collide
-- or block a ray (they sit on furniture, off the doorway lanes and room
-- centres the fairness contract keeps clear).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Tools = require(Shared.Data.Tools)
local ToolModel = require(Shared.World.ToolModel)

local Dressing = require(script.Parent.Dressing)

local ToolPickups = {}

-- The tops a tool can be left on, as Logic/ToolPlacement wants them.
-- `distances` maps room id to rooms from the start.
function ToolPickups.surfaces(world, distances): { any }
	local list = {}
	for index, s in world.surfaces or {} do
		local record = s.record
		if record and s.prop.model.Parent then
			table.insert(list, {
				key = record.id .. ":" .. s.prop.id .. ":" .. index,
				room = record.id,
				kind = s.prop.kind,
				steps = distances[record.id] or 99,
				free = Dressing.free(s),
				source = s,
			})
		end
	end
	return list
end

-- The lowest point of a model in the world (its parts' own boxes, turned by
-- however the model is turned). Model:GetBoundingBox is no use here: its box is
-- turned with the model's pivot, so a model lying on its side measures wrongly.
local function lowestY(model: Model): number
	local lowest = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, size = d.CFrame, d.Size
			local half = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2
			lowest = math.min(lowest, cf.Position.Y - half)
		end
	end
	return lowest
end

-- Stand a freshly built tool model on a spot: its resting turn, then its lowest
-- point on the surface. `spot` is a CFrame on the surface (Dressing).
local function settle(model: Model, id: string, spot: CFrame, yaw: number)
	model:ScaleTo(Config.Tools.PickupScale)
	local turn = ToolModel.restTurn(id)
	model:PivotTo(CFrame.new(0, 500, 0) * turn)
	local lift = model:GetPivot().Position.Y - lowestY(model)
	model:PivotTo(spot * CFrame.Angles(0, yaw, 0) * CFrame.new(0, lift, 0) * turn)
end

-- Build one pickup. `item` is { id, uid, film? }; `cframe` is where it rests
-- (a table spot, or a point on the floor for a dropped one). Returns the
-- model, with the prompt's Triggered wired by the caller through `onTake`.
function ToolPickups.make(parent: Instance, item, cframe: CFrame, yaw: number, onTake: (Player) -> ())
	local info = Tools.ById[item.id]
	local model = ToolModel.tool(item.id)
	if not model then
		return nil
	end
	model.Name = "Pickup_" .. item.uid
	settle(model, item.id, cframe, yaw)
	local hit = model.PrimaryPart :: BasePart
	-- No CId or Label on purpose: those make an object Witnessable on every client
	-- (UI/FocusMarkers would offer "Q Witness"), and a tool is something you take.
	model:SetAttribute("ToolId", item.id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = info and info.name or item.id
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = hit
	prompt.Triggered:Connect(onTake)
	model.Parent = parent
	return model, prompt
end

return ToolPickups
