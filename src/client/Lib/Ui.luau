-- Tiny declarative helper for building UI in code, plus the game's palette.
--   Ui.new("Frame", { Size = ..., Parent = ... }, { child1, child2 })
--
-- The look (V7, the diegetic 1988 interface; docs/ART.md): everything on
-- screen is a thing from 1988. Typed sheets and forms (Special Elite),
-- handwriting in pencil and ballpoint (Kalam), titles in an old book face
-- (Accanthis), the computer's green type (Inconsolata), on paper drawn by
-- tools/paper.py (Ui.paper). Over the world the few words left are pale lines
-- like a film's subtitles. Brass is kept for what matters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage:WaitForChild("Shared").Assets)

local Ui = {}

Ui.Theme = {
	-- Over the world (the HUD, subtitles, overlays) and dark screens.
	ink = Color3.fromRGB(16, 15, 18),
	panel = Color3.fromRGB(24, 22, 26),
	panelLight = Color3.fromRGB(38, 35, 40),
	text = Color3.fromRGB(232, 226, 214),
	textDim = Color3.fromRGB(168, 160, 146),
	-- On paper.
	paper = Color3.fromRGB(234, 226, 206),
	type = Color3.fromRGB(40, 36, 36), -- a typewriter's ribbon, a little faded
	typeDim = Color3.fromRGB(110, 100, 90),
	pencil = Color3.fromRGB(66, 64, 64), -- graphite
	pen = Color3.fromRGB(34, 46, 98), -- blue ballpoint
	red = Color3.fromRGB(152, 40, 32), -- a red pencil, a rubber stamp
	goodInk = Color3.fromRGB(46, 92, 50), -- a green felt tip
	-- Brass: kept for what matters (a marker's ring, a button's line).
	accent = Color3.fromRGB(196, 150, 92),
	good = Color3.fromRGB(150, 204, 150),
	warn = Color3.fromRGB(230, 196, 110),
	danger = Color3.fromRGB(226, 96, 84),
	-- The purple "ritual" colour retired with the 1988 interface: it's a
	-- pale parchment now, for the few old screens that still ask for it.
	ritual = Color3.fromRGB(220, 206, 172),
	-- Typed, for the screens that ask for an Enum.Font.
	font = Enum.Font.SpecialElite,
	fontBold = Enum.Font.SpecialElite,
	fontType = Enum.Font.SpecialElite,
}

-- The faces (Font objects, for FontFace).
Ui.Fonts = {
	type = Font.fromEnum(Enum.Font.SpecialElite),
	hand = Font.fromEnum(Enum.Font.Kalam),
	handBold = Font.new("rbxasset://fonts/families/Kalam.json", Enum.FontWeight.Bold),
	title = Font.new("rbxasset://fonts/families/AccanthisADFStd.json"),
	titleBold = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold),
	subtitle = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	body = Font.fromEnum(Enum.Font.Merriweather),
	crt = Font.new("rbxasset://fonts/families/Inconsolata.json"),
	crtBold = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Bold),
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

-- A label (typed, pale, for over the world or a dark screen). Pass FontFace
-- for another face.
function Ui.label(text: string, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Ui.Theme.text,
		FontFace = Ui.Fonts.type,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for key, value in props or {} do
		if key == "Font" then
			-- (Set after FontFace, an Enum.Font would undo it: asked for by
			-- name, it's the same typed face, so the FontFace stands.)
			if value ~= Ui.Theme.fontType and value ~= Ui.Theme.font then
				base.FontFace = Font.fromEnum(value)
			end
			continue
		end
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

local function hoverSounds(button: GuiButton)
	button.MouseEnter:Connect(function()
		if Ui.Sounds.hover then
			Ui.Sounds.hover()
		end
	end)
	button.Activated:Connect(function()
		if Ui.Sounds.click then
			Ui.Sounds.click()
		end
	end)
end

-- A typed word you can press, over the world or a dark screen: pale on a
-- faint dark ground, with a brass hairline under it that draws out when the
-- mouse is on it. `Plain = true`: a solid part of a thing instead (a piano's
-- key, a breaker): no line, a brass edge while the mouse is on it.
function Ui.button(text: string, props: { [string]: any }?, onClick: (() -> ())?)
	local plain = props ~= nil and props.Plain == true
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = Ui.Theme.ink,
		BackgroundTransparency = plain and 0 or 0.45,
		Text = text,
		TextColor3 = Ui.Theme.text,
		FontFace = Ui.Fonts.type,
		TextSize = 17,
		Size = UDim2.new(0, 160, 0, 40),
	}
	for key, value in props or {} do
		if key ~= "Font" and key ~= "Plain" then
			base[key] = value
		end
	end
	local button = Ui.new("TextButton", base, { Ui.corner(2) })
	if plain then
		local edge = Ui.stroke(Ui.Theme.accent, 2, 1)
		edge.Parent = button
		button.MouseEnter:Connect(function()
			Ui.tween(edge, 0.12, { Transparency = 0.1 })
		end)
		button.MouseLeave:Connect(function()
			Ui.tween(edge, 0.12, { Transparency = 1 })
		end)
		button.SelectionGained:Connect(function()
			edge.Transparency = 0.1
		end)
		button.SelectionLost:Connect(function()
			edge.Transparency = 1
		end)
		hoverSounds(button)
		if onClick then
			button.Activated:Connect(onClick)
		end
		return button
	end
	local line = Ui.new("Frame", {
		Name = "Underline",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(0.25, 0, 0, 1),
		BackgroundColor3 = Ui.Theme.accent,
		BackgroundTransparency = 0.45,
		Parent = button,
	})
	local rest = button.BackgroundTransparency
	button.MouseEnter:Connect(function()
		Ui.tween(line, 0.15, { Size = UDim2.new(0.8, 0, 0, 1), BackgroundTransparency = 0 })
		Ui.tween(button, 0.15, { BackgroundTransparency = math.max(0, rest - 0.2) })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(line, 0.15, { Size = UDim2.new(0.25, 0, 0, 1), BackgroundTransparency = 0.45 })
		Ui.tween(button, 0.15, { BackgroundTransparency = rest })
	end)
	hoverSounds(button)
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

-- A screen put away by a key or a click (a note by E, a puzzle by E): that
-- same press must not reach your hands too and open it again, whichever of
-- them hears it first (Controllers/HandsController asks).
local dismissedAt = -math.huge
function Ui.dismissed()
	dismissedAt = os.clock()
end

function Ui.justDismissed(): boolean
	return os.clock() - dismissedAt < 0.3
end

function Ui.color(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Shrinks a screen laid out at width x height to fit a smaller window or
-- a phone (never grows it).
function Ui.fit(frame: GuiObject, width: number, height: number): UIScale
	local scale = Ui.new("UIScale", { Parent = frame }) :: UIScale
	local watched: Camera? = nil
	local function update()
		local camera = Workspace.CurrentCamera
		if camera and camera ~= watched then
			watched = camera
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min((view.X - 24) / width, (view.Y - 24) / height), 0.4, 1)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	update()
	return scale
end

-- Paper -------------------------------------------------------------------------

-- A piece of paper (Assets.Paper: "Sheet", "Slip", "Folder", "Graph",
-- "Notebook"), lying on the screen with a soft shadow under it. Returns the
-- holder (size, place and turn it with props) and the sheet (put the content
-- in it). `shadow` false leaves the shadow out.
--
-- Stretched whole, not nine-sliced: sliced, Roblox drew the middle without
-- the edges' yellowing and a hard seam showed at the border (2026-10-14).
-- The screens are laid out near each paper's own proportions.
function Ui.paper(kind: string, props: { [string]: any }?, shadow: boolean?)
	local spec = Assets.Paper[kind]
	local parent = props and props.Parent
	local holder = Ui.new("Frame", { Name = kind, BackgroundTransparency = 1 })
	for key, value in props or {} do
		if key ~= "Parent" then
			(holder :: any)[key] = value
		end
	end
	if shadow ~= false then
		local s = Assets.Paper.Shadow
		Ui.new("ImageLabel", {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = s.image,
			ImageTransparency = 0.2,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(s.slice, s.slice, s.size[1] - s.slice, s.size[2] - s.slice),
			-- Lit from the upper left: the shadow falls down and right.
			Position = UDim2.fromOffset(-30, -26),
			Size = UDim2.new(1, 66, 1, 66),
			ZIndex = 1,
			Parent = holder,
		})
	end
	local sheet = Ui.new("ImageLabel", {
		Name = "Sheet",
		BackgroundTransparency = 1,
		Image = spec.image,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	})
	if spec.tile then
		sheet.ScaleType = Enum.ScaleType.Tile
		sheet.TileSize = UDim2.fromOffset(spec.tile, spec.tile)
	end
	if parent then
		holder.Parent = parent
	end
	return holder, sheet
end

-- A strip of old tape holding a paper down, across a corner or an edge.
function Ui.tape(parent: Instance, position: UDim2, rotation: number?, width: number?)
	local w = width or 110
	return Ui.new("ImageLabel", {
		Name = "Tape",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Assets.Paper.Tape.image,
		Position = position,
		Size = UDim2.fromOffset(w, math.floor(w * 0.3)),
		Rotation = rotation or 0,
		ZIndex = 9,
		Parent = parent,
	})
end

local function textOn(face: Font, color: Color3, size: number, text: string, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		FontFace = face,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 6),
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

-- Typed on paper.
function Ui.typed(text: string, props: { [string]: any }?)
	return textOn(Ui.Fonts.type, Ui.Theme.type, 17, text, props)
end

-- Written in pencil. (Kalam draws small for its size: about two thirds
-- of the typed face's at the same TextSize, so handwriting is set larger.)
function Ui.hand(text: string, props: { [string]: any }?)
	return textOn(Ui.Fonts.hand, Ui.Theme.pencil, 26, text, props)
end

-- A heading in the old book face.
function Ui.title(text: string, props: { [string]: any }?)
	return textOn(Ui.Fonts.title, Ui.Theme.type, 34, text, props)
end

-- A word stamped in red ink, a little crooked.
function Ui.stamp(text: string, props: { [string]: any }?)
	local base = {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Rotation = -5,
		TextTransparency = 0.15,
		ZIndex = 8,
	}
	for key, value in props or {} do
		base[key] = value
	end
	local label = textOn(Ui.Fonts.type, Ui.Theme.red, 30, text, base)
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label })
	Ui.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Ui.Theme.red,
		Thickness = 3,
		Transparency = 0.25,
		Parent = label,
	})
	Ui.corner(4).Parent = label
	return label
end

-- A typed word you can press, on paper: it gets a red-pencil underline
-- when the mouse is on it (or a pad's selection).
function Ui.paperButton(text: string, props: { [string]: any }?, onClick: (() -> ())?)
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = Ui.Theme.type,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Ui.Theme.type,
		FontFace = Ui.Fonts.type,
		TextSize = 18,
		Size = UDim2.fromOffset(160, 32),
	}
	for key, value in props or {} do
		base[key] = value
	end
	local button = Ui.new("TextButton", base)
	local line = Ui.new("Frame", {
		Name = "Underline",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundColor3 = Ui.Theme.red,
		BackgroundTransparency = 0.1,
		Parent = button,
	})
	if button.TextXAlignment == Enum.TextXAlignment.Left then
		line.AnchorPoint = Vector2.new(0, 1)
		line.Position = UDim2.new(0, 0, 1, -3)
	end
	local function show(on: boolean)
		local width = math.min(button.TextBounds.X + 6, button.AbsoluteSize.X)
		Ui.tween(line, 0.12, { Size = UDim2.new(0, on and width or 0, 0, 2) })
		Ui.tween(button, 0.12, { BackgroundTransparency = on and 0.93 or 1 })
	end
	button.MouseEnter:Connect(function()
		show(true)
	end)
	button.MouseLeave:Connect(function()
		show(false)
	end)
	button.SelectionGained:Connect(function()
		show(true)
	end)
	button.SelectionLost:Connect(function()
		show(false)
	end)
	hoverSounds(button)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A ruled line across a sheet (typed forms, a notepad).
function Ui.rule(parent: Instance, y: number, color: Color3?, transparency: number?)
	return Ui.new("Frame", {
		Name = "Rule",
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = color or Ui.Theme.typeDim,
		BackgroundTransparency = transparency or 0.55,
		Parent = parent,
	})
end

-- A line of film subtitle: pale, with a soft dark edge, for words over
-- the world (captions, toasts, the downed state).
function Ui.subtitle(text: string, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(238, 232, 218),
		FontFace = Ui.Fonts.subtitle,
		TextSize = 22,
		TextWrapped = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.55,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

return Ui
