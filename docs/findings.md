# Findings

Things measured on real machines while building restage. None of this is
recoverable by reading the code, so it is written down here.

## Window placement

**Placement is applied position → size → position.** Applying size first clamps
the window to the display it is still on. The first position moves it onto the
target screen, size is applied, and the second position corrects the drift that
applying size caused. On a single display this is equivalent to a two-step
apply.

**Xcode enforces a minimum width without exposing it.** Reading `AXMinSize`
returns -25205 (attribute unsupported), yet the width never goes below 940. The
height changes as asked, so it is not refusing to resize. The signal used to
detect this class of app is "one axis landed as asked while only the other is
pinned larger than asked". KakaoTalk enforces a 640 height the same way.

**Electron apps show a splash first.** Discord opens a fixed 300x300 window on
launch and swaps it for the real 1280x870 window a moment later, within 3
seconds. Requiring the candidate window to be resizable is what avoids catching
the splash and reporting a move with a failed resize.

**Some apps build no AX window tree until they are frontmost.** Safari does
this: `AXWindows` returns an empty array while the window is open and visible.
The fallback is to activate the app once after a grace period and keep polling.
Activating from the start makes apps fight over focus mid-run.

**Some apps have nothing but fixed-size windows.** IINA's start window is one.
Returning nothing there would report "no windows", so the window is handed over
anyway and the placement step reports `constrained` with the size limit.

## Spaces

**A window cannot be moved to another Space.** Neither the public nor the
private API does it. `CGSMoveWindowsToManagedSpace` was called directly and is
silently ignored for other apps' windows. That is why tools like yabai ask for
SIP to be partially disabled. Full measurements are in
[2026-08-25-space-placement-results](superpowers/plans/2026-08-25-space-placement-results.md).

**Sending the view to a Space does work.** `CGSManagedDisplaySetCurrentSpace` is
a different private call from the one that moves windows, and it is not refused.
It takes a connection, a display identifier and a Space id, all of which
`CGSCopyManagedDisplaySpaces` hands over. Measured 2026-08-30 with Dictionary's
only window in a full screen Space of the main display, the view on the desktop:

| what was tried | view moved | AX windows after |
|---|---|---|
| `AXFrontmost` | no | 0 |
| `NSRunningApplication.activate()` | no (returned true) | 0 |
| `NSWorkspace.openApplication(activates: true)` | no (no error) | 0 |
| `AXRaise` | nothing to raise | 0 |
| `CGSManagedDisplaySetCurrentSpace` | **yes** | **2** |

None of the public calls move the view, so restage sends it with the private
one and puts it back at the end of the run. If the symbol ever goes missing,
`dlsym` returns nothing and the old behaviour — report the reason and stop — is
what happens.

**"On another desktop" was mostly wrong.** The count came from subtracting the
on-screen window count from the total, which counts anything `CGWindowList`
reports and is not on screen. Most of those belong to no Space at all. Measured
on an ordinary session, every window the old rule called "another desktop":

```
Google Chrome                spaces=[]  at -283,-1501
Open and Save Panel Service  spaces=[]  at 0,617
OpenUsage                    spaces=[]  at 0,617
UserNotificationCenter       spaces=[]  at 0,617
loginwindow                  spaces=[]  at 0,617
메모                          spaces=[]  at 0,617
자동 완성                     spaces=[]  at 0,822 / 0,880 / 1234,708
Shottr                       spaces=[1] at 446,310   the current Space, app hidden
```

Not one of them was on another desktop. Save panels, autocomplete popups, the
notification centre and `loginwindow` have no Space, and no amount of switching
makes them appear. `CGSCopySpacesForWindows` answers the question directly, so
that is what decides now: no Space or off every display means it is not a window
to place, the current Space means here, anything else means another Space.

**Failing fast is most of the speed.** Before the Space read went in, the
three cases were told apart with `CGWindowList` alone: on screen but invisible
to AX meant the window was here and the app needed activating (Safari), nothing
on screen with windows somewhere meant another Space, nothing at all meant the
app was still starting. Reporting the middle case at once instead of waiting out
the 15s timeout, and stopping placement retries once a window holds the same
frame twice, took a ten-app workspace from 50.8s to 2.8s warm and from about 48s
to 5.7s cold. The rule that replaced it answers the same question from the Space
list rather than by subtraction.

**The setting is not what makes following work.** The note that used to stand
here credited `com.apple.dock workspaces-auto-swoosh`. On the machine where
following was measured that key was 1 while the one that governs it,
`AppleSpacesSwitchOnActivate` in `NSGlobalDomain`, was 0. Turning the latter on
with `defaults write` changed nothing for `AXFrontmost` or `activate` — though
that was without logging out, so the setting cannot be ruled out entirely.

The ten-app run that gathered eight apps was on a day when the main display had
three Spaces; the display had one when this was re-measured. What that run
actually followed was never established, and given the paragraph above some of
its "other desktop" items were likely the miscount rather than real Spaces.

**Focus needs the AX path.** `NSRunningApplication.activate()` is ignored by
macOS when the caller is not a GUI app. Only setting `AXFrontmost` works.

**Two windows of one app split across desktops cannot both be reached.**
Activating the app does not switch desktops when it already has a window on the
current one, so the other window stays out of accessibility's sight. Within one
desktop, several windows of one app are told apart by remembering which
`AXUIElement`s this run has already placed; `AXUIElement` is `Hashable`, so a
`Set` of them works. Measured: two Safari windows listed twice landed in q1 and
q2.

**Leaving full screen works while the window is reachable.** Setting
`AXFullScreen` to false returns the window to the desktop. What cannot be done
is clearing it from another Space, because accessibility does not see the window
there at all.

**A window can be closed to full screen on every route.** TextEdit's document
window on macOS 26 says no three times over:

```
AXFullScreen           present, settable = false
AXFullScreenButton     -25212, and AXZoomButton the same — no buttons at all
View > Enter Full Screen   AXEnabled = false
```

The window's only action is `AXRaise`. The menu item was found by its shortcut
(Fn+F, `AXMenuItemCmdModifiers` 24) and pressed; `AXPress` returned success and
nothing happened, because pressing a disabled item does nothing. Opening the
parent menu first made no difference, and neither did shrinking the window to a
half so it was not already filling the screen.

So `constrained` with "this window doesn't support full screen" is the correct
report, not a misjudgement — it is repeating what macOS says. A menu fallback was
written and measured before being thrown away: there is nothing for it to press.

**Setting `AXFullScreen` can succeed and do nothing.** Dictionary went full
screen through a direct `AXUIElementSetAttributeValue` earlier in the same
session; later the identical call still returned `.success` while no Space
appeared and the window kept its frame. It started refusing once the main display
already held three Spaces, but the cause was not established. The two outcomes
are reported apart: the write failing is "the switch didn't finish", the write
succeeding with nothing happening is "macOS did not accept the switch".

## Browsers

**Brave silently ignores the loop form.** Walking windows with `repeat` and
appending to `tabs of w` raises no error and creates no tab — it reports success
having done nothing. `tell window id` works in Brave, Chrome, and Safari alike.

**`tab` means the browser's class inside a `tell` block.** Building a tab
separator inside the block puts the literal string "tab" where the separator
should be and every parse fails. The separator has to be built outside the
block.

**Titles cannot pair an AX window with an AppleScript window.** The two APIs
give the same window different titles:

```
AppleScript(name of w):  "(15) Some Video Title - YouTube 🔊"
AX(AXTitle):             "(15) Some Video Title - YouTube - Chrome"
```

Chrome appends a speaker mark when sound is playing and adds the app name to the
AX title; neither string is a prefix of the other. Three Safari windows also
shared the title "Example Domain". The enumeration order differs too — AX is
most-recently-active, AppleScript is not. `bounds`, on the other hand, matches
AX's position and size exactly, so coordinates are what pair them.

**There is no reliable "is this a browser" signal.** Asking the system who can
open https caught iTerm and ChatGPT alongside Chrome, Safari, and Chromium.
Checking `CFBundleDocumentTypes` for an html viewer was worse: Safari dropped
out and iTerm came in. The check only filters; the verdict is whether reading
tabs actually succeeds.

**A new browser window is not guaranteed to come to the front.** Confirmed in
Safari. The caller has to find the window again by its first tab URL.

## Finding installed apps

**Spotlight sweeps too widely.** On one machine the standard locations held 109
apps and a full Spotlight query 388 — the difference is helper apps living
inside other apps, which nobody calls by name.

## Code signing

**Adhoc signatures break the Accessibility approval on every rebuild.** macOS
ties the approval to the designated requirement, and the two forms differ:

```
adhoc         designated => cdhash H"f3b2..."
certificate   designated => identifier "com.chakki.restage" and anchor apple generic
                            and certificate leaf[subject.CN] = "Apple Development: ..."
```

Adhoc is tied to the code hash, so recompiling identical source changes the
identity. A certificate is tied to the identifier and the certificate, so the
approval survives.

**Homebrew builds cannot sign with a certificate.** It builds in a sandbox with
no keychain access, so a formula install is always adhoc — and every
`brew upgrade` drops the Accessibility approval. Installing through `install.sh`
builds as the user and signs with the certificate.

## The menu bar panel

**`NSPopover` is tied to the status item button.** The menu bar hiding or
appearing closes it, so moving the cursor to the top over a full screen app is
enough to make it vanish. A separate `NSPanel` with `.canJoinAllSpaces`,
`.fullScreenAuxiliary`, and `hidesOnDeactivate = false` does not have that
problem.

**Revealing the menu bar deactivates the app.** Over a full screen app, macOS
returns focus to that app as the menu bar appears, and the panel loses key:

```
windowDidResignKey  menuShowing=false  appActive=false  keyWindow=nil
closePanel
NSApplicationDidResignActiveNotification
```

The deactivation is identical to clicking another app, so it cannot be the
signal. What differs is that nothing was pressed, so the cursor being inside the
menu bar band is what tells them apart.

**`NSApp.appearance` does not reach windows that already exist.** Measured:

```
after setting app.appearance:  app.effective = DarkAqua
                               existing window.effective = Aqua
                               a window made afterwards = DarkAqua
```

The appearance has to be pushed onto open windows as well, or a panel left open
keeps the old one.

**`ImageRenderer` cannot draw AppKit-backed SwiftUI controls.** A `ScrollView`,
a segmented `Picker`, a `TextField`, or a `.link` button comes out as a striped
placeholder. An `NSHostingView` inside an off-screen `NSWindow`, drawn with
`cacheDisplay(in:to:)`, renders all of them and still needs no screen recording
permission.

## Bundles and resources

**`swift build` does not compile String Catalogs.** A `Localizable.xcstrings`
is copied verbatim; only Xcode compiles it. Classic `.lproj/Localizable.strings`
works and is what this project uses.

**Running through a symlink breaks `Bundle.main`.** The installer and the
formula symlink `bin/restage` into the app bundle. Run through that link,
`Bundle.main` points at the folder holding the link, so:

- the resource bundle is not found, and `Bundle.module` kills the process
- `Info.plist` is not found, so the version falls back to `dev`
- there is no bundle identifier, so `UserDefaults.standard` reads a different
  domain than the app

All three are avoided by resolving the executable's symlink and looking beside
it and in the bundle's `Resources`.

**`Bundle.preferredLocalizations(from:)` ignores the user's languages.** Without
`forPreferences:` it returned `en` on a system set to `ko-KR`, because the
argument-less form reads the main bundle's language list and a binary run from
the terminal has an empty one.
