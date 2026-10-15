-- The three cutscenes, played (the visual rework V8; Logic/Cutscene has the
-- shots): the front door slamming and locking behind the squad, the lights
-- dying as he takes his seat at the dinner, and the last shot out of the
-- front door. The camera is taken for a few seconds through Controllers/
-- CinemaController, letterboxed. Any key or button skips the rest; "Skip
-- cutscenes" in Settings skips them all. Never in a hunt, nor while you're
-- being taken down (Controllers/TakedownController has the camera then).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Cutscene = require(Shared.Logic.Cutscene)
local Net = require(Shared.Net)

local RS = Constants.RunState
local OWNER = "cutscene"
local DOOR_OPEN = math.rad(58) -- (how far the front door stands open as the night begins)

local player = Players.LocalPlayer

local CutsceneController = {}

local active = nil -- the one playing

local function v3(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function arr(v: Vector3)
	return { v.X, v.Y, v.Z }
end

-- The default movement (Roblox's PlayerModule): off while it plays.
local function setControls(on: boolean)
	pcall(function()
		local module = player:FindFirstChild("PlayerScripts")
		module = module and module:FindFirstChild("PlayerModule")
		if module then
			local controls = (require :: any)(module):GetControls()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

function CutsceneController:Init(controllers)
	self.controllers = controllers
end

function CutsceneController:Start()
	Net.get("Cutscene").OnClientEvent:Connect(function(event)
		local ok, err = pcall(self._begin, self, event)
		if not ok then
			warn("[Consensus] cutscene failed to start: " .. tostring(err))
			self:_finish()
		end
	end)
	-- Any key or button skips (not the mouse moving, not the wheel).
	UserInputService.InputBegan:Connect(function(input)
		if not active or active.skipped then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.Gamepad1
		then
			active.skipped = os.clock()
		end
	end)
	RunService:BindToRenderStep("ConsensusCutscene", Enum.RenderPriority.Camera.Value + 4, function(dt)
		local ok, err = pcall(self._frame, self, dt)
		if not ok then
			warn("[Consensus] cutscene frame failed: " .. tostring(err))
			self:_finish()
		end
	end)
end

function CutsceneController:Playing(): boolean
	return active ~= nil
end

-- Whether to play one at all just now.
function CutsceneController:_wanted(kind: string): boolean
	local state = self.controllers.StateController
	if state and state.settings and state.settings.skipCutscenes then
		return false
	end
	local takedown = self.controllers.TakedownController
	if takedown and takedown:Owns(player) then
		return false
	end
	-- (Never in a hunt; you're out of the house for the last shot.)
	local hunting = ReplicatedStorage:FindFirstChild("RunState")
	if kind ~= "escape" and hunting and hunting:GetAttribute(RS.Hunting) then
		return false
	end
	return true
end

function CutsceneController:_begin(event)
	if type(event) ~= "table" or not self:_wanted(event.kind) then
		return
	end
	if active then
		self:_finish()
	end
	local scene
	local door = typeof(event.door) == "Instance" and event.door :: BasePart or nil
	local outward = typeof(event.outward) == "Vector3" and event.outward or nil
	-- (Where the doorway is: the door itself may be standing open.)
	local doorway = typeof(event.doorway) == "Vector3" and event.doorway or (door and door.Position)
	if event.kind == "arrival" and door and outward then
		-- The inside knob: the one nearer the hall.
		local hall = typeof(event.hall) == "Vector3" and event.hall or door.Position - outward * 12
		local knob = nil
		for _, d in door:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Knob" then
				if not knob or (d.Position - hall).Magnitude < (knob.Position - hall).Magnitude then
					knob = d
				end
			end
		end
		scene = Cutscene.arrival({
			door = arr(doorway),
			floor = door.Position.Y - door.Size.Y / 2,
			outward = { outward.X, outward.Z },
			knob = knob and arr(knob.Position) or nil,
			hall = arr(hall),
		})
	elseif event.kind == "dinner" and typeof(event.table) == "CFrame" and typeof(event.head) == "Vector3" then
		local centre = event.table.Position
		scene = Cutscene.dinner({
			centre = { centre.X, event.head.Y, centre.Z },
			head = arr(event.head),
		})
	elseif event.kind == "escape" and door and outward then
		scene = Cutscene.escape({
			door = arr(doorway),
			floor = door.Position.Y - door.Size.Y / 2,
			outward = { outward.X, outward.Z },
		})
	end
	if not scene then
		return
	end
	self:_clearShots(scene)
	active = {
		scene = scene,
		start = typeof(event.start) == "number" and event.start or Workspace:GetServerTimeNow(),
		beat = 1,
		shot = 0,
		door = door,
		outward = outward,
		jolts = {},
		-- (What the shots are of, never hidden from them: the front door; the
		-- laid table and his chair.)
		keep = door and { door } or {},
	}
	if scene.kind == "dinner" then
		local level = Workspace:FindFirstChild("ConsensusLevel")
		local dinner = level and level:FindFirstChild("Dinner", true)
		if dinner then
			table.insert(active.keep, dinner)
		end
		if typeof(event.tableModel) == "Instance" then
			table.insert(active.keep, event.tableModel)
		end
	end
	if scene.beats[1] and scene.beats[1].door and door then
		self:_holdDoor(door, outward)
	end
	if scene.key then
		-- (The shot's own key light, warm and soft, faded in on its shot.)
		local part = Instance.new("Part")
		part.Name = "CutsceneKey"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.CFrame = CFrame.new(v3(scene.key.at))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 168, 96)
		light.Range = scene.key.range
		light.Brightness = 0
		light.Shadows = true
		light.Parent = part
		part.Parent = Workspace
		active.key = { part = part, light = light }
	end
	self.controllers.CinemaController:Begin(OWNER, scene.keep)
	setControls(false)
	if scene.run then
		-- Out of the door and past the lens.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(v3(scene.run))
		end
	end
end

-- A camera with a wall or a tree between it and what it films stands
-- somewhere else (Logic/Cutscene.variants: the other side, higher); if
-- nowhere's clear, it comes in towards what it films till it sees it (never
-- closer than a quarter of the way).
function CutsceneController:_clearShots(scene)
	local cinema = self.controllers.CinemaController
	for _, shot in scene.shots do
		local placed = false
		for _, variant in Cutscene.variants(scene, shot) do
			if
				cinema:Clear(v3(shot.from.look), v3(variant.from))
				and cinema:Clear(v3(shot.to.look), v3(variant.to))
			then
				shot.from.at, shot.to.at = variant.from, variant.to
				placed = true
				break
			end
		end
		if not placed then
			for _, pose in { shot.from, shot.to } do
				local look, at = v3(pose.look), v3(pose.at)
				for step = 0, 5 do
					local try = look:Lerp(at, 1 - step * 0.15)
					if cinema:Clear(look, try) or step == 5 then
						pose.at = arr(try)
						break
					end
				end
			end
		end
	end
end

-- The front door as the night begins: standing open, to swing shut (on this
-- client only; it's put back exactly as it was after).
function CutsceneController:_holdDoor(door: BasePart, outward: Vector3)
	local parts = { door }
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local starts = {}
	for i, p in parts do
		starts[i] = p.CFrame
	end
	local width = math.max(door.Size.X, door.Size.Z)
	local along = door.Size.X >= door.Size.Z and door.CFrame.RightVector or door.CFrame.LookVector
	local hinge = door.Position - along * width / 2
	-- (It opens out, as at the dinner: FinaleService:_openFront.)
	local turnSign = along:Cross(outward).Y >= 0 and 1 or -1
	active.swing = { parts = parts, starts = starts, hinge = hinge, sign = turnSign, open = -1 }
	self:_swingDoor(1)
end

function CutsceneController:_swingDoor(open: number)
	local swing = active and active.swing
	if not swing or math.abs(swing.open - open) < 1e-4 then
		return
	end
	swing.open = open
	local hinge = swing.hinge
	local turn = CFrame.new(hinge) * CFrame.Angles(0, -swing.sign * DOOR_OPEN * open, 0) * CFrame.new(-hinge)
	local cframes = table.create(#swing.parts)
	for i, start in swing.starts do
		cframes[i] = turn * start
	end
	Workspace:BulkMoveTo(swing.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function CutsceneController:_frame(_dt: number)
	if not active then
		return
	end
	local scene = active.scene
	local t = Workspace:GetServerTimeNow() - active.start
	-- (F2 checks: the attribute DebugCutsceneAt pins the moment, for stills.)
	local pinned = player:GetAttribute("DebugCutsceneAt")
	if type(pinned) == "number" then
		t = math.clamp(pinned, 0, scene.length - 0.01)
	end
	local cinema = self.controllers.CinemaController
	if not cinema:Active() or cinema.owner ~= OWNER then
		-- (The camera went to something that matters more: a takedown.)
		local ended = active
		active = nil
		if ended.swing then
			Workspace:BulkMoveTo(ended.swing.parts, ended.swing.starts, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if ended.key then
			ended.key.part:Destroy()
		end
		setControls(true)
		return
	end
	-- Skipped: a moment's black, then yours again (the last shot stays black:
	-- you're on your way out).
	if active.skipped then
		local k = math.clamp((os.clock() - active.skipped) / 0.25, 0, 1)
		cinema:Black(k)
		if k >= 1 and (scene.kind ~= "escape" or t >= scene.length) then
			self:_finish()
		end
		return
	end
	if t >= scene.length then
		self:_finish()
		return
	end
	-- The beats: sounds, the door, a jolt, the lightning.
	while scene.beats[active.beat] and scene.beats[active.beat].t <= t do
		local beat = scene.beats[active.beat]
		active.beat += 1
		self:_play(beat)
	end
	if active.swing then
		local doorBeat = scene.beats[1]
		local swing = doorBeat and doorBeat.door
		if swing then
			-- Faster and faster: slammed.
			local k = math.clamp((t - doorBeat.t) / swing.seconds, 0, 1)
			self:_swingDoor(swing.from + (swing.to - swing.from) * k * k)
		end
	end
	if active.key then
		local k = math.clamp((t - scene.key.from) / 0.5, 0, 1)
		active.key.light.Brightness = scene.key.brightness * k * k * (3 - 2 * k)
	end
	local at, look, fov, index = Cutscene.camera(scene, math.max(0, t))
	local position, target = v3(at), v3(look)
	if index ~= active.shot then
		-- A new shot: the small things in its way put out of it.
		active.shot = index
		cinema:FadeFor(position, { target }, active.keep)
	end
	local shake = Vector3.zero
	local clock = os.clock()
	for _, jolt in active.jolts do
		local since = clock - jolt.at
		if since < 1 then
			local size = jolt.size * math.exp(-since * 9)
			shake += Vector3.new(math.sin(clock * 61), math.sin(clock * 53 + 1), math.sin(clock * 47 + 2)) * size
		end
	end
	cinema:Shoot(CFrame.lookAt(position + shake, target + shake * 0.5), fov)
	cinema:Black(Cutscene.black(scene, t))
end

function CutsceneController:_play(beat)
	local scene = active.scene
	local where = active.door and active.door.Position or Workspace.CurrentCamera.CFrame.Position
	local audio = self.controllers.AudioController
	if beat.sound and audio then
		if scene.kind == "escape" then
			-- (The storm's own, at the ears.)
			audio:PlayFor(beat.sound, nil, beat.volume or 1, beat.pitch or 1, 4)
		else
			audio:PlayAt(beat.sound, where, beat.volume or 1, beat.pitch or 1, false)
		end
	end
	if beat.jolt then
		table.insert(active.jolts, { at = os.clock(), size = beat.jolt })
	end
	if beat.flash then
		local weather = self.controllers.WeatherController
		local state = self.controllers.StateController
		local soft = state and state.settings and state.settings.reduceFlicker or false
		if weather and weather._flash then
			task.spawn(weather._flash, weather, 1, 0.12, soft)
		end
	end
end

function CutsceneController:_finish()
	local ended = active
	active = nil
	if not ended then
		return
	end
	if ended.swing then
		-- (The door exactly as the server has it.)
		Workspace:BulkMoveTo(ended.swing.parts, ended.swing.starts, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if ended.key then
		ended.key.part:Destroy()
	end
	self.controllers.CinemaController:End(OWNER)
	setControls(true)
end

return CutsceneController
