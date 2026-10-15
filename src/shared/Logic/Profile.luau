-- A player's saved profile: its shape, its upgrades, and the purchases on it
-- (Services/DataService saves it; Services/MonetizationService grants into
-- it). Version 2 (the lobby rework's LB0, docs/plans/lobby-rework.md, "Data")
-- adds what the lobby's shops will need: what you own and wear, arcade
-- credits and tickets, the starter pack, and the receipts that make every
-- purchase count once.

local Profile = {}

Profile.Version = 2

-- Receipts kept (the newest): Roblox asks again about a purchase until it's
-- granted, and only ever about recent ones.
Profile.MaxReceipts = 50

local TEMPLATE = {
	Version = Profile.Version,
	Marks = 0,
	Xp = 0,
	RunsPlayed = 0,
	Wins = 0,
	Extractions = 0,
	Settings = {},
	Dossier = {}, -- discovered anomaly and stalker entries
	-- Version 2 (LB0):
	Owned = {}, -- [kind] = { [id] = true }: garments, torch looks, car bits, frames
	Wearing = {}, -- [slot] = id: top, bottom, shoes, torch
	ArcadeCredits = 0, -- arcade plays bought (the unlimited pass needs none)
	Tickets = 0, -- the arcade's prize counter (none given until it opens)
	StarterPack = false, -- bought once
	Receipts = {}, -- recent purchase ids, oldest first
}

-- Versioned upgrades: add a step whenever the saved shape changes. A step
-- takes a profile of that version and returns the next one's. Fields new to
-- a version come from TEMPLATE, so a step only moves or reshapes old data.
local MIGRATIONS = {
	[1] = function(data)
		-- 1 -> 2: only new fields (TEMPLATE fills them in).
		return data
	end,
}

local function clampNumber(value, high: number): number
	value = tonumber(value) or 0
	if value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, high)
end

-- A profile in the current shape: missing fields filled, old versions
-- upgraded, anything a bad write could have pushed out of range clamped.
function Profile.reconcile(data)
	data = type(data) == "table" and data or {}
	for key, value in TEMPLATE do
		if data[key] == nil then
			data[key] = type(value) == "table" and {} or value
		end
	end
	local version = tonumber(data.Version) or Profile.Version
	while version < Profile.Version do
		local step = MIGRATIONS[version]
		if step then
			data = step(data)
		end
		version += 1
	end
	data.Version = Profile.Version
	data.Marks = clampNumber(data.Marks, 1e9)
	data.Xp = clampNumber(data.Xp, 1e9)
	data.ArcadeCredits = clampNumber(data.ArcadeCredits, 1e6)
	data.Tickets = clampNumber(data.Tickets, 1e9)
	data.StarterPack = data.StarterPack == true
	for _, key in { "Owned", "Wearing", "Settings", "Dossier" } do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	local receipts = {}
	if type(data.Receipts) == "table" then
		for _, id in data.Receipts do
			if type(id) == "string" then
				table.insert(receipts, id)
			end
		end
	end
	while #receipts > Profile.MaxReceipts do
		table.remove(receipts, 1)
	end
	data.Receipts = receipts
	return data
end

function Profile.new()
	return Profile.reconcile({})
end

function Profile.hasReceipt(data, purchaseId: string): boolean
	return table.find(data.Receipts, purchaseId) ~= nil
end

-- Applies a Robux purchase once: its grant and its receipt together.
-- grant = { marks = n?, arcadeCredits = n?, starterPack = true? }. Marks
-- bought never add Clearance XP (the plan's "Marks"). Returns whether
-- anything was applied (false when the receipt was already there) and a
-- function that takes it all back, for when the save that should keep it
-- fails.
function Profile.applyPurchase(data, purchaseId: string, grant): (boolean, () -> ())
	if Profile.hasReceipt(data, purchaseId) then
		return false, function() end
	end
	local before = {
		Marks = data.Marks,
		ArcadeCredits = data.ArcadeCredits,
		StarterPack = data.StarterPack,
		Receipts = table.clone(data.Receipts),
	}
	if type(grant.marks) == "number" and grant.marks > 0 then
		data.Marks = math.min(data.Marks + math.floor(grant.marks), 1e9)
	end
	if type(grant.arcadeCredits) == "number" and grant.arcadeCredits > 0 then
		data.ArcadeCredits = math.min(data.ArcadeCredits + math.floor(grant.arcadeCredits), 1e6)
	end
	if grant.starterPack then
		data.StarterPack = true
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > Profile.MaxReceipts do
		table.remove(data.Receipts, 1)
	end
	return true, function()
		for key, value in before do
			data[key] = value
		end
	end
end

return Profile
