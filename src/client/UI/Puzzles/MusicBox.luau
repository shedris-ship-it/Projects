-- The piano (Logic/Puzzles/MusicBox): eight keys to play the music box's
-- tune back on. Each key wears the colour of the comb's tooth for the same
-- note (Config.MusicBox.Colors) and sounds the moment it's pressed. Click a
-- key or press 1 to 8. Wrong notes cost nothing but the noise each key
-- makes: the piano opens the moment the last notes played are the tune, and
-- the lights fill with the colours matched so far. Listen winds the box when
-- it's beside the piano (its tune shows in UI/TuneStrip). UI/Puzzle hosts
-- it. Remade after the squad playtest (2026-10-08).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MusicBoxRules = require(Shared.Logic.Puzzles.MusicBox)

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local M = Config.MusicBox
local WOOD = Color3.fromRGB(34, 26, 24)
local IVORY = Color3.fromRGB(236, 230, 214)
local DIM = Color3.fromRGB(60, 50, 44)
local GOLD = Color3.fromRGB(214, 182, 96)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

local function colorOf(k: number): Color3
	local rgb = M.Colors[k].rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A music box within reach of you (so Listen can wind it beside the piano).
local function boxNear(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, model in CollectionService:GetTagged("ConsensusMusicBox") do
		local part = model:IsA("Model") and model.PrimaryPart
		if part and (part.Position - root.Position).Magnitude <= M.ListenReach + 2 then
			return true
		end
	end
	return false
end

local Screen = {}

function Screen.build(host, open)
	local view = open.view
	local audio = host.ctx.controllers.AudioController
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(600, 400),
		BackgroundColor3 = WOOD,
		Parent = host.gui,
	}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(90, 70, 50), 3, 0), Ui.padding(18) })
	Ui.modal(panel)
	open.panel = panel
	open.heard = {} -- the keys the server has heard, newest last
	Ui.label("PIANO", {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Ui.Theme.fontType,
		TextSize = 24,
		TextColor3 = IVORY,
		Parent = panel,
	})
	Ui.label(
		string.format(
			"Play the music box's %d-note tune. Each key wears the colour of its tooth on the box's comb.",
			view.length
		),
		{
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 190, 170),
			Parent = panel,
		}
	)
	open.lights = {}
	for i = 1, view.length do
		open.lights[i] = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (view.length + 1) / 2) * 30, 0, 68),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = DIM,
			Parent = panel,
		}, { Ui.corner(9), Ui.stroke(Color3.fromRGB(110, 92, 70), 1, 0) })
	end
	local keys = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 178),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	open.keys = {}
	local function press(k: number)
		-- Heard at once, here; the server tells everyone else.
		audio:PlayUi("MusicBoxNote", M.PianoVolume, MusicBoxRules.pitch(k, M.PianoPitch))
		local key = open.keys[k]
		if key then
			key.BackgroundColor3 = Color3.fromRGB(200, 192, 170)
			task.delay(0.15, function()
				if key.Parent then
					key.BackgroundColor3 = IVORY
				end
			end)
		end
		host:Send("key", nil, k)
	end
	for k = 1, view.keys do
		local key = Ui.button(tostring(k), {
			Size = UDim2.fromOffset(62, 178),
			BackgroundColor3 = IVORY,
			TextColor3 = Color3.fromRGB(110, 100, 86),
			TextSize = 20,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			LayoutOrder = k,
			Parent = keys,
		}, function()
			press(k)
		end)
		-- The sticker: the comb's colour for this note, and its name.
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = colorOf(k),
			Parent = key,
		}, { Ui.corner(6) })
		Ui.label(M.Colors[k].name, {
			Position = UDim2.fromOffset(0, 54),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 12,
			TextColor3 = Color3.fromRGB(110, 100, 86),
			Parent = key,
		})
		open.keys[k] = key
		if k == 1 then
			open.first = key
		end
	end
	open.listen = Ui.button("Listen", {
		Position = UDim2.fromOffset(0, 288),
		Size = UDim2.new(0.5, -4, 0, 36),
		Parent = panel,
	}, function()
		if boxNear() then
			host:Send("listen")
		end
	end)
	Ui.button("Step back", {
		Position = UDim2.new(0.5, 4, 0, 288),
		Size = UDim2.new(0.5, -4, 0, 36),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
	open.note = Ui.label("", {
		Position = UDim2.fromOffset(0, 332),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 160, 140),
		Parent = panel,
	})
	open.connections = {
		UserInputService.InputBegan:Connect(function(input, processed)
			local k = NUMBER_KEYS[input.KeyCode]
			if k and k <= view.keys and not processed then
				press(k)
			end
		end),
	}
end

-- The Listen button: lit while the box is with you.
function Screen.update(_host, open, _dt: number)
	local near = boxNear()
	if open.listen and open.listenNear ~= near then
		open.listenNear = near
		open.listen.Text = near and "Listen" or "Listen (bring the music box here)"
		open.listen.TextTransparency = near and 0 or 0.45
		open.note.Text = near and "" or "Each key is heard. Wrong notes cost nothing else."
	end
end

function Screen.refresh(_host, open, events)
	local state = open.state
	for _, event in events do
		if event.kind == "note" and event.key then
			table.insert(open.heard, event.key)
			while #open.heard > #open.lights do
				table.remove(open.heard, 1)
			end
		end
	end
	-- The lights: the colours of the notes that match the tune so far.
	local played = state.solved and #open.lights or (state.played or 0)
	for i, light in open.lights do
		if state.solved then
			light.BackgroundColor3 = GOLD
		elseif i <= played then
			local k = open.heard[#open.heard - played + i]
			light.BackgroundColor3 = k and colorOf(k) or GOLD
		else
			light.BackgroundColor3 = DIM
		end
	end
end

return Screen
