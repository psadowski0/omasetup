#!/bin/bash
# Root helper for the unlock-themes module. Called through sudo by
# unlock-themes and by the Pacman hooks; not meant to be run directly.
set -euo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

helper_installed=/usr/local/lib/omasetup/unlock-themes/system.sh
state_dir=/var/lib/omasetup/unlock-themes
record_hook=/etc/pacman.d/hooks/80-omasetup-unlock-themes-record.hook
restore_hook=/etc/pacman.d/hooks/85-omasetup-unlock-themes-restore.hook
layout_source=/usr/share/omarchy/default/plymouth/omarchy.script
layout_installed=/usr/share/plymouth/themes/omarchy/omarchy.script
theme_dir=/usr/share/plymouth/themes/omarchy

patch_line='  if (logo.image.GetHeight() == 1) entry.y = global.layout_height / 2 - entry.image.GetHeight() / 2;'
anchor_line='  entry.y = logo.sprite.GetY() + logo.image.GetHeight() + 40;'

usage() {
  cat >&2 <<'EOF'
Usage: sudo system.sh <command>

Commands:
  install <themes-dir>  Add the hooks, saved data, and layout change.
  uninstall             Remove the hooks, saved data, and layout change.
  record                Record the active screen before an Omarchy update.
  restore               Restore the active screen after an Omarchy update.
  rebuild               Rebuild the initramfs.

This helper is called by the unlock-themes module and by Pacman.
EOF
  exit 2
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run this helper as root: sudo $0 ${1:-}" >&2
    exit 1
  fi
}

theme_label() {
  case "$1" in
    white-no-logo) echo "White No Logo" ;;
    vantablack-no-logo) echo "Vantablack No Logo" ;;
    *) echo "$1" ;;
  esac
}

theme_color() {
  local file=$1 key=$2

  awk -F= -v key="$key" '
    {
      field = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field == key) {
        value = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/"/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

valid_layout_file() {
  local file=$1

  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  [ "$(stat -c %u -- "$file")" = "0" ] || return 1
}

validate_layout_targets() {
  local file

  for file in "$layout_source" "$layout_installed"; do
    if ! valid_layout_file "$file"; then
      echo "unlock-themes: $file is not a root-owned regular file." >&2
      return 1
    fi
    if ! grep -qF -- "$anchor_line" "$file"; then
      echo "unlock-themes: $file does not contain the expected layout line, so the field cannot be centered." >&2
      return 1
    fi
  done
}

patch_file() {
  local file=$1 tmp count

  valid_layout_file "$file" || {
    echo "unlock-themes: $file is not a root-owned regular file, so it was not changed." >&2
    return 1
  }

  if grep -qF -- "$patch_line" "$file"; then
    return 0
  fi

  if ! grep -qF -- "$anchor_line" "$file"; then
    echo "unlock-themes: $file does not contain the expected layout line, so the field cannot be centered." >&2
    return 1
  fi

  tmp=$(mktemp -- "${file}.XXXXXX")
  awk -v anchor="$anchor_line" -v line="$patch_line" '
    { print }
    $0 == anchor { print line }
  ' "$file" >"$tmp"
  chown 0:0 -- "$tmp"
  chmod 0644 -- "$tmp"

  count=$(grep -cF -- "$patch_line" "$tmp" || true)
  if [ "$count" -ne 1 ] || ! grep -qF -- "$anchor_line" "$tmp"; then
    rm -f -- "$tmp"
    echo "unlock-themes: The layout patch could not be applied to $file." >&2
    return 1
  fi

  mv -fT -- "$tmp" "$file"
}

unpatch_file() {
  local file=$1 tmp count

  [ -f "$file" ] && [ ! -L "$file" ] || return 0

  if [ "$(stat -c %u -- "$file")" != "0" ]; then
    echo "unlock-themes: $file is not root-owned, so it was not changed." >&2
    return 1
  fi

  count=$(grep -cF -- "$patch_line" "$file" || true)
  if [ "$count" -eq 0 ]; then
    return 0
  fi

  tmp=$(mktemp -- "${file}.XXXXXX")
  awk -v line="$patch_line" '$0 != line' "$file" >"$tmp"
  chown 0:0 -- "$tmp"
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$file"

  if grep -qF -- "$patch_line" "$file"; then
    echo "unlock-themes: The layout change could not be removed from $file." >&2
    return 1
  fi
}

patch_both() {
  local status=0

  validate_layout_targets || return 1
  patch_file "$layout_source" || status=1
  patch_file "$layout_installed" || status=1
  return "$status"
}

unpatch_both() {
  local status=0

  unpatch_file "$layout_source" || status=1
  unpatch_file "$layout_installed" || status=1
  return "$status"
}

write_hooks() {
  install -d -m 0755 /etc/pacman.d/hooks

  cat >"$record_hook" <<'EOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = omarchy-settings

[Action]
Description = Recording the active logo-free unlock screen.
When = PreTransaction
Exec = /usr/local/lib/omasetup/unlock-themes/system.sh record
EOF

  cat >"$restore_hook" <<'EOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = omarchy-settings

[Action]
Description = Restoring the centered logo-free unlock screen.
When = PostTransaction
Exec = /usr/local/lib/omasetup/unlock-themes/system.sh restore
EOF

  chmod 0644 -- "$record_hook" "$restore_hook"
}

install_all() {
  local themes_src=${1:-} name dir bg fg

  if [ -z "$themes_src" ] || [ ! -d "$themes_src" ]; then
    echo "unlock-themes: The theme source directory is missing." >&2
    return 1
  fi

  validate_layout_targets || return 1
  patch_both || return 1

  install -d -m 0755 /usr/local/lib/omasetup/unlock-themes
  if ! cmp -s -- "$0" "$helper_installed" 2>/dev/null; then
    install -m 0755 -- "$0" "$helper_installed"
  fi

  install -d -m 0755 "$state_dir"
  for name in white-no-logo vantablack-no-logo; do
    dir=$themes_src/$name
    if [ ! -f "$dir/unlock.png" ] || [ ! -f "$dir/colors.toml" ]; then
      echo "unlock-themes: The bundled $name files are incomplete." >&2
      return 1
    fi

    bg=$(theme_color "$dir/colors.toml" background)
    fg=$(theme_color "$dir/colors.toml" foreground)
    if ! [[ $bg =~ ^#[0-9a-fA-F]{6}$ && $fg =~ ^#[0-9a-fA-F]{6}$ ]]; then
      echo "unlock-themes: The $name colors could not be read." >&2
      return 1
    fi

    install -d -m 0755 "$state_dir/$name"
    install -m 0644 -- "$dir/unlock.png" "$state_dir/$name/logo.png"
    printf '%s\n%s\n' "$bg" "$fg" >"$state_dir/$name/colors"
    chown 0:0 -- "$state_dir/$name/logo.png" "$state_dir/$name/colors"
    chmod 0644 -- "$state_dir/$name/logo.png" "$state_dir/$name/colors"
  done

  rm -f -- "$state_dir/active"
  write_hooks

  echo "Installed $helper_installed."
  echo "Installed the two Pacman hooks."
  echo "The field is centered when a 1-pixel logo is used."
}

uninstall_all() {
  local status=0

  rm -f -- "$record_hook" "$restore_hook"
  unpatch_both || status=1
  rm -rf -- "$state_dir"
  rm -f -- "$helper_installed"
  rmdir --ignore-fail-on-non-empty /var/lib/omasetup 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty /usr/local/lib/omasetup/unlock-themes 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty /usr/local/lib/omasetup 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    echo "Removed the Pacman hooks, the saved screen data, and the layout change."
  else
    echo "unlock-themes: Some layout changes could not be removed." >&2
  fi
  return "$status"
}

record_active() {
  local logo=$theme_dir/logo.png name

  rm -f -- "$state_dir/active"
  if [ ! -d "$state_dir" ] || [ ! -f "$logo" ]; then
    return 0
  fi

  for name in white-no-logo vantablack-no-logo; do
    if [ -f "$state_dir/$name/logo.png" ] && cmp -s -- "$logo" "$state_dir/$name/logo.png"; then
      if printf '%s\n' "$name" >"$state_dir/active"; then
        chown 0:0 -- "$state_dir/active" 2>/dev/null || true
        chmod 0644 -- "$state_dir/active" 2>/dev/null || true
      fi
      return 0
    fi
  done

  return 0
}

apply_theme() {
  local name=$1 colors bg fg r g b asset

  mapfile -t colors <"$state_dir/$name/colors"
  bg=${colors[0]:-}
  fg=${colors[1]:-}
  bg=${bg#\#}
  fg=${fg#\#}

  if ! [[ $bg =~ ^[0-9a-fA-F]{6}$ && $fg =~ ^[0-9a-fA-F]{6}$ ]]; then
    echo "unlock-themes: The saved $(theme_label "$name") colors are not valid." >&2
    return 1
  fi

  if [ ! -d "$theme_dir" ] || [ ! -f "$theme_dir/omarchy.script" ]; then
    echo "unlock-themes: The installed Plymouth theme is missing." >&2
    return 1
  fi

  if ! install -o 0 -g 0 -m 0644 -- "$state_dir/$name/logo.png" "$theme_dir/logo.png"; then
    echo "unlock-themes: The $(theme_label "$name") logo could not be restored." >&2
    return 1
  fi

  r=$(awk -v n=$((16#${bg:0:2})) 'BEGIN{printf "%.3f", n/255}')
  g=$(awk -v n=$((16#${bg:2:2})) 'BEGIN{printf "%.3f", n/255}')
  b=$(awk -v n=$((16#${bg:4:2})) 'BEGIN{printf "%.3f", n/255}')
  if ! sed -i \
    -e "s/^Window.SetBackgroundTopColor.*/Window.SetBackgroundTopColor($r, $g, $b);/" \
    -e "s/^Window.SetBackgroundBottomColor.*/Window.SetBackgroundBottomColor($r, $g, $b);/" \
    "$theme_dir/omarchy.script"; then
    echo "unlock-themes: The $(theme_label "$name") background could not be restored." >&2
    return 1
  fi

  for asset in bullet.png entry.png lock.png progress_bar.png; do
    [ -f "$theme_dir/$asset" ] || continue
    if ! magick "$theme_dir/$asset" -channel RGB +level-colors "#$fg","#$fg" "$theme_dir/$asset"; then
      echo "unlock-themes: $asset could not be recolored." >&2
      return 1
    fi
    chown 0:0 -- "$theme_dir/$asset" || return 1
    chmod 0644 -- "$theme_dir/$asset" || return 1
  done

  echo "Restored the $(theme_label "$name") screen."
}

rebuild() {
  if command -v limine-mkinitcpio >/dev/null 2>&1; then
    limine-mkinitcpio
  elif command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
  else
    echo "unlock-themes: No initramfs rebuild command was found, so the boot screen was not updated." >&2
    return 1
  fi
}

restore_active() {
  local name

  if ! validate_layout_targets; then
    echo "unlock-themes: The layout was not patched because Omarchy's script changed." >&2
    return 0
  fi
  patch_both || return 0

  if [ ! -f "$state_dir/active" ]; then
    return 0
  fi

  name=$(head -n 1 -- "$state_dir/active")
  if [[ $name != white-no-logo && $name != vantablack-no-logo ]]; then
    echo "unlock-themes: The saved screen name is not recognized." >&2
    rm -f -- "$state_dir/active"
    return 0
  fi

  if [ ! -f "$state_dir/$name/logo.png" ] || [ ! -f "$state_dir/$name/colors" ]; then
    echo "unlock-themes: The saved $(theme_label "$name") screen data is incomplete, so the screen was not restored." >&2
    rm -f -- "$state_dir/active"
    return 0
  fi

  if apply_theme "$name"; then
    if ! rebuild; then
      echo "unlock-themes: The screen was restored, but the boot image could not be rebuilt." >&2
    fi
  else
    echo "unlock-themes: The saved $(theme_label "$name") screen could not be restored." >&2
  fi

  rm -f -- "$state_dir/active"
  return 0
}

require_root "${1:-}"

case "${1:-}" in
  install)
    install_all "${2:-}"
    ;;
  uninstall)
    uninstall_all
    ;;
  record)
    record_active
    ;;
  restore)
    restore_active
    ;;
  rebuild)
    rebuild
    ;;
  *)
    usage
    ;;
esac
