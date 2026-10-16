-- Every short board the lobby shows (LB5; docs/plans/lobby-rework.md, "The
-- diner" and "The arcade's games and scores"): the diner's run records
-- (Services/RecordsService) and the arcade's high scores (Services/
-- ArcadeService). Each is kept whole in one DataStore key (Logic/
-- Leaderboard): only the top few ever show, and a list with its names reads
-- in one request, where an OrderedDataStore would keep every score ever and
-- need a second store for the names. Written with UpdateAsync, so servers
-- posting at once both land, and only when an entry would make the board.
-- Without DataStores (Studio with API access off) the boards live in memory
-- for the session.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Signal = require(Shared.Lib.Signal)

local BoardService = {}

function BoardService:Init(services)
	self.services = services
	self.cache = {} -- board name -> its list, as last read or written
	self.kinds = {} -- board name -> { size, low, unique }
	self.memory = nil -- board name -> list, when there's no store
	self.Changed = Signal.new() -- (board name)
	local name = services.DataService.StoreName(Config.Boards.Store)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok then
		self.store = store
	else
		self.memory = {}
	end
end

function BoardService:Start()
	-- Boards someone shows are read again now and then (others post to them).
	task.spawn(function()
		while true do
			task.wait(Config.Boards.Refresh)
			for board in self.kinds do
				self:Read(board)
			end
		end
	end)
end

-- Says how a board sorts and keeps it fresh: `size` places, `low` when lower
-- is better, `unique` for one entry per key. Reads it now (yields).
function BoardService:Watch(board: string, size: number, low: boolean?, unique: boolean?)
	self.kinds[board] = { size = size, low = low, unique = unique }
	self:Read(board)
end

-- The board as last seen (best first; empty when unread).
function BoardService:Get(board: string)
	return self.cache[board] or {}
end

local function same(a, b): boolean
	if #a ~= #b then
		return false
	end
	for i, entry in a do
		if entry.value ~= b[i].value or entry.key ~= b[i].key or entry.at ~= b[i].at then
			return false
		end
	end
	return true
end

function BoardService:_set(board: string, list)
	local kind = self.kinds[board]
	list = Leaderboard.clean(list, kind and kind.size or 50, kind and kind.low)
	local old = self.cache[board]
	self.cache[board] = list
	if not old or not same(old, list) then
		self.Changed:Fire(board)
	end
end

-- Reads a board from its store (yields).
function BoardService:Read(board: string)
	if self.memory then
		self:_set(board, self.memory[board] or {})
		return
	end
	local ok, list = pcall(self.store.GetAsync, self.store, board)
	if ok then
		self:_set(board, list or {})
	else
		self:_failed(board, "read", list)
	end
end

-- A store that refuses every request (403: Studio without API access) is
-- given up for the session's memory; anything else is only warned.
function BoardService:_failed(board: string, what: string, err)
	warn(string.format("[Consensus] board %s couldn't be %s: %s", board, what, tostring(err)))
	if string.find(tostring(err), "403") then
		self.memory = self.memory or {}
	end
end

-- Posts an entry; returns its place, or nil when it didn't make the board
-- (or the write failed). Yields.
function BoardService:Post(board: string, entry, size: number, low: boolean?, unique: boolean?): number?
	self.kinds[board] = self.kinds[board] or { size = size, low = low, unique = unique }
	-- (A board read a moment ago that the entry can't make: no write.)
	local cached = self.cache[board]
	if cached and not unique and not Leaderboard.makes(cached, entry.value, size, low) then
		return nil
	end
	if self.memory then
		local list, rank = Leaderboard.insert(self.memory[board] or {}, entry, size, low, unique)
		self.memory[board] = list
		self:_set(board, list)
		return rank
	end
	local rank, kept
	local ok, err = pcall(self.store.UpdateAsync, self.store, board, function(old)
		local list, at = Leaderboard.insert(old or {}, entry, size, low, unique)
		rank, kept = at, list
		if not at then
			return nil -- (doesn't make it: nothing written)
		end
		return list
	end)
	if not ok then
		self:_failed(board, "written", err)
		return nil
	end
	if kept then
		self:_set(board, kept)
	end
	return rank
end

-- Empties a board (F2 `record clear`, Studio's boards only).
function BoardService:Clear(board: string)
	if self.memory then
		self.memory[board] = {}
	elseif self.store then
		pcall(self.store.RemoveAsync, self.store, board)
	end
	self:_set(board, {})
end

return BoardService
