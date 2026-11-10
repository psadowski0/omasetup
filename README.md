# Omasetup

## What is Omasetup?

Omasetup is an app for building, modifying, and restoring an Omarchy setup. The
app itself is not built yet. Omasetup is unofficial and is not affiliated with
Omarchy.

## How does it help you?

Omasetup will let you:

- Build a new Omarchy setup from a known-good configuration.
- Modify an existing setup without hunting through config files.
- Restore your setup after a reinstall or a hardware change.

## What works today?

Six independent modules work today: **auto-hibernate**, **auto-night**,
**unlock-themes**, **natural-scroll**, **keyboard-pl-dh**, and **ui-scale**.
They run on their own and do not need the Omasetup app. Omasetup will call the
same commands when the app is ready.

## Modules

| Module | Status | What it does |
|---|---|---|
| [auto-hibernate](modules/auto-hibernate/README.md) | Available | It suspends on battery, then hibernates before the battery dies. It never hibernates while the charger stays connected. |
| [auto-night](modules/auto-night/README.md) | Available | It switches between the White and Vantablack themes at your local sunrise and sunset, with a pure white or black wallpaper and night light after dark. |
| [unlock-themes](modules/unlock-themes/README.md) | Available | It adds two logo-free unlock screens with an exactly centered password field, based on White and Vantablack. |
| [natural-scroll](modules/natural-scroll/README.md) | Available | It makes the touchpad scroll naturally, the way a phone does, and leaves the mouse wheel alone. |
| [keyboard-pl-dh](modules/keyboard-pl-dh/README.md) | Available | It puts Polish Colemak-DH on the desktop and at the boot passphrase prompt. The desktop layout is switchable and labelled on the bar; the boot layout stays put. |
| [ui-scale](modules/ui-scale/README.md) | Available | It makes the desktop bigger: a 1.33 display scale, a larger shell and bar, a 14 pt terminal, and a larger text console that is also baked into the boot image. |

## Start here

Read a module README to install, use, update, and remove it.

## Contributing

Omasetup is built from independent modules. Read
[CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## License

Omasetup uses the MIT license; see [LICENSE](LICENSE).
