# dmgbuild settings (https://dmgbuild.readthedocs.io/), invoked from
# build-app.sh.
#
# Replaces an earlier approach that drove Finder live via AppleScript
# (mount a writable image, set background/positions, `hdiutil convert` to
# the final compressed .dmg). That worked for icon positions — plain
# stored coordinates — but not the background picture: Finder's
# "background picture" property is backed by a classic Alias Manager
# record tied to the writable volume's identity, which `hdiutil convert`
# doesn't preserve, so the reference silently failed to resolve on the
# distributed .dmg while the file itself was still sitting right there on
# disk. Confirmed directly: mounted the final compressed .dmg and found
# both `.background/background.png` and `.DS_Store` present and correct,
# just not rendering — an alias-resolution failure, not a missing-file one.
#
# dmgbuild sidesteps this entirely: it writes the .DS_Store's background
# and icon-position records itself (via the `ds_store`/`mac_alias`
# libraries), directly into the image it's building, rather than trusting
# a live Finder session's alias to survive a later conversion step.

import os.path

application = defines.get("app")
background_image = defines.get("background")
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}

# Matches the window size the background image (660x400) was designed
# for, plus room for the title bar.
window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_icon_preview = False
show_status_bar = False
show_tab_view = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 12
background = background_image

icon_locations = {
    appname: (154, 238),
    "Applications": (474, 238),
}
