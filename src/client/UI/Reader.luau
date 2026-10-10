-- Reading a note (R2c "leads"): the server sends a note's text only to the
-- player who reads it (Services/ItemService, the NoteText remote), and this
-- shows it on a sheet of notepaper. E, Escape or a click puts it down. What
-- you've read is kept for the journal (UI/Map).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local Ui = require(script.Parent.Parent.Lib.Ui)

local _player = Players.LocalPlayer

local Reader = {}
Reader.__index = Reader

local PAPER = Color3.fromRGB(236, 228, 202)
local INK = Color3.fromRGB(38, 44, 84)

function Reader.new(ctx)
	local self = setmetatable({ ctx = ctx, open = false, read = {}, order = {}, closedAt = 0 }, Reader)
	local gui = Ui.screen("ConsensusReader", 45, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Parent = gui,
	})
	local sheet = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(440, 540),
		BackgroundColor3 = PAPER,
		Rotation = -1.5,
		Parent = gui,
	}, {
		Ui.corner(3),
		Ui.stroke(Color3.fromRGB(150, 140, 110), 1, 0.4),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 540), MinSize = Vector2.new(280, 340) }),
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 440 / 540 }),
	})
	Ui.modal(sheet)
	-- Faint ruled lines, like a page torn from a pad.
	for i = 1, 14 do
		Ui.new("Frame", {
			Position = UDim2.new(0, 24, 0, 40 + i * 32),
			Size = UDim2.new(1, -48, 0, 1),
			BackgroundColor3 = Color3.fromRGB(150, 170, 200),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = sheet,
		})
	end
	-- One line of writing to each ruled line (32 px apart).
	self.text = Ui.new("TextLabel", {
		Position = UDim2.fromOffset(34, 44),
		Size = UDim2.new(1, -68, 1, -102),
		BackgroundTransparency = 1,
		Font = Enum.Font.IndieFlower,
		TextSize = 26,
		LineHeight = 32 / 26,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = INK,
		Text = "",
		Parent = sheet,
	})
	Ui.button("Put it down", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(160, 34),
		TextSize = 15,
		Parent = sheet,
	}, function()
		self:Close()
	end)
	Ui.label("E or a click to put it down", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 290),
		Size = UDim2.fromOffset(300, 20),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
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
