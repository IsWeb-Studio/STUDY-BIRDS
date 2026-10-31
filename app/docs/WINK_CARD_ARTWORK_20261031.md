# COVEY Winker card artwork

The numbered cards 1–11, winker face and common back are saved in `assets/images/games/covey_card_*.png`. All are portrait 1024×1536 (2:3). The three supplied images are copied unchanged for card 1, the winker face and the back. Existing assets are retained for rollback.

The built-in image generation tool generated separate number variants 2–11 using the supplied card 1 as the edit reference. No external image API or CLI was used. Final prompt set, with `n` expanded individually as 2, 3, 4, 5, 6, 7, 8, 9, 10 and 11:

> Edit the supplied playing card. Replace ONLY the central numeral 1 with the number n. Exactly n, no other number. Preserve the portrait 2:3 ivory card, thin rounded green border, dimensional lime/forest-green ribbon texture inside the number, small bird emblem, corner green waves and exact footer SPONSORED BY then STUDY BIRDS. Center the number in the same bounding area, with both digits fitting if needed. Match the supplied deck precisely.

All generated faces were inspected for the correct number and deck styling. The actual Flutter card grid was captured and visually checked. Full images are shown without superimposed legacy digits, eye art or COVEY captions.

The shared widget serves online, local and practice play. Protocol role 11 remains the winker, displayed with the supplied wink face, while ordinary play uses numbered faces 1–10. Numbered artwork 11 is included as requested but does not create a twelfth player or change the game's role distribution. The closed state mounts only the common back and its neutral accessibility label, even if the caller still holds a number.

This is an app artwork change. The assistant's game instructions remain accurate; its reviewed source snapshot was refreshed. No new server behavior or Render deployment is required for these cards.
