-- The Director (doc section 5): reads Drift, the run's act, time since the
-- last hunt and squad stress, sets the stalker's target tier and schedules
-- hunts, and plays the scare deck between them so the run has peaks and
-- valleys.
--
-- Progress wakes hunts (docs/plans/gameplay-rework.md, R2c "pacing"): a newly
-- entered part of the house, a new act or the first heirloom found arms one
-- (Arm), and it comes a minute or two later (Config.Pacing.ArmDelay),
-- wherever the squad has got to. So a good squad meets him at the moments
-- that matter, not only a squad that stalls into high Drift.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Acts = require(Shared.Logic.Acts)
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
		-- Its own fork, so waking a hunt never shifts the scare deck's draws.
		armRng = rng:Fork("arm"),
		difficulty = difficulty,
		deck = ScareDeck.new(CARDS, rng:Fork("deck"), 75),
		nextScare = os.clock() + 25,
		lastHuntEnded = nil,
		retreatUntil = nil,
		forced = false,
		armedAt = nil,
		armedRooms = nil,
		armedReason = nil,
		act = 1,
		lanternHeld = false,
		lastDecision = nil,
	}, Director)
end

function Director:ForceHunt()
	self.forced = true
end

-- Progress woke a hunt: it comes ArmDelay from now. `rooms` (a set) is where
-- the squad went, for him to head towards meanwhile. One at a time: arming
-- again keeps whichever is sooner. Returns the seconds until it's due.
function Director:Arm(reason: string, rooms: { [number]: boolean }?): number?
	if self.disarmed then
		return nil
	end
	local now = os.clock()
	local delay = self.armRng:NextNumber(Config.Pacing.ArmDelay[1], Config.Pacing.ArmDelay[2])
	if self.armedAt == nil or now + delay < self.armedAt then
		self.armedAt = now + delay
		self.armedReason = reason
		self.armedRooms = rooms
	end
	return self.armedAt - now
end

-- F2 `arm`: wake one now, due in `seconds`.
function Director:ArmIn(seconds: number)
	self.disarmed = false
	self.armedAt = os.clock() + seconds
	self.armedReason = "debug"
	self.armedRooms = nil
end

-- No more woken hunts (the dinner; while he waits at the table).
function Director:Disarm(forGood: boolean?)
	self.armedAt, self.armedRooms, self.armedReason = nil, nil, nil
	if forGood then
		self.disarmed = true
	end
end

-- A hunt has begun: whatever woke it is spent. `reason` is what woke it, for
-- the run's numbers (Logic/RunStats).
function Director:HuntBegan(reason: string?)
	self.services.RunLogService:Hunt(true, reason)
	self.forced = false
	self.armedAt, self.armedRooms, self.armedReason = nil, nil, nil
	self.lanternHeld = false
end

-- `how`: "survived", "stared down", "escaped" or "lost" (Logic/RunStats).
function Director:HuntEnded(now: number, how: string?)
	self.services.RunLogService:Hunt(false, how or "survived")
	self.lastHuntEnded = now
	self.retreatUntil = now + Config.Stalker.RetreatTierSeconds
	self.forced = false
end

-- How far the squad has got, from the services that know (Logic/Acts facts).
function Director:Facts()
	local services = self.services
	local facts = { gates = 0, gatesOpened = 0, heirlooms = 0, heirloomsFound = 0, places = 0, placesSet = 0 }
	local locks = services.LockService
	for _, entry in locks and locks.locks or {} do
		local kind = entry.lock.kind
		if kind ~= "bolt" and kind ~= "seal" then
			facts.gates += 1
			if entry.open then
				facts.gatesOpened += 1
			end
		end
	end
	local plan = locks and locks.plan
	if plan then
		facts.heirlooms = #plan.finale.heirlooms
		for _, token in plan.finale.heirlooms do
			if services.ItemService.found[token] then
				facts.heirloomsFound += 1
			end
		end
	end
	local finale = services.FinaleService
	if finale then
		facts.places = #finale.places
		for _, place in finale.places do
			if place.token then
				facts.placesSet += 1
			end
		end
		facts.served = finale.served == true
	end
	return facts
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
	-- A new act wakes a hunt.
	local act = Acts.of(self:Facts(), Config.Pacing)
	if act > self.act then
		self.act = act
		self.services.RunLogService:Act(act)
		if act < 4 then
			self.services.StalkerService:HeardProgress(self:Arm("act " .. act))
		end
	end
	-- A woken hunt held off by a Lantern room waits a little more once the
	-- squad leaves it, so stepping out isn't stepping into a hunt.
	if self.lanternHeld and not squadInLantern and self.armedAt then
		local release = Config.Pacing.LanternRelease
		self.armedAt = math.max(self.armedAt, now + self.armRng:NextNumber(release[1], release[2]))
		self.lanternHeld = false
	end
	local decision = DirectorModel.evaluate({
		now = now,
		runTime = runTime,
		drift = services.DriftService:Value(),
		act = self.act,
		armedAt = self.armedAt,
		lastHuntEnded = self.lastHuntEnded,
		retreatUntil = self.retreatUntil,
		lastRevive = services.PlayerStateService.lastRevive,
		squadInLantern = squadInLantern,
		stationary = services.SquadProfileService:Signals().stationary,
		forced = self.forced,
		difficulty = self.difficulty,
	}, Config)
	if squadInLantern and self.armedAt and now >= self.armedAt then
		self.lanternHeld = true
	end
	self.lastDecision = decision
	return decision
end

-- How long the next hunt lasts (longer at higher Drift).
function Director:HuntDuration(): number
	return DirectorModel.huntDuration(self.services.DriftService:Value(), self.rng:NextNumber(-1, 1), Config)
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
