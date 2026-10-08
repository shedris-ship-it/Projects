-- The music box's tune on screen (server/Puzzles/MusicBox): as the box plays
-- near you, each note's colour fills the next slot of a strip at the top of
-- the screen, its name under it ("red, blue, green..."), so the tune can be
-- remembered or called out to whoever is at the piano. It fades a moment
-- after the last note. The squad playtest (2026-10-08) found the tune
-- impossible to read by ear alone; the comb's teeth light as well
-- (Controllers/AudioController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Ui = require(script.Parent.Parent.Lib.Ui)

local M = Config.MusicBox

local function colorOf(k: number): Color3
	local rgb = M.Colors[k].rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local TuneStrip = {}
TuneStrip.__index = TuneStrip

function TuneStrip.new(ctx)
	local self = setmetatable({ ctx = ctx, slots = {}, hideAt = nil, box = nil }, TuneStrip)
	-- Above the piano's screen (UI/Puzzle is 46), so it shows while you play.
	local gui = Ui.screen("ConsensusTuneStrip", 47, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	self.panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104), -- under the objective line
		Size = UDim2.fromOffset(340, 92),
		BackgroundColor3 = Color3.fromRGB(24, 18, 16),
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(150, 120, 70), 2, 0.2) })
	self.title = Ui.label("THE MUSIC BOX", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.fontType,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(236, 222, 190),
		Parent = self.panel,
	})
	local function watch(model: Instance)
		model:GetAttributeChangedSignal("Comb"):Connect(function()
			self:_note(model)
		end)
	end
	for _, model in CollectionService:GetTagged("ConsensusMusicBox") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("ConsensusMusicBox"):Connect(watch)
	return self
end

-- Lay out `n` empty slots.
function TuneStrip:_reset(n: number)
	for _, slot in self.slots do
		slot.frame:Destroy()
	end
	self.slots = {}
	local width = math.max(220, n * 64 + 20)
	self.panel.Size = UDim2.fromOffset(width, 92)
	for i = 1, n do
		local frame = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (n + 1) / 2) * 64, 0, 30),
			Size = UDim2.fromOffset(56, 56),
			BackgroundTransparency = 1,
			Parent = self.panel,
		})
		local dot = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.fromRGB(60, 50, 44),
			Parent = frame,
		}, { Ui.corner(15), Ui.stroke(Color3.fromRGB(110, 92, 70), 1.5, 0) })
		local name = Ui.label("", {
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(220, 210, 190),
			Parent = frame,
		})
		self.slots[i] = { frame = frame, dot = dot, name = name }
	end
end

function TuneStrip:_note(model: Instance)
	local key, index, count = string.match(tostring(model:GetAttribute("Comb")), "^(%d+):(%d+):(%d+)")
	key, index, count = tonumber(key), tonumber(index), tonumber(count)
	if not key or not index or not count or not M.Colors[key] then
		return
	end
	local camera = Workspace.CurrentCamera
	local part = model:IsA("Model") and model.PrimaryPart
	if not camera or not part or (camera.CFrame.Position - part.Position).Magnitude > M.StripReach then
		return
	end
	if index == 1 or self.box ~= model or #self.slots ~= count then
		self.box = model
		self:_reset(count)
	end
	local slot = self.slots[index]
	if slot then
		slot.dot.BackgroundColor3 = colorOf(key)
		slot.name.Text = M.Colors[key].name
		slot.dot.Size = UDim2.fromOffset(36, 36)
		Ui.tween(slot.dot, 0.25, { Size = UDim2.fromOffset(30, 30) })
	end
	self.gui.Enabled = true
	-- Long enough to reach the next note; after the last, a moment to read it.
	self.hideAt = os.clock() + (index >= count and M.StripHold or M.NoteGap * 2.5)
end

function TuneStrip:Update(_dt: number)
	if self.hideAt and os.clock() >= self.hideAt then
		self.hideAt = nil
		self.gui.Enabled = false
	end
end

return TuneStrip
