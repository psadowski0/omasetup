# Omatweaks

A small command-line tool for [Omarchy](https://omarchy.org/). Each tweak fixes
one real annoyance, and you can remove it completely.

**Current tweak: `auto-hibernate`.** Your laptop is at 30%, you close the lid,
throw it in a bag, and forget about it. This makes it suspend, then hibernate
before the battery dies. Plugged in, nothing changes.

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

## Use

```bash
omatweaks list                      # what's available and what's on
omatweaks auto-hibernate enable     # turn a tweak on (asks for sudo once)
omatweaks auto-hibernate status     # what's happening right now
omatweaks auto-hibernate disable    # turn it off, remove everything
omatweaks update                    # get the latest version
```

`enable` and `disable` are safe to run more than once.

## Tweaks

| Tweak | What it does |
|---|---|
| `auto-hibernate` | Hibernate automatically on battery; AC unchanged. |

More tweaks will be added here over time.

## auto-hibernate

| You... | On battery | Plugged in |
|---|---|---|
| Close the lid | suspend, then hibernate after 2h or below 5% | suspend only |
| Leave it idle | suspend after ~10 min, then hibernate 2h later | nothing |

It waits if you are watching a video, on a call, or using "stay awake".

## Details

### How it works

- **Lid:** systemd-logind is told to `suspend-then-hibernate` on battery. On AC
  it keeps plain suspend, so it never hibernates there.
- **Idle:** a user timer checks once a minute whether Omarchy reports the
  session as idle. If it does, it suspends; systemd hibernates later.

### Settings

- **Idle time:** `IDLE_MINUTES` in `tweaks/auto-hibernate/idle-check.sh`
  (default `10`). If you edit it, revert that edit before `update`.
- **Hibernate delay:** add `HibernateDelaySec=1h` to
  `/etc/systemd/sleep.conf.d/` (default `2h`).

### Files

`enable` adds these, `disable` removes them:

```
~/.config/systemd/user/omatweaks-auto-hibernate.service
~/.config/systemd/user/omatweaks-auto-hibernate.timer
~/.config/systemd/user/timers.target.wants/omatweaks-auto-hibernate.timer
/run/user/$UID/omatweaks-auto-hibernate.since
/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
```

Older versions used different names. `enable` and `disable` remove those old
files too, so upgrading needs no manual cleanup.

### Requirements

Omarchy, systemd, `jq`, `git`, and working hibernation.

### Troubleshooting

```bash
omatweaks auto-hibernate status
systemctl --user status omatweaks-auto-hibernate.timer
journalctl --user -u omatweaks-auto-hibernate.service -n 50
```

## Remove completely

```bash
omatweaks auto-hibernate disable
omatweaks unlink
rm -rf ~/.local/share/omatweaks
```

## For maintainers

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
