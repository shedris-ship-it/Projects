-- Teaching in the house (the owner's audit of 2026-10-06, Finding 5: an
-- eight-bullet how-to taught nothing). One short tip at a time, when the
-- thing it teaches first comes up: your hands, the map, a locked door's
-- mark, your first key, the first time he shows himself, the first hunt, a
-- dying torch, your beam holding him. Each shows once a session, never two
-- within twenty seconds, and the "Show tips" setting turns them off.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local PA = Constants.PlayerAttributes
local RS = Constants.RunState

local player = Players.LocalPlayer

-- A Lantern shrine within a few strides, or the Lantern tool in a slot.
local function lanternNear(): boolean
	for _, slot in { "Slot2", "Slot3" } do
		if player:GetAttribute(slot) == "Lantern" then
			return true
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, glass in CollectionService:GetTagged(Constants.Tags.LanternShrine) do
		if glass:IsA("BasePart") and (glass.Position - root.Position).Magnitude < 14 then
			return true
		end
	end
	return false
end

-- The piano's music box within a few strides (server/Puzzles/MusicBox).
local function musicBoxNear(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, box in CollectionService:GetTagged("ConsensusMusicBox") do
		local part = box:IsA("Model") and box.PrimaryPart
		if part and (part.Position - root.Position).Magnitude < 12 then
			return true
		end
	end
	return false
end

local Tips = {}
Tips.__index = Tips

local GAP = 20 -- seconds between tips

-- Each tip: when (a function of the state that says it's time), what.
local TIPS = {
	{
		id = "hands",
		text = "E opens a door or a drawer and picks small things up; hold E (or the mouse) to swing, pull or push. Carrying: click throws, E puts down. The family's keys are in the drawers.",
		when = function(self)
			return self:_runTime() >= 12
		end,
	},
	{
		id = "map",
		text = "Tab opens the map. It only shows what your squad has seen.",
		when = function(self)
			return self:_runTime() >= 50
		end,
	},
	{
		id = "locked",
		text = "Every locked door wears a mark on its plaque. The key with the same mark opens it: say the mark aloud.",
		when = function(self)
			local line = self.state:Run(RS.Objective)
			return type(line) == "string"
				and (string.find(line, "is locked", 1, true) or string.find(line, "has a padlock", 1, true)) ~= nil
		end,
	},
	{
		id = "key",
		text = "A key goes on your ring (bottom left). Its door wears the same mark.",
		when = function()
			local keys = player:GetAttribute(PA.Keys)
			return type(keys) == "string" and keys ~= ""
		end,
	},
	-- The squad playtest (2026-10-10): a tester never knew the table wanted it.
	{
		id = "heirloom",
		text = "Something of the family's. Carry it to the dining table: a card at one of the empty places names it, and it's set as you walk up.",
		when = function(self)
			local hands = self.ctx.controllers.HandsController
			local carry = hands and hands.carry
			local model = carry and carry.model
			return model ~= nil and model.Name == "Heirloom"
		end,
		urgent = true,
	},
	{
		id = "guest",
		text = "Something is watching you. Two of you looking at it in the light stop it. Alone, your beam does, while the battery lasts.",
		when = function(self)
			return self.seenGuest
		end,
	},
	{
		id = "hunt",
		text = "It's coming. Hide (shut yourself in a wardrobe, a locker or a closet, or E under a bed) or run and break its line of sight. Staring holds it a few seconds, no more.",
		when = function(self)
			return self.huntTelegraphed
		end,
		urgent = true,
	},
	{
		id = "beam",
		text = "Your light is holding it. The battery pays for every second.",
		when = function()
			return player:GetAttribute(PA.BeamHold) == true
		end,
		urgent = true,
	},
	{
		id = "lantern",
		text = "A Lantern shrine: hold E to light it. A lit Lantern room recharges your torch, and he can't start a hunt on you there.",
		when = lanternNear,
	},
	-- The squad playtest (2026-10-08): nobody knew the piano was a puzzle.
	{
		id = "musicbox",
		text = "A music box. Hold E to wind it: each note lights a coloured tooth on its comb. Remember the colours; something in this house wants that tune.",
		when = musicBoxNear,
	},
	{
		id = "piano",
		text = "The piano is shut on something. Play it the music box's tune: its keys wear the same colours as the comb's teeth.",
		when = function(self)
			local line = self.state:Run(RS.Objective)
			return type(line) == "string" and string.find(line, "piano", 1, true) ~= nil
		end,
	},
	{
		id = "battery",
		text = "Your torch is going. Clip it (any slot but 1) to spare it; a lit Lantern room recharges it; the safe room keeps batteries.",
		when = function()
			local battery = player:GetAttribute(PA.Battery)
			return type(battery) == "number" and battery < 0.6
		end,
	},
}

function Tips.new(ctx)
	local self = setmetatable({
		ctx = ctx,
		state = ctx.state,
		shown = {},
		lastAt = -math.huge,
		seenGuest = false,
		huntTelegraphed = false,
		hunting = false,
		elapsed = 0,
	}, Tips)
	Net.get("StalkerVisibility").OnClientEvent:Connect(function(visible)
		if visible == true and self.state:InRun() then
			self.seenGuest = true
		end
	end)
	Net.get("HuntState").OnClientEvent:Connect(function(payload)
		if payload.state == "telegraph" then
			self.huntTelegraphed = true
			self.hunting = true
		elseif payload.state == "end" then
			self.hunting = false
		end
	end)
	self.state.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Generating" then
			-- A new run teaches again only what hasn't been shown this session.
			self.seenGuest, self.huntTelegraphed, self.hunting = false, false, false
		end
	end)
	return self
end

function Tips:_runTime(): number
	return self.state:Run(RS.RunTime) or 0
end

function Tips:Update(dt: number)
	self.elapsed += dt
	if self.elapsed < 0.5 then
		return
	end
	self.elapsed = 0
	if not self.state:InRun() or self.state.settings.tips == false then
		return
	end
	if self.state:PlayerState() ~= Constants.PlayerStates.Active then
		return
	end
	local now = os.clock()
	for _, tip in TIPS do
		if
			not self.shown[tip.id]
			and (tip.urgent or not self.hunting)
			and now - self.lastAt >= (tip.urgent and 4 or GAP)
		then
			local ok, due = pcall(tip.when, self)
			if ok and due then
				self.shown[tip.id] = true
				self.lastAt = now
				self.ctx.ui:Toast(tip.text, "tip")
				return
			end
		end
	end
end

return Tips
