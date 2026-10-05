-- The dinner, the escape's finale (docs/plans/gameplay-rework.md section 6).
-- The dining table is laid from the start with empty places, one for each
-- heirloom (Services/ItemService). Carry one to an empty place and hold E to
-- set it: its candle lights. When the last is set, the dinner is served:
--
--   1. every light in the house dies, and a chair scrapes at the head of the
--      table: he's sitting there;
--   2. the dining room's doors to the hall slam and lock (the plan's cut),
--      every other lock springs open, the front door swings open with its
--      porch light on, and the final hunt starts (RunOrchestrator:
--      BeginEscape): out, the long way round.
--
-- Also keeps the HUD's objective line (Logic/Objectives) from what the squad
-- has seen: the empty places, the last locked door someone tried, the
-- computer once someone has been near it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Dinner = require(Shared.Logic.Dinner)
local Objectives = require(Shared.Logic.Objectives)
local Props = require(Shared.Data.Props)
local PropFactory = require(Shared.World.PropFactory)
local Sfx = require(Shared.Lib.Sfx)

local RS = Constants.RunState
local part = PropFactory.part
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local FinaleService = {}

function FinaleService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Hands = services.HandsService
	self.Locks = services.LockService
	self.Items = services.ItemService
	self.Puzzles = services.PuzzleService
	self.PlayerState = services.PlayerStateService
	self.Drift = services.DriftService
	self.plan = nil
	self.places = {}
	self.facts = {}
end

function FinaleService:Start()
	self.World.Cleared:Connect(function()
		self.plan = nil
		self.served = false
		table.clear(self.places)
		self.facts = {}
		self.seenStations = {}
		ReplicatedStorage.RunState:SetAttribute(RS.Objective, nil)
	end)
	self.Locks.Tried:Connect(function(seamId, lock)
		local entry = self.Locks.locks[seamId]
		if self.plan and entry and lock.kind ~= "bolt" then
			local inside = lock.inside or entry.seam.b
			self.facts.locked = self.World:Room(inside).name
			self.facts.lockedTwo = lock.kind == "double" or nil
			self.facts.lockedSeam = seamId
			self:_publish()
		end
	end)
	self.Locks.Unlocked:Connect(function(seamId)
		if self.facts.lockedSeam == seamId then
			self.facts.locked, self.facts.lockedSeam, self.facts.lockedTwo = nil, nil, nil
			self:_publish()
		end
	end)
	-- He knows when someone takes one of his things: a chair scrapes at the
	-- table, and an empty place's candle gutters.
	self.Items.HeirloomTaken:Connect(function(_, _token)
		if not self.plan or self.served or not self.head then
			return
		end
		if self.facts.tidied then
			self.facts.tidied = nil
			self:_publish()
		end
		Sfx.play("CreakAlt", self.head + Vector3.new(0, 2, 0), 0.9, 0.45)
		for _, place in self.places do
			if not place.token then
				place.flame.Transparency = 0.2
				task.delay(0.7, function()
					if not place.token and place.flame.Parent then
						place.flame.Transparency = 1
					end
				end)
				break
			end
		end
	end)
	-- He put one back where it was kept.
	self.Items.Tidied:Connect(function()
		if self.plan and not self.served then
			self.facts.tidied = true
			self:_publish()
		end
	end)
	self.Puzzles.Solved:Connect(function(id)
		self:_stationSolved(id)
	end)
	self.Items.CaseOpened:Connect(function(_, case)
		self:_stationSolved(case.id)
	end)
	-- Someone near a puzzle or a locked case has seen it.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 or not self.plan then
			return
		end
		elapsed = 0
		self:_lookForStations()
	end)
end

-- The puzzles and locked cases in the house, for the objective line:
-- { id, kind, position, room, solved }.
function FinaleService:_stations()
	local list = {}
	for _, session in self.Puzzles.sessions do
		-- A padlock is on a door the line already mentions; puzzles stand in rooms.
		if session.room and session.station and session.station.Parent then
			table.insert(list, {
				id = session.id,
				kind = session.kind,
				position = session.station.Position,
				room = session.room,
				solved = session.state.solved == true,
			})
		end
	end
	-- A crank door's shutter, until it's latched open.
	for _, crank in self.services.CrankService.cranks do
		if crank.crankAt then
			table.insert(list, {
				id = "crank:" .. crank.id,
				kind = "crank",
				position = crank.crankAt,
				room = crank.outer,
				solved = crank.latched,
			})
		end
	end
	-- A case with something of his in it (one with a porcelain figure isn't
	-- worth a line: you can see what's in it).
	for _, case in self.Items.cases do
		if case.model.Parent and case.token then
			table.insert(list, {
				id = case.id,
				kind = "display",
				position = case.model:GetPivot().Position,
				room = case.room,
				solved = case.open,
			})
		end
	end
	return list
end

function FinaleService:_lookForStations()
	self.facts.stations = self.facts.stations or {}
	self.seenStations = self.seenStations or {}
	local positions = {}
	for _, player in self.PlayerState:ActivePlayers() do
		table.insert(positions, self.PlayerState:Position(player))
	end
	for _, station in self:_stations() do
		if not self.seenStations[station.id] and not station.solved then
			for _, position in positions do
				if (position - station.position).Magnitude < 14 then
					local entry = { kind = station.kind, room = self.World:Room(station.room).name, solved = false }
					self.seenStations[station.id] = entry
					table.insert(self.facts.stations, entry)
					self:_publish()
					break
				end
			end
		end
	end
end

function FinaleService:_stationSolved(id: string)
	local entry = self.seenStations and self.seenStations[id]
	if entry and not entry.solved then
		entry.solved = true
		self:_publish()
	elseif self.seenStations and not entry then
		-- Dealt with before anyone was near it (F2 `solve`): never mentioned.
		self.seenStations[id] = { solved = true }
	end
end

function FinaleService:_publish()
	ReplicatedStorage.RunState:SetAttribute(RS.Objective, Objectives.line(self.facts))
end

-- How far the squad got, for the end-of-run Dossier.
function FinaleService:Progress()
	local plan = self.plan
	if not plan then
		return nil
	end
	local set = 0
	for _, place in self.places do
		if place.token then
			set += 1
		end
	end
	local locks, opened = 0, 0
	for _, entry in self.Locks.locks do
		if entry.lock.kind ~= "bolt" and entry.lock.kind ~= "seal" then
			locks += 1
			if entry.open then
				opened += 1
			end
		end
	end
	local puzzles, solved = 0, 0
	for _ in plan.puzzles do
		puzzles += 1
	end
	for _, session in self.Puzzles.sessions do
		if plan.puzzles[session.id] and session.state.solved then
			solved += 1
		end
	end
	return {
		places = #self.places,
		placesSet = set,
		locks = locks,
		locksOpened = opened,
		puzzles = puzzles,
		puzzlesSolved = solved,
		lines = {},
	}
end

-- The table ----------------------------------------------------------------------------

-- The dining table's frame and size, or a spot in the middle of the dining room.
function FinaleService:_table(world)
	for _, prop in world.props do
		if prop.model == world.deliberationTable and prop.frame then
			local kind = Props.Kinds[prop.kind]
			return prop.frame, Vector3.new(kind.size[1], kind.size[2], kind.size[3])
		end
	end
	local room = self.World:Room(world.layout.deliberation)
	local floor = self.World:FloorBase(room.center.Y)
	return CFrame.new(room.center.X, floor, room.center.Z), Vector3.new(6, 3.4, 12)
end

-- One empty place: a plate, a card, an unlit candle, and the prompt to set it.
function FinaleService:_place(index: number, at: CFrame, folder: Instance)
	local white = Color3.fromRGB(232, 228, 216)
	local china = PropFactory.material("SmoothPlastic")
	local model = Instance.new("Model")
	model.Name = "Place" .. index
	local plate =
		part(model, "Plate", Vector3.new(0.06, 1.3, 1.3), at * CFrame.new(0, 0.03, 0) * UPRIGHT, white, china, {
			collide = false,
			shape = CYL,
		})
	local card = part(
		model,
		"Card",
		Vector3.new(0.6, 0.35, 0.03),
		at * CFrame.new(0, 0.2, -0.95) * CFrame.Angles(math.rad(-12), 0, 0),
		Color3.fromRGB(236, 230, 214),
		PropFactory.material("Fabric"),
		{ collide = false, castShadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(120, 70)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 40, 30)
	label.Text = "..."
	label.Parent = gui
	gui.Parent = card
	part(model, "Candle", Vector3.new(0.6, 0.16, 0.16), at * CFrame.new(0.8, 0.3, -0.7) * UPRIGHT, white, china, {
		collide = false,
		shape = CYL,
	})
	local flame = part(
		model,
		"Flame",
		Vector3.new(0.12, 0.2, 0.12),
		at * CFrame.new(0.8, 0.7, -0.7),
		Color3.fromRGB(255, 190, 110),
		PropFactory.material("Neon"),
		{ collide = false, castShadow = false, transparency = 1 }
	)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 90)
	glow.Range = 9
	glow.Brightness = 1.2
	glow.Enabled = false
	glow.Parent = flame
	model.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlacePrompt"
	prompt.ActionText = "Set the table"
	prompt.ObjectText = "Empty place"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	local place = { index = index, at = at, model = model, label = label, flame = flame, glow = glow, prompt = prompt }
	prompt.Triggered:Connect(function(player)
		self:_set(place, player)
	end)
	return place
end

function FinaleService:Begin(plan)
	self.plan = plan
	self.served = false
	table.clear(self.places)
	local world = self.World.World
	local frame, size = self:_table(world)
	self.tableFrame, self.tableSize = frame, size
	local folder = Instance.new("Folder")
	folder.Name = "Dinner"
	folder.Parent = self.World.content
	-- Places along both long sides, facing in; the head of the table is his,
	-- out of reach of anyone setting a place (Logic/Dinner).
	local count = #plan.finale.heirlooms
	local long = size.Z >= size.X
	local length = long and size.Z or size.X
	local across = long and size.X or size.Z
	local layout = Dinner.layout(count, length, across, Config.Guest.ContactRadius, Config.Scent.TableMargin)
	-- Lay it out from whichever end has room for him to stand (or sit).
	local flip = self:_seatBlocked(frame, long, layout.head) and not self:_seatBlocked(frame, long, -layout.head)
	local sign = flip and -1 or 1
	for i, place in layout.places do
		local along = place.along * sign
		local offset = long and Vector3.new(place.side, size.Y, along) or Vector3.new(along, size.Y, place.side)
		local position = frame:PointToWorldSpace(offset)
		local inward = frame:PointToWorldSpace(long and Vector3.new(0, size.Y, along) or Vector3.new(along, size.Y, 0))
		-- The card stands at the far side of the plate, facing whoever sits here.
		local at = CFrame.lookAt(position, Vector3.new(inward.X, position.Y, inward.Z)) * CFrame.Angles(0, math.pi, 0)
		table.insert(self.places, self:_place(i, at, folder))
	end
	local head = layout.head * sign
	self.head = frame:PointToWorldSpace(long and Vector3.new(0, 0, head) or Vector3.new(head, 0, 0))
	self:_frontExit(world)
	self.facts = { places = count, placesLeft = count, stations = {} }
	self.seenStations = {}
	self:_publish()
end

-- Is there no room for him at the head of the table at `along` (a wall, a
-- cabinet, out of the dining room)?
function FinaleService:_seatBlocked(frame: CFrame, long: boolean, along: number): boolean
	local point = frame:PointToWorldSpace(long and Vector3.new(0, 0, along) or Vector3.new(along, 0, 0))
	if self.World:RoomAt(point + Vector3.new(0, 2, 0)) ~= self.World.World.layout.deliberation then
		return true
	end
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local hits = Workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, 3, 0)), Vector3.new(2, 4.5, 2), params)
	for _, hit in hits do
		local model = hit:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return true
		end
	end
	return false
end

-- The way out is the front door the squad came in by (the mansion); the old
-- house keeps its exit.
function FinaleService:_frontExit(world)
	local door = world.frontDoor
	if not door then
		return
	end
	local hall = self.World:Room(world.layout.start).center
	local thin = door.Size.Z < door.Size.X and door.CFrame.LookVector or door.CFrame.RightVector
	local outward = thin * ((door.Position - hall):Dot(thin) >= 0 and 1 or -1)
	outward = Vector3.new(outward.X, 0, outward.Z).Unit
	local floor = door.Position.Y - door.Size.Y / 2
	local porchAt = door.Position + outward * 6
	part(
		self.World.content,
		"FrontPorch",
		Vector3.new(12, 1, 12),
		CFrame.new(porchAt.X, floor - 0.5, porchAt.Z),
		Color3.fromRGB(70, 66, 60),
		PropFactory.material("Concrete")
	)
	local zone = part(
		self.World.content,
		"ExitZone",
		Vector3.new(8, 8, 8),
		CFrame.new(door.Position + outward * 3.5),
		Color3.fromRGB(180, 220, 255),
		PropFactory.material("Neon"),
		{ collide = false, transparency = 1, query = false, castShadow = false }
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Range = 22
	light.Brightness = 2
	light.Enabled = false
	light.Parent = zone
	world.exit = {
		door = door,
		zone = zone,
		light = light,
		position = zone.Position,
		roomId = world.layout.start,
		outward = outward,
	}
end

local function notifyAll(text: string, kind: string?)
	Net.get("Notify"):FireAllClients(text, kind or "info")
end

-- Someone holding an heirloom sets it at a place.
function FinaleService:_set(place, player: Player)
	if self.served or place.token or not self.PlayerState:CanAct(player) then
		return
	end
	local thing = self.Hands:Held(player)
	local token = thing and thing.model:GetAttribute("Item")
	local info = token and self.plan and self.plan.tokens[token]
	if not info or info.kind ~= "heirloom" then
		Net.get("Notify"):FireClient(player, "Something belongs here. Something of the family's.")
		return
	end
	self.Hands:Forget(thing, false)
	local model = thing.model
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	model:PivotTo(place.at * CFrame.new(0, 0.1, 0))
	self.Items:MarkSet(token)
	self.services.RunLogService:Set(token, player)
	place.token = token
	place.label.Text = self.Items:Label(token)
	place.flame.Transparency = 0
	place.glow.Enabled = true
	place.prompt.Enabled = false
	Sfx.play("Match", place.at.Position, 0.5, 1)
	self.Drift:Apply("ItemFound")
	local left = 0
	for _, p in self.places do
		if not p.token then
			left += 1
		end
	end
	self.facts.placesLeft = left
	self:_publish()
	if left == 0 then
		self:Serve()
	else
		notifyAll(left == 1 and "One place is still empty." or (left .. " places are still empty."))
	end
end

-- The dinner -------------------------------------------------------------------------

-- Swing the front door open outward, about its edge.
function FinaleService:_openFront(exit)
	local door = exit.door
	local parts = { door }
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local starts = {}
	for i, p in parts do
		starts[i] = p.CFrame
		p.CanCollide = false
	end
	local width = math.max(door.Size.X, door.Size.Z)
	local along = door.Size.X >= door.Size.Z and door.CFrame.RightVector or door.CFrame.LookVector
	local hinge = door.Position - along * width / 2
	local turnSign = along:Cross(exit.outward).Y >= 0 and 1 or -1
	task.spawn(function()
		local t = 0
		while t < 1 do
			t = math.min(1, t + RunService.Heartbeat:Wait() / 1.1)
			local eased = 1 - (1 - t) ^ 3
			local turn = CFrame.new(hinge) * CFrame.Angles(0, -turnSign * math.rad(100) * eased, 0) * CFrame.new(-hinge)
			local cframes = table.create(#parts)
			for i, start in starts do
				cframes[i] = turn * start
			end
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
	Sfx.play("DoorOpen", door.Position, 1, 0.75)
end

-- Serve the dinner now (the last heirloom set, or F2 `resolve`).
function FinaleService:Serve()
	if not self.plan or self.served then
		return
	end
	self.served = true
	for _, place in self.places do
		place.prompt.Enabled = false
	end
	local world = self.World.World
	-- The lights die.
	for _, id in self.World:RoomIds() do
		self.World:SetLightCause(id, "dinner", true)
	end
	Sfx.play("Sting", self.tableFrame.Position, 0.6, 0.6)
	notifyAll("Every light in the house goes out.", "danger")
	task.delay(1.4, function()
		if not self.plan then
			return
		end
		-- A chair scrapes at the head of the table.
		Sfx.play("CreakAlt", self.head, 0.9, 0.45)
		self.services.StalkerService:PlaceAt(self.head, self.tableFrame.Position)
		notifyAll("A chair scrapes back. Someone has taken a seat at the table.", "danger")
	end)
	task.delay(3.4, function()
		if not self.plan then
			return
		end
		-- The way back to the hall seals; everything else springs open (the
		-- crank doors roll up and latch).
		self.services.CrankService:LatchAll()
		local cut = {}
		for _, seamId in self.plan.finale.cut do
			cut[seamId] = true
			self.Locks:LockSeam(seamId)
		end
		local ids = {}
		for seamId, entry in self.Locks.locks do
			if not entry.open and not cut[seamId] then
				table.insert(ids, seamId)
			end
		end
		table.sort(ids)
		for i, seamId in ids do
			task.delay(i * 0.15, function()
				self.Locks:Unlock(seamId, nil, nil)
			end)
		end
		local exit = world.exit
		if exit then
			if exit.outward then
				self:_openFront(exit)
			else
				exit.door.CanCollide = false
				exit.door.Transparency = 0.85
			end
			exit.light.Enabled = true
			-- The way out is lit, whatever kept it dark.
			self.World:ClearLightCauses(exit.roomId)
		end
		self.facts.served = true
		self:_publish()
		notifyAll(world.frontDoor and "The front door is open. Run." or "The way out is open. Run.", "good")
		self.services.RunOrchestrator:BeginEscape()
	end)
end

return FinaleService
