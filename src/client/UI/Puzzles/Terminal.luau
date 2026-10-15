-- The home computer's screen (Logic/Puzzles/Terminal): a memory dump of
-- words and brackets; click a word to try it as the password, a matched
-- bracket pair to remove a dud or get your tries back. UI/Puzzle hosts it.
-- In the 1988 interface (V7) it's the set itself: a beige plastic bezel round
-- a curved green screen, phosphor type that glows, scanlines over it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared").Assets)
local Ui = require(script.Parent.Parent.Parent.Lib.Ui)

local GREEN = Color3.fromRGB(110, 255, 140)
local DIM = Color3.fromRGB(60, 150, 80)
local SCREEN = Color3.fromRGB(8, 18, 11)
local PLASTIC = Color3.fromRGB(206, 196, 172)
local GLOW = 0.84 -- the phosphor's soft halo round each letter (a stroke of its own green)
local CELL_W, CELL_H = 11, 22
local COLUMN_CHARS = 7 + 12 -- "0xF4F0 " and twelve characters

local Screen = {}

local function cell(parent, x: number, y: number, text: string)
	return Ui.new("TextLabel", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(CELL_W, CELL_H),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = GREEN,
		TextStrokeColor3 = GREEN,
		TextStrokeTransparency = GLOW,
		FontFace = Ui.Fonts.crt,
		TextSize = 19,
		Parent = parent,
	})
end

function Screen.build(host, open)
	local view = open.view
	local rows = #view.lines // 2
	local dumpWidth = 2 * COLUMN_CHARS * CELL_W + 24
	local width, height = dumpWidth + 300, rows * CELL_H + 150
	-- The set: a beige plastic bezel, its badge and a lit LED.
	local bezel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width + 76, height + 96),
		BackgroundColor3 = PLASTIC,
		Parent = host.gui,
	}, {
		Ui.corner(22),
		Ui.stroke(Color3.fromRGB(120, 112, 96), 2, 0.2),
		Ui.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 192, 182)),
		}),
	})
	Ui.modal(bezel)
	open.panel = bezel
	Ui.label("HOMEWARE 64", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 44, 1, -20),
		Size = UDim2.fromOffset(240, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(104, 96, 82),
		Parent = bezel,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -26),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(120, 255, 120),
		Parent = bezel,
	}, { Ui.corner(4), Ui.stroke(Color3.fromRGB(60, 120, 60), 1, 0.3) })
	-- The glass, curved at its corners; the dump and log on it.
	local glass = Ui.new("Frame", {
		Position = UDim2.fromOffset(38, 30),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = SCREEN,
		ClipsDescendants = true,
		Parent = bezel,
	}, { Ui.corner(28), Ui.stroke(Color3.fromRGB(64, 60, 52), 6, 0) })
	local panel = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = glass,
	}, { Ui.padding(20) })
	-- Over everything on the glass: the scanlines, then the tube's dark edges.
	Ui.new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Paper.Scanlines.image,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(Assets.Paper.Scanlines.tile, Assets.Paper.Scanlines.tile),
		ImageTransparency = 0.2,
		ZIndex = 10,
		Parent = glass,
	}, { Ui.corner(28) })
	Ui.new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Lens.Vignette,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.25,
		ZIndex = 11,
		Parent = glass,
	}, { Ui.corner(28) })
	local function line(y: number, text: string)
		return Ui.new("TextLabel", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = GREEN,
			TextStrokeColor3 = GREEN,
			TextStrokeTransparency = GLOW,
			FontFace = Ui.Fonts.crt,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panel,
		})
	end
	line(0, "HOMEWARE 64 (C) 1987 -- FAMILY FILES")
	open.status = line(22, "ENTER PASSWORD NOW")
	open.tries = line(44, "")
	local dump = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.fromOffset(dumpWidth, rows * CELL_H),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	open.cells = {}
	for r, row in view.lines do
		local column = (r - 1) // rows
		local x0 = column * (COLUMN_CHARS * CELL_W + 24)
		local y = ((r - 1) % rows) * CELL_H
		Ui.new("TextLabel", {
			Position = UDim2.fromOffset(x0, y),
			Size = UDim2.fromOffset(7 * CELL_W, CELL_H),
			BackgroundTransparency = 1,
			Text = row.address,
			TextColor3 = DIM,
			FontFace = Ui.Fonts.crt,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = dump,
		})
		open.cells[r] = {}
		for c = 1, #row.text do
			open.cells[r][c] = cell(dump, x0 + (7 + c - 1) * CELL_W, y, string.sub(row.text, c, c))
		end
	end
	-- What you can click: the words, and matched brackets.
	open.spans = {}
	for _, span in view.spans do
		local column = (span.row - 1) // rows
		local x0 = column * (COLUMN_CHARS * CELL_W + 24) + (7 + span.col - 1) * CELL_W
		local y = ((span.row - 1) % rows) * CELL_H
		local button = Ui.new("TextButton", {
			Position = UDim2.fromOffset(x0, y),
			Size = UDim2.fromOffset(span.length * CELL_W, CELL_H),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = dump,
		})
		local entry = { span = span, button = button }
		table.insert(open.spans, entry)
		local function light(on: boolean)
			for k = 0, span.length - 1 do
				local c = open.cells[span.row][span.col + k]
				c.BackgroundTransparency = on and 0 or 1
				c.TextColor3 = on and SCREEN or GREEN
			end
			if on then
				open.hover.Text = ">"
					.. (
						span.kind == "word" and span.word
						or string.sub(view.lines[span.row].text, span.col, span.col + span.length - 1)
					)
			end
		end
		-- The mouse, and a gamepad's selection, light a word up the same way.
		button.MouseEnter:Connect(function()
			if not entry.dead then
				light(true)
			end
		end)
		button.MouseLeave:Connect(function()
			light(false)
		end)
		button.SelectionGained:Connect(function()
			if not entry.dead then
				light(true)
			end
		end)
		button.SelectionLost:Connect(function()
			light(false)
		end)
		button.Activated:Connect(function()
			if entry.dead or open.state.solved then
				return
			end
			if span.kind == "word" then
				host:Send("word", span.word)
			else
				host:Send("bracket", nil, span.index)
			end
		end)
	end
	-- The log down the right.
	local log = Ui.new("Frame", {
		Position = UDim2.fromOffset(dumpWidth + 16, 80),
		Size = UDim2.new(1, -(dumpWidth + 16), 0, rows * CELL_H - 24),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	open.log = Ui.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = GREEN,
		TextStrokeColor3 = GREEN,
		TextStrokeTransparency = GLOW,
		FontFace = Ui.Fonts.crt,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextWrapped = true,
		Parent = log,
	})
	open.hover = Ui.new("TextLabel", {
		Position = UDim2.fromOffset(dumpWidth + 16, 80 + rows * CELL_H - 22),
		Size = UDim2.new(1, -(dumpWidth + 16), 0, 22),
		BackgroundTransparency = 1,
		Text = ">",
		TextColor3 = GREEN,
		TextStrokeColor3 = GREEN,
		TextStrokeTransparency = GLOW,
		FontFace = Ui.Fonts.crt,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Ui.button("[" .. host:BackText() .. "]", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(170, 30),
		Plain = true,
		BackgroundColor3 = SCREEN,
		TextColor3 = GREEN,
		TextStrokeColor3 = GREEN,
		TextStrokeTransparency = GLOW,
		FontFace = Ui.Fonts.crt,
		TextSize = 19,
		Parent = panel,
	}, function()
		host:Hide(true)
	end)
	open.first = open.spans[1] and open.spans[1].button
end

function Screen.refresh(_host, open, _events)
	local state = open.state
	open.tries.Text = state.solved and "" or (state.tries .. " ATTEMPT(S) LEFT: " .. string.rep("[] ", state.tries))
	if state.solved then
		open.status.Text = "ACCESS GRANTED"
	elseif (state.lockedFor or 0) > 0 then
		open.status.Text = string.format("TERMINAL LOCKED. TRY AGAIN IN %d SECONDS", math.ceil(state.lockedFor))
		open.lockedAt = os.clock()
	else
		open.status.Text = "ENTER PASSWORD NOW"
	end
	open.log.Text = table.concat(state.log or {}, "\n")
	-- Removed duds and used brackets become dots.
	for _, entry in open.spans do
		local span = entry.span
		local dead = (span.kind == "word" and state.removed[span.word])
			or (span.kind == "bracket" and state.used[span.index])
		if dead and not entry.dead then
			entry.dead = true
			for k = 0, span.length - 1 do
				local c = open.cells[span.row][span.col + k]
				c.Text = "."
				c.BackgroundTransparency = 1
				c.TextColor3 = GREEN
			end
		end
	end
end

-- The lockout counts down on screen.
function Screen.update(_host, open)
	if open.lockedAt and (open.state.lockedFor or 0) > 0 then
		local left = open.state.lockedFor - (os.clock() - open.lockedAt)
		if left > 0 then
			open.status.Text = string.format("TERMINAL LOCKED. TRY AGAIN IN %d SECONDS", math.ceil(left))
		else
			open.state.lockedFor = 0
			open.status.Text = "ENTER PASSWORD NOW"
		end
	end
end

return Screen
