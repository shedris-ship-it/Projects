-- Faces that react (hair and faces, 2026-10-17; docs/progress/
-- 2026-10-17-hair-faces/). Everyone's face is one of Roblox's dynamic heads
-- (Data/Wardrobe Face): blinking and moving with voice chat are Roblox's
-- own. In a run, every client also sets each player's FaceControls from what
-- it already knows about them (Logic/FacePose, Config.Face): downed, a
-- wince; holding their breath, eyes screwed shut (PA.HoldingBreath); a hunt,
-- or The Guest near them, scared. Your own face isn't seen in first person;
-- in the takedown's shots it is.
--
-- Written each frame after the Animator, as Controllers/PoseController
-- writes the joints, and only what a pose sets: a property is set back to
-- rest once when its pose lets go, then left to Roblox's animation again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local FacePose = require(Shared.Logic.FacePose)

local PA = Constants.PlayerAttributes

local FaceController = {}

function FaceController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.weights = setmetatable({}, { __mode = "k" }) -- FaceControls -> its poses' weights
	self.last = setmetatable({}, { __mode = "k" }) -- FaceControls -> what was set on it last frame
end

-- Where The Guest is drawn on this client, or nil.
function FaceController:_guestAt(): Vector3?
	local guest = self.controllers.GuestController
	local model = guest and guest:Model()
	local root = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	return root and root.Position or nil
end

function FaceController:_frame(dt: number)
	local inRun = self.state:InRun()
	local hunting = inRun and self.state:Run(Constants.RunState.Hunting) == true
	local guestAt = inRun and self:_guestAt() or nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local face = head and head:FindFirstChildOfClass("FaceControls")
		if not face then
			continue
		end
		local near = guestAt ~= nil and (head :: BasePart).Position - guestAt
		-- (F2 `face <pose>` holds one: DebugService.)
		local target = player:GetAttribute("DebugFace")
			or FacePose.target({
				downed = player:GetAttribute(PA.State) == Constants.PlayerStates.Downed,
				holding = player:GetAttribute(PA.HoldingBreath) == true,
				scared = hunting or (near and near.Magnitude <= Config.Face.ScaredRange) or false,
			})
		local weights = self.weights[face]
		if not weights and not target then
			continue
		end
		weights = FacePose.step(weights or {}, target, dt, Config.Face.Ease)
		local values = FacePose.values(weights, Config.Face.Poses)
		local last = self.last[face] or {}
		for prop, v in values do
			(face :: any)[prop] = v
		end
		for prop in last do
			if values[prop] == nil then
				(face :: any)[prop] = 0
			end
		end
		self.weights[face] = next(weights) and weights or nil
		self.last[face] = next(values) and values or nil
	end
end

function FaceController:Start()
	RunService.Stepped:Connect(function(_, dt)
		local ok, err = pcall(self._frame, self, dt)
		if not ok then
			warn("[Consensus] faces failed: " .. tostring(err))
		end
	end)
end

return FaceController
