# How auto-night works

auto-night uses the systemd user manager that Omarchy already runs. `enable`
installs two small units, two wallpapers, and a little state. `disable` removes
exactly that. The module does not depend on the Omasetup app and never edits
`/usr/share/omarchy/`.

## The short version

- **The trigger:** one transient systemd timer is armed for the next sunrise or
  sunset, to the second. Nothing polls.
- **The change:** at that instant the timer runs `auto-night trigger`. It reads
  the clock, compares it with cached sun times, and starts the change with
  `omarchy theme set` (or `omarchy theme bg set` when the theme is already
  right) as its first external command.
- **Login:** `auto-night-session.service` runs before the desktop starts and
  writes the correct theme, so the desktop comes up correct. `auto-night-live`
  runs after login to set night light, which needs Hyprland.
- **A wrong clock:** if the clock is clearly wrong, the module leaves the theme
  alone and arms a path unit on the NTP sync stamp. It applies the correct
  preset the moment the clock synchronizes.
- **Night light:** 4000 K between sunset and sunrise. Omarchy's 07:00 hyprsunset
  profile is neutralized while the module is on and restored on disable.

## The trigger

There is no loop and no periodic check. For each change the module runs:

```bash
systemd-run --user --collect --unit=auto-night-at-<epoch> \
  --on-calendar=@<epoch> \
  --timer-property=AccuracySec=1us \
  auto-night trigger
```

- `@<epoch>` is the exact Unix second of the next sunrise or sunset.
- `AccuracySec=1us` removes systemd's default one-minute slack. In practice the
  timer fires about 60 ms after the target.
- The unit is transient, so it disappears after it fires. The next run arms the
  following one.
- `Restart=on-failure` with `RestartSec=2` retries a trigger that failed for a
  transient reason.

The hot path is deliberately small: `source` the state, read the clock with the
bash builtin, read the current theme name, compare integers, then make the first
external call. There is no network access and no Python on this path; the sun
cache is reused.

### Why one timer and not a scheduler

A timer armed at the exact instant costs nothing while it waits. A polling loop
would wake the machine repeatedly, and a coarse timer would be minutes late. The
module therefore recomputes the sun times only when the day changes, the clock
jumps, or the cache is invalid, and otherwise keeps one precise timer.

## Login, resume, and boot

| Unit | When it runs | What it does |
|---|---|---|
| `auto-night-session.service` | `Before=graphical-session-pre.target` | Writes the correct theme headless, so the first frame is correct. |
| `auto-night-live.service` | `After=graphical-session.target` | Re-applies the theme live and sets night light. |

The live unit always re-asserts night light, because `hyprsunset` is started by
the graphical session and does not survive a logout. The session unit does not
touch night light; there is no compositor yet.

After suspend or hibernate, an overdue transient timer fires when systemd
resumes. After a power loss, the session unit runs at boot. In both cases the
desktop is corrected without a poll.

## A wrong clock

The module refuses to trust a clock that cannot be right:

- **Lower bound:** `min_epoch=1794268800` (2026-11-10 00:00 UTC), the day the
  module was written. A clock earlier than the module itself is provably wrong.
  This constant is set once and never bumped, so it stays safe.
- **Upper bound:** 2100-01-01.
- **Clock jumps:** the module compares `NOW - /proc/uptime` between runs in the
  same boot. A correction larger than 5 seconds invalidates the sun cache.
  `/proc/uptime` includes suspend, so an ordinary sleep and resume does not look
  like a jump.

When the clock is implausible, the module leaves the previous theme in place and
arms:

```bash
systemd-run --user --collect --unit=auto-night-sync \
  --path-property=PathChanged=/run/systemd/timesync/synchronized \
  auto-night synced
```

`PathChanged` fires once when the stamp is created or updated. `PathExists` is
not used: it re-fires continuously while the path exists. `synced` applies the
correct preset and disarms the watcher as soon as the clock is plausible.

This is also armed whenever `NTPSynchronized=false`, even if the clock looks
plausible, so a plausible-but-wrong clock is corrected as soon as NTP lands.

## The sun times

`sun.py` is a line-for-line port of the solar math in Omarchy's world clock
(`Sun.js` and `GlobeModel.js`). The module and the world clock therefore agree
exactly. The port was checked against the JavaScript across 384 place and date
cases with zero mismatches.

The module never uses the network or your IP address. A VPN cannot move your
sunrise.

### Where the place comes from

1. **A pin:** `auto-night location --set LAT,LON`, stored in
   `~/.config/omasetup/auto-night.json`.
2. **The world clock's `here` place**, but only when its timezone matches the
   local timezone. A world clock showing another city does not move your theme.
3. **The world clock's `homeCity`.**
4. **The city of the system timezone.** `/etc/localtime` is resolved through
   `tzdata.zi`, so an alias such as `Poland` becomes `Europe/Warsaw`, and the
   city table supplies Warsaw's coordinates.
5. **The timezone's standard offset**, when the world clock has no city for the
   zone. This is approximate, and `auto-night location` says so.

The chosen place is printed by `auto-night location` and `auto-night status`,
together with its source.

### The cache

`~/.local/state/omasetup/auto-night/sun` holds today's and tomorrow's sunrise
and sunset, the local day boundaries, and a `recompute_after` instant. It is
recomputed when:

- the local day changes (including a DST day, which can be 23 or 25 hours),
- the clock jumps,
- a cached transition is already in the past.

Polar night and midnight sun are stored as a period and a recompute time, so the
module does not invent a sunrise that does not happen.

## What gets applied

### Theme and wallpaper

At each period change:

- If the current theme is not the target, `omarchy theme set <theme>` runs. This
  swaps the palette and the background together.
- If the current theme is already the target, the theme is not re-set. Calling
  `omarchy theme set` for the same theme cycles the background, which would be
  wrong.
- The wallpaper is forced with `omarchy theme bg set <file>` even when the theme
  was already correct. This covers a manual background change and a theme that
  was already on screen.

The module ships two 64×64 solid PNGs and installs them as:

```text
~/.config/omarchy/backgrounds/white/0-white.png
~/.config/omarchy/backgrounds/vantablack/0-black.png
```

Omarchy remembers a background per theme in
`~/.local/state/omarchy/theme-backgrounds/`. The module seeds those two entries
so a switch does not flash the theme's stock image, then forces its own
wallpaper afterwards. It backs up the previous entries on `enable` so `disable`
can put them back.

A manual theme change between two transitions is preserved. The module only acts
at a transition, so it never fights you between them.

### Night light

Night light is 4000 K. The module uses `omarchy toggle nightlight`, but first
reads `hyprctl hyprsunset temperature` so the call is idempotent:

- below 6000 K means on,
- 6000 K or above means off.

Turning it off also sends `hyprctl hyprsunset identity`, because a 6500 K
temperature still tints the screen. Omarchy reads the reported temperature, so
the module mirrors what `omarchy-toggle-nightlight` does.

### hyprsunset

Omarchy ships a `hyprsunset.conf` with a `07:00 identity` profile. In winter that
turns night light off before sunrise, which would fight the module. While
auto-night is on, it replaces every profile with one managed profile:

```text
profile {
    time = 12:00
    identity = true
}
```

`hyprsunset` applies a single profile around the clock, so one identity profile
holds the neutral state no matter when hyprsunset starts. In polar night there is
no daytime, so the managed profile holds the tint instead:

```text
profile {
    time = 00:00
    temperature = 4000
}
```

The original file is copied to
`~/.local/state/omasetup/auto-night/hyprsunset.conf.before` before the first
change and restored byte-for-byte on `disable`. If `omarchy refresh hyprsunset`
rewrites the file, the next trigger neutralizes it again. `disable` does not
restart hyprsunset, so the night light you see at that moment is left alone.

## Files

`enable` adds these files:

```text
~/.config/systemd/user/auto-night-session.service
~/.config/systemd/user/auto-night-live.service
~/.config/omarchy/backgrounds/white/0-white.png
~/.config/omarchy/backgrounds/vantablack/0-black.png
~/.local/state/omasetup/auto-night/state
~/.local/state/omasetup/auto-night/sun
~/.local/state/omasetup/auto-night/hyprsunset.conf.before
~/.local/state/omasetup/auto-night/theme-backgrounds.before
```

At runtime, two transient units exist:

```text
auto-night-at-<epoch>.timer   the next sunrise or sunset
auto-night-sync.path          only while the clock is not trusted
```

`disable` removes the units, stops the transient units, restores
`hyprsunset.conf` and the remembered theme backgrounds, removes the wallpapers
it is not currently showing, and deletes the state. It leaves the theme,
wallpaper, and night light as they are at that moment, so the desktop never goes
blank.

## Settings

- **Theme names:** `theme_day` and `theme_night` at the top of the command.
- **Night light temperature:** the normal toggle uses Omarchy's `ON_TEMP`
  (4000 K). The polar-night hyprsunset profile hardcodes 4000 K; change both if
  you change the temperature.
- **Clock bounds:** `min_epoch` and `max_epoch` at the top of the command. Do
  not lower `min_epoch`; it is what makes a pre-release clock detectably wrong.

## Requirements

Omarchy, Python 3, systemd user services, and systemd-timesyncd (Omarchy's
default). The sync watcher listens on
`/run/systemd/timesync/synchronized`, the stamp systemd-timesyncd writes.

## Troubleshooting

```bash
auto-night status
auto-night verify
systemctl --user list-timers --all 'auto-night*'
systemctl --user status auto-night-session.service auto-night-live.service
journalctl --user -u 'auto-night-at-*' -n 50
journalctl --user -u auto-night-sync -n 50
```

- **The theme did not change at sunrise:** check `auto-night status` for the
  armed timer, and `auto-night verify` for the units. If the clock was wrong,
  the status says the next change is not armed yet.
- **Night light is on in daylight:** check
  `omarchy toggle nightlight --status`. If `hyprsunset` was restarted by
  something else, the next trigger re-neutralizes the config.
- **The place is wrong:** run `auto-night location` to see the source, then
  `auto-night location --set LAT,LON`.
