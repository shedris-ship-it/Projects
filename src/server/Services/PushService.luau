-- Pushing furniture (docs/plans/gameplay-rework.md section 4.6; the owner
-- asked for every piece of furniture to be physical, with varying weights,
-- 2026-10-05). Light pieces are carried like small things (HandsService);
-- the rest are pushed. Data/Physical gives each kind a weight in people and
-- Logic/Push turns how many push it into a speed: one creeps a bed, two move
-- it, a dresser goes slowly for one, the piano wants three.
--
-- A client holding its mouse on a piece sends which way it walks (`Push`,
-- 10 a second). The server checks reach and that they face it, adds up
-- everyone pushing it in the last moment (alone, you push for more: Config.Push.SoloStrength)
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
	self.Stalker = services.StalkerService
	self.Doors = services.DoorService
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
				home = prop.frame, -- where the house put it (a flung piece may land back there)
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

-- A piece standing on a door's own floor (`door.position` is its threshold).
-- Not the floor above: boxes in the attic once held a door below shut, on
-- nothing anyone could see.
local function onDoorFloor(frame: CFrame, door): boolean
	return math.abs(frame.Y - door.position.Y) < 4
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

-- Alone, you push for more than one (Config.Push.SoloStrength): there is
-- nobody to help you creep a bed across a doorway (the Companion is gone,
-- the owner's choice of 2026-10-06).
function PushService:_strength(count: number): number
	if count > 0 and #self.PlayerState:RunPlayers() == 1 then
		return count * (P.SoloStrength or 1)
	end
	return count
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
	local directions, first = {}, nil -- (`first` names the scrape's source)
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
		local strength = self:_strength(#directions)
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
function PushService:_keepsClear(piece, from: CFrame, to: CFrame, size: Vector3, nudge: boolean?): boolean
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
			and onDoorFloor(to, door)
			and gap(to, size, Vector3.new(hinge.X, to.Y + 1, hinge.Z)) < DOOR_LENGTH + P.DoorClear
		then
			local at = door.state.value
			if door.open or at > D.LatchAngle then
				local room = self:_doorRoom(piece, to, door, at)
				if room < at - 1 and self:_doorRoom(piece, from, door, at) >= at - 1 then
					-- It pushes the door shut ahead of it (the owner's solo
					-- playtest, 2026-10-08: a table pushed at an open door
					-- stuck short of it and never blocked it). The door gives
					-- as far as the piece lets it; the piece goes on as it does.
					if nudge then
						self.Doors:Nudge(door, room - 1.5)
					end
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
		local stop = Articulation.sweepStopSigned(
			{ x = shut.X, z = shut.Z },
			{ x = point.x - door.hinge.X, z = point.z - door.hinge.Z },
			DOOR_LENGTH,
			0.25,
			0,
			upto,
			door.openSign
		)
		if stop and stop < best then
			best = stop
		end
	end
	return best
end

-- Where a door swinging open from `from` to `to` stops against pushable
-- furniture in its way (Services/DoorService), or nil.
function PushService:SwingStop(door, from: number, to: number): (number?, any)
	if to <= from or not door.hinge then
		return nil
	end
	local shut = door.closedCFrame.Position - door.hinge
	local best, which = nil, nil
	for _, piece in self.pieces do
		local frame = piece.prop.frame
		if
			piece.model.Parent
			and onDoorFloor(frame, door)
			and gap(frame, piece.size, Vector3.new(door.hinge.X, frame.Y + 1, door.hinge.Z)) < DOOR_LENGTH + 0.5
		then
			for _, point in Barricade.edgePoints(footprint(frame, piece.size), 0.5) do
				local stop = Articulation.sweepStopSigned(
					{ x = shut.X, z = shut.Z },
					{ x = point.x - door.hinge.X, z = point.z - door.hinge.Z },
					DOOR_LENGTH,
					0.25,
					from,
					to,
					door.openSign
				)
				if stop and (best == nil or stop < best) then
					best, which = stop, piece
				end
			end
		end
	end
	return best, which
end

-- Parts fixed to a piece after the house was built (a step's chain or
-- planks, Services/LockService) move with it when it's pushed.
function PushService:Fix(model: Instance, parts: { BasePart })
	for _, piece in self.pieces do
		if piece.model == model then
			for _, p in parts do
				table.insert(piece.parts, p)
			end
			return
		end
	end
end

-- And let go of them (cut off, or pried away).
function PushService:Unfix(parts: { BasePart })
	local gone = {}
	for _, p in parts do
		gone[p] = true
	end
	for _, piece in self.pieces do
		for i = #piece.parts, 1, -1 do
			if gone[piece.parts[i]] then
				table.remove(piece.parts, i)
			end
		end
	end
end

-- Any piece close enough to a door's hinge to be in its swing, either way
-- (DoorService only turns a door's swing round with none: barricades are
-- read against the swing as it is).
function PushService:NearDoor(door): boolean
	if not door.hinge then
		return false
	end
	for _, piece in self.pieces do
		local frame = piece.prop.frame
		if
			piece.model.Parent
			and onDoorFloor(frame, door)
			and gap(frame, piece.size, Vector3.new(door.hinge.X, frame.Y + 1, door.hinge.Z)) < DOOR_LENGTH + 0.5
		then
			return true
		end
	end
	return false
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
		-- Pushed into place: it lands against the doorway with a thud, and
		-- whoever pushed it is told it's barred (the owner's solo playtest,
		-- 2026-10-08, couldn't tell whether the table blocked the door).
		local told = false
		for player in piece.pushers do
			if player.Parent then
				Net.get("Notify"):FireClient(player, "The doorway's barred.", "good")
				told = true
			end
		end
		if told then
			Sfx.play("Thud", seam.floorPosition + Vector3.new(0, 2, 0), 0.7, 0.85)
		end
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
	local step = self:_shoveStep(piece, seam, from)
	if not step then
		return false
	end
	self:_slide(piece, step)
	return true
end

-- How far a shove from `from` moves it clear of the doorway, or nil if every
-- way is blocked.
function PushService:_shoveStep(piece, seam, from: Vector3): Vector3?
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
				return step
			end
		end
	end
	return nil
end

-- He's at the barricade (Stalker/Walker), banging to get through: each blow
-- louder as he nears the end of his patience (`progress` 0 to 1). The pieces
-- shudder in the doorway, the door rattles in its frame, and everyone near
-- feels it (Controllers/GuestController: the view shakes, the lights blink).
function PushService:Bang(seam, progress: number)
	local entries = seam and seam.barricades
	if not entries then
		return
	end
	local at = seam.floorPosition + Vector3.new(0, 3.5, 0)
	local F = B.Fling
	local strength = F.BangStrength[1] + (F.BangStrength[2] - F.BangStrength[1]) * math.clamp(progress, 0, 1)
	Sfx.play("DoorBang", at, math.min(1, 0.7 + strength * 0.3), 0.85 - strength * 0.2)
	Sfx.play("Thud", at, 0.6 + strength * 0.3, 0.7)
	self.Noise:Emit(at, B.BangNoise * (1 + strength), nil, "slam")
	for _, entry in entries do
		local piece = entry.piece
		if piece.model.Parent and not piece.shoving then
			-- A shudder into the room and back: seen, not moved.
			local lane = laneOf(seam, piece.prop.frame.Position)
			local jolt = Vector3.new(lane.ix, 0, lane.iz) * (0.12 + 0.18 * strength)
			local before = table.create(#piece.parts)
			local after = table.create(#piece.parts)
			for i, p in piece.parts do
				before[i] = p.CFrame
				after[i] = p.CFrame + jolt
			end
			Workspace:BulkMoveTo(piece.parts, after, Enum.BulkMoveMode.FireCFrameChanged)
			task.delay(0.09, function()
				if piece.model.Parent and not piece.shoving then
					Workspace:BulkMoveTo(piece.parts, before, Enum.BulkMoveMode.FireCFrameChanged)
				end
			end)
		end
	end
	local door = seam.door
	if door and door.state and not door.open and not door.locked then
		self.Doors:Rattle(door, 2 + 4 * strength)
	end
	Net.get("GuestEvent"):FireAllClients({ kind = "bang", position = at, strength = strength })
end

-- He bursts through (the owner's solo playtest, 2026-10-08: "when he's
-- trying to get through a door that's blocked he bangs on it really hard and
-- loudly and after a delay the door flies open and the furniture blocking it
-- flies across the room"). Each piece barring `seam` is flung away from him
-- into its room, to a spot it can fairly land on: clear of walls and other
-- furniture, of every doorway and of his walking points, on the same floor,
-- never on anyone. Anyone in its path is knocked back (the owner's choice:
-- knocked back and staggered, never downed). One with nowhere to land is
-- shoved clear as before. Then the door slams open. Returns whether every
-- piece moved.
function PushService:Burst(seam, from: Vector3): boolean
	local entries = seam and seam.barricades
	if not entries then
		return false
	end
	local all = true
	local pieces = {}
	for _, entry in entries do
		table.insert(pieces, entry.piece)
	end
	for _, piece in pieces do
		if not self:_fling(piece, seam, from) and not self:Shove(piece, seam, from) then
			all = false
		end
	end
	local at = seam.floorPosition + Vector3.new(0, 3.5, 0)
	Sfx.play("DoorSlam", at, 1, 0.8)
	Sfx.play("Thud", at, 1, 0.6)
	self.Noise:Emit(at, B.BangNoise * 2.5, nil, "slam")
	Net.get("GuestEvent"):FireAllClients({ kind = "burst", position = at })
	local door = seam.door
	if door then
		task.delay(0.08, function()
			if not door.open and not door.locked then
				self.Doors:SetOpen(door, true, nil, true)
			end
		end)
	end
	return all
end

-- Where a flung piece lands: away from him into its room, as far as its
-- weight lets it fly, turning aside if it must; or back where the house
-- first put it (always fair, unless something stands there now). Nil if
-- nowhere will do.
function PushService:_landing(piece, seam, from: Vector3): Vector3?
	local world = self.World.World
	local F = B.Fling
	local frame = piece.prop.frame
	local lane = laneOf(seam, frame.Position)
	local into = Vector3.new(lane.ix, 0, lane.iz)
	-- Away from him, mostly into the room.
	local away = flat(frame.Position - from)
	local dir = (away.Magnitude > 0.1 and (away.Unit + into * 2) or into).Unit
	local heavy = math.clamp((piece.weight - 1) / 2, 0, 1)
	local reach = F.Distance[2] + (F.Distance[1] - F.Distance[2]) * heavy
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { piece.model, table.unpack(piece.riders) }
	local bodies = self:_bodies()
	local function fits(to: CFrame): boolean
		if next(solids(piece, to)) ~= nil then
			return false
		end
		-- Not through a wall: a ray at waist height to where it lands meets
		-- nothing but furniture (it flies over that).
		local start = frame.Position + Vector3.new(0, 1.5, 0)
		local hit = Workspace:Raycast(start, to.Position + Vector3.new(0, 1.5, 0) - start, params)
		if hit and hit.Instance.CollisionGroup ~= Groups.Heavy and not isCharacter(hit.Instance) then
			return false
		end
		-- On a floor (not over the stairs or the hall's gallery).
		local down = Workspace:Raycast(to.Position + Vector3.new(0, 1, 0), Vector3.new(0, -2.5, 0), params)
		if not down or math.abs(down.Position.Y - frame.Y) > 0.6 then
			return false
		end
		for _, body in bodies do
			if over(to, piece.size, body, 0.7) then
				return false
			end
		end
		-- Never across any doorway, or on his walking points.
		for id, other in world.seams do
			if
				other.connected
				and math.abs(other.floorPosition.Y - frame.Y) < 4
				and flat(other.floorPosition - to.Position).Magnitude < 14
				and self:_barsAt(piece, to, id)
			then
				return false
			end
		end
		for _, node in piece.navNear or {} do
			if over(to, piece.size, node.p, P.KeepClear) then
				return false
			end
		end
		return true
	end
	for _, turn in F.Turns do
		local heading = CFrame.Angles(0, math.rad(turn), 0):VectorToWorldSpace(dir)
		local distance = reach
		while distance >= F.Distance[1] do
			local to = frame + heading * distance
			if fits(to) then
				return to.Position
			end
			distance -= 1
		end
	end
	local home = piece.home
	if home and flat(home.Position - frame.Position).Magnitude >= 2 and math.abs(home.Y - frame.Y) < 0.5 then
		local to = CFrame.new(home.X, frame.Y, home.Z) * frame.Rotation
		if fits(to) then
			return to.Position
		end
	end
	return nil
end

-- Fling a piece clear of the doorway (Burst): it flies in an arc, tipping as
-- it goes, and lands square where _landing said. Riders go with it.
function PushService:_fling(piece, seam, from: Vector3): boolean
	if not piece.model.Parent or piece.shoving or self:_occupied(piece) then
		return false
	end
	self:_gather(piece)
	local frame = piece.prop.frame
	local landing = self:_landing(piece, seam, from)
	-- Nowhere far: it still flies, as far as a shove would take it.
	local step = landing and Vector3.new(landing.X - frame.X, 0, landing.Z - frame.Z)
		or self:_shoveStep(piece, seam, from)
	if not step or step.Magnitude < 0.05 then
		return false
	end
	local F = B.Fling
	-- A short throw stays low.
	local height = F.Height * math.clamp(step.Magnitude / F.Distance[2], 0.35, 1)
	local heading = step.Unit
	local axis = heading:Cross(Vector3.yAxis)
	local centre = frame.Position + Vector3.new(0, piece.size.Y / 2, 0)
	piece.shoving = true
	piece.velocity = Vector3.zero
	-- Everything that flies, where it started.
	local parts = table.clone(piece.parts)
	for _, rider in piece.riders do
		for _, d in rider:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end
	local starts = table.create(#parts)
	for i, p in parts do
		starts[i] = p.CFrame
	end
	self:_knock(piece, frame.Position, step)
	task.spawn(function()
		local began = os.clock()
		while true do
			local t = math.clamp((os.clock() - began) / F.Seconds, 0, 1)
			if not piece.model.Parent then
				break
			end
			-- Up and over, tipping forward and back down square.
			local lift = 4 * height * t * (1 - t)
			local tip = math.sin(math.pi * t) * F.Tip
			local move = CFrame.new(centre + step * t + Vector3.new(0, lift, 0))
				* CFrame.fromAxisAngle(axis, -tip)
				* CFrame.new(-centre)
			local cframes = table.create(#parts)
			for i, start in starts do
				cframes[i] = move * start
			end
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		-- Square where it landed: put everything back where it started and
		-- move it there the usual way (its hiding spots, riders, joints and
		-- what it bars all follow).
		if piece.model.Parent then
			Workspace:BulkMoveTo(parts, starts, Enum.BulkMoveMode.FireCFrameChanged)
			self:_move(piece, step)
			self.Furniture:Settle(piece.model)
			for _, rider in piece.riders do
				self.Furniture:Settle(rider)
			end
			local at = piece.prop.frame.Position
			Sfx.play("Thud", at, 1, 0.7)
			Sfx.play("CreakAlt", at, 0.8, 0.55)
		end
		piece.shoving = nil
	end)
	return true
end

-- Anyone in a flung piece's path (and on its floor) is knocked aside out of
-- it, and staggered, the moment its leading edge reaches them (Controllers/
-- ActionController). Aside, not along: along it, it would land on them.
function PushService:_knock(piece, from: Vector3, step: Vector3)
	local F = B.Fling
	local length = step.Magnitude
	local heading = step.Unit
	local reach = math.max(piece.size.X, piece.size.Z) / 2 + F.KnockMargin
	-- How far its leading edge is ahead of its middle, flying this way.
	local frame = piece.prop.frame
	local lead = math.abs(heading:Dot(frame.RightVector)) * piece.size.X / 2
		+ math.abs(heading:Dot(frame.LookVector)) * piece.size.Z / 2
	for _, player in Players:GetPlayers() do
		local root = self.PlayerState:Root(player)
		if root and self.PlayerState:IsActive(player) and math.abs(root.Position.Y - from.Y - 3) < 4 then
			local offset = flat(root.Position - from)
			local along = offset:Dot(heading)
			local side = offset - heading * along
			if along > -0.5 and along < length + reach and side.Magnitude < reach then
				local delay = F.Seconds * math.clamp((along - lead) / math.max(length, 0.1), 0, 1)
				local aside = side.Magnitude > 0.2 and side.Unit or Vector3.new(-heading.Z, 0, heading.X)
				local push = (aside * 0.9 + heading * 0.35).Unit
				task.delay(delay, function()
					if player.Parent and self.PlayerState:IsActive(player) then
						self.PlayerState:MarkTeleport(player)
						Net.get("Knockback"):FireClient(player, push * F.Knock, F.Stagger)
						Sfx.play("Thud", root.Position, 0.9, 1.1)
					end
				end)
			end
		end
	end
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
	if not self:_keepsClear(piece, from, to, size, true) then
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
		if spot.tuckCFrame then
			spot.tuckCFrame += step
		end
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
	elseif mode == "burst" then
		-- As if he were on the far side of the nearest barricade: three
		-- blows, then he bursts through (stand behind it to be knocked back).
		if not nearest then
			return "no barricade within 12 studs"
		end
		local p = nearest.floorPosition
		local from = Vector3.new(2 * p.X - here.X, p.Y, 2 * p.Z - here.Z)
		task.spawn(function()
			for i = 1, 3 do
				self:Bang(nearest, i / 3)
				task.wait(B.BangEvery)
			end
			self:Burst(nearest, from)
		end)
		return "bang, bang, bang, then the burst"
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
