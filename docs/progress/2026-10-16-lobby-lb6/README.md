# The lobby rework, LB6: the immersive ads

The ads part of LB6 (`docs/plans/lobby-rework.md`, "Immersive ads"; the owner: "ads in places you might actually see ads inside of a mall"). It covers the frames, the rules and our own posters. Nothing was uploaded, and nothing earns yet: ad revenue needs the game public, the owner ID-verified with 2-step verification, the maturity questionnaire approved and 2,000 unique visitors a month. Build .230. The photo booth and the supporter pack, LB6's other two parts, are still to do.

## Where the frames are (`Data/Mall` `Ads`)

Seven frames, only where a mall really had ads:

| Slot | Kind | Where | Face | Our poster |
| --- | --- | --- | --- | --- |
| court-west-north, court-west-south | lightbox | the court's west wall either side of the diner (the existing boxes) | 11 x 6.2 | Mayfield's, Pine Hollow Estates |
| court-east-north, court-east-south | lightbox | either side of the shutter (the existing boxes) | 8.4 x 5 | Portraits by Lorraine, Sparkle Cola |
| video-coming-west, video-coming-east | film | the video store's side walls by the way in, over the first tapes, under a COMING SOON strip | 8.4 x 5 | DON'T LOOK AWAY, SUPPERTIME |
| electronics-screen | screen (video too) | a big projection screen behind the three sets in the electronics window | 8.8 x 4.95 | colour bars, PLEASE STAND BY |

- **The lightboxes weren't moved.** Their cases and clearances are LB1's. Their light now hangs 2 studs in front of the face instead of at its middle: an AdGui is lit by the scene, not by itself (seen in Studio: dark in the dark, lit near a light), so the light has to fall on it. The court looks the same as before (`before-court-west.jpg`, `after-court-west.jpg`).
- **The video store's frames hang inside, not in its front.** The court's string of bulbs and the cardboard CASES & CARS sign hang across the opening, so a frame low enough to clear them would hang at head height in the doorway. They hang on the side walls instead, in the kit's `LightboxSmall` case (no import needed), the way video stores hung posters over their shelves. They're seen from the way in and through the front (`after-video-west.jpg`).
- **The TV wall's sets are too small for an ad.** Roblox's smallest face is 8 x 4.5 studs, and the sets are 4 x 3, so a big projection screen stands behind them on two posts, its foot hidden by the sets. It's a grey-box case for now; a kit piece can come with a later batch. It hides the back wall's SERVICE sign from straight ahead (`before-electronics.jpg`, `after-electronics.jpg`).
- **None in** the garage (also a run server's waiting room), the arcade, the boutique, the diner or the dead mall behind the grille (anything there is seen through the grille), and none anywhere in the house. There are no portal ads and no rewarded video.

## The rules (`Logic/Ads`, spec'd; `Logic/MallLayout.adBlockers`)

- **A face Roblox can serve:** 8 x 4.5 to 32 x 18 studs and near 16:9 (`Ads.fits`, `Config.Ads`).
- **Only where a mall had ads:** `Config.Ads.Rooms` is the court, the video store and the electronics shop. `Ads.problems` also catches a frame in a run server's waiting room, a frame with no poster of ours, video on anything but a screen, and a slot named twice.
- **Nothing in front:** `adBlockers` now counts signs too, plus the room a frame is seen from (`through`: the court, for the electronics window). The check looks 14 studs out and 45 degrees off each face. The big screen is checked to 35 degrees (`fan`): beyond about 38, from the court's far corner, the gallery's column at the shop's corner cuts its edge.
- **When the AdGui goes up (`Ads.serving`):** only once the frame's own poster is uploaded (`Data/Posters` `image`), and while `Config.Ads.Serve` is on. An AdGui with no ad to show shows its fallback image, and without one Roblox's grey card with its logo. That's checked in Studio: `adgui-without-poster.jpg`, F2 `ads ad`. In a dead mall that would read as broken, so until the posters are uploaded every frame shows its lit blank, as today.
- **What each player sees (`Ads.show`, `Controllers/AdController`):** a player whose `PolicyService:GetPolicyInfoForPlayerAsync` says `AreAdsAllowed` false has the AdGui taken off their own copy of the face, and our poster put on in its place (`World/AdPoster`), so the mall looks the same to everyone. If the policy can't be read, the AdGui stays: Roblox shows its fallback (our poster) to anyone it can't serve. Checked in Studio with F2 `ads ad` and `ads deny`: every frame swapped to our blank for that player (`denied-court-west.jpg`). After `ads policy` and `ads live`, each face is back to one poster.

## Video on the TV wall: autoplay or click-to-play

That isn't ours to choose. Roblox's docs say a video ad plays autoplay (muted, while looked at, paused when you look away, with controls to unmute) or click-to-play (full screen with sound), depending on how the advertiser bids. What we decide is which frames take video at all:

- **Video:** only the big screen (`video = true`, AdGui `EnableVideoAds`). A moving picture belongs on a TV.
- **Image only:** every lightbox and film frame (`EnableVideoAds` false; Roblox's default is on). A backlit poster that moved would break the mall.

## Our posters (`tools/posters.py`, `assets/posters/`, `Data/Posters`)

Seven 1988 posters, drawn from code and seeded (Pillow and numpy), 1024 x 576. They use the Google fonts Roblox ships (OFL), found in the Roblox install. They're drafts for the owner to change, and none names a map or a real brand (`posters.jpg`):

- **The mall's own ads,** faded by years in their lightboxes:
  - Mayfield's closing sale ("EVERYTHING MUST GO");
  - Pine Hollow Estates ("A home that grows with your family", a figure at the attic window);
  - Portraits by Lorraine on the dead second floor ("Every family deserves to be remembered");
  - Sparkle Cola ("Home in time for dinner").
- **The video store's COMING SOON:**
  - DON'T LOOK AWAY (a porcelain mask: "As long as you watch him, he can't move.");
  - SUPPERTIME (the family table: "Everyone's home for dinner. Even him.").
- **The big screen:** colour bars and PLEASE STAND BY.

They're not uploaded: that's the owner's account, so it's their step. Until they're in, each frame shows its lit blank (`Data/Posters` `Blank`): the lightboxes THIS SPACE AVAILABLE as before, the film frames NEW TITLES EVERY FRIDAY, the screen its colour bars, drawn in the interface (no image).

## The owner's steps

1. **Look at the posters** (`posters.jpg`) and change any: text, ideas, which frame gets which (`Data/Mall` `poster`).
2. **Upload them** (ask Claude to, or use Creator Hub → Development Items → Decals): the seven files in `assets/posters/`. The ids go in `Data/Posters` `image` as `rbxassetid://<id>`. Each frame then shows its poster, and its AdGui goes up with the poster as its fallback.
3. **For ads to earn:** the game public, ID verification with 2-step verification, the maturity questionnaire approved in Creator Hub, and 2,000 unique visitors a month. Then Creator Dashboard → Monetization → Ads shows impressions about 48 hours after ads start.
4. `Config.Ads.Serve = false` takes every AdGui down (our posters stay) if an ad ever looks wrong in the mall.

## F2

- `ads`: each frame's state ("our poster", or "AdGui up (Inactive)" with its status), and whether you're forced.
- `ads ad`: every frame's AdGui up (Studio shows Roblox's grey card where no poster is uploaded).
- `ads poster`: ours on every frame.
- `ads live`: back to the rule.
- `ads deny`, `ads allow`: you as a player who can't, or can, be shown ads (the player attribute `DebugAdsAllowed`).
- `ads policy`: back to PolicyService's answer.

## Checked

- **Studio, solo (build .229's code with this pass, synced):**
  - all seven frames built, each showing its blank;
  - F2 `ads ad`: seven AdGuis, Status Inactive, video on the screen only, no fallback image, and the grey card in each;
  - `ads deny`: the client's own poster on all seven;
  - `ads policy`, then `ads live`: one server poster per face again;
  - no red errors. The only warnings are Roblox's own (UIBlox, the 203785492 interface sound).
- **Screenshots:** at the in-game exposure, 6 s after each camera move. Each "before" is this build with the new frames taken out of the running session and the lightbox light put back at the face's middle.
- **Checks:**
  - stylua, selene (0 and 0), `lune run tests/compile` (315 files), `rojo build` to `build/scratch`;
  - `lune run tests/run`: 7 new specs in `Ads.spec`, plus the sign test in `MallLayout.spec`, and `Kit.spec` lets the screen skip the case check.
- **Not checked:** multi-client (one denied, one allowed: TC-348), a real ad (the game isn't eligible: TC-350), the posters in place (not uploaded: TC-349).

## Files

- New:
  - `src/shared/Logic/Ads.luau` and `tests/specs/Ads.spec.luau`;
  - `src/shared/Data/Posters.luau`;
  - `src/shared/World/AdPoster.luau`;
  - `src/client/Controllers/AdController.luau`;
  - `tools/posters.py`, `assets/posters/*.jpg`.
- Changed:
  - `Data/Mall` (`Ads`: kinds, posters, three new frames; the two COMING SOON strips in `Signs`);
  - `Config` (`Config.Ads`; the old `Mall.Lights.ad` moved there);
  - `Constants` (`Tags.AdFace`);
  - `World/MallBuilder` (`buildAd`, `MallBuilder.dressAd`);
  - `Logic/MallLayout` (`adBlockers`: signs, `through`, `fan`);
  - `Services/DebugService` (`ads`);
  - `tests/specs/MallLayout.spec.luau`, `tests/specs/Kit.spec.luau`.
