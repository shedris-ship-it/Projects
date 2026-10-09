-- The three slots you carry (owner, 2026-10-04; docs/plans/gameplay-rework.md
-- section 4.1): slot 1 is the flashlight, 2 and 3 hold tools found around the
-- house, and one thing is in your hands at a time (an empty slot is a free
-- hand; the bare-hands slot went with the squad playtest of 2026-10-08).
-- Bottom centre. Press 1 to 3, spin the wheel, or tap a slot; X puts the tool
-- in your hands down. Everything shown is read from the player's replicated
-- attributes the server sets (Services/ToolService), so the bar can't disagree
-- with what you're holding.
--
-- Each tool's icon is the real tool model in a small ViewportFrame
-- (World/ToolModel), so what you see on the bar is what you find on the table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local Hotbar = {}
Hotbar.__index = Hotbar

-- A small picture of a tool: its model, seen from the front and a little above.
local function icon(parent: Instance, id: string)
	local model = id == Inventory.TORCH and ToolModel.torch() or ToolModel.tool(id)
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

function Hotbar.new(ctx)
	local self = setmetatable({ ctx = ctx, slots = {}, shown = {} }, Hotbar)
	for slot = 1, Inventory.SLOTS do
		self.shown[slot] = ""
	end
	local gui = Ui.screen("ConsensusHotbar", 6, ctx.playerGui)
	self.gui = gui
	local width = SLOT * Inventory.SLOTS + GAP * (Inventory.SLOTS - 1)
	self.root = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(width, SLOT + 18),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	for slot = 1, Inventory.SLOTS do
		local button = Ui.new("TextButton", {
			Name = "Slot" .. slot,
			Position = UDim2.fromOffset((slot - 1) * (SLOT + GAP), 0),
			Size = UDim2.fromOffset(SLOT, SLOT),
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Ui.Theme.ink,
			BackgroundTransparency = 0.35,
			Parent = self.root,
		}, { Ui.corner(8) })
		local stroke = Ui.stroke(Ui.Theme.accent, 1, 0.75)
		stroke.Parent = button
		Ui.label(tostring(slot), {
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(14, 14),
			Font = Ui.Theme.fontBold,
			TextSize = 12,
			TextColor3 = Ui.Theme.textDim,
			ZIndex = 3,
			Parent = button,
		})
		local extra = Ui.label("", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 3),
			Size = UDim2.fromOffset(34, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Ui.Theme.fontBold,
			TextSize = 12,
			TextColor3 = Ui.Theme.accent,
			ZIndex = 3,
			Parent = button,
		})
		local meter = Ui.new("Frame", {
			Position = UDim2.new(0, 6, 1, -8),
			Size = UDim2.new(1, -12, 0, 3),
			BackgroundColor3 = Ui.Theme.panelLight,
			Visible = false,
			ZIndex = 3,
			Parent = button,
		}, { Ui.corner(2) })
		local meterFill = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 230, 160),
			ZIndex = 3,
			Parent = meter,
		}, { Ui.corner(2) })
		button.Activated:Connect(function()
			Net.get("SelectSlot"):FireServer(slot)
		end)
		self.slots[slot] = {
			button = button,
			stroke = stroke,
			extra = extra,
			meter = meter,
			meterFill = meterFill,
			icon = nil,
		}
	end
	self.name = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, SLOT + 2),
		Size = UDim2.fromOffset(width + 80, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = Ui.Theme.textDim,
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
	if id == Inventory.TORCH then
		return "Flashlight"
	end
	local info = Tools.ById[id]
	return info and info.name or id
end

function Hotbar:Update()
	local state = self.ctx.state
	-- (Hidden anywhere, the breath bar sits here.)
	local visible = state:InRun() and state:PlayerState() == PS.Active and not state:IsHidden()
	self.root.Visible = visible
	if not visible then
		return
	end
	local ids = self:_ids()
	local active = player:GetAttribute(PA.ActiveSlot) or 1
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
		local isActive = slot == active
		entry.button.BackgroundTransparency = isActive and 0.1 or 0.45
		entry.stroke.Transparency = isActive and 0 or 0.8
		entry.stroke.Thickness = isActive and 2 or 1
		if entry.icon and entry.icon:IsA("ViewportFrame") then
			entry.icon.ImageTransparency = isActive and 0 or 0.35
		elseif entry.icon then
			entry.icon.TextTransparency = isActive and 0 or 0.35
		end
		-- Small facts under each icon: a lit Lantern, the torch's charge.
		entry.extra.Text = ""
		entry.meter.Visible = false
		if id == "Lantern" and isActive and player:GetAttribute("LanternOn") then
			entry.extra.Text = "lit"
		elseif id == Inventory.TORCH then
			entry.meter.Visible = true
			entry.meterFill.Size = UDim2.fromScale(player:GetAttribute(PA.Battery) or 1, 1)
			if player:GetAttribute(PA.Flashlight) then
				-- Lit in your hand, or clipped to your shirt while you hold something else.
				entry.extra.Text = player:GetAttribute(PA.TorchClipped) and "clip" or "on"
			end
		end
	end
	self.name.Text = ids[active] ~= "" and nameOf(ids[active]) or "Nothing"
end

return Hotbar
