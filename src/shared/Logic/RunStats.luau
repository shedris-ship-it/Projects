-- The run in numbers (docs/progress/2026-10-06-overnight, "A. Measure"): what
-- the F2 overlay shows while a run goes on and what the Dossier and the
-- Output window sum up at its end, so a playtest can be judged against the
-- fear curve rather than remembered. Pure (tests/specs/RunStats.spec);
-- Services/RunLogService owns one and feeds it.
--
-- A "beat" is anything that breaks the quiet for the squad: a scare card, a
-- house event, a sighting of The Guest, a tell behind your back, a hunt's
-- telegraph, progress. Silence is the time between beats; a stretch of
-- Config.Stats.SilentSeconds or more counts as silent minutes.
--
-- The effective tier score is the time-weighted mean of his tier from the
-- moment he arrives (0 Dormant to 4 Hunting), so a run that never leaves
-- tier 1 scores about 1, and one that spends half its time at tier 3 and in
-- hunts scores about 2.

local RunStats = {}
RunStats.__index = RunStats

local MAX_EVENTS = 400

function RunStats.new(startedAt: number, cfg)
	return setmetatable({
		cfg = cfg or { SilentSeconds = 60 },
		started = startedAt,
		arrivedAt = nil,
		lastBeat = startedAt,
		silentLongest = 0,
		silentLongestFrom = startedAt,
		silentTotal = 0, -- seconds spent in stretches of SilentSeconds or more
		tierSeconds = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
		tierSince = nil,
		freezeSeconds = 0,
		freezes = 0,
		frozen = false,
		events = {},
		scares = {}, -- id -> count
		scareTotal = 0,
		hunts = {}, -- { at, reason, endedAt?, how?, catches }
		falseAlarms = 0,
		stareDowns = 0,
		downs = 0,
		catches = 0,
		sightings = 0,
		progress = 0,
		firstProgressAt = nil,
		lastProgressAt = startedAt,
		longestGap = 0, -- the longest stretch without progress so far
		acts = {}, -- { act, at }
		act = 1,
		-- The owner's finish line (docs/progress/2026-10-06-overnight/REPORT.md).
		firstDoorAt = nil,
		firstHuntAt = nil,
		servedAt = nil,
		extractedAt = nil,
		torchDead = 0,
		torchDeadAt = nil,
		hints = 0,
		earlyScares = 0, -- scares in the first EarlySeconds
		f2 = 0, -- debug commands that changed the run
	}, RunStats)
end

function RunStats:_gap(t: number)
	self.longestGap = math.max(self.longestGap, t - self.lastProgressAt)
end

function RunStats:_event(t: number, kind: string, detail: string?)
	table.insert(self.events, { t = t, kind = kind, detail = detail })
	if #self.events > MAX_EVENTS then
		table.remove(self.events, 1)
	end
end

-- Something happened for the squad: the quiet is broken.
function RunStats:Beat(t: number, kind: string, detail: string?)
	local gap = t - self.lastBeat
	if gap > self.silentLongest then
		self.silentLongest = gap
		self.silentLongestFrom = self.lastBeat
	end
	if gap >= self.cfg.SilentSeconds then
		self.silentTotal += gap
	end
	self.lastBeat = t
	self:_event(t, kind, detail)
end

-- How long the quiet has lasted right now.
function RunStats:SilentNow(t: number): number
	return t - self.lastBeat
end

function RunStats:Arrived(t: number)
	if not self.arrivedAt then
		self.arrivedAt = t
		self.tierSince = t
		self:Beat(t, "arrived")
	end
end

-- Once a second or so: his tier (0-3, 4 in a hunt) and whether two watchers
-- hold him frozen.
function RunStats:Tick(t: number, tier: number, frozen: boolean)
	self:_gap(t)
	if not self.arrivedAt then
		return -- nothing to measure until he's in the house
	end
	if self.tierSince then
		local dt = t - self.tierSince
		if dt > 0 then
			local index = math.clamp(math.floor(tier + 0.5), 0, 4)
			self.tierSeconds[index] += dt
			if frozen then
				self.freezeSeconds += dt
			end
		end
	end
	self.tierSince = t
	if frozen and not self.frozen then
		self.freezes += 1
	end
	self.frozen = frozen
end

function RunStats:Progress(t: number, kind: string, detail: string?)
	self.progress += 1
	if not self.firstProgressAt then
		self.firstProgressAt = t
	end
	if kind == "lock" and not self.firstDoorAt then
		self.firstDoorAt = t
	end
	self:_gap(t)
	self.lastProgressAt = t
	self:Beat(t, "progress:" .. kind, detail)
end

-- The dinner is served; someone got out of the front door.
function RunStats:Served(t: number)
	self.servedAt = self.servedAt or t
	self:Beat(t, "served")
end

function RunStats:Extracted(t: number)
	self.extractedAt = self.extractedAt or t
	self:_event(t, "extracted")
end

-- A torch ran flat.
function RunStats:TorchDead(t: number)
	self.torchDead += 1
	self.torchDeadAt = self.torchDeadAt or t
	self:_event(t, "torchDead")
end

-- Stuck-assist had to say something (Logic/Assist).
function RunStats:Hint(t: number)
	self.hints += 1
	self:_event(t, "hint")
end

-- A debug command that changed the run (F2): the finish line wants none.
function RunStats:F2(t: number, command: string?)
	self.f2 += 1
	self:_event(t, "f2", command)
end

function RunStats:Act(t: number, act: number)
	self.act = act
	table.insert(self.acts, { act = act, at = t })
	self:Beat(t, "act", tostring(act))
end

function RunStats:Scare(t: number, id: string)
	self.scares[id] = (self.scares[id] or 0) + 1
	self.scareTotal += 1
	if t - self.started < (self.cfg.EarlySeconds or 600) then
		self.earlyScares += 1
	end
	self:Beat(t, "scare", id)
end

function RunStats:Sighting(t: number, who: string?)
	self.sightings += 1
	self:Beat(t, "sighting", who)
end

function RunStats:HuntBegan(t: number, reason: string?)
	table.insert(self.hunts, { at = t, reason = reason or "?", catches = 0 })
	self.firstHuntAt = self.firstHuntAt or t
	self:Beat(t, "hunt", reason)
end

-- how: "survived" (ran its course), "stared down", "escaped" (the final hunt,
-- out of the front door), "lost" (everyone caught or left behind), "ended"
function RunStats:HuntEnded(t: number, how: string?)
	local hunt = self.hunts[#self.hunts]
	if hunt and not hunt.endedAt then
		hunt.endedAt = t
		hunt.how = how or "ended"
	end
	self:_event(t, "huntEnd", how)
end

-- A telegraph that came to nothing (Stalker/Director false alarms).
function RunStats:FalseAlarm(t: number)
	self.falseAlarms += 1
	self:Beat(t, "falseAlarm")
end

function RunStats:StareDown(t: number, inHunt: boolean)
	self.stareDowns += 1
	self:_event(t, "stareDown", inHunt and "hunt" or "stalk")
end

function RunStats:Catch(t: number, who: string?, how: string?)
	self.catches += 1
	local hunt = self.hunts[#self.hunts]
	if hunt and not hunt.endedAt then
		hunt.catches += 1
	end
	self:Beat(t, "catch", who and (who .. " " .. tostring(how)) or how)
end

function RunStats:Down(t: number, who: string?)
	self.downs += 1
	self:_event(t, "down", who)
end

-- The numbers, as of `t`.
function RunStats:Summary(t: number)
	local seconds = t - self.started
	local from = self.arrivedAt or t
	local present = math.max(0, t - from)
	local weighted, total = 0, 0
	for tier = 0, 4 do
		local s = self.tierSeconds[tier]
		weighted += tier * s
		total += s
	end
	local silentNow = self:SilentNow(t)
	local silentTotal = self.silentTotal + (silentNow >= self.cfg.SilentSeconds and silentNow or 0)
	local hunts = {}
	for _, h in self.hunts do
		table.insert(hunts, {
			at = h.at - self.started,
			reason = h.reason,
			how = h.how or "going on",
			seconds = h.endedAt and (h.endedAt - h.at) or (t - h.at),
			catches = h.catches,
		})
	end
	local scares = {}
	for id, count in self.scares do
		table.insert(scares, { id = id, count = count })
	end
	table.sort(scares, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.id < b.id
	end)
	return {
		seconds = seconds,
		act = self.act,
		acts = self.acts,
		tierScore = total > 0 and weighted / total or 0,
		tierSeconds = table.clone(self.tierSeconds),
		presentSeconds = present,
		highTierShare = total > 0 and (self.tierSeconds[3] + self.tierSeconds[4]) / total or 0,
		silentLongest = math.max(self.silentLongest, silentNow),
		silentTotal = silentTotal,
		silentNow = silentNow,
		scares = scares,
		scareTotal = self.scareTotal,
		hunts = hunts,
		falseAlarms = self.falseAlarms,
		stareDowns = self.stareDowns,
		freezes = self.freezes,
		freezeSeconds = self.freezeSeconds,
		downs = self.downs,
		catches = self.catches,
		sightings = self.sightings,
		progress = self.progress,
		firstProgressAt = self.firstProgressAt and (self.firstProgressAt - self.started) or nil,
		sinceProgress = t - self.lastProgressAt,
		longestGap = math.max(self.longestGap, t - self.lastProgressAt),
		-- The finish line.
		firstDoorAt = self.firstDoorAt and (self.firstDoorAt - self.started) or nil,
		firstHuntAt = self.firstHuntAt and (self.firstHuntAt - self.started) or nil,
		servedAt = self.servedAt and (self.servedAt - self.started) or nil,
		extractedAt = self.extractedAt and (self.extractedAt - self.started) or nil,
		torchDead = self.torchDead,
		torchDeadAt = self.torchDeadAt and (self.torchDeadAt - self.started) or nil,
		hints = self.hints,
		earlyScares = self.earlyScares,
		f2 = self.f2,
	}
end

local function clockOr(seconds: number?, missing: string): string
	if seconds == nil then
		return missing
	end
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- The owner's finish line in one line (three solo runs: frightened twice in
-- the first ten minutes with no hunt, never stuck two minutes, no stare
-- ending a hunt, the dinner under forty minutes with no F2).
function RunStats.finishLine(s): string
	return string.format(
		"Finish line: first door %s · dinner %s · out %s · torch dead %d · hints %d · longest without progress %s · scares in the first 10 min %d · first hunt %s · F2 used %d",
		clockOr(s.firstDoorAt, "never"),
		clockOr(s.servedAt, "never"),
		clockOr(s.extractedAt, "never"),
		s.torchDead,
		s.hints,
		clockOr(s.longestGap, "0:00"),
		s.earlyScares,
		clockOr(s.firstHuntAt, "none"),
		s.f2
	)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
RunStats.clock = clock

-- The Dossier's and the Output window's lines for a summary.
function RunStats.lines(s): { string }
	local lines = {}
	table.insert(
		lines,
		string.format(
			"Run %s · act %d · tier score %.2f · %d%% of his time at tier 3 or hunting",
			clock(s.seconds),
			s.act,
			s.tierScore,
			math.floor(s.highTierShare * 100 + 0.5)
		)
	)
	local tiers = {}
	for tier = 0, 4 do
		table.insert(tiers, string.format("t%d %s", tier, clock(s.tierSeconds[tier])))
	end
	table.insert(lines, "Time by tier: " .. table.concat(tiers, " · "))
	table.insert(
		lines,
		string.format(
			"Silent: %.1f min in stretches of a minute or more · longest quiet %s",
			s.silentTotal / 60,
			clock(s.silentLongest)
		)
	)
	local scareWords = {}
	for i, entry in s.scares do
		if i > 8 then
			break
		end
		table.insert(scareWords, string.format("%s ×%d", entry.id, entry.count))
	end
	table.insert(
		lines,
		string.format(
			"Scares: %d%s",
			s.scareTotal,
			#scareWords > 0 and (" (" .. table.concat(scareWords, ", ") .. ")") or ""
		)
	)
	local alarms = s.falseAlarms > 0 and string.format(", %d false alarms", s.falseAlarms) or ""
	if #s.hunts == 0 then
		table.insert(lines, "Hunts: none" .. alarms)
	else
		table.insert(lines, string.format("Hunts: %d%s", #s.hunts, alarms))
		for i, h in s.hunts do
			table.insert(
				lines,
				string.format(
					"  %d at %s (%s): %s after %s%s",
					i,
					clock(h.at),
					h.reason,
					h.how,
					clock(h.seconds),
					h.catches > 0 and string.format(", %d caught", h.catches) or ""
				)
			)
		end
	end
	table.insert(
		lines,
		string.format(
			"Stare-downs %d · frozen %d times for %s · sightings %d · downs %d · caught %d",
			s.stareDowns,
			s.freezes,
			clock(s.freezeSeconds),
			s.sightings,
			s.downs,
			s.catches
		)
	)
	table.insert(
		lines,
		string.format(
			"Progress: %d steps · first at %s · %s since the last",
			s.progress,
			s.firstProgressAt and clock(s.firstProgressAt) or "never",
			clock(s.sinceProgress)
		)
	)
	table.insert(lines, RunStats.finishLine(s))
	return lines
end

-- The F2 overlay's lines (short).
function RunStats.overlay(s): { string }
	local ends = {}
	for _, h in s.hunts do
		table.insert(ends, h.how == "going on" and "on" or string.sub(h.how, 1, 7))
	end
	return {
		string.format(
			"act %d · tier score %.2f · high %d%% · silent now %s / longest %s / %.1f min",
			s.act,
			s.tierScore,
			math.floor(s.highTierShare * 100 + 0.5),
			clock(s.silentNow),
			clock(s.silentLongest),
			s.silentTotal / 60
		),
		string.format(
			"scares %d · hunts %d [%s] · false %d · stares %d · frozen %d/%s",
			s.scareTotal,
			#s.hunts,
			table.concat(ends, " "),
			s.falseAlarms,
			s.stareDowns,
			s.freezes,
			clock(s.freezeSeconds)
		),
		string.format(
			"progress %d · first %s · since last %s · sightings %d · downs %d · caught %d",
			s.progress,
			s.firstProgressAt and clock(s.firstProgressAt) or "-",
			clock(s.sinceProgress),
			s.sightings,
			s.downs,
			s.catches
		),
		string.format(
			"door %s · dinner %s · out %s · torch dead %d · hints %d · no progress max %s · early scares %d · F2 %d",
			clockOr(s.firstDoorAt, "-"),
			clockOr(s.servedAt, "-"),
			clockOr(s.extractedAt, "-"),
			s.torchDead,
			s.hints,
			clock(s.longestGap),
			s.earlyScares,
			s.f2
		),
	}
end

return RunStats
