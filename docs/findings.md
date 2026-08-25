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

The way around it is to make macOS go to that Space instead. With System
Settings → Desktop & Dock → "When switching to an application, switch to a Space
with open windows for the application" turned on:

```
0 AX windows before activating  →  set AXFrontmost  →  2 after
```

**Focus needs the AX path.** `NSRunningApplication.activate()` is ignored by
macOS when the caller is not a GUI app. Only setting `AXFrontmost` works.

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
