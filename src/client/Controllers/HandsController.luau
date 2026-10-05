-- Your hands on the house (docs/plans/gameplay-rework.md section 4.5), the
-- Amnesia way: hold the left mouse button (RT on a gamepad) on a door and
-- your hand takes hold of it. Your view stays put while you hold it, and
-- moving the mouse moves your hand: sideways for left and right, up for away
-- from you and down for towards you (the right stick on a gamepad). The door
-- turns about its hinge to follow your hand, so pushing and pulling from
-- either side just work. Let go of the button and you let go of the door.
--
-- The server decides (Services/HandsService checks reach and line of sight;
-- DoorService turns the door at its own rate and stops it against The Guest).
-- This only says where your hand wants the door, and moves your own copy at
-- once so it feels like your hand, not a round trip (Config.Hands.PredictDrag).
-- Grabbing anything puts your hands in your hands: slot 4, torch clipped on.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Articulation = require(Shared.Logic.Articulation)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Inventory = require(Shared.Logic.Inventory)
local Net = require(Shared.Net)

local H = Config.Hands
local D = Config.Doors
local PA = Constants.PlayerAttributes

local player = Players.LocalPlayer

local HandsController = {}

function HandsController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.drag = nil
	self.mouseDelta = Vector2.zero
	self.stick = Vector2.zero
	self.sentAt = 0
end

function HandsController:Start()
	ContextActionService:BindActionAtPriority("ConsensusGrab", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if self:_begin() then
				return Enum.ContextActionResult.Sink
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			if self.drag then
				self:_finish()
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	-- The camera reads the mouse itself (UserInputService), so this only
	-- listens; the view is held still in _update.
	UserInputService.InputChanged:Connect(function(input)
		if self.drag and input.UserInputType == Enum.UserInputType.MouseMovement then
			self.mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
	-- Right after the camera, before the view model hangs things on it.
	RunService:BindToRenderStep("ConsensusHands", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn("[Consensus] hands failed: " .. tostring(err))
			self:_finish()
		end
	end)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The door you're looking at within reach: its slab and the point you'd take
-- hold of, or nil.
function HandsController:_aimedDoor(): (BasePart?, Vector3?)
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, camera }
	local origin = camera.CFrame.Position
	local hit = Workspace:Raycast(origin, camera.CFrame.LookVector * H.Reach, params)
	if not hit then
		return nil, nil
	end
	local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
	local slab = model and model.Name == "Door" and model.PrimaryPart
	if not slab or not slab:GetAttribute("Hinge") or not slab:GetAttribute("Shut") then
		return nil, nil
	end
	return slab, hit.Position
end

-- Something your hands could take hold of here (FocusMarkers asks).
function HandsController:CanDrag(instance: Instance): boolean
	local model = instance:FindFirstAncestorWhichIsA("Model") or instance
	return model.Name == "Door" and model.PrimaryPart ~= nil and model.PrimaryPart:GetAttribute("Hinge") ~= nil
end

function HandsController:_active(): boolean
	return self.state:InRun() and self.state:IsActive() and not self.state:IsHidden()
end

function HandsController:_begin(): boolean
	if not self:_active() or self.drag then
		return false
	end
	local slab, point = self:_aimedDoor()
	if not slab or not point then
		return false
	end
	local hinge: Vector3 = slab:GetAttribute("Hinge")
	local shut: CFrame = slab:GetAttribute("Shut")
	local model = slab.Parent :: Model
	-- Where you took hold of it, on the slab, and where that point sits when
	-- the door is shut (the angle is measured from there).
	local onSlab = slab.CFrame:PointToObjectSpace(point)
	local grabShut = shut:PointToWorldSpace(onSlab) - hinge
	local parts, offsets = {}, {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			table.insert(offsets, slab.CFrame:ToObjectSpace(p.CFrame))
		end
	end
	local angle = Articulation.flatAngle(
		{ x = shut.LookVector.X, z = shut.LookVector.Z },
		{ x = slab.CFrame.LookVector.X, z = slab.CFrame.LookVector.Z }
	)
	self.drag = {
		id = slab:GetAttribute(Constants.Attributes.CId),
		slab = slab,
		hinge = hinge,
		shut = shut,
		onSlab = onSlab,
		grabShut = { x = grabShut.X, z = grabShut.Z },
		parts = parts,
		offsets = offsets,
		hand = point,
		angle = math.clamp(angle, 0, D.OpenAngle),
		target = math.clamp(angle, 0, D.OpenAngle),
		look = Workspace.CurrentCamera.CFrame.LookVector,
		state = { min = 0, max = D.OpenAngle },
	}
	self.mouseDelta = Vector2.zero
	self.stick = Vector2.zero
	-- The right stick moves your hand instead of the view while you hold on.
	ContextActionService:BindActionAtPriority("ConsensusDragStick", function(_, _, input)
		self.stick = Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Thumbstick2)
	if (player:GetAttribute(PA.ActiveSlot) or 1) ~= Inventory.HANDS_SLOT then
		Net.get("SelectSlot"):FireServer(Inventory.HANDS_SLOT)
	end
	return true
end

function HandsController:_finish()
	local drag = self.drag
	if not drag then
		return
	end
	self.drag = nil
	ContextActionService:UnbindAction("ConsensusDragStick")
	-- Our copy goes back to the server's once it has settled.
	task.delay(0.5, function()
		if self.drag and self.drag.slab == drag.slab then
			return
		end
		local angle = drag.slab:GetAttribute("Angle")
		if typeof(angle) == "number" and drag.slab.Parent then
			self:_pose(drag, angle)
		end
	end)
end

-- Put our copy of the door at an angle.
function HandsController:_pose(drag, degrees: number)
	local slab = CFrame.new(drag.hinge) * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-drag.hinge) * drag.shut
	local cframes = table.create(#drag.parts)
	for i, offset in drag.offsets do
		cframes[i] = slab * offset
	end
	Workspace:BulkMoveTo(drag.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function HandsController:_update(dt: number)
	local drag = self.drag
	if not drag then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = camera.CFrame.Position
	if not self:_active() or not drag.slab.Parent or (drag.slab.Position - eye).Magnitude > H.DragReach + 1 then
		self:_finish()
		return
	end
	-- Hold the view still: the camera builds each frame from where it looked
	-- last, so putting its aim back here keeps it put without a jump later.
	camera.CFrame = CFrame.lookAt(eye, eye + drag.look)

	-- Move the hand.
	local forward = flat(drag.look)
	forward = forward.Magnitude > 1e-3 and forward.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local delta = self.mouseDelta
	self.mouseDelta = Vector2.zero
	local hand = drag.hand
		+ right * (delta.X * H.DragSensitivity + self.stick.X * H.DragStickSpeed * dt)
		+ forward * (-delta.Y * H.DragSensitivity + self.stick.Y * H.DragStickSpeed * dt)
	-- A door that won't follow (shut, against something) keeps your hand close.
	local slabNow = CFrame.new(drag.hinge)
		* CFrame.Angles(0, math.rad(drag.angle), 0)
		* CFrame.new(-drag.hinge)
		* drag.shut
	local grabNow = slabNow:PointToWorldSpace(drag.onSlab)
	local reach = flat(hand - grabNow)
	if reach.Magnitude > H.DragStretch then
		hand = grabNow + reach.Unit * H.DragStretch + Vector3.new(0, hand.Y - grabNow.Y, 0)
	end
	drag.hand = hand
	local fromHinge = hand - drag.hinge
	drag.target = Articulation.hingeTarget(drag.state, drag.grabShut, { x = fromHinge.X, z = fromHinge.Z })

	local now = os.clock()
	if now - self.sentAt >= 1 / H.DragSendHz then
		self.sentAt = now
		Net.get("Drag"):FireServer(drag.id, drag.target)
	end
	-- Our own copy follows at the door's own rate (the server's catches up).
	if H.PredictDrag then
		local step = D.SwingRate * dt
		local gap = drag.target - drag.angle
		drag.angle = math.abs(gap) <= step and drag.target or drag.angle + math.sign(gap) * step
		if drag.angle <= D.LatchAngle and drag.target <= D.LatchAngle then
			drag.angle = 0
		end
		self:_pose(drag, drag.angle)
	else
		local angle = drag.slab:GetAttribute("Angle")
		drag.angle = typeof(angle) == "number" and angle or drag.angle
	end
end

-- Holding a door right now (the hotbar and markers can say so).
function HandsController:IsHolding(): boolean
	return self.drag ~= nil
end

-- F2 `drag <right> <away>` (Studio's input tool can't move a locked mouse):
-- take hold of the door you're looking at and move your hand that many studs
-- over a second, then let go, through the same code as the mouse.
function HandsController:DebugDrag(right: number, away: number): string
	if not self:_begin() then
		return "no door within reach where you're looking"
	end
	local drag = self.drag
	task.spawn(function()
		local started = os.clock()
		local moved = 0
		while self.drag == drag and moved < 1 do
			local t = math.min(1, os.clock() - started)
			local step = t - moved
			moved = t
			self.mouseDelta += Vector2.new(right, -away) * (step / H.DragSensitivity)
			RunService.RenderStepped:Wait()
		end
		task.wait(0.4)
		if self.drag == drag then
			self:_finish()
		end
	end)
	return string.format("dragging %s: hand %.1f right, %.1f away", tostring(drag.id), right, away)
end

return HandsController
