-- Reading a note (R2c "leads"): the server sends a note's text only to the
-- player who reads it (Services/ItemService, the NoteText remote), and this
-- shows it on a sheet of notepaper. E, Escape or a click puts it down. What
-- you've read is kept for the journal (UI/Map).
--
-- The 1988 interface (V7): a real sheet (tools/paper.py), ruled, a margin in
-- red, taped down, written in blue ballpoint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local Ui = require(script.Parent.Parent.Lib.Ui)

local _player = Players.LocalPlayer

local Reader = {}
Reader.__index = Reader

local RULE = 32 -- px between ruled lines: one line of writing to each
local TOP = 58

function Reader.new(ctx)
	local self = setmetatable({ ctx = ctx, open = false, read = {}, order = {}, closedAt = 0 }, Reader)
	local gui = Ui.screen("ConsensusReader", 45, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Parent = gui,
	})
	local holder, sheet = Ui.paper("Sheet", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(440, 560),
		Rotation = -1.5,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 560), MinSize = Vector2.new(280, 356), Parent = holder })
	Ui.new("UIAspectRatioConstraint", { AspectRatio = 440 / 560, Parent = holder })
	Ui.modal(holder)
	-- Ruled like a page from a pad, a red margin down the left.
	for i = 1, 14 do
		Ui.new("Frame", {
			Position = UDim2.new(0, 18, 0, TOP + i * RULE),
			Size = UDim2.new(1, -36, 0, 1),
			BackgroundColor3 = Color3.fromRGB(128, 156, 204),
			BackgroundTransparency = 0.5,
			ZIndex = 3,
			Parent = sheet,
		})
	end
	Ui.new("Frame", {
		Position = UDim2.new(0, 46, 0, 18),
		Size = UDim2.new(0, 1, 1, -36),
		BackgroundColor3 = Color3.fromRGB(206, 104, 100),
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.tape(holder, UDim2.new(0.5, 0, 0, 2), 3, 120)
	-- One line of writing to each ruled line, in blue ballpoint.
	self.text = Ui.hand("", {
		Position = UDim2.fromOffset(56, TOP + 4),
		Size = UDim2.new(1, -84, 1, -TOP - 70),
		TextSize = 30,
		LineHeight = RULE / 30,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.Theme.pen,
		ZIndex = 4,
		Parent = sheet,
	})
	Ui.paperButton("Put it down", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(170, 32),
		TextSize = 17,
		ZIndex = 4,
		Parent = sheet,
	}, function()
		self:Close()
	end)
	Ui.subtitle("E or a click to put it down", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 300),
		Size = UDim2.fromOffset(400, 22),
		TextSize = 16,
		TextColor3 = Ui.Theme.textDim,
		Parent = gui,
	})

	Net.get("NoteText").OnClientEvent:Connect(function(note)
		if typeof(note) ~= "table" or typeof(note.text) ~= "string" then
			return
		end
		-- The E that put it down can trigger the note's prompt again.
		if note.id == self.lastId and os.clock() - self.closedAt < 0.5 then
			return
		end
		self:Show(note)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not self.open then
			return
		end
		local key = input.KeyCode
		-- Any click too, wherever it lands (the squad playtest, 2026-10-10:
		-- the button alone didn't: in first person the click never reached it).
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
		if click or key == Enum.KeyCode.E or key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB then
			self:Close()
			Ui.dismissed()
		end
	end)
	-- A new house: last run's notes are gone.
	ctx.state.PhaseChanged:Connect(function()
		if not ctx.state:InRun() then
			self:Close()
			table.clear(self.read)
			table.clear(self.order)
		end
	end)
	return self
end

function Reader:Show(note)
	self.lastId = note.id
	self.text.Text = note.text
	if note.id and not self.read[note.id] then
		self.read[note.id] = note.text
		table.insert(self.order, note.id)
	end
	self.open = true
	self.gui.Enabled = true
	local audio = self.ctx.controllers.AudioController
	if audio and audio.PlayUi then
		audio:PlayUi("Cloth", 0.25, 1.5)
	end
end

function Reader:Close()
	if not self.open then
		return
	end
	self.open = false
	self.gui.Enabled = false
	self.closedAt = os.clock()
end

-- What you've read this run, oldest first: { { id, text } }.
function Reader:Read(): { { id: string, text: string } }
	local list = {}
	for _, id in self.order do
		table.insert(list, { id = id, text = self.read[id] })
	end
	return list
end

return Reader
