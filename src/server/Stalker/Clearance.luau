-- Keeping a walker's body out of the walls (docs/plans/mansion-generation.md,
-- M3; owner 2026-10-04: "when the guest retreats he commonly backs up into a
-- wall or phase through the wall"). Anything that moves him other than an
-- ordinary walk (a yank out of sight, a lunge, a side-step, a stuck nudge, a
-- stealth step) is swept first with a box the size of his body, and every
-- tick checks that he hasn't crossed a wall between two positions.
--
-- Casts use the walker's collision group, so whatever it passes through
-- anyway is ignored: players, doors (he opens them in code), and solid seams
-- while Phantom Architecture's twist lets him walk through them. Railing
-- colliders can't be queried (sight passes between the balusters), so they
-- are found by tag and tested by hand.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared.Constants)

local Clearance = {}
Clearance.__index = Clearance

-- A shape cast misses whatever it starts inside, so the swept box is a little
-- slimmer than the body that collides; `margin` is kept back from a hit.
local SWEEP = Vector3.new(0.9, 3, 0.9)
local SWEEP_LIFT = 0.4 -- the box's centre above the root (clear of steps and ramps underfoot)

-- agent: { model, group = collision group name, halfWidth = how far his body
-- reaches sideways (for railings and the margin) }
function Clearance.new(agent)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { agent.model }
	params.CollisionGroup = agent.group
	params.RespectCanCollide = true
	return setmetatable({
		params = params,
		halfWidth = agent.halfWidth or 0.8,
		margin = agent.margin or 0.3,
		phases = 0,
		lastPhase = nil,
	}, Clearance)
end

-- Ignore more instances (a door being opened, a teammate's tool).
function Clearance:SetIgnore(list: { Instance })
	self.params.FilterDescendantsInstances = list
end

-- How far along `delta` from `from` a segment can go before it meets one of
-- the railing colliders, widened by `pad`.
function Clearance:_railingTravel(from: Vector3, delta: Vector3, pad: number): number
	local length = delta.Magnitude
	if length < 1e-4 then
		return length
	end
	local best = length
	for _, part in CollectionService:GetTagged(Constants.Tags.Railing) do
		if part:IsA("BasePart") and part.CanCollide then
			local cf = part.CFrame
			local a = cf:PointToObjectSpace(from)
			local d = cf:VectorToObjectSpace(delta)
			local half = part.Size / 2 + Vector3.new(pad, 0, pad)
			-- Slab test in the railing's own frame.
			local tMin, tMax = 0, 1
			local hit = true
			for _, axis in { "X", "Y", "Z" } do
				local origin, dir, h = a[axis], d[axis], half[axis]
				if math.abs(dir) < 1e-6 then
					if origin < -h or origin > h then
						hit = false
						break
					end
				else
					local t1, t2 = (-h - origin) / dir, (h - origin) / dir
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					tMin, tMax = math.max(tMin, t1), math.min(tMax, t2)
					if tMin > tMax then
						hit = false
						break
					end
				end
			end
			if hit then
				best = math.min(best, tMin * length)
			end
		end
	end
	return best
end

-- The farthest root position toward `to` that his body can reach from
-- `from` (root positions), and whether it gets all the way there.
function Clearance:Reach(from: Vector3, to: Vector3): (Vector3, boolean)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.05 then
		return to, true
	end
	local start = from + Vector3.new(0, SWEEP_LIFT, 0)
	local travel = length
	local frame = math.abs(delta.Unit.Y) > 0.95 and CFrame.new(start) or CFrame.lookAt(start, start + delta)
	-- A shapecast can't go further than 1024 studs (a target far off in the
	-- hub, say): sweep the first stretch, which is all a step needs.
	local result = Workspace:Blockcast(frame, SWEEP, delta.Unit * math.min(length, 1000), self.params)
	if result then
		travel = math.max(0, result.Distance - self.margin)
	end
	travel = math.min(travel, math.max(0, self:_railingTravel(from, delta, self.halfWidth) - self.margin))
	if travel >= length - 1e-3 then
		return to, true
	end
	return from + delta.Unit * travel, false
end

function Clearance:Clear(from: Vector3, to: Vector3): boolean
	local _, ok = self:Reach(from, to)
	return ok
end

-- What a move between two root positions (one tick apart) went through, or
-- nil: a wall, a closed seam, a piece of furniture or a railing.
function Clearance:Crossed(from: Vector3, to: Vector3): Instance?
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return nil
	end
	local result = Workspace:Raycast(from, delta, self.params)
	if result then
		return result.Instance
	end
	if self:_railingTravel(from, delta, 0) < delta.Magnitude - 1e-3 then
		return CollectionService:GetTagged(Constants.Tags.Railing)[1]
	end
	return nil
end

-- Is there floor under a root position (not the void over the hall, not
-- mid-air beside a stair)? `drop` is how far below his feet to look.
function Clearance:Grounded(root: Vector3, groundOffset: number, drop: number?): boolean
	local result = Workspace:Raycast(root, Vector3.new(0, -(groundOffset + (drop or 1.5)), 0), self.params)
	return result ~= nil
end

return Clearance
