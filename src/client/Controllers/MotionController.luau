-- Draws every moving door, drawer, cupboard door and lid smoothly (R2c, the
-- physics feel pass; the owner found the physics "somewhat laggy"). The
-- server moves the real parts at its own step, which reaches this client in
-- jumps; while something moves, the server also writes a snapshot of its
-- motion on the main part (Lib/MotionState). This steps the same rules
-- (Logic/Articulation, Lib/Joint.motionSpec) from that snapshot every frame
-- and draws this client's copy just before the frame renders, easing into
-- each new snapshot rather than snapping to it. Once it comes to rest, the
-- server's copy (where it settled) is drawn as it is.
--
-- The one writer of moving joints on this client: your own hands
-- (Controllers/HandsController) don't move a door themselves, they hold its
-- state here (Hold), so what you drag answers your hand at once.
--
-- What lies in a drawer slides with it (RidesOn on the thing's model, set by
-- Services/FurnitureService).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Joint = require(Shared.Lib.Joint)
local MotionState = require(Shared.Lib.MotionState)

local H = Config.Hands
local Attr = Constants.Attributes

local MotionController = {}

-- primary part -> { primary, joint, momentum, parts, offsets, riders, state,
-- display, hand, rate }
local entries = {}
local active = {}

function MotionController:Init(controllers)
	self.controllers = controllers
end

local function riderModels(id: string)
	local found = {}
	for _, model in CollectionService:GetTagged(Constants.Tags.Grabbable) do
		if model:GetAttribute("RidesOn") == id and model:IsA("Model") then
			local offset = model:GetAttribute("RideOffset")
			if typeof(offset) == "CFrame" then
				table.insert(found, { model = model, offset = offset })
			end
		end
	end
	return found
end

-- Everything that moves with this main part, measured as it is now.
local function gather(entry)
	local primary = entry.primary
	local model = primary.Parent
	entry.parts, entry.offsets = {}, {}
	if model then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(entry.parts, p)
				table.insert(entry.offsets, primary.CFrame:ToObjectSpace(p.CFrame))
			end
		end
	end
	local id = primary:GetAttribute(Attr.CId)
	entry.riders = typeof(id) == "string" and riderModels(id) or {}
end

local function entryFor(primary: BasePart)
	local entry = entries[primary]
	if entry then
		return entry
	end
	local joint = Joint.read(primary)
	if not joint then
		return nil
	end
	entry = { primary = primary, joint = joint }
	entries[primary] = entry
	return entry
end

local function newState(entry, value: number)
	-- The joint can move (pushed furniture): read it fresh.
	entry.joint = Joint.read(entry.primary) or entry.joint
	local spec = Joint.motionSpec(entry.joint, entry.primary:GetAttribute("Momentum"), value)
	local max = entry.primary:GetAttribute("Max")
	if typeof(max) == "number" then
		spec.max = math.max(max, value)
	end
	return Articulation.new(spec)
end

-- Start drawing it, from where its parts are right now on this screen.
local function activate(entry)
	if not active[entry.primary] then
		gather(entry)
		entry.joint = Joint.read(entry.primary) or entry.joint
		entry.display = math.clamp(Joint.valueOf(entry.joint, entry.primary.CFrame), 0, entry.joint.max)
		active[entry.primary] = entry
	end
end

-- Where the server says it came to rest.
local function rested(entry)
	local value = entry.primary:GetAttribute("Value")
	if typeof(value) == "number" and entry.state then
		entry.state = newState(entry, value)
		entry.rate = nil
	end
end

-- A new snapshot from the server: rebuild the state from it, run forward to
-- now, and let the drawn copy ease towards it.
function MotionController:_snapshot(primary: BasePart)
	local entry = entryFor(primary)
	if not entry or entry.hand then
		return
	end
	local snap = MotionState.read(primary)
	if not snap then
		-- It has come to rest: ease into where it settled, then let go.
		if active[primary] then
			rested(entry)
		end
		return
	end
	local state = newState(entry, snap.value)
	state.velocity = snap.velocity
	state.target = snap.target
	state.mode = snap.mode
	entry.rate = snap.rate
	local late = math.clamp(Workspace:GetServerTimeNow() - snap.at, 0, 0.5)
	if late > 0 then
		Articulation.step(state, late, entry.rate)
	end
	activate(entry)
	entry.state = state
end

function MotionController:_watch(primary: Instance)
	if not primary:IsA("BasePart") then
		return
	end
	primary:GetAttributeChangedSignal("Motion"):Connect(function()
		self:_snapshot(primary)
	end)
	-- A rest value that lands after the stop (or a lock snapping it shut).
	primary:GetAttributeChangedSignal("Value"):Connect(function()
		local entry = entries[primary]
		if entry and active[primary] and not entry.hand and primary:GetAttribute("Motion") == nil then
			rested(entry)
		end
	end)
	if primary:GetAttribute("Motion") ~= nil then
		self:_snapshot(primary)
	end
end

local function pose(entry, value: number)
	local at = Joint.pose(entry.joint, value)
	local cframes = table.create(#entry.parts)
	for i, offset in entry.offsets do
		cframes[i] = at * offset
	end
	if #entry.parts > 0 then
		Workspace:BulkMoveTo(entry.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, rider in entry.riders do
		if rider.model.Parent and rider.model:GetAttribute("RidesOn") ~= nil then
			rider.model:PivotTo(at * rider.offset)
		end
	end
end

function MotionController:_step(dt: number)
	local blend = 1 - math.exp(-dt / H.MotionBlend)
	for primary, entry in active do
		if not primary.Parent then
			active[primary] = nil
			entries[primary] = nil
			continue
		end
		local state = entry.state
		if not state then
			continue
		end
		Articulation.step(state, dt, entry.rate)
		if entry.hand then
			-- Your own hand: no easing, it answers at once.
			entry.display = state.value
		else
			entry.display += (state.value - entry.display) * blend
		end
		pose(entry, entry.display)
		-- At rest, here and on the server: done.
		local resting = primary:GetAttribute("Motion") == nil
			and not entry.hand
			and not Articulation.moving(state)
			and math.abs(entry.display - state.value) < 0.02
		if resting then
			pose(entry, state.value)
			active[primary] = nil
		end
	end
end

-- Your hand takes hold of it (Controllers/HandsController): returns the
-- state the hand aims (set its target), already held, from `value`.
function MotionController:Hold(primary: BasePart, value: number)
	local entry = entryFor(primary)
	if not entry then
		return nil
	end
	local state = newState(entry, value)
	Articulation.hold(state)
	entry.state = state
	entry.hand = true
	entry.rate = nil
	activate(entry)
	entry.display = value
	return state
end

-- Your hand lets go at `velocity`: it swings on here, and the server's
-- snapshots take over as they come.
function MotionController:Release(primary: BasePart, velocity: number)
	local entry = entries[primary]
	if entry and entry.state then
		Articulation.release(entry.state, velocity)
		entry.hand = false
	end
end

-- The server stopped it in your hands (against a body, or he forced it).
function MotionController:Stop(primary: BasePart, value: number)
	local entry = entries[primary]
	if entry and entry.state then
		entry.hand = false
		Articulation.stop(entry.state, value)
	end
end

function MotionController:Start()
	for _, primary in CollectionService:GetTagged(Constants.Tags.Articulated) do
		self:_watch(primary)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Articulated):Connect(function(primary)
		self:_watch(primary)
	end)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.Articulated):Connect(function(primary)
		active[primary] = nil
		entries[primary] = nil
	end)
	-- Just before the frame is drawn, after replication has applied the
	-- server's copy: ours wins on this screen.
	local event = (RunService :: any).PreRender or RunService.RenderStepped
	event:Connect(function(dt)
		local ok, err = pcall(self._step, self, dt)
		if not ok then
			warn("[Consensus] motion failed: " .. tostring(err))
		end
	end)
end

return MotionController
