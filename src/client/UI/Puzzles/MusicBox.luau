-- The piano (Logic/Puzzles/MusicBox): eight keys to play the music box's
-- tune back on. Click a key, or press 1 to 8. A wrong note is a discord and
-- the tune starts again. The lights show how much of it you've played.
-- UI/Puzzle hosts it.

local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local WOOD = Color3.fromRGB(34, 26, 24)
local IVORY = Color3.fromRGB(236, 230, 214)

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

local Screen = {}

function Screen.build(host, open)
	local view = open.view
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 360),
		BackgroundColor3 = WOOD,
		Parent = host.gui,
	}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(90, 70, 50), 3, 0), Ui.padding(18) })
	Ui.modal(panel)
	open.panel = panel
	Ui.label("PIANO", {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Ui.Theme.fontType,
		TextSize = 24,
		TextColor3 = IVORY,
		Parent = panel,
	})
	Ui.label("Play the music box's tune.", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 190, 170),
		Parent = panel,
	})
	open.lights = {}
	for i = 1, view.length do
		open.lights[i] = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (view.length + 1) / 2) * 26, 0, 56),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(60, 50, 44),
			Parent = panel,
		}, { Ui.corner(7) })
	end
	local keys = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	open.keys = {}
	for k = 1, view.keys do
		local key = Ui.button(tostring(k), {
			Size = UDim2.fromOffset(58, 170),
			BackgroundColor3 = IVORY,
			TextColor3 = Color3.fromRGB(120, 110, 96),
			TextYAlignment = Enum.TextYAlignment.Bottom,
			LayoutOrder = k,
			Parent = keys,
		}, function()
			host:Send("key", nil, k)
		end)
		open.keys[k] = key
		if k == 1 then
			open.first = key
		end
	end
	Ui.button("Step back", {
		Position = UDim2.fromOffset(0, 272),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
	open.connections = {
		UserInputService.InputBegan:Connect(function(input)
			local k = NUMBER_KEYS[input.KeyCode]
			if k and k <= view.keys then
				host:Send("key", nil, k)
			end
		end),
	}
end

local function press(key: GuiObject, color: Color3)
	key.BackgroundColor3 = color
	task.delay(0.18, function()
		if key.Parent then
			key.BackgroundColor3 = IVORY
		end
	end)
end

function Screen.refresh(host, open, events)
	local state = open.state
	for i, light in open.lights do
		light.BackgroundColor3 = (state.solved or i <= state.played) and Color3.fromRGB(200, 170, 90)
			or Color3.fromRGB(60, 50, 44)
	end
	for _, event in events do
		local key = event.key and open.keys[event.key]
		if event.kind == "note" and key then
			press(key, Color3.fromRGB(210, 196, 150))
		elseif event.kind == "discord" then
			if key then
				press(key, Color3.fromRGB(190, 70, 60))
			end
			host:Shake(open.panel)
		end
	end
end

return Screen
