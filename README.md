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
  session as idle. If it does, it suspends; systemd hibernates later. If
  systemd wakes early and skips hibernation, it retries after one minute.
- **Timer:** a sleep drop-in sets `HibernateDelaySec=2h`. On a laptop with a
  battery, systemd otherwise ignores the 2-hour default and waits for the 5%
  low-battery alarm, which can take days.

### Settings

- **Idle time:** `IDLE_MINUTES` in `tweaks/auto-hibernate/idle-check.sh`
  (default `10`). If you edit it, revert that edit before `update`.
- **Hibernate delay:** edit `HibernateDelaySec=` in
  `/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf`
  (default `2h`).

### Files

`enable` adds these, `disable` removes them:

```
~/.config/systemd/user/omatweaks-auto-hibernate.service
~/.config/systemd/user/omatweaks-auto-hibernate.timer
~/.config/systemd/user/timers.target.wants/omatweaks-auto-hibernate.timer
/run/user/$UID/omatweaks-auto-hibernate.since
/run/user/$UID/omatweaks-auto-hibernate.attempt
/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf
```

Older versions used different names and did not install the sleep drop-in.
`enable` and `disable` remove the old files too, so upgrading only needs one
more run of `omatweaks auto-hibernate enable`.

### Requirements

Omarchy, systemd, `jq`, `git`, and working hibernation.

### Troubleshooting

```bash
omatweaks auto-hibernate status
systemctl --user status omatweaks-auto-hibernate.timer
journalctl --user -u omatweaks-auto-hibernate.service -n 50
systemd-analyze cat-config systemd/sleep.conf | grep HibernateDelaySec
journalctl -b | grep -E 'PM: hibernation|Performing sleep operation'
```

If it suspends but never hibernates, check the output above. If
`HibernateDelaySec` is set but the journal shows
`System returned from sleep operation 'suspend-then-hibernate'` without
`Performing sleep operation 'hibernate'`, you hit systemd issue #38193: the
wake alarm can fire a fraction of a second before systemd's timer, and systemd
then treats it as a manual wake. omatweaks retries automatically — logind
re-fires while the lid is closed, and the idle path retries after one minute.
A permanent fix is in systemd PR #44650.

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
