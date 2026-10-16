-- Everyone else's torch, in their hand (LB4; docs/plans/lobby-rework.md,
-- "Electronics": the torch's looks are seen by the squad). Until then the
-- squad saw only another's beam. While a player's torch is up (PA.TorchUp),
-- this client puts their look of it (PA.TorchLook, World/ToolModel) in their
-- left hand, its lens lit with their beam (PA.Flashlight); PoseController
-- raises the arm. Cosmetic and client-side: the beam itself is the server's.
-- Yours is your view model's (Controllers/ViewModelController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local ToolModel = require(Shared.World.ToolModel)

local PA = Constants.PlayerAttributes
local P = Config.Pose

local HeldTorchController = {}

function HeldTorchController:Init(controllers)
	self.controllers = controllers
	self.held = {} -- player -> { model, look, character, meshes }
end

-- Its parts follow the hand: welded, nothing anchored, nothing to collide.
local function attach(model: Model, hand: BasePart)
	local pivot = model.PrimaryPart :: BasePart
	local i = P.TorchInHand
	-- The torch's front (-z) along the hand's -y: down the raised arm.
	model:PivotTo(hand.CFrame * CFrame.new(i[1], i[2], i[3]) * CFrame.Angles(math.rad(-90), 0, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if part ~= pivot then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = pivot
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = pivot
	weld.Parent = pivot
end

function HeldTorchController:_drop(player: Player)
	local held = self.held[player]
	if held then
		held.model:Destroy()
		self.held[player] = nil
	end
end

function HeldTorchController:_frame()
	local kit = ReplicatedStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	local count = meshes and #meshes:GetChildren() or 0
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		local character = player.Character
		local hand = character and character:FindFirstChild("LeftHand") :: BasePart?
		local up = hand ~= nil and player:GetAttribute(PA.TorchUp) == true and not player:GetAttribute(PA.Hidden)
		local look = player:GetAttribute(PA.TorchLook)
		local held = self.held[player]
		if held and (not up or held.look ~= look or held.character ~= character or held.meshes ~= count) then
			self:_drop(player)
			held = nil
		end
		if up and not held then
			local model = ToolModel.torch(look)
			model.Name = "HeldTorch"
			attach(model, hand :: BasePart)
			model.Parent = character
			held = { model = model, look = look, character = character, meshes = count }
			self.held[player] = held
		end
		if held then
			ToolModel.setTorchOn(held.model, player:GetAttribute(PA.Flashlight) == true)
		end
	end
end

function HeldTorchController:Start()
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(self._frame, self)
		if not ok then
			warn("[Consensus] held torch failed: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_drop(player)
	end)
end

return HeldTorchController
