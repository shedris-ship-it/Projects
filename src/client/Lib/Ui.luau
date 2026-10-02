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
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(button, 0.12, { BackgroundColor3 = rest })
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
function Ui.modal(parent: Instance)
	return Ui.new("TextButton", {
		Name = "ModalUnlock",
		Modal = true,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Parent = parent,
	})
end

function Ui.color(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

return Ui
