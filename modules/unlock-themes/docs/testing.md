# Test log

The unlock-themes module was tested on real hardware on 7 November 2026. The
test used the real Omarchy menu data, the real Plymouth apply path, and real
`sudo` authentication.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15 |
| Session | Hyprland on Wayland |
| Desktop theme | Vantablack |
| Unlock theme before the test | `default` |

## How it was tested

The module was enabled, both screens were checked in the Unlock picker data,
each screen was applied through `omarchy-plymouth-set-by-theme`, and the module
was disabled again. The apply step rebuilt the unified kernel image, as Omarchy
does for every unlock theme change.

The v0.2.1 layout uses fully transparent 800×378 logos. That is the same size
as the original White and Vantablack logos, so Omarchy's layout code puts the
password field back in the exact stock position.

## Results

| # | Check | Result |
|---|---|---|
| 1 | `unlock-themes status` before enable | Both screens were reported as not installed. |
| 2 | `unlock-themes enable` | Both screens were installed in `~/.config/omarchy/themes`. |
| 3 | `omarchy-plymouth-list` | It listed `white-no-logo` and `vantablack-no-logo`. |
| 4 | Unlock picker rows | Both screens appeared with the labels **White No Logo** and **Vantablack No Logo**. |
| 5 | `omarchy-theme-switcher --print-rows` | It listed neither screen, so they stay out of **Appearance → Theme**. |
| 6 | Apply White No Logo | The command exited 0, and `omarchy-plymouth-current` returned `white-no-logo`. |
| 7 | Apply Vantablack No Logo | The command exited 0, and `omarchy-plymouth-current` returned `vantablack-no-logo`. |
| 8 | `unlock-themes status` while active | It named the active screen correctly. |
| 9 | `unlock-themes disable` while active | It restored `default`, then removed both theme directories. |
| 10 | `unlock-themes disable` again | It reported that there was nothing to remove and exited 0. |
| 11 | `unlock-themes status --quiet` | Exit 1 when off, exit 0 when both screens were installed. |
| 12 | Partial install repair | A missing `unlock.png` was reported, and `enable` restored it. |
| 13 | Name collision | An unrelated directory with the same name was refused and left untouched. |
| 14 | Preview files | Both 1920×1080 previews were rendered and checked by eye. |
| 15 | Stock field position | The original White and Vantablack previews place the lock and field at `334×48+769+769`. |
| 16 | Module field position | Both module previews match the stock position at `334×48+769+769`. |

Both transparent logos are 800×378 RGBA images with different bytes. That is
what lets `omarchy-plymouth-current` tell the two screens apart.

## Why the logo file still exists

Omarchy's Plymouth script always opens `logo.png` and sets
`entry.y = logo.y + logo.height + 40`. A theme cannot omit the file, and a PNG
cannot have a negative height. The 800×378 transparent image is an invisible
layout spacer that keeps the field in the original position. It is not visible
on the screen.

## Not tested

- **A real reboot.** The boot screen itself was not seen. The test verified the
  same apply path Omarchy uses for stock unlock themes, and the generated
  previews use Omarchy's own Plymouth layout. A reboot is still the final
  confirmation.

## What the tests show

- The two screens appear in **Appearance → Unlock**.
- They do not appear in **Appearance → Theme**.
- Applying either screen works through the stock Omarchy command.
- Removing the module while a screen is active restores the default screen.
- Repeated enable and disable runs leave no leftovers.
- Unrelated theme directories are not overwritten or removed.
