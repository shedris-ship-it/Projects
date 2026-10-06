-- Tool locks (docs/plans/level-design.md section 11, L3.3): a boarded door
-- the crowbar pries open plank by plank, a chained door the bolt cutters cut
-- in one snap. The tool is found once and works every lock of its kind.
-- It's loud work: each plank screeches and the chain snaps, a noise he may
-- hear, so a squad keeps a lookout (two watchers freeze him). Progress is
-- kept: let go and the boards already off stay off. One player gets shorter
-- work, with nobody to watch for them. Pure (tests/specs/ToolLocks.spec).

local ToolLocks = {}

-- What each kind is, and what it says.
ToolLocks.Kinds = {
	boards = {
		tool = "Crowbar",
		object = "Boarded door",
		action = "Pry",
		refuse = "Boarded up. Something could pry the boards off.",
		step = "A board screeches and comes away.",
		done = "The last board comes away.",
		verb = "pry the boards off",
	},
	chain = {
		tool = "BoltCutters",
		object = "Chained door",
		action = "Cut",
		refuse = "A chain through the handles. Something could cut it.",
		done = "The chain snaps and falls away.",
		verb = "cut the chain on",
	},
}

-- How the work goes for a squad of `squad` (Config.ToolLocks):
-- { steps (holds), seconds (each hold), noise (studs) }.
function ToolLocks.work(kind: string, squad: number?, cfg)
	local c = kind == "boards" and cfg.Boards or cfg.Chain
	local i = math.clamp(math.floor(squad or #c.Seconds), 1, #c.Seconds)
	return {
		steps = kind == "boards" and c.Planks[i] or 1,
		seconds = c.Seconds[i],
		noise = c.Noise,
	}
end

-- A lock's state: { left = steps still to do }.
function ToolLocks.start(work)
	return { left = work.steps }
end

-- One hold done: a plank off, or the chain cut. Returns whether it's open.
function ToolLocks.step(state): boolean
	state.left = math.max(0, state.left - 1)
	return state.left == 0
end

-- Is this a tool lock's kind?
function ToolLocks.is(kind: string?): boolean
	return kind ~= nil and ToolLocks.Kinds[kind] ~= nil
end

return ToolLocks
