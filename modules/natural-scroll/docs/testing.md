# Test log

natural-scroll was tested on real hardware on 8 November 2026. It was tested in
a disposable sandbox first and then on the real machine, with the real Hyprland
session.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland 0.56.2 on Wayland |
| Touchpad | `pixa3854:00-093a:0274-touchpad` |
| Desktop theme | Vantablack |

## How it was tested

1. A disposable sandbox. `HOME`, `XDG_STATE_HOME`, `PATH`, and `OMARCHY_PATH`
   pointed at a temporary directory, with a fake `hyprctl` that reports the
   runtime value from the presence of the toggle file. The real system was never
   touched.
2. The real session. The module ran against the live Hyprland instance and the
   setting was read back with `hyprctl getoption`.

## Sandbox results

| Check | Result |
|---|---|
| `status --quiet` is silent and fails before enable | Passed |
| `enable` installs the toggle file | Passed |
| The toggle file starts with the module marker | Passed |
| The toggle file turns natural scrolling on | Passed |
| The setting is scoped to the touchpad | Passed |
| The file sets only the touchpad, leaving the mouse wheel alone | Passed |
| `enable` is idempotent | Passed |
| `status --quiet` succeeds while enabled | Passed |
| `status` reports the touchpad on | Passed |
| `status` reads the runtime value | Passed |
| `status` reports the module on | Passed |
| `disable` removes the toggle file | Passed |
| `status --quiet` fails after disable | Passed |
| A second `disable` is safe | Passed |
| Omarchy's toggle directory is kept | Passed |
| `disable` refuses a file it did not write | Passed |
| The foreign file is left in place | Passed |
| `disable` refuses a symlink | Passed |
| The symlink is left in place | Passed |
| `enable` works without Hyprland running | Passed |
| `enable` says the setting applies at the next login | Passed |
| `status` explains that Hyprland is not running | Passed |
| `disable` works without Hyprland running | Passed |
| `enable` rolls back when Hyprland ignores the setting | Passed |
| The rollback removed the toggle file | Passed |
| `enable` still succeeds when the reload fails | Passed |
| The toggle file is installed when the reload fails | Passed |
| `enable` refuses a non-Omarchy system | Passed |
| Nothing is written on a non-Omarchy system | Passed |
| `enable` writes nothing outside the toggle directory | Passed |
| `disable` writes nothing outside the toggle directory | Passed |
| The command runs as a normal user | Passed |

32 checks, 0 failed.

## Real-system results

| # | Check | Result |
|---|---|---|
| 1 | Before enabling, Hyprland reported `natural_scroll` as false | Passed |
| 2 | `natural-scroll enable` exits 0 | Passed |
| 3 | The toggle file exists with the expected content | Passed |
| 4 | Hyprland reports `natural_scroll` as true | Passed |
| 5 | `scroll_factor` is still 0.4 | Passed |
| 6 | `clickfinger_behavior` is still true | Passed |
| 7 | `hyprctl configerrors` reports no errors | Passed |
| 8 | `status` reports the module on and the runtime on | Passed |
| 9 | `disable` reports the touchpad off | Passed |
| 10 | Hyprland reports `natural_scroll` as false after `disable` | Passed |
| 11 | `status --quiet` exits 1 after `disable` | Passed |
| 12 | `enable` again reports true and stays enabled | Passed |
| 13 | `~/.config/hypr/input.lua` was not modified | Passed |
| 14 | The other toggle files are untouched | Passed |
| 15 | No sudo was needed at any point | Passed |

## What the tests show

- The setting applies immediately, with no logout and no reboot.
- The other touchpad options keep Omarchy's values. The partial `hl.config`
  merges instead of replacing the `touchpad` table.
- The mouse wheel is not affected.
- The file is the only thing the module adds.
- Removing the module returns the touchpad to the default direction.

## The feel

The direction was confirmed by hand on the real touchpad: two-finger scrolling
now moves the content the way a phone does. The mouse wheel keeps the
traditional direction.
