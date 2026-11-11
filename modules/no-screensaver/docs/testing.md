# Test log

no-screensaver was tested on 11 November 2026 on real hardware and in a
disposable sandbox. The sandbox proves the flag handling and the edge cases; the
real machine proves that Omarchy's own menu toggle and launcher agree with the
module.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland 0.56.2 on Wayland |
| Desktop theme | Vantablack |

## How it was tested

1. A disposable sandbox. `HOME`, `XDG_STATE_HOME`, `XDG_CONFIG_HOME`, and
   `XDG_BIN_HOME` pointed at a temporary directory. The real system state was
   never touched.
2. The real session. The module ran against the live state directory, and
   Omarchy's own `omarchy-toggle-enabled` and `omarchy-launch-screensaver` were
   used to confirm the result.

## What Omarchy does

The menu entry **Screensaver Off** runs `omarchy-toggle-screensaver`, which
toggles this flag file:

```text
~/.local/state/omarchy/toggles/screensaver-off
```

While the file exists, `omarchy-launch-screensaver` exits with status 1 before it
starts a terminal. Omarchy's idle service still runs, so the lock timer still
fires. The module writes the same file and does not touch
`~/.config/omarchy/shell.json`.

## Sandbox results

85 checks, 0 failed.

| Check | Result |
|---|---|
| `status --quiet` is silent and fails before enable | Passed |
| `status` says the screensaver is on before enable | Passed |
| `verify` fails before enable | Passed |
| `enable` creates the Omarchy toggle file | Passed |
| The toggle file starts with the module marker | Passed |
| Omarchy's `omarchy-toggle-enabled` sees the flag | Passed |
| `status --quiet` succeeds after enable | Passed |
| `status` says the screensaver is off and the module is on | Passed |
| `verify` succeeds and says the module manages the flag | Passed |
| `enable` does not edit `shell.json` | Passed |
| `enable` creates no backup for a fresh flag | Passed |
| A second `enable` is idempotent | Passed |
| A second `enable` leaves the marker and creates no backup | Passed |
| `disable` removes the toggle file | Passed |
| Omarchy sees the screensaver as on again | Passed |
| `status --quiet` fails after disable | Passed |
| `status` says the screensaver is on and the module is off | Passed |
| `disable` does not edit `shell.json` | Passed |
| A second `disable` is safe | Passed |
| `enable` accepts a pre-existing empty flag | Passed |
| A pre-existing flag stays present and is backed up | Passed |
| `enable` says the screensaver was already off | Passed |
| `disable` restores the pre-existing flag | Passed |
| The restored flag is still empty and keeps its mode | Passed |
| `disable` removes the backup and the state directory | Passed |
| A pre-existing flag keeps the screensaver off after disable | Passed |
| A flag with other content is restored byte for byte | Passed |
| A flag with other content keeps its mode | Passed |
| `status --quiet` fails for a foreign flag | Passed |
| `status` explains that the flag was set outside the module | Passed |
| `verify` fails for a foreign flag | Passed |
| `disable` refuses a foreign flag and leaves it in place | Passed |
| `enable` refuses a symlink at the toggle path | Passed |
| `disable` refuses a symlink at the toggle path | Passed |
| The symlink is left in place | Passed |
| `enable` refuses a directory at the toggle path | Passed |
| `disable` refuses a directory at the toggle path | Passed |
| The directory is left in place | Passed |
| `enable` fails without Omarchy and writes nothing | Passed |
| A menu turn-on while enabled is handled cleanly | Passed |
| `disable` removes the stale backup after a menu turn-on | Passed |
| A fresh enable after a menu turn-on removes the stale backup | Passed |
| `disable` after a fresh enable removes the flag and does not restore the old state | Passed |
| With a custom `XDG_STATE_HOME`, the flag stays under `HOME` | Passed |
| With a custom `XDG_STATE_HOME`, Omarchy still sees the flag | Passed |
| With a custom `XDG_STATE_HOME`, the backup goes under `XDG_STATE_HOME` | Passed |
| `disable` restores the flag under `HOME` and removes the backup | Passed |
| `link` creates the command symlink | Passed |
| `unlink` removes the command symlink | Passed |
| A second `unlink` is safe | Passed |
| `link` and `unlink` refuse a symlink to another checkout | Passed |
| `version` prints the module name | Passed |

`bash -n` and ShellCheck 0.10.0 with `-S warning` pass.

## Real-system results

| # | Check | Result |
|---|---|---|
| 1 | Before enabling, the `screensaver-off` flag was absent | Passed |
| 2 | `status --quiet` exited 1 before enabling | Passed |
| 3 | `status` reported the screensaver on and the module off | Passed |
| 4 | `no-screensaver enable` exited 0 | Passed |
| 5 | The flag existed with the module marker | Passed |
| 6 | `omarchy-toggle-enabled screensaver-off` returned 0 | Passed |
| 7 | `omarchy-launch-screensaver` exited 1 with the flag present | Passed |
| 8 | `status --quiet` exited 0 while enabled | Passed |
| 9 | `status` reported the screensaver off and the module on | Passed |
| 10 | `verify` exited 0 and said the module manages the flag | Passed |
| 11 | `no-screensaver disable` exited 0 | Passed |
| 12 | The flag was gone after disable | Passed |
| 13 | `omarchy-toggle-enabled screensaver-off` returned 1 | Passed |
| 14 | `status --quiet` exited 1 after disable | Passed |
| 15 | `status` reported the screensaver on and the module off | Passed |
| 16 | `~/.config/omarchy/shell.json` was unchanged | Passed |
| 17 | The other toggle files under `toggles/hypr/` were untouched | Passed |
| 18 | No sudo was needed at any point | Passed |
| 19 | The live toggle directory was back to its original contents | Passed |

## What the tests show

- The module uses the same flag as the menu, so the menu and the module always
  agree.
- The lock timeout is untouched. Only the screensaver is stopped.
- A screensaver that was already off stays off when the module is disabled.
- A flag the module did not write is never removed.
- Removing the module returns the screensaver to the state it had before the
  module was enabled.
