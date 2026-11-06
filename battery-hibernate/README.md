# battery-hibernate

Suspend first, hibernate later — on battery only. AC behavior never changes.

## What happens

| Situation | Result |
|---|---|
| Battery, lid closed | suspend now, hibernate after 2h or below 5% battery |
| Battery, idle | suspend after ~10 min idle, hibernate 2h later or below 5% |
| AC, lid closed | plain suspend, never hibernate |
| AC, idle | nothing changes |
| Video, call, or "stay awake" | not considered idle |

The 2h hibernation delay is systemd's default `HibernateDelaySec`. The 5%
threshold comes from UPower's `PercentageCritical`.

## Enable

```bash
omatweaks battery-hibernate enable
```

The lid part asks for sudo once. The idle part runs as your user.

## Disable

```bash
omatweaks battery-hibernate disable
```

This removes the logind drop-in, the user timer, its units, and the runtime
state file. It is safe to run when nothing is installed.

## Status

```bash
omatweaks battery-hibernate status
```

`status --quiet` prints nothing and exits 0 only when the full feature is
enabled.

## How it works

- **Lid:** a systemd-logind drop-in sets `HandleLidSwitch=suspend-then-hibernate`
  on battery and `HandleLidSwitchExternalPower=suspend` on AC. The AC setting
  must be explicit — if left unset, logind falls back to `HandleLidSwitch` and
  would hibernate on AC too.
- **Idle:** a user timer runs `idle-check.sh` once a minute. It reads Omarchy's
  own idle state (`omarchy-shell idle status`), so it respects inhibitors and
  the "stay awake" toggle, then calls `systemctl suspend-then-hibernate`.
  It does nothing on AC and restarts its countdown after a resume.

## Files

Added by `enable`, removed by `disable`:

```
~/.config/systemd/user/omatweaks-battery-hibernate.service
~/.config/systemd/user/omatweaks-battery-hibernate.timer
~/.config/systemd/user/timers.target.wants/omatweaks-battery-hibernate.timer
/run/user/$UID/omatweaks-battery-hibernate.since
/etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
```

No packages are installed. The repository itself is never modified by
`enable`/`disable` (except marking the helper scripts executable).

## Knobs

- Idle time: `IDLE_MINUTES` at the top of `idle-check.sh` (default `10`).
- Hibernate delay: add `HibernateDelaySec=1h` to
  `/etc/systemd/sleep.conf.d/` (systemd default is `2h`).

## Troubleshooting

```bash
# Is the timer running?
systemctl --user status omatweaks-battery-hibernate.timer
systemctl --user list-timers | grep omatweaks

# What did the check decide?
journalctl --user -u omatweaks-battery-hibernate.service -n 50

# What does logind see?
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitch
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitchExternalPower

# Is Omarchy reporting idle? Are we on battery?
omarchy-shell idle status
omarchy-power-present; echo "exit=$? (0 = AC)"
```

If you move the repository, run `enable` again so the timer points at the new
path.

## Migrating from the old scripts

The first versions used `omarchy-idle-hibernate.*` units and
`30-lid-battery.conf`. `enable`, `disable`, and `status` clean those up
automatically.
