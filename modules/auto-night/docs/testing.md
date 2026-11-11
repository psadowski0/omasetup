# Test log

auto-night was tested on 11 November 2026 on real hardware and in a disposable
sandbox. The sandbox is the part that can drive the clock through a whole day in
seconds; the real machine is the part that proves the units, the timer, the
theme switch, and the night light actually work on Omarchy.

## The machine

| | |
|---|---|
| Laptop | Framework Laptop 13 (AMD Ryzen 7040 series) |
| CPU / RAM | Ryzen 5 7640U / 14.9 GiB |
| Firmware | BIOS 03.20 |
| System | Omarchy 4.5.0-3 on Arch, kernel 7.2.15-1-omarchy, systemd 262.1 |
| Session | Hyprland 0.56.2 on Wayland |
| Clock | systemd-timesyncd, `NTPSynchronized=yes` |
| Location | Krakow, from the world clock's `here` place |

## How it was tested

### 1. The sun math

`sun.py` is a port of Omarchy's own world clock. It was compared with the
JavaScript (`Sun.js` / `GlobeModel.js`) across 384 combinations of place, date,
and timezone, including DST boundaries and polar latitudes. There were zero
mismatches; the largest difference was 0 ms.

The comparison was run with Node.js against the installed
`/usr/share/omarchy/shell/plugins/panels/elsewhen/` files. A separate 16-check
suite covers:

| Check | Result |
|---|---|
| Warsaw 2026-11-11, sunrise and sunset (UTC) | 05:49:41 / 14:50:17 ✅ |
| Quito, an equatorial city | 10:54:12 / 23:01:39 ✅ |
| Sydney, southern hemisphere | 18:46:20 / 08:31:57 ✅ |
| Warsaw DST spring-forward day is 23 hours | ✅ |
| Tromsø 2026-12-21 is polar night | ✅ |
| Tromsø 2026-06-21 is midnight sun | ✅ |
| `Poland` resolves to `Europe/Warsaw` | ✅ |
| Environment hook, pin, `here`, `homeCity`, timezone order | 5/5 ✅ |
| JSON output is valid | ✅ |
| `AUTO_NIGHT_NOW` drives the clock | ✅ |
| An unknown timezone fails cleanly | ✅ |

The Warsaw result was also checked against wttr.in for the same day
(06:49 / 15:50 local), which agreed to the minute.

### 2. The state machine

A disposable sandbox replaced `omarchy`, `hyprctl`, `systemctl`,
`systemd-run`, `busctl`, `pgrep`, `omarchy-restart-hyprsunset`,
`omarchy-shell`, and `uwsm-app` with stubs on `PATH`. Every config, state, and
asset path was redirected into `/tmp/opencode/an-sandbox`. The real desktop was
not touched.

82 checks passed:

| Group | Checks |
|---|---|
| Enable in daylight | 15 |
| Enable is idempotent | 3 |
| Sunset trigger | 5 |
| Manual theme change is preserved | 3 |
| Same theme is not re-set, wallpaper is still forced | 5 |
| Sunrise overrides a third theme | 2 |
| Implausible clock waits for sync | 5 |
| Clock jump invalidates the sun cache | 2 |
| Stale transition does not loop | 1 |
| `omarchy refresh` is re-neutralized | 2 |
| Polar night profile | 6 |
| Pre-session apply | 5 |
| Disable round-trip | 13 |
| Disable restores remembered theme backgrounds | 5 |
| Location resolution and pinning | 6 |
| Status text | 4 |

Notable behaviours the sandbox proves:

- A manual theme between two triggers is left alone; the next sunrise replaces
  it.
- A trigger for the theme already on screen does not call `omarchy theme set`
  again, but still forces the wallpaper.
- An implausible clock changes nothing, arms the sync watcher, and applies the
  correct preset when the sync stamp appears.
- A clock jump recomputes the sun cache.
- A stale transition re-arms a future timer instead of firing in a loop.
- `disable` leaves the visible theme, wallpaper, and night light alone, restores
  `hyprsunset.conf` byte-for-byte, and removes the units, state, and unused
  wallpaper.
- `disable` restores a custom remembered background for a theme, and removes an
  entry the module created.

`bash -n` and ShellCheck 0.10.0 with `-S warning` pass.

A separate race test reproduces Omarchy's `omarchy-restart-app` behaviour: the
helper kills `hyprsunset` and relaunches at once, and the relaunch can lose the
socket race and exit. v0.6.0 left night light off in that case. v0.6.1 waits for
the old process to exit, then starts a fresh one if the race still lost. The
test fails on v0.6.0 and passes on v0.6.1.

### 3. The real machine

The original state was captured first:

| | Before |
|---|---|
| Theme | Vantablack |
| Background | `~/.local/state/omarchy/current/theme/backgrounds/0-dot-hands.webp` |
| Night light | Off (`{"enabled":false,"temperature":null}`) |
| hyprsunset | Not running |
| `hyprsunset.conf` | The stock `07:00 identity` profile |

`auto-night enable` at 00:47 CET produced:

| Check | Result |
|---|---|
| Theme | Vantablack ✅ |
| Background | `~/.config/omarchy/backgrounds/vantablack/0-black.png` ✅ |
| Night light | On at 4000 K ✅ |
| hyprsunset | Running ✅ |
| `hyprsunset.conf` | Managed `12:00 identity` profile ✅ |
| Original config | Backed up in `~/.local/state/omasetup/auto-night/` ✅ |
| Remembered backgrounds | The `white` and `vantablack` entries were absent, backed up as absent, and removed again on disable ✅ |
| Units | Both enabled ✅ |
| Timer | One timer, armed for 2026-11-11 06:46:47 ✅ |
| `auto-night status` | All fields correct ✅ |
| `auto-night verify` | Exit 0 ✅ |

A simulated daytime trigger (`AUTO_NIGHT_NOW`, 12:00 UTC) switched to White,
installed the white wallpaper, and turned night light off. A simulated night
trigger switched back to Vantablack, the black wallpaper, and 4000 K. The timer
was re-armed for 2026-11-12 06:48:26.

`auto-night disable` then:

| Check | Result |
|---|---|
| Theme | Unchanged ✅ |
| Background link | Unchanged ✅ |
| Night light | Unchanged ✅ |
| `hyprsunset.conf` | Byte-for-byte the original ✅ |
| Units | Removed ✅ |
| Timers | None ✅ |
| State | Removed ✅ |
| Unused wallpaper | Removed ✅ |
| In-use wallpaper | Kept, so the desktop did not blank ✅ |
| Second `disable` | Harmless ✅ |

The original wallpaper was then restored with `omarchy theme bg set`, and a
second `disable` removed the leftover black asset. The final live state matched
the captured original: same theme, same background, same config, night light
off, hyprsunset stopped.

## Not tested

- **A real sunrise or sunset was not waited for.** The timer was confirmed armed
  in the real systemd with the correct epoch. Waiting hours for a wall-clock
  transition would not test anything the sandbox does not already test.
- **A real suspend or hibernate across a transition was not performed.** The
  module relies on systemd firing an overdue timer on resume and on the session
  unit at boot. That mechanism is standard systemd behaviour, but it was not
  observed on this machine across a real sleep.
- **The lock screen was not watched across a transition.** The palette comes
  from the live Quickshell theme. The blurred wallpaper is captured at lock
  time, so it is expected to lag until unlock. That expectation comes from the
  plugin's code, not from a visual test.
- **Polar night and midnight sun were tested in the sandbox only**, not by
  living in Tromsø.
- **The wrong-clock path was tested in the sandbox and caught a real bug during
  development.** The first plausibility floor was midnight UTC on 11 November;
  the live clock was 23:47 UTC on 10 November, so `enable` correctly refused to
  trust it. The floor was corrected to the module's first day. The machine clock
  itself was not deliberately set backwards.
- **Only one machine, one monitor, and one timezone were used.**
- **Only systemd-timesyncd was tested.** The sync watcher listens on
  `/run/systemd/timesync/synchronized`, the stamp timesyncd writes. A system
  using chrony or another NTP client was not tested.

## What the tests show

- The sun times match Omarchy's world clock exactly.
- The trigger is one exact timer, not a poll, and it is armed for the right
  instant.
- The theme, wallpaper, and night light follow the period, including a manual
  theme change that must be preserved until the next transition.
- A wrong clock does not produce a wrong theme; the module waits and then
  applies.
- `disable` restores what `enable` changed and leaves the visible desktop
  alone.

## Honest answer to "is it always instant?"

While you are logged in and the machine is awake, the change starts at the
armed second; systemd fires about 60 ms after it. It cannot be instant when the
correct answer is unknown or the session is not running: a wrong clock waits for
NTP, a suspended machine applies on resume, a powered-off machine applies at
boot, a logged-out machine applies at login, and a locked screen's blurred
wallpaper catches up at unlock.
