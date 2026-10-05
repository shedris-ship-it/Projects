-- Divergence (doc sections 1 and 7, as reworked: docs/plans/
-- gameplay-rework.md section 2): the server sends each Witness a list of
-- perception rules, never world state, and each client applies its own rules
-- to its own copy of the house. Since the clue loop retired (R2c) the rules
-- are atmosphere only (Logic/Atmosphere): unsettling, never something to
-- solve, never on anything you play with. Also the channel for one-off
-- scares meant for a single Witness.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local AtmosphereData = require(Shared.Data.Atmosphere)
local Atmosphere = require(Shared.Logic.Atmosphere)

local DivergenceService = {}

-- Fixed furniture (Data/Physical lists everything you carry or push; these
-- stay put) that may take another colour for one Witness.
local RECOLOURABLE = {
	Counter = true,
	Sink = true,
	Toilet = true,
	Bathtub = true,
	Stove = true,
	WaterHeater = true,
	Curtain = true,
}

function DivergenceService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.profiles = {}
end

function DivergenceService:Start()
	self.World.Cleared:Connect(function()
		self.profiles = {}
		Net.get("PerceptionProfile"):FireAllClients({ rules = {} })
	end)
end

local function toTable(v: Vector3)
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Plan and send every Witness's atmosphere. Runs last in setup, so the wall
-- and floor spots it uses are the ones nothing else took (it never takes
-- them itself: its writing and sounds exist only on one client).
function DivergenceService:Begin(players: { Player }, rng)
	local world = self.World.World
	local ids = {}
	for _, player in players do
		table.insert(ids, tostring(player.UserId))
	end
	table.sort(ids)

	local portraits = {}
	for _, portrait in self.services.DecorService:Portraits() do
		table.insert(portraits, { id = portrait.id, position = toTable(portrait.position) })
	end
	local walls, floor, fixed = {}, {}, {}
	for _, roomId in self.World:RoomIds() do
		local room = world.rooms[roomId]
		for _, slot in room.wallSlots or {} do
			if not slot.used then
				table.insert(walls, {
					position = toTable(slot.cframe.Position + slot.cframe.LookVector * 0.5),
					normal = toTable(slot.cframe.LookVector),
				})
			end
		end
		for _, slot in room.floorSlots or {} do
			if not slot.used then
				table.insert(floor, { position = toTable(slot.position) })
			end
		end
	end
	for _, prop in world.props do
		if RECOLOURABLE[prop.kind] and not Physical.Furniture[prop.kind] and prop.model.Parent then
			table.insert(fixed, { id = prop.id })
		end
	end
	table.sort(fixed, function(a, b)
		return a.id < b.id
	end)

	local result = Atmosphere.plan({
		players = ids,
		portraits = portraits,
		walls = walls,
		fixed = fixed,
		floor = floor,
		content = AtmosphereData,
		config = Config.Atmosphere,
		rng = rng,
	})
	self.profiles = result.profiles
	for _, player in players do
		self:SendProfile(player)
	end
	return result
end

function DivergenceService:SendProfile(player: Player)
	local rules = self.profiles[tostring(player.UserId)] or {}
	Net.get("PerceptionProfile"):FireClient(player, { rules = rules })
end

-- One-off local scare for a single Witness (a knock only they hear, his face
-- at the window). Absent from server state by design.
function DivergenceService:Scare(player: Player, payload)
	Net.get("Scare"):FireClient(player, payload)
end

function DivergenceService:Reset()
	self.profiles = {}
end

return DivergenceService
