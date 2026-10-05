-- The music box and the piano (docs/plans/gameplay-rework.md section 7;
-- R2c). The box lies on a top in a room open no later than the piano's;
-- wind it (E) and it plays its tune for everyone, and while someone carries
-- it, it keeps playing, a lure he hears from whoever holds it. The tune
-- played back on the piano opens it on an heirloom; a wrong note is a loud
-- discord (heard by him from you) and you start again. Rules: Logic/
-- Puzzles/MusicBox.
--
-- The notes play through each client's sound (Lib/Sfx) at the box or the
-- piano. The box's comb carries the note last played (attribute Comb): with
-- subtitles on, each client lights that tooth (Controllers/AudioController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MusicBox = require(Shared.Logic.Puzzles.MusicBox)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local M = Config.MusicBox
local part = PropFactory.part
local BRASS = Color3.fromRGB(190, 160, 96)

local Kind = {
	label = "Piano",
	done = "The piano's lid is up. It's played.",
}

function Kind.create(service, id: string, puzzle)
	local rng = Rng.new(puzzle.seed)
	local spec = MusicBox.generate(rng:Fork("tune"), {})
	local token
	for tokenId, info in service.plan.tokens do
		if info.producer.kind == "puzzle" and info.producer.id == id then
			token = tokenId
		end
	end
	local session = {
		id = id,
		kind = "musicbox",
		spec = spec,
		state = MusicBox.start(spec),
		room = puzzle.room,
		token = token,
		reach = 8,
		nextNoise = 0,
		nextTune = 0,
	}
	Kind.piano(service, session, puzzle.room, rng:Fork("piano"))
	Kind.box(service, session, puzzle.rooms and puzzle.rooms[2] or puzzle.room, rng:Fork("box"))
	if token then
		local items = service.services.ItemService
		items:SetHome(token, {
			room = puzzle.room,
			station = {
				Restore = function(t)
					items:Make(t, session.top)
				end,
			},
		})
	end
	return session
end

-- The room's piano (or, if the room lost it fitting its furniture, a small
-- upright built on a free spot of floor).
function Kind.piano(service, session, roomId: number, rng)
	local world = service.World
	local frame
	for _, prop in world.World.props do
		if prop.roomId == roomId and prop.kind == "Piano" and prop.model.Parent then
			frame = prop.frame
			session.station = prop.model:FindFirstChild("Keys") or prop.model:FindFirstChild("Body")
			break
		end
	end
	if not session.station then
		local slot = world:TakeFloorSlot(roomId, rng)
		local at = slot and slot.cframe or CFrame.new(world:Room(roomId).center)
		frame = CFrame.new(at.Position.X, world:FloorBase(at.Position.Y), at.Position.Z) * at.Rotation
		local model = PropFactory.build("Piano", frame, world.content)
		session.station = model:FindFirstChild("Keys") or model:FindFirstChild("Body")
	end
	session.front = -frame.LookVector -- props face +Z
	session.top = frame * CFrame.new(1.6, 5, -0.6)
	session.prompt = service:Prompt(session, session.station, "Play", Kind.label)
end

-- The box: walnut, its lid ajar on a brass comb of eight teeth, a key at the
-- side. A small thing your hands can carry; the server keeps it in flight.
function Kind.box(service, session, roomId: number, rng)
	local items = service.services.ItemService
	local at = items:TopSpot(roomId, rng)
	if not at then
		local point = service.World:RandomPointIn(roomId, rng)
		at = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	local model = Instance.new("Model")
	model.Name = "MusicBox"
	local wood = Color3.fromRGB(86, 52, 32)
	local base = part(
		model,
		"Base",
		Vector3.new(0.9, 0.36, 0.6),
		at * CFrame.new(0, 0.18, 0),
		wood,
		PropFactory.material("Wood")
	)
	part(
		model,
		"Lid",
		Vector3.new(0.92, 0.06, 0.62),
		at * CFrame.new(0, 0.5, -0.22) * CFrame.Angles(math.rad(-55), 0, 0),
		PropFactory.shade(wood, 1.1),
		PropFactory.material("Wood"),
		{ collide = false }
	)
	for k = 1, MusicBox.Keys do
		local tooth = part(
			model,
			"Tooth" .. k,
			Vector3.new(0.05, 0.03, 0.3 - k * 0.015),
			at * CFrame.new(-0.3 + (k - 1) * 0.085, 0.37, 0.05),
			BRASS,
			PropFactory.material("Metal"),
			{ collide = false, castShadow = false }
		)
		tooth:SetAttribute("Key", k)
	end
	part(
		model,
		"Key",
		Vector3.new(0.2, 0.06, 0.06),
		at * CFrame.new(0.52, 0.2, 0),
		BRASS,
		PropFactory.material("Metal"),
		{
			collide = false,
		}
	)
	model.PrimaryPart = base
	model.Parent = items.folder or service.World.content
	model:SetAttribute("Precious", true) -- never left for a client to fly
	CollectionService:AddTag(model, "ConsensusMusicBox")
	local thing = service.Hands:AddThing(model, { class = "light", label = "Music box" })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WindPrompt"
	prompt.ActionText = "Wind it"
	prompt.ObjectText = "Music box"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if service.PlayerState:CanAct(player) then
			Kind.wind(service, session, player)
		end
	end)
	session.box = { model = model, thing = thing }
end

-- It plays its tune, once through, from wherever it is as each note sounds.
function Kind.wind(service, session, player: Player?)
	local box = session.box
	if not box or box.playing or not box.model.Parent then
		return
	end
	box.playing = true
	local notes = session.spec.notes
	for i, k in notes do
		task.delay((i - 1) * M.NoteGap, function()
			if not box.model.Parent then
				return
			end
			local position = box.model:GetPivot().Position
			Sfx.play("MusicBoxNote", position, M.BoxVolume, MusicBox.pitch(k, M.BoxPitch))
			box.model:SetAttribute("Comb", k .. ":" .. i .. ":" .. os.clock())
		end)
	end
	task.delay(#notes * M.NoteGap, function()
		box.playing = false
	end)
	local position = box.model:GetPivot().Position
	service.Noise:Emit(position, M.Lure, player, "musicbox")
end

-- While someone carries it, it keeps playing, and he hears where from.
function Kind.tick(service, session, _dt: number)
	local box = session.box
	local holder = box and box.thing and box.thing.holder
	if not holder then
		return
	end
	local now = os.clock()
	if now >= session.nextTune then
		session.nextTune = now + M.CarriedEvery
		Kind.wind(service, session, holder)
	end
	if now >= session.nextNoise and box.model.Parent then
		session.nextNoise = now + M.LureEvery
		service.Noise:Emit(box.model:GetPivot().Position, M.Lure, holder, "musicbox")
	end
end

function Kind.event(service, _session, event, player: Player, position: Vector3)
	if event.kind == "note" then
		Sfx.play("MusicBoxNote", position, M.PianoVolume, MusicBox.pitch(event.key, M.PianoPitch))
	elseif event.kind == "discord" then
		-- Three keys at once, a semitone apart: loud, and heard.
		for _, offset in { 0, 1.06, 1.12 } do
			Sfx.play("MusicBoxNote", position, 1, MusicBox.pitch(event.key, M.PianoPitch) * offset)
		end
		service.Noise:Emit(position, M.DiscordNoise, player, "puzzle")
	end
end

-- Played right: something drops inside the piano and its lid lifts.
function Kind.solved(service, session, _player: Player?)
	Sfx.play("DoorLatch", session.top.Position, 0.7, 0.5)
	if session.token then
		service.services.ItemService:Make(session.token, session.top)
	end
end

return Kind
