# Gathering windows across desktops — results

Measured 2026-08-25.

Up front: **a workspace now runs even when its windows are scattered across
desktops.** restage cannot move a window between Spaces, so it goes to the
window instead and comes back. Ten scattered apps: nine gathered, 48s → 16.7s.

## What was broken

A ten-app workspace was recorded end to end. The recording showed two problems
that no amount of reading the code would have found.

**The view was stolen for twelve seconds.** At 12s the screen jumped to another
desktop and did not return until 24s. Instrumenting the panel showed why:

```
windowDidResignKey  menuShowing=false  appActive=false  keyWindow=nil
closePanel
NSApplicationDidResignActiveNotification
```

When an app's windows live on another Space, accessibility sees none of them.
The fallback of activating the app — added so Safari would build its window tree
— takes the whole screen to that Space.

**Failures were the expensive part.** A warm run of the same workspace took
50.8s. Not the app launches: the items that could not be reached each waited out
a 15s timeout, and the items an app refused to resize each burned an 8s retry
budget, all of it serial.

## What could not be done

**Moving a window to another Space.** Established the same day in
[space-placement-results](2026-08-25-space-placement-results.md): neither the
public nor the private API does it.

**Split View.** macOS can put two apps in one full screen Space, and the menu
path exists — `Window > Full Screen Tile > Left of Screen`. It was driven
successfully for Notes. Three things stopped it from shipping:

- the menu items carry no `AXIdentifier`, only a localized title, so matching
  them means matching Korean strings that differ on every other system
- a submenu is not populated until its parent is opened, and even with the
  parent opened first, the same sequence worked for Notes and failed for
  Terminal
- tiling the first app raises a picker for the second, which was never driven

One of the three was solved. Two apps behaving differently on the same macOS was
enough to stop.

**Creating a desktop.** There is no API, and even with one, windows could not be
moved onto it. A screen whose display is missing borrows full screen instead:
macOS gives each full screen window its own Space, which is close to the intent
without inventing anything.

## What shipped

**Follow and return.** Where a window is on another Space, restage activates the
app to go there, places the window, and returns. Desktops have no identifier, so
the way back has to be captured first: at the start it records an app whose
windows are *only* on the current desktop. Activating an app whose windows span
several desktops lands somewhere else.

**Rounds, not one pass.** Moving between desktops breaks reachability for
everything else. Un-fullscreening Claude switched the view to its desktop and
Cursor — reachable a moment earlier — was left behind. Placement now runs
concurrently for what is reachable, then follows the rest one at a time, and
repeats while a round still reaches something. Three rounds at most.

**Following is serial.** Done concurrently, apps activate each other in turn and
each one steals the desktop before accessibility can see the previous window.

**Fail fast.** An app whose windows are only on another desktop is reported at
once instead of after 15s. A window that holds the same frame twice is the app
refusing, so the retry budget stops there.

**`whenMissing: fullscreen`.** A screen whose display is not connected used to
be dropped whole, and its apps never opened — the common case of leaving a desk
with two monitors and arriving with one. It now moves to the primary display
with every item full screen. `restage new` writes it for external screens;
hand-written configs default to `skip` and are unchanged.

## Two bugs the measurements exposed

**Fragments counted as windows.** Cursor was reported unreachable while its real
window sat on the current desktop. `CGWindowList` returns twelve entries under
that name:

```
1728x1084  the window
64x64      × 7
2560x30    × 4
```

The filter passed anything taller than 50, so `64x64` counted. Requiring both
sides above 100 and the window to be opaque fixed it, and dropped the run from
32s to 16.7s — most of that time had been spent following windows that were not
there.

**Quantized sizes read as failures.** Terminal resizes in character cells, so it
settled at 867x1015 against a 864x1027 target — 3px wider, 12px shorter. The
existing rule looked for one axis matching exactly while the other was pinned
larger, so neither axis matched and it fell through to `failed`. A window that
stops within 40px of the target on both axes is the app holding its own size.

**Locale grouping in identifiers and measurements.** `L10n.string` passes a
locale to `String(format:)`, so `%d` rendered a pid as `72,743` and a window
size as `867x1,015`. Counts should group; identifiers and dimensions should not.
They are passed as strings now.

## Numbers

```
before                48s, view stolen 12s
after fail-fast       warm 2.8s, cold 5.7s (windows already on one desktop)
after following       32s (scattered across desktops)
after fragment fix    16.7s, 9 of 10 placed
```

The one that does not place is on a second monitor's other desktop. Time with
desktop hops is dominated by the transition animation, which cannot be shortened.
