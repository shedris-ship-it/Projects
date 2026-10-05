-- What the squad can see, from The Guest's side: where each Witness is
-- looking (the camera direction every client reports, WitnessService
-- views), whose back is turned, and which nearby step keeps him out of
-- every view cone. Pure angle rules live in Logic/SightMath.
--
-- Raycasts are budgeted per body tick (Config.Guest.RayBudgetPerTick).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local SightMath = require(Shared.Logic.SightMath)

local Body = require(script.Parent.Body)

local G = Config.Guest

local Sight = {}
Sight.__index = Sight

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Sight.new(services, body)
	return setmetatable({
		services = services,
		body = body,
		rays = 0,
	}, Sight)
end

function Sight:NewTick()
	self.rays = 0
end

-- A fresh camera view for a living Witness, or nil.
function Sight:View(player: Player): CFrame?
	local cf, age = self.services.WitnessService:GetView(player)
	if not cf or age > 0.8 then
		return nil
	end
	return cf
end

-- Degrees between where a Witness looks and a point (180 = behind them).
function Sight:Angle(player: Player, point: Vector3): number
	local view = self:View(player)
	if not view then
		return 180
	end
	local d = point - view.Position
	return SightMath.angle(view.LookVector.X, view.LookVector.Z, d.X, d.Z)
end

function Sight:BackTurned(player: Player, point: Vector3): boolean
	return self:Angle(player, point) > G.BackTurnedDegrees
end

-- Which side of the Witness a point is on: +1 left, -1 right.
function Sight:Side(player: Player, point: Vector3): number
	local view = self:View(player)
	if not view then
		return 1
	end
	local d = point - view.Position
	return SightMath.side(view.LookVector.X, view.LookVector.Z, d.X, d.Z)
end

function Sight:_clear(from: Vector3, to: Vector3): boolean
	self.rays += 1
	return self.services.WitnessService:ClearLine(from, to, { self.body.model })
end

-- Could this Witness see this point right now (in their view, a clear
-- line)? Lighting doesn't matter: a figure in a dark doorway still counts.
function Sight:Sees(player: Player, point: Vector3, cone: number?): boolean
	local view = self:View(player)
	if not view then
		return false
	end
	local d = point - view.Position
	if d.Magnitude > 140 then
		return false
	end
	local c = cone or G.ViewConeDegrees
	if SightMath.angle(view.LookVector.X, view.LookVector.Z, d.X, d.Z) > c / 2 then
		return false
	end
	-- Vertical check too: looking at the floor or ceiling hides the rest.
	if view.LookVector:Dot(d.Unit) < math.cos(math.rad(c / 2 + 15)) then
		return false
	end
	if self.rays >= G.RayBudgetPerTick then
		return true -- out of budget: assume the worst (stay hidden)
	end
	return self:_clear(view.Position, point)
end

-- Who, among the living, could see any of these points.
function Sight:SeenBy(points: { Vector3 }, cone: number?): { Player }
	local seen = {}
	for _, player in self.services.PlayerStateService:LivingPlayers() do
		for _, point in points do
			if self:Sees(player, point, cone) then
				table.insert(seen, player)
				break
			end
		end
	end
	return seen
end

function Sight:AnyoneSees(points: { Vector3 }, cone: number?): boolean
	return #self:SeenBy(points, cone) > 0
end

-- Points of his body if he stood at a spot (head and chest), on the storey
-- the spot is on.
local function bodyPoints(position: Vector3): { Vector3 }
	local y = Body.FloorBase(position.Y)
	return { Vector3.new(position.X, y + 7.8, position.Z), Vector3.new(position.X, y + 5.6, position.Z) }
end
Sight.BodyPoints = bodyPoints

-- The best next point when sneaking towards `goal`: a step of a couple of
-- studs that makes progress while staying out of every Witness's view.
-- Returns the point and how many would see him there (0 = hidden).
function Sight:StealthStep(goal: Vector3): (Vector3?, number)
	local root = self.body.root
	local here = flat(root.Position)
	local toGoal = flat(goal) - here
	local distance = toGoal.Magnitude
	if distance < 0.5 then
		return nil, 0
	end
	local best, bestScore, bestExposure = nil, -math.huge, 0
	local step = math.min(G.StealthStep, distance)
	for i = 0, G.StealthSamples - 1 do
		local angle = (i / G.StealthSamples) * math.pi * 2
		local direction = (
			toGoal.Unit * math.cos(angle) + Vector3.new(-toGoal.Unit.Z, 0, toGoal.Unit.X) * math.sin(angle)
		)
		local candidate = root.Position + direction * step
		local progress = distance - (flat(goal) - flat(candidate)).Magnitude
		if progress > -0.5 then
			-- Walls, furniture and railings anywhere along his body, and floor
			-- to stand on (Stalker/Clearance).
			self.rays += 1
			local clearance = self.body.clearance
			local blocked = not clearance:Clear(root.Position, root.Position + direction * (step + 0.8))
				or not clearance:Grounded(candidate, self.body.built.groundOffset)
			local exposure = 0
			if not blocked then
				exposure = #self:SeenBy(bodyPoints(candidate))
			end
			local score = SightMath.stealthScore(progress, exposure, blocked)
			if score > bestScore then
				best, bestScore, bestExposure = candidate, score, exposure
			end
		end
	end
	return best, bestExposure
end

return Sight
