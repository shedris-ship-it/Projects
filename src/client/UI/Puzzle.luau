-- The escape's puzzle screens (docs/plans/gameplay-rework.md section 7):
-- the home computer's password hack and a door's padlock. The server
-- (Services/PuzzleService) opens one for you at its station and says what
-- each click did; this only draws it and sends what you clicked. Escape or
-- "Step back" leaves it (so does walking off).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local GREEN = Color3.fromRGB(110, 255, 140)
local DIM = Color3.fromRGB(60, 150, 80)
local SCREEN = Color3.fromRGB(8, 18, 11)
local CELL_W, CELL_H = 11, 22
local COLUMN_CHARS = 7 + 12 -- "0xF4F0 " and twelve characters

local Puzzle = {}
Puzzle.__index = Puzzle

function Puzzle.new(ctx)
	local self = setmetatable({ ctx = ctx, open = nil }, Puzzle)
	local gui = Ui.screen("ConsensusPuzzle", 46, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Net.get("PuzzleOpen").OnClientEvent:Connect(function(id, kind, view, state)
		self:_show(id, kind, view, state)
	end)
	Net.get("PuzzleState").OnClientEvent:Connect(function(id, state, events)
		if self.open and self.open.id == id then
			self.open.state = state
			self:_refresh(events or {})
		end
	end)
	Net.get("PuzzleClose").OnClientEvent:Connect(function(id)
		if self.open and self.open.id == id then
			self:_hide(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if self.open and input.KeyCode == Enum.KeyCode.Escape then
			self:_hide(true)
		end
	end)
	return self
end

local function cell(parent, x: number, y: number, text: string)
	return Ui.new("TextLabel", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(CELL_W, CELL_H),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = GREEN,
		Font = Enum.Font.Code,
		TextSize = 18,
		Parent = parent,
	})
end

function Puzzle:_hide(tell: boolean)
	local open = self.open
	self.open = nil
	self.gui.Enabled = false
	if open and open.panel then
		open.panel:Destroy()
	end
	if open and tell then
		Net.get("PuzzleLeave"):FireServer(open.id)
	end
end

function Puzzle:_show(id: string, kind: string, view, state)
	self:_hide(false)
	self.open = { id = id, kind = kind, view = view, state = state }
	if kind == "terminal" then
		self:_buildTerminal()
	else
		self:_buildPadlock()
	end
	self.gui.Enabled = true
	self:_refresh({})
end

-- The computer ---------------------------------------------------------------------

function Puzzle:_buildTerminal()
	local open = self.open
	local view = open.view
	local rows = #view.lines // 2
	local dumpWidth = 2 * COLUMN_CHARS * CELL_W + 24
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(dumpWidth + 300, rows * CELL_H + 150),
		BackgroundColor3 = SCREEN,
		Parent = self.gui,
	}, { Ui.corner(14), Ui.stroke(Color3.fromRGB(196, 186, 162), 8, 0), Ui.padding(18) })
	Ui.modal(panel)
	open.panel = panel
	local function line(y: number, text: string)
		return Ui.new("TextLabel", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = GREEN,
			Font = Enum.Font.Code,
			TextSize = 18,
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
			Font = Enum.Font.Code,
			TextSize = 18,
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
		button.MouseEnter:Connect(function()
			if not entry.dead then
				light(true)
			end
		end)
		button.MouseLeave:Connect(function()
			light(false)
		end)
		button.Activated:Connect(function()
			if entry.dead or open.state.solved then
				return
			end
			if span.kind == "word" then
				Net.get("PuzzleInput"):FireServer(open.id, "word", span.word)
			else
				Net.get("PuzzleInput"):FireServer(open.id, "bracket", nil, span.index)
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
		Font = Enum.Font.Code,
		TextSize = 18,
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
		Font = Enum.Font.Code,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Ui.button("Step back", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(130, 34),
		BackgroundColor3 = SCREEN,
		TextColor3 = GREEN,
		Font = Enum.Font.Code,
		Parent = panel,
	}, function()
		self:_hide(true)
	end)
end

function Puzzle:_refreshTerminal()
	local open = self.open
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

-- The padlock ----------------------------------------------------------------------

function Puzzle:_buildPadlock()
	local open = self.open
	local wheels = open.view.wheels
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120 + wheels * 70, 300),
		BackgroundColor3 = Ui.Theme.panel,
		Parent = self.gui,
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
		Ui.button("▲", {
			Position = UDim2.fromOffset(x, 40),
			Size = UDim2.fromOffset(56, 34),
			Parent = panel,
		}, function()
			Net.get("PuzzleInput"):FireServer(open.id, "turn", nil, w, 1)
		end)
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
			Net.get("PuzzleInput"):FireServer(open.id, "turn", nil, w, -1)
		end)
	end
	Ui.button("Pull", {
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(0.5, -6, 0, 40),
		Parent = panel,
	}, function()
		Net.get("PuzzleInput"):FireServer(open.id, "pull")
	end)
	Ui.button("Step back", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 200),
		Size = UDim2.new(0.5, -6, 0, 40),
		Parent = panel,
	}, function()
		self:_hide(true)
	end)
end

function Puzzle:_refreshPadlock(events)
	local open = self.open
	for w, label in open.digits do
		label.Text = tostring(open.state.digits[w] or 0)
	end
	for _, event in events do
		if event.kind == "rattle" then
			Ui.tween(open.panel, 0.05, { Position = UDim2.new(0.5, 6, 0.5, 0) }).Completed:Connect(function()
				if open.panel.Parent then
					Ui.tween(open.panel, 0.08, { Position = UDim2.fromScale(0.5, 0.5) })
				end
			end)
		end
	end
end

function Puzzle:_refresh(events)
	if not self.open then
		return
	end
	if self.open.kind == "terminal" then
		self:_refreshTerminal()
	else
		self:_refreshPadlock(events)
	end
end

function Puzzle:Update()
	local open = self.open
	if open and open.kind == "terminal" and open.lockedAt and (open.state.lockedFor or 0) > 0 then
		local left = open.state.lockedFor - (os.clock() - open.lockedAt)
		if left > 0 then
			open.status.Text = string.format("TERMINAL LOCKED. TRY AGAIN IN %d SECONDS", math.ceil(left))
		else
			open.state.lockedFor = 0
			open.status.Text = "ENTER PASSWORD NOW"
		end
	end
	-- Downed or out of the run: gone.
	if open and not self.ctx.state:IsActive() then
		self:_hide(true)
	end
end

return Puzzle
