-- The map: the house as the squad knows it (docs/plans/gameplay-rework.md,
-- R2c "the map and the journal"). Everyone's map shows the same thing, made
-- only of what someone has seen: rooms someone has been in, doorways someone
-- has looked at (and what kind of lock, once it's been tried or seen up
-- close), where a note was read, keys and heirlooms seen lying about, the
-- puzzles and cases someone has been near, the table, and a friend who's
-- down. Nothing unseen is ever sent (the layout snapshot, with every room,
-- is only for the client's own bookkeeping, and the map never draws a room
-- nobody has found).
--
-- Sent as MapState to everyone, at most twice a second and only when it
-- changes; a reloading client gets it again (SyncPlayer). Later systems add
-- their own marks (Mark: the breaker, a crank door, a barricade).
--
-- The map that saves time (docs/plans/level-design.md section 11, L3.5): a
-- room someone has been in gets a tick once nothing the run needs is left in
-- it (everything kept there taken, its puzzles done, its chests open: earned
-- by going in, as in Resident Evil); what's been seen and not yet done (a
-- locked door, a safe, a case, a chained chest) gets a ring on the client;
-- the house plans, once read, draw their floor's rooms; and who carries
-- which key or tool is everyone's to see.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Marks = require(Shared.Data.Marks)
local Net = require(Shared.Net)

local M = Config.Map

local MapService = {}

function MapService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.Locks = services.LockService
	self.Items = services.ItemService
	self.Witness = services.WitnessService
	self.PlayerState = services.PlayerStateService
	self.Finale = services.FinaleService
	self:_reset()
end

function MapService:_reset()
	self.rooms = {} -- room id -> true: someone has been in it
	self.doors = {} -- seam id -> { known = lock kind seen, open = bool }
	self.notes = {} -- note id -> true: someone read it here
	self.marks = {} -- key -> { kind, position, label?, done? } (other systems' facts)
	self.planStoreys = {} -- storey -> true once someone read the house plans for it
	self.sent = nil
	self.lastSent = 0
end

function MapService:Start()
	self.World.Cleared:Connect(function()
		self:_reset()
		Net.get("MapState"):FireAllClients(nil)
	end)
	self.Locks.Tried:Connect(function(seamId)
		self:_seeDoor(seamId, true)
	end)
	self.Locks.Unlocked:Connect(function(seamId)
		local door = self.doors[seamId]
		if door then
			door.open = true
		end
	end)
	-- A lantern lit: its room redraws as lit.
	self.services.ToolService.ShrineLit:Connect(function()
		self:_publish(true)
	end)
	self.Items.NoteRead:Connect(function(_, note)
		if not self.notes[note.id] then
			self.notes[note.id] = true
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < M.ScanSeconds or not self.World.World then
			return
		end
		elapsed = 0
		self:_scan()
		self:_publish()
	end)
end

-- Facts ---------------------------------------------------------------------------------

-- A doorway looked at (or tried, `tried`): it goes on the map, and what kind
-- of lock it has once it's been tried or seen up close.
function MapService:_seeDoor(seamId: string, tried: boolean?, close: boolean?)
	local door = self.doors[seamId]
	if not door then
		door = {}
		self.doors[seamId] = door
	end
	if (tried or close) and not door.known then
		door.known = true
		-- A locked door's place, for the journal's keys and the objective line.
		if self.Locks.locks[seamId] then
			self.Finale:DoorKnown(seamId)
		end
	end
end

-- Another system's fact, shown as a mark (a kind the client knows how to
-- draw): `key` is unique to the thing, `info` { kind, position, label?, done?,
-- room? (only once someone has been in that room: a landmark) }.
function MapService:Mark(key: string, info)
	self.marks[key] = info
end

function MapService:Unmark(key: string)
	if self.marks[key] then
		self.marks[key] = nil
	end
end

-- The house plans for `storey` were read (Services/ItemService): its rooms
-- go on everyone's map. Returns whether that's new.
function MapService:RevealStorey(storey: number): boolean
	if self.planStoreys[storey] then
		return false
	end
	self.planStoreys[storey] = true
	self:_publish(true)
	return true
end

-- Rooms someone has been in with nothing the run needs left in them: what
-- was kept there taken (a tool too), its puzzles and cases done, its chests
-- open. Junk in drawers, notes and decoys don't count.
function MapService:_doneRooms(): { number }
	local plan = self.Locks.plan
	local left = {} -- room -> true while something there is still to do
	if plan then
		local tools = self.services.ToolService
		for id, token in plan.tokens do
			if token.producer.kind == "container" then
				local taken = if token.kind == "tool" then tools.found[token.tool] else self.Items.found[id]
				-- (An heirloom he put back is there to take again.)
				local heirloom = self.Items.heirlooms[id]
				if heirloom and heirloom.tidied then
					taken = false
				end
				if not taken then
					left[token.producer.room] = true
				end
			end
		end
		for _, station in self.Finale:_stations() do
			if not station.solved then
				left[station.room] = true
			end
		end
		for _, entry in self.Locks.pieceLocks do
			if not entry.open then
				left[entry.lock.room] = true
			end
		end
	end
	local done = {}
	for id in self.rooms do
		if not left[id] then
			table.insert(done, id)
		end
	end
	table.sort(done)
	return done
end

-- Who carries which key and which tool for a lock, by name (sorted).
function MapService:_carried()
	local by = {} -- name -> { labels }
	for _, held in self.Locks:HeldKeys() do
		local name = held.holder.DisplayName
		by[name] = by[name] or {}
		table.insert(by[name], held.label)
	end
	local plan = self.Locks.plan
	local tools = self.services.ToolService
	for _, token in plan and plan.tokens or {} do
		local holder = token.kind == "tool" and tools:Holder(token.tool)
		if holder then
			by[holder.DisplayName] = by[holder.DisplayName] or {}
			table.insert(by[holder.DisplayName], token.label)
		end
	end
	local out = {}
	for name, labels in by do
		table.sort(labels)
		table.insert(out, { name = name, what = labels })
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Who has been where, and what each player is looking at.
function MapService:_scan()
	local world = self.World.World
	for _, player in self.PlayerState:ActivePlayers() do
		local position = self.PlayerState:Position(player)
		local room = position and self.World:RoomAt(position)
		if room and not self.rooms[room] then
			self.rooms[room] = true
		end
		local view, age = self.Witness:GetView(player)
		if view and age < 1 then
			local eye = view.Position
			for id, seam in world.seams do
				-- (A hidden door isn't a door to anyone until it's found.)
				if seam.connected and not (seam.hidden and not seam.found) then
					local distance = (seam.position - eye).Magnitude
					local door = self.doors[id]
					local wanted = not door or (not door.known and distance <= M.LockSeenRange)
					if wanted and distance <= M.SeenRange and self:_inView(view, seam.position) then
						if self.Witness:ClearLine(eye, seam.position) then
							self:_seeDoor(id, false, distance <= M.LockSeenRange)
						end
					end
				end
			end
		end
	end
end

function MapService:_inView(view: CFrame, point: Vector3): boolean
	local delta = point - view.Position
	return delta.Magnitude < 1e-3 or view.LookVector:Dot(delta.Unit) >= math.cos(math.rad(M.ViewCone / 2))
end

-- Is an item lying in plain sight seen by anyone (in view, clear line)?
function MapService:_seenLying(position: Vector3, ignore: Instance?): boolean
	for _, player in self.PlayerState:ActivePlayers() do
		local view, age = self.Witness:GetView(player)
		if view and age < 1 and (position - view.Position).Magnitude <= M.SeenRange then
			if self:_inView(view, position) and self.Witness:ClearLine(view.Position, position, { ignore }) then
				return true
			end
		end
	end
	return false
end

-- Sending -------------------------------------------------------------------------------

local function flat(position: Vector3)
	return { math.round(position.X * 10) / 10, math.round(position.Z * 10) / 10 }
end

function MapService:_floorOf(position: Vector3): number
	return self.World.FloorAt(position.Y - Config.Level.Origin.y)
end

function MapService:State()
	local world = self.World.World
	if not world then
		return nil
	end
	local state = { rooms = {}, doors = {}, notes = {}, items = {}, marks = {}, downed = {} }
	for id in self.rooms do
		table.insert(state.rooms, id)
	end
	table.sort(state.rooms)
	state.done = self:_doneRooms()
	-- Lantern shrines in rooms somebody has entered: lit or not (WP3).
	state.lanterns = {}
	for id in self.rooms do
		local shrine = world.shrines and world.shrines[id]
		if shrine then
			table.insert(state.lanterns, { room = id, lit = shrine.lit == true })
		end
	end
	-- Stuck-assist (Services/FinaleService): the room the line points at.
	state.hint = self.Finale.hintRoom
	state.plans = {}
	for storey in self.planStoreys do
		table.insert(state.plans, storey)
	end
	table.sort(state.plans)
	state.carried = self:_carried()
	for id, door in self.doors do
		local seam = world.seams[id]
		local entry = self.Locks.locks[id]
		local kind = "door"
		local label = nil
		local crank = self.services.CrankService:Get(id)
		if crank and not crank.latched and crank.blocked then
			kind = "crank"
		elseif entry and not entry.open and not door.open then
			if door.known then
				-- (A side room's door is a key door to look at.)
				kind = entry.lock.kind == "pocket" and "key" or entry.lock.kind
				-- Its mark, never the room behind it (nobody has seen that).
				local mark = entry.lock.mark and Marks.ById[entry.lock.mark]
				if mark then
					label = mark.glyph .. " " .. mark.name
				elseif entry.lock.vault then
					label = "SAFE ROOM"
				end
			else
				kind = "unknown" -- a door nobody has tried: it might be locked
			end
		end
		local at = flat(seam.position)
		table.insert(state.doors, {
			id = id,
			x = at[1],
			z = at[2],
			floor = seam.floor or 0,
			a = seam.a,
			b = seam.b,
			kind = kind,
			label = label,
			side = kind == "bolt" and entry.lock.side or nil,
		})
	end
	table.sort(state.doors, function(p, q)
		return p.id < q.id
	end)
	for id in self.notes do
		local note = self.Items.notes[id]
		if note and note.sheet.Parent then
			local at = flat(note.sheet.Position)
			table.insert(state.notes, { x = at[1], z = at[2], floor = self:_floorOf(note.sheet.Position) })
		end
	end
	-- Keys and heirlooms lying where someone can see them (not in a drawer,
	-- a box or anyone's hands).
	for _, thing in self.services.HandsService.things do
		local token = thing.model:GetAttribute("Item")
		if token and thing.state == "rest" and not thing.inside and thing.model.Parent then
			local position = thing.model:GetPivot().Position
			if thing.mapSeen or self:_seenLying(position, thing.model) then
				thing.mapSeen = true
				local at = flat(position)
				local info = self.Locks.plan and self.Locks.plan.tokens[token]
				table.insert(state.items, {
					x = at[1],
					z = at[2],
					floor = self:_floorOf(position),
					kind = info and info.kind or "item",
					label = self.Items:Label(token),
				})
			end
		end
	end
	for key, mark in self.marks do
		if mark.room and not self.rooms[mark.room] then
			continue
		end
		local at = flat(mark.position)
		table.insert(state.marks, {
			key = key,
			kind = mark.kind,
			x = at[1],
			z = at[2],
			floor = self:_floorOf(mark.position),
			label = mark.label,
			done = mark.done,
		})
	end
	table.sort(state.marks, function(p, q)
		return p.key < q.key
	end)
	-- The puzzles and cases someone has been near (FinaleService).
	for _, station in self.Finale:_stations() do
		local seen = self.Finale.seenStations and self.Finale.seenStations[station.id]
		if seen and seen.kind then
			local at = flat(station.position)
			table.insert(state.marks, {
				key = station.id,
				kind = station.kind,
				x = at[1],
				z = at[2],
				floor = self:_floorOf(station.position),
				done = station.solved,
			})
		end
	end
	-- A step's chest someone has been by (section 11, L3.4).
	for id, entry in self.Locks.pieceLocks do
		if self.Finale:PieceKnown(id) and entry.anchor then
			local at = flat(entry.anchor.Position)
			local word = entry.lock.kind == "boards" and "NAILED " or "CHAINED "
			table.insert(state.marks, {
				key = id,
				kind = "piece",
				x = at[1],
				z = at[2],
				floor = self:_floorOf(entry.anchor.Position),
				label = word .. string.upper(entry.lock.thing),
				done = entry.open,
			})
		end
	end
	local finale = self.Finale
	if finale.tableFrame then
		local at = flat(finale.tableFrame.Position)
		local places = finale.facts.places or 0
		state.table = {
			x = at[1],
			z = at[2],
			floor = self:_floorOf(finale.tableFrame.Position),
			set = places - (finale.facts.placesLeft or places),
			places = places,
		}
	end
	for _, player in Players:GetPlayers() do
		if self.PlayerState:State(player) == Constants.PlayerStates.Downed then
			local position = self.PlayerState:Position(player)
			if position then
				local at = flat(position)
				table.insert(
					state.downed,
					{ x = at[1], z = at[2], floor = self:_floorOf(position), name = player.DisplayName }
				)
			end
		end
	end
	return state
end

-- At most twice a second, and only when something changed (the whole state
-- is compared: it's small).
function MapService:_publish(force: boolean?)
	local now = os.clock()
	if not force and now - self.lastSent < 1 / M.SendHz then
		return
	end
	local state = self:State()
	if not state then
		return
	end
	local key = HttpService:JSONEncode(state)
	if not force and key == self.sent then
		return
	end
	self.sent = key
	self.lastSent = now
	Net.get("MapState"):FireAllClients(state)
end

-- A (re)loading client.
function MapService:SyncPlayer(player: Player)
	local state = self:State()
	if state then
		Net.get("MapState"):FireClient(player, state)
	end
end

return MapService
