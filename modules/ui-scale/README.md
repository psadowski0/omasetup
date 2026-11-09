# ui-scale

ui-scale is an independent module in [Omasetup](../../README.md). It runs on its
own and does not need the Omasetup app.

## What is it?

ui-scale makes the desktop bigger in four places at once:

| Element | What it sets | Value |
|---|---|---|
| Desktop | Hyprland's scale for the built-in panel (`eDP-1`) | 1.33 |
| Shell | The base text size the bar, menus, panels, and notifications derive from | 14 px |
| Terminal | The font size in foot | 14 pt |
| Text console | The console font, also used inside the boot image | `latarcyrheb-sun32` (16×32) |

It targets one specific laptop panel. The display scale names `eDP-1`, and the
console font is chosen for a 2256×1504 screen. On a different machine, run
`UI_SCALE_OUTPUT=<output>` or edit the values at the top of the command.

## Why these values?

The built-in panel is 2256×1504. Omarchy's scale of 2 gives 1128×752 logical
pixels, which is very little room. A scale of 1.33 gives 1692×1128 and looks
right, but every element gets smaller in the process, because the same point
sizes are drawn at fewer pixels.

The other three values bring the interface back up:

| Element | Before | After |
|---|---|---|
| Logical desktop | 1128×752 | 1692×1128 |
| Shell base size | 12 px | 14 px (bar 26→30, icons 27→32, labels 13→15) |
| foot font | 9 pt | 14 pt |
| Console font | `default8x16` (282×94 cells) | `latarcyrheb-sun32` (141×47 cells) |

The console font is the largest the Linux console supports. The kernel caps
glyph height at 32 pixels, and `latarcyrheb-sun32` is the only 32-pixel font
that ships with `kbd` and covers all the Polish diacritics.

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/ui-scale/ui-scale link
```

Then run `ui-scale enable`. The text console is part of the boot image, so this
step asks for sudo and rebuilds the image. Everything else is per-user.

## Use

```bash
ui-scale enable     # Applies all four values. Sudo once, for the boot image.
ui-scale verify     # Checks the running values and the boot image. Sudo again.
ui-scale status     # Shows the value of each element and whether all are on.
ui-scale disable    # Restores all four previous values and rebuilds the image.
```

You can run `enable` and `disable` more than once.

New terminal windows pick up the new font size. Windows that are already open
keep their size until you reopen them; foot has no way to reload its font.

## How it works

### The desktop scale

The module writes one small file:

```text
~/.local/state/omarchy/toggles/hypr/ui-scale.lua
```

```lua
-- omasetup: ui-scale
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.33 })
```

That directory is Omarchy's documented place for permanent configuration flags.
Omarchy loads every `*.lua` file in it on each reload, after your own
`~/.config/hypr` files. Two things follow:

- The file wins over `~/.config/hypr/monitors.lua`, so the scale is applied.
- `omarchy refresh hyprland` only overwrites `~/.config/hypr`, so the scale
  survives it. This was checked on the real machine: after a refresh, which
  removed the `eDP-1` line from `monitors.lua`, Hyprland still reported 1.33.

`enable` runs `hyprctl reload` and then reads the scale back with
`hyprctl monitors`. Hyprland reports 1.33 as `1.3333334`, so the module compares
it as a number. If the scale did not change, the module removes the file again.

### The shell size

The module sets `[font] base-size` in `~/.config/omarchy/shell.toml`:

```toml
[font]
base-size = 14
```

Omarchy reads the user file after the active theme's `shell.toml`, so this wins
over the theme and survives theme switches. The shell watches the file and
reflows immediately. Everything that derives from the base size follows:

- the bar's height, icon sizes, and label text
- menus, panels, and notifications
- the dock labels and the lock screen

Other keys and sections in the file are left alone; the module only manages
`base-size`. If the file does not exist, the module creates it with a short
comment. `disable` removes the line again, and removes the file if nothing else
is left in it.

### The terminal

The module changes only the size on the `font=` line in
`~/.config/foot/foot.ini`:

```ini
font=JetBrainsMono Nerd Font:size=14
```

The font family and any other attributes stay as they are. The original line is
saved to `~/.local/state/omasetup/ui-scale/foot-font.before` and restored by
`disable`. foot has no reload signal, so the new size reaches new windows only.

Only foot is handled. alacritty, ghostty, and kitty are not installed on this
machine, and the module does not guess at their configuration.

Omarchy's own `omarchy display text size` command can disagree with the real
size. It reads the first terminal configuration it finds, and this machine still
has leftover configurations for terminals that are not installed (ghostty,
alacritty, and kitty). Those files still say 9 pt, so the command reports 9 pt
while foot really uses 14 pt. The module changes foot only, so that report stays
as it is.

### The text console and the boot image

This is the only part that needs root. The helper at
`modules/ui-scale/system.sh` changes only the `FONT` line in
`/etc/vconsole.conf`:

```text
FONT=latarcyrheb-sun32
```

Every other key is kept exactly as it is, including the ones `keyboard-pl-dh`
writes (`KEYMAP`, `XKBLAYOUT`, `XKBVARIANT`). The original file is saved to
`/var/lib/omasetup/ui-scale/vconsole.before` the first time the module is
enabled, and `uninstall` restores only the `FONT` value from it, not the whole
file.

The `consolefont` hook bakes the font into the boot image, so the helper then
rebuilds that image with `limine-mkinitcpio`. A successful build is not trusted:
the helper extracts the image, reads the embedded `consolefont.psfu`, and
compares its SHA-256 with the font on disk. If the image does not contain the
font, the previous setting is restored and the image rebuilt again.

The same font is applied to the running consoles with `systemd-vconsole-setup`,
so `Ctrl+Alt+F2` shows the new size without a reboot.

Note: this changes the text console, not the graphical unlock screen. The
passphrase prompt during boot is drawn by Plymouth with its own font, and it is
not affected.

## What it does not change

- GTK's `text-scaling-factor`, which stays at 1.0.
- `GDK_SCALE`, which stays at 2 and only affects X11 and XWayland apps.
- The cursor size, which stays at 24.
- The SDDM login screen, which has its own compositor and scale.
- The Plymouth unlock screen during boot.
- Other terminals besides foot.

## Tested in the real world

Tested on 8 and 9 November 2026 on real hardware: Framework Laptop 13, Omarchy
4.5.0-3, Hyprland 0.56.2, foot 1.28.0, kbd 2.10.0.

A disposable sandbox ran 52 checks on the user-level commands and 31 checks on
the root helper, with stubbed `hyprctl`, `sudo`, `objcopy`, and `lsinitcpio`, and
with every file redirected into a temporary directory.

On the real machine:

- `enable` set all four values and rebuilt the boot image; the embedded font's
  SHA-256 matched `latarcyrheb-sun32`.
- `disable` restored the scale, removed `base-size`, put foot back to 9 pt, put
  `FONT=default8x16` back, and rebuilt the image; the image no longer contained
  the big font.
- `enable` again restored all four values.
- `omarchy refresh hyprland` did not disturb the scale.
- `ui-scale verify` reported all four values and the boot image as correct.

The reboot check is still owed: the scale and the console font have not been
seen after a cold boot with the module enabled. The image contents were checked
directly, which is the part a reboot would otherwise have to prove.

## Update

```bash
git -C ~/.local/share/omasetup pull --ff-only
ui-scale version
```

Run `ui-scale enable` again after an update. It applies the four values and
rebuilds the image only when the console font is not already in place.

## Remove

```bash
ui-scale disable
ui-scale unlink
rm -rf ~/.local/share/omasetup
```

`disable` is the part that matters. It restores every value it changed. The
saved originals are in `~/.local/state/omasetup/ui-scale/` and
`/var/lib/omasetup/ui-scale/`.

One interaction to know about: `keyboard-pl-dh` keeps its own copy of
`/etc/vconsole.conf` from before it was first enabled. If you run
`keyboard-pl-dh disable` and then `keyboard-pl-dh enable`, it restores that copy
and may put `FONT=default8x16` back. Run `ui-scale enable` afterwards and it
will restore the console font and rebuild the image.
