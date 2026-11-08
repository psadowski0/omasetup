# Test log

keyboard-pl-dh is tested in a disposable sandbox first, then on the real
machine. The sandbox never touches the real `/etc`, `/boot`, or `/var/lib`; the
root helper runs inside a private mount namespace with every path it writes
bind-mounted to a temporary directory.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland 0.56.2 on Wayland |
| Keyboard | ISO |
| Boot image | UKI at `/boot/EFI/Linux/omarchy_linux-omarchy.efi` |

## How it was tested

1. **CLI sandbox.** `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `PATH`
   point at a temporary directory. Fake `hyprctl`, `sudo`, `omarchy`, and
   `omarchy-menu-select` commands stand in for the real ones. The real system
   is never touched. The generated XKB symbols file is compiled with the real
   `xkbcli`, so a broken override fails the test.
2. **Helper sandbox.** The root helper runs under `unshare -r -m` (a private
   user and mount namespace). `/etc` is a temporary tmpfs, and
   `/var/lib/omasetup`, `/usr/local/lib/omasetup`, and `/boot` are bind-mounted
   to temporary directories. A fake `limine-mkinitcpio` builds a real cpio
   archive inside a fake UKI, in both the `sd-vconsole` shape (`/etc/vconsole.conf`
   plus the map file) and the `keymap` shape (`/keymap.bin`), so both
   verification paths are exercised for real.
3. **The real machine.** The module runs against the live Hyprland session and
   the real boot image. The boot prompt is tested in a TTY before rebooting.

## Sandbox results: the command

75 checks, 0 failed.

| Check | Result |
|---|---|
| `status --quiet` is silent and fails before enable | Passed |
| `enable --yes` succeeds | Passed |
| `enable` writes the desktop layout file | Passed |
| The desktop layout is Polish Colemak-DH then Polish QWERTY | Passed |
| The desktop variants are Colemak-DH then plain | Passed |
| `enable` remembers that there was no layout file before | Passed |
| `enable` records that the boot keymap is installed | Passed |
| `enable` runs the root helper with sudo | Passed |
| `enable` refreshes the Omarchy menu | Passed |
| The menu block begin marker is present | Passed |
| The menu block end marker is present | Passed |
| The menu override replaces the stock picker row | Passed |
| The menu override opens the labelled picker | Passed |
| The menu override keeps the stock label | Passed |
| The menu override does not show the raw id | Passed |
| The menu override keeps the stock icon | Passed |
| The old extra menu row is gone | Passed |
| The menu file is still valid JSONC | Passed |
| `enable` writes the bar-label symbols file | Passed |
| The symbols file renames the ISO Colemak-DH variant | Passed |
| `enable` remembers that there was no symbols file before | Passed |
| `status --quiet` succeeds while enabled | Passed |
| `status` reports the desktop layout | Passed |
| `status` reads the runtime layout | Passed |
| `status` reports the boot keymap | Passed |
| `status` reports the menu override | Passed |
| `status` reports the bar labels | Passed |
| `status` reports the module on | Passed |
| `enable` is idempotent for the layout file | Passed |
| `enable` is idempotent for the menu file | Passed |
| The menu block is not duplicated | Passed |
| `enable` rewrites an outdated menu block | Passed |
| Rewriting the block does not duplicate it | Passed |
| `picker` labels Polish Colemak-DH | Passed |
| `picker` keeps the stock key in its catalog | Passed |
| The menu label follows the language catalog | Passed |
| `desktop` restores the PL Colemak-DH list | Passed |
| The pre-module layout state is kept | Passed |
| `disable` succeeds | Passed |
| `disable` removes a layout file that did not exist before | Passed |
| `disable` removes a symbols file it created | Passed |
| `disable` clears the boot-on marker | Passed |
| `disable` restores the boot keymap with sudo | Passed |
| `disable` removes the menu block | Passed |
| `disable` keeps the rest of the menu file | Passed |
| The menu file is valid JSONC after disable | Passed |
| `status --quiet` fails after disable | Passed |
| A second `disable` is safe | Passed |
| `disable` restores the previous layout file byte for byte | Passed |
| `enable` keeps a custom symbols file | Passed |
| `enable` renames the custom symbols file | Passed |
| `disable` restores the previous symbols file byte for byte | Passed |
| `verify` asks the root helper to check the boot image | Passed |
| `enable` keeps existing menu entries | Passed |
| The menu file with entries is valid JSONC | Passed |
| `disable` restores the previous menu file byte for byte | Passed |
| `disable` refuses a half marker block | Passed |
| The half marker file is untouched | Passed |
| `disable` works with no markers | Passed |
| The foreign menu file is untouched | Passed |
| `enable` without a terminal exits cleanly | Passed |
| The desktop half still applies without a terminal | Passed |
| The boot half is skipped without confirmation | Passed |
| `enable` says the boot keymap was not changed | Passed |
| sudo did not run without confirmation | Passed |
| `desktop` fails when the Hyprland reload fails | Passed |
| `desktop` explains the failed reload | Passed |
| `desktop` works without Hyprland running | Passed |
| `desktop` says the layout applies at the next login | Passed |
| `enable` creates the menu file when it is missing | Passed |
| The created menu file is valid JSONC | Passed |
| `disable` removes a menu file it created | Passed |
| `link` creates the command symlink | Passed |
| `unlink` removes the command symlink | Passed |
| `version` prints a version line | Passed |

## Sandbox results: the root helper

40 checks, 0 failed.

| Check | Result |
|---|---|
| `install` succeeds | Passed |
| `install` sets the boot keymap | Passed |
| `install` sets the console XKB layout | Passed |
| `install` sets the console XKB variant | Passed |
| `install` keeps the original font | Passed |
| `install` does not force a module font | Passed |
| `install` keeps `XKBMODEL` | Passed |
| `install` keeps `XKBOPTIONS` | Passed |
| `install` keeps the file header | Passed |
| `install` saves the previous vconsole file | Passed |
| `install` records the active state | Passed |
| `install` verifies the boot image | Passed |
| `install` copies itself into `/usr/local/lib` | Passed |
| `verify` accepts the new image | Passed |
| `verify` names the keymap it found | Passed |
| `status` reports the boot keymap | Passed |
| `status` reports the active state | Passed |
| A second `install` keeps the original backup | Passed |
| `verify` rejects the wrong keymap | Passed |
| `uninstall` succeeds | Passed |
| `uninstall` restores the previous vconsole file byte for byte | Passed |
| `uninstall` clears the active state | Passed |
| `uninstall` verifies the restored image | Passed |
| `verify` accepts the restored image | Passed |
| A second `uninstall` fails without a backup | Passed |
| `install` fails when the image has the wrong keymap | Passed |
| `install` explains the wrong-keymap rollback | Passed |
| The wrong-keymap rollback restores the boot keymap | Passed |
| The wrong-keymap rollback clears the active state | Passed |
| `install` fails when the rebuild fails | Passed |
| `install` says the previous keymap was put back | Passed |
| The rollback restores the boot keymap | Passed |
| `install` works with the keymap hook | Passed |
| The keymap hook image is verified | Passed |
| `verify` accepts a `keymap.bin` image | Passed |
| `uninstall` works with the keymap hook | Passed |
| `verify` reports a missing boot image | Passed |
| `verify` explains the missing boot image | Passed |
| `install` does not add a font when there was none | Passed |
| The helper refuses a normal user | Passed |

## Real-system results

All live checks passed on the machine above. The reboot checks ran last, and the
`disable` round-trip was run after them and then re-enabled.

| # | Check | Result |
|---|---|---|
| 1 | The desktop layout file contains `XKBLAYOUT=pl,pl` and `XKBVARIANT=colemak_dh,` | Passed |
| 2 | `hyprctl getoption input:kb_layout` reports `pl,pl` | Passed |
| 3 | `hyprctl getoption input:kb_variant` reports `colemak_dh,` | Passed |
| 4 | `hyprctl configerrors` reports no errors | Passed |
| 5 | The extra `Polish Colemak-DH` row is gone from Setup > Typing | Passed |
| 6 | Both layouts switch with `hyprctl switchxkblayout` | Passed |
| 7 | `enable` sets `KEYMAP=mod-dh-iso-us` in `/etc/vconsole.conf` | Passed |
| 8 | `limine-mkinitcpio` succeeds | Passed |
| 9 | The boot image contains the `mod-dh-iso-us` keymap | Passed |
| 10 | `keyboard-pl-dh verify` reports the keymap from the boot image | Passed |
| 11 | The rebuilt `/etc/vconsole.conf` keeps the original `FONT=default8x16` | Passed |
| 12 | `~/.config/xkb/symbols/pl` compiles with `name[1]="Colemak-DH (PL)"` | Passed |
| 13 | `xkbcli list` plus the bar's label logic give COL and PL | Passed |
| 14 | The picker offers `pl:colemak_dh` as `Polish (Colemak-DH ISO)` | Passed |
| 15 | The merged menu row keeps the stock icon and label with the picker action, and the rest of the user file is unchanged | Passed |
| 16 | The bar shows COL for Colemak-DH and PL for QWERTY after a new login | Passed |
| 17 | Setup > Typing > Keyboard Layouts opens the labelled picker | Passed |
| 18 | The passphrase types correctly in a TTY after `loadkeys` (ASCII; the console map has no Polish diacritics) | Passed |
| 19 | The passphrase unlocks the disk after a reboot | Passed |
| 20 | The desktop layout and bar labels survive a reboot | Passed |
| 21 | `disable` restores the stock keymap, layout, symbols file, and menu block byte for byte, then `enable` puts them back | Passed |
