# The torch on F, your own arms, your own legs (build `2026-10-12.168`)

The owner's three asks after playing IT WANTS IN (`docs/reference/it-wants-in/NOTES.md`): the torch on its own key with a clean animation, the inventory separate from it, and your body in first person. Then, mid-build, a fourth: "make sure ... your arm is actually your arm and matches your avatar instead of just being a default hand". Design and code: `docs/plans/gameplay-rework.md` section 20. Tests: `docs/TESTING.md` TC-275 to TC-283. All shots are from Studio, seed 1800820264, one client, at the in-game exposure.

| Shot | What it shows |
| --- | --- |
| `1_torch_up_old_arm.jpg` | First pass: the torch up in the left hand, the hotbar with the torch apart (F, "on") and slots 1 and 2. The arm was still the old primitive sleeve and hand |
| `2_looking_down_before_neck.jpg` | Looking down with only the legs shown and no neck: all you see is the top of your own hips. Roblox's eye sits half a stud *behind* your middle |
| `3_looking_down_hips_block.jpg` | With the neck: your shoes show, but the hips draw as a block of shirt colour (these avatar meshes give the hips' top the torso's colour). The hips are hidden since |
| `4_your_arm_on_the_torch.jpg` | Your own arm: a copy of your character's forearm and hand (shirt sleeve, skin hand) holding the torch |
| `5_torch_and_crowbar.jpg` | The torch in your left hand, the crowbar from slot 1 in your right, both arms yours |
| `6_boards_worked.jpg` | Just after working a boarded door with R: the torch went to your shirt while both hands worked, and swung back up the moment the last board came away |
| `7_looking_down_arm_and_legs.jpg` | Looking steeply down: your arm on the torch and your two legs down to your shoes, no block |
| `8_walking_onto_the_stairs.jpg` | Looking down while walking onto the grand stair |
| `9_level_view.jpg` | The level view in the grand hall: the torch in your own hand |

Measured (frame by frame, from the client): the torch comes up from below the screen to its pose in 0.21 s, overshoots a touch and settles by 0.4 s, and lights with a thumb-click dip; put away, it clicks off at once and is out of sight in 0.2 s. Slot 1 pressed twice leaves the hand free. The console was clean throughout.

Not checked here: two clients (TC-282), a dead or cut torch (TC-283), the Settings toggle (TC-281), crouching and kneeling views (TC-279).
