-- The home computer (docs/plans/gameplay-rework.md section 7): a 1988 home
-- computer and a dot-matrix printer on a desk in the room the plan chose.
-- Cracked, it prints the padlock's code on a page anyone can pick up and
-- read. A wrong word costs a try; four, and it locks you out with a loud
-- beep (noise, with you as its source). The rules are Logic/Puzzles/
-- Terminal; this is its station in the house (Services/PuzzleService runs
-- it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Padlock = require(Shared.Logic.Puzzles.Padlock)
local PropFactory = require(Shared.World.PropFactory)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)
local Terminal = require(Shared.Logic.Puzzles.Terminal)

local Dressing = require(script.Parent.Parent.World.Dressing)
local Items = require(script.Parent.Parent.World.Items)

local part = PropFactory.part
local SIZE = Config.Dressing.Sizes.Computer
local BEIGE = Color3.fromRGB(196, 186, 162)
local PHOSPHOR = Color3.fromRGB(110, 255, 140)

local Kind = {
	label = "Computer",
	done = "The screen just says ACCESS GRANTED.",
}

-- A planned computer: its session (with the padlock code it prints), and
-- the machine on a desk.
function Kind.create(service, id: string, puzzle)
	local rng = Rng.new(puzzle.seed)
	local spec = Terminal.generate(rng:Fork("screen"), {})
	local session = {
		id = id,
		kind = "terminal",
		spec = spec,
		state = Terminal.start(spec),
		room = puzzle.room,
		-- The code it prints: the padlock its token opens.
		padlock = Padlock.generate(rng:Fork("padlock"), {}),
	}
	Kind.build(service, session, puzzle.room)
	return session
end

-- A top with a clear stretch as wide as the computer, the desk first, claimed
-- before anything else of the run's is set on a top (Services/PuzzleService
-- :Reserve; the progression audit, 2026-10-10: it stood wherever the desk's
-- middle was, through the photos and the music box already there). With no
-- room on any, the house's own dressing on the best top makes way. Returns
-- { surface, x } or nil.
function Kind.reserve(service, _id: string, puzzle)
	local roomId = puzzle.room
	local world = service.World
	local tops, fallback = {}, nil
	for _, s in world.World.surfaces or {} do
		if s.record.id == roomId and s.prop.model.Parent and s.kind.size[1] >= SIZE[1] + 0.2 then
			table.insert(tops, s)
			if not fallback or (s.prop.kind == "Desk" and fallback.prop.kind ~= "Desk") then
				fallback = s
			end
		end
	end
	table.sort(tops, function(a, b)
		return (a.prop.kind == "Desk" and 0 or 1) < (b.prop.kind == "Desk" and 0 or 1)
	end)
	local chosen, x = nil, nil
	-- (Its middle front to back: the monitor at the back, the keyboard before it.)
	local function middle(s): number
		return -s.kind.size[3] / 2 + 1.45
	end
	for _, s in tops do
		x = Dressing.claimSpan(s, SIZE[1], SIZE[2], middle(s))
		if x then
			chosen = s
			break
		end
	end
	if not chosen and fallback and Dressing.makeRoom(fallback, SIZE[1], tops) then
		chosen, x = fallback, Dressing.claimSpan(fallback, SIZE[1], SIZE[2], middle(fallback))
	end
	return chosen and x and { surface = chosen, x = x } or nil
end

function Kind.build(service, session, roomId: number)
	local world = service.World
	local model = Instance.new("Model")
	model.Name = "HomeComputer"
	local top
	local held = service.reserved[session.id] or Kind.reserve(service, session.id, { room = roomId })
	local chosen, x = held and held.surface, held and held.x
	local surface = not chosen and service:Surface(roomId) or nil
	if chosen and x then
		local size = chosen.kind.size
		-- (Its parts stand about the frame from 2.15 left to 2.05 right.)
		top = chosen.prop.cframe * CFrame.new(x + 0.05, size[2], -size[3] / 2 + 1.1)
	elseif surface then
		top = surface.frame * CFrame.new(0, surface.size[2], -surface.size[3] / 2 + 1.1)
	else
		local at = world:Room(roomId).center
		top = CFrame.new(at.X, world:FloorBase(at.Y), at.Z)
	end
	local plastic = PropFactory.material("SmoothPlastic")
	local monitor = top * CFrame.new(-1.2, 0, 0)
	part(model, "Monitor", Vector3.new(1.9, 1.6, 1.5), monitor * CFrame.new(0, 0.95, 0), BEIGE, plastic)
	part(
		model,
		"Stand",
		Vector3.new(1.2, 0.15, 1),
		monitor * CFrame.new(0, 0.075, 0),
		PropFactory.shade(BEIGE, 0.85),
		plastic
	)
	local screen = part(
		model,
		"Screen",
		Vector3.new(1.4, 1.05, 0.04),
		monitor * CFrame.new(0, 1, 0.76),
		Color3.fromRGB(14, 30, 18),
		PropFactory.material("Glass"),
		{ castShadow = false }
	)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color = PHOSPHOR
	glow.Brightness = 0.6
	glow.Range = 6
	glow.Angle = 70
	glow.Parent = screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(280, 210)
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = PHOSPHOR
	text.Font = Enum.Font.Code
	text.TextSize = 20
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = "HOMEWARE 64\nFAMILY FILES\n\nPASSWORD:\n> _"
	text.Parent = gui
	gui.Parent = screen
	part(
		model,
		"Keyboard",
		Vector3.new(1.7, 0.12, 0.6),
		top * CFrame.new(-1.2, 0.06, 1.15),
		PropFactory.shade(BEIGE, 0.92),
		plastic
	)
	local printer = top * CFrame.new(1.3, 0, 0.1)
	part(model, "Printer", Vector3.new(1.5, 0.5, 1), printer * CFrame.new(0, 0.25, 0), BEIGE, plastic)
	part(
		model,
		"PrinterSlot",
		Vector3.new(1.1, 0.04, 0.12),
		printer * CFrame.new(0, 0.48, -0.3),
		Color3.fromRGB(30, 28, 26),
		plastic,
		{ castShadow = false, collide = false }
	)
	model.Parent = world.content
	session.model = model
	session.station = screen
	session.screenText = text
	session.printerAt = printer * CFrame.new(0, 0.02, 1.0)
	session.prompt = service:Prompt(session, screen, "Use", Kind.label)
end

-- What a click did, heard in the house.
function Kind.event(service, _session, event, player: Player, position: Vector3)
	if event.kind == "lockout" then
		-- Locked out: a loud beep that carries, and the house notices.
		service.Noise:Emit(position, Config.Puzzles.LockoutNoise, player, "puzzle")
		Sfx.play("Sting", position, 0.35, 2.4)
		service.Drift:Apply("PuzzleFailed")
	elseif event.kind == "likeness" then
		Sfx.play("UIClick", position, 0.25, 0.7)
	end
end

-- Cracked: ACCESS GRANTED, and the printer chatters out the padlock's code.
function Kind.solved(service, session, _player: Player)
	session.screenText.Text = "HOMEWARE 64\n\nACCESS GRANTED\n\nPRINTING..."
	if session.prompt then
		session.prompt.ObjectText = "Computer (unlocked)"
	end
	task.delay(1.2, function()
		if not service.plan or not session.model.Parent then
			return
		end
		for i = 0, 3 do
			task.delay(i * 0.3, function()
				Sfx.play("Shutter", session.printerAt.Position, 0.3, 0.55)
			end)
		end
		task.delay(1.3, function()
			if not service.plan then
				return
			end
			local text = "HOMEWARE 64\n\nNOTE TO SELF\nthe lock code\n\n  "
				.. Padlock.code(session.padlock)
				.. "\n\ndon't let HIM in"
			local page = Items.printout(session.printerAt, text, service.World.content)
			service.Hands:AddThing(page, { class = "light", label = "Printout" })
			-- Read it up close (UI/Reader), in your hands or where it lies.
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ReadPrompt"
			prompt.ActionText = "Read"
			prompt.ObjectText = "Printout"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Config.Leads.ReadRange
			prompt.RequiresLineOfSight = false
			prompt.Parent = page:FindFirstChild("Sheet")
			prompt.Triggered:Connect(function(reader)
				Net.get("NoteText"):FireClient(reader, { id = "printout:" .. session.id, text = text })
			end)
		end)
	end)
end

return Kind
