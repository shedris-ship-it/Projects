-- Landmarks at the house's corridors (docs/plans/level-design.md section 4,
-- L3.6): Logic/Landmarks says which corridor gets which; this hangs each on
-- a wall there (clear of any door's swing) and puts it on the map once
-- someone has been in its corridor (Services/MapService marks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Landmarks = require(Shared.Logic.Landmarks)
local Rooms = require(Shared.Data.Rooms)
local LandmarkProps = require(script.Parent.Parent.World.LandmarkProps)

local LandmarkService = {}

function LandmarkService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.placed = {} -- { room, kind, position }
end

function LandmarkService:Start()
	self.World.Cleared:Connect(function()
		table.clear(self.placed)
	end)
end

function LandmarkService:Begin(rng)
	local world = self.World.World
	if not world then
		return
	end
	local function clear(at: Vector3): boolean
		for _, door in world.doors do
			local hinge = door.hinge
			if
				hinge
				and math.abs(hinge.Y - at.Y) < 6
				and (Vector3.new(hinge.X, at.Y, hinge.Z) - at).Magnitude < Config.BellBoard.DoorClear
			then
				return false
			end
		end
		return true
	end
	local map = self.services.MapService
	for _, entry in Landmarks.plan(world.layout, Rooms.MansionById) do
		-- A wall spot of its own (a corridor's picture spots are mostly taken
		-- by its doorways), else a picture's.
		local cf = self:_wallSpot(entry.room)
		local slot = nil
		if not cf then
			for _ = 1, 6 do
				local try = self.World:TakeWallSlot(entry.room, rng)
				if not try then
					break
				end
				slot = slot or try
				if clear(try.cframe.Position) then
					slot = try
					break
				end
			end
			-- Its back to the wall, a little lower than a picture's centre.
			cf = slot and slot.cframe * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, -0.6, 0)
		end
		if cf then
			local family = world.layout.family
			local model =
				LandmarkProps.build(entry.kind.id, cf, self.World.content, { surname = family and family.surname })
			if model then
				local position = model:GetBoundingBox().Position
				table.insert(self.placed, { room = entry.room, kind = entry.kind, position = position })
				if map then
					-- On the map once someone has been in its corridor.
					map:Mark("landmark:" .. entry.room, {
						kind = "landmark",
						position = position,
						label = entry.kind.name,
						room = entry.room,
					})
				end
			end
		end
	end
end

-- The spot on the room's inner walls farthest from any of its doorways (and
-- so from any door's swing), at about eye height, its front (+Z) into the
-- room; nil with none at least `Config.Landmarks.Clear` studs from them all.
function LandmarkService:_wallSpot(roomId: number): CFrame?
	local world = self.World.World
	local room = self.World:Room(roomId)
	local rect = room and room.rect
	if not rect then
		return nil
	end
	local o = Config.Level.Origin
	local wall = Config.Level.WallThickness
	local cx, cz = o.x + rect.x + rect.w / 2, o.z + rect.z + rect.d / 2
	local hx, hz = rect.w / 2 - wall, rect.d / 2 - wall
	local floorY = self.World:FloorBase(room.center.Y)
	local storey = room.floor or 0
	local doorways = {}
	for _, seam in world.seams do
		if seam.connected and (seam.a == roomId or seam.b == roomId) and (seam.floor or 0) == storey then
			table.insert(doorways, seam.floorPosition)
		end
	end
	-- Each wall: a point on it, the way along it, its half length, and the
	-- way into the room.
	local walls = {
		{ Vector3.new(cx, 0, cz - hz), Vector3.xAxis, hx, Vector3.zAxis },
		{ Vector3.new(cx, 0, cz + hz), Vector3.xAxis, hx, -Vector3.zAxis },
		{ Vector3.new(cx - hx, 0, cz), Vector3.zAxis, hz, Vector3.xAxis },
		{ Vector3.new(cx + hx, 0, cz), Vector3.zAxis, hz, -Vector3.xAxis },
	}
	local spots = {}
	for _, w in walls do
		local t = -w[3] + 1.6
		while t <= w[3] - 1.6 do
			local at = w[1] + w[2] * t
			local score = math.huge
			for _, d in doorways do
				score = math.min(score, (Vector3.new(d.X, 0, d.Z) - at).Magnitude)
			end
			if score >= Config.Landmarks.Clear then
				table.insert(spots, { at = at, into = w[4], along = w[2], score = score })
			end
			t += 1
		end
	end
	table.sort(spots, function(a, b)
		return a.score > b.score
	end)
	-- The best spot with nothing already against the wall there: a walk-in
	-- closet, a wardrobe, a window, a picture, a sconce, a switch (the
	-- progression audit's clip scan, 2026-10-10: a landmark through a
	-- corridor closet's back).
	local blockers = self:_wallThings(roomId)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = blockers
	local L = Config.Landmarks
	for _, spot in spots do
		local at = Vector3.new(spot.at.X, floorY + L.Height, spot.at.Z)
		local box = CFrame.lookAt(at + spot.into * L.Footprint[3] / 2, at + spot.into * 2)
		if
			#blockers == 0
			or #Workspace:GetPartBoundsInBox(
					box,
					Vector3.new(L.Footprint[1], L.Footprint[2], L.Footprint[3]),
					params
				)
				== 0
		then
			-- (Looking into the wall: its +Z is the way into the room.)
			return CFrame.lookAt(at, at - spot.into)
		end
	end
	return nil
end

-- What stands against a room's walls: its furniture, windows, pictures and
-- sconces, and the house's light switches.
function LandmarkService:_wallThings(roomId: number): { Instance }
	local world = self.World.World
	local record = world.rooms and world.rooms[roomId]
	local list = {}
	if record then
		for _, prop in record.props or {} do
			if prop.model and prop.model.Parent then
				table.insert(list, prop.model)
			end
		end
		for _, painting in record.paintings or {} do
			if painting.model and painting.model.Parent then
				table.insert(list, painting.model)
			end
		end
		for _, window in record.windows or {} do
			if window.glass and window.glass.Parent then
				table.insert(list, window.glass.Parent)
			end
		end
		for _, child in record.model and record.model:GetChildren() or {} do
			if child.Name == "Sconce" or child.Name == "Window" then
				table.insert(list, child)
			end
		end
	end
	local fixtures = self.World.content and self.World.content:FindFirstChild("Fixtures")
	if fixtures then
		table.insert(list, fixtures)
	end
	return list
end

function LandmarkService:Describe(): string
	local lines = {}
	for _, entry in self.placed do
		table.insert(lines, string.format("%s in room %d", entry.kind.name, entry.room))
	end
	return #lines > 0 and table.concat(lines, "; ") or "no landmarks this run"
end

return LandmarkService
