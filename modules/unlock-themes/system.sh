#!/bin/bash
# Root helper for the unlock-themes module. Called through sudo by
# unlock-themes and by the post-upgrade Pacman hook; not meant to be run
# directly.
#
# The centering lives in the boot image, not in the files on disk. This helper
# only adds the module's own files, remembers the selected screen, and restores
# the selected screen after an Omarchy update.
set -euo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

helper_installed=/usr/local/lib/omasetup/unlock-themes/system.sh
state_dir=/var/lib/omasetup/unlock-themes
build_hook=/etc/initcpio/install/omasetup-unlock-themes
dropin=/etc/mkinitcpio.conf.d/99-omasetup-unlock-themes.conf
restore_hook=/etc/pacman.d/hooks/85-omasetup-unlock-themes-restore.hook
legacy_record_hook=/etc/pacman.d/hooks/80-omasetup-unlock-themes-record.hook
theme_dir=/usr/share/plymouth/themes/omarchy
layout_source=/usr/share/omarchy/default/plymouth/omarchy.script
layout_installed=$theme_dir/omarchy.script

patch_line='  if (logo.image.GetHeight() == 1) entry.y = global.layout_height / 2 - entry.image.GetHeight() / 2;'

usage() {
  cat >&2 <<'EOF'
Usage: sudo system.sh <command>

Commands:
  install <themes-dir>  Add the boot-image hook, Pacman hook, and saved data.
  uninstall             Remove every added file and any old layout change.
  restore               Restore the selected screen after an Omarchy update.
  rebuild               Rebuild the boot image.

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

root_file() {
  [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = "0" ]
}

# Remove the v0.2.2 layout line from a file that the module used to patch.
# The files stay otherwise byte-identical and remain owned by the package.
unpatch_file() {
  local file=$1 tmp count

  [ -e "$file" ] || return 0
  if ! root_file "$file"; then
    echo "unlock-themes: $file is not a root-owned regular file, so the old layout change was left in place." >&2
    return 0
  fi

  count=$(grep -cF -- "$patch_line" "$file" 2>/dev/null || true)
  if [ "$count" -eq 0 ]; then
    return 0
  fi

  tmp=$(mktemp -- "${file}.XXXXXX")
  if ! awk -v line="$patch_line" '$0 != line' "$file" >"$tmp"; then
    rm -f -- "$tmp"
    echo "unlock-themes: The old layout change could not be removed from $file." >&2
    return 0
  fi
  chown 0:0 -- "$tmp"
  chmod 0644 -- "$tmp"
  mv -fT -- "$tmp" "$file"

  echo "Removed the old layout change from $file."
}

unpatch_legacy() {
  unpatch_file "$layout_source"
  unpatch_file "$layout_installed"
}

write_restore_hook() {
  install -d -m 0755 /etc/pacman.d/hooks

  cat >"$restore_hook" <<'EOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = omarchy-settings

[Action]
Description = Restoring the selected logo-free unlock screen.
When = PostTransaction
Exec = /usr/local/lib/omasetup/unlock-themes/system.sh restore
EOF

  chmod 0644 -- "$restore_hook"
}

write_build_hook() {
  local source=$1

  if [ ! -f "$source" ]; then
    echo "unlock-themes: The bundled build hook is missing from $source." >&2
    return 1
  fi
  if ! bash -n -- "$source" 2>/dev/null; then
    echo "unlock-themes: The bundled build hook is not valid, so the boot image was not changed." >&2
    return 1
  fi

  install -d -m 0755 /etc/initcpio/install
  install -o 0 -g 0 -m 0644 -- "$source" "$build_hook"
}

write_dropin() {
  install -d -m 0755 /etc/mkinitcpio.conf.d

  cat >"$dropin" <<'EOF'
# Added by the unlock-themes module. Removed by 'unlock-themes disable'.
#
# The hook writes a centered copy of the Plymouth layout into the boot image
# only, so the packaged files on disk stay exactly as Omarchy ships them. It
# does nothing unless one of the module's screens is selected.
if [[ -f /etc/initcpio/install/omasetup-unlock-themes ]]; then
  case " ${HOOKS[*]:-} " in
    *" omasetup-unlock-themes "*) ;;
    *)
      if [[ ${HOOKS@a} == *a* ]]; then
        HOOKS+=(omasetup-unlock-themes)
      else
        HOOKS="${HOOKS:-} omasetup-unlock-themes"
      fi
      ;;
  esac
fi
EOF

  chmod 0644 -- "$dropin"
}

record_active() {
  local logo=$theme_dir/logo.png name tmp

  if [ -d "$state_dir" ] && [ ! -L "$state_dir" ]; then
    rm -f -- "$state_dir/active" 2>/dev/null || true
  fi

  if [ ! -d "$state_dir" ] || [ ! -f "$logo" ] || [ -L "$logo" ]; then
    return 0
  fi

  for name in white-no-logo vantablack-no-logo; do
    if [ -f "$state_dir/$name/logo.png" ] && cmp -s -- "$logo" "$state_dir/$name/logo.png"; then
      tmp=$(mktemp -- "$state_dir/.active.XXXXXX") || return 0
      if printf '%s\n' "$name" >"$tmp"; then
        chown 0:0 -- "$tmp" 2>/dev/null || true
        chmod 0644 -- "$tmp" 2>/dev/null || true
        mv -fT -- "$tmp" "$state_dir/active" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
      else
        rm -f -- "$tmp" 2>/dev/null || true
      fi
      return 0
    fi
  done

  return 0
}

# Put the selected screen's logo and colors back into the installed theme.
# This is the same result as Omarchy's own apply command; it never adds the
# centering line, which only exists inside the boot image.
apply_theme() {
  local name=$1 colors bg fg r g b asset tmp

  if [ ! -f "$state_dir/$name/logo.png" ] || [ ! -f "$state_dir/$name/colors" ]; then
    echo "unlock-themes: The saved $(theme_label "$name") screen data is incomplete." >&2
    return 1
  fi

  mapfile -t colors <"$state_dir/$name/colors"
  bg=${colors[0]:-}
  fg=${colors[1]:-}
  bg=${bg#\#}
  fg=${fg#\#}

  if ! [[ $bg =~ ^[0-9a-fA-F]{6}$ && $fg =~ ^[0-9a-fA-F]{6}$ ]]; then
    echo "unlock-themes: The saved $(theme_label "$name") colors are not valid." >&2
    return 1
  fi

  if [ ! -d "$theme_dir" ] || [ -L "$theme_dir" ]; then
    echo "unlock-themes: The installed Plymouth theme is missing." >&2
    return 1
  fi
  if ! root_file "$layout_installed"; then
    echo "unlock-themes: The installed Plymouth layout is missing." >&2
    return 1
  fi

  # Start from the layout Omarchy ships, so an old on-disk change can never
  # survive an update.
  if root_file "$layout_source"; then
    tmp=$(mktemp -- "$theme_dir/.omarchy.script.XXXXXX")
    if install -o 0 -g 0 -m 0644 -- "$layout_source" "$tmp"; then
      mv -fT -- "$tmp" "$layout_installed"
    else
      rm -f -- "$tmp"
      echo "unlock-themes: The stock Plymouth layout could not be restored." >&2
      return 1
    fi
  fi

  r=$(awk -v n=$((16#${bg:0:2})) 'BEGIN{printf "%.3f", n/255}')
  g=$(awk -v n=$((16#${bg:2:2})) 'BEGIN{printf "%.3f", n/255}')
  b=$(awk -v n=$((16#${bg:4:2})) 'BEGIN{printf "%.3f", n/255}')
  if ! sed -i \
    -e "s/^Window.SetBackgroundTopColor.*/Window.SetBackgroundTopColor($r, $g, $b);/" \
    -e "s/^Window.SetBackgroundBottomColor.*/Window.SetBackgroundBottomColor($r, $g, $b);/" \
    "$layout_installed"; then
    echo "unlock-themes: The $(theme_label "$name") background could not be restored." >&2
    return 1
  fi

  if ! install -o 0 -g 0 -m 0644 -- "$state_dir/$name/logo.png" "$theme_dir/logo.png"; then
    echo "unlock-themes: The $(theme_label "$name") logo could not be restored." >&2
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

install_all() {
  local themes_src=${1:-} module_dir name dir bg fg

  if [ -z "$themes_src" ] || [ ! -d "$themes_src" ]; then
    echo "unlock-themes: The theme source directory is missing." >&2
    return 1
  fi
  module_dir=$(cd -P -- "$(dirname -- "$themes_src")" && pwd)

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

  # v0.2.2 recorded the screen before an upgrade and patched the layout on
  # disk. The boot-image hook records and centers on its own now.
  rm -f -- "$legacy_record_hook"
  unpatch_legacy

  if ! write_build_hook "$module_dir/build-hook"; then
    return 1
  fi
  write_restore_hook
  # The drop-in goes last, so a build can never see it without its hook.
  write_dropin

  if [ ! -f "$state_dir/active" ]; then
    record_active
  fi
  if [ -f "$state_dir/active" ]; then
    apply_theme "$(head -n 1 -- "$state_dir/active")" || true
  fi

  echo "Installed $helper_installed."
  echo "Installed the boot-image hook and the update hook."
  echo "The password field is centered in the boot image, not on disk."
}

restore_active() {
  local name

  if [ ! -d "$state_dir" ] || [ ! -f "$state_dir/active" ]; then
    return 0
  fi

  name=$(head -n 1 -- "$state_dir/active")
  if [[ $name != white-no-logo && $name != vantablack-no-logo ]]; then
    echo "unlock-themes: The saved screen name is not recognized, so the screen was not restored." >&2
    return 0
  fi

  if ! root_file "$layout_source"; then
    echo "unlock-themes: Omarchy's Plymouth layout is missing, so the screen was not restored." >&2
    return 0
  fi

  unpatch_legacy
  if ! apply_theme "$name"; then
    echo "unlock-themes: The saved $(theme_label "$name") screen could not be restored." >&2
  fi

  return 0
}

uninstall_all() {
  # Remove the drop-in first, so a build can never look for a missing hook.
  rm -f -- "$dropin"
  rm -f -- "$build_hook"
  rm -f -- "$restore_hook" "$legacy_record_hook"

  unpatch_legacy

  rm -rf -- "$state_dir"
  rm -f -- "$helper_installed"
  rmdir --ignore-fail-on-non-empty /var/lib/omasetup 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty /usr/local/lib/omasetup/unlock-themes 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty /usr/local/lib/omasetup 2>/dev/null || true

  echo "Removed the boot-image hook, the update hook, the saved screen data, and any old layout change."
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

require_root "${1:-}"

case "${1:-}" in
  install)
    install_all "${2:-}"
    ;;
  uninstall)
    uninstall_all
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
