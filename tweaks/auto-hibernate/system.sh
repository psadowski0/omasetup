#!/bin/bash
# Root helper for the auto-hibernate tweak. Called through sudo by
# auto-hibernate.sh; not meant to be run directly.
set -euo pipefail

logind_config=/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
sleep_config=/etc/systemd/sleep.conf.d/60-omatweaks-auto-hibernate.conf
manual_config=/etc/systemd/system/systemd-suspend.service.d/60-omatweaks-auto-hibernate.conf
old_logind_configs=(
  /etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
  /etc/systemd/logind.conf.d/30-lid-battery.conf
)

usage() {
  echo "Usage: sudo $0 {install|uninstall}" >&2
  exit 2
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root: sudo $0 ${1:-}" >&2
    exit 1
  fi
}

prop() {
  busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager "$1" | cut -d'"' -f2
}

install() {
  mkdir -p -- "$(dirname -- "$logind_config")" "$(dirname -- "$sleep_config")"
  rm -f -- "${old_logind_configs[@]}"

  cat > "$logind_config" <<'EOF'
# Omatweaks: auto-hibernate.
#
# On battery: suspend first, then hibernate after HibernateDelaySec.
# On AC: also suspend-then-hibernate, but HibernateOnACPower=no keeps it
# suspended while AC stays connected. If AC is unplugged while suspended,
# the next check hibernates.
[Login]
HandleLidSwitch=suspend-then-hibernate

# This must be explicit: logind ignores this setting when unset and falls
# back to HandleLidSwitch, which would then hibernate on AC too.
HandleLidSwitchExternalPower=suspend-then-hibernate
EOF

  cat > "$sleep_config" <<'EOF'
# Omatweaks: auto-hibernate.
#
# systemd only applies a timeout to suspend-then-hibernate on a laptop with a
# battery when HibernateDelaySec is set explicitly. Without it, the laptop
# stays suspended until the 5% low-battery alarm, which can take days.
[Sleep]
HibernateDelaySec=2h

# Never hibernate while AC stays connected. If the charger is unplugged
# while suspended, the next check hibernates.
HibernateOnACPower=no
EOF

  # Every plain suspend (power menu, suspend key, `systemctl suspend`, logind
  # D-Bus, scripts) goes through systemd-suspend.service. Turn it into the same
  # battery-aware suspend-then-hibernate the lid and idle paths already use.
  mkdir -p -- "$(dirname -- "$manual_config")"
  cat > "$manual_config" <<'EOF'
# Omatweaks: auto-hibernate.
#
# Every plain suspend becomes suspend-then-hibernate. On battery it hibernates
# after HibernateDelaySec; HibernateOnACPower=no keeps it suspended on AC.
# Explicit `systemctl hibernate` and hybrid sleep are not affected.
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-sleep suspend-then-hibernate
EOF

  systemctl daemon-reload

  if ! systemctl show systemd-suspend.service -p ExecStart |
    grep -q 'suspend-then-hibernate'; then
    echo "The override of systemd-suspend.service failed." >&2
    exit 1
  fi

  # logind supports reload, which is safer than restarting it.
  systemctl reload systemd-logind

  if [ "$(prop HandleLidSwitch)" != "suspend-then-hibernate" ] ||
    [ "$(prop HandleLidSwitchExternalPower)" != "suspend-then-hibernate" ]; then
    echo "The reload did not apply the settings, so systemd-logind is restarting." >&2
    systemctl restart systemd-logind
  fi

  echo "Installed $logind_config."
  echo "Installed $sleep_config."
  echo "Installed $manual_config."
  printf 'HandleLidSwitch=%s\n' "$(prop HandleLidSwitch)"
  printf 'HandleLidSwitchExternalPower=%s\n' "$(prop HandleLidSwitchExternalPower)"
  printf 'HibernateDelaySec=%s\n' "$(sed -n 's/^HibernateDelaySec=//p' "$sleep_config" | tail -n 1)"
  printf 'HibernateOnACPower=%s\n' "$(sed -n 's/^HibernateOnACPower=//p' "$sleep_config" | tail -n 1)"
  printf 'Manual suspend=%s\n' "suspend-then-hibernate"
}

uninstall() {
  rm -f -- "$logind_config" "$sleep_config" "$manual_config" "${old_logind_configs[@]}"
  rmdir --ignore-fail-on-non-empty "$(dirname -- "$manual_config")" 2>/dev/null || true

  systemctl daemon-reload

  if systemctl show systemd-suspend.service -p ExecStart |
    grep -q 'suspend-then-hibernate'; then
    echo "systemd-suspend.service is still overridden by another drop-in." >&2
  fi

  systemctl reload systemd-logind

  if [ "$(prop HandleLidSwitch)" = "suspend-then-hibernate" ] ||
    [ "$(prop HandleLidSwitchExternalPower)" = "suspend-then-hibernate" ]; then
    echo "The reload did not apply the changes, so systemd-logind is restarting." >&2
    systemctl restart systemd-logind
  fi

  echo "Removed $logind_config."
  echo "Removed $sleep_config."
  echo "Removed $manual_config."
  printf 'HandleLidSwitch=%s\n' "$(prop HandleLidSwitch)"
  printf 'HandleLidSwitchExternalPower=%s\n' "$(prop HandleLidSwitchExternalPower)"
}

case "${1:-}" in
  install)
    require_root install
    install
    ;;
  uninstall)
    require_root uninstall
    uninstall
    ;;
  *)
    usage
    ;;
esac
