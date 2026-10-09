-- Drawers, cupboard doors and lids (docs/plans/gameplay-rework.md section
-- 4.5). World/PropFactory builds each as a named piece whose main part
-- carries its joint (Lib/Joint); this moves them on the server the way
-- DoorService moves doors (Logic/Articulation, BulkMoveTo): by hand (Services/
-- HandsService checks reach and passes the drag on), by the E prompt, and on
-- their own when someone hides in a wardrobe (it pulls shut) or is dragged
-- out of one (it flies open).
--
-- What's kept inside stays on the server: the first time a drawer or door is
-- opened past half way, whatever belongs in that space is made there (an odd
-- small thing from World/Junk, or nothing; R2a's keys and items take over
-- through `Filler`). Something lying in a drawer rides it in and out until
-- someone takes it.
--
-- Each piece learns how far it can open at build: a cupboard in a corner
-- stops before its door would go through the wall.
--
-- Like doors they have momentum (R2c): a flicked drawer slides out to its
-- stop with a knock, a cupboard door flung shut slams. Clients draw them from
-- the motion snapshots on their main parts (Lib/MotionState), and what lies
-- in a drawer is marked RidesOn so it slides with it on every screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Props = require(Shared.Data.Props)
local Joint = require(Shared.Lib.Joint)
local MotionState = require(Shared.Lib.MotionState)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Rng = require(Shared.Lib.Rng)
local Sfx = require(Shared.Lib.Sfx)

local Junk = require(script.Parent.Parent.World.Junk)

local F = Config.Furniture
local H = Config.Hands
local Attr = Constants.Attributes

local FurnitureService = {}

function FurnitureService:Init(services)
	self.World = services.WorldService
	self.Hands = services.HandsService
	self.Hiding = services.HidingService
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
	self.pieces = {} -- id -> piece
	self.spaces = {} -- every space a piece opens onto
	self.moving = {} -- piece -> true while it moves
	self.count = 0
	-- Optional (Services/ItemService): function(space, at: CFrame) -> (Model?,
	-- thing?), what belongs in a space instead of junk (already a thing your
	-- hands can take, or not yet); false to leave it empty.
	self.Filler = nil
end

function FurnitureService:Start()
	self.World.Built:Connect(function(world)
		self:_setup(world)
	end)
	self.World.Cleared:Connect(function()
		table.clear(self.pieces)
		table.clear(self.spaces)
		table.clear(self.moving)
		self.count = 0
	end)
	RunService.Heartbeat:Connect(function(dt)
		for piece in self.moving do
			self:_step(piece, dt)
		end
	end)
	-- Hidden by E in furniture with doors, they pull to behind you; leave
	-- (or be found) and they open. A walk-in place's doors are yours to
	-- work (Services/HidingService's physical spots).
	self.Hiding.Entered:Connect(function(_, spot)
		if not spot.physical then
			self:_setAll(spot.model, false, false)
		end
	end)
	self.Hiding.Left:Connect(function(_, spot, forced)
		if not spot.physical then
			self:_setAll(spot.model, true, forced == true)
		end
	end)
end

-- Setup -------------------------------------------------------------------------

local function isCharacter(part: BasePart): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- How far a piece can open before its main part would run into something
-- solid that isn't its own furniture (a wall, the bed beside it).
function FurnitureService:_clearance(joint, primary: BasePart, own: Instance): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { own }
	params.RespectCanCollide = true
	local step = joint.kind == "slide" and 0.1 or F.ClearStep
	-- A hair smaller, so touching isn't hitting (and never below nothing: a
	-- glass lid is thinner than the margin).
	local size = (primary.Size - Vector3.new(0.1, 0.1, 0.1)):Max(Vector3.new(0.02, 0.02, 0.02))
	local value = step
	while value <= joint.max + 1e-6 do
		for _, hit in Workspace:GetPartBoundsInBox(Joint.pose(joint, value), size, params) do
			if not isCharacter(hit) then
				return math.max(0, value - step)
			end
		end
		value += step
	end
	return joint.max
end

function FurnitureService:_setup(world)
	for _, prop in world.props or {} do
		self:AddProp(prop)
	end
	world.pieces = self.pieces
end

-- Furniture whose pieces open: the house's, and things made after it was
-- built (a keepsake box, a display case: Services/ItemService). `prop` is
-- { id, model, roomId, kind }. Returns the spaces its pieces open onto.
function FurnitureService:AddProp(prop): { any }
	local model = prop.model
	local made = {}
	if not model.Parent then
		return made
	end
	local spaces = {}
	for _, child in model:GetChildren() do
		local primary = child:IsA("Model") and child.PrimaryPart
		local joint = primary and Joint.read(primary)
		if not joint then
			continue
		end
		self.count += 1
		local piece = self:_piece("piece:" .. self.count, child, primary, joint, prop)
		local group = primary:GetAttribute("Group") or child.Name
		local space = spaces[group]
		if not space then
			space = {
				id = prop.id .. ":" .. group,
				group = group,
				prop = prop,
				spot = primary:GetAttribute("Spot"),
				pieces = {},
				filled = false,
				contents = {},
			}
			spaces[group] = space
			table.insert(self.spaces, space)
			table.insert(made, space)
		end
		table.insert(space.pieces, piece)
		piece.space = space
		if joint.kind == "slide" then
			-- A drawer carries what's in it.
			space.rides = piece
			piece.spotOffset = typeof(space.spot) == "CFrame" and joint.shut:ToObjectSpace(space.spot) or nil
		end
		-- Too cramped to see into (a drawer against the bed): nothing's kept there.
		local roomy = joint.kind == "slide" and piece.state.max >= 0.9 or piece.state.max >= 45
		if not roomy then
			space.filled = true
		end
	end
	for _, child in model:GetChildren() do
		local space = child.Name == "Lamp" and spaces[child:GetAttribute("Group")]
		if space then
			space.lamp = child:FindFirstChildOfClass("PointLight")
		end
	end
	return made
end

function FurnitureService:_piece(id: string, model: Model, primary: BasePart, joint, prop)
	local parts, offsets = {}, {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			table.insert(offsets, primary.CFrame:ToObjectSpace(p.CFrame))
		end
	end
	local max = self:_clearance(joint, primary, prop.model)
	local spec = Joint.motionSpec(joint, "furniture", 0)
	spec.max = max
	local piece = {
		id = id,
		model = model,
		primary = primary,
		joint = joint,
		prop = prop,
		parts = parts,
		offsets = offsets,
		state = Articulation.new(spec),
		holder = nil,
		heldUntil = 0,
		upright = Joint.upright(joint),
		solid = primary.CanCollide,
		label = primary:GetAttribute("Label") or "Drawer",
	}
	primary:SetAttribute(Attr.CId, id)
	primary:SetAttribute("Max", max)
	primary:SetAttribute("Value", 0)
	primary:SetAttribute("Momentum", "furniture")
	CollectionService:AddTag(primary, Constants.Tags.Articulated)
	self.pieces[id] = piece

	-- The tap version (touch, or anyone who'd rather): E opens and shuts it.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = piece.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = true
	prompt.HoldDuration = 0
	prompt.Enabled = max > 0
	prompt.Parent = primary
	prompt.Triggered:Connect(function(player)
		if self.PlayerState:CanAct(player) then
			self:Toggle(piece, player)
		end
	end)
	piece.prompt = prompt
	-- On a keyboard, E is your hands' (the squad playtest, 2026-10-08: "make
	-- everything grabbable with E"): a tap opens or shuts it (HandsService
	-- :Tap), a hold drags it. Not on furniture E hides you in; a wardrobe or
	-- a locker you walk into has doors like any other.
	local kind = prop.kind and Props.Kinds[prop.kind]
	if not (kind and kind.hide and not kind.physical) then
		prompt:SetAttribute("HandsOwned", true)
		CollectionService:AddTag(prompt, Constants.Tags.HandsPrompt)
	else
		primary:SetAttribute("HideSpot", true)
	end
	return piece
end

-- Moving ------------------------------------------------------------------------

function FurnitureService:_place(piece)
	local at = Joint.pose(piece.joint, piece.state.value)
	local cframes = table.create(#piece.parts)
	for i, offset in piece.offsets do
		cframes[i] = at * offset
	end
	Workspace:BulkMoveTo(piece.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	-- Whatever lies in a drawer goes in and out with it, until it's taken.
	local space = piece.space
	if space.rides == piece then
		for _, thing in space.contents do
			if thing.rides == piece and thing.state == "rest" and thing.model.Parent then
				thing.model:PivotTo(at * thing.rideOffset)
			end
		end
	end
end

function FurnitureService:_step(piece, dt: number)
	if not piece.primary.Parent then
		self.moving[piece] = nil
		return
	end
	local state = piece.state
	local joint = piece.joint
	local now = os.clock()
	local holder = (piece.holder and now < piece.heldUntil) and piece.holder or nil
	-- The hand let go (no word from it for a moment): it moves on by itself.
	if state.mode == "held" and not holder then
		Articulation.release(state)
	end
	local from = state.value
	local events = Articulation.step(state, dt, piece.fast)
	self:_place(piece)
	local position = piece.primary.Position
	local slide = joint.kind == "slide"
	local flung = (piece.lastHolder and now - (piece.lastHeldAt or 0) < 2) and piece.lastHolder or nil
	for _, event in events do
		if event == "slam" then
			Sfx.play(slide and "Drawer" or "DoorClose", position, 0.7, slide and 0.8 or 1)
			self.Noise:Emit(position, F.SlamNoise, flung, flung and "furniture" or "lure")
		elseif event == "knock" then
			Sfx.play("Knock", position, 0.35, slide and 1.4 or 1.1)
		elseif event == "latch" then
			Sfx.play(slide and "Drawer" or "DoorLatch", position, 0.3, slide and 1.25 or 1.35)
		elseif event == "unlatch" and not slide then
			Sfx.play("DoorLatch", position, 0.18, 1.5)
		end
	end
	-- Yanked open or slammed shut: heard. Eased, it isn't.
	local speed = math.abs(state.value - from) / math.max(dt, 1e-3)
	if holder and speed > joint.rate * F.NoiseSpeed and now - (piece.noisedAt or 0) > 0.6 then
		piece.noisedAt = now
		self.Noise:Emit(position, F.NoiseRadius, holder, "furniture")
		Sfx.play(slide and "Drawer" or "Creak", position, 0.45, slide and 0.9 or 1.2)
	end
	-- A door is only solid near shut: a shut one can't be walked through, and
	-- an opening one never shoves anyone.
	if piece.upright then
		local solid = state.value < F.SolidBelow
		if solid ~= piece.solid then
			piece.solid = solid
			piece.primary.CanCollide = solid
		end
	end
	local space = piece.space
	if space.lamp then
		local lit = false
		for _, other in space.pieces do
			lit = lit or other.state.value > 4
		end
		space.lamp.Enabled = lit
	end
	if not space.filled and state.value >= state.max * F.FillAt then
		self:_fill(space)
	end
	if not Articulation.moving(state) then
		self.moving[piece] = nil
		piece.fast = nil
		MotionState.settle(piece.primary, math.round(state.value * 100) / 100)
		self:_label(piece)
	else
		MotionState.publish(piece.primary, state, H.MotionHz, piece.fast)
	end
end

-- The first look inside: make what's kept there, where it lies.
function FurnitureService:_fill(space)
	space.filled = true
	if typeof(space.spot) ~= "CFrame" then
		return
	end
	local rides = space.rides
	local at = space.spot
	if rides and rides.spotOffset then
		at = rides.primary.CFrame * rides.spotOffset
	end
	local world = self.World.World
	local seed = world and world.layout and world.layout.seed or 0
	local rng = Rng.new(Rng.hash(space.id .. ":" .. tostring(seed)))
	at *= CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
	local model, thing
	if self.Filler then
		model, thing = self.Filler(space, at)
	end
	if model == nil then
		if rng:NextNumber() >= F.JunkChance then
			return
		end
		model = Junk.build(rng:Pick(Junk.Names), at, self.World.content)
	end
	if not model then
		return
	end
	if typeof(thing) ~= "table" then
		thing = self.Hands:AddThing(model, Physical.Dressing[model.Name] or { class = "light", label = model.Name })
	end
	if thing then
		table.insert(space.contents, thing)
		thing.inside = space
		if rides then
			thing.rides = rides
			thing.rideOffset = rides.primary.CFrame:ToObjectSpace(model:GetPivot())
			-- Every client slides it with its drawer (Controllers/MotionController).
			model:SetAttribute("RidesOn", rides.id)
			model:SetAttribute("RideOffset", thing.rideOffset)
		end
	end
end

-- Hands and prompts ---------------------------------------------------------------

function FurnitureService:Piece(id: string)
	return self.pieces[id]
end

-- A player's hand on it (HandsService has checked reach and line of sight).
-- `release` (per second) is the last word as the hand lets go: it moves on
-- at that speed.
function FurnitureService:Drag(piece, value: number, player: Player, release: number?)
	local now = os.clock()
	piece.lastHolder, piece.lastHeldAt = player, now
	piece.fast = nil
	Articulation.hold(piece.state)
	Articulation.setTarget(piece.state, value)
	if release then
		piece.holder, piece.heldUntil = nil, 0
		Articulation.release(piece.state, release)
	else
		piece.holder = player
		piece.heldUntil = now + H.HoldSeconds
	end
	self.moving[piece] = true
end

-- Tell whoever holds it that it was taken out of their hands.
function FurnitureService:_dragStopped(piece)
	local holder = (piece.holder and os.clock() < piece.heldUntil) and piece.holder or nil
	if holder then
		piece.holder = nil
		Net.get("DragStop"):FireClient(holder, piece.id, piece.state.value)
	end
end

-- Open it all the way or shut it; `fast` for a door flung open.
function FurnitureService:SetOpen(piece, open: boolean, fast: boolean?)
	self:_dragStopped(piece)
	Articulation.drive(piece.state, open and piece.state.max or 0)
	piece.fast = fast and piece.joint.rate * 2.2 or nil
	self.moving[piece] = true
end

-- Held shut by a lock (a display case): it only rattles in its frame, and
-- its prompt is off until it's unlocked.
function FurnitureService:SetLocked(piece, locked: boolean)
	if locked then
		local state = piece.state
		state.value, state.target, state.latched = 0, 0, true
		state.velocity, state.mode = 0, "driven"
		self.moving[piece] = nil
		self:_place(piece)
		MotionState.settle(piece.primary, 0)
	end
	Articulation.setLocked(piece.state, locked)
	piece.locked = locked or nil
	piece.primary:SetAttribute("Locked", locked or nil)
	piece.prompt.Enabled = not locked and piece.state.max > 0
end

-- A closet's two sliding doors (bypass doors, on two tracks): one of them
-- open, either one shuts it. From inside, the door on the inner track hides
-- the other, so you could open the outer one and never reach it again (the
-- owner's solo playtest, 2026-10-09: stuck in a closet).
function FurnitureService:_partnerOpen(piece)
	if not piece.primary:GetAttribute("Bypass") then
		return nil
	end
	for _, other in self.pieces do
		if
			other ~= piece
			and other.prop.model == piece.prop.model
			and other.primary:GetAttribute("Bypass")
			and other.state.target >= other.state.max / 2
		then
			return other
		end
	end
	return nil
end

-- What E on it does: "Close" while it (or, for a bypass door, either of
-- the pair) is open.
function FurnitureService:_label(piece)
	local pair = { piece }
	if piece.primary:GetAttribute("Bypass") then
		for _, other in self.pieces do
			if other ~= piece and other.prop.model == piece.prop.model and other.primary:GetAttribute("Bypass") then
				table.insert(pair, other)
			end
		end
	end
	local open = false
	for _, one in pair do
		open = open or one.state.target >= one.state.max / 2
	end
	for _, one in pair do
		one.prompt.ActionText = open and "Close" or "Open"
	end
end

function FurnitureService:Toggle(piece, player: Player?)
	local open = piece.state.target < piece.state.max / 2
	local partner = open and self:_partnerOpen(piece)
	if partner then
		piece, open = partner, false
	end
	self:SetOpen(piece, open)
	self:_label(piece)
	local slide = piece.joint.kind == "slide"
	Sfx.play(
		slide and "Drawer" or (open and "DoorOpen" or "DoorClose"),
		piece.primary.Position,
		0.3,
		slide and 1.1 or 1.3
	)
	self.Noise:Emit(piece.primary.Position, 6, player, "furniture")
end

-- The furniture these pieces belong to was pushed by `step` (Services/
-- PushService has already moved every part of it): their joints, the spot
-- inside and whatever still lies in there go with it.
function FurnitureService:Shift(model: Instance, step: Vector3)
	for _, piece in self.pieces do
		if piece.prop.model == model then
			-- The joint moves with it; clients are told once it comes to rest
			-- (Settle), not every step of the push.
			local joint = piece.joint
			joint.shut += step
			joint.hinge += step
		end
	end
	for _, space in self.spaces do
		if space.prop.model == model then
			if typeof(space.spot) == "CFrame" then
				space.spot += step
			end
			for _, thing in space.contents do
				if thing.inside == space and thing.state == "rest" and thing.model.Parent then
					thing.model:PivotTo(thing.model:GetPivot() + step)
				end
			end
		end
	end
end

-- Pushed somewhere new and come to rest: how far each of its drawers and
-- doors can open is measured again (a wall or a bed may be in the way now).
function FurnitureService:Settle(model: Instance)
	for _, piece in self.pieces do
		if piece.prop.model == model then
			piece.primary:SetAttribute("Shut", piece.joint.shut)
			piece.primary:SetAttribute("Hinge", piece.joint.hinge)
			local max = self:_clearance(piece.joint, piece.primary, model)
			piece.state.max = max
			piece.primary:SetAttribute("Max", max)
			piece.prompt.Enabled = max > 0
			if piece.state.target > max then
				Articulation.drive(piece.state, max)
				self.moving[piece] = true
			end
		end
	end
end

-- Every door on a piece of furniture (a hiding spot's wardrobe).
function FurnitureService:_setAll(model: Instance, open: boolean, fast: boolean)
	for _, piece in self.pieces do
		if piece.prop.model == model and piece.joint.kind == "hinge" then
			if open then
				self:_dragStopped(piece)
				Articulation.drive(piece.state, piece.state.max * 0.7)
				piece.fast = fast and piece.joint.rate * 2.2 or nil
				self.moving[piece] = true
			else
				self:SetOpen(piece, false)
			end
		end
	end
end

return FurnitureService
