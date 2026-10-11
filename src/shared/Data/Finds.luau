-- What a drawer or a cupboard holds when the run keeps nothing of its own
-- there (Services/FindService picks one as it's first opened; World/Junk
-- builds it). The owner's playtest, 2026-10-11: "Useless items kinda suck".
-- Every find is worth the look now: most do something when you press E on
-- them, the rest are for throwing (a lure, and a hit stuns him).
--
--   name    the model's name (World/Junk builds it; Data/Physical carries it)
--   use     what E does to it, on its prompt; nil: something to throw
--   effect  "battery"  a share of a full torch (Config.Finds.BatteryShare)
--           "mend"     one of your downs forgiven (Config.Run.DownsBeforeLost);
--                      with none to forgive, it stays where it is
--           "lead"     old letters with a line in them that points at what
--                      the run wants next (Logic/Assist); the map rings it
--           "matches"  pocketed: a lantern shrine lights at once with one
--   weight  how often, against the others
--   max     at most this many a run, by the squad's size (1 to 4 players)

return {
	{ name = "SpareBatteries", use = "Put them in your torch", effect = "battery", weight = 4, max = { 3, 4, 5, 6 } },
	{ name = "PillBottle", use = "Take them", effect = "mend", weight = 2, max = { 1, 1, 2, 2 } },
	{ name = "Letters", use = "Read them", effect = "lead", weight = 3, max = { 3, 3, 4, 4 } },
	{ name = "Matchbox", use = "Pocket the matches", effect = "matches", weight = 2, max = { 2, 2, 3, 3 } },
	{ name = "Cassette", weight = 2 },
	{ name = "Candle", weight = 1 },
	{ name = "Spool", weight = 1 },
}
