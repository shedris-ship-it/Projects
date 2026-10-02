-- The shared Case Board (doc sections 2 and 3). Anchored or photographed tell
-- sites are pinned as confirmed (or debunked, for red herrings); a lone
-- Witness's observation is pinned as an unconfirmed claim. The board narrows
-- the 12 anomalies by elimination. It is mirrored on a physical corkboard in
-- the Foyer and in each client's Case File.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anomalies = require(Shared.Data.Anomalies)
local Tells = require(Shared.Data.Tells)
local CaseBoard = require(Shared.Logic.CaseBoard)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)

local CaseBoardService = {
	Changed = Signal.new(),
}

function CaseBoardService:Init(services)
	self.services = services
	self.Drift = services.DriftService
	self:Reset()
end

function CaseBoardService:Reset()
	self.pins = {} -- siteId -> { tellId, status, by = {names}, room }
	self.confirmedCount = 0
end

function CaseBoardService:Start()
	self.services.WorldService.Built:Connect(function(world)
		self.boardPart = world.caseBoardPart
		self:_renderBoard()
	end)
end

function CaseBoardService:ConfirmedTells(): { string }
	local list, seen = {}, {}
	for _, pin in self.pins do
		if pin.status == "confirmed" and not seen[pin.tellId] then
			seen[pin.tellId] = true
			table.insert(list, pin.tellId)
		end
	end
	table.sort(list)
	return list
end

function CaseBoardService:ClaimedTells(): { string }
	local list, seen = {}, {}
	for _, pin in self.pins do
		if pin.status == "claimed" and not seen[pin.tellId] then
			seen[pin.tellId] = true
			table.insert(list, pin.tellId)
		end
	end
	table.sort(list)
	return list
end

function CaseBoardService:Suspects(): { string }
	return CaseBoard.suspects(Anomalies.List, self:ConfirmedTells())
end

local function addName(pin, name)
	if name and not table.find(pin.by, name) then
		table.insert(pin.by, name)
	end
end

-- A tell site was anchored or photographed. Returns "confirmed" or "debunked".
function CaseBoardService:Resolve(site, names: { string }, viaCamera: boolean?): string
	local pin = self.pins[site.id]
	local status = site.isRedHerring and "debunked" or "confirmed"
	if pin and pin.status == status then
		for _, name in names do
			addName(pin, name)
		end
		return status
	end
	pin = pin or { tellId = site.tellId, by = {}, room = site.roomName }
	pin.status = status
	pin.camera = viaCamera
	for _, name in names do
		addName(pin, name)
	end
	self.pins[site.id] = pin
	if status == "confirmed" then
		self.confirmedCount += 1
		self.Drift:Apply(viaCamera and "EvidencePhotographed" or "EvidenceConfirmed")
		ReplicatedStorage.RunState:SetAttribute(Constants.RunState.ConfirmedCount, self.confirmedCount)
	end
	local text = status == "confirmed" and ("Evidence confirmed: " .. Tells[site.tellId].name)
		or ("Debunked: " .. Tells[site.tellId].name .. " was nothing. The house was lying to one of you.")
	Net.get("Notify"):FireAllClients(text, status == "confirmed" and "good" or "info")
	self:Broadcast()
	return status
end

-- A Witness noticed a tell alone. It goes on the board as a claim.
function CaseBoardService:Claim(site, player: Player)
	local pin = self.pins[site.id]
	if pin and pin.status ~= "claimed" then
		return
	end
	if not pin then
		pin = { tellId = site.tellId, status = "claimed", by = {}, room = site.roomName }
		self.pins[site.id] = pin
	end
	addName(pin, player.DisplayName)
	Net.get("Notify")
		:FireClient(player, "You noted: " .. Tells[site.tellId].name .. ". Get a second Witness to confirm it.", "info")
	self:Broadcast()
end

function CaseBoardService:Snapshot()
	local entries = {}
	for siteId, pin in self.pins do
		table.insert(entries, {
			site = siteId,
			tellId = pin.tellId,
			name = Tells[pin.tellId].name,
			notice = Tells[pin.tellId].notice,
			status = pin.status,
			by = pin.by,
			room = pin.room,
			camera = pin.camera,
		})
	end
	table.sort(entries, function(a, b)
		return a.site < b.site
	end)
	return {
		entries = entries,
		confirmed = self:ConfirmedTells(),
		claimed = self:ClaimedTells(),
		suspects = self:Suspects(),
	}
end

function CaseBoardService:Broadcast(player: Player?)
	local snapshot = self:Snapshot()
	if player then
		Net.get("CaseBoard"):FireClient(player, snapshot)
	else
		Net.get("CaseBoard"):FireAllClients(snapshot)
	end
	self:_renderBoard()
	self.Changed:Fire(snapshot)
end

-- The physical corkboard in the Foyer (diegetic UI, doc section 8).
function CaseBoardService:_renderBoard()
	local part = self.boardPart
	if not part or not part.Parent then
		return
	end
	local gui = part:FindFirstChild("BoardGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.8
		gui.Parent = part
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0.14, 0)
		title.Font = Enum.Font.SpecialElite
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(40, 24, 16)
		title.Text = "CASE BOARD"
		title.Parent = gui
		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.new(0.04, 0, 0.15, 0)
		body.Size = UDim2.new(0.92, 0, 0.83, 0)
		body.Font = Enum.Font.SpecialElite
		body.TextScaled = true
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextColor3 = Color3.fromRGB(30, 20, 14)
		body.Parent = gui
	end
	local lines = {}
	for _, entry in self:Snapshot().entries do
		local mark = entry.status == "confirmed" and "✔" or entry.status == "debunked" and "✘" or "?"
		table.insert(lines, mark .. " " .. entry.name)
	end
	local suspects = self:Suspects()
	local names = {}
	for _, id in suspects do
		table.insert(names, Anomalies.ById[id].name)
	end
	if #lines == 0 then
		table.insert(lines, "Nothing pinned yet. Witness what's wrong, together.")
	end
	table.insert(lines, "")
	table.insert(
		lines,
		#suspects == #Anomalies.List and "Suspects: all 12" or ("Suspects: " .. table.concat(names, ", "))
	)
	gui.Body.Text = table.concat(lines, "\n")
end

return CaseBoardService
