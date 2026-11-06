#!/bin/bash
# Run once a minute by omatweaks-auto-hibernate.timer.
#
# Hibernate after a period of continuous idle while on battery. It uses
# Omarchy's own idle state, so it is input-aware, respects inhibitors
# (video, calls, ...) and the "stay awake" toggle. No extra idle daemon or
# package is needed.
#
# Battery only: on AC power it does nothing.
#
# IDLE_MINUTES is total idle time measured from the last input. Omarchy only
# starts reporting "idle" after its first idle timeout (screensaver/lock), so
# that delay is subtracted.

set -u

IDLE_MINUTES="${IDLE_MINUTES:-10}"

OMARCHY_BIN=/usr/share/omarchy/bin
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.since"

# A gap this large between runs means the machine was suspended/hibernated.
GAP_RESET_SECONDS=90

clear_state() { /usr/bin/rm -f -- "$STATE_FILE"; }

# AC power: never act, and forget any pending idle time.
if "$OMARCHY_BIN/omarchy-power-present"; then
  clear_state
  exit 0
fi

status=$("$OMARCHY_BIN/omarchy-shell" idle status 2>/dev/null) || { clear_state; exit 0; }

idle=$(/usr/bin/jq -r '.idle // false' <<<"$status" 2>/dev/null) || { clear_state; exit 0; }
[ "$idle" = true ] || { clear_state; exit 0; }

now=$(/usr/bin/date +%s)

# If the previous run was long ago, we were suspended. Restart the countdown
# so resuming does not immediately suspend the machine again.
if [ -f "$STATE_FILE" ]; then
  last=$(/usr/bin/stat -c %Y -- "$STATE_FILE" 2>/dev/null) || last=0
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  if [ "$last" -gt 0 ] && [ $(( now - last )) -gt "$GAP_RESET_SECONDS" ]; then
    /usr/bin/printf '%s\n' "$now" > "$STATE_FILE"
    exit 0
  fi
fi

if [ ! -f "$STATE_FILE" ]; then
  /usr/bin/printf '%s\n' "$now" > "$STATE_FILE"
  exit 0
fi

since=$(/usr/bin/cat "$STATE_FILE" 2>/dev/null) || since=$now
case "$since" in ''|*[!0-9]*) since=$now ;; esac

# Mark this run so the suspend-gap check works next minute.
/usr/bin/touch -- "$STATE_FILE"

# Omarchy reports idle only after min(screensaver, lock) seconds have passed.
first=$(
  /usr/bin/jq -r '[.screensaver, .lock] | map(select(. > 0)) | min // 0' <<<"$status" 2>/dev/null
) || first=0
case "$first" in ''|*[!0-9]*) first=0 ;; esac

grace=$(( IDLE_MINUTES * 60 - first ))
[ "$grace" -ge 0 ] || grace=0

if [ $(( now - since )) -lt "$grace" ]; then
  exit 0
fi

clear_state
/usr/bin/systemctl --no-block suspend-then-hibernate
