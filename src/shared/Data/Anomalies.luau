-- The 12 anomalies (doc section 4). Every anomaly lists its tells; the Case
-- Board turns confirmed tells into an elimination puzzle across all 12.
--
-- implemented = true means the anomaly can be chosen for a run: its ritual
-- exists in ServerScriptService.Server.Services.Rituals. The others still
-- appear on the Case Board and lend their tells as red herrings, so the
-- deduction is a real 12-suspect puzzle from the vertical slice onward.

local Anomalies = {
	{
		id = "PhantomArchitecture",
		name = "Phantom Architecture",
		channel = "Space",
		summary = "Doors, walls and windows exist for some Witnesses only.",
		tells = { "phantom_doorway", "footprints_into_wall", "wrong_scale", "door_shadow", "sealed_window" },
		ritual = {
			name = "Triangulate",
			summary = "Each seam flickers for everyone, but some flickers are yours alone. "
				.. "Every Witness must Witness the same seam together to close it. Three seams, one Source.",
		},
		source = "seam",
		stalkerTwist = "It walks through walls that were never really there.",
		buildCost = "Low",
		stage = "Vertical slice",
		implemented = true,
	},
	{
		id = "Echo",
		name = "The Echo",
		channel = "Time",
		summary = "Clocks disagree and sounds arrive before their cause.",
		tells = {
			"clock_disagree",
			"early_sound",
			"delayed_teammate",
			"wrong_side_steps",
			"looping_sound",
			"failing_key",
		},
		ritual = {
			name = "Synchronise",
			summary = "Perform linked actions in the order each Witness hears the countdown.",
		},
		source = "floor",
		stalkerTwist = "You hear it a few seconds after it has moved.",
		buildCost = "Medium",
		stage = "Launch",
		implemented = false,
	},
	{
		id = "Mimic",
		name = "Mimic",
		channel = "Identity",
		summary = "Head counts differ, name tags glitch, extra footsteps follow.",
		tells = {
			"headcount",
			"glitched_nametag",
			"extra_footsteps",
			"delayed_teammate",
			"duplicate_object",
			"wet_footprints",
		},
		ritual = { name = "Interrogate", summary = "Ask the copy questions only the real Witness can answer." },
		source = "floor",
		stalkerTwist = "It sends pings in your friends' names.",
		buildCost = "Medium",
		stage = "Alpha",
		implemented = false,
	},
	{
		id = "DeadAir",
		name = "Dead Air",
		channel = "Sound",
		summary = "Footsteps from the wrong side; voices drop out in certain rooms.",
		tells = { "early_sound", "wrong_side_steps", "extra_footsteps", "muted_radio", "dripping_sound" },
		ritual = {
			name = "Tune",
			summary = "Tune the radio to the Source frequency by comparing what each Witness hears.",
		},
		source = "floor",
		stalkerTwist = "Its footsteps come from the wrong direction.",
		buildCost = "Medium",
		stage = "Alpha",
		implemented = false,
	},
	{
		id = "Umbra",
		name = "Umbra",
		channel = "Light",
		summary = "Shadows with no owner; a flashlight reveals what others can't see.",
		tells = { "ownerless_shadow", "hidden_writing", "dead_lamp", "door_shadow", "long_shadow" },
		ritual = {
			name = "Converge",
			summary = "Overlap two or more light beams so the shadows converge on the Source.",
		},
		source = "floor",
		stalkerTwist = "It waits just outside your beam.",
		buildCost = "Medium",
		stage = "Launch",
		implemented = false,
	},
	{
		id = "Redaction",
		name = "Redaction",
		channel = "Memory",
		summary = "Notes, pins and logs rewrite themselves.",
		tells = {
			"clock_disagree",
			"glitched_nametag",
			"hidden_writing",
			"rewritten_note",
			"moved_pins",
			"measured_wrong",
		},
		ritual = { name = "Reconcile", summary = "Rebuild a shared ledger; an entry holds only when two logs match." },
		source = "wall",
		stalkerTwist = "Your map pins lie about where it is.",
		buildCost = "Low",
		stage = "Alpha",
		implemented = false,
	},
	{
		id = "LoopCorridor",
		name = "Loop Corridor",
		channel = "Topology",
		summary = "The same painting repeats; teammates walk through dead ends.",
		tells = {
			"phantom_doorway",
			"clock_disagree",
			"moved_pins",
			"repeating_painting",
			"looping_sound",
			"duplicate_object",
		},
		ritual = {
			name = "Break the loop",
			summary = "Stamp each junction, compare stamps, and break the loop where paths diverge.",
		},
		source = "seam",
		stalkerTwist = "It is waiting at the far end of every loop.",
		buildCost = "High",
		stage = "Post-launch",
		implemented = false,
	},
	{
		id = "Counterfeit",
		name = "Counterfeit",
		channel = "Objects",
		summary = "Items read differently to each Witness; keys and fuses fail.",
		tells = { "rewritten_note", "repeating_painting", "mismatched_label", "failing_key", "duplicate_object" },
		ritual = {
			name = "Cross-check",
			summary = "Several identical keys appear. Only the genuine one reads the same to every Witness. "
				.. "Bring it to the Source with the whole squad present.",
		},
		source = "floor",
		stalkerTwist = "Picking up a counterfeit rings out through the house.",
		buildCost = "Low",
		stage = "Vertical slice",
		implemented = true,
	},
	{
		id = "Gaze",
		name = "Gaze",
		channel = "Attention",
		summary = "Objects change when unobserved; a portrait's eyes follow one Witness.",
		tells = { "moved_when_unobserved", "portrait_eyes", "ownerless_shadow", "dead_lamp", "turned_figures" },
		ritual = {
			name = "Stare-down",
			summary = "Every Witness must hold their eyes on the Source portrait at once, while it closes in behind you.",
		},
		source = "wall",
		stalkerTwist = "It is faster whenever nobody is looking.",
		buildCost = "Low-Medium",
		stage = "Vertical slice",
		implemented = true,
	},
	{
		id = "Hollow",
		name = "Hollow",
		channel = "Absence",
		summary = "One Witness can't see a squadmate; held items float in mid-air.",
		tells = {
			"vanished_teammate",
			"floating_item",
			"headcount",
			"muted_radio",
			"breath_fog",
			"phantom_doorway",
		},
		ritual = {
			name = "Map the boundary",
			summary = "Find where the missing Witness reappears; the Source sits on it.",
		},
		source = "floor",
		stalkerTwist = "It can be invisible to one of you.",
		buildCost = "Medium",
		stage = "Post-launch",
		implemented = false,
	},
	{
		id = "Tide",
		name = "Tide",
		channel = "Environment",
		summary = "Indoor rain, breath fog and wet footprints, real for only some.",
		tells = { "footprints_into_wall", "indoor_rain", "breath_fog", "wet_footprints", "dripping_sound" },
		ritual = {
			name = "Close the valves",
			summary = "Follow the water and close two valves in distant rooms at the same moment.",
		},
		source = "floor",
		stalkerTwist = "It moves faster through water.",
		buildCost = "Medium",
		stage = "Post-launch",
		implemented = false,
	},
	{
		id = "Proportion",
		name = "Proportion",
		channel = "Scale",
		summary = "Furniture and doorways are the wrong size; distances feel wrong.",
		tells = {
			"wrong_scale",
			"mismatched_label",
			"floating_item",
			"moved_when_unobserved",
			"measured_wrong",
			"long_shadow",
		},
		ritual = {
			name = "Measure",
			summary = "Everyone measures the same objects; the one object all agree on is the Source.",
		},
		source = "floor",
		stalkerTwist = "It looks further away than it is.",
		buildCost = "Medium",
		stage = "Post-launch",
		implemented = false,
	},
}

local byId = {}
for index, anomaly in Anomalies do
	anomaly.index = index
	byId[anomaly.id] = anomaly
end

local module = {
	List = Anomalies,
	ById = byId,
}

function module.get(id: string)
	return byId[id]
end

function module.implemented(): { any }
	local result = {}
	for _, anomaly in Anomalies do
		if anomaly.implemented then
			table.insert(result, anomaly)
		end
	end
	return result
end

return module
