# unlock-themes

unlock-themes is an independent module in [Omasetup](../../README.md). It runs
on its own and does not need the Omasetup app.

## What is it?

unlock-themes adds two unlock screens to **Appearance → Unlock**. One uses the
White palette. The other uses the Vantablack palette. Both show no logo.

## How does it help you?

You get a clean unlock screen without changing your desktop theme. The password
field sits near the center of the screen, where the logo used to be.

| White No Logo | Vantablack No Logo |
|---|---|
| <img src="themes/white-no-logo/preview-unlock.png" alt="A white unlock screen with a centered password field and no logo" width="100%"> | <img src="themes/vantablack-no-logo/preview-unlock.png" alt="A black unlock screen with a centered password field and no logo" width="100%"> |

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/unlock-themes/unlock-themes link
```

Then run `unlock-themes enable`.

## Use

```bash
unlock-themes enable     # Adds the two unlock screens.
unlock-themes status     # Shows what is installed and which screen is active.
unlock-themes disable    # Removes the screens and restores the default if needed.
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

## Good to know

- It does not change your desktop theme.
- Use these screens from **Appearance → Unlock**. They are not desktop themes.
- These screens do not appear under **Appearance → Theme**. Omarchy's Theme
  picker only lists themes with a desktop preview or backgrounds, and these
  screens have neither. The `omarchy theme list` command still lists every
  theme directory, including these two.
- `disable` restores the default unlock screen when one of these screens is
  active.
- It leaves stock themes and your own themes alone.
- The preview images use Omarchy's own Plymouth layout.

## Tested in the real world

The module was tested on 7 November 2026 on real hardware with Omarchy 4.5.0-3.
Both screens were applied, Omarchy identified each one as active, and `disable`
restored the default screen and removed the files. The machine was not rebooted,
so the boot screen itself was not seen.

The full evidence is in the [test log](docs/testing.md).

## Update

Run this command to get the latest version:

```bash
unlock-themes update
```

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
