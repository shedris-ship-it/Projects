-- The fuse box (Logic/Puzzles/Breaker): a row of breakers in the family's
-- handwriting, and the main. Flip one and real rooms go dark or light up;
-- too many on and the main trips. UI/Puzzle hosts it.

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local STEEL = Color3.fromRGB(70, 74, 72)
local DARK = Color3.fromRGB(28, 30, 30)
local TAPE = Color3.fromRGB(232, 222, 190)
local INK = Color3.fromRGB(40, 44, 84)
local ON = Color3.fromRGB(90, 200, 110)
local OFF = Color3.fromRGB(110, 40, 34)

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
	}, { Ui.corner(6), Ui.stroke(Color3.fromRGB(40, 40, 40), 3, 0), Ui.padding(18) })
	Ui.modal(panel)
	open.panel = panel
	Ui.label("FUSE BOX", {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Ui.Theme.fontType,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(230, 220, 190),
		Parent = panel,
	})
	Ui.label(string.format("MAX %d CIRCUITS ON - MORE WILL TRIP THE MAIN", view.capacity), {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(240, 200, 80),
		Parent = panel,
	})
	open.status = Ui.label("", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(230, 220, 190),
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
			Font = Enum.Font.Code,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(200, 200, 196),
			Parent = column,
		})
		local toggle = Ui.button("", {
			Position = UDim2.fromOffset(16, 20),
			Size = UDim2.fromOffset(40, 90),
			BackgroundColor3 = OFF,
			Parent = column,
		}, function()
			host:Send("flip", nil, i)
		end)
		if i == 1 then
			open.first = toggle
		end
		open.toggles[i] = toggle
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
			Font = Enum.Font.IndieFlower,
			TextColor3 = INK,
			Rotation = (i % 2 == 0) and 2 or -2,
			Parent = column,
		}, { Ui.padding(2), Ui.new("UITextSizeConstraint", { MaxTextSize = 22 }) })
	end
	open.main = Ui.button("MAIN", {
		Position = UDim2.fromOffset(0, 296),
		Size = UDim2.new(0.5, -6, 0, 44),
		Parent = panel,
	}, function()
		host:Send("main")
	end)
	Ui.button("Step back", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 296),
		Size = UDim2.new(0.5, -6, 0, 44),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
end

function Screen.refresh(host, open, events)
	local state = open.state
	for i, label in open.labels or {} do
		local text = (state.labels and state.labels[i]) or open.view.labels[i] or ""
		label.Text = text == "?" and "" or text
	end
	for i, toggle in open.toggles do
		local on = state.on[i] == true
		toggle.Text = on and "ON" or "OFF"
		toggle.BackgroundColor3 = on and (state.tripped and Color3.fromRGB(70, 110, 76) or ON) or OFF
	end
	open.main.Text = state.tripped and "MAIN (TRIPPED): RESET" or "MAIN"
	open.main.BackgroundColor3 = state.tripped and Color3.fromRGB(170, 40, 30) or Ui.Theme.panelLight
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
