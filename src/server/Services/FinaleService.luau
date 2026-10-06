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
-- has seen: the empty places, the keys someone holds and where their doors
-- are (by their marks), the locked doors someone has tried, the computer
-- once someone has been near it. A door is always named by the room it's
-- seen from, never the one behind it (docs/plans/level-design.md section 11).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Dinner = require(Shared.Logic.Dinner)
local Marks = require(Shared.Data.Marks)
local Assist = require(Shared.Logic.Assist)
local Objectives = require(Shared.Logic.Objectives)
local ToolLocks = require(Shared.Logic.ToolLocks)
local Props = require(Shared.Data.Props)
local RoomRects = require(Shared.Logic.RoomRects)
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
	self.tried = {} -- seam ids of locked doors someone has tried, oldest first
	self.spans = {} -- room id -> { floor, top }: the storeys it spans
	self.line = nil
end

function FinaleService:Start()
	self.World.Cleared:Connect(function()
		self.plan = nil
		self.served = false
		table.clear(self.places)
		self.facts = {}
		self.seenStations = {}
		self.knownPieces = {}
		table.clear(self.tried)
		table.clear(self.spans)
		self.line = nil
		ReplicatedStorage.RunState:SetAttribute(RS.Objective, nil)
	end)
	self.Locks.Tried:Connect(function(seamId, lock)
		local entry = self.Locks.locks[seamId]
		if self.plan and entry and lock.needs then
			-- The newest tried goes last.
			local at = table.find(self.tried, seamId)
			if at then
				table.remove(self.tried, at)
			end
			table.insert(self.tried, seamId)
			self:_publish()
		end
	end)
	self.Locks.Unlocked:Connect(function()
		if self.plan then
			self:_publish()
		end
	end)
	self.Locks.RingChanged:Connect(function()
		if self.plan then
			self:_publish()
		end
	end)
	-- A step's chest (L3.4): tried without its tool, or opened.
	self.Locks.PieceTried:Connect(function(id)
		self.knownPieces = self.knownPieces or {}
		if self.plan and not self.knownPieces[id] then
			self.knownPieces[id] = true
			self:_publish()
		end
	end)
	self.Locks.PieceOpened:Connect(function()
		if self.plan then
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
		self:_assist()
		-- (A tool picked up or put down changes the line too.)
		self:_publish()
	end)
end

-- Stuck-assist (Logic/Assist, Config.Assist): no progress for HintAfter
-- seconds and the line says what the plan wants next; after LampAfter the
-- lights there stutter every LampEvery seconds and the map rings the room
-- (Services/MapService reads `hintRoom`).
function FinaleService:_assist()
	local services = self.services
	local since = services.DriftService:SinceProgress()
	if self.served or since < Config.Assist.HintAfter then
		if self.facts.hint then
			self.facts.hint = nil
			self.hintRoom = nil
			self.hint = nil
		end
		return
	end
	local hint = Assist.next(self.plan, self:_assistState())
	if not hint then
		self.facts.hint, self.hintRoom, self.hint = nil, nil, nil
		return
	end
	local roomName = hint.room and self.Items:RoomPhrase(hint.room) or nil
	local label = hint.token and string.lower(self.Items:Label(hint.token)) or nil
	local text = Assist.phrase(hint, roomName, label)
	if text ~= self.facts.hint then
		self.facts.hint = text
		self.hint = hint
		services.Telemetry:Log("Assist", { kind = hint.kind, room = hint.room, since = math.floor(since) })
		services.RunLogService:Hint()
	end
	local lamp = since >= Config.Assist.LampAfter
	self.hintRoom = lamp and hint.room or nil
	if lamp and hint.room and os.clock() >= (self.nextLamp or 0) then
		self.nextLamp = os.clock() + Config.Assist.LampEvery
		for _, player in self.PlayerState:RunPlayers() do
			services.DivergenceService:Scare(player, { kind = "flicker", roomId = hint.room, duration = 2.5 })
		end
	end
end

-- What the squad has, as Logic/Assist reads it.
function FinaleService:_assistState()
	local services = self.services
	local locks = self.Locks
	local had, opened, set, seams = {}, {}, {}, {}
	for token in self.Items.found do
		had[token] = true
	end
	for _, held in locks:HeldKeys() do
		had[held.token] = true
	end
	for seamId, entry in locks.locks do
		if entry.open then
			opened[seamId] = true
		end
		if entry.seam then
			seams[seamId] = { a = entry.seam.a, b = entry.seam.b }
		end
	end
	local tools = services.ToolService
	for id, token in self.plan.tokens do
		if token.kind == "tool" and tools:Holder(token.tool) then
			had[id] = true
		elseif token.producer.kind == "puzzle" then
			local session = self.Puzzles.sessions[token.producer.id]
			if session and session.state and session.state.solved then
				had[id] = true
			end
		end
	end
	for _, place in self.places do
		if place.token then
			set[place.token] = true
			had[place.token] = true
		end
	end
	return { reachable = locks.reach, had = had, opened = opened, set = set, seams = seams }
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
				optional = session.optional,
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
		local position = self.PlayerState:Position(player)
		if position then
			table.insert(positions, { at = position, room = self.World:RoomAt(position) })
		end
	end
	self:_lookForPieces(positions)
	for _, station in self:_stations() do
		if not self.seenStations[station.id] and not station.solved then
			for _, seen in positions do
				-- Near it and in its room: never through a floor or a wall into
				-- a wing nobody can get to (a playtest's line named a safe in
				-- the locked attic above).
				if seen.room == station.room and (seen.at - station.position).Magnitude < 14 then
					local entry = {
						kind = station.kind,
						room = self.World:Room(station.room).name,
						solved = false,
						optional = station.optional,
					}
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

-- Doors and keys --------------------------------------------------------------------

local STOREY_WORDS = { [-1] = "in the cellar", [0] = "on the ground floor", [1] = "upstairs", [2] = "in the attic" }

-- The room a door is seen from: a gate's outer side (the planner keeps the
-- room behind it as `inside`).
function FinaleService:_nearRoom(seamId: string): number?
	local world = self.World.World
	local seam = world and world.seams[seamId]
	if not seam then
		return nil
	end
	local entry = self.Locks.locks[seamId]
	local inside = entry and entry.lock.inside
	if inside then
		return inside == seam.a and seam.b or seam.a
	end
	return seam.a
end

-- Where a door is, in words, from the side the squad knows: "the Study";
-- in a stairwell, which storey ("the Back Stairs, on the ground floor").
function FinaleService:_placeOf(seamId: string): string?
	local near = self:_nearRoom(seamId)
	if not near then
		return nil
	end
	local phrase = self.Items:RoomPhrase(near)
	local span = self.spans[near]
	local seam = self.World.World.seams[seamId]
	if span and span.top > span.floor and seam then
		phrase ..= ", " .. (STOREY_WORDS[seam.floor or 0] or "")
	end
	return phrase
end

-- A room as the line says it ("the Nursery"), for a step's chest.
function FinaleService:RoomPlace(room: number): string
	return self.Items:RoomPhrase(room)
end

-- Someone has been by a step's chest (in its room, near it) or tried it.
function FinaleService:PieceKnown(id: string): boolean
	return self.knownPieces ~= nil and self.knownPieces[id] == true
end

function FinaleService:_lookForPieces(positions)
	self.knownPieces = self.knownPieces or {}
	for id, entry in self.Locks.pieceLocks do
		if not entry.open and not self.knownPieces[id] and entry.anchor.Parent then
			for _, seen in positions do
				if seen.room == entry.lock.room and (seen.at - entry.anchor.Position).Magnitude < 14 then
					self.knownPieces[id] = true
					self:_publish()
					break
				end
			end
		end
	end
end

-- Where a door is, once someone has tried it or seen it up close
-- (MapService); nil till then.
function FinaleService:DoorPlace(seamId: string): string?
	local map = self.services.MapService
	local door = map and map.doors[seamId]
	if not (door and door.known) and not table.find(self.tried, seamId) then
		return nil
	end
	return self:_placeOf(seamId)
end

-- Someone has seen a locked door up close (MapService): the journal can say
-- where a key's door is, and so can the line.
function FinaleService:DoorKnown(_seamId: string)
	if self.plan then
		self.Locks:RefreshRings()
		self:_publish()
	end
end

-- The keys anyone holds and the locked doors tried, as Logic/Objectives
-- wants them.
function FinaleService:_lockFacts()
	local doors = {}
	for _, seamId in self.tried do
		local entry = self.Locks.locks[seamId]
		if entry and not entry.open then
			local mark = entry.lock.mark and Marks.ById[entry.lock.mark]
			local kind = entry.lock.vault and "vault" or entry.lock.kind
			table.insert(doors, { mark = mark and mark.name, kind = kind, place = self:_placeOf(seamId) })
		end
	end
	local keys = {}
	for _, held in self.Locks:HeldKeys() do
		local info = self.plan.tokens[held.token]
		local mark = info and info.mark and Marks.ById[info.mark]
		if mark and info.kind == "key" then
			local lock = info.opens and self.plan.locks[info.opens]
			table.insert(keys, {
				mark = mark.name,
				-- (The house key's next door still shut: docs/plans/level-design.md 11.)
				place = self.Locks:KeyPlace(held.token),
				two = lock and lock.kind == "double" or nil,
			})
		end
	end
	-- The crowbar and the bolt cutters, while someone carries them (L3.3).
	local tools = {}
	local toolService = self.services.ToolService
	local ids = {}
	for id, token in self.plan.tokens do
		if token.kind == "tool" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		local token = self.plan.tokens[id]
		if toolService and toolService:Holder(token.tool) then
			local place, thing = self.Locks:KeyPlace(id)
			table.insert(
				tools,
				{ name = token.label, kind = ToolLocks.kindOf(token.tool), place = place, thing = thing }
			)
		end
	end
	return doors, keys, tools
end

function FinaleService:_publish()
	if self.plan then
		self.facts.doors, self.facts.keys, self.facts.tools = self:_lockFacts()
	end
	local line = Objectives.line(self.facts)
	if line ~= self.line then
		self.line = line
		ReplicatedStorage.RunState:SetAttribute(RS.Objective, line)
	end
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
	table.clear(self.spans)
	for _, room in world.layout.rooms or {} do
		self.spans[room.id] = { floor = room.floor or 0, top = RoomRects.topOf(room) }
	end
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
	self.services.RunLogService:Served()
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
