-- The wall safe (docs/plans/gameplay-rework.md section 7; R2c): behind a
-- painting that swings out on hinges, a steel safe with a dial, holding an
-- heirloom. Cracked by ear: the click on each number goes only to whoever
-- works the dial (the event reaches that client alone, UI/Puzzles/Safe);
-- spin it fast and it rattles, loud enough for him. Rules: Logic/Puzzles/
-- Safe.
--
-- The painting and the safe's door are furniture pieces (Services/
-- FurnitureService): drag the painting aside or press E; the door stays
-- locked until the dial is right, then swings open on the heirloom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Joint = require(Shared.Lib.Joint)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Safe = require(Shared.Logic.Puzzles.Safe)
local Sfx = require(Shared.Lib.Sfx)

local part = PropFactory.part
local STEEL = Color3.fromRGB(78, 84, 86)
local SMALL = { collide = false, castShadow = false }

local Kind = {
	label = "Wall safe",
	done = "The safe stands open.",
}

-- A piece that turns about an upright edge (Lib/Joint), toward the room.
local function hinged(model: Model, primary: BasePart, hinge: Vector3, o)
	model.PrimaryPart = primary
	Joint.write(primary, {
		kind = "hinge",
		hinge = hinge,
		axis = Vector3.yAxis,
		sign = -1,
		shut = primary.CFrame,
		max = o.max,
		rate = Config.Furniture.DoorRate,
		latch = Config.Furniture.DoorLatch,
	})
	primary:SetAttribute("Group", o.group)
	primary:SetAttribute("Spot", o.spot)
	primary:SetAttribute("Label", o.label)
end

function Kind.create(service, id: string, puzzle)
	local rng = Rng.new(puzzle.seed)
	local spec = Safe.generate(rng:Fork("dial"), {})
	local token
	for tokenId, info in service.plan.tokens do
		if info.producer.kind == "puzzle" and info.producer.id == id then
			token = tokenId
		end
	end
	local session = {
		id = id,
		kind = "safe",
		spec = spec,
		state = Safe.start(spec),
		room = puzzle.room,
		token = token,
		reach = 7,
	}
	Kind.build(service, session, puzzle.room, rng:Fork("place"))
	local items = service.services.ItemService
	if token then
		-- Where he puts it back if it's left lying (the open safe; never
		-- locked again).
		items:SetHome(token, {
			room = puzzle.room,
			station = {
				Restore = function(t)
					items:Make(t, session.inside)
				end,
			},
		})
	end
	return session
end

-- A steel safe on the wall at chest height, a painting hung in front of it.
-- `cf`: on the wall face, +Z into the room.
function Kind.build(service, session, roomId: number, rng)
	local world = service.World
	local slot = world:TakeWallSlot(roomId, rng)
	local cf
	if slot then
		cf = slot.cframe * CFrame.new(0, -1.4, 0) * CFrame.Angles(0, math.pi, 0)
	else
		local at = world:Room(roomId).center
		cf = CFrame.new(at.X, world:FloorBase(at.Y) + 5, at.Z)
	end
	local model = Instance.new("Model")
	model.Name = "WallSafe"
	local metal = PropFactory.material("Metal")
	local dark = Color3.fromRGB(30, 32, 32)
	-- The box: open at the front, so what's in it shows once the door swings.
	part(model, "Back", Vector3.new(1.7, 1.7, 0.1), cf * CFrame.new(0, 0, 0.05), dark, metal)
	for _, sx in { -1, 1 } do
		part(model, "Side", Vector3.new(0.1, 1.7, 0.9), cf * CFrame.new(sx * 0.8, 0, 0.45), STEEL, metal)
	end
	for _, sy in { -1, 1 } do
		part(model, "Shelf", Vector3.new(1.7, 0.1, 0.9), cf * CFrame.new(0, sy * 0.8, 0.45), STEEL, metal)
	end
	session.inside = cf * CFrame.new(0, -0.75, 0.45)
	-- Its door, hinged on the left, with the dial and a handle.
	local door = Instance.new("Model")
	door.Name = "SafeDoor"
	door.Parent = model
	local slab = part(door, "Door", Vector3.new(1.6, 1.6, 0.12), cf * CFrame.new(0, 0, 0.96), STEEL, metal)
	local dial = part(
		door,
		"Dial",
		Vector3.new(0.12, 0.6, 0.6),
		cf * CFrame.new(0.15, 0.15, 1.08) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(200, 196, 180),
		metal,
		{ collide = false, shape = Enum.PartType.Cylinder }
	)
	part(
		door,
		"Handle",
		Vector3.new(0.12, 0.5, 0.1),
		cf * CFrame.new(-0.45, -0.35, 1.07),
		Color3.fromRGB(180, 160, 110),
		metal,
		SMALL
	)
	hinged(
		door,
		slab,
		cf:PointToWorldSpace(Vector3.new(-0.8, 0, 0.96)),
		{ max = 100, group = "SafeDoor", label = "Safe door" }
	)
	-- The painting in front, hinged on its left: it swings aside.
	local painting = Instance.new("Model")
	painting.Name = "Painting"
	painting.Parent = model
	local frame = part(
		painting,
		"Frame",
		Vector3.new(2.4, 2.2, 0.14),
		cf * CFrame.new(0, 0, 1.14),
		Color3.fromRGB(70, 46, 28),
		PropFactory.material("Wood")
	)
	-- A plain country landscape: sky, hills, a field.
	local hues = { Color3.fromRGB(104, 118, 134), Color3.fromRGB(70, 90, 64), Color3.fromRGB(146, 122, 78) }
	for i, hue in hues do
		part(
			painting,
			"Canvas",
			Vector3.new(2.1, 1.9 / #hues, 0.02),
			cf * CFrame.new(0, 0.95 - (i - 0.5) * 1.9 / #hues, 1.22),
			hue,
			PropFactory.material("SmoothPlastic"),
			SMALL
		)
	end
	hinged(
		painting,
		frame,
		cf:PointToWorldSpace(Vector3.new(-1.2, 0, 1.14)),
		{ max = 105, group = "Painting", label = "Painting" }
	)
	model.Parent = world.content
	local spaces = service.services.FurnitureService:AddProp({
		id = session.id,
		model = model,
		roomId = roomId,
		kind = "WallSafe",
	})
	for _, space in spaces do
		space.filled = true -- nothing's made here by opening: the safe makes its heirloom
		local piece = space.pieces[1]
		if piece and piece.model == door then
			session.doorPiece = piece
			service.services.FurnitureService:SetLocked(piece, true)
		elseif piece and piece.model == painting then
			session.paintingPiece = piece
		end
	end
	session.model = model
	session.station = dial
	session.front = -cf.LookVector
	session.prompt = service:Prompt(session, dial, "Work the dial", Kind.label)
	-- Hidden until the painting is swung aside.
	session.prompt.RequiresLineOfSight = true
end

function Kind.event(service, session, event, player: Player, position: Vector3)
	if event.kind == "turned" then
		-- A soft tick anyone near hears; the click is the operator's alone.
		Sfx.play("UIClick", position, 0.08, 2.2)
	elseif event.kind == "rattle" then
		Sfx.play("DoorLatch", position, 0.6, 1.8)
		service.Noise:Emit(position, Config.Puzzles.RattleNoise, player, "puzzle")
	elseif event.kind == "set" then
		Sfx.play("LockClick", position, 0.3, 0.7)
	elseif event.kind == "wrong" then
		Sfx.play("DoorLatch", position, 0.4, 0.6)
	end
	local dial = session.station
	if dial and dial.Parent then
		-- The dial turns for everyone to see (a notch is 9 degrees).
		local base = dial:GetAttribute("Base") or dial.CFrame
		dial:SetAttribute("Base", base)
		dial.CFrame = base * CFrame.Angles(-math.rad(session.state.dial * 360 / session.spec.size), 0, 0)
	end
end

-- Open: the door swings out on the heirloom.
function Kind.solved(service, session, _player: Player?)
	local furniture = service.services.FurnitureService
	-- (Swung aside already, unless it was opened from afar: F2 `solve`.)
	if session.paintingPiece then
		furniture:SetOpen(session.paintingPiece, true)
	end
	Sfx.play("DoorLatch", session.inside.Position, 0.7, 0.55)
	if session.token then
		service.services.ItemService:Make(session.token, session.inside)
	end
	-- The door after the painting is clear of it.
	task.delay(0.5, function()
		if session.doorPiece and session.model.Parent then
			furniture:SetLocked(session.doorPiece, false)
			furniture:SetOpen(session.doorPiece, true)
		end
	end)
end

return Kind
