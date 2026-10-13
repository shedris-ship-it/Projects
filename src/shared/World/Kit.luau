-- Dresses PropFactory's grey-box in the kit's modelled pieces (the visual
-- rework; Data/Kit, tools/blender). The grey-box stays as the piece's body
-- for the game: its parts keep colliding, blocking sight, catching the
-- hands' rays and carrying their names, joints and lights, only no longer
-- seen. The kit's mesh is what you see: fitted to the prop's own size, it
-- never collides, never catches a ray (CanQuery off), and casts the shadow.
-- It sits inside the prop's model, so pushing the prop moves it too
-- (Services/PushService gathers every part in the model).
--
-- A kind without a kit entry, or whose mesh isn't loaded, stays as it was
-- built.
--
-- The meshes are built once on the server from their ids (Kit.preload; how
-- the kit reaches the place is in Data/Kit's header), each wearing its
-- SurfaceAppearance from ReplicatedStorage.Kit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitData = require(script.Parent.Parent.Data.Kit)

local Kit = {}

-- Where the kit's looks live in the place: ReplicatedStorage.Kit, one
-- SurfaceAppearance per mesh name (assets/kit). (A MeshPart there, from a
-- test in Studio, is used as it is.)
function Kit.folder(): Instance?
	return ReplicatedStorage:FindFirstChild("Kit")
end

local loaded: { [string]: MeshPart } = {} -- mesh name -> its template, built from its id
local loading = false
local done = Instance.new("BindableEvent")
local ready = false

-- Every kit entry with an id, once per mesh.
local function entriesWithIds()
	local byMesh = {}
	for _, group in { KitData.Props, KitData.Slabs, KitData.Parts, KitData.Fixtures } do
		for _, entry in group do
			if entry.id and not byMesh[entry.mesh] then
				byMesh[entry.mesh] = entry
			end
		end
	end
	return byMesh
end

-- Builds every imported mesh from its id, all at once (server; yields until
-- they're in, a second or so). Safe to call again: later calls wait for the
-- first. Returns the names loaded and those that failed.
function Kit.preload(): ({ string }, { string })
	if not ready then
		if loading then
			done.Event:Wait()
		else
			loading = true
			local AssetService = game:GetService("AssetService")
			local folder = Kit.folder()
			local pending = 0
			local finished = Instance.new("BindableEvent")
			for name, entry in entriesWithIds() do
				pending += 1
				task.spawn(function()
					local ok, part = pcall(function()
						return AssetService:CreateMeshPartAsync(
							Content.fromUri("rbxassetid://" .. tostring(entry.id)),
							{ CollisionFidelity = Enum.CollisionFidelity.Box }
						)
					end)
					if ok and part then
						part.Name = name
						local look = folder and folder:FindFirstChild(name)
						if look and look:IsA("SurfaceAppearance") then
							look:Clone().Parent = part
						end
						loaded[name] = part
					else
						warn(
							("[Consensus] kit: %s's mesh (%s) didn't load: %s"):format(
								name,
								tostring(entry.id),
								tostring(part)
							)
						)
					end
					pending -= 1
					if pending == 0 then
						finished:Fire()
					end
				end)
			end
			if pending > 0 then
				finished.Event:Wait()
			end
			finished:Destroy()
			ready = true
			loading = false
			done:Fire()
		end
	end
	local names, failed = {}, {}
	for name in entriesWithIds() do
		table.insert(loaded[name] and names or failed, name)
	end
	table.sort(names)
	table.sort(failed)
	return names, failed
end

function Kit.template(name: string): MeshPart?
	if loaded[name] then
		return loaded[name]
	end
	local folder = Kit.folder()
	local found = folder and folder:FindFirstChild(name, true)
	return found and found:IsA("MeshPart") and found or nil
end

-- Studio's 3D importer turns a model's front from glTF's (+Z, where kit.py
-- builds it) to Roblox's (-Z, the LookVector), but the grey-box's front is
-- +Z: every imported piece needs a half turn (seen 2026-10-12: the dining
-- chairs had their backs to the table).
local IMPORT_TURN = CFrame.Angles(0, math.pi, 0)

local function visual(template: MeshPart, size: Vector3, cframe: CFrame): MeshPart
	local mesh = template:Clone()
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = true
	mesh.Massless = true
	mesh.Size = size
	mesh.CFrame = cframe * IMPORT_TURN
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
-- (+Z its front); size: its kind's size (Data/Props; the mesh keeps its own,
-- which Kit.spec holds within it). Returns the mesh it put on, or nil when
-- the kind stays grey-box.
-- Whether a prop (by its item's name in its room, Data/Rooms: "books1",
-- "china", "shelf2") wears its kind's mesh: one kind stands for many things
-- (a Shelf is a bookcase, a china cabinet or a pantry's shelving), and an
-- entry with `names` dresses only the items those patterns match.
function Kit.wears(entry, itemName: string): boolean
	if not entry.names then
		return true
	end
	for _, pattern in entry.names do
		if string.match(itemName, pattern) then
			return true
		end
	end
	return false
end

function Kit.dressProp(model: Model, kindName: string, cf: CFrame, size: Vector3): MeshPart?
	local entry = KitData.Props[kindName]
	local template = entry and Kit.template(entry.mesh)
	if not template or not Kit.wears(entry, model.Name) then
		return nil
	end
	local keep = {}
	for _, name in entry.keep or {} do
		keep[name] = true
	end
	for _, part in bodyParts(model, keep) do
		hide(part)
	end
	-- At the size it was modelled at (never stretched to the grey-box's box:
	-- a coat rack is narrower than its footprint), standing on the floor.
	local _ = size
	local modelled = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	local turn = CFrame.Angles(0, math.rad(entry.turn or 0), 0)
	-- (Where its box's middle belongs, Data/Kit `centre`: a bookcase's front
	-- cornice put its back 0.06 into the wall, which showed between the books.)
	local centre = entry.centre or { 0, 0 }
	local mesh = visual(template, modelled, cf * CFrame.new(centre[1], modelled.Y / 2, centre[2]) * turn)
	mesh.Name = "KitBody"
	mesh.CastShadow = entry.shadow ~= false
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

-- Dresses one grey-box part of the architecture (Data/Kit `Parts`: a
-- railing's baluster, the staircase's newel, a handrail): the mesh stands
-- where the part is, at its modelled size, or at the part's own size when
-- the entry `fit`s (a rail stretched to its length, or slimmed to a bottom
-- rail). The part stays as the game's (a railing's collider is its own part).
function Kit.dressPart(part: BasePart, name: string): MeshPart?
	local entry = KitData.Parts[name]
	local template = entry and Kit.template(entry.mesh)
	if not template or not part.Parent then
		return nil
	end
	local size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	if entry.fit == true then
		size = part.Size
	elseif entry.fit == "y" then
		size = Vector3.new(size.X, part.Size.Y, size.Z) -- (a baluster stretched to its rail)
	end
	local mesh = visual(template, size, part.CFrame)
	mesh.Name = "Kit" .. name
	mesh.CastShadow = entry.shadow ~= false
	mesh.Parent = part.Parent
	hide(part)
	return mesh
end

-- Dresses a light fixture's model (Data/Kit `Fixtures`: the pendant, the
-- hall's chandelier, a sconce). `origin` is where kit.py built the piece
-- round (its floor and middle; +Z its front, into the room), so the caller
-- says where that is (a pendant's top at the ceiling, a sconce's back on the
-- wall). Every grey-box part in the model is hidden, the light-carrying ones
-- too: their lights shine on, and the mesh's glow mask follows them
-- (EffectsController).
function Kit.dressFixture(model: Model, name: string, origin: CFrame): MeshPart?
	local entry = KitData.Fixtures[name]
	local template = entry and Kit.template(entry.mesh)
	if not template then
		return nil
	end
	-- (`scale`: bigger than modelled, all of it: the hall's chandelier.)
	local k = entry.scale or 1
	local modelled = Vector3.new(entry.size[1], entry.size[2], entry.size[3]) * k
	local centre = entry.centre or { 0, 0 }
	local mesh = visual(
		template,
		modelled,
		origin * CFrame.new(centre[1] * k, (entry.floor or 0) * k + modelled.Y / 2, centre[2] * k)
	)
	mesh.Name = "KitBody"
	-- (A shade mustn't hide its own bulb: Data/Kit `shadow`.)
	mesh.CastShadow = entry.shadow ~= false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			hide(part)
		end
	end
	mesh.Parent = model
	return mesh
end

-- A fixture's measures (Data/Kit), for callers that place it: its modelled
-- size, nil when it isn't in.
function Kit.measures(group: string, name: string)
	local entry = KitData[group] and KitData[group][name]
	if not entry or not Kit.template(entry.mesh) then
		return nil
	end
	return entry
end

return Kit
