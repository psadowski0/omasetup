# natural-scroll

natural-scroll is an independent module in [Omasetup](../../README.md). It runs
on its own and does not need the Omasetup app.

## What is it?

natural-scroll makes the touchpad scroll the way a phone or a Mac does: when you
move two fingers up, the page moves up with them. Omarchy ships with the
opposite direction, which is common on Windows laptops.

The mouse wheel is left alone. Only the touchpad changes.

## Why is the default the other way?

Hyprland, the window manager Omarchy uses, sets `natural_scroll = false` in
`/usr/share/omarchy/default/hypr/input.lua`. That is a legitimate default, not a
bug. This module flips it for people who prefer the other direction.

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/natural-scroll/natural-scroll link
```

Then run `natural-scroll enable`. No sudo is needed.

## Use

```bash
natural-scroll enable     # Turns natural scrolling on.
natural-scroll status     # Shows whether the touchpad scrolls naturally.
natural-scroll disable    # Returns the touchpad to the default direction.
```

The change applies immediately. There is no logout and no reboot.

You can run `enable` and `disable` more than once.

## How it works

The module writes one small file:

```text
~/.local/state/omarchy/toggles/hypr/natural-scroll.lua
```

```lua
-- omasetup: natural-scroll
-- Make the touchpad scroll naturally. The mouse wheel keeps its direction.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})
```

That directory is Omarchy's documented place for permanent configuration flags.
Omarchy loads every `*.lua` file in it on each config reload, after your own
config in `~/.config/hypr`. The file is new; no existing file is edited.

Because the file lives in your state directory, it survives `omarchy refresh
hyprland` (which only overwrites `~/.config/hypr`) and it survives Omarchy
updates.

After writing the file, the module runs `hyprctl reload` and then reads the
setting back with `hyprctl getoption input:touchpad:natural_scroll`. If Hyprland
did not pick it up, the module removes the file again and reports the problem
instead of leaving you with a setting that silently does nothing.

## Tested in the real world

Tested on 8 November 2026 on real hardware: Framework Laptop 13, Omarchy
4.5.0-3, Hyprland 0.56.2. A disposable sandbox ran 32 checks, and the live
session was checked with `hyprctl`, and the direction was confirmed by hand on
the real touchpad. Every check passed. The [test log](docs/testing.md) lists
each check. The module is left on.

## Good to know

- The touchpad only. The mouse wheel keeps its traditional direction.
- No sudo, no boot image rebuild, and no background service.
- The other touchpad defaults stay as Omarchy set them: tap-to-click, two-finger
  right-click, the 0.4 scroll speed, and disable-while-typing.
- If you set a scrolling option yourself in `~/.config/hypr/input.lua`, the
  module overrides it while it is on. `natural-scroll disable` returns your own
  setting.
- `natural-scroll disable` removes only the file it wrote. It refuses to delete
  a file it did not create.

## Update

Run this command to get the latest version:

```bash
natural-scroll update
```

## Remove

Run this command to remove everything:

```bash
natural-scroll disable && natural-scroll unlink && rm -rf ~/.local/share/omasetup
```

## More

- [Full test log](docs/testing.md) lists every check and the evidence behind it.
- [Omasetup](../../README.md) explains the project that hosts this module.
- [Contributing](../../CONTRIBUTING.md) explains how to add a module.
- Omasetup uses the MIT license; see [LICENSE](../../LICENSE).
