-- Phantom Architecture — "Triangulate" (doc section 4).
--
-- Three seams in turn are the Source. During each stage the Source seam
-- flickers for every Witness, but each Witness also sees two flickering seams
-- that are theirs alone. The squad has to compare notes and Witness the same
-- seam together: every active Witness within an 8-second window. Three
-- closed seams resolve the anomaly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)

local STAGES = 3
local DECOYS_PER_PLAYER = 2

local Ritual = {}
Ritual.__index = Ritual

function Ritual.prepare(ctx)
	local world = ctx.services.WorldService.World
	local rng = ctx.rng:Fork("triangulate")
	local layout = world.layout
	local candidates = {}
	for id, seam in world.seams do
		if seam.a ~= layout.start and seam.b ~= layout.start then
			table.insert(candidates, { id = id, seam = seam })
		end
	end
	table.sort(candidates, function(a, b)
		return a.id < b.id
	end)
	rng:Shuffle(candidates)
	-- Solid walls first (a seam that shouldn't be a doorway), distinct rooms.
	table.sort(candidates, function(a, b)
		return (a.seam.connected and 1 or 0) < (b.seam.connected and 1 or 0)
	end)
	local chosen, usedRooms = {}, {}
	for _, c in candidates do
		if #chosen >= STAGES then
			break
		end
		if not usedRooms[c.seam.a] and not usedRooms[c.seam.b] then
			table.insert(chosen, c.id)
			usedRooms[c.seam.a] = true
			usedRooms[c.seam.b] = true
		end
	end
	for _, c in candidates do
		if #chosen >= STAGES then
			break
		end
		if not table.find(chosen, c.id) then
			table.insert(chosen, c.id)
		end
	end
	return {
		position = world.seams[chosen[1]].position,
		seams = chosen,
		reservedSeams = chosen,
	}
end

function Ritual.new(ctx, source)
	local self = setmetatable({
		ctx = ctx,
		source = source,
		stage = 0,
		progress = 0,
		text = nil,
		done = false,
		Completed = Signal.new(),
		decoys = {}, -- player -> { seamIds }
		overridden = {}, -- seamId -> previous entry fields
		connections = {},
	}, Ritual)
	return self
end

function Ritual:_services()
	return self.ctx.services
end

function Ritual:_required(): number
	local services = self:_services()
	local count = #services.PlayerStateService:ActivePlayers()
	if services.CompanionService and services.CompanionService:IsPresent() then
		count += 1
	end
	return math.max(1, count)
end

-- Make a seam need every active Witness, with a longer window.
function Ritual:_override(seamId: string)
	local entry = self:_services().WitnessService:Entry(seamId)
	if not entry or self.overridden[seamId] then
		return
	end
	self.overridden[seamId] =
		{ required = entry.required, windowSeconds = entry.windowSeconds, reanchor = entry.reanchor }
	entry.required = function()
		return self:_required()
	end
	entry.windowSeconds = 8
	entry.reanchor = true
end

function Ritual:_restoreAll()
	local witness = self:_services().WitnessService
	for seamId, previous in self.overridden do
		local entry = witness:Entry(seamId)
		if entry then
			entry.required = previous.required
			entry.windowSeconds = previous.windowSeconds
			entry.reanchor = previous.reanchor
		end
	end
	self.overridden = {}
end

function Ritual:_sendFlickers(player: Player)
	local seamId = self.source.seams[self.stage]
	local list = { seamId }
	for _, id in self.decoys[player] or {} do
		table.insert(list, id)
	end
	-- Shuffle per player so the Source isn't always first in the list.
	self.ctx.rng:Shuffle(list)
	Net.get("RitualState"):FireClient(player, {
		anomaly = "PhantomArchitecture",
		flickers = list,
		stage = self.stage,
		stages = STAGES,
	})
end

function Ritual:_beginStage()
	self.stage += 1
	local world = self:_services().WorldService.World
	local seamId = self.source.seams[self.stage]
	self:_override(seamId)
	local pool = {}
	for id in world.seams do
		if not table.find(self.source.seams, id) then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	self.decoys = {}
	for _, player in self.ctx.players do
		local decoys = self.ctx.rng:Sample(pool, DECOYS_PER_PLAYER)
		self.decoys[player] = decoys
		for _, id in decoys do
			self:_override(id)
		end
		if player.Parent then
			self:_sendFlickers(player)
		end
	end
	self.text = string.format(
		"Triangulate %d/%d: Witness the flickering seam everyone can see, together. Some flickers are yours alone.",
		self.stage,
		STAGES
	)
end

function Ritual:Start()
	local witness = self:_services().WitnessService
	table.insert(
		self.connections,
		witness.Anchored:Connect(function(id)
			if self.done then
				return
			end
			if id == self.source.seams[self.stage] then
				self:_services().DriftService:Apply("RitualStage")
				Net.get("Notify"):FireAllClients(string.format("Seam %d closed.", self.stage), "good")
				self.progress = self.stage / STAGES
				if self.stage >= STAGES then
					self:_finish()
				else
					self:_beginStage()
				end
			else
				for _, decoys in self.decoys do
					if table.find(decoys, id) then
						Net.get("Notify")
							:FireAllClients("Nothing happens. That seam was only flickering for one of you.", "warning")
						break
					end
				end
			end
		end)
	)
	self:_beginStage()
end

function Ritual:_finish()
	self.done = true
	self.progress = 1
	self.text = "The house's walls settle into place."
	for _, player in self.ctx.players do
		if player.Parent then
			Net.get("RitualState"):FireClient(player, { anomaly = "PhantomArchitecture", flickers = {}, done = true })
		end
	end
	self:_restoreAll()
	self.Completed:Fire()
end

function Ritual:Update() end

function Ritual:SyncPlayer(player: Player)
	if not self.done and self.stage > 0 then
		self:_sendFlickers(player)
	end
end

function Ritual:Photograph(_, entry)
	if entry.id == self.source.seams[self.stage] then
		return "In the photo, this seam glows white. It's the real one."
	end
	for _, decoys in self.decoys do
		if table.find(decoys, entry.id) then
			return "In the photo this seam is just wall."
		end
	end
	return nil
end

function Ritual:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self:_restoreAll()
end

return Ritual
