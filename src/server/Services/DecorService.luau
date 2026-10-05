-- The house's dressing that isn't furniture (docs/ART.md, Hero props):
-- family portraits, wall clocks and radios, placed in wall and floor slots
-- each run. Moved out of the old anomaly service when the clue loop retired
-- (docs/plans/gameplay-rework.md, R2c); same builders, same seed forks and
-- draw order, so the same seed dresses the house the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local PropFactory = require(Shared.World.PropFactory)

local DecorService = {}

function DecorService:Init(services)
	self.services = services
	self.World = services.WorldService
	self:_reset()
end

function DecorService:_reset()
	self.portraits = {}
	self.decor = {}
	self.folder = nil
end

function DecorService:Start()
	self.World.Cleared:Connect(function()
		self:_reset()
	end)
end

-- Rooms in a seeded order, the start and the exit last out.
local function roomOrder(world, rng)
	local layout = world.layout
	local ids = {}
	for id in world.rooms do
		if id ~= layout.start and id ~= layout.exit then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	rng:Shuffle(ids)
	return ids
end

-- Dress the freshly built house. `rng` is the run's "anomaly" fork (the
-- name it has always had, so placements don't move between builds).
function DecorService:Begin(rng)
	self:_reset()
	local world = self.World.World
	self.folder = Instance.new("Folder")
	self.folder.Name = "Decor"
	self.folder.Parent = self.World.content
	local rooms = roomOrder(world, rng:Fork("rooms"))
	self:_placePortraits(rng:Fork("portraits"), rooms)
	self:_placeDecor(rng:Fork("decor"), rooms)
end

-- Three family portraits; the Guest can look out of them for one Witness
-- (Logic/Atmosphere's portrait eyes).
function DecorService:_placePortraits(rng, rooms)
	local count = 0
	for _, roomId in rooms do
		if count >= 3 then
			break
		end
		local slot = self.World:TakeWallSlot(roomId, rng)
		if slot then
			count += 1
			local model = PropFactory.buildTellBase("Portrait", slot.cframe, self.folder)
			model.Name = "Portrait"
			-- Its id, so a Witness's own copy can find its eyes.
			model:SetAttribute(Constants.Attributes.CId, "portrait:" .. count)
			table.insert(self.portraits, {
				id = "portrait:" .. count,
				model = model,
				cframe = slot.cframe,
				position = slot.cframe.Position + slot.cframe.LookVector * 0.4,
				roomId = roomId,
			})
		end
	end
end

-- Wall clocks in free wall slots and radios in free floor slots of living
-- rooms and bedrooms.
function DecorService:_placeDecor(rng, rooms)
	local clocks = 0
	for _, roomId in rooms do
		if clocks >= Config.Props.DecorClocks then
			break
		end
		local slot = self.World:TakeWallSlot(roomId, rng)
		if slot then
			clocks += 1
			local model = PropFactory.buildTellBase("Clock", slot.cframe, self.folder, PropFactory.decorClockTime(rng))
			model:SetAttribute(Constants.Attributes.CId, "decor:clock:" .. clocks)
			table.insert(self.decor, model)
		end
	end
	local world = self.World.World
	local radios = 0
	for _, roomId in rooms do
		if radios >= Config.Props.DecorRadios then
			break
		end
		local family = world.rooms[roomId].template.family
		if family == "living" or family == "bedroom" then
			local slot = self.World:TakeFloorSlot(roomId, rng)
			if slot then
				radios += 1
				local model = PropFactory.buildTellBase("Radio", slot.cframe, self.folder)
				model:SetAttribute(Constants.Attributes.CId, "decor:radio:" .. radios)
				table.insert(self.decor, model)
			end
		end
	end
end

function DecorService:Portraits()
	return self.portraits
end

return DecorService
