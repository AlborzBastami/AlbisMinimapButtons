# 1.8.1

- Fixed an error ("Attempt to access forbidden object") caused by the button search touching protected Blizzard windows.

# 1.8.0

- Minimap buttons without a frame name (e.g. SpellRank) are now collected: buttons on the edge of the minimap are recognized by their position, Blizzard's own minimap parts are still left alone. Their name is taken from their tooltip.
- New buttons are noticed the moment an addon creates them or moves them to the minimap. The background check now only runs every 10 seconds, which uses fewer resources.
- The version is shown in the button tooltip and in the options, and with /amb version.
- Version check in party/raid: if someone in your group has a newer version, you get a hint in chat to update. /amb version also lists the versions of your group members.
- /amb ignore now also works with the shown name of a button.

# 1.7.0

- Much more reliable button detection: buttons that an addon creates or shows later (even minutes after login) are now picked up automatically, without having to open the menu first.
- Buttons that are attached to the screen but placed on the minimap (e.g. Guild Roster Manager) are now collected too.
- Buttons with unusual or missing frame names are recognized by their addon icon.
- Load-on-demand addons and late LibDBIcon registrations are handled.
- A single faulty button from another addon can no longer stop the whole scan.
- Entries are named after the addon they belong to where possible.
- Warning in chat if another minimap button collector (e.g. MinimapButtonButton) is active.

# 1.6.1

- Translations reviewed and improved (Korean, Chinese, Russian, Portuguese, Spanish, Italian, French).
- Separate wording for Mexican Spanish.
- The custom icon hint in the options now wraps instead of overlapping the slider next to it.

# 1.6.0

- Translated into all WoW client languages: English, German, French, Spanish (EU/MX), Italian, Brazilian Portuguese, Russian, Korean, Simplified and Traditional Chinese.
- Localized addon description in the addon list.

# 1.5.2

- WoW Forever support (Interface 16001).
- Fixed an error spam on clients without the MouseIsOver function.
- More Blizzard minimap frames on modern clients are left alone.

# 1.5.0

- 12 bundled fonts (SIL Open Font License), also registered with SharedMedia.

# 1.4.0

- Brighter logo with a glow, adjustable button size.
- Fixed buttons from Method Raid Tools.

# 1.3.0

- Own logo and a choice of icons for the anchor button.

# 1.2.0

- Themes, SharedMedia support and an options window with live preview.

# 1.1.0

- Tooltip texts shown directly in the list, resizable menu.

# 1.0.0

- First release.
