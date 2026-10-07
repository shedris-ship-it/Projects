-- Tiny declarative helper for building UI in code, plus the game's palette.
--   Ui.new("Frame", { Size = ..., Parent = ... }, { child1, child2 })

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Theme = {
	ink = Color3.fromRGB(16, 15, 18),
	panel = Color3.fromRGB(24, 22, 26),
	panelLight = Color3.fromRGB(38, 35, 40),
	paper = Color3.fromRGB(226, 216, 190),
	text = Color3.fromRGB(232, 226, 214),
	textDim = Color3.fromRGB(160, 152, 140),
	accent = Color3.fromRGB(196, 150, 92),
	good = Color3.fromRGB(130, 200, 140),
	warn = Color3.fromRGB(230, 190, 90),
	danger = Color3.fromRGB(220, 90, 80),
	ritual = Color3.fromRGB(170, 140, 230),
	font = Enum.Font.GothamMedium,
	fontBold = Enum.Font.GothamBold,
	fontType = Enum.Font.SpecialElite,
}

-- Sounds for buttons, set by UIController once audio exists: { hover, click }.
Ui.Sounds = {}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if instance:IsA("GuiObject") and (props == nil or props.BorderSizePixel == nil) then
		(instance :: any).BorderSizePixel = 0
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?)
	return Ui.new("UIStroke", {
		Color = color or Ui.Theme.accent,
		Thickness = thickness or 1,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number)
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Ui.list(padding: number?, direction: Enum.FillDirection?, align: Enum.HorizontalAlignment?)
	return Ui.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Ui.label(text: string, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Ui.Theme.text,
		Font = Ui.Theme.font,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

function Ui.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- A button with hover and press feedback.
function Ui.button(text: string, props: { [string]: any }?, onClick: (() -> ())?)
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = Ui.Theme.panelLight,
		Text = text,
		TextColor3 = Ui.Theme.text,
		Font = Ui.Theme.fontBold,
		TextSize = 16,
		Size = UDim2.new(0, 160, 0, 40),
	}
	for key, value in props or {} do
		base[key] = value
	end
	local button = Ui.new("TextButton", base, { Ui.corner(8), Ui.stroke(Ui.Theme.accent, 1, 0.6) })
	local rest = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		Ui.tween(button, 0.12, { BackgroundColor3 = rest:Lerp(Ui.Theme.accent, 0.25) })
		if Ui.Sounds.hover then
			Ui.Sounds.hover()
		end
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(button, 0.12, { BackgroundColor3 = rest })
	end)
	button.Activated:Connect(function()
		if Ui.Sounds.click then
			Ui.Sounds.click()
		end
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Ui.screen(name: string, displayOrder: number?, parent: Instance)
	return Ui.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = parent,
	})
end

-- An invisible modal button: while its panel is visible, the mouse is
-- released even in first person, so menus can be clicked.
-- (A plain table: Roblox can drop an Instance's handle from a weak one while
-- the Instance lives on. Destroyed buttons are cleared in Ui.modalOpen.)
local modals = {}
function Ui.modal(parent: Instance)
	local button = Ui.new("TextButton", {
		Name = "ModalUnlock",
		Modal = true,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Parent = parent,
	})
	modals[button] = true
	return button
end

-- Is a menu that frees the mouse showing right now? (Its modal button and
-- every frame above it visible, its screen enabled.) Roblox frees the mouse
-- for one but still reports MouseBehavior as LockCenter, so the cursor rule
-- asks this instead (the owner, 2026-10-07: no cursor on the puzzle screens).
function Ui.modalOpen(): boolean
	for button in modals do
		if button.Parent == nil then
			modals[button] = nil
			continue
		end
		local node: Instance? = button
		local shown = true
		while shown and node do
			if node:IsA("GuiObject") and not node.Visible then
				shown = false
			elseif node:IsA("LayerCollector") then
				shown = node.Enabled
				break
			end
			node = node.Parent
		end
		if shown and node then
			return true
		end
	end
	return false
end

function Ui.color(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

return Ui
