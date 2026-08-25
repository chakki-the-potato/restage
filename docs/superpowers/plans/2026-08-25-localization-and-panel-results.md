# Two languages and a redesigned panel — results

Measured 2026-08-25.

Up front: **every string the user sees moved into en/ko catalogues, and the menu
bar panel was rebuilt around what a workspace contains.** 264 string literals
moved; English is the base language.

## Choosing how to localize

**String Catalogs do not work here.** `swift build` copies a
`Localizable.xcstrings` verbatim instead of compiling it — only Xcode compiles
them. Verified by building a throwaway package: the file appeared in the bundle
untouched and no `.lproj` was produced. Classic `.lproj/Localizable.strings`
compiles and resolves, so that is what ships.

**`String(localized:)` cannot be used either.** It only sees the language fixed
when the process started, so honouring a language chosen inside the app would
need a restart. `L10n` opens the chosen `.lproj` bundle directly, which changes
immediately.

**English is the base.** A key missing a translation falls back to English, and
with English missing too, to the key itself. A raw key on screen makes the gap
obvious at once.

**Two guards, both tests.** Key sets must match across languages, and format
specifiers must match position for position — `%1$@ … %3$d … %2$d` reordered in
Korean is normal, a missing one crashes. A CI step rejects any Korean string
literal left in the source.

## Three bundle bugs, one cause

The installer and the formula symlink `bin/restage` into the app bundle. Run
through that link, `Bundle.main` points at the folder holding the link. Three
things broke and none of them showed up locally, because locally the binary was
run by its real path.

```
resource bundle not found  →  Bundle.module killed the process on the first string
Info.plist not found       →  the version fell back to "dev"
no bundle identifier       →  UserDefaults read a different domain than the app
```

The first killed `restage --version` outright for anyone who installed it. All
three are avoided by resolving the executable's symlink and looking beside it
and in the bundle's `Resources`. CI now runs the binary through a symlink and
checks the version it prints.

**The version was wrong for everyone anyway.** `make-app.sh` defaulted to
`0.1.0` and neither the formula nor the installer passed `RESTAGE_VERSION`, so
every installed app believed it was 0.1.0 and the update check always claimed a
newer version existed. A real version must never be the default; it now falls
back to the latest tag, and to `0.0.0` where git is absent.

## What the panel shows

The old card showed the same glyph three times and a subtitle reading
`화면 1 · 항목 2`. Neither says what the workspace holds.

**App icons, up to three, then `+N`.** Capped so the width is fixed — otherwise
the name starts at a different place on every row and the list wobbles.

**The shape of the arrangement.** `LayoutShape` reads it from the config that is
already there — left & right, quarters, N panes — drawn as a glyph and named.
The display count is appended only when there is more than one, so the common
case stays quiet.

**The shortcut chip and the management buttons share one slot.** Both at once
pushed the name sideways on every hover.

**States that say what to do next.** The empty state is the first thing a new
user sees; the permission banner got a real button and a line explaining why.
Progress counts items, because the runner reports per item and a screen-level
count means nothing when there is one screen.

## Appearance

`NSApp.appearance` reaches windows made afterwards but not windows that already
exist:

```
after setting app.appearance:  app.effective = DarkAqua
                               existing window.effective = Aqua
                               a window made afterwards = DarkAqua
```

The panel is made once and reused, so it kept the old appearance until reopened.
It is pushed onto open windows too. macOS calls this "화면 모드" in Korean —
taken from the system's own translation table rather than invented.

## Seeing the panel without a screen

The menu bar popover cannot be captured without Screen Recording permission,
which left the redesign unverified by eye. `ImageRenderer` draws the real
SwiftUI views to a PNG with no window and no permission:

```
RESTAGE_SNAPSHOT_DIR=/tmp/shots swift test --filter renderPanel
```

It immediately found two things that were wrong: `ProgressView(value:)` and
`.buttonStyle(.link)` are AppKit-backed, so neither the 3pt bar height nor the
colour inside the card came out as specified. Both are drawn directly now. The
README screenshots come from this path, so they cannot drift from the code.
