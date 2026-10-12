-- The lens (the visual rework V1, 2026-10-12: P.T. on 35mm film; docs/plans
-- in the owner's plan, phase V1). What the camera does to the picture, on
-- this client only:
--   film grain   8 frames of real grain, one texel to a screen pixel, flipped
--                at 24 a second whatever the frame rate (Logic/Lens)
--   tonemapping  Roblox's ColorGradingEffect (Config.Lens.Tonemapper)
--   rack focus   the depth of field pulls to what the middle of your view
--                rests on; the Guest is always kept sharp within 40 studs
--   adaptation   your eyes open a little in the dark and close under lamps
--   glare        a warm halo with a red rim round lamps you can see, a faint
--                streak, and lens dirt when one is near the middle
--   vignette     one smooth, dithered image, closing in with Dread
--   letterbox    bars for the cutscenes (V8)
-- Nothing here moves the camera (doc section 4). Grain, flares and the film
-- flicker each have an off switch in Settings; the graphics preset decides
-- the rest (Config.Graphics).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Lens = require(Shared.Logic.Lens)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer
local L = Config.Lens

local LensController = {}

local farBase = {} -- a tagged far light -> its brightness as built

function LensController:Init(controllers)
	self.state = controllers.StateController
	self.effects = controllers.EffectsController
end

function LensController:_build()
	local camera = Workspace.CurrentCamera
	self.grade = Instance.new("ColorGradingEffect")
	self.grade.Name = "ConsensusTonemap"
	self.grade.TonemapperPreset = Enum.TonemapperPreset[L.Tonemapper] or Enum.TonemapperPreset.Default
	self.grade.Parent = camera
	self.dof = Instance.new("DepthOfFieldEffect")
	self.dof.Name = "ConsensusDof"
	self.dof.NearIntensity = 0
	self.dof.FarIntensity = L.Focus.FarBlur
	self.dof.FocusDistance = L.Focus.Far
	self.dof.InFocusRadius = L.Focus.Far * L.Focus.RadiusPerStud
	self.dof.Parent = camera

	-- Above the hunt's wash and the bleed-out rim (ConsensusEffects, -5),
	-- under the HUD.
	local gui = Ui.screen("ConsensusLens", -4, player:WaitForChild("PlayerGui"))
	self.gui = gui
	local function layer(className, props)
		props.BackgroundTransparency = 1
		props.Parent = gui
		return Ui.new(className, props)
	end
	-- Glare first, so the dirt, the vignette and the grain lie over it.
	self.glares = {}
	for i = 1, L.Glare.Max do
		local streak = layer("ImageLabel", {
			Name = "Streak" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = Assets.Lens.GlareStreak,
			Visible = false,
			ZIndex = 1,
		})
		local halo = layer("ImageLabel", {
			Name = "Glare" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = Assets.Lens.Glare,
			Visible = false,
			ZIndex = 2,
		})
		self.glares[i] = { halo = halo, streak = streak }
	end
	self.dirt = layer("ImageLabel", {
		Name = "Dirt",
		Size = UDim2.fromScale(1, 1),
		Image = Assets.Lens.Dirt,
		ImageTransparency = 1,
		ZIndex = 3,
	})
	self.vignette = layer("ImageLabel", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		Image = Assets.Lens.Vignette,
		ImageTransparency = 1 - L.Vignette.hub,
		ZIndex = 4,
	})
	-- One label per grain frame, all resident, only one shown: swapping the
	-- Image instead could hitch while a texture loads.
	local size = Assets.Lens.GrainSize
	self.grain = {}
	for i, image in Assets.Lens.Grain do
		self.grain[i] = layer("ImageLabel", {
			Name = "Grain" .. i,
			Size = UDim2.new(1, size, 1, size),
			Image = image,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(size, size),
			ImageTransparency = 1,
			Visible = false,
			ZIndex = 5,
		})
	end
	self.bars = {}
	for _, top in { true, false } do
		self.bars[top] = layer("Frame", {
			Name = top and "LetterboxTop" or "LetterboxBottom",
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 6,
		})
	end
end

function LensController:Start()
	self:_build()
	self.exposureBase = Lighting.ExposureCompensation
	self.adapted = 0 -- stops, eased
	self.light = Lens.lightAt(1, 1, 0) -- the last light estimate at the camera
	self.flicker = 0
	self.tick = -1
	self.nextFocus = 0
	self.nextLight = 0
	self.focusTarget = { distance = L.Focus.Far, radius = L.Focus.Far * L.Focus.RadiusPerStud, far = L.Focus.FarBlur }
	self.rays = RaycastParams.new()
	self.rays.FilterType = Enum.RaycastFilterType.Exclude
	self.state.SettingsChanged:Connect(function()
		self:_applyPreset()
	end)
	self:_applyPreset()
	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)
	-- F2 `look <name>` (Services/DebugService, Data/LookSpots): once you're on
	-- the spot, your view turns to rest where the shot wants it.
	player:GetAttributeChangedSignal("DebugLookAt"):Connect(function()
		local target = player:GetAttribute("DebugLookAt")
		if typeof(target) ~= "Vector3" then
			return
		end
		task.wait(0.4)
		local camera = Workspace.CurrentCamera
		local head = player.Character and player.Character:FindFirstChild("Head")
		if camera and head then
			camera.CFrame = CFrame.lookAt(head.Position, target)
		end
	end)
end

function LensController:_applyPreset()
	local _, preset = self.state:Graphics()
	self.preset = preset
	self.dof.Enabled = preset.dof
end

-- Letterbox bars in or out (the cutscenes, V8): 2.39:1 on any screen.
function LensController:Letterbox(on: boolean, seconds: number?)
	local view = Workspace.CurrentCamera.ViewportSize
	local height = 0
	if on and view.X > 0 then
		local wanted = view.X / L.Letterbox.Aspect
		height = math.max(0, (view.Y - wanted) / 2 / view.Y)
	end
	local info = TweenInfo.new(seconds or L.Letterbox.Seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, bar in self.bars do
		TweenService:Create(bar, info, { Size = UDim2.fromScale(1, height) }):Play()
	end
end

-- What not to hit: you, your view-model (under the camera), and a light's
-- own fixture when looking for walls in its way.
function LensController:_exclude(extra: Instance?)
	local list = { Workspace.CurrentCamera }
	if player.Character then
		table.insert(list, player.Character)
	end
	if extra then
		table.insert(list, extra)
	end
	self.rays.FilterDescendantsInstances = list
	return self.rays
end

-- The fixture model a room light hangs in (never the room itself: rooms sit
-- directly under ConsensusLevel, and ignoring one would ignore its walls).
local function fixtureOf(part: Instance): Instance?
	local model = part.Parent
	if model and model:IsA("Model") and model.Parent and model.Parent.Name ~= "ConsensusLevel" then
		return model
	end
	return nil
end

local function visible(self, from: Vector3, part: BasePart): boolean
	local to = part.Position
	local hit = Workspace:Raycast(from, to - from, self:_exclude(fixtureOf(part)))
	return hit == nil or (hit.Position - to).Magnitude < 0.6
end

local function bypassed(): { [string]: boolean }
	local value = RunService:IsStudio() and player:GetAttribute("LensBypass")
	if value == true then
		return { all = true }
	elseif type(value) == "string" then
		local skip = {}
		for name in string.gmatch(value, "%a+") do
			skip[name] = true
		end
		return skip
	end
	return {}
end

-- The Guest's distance when he's in view (for the focus), else nil.
local function guestInView(camera: Camera): number?
	local level = Workspace:FindFirstChild("ConsensusLevel")
	local guest = level and level:FindFirstChild("Stalker")
	if not guest or not guest:IsA("Model") then
		return nil
	end
	local position = guest:GetPivot().Position + Vector3.new(0, 2, 0)
	if position.Y >= 200 then
		return nil
	end
	local offset = position - camera.CFrame.Position
	local distance = offset.Magnitude
	if distance < 0.5 or offset.Unit:Dot(camera.CFrame.LookVector) < math.cos(math.rad(55)) then
		return nil
	end
	return distance
end

function LensController:_update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Studio only: the player attribute LensBypass shows the picture without
	-- the lens (true), or without some of it ("grain,grade,exposure,vignette,
	-- glare,focus"), for before-and-after shots from the same spot.
	local skip = bypassed()
	self.gui.Enabled = not skip.all
	self.grade.Enabled = not (skip.all or skip.grade)
	if skip.all then
		Lighting.ExposureCompensation = self.exposureBase
		self.dof.FocusDistance, self.dof.InFocusRadius, self.dof.FarIntensity = 16, 24, 0.3
		return
	end
	local settings = self.state.settings
	local preset = self.preset
	local inRun = self.state:InRun()
	local dread = inRun and self.state:Dread() or 0
	local now = os.clock()
	local from = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local view = camera.ViewportSize

	-- How much light reaches the camera, a few times a second: every room
	-- light by its fall-off, the strongest checked for a wall in the way
	-- (light round a corner still counts a little).
	if now >= self.nextLight then
		self.nextLight = now + L.Exposure.Every
		local lit = {}
		for light, info in self.effects:Lights() do
			if light.Parent and light.Enabled and info.part and info.part.Parent then
				local amount = Lens.lightAt(light.Brightness, light.Range, (info.part.Position - from).Magnitude)
				if amount > 0 then
					table.insert(lit, { amount = amount, part = info.part })
				end
			end
		end
		table.sort(lit, function(a, b)
			return a.amount > b.amount
		end)
		local total = 0
		for i, entry in lit do
			if i <= L.Exposure.Occluded and not visible(self, from, entry.part) then
				total += entry.amount * 0.15
			else
				total += entry.amount
			end
		end
		-- Your own torch: your eyes adjust to its pool, so the dark round the
		-- beam stays dark (ActionController's light, under the camera).
		local torchPart = camera:FindFirstChild("ConsensusFlashlight")
		local torch = torchPart and torchPart:FindFirstChild("SpotLight") -- the spill, not the Core
		if torch and torch.Enabled then
			total += L.Exposure.Torch * math.clamp(torch.Brightness / Config.Torch.Spill, 0, 1.5)
		end
		self.light = total
	end

	-- Eye adaptation, and the film's flicker on top (each grain frame).
	local tick = Lens.grainTick(now, L.GrainFps)
	local newFrame = tick ~= self.tick
	if newFrame then
		self.tick = tick
		local film = settings.grain == 2 and not settings.reduceFlicker and inRun
		self.flicker = film and (math.random() * 2 - 1) * L.Flicker or 0
	end
	if preset.adapt and inRun and not skip.exposure then
		local target = Lens.exposure(self.light, L)
		self.adapted = Lens.ease(self.adapted, target, Lens.exposureRate(self.adapted, target, L), dt)
	else
		self.adapted = Lens.ease(self.adapted, 0, 2, dt)
	end
	Lighting.ExposureCompensation = self.exposureBase + self.adapted + (skip.exposure and 0 or self.flicker)

	-- Grain: a new frame and shift 24 times a second. Its light specks fade
	-- with the light (the frame's tint): over black they read as TV snow, so
	-- in the dark the grain only darkens.
	local darkness = Lens.darkness(self.light, L)
	local opacity = skip.grain and 0 or Lens.grainOpacity(settings.grain or 2, dread, darkness, inRun, L)
	if newFrame then
		local frame, x, y = Lens.grainPick(tick, #self.grain, Assets.Lens.GrainSize)
		for i, label in self.grain do
			label.Visible = i == frame and opacity > 0
		end
		self.grain[frame].Position = UDim2.fromOffset(-x, -y)
	end
	local light = Lens.grainLight(darkness, L)
	for _, label in self.grain do
		if label.Visible then
			label.ImageTransparency = 1 - opacity
			label.ImageColor3 = Color3.new(light, light, light)
		end
	end

	-- The vignette closes in as the house turns.
	local v = L.Vignette
	self.vignette.ImageTransparency = skip.vignette and 1
		or 1 - (inRun and (v.calm + (v.collapse - v.calm) * dread / 100) or v.hub)

	-- Rack focus: what the middle of the view rests on, a few times a second,
	-- eased into a pull. The Guest in view stays sharp.
	if preset.dof and not skip.focus then
		if now >= self.nextFocus then
			self.nextFocus = now + L.Focus.Every
			local hit = Workspace:Raycast(from, look * L.Focus.Far, self:_exclude())
			local distance, radius, far = Lens.focus(hit and hit.Distance or nil, guestInView(camera), L)
			self.focusTarget = { distance = distance, radius = radius, far = far }
		end
		local t = self.focusTarget
		local dof = self.dof
		dof.FocusDistance = Lens.ease(dof.FocusDistance, t.distance, L.Focus.Ease, dt)
		dof.InFocusRadius = Lens.ease(dof.InFocusRadius, t.radius, L.Focus.Ease, dt)
		dof.FarIntensity = Lens.ease(dof.FarIntensity, t.far, L.Focus.Ease, dt)
	end

	-- Glare round the lamps you can see, nearest first; the lens's dirt when
	-- one burns near the middle of the view.
	local flares = preset.glare and settings.lensFlares ~= false and inRun and not skip.glare
	local shown, centre, centreLevel = 0, 0, 0
	if flares then
		local candidates = {}
		for light, info in self.effects:Lights() do
			local part = info.part
			if
				light.Parent
				and light.Enabled
				and part
				and part.Parent
				and (light:IsA("PointLight") or light:IsA("SpotLight"))
				and light.Name ~= "BounceLight"
			then
				local offset = part.Position - from
				local distance = offset.Magnitude
				if distance < L.Glare.MaxDistance and offset.Unit:Dot(look) > 0.2 then
					table.insert(candidates, { light = light, info = info, part = part, distance = distance })
				end
			end
		end
		-- Lights outside (World/Exterior's streetlamp): far brighter than a
		-- house lamp, so their glare carries much further.
		for _, part in CollectionService:GetTagged("ConsensusGlare") do
			local light = part:IsA("BasePart") and part:FindFirstChildWhichIsA("Light")
			if light and light.Enabled then
				local offset = part.Position - from
				local distance = offset.Magnitude
				if distance < L.Glare.MaxDistance / L.Glare.Far and offset.Unit:Dot(look) > 0.2 then
					farBase[light] = farBase[light] or light.Brightness
					table.insert(candidates, {
						light = light,
						info = { base = farBase[light] },
						part = part,
						distance = distance * L.Glare.Far,
					})
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.distance < b.distance
		end)
		for _, c in candidates do
			if shown >= L.Glare.Max then
				break
			end
			local point, onScreen = camera:WorldToViewportPoint(c.part.Position)
			if onScreen and point.Z > 0 and visible(self, from, c.part) then
				local level = c.light.Brightness / math.max(c.info.base or 1, 0.01)
				local facing = math.clamp((look:Dot((c.part.Position - from).Unit) - 0.6) / 0.4, 0, 1)
				local size, alpha = Lens.glare(c.distance, level, facing, view.Y, L)
				if alpha > 0.01 then
					shown += 1
					local slot = self.glares[shown]
					local tint = c.light.Color
					slot.halo.Visible = true
					slot.halo.Position = UDim2.fromOffset(point.X, point.Y)
					slot.halo.Size = UDim2.fromOffset(size, size)
					slot.halo.ImageTransparency = 1 - alpha
					slot.halo.ImageColor3 = Color3.new(1, 1, 1):Lerp(tint, 0.5)
					slot.streak.Visible = true
					slot.streak.Position = slot.halo.Position
					slot.streak.Size = UDim2.fromOffset(size * L.Glare.StreakWidth, size * 0.5)
					slot.streak.ImageTransparency = 1 - alpha * L.Glare.Streak
					slot.streak.ImageColor3 = slot.halo.ImageColor3
					-- How near the middle of the view (1 dead centre).
					local dx = (point.X - view.X / 2) / (view.X / 2)
					local dy = (point.Y - view.Y / 2) / (view.Y / 2)
					local c0 = 1 - math.clamp(math.sqrt(dx * dx + dy * dy), 0, 1)
					if c0 > centre then
						centre, centreLevel = c0, math.clamp(level, 0, 1) * math.clamp(1 - c.distance / 25, 0, 1)
					end
				end
			end
		end
	end
	for i = shown + 1, #self.glares do
		local slot = self.glares[i]
		if slot.halo.Visible then
			slot.halo.Visible = false
			slot.streak.Visible = false
		end
	end
	local dirt = (flares and preset.dirt) and Lens.dirt(centre, centreLevel, L) or 0
	self.dirt.ImageTransparency = 1 - dirt
end

return LensController
