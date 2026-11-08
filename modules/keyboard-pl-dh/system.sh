#!/bin/bash
# Root helper for keyboard-pl-dh. Installed at
# /usr/local/lib/omasetup/keyboard-pl-dh/system.sh.
#
# It changes only the console keymap used before the desktop starts: the
# KEYMAP in /etc/vconsole.conf, which the sd-vconsole hook bakes into the boot
# image. The desktop layout is a per-user file and is not touched here.
set -euo pipefail

state_dir=/var/lib/omasetup/keyboard-pl-dh
vconsole=/etc/vconsole.conf
helper_installed=/usr/local/lib/omasetup/keyboard-pl-dh/system.sh

keymap=mod-dh-iso-us
xkb_layout=pl
xkb_variant=colemak_dh

usage() {
  local code="${1:-2}"
  cat >&2 <<'EOF'
Usage: system.sh <command>

Commands:
  install    Set the boot keymap and rebuild the boot image.
  uninstall  Restore the previous keymap and rebuild the boot image.
  verify     Check that the boot image contains the expected keymap.
  status     Print the current console keymap and the saved state.

This command is run by the keyboard-pl-dh command with sudo.
EOF
  exit "$code"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "keyboard-pl-dh: This helper must run as root." >&2
  exit 1
fi

rebuild() {
  if command -v limine-mkinitcpio >/dev/null 2>&1; then
    limine-mkinitcpio
  elif command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
  else
    echo "keyboard-pl-dh: No initramfs rebuild command was found, so the boot image was not updated." >&2
    return 1
  fi
}

write_vconsole() {
  local tmp font_value
  # FONT is not part of this module. Keep whatever the file had before the
  # module was first enabled, so a font choice is never silently replaced.
  font_value=$(sed -n 's/^FONT=//p' "$state_dir/vconsole.before" 2>/dev/null | tail -n 1)
  if [ -z "$font_value" ]; then
    font_value=$(sed -n 's/^FONT=//p' "$vconsole" 2>/dev/null | tail -n 1)
  fi

  tmp=$(mktemp) || return 1
  {
    grep -vE '^(KEYMAP|XKBLAYOUT|XKBVARIANT|FONT)=' "$vconsole" 2>/dev/null || true
    printf 'KEYMAP=%s\n' "$keymap"
    printf 'XKBLAYOUT=%s\n' "$xkb_layout"
    printf 'XKBVARIANT=%s\n' "$xkb_variant"
    if [ -n "$font_value" ]; then
      printf 'FONT=%s\n' "$font_value"
    fi
  } >"$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  chown 0:0 -- "$tmp" || true
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$vconsole"
}

restore_vconsole() {
  local backup=$state_dir/vconsole.before tmp
  [ -f "$backup" ] || return 1
  tmp=$(mktemp) || return 1
  cp -a -- "$backup" "$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  chown 0:0 -- "$tmp" || true
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$vconsole"
}

find_boot_image() {
  local candidate=/boot/EFI/Linux/omarchy_linux-omarchy.efi version
  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  # Prefer the UKI for the running kernel. The default name is
  # <machine-id>_<kernel-version>.efi, but a custom name may be configured.
  version=$(uname -r)
  candidate=$(find /boot/EFI/Linux -maxdepth 1 -type f -name "*${version}*.efi" 2>/dev/null | sort | head -n 1)
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  find /boot -type f -path '*/EFI/Linux/*.efi' 2>/dev/null | sort | head -n 1
}

# The boot image is built by whichever vconsole hook the system uses. This one
# uses sd-vconsole, which stores /etc/vconsole.conf and the keymap file in the
# initramfs and lets systemd-vconsole-setup load them. Older layouts use the
# keymap hook, which stores a compiled /keymap.bin. Both are accepted.
#
# Return 0 when the expected keymap is in the image, 1 when a different one is,
# and 2 when the image cannot be inspected.
verify_keymap() {
  local expected=${1:-$keymap} image tmp embedded actual with_u without_u
  local vconsole_keymap map_file

  if ! command -v objcopy >/dev/null 2>&1 ||
    ! command -v lsinitcpio >/dev/null 2>&1 ||
    ! command -v loadkeys >/dev/null 2>&1; then
    echo "keyboard-pl-dh: The tools needed to verify the boot image are missing." >&2
    return 2
  fi

  image=$(find_boot_image)
  if [ -z "$image" ]; then
    echo "keyboard-pl-dh: No boot image was found under /boot/EFI/Linux." >&2
    return 2
  fi

  tmp=$(mktemp -d) || return 2
  if ! objcopy -O binary --only-section=.initrd "$image" "$tmp/initrd" 2>/dev/null; then
    rm -rf -- "$tmp"
    echo "keyboard-pl-dh: The boot image could not be read." >&2
    return 2
  fi
  mkdir -p "$tmp/root"
  if ! (cd "$tmp/root" && lsinitcpio -x --cpio "$tmp/initrd" >/dev/null 2>&1); then
    rm -rf -- "$tmp"
    echo "keyboard-pl-dh: The boot image could not be unpacked." >&2
    return 2
  fi

  # The keymap hook compiles the map into keymap.bin. Compare the bytes with
  # what loadkeys produces now. The hook adds -u for a UTF-8 locale, so accept
  # either form.
  embedded=$tmp/root/keymap.bin
  if [ -f "$embedded" ]; then
    actual=$(sha256sum -- "$embedded" | cut -d' ' -f1)
    without_u=$(loadkeys -q -b "$expected" 2>/dev/null | sha256sum | cut -d' ' -f1)
    with_u=$(loadkeys -q -u -b "$expected" 2>/dev/null | sha256sum | cut -d' ' -f1)
    rm -rf -- "$tmp"

    if [ "$actual" = "$without_u" ] || [ "$actual" = "$with_u" ]; then
      echo "keyboard-pl-dh: The boot image contains the $expected keymap."
      return 0
    fi
    echo "keyboard-pl-dh: The boot image does not contain the $expected keymap." >&2
    return 1
  fi

  # sd-vconsole stores the configuration and the map file instead.
  if [ -f "$tmp/root/etc/vconsole.conf" ]; then
    vconsole_keymap=$(sed -n 's/^KEYMAP=//p' "$tmp/root/etc/vconsole.conf" | tail -n 1)
    if [ "$vconsole_keymap" != "$expected" ]; then
      rm -rf -- "$tmp"
      echo "keyboard-pl-dh: The boot image names the $vconsole_keymap keymap, not $expected." >&2
      return 1
    fi
    map_file=$(find "$tmp/root/usr/share/kbd/keymaps" -type f \
      \( -name "$expected.map" -o -name "$expected.map.gz" \
      -o -name "$expected.map.bz2" -o -name "$expected.map.zst" \) \
      2>/dev/null | head -n 1)
    if [ -z "$map_file" ]; then
      rm -rf -- "$tmp"
      echo "keyboard-pl-dh: The boot image names the $expected keymap but does not contain its file." >&2
      return 1
    fi
    rm -rf -- "$tmp"
    echo "keyboard-pl-dh: The boot image contains the $expected keymap."
    return 0
  fi

  rm -rf -- "$tmp"
  echo "keyboard-pl-dh: The boot image has no vconsole configuration or keymap." >&2
  return 2
}

record() {
  local value=$1 tmp
  tmp=$(mktemp -- "$state_dir/.last-build.XXXXXX") || return 0
  printf '%s\n' "$value" >"$tmp" || {
    rm -f -- "$tmp"
    return 0
  }
  chown 0:0 -- "$tmp" 2>/dev/null || true
  chmod 0644 -- "$tmp" 2>/dev/null || true
  mv -fT -- "$tmp" "$state_dir/last-build" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
}

check_image() {
  local expected=$1 rc
  verify_keymap "$expected"
  rc=$?
  case "$rc" in
    0)
      record "keymap $expected verified"
      ;;
    1)
      record "keymap $expected unverified"
      echo "keyboard-pl-dh: WARNING: the boot image does not contain the $expected keymap." >&2
      echo "keyboard-pl-dh: WARNING: check /boot before rebooting." >&2
      ;;
    *)
      record "keymap $expected not checked"
      ;;
  esac
  return "$rc"
}

install() {
  command install -d -m 0755 /usr/local/lib/omasetup/keyboard-pl-dh
  if [ "$(readlink -f -- "$0")" != "$(readlink -f -- "$helper_installed")" ]; then
    command install -m 0755 -- "$0" "$helper_installed"
  fi
  command install -d -m 0755 "$state_dir"

  if [ ! -f "$state_dir/vconsole.before" ]; then
    cp -a -- "$vconsole" "$state_dir/vconsole.before"
    chmod 0644 -- "$state_dir/vconsole.before"
  fi

  write_vconsole

  if ! rebuild; then
    restore_vconsole || true
    if [ "$(sed -n 's/^KEYMAP=//p' "$vconsole" | tail -n 1)" != "$keymap" ]; then
      rm -f -- "$state_dir/active"
    fi
    echo "keyboard-pl-dh: The boot image was not rebuilt, so the previous keymap was put back." >&2
    return 1
  fi

  # A successful build is not enough: limine-mkinitcpio exits 0 even when the
  # image it wrote carries another keymap. A wrong image is fatal here, because
  # booting it would ask for the passphrase in a different layout.
  local rc=0
  check_image "$keymap" || rc=$?
  if [ "$rc" -eq 1 ]; then
    restore_vconsole || true
    if [ "$(sed -n 's/^KEYMAP=//p' "$vconsole" | tail -n 1)" != "$keymap" ]; then
      rm -f -- "$state_dir/active"
    fi
    echo "keyboard-pl-dh: The boot image did not take the new keymap, so the previous keymap was put back." >&2
    if rebuild; then
      check_image "$(sed -n 's/^KEYMAP=//p' "$vconsole" | tail -n 1)" >/dev/null 2>&1 || true
    else
      echo "keyboard-pl-dh: WARNING: the boot image could not be rebuilt after the rollback." >&2
      echo "keyboard-pl-dh: WARNING: check /boot before rebooting." >&2
    fi
    return 1
  fi
  if [ "$rc" -eq 2 ]; then
    echo "keyboard-pl-dh: WARNING: the boot image could not be verified." >&2
    echo "keyboard-pl-dh: WARNING: check /boot before rebooting." >&2
  fi

  printf 'active\n' >"$state_dir/active"
  chmod 0644 -- "$state_dir/active"
  echo "The boot passphrase prompt now uses the $keymap keymap."
  echo "Test it in a TTY before rebooting: sudo loadkeys $keymap, then type your passphrase into nano."
}

uninstall() {
  local current

  if [ ! -f "$state_dir/vconsole.before" ]; then
    echo "keyboard-pl-dh: There is no saved keymap to restore." >&2
    return 1
  fi

  if ! restore_vconsole; then
    echo "keyboard-pl-dh: The saved keymap could not be restored." >&2
    return 1
  fi

  if ! rebuild; then
    echo "keyboard-pl-dh: The keymap was restored but the boot image was not rebuilt." >&2
    return 1
  fi

  current=$(sed -n 's/^KEYMAP=//p' "$vconsole" | tail -n 1)
  local rc=0
  check_image "${current:-us}" || rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f -- "$state_dir/vconsole.before"
  elif [ "$rc" -eq 1 ]; then
    echo "keyboard-pl-dh: The boot image still carries another keymap." >&2
    echo "keyboard-pl-dh: The saved keymap and the active state were kept; run uninstall again." >&2
    return 1
  else
    echo "keyboard-pl-dh: WARNING: the restored boot image could not be verified." >&2
    echo "keyboard-pl-dh: WARNING: check /boot before rebooting." >&2
  fi

  rm -f -- "$state_dir/active"
  echo "The boot passphrase prompt uses the ${current:-us} keymap again."
}

print_status() {
  local keymap_now active last
  keymap_now=$(sed -n 's/^KEYMAP=//p' "$vconsole" 2>/dev/null | tail -n 1)
  active=no
  [ -f "$state_dir/active" ] && active=yes
  last=$(cat "$state_dir/last-build" 2>/dev/null || true)

  echo "keyboard-pl-dh (system)"
  echo
  echo "  Console keymap   ${keymap_now:-unknown}"
  echo "  Boot image       ${last:-no build recorded}"
  if [ "$active" = yes ]; then
    echo "  State            The boot keymap is installed."
  else
    echo "  State            The boot keymap is not installed."
  fi
}

case "${1:-}" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  verify)
    verify_keymap "${2:-$keymap}"
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
