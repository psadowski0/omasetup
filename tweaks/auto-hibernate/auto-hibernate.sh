#!/bin/bash
# Summary: Hibernate automatically on battery; never on AC.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
idle_check="$script_dir/idle-check.sh"
system_helper="$script_dir/system.sh"

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service="$unit_dir/omatweaks-auto-hibernate.service"
timer="$unit_dir/omatweaks-auto-hibernate.timer"
state_file="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.since"
handled_file="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.handled"
old_runtime_files=(
  "${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.attempt"
)

lid_config=/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
sleep_config=/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf
manual_config=/etc/systemd/system/systemd-suspend.service.d/60-omatweaks-auto-hibernate.conf
old_lid_configs=(
  /etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
  /etc/systemd/logind.conf.d/30-lid-battery.conf
)

old_units=(
  "$unit_dir/omatweaks-battery-hibernate.service"
  "$unit_dir/omatweaks-battery-hibernate.timer"
  "$unit_dir/omarchy-idle-hibernate.service"
  "$unit_dir/omarchy-idle-hibernate.timer"
)
old_states=(
  "${XDG_RUNTIME_DIR:-/tmp}/omatweaks-battery-hibernate.since"
  "${XDG_RUNTIME_DIR:-/tmp}/omarchy-idle-hibernate.since"
)
old_wants=(
  "$unit_dir/timers.target.wants/omatweaks-battery-hibernate.timer"
  "$unit_dir/timers.target.wants/omarchy-idle-hibernate.timer"
)

usage() {
  echo "Usage: $0 {enable|disable|status [--quiet]}" >&2
  exit 2
}

if [ "$(id -u)" -eq 0 ]; then
  echo "Run as your normal user, not root." >&2
  exit 1
fi

logind_prop() {
  busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager "$1" 2>/dev/null | cut -d'"' -f2 || true
}

lid_enabled() {
  [ "$(logind_prop HandleLidSwitch)" = "suspend-then-hibernate" ] &&
    [ "$(logind_prop HandleLidSwitchExternalPower)" = "suspend-then-hibernate" ]
}

manual_enabled() {
  [ -e "$manual_config" ] &&
    grep -q '^ExecStart=/usr/lib/systemd/systemd-sleep suspend-then-hibernate' "$manual_config"
}

configs_installed() {
  local config
  [ -e "$sleep_config" ] && return 0
  [ -e "$manual_config" ] && return 0
  for config in "$lid_config" "${old_lid_configs[@]}"; do
    [ -e "$config" ] && return 0
  done
  return 1
}

timer_running() {
  [ "$(systemctl --user is-enabled omatweaks-auto-hibernate.timer 2>/dev/null || true)" = "enabled" ] &&
    [ "$(systemctl --user is-active omatweaks-auto-hibernate.timer 2>/dev/null || true)" = "active" ]
}

is_enabled() {
  lid_enabled && timer_running && [ -e "$sleep_config" ] &&
    grep -q '^HibernateOnACPower=no' "$sleep_config" &&
    manual_enabled
}

cleanup_old() {
  local unit
  for unit in omatweaks-battery-hibernate.timer omarchy-idle-hibernate.timer; do
    systemctl --user disable --now "$unit" 2>/dev/null || true
  done
  for unit in omatweaks-battery-hibernate.service omarchy-idle-hibernate.service; do
    systemctl --user reset-failed "$unit" 2>/dev/null || true
  done

  rm -f -- "${old_units[@]}" "${old_states[@]}" "${old_wants[@]}" "${old_runtime_files[@]}"
  systemctl --user daemon-reload 2>/dev/null || true
}

idle_install() {
  chmod +x -- "$idle_check"
  mkdir -p -- "$unit_dir"

  cat > "$service" <<EOF
[Unit]
Description=Omatweaks: hibernate automatically on battery

[Service]
Type=oneshot
ExecStart="$idle_check"
EOF

  cat > "$timer" <<'EOF'
[Unit]
Description=Omatweaks: check for auto-hibernate on battery

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now omatweaks-auto-hibernate.timer
}

idle_remove() {
  systemctl --user disable --now omatweaks-auto-hibernate.timer 2>/dev/null || true
  systemctl --user reset-failed omatweaks-auto-hibernate.service 2>/dev/null || true
  rm -f -- "$service" "$timer" "$state_file" "$handled_file" "${old_runtime_files[@]}"
  systemctl --user daemon-reload
}

enable() {
  if [ -x /usr/share/omarchy/bin/omarchy-hibernation-available ] &&
    ! /usr/share/omarchy/bin/omarchy-hibernation-available; then
    echo "Hibernation is not available on this machine." >&2
    echo "Enable hibernation first (omarchy-hibernation-setup), then retry." >&2
    exit 1
  fi

  echo "Applying lid and sleep policy (sudo)..."
  sudo "$system_helper" install
  echo

  echo "Installing idle timer..."
  cleanup_old
  idle_install
  echo

  echo "auto-hibernate is on."
  echo "  Turn off: omatweaks auto-hibernate disable"
}

disable() {
  if configs_installed; then
    echo "Removing lid and sleep policy (sudo)..."
    sudo "$system_helper" uninstall
    echo
  else
    echo "Lid and sleep policy are not installed; skipping sudo."
  fi

  echo "Removing idle timer..."
  idle_remove
  cleanup_old
  echo

  echo "auto-hibernate is off."
}

print_status() {
  local lid ext timer_enabled timer_active power delay

  lid="$(logind_prop HandleLidSwitch)"
  ext="$(logind_prop HandleLidSwitchExternalPower)"
  timer_enabled="$(systemctl --user is-enabled omatweaks-auto-hibernate.timer 2>/dev/null || true)"
  timer_active="$(systemctl --user is-active omatweaks-auto-hibernate.timer 2>/dev/null || true)"

  if omarchy-power-present 2>/dev/null; then
    power="AC"
  else
    power="battery"
  fi

  echo "auto-hibernate"
  echo

  if [ "$lid" = "suspend-then-hibernate" ] && [ "$ext" = "suspend-then-hibernate" ]; then
    echo "  Lid on battery   suspend, then hibernate"
  elif [ "$lid" = "suspend" ] && [ -z "$ext" ]; then
    echo "  Lid on battery   suspend only (tweak off)"
  else
    echo "  Lid on battery   custom (${lid:-unknown})"
  fi

  if [ "$ext" = "suspend-then-hibernate" ]; then
    echo "  Lid on AC        suspend only (never hibernates)"
  elif [ "$ext" = "suspend" ]; then
    echo "  Lid on AC        suspend only (safe)"
  else
    echo "  Lid on AC        ${ext:-unset}"
  fi

  if manual_enabled; then
    echo "  Manual suspend   suspend, then hibernate"
  else
    echo "  Manual suspend   suspend only (tweak off)"
  fi

  if [ "$timer_enabled" = "enabled" ] && [ "$timer_active" = "active" ]; then
    echo "  Idle timer       on"
  elif [ "$timer_enabled" = "enabled" ]; then
    echo "  Idle timer       on, not running"
  elif [ -f "$timer" ]; then
    echo "  Idle timer       installed, off"
  else
    echo "  Idle timer       not installed"
  fi

  echo "  Power now        $power"
  echo
  echo "  Idle after       10 minutes"
  if [ -e "$sleep_config" ]; then
    delay="$(sed -n 's/^HibernateDelaySec=//p' "$sleep_config" | tail -n 1)"
    echo "  Hibernate        ${delay:-?} after suspend"
  else
    echo "  Hibernate        not configured"
  fi
  echo

  if is_enabled; then
    echo "  State            on"
  else
    echo "  State            incomplete"
  fi
}

case "${1:-}" in
  enable)
    enable
    ;;
  disable)
    disable
    ;;
  status)
    if [ "${2:-}" = "--quiet" ]; then
      is_enabled
    else
      print_status
    fi
    ;;
  *)
    usage
    ;;
esac
