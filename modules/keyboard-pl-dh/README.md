# keyboard-pl-dh

keyboard-pl-dh is an independent module in [Omasetup](../../README.md). It runs
on its own and does not need the Omasetup app.

## What is it?

It puts Polish Colemak-DH in two places:

- **On the desktop**, as the first layout, with plain Polish QWERTY as the
  second. Switch between them with the layout indicator on the Omarchy bar.
- **At the boot passphrase prompt**, as the only layout. This is the prompt
  before the desktop starts, so it covers LUKS, Plymouth, and the SDDM greeter.

The two are separate on purpose. Changing the desktop layout in the Omarchy menu
changes only the desktop. The boot prompt stays on Polish Colemak-DH until you
run `keyboard-pl-dh disable` or change it yourself.

## Why is this needed?

Omarchy already separates the two:

- The menu writes `~/.config/omarchy/keyboard-layouts`, and Hyprland reads it
  for the desktop.
- `/etc/vconsole.conf` holds `KEYMAP`, and mkinitcpio bakes it into the boot
  image for the passphrase prompt.

What is missing is Polish Colemak-DH in the menu. Stock `xkeyboard-config` has
`pl(colemak_dh)` and `pl(colemak_dh_ansi)`. They are listed in
`evdev.extras.xml` with `popularity="exotic"`, so `xkbcli list` shows them only
with `--load-exotic`, and `localectl` and Omarchy's fixed catalog leave them
out. This module adds the catalog label the picker needs and selects the stock
layout.

There is also no Polish Colemak-DH console keymap in `kbd`. The module uses
`mod-dh-iso-us`, the ISO US Colemak-DH map. It has the DH letter and punctuation
positions but no ą/ę/ł/ń/ć/ź/ż. The boot passphrase must therefore be ASCII-only.

## Desktop

The module writes:

```text
~/.config/omarchy/keyboard-layouts
```

```text
XKBLAYOUT=pl,pl
XKBVARIANT=colemak_dh,
```

The first entry is Polish Colemak-DH (ISO). The second is plain Polish QWERTY.
Both are stock XKB layouts; no layout is created from scratch.

The module also writes a user copy of the Polish symbols file:

```text
~/.config/xkb/symbols/pl
```

It changes one line, the compiled name of `pl(colemak_dh)`, from
`Polish (Colemak-DH ISO)` to `Colemak-DH (PL)`. The bar's `xkbcli` table still
uses the stock description, so the bar shows **COL** for Colemak-DH and **PL**
for plain Polish QWERTY instead of PL for both.

The copy is generated from the stock file and carries a marker comment. A
re-run regenerates it, so an `xkeyboard-config` update is picked up. If you
already had your own `pl` symbols file, the module renames that copy and
restores it byte for byte on `disable`. The file is validated with
`xkbcli compile-keymap` before it is installed.

Before writing, the module saves the previous layout file and symbols file in
`~/.local/state/omasetup/keyboard-pl-dh/`. If there was no file, it records that
too. `disable` puts the previous files back byte for byte, or removes them if
there were none.

## Menu

The module adds a marked block to:

```text
~/.config/omarchy/extensions/omarchy-menu.jsonc
```

```jsonc
// omasetup:keyboard-pl-dh begin
// Added by the keyboard-pl-dh module. Removed by "keyboard-pl-dh disable".
"setup.typing.keyboard": {"icon":"\uf11c","label":"Keyboard Layouts","action":"keyboard-pl-dh picker"},
// omasetup:keyboard-pl-dh end
```

This changes the action of the stock **Setup → Typing → Keyboard Layouts** row.
It opens `keyboard-pl-dh picker`, a thin wrapper around Omarchy's own picker
that adds `Polish (Colemak-DH ISO)` as the label for `pl:colemak_dh`. Without
it, the picker would show the raw key.

The icon and label have to be repeated. Omarchy normalizes a user row before
merging it over the stock row, so an omitted label becomes the raw id
(`setup.typing.keyboard`) and an omitted icon becomes empty. `enable` copies
the icon from Omarchy's default menu and the label from its menu catalog for
the current language, so a translated menu keeps its translation and the row
keeps the keyboard glyph. If you change the menu language later, run
`keyboard-pl-dh enable` again to refresh the label.

The block is rewritten on every `enable`, so an update to this module replaces
an older action instead of leaving it behind. `disable` removes only the lines
between the markers. Everything else in the file is left alone.

The menu action calls `keyboard-pl-dh` from `PATH`. Run `keyboard-pl-dh link`
once (the install command below does), and log in again after linking.

## Boot passphrase

The module changes only these lines in `/etc/vconsole.conf`:

```text
KEYMAP=mod-dh-iso-us
XKBLAYOUT=pl
XKBVARIANT=colemak_dh
```

`FONT` is not changed. The module keeps the font that was in the file before it
was first enabled, and does not add one if there was none. `XKBMODEL` and
`XKBOPTIONS` are kept. The previous file is saved in
`/var/lib/omasetup/keyboard-pl-dh/vconsole.before`.

Then it rebuilds the boot image with `limine-mkinitcpio` and checks the result.
On this machine the build uses the `keymap` and `consolefont` hooks, so the
image stores a compiled `/keymap.bin` and `/consolefont.psfu`. The module
extracts the image's `.initrd` section, unpacks it, and compares `keymap.bin`
with what `loadkeys -b` produces for `mod-dh-iso-us`. It also understands the
`sd-vconsole` hook, which stores `/etc/vconsole.conf` and the map file, and
checks those instead.

A successful build is not enough: `limine-mkinitcpio` can exit 0 after writing
an image with a different keymap. If the image does not contain the new keymap,
the module restores the previous configuration, rebuilds, and fails instead of
reporting success. If the image cannot be inspected, it warns and leaves the
module active so the user can check `/boot`.

`disable` restores the saved file, rebuilds, and checks that the image is back
to the original keymap. If the restored image still carries another keymap, it
keeps the saved file and the active state so a later run can finish the job.

## Install

Run this command once. Omarchy already has `~/.local/bin` on `PATH`.

```bash
git clone --depth=1 https://github.com/psadowski0/omasetup.git \
  ~/.local/share/omasetup && ~/.local/share/omasetup/modules/keyboard-pl-dh/keyboard-pl-dh link
```

Then run:

```bash
keyboard-pl-dh enable
```

`enable` applies the desktop layout, the bar labels, and the menu override
first, then asks for confirmation before changing the boot keymap. The boot part
needs sudo.

## Use

```bash
keyboard-pl-dh enable     # Desktop layout, menu override, and boot keymap.
keyboard-pl-dh desktop    # Desktop layout and bar labels only. No sudo.
keyboard-pl-dh picker     # The labelled picker used by the menu.
keyboard-pl-dh verify     # Check the boot image. Uses sudo.
keyboard-pl-dh status     # What the desktop, the boot prompt, and the menu use.
keyboard-pl-dh disable    # Undo everything, including the boot keymap.
```

The desktop part applies immediately. The boot part applies at the next reboot.

`enable`, `desktop`, and `disable` can be run more than once.

## Test before you reboot

Colemak-DH moves letters **and punctuation**. An ASCII-only passphrase avoids
the Polish-letter problem, but the positions are still different.

First check that the boot image really contains the map:

```bash
keyboard-pl-dh verify
```

Then switch to a TTY (`Ctrl+Alt+F3`) and try it:

```bash
sudo loadkeys mod-dh-iso-us
nano /tmp/passphrase-test
```

Type your passphrase, compare it with what you expect, and exit without saving.
Then switch back with `Ctrl+Alt+F2`.

Keep a live USB nearby. If the passphrase cannot be typed at boot, boot the live
USB, mount the system, restore `/var/lib/omasetup/keyboard-pl-dh/vconsole.before`
to `/etc/vconsole.conf`, and rebuild, or run `keyboard-pl-dh disable` from the
installed system.

## Good to know

- The SDDM greeter follows `/etc/vconsole.conf`, so it also becomes Polish
  Colemak-DH. That is consistent with the passphrase prompt.
- TTYs become US Colemak-DH. They have no Polish letters, only the DH
  positions.
- The Omarchy menu never touches the boot keymap. That is stock behaviour, not
  something this module adds.
- The desktop layout is a per-user file. A second user on the same machine has
  their own layout, but the boot keymap is machine-wide.
- The bar label change needs a new Hyprland process, because Hyprland creates
  its XKB context at startup. Log out and back in, or reboot, after the first
  `enable`. Until then the bar may still show PL for both layouts.
- The menu override and the symbols file are user files, not package files. An
  Omarchy update does not remove them. `enable` regenerates the symbols file
  from the current stock file, so an `xkeyboard-config` update is picked up.
- The picker wrapper uses Omarchy's own catalog and only adds the missing
  label. It does not patch `/usr/share/omarchy`.
- `disable` removes only a menu block with both markers. A half-written or
  hand-edited block is left alone and reported.

## Requirements

- Omarchy 4.5 or newer, with the Lua Hyprland config.
- `xkeyboard-config` with `pl(colemak_dh)`. It is stock in 2.48.
- `kbd` with `mod-dh-iso-us`. It is stock in 2.10.
- `limine-mkinitcpio`, or `mkinitcpio -P`.
- An ASCII-only LUKS passphrase.

## Update

```bash
keyboard-pl-dh update
```

## Remove

```bash
keyboard-pl-dh disable && keyboard-pl-dh unlink && rm -rf ~/.local/share/omasetup
```

`disable` restores the desktop layout and the symbols file, removes the menu
override, restores `/etc/vconsole.conf`, and rebuilds the boot image.

## More

- [Full test log](docs/testing.md) lists every check and the evidence behind it.
- [Upstream notes](docs/upstream.md) describe what Omarchy itself would need to
  offer this layout.
- [Omasetup](../../README.md) explains the project that hosts this module.
- [Contributing](../../CONTRIBUTING.md) explains how to add a module.
- Omasetup uses the MIT license; see [LICENSE](../../LICENSE).
