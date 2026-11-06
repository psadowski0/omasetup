# How auto-hibernate works

The tweak plugs into the sleep system already provided by systemd and Omarchy.
`enable` adds a few drop-in files; `disable` removes them.

## The short version

- **Lid and manual suspend:** systemd-logind and `systemd-suspend.service` are
  told to `suspend-then-hibernate`. `HibernateDelaySec=2h` sets the timer.
  `HibernateOnACPower=no` keeps it suspended while AC stays connected. If you
  unplug while suspended, the next check (within 2 h) hibernates.
- **Idle:** a user timer runs once a minute. When Omarchy reports the session as
  idle, it suspends; systemd hibernates later. It respects video/call inhibitors
  and the stay-awake toggle.
- **Early wake:** if systemd wakes after its timer but skips hibernation
  (systemd issue #38193), the next idle check notices the missing hibernation
  and hibernates after one minute of idle instead of sleeping again.
- **Timer:** without an explicit `HibernateDelaySec`, systemd waits for the 5%
  low-battery alarm, which can take days.

## Settings

- **Idle time:** `IDLE_MINUTES` in `tweaks/auto-hibernate/idle-check.sh`
  (default `10`). Revert that edit before `omatweaks update`.
- **Hibernate delay:** `HibernateDelaySec=` in
  `/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf`
  (default `2h`). This also sets how often an AC suspend checks the power
  source.

## Files

`enable` adds these, `disable` removes them:

```
~/.config/systemd/user/omatweaks-auto-hibernate.service
~/.config/systemd/user/omatweaks-auto-hibernate.timer
~/.config/systemd/user/timers.target.wants/omatweaks-auto-hibernate.timer
/run/user/$UID/omatweaks-auto-hibernate.since
/run/user/$UID/omatweaks-auto-hibernate.handled
/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf
/etc/systemd/system/systemd-suspend.service.d/60-omatweaks-auto-hibernate.conf
```

Older versions used different names. `enable` and `disable` also remove the old
files, so upgrading only needs one more `omatweaks auto-hibernate enable`.

## Requirements

Omarchy, systemd, `jq`, `git`, and working hibernation. Check with
`omarchy-hibernation-available`.

## Troubleshooting

```bash
omatweaks auto-hibernate status
systemctl --user status omatweaks-auto-hibernate.timer
journalctl --user -u omatweaks-auto-hibernate.service -n 50
systemd-analyze cat-config systemd/sleep.conf | grep HibernateDelaySec
journalctl -b | grep -E 'PM: hibernation|Performing sleep operation'
```

If it suspends but never hibernates, look for
`System returned from sleep operation 'suspend-then-hibernate'` without
`Performing sleep operation 'hibernate'`. That is systemd issue #38193: the
wake alarm can fire a fraction early and systemd treats it as a manual wake.
The tweak retries after one minute of idle. A permanent fix is in systemd
PR #44650.
