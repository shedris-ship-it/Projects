-- The music box and the piano (docs/plans/gameplay-rework.md section 7;
-- R2c). The box lies on a top in a room open no later than the piano's;
-- wind it (E) and it plays its tune for everyone, and while someone carries
-- it, it keeps playing, a lure he hears from whoever holds it. The tune
-- played back on the piano opens it on an heirloom. Rules: Logic/Puzzles/
-- MusicBox.
--
-- Made readable after the squad playtest (2026-10-08: "even for me who
-- knows it's there, I don't know how to do it"):
--   * the box's comb and the piano's keys wear the same eight colours (a
--     child's practice stickers, Config.MusicBox.Colors), and the tooth of
--     each note lights as it plays, for everyone near (the strip on screen:
--     UI/TuneStrip; the comb itself: Controllers/AudioController);
--   * a sheet on the piano's stand shows how many notes the tune has, blank
--     until it's played, and fills with its colours once it is;
--   * the piano plays freely: no discord, no starting again; each key is a
--     little noise he hears;
--   * Listen, on the piano's screen, winds the box when it's beside the piano.
--
-- The notes play through each client's sound (Lib/Sfx) at the box or the
-- piano; the one pressing a key hears it at once on their own client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MusicBox = require(Shared.Logic.Puzzles.MusicBox)
local Net = require(Shared.Net)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local M = Config.MusicBox
local part = PropFactory.part
local BRASS = Color3.fromRGB(190, 160, 96)
local PAPER = Color3.fromRGB(226, 218, 196)
local INK = Color3.fromRGB(58, 44, 34)

local function colorOf(k: number): Color3
	local rgb = M.Colors[k].rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

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
		-- Someone has heard the box play (the objective line and the hint
		-- point to the box until then: Services/FinaleService).
		heard = false,
	}
	Kind.piano(service, session, puzzle.room, rng:Fork("piano"))
	Kind.box(service, session, puzzle.rooms and puzzle.rooms[2] or puzzle.room, rng:Fork("box"))
	if token then
		local items = service.services.ItemService
		items:SetHome(token, {
			room = puzzle.room,
			station = {
				Restore = function(t)
					items:Make(t, Kind.top(session))
				end,
			},
		})
	end
	return session
end

-- Where the heirloom comes to rest: on the piano's top, wherever the piano
-- has been pushed to since.
function Kind.top(session): CFrame
	local model = session.pianoModel
	if model and model.Parent and session.topLocal then
		return model:GetPivot() * session.topLocal
	end
	return session.topAt
end

-- The room's piano (or, if the room lost it fitting its furniture, a small
-- upright built on a free spot of floor).
function Kind.piano(service, session, roomId: number, rng)
	local world = service.World
	local frame, model
	for _, prop in world.World.props do
		if prop.roomId == roomId and prop.kind == "Piano" and prop.model.Parent then
			frame, model = prop.frame, prop.model
			session.station = prop.model:FindFirstChild("Keys") or prop.model:FindFirstChild("Body")
			break
		end
	end
	if not session.station then
		local slot = world:TakeFloorSlot(roomId, rng)
		local at = slot and slot.cframe or CFrame.new(world:Room(roomId).center)
		frame = CFrame.new(at.Position.X, world:FloorBase(at.Position.Y), at.Position.Z) * at.Rotation
		model = PropFactory.build("Piano", frame, world.content)
		session.station = model:FindFirstChild("Keys") or model:FindFirstChild("Body")
	end
	session.front = -frame.LookVector -- props face +Z
	session.topAt = frame * CFrame.new(1.6, 5, -0.6)
	session.pianoModel = model
	if model then
		session.topLocal = model:GetPivot():ToObjectSpace(session.topAt)
		Kind.dress(session, model, frame)
	end
	session.prompt = service:Prompt(session, session.station, "Play", Kind.label)
end

-- The stickers on eight of its keys and the sheet on its stand: a blank
-- note for each of the tune's notes, "the box's song".
function Kind.dress(session, model: Model, frame: CFrame)
	local size = model:GetExtentsSize()
	local w = math.min(size.X, 7)
	local depth = 3 -- Data/Props Piano: the keys run along its front edge
	local spacing = math.min(0.6, (w - 1.4) / MusicBox.Keys)
	for k = 1, MusicBox.Keys do
		part(
			model,
			"Sticker" .. k,
			Vector3.new(spacing * 0.6, 0.02, 0.3),
			frame * CFrame.new((k - (MusicBox.Keys + 1) / 2) * spacing, 3.14, depth / 2 - 0.3),
			colorOf(k),
			Enum.Material.SmoothPlastic,
			{ collide = false, castShadow = false, query = false }
		)
	end
	local sheet = part(
		model,
		"Score",
		Vector3.new(2.4, 1.4, 0.04),
		frame * CFrame.new(0, 3.85, depth / 2 - 0.86) * CFrame.Angles(math.rad(-8), 0, 0),
		PAPER,
		PropFactory.material("SmoothPlastic"),
		{ collide = false, castShadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- props face +Z
	gui.CanvasSize = Vector2.new(240, 140)
	gui.LightInfluence = 1
	gui.Parent = sheet
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.Position = UDim2.fromOffset(0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.IndieFlower
	title.TextScaled = true
	title.TextColor3 = INK
	title.Text = "the box's song"
	title.Parent = gui
	local dots = {}
	local n = session.spec.length
	for i = 1, n do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(120 + (i - (n + 1) / 2) * 38, 92)
		dot.Size = UDim2.fromOffset(26, 26)
		dot.BackgroundTransparency = 1
		dot.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 2
		stroke.Parent = dot
		dots[i] = dot
	end
	session.sheetDots = dots
end

-- The box: walnut, its lid open on a brass comb of eight painted teeth, a
-- key at the side. A small thing your hands can carry; the server keeps it
-- in flight.
function Kind.box(service, session, roomId: number, rng)
	local items = service.services.ItemService
	local at = items:TopSpot(roomId, rng, Config.Dressing.Sizes.MusicBox)
	if not at then
		local point = service.World:ClearFloorPoint(roomId, rng)
		at = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	local model = Instance.new("Model")
	model.Name = "MusicBox"
	local wood = Color3.fromRGB(86, 52, 32)
	local base =
		part(model, "Base", Vector3.new(1.2, 0.4, 0.8), at * CFrame.new(0, 0.2, 0), wood, PropFactory.material("Wood"))
	part(
		model,
		"Lid",
		Vector3.new(1.22, 0.06, 0.82),
		at * CFrame.new(0, 0.62, -0.32) * CFrame.Angles(math.rad(-70), 0, 0),
		PropFactory.shade(wood, 1.1),
		PropFactory.material("Wood"),
		{ collide = false }
	)
	part(
		model,
		"Comb",
		Vector3.new(1.0, 0.03, 0.12),
		at * CFrame.new(0, 0.415, -0.2),
		BRASS,
		PropFactory.material("Metal"),
		{ collide = false, castShadow = false }
	)
	for k = 1, MusicBox.Keys do
		local tooth = part(
			model,
			"Tooth" .. k,
			Vector3.new(0.09, 0.03, 0.42 - k * 0.02),
			at * CFrame.new(-0.42 + (k - 1) * 0.12, 0.42, 0.06 - k * 0.01),
			colorOf(k),
			Enum.Material.SmoothPlastic,
			{ collide = false, castShadow = false }
		)
		tooth:SetAttribute("Key", k)
	end
	part(
		model,
		"Key",
		Vector3.new(0.24, 0.07, 0.07),
		at * CFrame.new(0.68, 0.22, 0),
		BRASS,
		PropFactory.material("Metal"),
		{
			collide = false,
		}
	)
	model.PrimaryPart = base
	model.Parent = items.folder or service.World.content
	model:SetAttribute("Precious", true) -- never left for a client to fly
	model:SetAttribute("TuneLength", session.spec.length)
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
-- The comb's attribute ("key:index:length:clock") lights the tooth and the
-- strip on every client near it.
function Kind.wind(service, session, player: Player?): boolean
	local box = session.box
	if not box or box.playing or not box.model.Parent then
		return false
	end
	box.playing = true
	session.heard = true
	local notes = session.spec.notes
	for i, k in notes do
		task.delay(0.35 + (i - 1) * M.NoteGap, function()
			if not box.model.Parent then
				return
			end
			local position = box.model:GetPivot().Position
			Sfx.play("MusicBoxNote", position, M.BoxVolume, MusicBox.pitch(k, M.BoxPitch))
			box.model:SetAttribute("Comb", k .. ":" .. i .. ":" .. #notes .. ":" .. os.clock())
		end)
	end
	task.delay(0.35 + #notes * M.NoteGap, function()
		box.playing = false
	end)
	local position = box.model:GetPivot().Position
	service.Noise:Emit(position, M.Lure, player, "musicbox")
	return true
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

function Kind.event(service, session, event, player: Player, position: Vector3)
	if event.kind == "note" then
		-- The presser heard it already (UI/Puzzles/MusicBox); every key is a
		-- little noise, the only cost of a wrong one.
		Sfx.playExcept(player, "MusicBoxNote", position, M.PianoVolume, MusicBox.pitch(event.key, M.PianoPitch))
		service.Noise:Emit(position, M.KeyNoise, player, "puzzle")
	elseif event.kind == "listen" then
		local box = session.box
		local near = box
			and box.model.Parent
			and (box.model:GetPivot().Position - session.station.Position).Magnitude <= M.ListenReach
		if not near then
			Net.get("Notify"):FireClient(player, "Bring the music box to the piano to hear it here.", "info")
		elseif not Kind.wind(service, session, player) then
			Net.get("Notify"):FireClient(player, "It's still playing.", "info")
		end
	end
end

-- Played right: the sheet fills with the tune's colours, something drops
-- inside the piano and its lid lifts.
function Kind.solved(service, session, _player: Player?)
	local top = Kind.top(session)
	Sfx.play("DoorLatch", top.Position, 0.7, 0.5)
	for i, dot in session.sheetDots or {} do
		local k = session.spec.notes[i]
		if dot.Parent and k then
			dot.BackgroundColor3 = colorOf(k)
			dot.BackgroundTransparency = 0
		end
	end
	if session.token then
		service.services.ItemService:Make(session.token, top)
	end
end

return Kind
