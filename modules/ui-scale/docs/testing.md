# Test log

ui-scale was tested on real hardware on 8 and 9 November 2026. It was tested in
a disposable sandbox first and then on the real machine, with the real Hyprland
session and a real boot-image rebuild.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland 0.56.2 on Wayland |
| Panel | `eDP-1`, 2256×1504, BOE 0x0BCA |
| Terminal | foot 1.28.0 |
| Console fonts | kbd 2.10.0 |
| Desktop theme | Vantablack |

## How it was tested

1. A disposable sandbox for the four user-level commands. `HOME`,
   `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `OMARCHY_PATH` pointed at a
   temporary directory, with a fake `hyprctl` that reports the scale from the
   presence of the toggle file, and a fake `sudo` that records its calls. The
   real files were never touched.
2. A disposable sandbox for the root helper, run under `pkexec` with
   `UI_SCALE_VCONSOLE`, `UI_SCALE_ROOT_STATE`, `UI_SCALE_FONT_DIR`,
   `UI_SCALE_BOOT_IMAGE`, and `UI_SCALE_REBUILD` redirected into a temporary
   directory, and stubbed `objcopy` and `lsinitcpio`.
3. The real machine. The module ran against the live session and the real boot
   image, including a full `enable` → `disable` → `enable` round-trip.

## Sandbox results: the user-level commands (52 checks)

| Check | Result |
|---|---|
| `status --quiet` fails before enable | Passed |
| `status` reports the module off | Passed |
| `enable` writes the toggle file with the module marker | Passed |
| The toggle file sets scale 1.33 for `eDP-1` | Passed |
| `enable` sets `[font] base-size = 14` | Passed |
| `enable` keeps the existing `family` key in `[font]` | Passed |
| `enable` keeps other sections in `shell.toml` | Passed |
| `enable` sets foot to 14 pt and keeps the font family | Passed |
| `enable` saves the original foot font line | Passed |
| `enable` marks the console as applied | Passed |
| `status --quiet` succeeds after enable | Passed |
| `enable` twice leaves one `base-size` line | Passed |
| `enable` twice does not overwrite the foot backup | Passed |
| `status` shows the desktop, shell, terminal, and console values | Passed |
| `status` reports the module on | Passed |
| `verify` succeeds when all four values are present | Passed |
| `disable` removes the toggle file | Passed |
| `disable` removes `base-size` and keeps `[font]` | Passed |
| `disable` restores foot to 9 pt | Passed |
| `disable` clears the console marker | Passed |
| `disable` calls the helper's `uninstall` | Passed |
| `status --quiet` fails after disable | Passed |
| A second `disable` is safe | Passed |
| `enable` creates `shell.toml` when it is missing | Passed |
| `disable` removes a `shell.toml` that it created | Passed |
| `enable` warns when foot has no font line | Passed |
| `enable` warns when foot.ini is missing | Passed |
| `disable` refuses a toggle file it did not write | Passed |
| `enable` rolls the toggle back when Hyprland ignores the scale | Passed |
| `enable` reports a failed console step and keeps the user settings | Passed |
| `version` prints a name | Passed |

## Sandbox results: the root helper (31 checks)

| Check | Result |
|---|---|
| `install` sets `FONT` and keeps `KEYMAP` | Passed |
| `install` keeps `XKBLAYOUT`, `XKBVARIANT`, and `XKBMODEL` | Passed |
| `install` leaves exactly one `FONT` line | Passed |
| `install` saves the previous file | Passed |
| `install` rebuilds the image and verifies the font inside it | Passed |
| `install` twice does not rebuild again | Passed |
| `verify` succeeds when the image has the font | Passed |
| `uninstall` restores the previous `FONT` and keeps `KEYMAP` | Passed |
| `uninstall` removes the active marker | Passed |
| `install` rolls back when the image does not contain the font | Passed |
| `install` adds `FONT` when the file had none | Passed |
| `uninstall` removes `FONT` again when the file had none | Passed |
| `verify` fails when `FONT` is different | Passed |
| `status` shows the font and the module state | Passed |
| The helper refuses to run as a normal user | Passed |

## Real-system results

| # | Check | Result |
|---|---|---|
| 1 | `enable` sets `eDP-1` to scale 1.33 and Hyprland reports `1.3333334` | Passed |
| 2 | `enable` sets `[font] base-size = 14` and the shell reports 14 px | Passed |
| 3 | `enable` sets foot to `size=14` and keeps the font family | Passed |
| 4 | `enable` sets `FONT=latarcyrheb-sun32` and keeps every other key | Passed |
| 5 | The rebuilt boot image contains `consolefont.psfu` with the same SHA-256 as the font on disk | Passed |
| 6 | `systemd-vconsole-setup` applies the font to the running consoles | Passed |
| 7 | The text console at `Ctrl+Alt+F2` shows the larger font, and the Polish diacritics render | Passed |
| 8 | `omarchy refresh hyprland` does not disturb the scale | Passed |
| 9 | `disable` restores foot to 9 pt, `FONT=default8x16`, and the previous scale | Passed |
| 10 | `disable` rebuilds the image, and the image no longer contains the big font | Passed |
| 11 | `enable` after `disable` restores all four values | Passed |
| 12 | `ui-scale verify` reports all four values and the boot image | Passed |
| 13 | `status --quiet` exits 0 only when all four values are on | Passed |
| 14 | After a reboot the panel is at scale `1.3333334`, logical 1692×1128 | Passed |
| 15 | After a reboot the shell reports 14 px and foot uses 14 pt | Passed |
| 16 | After a reboot every console is 47×141 cells, so the boot applied the console font | Passed |
| 17 | After a reboot the tty2 and tty3 login prompts are complete | Passed |

## Reboot

The machine was rebooted with the module enabled. After the reboot:

- Hyprland reported scale `1.3333334` for `eDP-1`, and the logical size was
  1692×1128. `hyprctl configerrors` was empty.
- The shell reported 14 px, and `~/.config/foot/foot.ini` still said
  `size=14`.
- All three consoles reported 47×141 cells, which is the 16×32 font from
  `/etc/vconsole.conf`, so `systemd-vconsole-setup` applied it during boot.
- The tty2 and tty3 login prompts were complete.

One cosmetic detail was seen before the reboot: a console that was on screen
while its font changed can lose the last characters of a line, because the
screen is resized in place. tty2 showed `framework-13 logi` until the reboot.
It is not a login problem: the prompt is generated by `agetty` and is not read
back from the screen, and pressing Enter reprints it. After the reboot both
prompts were complete.

The Plymouth passphrase screen is not affected by this module; it uses its own
font in the theme. The boot console was seen during the reboot, and the font
inside the image was also checked by extracting it.
