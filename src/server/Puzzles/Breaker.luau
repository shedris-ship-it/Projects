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
--
-- The safe room's steel door (docs/plans/level-design.md section 11.12) is on
-- the panel too, truly labelled "⌂ SAFE ROOM": a second door (`extra`) when
-- the house has an electric lock of its own, else the panel's only one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Breaker = require(Shared.Logic.Puzzles.Breaker)
local Circuits = require(Shared.Logic.Circuits)
local Config = require(Shared.Config)
local Marks = require(Shared.Data.Marks)
local Net = require(Shared.Net)
local Kit = require(Shared.World.Kit)
local PropFactory = require(Shared.World.PropFactory)
local RoomRects = require(Shared.Logic.RoomRects)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local B = Config.Breaker
local part = PropFactory.part
local STEEL = Color3.fromRGB(110, 116, 112)
local D = Config.Devices.FuseBox

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

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
	-- The door it powers: the gate whose token this panel makes; and the safe
	-- room's, if it's on this panel.
	local seamId, inside, mark
	local safeSeam, safeInside = nil, nil
	for _, token in plan.tokens do
		if token.producer.kind == "puzzle" and token.producer.id == id and token.opens then
			if token.optional then
				safeSeam = token.opens
				safeInside = plan.locks[safeSeam] and plan.locks[safeSeam].inside
			else
				seamId = token.opens
				inside = plan.locks[seamId] and plan.locks[seamId].inside
				mark = token.mark and Marks.ById[token.mark]
			end
		end
	end
	local safeName = "⌂ SAFE ROOM"
	local onlySafe = seamId == nil and safeSeam ~= nil
	if onlySafe then
		-- The panel's only door is the safe room's: no riddle in its label.
		seamId, inside = safeSeam, safeInside
		safeSeam = nil
	end
	local gate = inside and wiring.roomCircuit[inside] or 2
	-- Its breaker is labelled by the door's mark, as the door's plate is (the
	-- room behind it is one nobody has seen: docs/plans/level-design.md 11).
	local gateName = onlySafe and safeName
		or mark and (mark.glyph .. " " .. string.upper(mark.name) .. " DOOR")
		or string.upper(inside and service.World:Room(inside).name or "DOOR")
	-- The safe room's breaker: its room's circuit, or another than the door's.
	local extra = nil
	if safeSeam then
		local index = safeInside and wiring.roomCircuit[safeInside]
		if not index or index == gate then
			index = gate == #wiring.circuits and 2 or #wiring.circuits
		end
		if index ~= gate and index >= 2 then
			extra = { index = index, name = safeName }
		else
			safeSeam = nil
		end
	end
	-- Labels: each breaker's own, never another's by mistake (the planted
	-- mistakes are Breaker.generate's).
	local labels, used = {}, {}
	for i, circuit in wiring.circuits do
		local label = circuit.label
		if i ~= gate and (label == gateName or label == safeName or used[label]) then
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
		smudge = onlySafe and 0 or B.SmudgeChance,
		decoy = onlySafe and 0 or B.DecoyChance,
		extra = extra,
		plate = B.PlateAtDoor and not onlySafe,
	})
	local session = {
		id = id,
		kind = "breaker",
		spec = spec,
		state = Breaker.start(spec),
		room = puzzle.room,
		circuits = wiring.circuits,
		seam = seamId,
		safeSeam = safeSeam,
		-- (Only the safe room's: the line says so, so nobody thinks it's needed.)
		optional = onlySafe or nil,
		reach = 8,
	}
	Kind.build(service, session, puzzle.room, rng:Fork("place"))
	Kind.lights(service, session)
	if seamId then
		service.Locks:SetPowered(seamId, false)
		-- The labels live on a plate by the door it powers (Config.Breaker.PlateAtDoor).
		if spec.plate then
			service.Locks:SetPlateText(seamId, Breaker.plateText(spec))
		end
	end
	if safeSeam then
		service.Locks:SetPowered(safeSeam, false)
	end
	if not onlySafe then
		Kind.hint(service, session, rng:Fork("hint"))
	end
	return session
end

-- A grey steel box on a wall of its room, its door open on the breakers.
function Kind.build(service, session, roomId: number, rng)
	local world = service.World
	-- (The box, and its door swung open beside it.)
	local slot = world:WallSpot(roomId, rng, Vector3.new(2.8, 2.6, 2), 1.2)
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
	local count = math.min(8, session.spec.count)
	local xs = {}
	for i = 1, count do
		local x = -0.6 + (i - 1) * (1.2 / math.max(1, count - 1))
		xs[i] = x
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
	-- The modelled box first (it hides the grey-box), then each breaker's
	-- body and toggle and the main switch (Data/Kit; Kind.show tips them).
	Kit.dressThing(model, "FuseBox", cf)
	local plastic = PropFactory.material("SmoothPlastic")
	local lamp = { collide = false, castShadow = false, shape = Enum.PartType.Ball, query = false }
	session.toggles = {}
	session.pilots = {}
	for i, x in xs do
		Kit.place(model, "BreakerModule", cf * CFrame.new(x, 0.3, 0.41))
		local pivot = cf * CFrame.new(x, 0.3, 0.45)
		local toggle = Kit.place(model, "BreakerToggle", pivot * CFrame.Angles(math.rad(D.Tilt[1]), 0, 0))
		if toggle then
			session.toggles[i] = { mesh = toggle, pivot = pivot }
		end
		-- Its lamp over it: lit while it's on.
		session.pilots[i] = part(
			model,
			"Pilot",
			Vector3.new(0.07, 0.07, 0.07),
			cf * CFrame.new(x, 0.62, 0.42),
			rgb(D.PilotOff),
			plastic,
			lamp
		)
	end
	local mainPivot = cf * CFrame.new(0, -0.6, 0.43)
	local main = Kit.place(model, "MainSwitch", mainPivot * CFrame.Angles(math.rad(D.Tilt[1]), 0, 0))
	session.mainSwitch = main and { mesh = main, pivot = mainPivot } or nil
	session.mainLamp = part(
		model,
		"MainLamp",
		Vector3.new(0.09, 0.09, 0.09),
		cf * CFrame.new(0.32, -0.6, 0.42),
		rgb(D.Main),
		plastic,
		lamp
	)
	-- The open panel's warm glow on the wall round it and whoever works it
	-- (decoration: the rooms its breakers light are WorldService's).
	local glow = part(
		model,
		"Glow",
		Vector3.new(0.2, 0.2, 0.2),
		cf * CFrame.new(0, 0.3, 0.9),
		Color3.new(0, 0, 0),
		plastic,
		{ collide = false, castShadow = false, transparency = 1, query = false }
	)
	local light = Instance.new("PointLight")
	light.Name = "PanelGlow"
	light.Color = rgb(D.Glow)
	light.Range = D.GlowRange
	light.Shadows = false
	light.Parent = glow
	session.glow = light
	model.Parent = world.content
	session.model = model
	session.station = face
	session.front = -cf.LookVector -- into the room (the builder faces +Z out of the wall)
	session.prompt = service:Prompt(session, face, "Open", Kind.label)
	-- Alone there is nobody at the door to read the plate: a long hold here
	-- traces the wiring, and the labels show on the panel for a while.
	if session.spec.plate and #service.services.PlayerStateService:RunPlayers() == 1 then
		local trace = Instance.new("ProximityPrompt")
		trace.Name = "TracePrompt"
		trace.ActionText = "Trace the wiring"
		trace.ObjectText = "Fuse box"
		trace.KeyboardKeyCode = Enum.KeyCode.T
		trace.GamepadKeyCode = Enum.KeyCode.ButtonY
		trace.HoldDuration = B.RevealHold
		trace.MaxActivationDistance = 8
		trace.RequiresLineOfSight = false
		trace.UIOffset = Vector2.new(0, 72)
		trace.Parent = face
		trace.Triggered:Connect(function(player)
			if not service.PlayerState:CanAct(player) then
				return
			end
			if Breaker.reveal(session.spec, session.state, os.clock(), B.RevealSeconds) then
				service:Push(session, { { kind = "reveal" } })
				Net.get("Notify"):FireClient(
					player,
					string.format("You trace the wiring. The labels hold in your head for %d seconds.", B.RevealSeconds),
					"info"
				)
			end
		end)
		session.tracePrompt = trace
	end
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
	Kind.show(session)
	if session.safeSeam and not state.extraOpen then
		service.Locks:SetPowered(session.safeSeam, Breaker.powered(state, session.spec.extra))
	end
end

-- Its toggles, its main switch and its lamps as the panel stands: a
-- breaker's lamp lit while it's on (and nothing tripped), the main's green
-- or red, the panel's glow warmer the more breakers are on.
function Kind.show(session)
	local state = session.state
	local on = 0
	for i, pilot in session.pilots or {} do
		local lit = state.on[i] == true and not state.tripped
		if lit then
			on += 1
		end
		pilot.Color = rgb(lit and D.Pilot or D.PilotOff)
		pilot.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local toggle = session.toggles[i]
		if toggle then
			local tilt = state.on[i] == true and D.Tilt[1] or D.Tilt[2]
			Kit.repose(toggle.mesh, "BreakerToggle", toggle.pivot * CFrame.Angles(math.rad(tilt), 0, 0))
		end
	end
	if session.mainLamp then
		session.mainLamp.Color = rgb(state.tripped and D.Tripped or D.Main)
		session.mainLamp.Material = Enum.Material.Neon
	end
	if session.mainSwitch then
		local tilt = state.tripped and D.Tilt[2] or D.Tilt[1]
		Kit.repose(
			session.mainSwitch.mesh,
			"MainSwitch",
			session.mainSwitch.pivot * CFrame.Angles(math.rad(tilt), 0, 0)
		)
	end
	if session.glow then
		session.glow.Enabled = on > 0
		session.glow.Brightness = D.GlowBase + D.GlowPer * on
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
	elseif event.kind == "reveal" then
		Sfx.play("LockClick", position, 0.4, 1.15)
	elseif event.kind == "trip" then
		-- Every light out, and a clunk he hears from you.
		Sfx.play("DoorBang", position, 0.9, 0.5)
		service.Noise:Emit(position, B.TripNoise, player, "puzzle")
		Net.get("Notify"):FireAllClients("A loud clunk somewhere. Every light goes out.", "danger")
	elseif event.kind == "reset" then
		Sfx.play("DoorLatch", position, 0.6, 0.7)
	elseif event.kind == "extra" and session.safeSeam then
		-- The safe room's steel door, open for good.
		service.Locks:SetPowered(session.safeSeam, true)
		service.Locks:Unlock(session.safeSeam, player, "Somewhere, a heavy steel lock clunks open.")
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
