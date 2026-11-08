# Test log

The unlock-themes module was tested on real hardware on 8 November 2026. The
test migrated the live v0.2.2 install, used the real Omarchy commands, the real
Pacman hook action, the real boot-image builder, and real `sudo` authentication.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy |
| Session | Hyprland on Wayland |
| Desktop theme | Vantablack |
| Unlock theme before the test | `vantablack-no-logo` (v0.2.2) |

## What changed in v0.2.3

- The centering moved from the files on disk into the boot image. A new
  mkinitcpio install hook and a drop-in add one conditional line to the copy of
  Omarchy's Plymouth layout inside the initramfs only.
- The packaged layout and the installed layout are no longer patched. Only the
  boot image is changed, and only while one of the two screens is selected.
- The old pre-upgrade record hook and the on-disk layout line are removed
  during migration.
- One Pacman post-upgrade hook restores the selected logo and colors after an
  `omarchy-settings` upgrade. It does not force a rebuild.
- `disable` removes the drop-in first, then the hook, then the rest, so a build
  can never look for a missing hook.

## How it was tested

The module was tested in two layers.

1. A disposable sandbox. The real `system.sh` ran inside a private mount
   namespace with throwaway bind mounts over every system path it touches. The
   build hook ran under a user namespace with a throwaway state directory and
   boot-root. Neither layer changed the real system.
2. The real system. The test migrated the live v0.2.2 install, ran both screens
   through the official `omarchy-plymouth-set-by-theme` command, simulated an
   `omarchy-settings` upgrade, ran the update hook's restore action, removed
   everything, and installed it again. It extracted the real UKI, unpacked the
   initramfs, and read the Plymouth layout back out.

The module was left on with **Vantablack No Logo** active for the reboot check.

## Sandbox results

### The build hook

| Check | Result |
|---|---|
| The White 1×1 logo adds the centered line exactly once | Passed |
| The White logo records the active screen | Passed |
| The build note says the image was centered | Passed |
| The on-disk theme stays stock | Passed |
| The Vantablack 1×1 logo adds the centered line exactly once | Passed |
| The Vantablack logo records the active screen | Passed |
| A stock logo adds no centered line | Passed |
| A stock logo clears the active record | Passed |
| A stock logo notes a stock build | Passed |
| A missing anchor keeps the stock layout | Passed |
| A missing anchor notes a skipped build | Passed |
| A missing anchor reports the reason | Passed |
| An already-centered layout is not patched twice | Passed |
| A symlinked installed logo is ignored | Passed |
| A non-omarchy Plymouth theme is ignored | Passed |
| A missing state directory is ignored | Passed |
| The real rewritten hook passes `bash -n` | Passed |

### The root helper

| Check | Result |
|---|---|
| `install` adds the helper, hook, drop-in, update hook, and state | Passed |
| `install` records no active screen for a stock screen | Passed |
| `install` leaves the packaged and installed layouts untouched | Passed |
| The drop-in appends the hook and guards a missing hook | Passed |
| The update hook calls `restore` | Passed |
| `install` is idempotent | Passed |
| Migration removes the v0.2.2 record hook | Passed |
| Migration removes the on-disk line from both layouts | Passed |
| Migration keeps the packaged layout byte-identical to the pristine copy | Passed |
| Migration records the active screen | Passed |
| Migration re-applies the saved logo and background | Passed |
| A simulated upgrade resets the installed layout and logo | Passed |
| `restore` brings the saved logo and background back | Passed |
| `restore` leaves the installed layout unpatched | Passed |
| `restore` keeps the active screen for later upgrades | Passed |
| `restore` leaves the packaged layout untouched | Passed |
| `restore` without an active screen does nothing | Passed |
| `restore` with an unknown screen name is safe | Passed |
| `uninstall` removes the helper, hook, drop-in, update hook, and state | Passed |
| `uninstall` leaves the packaged layout byte-identical to the pristine copy | Passed |
| `uninstall` leaves no on-disk centering line | Passed |

## Real-system results

The first full run reported 60 passed and 2 failed. Both failures were in the
test harness: `pipefail` makes `status | grep -q` look like a failure when
`grep` exits early. Both status checks passed when re-run with the output
captured first. The same harness bug affected the package-integrity checks, so
those were re-run as well. The table below lists the corrected results.

| # | Check | Result |
|---|---|---|
| 1 | The source layout starts with exactly one v0.2.2 line | Passed |
| 2 | The installed layout starts with exactly one v0.2.2 line | Passed |
| 3 | The v0.2.2 helper, both old hooks, and saved state are present | Passed |
| 4 | Vantablack No Logo is active before the migration | Passed |
| 5 | The source layout still contains the anchor line | Passed |
| 6 | `unlock-themes enable` exits 0 | Passed |
| 7 | The old pre-upgrade record hook is removed | Passed |
| 8 | The boot-image hook, drop-in, and update hook are installed | Passed |
| 9 | The installed helper matches the module source | Passed |
| 10 | Both saved logos and color pairs exist | Passed |
| 11 | The build hook records Vantablack No Logo as active | Passed |
| 12 | The source layout has no on-disk centering line | Passed |
| 13 | The installed layout has no on-disk centering line | Passed |
| 14 | The source layout is byte-identical to the pristine copy | Passed |
| 15 | The drop-in appends the hook and guards a missing hook | Passed |
| 16 | The update hook calls the restore action | Passed |
| 17 | The rebuilt boot image reports that it was centered | Passed |
| 18 | The rebuilt boot image contains the centered layout | Passed |
| 19 | `omarchy-plymouth-current` still reports Vantablack No Logo | Passed |
| 20 | `omarchy-plymouth-list` includes both screens | Passed |
| 21 | The Theme picker still excludes both screens | Passed |
| 22 | `status --quiet` exits 0 after the migration | Passed |
| 23 | `status` reports the module on and the last boot image centered | Passed |
| 24 | Applying White No Logo exits 0 | Passed |
| 25 | `omarchy-plymouth-current` reports `white-no-logo` | Passed |
| 26 | The installed logo is the White screen's 1×1 image | Passed |
| 27 | The official apply path keeps the installed layout unpatched | Passed |
| 28 | The installed background is white | Passed |
| 29 | The build hook records White No Logo as active | Passed |
| 30 | The rebuild after the White apply is centered | Passed |
| 31 | The boot image contains the centered layout after the White apply | Passed |
| 32 | The simulated upgrade resets the installed layout to stock | Passed |
| 33 | The simulated upgrade resets the installed logo to stock | Passed |
| 34 | The update hook's `restore` action exits 0 | Passed |
| 35 | `restore` brings the White logo back | Passed |
| 36 | `restore` brings the white background back | Passed |
| 37 | `restore` leaves the installed layout unpatched | Passed |
| 38 | `restore` keeps the active screen for later upgrades | Passed |
| 39 | The screen is active again after the simulated upgrade | Passed |
| 40 | Applying Vantablack No Logo exits 0 | Passed |
| 41 | `omarchy-plymouth-current` reports `vantablack-no-logo` | Passed |
| 42 | The installed logo is the Vantablack screen's 1×1 image | Passed |
| 43 | The installed background is black | Passed |
| 44 | The second official apply keeps the installed layout unpatched | Passed |
| 45 | The build hook records Vantablack No Logo as active | Passed |
| 46 | The boot image contains the centered layout after the Vantablack apply | Passed |
| 47 | `status` names Vantablack No Logo as active | Passed |
| 48 | The packaged source layout has no checksum mismatch | Passed |
| 49 | The installed layout differs only by the applied colors | Passed |
| 50 | `unlock-themes disable` exits 0 | Passed |
| 51 | `disable` restores the default screen | Passed |
| 52 | `disable` removes both screen directories | Passed |
| 53 | `disable` removes the helper, all hooks, and the saved state | Passed |
| 54 | The source layout is byte-identical to the pristine copy after `disable` | Passed |
| 55 | The installed layout has no centering line after `disable` | Passed |
| 56 | The rebuilt boot image has no centering line after `disable` | Passed |
| 57 | `status --quiet` reports the module off after `disable` | Passed |
| 58 | The second `disable` reports nothing to remove | Passed |
| 59 | The second `enable` exits 0 | Passed |
| 60 | A fresh `enable` records no active screen while the default is active | Passed |
| 61 | Vantablack No Logo was applied again for the reboot check | Passed |
| 62 | The module is on with Vantablack No Logo active | Passed |
| 63 | The final boot image contains the centered layout | Passed |

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

The test read the line back out of the real boot image:

```text
224:  entry.y = logo.sprite.GetY() + logo.image.GetHeight() + 40;
225:  if (logo.image.GetHeight() == 1) entry.y = global.layout_height / 2 - entry.image.GetHeight() / 2;
```

The image contains exactly one copy of the line, the Vantablack 1×1 logo, and
the black background.

## Why the logo file still exists

Omarchy's Plymouth script always opens `logo.png`, so a theme cannot omit the
file. A PNG also cannot have a negative height. The 1×1 transparent image is
invisible and takes almost no space. It also lets the build hook and
`omarchy-plymouth-current` tell the two screens apart because each file has
different bytes.

The White logo is 336 bytes, and the Vantablack logo is 341 bytes. Both are
1×1 RGBA images with full transparency.

## The update hook

Pacman allows one action per hook file, so the module installs one.

| Hook | When | Action |
|---|---|---|
| `85-omasetup-unlock-themes-restore.hook` | After an `omarchy-settings` install or upgrade | Restores the selected screen's logo and colors. |

The restore hook runs before `90-mkinitcpio-install.hook`. If the same
transaction rebuilds the boot image, the screen is already restored when the
build hook runs, so the new image is centered. If no rebuild happens, the
existing boot image is still correct, and the next normal rebuild centers it
again.

The build hook writes the selected screen to `/var/lib/omasetup/unlock-themes/`
at build time, so the restore hook does not need a separate pre-upgrade hook.

## Expected package warnings

`pacman -Qkk omarchy-settings` reports modified Plymouth and SDDM assets while
the module is on. Omarchy itself recolors those files for every unlock theme,
and the module applies its screen through the same official command. The
packaged `default/plymouth/omarchy.script` has no checksum mismatch. Migration
from v0.2.2 can leave a modification-time warning on that file until the next
`omarchy-settings` update.

## Not tested

- **A real reboot.** The module is left on with **Vantablack No Logo** active,
  and the final UKI contains the centered layout. The boot screen itself has not
  been seen yet. A reboot is the final confirmation.

## What the tests show

- Both screens appear in **Appearance → Unlock**.
- They do not appear in **Appearance → Theme**.
- The official Omarchy apply command keeps the centering in the boot image.
- The packages' Plymouth files are not patched.
- The update hook restores the screen after an `omarchy-settings` upgrade.
- The password field is exactly centered, and the lock icon stays to its left.
- Removing the module while a screen is active restores the default screen and
  leaves the packaged layout byte-identical.
- Repeated `enable` and `disable` runs leave no leftovers.
- Unrelated theme directories are not overwritten or removed.
