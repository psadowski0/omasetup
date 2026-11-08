# unlock-themes

unlock-themes is an independent module in [Omasetup](../../README.md). It runs
on its own and does not need the Omasetup app.

## What is it?

unlock-themes adds two unlock screens to **Appearance → Unlock**. One uses the
White palette. The other uses the Vantablack palette. Both show no logo, and
the password field is exactly centered.

## How does it help you?

You get a clean unlock screen without changing your desktop theme. The password
field is exactly centered, horizontally and vertically, and the lock icon stays
slightly to its left. Stock unlock themes keep their original layout.

| White No Logo | Vantablack No Logo |
|---|---|
| <img src="themes/white-no-logo/preview-unlock.png" alt="A white unlock screen with an exactly centered password field and no logo" width="100%"> | <img src="themes/vantablack-no-logo/preview-unlock.png" alt="A black unlock screen with an exactly centered password field and no logo" width="100%"> |

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/unlock-themes/unlock-themes link
```

Then run `unlock-themes enable`. The first `enable` asks for sudo once to add a
small boot-image hook. It does not change Omarchy's own files.

## Use

```bash
unlock-themes enable     # Adds the centered screens and the update hook.
unlock-themes status     # Shows what is installed and which screen is active.
unlock-themes disable    # Removes everything and restores the default if needed.
```

Open Omarchy menu → **Appearance → Unlock** and choose **White No Logo** or
**Vantablack No Logo**.

You can run `enable` and `disable` more than once. The module requires Omarchy
4.5 or newer. Install and update use `git`.

## What it does

| Screen | Background | Text | Logo |
|---|---|---|---|
| White No Logo | White | Black | None |
| Vantablack No Logo | Black | White | None |

Omarchy applies the same choice to its login screen, as it does for every
unlock theme.

The centering is written into the boot image when the boot image is built. The
module adds a small mkinitcpio hook and a drop-in, and the hook adds one
conditional line to the copy of Omarchy's Plymouth layout inside the boot image
only. The files on disk stay exactly as Omarchy ships them.

The line runs only when the logo is one pixel tall, which is true for these two
screens and false for every stock theme. Stock screens keep their original
layout.

One small Pacman hook restores the selected screen's logo and colors after an
`omarchy-settings` update. It does not force a rebuild. The next normal boot
image build centers the field again.

## Good to know

- It does not change your desktop theme.
- Use these screens from **Appearance → Unlock**. They are not desktop themes.
- These screens do not appear under **Appearance → Theme**. Omarchy's Theme
  picker only lists themes with a desktop preview or backgrounds, and these
  screens have neither. The `omarchy theme list` command still lists every
  theme directory, including these two.
- The password field is exactly centered. Stock themes keep their original
  position.
- No Omarchy or Plymouth file is patched in normal use. The module only adds
  new files. Migrating from v0.2.2 removes its old one-line change from the
  packaged layout, which can leave a modification-time warning until the next
  `omarchy-settings` update.
- `pacman -Qkk omarchy-settings` reports the installed theme assets while a
  screen is active, because Omarchy applies the selected colors and logo for
  every unlock theme. The packaged source layout has no checksum mismatch.
- The SDDM login screen is not patched. Omarchy still applies the selected
  screen's logo to it, as it does for every unlock theme.
- `unlock-themes status` shows whether the last boot image was centered.
- `disable` restores the default screen when one of these screens is active,
  removes every added file, and rebuilds the boot image once.
- It leaves stock themes and your own themes alone.
- The preview images use Omarchy's Plymouth layout with the same centering rule.

## Tested in the real world

The module was tested on 8 November 2026 on real hardware with Omarchy 4.5.0-3.
A 63-check real-system test migrated the live v0.2.2 install, exercised both
screens, simulated an `omarchy-settings` upgrade, removed everything, and
installed it again. It also read the centered layout back out of the real boot
image. Every check passed. The [test log](docs/testing.md) lists each check and
the sandbox results. The module is left on with **Vantablack No Logo** active
for the reboot check. The boot screen itself has not been seen yet, so a reboot
is the final confirmation.

## Update

Run this command to get the latest version:

```bash
unlock-themes update
```

If the screens are already installed, run `unlock-themes enable` after updating
so the helper, hooks, and screens use the new version. If one of the screens is
active, `enable` rebuilds the boot image automatically.

## Remove

Run this command to remove everything:

```bash
unlock-themes disable && unlock-themes unlink && rm -rf ~/.local/share/omasetup
```

## More

- [Full test log](docs/testing.md) lists every check and the result.
- [Omasetup](../../README.md) explains the project that hosts this module.
- [Contributing](../../CONTRIBUTING.md) explains how to add a module.
- Omasetup uses the MIT license; see [LICENSE](../../LICENSE).
