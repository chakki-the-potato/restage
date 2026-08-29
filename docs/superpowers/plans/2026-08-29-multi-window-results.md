# Several windows of one app — results

Measured 2026-08-29.

Up front: **a workspace can now hold more than one window of the same app, and
each one lands in its own slot.** Capture no longer throws windows away, and a
run never places two items onto the same window.

## What was broken

**Capture dropped windows it could not name.** Windows of one app whose titles
were identical or empty were discarded outright — only the first survived. A
real capture lost three Claude windows and three Chrome windows this way. The
count of what had been dropped was reported, which was honest and useless: there
was no way to get the windows back.

**Two items moved the same window.** Writing an app twice by hand was worse than
losing a window. The only selector was "most recently active", so both items
asked the same question and both got the same answer. The first placement was
overwritten by the second, and one slot was left empty.

**A browser with nothing open was demoted to a plain app.** Capture turned a
browser window with no URLs into an app item, and an app item has no place to
put a URL later. `dev.yaml`'s Safari had been captured in exactly that state,
which is why it sat there "not opening its URL" — there was no URL in the file
to open.

## What shipped

**A run remembers the windows it has already taken.** `WindowClaims` holds a
`Set<AXUIElement>` — `AXUIElement` is `Hashable`, so this works with no
identifier of our own — and the window waiter skips anything already claimed.
The second item for an app therefore gets the second window.

**Same app serial, different apps concurrent.** Items are grouped by app.
Within a group they run one at a time, titled windows first, so the named ones
claim their match before the unnamed ones take whatever is left. Groups still
run against each other concurrently, so nothing got slower.

**Capture numbers instead of dropping.** Every window is kept. Windows that
titles cannot tell apart show as `Cursor 1`, `Cursor 2` in the editor and in the
list. A run places them in that order, so the number is a fact rather than a
label. Clicking the name in the editor brings that window forward.

**A browser stays a browser.** A window with only a start page is captured as a
browser with no URLs rather than demoted to an app. The editor reports which
browsers came in empty; clicking the URL count opens a field to fill in, and
"Web" mode adds a browser with pasted addresses.

## What still cannot be done

**Two windows of one app on different desktops.** Both cannot be reached in one
run. Activating an app does not switch desktops while the app already has a
window on the current one, so the window on the other desktop stays outside
accessibility's view — and the follow-and-return path from
[desktop-gathering-results](2026-08-25-desktop-gathering-results.md) only
triggers when *none* of the app's windows are here. Reproduced with Terminal and
with Dictionary.

## An aside from testing the editor

`ImageRenderer` will not draw AppKit-backed SwiftUI controls — a `ScrollView`, a
segmented `Picker`, a `TextField` all come out as striped placeholders, which is
most of the draft editor. An `NSHostingView` in an off-screen `NSWindow` drawn
with `cacheDisplay(in:to:)` renders them, and still needs no screen recording
permission. Written up in [findings](../../findings.md).

## Numbers

```
before   3 Claude windows, 3 Chrome windows dropped by capture
         two items for one app → one window moved twice, one slot empty

after    every window kept, unnamed ones numbered in placement order
         two Safari windows written as q1, q2:
           0,33    864x514
           864,33  864x514
```
