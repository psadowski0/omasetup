# Test log

`auto-hibernate` was tested by a human in the real world, on real hardware, on
6 November 2026. The hardware tests ran on `v0.7.0`. Later releases change only
wording, documentation, and graphics.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 (2026-06-23) |
| System | Omarchy 4.5.0 on Arch, kernel 7.2.15, systemd 262.1 |
| Session | Hyprland on Wayland |
| Sleep | `s2idle` |
| Hibernation | encrypted 14.9 GiB swapfile; `omarchy-hibernation-available` passes |

Only the details that matter for suspend and hibernation are listed.

## How it was tested

A person closed the real lid, plugged and unplugged the real charger, left the
laptop idle, used stay-awake, and pressed the power button to resume. The
journal was checked after each run. Short delays (30 s and 2 min) were used
during some tests to avoid multi-hour waits; the shipped default is 2 h, and
that default was tested separately.

## Results

| # | Scenario | What happened |
|---|---|---|
| 1 | Manual suspend on battery | suspend 13:26:42 → hibernate 13:28:43 (2-min test delay) → resume 13:35:18 |
| 2 | Lid closed on battery | suspend 14:31:36 → hibernate 14:33:37 (2-min test delay) → resume 14:37:15 |
| 3 | Real 2-hour default | lid closed 14:42:21 → suspend → hibernate 16:42:22 → resume 21:26:59 |
| 4 | Lid closed on AC | suspended 21:41:55; woke and re-suspended at 21:43:55; no hibernation |
| 5 | Unplug while suspended | hibernate 21:45:56 → resume 21:56:47 |
| 6 | Idle on AC | Omarchy reported idle repeatedly between 22:02 and 22:08; no suspend |
| 7 | Stay-awake | 4 minutes with stay-awake on; no idle event, no suspend |
| 8 | Early-wake race (#38193) | suspend 14:03:53 → woke early 14:04:09 → retried and hibernated 14:08:07 |
| 9 | Disable → enable | all three drop-ins and the timer removed, then restored; no leftovers |

Additional checks passed: `bash -n`, ShellCheck 0.10.0 `-S warning`,
`omatweaks list`, and `status --quiet` (exit 0). GitHub CI also passed.

## Not tested on purpose

- **Below 5% battery:** Draining the battery to force this case is unsafe, so it
  was not tested.
- **Hybrid sleep:** This tweak does not change it, so there is nothing to test.

## Known systemd quirk

With a very short `HibernateDelaySec` (30 s), systemd issue #38193 reproduced
every time: the wake alarm fired a fraction early, systemd treated it as a
manual wake, and logind suspended again. The idle retry catches the normal
case; the shipped 2-hour default hibernated correctly. A permanent fix is in
systemd PR #44650.

## What the tests show

- The battery path works end to end: suspend, hibernate, resume.
- AC never hibernates while the charger stays connected.
- Unplugging while suspended still protects the battery.
- Video, calls, and stay-awake are respected.
- Removal is clean and repeatable.
