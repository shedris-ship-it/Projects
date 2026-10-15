-- Cutscenes and the Guest's takedown: the camera taken from you for a few
-- seconds, letterboxed (the visual rework V8; docs/ART.md "the look": the
-- bars only for big moments). One owner at a time says where the camera is
-- each frame (Shoot) and how black the screen is (Black); this keeps it
-- there, after everything else that moves the camera, and gives it back.
--
-- It also answers "can the camera stand here?" for Logic/ShotPicker: a ball
-- swept along the line (Config.Cinema.ClearRadius) through anything that
-- collides (walls, closed doors, the furniture's bodies), and hides the small
-- things that still get in a shot (a lamp, a plant, a chair's model).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local C = Config.Cinema
local player = Players.LocalPlayer

-- The level's own structure is never hidden for a shot (a wall would show
-- the next room); only small things are.
local STRUCTURE = {
	Wall = true,
	Floor = true,
	Ceiling = true,
	WallSkin = true,
	Skin = true,
	Lining = true,
	Crown = true,
	Baseboard = true,
	DadoRail = true,
	Casing = true,
	Wainscot = true,
}

local CinemaController = {}

function CinemaController:Init(controllers)
	self.controllers = controllers
	self.owner = nil
	self.want = nil
	self.black = 0
	self.bars = 0
	self.faded = {} -- part -> true (hidden for the shot)
	self.hidden = {} -- ScreenGui -> true (the HUD, put away)
end

function CinemaController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ConsensusCinema"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 95
	local function bar(name: string, anchorY: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = gui
		return f
	end
	self.top = bar("Top", 0)
	self.bottom = bar("Bottom", 1)
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.ZIndex = 2
	black.Parent = gui
	self.blackFrame = black
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui
	-- After every other camera writer (the hands, the view model, the roll).
	RunService:BindToRenderStep("ConsensusCinema", Enum.RenderPriority.Last.Value + 5, function(dt)
		local ok, err = pcall(self._frame, self, dt)
		if not ok then
			warn("[Consensus] cinema frame failed: " .. tostring(err))
		end
	end)
end

function CinemaController:Active(): boolean
	return self.owner ~= nil
end

-- Take the camera for `owner` (a name, so only its owner gives it back).
function CinemaController:Begin(owner: string)
	if self.owner and self.owner ~= owner then
		self:End(self.owner)
	end
	self.owner = owner
	self.want = nil
	self.black = 0
end

-- Where the camera is this frame.
function CinemaController:Shoot(cframe: CFrame, fov: number?)
	self.want = { cframe = cframe, fov = fov or C.FieldOfView }
end

-- How black the screen is (0 .. 1).
function CinemaController:Black(amount: number)
	self.black = math.clamp(amount, 0, 1)
end

-- Give the camera back.
function CinemaController:End(owner: string)
	if self.owner ~= owner then
		return
	end
	self.owner = nil
	self.want = nil
	self.black = 0
	self:Unfade()
	for gui in self.hidden do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	table.clear(self.hidden)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	local state = self.controllers.StateController
	camera.FieldOfView = (state and state.settings and state.settings.fov) or Config.Camera.FieldOfView
	local action = self.controllers.ActionController
	if action and action._applyCamera then
		action:_applyCamera()
	end
end

function CinemaController:_frame(dt: number)
	local goal = self.owner and 1 or 0
	local rate = dt / C.BarSeconds
	self.bars = goal > self.bars and math.min(goal, self.bars + rate) or math.max(goal, self.bars - rate)
	local eased = self.bars * self.bars * (3 - 2 * self.bars)
	self.top.Size = UDim2.fromScale(1, C.Bars * eased)
	self.bottom.Size = UDim2.fromScale(1, C.Bars * eased)
	self.blackFrame.BackgroundTransparency = 1 - self.black
	if not self.owner then
		return
	end
	-- The HUD stays away while it runs (captions stay: they're the film's
	-- subtitles, under the bars).
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui ~= self.gui and gui.Enabled and not gui:GetAttribute("CinemaKeep") then
				gui.Enabled = false
				self.hidden[gui] = true
			end
		end
	end
	local want = self.want
	if want then
		local camera = Workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.CFrame = want.cframe
		camera.FieldOfView = want.fov
	end
end

-- Sight lines -------------------------------------------------------------------------

-- What a sight line passes through: anything that collides, but not the
-- people in the scene (every player, him) nor anything see-through.
function CinemaController:_params(): RaycastParams
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local level = Workspace:FindFirstChild("ConsensusLevel")
	local guest = level and level:FindFirstChild("Stalker")
	if guest then
		table.insert(ignore, guest)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

-- Nothing between a and b (a ball the camera's size swept along it).
function CinemaController:Clear(a: Vector3, b: Vector3, params: RaycastParams?): boolean
	local offset = b - a
	local length = offset.Magnitude
	if length < 0.05 then
		return true
	end
	local hit = Workspace:Spherecast(a, C.ClearRadius, offset, params or self:_params())
	return hit == nil or hit.Distance >= length - 0.15
end

-- Logic/ShotPicker's `clear`, over the house as it is now.
function CinemaController:ClearFunction()
	local params = self:_params()
	return function(a, b)
		return self:Clear(Vector3.new(a[1], a[2], a[3]), Vector3.new(b[1], b[2], b[3]), params)
	end
end

-- Where the ceiling is above a point (or `fallback` above it).
function CinemaController:CeilingAbove(point: Vector3, fallback: number): number
	local hit = Workspace:Raycast(point, Vector3.new(0, fallback, 0), self:_params())
	return hit and hit.Position.Y or point.Y + fallback
end

-- Hiding what's in the shot ---------------------------------------------------------

-- Does the segment a -> b pass within `margin` of a part's box?
local function crosses(part: BasePart, a: Vector3, b: Vector3, margin: number): boolean
	local half = part.Size / 2 + Vector3.new(margin, margin, margin)
	local la = part.CFrame:PointToObjectSpace(a)
	local lb = part.CFrame:PointToObjectSpace(b)
	local tmin, tmax = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local p0 = (la :: any)[axis]
		local d = (lb :: any)[axis] - p0
		local h = (half :: any)[axis]
		if math.abs(d) < 1e-6 then
			if p0 < -h or p0 > h then
				return false
			end
		else
			local t1, t2 = (-h - p0) / d, (h - p0) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return false
			end
		end
	end
	return true
end

-- Hide the small things between the camera at `from` and each of `targets`
-- (and any the camera stands in), for this shot.
function CinemaController:FadeFor(from: Vector3, targets: { Vector3 })
	self:Unfade()
	local level = Workspace:FindFirstChild("ConsensusLevel")
	if not level then
		return
	end
	local guest = level:FindFirstChild("Stalker")
	local reach = 0
	for _, target in targets do
		reach = math.max(reach, (target - from).Magnitude)
	end
	for _, d in level:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and not STRUCTURE[d.Name] then
			local size = d.Size
			local big = math.max(size.X, size.Y, size.Z)
			if big < 12 and (d.Position - from).Magnitude < reach + big and not (guest and d:IsDescendantOf(guest)) then
				local hide = crosses(d, from, from, C.FadeMargin)
				if not hide then
					for _, target in targets do
						-- (Up to near the subject: what's right by them is part of the scene.)
						local stop = from + (target - from) * 0.85
						if crosses(d, from, stop, C.FadeMargin * 0.5) then
							hide = true
							break
						end
					end
				end
				if hide then
					d.LocalTransparencyModifier = 1
					self.faded[d] = true
				end
			end
		end
	end
end

function CinemaController:Unfade()
	for part in self.faded do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	table.clear(self.faded)
end

return CinemaController
