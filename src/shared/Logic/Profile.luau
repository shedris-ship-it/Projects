-- A player's saved profile: its shape, its upgrades, and the purchases on it
-- (Services/DataService saves it; Services/MonetizationService grants into
-- it). Version 2 (the lobby rework's LB0, docs/plans/lobby-rework.md, "Data")
-- adds what the lobby's shops will need: what you own and wear, arcade
-- credits and tickets, the starter pack, and the receipts that make every
-- purchase count once. Version 3 (LB3, the boutique) adds the day of your
-- last double-Marks escape, whether the starter pack has been offered, and
-- gifts waiting to be opened.

local Profile = {}

Profile.Version = 3

-- Gifts waiting to be opened (more are refused until some are).
Profile.MaxGifts = 20

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
	-- Version 3 (LB3):
	DoubleDay = 0, -- the day (UTC, Logic/Progression.day) of the last double-Marks escape
	StarterOffered = false, -- the starter pack's slip shown, after the first run
	Gifts = {}, -- wrapped boxes not yet opened: { product, from (a user id) }, oldest first
}

-- Versioned upgrades: add a step whenever the saved shape changes. A step
-- takes a profile of that version and returns the next one's. Fields new to
-- a version come from TEMPLATE, so a step only moves or reshapes old data.
local MIGRATIONS = {
	[1] = function(data)
		-- 1 -> 2: only new fields (TEMPLATE fills them in).
		return data
	end,
	[2] = function(data)
		-- 2 -> 3: only new fields.
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
	data.StarterOffered = data.StarterOffered == true
	data.DoubleDay = clampNumber(data.DoubleDay, 1e7)
	for _, key in { "Owned", "Wearing", "Settings", "Dossier" } do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	-- What you own: sets of names by kind; what you wear: a name a slot.
	for kind, set in data.Owned do
		if type(kind) ~= "string" or type(set) ~= "table" then
			data.Owned[kind] = nil
		else
			for id, yes in set do
				if type(id) ~= "string" or yes ~= true then
					set[id] = nil
				end
			end
		end
	end
	for slot, id in data.Wearing do
		if type(slot) ~= "string" or type(id) ~= "string" then
			data.Wearing[slot] = nil
		end
	end
	local gifts = {}
	if type(data.Gifts) == "table" then
		for _, gift in data.Gifts do
			if type(gift) == "table" and type(gift.product) == "string" and #gifts < Profile.MaxGifts then
				table.insert(gifts, { product = gift.product, from = math.floor(tonumber(gift.from) or 0) })
			end
		end
	end
	data.Gifts = gifts
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
-- grant = { marks = n?, arcadeCredits = n?, starterPack = true?, garment =
-- id? }. Marks bought never add Clearance XP (the plan's "Marks"). `gift` =
-- { product, from }: the purchase was a friend's gift to this profile, its
-- wrapped box waiting (LB3; its grant is applied now, the box is how it's
-- opened). Returns whether anything was applied (false when the receipt was
-- already there) and a function that takes it all back, for when the save
-- that should keep it fails.
function Profile.applyPurchase(data, purchaseId: string, grant, gift): (boolean, () -> ())
	if Profile.hasReceipt(data, purchaseId) then
		return false, function() end
	end
	local before = {
		Marks = data.Marks,
		ArcadeCredits = data.ArcadeCredits,
		StarterPack = data.StarterPack,
		Receipts = table.clone(data.Receipts),
		Gifts = table.clone(data.Gifts),
		Owned = table.clone(data.Owned),
	}
	for kind, set in data.Owned do
		before.Owned[kind] = table.clone(set)
	end
	if type(grant.marks) == "number" and grant.marks > 0 then
		data.Marks = math.min(data.Marks + math.floor(grant.marks), 1e9)
	end
	if type(grant.arcadeCredits) == "number" and grant.arcadeCredits > 0 then
		data.ArcadeCredits = math.min(data.ArcadeCredits + math.floor(grant.arcadeCredits), 1e6)
	end
	if grant.starterPack then
		data.StarterPack = true
	end
	if type(grant.garment) == "string" then
		data.Owned.garment = data.Owned.garment or {}
		data.Owned.garment[grant.garment] = true
	end
	if gift and #data.Gifts < Profile.MaxGifts then
		table.insert(data.Gifts, { product = gift.product, from = gift.from })
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

-- Opens the oldest wrapped gift: takes it off the list and returns it ({
-- product, from }), or nil when there's none.
function Profile.openGift(data)
	if #data.Gifts == 0 then
		return nil
	end
	return table.remove(data.Gifts, 1)
end

return Profile
