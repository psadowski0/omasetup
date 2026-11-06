# Omatweaks

Small, reversible tweaks for [Omarchy](https://omarchy.org/). One command to
enable a tweak, one to disable it. No packages, no leftover state.

Unofficial. Not affiliated with Omarchy.

## Install once

```bash
d="${XDG_DATA_HOME:-$HOME/.local/share}/omatweaks"
git clone --depth=1 https://github.com/psadowski0/omatweaks.git "$d"
"$d/omatweaks" link
```

`link` adds `omatweaks` to `~/.local/bin` (Omarchy already has it in
`PATH`). Everything after this works offline. Only `update` needs the network.

## Features

| Tweak | What it does |
|---|---|
| [battery-hibernate](battery-hibernate/README.md) | Suspend then hibernate on battery, for lid close and idle. AC stays unchanged. |

More tweaks will be added here as separate folders.

## Use

```bash
omatweaks list
omatweaks battery-hibernate enable
omatweaks battery-hibernate status
omatweaks battery-hibernate disable
```

`enable` and `disable` are idempotent. Run them as your normal user, never
with `sudo`; the tweak asks for sudo only for the part that needs root.

If you skipped `link`, use `"$d/omatweaks"` instead, or add the checkout to
your `PATH`.

## Requirements

- Omarchy
- systemd (user units)
- `jq`
- `git` (for cloning and updating)
- Working hibernation for `battery-hibernate`

## Update

```bash
omatweaks update
```

## Remove everything

Disable each tweak first, then delete the checkout:

```bash
d="${XDG_DATA_HOME:-$HOME/.local/share}/omatweaks"
omatweaks battery-hibernate disable
omatweaks unlink
rm -rf "$d"
```

`disable` removes exactly what `enable` added. `unlink` removes only the
`omatweaks` command link. The checkout itself is removed by the `rm -rf`.

## Troubleshooting

```bash
omatweaks battery-hibernate status
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
