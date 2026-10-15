-- The fuse box (Logic/Puzzles/Breaker): a row of breakers in the family's
-- handwriting, and the main. Flip one and real rooms go dark or light up;
-- too many on and the main trips. UI/Puzzle hosts it. Keys too: 1 to 9
-- flip, M the main, E steps back. In the 1988 interface (V7): a painted steel
-- box, riveted, its breakers bakelite levers with a lamp each, the family's
-- labels on strips of masking tape.

local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local STEEL = Color3.fromRGB(78, 86, 80)
local DARK = Color3.fromRGB(28, 30, 30)
local TAPE = Color3.fromRGB(232, 222, 190)
local INK = Ui.Theme.pen
local CREAM = Color3.fromRGB(230, 220, 190)
local LEVER = Color3.fromRGB(222, 212, 188) -- a breaker's bakelite lever
local ON = Color3.fromRGB(120, 230, 120) -- its lamp, lit
local OFF = Color3.fromRGB(46, 40, 36) -- its lamp, dark
local DEAD = Color3.fromRGB(70, 110, 76) -- on, but the main has tripped

local Screen = {}

function Screen.build(host, open)
	local view = open.view
	local count = view.count
	local width = math.max(520, 40 + count * 86)
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 400),
		BackgroundColor3 = STEEL,
		Parent = host.gui,
	}, {
		Ui.corner(6),
		Ui.stroke(Color3.fromRGB(36, 38, 36), 3, 0),
		Ui.padding(18),
		Ui.new("UIGradient", {
			Rotation = 70,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 180, 176)),
		}),
	})
	Ui.modal(panel)
	open.panel = panel
	-- Rivets in the corners.
	for _, at in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(at[1], at[2]),
			Position = UDim2.new(at[1], at[1] == 0 and -10 or 10, at[2], at[2] == 0 and -10 or 10),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = Color3.fromRGB(150, 156, 150),
			Parent = panel,
		}, { Ui.corner(5), Ui.stroke(Color3.fromRGB(40, 42, 40), 1, 0.3) })
	end
	Ui.label("FUSE BOX", {
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 26,
		TextColor3 = CREAM,
		Parent = panel,
	})
	-- The maker's warning, a yellow sticker.
	Ui.label(string.format("MAX %d CIRCUITS ON - MORE WILL TRIP THE MAIN", view.capacity), {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(0, 400, 0, 18),
		BackgroundColor3 = Color3.fromRGB(226, 186, 52),
		BackgroundTransparency = 0,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(26, 22, 16),
		Parent = panel,
	})
	open.status = Ui.label("", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = CREAM,
		Parent = panel,
	})
	open.toggles = {}
	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = DARK,
		Parent = panel,
	}, { Ui.corner(4), Ui.list(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center), Ui.padding(10) })
	for i = 1, count do
		local column = Ui.new("Frame", {
			Size = UDim2.fromOffset(72, 180),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = row,
		})
		Ui.label(tostring(i), {
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(200, 200, 196),
			Parent = column,
		})
		-- Its lamp, by its number.
		open.lamps = open.lamps or {}
		open.lamps[i] = Ui.new("Frame", {
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = OFF,
			Parent = column,
		}, { Ui.corner(5), Ui.stroke(Color3.fromRGB(10, 10, 10), 1, 0.4) })
		local toggle = Ui.button("", {
			Position = UDim2.fromOffset(16, 20),
			Size = UDim2.fromOffset(40, 90),
			Plain = true,
			BackgroundColor3 = Color3.fromRGB(18, 18, 18),
			TextSize = 12,
			TextColor3 = Color3.fromRGB(190, 186, 170),
			Parent = column,
		}, function()
			host:Send("flip", nil, i)
		end)
		if i == 1 then
			open.first = toggle
		end
		open.toggles[i] = toggle
		-- The lever: up is on.
		open.levers = open.levers or {}
		open.levers[i] = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -42),
			Size = UDim2.fromOffset(28, 36),
			BackgroundColor3 = LEVER,
			Parent = toggle,
		}, {
			Ui.corner(3),
			Ui.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 162, 146)),
			}),
		})
		-- The family's label on a strip of tape (a number when the labels
		-- live on the plate by the door; the plate's words while traced).
		open.labels = open.labels or {}
		open.labels[i] = Ui.new("TextLabel", {
			Position = UDim2.fromOffset(0, 118),
			Size = UDim2.fromOffset(72, 54),
			BackgroundColor3 = TAPE,
			Text = view.labels[i] == "?" and "" or view.labels[i],
			TextWrapped = true,
			TextScaled = true,
			FontFace = Ui.Fonts.hand,
			TextColor3 = INK,
			Rotation = (i % 2 == 0) and 2 or -2,
			Parent = column,
		}, { Ui.padding(2), Ui.new("UITextSizeConstraint", { MaxTextSize = 28 }) })
	end
	open.main = Ui.button("MAIN", {
		Position = UDim2.fromOffset(0, 296),
		Size = UDim2.new(0.5, -6, 0, 44),
		Plain = true,
		BackgroundColor3 = DARK,
		TextColor3 = CREAM,
		Parent = panel,
	}, function()
		host:Send("main")
	end)
	Ui.button(host:BackText(), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 296),
		Size = UDim2.new(0.5, -6, 0, 44),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
	Ui.label(string.format("Keys: 1-%d flip  ·  M the main", count), {
		Position = UDim2.fromOffset(0, 348),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 166, 150),
		Parent = panel,
	})
	open.connections = {
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local i = NUMBER_KEYS[input.KeyCode]
			if i and i <= count then
				host:Send("flip", nil, i)
			elseif input.KeyCode == Enum.KeyCode.M then
				host:Send("main")
			end
		end),
	}
end

function Screen.refresh(host, open, events)
	local state = open.state
	for i, label in open.labels or {} do
		local text = (state.labels and state.labels[i]) or open.view.labels[i] or ""
		label.Text = text == "?" and "" or text
	end
	for i, toggle in open.toggles do
		local on = state.on[i] == true
		-- The lever up and the word under it, or down and the word over it.
		toggle.Text = on and "ON" or "OFF"
		toggle.TextYAlignment = on and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Top
		open.levers[i].Position = on and UDim2.new(0.5, 0, 0, 6) or UDim2.new(0.5, 0, 1, -42)
		open.lamps[i].BackgroundColor3 = on and (state.tripped and DEAD or ON) or OFF
	end
	open.main.Text = state.tripped and "MAIN (TRIPPED): RESET" or "MAIN"
	open.main.BackgroundColor3 = state.tripped and Color3.fromRGB(150, 36, 28) or DARK
	if state.tripped then
		open.status.Text = "THE MAIN HAS TRIPPED. EVERY LIGHT IS OUT."
	elseif state.solved then
		open.status.Text = "Somewhere, a lock has power."
	else
		open.status.Text = ""
	end
	for _, event in events do
		if event.kind == "trip" then
			host:Shake(open.panel)
		end
	end
end

return Screen
