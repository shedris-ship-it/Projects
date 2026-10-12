-- Your own body in first person (the owner, 2026-10-12, after IT WANTS IN:
-- "you can see your body in first person, I think that it makes it feel more
-- grounded and compliments the horror atmosphere"; docs/plans/gameplay-rework.md
-- section 20). Roblox hides your whole character while the camera is in your
-- head; this shows what's below the waist again every frame (Config.Body.Show),
-- so looking down there are your legs and feet, walking, crouching or kneeling
-- (Controllers/PoseController), lit by your torch. Head and arms stay hidden:
-- the arms on screen are the view model's, which hold what you hold
-- (Controllers/ViewModelController). Your whole body casts its shadow, so a
-- lamp behind you throws you across the floor ahead.
--
-- Roblox's own camera only rewrites these when its idea of how see-through you
-- are changes, so everything is set here, every frame, while you look out of
-- your own eyes in the house, and handed back once when you don't.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer

local SHOW = {}
for _, name in Config.Body.Show do
	SHOW[name] = true
end

local BodyController = {}

function BodyController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
	self.managing = nil -- the character whose parts this last set
end

-- Your legs are there to see: on your feet in the house, not hidden away
-- under something, and not turned off in Settings.
function BodyController:LegsShown(): boolean
	return self.state:IsActive() and not self.state:IsTucked() and self.state.settings.hideBody ~= true
end

function BodyController:_set(character: Model, legs: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local want = (legs and SHOW[d.Name]) and 0 or 1
			if d.LocalTransparencyModifier ~= want then
				d.LocalTransparencyModifier = want
			end
			-- (The old rule hid your body's shadow in first person, when the beam
			-- left from beside your eye; it leaves from the torch's lens now.)
			if not d.CastShadow and d.Transparency < 1 then
				d.CastShadow = true
			end
		end
	end
end

function BodyController:_update()
	local character = player.Character
	-- (Tucked under a bed or behind a curtain the camera is ours, not Roblox's,
	-- and nothing of you shows: everything stays hidden.)
	local inHead = character ~= nil and self.state:InRun() and player.CameraMode == Enum.CameraMode.LockFirstPerson
	if inHead then
		self:_set(character :: Model, self:LegsShown())
		self.managing = character
	elseif self.managing then
		-- Out of your head (the hub, an Echo, the run over): Roblox's camera has it back.
		if self.managing.Parent then
			for _, d in self.managing:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		self.managing = nil
	end
end

function BodyController:Start()
	-- After the camera script (which hides you in first person) and before the
	-- view model.
	RunService:BindToRenderStep("ConsensusBody", Enum.RenderPriority.Camera.Value + 2, function()
		local ok, err = pcall(self._update, self)
		if not ok then
			warn("[Consensus] body update failed: " .. tostring(err))
		end
	end)
end

return BodyController
