# restage

**English** · [한국어](README.ko.md)

A macOS tool that restores a declared arrangement of apps and windows in one step.

Instead of opening apps and dragging windows every time you start working, you write it down once.

```yaml
hotkey: "ctrl+alt+cmd+1"
workspace: dev
screens:
  - id: main
    display: builtin
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm,  slot: right-half}
```

```
restage open dev
```

## What it does

- Launches the apps you declared and puts their windows where you said
- Opens browser tabs
- Spreads the arrangement across several displays
- Runs from a menu bar click or a global shortcut

**It doesn't store coordinates.** It stores names like `left-half` and works out the numbers from the screen you have at the time. Change monitors and the config still holds.

**It leaves things alone when they're already right.** Run the same command twice and nothing moves the second time.

**It doesn't touch what you didn't declare.** Apps missing from the config are neither hidden nor quit. Browser tabs you already have open stay open; only missing ones are added.

## Install

**Homebrew**

```bash
brew install chakki-the-potato/tap/restage
open $(brew --prefix restage)/restage.app
```

**Without Homebrew**

```bash
curl -fsSL https://raw.githubusercontent.com/chakki-the-potato/restage/main/install.sh | bash
```

Both fetch the source and build it on your machine. An app you built yourself isn't blocked by Gatekeeper, so there's no "unidentified developer" warning and no right-click-to-open dance.

macOS 13 or later and the Xcode command line tools are required. The install script walks you through it if they're missing.

### Accessibility permission

Moving windows needs Accessibility permission. The app asks the first time you open it.

Turn **restage** on in System Settings → Privacy & Security → Accessibility.

From the terminal, the thing you approve is **the terminal app that ran the command**. If you run it from iTerm, turn iTerm on. Quit the terminal completely and reopen it afterwards.

Without permission it explains what's wrong and stops.

Upgrading may require turning it on again. Free signing changes the app's identity on every build. Getting rid of that needs a Developer ID certificate from the paid Apple Developer Program.

### From source

```bash
git clone https://github.com/chakki-the-potato/restage.git
cd restage
./scripts/make-app.sh          # builds the menu bar app into build/restage.app
swift build -c release         # if you only want the CLI
```

## Creating a workspace

Arrange your windows the way you want them, then run one command.

```bash
restage new dev
```

It reads what you have open and shows it back to you.

```
Read the current window layout.

  main
    1. Safari · Docs        Left half    2 tabs
    2. Safari · Mail        Right half
  external-1
    3. iTerm                Bottom left? [another desktop]

  ? means the position is ambiguous. Press its number to choose one yourself.
[Enter] save   [number] change position   [-number] remove   [+] add an app   [w] add a browser   [q] cancel
```

Press Enter and `~/.config/restage/dev.yaml` is written.

- Browsers are saved **with the tabs they have open.** Start pages and new tabs aren't saved
- An ambiguous position gets a `?`. **It doesn't guess quietly.** Press the number and choose
- Windows on another desktop are saved too, and marked
- If one app has several windows, each is saved and told apart by its title
- Add an app that isn't running with `+`, and a URL that isn't open with `w`
- Positions are stored as names like `left-half`, not coordinates

The menu bar icon's **New from Current Layout** does the same thing. There you pick what to keep with checkboxes and change each position from a dropdown. If an app you want isn't running, type its name in.

The list is from **when the windows were read**. If you moved them since, press **Read Again**.

### Full screen

Choosing **Full screen** instead of a position sends that app to its own desktop. It's the same as "Enter Full Screen" in the macOS window menu.

```yaml
- {type: app, app: Cursor, slot: full, fullscreen: true}
```

A window that was already full screen when captured is saved this way automatically.

### Windows that aren't saved

**Windows that can't be told apart by title aren't saved.** At run time the title is the only handle there is, so if a title is empty or two windows share one, the same window gets picked every time. Saving such an item would look like it worked while doing nothing.

```
3 Claude windows weren't saved. Their titles are identical or empty, so there is no way to tell which window to use.
```

**Minimized windows aren't saved either.** Their position means nothing.

## Writing a config by hand

You can skip `restage new` and write it yourself. Configs live in `~/.config/restage/<name>.yaml`.

```bash
mkdir -p ~/.config/restage
cp examples/dev.yaml ~/.config/restage/
```

`examples/` has a single screen, browser tabs, and a dual monitor setup.

### The full format

```yaml
workspace: dev            # required. the workspace name
hotkey: "ctrl+alt+cmd+1"  # optional. only works while the menu bar app runs

screens:
  - id: main              # required. it appears in the report
    display: builtin      # builtin | external-N | any. defaults to any
    mode: desktop         # desktop | fullscreen. defaults to desktop
    anchor: cursor        # optional. the app to focus after this screen
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm,  slot: right-half}

  - id: web
    display: external-1
    items:
      - type: browser
        app: safari
        window: separate  # separate | shared. defaults to separate
        slot: full        # optional. without it the window size is left alone
        tabs:
          - https://example.com
          - https://example.org
```

### slot

`full`, `left-half`, `right-half`, `top-half`, `bottom-half`, `q1`–`q4`, `centered`

The quadrants follow reading order: `q1` top left, `q2` top right, `q3` bottom left, `q4` bottom right.

Omitted on `type: app` it means `full`. Omitted on `type: browser` the window size is left alone.

### display

- `builtin` — the primary display
- `external-N` — an external display. Sorted by frame origin, then the Nth (from 1)
- `any` — the primary display. Behaves like `builtin` today

Naming a display that isn't connected skips that screen and reports why.

### Apps with several windows

Use `title` to say which window to move. Part of the window title is enough.

```yaml
items:
  - {type: app, app: safari, slot: left-half,  title: Start Page}
  - {type: app, app: safari, slot: right-half, title: Work}
```

Without it, the most recently active window is used.

### App names

**Any installed app works.** Write the name as Finder shows it.

```yaml
- {type: app, app: Figma,           slot: left-half}
- {type: app, app: Microsoft Word,  slot: right-half}
- {type: app, app: KakaoTalk,       slot: q4}
```

Case doesn't matter, and short names are understood. `chrome` means `Google Chrome`, `edge` means `Microsoft Edge`. An exact match always wins.

If a name matches several apps it stops and tells you the candidates.

```
More than one app matches 'microsoft': Microsoft Edge, Microsoft Word
```

If nothing matches it suggests something close.

```
There is no app installed named 'Noton'. Did you mean: Notion
```

## Usage

```bash
restage new dev               # create one from the current layout
restage open dev              # by name
restage open ./my.yaml        # by path
restage list                  # saved workspaces
restage menubar               # run in the menu bar
```

`restage open` prints a table of what happened.

```
SCREEN   APP      RESULT            EXPECTED         ACTUAL           NOTE
main     safari   placed            0,33 864x1027    0,33 864x1027
main     notion   alreadySatisfied  864,33 864x1027  -                Already where it should be
```

| Result | Meaning |
|---|---|
| `placed` | It was placed |
| `alreadySatisfied` | Already where it should be, so nothing was touched |
| `constrained` | The app refused. Minimum size, fixed size, no full screen support |
| `unreachable` | The window is on another Space and can't be reached |
| `failed` | Anything else |
| `skipped` | A skipped screen or an unsupported feature |

One failed item doesn't stop the rest; the failures are listed with their reasons at the end.

## Menu bar and shortcuts

```bash
restage menubar
```

Clicking the menu bar icon opens a panel. Clicking a card runs it.

A card shows what's inside the workspace: up to three real app icons overlapped in front, counted as `+2` beyond that, and under the name the shape of the arrangement as a small drawing plus its name. How many displays it uses is only spelled out when there's more than one.

- Hovering reveals the **shortcut slot**, **Edit**, and **More**
- A card without a shortcut only shows its dashed slot on hover. Click it to set one
- **More** has Rename, Change Shortcut, Reveal in Finder, and Delete
- To set a shortcut, just press the combination you want. Only the `hotkey` line of the config changes
- Delete asks first, then moves the file to the Trash
- While it runs, the card says which app it's opening and how far along it is
- On failure the card carries the reason and a **Retry**
- An app named in the config that isn't installed is drawn as a dashed placeholder with the reason underneath

The **gear** at the top right holds Open at Login, **Check for Updates**, Open Config Folder, and Quit.

A shortcut another app already owns won't register. The card says so.

### Language

The panel and the terminal both speak English and Korean. It follows the system language by default, and **Auto · 한국어 · English** under the list overrides it. The change is immediate — no restart.

The terminal follows the same setting.

```bash
restage list
```

### Editing

The pencil on a card opens the same window you saw when creating it. Remove items or change positions and save. To read the YAML itself, use **Reveal in Finder** from More.

Building the app bundle lets you launch it from Finder and open it at login.

```bash
./scripts/make-app.sh
open build/restage.app
```

**The app bundle needs its own Accessibility approval.** Once given, it sticks.

`make-app.sh` finds and uses a code signing certificate from your machine. Signing with a certificate is what keeps the approval across rebuilds. macOS ties the approval to the designated requirement, and the two forms differ.

```
adhoc         designated => cdhash H"f3b2..."
certificate   designated => identifier "com.chakki.restage" and anchor apple generic
                            and certificate leaf[subject.CN] = "Apple Development: ..."
```

Adhoc is tied to the code hash, so recompiling the same source changes the identity and drops the approval.

Signing into Xcode with an Apple account gives you a free Apple Development certificate. The paid Developer ID is for distributing to other people (notarization); a free certificate is enough for your own machine. With no certificate at all it signs adhoc and warns.

`RESTAGE_SIGN_IDENTITY` can name an identity explicitly.

If the menu bar icon isn't visible, check the hidden area of a menu bar manager like Hidden Bar. Those tools hide items by pushing them off-screen.

## Known limits

Most of these are things macOS doesn't allow.

**Windows can't be placed on a specific desktop (Space).** There's no public API. `mode: fullscreen` is the way around it — macOS makes a dedicated Space for you.

**Full screen is one-way.** It can be entered but not left. A full screen app's window moves to its own Space and there's no way to switch to it. Leave it by hand with `ctrl+cmd+F`.

**Handling windows on another desktop needs one setting.** Left alone they're reported as `unreachable`.

Moving a window to another desktop works through neither the public nor the private API. The window server's private functions were called directly to check, and they're silently ignored for other apps' windows. That's why tools like yabai ask you to partially disable SIP. The measurements are in [space-placement-results](docs/superpowers/plans/2026-08-25-space-placement-results.md).

The way around it is to go to that desktop instead.

System Settings → Desktop & Dock → **"When switching to an application, switch to a Space with open windows for the application"**

With it on, `restage` activates the app, follows it to that desktop, and places the window. Measured:

```
0 AX windows before activating  →  set AXFrontmost  →  2 after
```

A Safari window that was full screen on another Space was placed correctly this way. The cost is that ordinary app switching also jumps between desktops. It's a matter of taste.

To undo it:

```bash
defaults delete com.apple.dock workspaces-auto-swoosh && killall Dock
```

**Some apps enforce a minimum size.** Xcode won't go under 940 wide, KakaoTalk under 640 tall. Those are reported as `constrained`.

**Browser tab order is only exact on the first run.** Tabs added later go to the end of the window. Guaranteeing the order would mean closing the tabs you already have, which throws away your work, so it doesn't.

**Firefox and its relatives can't be driven.** They don't expose a tab control vocabulary. Window placement works; `tabs` is reported as a failure.

Safari and the Chromium family (Chrome, Edge, Brave, Arc, Whale, Vivaldi) take the same path. **Safari, Chrome, and Brave were verified.** Edge, Arc, Whale, and Vivaldi run the same code but weren't checked.

Browser tab control needs Apple Events permission once per target app.

**It doesn't work while the screen is locked.** The accessibility API can't list windows then. `restage` detects this, says so, and stops.

## Development

```bash
swift build
swift test        # 205 tests
```

There's a harness for checking placement.

```bash
restage probe --slot left-half
```

It measures the placement success rate against the apps you have running. By default it quits nothing.

Add `--cold` to include a cold start. That **force quits** the target app, so `--app` must name exactly one, and it asks before running.

```bash
restage probe --app Safari --cold
```

Rendering the panel to a PNG, without a screen or any recording permission:

```bash
RESTAGE_SNAPSHOT_DIR=/tmp/shots swift test --filter renderPanel
```

### Repository layout

```
Sources/RestageKit/         OS-independent schema, validation, geometry, and the translations
Sources/RestageKitDarwin/   AX, AppKit, and AppleScript implementations; installed app lookup
Sources/restage/            the CLI and the menu bar
Sources/RestageBrand/       the shapes behind the app and menu bar icons
Sources/restage-icon/       a build tool that bakes the .iconset. Not part of the bundle
docs/superpowers/           design specs and measurements
```

`docs/` holds design decisions and measurements taken during development. It isn't a manual — it records why things are built the way they are and how macOS actually behaves. It may help someone hitting the same walls.

## License

MIT. See `LICENSE`.
