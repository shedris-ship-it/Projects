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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Joint = require(Shared.Lib.Joint)
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
	-- Optional (R2a): function(space, at: CFrame) -> Model?, what belongs in
	-- a space instead of junk; return false to leave it empty.
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
	end)
	RunService.Heartbeat:Connect(function(dt)
		for piece in self.moving do
			self:_step(piece, dt)
		end
	end)
	-- Hide in a wardrobe and its doors pull shut behind you; leave (or be
	-- found) and they swing open.
	self.Hiding.Entered:Connect(function(_, spot)
		self:_setAll(spot.model, false, false)
	end)
	self.Hiding.Left:Connect(function(_, spot, forced)
		self:_setAll(spot.model, true, forced == true)
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
	local size = primary.Size - Vector3.new(0.1, 0.1, 0.1)
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
	local count = 0
	for _, prop in world.props or {} do
		local model = prop.model
		if not model.Parent then
			continue
		end
		local spaces = {}
		for _, child in model:GetChildren() do
			local primary = child:IsA("Model") and child.PrimaryPart
			local joint = primary and Joint.read(primary)
			if not joint then
				continue
			end
			count += 1
			local piece = self:_piece("piece:" .. count, child, primary, joint, prop)
			local group = primary:GetAttribute("Group") or child.Name
			local space = spaces[group]
			if not space then
				space = {
					id = prop.id .. ":" .. group,
					prop = prop,
					spot = primary:GetAttribute("Spot"),
					pieces = {},
					filled = false,
					contents = {},
				}
				spaces[group] = space
				table.insert(self.spaces, space)
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
	end
	world.pieces = self.pieces
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
	local piece = {
		id = id,
		model = model,
		primary = primary,
		joint = joint,
		prop = prop,
		parts = parts,
		offsets = offsets,
		state = Articulation.new({ max = max, rate = joint.rate, latchAt = joint.latch }),
		holder = nil,
		heldUntil = 0,
		upright = Joint.upright(joint),
		solid = primary.CanCollide,
		label = primary:GetAttribute("Label") or "Drawer",
	}
	primary:SetAttribute(Attr.CId, id)
	primary:SetAttribute("Max", max)
	primary:SetAttribute("Value", 0)
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
	local from = state.value
	local events = Articulation.step(state, dt, piece.fast)
	self:_place(piece)
	local now = os.clock()
	local holder = (piece.holder and now < piece.heldUntil) and piece.holder or nil
	local position = piece.primary.Position
	local slide = joint.kind == "slide"
	for _, event in events do
		if event == "latch" then
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
		piece.primary:SetAttribute("Value", math.round(state.value * 100) / 100)
		piece.prompt.ActionText = state.value > state.max / 2 and "Close" or "Open"
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
	local model
	if self.Filler then
		model = self.Filler(space, at)
	end
	if model == nil then
		if rng:NextNumber() >= F.JunkChance then
			return
		end
		model = Junk.build(rng:Pick(Junk.Names), at, self.World.folder)
	end
	if not model then
		return
	end
	local thing = self.Hands:AddThing(model, Physical.Dressing[model.Name] or { class = "light", label = model.Name })
	if thing then
		table.insert(space.contents, thing)
		if rides then
			thing.rides = rides
			thing.rideOffset = rides.primary.CFrame:ToObjectSpace(model:GetPivot())
		end
	end
end

-- Hands and prompts ---------------------------------------------------------------

function FurnitureService:Piece(id: string)
	return self.pieces[id]
end

-- A player's hand on it (HandsService has checked reach and line of sight).
function FurnitureService:Drag(piece, value: number, player: Player)
	piece.holder = player
	piece.heldUntil = os.clock() + H.HoldSeconds
	piece.fast = nil
	Articulation.setTarget(piece.state, value)
	self.moving[piece] = true
end

-- Open it all the way or shut it; `fast` for a door flung open.
function FurnitureService:SetOpen(piece, open: boolean, fast: boolean?)
	Articulation.setTarget(piece.state, open and piece.state.max or 0)
	piece.fast = fast and piece.joint.rate * 2.2 or nil
	self.moving[piece] = true
end

function FurnitureService:Toggle(piece, player: Player?)
	local open = piece.state.target < piece.state.max / 2
	self:SetOpen(piece, open)
	piece.prompt.ActionText = open and "Close" or "Open"
	local slide = piece.joint.kind == "slide"
	Sfx.play(
		slide and "Drawer" or (open and "DoorOpen" or "DoorClose"),
		piece.primary.Position,
		0.3,
		slide and 1.1 or 1.3
	)
	self.Noise:Emit(piece.primary.Position, 6, player, "furniture")
end

-- Every door on a piece of furniture (a hiding spot's wardrobe).
function FurnitureService:_setAll(model: Instance, open: boolean, fast: boolean)
	for _, piece in self.pieces do
		if piece.prop.model == model and piece.joint.kind == "hinge" then
			if open then
				Articulation.setTarget(piece.state, piece.state.max * 0.7)
				piece.fast = fast and piece.joint.rate * 2.2 or nil
				self.moving[piece] = true
			else
				self:SetOpen(piece, false)
			end
		end
	end
end

return FurnitureService
