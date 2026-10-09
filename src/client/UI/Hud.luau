-- The HUD is deliberately small (doc section 8): a Focus ring, what is in your
-- hands (the three slots are UI/Hotbar) and the squad. There is no crosshair (UI/FocusMarkers marks what you
-- look at). Drift is never a bar; you read it from the world, and from one word.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Tools = require(Shared.Data.Tools)
local Util = require(Shared.Lib.Util)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PA = Constants.PlayerAttributes
local RS = Constants.RunState
local PS = Constants.PlayerStates

local player = Players.LocalPlayer

local Hud = {}
Hud.__index = Hud

local function bar(parent, name, position, color)
	local frame = Ui.new("Frame", {
		Name = name,
		Position = position,
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Ui.Theme.panelLight,
		BackgroundTransparency = 0.3,
		Parent = parent,
	}, { Ui.corner(3) })
	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = frame,
	}, { Ui.corner(3) })
	return frame, fill
end

function Hud.new(ctx)
	local self = setmetatable({ ctx = ctx, state = ctx.state }, Hud)
	local gui = Ui.screen("ConsensusHud", 5, ctx.playerGui)
	self.gui = gui

	-- No crosshair by default: objects show their own markers (UI/FocusMarkers).
	-- The centre dot is an opt-in aiming aid in Settings.
	self.reticle = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Ui.Theme.text,
		BackgroundTransparency = 0.5,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(2) })

	-- Tool and meters (bottom left).
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -30),
		Size = UDim2.fromOffset(220, 92),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.toolLabel =
		Ui.label("", { Size = UDim2.new(1, 0, 0, 20), Font = Ui.Theme.fontBold, TextSize = 16, Parent = panel })
	self.toolDetail = Ui.label("", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	Ui.label("Stamina", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local _, staminaFill = bar(panel, "Stamina", UDim2.fromOffset(0, 56), Color3.fromRGB(200, 200, 200))
	self.staminaFill = staminaFill
	Ui.label("Flashlight", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local _, batteryFill = bar(panel, "Battery", UDim2.fromOffset(0, 78), Color3.fromRGB(255, 230, 160))
	self.batteryFill = batteryFill
	self.panel = panel

	-- Phase, Drift word and the objective line (top centre).
	local top = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(520, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.phaseLabel = Ui.label("", {
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.fontType,
		TextSize = 20,
		TextColor3 = Ui.Theme.text,
		TextStrokeTransparency = 0.6,
		Parent = top,
	})
	self.objectiveLabel = Ui.label("", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = Ui.Theme.ritual,
		TextStrokeTransparency = 0.6,
		Parent = top,
	})

	-- Squad (top left).
	self.squad = Ui.new("Frame", {
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(220, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(4) })
	self.squadRows = {}

	-- Hiding: breath meter and hints.
	local hide = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.fromOffset(300, 54),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.hideHint = Ui.label("Hold SPACE to hold your breath · E to leave", {
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		Parent = hide,
	})
	local breathBar, breathFill = bar(hide, "Breath", UDim2.fromOffset(0, 24), Color3.fromRGB(160, 200, 255))
	self.breathFill = breathFill
	self.breathBar = breathBar
	self.hideDanger = Ui.label("It's close.", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = Ui.Theme.danger,
		Visible = false,
		Parent = hide,
	})
	self.hide = hide

	-- Controls reminder (bottom right, fades after the first minutes).
	self.help = Ui.label(
		"E: use · hold E: drag · R: tool · 1 2 3: slots · F: light · Ctrl: crouch · Shift: run · G: ping · Tab: map · F1: help",
		{
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 1, -12),
			Size = UDim2.fromOffset(640, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 12,
			TextColor3 = Ui.Theme.textDim,
			Parent = gui,
		}
	)
	return self
end

local PHASE_TEXT = {
	-- The escape's phases, in its own words (the clue loop's INVESTIGATION and
	-- RESOLUTION retired with it).
	Arrival = "LOCKED IN",
	Investigation = "THE HOUSE",
	Resolution = "THE DINNER",
	Extraction = "GET OUT",
}

function Hud:_squad()
	local rows = self.squadRows
	local seen = {}
	for _, other in Players:GetPlayers() do
		local state = other:GetAttribute(PA.State)
		if state and state ~= PS.Lobby then
			seen[other] = true
			local row = rows[other]
			if not row then
				row =
					Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = self.squad })
				local nameLabel = Ui.label(
					other.DisplayName,
					{ Name = "PlayerName", Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Parent = row }
				)
				rows[other] = { frame = row, label = nameLabel }
				row = rows[other]
			end
			local text = other.DisplayName
			local color = Ui.Theme.text
			if state == PS.Downed then
				text ..= "  — DOWN"
				color = Ui.Theme.danger
			elseif state == PS.Lost then
				text ..= "  — Echo"
				color = Ui.Theme.textDim
			elseif state == PS.Extracted then
				text ..= "  — out"
				color = Ui.Theme.good
			end
			row.label.Text = text
			row.label.TextColor3 = color
		end
	end
	for other, row in rows do
		if not seen[other] then
			row.frame:Destroy()
			rows[other] = nil
		end
	end
end

function Hud:Update()
	local state = self.state
	local inRun = state:InRun()
	local phase = state:Phase()
	self.gui.Enabled = inRun
	if not inRun then
		return
	end
	local myState = state:PlayerState()
	local active = myState == PS.Active
	self.reticle.Visible = active and not state:IsTucked() and state.settings.centerDot == true

	-- What's in your hands (the slots themselves are UI/Hotbar)
	local toolId = player:GetAttribute(PA.Tool)
	local tool = Tools.ById[toolId]
	local activeSlot = player:GetAttribute(PA.ActiveSlot) or 1
	local torchHeld = toolId == nil and activeSlot == 1
	-- An empty slot: a free hand (the torch on your shirt).
	local handsFree = toolId == nil and activeSlot ~= 1
	self.toolLabel.Text = tool and tool.name or (torchHeld and "Flashlight" or "A free hand")
	local detail = ""
	local hands = self.ctx.controllers.HandsController
	if hands and hands:IsCarrying() then
		detail = "Click: throw (hold to wind up) · E: put down · wheel: nearer, further"
	elseif torchHeld then
		detail = player:GetAttribute(PA.Flashlight) and "F: switch off" or "F: switch on"
	elseif handsFree then
		-- The torch rides clipped to your shirt while your hands are free.
		detail = player:GetAttribute(PA.Flashlight) and "F: clip light off" or "F: clip light on"
	elseif toolId == "Radio" then
		local signal = player:GetAttribute("RadioSignal") or 0
		detail = "Static "
			.. string.rep("▮", math.floor(signal * 10))
			.. string.rep("▯", 10 - math.floor(signal * 10))
	elseif toolId == "Lantern" then
		detail = player:GetAttribute("LanternOn") and "Lantern lit (R near a shrine to light it)"
			or "R: lantern · near a shrine: light it"
	end
	local carrying = player:GetAttribute(PA.Carrying)
	if carrying then
		detail ..= "  ·  carrying a key"
	end
	-- The escape's keys on your ring (Services/LockService).
	local keys = player:GetAttribute(PA.Keys)
	if typeof(keys) == "string" and keys ~= "" then
		detail ..= "  ·  🔑 " .. (string.gsub(keys, "\n", ", "))
	end
	self.toolDetail.Text = detail
	local actions = self.ctx.controllers.ActionController
	self.staminaFill.Size = UDim2.fromScale(actions.stamina or 1, 1)
	self.staminaFill.BackgroundColor3 = actions.exhausted and Ui.Theme.danger or Color3.fromRGB(200, 200, 200)
	self.batteryFill.Size = UDim2.fromScale(player:GetAttribute(PA.Battery) or 1, 1)
	self.panel.Visible = active

	-- Phase and Drift word (the Reckoning: Drift 100, a hunt that never ends)
	local phaseText = PHASE_TEXT[phase] or string.upper(phase)
	if state:Run(RS.Reckoning) and phase ~= "Extraction" then
		phaseText = "THE RECKONING"
	end
	local driftState = state:Run(RS.DreadState) or state:Run(RS.DriftState)
	local endsAt = state:Run(RS.PhaseEndsAt)
	local timer = ""
	if phase == "Extraction" and endsAt then
		timer = "  ·  " .. Util.formatClock(endsAt - Workspace:GetServerTimeNow())
	end
	self.phaseLabel.Text = phaseText .. (driftState and ("  ·  " .. string.lower(driftState)) or "") .. timer
	self.objectiveLabel.Text = state:Run(RS.Objective) or ""

	-- Hiding
	local hidden = state:IsHidden()
	self.hide.Visible = hidden
	if hidden then
		self.breathFill.Size = UDim2.fromScale(player:GetAttribute("Breath") or 1, 1)
		-- In a walk-in place you get out by opening its door yourself.
		-- (Short: the longer line ran off the end of its box.)
		self.hideHint.Text = player:GetAttribute("HidePhysical") and "SPACE: hold breath · E on the door: get out"
			or "Right click: peek · SPACE: hold breath · E: leave"
		self.hideDanger.Visible = player:GetAttribute("HideDanger") == true
	end

	local runTime = state:Run(RS.RunTime) or 0
	self.help.Visible = runTime < 240
	self:_squad()
end

return Hud
