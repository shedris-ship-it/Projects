-- The escape's puzzle screens (docs/plans/gameplay-rework.md section 7). The
-- server (Services/PuzzleService) opens one for you at its station and says
-- what each click did; this hosts the screen for that kind (UI/Puzzles/*:
-- build, refresh, and optionally update each frame) and sends what you
-- clicked. Escape, B or "Step back" leaves it (so does walking off, being
-- downed, or a hunt coming). With a gamepad, the screen's first button is
-- selected so it can be driven with the stick.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local SCREENS = {}
for _, module in script.Parent:WaitForChild("Puzzles"):GetChildren() do
	SCREENS[string.lower(module.Name)] = require(module)
end

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
			self:Hide(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if self.open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			self:Hide(true)
		end
	end)
	return self
end

-- For the screens ----------------------------------------------------------------------

-- Send a click to the server: (action, word?, a?, b?).
function Puzzle:Send(action: string, word: string?, a: number?, b: number?)
	local open = self.open
	if open then
		Net.get("PuzzleInput"):FireServer(open.id, action, word, a, b)
	end
end

-- A short shake, for a wrong try.
function Puzzle:Shake(panel: GuiObject)
	Ui.tween(panel, 0.05, { Position = UDim2.new(0.5, 6, 0.5, 0) }).Completed:Connect(function()
		if panel.Parent then
			Ui.tween(panel, 0.08, { Position = UDim2.fromScale(0.5, 0.5) })
		end
	end)
end

-- Close it; `tell` the server you stepped back.
function Puzzle:Hide(tell: boolean)
	local open = self.open
	self.open = nil
	self.gui.Enabled = false
	if open and open.panel then
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(open.panel) then
			GuiService.SelectedObject = nil
		end
		open.panel:Destroy()
	end
	if open and tell then
		Net.get("PuzzleLeave"):FireServer(open.id)
	end
end

-- Opening ---------------------------------------------------------------------------

function Puzzle:_show(id: string, kind: string, view, state)
	self:Hide(false)
	local screen = SCREENS[kind]
	if not screen then
		warn("[Consensus] no screen for puzzle kind " .. tostring(kind))
		return
	end
	self.open = { id = id, kind = kind, view = view, state = state, screen = screen }
	screen.build(self, self.open)
	self.gui.Enabled = true
	self:_refresh({})
	if UserInputService.GamepadEnabled and self.open.first then
		GuiService.SelectedObject = self.open.first
	end
end

function Puzzle:_refresh(events)
	local open = self.open
	if open then
		open.screen.refresh(self, open, events)
	end
end

function Puzzle:Update(dt: number)
	local open = self.open
	if not open then
		return
	end
	if open.screen.update then
		open.screen.update(self, open, dt)
	end
	-- Downed or out of the run: gone.
	if self.open and not self.ctx.state:IsActive() then
		self:Hide(true)
	end
end

return Puzzle
