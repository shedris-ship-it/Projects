-- Focus markers: the game has no crosshair. Whatever you're close to and
-- looking at gets a small marker attached to it, with its name and what you
-- can do (docs/ART.md, "Interface"). One marker per object, merging its
-- prompts (doors: Open, Brace) and what your hands can do. Markers fade with distance and
-- with how directly you're looking, so they read as part of the room rather
-- than a HUD. Proximity prompts use this look instead of Roblox's default.
-- Markers are screen frames placed by projecting the object's position each
-- frame (rather than BillboardGuis), so touch input and fades behave like the
-- rest of the UI.
--
-- On a keyboard there is one focus (the owner's solo playtest, 2026-10-08:
-- "streamline the UI a little bit or make a better focus system"): the one
-- thing E is for (Controllers/HandsController:Focus) gets the only marker
-- with words, saying what a tap and a hold of E do; other things you could
-- use close by get a faint ring and nothing else. Gamepad and touch keep a
-- marker per prompt Roblox shows (touch taps their rows).

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local Ui = require(script.Parent.Parent.Lib.Ui)

local F = Config.Focus
local Attr = Constants.Attributes
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local GAMEPAD_GLYPH = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	DPadUp = "↑",
	DPadDown = "↓",
	DPadLeft = "←",
	DPadRight = "→",
}

local FocusMarkers = {}
FocusMarkers.__index = FocusMarkers

local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(last.Name, "^Gamepad") then
		return "gamepad"
	end
	return "keyboard"
end

-- The key to show for an action, or nil on touch (rows are tapped instead).
local function keyText(keyboard: Enum.KeyCode, gamepad: Enum.KeyCode): string?
	local kind = inputKind()
	if kind == "touch" then
		return nil
	elseif kind == "gamepad" then
		return GAMEPAD_GLYPH[gamepad.Name] or (string.gsub(gamepad.Name, "^Button", ""))
	end
	return keyboard.Name
end

-- The object a part belongs to: the nearest ancestor with an object id.
local function objectOf(instance: Instance): Instance
	local node = instance
	while node and node ~= Workspace do
		if node:GetAttribute(Attr.CId) or node:GetAttribute(Attr.SeamId) then
			return node
		end
		node = node.Parent
	end
	return instance
end

-- Where to attach a marker: a part (or attachment) plus a world offset to the
-- object's centre.
local function anchorOf(object: Instance): (Instance?, Vector3)
	if object:IsA("Attachment") then
		return object, Vector3.zero
	elseif object:IsA("BasePart") then
		return object, Vector3.zero
	elseif object:IsA("Model") then
		local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local box = object:GetBoundingBox()
			return part, box.Position - part.Position
		end
	end
	return nil, Vector3.zero
end

function FocusMarkers.new(ctx)
	local self = setmetatable({
		ctx = ctx,
		state = ctx.state,
		screen = Ui.screen("ConsensusFocus", 4, ctx.playerGui),
		markers = {}, -- object -> marker
		shown = {}, -- ProximityPrompt -> true while Roblox would show it
		promptHolds = {}, -- ProximityPrompt -> hold start time
	}, FocusMarkers)

	-- Take over every prompt's look, now and as the house is built.
	local function claim(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			instance.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, d in Workspace:GetDescendants() do
		claim(d)
	end
	Workspace.DescendantAdded:Connect(claim)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		self.shown[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		self.shown[prompt] = nil
		self.promptHolds[prompt] = nil
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		self.promptHolds[prompt] = os.clock()
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		self.promptHolds[prompt] = nil
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		self.promptHolds[prompt] = nil
	end)
	return self
end

-- One action row: an optional keycap and the action word. On touch the row
-- is the button.
function FocusMarkers:_row(parent: Instance, order: number, key: string?, action: string, onPress, onRelease)
	local row = Ui.new("TextButton", {
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		-- Only a button on touch. With a mouse the cursor is locked to the
		-- middle of the screen, and a marker hanging there would swallow the
		-- click meant for your hands (Controllers/HandsController).
		Interactable = inputKind() == "touch",
		Text = "",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Parent = parent,
	}, { Ui.list(5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	if key then
		local cap = Ui.new("Frame", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Ui.Theme.ink,
			BackgroundTransparency = 0.45,
			Parent = row,
		}, {
			Ui.corner(3),
			Ui.stroke(Ui.Theme.accent, 1, 0.35),
			Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		})
		Ui.label(key, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Font = Ui.Theme.fontBold,
			TextSize = 11,
			TextWrapped = false,
			TextColor3 = Ui.Theme.paper,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cap,
		})
	end
	Ui.label(action, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		TextSize = 12,
		TextWrapped = false,
		TextColor3 = Ui.Theme.textDim,
		TextStrokeTransparency = 0.7,
		Parent = row,
	})
	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onPress()
		end
	end)
	row.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onRelease()
		end
	end)
	return row
end

function FocusMarkers:_build(marker)
	if marker.gui then
		marker.gui:Destroy()
	end
	local anchor, offset = anchorOf(marker.object)
	if not anchor then
		return
	end
	marker.anchor = anchor
	marker.offset = offset
	-- The ring sits on the object; the name and actions hang below it.
	local gui = Ui.new("Frame", {
		Name = "FocusMarker",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(240, 90),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local holder = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(3, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center) })
	-- A thin brass ring marks the object itself.
	Ui.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { Ui.corner(6), Ui.stroke(Ui.Theme.accent, 1.5, 0.15) })
	if marker.ring then
		-- Something else you could use, close by: the ring alone.
		marker.fade = {}
		for _, d in gui:GetDescendants() do
			if d:IsA("UIStroke") then
				table.insert(marker.fade, { d, "Transparency", d.Transparency })
			end
		end
		marker.gui = gui
		marker.shownAlpha = -1
		gui.Parent = self.screen
		return
	end
	if marker.name then
		Ui.label(marker.name, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			Font = Ui.Theme.fontType,
			TextSize = 15,
			TextColor3 = Ui.Theme.paper,
			TextStrokeTransparency = 0.6,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
	end
	local actions = Ui.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { Ui.list(12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	for i, row in marker.rows do
		self:_row(actions, i, row.key, row.text, row.press or function() end, row.release or function() end)
	end
	-- Hold progress: a hairline that fills under the actions.
	local track = Ui.new("Frame", {
		LayoutOrder = 4,
		Size = UDim2.fromOffset(90, 1),
		BackgroundColor3 = Ui.Theme.textDim,
		BackgroundTransparency = 0.7,
		Parent = holder,
	})
	marker.fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.Theme.accent,
		Parent = track,
	})
	-- Remember each element's resting transparency so the marker can fade.
	marker.fade = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(marker.fade, { d, "TextTransparency", d.TextTransparency })
			table.insert(marker.fade, { d, "TextStrokeTransparency", d.TextStrokeTransparency })
		elseif d:IsA("UIStroke") then
			table.insert(marker.fade, { d, "Transparency", d.Transparency })
		end
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			table.insert(marker.fade, { d, "BackgroundTransparency", d.BackgroundTransparency })
		end
	end
	marker.gui = gui
	marker.shownAlpha = -1
	gui.Parent = self.screen
end

function FocusMarkers:_setAlpha(marker, alpha: number)
	if math.abs(alpha - marker.shownAlpha) < 0.01 then
		return
	end
	marker.shownAlpha = alpha
	for _, entry in marker.fade do
		entry[1][entry[2]] = 1 - (1 - entry[3]) * alpha
	end
end

-- Pin the marker to its object on screen; hide it behind the camera or far away.
function FocusMarkers:_place(marker, camera: Camera)
	local anchor = marker.anchor
	local position = (anchor:IsA("Attachment") and anchor.WorldPosition or (anchor :: BasePart).Position)
		+ marker.offset
	local point, onScreen = camera:WorldToViewportPoint(position)
	local near = (position - camera.CFrame.Position).Magnitude <= F.MaxDistance
	marker.gui.Visible = onScreen and near and marker.alpha > 0.01
	marker.gui.Position = UDim2.fromOffset(math.round(point.X), math.round(point.Y))
end

-- The prompts whose hold this marker shows filling.
function FocusMarkers:_holdable(marker): { ProximityPrompt }
	local focus = marker.focus
	if not focus then
		return marker.prompts or {}
	end
	local list = {}
	for _, action in { focus.tap, focus.hold } do
		if action and typeof(action.id) == "Instance" then
			table.insert(list, action.id)
		end
	end
	for _, prompt in focus.keyed or {} do
		table.insert(list, prompt)
	end
	return list
end

-- The focus's rows on a keyboard: what a tap of E does, what holding it does,
-- prompts on keys of their own, and a tool lock's tool.
function FocusMarkers:_focusRows(focus, hands)
	local rows = {}
	if focus.tap then
		table.insert(rows, { key = "E", text = focus.tap.text })
	end
	if focus.hold then
		table.insert(rows, { key = "Hold E", text = focus.hold.text })
	end
	for _, prompt in focus.keyed or {} do
		local key = keyText(prompt.KeyboardKeyCode, prompt.GamepadKeyCode)
		if key and prompt.HoldDuration >= 0.5 then
			key = "Hold " .. key
		end
		table.insert(rows, { key = key, text = prompt.ActionText })
	end
	local lock = focus.toolLock
	if lock and hands then
		local _, where = hands:ToolFor(lock)
		if where ~= "none" then
			-- In your hands, or a slot's (holding the click takes it up).
			table.insert(rows, { key = "Hold click", text = lock.action })
		end
	end
	return rows
end

-- A marker's rows on a gamepad or touch: your hands' (not on touch, where the
-- prompt opens and shuts it instead) and each prompt Roblox shows.
function FocusMarkers:_promptRows(entry, kind: string)
	local rows = {}
	if entry.drag and kind ~= "touch" then
		table.insert(rows, { key = "RT", text = "Drag" })
	end
	if entry.grab and kind ~= "touch" then
		table.insert(rows, { key = "RT", text = "Pick up" })
	end
	if entry.push and kind ~= "touch" then
		table.insert(rows, { key = "RT", text = "Push" })
	end
	for _, prompt in entry.prompts do
		-- A long hold says so ("Hold X"): the shrine's wait was a secret before.
		local key = keyText(prompt.KeyboardKeyCode, prompt.GamepadKeyCode)
		if key and prompt.HoldDuration >= 0.5 then
			key = "Hold " .. key
		end
		table.insert(rows, {
			key = key,
			text = prompt.ActionText,
			press = function()
				prompt:InputHoldBegin()
			end,
			release = function()
				prompt:InputHoldEnd()
			end,
		})
	end
	return rows
end

function FocusMarkers:Update(dt: number)
	local state = self.state
	local inRun = state:InRun()
	-- Same rule as the prompts themselves (ActionController): always in the
	-- hub; in a run only while Active and not hiding.
	local active = not inRun or (state:IsActive() and not state:IsTucked())

	-- No cursor in first person; menus that free the mouse (Ui.modal) get it
	-- back: a puzzle, the map, a note, the settings.
	UserInputService.MouseIconEnabled = Ui.modalOpen()
		or not (inRun and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)

	-- What each object should show this frame.
	local wanted = {}
	local function want(object: Instance)
		local entry = wanted[object]
		if not entry then
			entry = { prompts = {}, drag = false, grab = false, push = false, name = nil, target = 0, rows = nil }
			wanted[object] = entry
		end
		return entry
	end
	local camera = Workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local eye = camera.CFrame.Position
	local function gaze(position: Vector3): number
		local offset = position - eye
		if offset.Magnitude < 0.1 then
			return 1
		end
		return math.clamp((look:Dot(offset.Unit) - F.GazeNone) / (F.GazeFull - F.GazeNone), 0, 1)
	end

	local hands = self.ctx.controllers.HandsController
	local kind = inputKind()
	local keyboard = kind == "keyboard"
	if keyboard then
		-- The one focus, with words; faint rings on the rest close by.
		local focus = hands and active and hands:Focus() or nil
		if focus then
			local entry = want(focus.object)
			entry.focus = focus
			entry.name = focus.name
			entry.target = 1
			entry.rows = self:_focusRows(focus, hands)
		end
		for prompt in self.shown do
			local parent = prompt.Parent
			if parent and prompt.Enabled then
				local position = parent:IsA("Attachment") and parent.WorldPosition
					or (parent:IsA("BasePart") and parent.Position)
				local object = objectOf(parent)
				local mine = focus
					and (
						object == focus.object
						or object:IsDescendantOf(focus.object)
						or (parent:IsA("Attachment") and parent.Parent or parent):GetAttribute("HideFor")
							== focus.object:GetAttribute(Attr.CId)
					)
				if position and not mine then
					if (position - eye).Magnitude <= F.RingRange then
						local entry = want(object)
						if not entry.focus then
							entry.ring = true
							entry.target = math.max(entry.target, F.RingAlpha * gaze(position))
						end
					end
				end
			else
				self.shown[prompt] = nil
			end
		end
	else
		for prompt in self.shown do
			if prompt.Parent and prompt.Enabled then
				local object = objectOf(prompt.Parent)
				local entry = want(object)
				table.insert(entry.prompts, prompt)
				entry.drag = entry.drag or (inRun and hands ~= nil and hands:CanDrag(prompt.Parent))
				entry.name = entry.name or (prompt.ObjectText ~= "" and prompt.ObjectText or nil)
				local position = prompt.Parent:IsA("Attachment") and prompt.Parent.WorldPosition
					or (prompt.Parent :: BasePart).Position
				entry.target = math.max(entry.target, math.max(F.PromptMinAlpha, gaze(position)))
			else
				self.shown[prompt] = nil
			end
		end
		-- A small thing your hands could pick up (Controllers/HandsController).
		local thing = (inRun and active and hands) and hands:AimedThing() or nil
		if thing then
			local entry = want(thing)
			entry.grab = true
			entry.name = entry.name or thing:GetAttribute("Label")
			entry.target = 1
		end
		-- Furniture you could push, or are pushing (Controllers/HandsController).
		local pushable = (inRun and active and hands) and hands:AimedPushable() or nil
		if pushable then
			local entry = want(pushable)
			entry.push = true
			entry.name = entry.name or pushable:GetAttribute("PushLabel")
			entry.target = 1
		end
		for _, entry in wanted do
			entry.rows = self:_promptRows(entry, kind)
		end
	end

	-- Build, update and retire markers.
	for object, entry in wanted do
		local marker = self.markers[object]
		local signature = (entry.ring and "ring" or "") .. kind
		for _, row in entry.rows or {} do
			signature ..= "|" .. (row.key or "") .. ":" .. row.text
		end
		-- (Its name can change too: "Batteries (2)" to "(1)".)
		signature ..= "|" .. (entry.name or "")
		if not marker then
			marker = { object = object, alpha = 0 }
			self.markers[object] = marker
		end
		marker.target = active and entry.target or 0
		marker.focus = entry.focus
		if marker.signature ~= signature then
			marker.signature = signature
			marker.prompts = entry.prompts
			marker.rows = entry.rows or {}
			marker.ring = entry.ring and not entry.focus
			marker.name = entry.name
			self:_build(marker)
		end
	end
	local now = os.clock()
	for object, marker in self.markers do
		if not wanted[object] then
			marker.target = 0
		end
		marker.alpha += math.clamp(marker.target - marker.alpha, -dt / F.FadeSeconds, dt / F.FadeSeconds)
		if marker.gui then
			-- Hold progress for whichever action is being held here.
			local progress = 0
			for _, prompt in self:_holdable(marker) do
				local started = self.promptHolds[prompt]
				if started and prompt.HoldDuration > 0 then
					progress = math.max(progress, math.clamp((now - started) / prompt.HoldDuration, 0, 1))
				end
			end
			-- Work at a tool lock (Services/LockService says when each stroke began).
			local since, seconds = player:GetAttribute("WorkSince"), player:GetAttribute("WorkSeconds")
			if marker.focus and marker.focus.toolLock and since and seconds and seconds > 0 then
				progress = math.max(progress, math.clamp((Workspace:GetServerTimeNow() - since) / seconds, 0, 1))
			end
			if marker.fill then
				marker.fill.Size = UDim2.fromScale(progress, 1)
			end
			self:_setAlpha(marker, marker.alpha)
			self:_place(marker, camera)
		end
		if marker.alpha <= 0 and not wanted[object] or not object.Parent then
			if marker.gui then
				marker.gui:Destroy()
			end
			self.markers[object] = nil
		end
	end
end

return FocusMarkers
