-- What drawers and cupboards hold when the run keeps nothing of its own there
-- (the owner's playtest, 2026-10-11: "Useless items kinda suck"). Data/Finds
-- lists them; Logic/Finds picks one, keeping each kind to its limit a run.
-- Most do something when you look at one and press E (its prompt; the mouse
-- still picks it up to throw):
--   batteries    a share of your torch back (PlayerStateService:AddBattery)
--   painkillers  one of your downs forgiven (PlayerStateService:ForgiveDown)
--   letters      a line that points at what the run wants next (Logic/
--                Assist through FinaleService:Lead); the map rings that room
--   matches      pocketed: a lantern shrine lights at once with one
--                (ToolService's shrine prompt spends them)
-- The rest are for throwing: a lure, and a hit stuns him.
-- Something that wouldn't help you now (a full torch, no downs) stays put
-- for someone it would.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local FindData = require(Shared.Data.Finds)
local Finds = require(Shared.Logic.Finds)
local Net = require(Shared.Net)
local Physical = require(Shared.Data.Physical)
local Sfx = require(Shared.Lib.Sfx)

local Junk = require(script.Parent.Parent.World.Junk)

local PA = Constants.PlayerAttributes
local C = Config.Finds

local FindService = {}

function FindService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.Hands = services.HandsService
	self.counts = {} -- name -> how many this run
	self.count = 0
end

function FindService:Start()
	self.World.Cleared:Connect(function()
		table.clear(self.counts)
		for _, player in Players:GetPlayers() do
			player:SetAttribute(PA.Matches, nil)
		end
	end)
end

local function notify(player: Player, text: string, kind: string?)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

-- A find for a drawer or cupboard opened for the first time, lying at `at`
-- (its model), or nil when the house has run out of every kind.
function FindService:Fill(at: CFrame, rng): Model?
	local squad = math.max(1, #self.PlayerState:RunPlayers())
	local entry = Finds.pick(FindData, rng, self.counts, squad)
	if not entry then
		return nil
	end
	self.counts[entry.name] = (self.counts[entry.name] or 0) + 1
	return self:Make(entry.name, at)
end

-- Build one by name (World/Junk) with its use, if it has one.
function FindService:Make(name: string, at: CFrame): Model
	local model = Junk.build(name, at, self.World.content)
	local entry = Finds.byName(FindData, name)
	if entry and entry.use then
		self:_prompt(model, entry)
	end
	return model
end

function FindService:_prompt(model: Model, entry)
	local part = model:FindFirstChildWhichIsA("BasePart")
	if not part then
		return
	end
	self.count += 1
	model:SetAttribute("FindId", self.count)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UsePrompt"
	prompt.ActionText = entry.use
	local info = Physical.Dressing[model.Name]
	prompt.ObjectText = info and info.label or model.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = C.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		self:_use(player, model, entry)
	end)
end

-- Someone pressed E on it: if it helps them now, it's spent.
function FindService:_use(player: Player, model: Model, entry)
	if not model.Parent or not self.PlayerState:CanAct(player) then
		return
	end
	local position = model:GetPivot().Position
	local from = self.PlayerState:Position(player)
	if not from or (from - position).Magnitude > C.Reach + 2 then
		return
	end
	local id = model:GetAttribute("Grab")
	local thing = id and self.Hands.things[id]
	if thing and thing.holder and thing.holder ~= player then
		return
	end
	local spent = false
	if entry.effect == "battery" then
		if self.PlayerState:AddBattery(player, C.BatteryShare) then
			spent = true
			Sfx.play("FlashlightClick", position, 0.5, 0.9)
			notify(player, "Fresh batteries in your torch.", "good")
		else
			notify(player, "Your torch is full. Leave them for someone.")
		end
	elseif entry.effect == "mend" then
		local downs = self.PlayerState:ForgiveDown(player)
		if downs then
			spent = true
			Sfx.play("Cloth", position, 0.35, 1.5)
			local cap = self.PlayerState:DownsCap()
			notify(
				player,
				string.format("Two tablets, dry. The ache dulls: one down forgiven (%d of %d now).", downs, cap),
				"good"
			)
		else
			notify(player, "You don't need these yet. They'll keep.")
		end
	elseif entry.effect == "lead" then
		self:_read(player, model)
	elseif entry.effect == "matches" then
		spent = true
		local matches = (player:GetAttribute(PA.Matches) or 0) + C.MatchesPerBox
		player:SetAttribute(PA.Matches, matches)
		Sfx.play("Cloth", position, 0.3, 1.6)
		notify(
			player,
			string.format("%d matches in your pocket: a lantern shrine lights at once with one.", matches),
			"good"
		)
	end
	if spent then
		if thing then
			self.Hands:Forget(thing, true)
		else
			model:Destroy()
		end
	end
end

-- Letters: what's in them is decided the first time anyone reads them (the
-- run's next step then), and stays what they say after.
function FindService:_read(player: Player, model: Model)
	local text = model:GetAttribute("LeadText")
	if typeof(text) ~= "string" then
		local finale = self.services.FinaleService
		local line = finale and finale:Lead()
		if line then
			text = 'Old letters, tied with twine. Someone went through them before you, and pencilled a note to themself on the last one:\n\n"'
				.. line
				.. '"'
		else
			text =
				"Old letters, tied with twine: bills, a birthday card, a postcard from the coast. Nothing in them helps."
		end
		model:SetAttribute("LeadText", text)
	end
	Sfx.play("Cloth", model:GetPivot().Position, 0.3, 1.3)
	Net.get("NoteText"):FireClient(player, { id = "letters:" .. tostring(model:GetAttribute("FindId")), text = text })
end

-- F2 `find <name>`: one in front of you.
function FindService:DebugMake(player: Player, name: string?): string
	local root = self.PlayerState:Root(player)
	if not root then
		return "no character"
	end
	local entry = nil
	for _, e in FindData do
		if name and string.lower(e.name) == string.lower(name) then
			entry = e
		end
	end
	if not entry then
		local names = {}
		for _, e in FindData do
			table.insert(names, e.name)
		end
		return "find <" .. table.concat(names, "|") .. ">"
	end
	local look = root.CFrame.LookVector
	local spot = root.Position + Vector3.new(look.X, 0, look.Z).Unit * 3 - Vector3.new(0, 2.9, 0)
	local model = self:Make(entry.name, CFrame.new(spot))
	self.Hands:AddThing(model, Physical.Dressing[model.Name])
	return entry.name .. " in front of you"
end

return FindService
