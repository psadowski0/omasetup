# Omatweaks

Small, reversible tweaks for [Omarchy](https://omarchy.org/). Enable a tweak,
disable it, and the system is back to how it was. No packages are installed.

Unofficial. Not affiliated with Omarchy.

## Install

```bash
git clone --depth=1 https://github.com/psadowski0/omatweaks.git \
  ~/.local/share/omatweaks
~/.local/share/omatweaks/omatweaks link
```

`link` puts the `omatweaks` command in `~/.local/bin`, which Omarchy already
has on `PATH`. Everything below works offline; only `update` needs the network.

## Tweaks

| Tweak | What it does |
|---|---|
| `battery-hibernate` | Suspend then hibernate on battery, for lid close and idle. AC never changes. |

```bash
omatweaks battery-hibernate enable     # asks for sudo once (lid part)
omatweaks battery-hibernate status
omatweaks battery-hibernate disable
```

`enable` and `disable` are idempotent and remove exactly what they added.

## battery-hibernate

Battery only.

| Situation | Result |
|---|---|
| Battery, lid closed | suspend now, hibernate after 2h or below 5% |
| Battery, idle | suspend after ~10 min, hibernate 2h later or below 5% |
| AC, lid closed | plain suspend, never hibernate |
| AC, idle | nothing changes |
| Video, call, or "stay awake" | not considered idle |

The lid part uses a systemd-logind drop-in. The idle part is a user timer that
reads Omarchy's own idle state, so inhibitors and the "stay awake" toggle work.

### Knobs

- Idle time: `IDLE_MINUTES` at the top of `battery-hibernate/idle-check.sh`
  (default `10`). If you edit it, revert that edit before `update`, or `update`
  will refuse because of local changes.
- Hibernate delay: add `HibernateDelaySec=1h` to `/etc/systemd/sleep.conf.d/`
  (default `2h`).

### Files

`enable` adds these, `disable` removes them:

```
~/.config/systemd/user/omatweaks-battery-hibernate.service
~/.config/systemd/user/omatweaks-battery-hibernate.timer
~/.config/systemd/user/timers.target.wants/omatweaks-battery-hibernate.timer
/run/user/$UID/omatweaks-battery-hibernate.since
/etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
```

Upgrading from the first version? `enable` and `disable` also remove the old
`omarchy-idle-hibernate.*` units and `30-lid-battery.conf`.

## Troubleshooting

```bash
omatweaks battery-hibernate status
systemctl --user status omatweaks-battery-hibernate.timer
journalctl --user -u omatweaks-battery-hibernate.service -n 50
```

## Update

```bash
omatweaks update
```

## Remove everything

```bash
omatweaks battery-hibernate disable
omatweaks unlink
rm -rf ~/.local/share/omatweaks
```

## Requirements

Omarchy, systemd, `jq`, `git`, and working hibernation for `battery-hibernate`.

## Adding a tweak

One folder per tweak, with a script named `<tweak>/<tweak>.sh` that handles
`enable`, `disable`, and `status`, a `# Summary:` line in that script, and a
row in the table above. Tweaks must not depend on each other.

## License

MIT. See [LICENSE](LICENSE).
