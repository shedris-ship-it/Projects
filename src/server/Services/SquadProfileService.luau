-- Watches the squad's habits for the stalker (doc section 5, "Adaptation")
-- and keeps the material for the end-of-run Dossier: favourite hiding
-- spots, loops, closest calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Graph = require(Shared.Logic.Graph)
local SquadProfile = require(Shared.Logic.SquadProfile)

local SquadProfileService = {}

function SquadProfileService:Init(services)
	self.services = services
	self.PlayerState = services.PlayerStateService
	self.World = services.WorldService
	self:Reset()
end

function SquadProfileService:Reset()
	self.profile = SquadProfile.new(Config.Stalker.ProfileHalfLife)
	self.rooms = {} -- player -> current room
	self.lastPositions = {}
	self.cycles = {}
	self.edgeCycles = {}
	self.closeCalls = {} -- player -> nearest distance during a hunt while uncaught
	self.catches = {} -- player -> count
	self.hideSpots = {} -- spotId -> { label, room, count }
end

function SquadProfileService:Start()
	self.World.Built:Connect(function(world)
		local ids = self.World:RoomIds()
		self.cycles = Graph.fundamentalCycles(self.World.adjacency, ids, world.layout.edges)
		self.edgeCycles = {}
		for index, cycle in self.cycles do
			for i = 1, #cycle do
				local a, b = cycle[i], cycle[i % #cycle + 1]
				local key = Graph.edgeKey(a, b)
				self.edgeCycles[key] = self.edgeCycles[key] or {}
				table.insert(self.edgeCycles[key], index)
			end
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 then
			self:_sample(accumulator)
			accumulator = 0
		end
	end)
end

function SquadProfileService:Now(): number
	return os.clock()
end

function SquadProfileService:Record(key: string, amount: number)
	self.profile:Add(key, amount, os.clock())
end

function SquadProfileService:RecordHide(spot, now: number)
	self.profile:Add("hides", 1, now)
	self.profile:AddTo("hide", spot.category, 1, now)
	local entry = self.hideSpots[spot.id]
		or { label = spot.label, roomId = spot.roomId, count = 0, category = spot.category }
	entry.count += 1
	self.hideSpots[spot.id] = entry
end

function SquadProfileService:RecordGaze(seconds: number)
	self.profile:Add("gazeSeconds", seconds, os.clock())
end

function SquadProfileService:RecordCloseCall(player: Player, distance: number)
	local current = self.closeCalls[player]
	if current == nil or distance < current then
		self.closeCalls[player] = distance
	end
end

function SquadProfileService:RecordCatch(player: Player)
	self.catches[player] = (self.catches[player] or 0) + 1
end

function SquadProfileService:Signals()
	return self.profile:Signals(os.clock())
end

function SquadProfileService:FavouriteHideCategory(): string?
	local ranked = self.profile:Ranked("hide", os.clock())
	return ranked[1] and ranked[1].key
end

-- Rooms ranked by how much the squad uses them.
function SquadProfileService:RoomsByUse(): { number }
	local ranked = self.profile:Ranked("route", os.clock())
	local list = {}
	for _, entry in ranked do
		table.insert(list, tonumber(entry.key))
	end
	return list
end

-- The loop the squad keeps running, as a list of room ids.
function SquadProfileService:FavouriteLoop(): { number }?
	local ranked = self.profile:Ranked("loop", os.clock())
	local top = ranked[1]
	if not top or top.weight < 1 then
		return nil
	end
	return self.cycles[tonumber(top.key)]
end

function SquadProfileService:_sample(dt: number)
	if not self.PlayerState.inRun then
		return
	end
	local now = os.clock()
	local living = self.PlayerState:LivingPlayers()
	local stalker = self.services.StalkerService
	local hunting = stalker and stalker:IsHunting()
	local positions = {}
	local flashlights = 0
	local moving = false
	for _, player in living do
		local pos = self.PlayerState:Position(player)
		if pos then
			positions[player] = pos
			local last = self.lastPositions[player]
			if last and (last - pos).Magnitude > 2 then
				moving = true
			end
			self.lastPositions[player] = pos
			local room = self.World:RoomAt(pos)
			local previous = self.rooms[player]
			if room and previous and room ~= previous then
				self.profile:AddTo("route", tostring(room), 1, now)
				for _, cycleIndex in self.edgeCycles[Graph.edgeKey(previous, room)] or {} do
					self.profile:AddTo("loop", tostring(cycleIndex), hunting and 1 or 0.3, now)
				end
			end
			if room then
				self.rooms[player] = room
			end
		end
		if self.PlayerState:FlashlightOn(player) then
			flashlights += 1
		end
	end

	-- Average pairwise spread.
	local list = {}
	for _, pos in positions do
		table.insert(list, pos)
	end
	if #list >= 2 then
		local total, count = 0, 0
		for i = 1, #list do
			for j = i + 1, #list do
				total += (list[i] - list[j]).Magnitude
				count += 1
			end
		end
		self.profile:Sample("spread", total / count, dt, 20)
	end
	if #living > 0 then
		self.profile:Sample("flashlight", flashlights / #living, dt, 30)
	end
	if not moving and #list > 0 then
		self.profile:Add("stationarySeconds", dt, now)
	end
end

-- The end-of-run Dossier (doc section 2, "Extraction and debrief").
function SquadProfileService:Dossier(extra)
	local now = os.clock()
	local hideRanking = self.profile:Ranked("hide", now)
	local spots = {}
	for _, entry in self.hideSpots do
		table.insert(spots, entry)
	end
	table.sort(spots, function(a, b)
		return a.count > b.count
	end)
	local favouriteSpot = spots[1]
	local closeCalls = {}
	for player, distance in self.closeCalls do
		if player.Parent then
			table.insert(closeCalls, { name = player.DisplayName, distance = math.floor(distance * 10) / 10 })
		end
	end
	table.sort(closeCalls, function(a, b)
		return a.distance < b.distance
	end)
	local catches = {}
	for player, count in self.catches do
		if player.Parent then
			table.insert(catches, { name = player.DisplayName, count = count })
		end
	end
	local signals = self.profile:Signals(now)
	local habits = {}
	if signals.cohesion > 0.6 then
		table.insert(habits, "You stuck together. It waited for someone to stray.")
	elseif signals.cohesion < 0.3 then
		table.insert(habits, "You split up. It noticed who was alone.")
	end
	if signals.flashlightHabit > 0.6 then
		table.insert(habits, "You leaned on your flashlights. It learned to wait outside the beam.")
	end
	if (self.profile.totals.anchors or 0) >= 5 then
		table.insert(habits, "You anchored often. It learned when your Focus ran low.")
	end
	if (self.profile.totals.pings or 0) >= 10 then
		table.insert(habits, "You pinged a lot. It learned to fake them.")
	end
	if hideRanking[1] then
		table.insert(habits, "Favourite hiding place: " .. hideRanking[1].key .. ".")
	end
	local loop = self:FavouriteLoop()
	if loop then
		local names = {}
		for _, id in loop do
			local room = self.World:Room(id)
			table.insert(names, room and room.name or tostring(id))
		end
		table.insert(habits, "You kept running the loop through " .. table.concat(names, ", ") .. ".")
	end
	if #habits == 0 then
		table.insert(habits, "It didn't learn much about you. Next time it will.")
	end
	local room = favouriteSpot and self.World:Room(favouriteSpot.roomId)
	return {
		favouriteSpot = favouriteSpot and string.format(
			"The %s in the %s (%d time%s)",
			string.lower(favouriteSpot.label),
			room and room.name or "house",
			favouriteSpot.count,
			favouriteSpot.count == 1 and "" or "s"
		) or nil,
		habits = habits,
		closeCalls = closeCalls,
		catches = catches,
		tactics = extra and extra.tactics or {},
		totals = {
			hides = self.profile.totals.hides or 0,
			anchors = self.profile.totals.anchors or 0,
			pings = self.profile.totals.pings or 0,
		},
	}
end

return SquadProfileService
