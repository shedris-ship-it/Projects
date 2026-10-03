-- The Director (doc section 5): reads Drift, time since the last hunt and
-- squad stress, sets the stalker's target tier and schedules hunts, and
-- plays the scare deck between them so the run has peaks and valleys.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local DirectorModel = require(Shared.Logic.DirectorModel)
local ScareDeck = require(Shared.Logic.ScareDeck)

local Director = {}
Director.__index = Director

local CARDS = {
	{ id = "knock", weight = 3, cooldown = 40 },
	{ id = "distantSteps", weight = 3, cooldown = 30 },
	{ id = "flicker", weight = 3, cooldown = 20 },
	{ id = "coldSpot", weight = 2, cooldown = 60 },
	{ id = "doorSlam", weight = 1, cooldown = 70, minDrift = 30, big = true },
	{ id = "whisper", weight = 1, cooldown = 90, minDrift = 40, big = true },
	-- No phantom "figure" card (owner, 2026-10-03): the only Guest you see is
	-- the real one, always somewhere in the house. The one exception, chosen
	-- by the owner: early on, one Witness may see his face at a window while
	-- he's elsewhere. Something to argue about.
	{ id = "windowFace", weight = 1, cooldown = 120, minDrift = 5, big = true },
}

function Director.new(services, rng, difficulty)
	return setmetatable({
		services = services,
		rng = rng,
		difficulty = difficulty,
		deck = ScareDeck.new(CARDS, rng:Fork("deck"), 75),
		nextScare = os.clock() + 25,
		lastHuntEnded = nil,
		retreatUntil = nil,
		forced = false,
		lastDecision = nil,
	}, Director)
end

function Director:ForceHunt()
	self.forced = true
end

function Director:HuntEnded(now: number)
	self.lastHuntEnded = now
	self.retreatUntil = now + Config.Stalker.RetreatTierSeconds
	self.forced = false
end

-- One pacing decision. runTime is seconds since Arrival began.
function Director:Evaluate(runTime: number)
	local services = self.services
	local now = os.clock()
	local living = services.PlayerStateService:LivingPlayers()
	local squadInLantern = #living > 0
	for _, player in living do
		local pos = services.PlayerStateService:Position(player)
		if not pos or not services.WorldService:IsLanternRoom(services.WorldService:RoomAt(pos)) then
			squadInLantern = false
		end
	end
	local decision = DirectorModel.evaluate({
		now = now,
		runTime = runTime,
		drift = services.DriftService:Value(),
		lastHuntEnded = self.lastHuntEnded,
		retreatUntil = self.retreatUntil,
		lastRevive = services.PlayerStateService.lastRevive,
		squadInLantern = squadInLantern,
		stationary = services.SquadProfileService:Signals().stationary,
		forced = self.forced,
		difficulty = self.difficulty,
	}, Config)
	self.lastDecision = decision
	if decision.huntDue then
		self.forced = false
	end
	return decision
end

-- Draw a scare if one is due. Returns the card or nil.
function Director:MaybeScare(tier: number)
	local now = os.clock()
	if now < self.nextScare then
		return nil
	end
	local drift = self.services.DriftService:Value()
	-- Higher Drift, shorter gaps.
	local gap = 35 - drift * 0.2
	self.nextScare = now + self.rng:NextNumber(gap * 0.6, gap * 1.2)
	if tier <= 0 and drift < 5 then
		return nil
	end
	return self.deck:Draw(now, drift)
end

return Director
