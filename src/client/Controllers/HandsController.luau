-- Your hands on the house (docs/plans/gameplay-rework.md section 4.5), the
-- Amnesia way: hold the left mouse button (RT on a gamepad) on a door (or a
-- drawer, a cupboard door, a chest's lid) and your hand takes hold of it. Your view stays put while you hold it, and
-- moving the mouse moves your hand: sideways for left and right, up for away
-- from you and down for towards you (the right stick on a gamepad). A door
-- turns about its hinge to follow your hand, so pushing and pulling from
-- either side just work; a drawer comes out as far as you pull; a lid lifts
-- as you push your hand away. Let go of the button and you let go.
--
-- The server decides (Services/HandsService checks reach and line of sight;
-- DoorService and FurnitureService move it, and a door stops against The
-- Guest or anyone in its way). This says where your hand wants the door and
-- turns your own copy at once (through Controllers/MotionController, the one
-- writer of moving joints here), so it feels like your hand, not a round
-- trip. Let go mid-swing and it swings on (R2c): the last word says how fast.
-- Your hands work from any slot (the squad playtest, 2026-10-08: swapping
-- the torch's beam for bare hands to open a door "doesn't feel good"): what
-- you hold stays in your hand, the torch lit.
--
-- Small things (Data/Physical: a mug, the telephone, a chair, a lamp) are
-- carried instead (section 4.3): hold the button on one and it floats at
-- arm's length in front of you while you look and walk about; the wheel
-- brings it nearer or further, holding the right button (LT) winds up a
-- throw and letting it go throws, letting the left button go drops it. This
-- client moves it with two constraints of its own, made as you reach for it
-- so they take hold the moment the server hands it over; it follows your
-- eye through a spring with its class's weight (Logic/Heft): light things
-- keep up, heavy ones trail, sag when whipped and lean as you swing them. A
-- throw or a drop leaves your hands exactly as it was moving; the server
-- watches that it stays near you and never passes through a wall.
--
-- Everything else that isn't built in is pushed (section 4.6): hold the
-- button on a bed or a wardrobe and walk, and this says which way you're
-- walking (Services/PushService works out how far it goes for how many push
-- it, and how heavy it is).
--
-- E does it all, on a keyboard (the squad playtest, 2026-10-08: "make
-- everything grabbable with E"). Tap E on a door or a drawer and it opens or
-- shuts (HandsService:Tap, the prompt's own job); hold E on it, or on
-- furniture, and your hand takes hold as the mouse button does. Tap E on a
-- small thing and you carry it: click to throw (hold to wind up), E to put
-- it down. Furniture you hide in: E hides you, holding it pushes, its doors
-- take the mouse.
--
-- One focus (the owner's solo playtest, 2026-10-08: a light switch by a door
-- took the door's E, and the piano offered only a push). E goes to the one
-- thing you're looking at, the only marker with words (UI/FocusMarkers):
-- what your eye ray hits, else the prompt nearest the middle of your view a
-- few degrees out at most (a switch is small; a door is not).
-- Logic/FocusActions says what a tap and a hold do to it. On a keyboard every
-- E prompt gives up its key and always shows (drawn by nobody), so this
-- fires the one you look at, not the one Roblox would have picked. Gamepad
-- and touch keep Roblox's prompts.
--
-- Tools in hand (same playtest: "boltcutters and items like that should be
-- held in the hand"): with the crowbar or the bolt cutters in your hands,
-- hold the click (or R) on the boards or the chain and you work at them
-- (Services/LockService, the ToolWork remote).

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
local FocusActions = require(Shared.Logic.FocusActions)
local Heft = require(Shared.Logic.Heft)
local Joint = require(Shared.Lib.Joint)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Throw = require(Shared.Logic.Throw)
local ThrowLift = require(Shared.Lib.ThrowLift)
local ToolLocks = require(Shared.Logic.ToolLocks)
local Tools = require(Shared.Data.Tools)
local Util = require(Shared.Lib.Util)

local ProximityPromptService = game:GetService("ProximityPromptService")

local Ui = require(script.Parent.Parent.Lib.Ui)

local GameSettings = UserSettings():GetService("UserGameSettings")

local H = Config.Hands
local P = Config.Push
local F = Config.Focus
local PA = Constants.PlayerAttributes

local player = Players.LocalPlayer

local HandsController = {}

function HandsController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.drag = nil
	self.carry = nil -- { id, model, class, distance, askedAt, owned, attachment, align, orient, turn }
	self.push = nil -- { id, model, sentAt } while you lean on a piece of furniture
	self.aimedPush = nil -- the furniture you could push, where you look
	self.aimedThing = nil -- the small thing you're looking at within reach
	self.focus = nil -- the one thing E is for now (_resolveFocus)
	self.working = nil -- the tool lock you're working at (ToolWork)
	self.mouseDelta = Vector2.zero
	self.stick = Vector2.zero
	self.sentAt = 0
end

function HandsController:Start()
	ContextActionService:BindActionAtPriority("ConsensusGrab", function(_, inputState)
		local carry = self.carry
		if carry and carry.viaE then
			-- Picked up with E: the click throws (held, it winds up).
			if inputState == Enum.UserInputState.Begin and carry.owned then
				carry.windingSince = os.clock()
			elseif
				(inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel)
				and carry.windingSince
			then
				self:_throw(os.clock() - carry.windingSince)
			end
			return Enum.ContextActionResult.Sink
		end
		if inputState == Enum.UserInputState.Begin then
			if self:ToolWork(true) or self:_begin() then
				return Enum.ContextActionResult.Sink
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			if self:ToolWork(false) then
				return Enum.ContextActionResult.Sink
			elseif self.drag then
				self:_finish()
				return Enum.ContextActionResult.Sink
			elseif self.carry then
				self:_drop(true)
				return Enum.ContextActionResult.Sink
			elseif self.push then
				self.push = nil
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	-- Hold to wind up, let go to throw (a tap still throws, softly).
	ContextActionService:BindActionAtPriority("ConsensusThrow", function(_, inputState)
		local carry = self.carry
		if inputState == Enum.UserInputState.Begin and carry and carry.owned then
			carry.windingSince = os.clock()
			return Enum.ContextActionResult.Sink
		elseif
			(inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel)
			and carry
			and carry.windingSince
		then
			self:_throw(os.clock() - carry.windingSince)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	-- E (keyboard): the one thing you're looking at (_resolveFocus), tapped
	-- or held. Ahead of everything else on E.
	ContextActionService:BindActionAtPriority("ConsensusHandsE", function(_, inputState)
		return self:_onE(inputState)
	end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.E)
	-- On a keyboard every E prompt gives its key to this and always shows
	-- (Style Custom: UI/FocusMarkers draws the one marker), so E fires
	-- whichever you look at, never the one Roblox would pick. Gamepad and
	-- touch get them back as they were. The server never changes these two
	-- properties, so ours stand.
	-- (A plain table: Roblox drops instance keys from weak ones while the
	-- instance lives on.)
	self.claimed = {} -- prompt -> true: one of E's
	self.shown = {} -- prompt -> true while Roblox shows it
	local function claim(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		if not self.claimed[prompt] then
			if prompt.KeyboardKeyCode ~= Enum.KeyCode.E then
				return
			end
			self.claimed[prompt] = true
			prompt.Destroying:Once(function()
				self.claimed[prompt] = nil
				self.shown[prompt] = nil
			end)
		end
		local keyboard = self:_keyboard()
		prompt.KeyboardKeyCode = keyboard and Enum.KeyCode.Unknown or Enum.KeyCode.E
		prompt.Exclusivity = keyboard and Enum.ProximityPromptExclusivity.AlwaysShow
			or Enum.ProximityPromptExclusivity.OnePerButton
	end
	for _, d in Workspace:GetDescendants() do
		claim(d)
	end
	Workspace.DescendantAdded:Connect(claim)
	ProximityPromptService.PromptShown:Connect(function(prompt)
		self.shown[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		self.shown[prompt] = nil
	end)
	self.wasKeyboard = self:_keyboard()
	UserInputService.LastInputTypeChanged:Connect(function()
		local keyboard = self:_keyboard()
		if keyboard ~= self.wasKeyboard then
			self.wasKeyboard = keyboard
			for prompt in self.claimed do
				if prompt.Parent then
					claim(prompt)
				else
					self.claimed[prompt] = nil
				end
			end
		end
	end)

	-- The server stopped what you hold (a body in its way, or he forced it).
	Net.get("DragStop").OnClientEvent:Connect(function(id, value)
		local drag = self.drag
		if drag and drag.id == id and typeof(value) == "number" then
			self:_finish(value)
		end
	end)
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
	-- Right after the camera (and after FeelController's roll, so a drag's
	-- held view isn't rolled), before the view model hangs things on it.
	RunService:BindToRenderStep("ConsensusHands", Enum.RenderPriority.Camera.Value + 2, function(dt)
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

-- What's in front of your eye within reach, looking past invisible helpers
-- (a hiding spot's prompt anchor, a window's light pane).
function HandsController:_aim(): RaycastResult?
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { player.Character, camera }
	params.FilterDescendantsInstances = ignore
	for _ = 1, 4 do
		local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * H.Reach, params)
		if not hit or hit.Instance.Transparency < 0.99 or hit.Instance.CanCollide then
			return hit
		end
		table.insert(ignore, hit.Instance)
		params.FilterDescendantsInstances = ignore
	end
	return nil
end

-- The small thing you're looking at within reach (its model), or nil.
-- Small things are forgiving to aim at: looking just past one (into the
-- drawer it lies in, at the floor beside it) counts, unless you're looking
-- at the front of a drawer or a door, which your hand takes instead.
local NEAR = 0.6

local function grabbable(instance: Instance): Model?
	local model = instance:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("Grab") do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model
end

function HandsController:_thingOf(hit: RaycastResult?): Model?
	if not hit then
		return nil
	end
	local model = grabbable(hit.Instance)
	if model then
		return model
	end
	local piece = hit.Instance:FindFirstAncestorWhichIsA("Model")
	if piece and piece.PrimaryPart == hit.Instance and hit.Instance:GetAttribute("Joint") then
		return nil
	end
	local best, nearest = nil, NEAR
	for _, part in Workspace:GetPartBoundsInRadius(hit.Position, NEAR) do
		local thing = grabbable(part)
		local distance = (part.Position - hit.Position).Magnitude
		if thing and distance < nearest then
			best, nearest = thing, distance
		end
	end
	return best
end

-- The main part of the door, drawer, cupboard door or lid this belongs to, if
-- your hands can take hold of it (the server gave it an id).
function HandsController:_pieceOf(instance: Instance): BasePart?
	local model = instance:FindFirstAncestorWhichIsA("Model")
	while model do
		local primary = model.PrimaryPart
		if primary and primary:GetAttribute("Joint") and primary:GetAttribute(Constants.Attributes.CId) then
			return primary
		end
		if model:GetAttribute("Grab") then
			return nil
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- Something your hands could take hold of here (FocusMarkers asks).
function HandsController:CanDrag(instance: Instance): boolean
	return self:_pieceOf(instance) ~= nil
end

-- Playing on a keyboard and mouse (E is your hands' then).
function HandsController:_keyboard(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Keyboard
		or last == Enum.UserInputType.TextInput
		or string.find(last.Name, "^Mouse") ~= nil
end

-- One focus ------------------------------------------------------------------------

-- How far off your line of sight the nearest point of a box is (radians),
-- how far away that point is, and the point.
local function offAim(eye: Vector3, look: Vector3, frame: CFrame, size: Vector3): (number, number, Vector3)
	local along = math.max(0, (frame.Position - eye):Dot(look))
	local onLine = frame:PointToObjectSpace(eye + look * along)
	local half = size / 2
	local nearest = frame:PointToWorldSpace(
		Vector3.new(
			math.clamp(onLine.X, -half.X, half.X),
			math.clamp(onLine.Y, -half.Y, half.Y),
			math.clamp(onLine.Z, -half.Z, half.Z)
		)
	)
	local toward = nearest - eye
	local distance = toward.Magnitude
	if distance < 1e-3 then
		return 0, 0, nearest
	end
	return math.acos(math.clamp(look:Dot(toward / distance), -1, 1)), distance, nearest
end

-- The furniture a hiding place's prompt anchor (in front of it, in the room)
-- belongs to: its sibling with the id the anchor names (World/LevelBuilder).
local hideFurniture = setmetatable({}, { __mode = "k" })
local function furnitureOf(anchor: Instance): Instance?
	local id = anchor:GetAttribute("HideFor")
	if not id then
		return nil
	end
	local known = hideFurniture[anchor]
	if known and known.Parent then
		return known
	end
	for _, sibling in anchor.Parent and anchor.Parent:GetChildren() or {} do
		if sibling ~= anchor and sibling:GetAttribute(Constants.Attributes.CId) == id then
			hideFurniture[anchor] = sibling
			return sibling
		end
	end
	return nil
end

-- What a part belongs to, and what kind of thing that is: a small thing you
-- carry, a door or drawer your hands take, furniture, or something with a
-- prompt (a switch, a note, a key). Outside a run, only prompts.
function HandsController:_objectOf(instance: Instance, inRun: boolean): (Instance?, string?)
	local furniture = furnitureOf(instance)
	if furniture then
		return furniture, "pushable"
	end
	if inRun then
		local thing = grabbable(instance)
		if thing then
			return thing, "thing"
		end
		local pushable = self:_pushableOf(instance)
		if pushable and pushable:GetAttribute("HideSpot") and not pushable:GetAttribute("WalkIn") then
			return pushable, "pushable" -- its doors are the hiding place: E hides you
		end
		local piece = self:_pieceOf(instance)
		if piece then
			return piece, "piece"
		end
		if pushable then
			return pushable, "pushable"
		end
	end
	local node = instance
	while node and node ~= Workspace do
		if node:GetAttribute(Constants.Attributes.CId) or node:FindFirstChildWhichIsA("ProximityPrompt") then
			return node, "prompt"
		end
		node = node.Parent
	end
	return nil, nil
end

-- Its prompts: E's (those on the part you look at first) and those on keys
-- of their own (Brace, the bolt), each once.
function HandsController:_promptsOf(object: Instance, kind: string, near: Instance?)
	local claimed, keyed, seen = {}, {}, {}
	local function add(prompt: Instance)
		-- Only one Roblox shows: one it doesn't (off screen, out of reach)
		-- can't be fired, so it's not offered.
		if not prompt:IsA("ProximityPrompt") or seen[prompt] or not prompt.Enabled or not self.shown[prompt] then
			return
		end
		seen[prompt] = true
		if self.claimed[prompt] then
			-- A door's or drawer's own prompt is what a tap does (HandsService:Tap).
			if not prompt:GetAttribute("HandsOwned") then
				table.insert(claimed, prompt)
			end
		elseif prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then
			table.insert(keyed, prompt)
		end
	end
	local node = near
	while node and node ~= Workspace and node ~= object.Parent do
		for _, child in node:GetChildren() do
			add(child)
		end
		node = node.Parent
	end
	-- A door's prompts are on its model; anything else's are in it.
	local scope = (kind == "piece" and object.Parent and object.Parent:IsA("Model")) and object.Parent or object
	for _, d in scope:GetDescendants() do
		add(d)
	end
	-- A hiding place's prompt is on an anchor in front of the furniture (on
	-- an attachment at its top).
	for prompt in self.shown do
		local parent = prompt.Parent
		local part = parent and (parent:IsA("Attachment") and parent.Parent or parent)
		if part and furnitureOf(part) == object then
			add(prompt)
		end
	end
	return claimed, keyed
end

-- Nothing solid between your eye and `point` (on `part`) but what's part of
-- `object`.
function HandsController:_inSight(eye: Vector3, point: Vector3, part: BasePart, object: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { player.Character, Workspace.CurrentCamera }
	params.FilterDescendantsInstances = ignore
	local toward = point - eye
	local distance = toward.Magnitude
	for _ = 1, 4 do
		local hit = Workspace:Raycast(eye, toward, params)
		if not hit or hit.Instance == part or hit.Instance:IsDescendantOf(object) or hit.Instance == object then
			return true
		end
		if hit.Distance >= distance - 0.4 then
			return true
		end
		if hit.Instance.Transparency < 0.99 or hit.Instance.CanCollide then
			return false
		end
		table.insert(ignore, hit.Instance)
		params.FilterDescendantsInstances = ignore
	end
	return true
end

-- The tool lock on it, if any: { kind, id, tool, action } (Services/LockService
-- marks a boarded or chained door's slab, a nailed chest and its fixings).
local function toolLockOf(object: Instance)
	local node = object
	for _ = 1, 3 do
		if not node or node == Workspace then
			break
		end
		local kind = node:GetAttribute("ToolLock")
		local id = node:GetAttribute("WorkId")
		local info = kind and ToolLocks.Kinds[kind]
		if info and id then
			return { kind = kind, id = id, tool = info.tool, action = info.action }
		end
		node = node.Parent
	end
	return nil
end

-- Can anything have your focus now (a screen up, tucked away or down: no;
-- shut in a wardrobe, yes: its door is how you get out).
function HandsController:_canFocus(): boolean
	if Ui.modalOpen() then
		return false
	end
	if not self.state:InRun() then
		return true
	end
	return self.state:IsActive() and not self.state:IsTucked()
end

-- Whether you stand inside it (a wardrobe or a locker you walked into).
local function standingIn(object: Instance): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not object:IsA("Model") or not object:GetAttribute("WalkIn") then
		return false
	end
	local frame, size = object:GetBoundingBox()
	local p = frame:PointToObjectSpace(root.Position)
	return math.abs(p.X) < size.X / 2 and math.abs(p.Z) < size.Z / 2
end

-- The one thing you're looking at, and what E does to it (Logic/FocusActions).
function HandsController:_resolveFocus()
	local inRun = self.state:InRun()
	local camera = Workspace.CurrentCamera
	local eye, look = camera.CFrame.Position, camera.CFrame.LookVector
	local hit = self:_aim()
	local object, kind, near, distance = nil, nil, nil, math.huge
	local thing = inRun and self:_thingOf(hit) or nil
	if thing then
		object, kind, near, distance = thing, "thing", hit and hit.Instance, hit and hit.Distance or 0
	elseif hit then
		object, kind = self:_objectOf(hit.Instance, inRun)
		near, distance = hit.Instance, hit.Distance
		if kind == "prompt" then
			-- Only with a prompt showing (Roblox shows a prompt in its reach).
			local any = false
			for prompt in self.shown do
				if prompt.Parent and (prompt.Parent == object or prompt:IsDescendantOf(object)) then
					any = true
					break
				end
			end
			if not any then
				object, kind = nil, nil
			end
		end
	end
	-- Off your aim: the prompt nearest the middle of your view, a few degrees
	-- out at most. Over furniture, only one right by your aim (a note lying
	-- on a table, a place at the dinner table) takes it from the furniture.
	if not object or kind == "pushable" then
		local best, bestAngle = nil, math.rad(object and F.NearCone or F.Cone)
		for prompt in self.shown do
			local parent = prompt.Parent
			local part = parent and (parent:IsA("Attachment") and parent.Parent or parent)
			if prompt.Enabled and part and part:IsA("BasePart") then
				local other, otherKind = self:_objectOf(part, inRun)
				if other and other ~= object then
					local angle, away, point = offAim(eye, look, part.CFrame, part.Size)
					angle += away * 0.002 -- (nearer first, all else equal)
					-- In sight where you look at it, or its middle.
					if
						angle < bestAngle
						and (self:_inSight(eye, point, part, other) or self:_inSight(eye, part.Position, part, other))
					then
						best, bestAngle = { other, otherKind, part, away }, angle
					end
				end
			end
		end
		if best then
			object, kind, near, distance = best[1], best[2], best[3], best[4]
		end
	end
	if not object or not kind then
		return nil
	end
	local claimed, keyed = self:_promptsOf(object, kind, near)
	local prompts = {}
	for _, prompt in claimed do
		table.insert(prompts, {
			id = prompt,
			action = prompt.ActionText,
			hold = prompt.HoldDuration,
			hide = prompt.Name == "HidePrompt",
		})
	end
	local pieceAction, pieceName
	if kind == "piece" then
		-- Its own prompt says what it is now ("Boarded door") and what a tap does.
		local scope = object.Parent or object
		for _, d in scope:GetDescendants() do
			if d:IsA("ProximityPrompt") and d:GetAttribute("HandsOwned") and d.Enabled then
				pieceAction = d.ActionText
				pieceName = d.ObjectText ~= "" and d.ObjectText or nil
				break
			end
		end
	end
	local tap, hold = FocusActions.choose({
		kind = kind,
		hideSpot = object:GetAttribute("HideSpot") == true,
		prompts = prompts,
		pieceAction = pieceAction,
		-- (Not the wardrobe you stand in.)
		canPush = kind == "pushable" and distance <= P.Reach + 1.5 and not standingIn(object),
	})
	local toolLock = inRun and toolLockOf(object) or nil
	if not tap and not hold and #keyed == 0 and not toolLock then
		return nil
	end
	local name = pieceName or object:GetAttribute("Label") or object:GetAttribute("PushLabel")
	for _, prompt in claimed do
		name = name or (prompt.ObjectText ~= "" and prompt.ObjectText or nil)
	end
	for _, prompt in keyed do
		name = name or (prompt.ObjectText ~= "" and prompt.ObjectText or nil)
	end
	return {
		object = object,
		kind = kind,
		name = name,
		tap = tap,
		hold = hold,
		keyed = keyed,
		toolLock = toolLock,
		near = near,
	}
end

-- The one thing you're looking at (UI/FocusMarkers marks it), or nil.
function HandsController:Focus()
	return self.focus
end

-- E pressed or let go (keyboard only: gamepad and touch use the prompts).
-- What E last did, for tests in Studio (the MCP can't see this client's tables).
function HandsController:_note(what: string)
	if RunService:IsStudio() then
		player:SetAttribute("DebugHandsE", what)
	end
end

-- Fire a prompt as a tap would: held for its hold, then let go.
local function tapPrompt(prompt: ProximityPrompt)
	prompt:InputHoldBegin()
	if prompt.HoldDuration <= 0 then
		prompt:InputHoldEnd()
	else
		task.delay(prompt.HoldDuration + 0.05, function()
			prompt:InputHoldEnd()
		end)
	end
end

-- Do what a tap of E does to the focus.
function HandsController:_doTap(press): boolean
	local action = press.tap
	local focus = press.focus
	if not action or not focus.object.Parent then
		return false
	end
	if action.kind == "tap" then
		Net.get("Tap"):FireServer(focus.object:GetAttribute(Constants.Attributes.CId))
	elseif action.kind == "pick" then
		if self:_pickUp(focus.object) and self.carry then
			self.carry.viaE = true
		end
	elseif action.kind == "prompt" and action.id.Parent then
		tapPrompt(action.id)
	else
		return false
	end
	self:_note("tap " .. action.kind .. " " .. tostring(action.text))
	return true
end

-- Begin what holding E does to the focus. Returns whether it began.
function HandsController:_doHold(press): boolean
	local action = press.hold
	local focus = press.focus
	if not action or not focus.object.Parent then
		return false
	end
	local began = false
	if action.kind == "drag" then
		local point = (press.near and press.near:IsDescendantOf(focus.object.Parent or focus.object) and press.at3)
			or focus.object.Position
		began = self:_takeHold(focus.object, point)
	elseif action.kind == "push" then
		began = self:_leanOn(focus.object)
	elseif action.kind == "holdPrompt" and action.id.Parent then
		action.id:InputHoldBegin()
		press.prompt = action.id
		began = true
	end
	self:_note((began and "hold " or "hold failed ") .. action.kind .. " " .. tostring(action.text))
	return began
end

function HandsController:_onE(inputState: Enum.UserInputState)
	local pass = Enum.ContextActionResult.Pass
	local sink = Enum.ContextActionResult.Sink
	if not self:_keyboard() then
		return pass -- gamepad and touch: Roblox's prompts
	end
	if inputState == Enum.UserInputState.Begin then
		if self.state:InRun() and (not self.state:IsActive() or self.state:IsTucked()) then
			self:_note("pass: not active")
			return pass -- (tucked away, E gets you out)
		end
		if Ui.modalOpen() then
			self:_note("pass: a screen is open")
			return pass
		end
		if self.carry then
			self:_drop(true) -- E puts down what you carry
			self:_note("put down")
			return sink
		end
		if self.drag or self.push then
			self:_note("busy")
			return sink
		end
		-- What you look at now, as you press (not last frame's).
		local focus = self:_resolveFocus()
		if not focus or not (focus.tap or focus.hold) then
			self:_note("nothing")
			return sink
		end
		local hit = self:_aim()
		local press = {
			at = os.clock(),
			focus = focus,
			tap = focus.tap,
			hold = focus.hold,
			near = hit and hit.Instance,
			at3 = hit and hit.Position,
		}
		if not focus.hold then
			-- Only a tap: at once.
			self:_doTap(press)
			return sink
		elseif not focus.tap then
			-- Only a hold: at once too.
			press.held = true
			if self:_doHold(press) then
				self.press = press
			end
			return sink
		end
		-- Both: a tap or a hold, as long as you keep it down (_update).
		self.press = press
		self:_note("press " .. focus.kind)
		return sink
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		local press = self.press
		if not press then
			return pass
		end
		self.press = nil
		if press.held then
			-- Let go, as letting go of the mouse button would.
			if press.prompt then
				press.prompt:InputHoldEnd()
			elseif self.drag then
				self:_finish()
			elseif self.push then
				self.push = nil
			end
			self:_note("let go")
		else
			self:_doTap(press)
		end
		return sink
	end
	return pass
end

-- Tools in hand (the owner's solo playtest, 2026-10-08): the crowbar or the
-- bolt cutters in your hands and the click (or R) held on the boards or the
-- chain you look at: you work at them till you let go or they give
-- (Services/LockService). `on` false lets go. Returns whether it was this.
function HandsController:ToolWork(on: boolean): boolean
	if not on then
		if self.working then
			self.working = nil
			Net.get("ToolWork"):FireServer(false, nil)
			return true
		end
		return false
	end
	if self.carry or self.drag or not self:_canFocus() then
		return false
	end
	-- What you look at now, as you press (not last frame's).
	local focus = self:_resolveFocus()
	local lock = focus and focus.toolLock
	if not lock or player:GetAttribute(PA.Tool) ~= lock.tool then
		self:_note("tool: " .. (focus and focus.kind or "no focus") .. (lock and " wrong tool" or " no lock"))
		return false
	end
	self:_note("tool: work " .. tostring(lock.id))
	self.working = lock.id
	Net.get("ToolWork"):FireServer(true, lock.id)
	return true
end

-- The tool a lock wants: its name, and whether you carry it (in a slot, not
-- your hands) or hold it.
function HandsController:ToolFor(lock): (string, string)
	local info = Tools.ById[lock.tool]
	local name = info and info.name or lock.tool
	if player:GetAttribute(PA.Tool) == lock.tool then
		return name, "held"
	end
	for i, attribute in PA.Slots do
		if player:GetAttribute(attribute) == lock.tool then
			return name, tostring(i)
		end
	end
	return name, "none"
end

function HandsController:_active(): boolean
	return self.state:InRun() and self.state:IsActive() and not self.state:IsTucked()
end

function HandsController:_begin(): boolean
	if not self:_active() or self.drag or self.carry then
		return false
	end
	local hit = self:_aim()
	if self:_thingOf(hit) then
		return self:_pickUp()
	end
	local primary = hit and self:_pieceOf(hit.Instance)
	if not hit or not primary then
		return self:_lean(hit)
	end
	return self:_takeHold(primary, hit.Position)
end

-- Take hold of a door, drawer or lid at `point` (on it).
function HandsController:_takeHold(primary: BasePart, point: Vector3): boolean
	local joint = Joint.read(primary)
	if not joint or self.drag or self.carry then
		return false
	end
	local value = math.clamp(Joint.valueOf(joint, primary.CFrame), 0, joint.max)
	-- Where you took hold of it, on the part, and where that point sits when
	-- it's shut (a door's angle is measured from there).
	local onPart = primary.CFrame:PointToObjectSpace(point)
	local grabShut = joint.shut:PointToWorldSpace(onPart) - joint.hinge
	-- A lid lifts along the arc its edge makes: how far that edge is from the hinge.
	local across = grabShut - joint.axis * grabShut:Dot(joint.axis)
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local forward = flat(look)
	-- Your hand holds its state in MotionController, which turns it at once.
	local state = self.controllers.MotionController:Hold(primary, value)
	if not state then
		return false
	end
	self.drag = {
		id = primary:GetAttribute(Constants.Attributes.CId),
		primary = primary,
		joint = joint,
		upright = Joint.upright(joint),
		onPart = onPart,
		grabShut = { x = grabShut.X, z = grabShut.Z },
		radius = math.max(0.5, across.Magnitude),
		hand = point,
		start = point,
		startValue = value,
		value = value,
		target = value,
		look = look,
		forward = forward.Magnitude > 1e-3 and forward.Unit or Vector3.new(0, 0, -1),
		state = state,
	}
	self.mouseDelta = Vector2.zero
	self.stick = Vector2.zero
	-- The right stick moves your hand instead of the view while you hold on.
	ContextActionService:BindActionAtPriority("ConsensusDragStick", function(_, _, input)
		self.stick = Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Thumbstick2)
	return true
end

-- Let go. It swings on at the speed your hand had (the server is told, and
-- its copy takes over as it comes). `stoppedAt` instead: the server stopped
-- it in your hands, at that value.
function HandsController:_finish(stoppedAt: number?)
	local drag = self.drag
	if not drag then
		return
	end
	self.drag = nil
	ContextActionService:UnbindAction("ConsensusDragStick")
	local motion = self.controllers.MotionController
	if stoppedAt then
		motion:Stop(drag.primary, stoppedAt)
		return
	end
	local velocity = drag.state.velocity
	motion:Release(drag.primary, velocity)
	if drag.primary.Parent then
		Net.get("DragRelease"):FireServer(drag.id, drag.state.target, velocity)
	end
end

-- Where your hand wants it: a door turns to point at your hand, a drawer
-- follows your hand straight out, a lid lifts as your hand moves away.
function HandsController:_target(drag, hand: Vector3): number
	local joint = drag.joint
	if drag.upright then
		local fromHinge = hand - joint.hinge
		return Articulation.hingeTarget(drag.state, drag.grabShut, { x = fromHinge.X, z = fromHinge.Z }, joint.sign)
	elseif joint.kind == "slide" then
		return Articulation.alongTarget(drag.state, drag.startValue, (hand - drag.start):Dot(joint.axis))
	end
	local away = (hand - drag.start):Dot(drag.forward)
	return Articulation.alongTarget(drag.state, drag.startValue, math.deg(away / drag.radius))
end

-- Pushing --------------------------------------------------------------------------

-- The piece of furniture this belongs to, if it can be pushed.
function HandsController:_pushableOf(instance: Instance): Model?
	local model = instance:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:GetAttribute("Grab") then
			return nil
		end
		if model:GetAttribute("Push") and model:GetAttribute(Constants.Attributes.CId) then
			return model
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- Lean on the furniture you're looking at, close enough to push.
function HandsController:_lean(hit: RaycastResult?): boolean
	local model = hit and hit.Distance <= P.Reach + 1.5 and self:_pushableOf(hit.Instance)
	if not model then
		return false
	end
	return self:_leanOn(model)
end

function HandsController:_leanOn(model: Model): boolean
	if self.drag or self.carry then
		return false
	end
	self.push = { id = model:GetAttribute(Constants.Attributes.CId), model = model, sentAt = 0 }
	return true
end

-- While you lean on it, say which way you walk.
function HandsController:_pushStep()
	local push = self.push
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not self:_active() or not push.model.Parent or not humanoid or not root then
		self.push = nil
		return
	end
	local box, size = push.model:GetBoundingBox()
	if (box.Position - root.Position).Magnitude > P.ReachHeld + size.Magnitude / 2 + 2 then
		self.push = nil
		return
	end
	local walking = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	local now = os.clock()
	if walking.Magnitude > 0.1 and now - push.sentAt >= 1 / P.SendHz then
		push.sentAt = now
		Net.get("Push"):FireServer(push.id, walking.Unit)
	end
end

function HandsController:_update(dt: number)
	-- E held past a tap: what holding it does (your hand takes hold, or a
	-- long prompt's hold begins).
	local press = self.press
	if press and not press.held and os.clock() - press.at >= H.TapSeconds then
		press.held = true
		if not self:_doHold(press) then
			self.press = nil
		end
	end
	if self.carry then
		self:_carryStep(dt)
	end
	if self.push then
		self:_pushStep()
	end
	local looking = not self.drag and not self.carry and not self.push and self:_active()
	self.focus = (not self.drag and not self.carry and not self.push and self:_canFocus()) and self:_resolveFocus()
		or nil
	if RunService:IsStudio() then
		-- What has your focus, for tests in Studio (the MCP can't see this table).
		local focus = self.focus
		local said = focus
				and string.format(
					"%s %s%s tap=%s hold=%s shown=%d",
					focus.kind,
					focus.object.Name,
					focus.object:GetAttribute("HideSpot") and " (hide)" or "",
					focus.tap and (focus.tap.kind .. ":" .. tostring(focus.tap.text)) or "-",
					focus.hold and (focus.hold.kind .. ":" .. tostring(focus.hold.text)) or "-",
					(function()
						local n = 0
						for _ in self.shown do
							n += 1
						end
						return n
					end)()
				)
			or "nothing"
		if said ~= self.saidFocus then
			self.saidFocus = said
			player:SetAttribute("DebugFocus", said)
		end
	end
	local hit = looking and self:_aim() or nil
	self.aimedThing = looking and self:_thingOf(hit) or nil
	self.aimedPush = (looking and not self.aimedThing and hit and hit.Distance <= P.Reach + 1.5)
			and self:_pushableOf(hit.Instance)
		or nil
	local drag = self.drag
	if not drag then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = camera.CFrame.Position
	if not self:_active() or not drag.primary.Parent or (drag.primary.Position - eye).Magnitude > H.DragReach + 1 then
		self:_finish()
		return
	end
	local sensitivity = H.DragSensitivity * math.clamp(GameSettings.MouseSensitivity, 0.2, 4)
	-- Hold the view still: the camera builds each frame from where it looked
	-- last, so putting its aim back here keeps it put without a jump later.
	camera.CFrame = CFrame.lookAt(eye, eye + drag.look)

	-- Move the hand.
	local forward = drag.forward
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local delta = self.mouseDelta
	self.mouseDelta = Vector2.zero
	local hand = drag.hand
		+ right * (delta.X * sensitivity + self.stick.X * H.DragStickSpeed * dt)
		+ forward * (-delta.Y * sensitivity + self.stick.Y * H.DragStickSpeed * dt)
	-- Something that won't follow (shut, against something) keeps your hand close.
	drag.value = drag.state.value
	local grabNow = Joint.pose(drag.joint, drag.value):PointToWorldSpace(drag.onPart)
	local reach = flat(hand - grabNow)
	if reach.Magnitude > H.DragStretch then
		hand = grabNow + reach.Unit * H.DragStretch + Vector3.new(0, hand.Y - grabNow.Y, 0)
	end
	drag.hand = hand
	local target = self:_target(drag, hand)
	-- A locked door only shifts in its frame (the server rattles it and says why).
	if drag.primary:GetAttribute("Locked") then
		target = math.min(target, drag.joint.latch)
	end
	drag.target = target
	Articulation.setTarget(drag.state, target)

	local now = os.clock()
	if now - self.sentAt >= 1 / H.DragSendHz then
		self.sentAt = now
		Net.get("Drag"):FireServer(drag.id, drag.target)
	end
end

-- Carrying ---------------------------------------------------------------------

-- Ask for the small thing you're looking at. The server says yes by marking
-- it HeldBy you and handing you its physics (_carryStep).
function HandsController:_pickUp(thing: Model?): boolean
	local model = thing or self:_thingOf(self:_aim())
	if not model or self.carry then
		return false
	end
	local carry = {
		id = model:GetAttribute("Grab"),
		model = model,
		class = Physical.Classes[model:GetAttribute("Class")] or Physical.Classes.medium,
		distance = H.CarryDistance[2],
		askedAt = os.clock(),
		owned = false,
		phase = 0,
	}
	self.carry = carry
	-- Reach for it now: the constraints wait on it, and take hold the moment
	-- the server unanchors it and hands it over, with no round trip of sag.
	self:_buildHold(carry)
	Net.get("Grab"):FireServer(carry.id)
	return true
end

-- The part everything is welded to: the biggest, as the server picks
-- (Services/HandsService.rootOf).
local function rootOf(model: Model): BasePart?
	local root, best = nil, -1
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local volume = p.Size.X * p.Size.Y * p.Size.Z
			if volume > best then
				root, best = p, volume
			end
		end
	end
	return root
end

function HandsController:_buildHold(carry)
	local model = carry.model
	local root = rootOf(model)
	if not root then
		return
	end
	local camera = Workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local heft = carry.class.carry
	-- Held by its middle, so a tall thing (a lamp, a mannequin) is held like
	-- one rather than by whichever part is biggest.
	local low, high = Util.verticalSpan(model)
	local middle = model:GetBoundingBox().Position
	carry.half = (high - low) / 2
	carry.root = root
	local attachment = Instance.new("Attachment")
	attachment.Name = "HandGrip"
	attachment.Parent = root
	attachment.Position = root.CFrame:PointToObjectSpace(Vector3.new(middle.X, (low + high) / 2, middle.Z))
	-- Mass is worked out from the class's density and the parts' sizes, the
	-- same as the server sets them on the first grab.
	local mass = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			mass += p.Size.X * p.Size.Y * p.Size.Z * carry.class.density
		end
	end
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = mass * Workspace.Gravity * heft.forceG + 200
	align.MaxVelocity = heft.maxSpeed
	align.Responsiveness = 200
	align.Position = root.Position
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = mass * 4000 + 2000
	orient.Responsiveness = heft.omega * 1.2
	orient.CFrame = root.CFrame.Rotation
	orient.Parent = root
	carry.attachment, carry.align, carry.orient = attachment, align, orient
	-- Keep the way it was lying, relative to where you face.
	carry.turn = CFrame.Angles(0, -yaw, 0) * root.CFrame.Rotation
	-- The hold point starts where it lies and swings up into your hands.
	carry.holdPos = attachment.WorldPosition
	carry.holdVel = Vector3.zero
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

-- Throw what you carry, wound up for `held` seconds. This client launches it
-- (it owns it) from exactly where and how it was moving, and tells the
-- server, which checks the launch.
function HandsController:_throw(held: number)
	local carry = self.carry
	if not carry then
		return
	end
	local root = carry.root
	local camera = Workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local class = carry.class
	local charge = Throw.charge(held, H)
	local body = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local velocity = look * class.throwSpeed * charge + Vector3.new(0, class.throwSpeed * charge * H.ThrowLift, 0)
	if root then
		velocity += root.AssemblyLinearVelocity * H.ThrowCarry
	end
	if body then
		velocity += body.AssemblyLinearVelocity * H.ThrowCarry
	end
	self:_cleanCarry()
	if root and root.Parent and not root.Anchored then
		root.AssemblyLinearVelocity = velocity
		-- It tumbles end over end along the throw, less the heavier it is.
		root.AssemblyAngularVelocity = look:Cross(Vector3.yAxis) * (6 / class.density)
		ThrowLift.add(root, H)
	end
	Net.get("Throw"):FireServer(look, charge, root and root.Position or nil, velocity)
	-- A full throw kicks the view out a little (behind Camera motion).
	local feel = self.controllers.FeelController
	if feel and feel.Kick then
		feel:Kick(H.ThrowKick * charge)
	end
end

-- Keep what you carry in front of you, following your eye with its weight.
function HandsController:_carryStep(dt: number)
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
	if not carry.align or not carry.root or not carry.root.Parent then
		self:_cleanCarry()
		return
	end
	carry.owned = true
	local camera = Workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	-- In front of your eye, but never pushed into a wall or a shelf.
	local eye = camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, camera, model }
	local distance = carry.distance
	-- Winding up draws it back towards you.
	if carry.windingSince then
		local wound = math.clamp((os.clock() - carry.windingSince) / H.ChargeFull, 0, 1)
		distance = math.max(H.CarryDistance[1] - 0.4, distance - H.WindPull * wound)
	end
	local hit = Workspace:Raycast(eye, look * (distance + 0.5), params)
	if hit then
		distance = math.max(0.8, hit.Distance - 0.7)
	end
	local hold = eye + look * distance - Vector3.new(0, 0.35, 0)
	-- Something big (a lamp, a plant) is held off to one side, so you can see past it.
	if carry.class == Physical.Classes.bulky then
		hold += camera.CFrame.RightVector * H.BulkySide
	end
	-- Never pushed into the floor: its bottom stays a little above your feet.
	local body = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local heft = carry.class.carry
	if body and humanoid then
		-- Something big bobs with your stride.
		local walking = Vector3.new(body.AssemblyLinearVelocity.X, 0, body.AssemblyLinearVelocity.Z).Magnitude
		carry.phase += dt * walking * 0.9
		hold += Vector3.new(0, Heft.bob(carry.phase, walking, heft.bob), 0)
		local feet = body.Position.Y - body.Size.Y / 2 - humanoid.HipHeight
		hold = Vector3.new(hold.X, math.max(hold.Y, feet + carry.half + 0.3), hold.Z)
	end
	-- The hold point follows through a spring: light things keep up, heavy
	-- ones trail behind a quick turn and settle without wobbling.
	carry.holdPos, carry.holdVel = Heft.spring(carry.holdPos, carry.holdVel, hold, heft.omega, dt)
	carry.align.Position = carry.holdPos
	-- It leans the way it's swung.
	local swing = camera.CFrame:VectorToObjectSpace(carry.holdVel)
	local lean = CFrame.Angles(Heft.lean(-swing.Y, heft.tilt * 0.6), 0, Heft.lean(swing.X, heft.tilt))
	carry.orient.CFrame = CFrame.Angles(0, yaw, 0) * lean * carry.turn
end

-- Holding a door, carrying something or pushing right now.
function HandsController:IsHolding(): boolean
	return self.drag ~= nil or self.carry ~= nil or self.push ~= nil
end

-- The furniture you could push where you look, or are pushing (FocusMarkers).
function HandsController:AimedPushable(): Model?
	return self.push and self.push.model or self.aimedPush
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
		return "nothing within reach to take hold of where you're looking"
	end
	local drag = self.drag
	if not drag then
		return "picked up what you're looking at instead"
	end
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
