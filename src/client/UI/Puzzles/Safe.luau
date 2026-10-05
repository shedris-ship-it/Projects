-- The wall safe's dial (Logic/Puzzles/Safe): turn it a notch at a time
-- (hold the arrows, or the arrow keys, A and D, or the stick) and listen.
-- On the next number of the combination there's a click, for you alone; set
-- it there. Spin it fast and it rattles for the whole house. With subtitles
-- on (the accessibility setting) the dial also trembles on the click.
-- UI/Puzzle hosts it.

local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local STEEL = Color3.fromRGB(60, 64, 66)
local FACE = Color3.fromRGB(214, 208, 190)
local INK = Color3.fromRGB(30, 30, 32)
local STEP = 0.18 -- seconds between notches while a direction is held (under the rattle)

local Screen = {}

function Screen.build(host, open)
	local view = open.view
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 470),
		BackgroundColor3 = STEEL,
		Parent = host.gui,
	}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(30, 30, 30), 3, 0), Ui.padding(16) })
	Ui.modal(panel)
	open.panel = panel
	Ui.label("WALL SAFE", {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Ui.Theme.fontType,
		TextSize = 24,
		TextColor3 = FACE,
		Parent = panel,
	})
	Ui.label("Turn slowly and listen. Set it on the click.", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 196, 180),
		Parent = panel,
	})
	-- The dial: a ring of numbers that turns, a mark at the top.
	local dial = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(240, 240),
		BackgroundColor3 = FACE,
		Parent = panel,
	}, { Ui.corner(120), Ui.stroke(Color3.fromRGB(120, 116, 104), 4, 0) })
	open.dial = dial
	local ring = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = dial,
	})
	open.ring = ring
	for n = 0, view.size - 1, 5 do
		local angle = math.rad(n * 360 / view.size)
		Ui.label(tostring(n), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(angle) * 96, 0.5, -math.cos(angle) * 96),
			Size = UDim2.fromOffset(30, 20),
			Font = Enum.Font.Code,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = INK,
			Rotation = n * 360 / view.size,
			Parent = ring,
		})
	end
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(4, 16),
		BackgroundColor3 = Color3.fromRGB(180, 40, 30),
		BorderSizePixel = 0,
		Parent = panel,
	})
	open.number = Ui.label("0", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(80, 50),
		Font = Enum.Font.Code,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = INK,
		Parent = dial,
	})
	-- How far in: one light a number set.
	open.lights = {}
	for i = 1, view.stages do
		open.lights[i] = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (view.stages + 1) / 2) * 30, 0, 312),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			Parent = panel,
		}, { Ui.corner(9) })
	end
	local function held(direction: number)
		return function()
			open.holding = direction
			open.nextTurn = 0
		end
	end
	local left = Ui.button("◀  Left", {
		Position = UDim2.fromOffset(0, 344),
		Size = UDim2.new(0.33, -6, 0, 44),
		Parent = panel,
	})
	local right = Ui.button("Right  ▶", {
		Position = UDim2.new(0.33, 3, 0, 344),
		Size = UDim2.new(0.34, -6, 0, 44),
		Parent = panel,
	})
	open.connections = {}
	for button, direction in { [left] = -1, [right] = 1 } do
		table.insert(open.connections, button.MouseButton1Down:Connect(held(direction)))
		table.insert(
			open.connections,
			button.MouseButton1Up:Connect(function()
				open.holding = nil
			end)
		)
		table.insert(
			open.connections,
			button.MouseLeave:Connect(function()
				if open.holding == direction then
					open.holding = nil
				end
			end)
		)
		-- A gamepad's A or a tap: one notch.
		table.insert(
			open.connections,
			button.Activated:Connect(function(input)
				if input and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
					host:Send("turn", nil, direction)
				end
			end)
		)
	end
	open.first = right
	Ui.button("Set", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 344),
		Size = UDim2.new(0.33, -6, 0, 44),
		Parent = panel,
	}, function()
		host:Send("set")
	end)
	Ui.button("Step back", {
		Position = UDim2.fromOffset(0, 398),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
	-- Keys: Left/Right or A/D held turn it, Space or Enter sets it.
	local keys = {
		[Enum.KeyCode.Left] = -1,
		[Enum.KeyCode.A] = -1,
		[Enum.KeyCode.DPadLeft] = -1,
		[Enum.KeyCode.Right] = 1,
		[Enum.KeyCode.D] = 1,
		[Enum.KeyCode.DPadRight] = 1,
	}
	table.insert(
		open.connections,
		UserInputService.InputBegan:Connect(function(input)
			local direction = keys[input.KeyCode]
			if direction then
				held(direction)()
			elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
				host:Send("set")
			end
		end)
	)
	table.insert(
		open.connections,
		UserInputService.InputEnded:Connect(function(input)
			if keys[input.KeyCode] == open.holding then
				open.holding = nil
			end
		end)
	)
end

function Screen.refresh(host, open, events)
	local state = open.state
	open.number.Text = tostring(state.dial)
	open.ring.Rotation = -state.dial * 360 / open.view.size
	for i, light in open.lights do
		light.BackgroundColor3 = (state.solved or i < state.stage) and Color3.fromRGB(80, 200, 100)
			or Color3.fromRGB(40, 40, 40)
	end
	local ui = host.ctx.controllers.UIController
	local audio = host.ctx.controllers.AudioController
	for _, event in events do
		if event.kind == "click" then
			-- For you alone: a click in the mechanism.
			if audio then
				audio:PlayUi("LockClick", 0.7, 2.1)
			end
			if host.ctx.state.settings.subtitles then
				if ui then
					ui:Caption("[a click in the lock]")
				end
				Ui.tween(open.dial, 0.04, { Position = UDim2.new(0.5, 3, 0, 62) }).Completed:Connect(function()
					if open.dial.Parent then
						Ui.tween(open.dial, 0.06, { Position = UDim2.new(0.5, 0, 0, 62) })
					end
				end)
			end
		elseif event.kind == "rattle" or event.kind == "wrong" then
			host:Shake(open.panel)
		end
	end
end

-- A held direction turns it a notch every STEP seconds (slow enough never
-- to rattle; spin faster by clicking and it will).
function Screen.update(host, open, dt: number)
	if open.holding then
		open.nextTurn = (open.nextTurn or 0) - (dt or 0)
		if open.nextTurn <= 0 then
			open.nextTurn = STEP
			host:Send("turn", nil, open.holding)
		end
	end
end

return Screen
