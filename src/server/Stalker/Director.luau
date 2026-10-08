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
	-- The house's own scares (Services/HouseEventService), by act: the deeper
	-- the squad goes, the more the house does. minDrift is a Dread threshold.
	{ id = "doorAjar", weight = 2, cooldown = 45, house = true },
	{ id = "radioOn", weight = 2, cooldown = 90, minDrift = 10, house = true },
	{ id = "overhead", weight = 2, cooldown = 50, minAct = 2, house = true },
	{ id = "knockInside", weight = 2, cooldown = 80, minAct = 2, house = true },
	{ id = "lightsDie", weight = 2, cooldown = 110, minAct = 2, big = true, house = true },
	{ id = "phoneRings", weight = 1, cooldown = 150, minAct = 2, big = true, house = true },
	{ id = "clockStrikes", weight = 1, cooldown = 60, minAct = 3, big = true, once = true, house = true },
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
		armedFalse = false, -- the woken hunt is only its telegraph
		armedUrgent = false, -- it waits for no gap (he comes straight back)
		nextGap = Config.Pacing.MinHuntGap, -- drawn afresh after every hunt
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
	local pacing = Config.Pacing
	local delay = self.armRng:NextNumber(pacing.ArmDelay[1], pacing.ArmDelay[2])
	-- Sometimes only the telegraph comes (the real hunt follows soon after).
	local falseAlarm = self.armRng:NextNumber() < (pacing.FalseAlarmChance or 0)
	if self.armedAt == nil or now + delay < self.armedAt then
		self.armedAt = now + delay
		self.armedReason = reason
		self.armedRooms = rooms
		self.armedFalse = falseAlarm
		self.armedUrgent = false
	end
	return self.armedAt - now
end

-- The telegraph came to nothing (StalkerService): the real hunt follows,
-- sooner than a fresh arming would.
function Director:FalseAlarmDone(now: number)
	self.services.RunLogService:FalseAlarm()
	local follow = Config.Pacing.FalseAlarmFollow
	self.armedAt = now + self.armRng:NextNumber(follow[1], follow[2])
	self.armedReason = "after a false alarm"
	self.armedFalse = false
	self.armedUrgent = false
end

-- F2 `arm`: wake one now, due in `seconds`.
function Director:ArmIn(seconds: number, falseAlarm: boolean?)
	self.disarmed = false
	self.armedAt = os.clock() + seconds
	self.armedReason = "debug"
	self.armedRooms = nil
	self.armedFalse = falseAlarm == true
	self.armedUrgent = true
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
	self.armedFalse, self.armedUrgent = false, false
	self.lanternHeld = false
end

-- `how`: "survived", "stared down", "escaped" or "lost" (Logic/RunStats).
-- The gap before the next woken hunt is drawn afresh, and sometimes he comes
-- straight back (Config.Pacing.ReturnChance), gap or no gap.
function Director:HuntEnded(now: number, how: string?)
	self.services.RunLogService:Hunt(false, how or "survived")
	self.lastHuntEnded = now
	self.retreatUntil = now + Config.Stalker.RetreatTierSeconds
	self.forced = false
	local pacing = Config.Pacing
	self.nextGap = DirectorModel.huntGap(self.armRng:NextNumber(), Config)
	if how == "survived" and not self.disarmed and self.armRng:NextNumber() < (pacing.ReturnChance or 0) then
		self.armedAt = now + self.armRng:NextNumber(pacing.ReturnDelay[1], pacing.ReturnDelay[2])
		self.armedReason = "back again"
		self.armedRooms = nil
		self.armedFalse = false
		self.armedUrgent = true
	end
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
		-- Dread's floor rises with the act (Logic/Dread).
		services.DriftService:SetAct(act)
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
		dread = services.DriftService:Dread(),
		act = self.act,
		armedAt = self.armedAt,
		armedFalse = self.armedFalse,
		armedUrgent = self.armedUrgent,
		minGap = self.nextGap,
		lastHuntEnded = self.lastHuntEnded,
		retreatUntil = self.retreatUntil,
		lastRevive = services.PlayerStateService.lastRevive,
		squadInLantern = squadInLantern,
		stationary = services.SquadProfileService:Signals().stationary,
		forced = self.forced,
		difficulty = self.difficulty,
		introSeconds = self:IntroSeconds(),
	}, Config)
	if squadInLantern and self.armedAt and now >= self.armedAt then
		self.lanternHeld = true
	end
	self.lastDecision = decision
	return decision
end

-- How long this night's intro is (Config.Pacing.IntroSeconds): shorter on
-- the short night (DirectorModel shortens it again on Hard).
function Director:IntroSeconds(): number
	local pacing = Config.Pacing
	local night = self.services.RunOrchestrator and self.services.RunOrchestrator:Night()
	return night == "short" and (pacing.ShortIntroSeconds or pacing.IntroSeconds) or pacing.IntroSeconds
end

-- How long the next hunt lasts (longer the worse the house is).
function Director:HuntDuration(): number
	return DirectorModel.huntDuration(self.services.DriftService:Dread(), self.rng:NextNumber(-1, 1), Config)
end

-- Draw a scare if one is due. Returns the card or nil.
function Director:MaybeScare(tier: number)
	local now = os.clock()
	if now < self.nextScare then
		return nil
	end
	local dread = self.services.DriftService:Dread()
	-- The worse the house, the shorter the gaps; in the intro, longer, and
	-- nothing big (the squad playtest, 2026-10-08).
	local intro = self.lastDecision ~= nil and self.lastDecision.intro == true
	local gap = (35 - dread * 0.2) * (intro and Config.Pacing.IntroScareGap or 1)
	self.nextScare = now + self.rng:NextNumber(gap * 0.6, gap * 1.2)
	if tier <= 0 and dread < 5 then
		return nil
	end
	return self.deck:Draw(now, dread, self.act, intro)
end

-- The card drawn couldn't be played (StalkerService:_scare): its cooldown
-- doesn't run, and the next draw comes sooner.
function Director:Unplayed(card)
	self.deck:Unplay(card)
	self.nextScare = math.min(self.nextScare, os.clock() + 8)
end

return Director
