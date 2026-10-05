-- Every room has a reason (owner, 2026-10-05: "a reason for going there or
-- being there, even if that reason is as simple as a landmark"; docs/plans/
-- level-design.md section 4). A room's reasons come in three tiers:
--
--   strong    something draws you in: what the run needs is kept there (a
--             key, a code's puzzle, an heirloom, a note, a box, a case, a
--             rack), the table or the front door, a Lantern shrine, a
--             landmark (Data/Props `landmark`), a fixture to lure him with
--             (Data/Interactables)
--   survival  somewhere to hide
--   route     a corridor or a stair, or a room on a loop you can run round
--
-- A room "has a reason" when it has a strong one, or is a corridor or a stair
-- (its reason is getting places). Each region should have its kit: a hiding
-- spot, a lure, and a landmark or a Lantern. Logic/HouseMetrics counts the
-- rooms without a reason and the regions short of their kit; the planner and
-- the leads put what they keep into rooms with no strong reason first. Pure.

local Graph = require(script.Parent.Graph)
local LockPlanner = require(script.Parent.LockPlanner)
local Props = require(script.Parent.Parent.Data.Props)
local Interactables = require(script.Parent.Parent.Data.Interactables)

local RoomPurpose = {}

local LEAD_NAMES = { note = "note", keepsake = "keepsake box", display = "display case", hook = "key rack" }

local function add(list, label: string)
	if not table.find(list, label) then
		table.insert(list, label)
	end
end

-- Whether a room is a way between others (a corridor or a stair).
function RoomPurpose.connector(room, template): boolean
	return room.corridor == true or room.kind == "stair" or (template ~= nil and template.family == "corridor")
end

-- What each room offers by itself, before any plan: { [room id] = { strong,
-- survival, route, lure, landmark } }.
function RoomPurpose.base(layout, templatesById)
	local mansion = layout.mode == "Mansion"
	local out = {}
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		local entry = { strong = {}, survival = {}, route = {}, lure = false, landmark = false }
		for _, prop in template and template.props or {} do
			local kind = Props.Kinds[prop.kind]
			if kind and kind.landmark then
				add(entry.strong, "landmark: " .. prop.kind)
				entry.landmark = true
			end
			if Interactables[prop.kind] then
				add(entry.strong, "lure: " .. prop.kind)
				entry.lure = true
			end
		end
		if LockPlanner.offers(template, mansion).hides > 0 then
			add(entry.survival, "hide")
		end
		if room.lantern then
			add(entry.strong, "Lantern")
		end
		if room.id == layout.start then
			add(entry.strong, "the start")
		end
		if room.id == layout.deliberation then
			add(entry.strong, "the table")
		end
		if RoomPurpose.connector(room, template) then
			add(entry.route, room.kind == "stair" and "stairs" or "corridor")
		end
		out[room.id] = entry
	end
	-- The laundry chute (section 10.5): a way down out of a chase, and a
	-- shortcut for what you carry.
	local chute = layout.chute
	if chute and out[chute.upper] and out[chute.ground] then
		add(out[chute.upper].survival, "chute down")
		add(out[chute.ground].route, "chute")
	end
	-- Rooms on a loop of four or more: somewhere to run round.
	local ids, edges = {}, {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	table.sort(ids)
	for _, seam in layout.seams do
		if seam.connected then
			table.insert(edges, { seam.a, seam.b })
		end
	end
	local adj = Graph.adjacency(ids, edges)
	for _, cycle in Graph.fundamentalCycles(adj, ids, edges) do
		if #cycle >= 4 then
			for _, id in cycle do
				add(out[id].route, "loop")
			end
		end
	end
	return out
end

-- Every room's reasons with the plan (and the leads, when they're known:
-- Logic/Leads.plan) laid in.
function RoomPurpose.of(layout, plan, templatesById, leads)
	local out = RoomPurpose.base(layout, templatesById)
	if plan then
		for id, token in plan.tokens do
			local label = token.kind == "heirloom" and "heirloom" or token.kind
			if token.producer.kind == "puzzle" then
				local puzzle = plan.puzzles[token.producer.id]
				label = "puzzle: " .. (puzzle and puzzle.kind or "?")
			end
			for _, room in LockPlanner.producerRooms(plan, token) do
				if out[room] then
					add(out[room].strong, label)
				end
			end
			local lead = leads and leads.tokens[id]
			if lead then
				if lead.kind == "note" and lead.noteRoom and out[lead.noteRoom] then
					add(out[lead.noteRoom].strong, "note")
				elseif LEAD_NAMES[lead.kind] then
					local room = LockPlanner.tokenRoom(plan, token)
					if room and out[room] then
						add(out[room].strong, LEAD_NAMES[lead.kind])
					end
				end
			end
		end
		for _, puzzle in plan.puzzles do
			for _, room in puzzle.rooms or { puzzle.room } do
				if out[room] then
					add(out[room].strong, "puzzle: " .. puzzle.kind)
				end
			end
		end
	end
	for _, decoy in leads and leads.decoys or {} do
		if out[decoy.room] then
			add(out[decoy.room].strong, LEAD_NAMES[decoy.kind] or decoy.kind)
		end
	end
	return out
end

-- Whether a room has a reason to go in: a strong one, or it's a way between.
function RoomPurpose.hasReason(entry): boolean
	if #entry.strong > 0 then
		return true
	end
	for _, label in entry.route do
		if label == "corridor" or label == "stairs" then
			return true
		end
	end
	return false
end

-- What a region is short of: one each for a hiding spot, a lure, and a
-- landmark or a Lantern, counted over every region of the plan.
function RoomPurpose.kitGaps(purposes, plan): number
	local gaps = 0
	for r = 0, #plan.order do
		local hide, lure, mark = false, false, false
		for _, id in plan.regions[r].rooms do
			local entry = purposes[id]
			if entry then
				hide = hide or #entry.survival > 0
				lure = lure or entry.lure
				mark = mark or entry.landmark or table.find(entry.strong, "Lantern") ~= nil
			end
		end
		gaps += (hide and 0 or 1) + (lure and 0 or 1) + (mark and 0 or 1)
	end
	return gaps
end

-- One line per room: its reasons, strongest first (tools/plan, F2 `house`).
function RoomPurpose.describe(entry): string
	local parts = {}
	for _, label in entry.strong do
		table.insert(parts, label)
	end
	for _, label in entry.survival do
		table.insert(parts, label)
	end
	for _, label in entry.route do
		table.insert(parts, label)
	end
	local line = table.concat(parts, ", ")
	if not RoomPurpose.hasReason(entry) then
		line = "NO REASON (" .. (line ~= "" and line or "nothing") .. ")"
	end
	return line
end

return RoomPurpose
