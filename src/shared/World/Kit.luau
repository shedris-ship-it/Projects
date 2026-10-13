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

-- Every kit entry with an id, once per mesh: the groups' entries, a prop's
-- moving pieces and the mesh it hangs on each of its parts (`pieces`,
-- `each`), and a wall decor's variants.
local function entriesWithIds()
	local byMesh = {}
	local function add(entry)
		if entry.id and entry.mesh and not byMesh[entry.mesh] then
			byMesh[entry.mesh] = entry
		end
	end
	for _, group in { KitData.Props, KitData.Slabs, KitData.Parts, KitData.Fixtures, KitData.Decor or {} } do
		for _, entry in group do
			add(entry)
			for _, piece in entry.pieces or {} do
				add(piece)
			end
			if entry.each then
				add(entry.each)
			end
			for _, variant in entry.variants or {} do
				add(variant)
			end
			for _, other in entry.others or {} do
				add(other)
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

-- (An entry's `turn`, degrees about Y: a piece whose front faces another way
-- than a prop's. Trim's front is its part's -Z, toward the room, so it turns
-- back the half turn every piece gets.)
local function turnOf(entry): CFrame
	return CFrame.Angles(0, math.rad(entry.turn or 0), 0)
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

-- Which of a kind's entries an item wears: the kind's own, or one of its
-- `others` (another thing the kind stands for: the china cabinet and the
-- steel shelving are Shelf items too), by its name. nil: none.
function Kit.choose(entry, itemName: string)
	if Kit.wears(entry, itemName) then
		return entry
	end
	for _, other in entry.others or {} do
		if Kit.wears(other, itemName) then
			return other
		end
	end
	return nil
end

-- A prop's moving pieces (Data/Kit `pieces`: a drawer's front, a chest's
-- lid): each piece's mesh hangs on the piece's main part, where kit.py built
-- it round that part's middle (`at`), inside the piece's model so it moves
-- with it (Services/FurnitureService and Controllers/MotionController move
-- every part in the model). The grey-box parts it replaces (`hide`) stay as
-- the game's.
local function dressPieces(model: Model, entry)
	for _, spec in entry.pieces or {} do
		local template = Kit.template(spec.mesh)
		if not template then
			continue
		end
		for _, child in model:GetChildren() do
			if not child:IsA("Model") or not string.match(child.Name, spec.match) then
				continue
			end
			local primary = child.PrimaryPart
			if not primary then
				continue
			end
			local at = spec.at or { 0, 0, 0 }
			local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
			local mesh = visual(template, size, primary.CFrame * CFrame.new(at[1], at[2], at[3]))
			mesh.Name = "KitPiece"
			mesh.Parent = child
			local names = {}
			for _, name in spec.hide or {} do
				names[name] = true
			end
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") and names[part.Name] then
					hide(part)
				end
			end
		end
	end
end

-- A kind built of several alike things (Data/Kit `each`: the boxes in a
-- stack): each matching part wears the mesh at its own size.
local function dressEach(model: Model, entry): MeshPart?
	local spec = entry.each
	local template = Kit.template(spec.mesh)
	if not template then
		return nil
	end
	local last
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and string.match(part.Name, spec.match) then
			local mesh = visual(template, part.Size, part.CFrame)
			mesh.Name = "Kit" .. part.Name
			mesh.Parent = model
			hide(part)
			last = mesh
		end
	end
	return last
end

function Kit.dressProp(model: Model, kindName: string, cf: CFrame, size: Vector3): MeshPart?
	local entry = KitData.Props[kindName]
	if entry and entry.each then
		return dressEach(model, entry)
	end
	entry = entry and Kit.choose(entry, model.Name)
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
	-- At the size it was modelled at (never stretched to the grey-box's box:
	-- a coat rack is narrower than its footprint), standing on the floor.
	local _ = size
	local modelled = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	local turn = CFrame.Angles(0, math.rad(entry.turn or 0), 0)
	-- (Where its box's middle belongs, Data/Kit `centre`: a bookcase's front
	-- cornice put its back 0.06 into the wall, which showed between the books.)
	local centre = entry.centre or { 0, 0 }
	-- (`floor`: its box's bottom above the floor, a curtain hanging clear of it.)
	local mesh =
		visual(template, modelled, cf * CFrame.new(centre[1], (entry.floor or 0) + modelled.Y / 2, centre[2]) * turn)
	mesh.Name = "KitBody"
	mesh.CastShadow = entry.shadow ~= false
	mesh.Parent = model
	dressPieces(model, entry)
	return mesh
end

-- Dresses a door slab (World/LevelBuilder): the mesh sits in the door's
-- model at the slab, so it swings with it (Services/DoorService moves every
-- part in the door's model, each keeping its place on the slab). `also`
-- names the slab's grey-box details the mesh replaces (its panels). `whole`:
-- the whole door's frame, when the slab is only part of it (a glazed door's
-- slab stops at the glass): the mesh stands there at its modelled size.
function Kit.dressSlab(slab: BasePart, kind: string, also: { string }?, whole: CFrame?): MeshPart?
	local entry = KitData.Slabs[kind]
	local template = entry and Kit.template(entry.mesh)
	local model = slab.Parent
	if not template or not model then
		return nil
	end
	local size = if whole
		then Vector3.new(entry.size[1], entry.size[2], entry.size[3])
		else Vector3.new(slab.Size.X, slab.Size.Y, entry.size[3])
	local mesh = visual(template, size, (whole or slab.CFrame) * turnOf(entry))
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
local function fitted(entry, size: Vector3?): Vector3
	local modelled = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	if not size then
		return modelled
	elseif entry.fit == true then
		return size
	elseif entry.fit == "y" then
		return Vector3.new(modelled.X, size.Y, modelled.Z) -- (a baluster stretched to its rail)
	end
	return modelled
end

function Kit.dressPart(part: BasePart, name: string): MeshPart?
	local entry = KitData.Parts[name]
	local template = entry and Kit.template(entry.mesh)
	if not template or not part.Parent then
		return nil
	end
	local mesh = visual(template, fitted(entry, part.Size), part.CFrame * turnOf(entry))
	mesh.Name = "Kit" .. name
	mesh.CastShadow = entry.shadow ~= false
	mesh.Parent = part.Parent
	hide(part)
	return mesh
end

-- Puts a piece of the architecture where no grey-box part stands for it
-- (Data/Kit `Parts`: a stair's tread and riser over its step); `size` for
-- one that fits. Returns nil when it isn't in.
function Kit.place(parent: Instance, name: string, cframe: CFrame, size: Vector3?): MeshPart?
	local entry = KitData.Parts[name]
	local template = entry and Kit.template(entry.mesh)
	if not template then
		return nil
	end
	local mesh = visual(template, fitted(entry, size), cframe * turnOf(entry))
	mesh.Name = "Kit" .. name
	mesh.CastShadow = entry.shadow ~= false
	mesh.Parent = parent
	return mesh
end

-- Swaps a piece of trim for its kit mesh (Data/Kit `Parts`: a baseboard,
-- the crown, a casing). Trim is only seen (it never collides, never catches
-- a ray), so the mesh takes the part's place, name, attributes, tags and
-- transparency (a seam's trim shown only while it's a wall) and the part
-- goes. `roll`: degrees about the part's own Z, for a casing's upright legs
-- (the mesh lies along X; its length then runs up the part). Returns what
-- stands there now.
function Kit.swap(part: BasePart, name: string, roll: number?): BasePart
	local entry = KitData.Parts[name]
	local template = entry and Kit.template(entry.mesh)
	if not template or not part.Parent then
		return part
	end
	local size = part.Size
	if roll and math.abs(roll) == 90 then
		size = Vector3.new(size.Y, size.X, size.Z)
	end
	local mesh =
		visual(template, fitted(entry, size), part.CFrame * CFrame.Angles(0, 0, math.rad(roll or 0)) * turnOf(entry))
	mesh.Name = part.Name
	mesh.Transparency = part.Transparency
	mesh.CastShadow = part.CastShadow
	for key, value in part:GetAttributes() do
		mesh:SetAttribute(key, value)
	end
	for _, tag in part:GetTags() do
		mesh:AddTag(tag)
	end
	mesh.Parent = part.Parent
	part:Destroy()
	return mesh
end

-- Dresses the house's front door (Data/Kit `Slabs` FrontDoor; World/
-- MansionBuilder): the mesh hangs under the door part, which swings open
-- with everything under it at the end of the run (Services/FinaleService),
-- and the part and its grey-box panels and knob are hidden. `inside` is
-- the door's frame facing into the hall (the mesh's front).
function Kit.dressFront(door: BasePart, inside: CFrame): MeshPart?
	local entry = KitData.Slabs.FrontDoor
	local template = entry and Kit.template(entry.mesh)
	if not template then
		return nil
	end
	local size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	local at = entry.at or { 0, 0, 0 }
	-- (Its front is `inside`'s LookVector: undo the half turn every piece gets.)
	local mesh = visual(template, size, inside * CFrame.new(at[1], at[2], -at[3]) * IMPORT_TURN)
	mesh.Name = "KitFront"
	hide(door)
	for _, part in door:GetDescendants() do
		if part:IsA("BasePart") then
			hide(part)
		end
	end
	mesh.Parent = door
	return mesh
end

-- Dresses a wall decor's model (Data/Kit `Decor`: the window, a painting,
-- the mirror). `cf` is the decor's frame on the wall (its LookVector into
-- the room, World/PropFactory.buildDecor); kit.py built the piece out from
-- the wall, its box's middle `at` = { x, y, out }. A kind with `variants`
-- wears the `pick`th (from the decor's own seed). The grey-box parts it
-- replaces (`hide`) stay, unseen; the rest (the glass, the night, a curtain)
-- are the game's.
function Kit.dressDecor(model: Model, kind: string, cf: CFrame, pick: number?): MeshPart?
	local entry = KitData.Decor and KitData.Decor[kind]
	if not entry then
		return nil
	end
	local meshName = entry.mesh
	if entry.variants then
		local n = #entry.variants
		meshName = entry.variants[((pick or 1) - 1) % n + 1].mesh
		-- (One not imported yet: the first that is.)
		if not Kit.template(meshName) then
			for _, other in entry.variants do
				if Kit.template(other.mesh) then
					meshName = other.mesh
					break
				end
			end
		end
	end
	local template = meshName and Kit.template(meshName)
	if not template then
		return nil
	end
	local at = entry.at or { 0, 0, 0 }
	local size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
	-- (Its front is the decor frame's LookVector: undo the half turn every
	-- piece gets, which faces a prop's front the other way.)
	local mesh = visual(template, size, cf * CFrame.new(at[1], at[2], -at[3]) * IMPORT_TURN)
	mesh.Name = "KitBody"
	mesh.CastShadow = entry.shadow ~= false
	local names = {}
	for _, name in entry.hide or {} do
		names[name] = true
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and names[part.Name] then
			hide(part)
		end
	end
	mesh.Parent = model
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
