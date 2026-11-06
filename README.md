# Omatweaks

Keep your Omarchy laptop from dying in your bag.

On battery, it suspends when you close the lid or leave it idle, then
hibernates before the battery runs out. Plugged in, nothing changes.

Unofficial. Not affiliated with Omarchy.

## Install

Copy-paste this once:

```bash
git clone --depth=1 https://github.com/psadowski0/omatweaks.git \
  ~/.local/share/omatweaks
~/.local/share/omatweaks/omatweaks link
```

`link` puts the `omatweaks` command in `~/.local/bin`, which Omarchy already
has on `PATH`.

## Turn it on

```bash
omatweaks battery-hibernate enable
```

It asks for your password once. That's it.

## What happens

| You... | On battery | Plugged in |
|---|---|---|
| Close the lid | suspend, then hibernate after 2h or below 5% | suspend only |
| Leave it idle | suspend after ~10 min, then hibernate 2h later | nothing |

It also waits if you are watching a video, on a call, or using "stay awake".

## Check it

```bash
omatweaks battery-hibernate status
```

## Turn it off

```bash
omatweaks battery-hibernate disable
```

Removes everything `enable` added. No leftovers.

## Update

```bash
omatweaks update
```

## Remove completely

```bash
omatweaks battery-hibernate disable
omatweaks unlink
rm -rf ~/.local/share/omatweaks
```

## Details

### How it works

- **Lid:** systemd-logind is told to `suspend-then-hibernate` on battery. On AC
  it keeps plain suspend, so it never hibernates there.
- **Idle:** a user timer checks once a minute whether Omarchy reports the
  session as idle. If it does, it suspends; systemd hibernates later.

### Settings

- **Idle time:** `IDLE_MINUTES` in `battery-hibernate/idle-check.sh`
  (default `10`). If you edit it, revert that edit before `update`.
- **Hibernate delay:** add `HibernateDelaySec=1h` to
  `/etc/systemd/sleep.conf.d/` (default `2h`).

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

### Requirements

Omarchy, systemd, `jq`, `git`, and working hibernation.

### Troubleshooting

```bash
omatweaks battery-hibernate status
systemctl --user status omatweaks-battery-hibernate.timer
journalctl --user -u omatweaks-battery-hibernate.service -n 50
```

## For maintainers

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
