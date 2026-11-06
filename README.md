# Omasetup

## What is Omasetup?

Omasetup is an app for building, modifying, and restoring an Omarchy setup. The
app itself is not built yet. Omasetup is unofficial and is not affiliated with
Omarchy.

## How will it help you?

Omasetup will let you:

- Build a new Omarchy setup from a known-good configuration.
- Modify an existing setup without hunting through config files.
- Restore your setup after a reinstall or a hardware change.

The app itself is not built yet.

## What works today?

The first independent module is **auto-hibernate**. It runs on its own and does
not need the Omasetup app. Omasetup will call the same command when the app is
ready.

## Modules

| Module | Status | What it does |
|---|---|---|
| [auto-hibernate](modules/auto-hibernate/README.md) | Available | It suspends on battery, then hibernates before the battery dies. It never hibernates while the charger stays connected. |

## Start here

Read the [auto-hibernate README](modules/auto-hibernate/README.md) to install,
use, update, and remove it.

## Contributing

Omasetup is built from independent modules. Read
[CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## License

Omasetup uses the MIT license; see [LICENSE](LICENSE).
