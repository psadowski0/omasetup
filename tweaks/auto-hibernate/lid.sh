#!/bin/bash
# Root helper for the auto-hibernate tweak. Called through sudo by
# auto-hibernate.sh; not meant to be run directly.
set -euo pipefail

config=/etc/systemd/logind.conf.d/30-omatweaks-auto-hibernate.conf
old_configs=(
  /etc/systemd/logind.conf.d/30-omatweaks-battery-hibernate.conf
  /etc/systemd/logind.conf.d/30-lid-battery.conf
)

usage() {
  echo "Usage: sudo $0 {install|uninstall}" >&2
  exit 2
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 ${1:-}" >&2
    exit 1
  fi
}

prop() {
  busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager "$1" | cut -d'"' -f2
}

install() {
  mkdir -p -- "$(dirname -- "$config")"
  rm -f -- "${old_configs[@]}"

  cat > "$config" <<'EOF'
# Omatweaks: auto-hibernate.
#
# On battery: suspend first, then hibernate after HibernateDelaySec
# (2h by default) or when the battery drops below 5%, whichever comes first.
[Login]
HandleLidSwitch=suspend-then-hibernate

# Keep AC behavior unchanged: plain suspend, never hibernate.
# This must be explicit: logind ignores this setting when unset and falls
# back to HandleLidSwitch, which would then hibernate on AC too.
HandleLidSwitchExternalPower=suspend
EOF

  # logind supports reload, which is safer than restarting it.
  systemctl reload systemd-logind

  if [ "$(prop HandleLidSwitch)" != "suspend-then-hibernate" ]; then
    echo "Reload did not apply the setting; restarting systemd-logind." >&2
    systemctl restart systemd-logind
  fi

  echo "Installed $config"
  printf 'HandleLidSwitch=%s\n' "$(prop HandleLidSwitch)"
  printf 'HandleLidSwitchExternalPower=%s\n' "$(prop HandleLidSwitchExternalPower)"
}

uninstall() {
  rm -f -- "$config" "${old_configs[@]}"

  systemctl reload systemd-logind

  if [ "$(prop HandleLidSwitch)" = "suspend-then-hibernate" ]; then
    echo "Reload did not apply the change; restarting systemd-logind." >&2
    systemctl restart systemd-logind
  fi

  echo "Removed $config"
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
