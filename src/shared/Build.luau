-- Which build is running (owner, 2026-10-04: after a cloud session's work the
-- owner couldn't tell whether Studio had the new code or the old). The id is
-- shown in the F2 overlay (client and server side by side, so a half-synced
-- place shows two different ids), on the hub panel, and in the Output window
-- when the server and each client start.
--
-- Bump `id` (date, then a counter for the day) in every commit that is meant
-- to reach Studio. `note` says what is new in a few words.

return {
	id = "2026-10-04.17",
	note = "Rework R1a.8: noises nobody made (a thing landing) draw The Guest to look when he has lost you; F2 lure",
}
