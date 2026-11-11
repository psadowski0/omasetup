# no-screensaver

no-screensaver is an independent module in [Omasetup](../../README.md). It runs
on its own and does not need the Omasetup app.

## What is it?

no-screensaver turns off the Omarchy screensaver. When the screen is idle,
Omarchy will not start its text screensaver. The screen still locks after the
lock timeout, so the machine is not left unlocked.

This is the same switch as **Screensaver Off** in the Omarchy menu. If you turn
the screensaver off there, this module reports that it is already off.

## Why would I want it?

The Omarchy screensaver fills every monitor with a terminal animation. Some
people prefer the screen to go straight to the lock screen, or to stay visible
while the machine is idle. This module leaves the lock timeout alone and only
stops the screensaver.

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/no-screensaver/no-screensaver link
```

Then run `no-screensaver enable`. No sudo is needed.

## Use

```bash
no-screensaver enable     # Turns the Omarchy screensaver off.
no-screensaver status     # Shows whether the screensaver is off.
no-screensaver verify     # Checks that the screensaver is off and this module manages it.
no-screensaver disable    # Turns the screensaver back on.
```

The change applies immediately. There is no logout and no reboot.

You can run `enable` and `disable` more than once.

## How it works

Omarchy's menu has a **Screensaver Off** switch. It sets one flag file:

```text
~/.local/state/omarchy/toggles/screensaver-off
```

While that file exists, `omarchy-launch-screensaver` exits before it starts a
terminal. Omarchy's idle service still runs, and the lock timer still fires at
the time in `~/.config/omarchy/shell.json`.

no-screensaver writes the same file, with a comment that marks it as this
module's. It does not edit `shell.json` and it does not change
`idle.screensaver` or `idle.lock`.

If the screensaver was already off before you enabled the module, the module
remembers the original file and puts it back when you disable the module. It
does not turn the screensaver back on in that case.

## Tested in the real world

Tested on 11 November 2026 on real hardware: Framework Laptop 13, Omarchy
4.5.0-3, Hyprland 0.56.2. A disposable sandbox ran 85 checks, and the live
session was checked with `omarchy-toggle-enabled` and
`omarchy-launch-screensaver`. Every check passed. The [test log](docs/testing.md)
lists each check.

## Good to know

- No sudo, no background service, and no edit to `/usr/share/omarchy`.
- The lock timeout is unchanged. The screen still locks.
- The module does not kill a screensaver that is already running. It stops the
  next one from starting. This matches the menu.
- If you use the menu to turn the screensaver back on, the module's flag is
  removed and `no-screensaver status` reports that the module is off.
- `no-screensaver disable` removes only the flag it wrote. It refuses to remove
  a flag it did not create.
- If you also set `idle.screensaver` to `0` in `shell.json`, the screensaver
  stays off after `disable`; this module only manages the menu toggle.
- Omarchy updates and `omarchy refresh` do not remove the flag, because it lives
  in your state directory.

## Update

Run this command to get the latest version:

```bash
no-screensaver update
```

## Remove

Run this command to remove everything:

```bash
no-screensaver disable && no-screensaver unlink && rm -rf ~/.local/share/omasetup
```

## More

- [Full test log](docs/testing.md) lists every check and the evidence behind it.
- [Omasetup](../../README.md) explains the project that hosts this module.
- [Contributing](../../CONTRIBUTING.md) explains how to add a module.
- Omasetup uses the MIT license; see [LICENSE](../../LICENSE).
