-- The map (Tab): the house as the squad knows it (docs/plans/
-- gameplay-rework.md, R2c "the map and the journal").

local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local Map = {}
Map.__index = Map

function Map.new(ctx)
	local self = setmetatable({ ctx = ctx, tab = "Map", open = false }, Map)
	local gui = Ui.screen("ConsensusMap", 40, ctx.playerGui)
	gui.Enabled = false
	self.gui = gui
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.82, 0),
		BackgroundColor3 = Ui.Theme.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, {
		Ui.corner(10),
		Ui.stroke(Ui.Theme.accent, 1, 0.5),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 720) }),
	})
	Ui.modal(panel)
	Ui.label("MAP", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.fromOffset(300, 28),
		Font = Ui.Theme.fontType,
		TextSize = 26,
		TextColor3 = Ui.Theme.accent,
		Parent = panel,
	})
	self.summary = Ui.label("", {
		Position = UDim2.new(0, 20, 0, 42),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.Theme.textDim,
		Parent = panel,
	})
	local tabs = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.fromOffset(360, 32),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) })
	for _, name in { "Map" } do
		Ui.button(name, { Size = UDim2.fromOffset(100, 30), TextSize = 14, Parent = tabs }, function()
			self.tab = name
			self:Render()
		end)
	end
	self.body = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 1, -92),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	ctx.state.LayoutChanged:Connect(function()
		if self.open then
			self:Render()
		end
	end)
	return self
end

function Map:Toggle()
	if not self.ctx.state:InRun() and not self.open then
		return
	end
	self.open = not self.open
	self.gui.Enabled = self.open
	if self.open then
		self:Render()
	end
end

function Map:_clear()
	for _, child in self.body:GetChildren() do
		child:Destroy()
	end
end

function Map:Render()
	self:_clear()
	self.summary.Text = "The rooms you've been in. The way you came is the way you know."
	if self.tab == "Map" then
		self:_renderMap()
	end
end

function Map:_renderMap()
	local layout = self.ctx.state.layout
	if not layout then
		Ui.label("No map yet.", { Parent = self.body })
		return
	end
	-- Rooms are rectangles (x, z, w, d in studs); the mansion's two floors are
	-- drawn side by side, the hall and stairwells on both.
	local floors = layout.mode == "Mansion" and 2 or 1
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in layout.rooms do
		minX, maxX = math.min(minX, room.x), math.max(maxX, room.x + room.w)
		minZ, maxZ = math.min(minZ, room.z), math.max(maxZ, room.z + room.d)
	end
	local gap = 30 -- studs between the floors' plans
	local width = (maxX - minX) * floors + gap * (floors - 1)
	local height = maxZ - minZ
	local scale = math.min(540 / height, 900 / width)
	local canvas = Ui.new("Frame", {
		Size = UDim2.fromOffset(width * scale, height * scale + 46),
		BackgroundTransparency = 1,
		Parent = self.body,
	})
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and self.ctx.state:RoomAt(root.Position)
	for floor = 0, floors - 1 do
		local left = floor * (maxX - minX + gap)
		if floors > 1 then
			Ui.label(floor == 0 and "Ground floor" or "Upper floor", {
				Position = UDim2.fromOffset(left * scale, height * scale + 4),
				Size = UDim2.fromOffset((maxX - minX) * scale, 18),
				TextSize = 13,
				TextColor3 = Ui.Theme.textDim,
				Parent = canvas,
			})
		end
		for _, room in layout.rooms do
			if room.tall or (room.floor or 0) == floor then
				local isHere = here and here.id == room.id
				local tag = room.role == "start" and " (Hall)"
					or room.role == "deliberation" and " (Table)"
					or room.role == "exit" and " (Exit)"
					or room.kind == "stair" and " (Stairs)"
					or ""
				if room.lantern then
					tag ..= " (Lantern)"
				end
				local color = isHere and Ui.Theme.accent
					or (room.lantern and Color3.fromRGB(90, 70, 40) or Ui.Theme.panelLight)
				local x0, z0 = (left + room.x - minX) * scale, (room.z - minZ) * scale
				if room.tall and room.role == "start" and floor == 1 then
					-- Upstairs the hall is only its gallery, round three walls
					-- over the open hall (Logic/TallRooms).
					local g = 8 * scale
					local strips = {
						{ 0, 0, room.w * scale, g },
						{ 0, g, g, room.d * scale - g },
						{ room.w * scale - g, g, g, room.d * scale - g },
					}
					for _, strip in strips do
						Ui.new("Frame", {
							Position = UDim2.fromOffset(x0 + strip[1] + 2, z0 + strip[2] + 2),
							Size = UDim2.fromOffset(math.max(1, strip[3] - 4), math.max(1, strip[4] - 4)),
							BackgroundColor3 = color,
							Parent = canvas,
						}, { Ui.corner(3) })
					end
					Ui.label("Gallery", {
						Position = UDim2.fromOffset(x0 + 2, z0 + 2),
						Size = UDim2.fromOffset(room.w * scale - 4, g - 4),
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = isHere and Ui.Theme.ink or Ui.Theme.text,
						Parent = canvas,
					})
				else
					Ui.new("TextLabel", {
						Position = UDim2.fromOffset(x0 + 2, z0 + 2),
						Size = UDim2.fromOffset(room.w * scale - 4, room.d * scale - 4),
						BackgroundColor3 = color,
						Text = room.name .. tag,
						TextWrapped = true,
						TextScaled = room.w * scale < 70,
						TextSize = 12,
						Font = Ui.Theme.font,
						TextColor3 = isHere and Ui.Theme.ink or Ui.Theme.text,
						Parent = canvas,
					}, { Ui.corner(4), Ui.new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }) })
				end
			end
		end
	end
	Ui.label("Rooms only, for now.", {
		Position = UDim2.fromOffset(0, height * scale + 24),
		Size = UDim2.fromOffset(width * scale, 18),
		TextSize = 12,
		TextColor3 = Ui.Theme.textDim,
		Parent = canvas,
	})
end

return Map
