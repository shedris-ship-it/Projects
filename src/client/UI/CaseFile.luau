-- The Case File (Tab): the Case Board (12 suspects, narrowed by confirmed
-- tells), the evidence log, and a map of the house. The map shows rooms
-- only, never doorways, so it can't settle an argument about a phantom door.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anomalies = require(Shared.Data.Anomalies)
local Tells = require(Shared.Data.Tells)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local CaseFile = {}
CaseFile.__index = CaseFile

function CaseFile.new(ctx)
	local self = setmetatable({ ctx = ctx, tab = "Board", open = false }, CaseFile)
	local gui = Ui.screen("ConsensusCaseFile", 40, ctx.playerGui)
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
	Ui.label("CASE FILE", {
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
	for _, name in { "Board", "Evidence", "Map" } do
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
	ctx.state.CaseBoardChanged:Connect(function()
		if self.open then
			self:Render()
		end
	end)
	ctx.state.LayoutChanged:Connect(function()
		if self.open then
			self:Render()
		end
	end)
	return self
end

function CaseFile:Toggle()
	if not self.ctx.state:InRun() and not self.open then
		return
	end
	self.open = not self.open
	self.gui.Enabled = self.open
	if self.open then
		self:Render()
	end
end

function CaseFile:_clear()
	for _, child in self.body:GetChildren() do
		child:Destroy()
	end
end

function CaseFile:Render()
	self:_clear()
	local board = self.ctx.state.caseBoard or { entries = {}, confirmed = {}, claimed = {}, suspects = {} }
	local suspects = {}
	for _, id in board.suspects or {} do
		suspects[id] = true
	end
	local confirmed = {}
	for _, id in board.confirmed or {} do
		confirmed[id] = true
	end
	local claimed = {}
	for _, id in board.claimed or {} do
		claimed[id] = true
	end
	local remaining = #(board.suspects or {})
	self.summary.Text = string.format(
		"%d confirmed tell%s · %d suspect%s remain · claims are unconfirmed until two Witnesses agree",
		#(board.confirmed or {}),
		#(board.confirmed or {}) == 1 and "" or "s",
		remaining,
		remaining == 1 and "" or "s"
	)

	if self.tab == "Board" then
		local grid = Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -10, 0, 196),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = self.body,
		})
		grid.Name = "Grid"
		for index, anomaly in Anomalies.List do
			local alive = suspects[anomaly.id] == true
			local card = Ui.new("Frame", {
				LayoutOrder = index,
				BackgroundColor3 = alive and Ui.Theme.paper or Ui.Theme.panelLight,
				BackgroundTransparency = alive and 0 or 0.3,
				Parent = self.body,
			}, { Ui.corner(6), Ui.padding(8) })
			local ink = alive and Ui.Theme.ink or Ui.Theme.textDim
			Ui.label(anomaly.name, {
				Size = UDim2.new(1, 0, 0, 20),
				Font = Ui.Theme.fontType,
				TextSize = 17,
				TextColor3 = ink,
				Parent = card,
			})
			Ui.label(anomaly.channel .. (alive and "" or "  ·  eliminated"), {
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 0, 14),
				TextSize = 11,
				TextColor3 = alive and Color3.fromRGB(110, 80, 50) or Ui.Theme.textDim,
				Parent = card,
			})
			local y = 38
			for _, tellId in anomaly.tells do
				local tell = Tells[tellId]
				local mark, color = "·", ink
				if confirmed[tellId] then
					mark, color = "✔", Color3.fromRGB(40, 130, 60)
				elseif claimed[tellId] then
					mark, color = "?", Color3.fromRGB(160, 110, 30)
				end
				Ui.label(mark .. " " .. tell.name, {
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, 16),
					TextSize = 12,
					TextColor3 = color,
					Parent = card,
				})
				y += 17
			end
		end
	elseif self.tab == "Evidence" then
		Ui.list(6).Parent = self.body
		if #(board.entries or {}) == 0 then
			Ui.label(
				"Nothing pinned yet. When something looks wrong, hold Q on it. If a teammate Witnesses it too within 4 seconds, it's confirmed (or debunked).",
				{ Size = UDim2.new(1, 0, 0, 40), TextColor3 = Ui.Theme.textDim, Parent = self.body }
			)
		end
		for i, entry in board.entries or {} do
			local color = entry.status == "confirmed" and Ui.Theme.good
				or entry.status == "debunked" and Ui.Theme.textDim
				or Ui.Theme.warn
			local status = entry.status == "confirmed" and "CONFIRMED"
				or entry.status == "debunked" and "DEBUNKED"
				or "CLAIMED"
			local row = Ui.new("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = Ui.Theme.panelLight,
				Parent = self.body,
			}, { Ui.corner(6), Ui.padding(8) })
			Ui.label(string.format("%s  ·  %s  ·  %s", status, entry.name, entry.room or "?"), {
				Size = UDim2.new(1, 0, 0, 18),
				Font = Ui.Theme.fontBold,
				TextSize = 14,
				TextColor3 = color,
				Parent = row,
			})
			Ui.label(entry.notice .. "  — " .. table.concat(entry.by or {}, ", "), {
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 12,
				TextColor3 = Ui.Theme.textDim,
				Parent = row,
			})
		end
	elseif self.tab == "Map" then
		self:_renderMap()
	end
end

function CaseFile:_renderMap()
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
				local tag = room.role == "start" and " (Case Board)"
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
	Ui.label("Rooms only: doorways aren't drawn, because the house won't agree on them.", {
		Position = UDim2.fromOffset(0, height * scale + 24),
		Size = UDim2.fromOffset(width * scale, 18),
		TextSize = 12,
		TextColor3 = Ui.Theme.textDim,
		Parent = canvas,
	})
end

return CaseFile
