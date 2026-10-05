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
--
-- Small things (Data/Physical: a mug, the telephone, a chair) are carried
-- instead (section 4.3): hold the button on one and it floats at arm's length
-- in front of you while you look and walk about; the wheel brings it nearer or
-- further, the right button (LT) throws it, letting go drops it. Once the
-- server hands it over, this client moves it with two constraints of its own;
-- the server watches that it stays near you and never passes through a wall.

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
local Physical = require(Shared.Data.Physical)

local H = Config.Hands
local D = Config.Doors
local PA = Constants.PlayerAttributes

local player = Players.LocalPlayer

local HandsController = {}

function HandsController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.drag = nil
	self.carry = nil -- { id, model, class, distance, askedAt, owned, attachment, align, orient, turn }
	self.aimedThing = nil -- the small thing you're looking at within reach
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
			elseif self.carry then
				self:_drop(true)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("ConsensusThrow", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and self.carry and self.carry.owned then
			self:_throw()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	-- The camera reads the mouse itself (UserInputService), so this only
	-- listens; the view is held still in _update.
	UserInputService.InputChanged:Connect(function(input)
		if self.drag and input.UserInputType == Enum.UserInputType.MouseMovement then
			self.mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		elseif self.carry and input.UserInputType == Enum.UserInputType.MouseWheel then
			-- The wheel brings what you carry nearer or further (instead of slots).
			local range = H.CarryDistance
			self.carry.distance = math.clamp(self.carry.distance + input.Position.Z * 0.4, range[1], range[3])
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

-- What's in front of your eye within reach.
function HandsController:_aim(): RaycastResult?
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, camera }
	return Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * H.Reach, params)
end

-- The small thing you're looking at within reach (its model), or nil.
function HandsController:_thingOf(hit: RaycastResult?): Model?
	local model = hit and hit.Instance:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("Grab") do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model
end

-- The door you're looking at within reach: its slab and the point you'd take
-- hold of, or nil.
function HandsController:_aimedDoor(): (BasePart?, Vector3?)
	local hit = self:_aim()
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
	if not self:_active() or self.drag or self.carry then
		return false
	end
	local slab, point = self:_aimedDoor()
	if not slab or not point then
		return self:_pickUp()
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
	if self.carry then
		self:_carryStep()
	end
	local looking = not self.drag and not self.carry and self:_active()
	self.aimedThing = looking and self:_thingOf(self:_aim()) or nil
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

-- Carrying ---------------------------------------------------------------------

-- Ask for the small thing you're looking at. The server says yes by marking
-- it HeldBy you and handing you its physics (_carryStep).
function HandsController:_pickUp(): boolean
	local model = self:_thingOf(self:_aim())
	if not model then
		return false
	end
	self.carry = {
		id = model:GetAttribute("Grab"),
		model = model,
		class = Physical.Classes[model:GetAttribute("Class")] or Physical.Classes.medium,
		distance = H.CarryDistance[2],
		askedAt = os.clock(),
		owned = false,
	}
	Net.get("Grab"):FireServer(self.carry.id)
	return true
end

function HandsController:_cleanCarry()
	local carry = self.carry
	self.carry = nil
	if carry then
		for _, key in { "align", "orient", "attachment" } do
			if carry[key] then
				carry[key]:Destroy()
			end
		end
	end
	return carry
end

-- Let go: it falls where it is.
function HandsController:_drop(tell: boolean)
	if self:_cleanCarry() and tell then
		Net.get("Release"):FireServer()
	end
end

function HandsController:_throw()
	self:_cleanCarry()
	Net.get("Throw"):FireServer(Workspace.CurrentCamera.CFrame.LookVector)
end

-- Keep what you carry floating in front of you, turning as you turn.
function HandsController:_carryStep()
	local carry = self.carry
	local model = carry.model
	local mine = model.Parent ~= nil and model:GetAttribute("HeldBy") == player.UserId
	if not mine then
		-- Refused, or taken from you (dropped by the server, you went down).
		if carry.owned or os.clock() - carry.askedAt > 1 then
			self:_cleanCarry()
		end
		return
	end
	if not self:_active() then
		self:_drop(true)
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local camera = Workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if not carry.owned then
		carry.owned = true
		local attachment = Instance.new("Attachment")
		attachment.Name = "HandGrip"
		attachment.Parent = root
		local align = Instance.new("AlignPosition")
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxForce = root.AssemblyMass * Workspace.Gravity * 8 + 1000
		align.MaxVelocity = 60
		align.Responsiveness = carry.class.follow
		align.Position = root.Position
		align.Parent = root
		local orient = Instance.new("AlignOrientation")
		orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orient.Attachment0 = attachment
		orient.MaxTorque = root.AssemblyMass * 4000 + 2000
		orient.Responsiveness = carry.class.follow * 0.6
		orient.CFrame = root.CFrame.Rotation
		orient.Parent = root
		carry.attachment, carry.align, carry.orient = attachment, align, orient
		-- Keep the way it was lying, relative to where you face.
		carry.turn = CFrame.Angles(0, -yaw, 0) * root.CFrame.Rotation
	end
	-- In front of your eye, but never pushed into a wall or a shelf.
	local eye = camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, camera, model }
	local distance = carry.distance
	local hit = Workspace:Raycast(eye, look * (distance + 0.5), params)
	if hit then
		distance = math.max(0.8, hit.Distance - 0.7)
	end
	carry.align.Position = eye + look * distance - Vector3.new(0, 0.35, 0)
	carry.orient.CFrame = CFrame.Angles(0, yaw, 0) * carry.turn
end

-- Holding a door or carrying something right now.
function HandsController:IsHolding(): boolean
	return self.drag ~= nil or self.carry ~= nil
end

function HandsController:IsCarrying(): boolean
	return self.carry ~= nil
end

-- The small thing you're looking at within reach (FocusMarkers marks it).
function HandsController:AimedThing(): Model?
	return self.aimedThing
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
