-- The grime layer (docs/ART.md, Materials): one shared set of decals, placed
-- from the seed so every player sees the same aging (rule 6: decay is shared).
--
--   * water stains on ceilings
--   * rust streaks under some windows and in utility rooms
--   * scuffs low on walls
--   * clean patches where a picture hung for years
--
-- Fairness first. Wall grime stays well clear of every seam, so it never hints
-- where a doorway might be (rule 3), and clear of wall slots and decor, so it's
-- never mistaken for a tell. Grime is never collidable, never hit by a ray
-- and never Witnessable. Corridors only get ceiling stains.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local PropFactory = require(Shared.World.PropFactory)

local G = Config.Grime

local HALF = Config.Level.CellSize / 2
local INNER = HALF - Config.Level.WallThickness
local HEIGHT = Config.Level.WallHeight
local UP = Vector3.new(0, 1, 0)

local DIRS = {
	N = Vector3.new(0, 0, -1),
	E = Vector3.new(1, 0, 0),
	S = Vector3.new(0, 0, 1),
	W = Vector3.new(-1, 0, 0),
}

local Grime = {}

-- An invisible card carrying one decal on its front face.
local function card(parent, name: string, cf: CFrame, width: number, height: number, texture: string, rng)
	local part = PropFactory.part(
		parent,
		name,
		Vector3.new(width, height, 0.02),
		cf,
		Color3.new(),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, query = false, castShadow = false, transparency = 1 }
	)
	local decal = Instance.new("Decal")
	decal.Texture = texture
	decal.Face = Enum.NormalId.Front
	decal.Transparency = rng:NextNumber(G.Fade[1], G.Fade[2])
	decal.Parent = part
	return part
end

-- A room's walls as grime sees them: its centre at floor level, and per side
-- the distance to the wall face (`inner`), half the face's length (`half`)
-- and where its doorways are along it (`openings`). A 40x40 cell has one
-- opening in the middle of each shared wall; the mansion builder gives its
-- rooms their own (`record.walls`).
local function wallsOf(record)
	if record.walls then
		return record.walls
	end
	local inner, half, openings = {}, {}, {}
	for side, info in record.sides do
		inner[side], half[side] = INNER, INNER
		openings[side] = (info.neighbour ~= nil or info.exit) and { 0 } or {}
	end
	return {
		center = record.center,
		inner = inner,
		half = half,
		openings = openings,
		radius = math.huge,
		ceiling = HEIGHT,
	}
end

-- A point on a wall face, `along` across it and `y` up, facing into the room.
local function onWall(walls, side: string, along: number, y: number): CFrame
	local dir = DIRS[side]
	local perp = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
	local pos = walls.center + dir * (walls.inner[side] - G.WallOffset) + perp * along + UP * y
	return CFrame.lookAt(pos, pos - dir)
end

-- Things wall grime must keep its distance from: wall slots (where tells go)
-- and decor such as paintings and windows.
local function keepClear(record)
	local points = {}
	for _, slot in record.wallSlots do
		table.insert(points, slot.cframe.Position)
	end
	for _, child in record.model:GetChildren() do
		if child:IsA("Model") and (child.Name == "Painting" or child.Name == "Window" or child.Name == "Mirror") then
			table.insert(points, child:GetPivot().Position)
		end
	end
	return points
end

-- A spot along a wall face for grime of this width, or nil: away from the
-- seam in the middle of a shared wall or the exit, and from anything in
-- `clear` on that face.
local function wallSpot(rng, walls, side: string, width: number, clear)
	local dir = DIRS[side]
	local reach = walls.half[side] - width / 2 - 1
	for _ = 1, 8 do
		local along = rng:NextNumber(-reach, reach)
		local ok = true
		for _, opening in walls.openings[side] do
			if math.abs(along - opening) - width / 2 < G.SeamClearance then
				ok = false
			end
		end
		if ok then
			local perp = Vector3.new(math.abs(dir.Z), 0, math.abs(dir.X))
			local spot = walls.center + dir * walls.inner[side] + perp * along
			for _, p in clear do
				local flat = Vector3.new(p.X - spot.X, 0, p.Z - spot.Z)
				-- Only things on this face count.
				if math.abs(flat:Dot(dir)) < 1 and math.abs(flat:Dot(perp)) - width / 2 < G.SlotClearance then
					ok = false
				end
			end
		end
		if ok then
			return along
		end
	end
	return nil
end

function Grime.build(world, rng)
	local textures = Assets.Grime
	for _, room in world.layout.rooms do
		local record = world.rooms[room.id]
		local model = record.model
		local family = record.template.family
		local walls = wallsOf(record)

		-- Ceiling water stains, clear of the light in the middle.
		if textures.WaterStain ~= "" and rng:Chance(G.CeilingStainChance) then
			local size = rng:NextNumber(G.CeilingStainSize[1], G.CeilingStainSize[2])
			local angle = rng:NextNumber(0, 2 * math.pi)
			local radius = rng:NextNumber(math.min(6, walls.radius), math.min(14, walls.radius))
			local pos = walls.center
				+ Vector3.new(math.cos(angle) * radius, walls.ceiling - G.CeilingOffset, math.sin(angle) * radius)
			local cf = CFrame.lookAt(pos, pos - UP) * CFrame.Angles(0, 0, rng:NextNumber(0, 2 * math.pi))
			card(model, "GrimeStain", cf, size, size, textures.WaterStain, rng)
		end

		if record.corridor then
			continue
		end
		local clear = keepClear(record)
		local sides = { "N", "E", "S", "W" }

		-- Blood, hidden until Drift reaches Breaking (EffectsController shows it).
		-- Tinted rust streaks, placed like the other wall grime so they never hint
		-- at a seam, a wall slot or a piece of decor.
		if textures.RustStreak ~= "" and rng:Chance(G.BloodChance) then
			local side = sides[rng:NextInteger(1, 4)]
			local along = wallSpot(rng, walls, side, 2.4, clear)
			if along then
				local size = rng:NextNumber(G.BloodSize[1], G.BloodSize[2])
				local blood = card(
					model,
					"GrimeBlood",
					onWall(walls, side, along, rng:NextNumber(2.8, 6)),
					size * 0.7,
					size * 1.5,
					textures.RustStreak,
					rng
				)
				local decal = blood:FindFirstChildOfClass("Decal")
				if decal then
					decal.Color3 = Color3.fromRGB(120, 14, 12)
					decal.Transparency = 1
				end
				blood:SetAttribute("BloodAt", rng:NextInteger(G.BloodAt[1], G.BloodAt[2]))
				CollectionService:AddTag(blood, Constants.Tags.Blood)
			end
		end

		-- Rust under some windows: from the sill down the wall.
		if textures.RustStreak ~= "" then
			for _, child in model:GetChildren() do
				if child.Name == "Window" and child:IsA("Model") and rng:Chance(G.RustUnderWindowChance) then
					local sill = child:FindFirstChild("Sill")
					local glass = child:FindFirstChild("Glass")
					if sill and glass then
						local pivot = glass.CFrame -- faces into the room
						local look = pivot.LookVector
						local base = sill.Position - look * (sill.Size.Z / 2) + look * G.WallOffset
						local height = rng:NextNumber(2.2, 3.2)
						local x = rng:NextNumber(-1.5, 1.5)
						local pos = base + pivot.RightVector * x - UP * (height / 2 + 0.1)
						card(
							model,
							"GrimeRust",
							CFrame.lookAt(pos, pos + look),
							rng:NextNumber(1.2, 1.8),
							height,
							textures.RustStreak,
							rng
						)
					end
				end
			end
			-- A pipe somewhere behind the wall has been leaking for years.
			if family == "utility" and rng:Chance(G.UtilityRustChance) then
				local side = sides[rng:NextInteger(1, 4)]
				local along = wallSpot(rng, walls, side, 2, clear)
				if along then
					local height = rng:NextNumber(3, 5)
					card(
						model,
						"GrimeRust",
						onWall(walls, side, along, HEIGHT - 0.6 - height / 2),
						rng:NextNumber(1.4, 2),
						height,
						textures.RustStreak,
						rng
					)
				end
			end
		end

		-- Scuffs low on the walls, above the baseboard.
		if textures.Scuffs ~= "" then
			for _ = 1, rng:NextInteger(G.Scuffs[1], G.Scuffs[2]) do
				local side = sides[rng:NextInteger(1, 4)]
				local width = rng:NextNumber(3, 5)
				local along = wallSpot(rng, walls, side, width, clear)
				if along then
					card(
						model,
						"GrimeScuffs",
						onWall(walls, side, along, rng:NextNumber(1.1, 1.8)),
						width,
						1.6,
						textures.Scuffs,
						rng
					)
				end
			end
		end

		-- Where a picture hung for years.
		if textures.PictureGhost ~= "" and rng:Chance(G.PictureGhostChance) then
			local side = sides[rng:NextInteger(1, 4)]
			local width = rng:NextNumber(2.6, 4)
			local along = wallSpot(rng, walls, side, width, clear)
			if along then
				card(
					model,
					"GrimeGhost",
					onWall(walls, side, along, rng:NextNumber(6, 7)),
					width,
					width * rng:NextNumber(1.1, 1.35),
					textures.PictureGhost,
					rng
				)
			end
		end
	end
end

return Grime
