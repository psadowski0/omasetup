# Upstream notes

This module works around two gaps that belong upstream. Neither is a bug in
Omarchy, but both make Polish Colemak-DH harder to offer than other layouts.

## 1. `pl(colemak_dh)` is marked exotic

Stock `xkeyboard-config` 2.48 ships the layout in
`/usr/share/X11/xkb/symbols/pl`:

```text
xkb_symbols "colemak_dh"      // ISO
xkb_symbols "colemak_dh_ansi" // ANSI
```

Both compile with `xkbcli compile-keymap --layout pl --variant colemak_dh` and
`--variant colemak_dh_ansi`. They are not in the `pl` block of
`/usr/share/X11/xkb/rules/evdev.xml`; they are in
`/usr/share/X11/xkb/rules/evdev.extras.xml` with `popularity="exotic"`:

```xml
<variant>
  <configItem popularity="exotic">
    <name>colemak_dh</name>
    <description>Polish (Colemak-DH ISO)</description>
  </configItem>
</variant>
```

As a result, `xkbcli list` shows them only with `--load-exotic`, and
`localectl list-x11-keymap-variants pl` omits them. GUI layout pickers that read
only the default list cannot offer them.

The fix is to promote the variants into `evdev.xml` (or stop marking them
exotic), plus the usual translation strings. That is an `xkeyboard-config`
change, not an Omarchy one. Until it lands, the layout can still be selected by
name, which is what this module does.

## 2. Omarchy's catalog has no Polish Colemak-DH row

Omarchy's menu reads a fixed catalog from
`/usr/share/omarchy/install/provisioning/setup-form.sh`:

```bash
OMARCHY_KEYBOARD_LAYOUTS=$'English (US)|us
...
Polish|pl
...'
```

The format is `label|console-keymap|input-method|XKB-setting`. The last field is
optional; when it is present it overrides the table lookup. A row for this
layout would be:

```text
Polish (Colemak-DH)|mod-dh-iso-us||pl:colemak_dh
```

That gives the picker the right desktop layout. The console keymap is the
problem.

This module does not patch that catalog. The same file feeds the installer's
`apply_keyboard`, which writes `/etc/vconsole.conf`; adding
`mod-dh-iso-us` there would make a fresh install choose a console map that is
not in systemd's `kbd-model-map`, with a layout the user may not expect at the
passphrase prompt. Instead the module leaves the package file alone and adds
the missing label in a user-level wrapper around Omarchy's picker.

## The console keymap gap

`kbd` ships `mod-dh-iso-us` and `mod-dh-ansi-us`, but both are US maps. They
have the DH letter and punctuation positions and no ą/ę/ł/ń/ć/ź/ż. Only ó is
available, on AltGr.

Omarchy's install flow uses the console keymap for the LUKS passphrase. A Polish
user who types Polish letters in the passphrase could not unlock the disk if the
installer chose `mod-dh-iso-us`. That is why this module requires an ASCII-only
passphrase and says so before changing anything.

A complete upstream row would need one of:

1. **A Polish Colemak-DH console map in `kbd`.** It would put ą/ę/ł/ń/ć/ź/ż on
   AltGr, following `pl(colemak_dh)`. Then the catalog row could use it and the
   passphrase could contain Polish letters. This is the clean fix, but it is a
   new keymap in `kbd`, not a one-line Omarchy change.
2. **A console map generated from XKB at build time.** `ckbcomp` (from
   `console-setup`) can convert an XKB layout to a console keymap. Omarchy does
   not depend on it today. Adding that dependency for one layout is a larger
   decision.
3. **Accept ASCII-only at install.** The row above works today for ASCII
   passphrases, but the installer would need to warn about it, and a user with
   Polish letters would be locked out.

This module takes option 3 locally, with an explicit warning and a TTY test
before rebooting. It does not pretend the console map has Polish letters.

## What this module does not change

- It does not patch `/usr/share/omarchy`. Package files stay untouched. The
  picker label lives in a user wrapper, and the menu override is a user file.
- It does not add a layout to `/usr/share/X11/xkb`. It selects the stock one.
  The bar-label override is a user copy in `~/.config/xkb/symbols/pl` that
  changes one compiled name; `disable` removes or restores it.
- It does not overwrite `~/.config/hypr/input.lua`. The supported seam is
  `~/.config/omarchy/keyboard-layouts`.
- It does not touch `/etc/X11/xorg.conf.d`. Hyprland does not read it.

## A possible upstream patch

If you want to send this upstream, the smallest useful change is:

1. Add `Polish (Colemak-DH)|mod-dh-iso-us||pl:colemak_dh` to
   `OMARCHY_KEYBOARD_LAYOUTS`.
2. Promote the `pl` variants from `evdev.extras.xml` into `evdev.xml` in
   `xkeyboard-config` (separate project).
3. Decide what to do about Polish letters at the passphrase prompt. Without a
   Polish console map, the row is only safe for ASCII passphrases.

The first item alone makes the desktop layout selectable from the stock picker.
It does not solve the boot prompt for non-ASCII passphrases.
