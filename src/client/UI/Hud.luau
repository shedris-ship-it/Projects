-- The HUD is deliberately small (doc section 8), and in the 1988 interface
-- (V7) nearly empty: the objective is a slip torn off a notepad that comes
-- when it changes and then goes; stamina is the edges of your sight closing
-- in (and your breath); the torch's charge is on its beam (ActionController).
-- The tool slots are UI/Hotbar, what you look at UI/FocusMarkers; there is no
-- crosshair. Drift is never a bar: you read it from the world, and from one
-- word on the slip. The meters come back with "Show meters" in Settings.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Tools = require(Shared.Data.Tools)
local Util = require(Shared.Lib.Util)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PA = Constants.PlayerAttributes
local RS = Constants.RunState
local PS = Constants.PlayerStates
local I = Config.Interface

local player = Players.LocalPlayer

local Hud = {}
Hud.__index = Hud

-- The objective's handwriting, and where it sits on the slip.
local HAND_SIZE = 27
local SLIP_TOP = 38 -- under the typed heading
local SLIP_SIDE = 26

local function hairline(parent, name, position, width, color)
	local frame = Ui.new("Frame", {
		Name = name,
		Position = position,
		Size = UDim2.fromOffset(width, 3),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = parent,
	})
	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		Parent = frame,
	})
	return frame, fill
end

-- Pale typed words over the world, with a soft dark edge so they read on
-- a lit wall.
local function overWorld(text: string, props)
	local base = {
		TextColor3 = Ui.Theme.text,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.6,
		TextSize = 15,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.label(text, base)
end

function Hud.new(ctx)
	local self = setmetatable({ ctx = ctx, state = ctx.state, slipKey = nil, slipShownAt = -math.huge }, Hud)
	local gui = Ui.screen("ConsensusHud", 5, ctx.playerGui)
	self.gui = gui

	-- Out of breath, the edges of your sight close in (behind everything else).
	self.staminaEdge = Ui.new("ImageLabel", {
		Name = "StaminaEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Assets.Lens.Vignette,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 1,
		ZIndex = 0,
		Parent = gui,
	})

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

	-- What's in your hand (bottom left), and the meters if you want them.
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -26),
		Size = UDim2.fromOffset(420, 92),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.toolLabel = overWorld("", { Size = UDim2.new(1, 0, 0, 20), TextSize = 17, Parent = panel })
	self.toolDetail = overWorld("", {
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local meters = Ui.new("Frame", {
		Name = "Meters",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.fromOffset(220, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	})
	overWorld("breath", { Size = UDim2.fromOffset(220, 14), TextSize = 12, Parent = meters })
	local _, staminaFill = hairline(meters, "Stamina", UDim2.fromOffset(0, 15), 220, Ui.Theme.text)
	overWorld(
		"torch",
		{ Position = UDim2.fromOffset(0, 22), Size = UDim2.fromOffset(220, 14), TextSize = 12, Parent = meters }
	)
	local _, batteryFill = hairline(meters, "Battery", UDim2.fromOffset(0, 37), 220, Color3.fromRGB(255, 226, 160))
	self.staminaFill = staminaFill
	self.batteryFill = batteryFill
	self.meters = meters
	self.panel = panel

	-- The objective (top centre): a slip torn off a notepad, taped up, in
	-- pencil, with the phase and Drift's word typed across its head.
	local slip = Ui.new("CanvasGroup", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(I.SlipWidth + 80, 160),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	})
	local holder, sheet = Ui.paper("Slip", {
		Position = UDim2.fromOffset(40, 16),
		Size = UDim2.fromOffset(I.SlipWidth, 100),
		Rotation = -1.2,
		Parent = slip,
	})
	self.phaseLabel = Ui.typed("", {
		Position = UDim2.fromOffset(SLIP_SIDE, 14),
		Size = UDim2.new(1, -SLIP_SIDE * 2, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.Theme.typeDim,
		ZIndex = 3,
		Parent = sheet,
	})
	self.objectiveLabel = Ui.hand("", {
		Position = UDim2.fromOffset(SLIP_SIDE, SLIP_TOP),
		Size = UDim2.new(1, -SLIP_SIDE * 2, 0, 30),
		TextSize = HAND_SIZE,
		LineHeight = 1.05,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.Theme.pencil,
		ZIndex = 3,
		Parent = sheet,
	})
	Ui.tape(holder, UDim2.new(0, 34, 0, 4), -24, 96)
	self.slip = slip
	self.slipPaper = holder

	-- Squad (top left), when there is one: below Roblox's own buttons there
	-- (its topbar, once it's up).
	self.squad = Ui.new("Frame", {
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(240, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(2) })
	local function clearTopbar()
		self.squad.Position = UDim2.fromOffset(20, math.max(18, GuiService.TopbarInset.Max.Y + 8))
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(clearTopbar)
	clearTopbar()
	self.squadRows = {}

	-- Hiding: what to do, your held breath and the warning.
	local hide = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		-- (Wide enough for the curtain's line: at 420 its "E: leave" wrapped
		-- out of sight, leaving "E:".)
		Size = UDim2.fromOffset(560, 56),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.hideHint = overWorld("", {
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = Ui.Theme.textDim,
		Parent = hide,
	})
	local breathBar, breathFill =
		hairline(hide, "Breath", UDim2.new(0.5, -110, 0, 25), 220, Color3.fromRGB(196, 214, 236))
	self.breathFill = breathFill
	self.breathBar = breathBar
	self.hideDanger = Ui.subtitle("It's close.", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 19,
		TextColor3 = Ui.Theme.danger,
		Visible = false,
		Parent = hide,
	})
	self.hide = hide

	-- The keys, typed small (bottom right), at the start of a run only; the
	-- whole list is in Settings (F1).
	self.help = overWorld(
		"E use · hold E drag · R tool · 1 2 tools · F torch · Ctrl crouch · Shift run · G ping · Tab map · F1 help",
		{
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -12),
			Size = UDim2.fromOffset(820, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 13,
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
	local count = 0
	for _, other in Players:GetPlayers() do
		local state = other:GetAttribute(PA.State)
		if state and state ~= PS.Lobby then
			count += 1
		end
	end
	for _, other in Players:GetPlayers() do
		local state = other:GetAttribute(PA.State)
		-- (Alone, your own name is no news.)
		if state and state ~= PS.Lobby and count > 1 then
			seen[other] = true
			local row = rows[other]
			if not row then
				local label = overWorld(other.DisplayName, {
					Name = "PlayerName",
					Size = UDim2.new(1, 0, 0, 18),
					TextSize = 14,
					Parent = self.squad,
				})
				rows[other] = { frame = label, label = label }
				row = rows[other]
			end
			local text = other.DisplayName
			local color = Ui.Theme.text
			if state == PS.Downed then
				text ..= ": down"
				color = Ui.Theme.danger
			elseif state == PS.Lost then
				text ..= ": an echo"
				color = Ui.Theme.textDim
			elseif state == PS.Extracted then
				text ..= ": got out"
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

-- The slip's words: it fits them, and comes back whenever they change
-- (Config.Interface Slip*). `pinned`: it stays (the run's last minutes).
function Hud:_slip(heading: string, objective: string, pinned: boolean)
	local key = heading .. "\n" .. objective
	if key ~= self.slipKey then
		local changed = self.slipKey ~= nil
		self.slipKey = key
		self.phaseLabel.Text = heading
		self.objectiveLabel.Text = objective
		local width = I.SlipWidth - SLIP_SIDE * 2
		local bounds = TextService:GetTextSize(objective, HAND_SIZE, Enum.Font.Kalam, Vector2.new(width, math.huge))
		local textHeight = math.max(HAND_SIZE + 4, math.ceil(bounds.Y * 1.05) + 6)
		self.objectiveLabel.Size = UDim2.new(1, -SLIP_SIDE * 2, 0, textHeight)
		local height = SLIP_TOP + textHeight + 20
		self.slipPaper.Size = UDim2.fromOffset(I.SlipWidth, height)
		self.slip.Size = UDim2.fromOffset(I.SlipWidth + 80, height + 50)
		self.slipShownAt = os.clock()
		self.slipFading = false
		Ui.tween(self.slip, I.SlipFadeIn, { GroupTransparency = 0 })
		-- A slip of paper (not on the first: the run's start has its sounds).
		local audio = self.ctx.controllers.AudioController
		if changed and audio and audio.PlayUi then
			audio:PlayUi("Cloth", 0.12, 1.7)
		end
	elseif pinned then
		self.slipShownAt = os.clock()
		if self.slipFading then
			self.slipFading = false
			Ui.tween(self.slip, I.SlipFadeIn, { GroupTransparency = 0 })
		end
	elseif not self.slipFading and os.clock() - self.slipShownAt > I.SlipHold then
		self.slipFading = true
		Ui.tween(self.slip, I.SlipFadeOut, { GroupTransparency = 1 })
	end
end

function Hud:Update()
	local state = self.state
	local inRun = state:InRun()
	local phase = state:Phase()
	-- (Put away while a cutscene or a takedown has the camera: the cinema's
	-- bars and nothing else, Controllers/CinemaController.)
	local cinema = self.ctx.controllers and self.ctx.controllers.CinemaController
	self.gui.Enabled = inRun and not (cinema and cinema:Active())
	if not inRun then
		self.slipKey = nil
		self.slip.GroupTransparency = 1
		return
	end
	local myState = state:PlayerState()
	local active = myState == PS.Active
	local settings = state.settings
	self.reticle.Visible = active and not state:IsTucked() and settings.centerDot == true
	local runTime = state:Run(RS.RunTime) or 0
	local early = runTime < I.HelpSeconds

	-- What's in your hand (the slots themselves are UI/Hotbar)
	local toolId = player:GetAttribute(PA.Tool)
	local tool = Tools.ById[toolId]
	-- The torch has its own hand and its own key (section 20); this names the
	-- tool in the other, if any.
	self.toolLabel.Text = tool and tool.name or ""
	local detail = ""
	local hands = self.ctx.controllers.HandsController
	local actions = self.ctx.controllers.ActionController
	if hands and hands:IsCarrying() then
		detail = "Click: throw (hold to wind up) · E: put down · wheel: nearer, further"
	elseif not tool then
		-- (The torch's key, while the key hints show.)
		if early then
			detail = (actions and actions:TorchWanted()) and "F: put the torch away" or "F: raise the torch"
		end
	elseif toolId == "Radio" then
		local signal = player:GetAttribute("RadioSignal") or 0
		detail = "Static " .. string.rep("|", math.floor(signal * 10)) .. string.rep(".", 10 - math.floor(signal * 10))
	elseif toolId == "Lantern" then
		detail = player:GetAttribute("LanternOn") and "Lantern lit (R near a shrine to light it)"
			or "R: lantern · near a shrine: light it"
	end
	if tool and not (hands and hands:IsCarrying()) then
		-- (The squad playtest, 2026-10-10: "I didn't know how to drop stuff.")
		detail ..= (detail ~= "" and "  ·  " or "") .. "X: drop"
	end
	local carrying = player:GetAttribute(PA.Carrying)
	if carrying then
		detail ..= (detail ~= "" and "  ·  " or "") .. "carrying a key"
	end
	-- The escape's keys on your ring (Services/LockService). (Words: the font
	-- has no key glyph.)
	local keys = player:GetAttribute(PA.Keys)
	if typeof(keys) == "string" and keys ~= "" then
		detail ..= (detail ~= "" and "  ·  " or "") .. "keys: " .. (string.gsub(keys, "\n", ", "))
	end
	self.toolDetail.Text = detail
	local stamina = actions and actions.stamina or 1
	self.staminaFill.Size = UDim2.fromScale(stamina, 1)
	self.staminaFill.BackgroundColor3 = (actions and actions.exhausted) and Ui.Theme.danger or Ui.Theme.text
	self.batteryFill.Size = UDim2.fromScale(player:GetAttribute(PA.Battery) or 1, 1)
	self.meters.Visible = settings.showMeters == true
	self.panel.Visible = active

	-- Out of breath: the edges close in, breathing as you do.
	local short = active and math.clamp((I.StaminaFrom - stamina) / I.StaminaFrom, 0, 1) or 0
	if actions and actions.exhausted and active then
		short = math.max(short, 0.75) * (0.85 + 0.15 * math.sin(os.clock() * 5))
	end
	self.staminaEdge.ImageTransparency = 1 - short * I.StaminaVignette

	-- The slip: phase and Drift's word typed across its head, the objective
	-- in pencil (the Reckoning: Drift 100, a hunt that never ends).
	local phaseText = PHASE_TEXT[phase] or string.upper(phase)
	local reckoning = state:Run(RS.Reckoning) and phase ~= "Extraction"
	if reckoning then
		phaseText = "THE RECKONING"
	end
	local driftState = state:Run(RS.DreadState) or state:Run(RS.DriftState)
	local heading = phaseText .. (driftState and ("  ·  " .. string.lower(driftState)) or "")
	local endsAt = state:Run(RS.PhaseEndsAt)
	local extraction = phase == "Extraction" and endsAt ~= nil
	self:_slip(heading, state:Run(RS.Objective) or "", extraction or reckoning)
	-- (The map has its own slip; this one would poke out above it.)
	local map = self.ctx.ui.components.Map
	self.slip.Visible = not (map and map.open)
	if extraction then
		-- The clock ticks on the typed line without bringing the slip back.
		self.phaseLabel.Text = heading .. "  ·  " .. Util.formatClock(endsAt - Workspace:GetServerTimeNow())
	end

	-- Hiding
	local hidden = state:IsHidden()
	self.hide.Visible = hidden
	if hidden then
		self.breathFill.Size = UDim2.fromScale(player:GetAttribute("Breath") or 1, 1)
		-- In a walk-in place you get out by opening its door yourself.
		-- (Short: the longer line ran off the end of its box.)
		self.hideHint.Text = player:GetAttribute("HidePhysical") and "Space: hold your breath · E on the door: get out"
			or "Right click: peek · Space: hold your breath · E: leave"
		self.hideDanger.Visible = player:GetAttribute("HideDanger") == true
	end

	self.help.Visible = early
	self:_squad()
end

return Hud
