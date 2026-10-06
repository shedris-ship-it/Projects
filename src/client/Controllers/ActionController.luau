-- Input, movement, camera and tools. Keyboard, gamepad and touch all go
-- through ContextActionService so every action gets a mobile button.
--
--   R  use tool               F  flashlight
--   1 2 3 4 or wheel  choose a slot (1 torch, 4 hands)   X  put the tool down
--   Shift  sprint             G  hold for pings    C  callouts
--   Tab  map                  E  doors / hide / revive (prompts)
--   Enter or /  say something (spoken aloud, and he hears it; /w whispers)
--   Space (hidden)  hold breath                    E (hidden)  leave
--   F1  settings              F2  debug overlay (Studio)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Feel = require(Shared.Logic.Feel)
local Inventory = require(Shared.Logic.Inventory)
local Net = require(Shared.Net)

local PA = Constants.PlayerAttributes
local PS = Constants.PlayerStates
local P = Config.Player

local player = Players.LocalPlayer

local ActionController = {}

local sprintHeld = false
local stamina = P.StaminaMax
local exhausted = false
local cameraLight: SpotLight? = nil
local lightPart: BasePart? = nil
local flashlightAim: CFrame? = nil
local peekYaw, peekPitch = 0, 0

function ActionController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

local function sink()
	return Enum.ContextActionResult.Sink
end

function ActionController:_bind(name: string, handler, touch: boolean, title: string?, ...)
	ContextActionService:BindAction(name, function(_, inputState, input)
		return handler(inputState, input) or sink()
	end, touch, ...)
	if touch and title then
		ContextActionService:SetTitle(name, title)
	end
end

function ActionController:Start()
	local ui = self.controllers.UIController

	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end)

	self:_bind("ConsensusTool", function(inputState)
		if inputState == Enum.UserInputState.Begin and self.state:IsActive() and not self.state:IsHidden() then
			Net.get("UseTool"):FireServer(nil, nil)
		end
	end, true, "Tool", Enum.KeyCode.R, Enum.KeyCode.ButtonR1)

	self:_bind("ConsensusFlashlight", function(inputState)
		if inputState == Enum.UserInputState.Begin and self.state:IsActive() then
			local turningOn = not player:GetAttribute(PA.Flashlight)
			self.controllers.AudioController:PlayUi("FlashlightClick", 0.5, turningOn and 1 or 0.88)
			Net.get("SetFlashlight"):FireServer(turningOn)
		end
	end, true, "Light", Enum.KeyCode.F, Enum.KeyCode.DPadUp)

	-- Slots (owner, 2026-10-04): 1 is the torch, 2 and 3 hold found tools, 4 is
	-- your bare hands. The server decides; these only ask.
	for slot, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four } do
		self:_bind("ConsensusSlot" .. slot, function(inputState)
			if inputState == Enum.UserInputState.Begin and self.state:IsActive() and not self.state:IsHidden() then
				Net.get("SelectSlot"):FireServer(slot)
			end
		end, false, nil, key)
	end
	self:_bind("ConsensusCycleSlot", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:_cycleSlot(1)
		end
	end, false, nil, Enum.KeyCode.DPadDown)
	self:_bind("ConsensusDrop", function(inputState)
		if inputState == Enum.UserInputState.Begin and self.state:IsActive() and not self.state:IsHidden() then
			Net.get("DropItem"):FireServer()
		end
	end, false, nil, Enum.KeyCode.X)

	self:_bind("ConsensusSprint", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			sprintHeld = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			sprintHeld = false
		end
	end, true, "Run", Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	self:_bind("ConsensusPing", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:OpenPingWheel()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			ui:ClosePingWheel(true)
		end
	end, true, "Ping", Enum.KeyCode.G, Enum.KeyCode.DPadLeft)

	self:_bind("ConsensusCallout", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:ToggleCallouts()
		end
	end, true, "Call", Enum.KeyCode.C, Enum.KeyCode.DPadRight)

	self:_bind("ConsensusSay", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:OpenSpeak()
		end
	end, false, nil, Enum.KeyCode.Return, Enum.KeyCode.Slash)

	self:_bind("ConsensusMap", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:ToggleMap()
		end
	end, true, "Map", Enum.KeyCode.Tab, Enum.KeyCode.ButtonY) -- (Select is Roblox's own menu navigation)

	self:_bind("ConsensusSettings", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:ToggleSettings()
		end
	end, false, nil, Enum.KeyCode.F1)

	self:_bind("ConsensusDebug", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			ui:ToggleDebug()
		end
	end, false, nil, Enum.KeyCode.F2)

	-- Lay the touch buttons out around the jump button.
	local positions = {
		ConsensusTool = UDim2.new(1, -95, 1, -230),
		ConsensusFlashlight = UDim2.new(1, -170, 1, -245),
		ConsensusSprint = UDim2.new(1, -240, 1, -110),
		ConsensusPing = UDim2.new(1, -240, 1, -180),
		ConsensusCallout = UDim2.new(1, -240, 1, -250),
		ConsensusMap = UDim2.new(0, 20, 0, 120),
	}
	for name, position in positions do
		pcall(function()
			ContextActionService:SetPosition(name, position)
		end)
	end

	self.state.AttributeChanged:Connect(function(name, value)
		if name == PA.Hidden then
			self:_onHidden(value ~= nil)
		end
	end)
	self.state.PhaseChanged:Connect(function()
		self:_applyCamera()
	end)
	self.state.PlayerStateChanged:Connect(function()
		self:_applyCamera()
	end)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			self:_applyCamera()
		end)
	end)
	self:_applyCamera()

	RunService.RenderStepped:Connect(function(dt)
		self:_updateMovement(dt)
		self:_updateFlashlight(dt)
		self:_updateHiddenCamera()
	end)
	-- The wheel flips between slots, but only while the mouse is captured for
	-- looking (a menu that frees the mouse keeps its own scrolling), and not
	-- while you carry something (it brings that nearer or further instead).
	UserInputService.InputChanged:Connect(function(input, processed)
		local hands = self.controllers.HandsController
		if
			input.UserInputType == Enum.UserInputType.MouseWheel
			and not processed
			and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			and self.state:IsActive()
			and not self.state:IsHidden()
			and not (hands and hands:IsCarrying())
		then
			self:_cycleSlot(input.Position.Z > 0 and -1 or 1)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.state:IsHidden() then
			peekYaw = math.clamp(peekYaw - input.Delta.X * 0.004, -0.6, 0.6)
			peekPitch = math.clamp(peekPitch - input.Delta.Y * 0.004, -0.4, 0.4)
		end
	end)
end

-- The next slot with something in it, from the slots the server last told us.
-- The attribute lags a round trip, so a second flick of the wheel would read the
-- same slot as the first; the slot just asked for is remembered for a moment.
function ActionController:_cycleSlot(direction: number)
	local current = player:GetAttribute(PA.ActiveSlot) or 1
	if self.pendingSlot and os.clock() < (self.pendingUntil or 0) then
		current = self.pendingSlot
	end
	local mirror = { slots = {}, active = current }
	for slot, name in PA.Slots do
		local id = player:GetAttribute(name)
		mirror.slots[slot] = (type(id) == "string" and id ~= "") and { id = id } or false
	end
	if Inventory.cycle(mirror, direction) then
		self.pendingSlot, self.pendingUntil = mirror.active, os.clock() + 0.35
		Net.get("SelectSlot"):FireServer(mirror.active)
	end
end

-- Camera -------------------------------------------------------------------------------

function ActionController:_applyCamera()
	local inRun = self.state:InRun()
	local state = self.state:PlayerState()
	local firstPerson = inRun and Config.Camera.FirstPersonInRun and (state == PS.Active or state == PS.Downed)
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = Config.Camera.LobbyMaxZoom
		player.CameraMinZoomDistance = 4
	end
	-- Prompts are for active Witnesses only.
	ProximityPromptService.Enabled = (not inRun) or (state == PS.Active and not self.state:IsHidden())
end

function ActionController:_onHidden(hidden: boolean)
	local camera = Workspace.CurrentCamera
	-- Cloth settling and a door pulled to on the way in; the same on the way out.
	local audio = self.controllers.AudioController
	if audio then
		audio:PlayUi("Cloth", 0.45, hidden and 0.9 or 1.05)
		audio:PlayUi("Drawer", 0.3, hidden and 0.85 or 1)
	end
	-- In a walk-in closet you're just standing there: your own eyes, and the
	-- doors to slide open yourself (Services/HidingService's physical spots).
	local physical = player:GetAttribute("HidePhysical") == true
	if hidden then
		peekYaw, peekPitch = 0, 0
		if not physical then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		ContextActionService:BindActionAtPriority("ConsensusBreath", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Net.get("HoldBreath"):FireServer(true)
			elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				Net.get("HoldBreath"):FireServer(false)
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		ContextActionService:SetTitle("ConsensusBreath", "Breath")
		if not physical then
			ContextActionService:BindActionAtPriority("ConsensusLeave", function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					Net.get("LeaveHiding"):FireServer()
				end
				return Enum.ContextActionResult.Sink
			end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
			ContextActionService:SetTitle("ConsensusLeave", "Leave")
		end
	else
		ContextActionService:UnbindAction("ConsensusBreath")
		ContextActionService:UnbindAction("ConsensusLeave")
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	self:_applyCamera()
end

function ActionController:_updateHiddenCamera()
	if not self.state:IsHidden() then
		return
	end
	local peek = player:GetAttribute("HidePeek")
	if typeof(peek) == "CFrame" then
		Workspace.CurrentCamera.CFrame = peek * CFrame.Angles(0, peekYaw, 0) * CFrame.Angles(peekPitch, 0, 0)
	end
end

-- Movement ----------------------------------------------------------------------------------

function ActionController:_updateMovement(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local state = self.state:PlayerState()
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = false
	-- (Crawling or hiding uses no stamina.)
	if
		state ~= PS.Downed
		and not self.state:IsHidden()
		and (state == PS.Active or state == PS.Lobby or state == PS.Lost)
	then
		local canSprint = sprintHeld and moving and not exhausted and state ~= PS.Lost
		if canSprint then
			sprinting = true
			stamina = math.max(0, stamina - P.StaminaDrainPerSecond * dt)
			if stamina <= 0 then
				exhausted = true
			end
		else
			stamina = math.min(P.StaminaMax, stamina + P.StaminaRegenPerSecond * dt)
			if exhausted and stamina >= P.StaminaRecoverThreshold then
				exhausted = false
			end
		end
	end
	if state == PS.Lobby and not self.state:InRun() then
		stamina = P.StaminaMax
	end
	-- Slow walk, fast sprint, a stagger when out of stamina, and no faster
	-- than the furniture you lean on (Logic/Feel).
	local hands = self.controllers.HandsController
	local pushing = hands and hands.push
	local pushSpeed = pushing and pushing.model:GetAttribute("PushSpeed") or (pushing and 0 or nil)
	-- (F2 `botrun`: the server walks this character and sets its speed.)
	if not player:GetAttribute(PA.BotDriven) then
		humanoid.WalkSpeed = Feel.targetSpeed({
			downed = state == PS.Downed,
			hidden = self.state:IsHidden(),
			hub = state == PS.Lobby,
			sprinting = sprinting,
			exhausted = exhausted,
			pushSpeed = pushSpeed,
		}, P, Config.Run.DownedCrawlSpeed, Config.Push)
	end
	self.stamina = stamina / P.StaminaMax
	self.exhausted = exhausted
	self.sprinting = sprinting
end

-- Flashlight: a light for you; the server's head light (or clip light) is
-- what everyone else sees, so it's hidden locally to avoid doubling up. Its aim
-- trails the camera slightly on quick turns, like a handheld torch; the camera
-- itself never moves (doc section 4, comfort-safe). In first person the light
-- leaves the torch's lens (`beamCFrame`, from ViewModelController); the
-- camera-side spot below is the fallback for the hub and third person. With
-- anything else in your hands the torch is clipped to your shirt
-- (docs/plans/gameplay-rework.md section 4.1): a weak, short light from your
-- chest, pointing where your body faces.
function ActionController:_updateFlashlight(dt: number)
	local on = player:GetAttribute(PA.Flashlight) == true
	local clipped = player:GetAttribute(PA.TorchClipped) == true
	if not lightPart then
		lightPart = Instance.new("Part")
		lightPart.Name = "ConsensusFlashlight"
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.CanQuery = false
		lightPart.CanTouch = false
		lightPart.Transparency = 1
		lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
		lightPart.Parent = Workspace.CurrentCamera
		cameraLight = Instance.new("SpotLight")
		cameraLight.Angle = 48
		cameraLight.Range = 42
		cameraLight.Brightness = 2.6
		cameraLight.Color = Color3.fromRGB(255, 244, 220)
		cameraLight.Shadows = true
		cameraLight.Face = Enum.NormalId.Front
		cameraLight.Parent = lightPart
	end
	if lightPart.Parent ~= Workspace.CurrentCamera then
		lightPart.Parent = Workspace.CurrentCamera
	end
	local target = Workspace.CurrentCamera.CFrame * CFrame.new(0.6, -0.5, 0)
	local follow = math.clamp(dt * Config.PostFX.FlashlightFollow, 0, 1)
	flashlightAim = flashlightAim and flashlightAim:Lerp(target.Rotation, follow) or target.Rotation
	self.flashlightRotation = flashlightAim -- ViewModelController hangs the torch on it
	-- With a torch in hand the light leaves its lens (ViewModelController sets
	-- beamCFrame every frame); otherwise it falls back to your eye.
	lightPart.CFrame = self.beamCFrame or (CFrame.new(target.Position) * flashlightAim)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local clip = Config.Hands.ClipLight
	if clipped and root then
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		lightPart.CFrame = CFrame.new(root.Position + Vector3.new(0, clip.Height, 0))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(-10), 0, 0)
		cameraLight.Range = clip.Range
		cameraLight.Angle = clip.Angle
		cameraLight.Brightness = clip.Brightness
	else
		cameraLight.Range = 42
		cameraLight.Angle = 48
		cameraLight.Brightness = 2.6
	end
	cameraLight.Enabled = on
	cameraLight.Shadows = not self.state.settings.lowEnd
	local head = character and character:FindFirstChild("Head")
	local headLight = head and head:FindFirstChild("Flashlight")
	if headLight then
		headLight.Enabled = false
	end
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local clipLight = torso and torso:FindFirstChild("ClipLight")
	if clipLight then
		clipLight.Enabled = false
	end
end

return ActionController
