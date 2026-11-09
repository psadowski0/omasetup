#!/bin/bash
# Root helper for ui-scale. Installed at /usr/local/lib/omasetup/ui-scale/system.sh.
#
# It changes only FONT in /etc/vconsole.conf, which the consolefont hook bakes
# into the boot image, and then rebuilds that image. The display scale, the
# shell base size, and the terminal font are per-user settings and are not
# touched here.
set -euo pipefail

state_dir="${UI_SCALE_ROOT_STATE:-/var/lib/omasetup/ui-scale}"
vconsole="${UI_SCALE_VCONSOLE:-/etc/vconsole.conf}"
font_dir="${UI_SCALE_FONT_DIR:-/usr/share/kbd/consolefonts}"
boot_image="${UI_SCALE_BOOT_IMAGE:-}"
rebuild_command="${UI_SCALE_REBUILD:-}"

font=latarcyrheb-sun32
font_file="$font_dir/$font.psfu.gz"

usage() {
  local code="${1:-2}"
  cat >&2 <<'EOF'
Usage: system.sh <command>

Commands:
  install    Set the console font and rebuild the boot image.
  uninstall  Restore the previous console font and rebuild the boot image.
  verify     Check that the boot image contains the console font.
  status     Print the current console font and the saved state.

This command is run by the ui-scale command with sudo.
EOF
  exit "$code"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "ui-scale: This helper must run as root." >&2
  exit 1
fi

rebuild() {
  if [ -n "$rebuild_command" ]; then
    eval "$rebuild_command"
  elif command -v limine-mkinitcpio >/dev/null 2>&1; then
    limine-mkinitcpio
  elif command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
  else
    echo "ui-scale: No initramfs rebuild command was found, so the boot image was not updated." >&2
    return 1
  fi
}

find_boot_image() {
  local candidate version

  if [ -n "$boot_image" ]; then
    printf '%s\n' "$boot_image"
    return 0
  fi

  candidate=/boot/EFI/Linux/omarchy_linux-omarchy.efi
  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  version=$(uname -r)
  candidate=$(find /boot/EFI/Linux -maxdepth 1 -type f -name "*${version}*.efi" 2>/dev/null | sort | head -n 1)
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  find /boot -type f -path '*/EFI/Linux/*.efi' 2>/dev/null | sort | head -n 1
}

# The consolefont hook stores the uncompressed font in the initramfs. Return
# the hash of that file, or nothing when the image has no console font.
embedded_font_hash() {
  local image tmp embedded

  image=$(find_boot_image)
  [ -n "$image" ] || return 1
  command -v objcopy >/dev/null 2>&1 || return 1
  command -v lsinitcpio >/dev/null 2>&1 || return 1

  tmp=$(mktemp -d) || return 1
  if ! objcopy -O binary --only-section=.initrd "$image" "$tmp/initrd" 2>/dev/null; then
    rm -rf -- "$tmp"
    return 1
  fi
  mkdir -p "$tmp/root"
  if ! (cd "$tmp/root" && lsinitcpio -x --cpio "$tmp/initrd" >/dev/null 2>&1); then
    rm -rf -- "$tmp"
    return 1
  fi

  embedded=$(find "$tmp/root" -maxdepth 1 -type f -name 'consolefont*' | head -n 1)
  if [ -n "$embedded" ]; then
    sha256sum -- "$embedded" | cut -d' ' -f1
  fi
  rm -rf -- "$tmp"
}

font_hash() {
  zcat -- "$font_file" | sha256sum | cut -d' ' -f1
}

image_has_font() {
  local embedded expected
  embedded=$(embedded_font_hash) || return 2
  expected=$(font_hash)
  [ -n "$embedded" ] && [ "$embedded" = "$expected" ]
}

current_font() {
  sed -n 's/^FONT=//p' "$vconsole" 2>/dev/null | tail -n 1
}

backup_font() {
  sed -n 's/^FONT=//p' "$state_dir/vconsole.before" 2>/dev/null | tail -n 1
}

# Replace only the FONT line. Every other key, including the ones that belong
# to keyboard-pl-dh, is kept exactly as it is.
write_font() {
  local value=$1 tmp

  tmp=$(mktemp) || return 1
  awk -v val="$value" '
    /^[[:space:]]*FONT=/ { if (!done) { print "FONT=" val; done = 1 } ; next }
    { print }
    END { if (!done) print "FONT=" val }
  ' "$vconsole" >"$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  chown 0:0 -- "$tmp" 2>/dev/null || true
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$vconsole"
}

remove_font_line() {
  local tmp

  tmp=$(mktemp) || return 1
  awk '!/^[[:space:]]*FONT=/' "$vconsole" >"$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  chown 0:0 -- "$tmp" 2>/dev/null || true
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$vconsole"
}

save_state() {
  mkdir -p -- "$state_dir"
  printf '%s\n' "$font" >"$state_dir/active"
  chmod 0644 -- "$state_dir/active"
}

# Apply the font to the running consoles as well, so Ctrl+Alt+F2 shows it
# without a reboot. This only runs for the real vconsole file, never for a
# sandbox copy, and a failure here does not undo the saved configuration.
apply_to_consoles() {
  [ "$vconsole" = /etc/vconsole.conf ] || return 0
  [ -x /usr/lib/systemd/systemd-vconsole-setup ] || return 0
  /usr/lib/systemd/systemd-vconsole-setup >/dev/null 2>&1 || true
}

install() {
  local previous status

  if [ ! -f "$font_file" ]; then
    echo "ui-scale: The console font $font is not installed." >&2
    return 1
  fi

  if [ -f "$state_dir/vconsole.before" ]; then
    :
  else
    mkdir -p -- "$state_dir"
    cp -a -- "$vconsole" "$state_dir/vconsole.before"
    chmod 0644 -- "$state_dir/vconsole.before"
  fi

  previous=$(current_font)

  if [ "$previous" = "$font" ]; then
    if image_has_font; then
      save_state
      apply_to_consoles
      echo "ui-scale: The console already uses $font, and the boot image contains it."
      return 0
    fi
  fi

  if [ "$previous" != "$font" ]; then
    write_font "$font"
  fi

  echo "ui-scale: Rebuilding the boot image."
  if ! rebuild; then
    echo "ui-scale: The boot image was not rebuilt, so the console font was restored." >&2
    if [ "$previous" != "$font" ]; then
      if [ -n "$previous" ]; then write_font "$previous"; else remove_font_line; fi
      rebuild || true
    fi
    return 1
  fi

  set +e
  image_has_font
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    echo "ui-scale: The boot image does not contain $font, so the change was undone." >&2
    if [ -n "$previous" ]; then write_font "$previous"; else remove_font_line; fi
    rebuild || true
    return 1
  fi

  save_state
  apply_to_consoles
  echo "ui-scale: The boot image contains $font."
}

uninstall() {
  local previous status

  [ -f "$state_dir/vconsole.before" ] || {
    echo "ui-scale: There is no saved console font to restore." >&2
    return 1
  }

  previous=$(backup_font)

  if [ -f "$font_file" ]; then
    if [ -n "$previous" ]; then write_font "$previous"; else remove_font_line; fi
  elif [ -n "$previous" ] && [ "$previous" != "$font" ]; then
    write_font "$previous"
  else
    remove_font_line
  fi

  echo "ui-scale: Rebuilding the boot image."
  if ! rebuild; then
    echo "ui-scale: The boot image was not rebuilt, so the console font was not restored." >&2
    return 1
  fi

  set +e
  image_has_font
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "ui-scale: The boot image still contains $font." >&2
    return 1
  fi

  rm -f -- "$state_dir/active"
  apply_to_consoles
  if [ -n "$previous" ]; then
    echo "ui-scale: The console uses $previous again."
  else
    echo "ui-scale: The console has no FONT setting again."
  fi
}

verify() {
  local status

  if [ "$(current_font)" != "$font" ]; then
    echo "ui-scale: The console font is not $font." >&2
    return 1
  fi
  echo "ui-scale: The console font is $font."

  set +e
  image_has_font
  status=$?
  set -e
  case "$status" in
    0) echo "ui-scale: The boot image contains $font." ;;
    1)
      echo "ui-scale: The boot image does not contain $font." >&2
      return 1
      ;;
    *)
      echo "ui-scale: The boot image could not be inspected." >&2
      return 2
      ;;
  esac
}

print_status() {
  local current saved active
  current=$(current_font)
  saved=$(backup_font)
  active=no
  [ -f "$state_dir/active" ] && active=yes

  echo "ui-scale helper"
  echo
  echo "  Console font     ${current:-unset}"
  echo "  Saved before     ${saved:-unset}"
  echo "  Module state     $active"
}

case "${1:-}" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  verify)
    verify
    ;;
  status)
    print_status
    ;;
  -h | --help | help)
    usage 0
    ;;
  *)
    usage
    ;;
esac
