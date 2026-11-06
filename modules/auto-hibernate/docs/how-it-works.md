# How auto-hibernate works

auto-hibernate plugs into the sleep system already provided by systemd and
Omarchy. The `enable` command adds a few drop-in files, and `disable` removes
them. The module does not depend on the Omasetup app.

## The short version

- **Lid and manual suspend:** systemd-logind and `systemd-suspend.service` are
  told to `suspend-then-hibernate`. `HibernateDelaySec=2h` sets the timer.
  `HibernateOnACPower=no` keeps it suspended while AC stays connected. If you
  unplug while suspended, the laptop hibernates at the next check (within 2 h).
- **Idle:** a user timer runs once a minute. When Omarchy reports the session as
  idle, it suspends; systemd hibernates later. It respects video and call
  inhibitors and the stay-awake toggle.
- **Early wake:** if systemd wakes after its timer but skips hibernation
  (systemd issue #38193), the next idle check notices the missing hibernation
  and hibernates after one minute of idle instead of sleeping again.
- **Timer:** without an explicit `HibernateDelaySec`, systemd waits for the 5%
  low-battery alarm, which can take days.

## Settings

- **Idle time:** `IDLE_MINUTES` in `modules/auto-hibernate/idle-check.sh`
  (default `10`). Revert that edit before `auto-hibernate update`.
- **Hibernate delay:** `HibernateDelaySec=` in
  `/etc/systemd/sleep.conf.d/60-auto-hibernate.conf`
  (default `2h`). This also sets how often an AC suspend checks the power
  source.

## Files

The `enable` command adds these files, and `disable` removes them:

```
~/.config/systemd/user/auto-hibernate.service
~/.config/systemd/user/auto-hibernate.timer
~/.config/systemd/user/timers.target.wants/auto-hibernate.timer
/run/user/$UID/auto-hibernate.since
/run/user/$UID/auto-hibernate.handled
/etc/systemd/logind.conf.d/30-auto-hibernate.conf
/etc/systemd/sleep.conf.d/60-auto-hibernate.conf
/etc/systemd/system/systemd-suspend.service.d/60-auto-hibernate.conf
```

## Requirements

The module needs Omarchy, systemd, `jq`, `git`, and working hibernation. Check
with `omarchy-hibernation-available`.

## Troubleshooting

```bash
auto-hibernate status
systemctl --user status auto-hibernate.timer
journalctl --user -u auto-hibernate.service -n 50
systemd-analyze cat-config systemd/sleep.conf | grep HibernateDelaySec
journalctl -b | grep -E 'PM: hibernation|Performing sleep operation'
```

If it suspends but never hibernates, look for
`System returned from sleep operation 'suspend-then-hibernate'` without
`Performing sleep operation 'hibernate'`. That is systemd issue #38193: the
wake alarm can fire a fraction early and systemd treats it as a manual wake.
The module retries after one minute of idle. A permanent fix is in systemd
PR #44650.
