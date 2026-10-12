# Reference: IT WANTS IN [HORROR]

The closest game to ours on Roblox, and the quality bar the owner chose on 2026-10-11 (Roblox place 104376435116540, by The Horror Zone, released 2026-10-01; about 6,900 playing and 714K visits ten days in). A squad in a cabin in late-October 1986 keeps a tall thing out until 6 AM: close the curtains, board the windows, keep the fire and the power on, stay quiet. The owner: its loop is simpler than ours, it looks really good and plays streamlined, and **Consensus should exceed it, visually and in the loop.** We learn from it; we don't copy its models, sounds or text.

The screenshots in this folder are the owner's, from one night. They are git-ignored (someone else's game, in a public repo), so a cloud session won't have them: the list below says what each shows.

| File | What it shows |
| --- | --- |
| `01-study-1-20am.webp` | A study at 1:20 AM: tufted leather armchairs, an office chair, a deer mount, log walls, lamps with glowing shades; captions stacked over the hotbar |
| `02-living-room-fire.webp` | The living room lit by the fireplace; the TV above it shows colour bars and "CLOSE YOUR CURTAINS" |
| `03-hall-dark.webp` | A dark hall with double doors, the lit dining room beyond; a scan band rolls across the image |
| `04-broadcast-midnight.webp` | Midnight: an Emergency Broadcast panel types out the curfew's rules over the kitchen and the dining table; the objective reads "Close the curtains (14 open)" |
| `05-window-outside.webp` | A window at night: pine trees in fog and a parked car outside; prompts "R Board up · window 0/3 · uses plank (1)" and "E Close curtains" |

## The owner's notes (2026-10-11)

1. **The flashlight has its own button.** F raises it, F again puts it away, and the inventory is separate from it. It felt streamlined. (Ours today: the torch is slot 1 of the hotbar, slots 2 and 3 clip it to your shirt, and F only switches it on and off.)
2. **You can see outside.** Trees, the tree line, a car in the drive, through the windows. (Ours today: a near-black sky, one moon a run as a soft glow, a covering per window; `Logic/WindowView`, `Config.Window`.)
3. **It shows how good Roblox horror can look**, and ours should look better.
4. **Order:** the full visual rework plan comes once the gameplay loop is solid, which the owner thinks it is, provided every system works as intended.

## Why it looks good (Claude's read of the screenshots)

- **Modelled furniture.** Real shapes with real materials: tufted leather, a live-edge table, a stone chimney, plants with real leaves. This is the biggest gap: ours is built from primitives in code (`World/PropFactory`).
- **Materials at the scale you stand at.** Log walls with chinking, wide plank floors, stone, all with visible grain from two studs away.
- **Lights you can see.** Lampshades glow, the fire is the living room's key light, a ceiling dome throws a pool, and a lit room sits next to a black hall (03). This is our ART.md rule 1 done well.
- **A camcorder grade.** A date stamp in the corner ("OCT 31 1986 1:20 AM"), a rolling scan band, a soft vignette, a warm brown grade. One idea sells both the period and the found-footage dread.
- **Pictures of real places** in the frames (a misty lake, a barn, a field).
- **The outside.** Cool blue trees and fog behind warm interiors: the contrast does a lot of the mood.

## Where we can beat it

- **Bodies.** Their players are their own Roblox avatars with name tags, inside the set. Ours already wear period outfits (`LoadCharacterAppearance` off, `Logic/Outfit`); our players' name tags still show (only the Guest's are hidden), which is a choice for the plan.
- **One cabin, every night.** Handmade can be right corner by corner. Ours has to look this good in any room the generator makes, so the plan needs a kit of rooms and props that hold up anywhere.
- **A busy screen.** A clock panel, an objective line, three house meters (power, fire, seal), a flashlight meter, a noise meter, five consumable counts and four paid powers. All readable, but the screen is full; ART.md says the house does the talking. The one worth discussing is the noise meter: he hears us, and our players can't see how loud they are.
- **Paid powers on the hotbar.** Push R$90, Scare All R$117, Lockdown R$225, Skip Hour R$225 (Robux developer products). That's how it earns, and it lets a squad buy its way through the night. Money is the owner's decision and isn't decided; noted so it's a choice later, not an accident.

## Worth learning beyond the look

- **The house teaches the rules.** The TV says to close the curtains (02), the broadcast types out the rules at midnight (04), and the objective line names the next job with a count (04, 05). Nobody reads a how-to. Ours teaches the three rules on a how-to screen and in tips; the tutorial run (CLAUDE.md roadmap item 4) could teach them through the house the same way.
- **Every sound has a caption**, stacked over the hotbar: breathing, footsteps, a crack, a shriek. We caption too (`Sfx.play` takes one); compare how often.
- **Prompts state cost and progress:** "Board up · window 0/3 · uses plank (1)".
- **The clock is the progress bar:** 12:00 to 6:00 AM with ticks, under "NIGHT 1 · IT WATCHES".

## For the visual rework plan

Take the same moments in Consensus from Studio, at the in-game exposure, and put them side by side with these: the first room after spawning, a lit room, a dark hall, a window at night, the screen's interface, and the first sight of him. Then say, for each, what we'd change to beat it.
