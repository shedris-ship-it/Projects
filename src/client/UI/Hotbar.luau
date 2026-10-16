-- What you carry (owner, 2026-10-04; docs/plans/gameplay-rework.md section 4.1,
-- reworked in section 20): the torch on its own at the left, F to raise it or
-- put it away, with its battery under it; then the two slots for tools found
-- around the house, 1 and 2, one in your right hand at a time (its key again
-- puts it away). Bottom centre. Press the keys, spin the wheel, or tap; X puts
-- the tool in your hand down. Everything shown is read from the player's
-- replicated attributes the server sets (Services/ToolService,
-- Services/PlayerStateService), so the bar can't disagree with what you hold.
--
-- Each icon is the real model in a small ViewportFrame (World/ToolModel), so
-- what you see on the bar is what you find on the table.
--
-- The 1988 interface (V7): the bar shows while you switch (or pick up, or
-- raise the torch) and fades a moment later (Config.Interface.HotbarHold);
-- with "Show meters" on it stays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Tools = require(Shared.Data.Tools)
local Inventory = require(Shared.Logic.Inventory)
local ToolModel = require(Shared.World.ToolModel)

local Ui = require(script.Parent.Parent.Lib.Ui)

local PA = Constants.PlayerAttributes
local PS = Constants.PlayerStates

local player = Players.LocalPlayer

local SLOT = 64
local GAP = 8
local TORCH_GAP = 18 -- the torch sits apart: it isn't one of the slots

local Hotbar = {}
Hotbar.__index = Hotbar

-- A small picture of a tool: its model, seen from the front and a little above.
local function icon(parent: Instance, id: string)
	local model = id == Inventory.TORCH and ToolModel.torch(player:GetAttribute(PA.TorchLook)) or ToolModel.tool(id)
	if not model then
		return nil
	end
	local view = Ui.new("ViewportFrame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 184, 176),
		LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(-0.4, -0.8, 0.5),
		Parent = parent,
	})
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local center, size = model:GetBoundingBox()
	local distance = (size.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0.7, 0.45, -1).Unit * distance, center.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

-- One square: its key in the corner, a word in the other, a meter along the bottom.
local function cell(parent: Instance, x: number, key: string, onTap: () -> ())
	local button = Ui.new("TextButton", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(SLOT, SLOT),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Ui.Theme.ink,
		BackgroundTransparency = 0.35,
		Parent = parent,
	}, { Ui.corner(3) })
	local stroke = Ui.stroke(Ui.Theme.accent, 1, 0.75)
	stroke.Parent = button
	local keyLabel = Ui.label(key, {
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.fromOffset(14, 14),
		TextSize = 13,
		TextColor3 = Ui.Theme.textDim,
		ZIndex = 3,
		Parent = button,
	})
	local extra = Ui.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 3),
		Size = UDim2.fromOffset(40, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		TextColor3 = Ui.Theme.accent,
		ZIndex = 3,
		Parent = button,
	})
	local meter = Ui.new("Frame", {
		Position = UDim2.new(0, 6, 1, -7),
		Size = UDim2.new(1, -12, 0, 2),
		BackgroundColor3 = Ui.Theme.panelLight,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	local meterFill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 230, 160),
		ZIndex = 3,
		Parent = meter,
	})
	button.Activated:Connect(onTap)
	return {
		button = button,
		stroke = stroke,
		key = keyLabel,
		extra = extra,
		meter = meter,
		meterFill = meterFill,
		icon = nil,
	}
end

-- `alpha`: how far the bar has faded in (0 gone, 1 shown).
local function lightUp(entry, on: boolean, alpha: number)
	local function fade(rest: number): number
		return 1 - (1 - rest) * alpha
	end
	entry.button.BackgroundTransparency = fade(on and 0.15 or 0.5)
	entry.stroke.Transparency = fade(on and 0 or 0.8)
	entry.stroke.Thickness = on and 2 or 1
	entry.key.TextTransparency = fade(0)
	entry.extra.TextTransparency = fade(0)
	entry.meter.BackgroundTransparency = fade(0)
	entry.meterFill.BackgroundTransparency = fade(0)
	if entry.icon and entry.icon:IsA("ViewportFrame") then
		entry.icon.ImageTransparency = fade(on and 0 or 0.35)
	end
end

function Hotbar.new(ctx)
	local self = setmetatable({ ctx = ctx, slots = {}, shown = {}, alpha = 0, shownAt = -math.huge }, Hotbar)
	for slot = 1, Inventory.SLOTS do
		self.shown[slot] = ""
	end
	local gui = Ui.screen("ConsensusHotbar", 6, ctx.playerGui)
	self.gui = gui
	local slotsWidth = SLOT * Inventory.SLOTS + GAP * (Inventory.SLOTS - 1)
	local width = SLOT + TORCH_GAP + slotsWidth
	self.root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(width, SLOT + 18),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	self.torch = cell(self.root, 0, "F", function()
		local actions = ctx.controllers and ctx.controllers.ActionController
		if actions then
			actions:ToggleTorch()
		end
	end)
	self.torch.icon = icon(self.torch.button, Inventory.TORCH)
	self.torch.meter.Visible = true
	for slot = 1, Inventory.SLOTS do
		local x = SLOT + TORCH_GAP + (slot - 1) * (SLOT + GAP)
		self.slots[slot] = cell(self.root, x, tostring(slot), function()
			Net.get("SelectSlot"):FireServer(slot)
		end)
		self.slots[slot].button.Name = "Slot" .. slot
	end
	self.name = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0, SLOT + TORCH_GAP + slotsWidth / 2, 0, SLOT + 2),
		Size = UDim2.fromOffset(slotsWidth + 80, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = Ui.Theme.text,
		TextStrokeTransparency = 0.7,
		Parent = self.root,
	})
	return self
end

-- The slot ids as the server last told us.
function Hotbar:_ids(): { string }
	local ids = {}
	for slot, name in PA.Slots do
		ids[slot] = player:GetAttribute(name) or ""
	end
	return ids
end

local function nameOf(id: string): string
	local info = Tools.ById[id]
	return info and info.name or id
end

function Hotbar:Update(dt: number)
	local state = self.ctx.state
	-- (Hidden anywhere, the breath bar sits here.)
	local visible = state:InRun() and state:PlayerState() == PS.Active and not state:IsHidden()
	if not visible then
		self.root.Visible = false
		self.signature = nil
		self.alpha = 0
		return
	end

	-- The tools' modelled meshes arrive from the server a moment after start
	-- (World/Kit.share): the pictures are drawn again when they do.
	local kit = ReplicatedStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	local count = meshes and #meshes:GetChildren() or 0
	-- (Again for your torch look, LB4.)
	local look = player:GetAttribute(PA.TorchLook)
	if count ~= self.meshCount or look ~= self.look then
		self.meshCount = count
		self.look = look
		if self.torch.icon then
			self.torch.icon:Destroy()
		end
		self.torch.icon = icon(self.torch.button, Inventory.TORCH)
		for slot in self.slots do
			self.shown[slot] = nil
		end
	end

	-- The torch: up or not, its battery, and lit, clipped (at a tool lock) or dead.
	local actions = self.ctx.controllers and self.ctx.controllers.ActionController
	local up = actions ~= nil and actions:TorchWanted()
	local battery = player:GetAttribute(PA.Battery) or 1
	local ids = self:_ids()
	local active = player:GetAttribute(PA.ActiveSlot) or Inventory.FREE

	-- Shown while something on it changes, then it fades (V7).
	local signature = table.concat(ids, ",")
		.. "|"
		.. tostring(active)
		.. "|"
		.. tostring(up)
		.. "|"
		.. tostring(battery <= 0)
	if signature ~= self.signature then
		self.signature = signature
		self.shownAt = os.clock()
	end
	local keep = state.settings.showMeters == true or os.clock() - self.shownAt < Config.Interface.HotbarHold
	self.alpha += ((keep and 1 or 0) - self.alpha) * math.clamp((dt or 0) * (keep and 12 or 3), 0, 1)
	local alpha = self.alpha
	self.root.Visible = alpha > 0.01
	if alpha <= 0.01 then
		return
	end

	lightUp(self.torch, up, alpha)
	self.torch.meterFill.Size = UDim2.fromScale(battery, 1)
	if battery <= 0 then
		self.torch.extra.Text = "dead"
	elseif up and player:GetAttribute(PA.Flashlight) then
		self.torch.extra.Text = player:GetAttribute(PA.TorchClipped) and "clip" or "on"
	else
		self.torch.extra.Text = ""
	end

	for slot, entry in self.slots do
		local id = ids[slot]
		if self.shown[slot] ~= id then
			self.shown[slot] = id
			if entry.icon then
				entry.icon:Destroy()
				entry.icon = nil
			end
			if id ~= "" then
				entry.icon = icon(entry.button, id)
			end
		end
		lightUp(entry, slot == active, alpha)
		-- A small fact in the corner: a lit Lantern.
		entry.extra.Text = (id == "Lantern" and slot == active and player:GetAttribute("LanternOn")) and "lit" or ""
	end
	self.name.Text = (ids[active] and ids[active] ~= "") and nameOf(ids[active]) or ""
	self.name.TextTransparency = 1 - alpha
	self.name.TextStrokeTransparency = 1 - 0.3 * alpha
end

return Hotbar
