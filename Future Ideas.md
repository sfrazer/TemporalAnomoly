## Future Ideas


### Active / Next

Order is not priority. Move each into the archive once complete.

Open design threads:
- *Mobile Outpost* card effect — currently a stub returning "Not yet implemented".
- *Supply Drop* card effect — currently a stub returning "Not yet implemented".
- *Chronomancer unlock condition* — TBD (see Phase 17).

---

### Archive

Future Ideas (these are already incorperated in the plan)

- bugfix: chronologist role is supposed to auto-clear REPAIRED-color cubes when moving to a new location

- Demo: allows one complete run then exits, no saves.

- Itch.io web-playable release for demo and full game using 

- new console commands:
  - showPlayerDeck - shows player deck contents in draw order
  - showThreatDeck - shows threat deck contents in draw order

- Additional unlockable roles:
  - Chronomancer - once per run, look at the top 6 threat cards and re-order them.

- Don't end turn when actions=0. Require teh player to click "end turn." this should let the player play event cards before the turn ends even though they have no actions remaining

- Scroll and sort cards

- Zoom/scroll in map is awful, remove it for now

- additional status entries:
  - Current role (with a pop-up describing the role)
  - Any events or threat modifier cards that have a duration (end of turn, next threat draw, etc.) should have a status entry with a tooltip describing them

- Status bar: The resolved tracker is too hard to differentiate RESOLVED vs REPAIRED. Make the REPAIRED be an "X" in the appropriate color

- Profile Screen: Allow player to name the profile when creating it


- UI: Need a button for options/settings. That will eventually include settings for:
  - Sound:
    - music on/off
    - music volume
    - sound effects volume
  - Graphics:
    - change starting resolutions
    - enable some other features (currently undefined)
  - Quit run (return to main menu)
  - Exit game

- UI: on modal to Resolve Anomaly, only highlight the colors we have the correct amount (4 or 5 depending on role/effect) in hand

- UI: enable tooltips for cards in modal dialogs

- Startup should launch an introduction/main menu screen with:
  - Options
  - Resume last run (enabled if there is a run in progress, disabled otherwise)
  - A button to change profile, that shows the current profile.
  - A button to start a new run

Travel / Teleport / Teleport Alt actions:
  - Can we have them happen simply by clicking on the desired location? 
    - If it's a travel event, just move the player and decrement the action.
    - If it's a teleport, check to see if we have the required target card and prompt to use it
    - If it's a teleport alt, check to see if we have the required source card and prompt to use it
    - If we have both cards, prompt for which card to use

Animations
 - For Instability phase, show each threat card drawn, pausing for 2 seconds before continuing
