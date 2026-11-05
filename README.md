# Omatweaks

Small, reversible tweaks for [Omarchy](https://omarchy.org/). One command to
enable a tweak, one to disable it. No packages, no leftover state.

Unofficial. Not affiliated with Omarchy.

## Install once

```bash
d="${XDG_DATA_HOME:-$HOME/.local/share}/omatweaks"
git clone --depth=1 https://github.com/psadowski0/omatweaks.git "$d"
```

Everything after this works offline. Only `update` needs the network.

## Features

| Tweak | What it does |
|---|---|
| [battery-hibernate](battery-hibernate/README.md) | Suspend then hibernate on battery, for lid close and idle. AC stays unchanged. |

More tweaks will be added here as separate folders.

## Use

```bash
d="${XDG_DATA_HOME:-$HOME/.local/share}/omatweaks"

"$d/omatweaks" list
"$d/omatweaks" battery-hibernate enable
"$d/omatweaks" battery-hibernate status
"$d/omatweaks" battery-hibernate disable
```

`enable` and `disable` are idempotent. Run them as your normal user, never
with `sudo`; the tweak asks for sudo only for the part that needs root.

## Requirements

- Omarchy
- systemd (user units)
- `jq`
- `git` (for cloning and updating)
- Working hibernation for `battery-hibernate`

## Update

```bash
"$d/omatweaks" update
```

## Remove everything

Disable each tweak first, then delete the checkout:

```bash
"$d/omatweaks" battery-hibernate disable
rm -rf "$d"
```

`disable` removes exactly what `enable` added. The checkout itself is only
removed by the `rm -rf`.

## Troubleshooting

```bash
"$d/omatweaks" battery-hibernate status
systemctl --user status omatweaks-battery-hibernate.timer
journalctl --user -u omatweaks-battery-hibernate.service -n 50
```

## Adding a tweak

Create one folder per tweak:

```
my-tweak/
├── README.md
└── my-tweak.sh      # enable | disable | status
```

`my-tweak.sh` must start with a `# Summary: ...` line. Add a row to the
Features table above. Tweaks must not depend on each other.

## License

MIT. See [LICENSE](LICENSE).
