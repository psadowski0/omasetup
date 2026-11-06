#!/bin/bash
# Summary: Lid and idle hibernate on battery; AC unchanged.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
idle_check="$script_dir/idle-check.sh"
lid_helper="$script_dir/lid.sh"

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service="$unit_dir/omatweaks-battery-hibernate.service"
timer="$unit_dir/omatweaks-battery-hibernate.timer"
state_file="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-battery-hibernate.since"

lid_config=/etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
legacy_lid_config=/etc/systemd/logind.conf.d/30-lid-battery.conf

legacy_service="$unit_dir/omarchy-idle-hibernate.service"
legacy_timer="$unit_dir/omarchy-idle-hibernate.timer"
legacy_state="${XDG_RUNTIME_DIR:-/tmp}/omarchy-idle-hibernate.since"

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
    [ "$(logind_prop HandleLidSwitchExternalPower)" = "suspend" ]
}

timer_running() {
  [ "$(systemctl --user is-enabled omatweaks-battery-hibernate.timer 2>/dev/null || true)" = "enabled" ] &&
    [ "$(systemctl --user is-active omatweaks-battery-hibernate.timer 2>/dev/null || true)" = "active" ]
}

is_enabled() {
  lid_enabled && timer_running
}

remove_legacy_idle() {
  systemctl --user disable --now omarchy-idle-hibernate.timer 2>/dev/null || true
  systemctl --user reset-failed omarchy-idle-hibernate.service 2>/dev/null || true
  rm -f -- "$legacy_service" "$legacy_timer" "$legacy_state"
  systemctl --user daemon-reload 2>/dev/null || true
}

idle_install() {
  chmod +x -- "$idle_check"
  mkdir -p -- "$unit_dir"

  cat > "$service" <<EOF
[Unit]
Description=Omatweaks: hibernate when idle on battery

[Service]
Type=oneshot
ExecStart="$idle_check"
EOF

  cat > "$timer" <<'EOF'
[Unit]
Description=Omatweaks: check for idle-on-battery hibernate

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now omatweaks-battery-hibernate.timer
}

idle_remove() {
  systemctl --user disable --now omatweaks-battery-hibernate.timer 2>/dev/null || true
  systemctl --user reset-failed omatweaks-battery-hibernate.service 2>/dev/null || true
  rm -f -- "$service" "$timer" "$state_file"
  systemctl --user daemon-reload
}

enable() {
  echo "Applying lid policy (sudo)..."
  sudo "$lid_helper" install
  echo

  echo "Installing idle timer..."
  remove_legacy_idle
  idle_install
  echo

  echo "Battery hibernate enabled."
  echo "  Remove: omatweaks battery-hibernate disable"
}

disable() {
  if [ -e "$lid_config" ] || [ -e "$legacy_lid_config" ]; then
    echo "Removing lid policy (sudo)..."
    sudo "$lid_helper" uninstall
    echo
  else
    echo "Lid policy is not installed; skipping sudo."
  fi

  echo "Removing idle timer..."
  idle_remove
  remove_legacy_idle
  echo

  echo "Battery hibernate disabled."
}

print_status() {
  local lid ext timer_enabled timer_active power

  lid="$(logind_prop HandleLidSwitch)"
  ext="$(logind_prop HandleLidSwitchExternalPower)"
  timer_enabled="$(systemctl --user is-enabled omatweaks-battery-hibernate.timer 2>/dev/null || true)"
  timer_active="$(systemctl --user is-active omatweaks-battery-hibernate.timer 2>/dev/null || true)"

  if omarchy-power-present 2>/dev/null; then
    power="AC"
  else
    power="battery"
  fi

  echo "Battery hibernate"
  echo

  if [ "$lid" = "suspend-then-hibernate" ] && [ "$ext" = "suspend" ]; then
    echo "  Lid on battery   suspend-then-hibernate (enabled)"
  elif [ "$lid" = "suspend" ] && [ -z "$ext" ]; then
    echo "  Lid on battery   suspend (not enabled)"
  else
    echo "  Lid on battery   ${lid:-unknown} (custom)"
  fi

  if [ "$ext" = "suspend" ]; then
    echo "  Lid on AC        suspend (safe, never hibernates)"
  else
    echo "  Lid on AC        ${ext:-unset}"
  fi

  if [ "$timer_enabled" = "enabled" ] && [ "$timer_active" = "active" ]; then
    echo "  Idle timer       enabled, active"
  elif [ "$timer_enabled" = "enabled" ]; then
    echo "  Idle timer       enabled, ${timer_active:-inactive}"
  elif [ -f "$timer" ]; then
    echo "  Idle timer       installed, ${timer_enabled:-disabled}"
  else
    echo "  Idle timer       not installed"
  fi

  echo "  Power now        $power"
  echo
  echo "  Idle after       10 minutes (default)"
  echo "  Hibernate        2 hours after suspend (systemd default)"
  echo

  if is_enabled; then
    echo "  State            enabled"
  else
    echo "  State            not fully enabled"
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
