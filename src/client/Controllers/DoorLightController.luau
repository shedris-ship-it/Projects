-- Light under a shut door (the visual rework V2: P.T.'s hallway, a line of
-- lamplight under a door with the room behind it lit). For each shut door
-- near you with a lit room on one side and a dark one on the other, a thin
-- line glows in the gap and a little light spills onto the dark side's
-- floor, in the lit room's own colour (so it goes hunt red with the lamps).
-- Client only, decoration only: what counts as lit for the rules is still
-- WorldService's light rule, and a hidden door never leaks (it would give
-- itself away).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local C = Config.DoorLight
local Attr = Constants.Attributes

local DoorLightController = {}

function DoorLightController:Init(controllers)
	self.state = controllers.StateController
	self.effects = controllers.EffectsController
end

local doors = {} -- slab -> its leak, or false
local nextUpdate = 0

local function leakFor(slab: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "DoorLight"
	local line = Instance.new("Part")
	line.Name = "Line"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Size = Vector3.new(math.max(slab.Size.X - 0.3, 0.5), C.LineHeight, C.LineDepth)
	line.Parent = folder
	local emitter = Instance.new("Part")
	emitter.Name = "Spill"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.CastShadow = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(math.max(slab.Size.X - 0.6, 0.5), 0.1, 0.05)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Angle = C.Angle
	light.Range = C.Range
	light.Shadows = false
	light.Parent = emitter
	emitter.Parent = folder
	folder.Parent = Workspace.CurrentCamera -- client only, and out of the lens's rays
	return { folder = folder, line = line, emitter = emitter, light = light }
end

local function hide(leak)
	if leak and leak.folder.Parent then
		leak.line.Transparency = 1
		leak.light.Enabled = false
	end
end

-- How lit each room is (its brightest light against its own base: 0 dark,
-- 1 burning as built) and in what colour, from the lights EffectsController
-- already tracks (it dims, flickers and reddens them).
local function roomLight(effects)
	local lit = {}
	for light, info in effects:Lights() do
		local part = info.part
		local room = part and part:GetAttribute(Attr.RoomId)
		if room and light.Parent and light.Enabled and light.Name ~= "BounceLight" then
			local level = light.Brightness / math.max(info.base or 1, 0.01)
			local best = lit[room]
			if not best or level > best.level then
				lit[room] = { level = math.clamp(level, 0, 1), color = light.Color }
			end
		end
	end
	return lit
end

function DoorLightController:_update()
	local camera = Workspace.CurrentCamera
	if not camera or not self.state:InRun() then
		for _, leak in doors do
			hide(leak)
		end
		return
	end
	local from = camera.CFrame.Position
	local lit = roomLight(self.effects)
	local candidates = {}
	for slab, leak in doors do
		if not slab.Parent then
			if leak then
				leak.folder:Destroy()
			end
			doors[slab] = nil
			continue
		end
		local distance = (slab.Position - from).Magnitude
		local value = slab:GetAttribute("Value") or 0
		if distance < C.Radius and math.abs(value) < C.ShutAngle then
			table.insert(candidates, { slab = slab, distance = distance })
		else
			hide(leak)
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for i, c in candidates do
		local slab = c.slab
		local leak = doors[slab]
		local look = slab.CFrame.LookVector
		local front = self.state:RoomAt(slab.Position + look * 2.6)
		local back = self.state:RoomAt(slab.Position - look * 2.6)
		local frontLit = front and lit[front.id]
		local backLit = back and lit[back.id]
		local fl = frontLit and frontLit.level or 0
		local bl = backLit and backLit.level or 0
		-- One side lit, the other dark: the light comes through to the dark side.
		local source, toward = nil, nil
		if fl >= C.LitAt and bl <= C.DarkAt then
			source, toward = frontLit, -look
		elseif bl >= C.LitAt and fl <= C.DarkAt then
			source, toward = backLit, look
		end
		if i > C.Max or not source then
			hide(leak)
			continue
		end
		if not leak then
			leak = leakFor(slab)
			doors[slab] = leak
		end
		local bottom = slab.CFrame * CFrame.new(0, -slab.Size.Y / 2 - C.LineHeight / 2 - C.Gap, 0)
		local gap = bottom.Position + toward * (slab.Size.Z / 2 + C.LineDepth / 2)
		leak.line.CFrame = CFrame.lookAt(gap, gap + toward)
		local k = source.level
		local c3 = source.color
		leak.line.Color = Color3.new(c3.R * k, c3.G * k, c3.B * k)
		leak.line.Transparency = C.LineTransparency + (1 - C.LineTransparency) * (1 - k)
		leak.emitter.CFrame = CFrame.lookAt(gap + toward * 0.05, gap + toward * 1.05)
		leak.light.Color = c3
		leak.light.Brightness = C.Brightness * k
		leak.light.Enabled = true
	end
end

function DoorLightController:Start()
	local function track(slab)
		if slab:IsA("BasePart") and slab:GetAttribute("HiddenDoor") ~= true then
			doors[slab] = doors[slab] or false
		end
	end
	for _, slab in CollectionService:GetTagged(Constants.Tags.Door) do
		track(slab)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Door):Connect(function(slab)
		task.defer(track, slab)
	end)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextUpdate then
			nextUpdate = now + C.Every
			self:_update()
		end
	end)
end

return DoorLightController
