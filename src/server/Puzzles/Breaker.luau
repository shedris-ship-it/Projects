-- The fuse box (docs/plans/gameplay-rework.md section 7; R2c): a grey panel
-- on the wall of a service room, its breakers feeding real rooms (Logic/
-- Circuits). Flip one and a stretch of the house goes dark or lights up;
-- put on more than the panel can carry and the main trips: every light out,
-- a loud clunk he hears from you. A door with an electric lock is on one of
-- the breakers: give it power and it opens for good (tripping later never
-- locks it again). Rules: Logic/Puzzles/Breaker.
--
-- Co-op, one at the panel and one at the door calling out its lamp; solo,
-- a note somewhere already open says which breaker is the door's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Breaker = require(Shared.Logic.Puzzles.Breaker)
local Circuits = require(Shared.Logic.Circuits)
local Config = require(Shared.Config)
local Marks = require(Shared.Data.Marks)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local RoomRects = require(Shared.Logic.RoomRects)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local B = Config.Breaker
local part = PropFactory.part
local STEEL = Color3.fromRGB(110, 116, 112)

local Kind = {
	label = "Fuse box",
	-- Still worked after the door has power: the lights are yours to play with.
	reusable = true,
	done = "",
}

-- Every room of the house, for Logic/Circuits.
local function roomsOf(world)
	local o = Config.Level.Origin
	local list = {}
	for _, rect in RoomRects.ofLayout(world.layout, Config.Level) do
		local record = world.rooms[rect.id]
		table.insert(list, {
			id = rect.id,
			floor = rect.floor or 0,
			x = o.x + rect.x + rect.w / 2,
			z = o.z + rect.z + rect.d / 2,
			name = record.name,
			corridor = record.template.family == "corridor",
		})
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function Kind.create(service, id: string, puzzle)
	local world = service.World.World
	local plan = service.plan
	local rng = Rng.new(puzzle.seed)
	local wiring = Circuits.plan(roomsOf(world), world.layout.start, world.layout.deliberation, rng:Fork("circuits"), B)
	-- The door it powers: the gate whose token this panel makes.
	local seamId, inside, mark
	for _, token in plan.tokens do
		if token.producer.kind == "puzzle" and token.producer.id == id and token.opens then
			seamId = token.opens
			inside = plan.locks[seamId] and plan.locks[seamId].inside
			mark = token.mark and Marks.ById[token.mark]
		end
	end
	local gate = inside and wiring.roomCircuit[inside] or 2
	-- Its breaker is labelled by the door's mark, as the door's plate is (the
	-- room behind it is one nobody has seen: docs/plans/level-design.md 11).
	local gateName = mark and (mark.glyph .. " " .. string.upper(mark.name) .. " DOOR")
		or string.upper(inside and service.World:Room(inside).name or "DOOR")
	-- Labels: each breaker's own, never another's by mistake (the planted
	-- mistakes are Breaker.generate's).
	local labels, used = {}, {}
	for i, circuit in wiring.circuits do
		local label = circuit.label
		if i ~= gate and (label == gateName or used[label]) then
			label = "LIGHTS " .. i
		end
		used[label] = true
		labels[i] = label
	end
	local spec = Breaker.generate(rng:Fork("panel"), {
		labels = labels,
		gate = gate,
		gateName = gateName,
		capacity = rng:NextInteger(B.Capacity[1], B.Capacity[2]),
		smudge = B.SmudgeChance,
		decoy = B.DecoyChance,
	})
	local session = {
		id = id,
		kind = "breaker",
		spec = spec,
		state = Breaker.start(spec),
		room = puzzle.room,
		circuits = wiring.circuits,
		seam = seamId,
		reach = 8,
	}
	Kind.build(service, session, puzzle.room, rng:Fork("place"))
	Kind.lights(service, session)
	if seamId then
		service.Locks:SetPowered(seamId, false)
	end
	Kind.hint(service, session, rng:Fork("hint"))
	return session
end

-- A grey steel box on a wall of its room, its door open on the breakers.
function Kind.build(service, session, roomId: number, rng)
	local world = service.World
	local slot = world:TakeWallSlot(roomId, rng)
	local cf
	if slot then
		-- Wall slots face out of the wall; a little lower than a picture.
		cf = slot.cframe * CFrame.new(0, -1.2, 0) * CFrame.Angles(0, math.pi, 0)
	else
		local at = world:Room(roomId).center
		cf = CFrame.new(at.X, world:FloorBase(at.Y) + 4.6, at.Z)
	end
	local model = Instance.new("Model")
	model.Name = "FuseBox"
	local metal = PropFactory.material("Metal")
	local face = part(model, "Box", Vector3.new(1.8, 2.4, 0.4), cf * CFrame.new(0, 0, 0.2), STEEL, metal)
	part(
		model,
		"Inside",
		Vector3.new(1.6, 2.2, 0.02),
		cf * CFrame.new(0, 0, 0.41),
		Color3.fromRGB(40, 42, 40),
		metal,
		{ collide = false, castShadow = false }
	)
	-- The door, swung open beside it.
	part(
		model,
		"Door",
		Vector3.new(0.06, 2.4, 1.8),
		cf * CFrame.new(-0.93, 0, 1.3),
		PropFactory.shade(STEEL, 0.9),
		metal,
		{ collide = false }
	)
	for i = 1, math.min(8, session.spec.count) do
		local x = -0.6 + (i - 1) * (1.2 / math.max(1, math.min(8, session.spec.count) - 1))
		part(
			model,
			"Breaker",
			Vector3.new(0.12, 0.3, 0.08),
			cf * CFrame.new(x, 0.3, 0.45),
			Color3.fromRGB(30, 30, 32),
			PropFactory.material("SmoothPlastic"),
			{ collide = false, castShadow = false }
		)
	end
	part(
		model,
		"Main",
		Vector3.new(0.3, 0.45, 0.1),
		cf * CFrame.new(0, -0.6, 0.45),
		Color3.fromRGB(150, 30, 26),
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false }
	)
	model.Parent = world.content
	session.model = model
	session.station = face
	session.front = -cf.LookVector -- into the room (the builder faces +Z out of the wall)
	session.prompt = service:Prompt(session, face, "Open", Kind.label)
end

-- Each circuit's rooms lit or dark as the panel says (WorldService's one
-- light rule: "circuit" for a breaker off, "main" for a tripped main).
function Kind.lights(service, session)
	local state = session.state
	for i, circuit in session.circuits do
		for _, roomId in circuit.rooms do
			service.World:SetLightCause(roomId, "circuit", state.on[i] ~= true)
			service.World:SetLightCause(roomId, "main", state.tripped)
		end
	end
	if session.seam and not session.state.solved then
		service.Locks:SetPowered(session.seam, Breaker.powered(state, session.spec.gate))
	end
end

-- The solo route: a note somewhere already open says which is the door's.
function Kind.hint(service, session, rng)
	local plan = service.plan
	local lock = session.seam and plan.locks[session.seam]
	if not lock then
		return
	end
	local position = { [0] = 0 }
	for i, r in plan.order do
		position[r] = i
	end
	local rooms = {}
	for roomId, region in plan.roomRegion do
		-- (Never in a side room the house key opens: docs/plans/level-design.md 11.)
		local pocket = plan.pockets and plan.pockets[roomId]
		if position[region] < position[lock.region] and roomId ~= session.room and not pocket then
			table.insert(rooms, roomId)
		end
	end
	table.sort(rooms)
	local room = rng:Pick(rooms)
	if not room then
		return
	end
	local items = service.services.ItemService
	-- The door by its mark, as its plate shows it (the room behind it is one
	-- nobody has seen yet).
	local mark = lock.mark and Marks.ById[lock.mark]
	local where = mark and ("the door with the " .. mark.name .. " on it") or (items:RoomPhrase(lock.inside) .. " door")
	local text = string.format(
		"The labels in the fuse box are wrong since your father redid them.\n\nThe lock on %s is number %d.\n\n- Mom",
		where,
		session.spec.gate
	)
	items:AddNote(room, text, rng)
end

function Kind.event(service, session, event, player: Player, position: Vector3)
	if event.kind == "flip" then
		Sfx.play("LockClick", position, 0.5, event.on and 0.8 or 0.65)
		service.Noise:Emit(position, B.FlipNoise, player, "puzzle")
	elseif event.kind == "trip" then
		-- Every light out, and a clunk he hears from you.
		Sfx.play("DoorBang", position, 0.9, 0.5)
		service.Noise:Emit(position, B.TripNoise, player, "puzzle")
		Net.get("Notify"):FireAllClients("A loud clunk somewhere. Every light goes out.", "danger")
	elseif event.kind == "reset" then
		Sfx.play("DoorLatch", position, 0.6, 0.7)
	end
	Kind.lights(service, session)
end

-- The door has power: its lock buzzes open, for good.
function Kind.solved(service, session, player: Player?)
	if session.seam then
		service.Locks:SetPowered(session.seam, true)
		local entry = service.Locks.locks[session.seam]
		if entry and entry.door then
			Sfx.play("LockClick", entry.door.slab.Position, 0.8, 0.5)
		end
		service.Locks:Unlock(session.seam, player, "Somewhere, an electric lock buzzes open.")
	end
end

return Kind
