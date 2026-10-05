-- A door's combination padlock (Logic/Puzzles/Padlock): turn the wheels,
-- pull. A wrong pull rattles. UI/Puzzle hosts it.

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local Screen = {}

function Screen.build(host, open)
	local wheels = open.view.wheels
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120 + wheels * 70, 300),
		BackgroundColor3 = Ui.Theme.panel,
		Parent = host.gui,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(150, 150, 156), 2, 0.2), Ui.padding(16) })
	Ui.modal(panel)
	open.panel = panel
	Ui.label("PADLOCK", {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Ui.Theme.fontType,
		TextSize = 24,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	open.digits = {}
	local x0 = (120 + wheels * 70 - 32) / 2 - wheels * 35
	for w = 1, wheels do
		local x = x0 + (w - 1) * 70
		local up = Ui.button("▲", {
			Position = UDim2.fromOffset(x, 40),
			Size = UDim2.fromOffset(56, 34),
			Parent = panel,
		}, function()
			host:Send("turn", nil, w, 1)
		end)
		if w == 1 then
			open.first = up
		end
		open.digits[w] = Ui.label("0", {
			Position = UDim2.fromOffset(x, 80),
			Size = UDim2.fromOffset(56, 60),
			Font = Enum.Font.Code,
			TextSize = 46,
			TextColor3 = Ui.Theme.text,
			BackgroundColor3 = Ui.Theme.ink,
			BackgroundTransparency = 0,
			Parent = panel,
		})
		Ui.button("▼", {
			Position = UDim2.fromOffset(x, 146),
			Size = UDim2.fromOffset(56, 34),
			Parent = panel,
		}, function()
			host:Send("turn", nil, w, -1)
		end)
	end
	Ui.button("Pull", {
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(0.5, -6, 0, 40),
		Parent = panel,
	}, function()
		host:Send("pull")
	end)
	Ui.button("Step back", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 200),
		Size = UDim2.new(0.5, -6, 0, 40),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
end

function Screen.refresh(host, open, events)
	for w, label in open.digits do
		label.Text = tostring(open.state.digits[w] or 0)
	end
	for _, event in events do
		if event.kind == "rattle" then
			host:Shake(open.panel)
		end
	end
end

return Screen
