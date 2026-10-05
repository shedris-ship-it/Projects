-- Pushing furniture (docs/plans/gameplay-rework.md section 4.6; the owner
-- asked for every piece of furniture to be physical, with varying weights,
-- 2026-10-05). Light pieces are carried like small things (HandsService);
-- the rest are pushed. Data/Physical gives each kind a weight in people and
-- Logic/Push turns how many push it into a speed: one creeps a bed, two move
-- it, a dresser goes slowly for one, the piano wants three.
--
-- A client holding its mouse on a piece sends which way it walks (`Push`,
-- 10 a second). The server checks reach and that they face it, adds up
-- everyone pushing it in the last moment (solo, the Companion lends a hand)
-- and slides it along the floor, every step checked against the house:
-- walls, door jambs, other furniture and anybody standing there stop it, and
-- it never comes near a point The Guest walks by (a room's middle, a doorway)
-- or into a door's swing, so his walking graph never breaks (barricades,
-- R1b, will open doorways to heavy pieces). It scrapes as it goes: noise with
-- the pushers as its source.
--
-- Everything goes with it: its drawers and doors and what's in them
-- (FurnitureService:Shift), things standing on top, its light, its hiding
-- spot. Nobody can push a piece someone is hiding in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Props = require(Shared.Data.Props)
local Push = require(Shared.Logic.Push)
local Sfx = require(Shared.Lib.Sfx)
local Util = require(Shared.Lib.Util)

local P = Config.Push
local Groups = Constants.CollisionGroups
local DOOR_LENGTH = Config.Level.DoorWidth

local PushService = {}

function PushService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Furniture = services.FurnitureService
	self.Hands = services.HandsService
	self.PlayerState = services.PlayerStateService
	self.Noise = services.NoiseService
	self.Companion = services.CompanionService
	self.Stalker = services.StalkerService
	self.pieces = {} -- prop id -> piece
	self.moving = {} -- piece -> true while someone pushes it
end

function PushService:Start()
	Net.onServer("Push", {
		interval = 1 / (P.SendHz + 4),
		burst = P.SendHz + 6,
		types = { "string", "Vector3" },
	}, function(player, id, direction)
		self:_push(player, id, direction)
	end)
	self.World.Built:Connect(function(world)
		self:_setup(world)
	end)
	self.World.Cleared:Connect(function()
		table.clear(self.pieces)
		table.clear(self.moving)
	end)
	RunService.Heartbeat:Connect(function(dt)
		for piece in self.moving do
			self:_step(piece, dt)
		end
	end)
end

function PushService:_setup(world)
	for _, prop in world.props or {} do
		local info = Physical.Furniture[prop.kind]
		local kind = Props.Kinds[prop.kind]
		if info and info.weight and kind and prop.frame and prop.model.Parent then
			local spots = {}
			for _, spot in world.hidingSpots or {} do
				if spot.model == prop.model then
					table.insert(spots, spot)
				end
			end
			local parts = {}
			for _, p in prop.model:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
				end
			end
			-- Hiding spots' anchors live in the room, not in the piece.
			for _, spot in spots do
				if spot.anchor and not spot.anchor:IsDescendantOf(prop.model) then
					table.insert(parts, spot.anchor)
				end
			end
			-- What the client needs to know it can push this (and how heavy).
			prop.model:SetAttribute("Push", info.weight)
			prop.model:SetAttribute("PushLabel", info.label)
			self.pieces[prop.id] = {
				id = prop.id,
				prop = prop,
				model = prop.model,
				room = prop.model.Parent,
				weight = info.weight,
				size = Vector3.new(kind.size[1], kind.size[2], kind.size[3]),
				parts = parts,
				spots = spots,
				pushers = {},
				riders = {},
				scrapedAt = 0,
			}
		end
	end
end

-- Geometry -----------------------------------------------------------------------

-- How far a point is from a piece's footprint (flat), and the flat way to it.
local function gap(frame: CFrame, size: Vector3, point: Vector3): (number, Vector3)
	local at = frame:PointToObjectSpace(point)
	local nearest = frame:PointToWorldSpace(
		Vector3.new(math.clamp(at.X, -size.X / 2, size.X / 2), at.Y, math.clamp(at.Z, -size.Z / 2, size.Z / 2))
	)
	local toward = Vector3.new(nearest.X - point.X, 0, nearest.Z - point.Z)
	return toward.Magnitude, toward
end

-- A point over the footprint (grown by `margin`) on the piece's own floor.
local function over(frame: CFrame, size: Vector3, point: Vector3, margin: number): boolean
	local at = frame:PointToObjectSpace(point)
	return math.abs(at.X) <= size.X / 2 + margin
		and math.abs(at.Z) <= size.Z / 2 + margin
		and at.Y > -3
		and at.Y < size.Y + 5
end

local function isCharacter(part: BasePart): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- Hands ---------------------------------------------------------------------------

function PushService:_occupied(piece): boolean
	for _, spot in piece.spots do
		if #spot.occupants > 0 then
			return true
		end
	end
	return false
end

function PushService:_push(player: Player, id: string, direction: Vector3)
	local piece = self.pieces[id]
	if not piece or not piece.model.Parent or not self.PlayerState:CanAct(player) then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local root = self.PlayerState:Root(player)
	if flat.Magnitude < 0.5 or flat.Magnitude > 1.5 or not root then
		return
	end
	local frame = piece.prop.frame
	local distance, toward = gap(frame, piece.size, root.Position)
	if distance > P.Reach or not over(frame, piece.size, root.Position, P.Reach + 1) then
		return
	end
	-- You push what's in front of you (pulling, you still face it).
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if toward.Magnitude > 0.05 and look.Magnitude > 1e-3 and look.Unit:Dot(toward.Unit) < 0.2 then
		return
	end
	if self:_occupied(piece) then
		return
	end
	piece.pushers[player] = { dir = flat.Unit, at = os.clock() }
	self:_wake(piece)
end

-- Starting to move: note what stands on top, so it goes along.
function PushService:_wake(piece)
	if self.moving[piece] then
		return
	end
	self.moving[piece] = true
	table.clear(piece.riders)
	local frame, size = piece.prop.frame, piece.size
	local top = frame.Y + size.Y
	local seen = {}
	local function consider(model: Instance)
		if seen[model] or model == piece.model or not model:IsA("Model") then
			return
		end
		seen[model] = true
		local bottom = Util.verticalSpan(model)
		if math.abs(bottom - top) < 0.4 and over(frame, size, model:GetBoundingBox().Position, -0.2) then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and not p.Anchored then
					return -- something awake in someone's hands or falling
				end
			end
			table.insert(piece.riders, model)
		end
	end
	for _, thing in self.Hands.things do
		if thing.state == "rest" then
			consider(thing.model)
		end
	end
	local pickups = self.World.content and self.World.content:FindFirstChild("ToolPickups")
	for _, holder in { piece.room, pickups } do
		for _, child in holder and holder:GetChildren() or {} do
			consider(child)
		end
	end
end

-- Solo, the Companion lends a hand when it's close.
function PushService:_help(piece): number
	if #self.PlayerState:RunPlayers() ~= 1 or not self.Companion:IsPresent() then
		return 0
	end
	local at = self.Companion:GetPosition()
	if at and gap(piece.prop.frame, piece.size, at) <= P.CompanionRange then
		return 1
	end
	return 0
end

-- Moving -----------------------------------------------------------------------------

function PushService:_step(piece, dt: number)
	if not piece.model.Parent then
		self.moving[piece] = nil
		return
	end
	local now = os.clock()
	local directions, first = {}, nil
	for player, push in piece.pushers do
		if now - push.at > P.Window or not player.Parent then
			piece.pushers[player] = nil
		else
			table.insert(directions, { x = push.dir.X, z = push.dir.Z })
			first = first or player
		end
	end
	local debug = piece.debug
	if debug and now < debug.untilT then
		for _ = 1, debug.strength do
			table.insert(directions, { x = debug.dir.X, z = debug.dir.Z })
		end
	elseif debug then
		piece.debug = nil
	end
	if #directions == 0 then
		self.moving[piece] = nil
		self.Furniture:Settle(piece.model)
		return
	end
	local d = Push.direction(directions)
	if not d then
		return
	end
	local strength = #directions + (first and self:_help(piece) or 0)
	local speed, creeping = Push.speed(strength, piece.weight, P)
	local step = Vector3.new(d.x, 0, d.z) * speed * dt
	-- Blocked straight on? It slides along whatever stopped it.
	local moved = self:_try(piece, step)
	if not moved then
		for _, part in { Vector3.new(step.X, 0, 0), Vector3.new(0, 0, step.Z) } do
			if part.Magnitude > 1e-4 and self:_try(piece, part) then
				moved = true
				break
			end
		end
	end
	if moved and now - piece.scrapedAt > P.ScrapeEvery then
		piece.scrapedAt = now
		local at = piece.prop.frame.Position
		self.Noise:Emit(at, Push.noise(piece.weight, creeping, P.ScrapeNoise), first, "scrape")
		Sfx.play("CreakAlt", at, creeping and 0.5 or 0.35, creeping and 0.45 or 0.6)
	end
end

-- Where The Guest walks: his graph's points, and every door's swing.
function PushService:_keepsClear(from: CFrame, to: CFrame, size: Vector3): boolean
	local world = self.World.World
	local nav = self.World.nav
	if nav then
		local fromLayout = self.World.FromLayout
		for _, node in nav.nodes do
			local p = fromLayout(node)
			if
				(p - to.Position).Magnitude < 40
				and over(to, size, p, P.KeepClear)
				and not over(from, size, p, P.KeepClear)
			then
				return false
			end
		end
	end
	for _, door in world and world.doors or {} do
		local hinge = door.hinge
		if hinge and math.abs(hinge.Y - to.Y) < 8 then
			local reach = DOOR_LENGTH + P.DoorClear
			local before = gap(from, size, Vector3.new(hinge.X, from.Y + 1, hinge.Z))
			local after = gap(to, size, Vector3.new(hinge.X, to.Y + 1, hinge.Z))
			if after < reach and after < before then
				return false
			end
		end
	end
	return true
end

-- Nobody is pushed into or crushed: a body it would newly cover stops it.
function PushService:_bodies(): { Vector3 }
	local bodies = {}
	for _, player in Players:GetPlayers() do
		local root = self.PlayerState:Root(player)
		if root then
			table.insert(bodies, root.Position)
		end
	end
	local companion = self.Companion:IsPresent() and self.Companion:GetPosition()
	if companion then
		table.insert(bodies, companion)
	end
	local guest = self.Stalker:GetPosition()
	if guest then
		table.insert(bodies, guest)
	end
	return bodies
end

-- The solid things its body overlaps at `frame`: lifted off the floor and
-- stopping under its top (what stands on top rides along).
local function solids(piece, frame: CFrame): { [BasePart]: true }
	local size = piece.size
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(piece.riders)
	table.insert(ignore, piece.model)
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local found = {}
	local box = frame * CFrame.new(0, size.Y / 2 + 0.1, 0)
	local boxSize = Vector3.new(size.X - 0.2, math.max(0.2, size.Y - 0.4), size.Z - 0.2)
	for _, hit in Workspace:GetPartBoundsInBox(box, boxSize, params) do
		if hit.CollisionGroup ~= Groups.Prop and hit.CollisionGroup ~= Groups.Held and not isCharacter(hit) then
			found[hit] = true
		end
	end
	return found
end

function PushService:_try(piece, step: Vector3): boolean
	local from = piece.prop.frame
	local to = from + step
	local size = piece.size
	-- Anything solid it would newly run into stops it (it may already touch
	-- the skirting board it stands against, and can still slide off it).
	local already = solids(piece, from)
	for hit in solids(piece, to) do
		if not already[hit] then
			return false
		end
	end
	for _, body in self:_bodies() do
		if over(to, size, body, 0.7) and not over(from, size, body, 0.7) then
			return false
		end
	end
	if not self:_keepsClear(from, to, size) then
		return false
	end
	self:_move(piece, step)
	return true
end

function PushService:_move(piece, step: Vector3)
	local cframes = table.create(#piece.parts)
	for i, p in piece.parts do
		cframes[i] = p.CFrame + step
	end
	Workspace:BulkMoveTo(piece.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	for _, spot in piece.spots do
		spot.insideCFrame += step
		spot.peekCFrame += step
		spot.frontPosition += step
	end
	for _, rider in piece.riders do
		if rider.Parent then
			rider:PivotTo(rider:GetPivot() + step)
		end
	end
	piece.prop.frame += step
	self.Furniture:Shift(piece.model, step)
end

-- F2 `push`: the nearest pushable piece is pushed `strength` people's worth
-- along (dx, dz) for a while, as if they were there.
function PushService:DebugPush(player: Player, dx: number, dz: number, strength: number, seconds: number): string
	local root = self.PlayerState:Root(player)
	local direction = Vector3.new(dx, 0, dz)
	if not root or direction.Magnitude < 1e-3 then
		return "usage: push <dx> <dz> [strength] [seconds]"
	end
	local best, nearest = nil, 12
	for _, piece in self.pieces do
		local distance = gap(piece.prop.frame, piece.size, root.Position)
		if distance < nearest and over(piece.prop.frame, piece.size, root.Position, 12) then
			best, nearest = piece, distance
		end
	end
	if not best then
		return "nothing pushable within 12 studs"
	end
	best.debug = { dir = direction.Unit, strength = strength, untilT = os.clock() + seconds }
	self:_wake(best)
	local speed = Push.speed(strength, best.weight, P)
	return string.format(
		"pushing %s (weight %.1f) with %d for %.1f s: %.2f studs/s",
		best.id,
		best.weight,
		strength,
		seconds,
		speed
	)
end

return PushService
