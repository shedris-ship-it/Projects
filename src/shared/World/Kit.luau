-- Dresses PropFactory's grey-box in the kit's modelled pieces (the visual
-- rework; Data/Kit, tools/blender). The grey-box stays as the piece's body
-- for the game: its parts keep colliding, blocking sight, catching the
-- hands' rays and carrying their names, joints and lights, only no longer
-- seen. The kit's mesh is what you see: fitted to the prop's own size, it
-- never collides, never catches a ray (CanQuery off), and casts the shadow.
-- It sits inside the prop's model, so pushing the prop moves it too
-- (Services/PushService gathers every part in the model).
--
-- A kind without a kit entry, or whose mesh isn't in the place yet, stays as
-- it was built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitData = require(script.Parent.Parent.Data.Kit)

local Kit = {}

-- Where the kit's meshes live in the place: ReplicatedStorage.Kit, one
-- MeshPart (with its SurfaceAppearance) per mesh name.
function Kit.folder(): Instance?
	return ReplicatedStorage:FindFirstChild("Kit")
end

function Kit.template(name: string): MeshPart?
	local folder = Kit.folder()
	local found = folder and folder:FindFirstChild(name, true)
	return found and found:IsA("MeshPart") and found or nil
end

local function visual(template: MeshPart, size: Vector3, cframe: CFrame): MeshPart
	local mesh = template:Clone()
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = true
	mesh.Massless = true
	mesh.Size = size
	mesh.CFrame = cframe
	mesh:SetAttribute("Kit", true)
	return mesh
end

-- Hides a grey-box part (it stays solid and queryable for the game).
local function hide(part: BasePart)
	if part.Transparency < 1 then
		part:SetAttribute("KitHidden", part.Transparency)
		part.Transparency = 1
	end
	for _, child in part:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		end
	end
end

-- The parts of a prop that belong to its static body: not inside a moving
-- piece (a Model of its own: a drawer, a door, a lid), not kept.
local function bodyParts(model: Model, keep: { [string]: boolean })
	local list = {}
	local function walk(node: Instance)
		for _, child in node:GetChildren() do
			if child:IsA("Model") then
				continue -- a moving piece: dressed on its own, or left as built
			elseif child:IsA("BasePart") then
				if not keep[child.Name] then
					table.insert(list, child)
				end
				walk(child)
			else
				walk(child)
			end
		end
	end
	walk(model)
	return list
end

-- Dresses a prop PropFactory just built. cf: its base frame on the floor
-- (+Z its front); size: its kind's size (Data/Props). Returns the mesh it
-- put on, or nil when the kind stays grey-box.
function Kit.dressProp(model: Model, kindName: string, cf: CFrame, size: Vector3): MeshPart?
	local entry = KitData.Props[kindName]
	local template = entry and Kit.template(entry.mesh)
	if not template then
		return nil
	end
	local keep = {}
	for _, name in entry.keep or {} do
		keep[name] = true
	end
	for _, part in bodyParts(model, keep) do
		hide(part)
	end
	local turn = CFrame.Angles(0, math.rad(entry.turn or 0), 0)
	local mesh = visual(template, size, cf * CFrame.new(0, size.Y / 2, 0) * turn)
	mesh.Name = "KitBody"
	mesh.Parent = model
	return mesh
end

-- Dresses a door slab (World/LevelBuilder): the mesh sits in the door's
-- model at the slab, so it swings with it (Services/DoorService moves every
-- part in the door's model, each keeping its place on the slab). `also`
-- names the slab's grey-box details the mesh replaces (its panels).
function Kit.dressSlab(slab: BasePart, kind: string, also: { string }?): MeshPart?
	local entry = KitData.Slabs[kind]
	local template = entry and Kit.template(entry.mesh)
	local model = slab.Parent
	if not template or not model then
		return nil
	end
	local size = Vector3.new(slab.Size.X, slab.Size.Y, entry.size[3])
	local mesh = visual(template, size, slab.CFrame * CFrame.Angles(0, math.rad(entry.turn or 0), 0))
	mesh.Name = "KitSlab"
	mesh.Parent = model
	hide(slab)
	local names = {}
	for _, name in also or {} do
		names[name] = true
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and names[child.Name] then
			hide(child)
		end
	end
	return mesh
end

return Kit
