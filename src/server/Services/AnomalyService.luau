-- Picks the run's anomaly, plants its evidence (true tells and red herrings)
-- around the house, prepares its Source, and runs its resolution ritual
-- (doc section 4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Anomalies = require(Shared.Data.Anomalies)
local Tells = require(Shared.Data.Tells)
local Locations = require(Shared.Data.Locations)
local EvidencePlanner = require(Shared.Logic.EvidencePlanner)
local PropFactory = require(Shared.World.PropFactory)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Net)

local Rituals = script.Parent.Parent:WaitForChild("Rituals")

local AnomalyService = {
	RitualCompleted = Signal.new(),
}

local LABELS = {
	Clock = "Clock",
	Note = "Pinned note",
	Nametag = "Name badge",
	KeyTag = "Key on a hook",
	Fusebox = "Fuse box",
	Corkboard = "Pinned map",
	TapeMark = "Height marks",
	Window = "Window",
	Lamp = "Lamp",
	ScaleChair = "Chair",
	Chair = "Chair",
	Mannequin = "Dress form",
	Radio = "Radio",
	Portrait = "Portrait",
	WallMarker = "Bare wall",
}

-- Which base prop (if any) the server builds for a tell.
local function baseModelFor(tell): string?
	local p = tell.presentation
	if p == "VariantProp" then
		return tell.model
	elseif p == "PhantomSound" then
		return tell.baseModel
	elseif p == "PortraitEyes" then
		return "Portrait"
	elseif p == "HiddenWriting" then
		return "WallMarker"
	elseif p == "UnobservedShift" then
		return "Chair"
	end
	return nil
end

function AnomalyService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Witness = services.WitnessService
	self.CaseBoard = services.CaseBoardService
	self.Divergence = services.DivergenceService
	self:_reset()
end

function AnomalyService:_reset()
	self.anomaly = nil
	self.sites = {}
	self.siteByTarget = {}
	self.portraits = {}
	self.source = nil
	self.ritualModule = nil
	self.ritual = nil
	self.folder = nil
end

function AnomalyService:Start()
	self.Witness.Anchored:Connect(function(id, _, names)
		local site = self.siteByTarget[id]
		if site then
			self.CaseBoard:Resolve(site, names, false)
		end
	end)
	self.Witness.SoloWitnessed:Connect(function(player, id)
		local site = self.siteByTarget[id]
		if site then
			self.CaseBoard:Claim(site, player)
		end
	end)
	self.World.Cleared:Connect(function()
		if self.ritual then
			self.ritual:Destroy()
		end
		self:_reset()
	end)
end

function AnomalyService:Anomaly()
	return self.anomaly
end

-- Choose an anomaly the location supports and that has a ritual.
function AnomalyService:Choose(locationId: string, rng, forced: string?)
	if forced and Anomalies.ById[forced] and Anomalies.ById[forced].implemented then
		return Anomalies.ById[forced]
	end
	local location = Locations.ById[locationId]
	local pool = {}
	for _, id in location.anomalies do
		local anomaly = Anomalies.ById[id]
		if anomaly and anomaly.implemented and Rituals:FindFirstChild(id) then
			table.insert(pool, anomaly)
		end
	end
	return rng:Pick(pool)
end

-- Rooms ordered for spreading evidence: far rooms first, start/exit last.
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

function AnomalyService:_placeSite(index: number, tellId: string, isRedHerring: boolean, rooms, rng, usedRooms)
	local tell = Tells[tellId]
	local world = self.World.World
	local reserved = {}
	for _, seamId in self.reservedSeams or {} do
		reserved[seamId] = true
	end
	-- Prefer rooms with no evidence yet.
	local ordered = {}
	for _, id in rooms do
		if not usedRooms[id] then
			table.insert(ordered, id)
		end
	end
	for _, id in rooms do
		if usedRooms[id] then
			table.insert(ordered, id)
		end
	end
	for _, roomId in ordered do
		local room = world.rooms[roomId]
		local site = {
			id = "tell:" .. index,
			tellId = tellId,
			isRedHerring = isRedHerring,
			roomId = roomId,
			roomName = room.name,
		}
		if tell.slot == "seam" then
			local candidates = {}
			for _, dir in { "N", "E", "S", "W" } do
				local seam = room.sides[dir].seam
				if seam and not reserved[seam.id] and not self.siteByTarget[seam.id] then
					table.insert(candidates, seam)
				end
			end
			table.sort(candidates, function(a, b)
				if a.connected ~= b.connected then
					return not a.connected -- solid walls first: a phantom door is the clearer tell
				end
				return a.id < b.id
			end)
			local seam = candidates[1]
			if seam then
				site.seamId = seam.id
				site.connected = seam.connected
				site.position = seam.position
				site.target = seam.id
				usedRooms[roomId] = true
				return site
			end
		elseif tell.slot == "wall" then
			local slot = self.World:TakeWallSlot(roomId, rng)
			if slot then
				site.cframe = slot.cframe
				site.position = slot.cframe.Position + slot.cframe.LookVector * 0.5
				site.target = site.id
				usedRooms[roomId] = true
				return site
			end
		else
			local slot = self.World:TakeFloorSlot(roomId, rng)
			if slot then
				site.cframe = slot.cframe
				site.position = slot.position + Vector3.new(0, 2.5, 0)
				site.target = site.id
				usedRooms[roomId] = true
				return site
			end
		end
	end
	return nil
end

-- Decorative portraits: atmosphere for every run, and the pool Gaze picks
-- its Source from, so a portrait on the wall never gives the answer away.
function AnomalyService:_placePortraits(rng, rooms)
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

-- Set everything up for a run. ctx = { players, rng, locationId, forced, squadSize }
function AnomalyService:Setup(ctx)
	self:_reset()
	local world = self.World.World
	local rng = ctx.rng
	self.folder = Instance.new("Folder")
	self.folder.Name = "Anomaly"
	self.folder.Parent = self.World.folder

	local anomaly = self:Choose(ctx.locationId, rng:Fork("anomaly"), ctx.forced)
	self.anomaly = anomaly
	self.ritualModule = require(Rituals:WaitForChild(anomaly.id))
	local rooms = roomOrder(world, rng:Fork("rooms"))

	self:_placePortraits(rng:Fork("portraits"), rooms)

	-- The anomaly reserves what its ritual needs before evidence is placed.
	local ritualCtx = self:RitualContext(ctx)
	self.source = self.ritualModule.prepare(ritualCtx)
	self.reservedSeams = self.source.reservedSeams
	self.Divergence:ReserveSeams(self.source.reservedSeams or {})

	local plan = EvidencePlanner.plan(anomaly, Anomalies.List, Tells, rng:Fork("evidence"), {
		trueTells = Config.Evidence.TrueTells,
		redHerrings = ctx.difficulty.RedHerrings,
		maxSuspects = Config.Evidence.MaxSuspectsAfterThree,
		squadSize = ctx.squadSize,
	})
	self.plan = plan

	local usedRooms = {}
	local index = 0
	local placeRng = rng:Fork("placement")
	local all = {}
	for _, id in plan.trueTells do
		table.insert(all, { id = id, herring = false })
	end
	for _, id in plan.redHerrings do
		table.insert(all, { id = id, herring = true })
	end
	for _, entry in all do
		index += 1
		local site = self:_placeSite(index, entry.id, entry.herring, rooms, placeRng, usedRooms)
		if site then
			table.insert(self.sites, site)
			self.siteByTarget[site.target] = site
		else
			warn("[Consensus] no room for tell " .. entry.id)
		end
	end

	-- Perception profiles decide each site's true state (for variant props).
	local perception = self.Divergence:Plan(ctx.players, self.sites, rng:Fork("perception"))

	for _, site in self.sites do
		local tell = Tells[site.tellId]
		local baseModel = baseModelFor(tell)
		if baseModel and site.cframe then
			site.model = PropFactory.buildTellBase(baseModel, site.cframe, self.folder, perception.truths[site.id])
			site.model:SetAttribute(Constants.Attributes.CId, site.id)
		elseif site.cframe then
			site.model = PropFactory.buildTellBase("Marker", site.cframe, self.folder)
			site.model:SetAttribute(Constants.Attributes.CId, site.id)
		end
		site.truth = perception.truths[site.id]
		if not site.seamId then
			self.Witness:Register(site.id, {
				kind = "tell",
				position = site.position,
				label = baseModel and LABELS[baseModel] or "This spot",
				radius = 5,
				divergent = true,
			})
		else
			self.Witness:MarkDivergent(site.seamId)
		end
	end

	-- Stalker twist for Phantom Architecture.
	self.World:SetStalkerUsesSeams(anomaly.id == "PhantomArchitecture")

	local summary = {}
	for _, site in self.sites do
		table.insert(summary, (site.isRedHerring and "~" or "") .. site.tellId .. "@" .. site.roomId)
	end
	print(string.format("[Consensus] anomaly %s, evidence: %s", anomaly.id, table.concat(summary, ", ")))
	return anomaly
end

function AnomalyService:RitualContext(ctx)
	return {
		services = self.services,
		rng = ctx.rng:Fork("ritual"),
		players = ctx.players,
		folder = self.folder,
		anomaly = self.anomaly,
		portraits = self.portraits,
	}
end

function AnomalyService:SourcePosition(): Vector3?
	return self.source and self.source.position
end

function AnomalyService:Sites()
	return self.sites
end

function AnomalyService:SiteForTarget(id: string)
	return self.siteByTarget[id]
end

-- Witness Camera: the true state of one object. Returns a short caption.
function AnomalyService:Photograph(player: Player, entry): string
	local site = self.siteByTarget[entry.id]
	if site then
		local status = self.CaseBoard:Resolve(site, { player.DisplayName .. " (photo)" }, true)
		if status == "confirmed" then
			return "The photo shows it plainly: " .. Tells[site.tellId].name .. "."
		end
		return "In the photo there's nothing wrong here at all."
	end
	if self.ritual and self.ritual.Photograph then
		local caption = self.ritual:Photograph(player, entry)
		if caption then
			return caption
		end
	end
	if entry.kind == "seam" then
		local seam = self.World.World.seams[entry.id]
		return seam.connected and "The photo shows an open doorway." or "The photo shows solid wall."
	elseif entry.kind == "divergence" then
		return "In the photo, it isn't there. Or isn't like that."
	elseif entry.kind == "stalker" then
		return "The photo is a blur of grain. Something tall was there."
	end
	return "The photo shows exactly what you see."
end

-- Ritual lifecycle -------------------------------------------------------------

function AnomalyService:StartRitual(players: { Player }, rng)
	local ctx = self:RitualContext({ players = players, rng = rng })
	self.ritual = self.ritualModule.new(ctx, self.source)
	self.ritual.Completed:Connect(function()
		ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualProgress, 1)
		ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualText, "The Source is closed.")
		self.RitualCompleted:Fire()
	end)
	ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualProgress, 0)
	ReplicatedStorage.RunState:SetAttribute(
		Constants.RunState.RitualText,
		self.anomaly.ritual.name .. ": " .. self.anomaly.ritual.summary
	)
	Net.get("Notify"):FireAllClients(self.anomaly.ritual.name .. " — " .. self.anomaly.ritual.summary, "ritual")
	self.ritual:Start()
end

function AnomalyService:UpdateRitual(dt: number)
	if self.ritual and not self.ritual.done then
		self.ritual:Update(dt)
		ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualProgress, self.ritual.progress or 0)
		if self.ritual.text then
			ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualText, self.ritual.text)
		end
	end
end

function AnomalyService:StopRitual()
	if self.ritual then
		self.ritual:Destroy()
		self.ritual = nil
	end
	ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualProgress, nil)
	ReplicatedStorage.RunState:SetAttribute(Constants.RunState.RitualText, nil)
end

function AnomalyService:RitualActive(): boolean
	return self.ritual ~= nil and not self.ritual.done
end

function AnomalyService:HandleRitualAction(player: Player, payload)
	if self.ritual and self.ritual.HandleAction then
		self.ritual:HandleAction(player, payload)
	end
end

-- Sync a late-loading client with ritual visuals.
function AnomalyService:SyncPlayer(player: Player)
	if self.ritual and self.ritual.SyncPlayer then
		self.ritual:SyncPlayer(player)
	end
end

return AnomalyService
