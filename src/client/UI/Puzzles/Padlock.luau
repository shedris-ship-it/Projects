-- A door's combination padlock (Logic/Puzzles/Padlock): turn the wheels,
-- pull. A wrong pull rattles. UI/Puzzle hosts it. In the 1988 interface
-- (V7): the lock itself, a brass body under a steel shackle, its wheels
-- stamped steel.

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local BRASS = Color3.fromRGB(176, 138, 64)
local BRASS_DARK = Color3.fromRGB(92, 68, 28)
local WHEEL = Color3.fromRGB(196, 196, 190)

local Screen = {}

function Screen.build(host, open)
	local wheels = open.view.wheels
	local width = 120 + wheels * 70
	-- (One frame holds the shackle behind the body, so they shake together.)
	local holder = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 300),
		BackgroundTransparency = 1,
		Parent = host.gui,
	})
	Ui.modal(holder)
	open.panel = holder
	Ui.new("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(math.floor(width * 0.56), 150),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = holder,
	}, { Ui.corner(80), Ui.stroke(Color3.fromRGB(170, 172, 176), 16, 0) })
	local panel = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BRASS,
		ZIndex = 2,
		Parent = holder,
	}, {
		Ui.corner(26),
		Ui.stroke(BRASS_DARK, 3, 0),
		Ui.padding(16),
		Ui.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 200)),
				ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 130, 100)),
			}),
		}),
	})
	Ui.label("PADLOCK", {
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = BRASS_DARK,
		Parent = panel,
	})
	open.digits = {}
	local x0 = (120 + wheels * 70 - 32) / 2 - wheels * 35
	for w = 1, wheels do
		local x = x0 + (w - 1) * 70
		local up = Ui.button("+", {
			Position = UDim2.fromOffset(x, 40),
			Size = UDim2.fromOffset(56, 34),
			Plain = true,
			BackgroundColor3 = Color3.fromRGB(60, 58, 54),
			TextSize = 22,
			Parent = panel,
		}, function()
			host:Send("turn", nil, w, 1)
		end)
		if w == 1 then
			open.first = up
		end
		-- A stamped steel wheel, rounded by its shading.
		open.digits[w] = Ui.label("0", {
			Position = UDim2.fromOffset(x, 80),
			Size = UDim2.fromOffset(56, 60),
			TextSize = 44,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(26, 24, 22),
			BackgroundColor3 = WHEEL,
			BackgroundTransparency = 0,
			Parent = panel,
		}, {
			Ui.corner(4),
			Ui.stroke(Color3.fromRGB(70, 70, 70), 1, 0.2),
			Ui.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 90, 90)),
					ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 90, 90)),
				}),
			}),
		})
		Ui.button("-", {
			Position = UDim2.fromOffset(x, 146),
			Size = UDim2.fromOffset(56, 34),
			Plain = true,
			BackgroundColor3 = Color3.fromRGB(60, 58, 54),
			TextSize = 22,
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
	Ui.button(host:BackText(), {
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
