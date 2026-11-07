# Test log

The unlock-themes module was tested on real hardware on 7 November 2026. The
test used the real Omarchy menu data, the real Plymouth apply path, the real
Pacman hook actions, and real `sudo` authentication.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland on Wayland |
| Desktop theme | Vantablack |
| Unlock theme before the test | `default` |

## What changed in v0.2.2

- Both screens use a 1×1 fully transparent logo, so the logo itself takes no
  space.
- Omarchy's Plymouth layout gains one conditional line. It centers the password
  field only when the logo is one pixel tall.
- Two Pacman hooks keep the centering and the selected screen through an
  `omarchy-settings` upgrade.
- `disable` removes every added file and restores both layout scripts.

## How it was tested

The module was tested in two layers.

1. A disposable mount namespace on the same machine. It held a copy of the real
   Plymouth scripts, a copy of the real theme assets, and a fake
   `limine-mkinitcpio`. This layer ran the real `system.sh` helper and checked
   the install, record, restore, and uninstall paths without touching the real
   system files.
2. The real system. A test script ran 44 checks against the real Omarchy
   commands, the real Pacman hooks, and the real boot image builder. The module
   was left on with **Vantablack No Logo** active for the reboot check.

## Real-system results

The test ran from a clean state: the module was off, and the active screen was
`default`. Every check passed.

| # | Check | Result |
|---|---|---|
| 1 | A pristine copy of the source layout script was saved | Passed |
| 2 | Neither layout script was patched before the test | Passed |
| 3 | `status --quiet` reported the module as off before the test | Passed |
| 4 | Both screen directories contain the marker, logo, and preview | Passed |
| 5 | The helper, both hooks, and the saved state exist after `enable` | Passed |
| 6 | Each layout script contains exactly one patch line | Passed |
| 7 | The source layout changed only by the added line | Passed |
| 8 | The installed layout changed only by the added line | Passed |
| 9 | `status --quiet` exits 0 after `enable` | Passed |
| 10 | `status` reports the layout, update hook, and module as on | Passed |
| 11 | `omarchy-plymouth-list` includes both screens | Passed |
| 12 | The Theme picker still excludes both screens | Passed |
| 13 | Applying White No Logo exits 0 | Passed |
| 14 | `omarchy-plymouth-current` reports `white-no-logo` | Passed |
| 15 | The installed logo is the White screen's 1×1 image | Passed |
| 16 | The installed logo is 1×1 | Passed |
| 17 | The official apply path kept the layout patch | Passed |
| 18 | The installed background is white | Passed |
| 19 | The record action saved `white-no-logo` as active | Passed |
| 20 | The simulated upgrade removed the patch | Passed |
| 21 | The simulated upgrade reset the active screen to `default` | Passed |
| 22 | The restore action patched both layout scripts again | Passed |
| 23 | The restore action restored the White logo | Passed |
| 24 | The restore action restored the white background | Passed |
| 25 | The screen is active again after the simulated upgrade | Passed |
| 26 | The restore action cleared the active marker | Passed |
| 27 | The restore action rebuilt the boot image | Passed |
| 28 | Applying Vantablack No Logo exits 0 | Passed |
| 29 | `omarchy-plymouth-current` reports `vantablack-no-logo` | Passed |
| 30 | The installed logo is the Vantablack screen's 1×1 image | Passed |
| 31 | The installed background is black | Passed |
| 32 | The layout patch survived the second apply | Passed |
| 33 | `status` names Vantablack No Logo as active and the module as on | Passed |
| 34 | `disable` exits 0 | Passed |
| 35 | `disable` restored the default screen | Passed |
| 36 | `disable` removed both screen directories | Passed |
| 37 | `disable` removed the helper, both hooks, and the saved state | Passed |
| 38 | Both layout scripts are byte-identical to the pristine copies | Passed |
| 39 | No patch line remains after `disable` | Passed |
| 40 | The installed Plymouth assets match the pristine copies | Passed |
| 41 | `status --quiet` reports the module as off after `disable` | Passed |
| 42 | The second `disable` left the default screen active | Passed |
| 43 | Vantablack No Logo was applied again for the reboot check | Passed |
| 44 | The module is on with Vantablack No Logo active | Passed |

The simulated upgrade copied the packaged layout and theme files over the
installed ones, exactly as an `omarchy-settings` upgrade does. Then it ran the
two hook actions, `record` before the overwrite and `restore` after it.

## Sandbox results

| Check | Result |
|---|---|
| `install` patches both layout scripts and writes both hooks | Passed |
| `install` saves a logo and a color pair for each screen | Passed |
| `record` with the stock logo creates no active marker | Passed |
| `record` with the White 1×1 logo saves `white-no-logo` | Passed |
| `restore` after a simulated upgrade re-patches both scripts | Passed |
| `restore` brings back the logo, the background, and the active screen | Passed |
| `restore` rebuilds the boot image only when a screen was active | Passed |
| `restore` clears the active marker | Passed |
| `uninstall` removes the hooks, the helper, and the saved state | Passed |
| The source layout is byte-identical to the package copy after `uninstall` | Passed |
| The installed layout has no patch line after `uninstall` | Passed |

## The layout

Omarchy places the password field with:

```text
logo.y  = screen height / 2 - logo height / 2
entry.y = logo.y + logo height + 40
```

A 1×1 logo alone would put the field at `y = 581` on a 1080-pixel screen. The
added line changes that to:

```text
entry.y = screen height / 2 - entry height / 2
```

The result at 1920×1080 is a 286×48 field at x 817 and y 516. Its center is
exactly `960,540`. The lock icon sits at x 769, slightly left of the field.

Both 1920×1080 previews were trimmed to the same content box:
`334x48 +769+136` relative to a crop at y 380, which is absolute y 516. That
matches the live layout.

## Why the logo file still exists

Omarchy's Plymouth script always opens `logo.png`, so a theme cannot omit the
file. A PNG also cannot have a negative height. The 1×1 transparent image is
invisible and takes almost no space. It also lets
`omarchy-plymouth-current` tell the two screens apart because each file has
different bytes.

The White logo is 336 bytes, and the Vantablack logo is 341 bytes. Both are
1×1 RGBA images with full transparency.

## The update hooks

Pacman allows one action per hook file, so the module installs two.

| Hook | When | Action |
|---|---|---|
| `80-omasetup-unlock-themes-record.hook` | Before an `omarchy-settings` install or upgrade | Saves the active screen. |
| `85-omasetup-unlock-themes-restore.hook` | After an `omarchy-settings` install or upgrade | Re-applies the patch and the saved screen. |

The restore hook runs before `90-mkinitcpio-install.hook`, so the boot image is
rebuilt with the restored screen. A combined kernel and `omarchy-settings`
update may rebuild the image twice, which is harmless.

## Expected package warnings

`pacman -Qkk omarchy-settings` reports altered Plymouth and SDDM files while the
module is on. Omarchy itself recolors those files for every unlock theme, and
the module applies its screen through the same official command. `disable`
restores the Plymouth layout scripts byte-for-byte.

## Not tested

- **A real reboot.** The module is left on with **Vantablack No Logo** active,
  and the boot image was rebuilt. The boot screen itself has not been seen yet.
  A reboot is the final confirmation.

## What the tests show

- Both screens appear in **Appearance → Unlock**.
- They do not appear in **Appearance → Theme**.
- The official Omarchy apply command keeps the centering.
- The Pacman hooks restore the screen after an `omarchy-settings` upgrade.
- The password field is exactly centered, and the lock icon stays to its left.
- Removing the module while a screen is active restores the default screen.
- Removing the module leaves both layout scripts byte-identical to the package
  copies.
- Repeated enable and disable runs leave no leftovers.
- Unrelated theme directories are not overwritten or removed.
