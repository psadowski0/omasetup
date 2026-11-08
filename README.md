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

Three independent modules work today: **auto-hibernate**, **unlock-themes**, and
**natural-scroll**. They run on their own and do not need the Omasetup app.
Omasetup will call the same commands when the app is ready.

## Modules

| Module | Status | What it does |
|---|---|---|
| [auto-hibernate](modules/auto-hibernate/README.md) | Available | It suspends on battery, then hibernates before the battery dies. It never hibernates while the charger stays connected. |
| [unlock-themes](modules/unlock-themes/README.md) | Available | It adds two logo-free unlock screens with an exactly centered password field, based on White and Vantablack. |
| [natural-scroll](modules/natural-scroll/README.md) | Available | It makes the touchpad scroll naturally, the way a phone does, and leaves the mouse wheel alone. |

## Start here

Read a module README to install, use, update, and remove it.

## Contributing

Omasetup is built from independent modules. Read
[CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## License

Omasetup uses the MIT license; see [LICENSE](LICENSE).
