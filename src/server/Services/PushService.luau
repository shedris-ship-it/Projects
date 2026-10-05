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
-- it never comes near a point The Guest walks by (a room's middle, a stair's
-- foot) or into a door's swing, so his walking graph never breaks. It
-- scrapes as it goes: noise with the pushers as its source.
--
-- Barricades (gameplay rework 4.7): a heavy piece may go across a doorway,
-- but only far enough to bar it (Logic/Barricade), and a shut door's swing
-- may be filled then too, so the door won't open past it. A barred doorway
-- costs everyone extra (WorldService:SeamCost): a player squeezes past it
-- (a hold at the doorway, noisy), and The Guest bangs on it and shoves it
-- clear (Stalker/Walker, Shove here) within a few seconds.
--
-- Everything goes with it: its drawers and doors and what's in them
-- (FurnitureService:Shift), things standing on top, its light, its hiding
-- spot. Nobody can push a piece someone is hiding in.
--
-- It has weight (R2c, the physics feel pass): a heavy piece is slow to get
-- going (Logic/Push.step), coasts a moment when you stop, and you walk no
-- faster than it moves while you lean on it (the PushSpeed attribute,
-- Controllers/ActionController). You can pull it too: once you have hold,
-- it stays yours a little further out. Pushed pieces are the Heavy
-- collision group.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Articulation = require(Shared.Logic.Articulation)
local Barricade = require(Shared.Logic.Barricade)
local Physical = require(Shared.Data.Physical)
local Props = require(Shared.Data.Props)
local Push = require(Shared.Logic.Push)
local Sfx = require(Shared.Lib.Sfx)
local Util = require(Shared.Lib.Util)

local P = Config.Push
local B = Config.Barricade
local D = Config.Doors
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
	self.moving = {} -- piece -> true while someone pushes it (or it coasts)
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
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / P.StepHz then
			return
		end
		local step = math.min(accumulator, 0.1)
		accumulator = 0
		for piece in self.moving do
			self:_step(piece, step)
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
			-- Pushed furniture collides with everyone but Echoes (WorldService).
			for _, p in prop.model:GetDescendants() do
				if p:IsA("BasePart") then
					p.CollisionGroup = Groups.Heavy
				end
			end
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
				velocity = Vector3.zero,
				barring = {}, -- seam id -> true while it bars that doorway
			}
		end
	end
	-- Anything that starts out barring a doorway (RoomFit keeps lanes clear, so
	-- nothing should) is known from the start.
	for _, piece in self.pieces do
		self:_refreshBars(piece)
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

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A piece's footprint in Logic/Barricade's numbers.
local function footprint(frame: CFrame, size: Vector3)
	local right = frame.RightVector
	return { x = frame.X, z = frame.Z, yaw = math.atan2(-right.Z, right.X), w = size.X, d = size.Z }
end

-- A doorway's lane on the side of `position`, and that side (+1 along the
-- seam's normal, toward room b).
local function laneOf(seam, position: Vector3)
	local n = flat(seam.normal).Unit
	local side = (position - seam.floorPosition):Dot(n) >= 0 and 1 or -1
	local into = n * side
	local p = seam.floorPosition
	return {
		x = p.X,
		z = p.Z,
		ix = into.X,
		iz = into.Z,
		width = DOOR_LENGTH,
		depth = B.LaneDepth,
		approach = Config.Nav.Approach,
	},
		side
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
	-- Once you have hold (pushing or pulling), it stays yours a little further.
	local holding = piece.pushers[player] and os.clock() - piece.pushers[player].at < 1
	local reach = holding and P.ReachHeld or P.Reach
	if distance > reach or not over(frame, piece.size, root.Position, reach + 1) then
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
	self:_gather(piece)
end

-- The points The Guest walks by near the piece (once per push), and what
-- stands on top of it.
function PushService:_gather(piece)
	table.clear(piece.riders)
	local frame, size = piece.prop.frame, piece.size
	piece.navNear = {}
	local nav = self.World.nav
	if nav then
		local fromLayout = self.World.FromLayout
		for _, node in nav.nodes do
			local p = fromLayout(node)
			if (p - frame.Position).Magnitude < 50 then
				table.insert(piece.navNear, { p = p, kind = node.kind, seam = node.seam })
			end
		end
	end
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
	local content = self.World.content
	local pickups = content and content:FindFirstChild("ToolPickups")
	-- Keepsake boxes, display cases and notes (Services/ItemService).
	local leads = content and content:FindFirstChild("Leads")
	for _, holder in { piece.room, pickups, leads } do
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
	if piece.shoving then
		return -- he has it (Shove)
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
	-- Where the pushers want it to go, if anywhere (they may cancel out).
	local d = #directions > 0 and Push.direction(directions) or nil
	local target, creeping = Vector3.zero, false
	if d then
		local strength = #directions + (first and self:_help(piece) or 0)
		local speed
		speed, creeping = Push.speed(strength, piece.weight, P)
		target = Vector3.new(d.x, 0, d.z) * speed
	end
	piece.velocity = Push.step(piece.velocity, target, piece.weight, dt, P)
	if #directions == 0 and piece.velocity.Magnitude < 0.02 then
		-- Nobody pushing and it has coasted to a stop.
		piece.velocity = Vector3.zero
		self.moving[piece] = nil
		piece.model:SetAttribute("PushSpeed", nil)
		self.Furniture:Settle(piece.model)
		for _, rider in piece.riders do
			self.Furniture:Settle(rider)
		end
		return
	end
	local step = piece.velocity * dt
	-- Blocked straight on? It slides along whatever stopped it, and loses the
	-- speed it had into it.
	local moved = step.Magnitude > 1e-5 and self:_try(piece, step)
	if not moved and step.Magnitude > 1e-5 then
		for _, part in { Vector3.new(step.X, 0, 0), Vector3.new(0, 0, step.Z) } do
			if part.Magnitude > 1e-4 and self:_try(piece, part) then
				moved = true
				piece.velocity = part / dt
				break
			end
		end
		if not moved then
			piece.velocity = Vector3.zero
		end
	end
	-- How fast it really goes, for its pushers' feet (you lean into it).
	if now - (piece.speedSentAt or 0) > 0.1 then
		piece.speedSentAt = now
		piece.model:SetAttribute("PushSpeed", math.round((moved and piece.velocity.Magnitude or 0) * 100) / 100)
	end
	if moved and now - piece.scrapedAt > P.ScrapeEvery then
		piece.scrapedAt = now
		local at = piece.prop.frame.Position
		self.Noise:Emit(at, Push.noise(piece.weight, creeping, P.ScrapeNoise), first, "scrape")
		Sfx.play("CreakAlt", at, creeping and 0.5 or 0.35, creeping and 0.45 or 0.6)
	end
end

-- Where The Guest walks: his graph's points (those near the piece, found when
-- the push began), and doors. A doorway's own points may be filled only by a
-- piece that then bars the doorway (a barricade, which everyone's routes
-- know about). A shut door's swing may be filled while the door can still
-- open far enough to walk through (it stops against the piece), or by a
-- piece that then bars the doorway; an open door's leaf (it doesn't collide
-- while open) is kept clear.
function PushService:_keepsClear(piece, from: CFrame, to: CFrame, size: Vector3): boolean
	local world = self.World.World
	for _, node in piece.navNear or {} do
		local p = node.p
		if
			(p - to.Position).Magnitude < 40
			and over(to, size, p, P.KeepClear)
			and not over(from, size, p, P.KeepClear)
		then
			local lane = (node.kind == "approach" or node.kind == "doorway") and node.seam
			if not (lane and self:_barsAt(piece, to, lane)) then
				return false
			end
		end
	end
	for _, door in world and world.doors or {} do
		local hinge = door.hinge
		if
			hinge
			and door.state
			and math.abs(hinge.Y - to.Y) < 8
			and gap(to, size, Vector3.new(hinge.X, to.Y + 1, hinge.Z)) < DOOR_LENGTH + P.DoorClear
		then
			if door.open then
				local at = door.state.value
				if self:_doorRoom(piece, to, door, at) < at - 1 and self:_doorRoom(piece, from, door, at) >= at - 1 then
					return false
				end
			else
				local room = self:_doorRoom(piece, to, door, D.OpenAngle)
				if
					room < D.PassAngle
					and room < self:_doorRoom(piece, from, door, D.OpenAngle)
					and not self:_barsAt(piece, to, door.seamId)
				then
					return false
				end
			end
		end
	end
	return true
end

-- How far a door could swing open (up to `upto` degrees) with the piece at
-- `frame` in the way.
function PushService:_doorRoom(piece, frame: CFrame, door, upto: number): number
	local shut = door.closedCFrame.Position - door.hinge
	local best = upto
	for _, point in Barricade.edgePoints(footprint(frame, piece.size), 0.5) do
		local stop = Articulation.sweepStop(
			{ x = shut.X, z = shut.Z },
			{ x = point.x - door.hinge.X, z = point.z - door.hinge.Z },
			DOOR_LENGTH,
			0.25,
			0,
			upto
		)
		if stop and stop < best then
			best = stop
		end
	end
	return best
end

-- Where a door swinging open from `from` to `to` stops against pushable
-- furniture in its way (Services/DoorService), or nil.
function PushService:SwingStop(door, from: number, to: number): number?
	if to <= from or not door.hinge then
		return nil
	end
	local shut = door.closedCFrame.Position - door.hinge
	local best = nil
	for _, piece in self.pieces do
		local frame = piece.prop.frame
		if
			piece.model.Parent
			and math.abs(frame.Y - door.hinge.Y) < 8
			and gap(frame, piece.size, Vector3.new(door.hinge.X, frame.Y + 1, door.hinge.Z)) < DOOR_LENGTH + 0.5
		then
			for _, point in Barricade.edgePoints(footprint(frame, piece.size), 0.5) do
				local stop = Articulation.sweepStop(
					{ x = shut.X, z = shut.Z },
					{ x = point.x - door.hinge.X, z = point.z - door.hinge.Z },
					DOOR_LENGTH,
					0.25,
					from,
					to
				)
				if stop and (best == nil or stop < best) then
					best = stop
				end
			end
		end
	end
	return best
end

-- Barricades -------------------------------------------------------------------------

-- Whether the piece, standing at `frame`, bars a doorway: across its lane or
-- on his walking points (Logic/Barricade), or keeping its shut door from
-- opening far enough to walk through.
function PushService:_barsAt(piece, frame: CFrame, seamId: string): boolean
	local world = self.World.World
	local seam = world and world.seams[seamId]
	-- Only a real doorway (a solid wall between rooms has walking points too,
	-- for the day it becomes a doorway: those stay clear).
	if not seam or not seam.connected or piece.weight < B.MinWeight or math.abs(frame.Y - seam.floorPosition.Y) > 4 then
		return false
	end
	if Barricade.bars((laneOf(seam, frame.Position)), footprint(frame, piece.size), B) then
		return true
	end
	local door = seam.door
	return door ~= nil
		and door.state ~= nil
		and not door.open
		and gap(frame, piece.size, Vector3.new(door.hinge.X, frame.Y + 1, door.hinge.Z)) < DOOR_LENGTH + 0.5
		and self:_doorRoom(piece, frame, door, D.OpenAngle) < D.PassAngle
end

-- Which doorways it bars where it stands now; who may pass each that changed
-- changes (WorldService:SeamCost reads seam.barricades).
function PushService:_refreshBars(piece)
	local world = self.World.World
	if not world then
		return
	end
	local frame = piece.prop.frame
	local now = {}
	if piece.weight >= B.MinWeight then
		for id, seam in world.seams do
			local p = seam.floorPosition
			if
				math.abs(p.Y - frame.Y) < 4
				and flat(p - frame.Position).Magnitude < 14
				and self:_barsAt(piece, frame, id)
			then
				now[id] = true
			end
		end
	end
	for id in piece.barring do
		if not now[id] then
			self:_setBar(piece, world.seams[id], false)
		end
	end
	for id in now do
		if not piece.barring[id] then
			self:_setBar(piece, world.seams[id], true)
		end
	end
end

function PushService:_setBar(piece, seam, on: boolean)
	seam.barricades = seam.barricades or {}
	if on then
		local _, side = laneOf(seam, piece.prop.frame.Position)
		piece.barring[seam.id] = true
		seam.barricades[piece.id] = { piece = piece, side = side }
	else
		piece.barring[seam.id] = nil
		seam.barricades[piece.id] = nil
	end
	self:_squeezePrompt(seam)
	self.World:MarkPassageChanged(seam.id, "barricade")
end

-- How far into the room on its side a barricade reaches (from the wall line).
function PushService:Depth(piece, seam): number
	local frame = piece.prop.frame
	local _, _, _, vmax = Barricade.extent((laneOf(seam, frame.Position)), footprint(frame, piece.size))
	return vmax
end

-- How near a point is to a piece's footprint (flat).
function PushService:Gap(piece, point: Vector3): number
	return (gap(piece.prop.frame, piece.size, point))
end

-- Somewhere to stand clear of everything (a body's room), on the floor at `spot`.
function PushService:_standable(spot: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local box = CFrame.new(spot + Vector3.new(0, 3, 0))
	for _, hit in Workspace:GetPartBoundsInBox(box, Vector3.new(2.4, 4.6, 2.4), params) do
		if hit.CollisionGroup ~= Groups.Prop and hit.CollisionGroup ~= Groups.Held and not isCharacter(hit) then
			return false
		end
	end
	return true
end

-- Where someone at `from` comes out squeezing past a barred doorway: just
-- through it, or past what bars the far side. nil if there's no room.
function PushService:SqueezeSpot(seam, from: Vector3): Vector3?
	local n = flat(seam.normal).Unit
	local to = (from - seam.floorPosition):Dot(n) >= 0 and -1 or 1
	local into = n * to
	local depth = 2.5
	for _, entry in seam.barricades or {} do
		if entry.side == to and entry.piece.model.Parent then
			depth = math.max(depth, self:Depth(entry.piece, seam) + 1.8)
		end
	end
	local along = Vector3.new(-into.Z, 0, into.X)
	for _, v in { depth, depth + 1.5, depth + 3 } do
		for _, u in { 0, 1.5, -1.5, 3, -3 } do
			local spot = seam.floorPosition + into * v + along * u
			if self.World:RoomAt(spot + Vector3.new(0, 1, 0)) and self:_standable(spot) then
				return spot
			end
		end
	end
	return nil
end

-- A barred doorway has a prompt to squeeze past, on either side.
function PushService:_squeezePrompt(seam)
	local barred = seam.barricades ~= nil and next(seam.barricades) ~= nil
	if barred and not seam.squeeze then
		local anchor = Instance.new("Part")
		anchor.Name = "Squeeze"
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(seam.floorPosition + Vector3.new(0, 3, 0))
		anchor.Parent = self.World.content or Workspace
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SqueezePrompt"
		prompt.ActionText = "Squeeze past"
		prompt.ObjectText = "Barricade"
		-- Its own key: Roblox shows one prompt per key, and the doorway's door
		-- (E, and LB to brace) and the piece's own drawers and doors are right
		-- here. Q is otherwise only a crank's ratchet or a dumbwaiter's jam.
		prompt.KeyboardKeyCode = Enum.KeyCode.Q
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonR3
		prompt.HoldDuration = B.SqueezeSeconds
		prompt.MaxActivationDistance = B.SqueezeReach
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			self:_squeeze(player, seam)
		end)
		seam.squeeze = anchor
	elseif not barred and seam.squeeze then
		seam.squeeze:Destroy()
		seam.squeeze = nil
	end
end

function PushService:_squeeze(player: Player, seam)
	if not seam.barricades or not next(seam.barricades) or not self.PlayerState:CanAct(player) then
		return
	end
	local root = self.PlayerState:Root(player)
	if not root or flat(root.Position - seam.floorPosition).Magnitude > B.SqueezeReach + 3 then
		return
	end
	local spot = self:SqueezeSpot(seam, root.Position)
	if not spot then
		return
	end
	local into = flat(spot - seam.floorPosition)
	local at = spot + Vector3.new(0, 3, 0)
	self.PlayerState:MarkTeleport(player)
	root.CFrame = CFrame.lookAt(at, at + (into.Magnitude > 0.1 and into.Unit or root.CFrame.LookVector))
	self.Noise:Emit(seam.floorPosition, B.SqueezeNoise, player, "scrape")
	Sfx.play("CreakAlt", seam.floorPosition, 0.5, 0.8)
end

-- The Guest shoves a barricade clear of the doorway (Stalker/Walker), from
-- where he stands. Returns whether it moved: false when every way is blocked.
function PushService:Shove(piece, seam, from: Vector3): boolean
	if not piece.model.Parent or piece.shoving or not seam then
		return false
	end
	self:_gather(piece)
	local frame = piece.prop.frame
	local lane, side = laneOf(seam, frame.Position)
	local mine = (from - seam.floorPosition):Dot(flat(seam.normal).Unit) >= 0 and 1 or -1
	local along = Vector3.new(-lane.iz, 0, lane.ix)
	local into = Vector3.new(lane.ix, 0, lane.iz)
	for _, scale in { 1, 1.4, 2 } do
		for _, shove in Barricade.shoves(lane, footprint(frame, piece.size), mine ~= side, B) do
			local step = (along * shove[1] + into * shove[2]) * scale
			if
				step.Magnitude > 0.05
				and not self:_barsAt(piece, frame + step, seam.id)
				and self:_clearAlong(piece, frame, step)
			then
				self:_slide(piece, step)
				return true
			end
		end
	end
	return false
end

-- Nothing in the way of a shove, every stud of it.
function PushService:_clearAlong(piece, from: CFrame, step: Vector3): boolean
	local size = piece.size
	local already = solids(piece, from)
	local count = math.max(1, math.ceil(step.Magnitude))
	for i = 1, count do
		for hit in solids(piece, from + step * (i / count)) do
			if not already[hit] then
				return false
			end
		end
	end
	local to = from + step
	for _, body in self:_bodies() do
		if over(to, size, body, 0.7) and not over(from, size, body, 0.7) then
			return false
		end
	end
	return self:_keepsClear(piece, from, to, size)
end

-- It goes over in a heave, loud.
function PushService:_slide(piece, step: Vector3)
	piece.shoving = true
	piece.velocity = Vector3.zero
	local at = piece.prop.frame.Position
	self.Noise:Emit(at, B.BangNoise, nil, "lure")
	Sfx.play("CreakAlt", at, 0.9, 0.5)
	Sfx.play("Thud", at, 0.8, 0.8)
	task.spawn(function()
		local count = math.max(4, math.ceil(B.ShoveTime * 30))
		for _ = 1, count do
			if not piece.model.Parent then
				break
			end
			self:_move(piece, step / count)
			task.wait(B.ShoveTime / count)
		end
		piece.shoving = nil
		if piece.model.Parent then
			self.Furniture:Settle(piece.model)
			for _, rider in piece.riders do
				self.Furniture:Settle(rider)
			end
		end
	end)
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
	if not self:_keepsClear(piece, from, to, size) then
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
			-- A box or case riding along: its lid's hinge goes too.
			self.Furniture:Shift(rider, step)
		end
	end
	piece.prop.frame += step
	self.Furniture:Shift(piece.model, step)
	self:_refreshBars(piece)
end

-- F2 `barricade`: list what bars which doorway; `barricade here [piece]` puts
-- the nearest heavy piece (or the one named, from anywhere) across the
-- nearest doorway on your side; `barricade
-- squeeze` squeezes you past the nearest barricade (as its prompt does);
-- `barricade shove` has him shove it, as if from where you stand; `barricade
-- scan` checks every piece against every doorway.
function PushService:DebugBarricade(player: Player, mode: string?, pieceId: string?): string
	local world = self.World.World
	local root = self.PlayerState:Root(player)
	if not world or not root then
		return "no house"
	end
	local here = root.Position
	local nearest, best = nil, 12
	for _, seam in world.seams do
		local d = (seam.floorPosition + Vector3.new(0, 3, 0) - here).Magnitude
		local wanted = seam.connected
			and ((mode ~= "shove" and mode ~= "squeeze") or (seam.barricades and next(seam.barricades)))
		if wanted and d < best then
			nearest, best = seam, d
		end
	end
	if mode == "here" then
		if not nearest then
			return "no doorway within 12 studs"
		end
		local lane = laneOf(nearest, here)
		local into = Vector3.new(lane.ix, 0, lane.iz)
		local along = Vector3.new(-lane.iz, 0, lane.ix)
		local chosen, closest = self.pieces[pieceId or ""], 18
		for _, piece in chosen and {} or self.pieces do
			local d = gap(piece.prop.frame, piece.size, nearest.floorPosition)
			local sameSide = (piece.prop.frame.Position - nearest.floorPosition):Dot(into) > 0
			if piece.weight >= B.MinWeight and sameSide and d < closest and not self:_occupied(piece) then
				chosen, closest = piece, d
			end
		end
		if not chosen then
			return "no heavy piece within 18 studs on your side"
		end
		local frame = chosen.prop.frame
		local umin, umax, vmin = Barricade.extent(lane, footprint(frame, chosen.size))
		local step = along * -((umin + umax) / 2) + into * (0.7 - vmin)
		local to = frame + step
		local already = solids(chosen, frame)
		for hit in solids(chosen, to) do
			if not already[hit] then
				return string.format(
					"%s won't fit across that doorway (%s is in the way)",
					chosen.id,
					hit:GetFullName()
				)
			end
		end
		self:_gather(chosen)
		self:_move(chosen, step)
		self.Furniture:Settle(chosen.model)
		return string.format(
			"%s across %s: bars it %s, cost to a player %s, to him %s",
			chosen.id,
			nearest.id,
			tostring(chosen.barring[nearest.id] == true),
			tostring(self.World:SeamCost(nearest.id, "player")),
			tostring(self.World:SeamCost(nearest.id, "guest"))
		)
	elseif mode == "squeeze" then
		-- As if you held the doorway's prompt.
		if not nearest then
			return "no barricade within 12 studs"
		end
		self:_squeeze(player, nearest)
		local at = root.Position
		return string.format("from (%.1f, %.1f) to (%.1f, %.1f)", here.X, here.Z, at.X, at.Z)
	elseif mode == "scan" then
		-- Every heavy piece against every doorway, where it stands now.
		local count, lines = 0, {}
		for _, piece in self.pieces do
			for id, seam in world.seams do
				if self:_barsAt(piece, piece.prop.frame, id) then
					count += 1
					table.insert(lines, piece.id .. " bars " .. id .. (seam.door and " (door)" or ""))
				end
			end
		end
		return count == 0 and "nothing bars any doorway" or table.concat(lines, "\n")
	elseif mode == "shove" then
		if not nearest then
			return "no barricade within 12 studs"
		end
		local lines = {}
		for _, entry in table.clone(nearest.barricades) do
			table.insert(
				lines,
				entry.piece.id .. (self:Shove(entry.piece, nearest, here) and " shoved" or " won't move")
			)
		end
		return table.concat(lines, "; ")
	end
	local lines = {}
	for id, seam in world.seams do
		if seam.barricades and next(seam.barricades) then
			local ids = {}
			for pieceId, entry in seam.barricades do
				table.insert(ids, pieceId .. (entry.side > 0 and " (b side)" or " (a side)"))
			end
			table.insert(lines, string.format("%s (%d-%d): %s", id, seam.a, seam.b, table.concat(ids, ", ")))
		end
	end
	return #lines > 0 and table.concat(lines, "\n") or "no doorway is barricaded"
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
