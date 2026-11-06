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
#
# Normally systemd hibernates after HibernateDelaySec. If it wakes without
# hibernating (systemd issue #38193), the journal shows a suspend that ended
# after its hibernate delay with no hibernation entry. Hibernation was already
# due, so hibernate directly after RETRY_GRACE_SECONDS of idle instead of
# waiting the full idle time again.

set -u

IDLE_MINUTES="${IDLE_MINUTES:-10}"

OMARCHY_BIN=/usr/share/omarchy/bin
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.since"
HANDLED_FILE="${XDG_RUNTIME_DIR:-/tmp}/omatweaks-auto-hibernate.handled"

# A gap this large between runs means the machine was suspended/hibernated.
GAP_RESET_SECONDS=90

# After a suspend that should have hibernated but did not, act soon instead of
# waiting the full idle time again.
RETRY_GRACE_SECONDS=60

clear_state() { /usr/bin/rm -f -- "$STATE_FILE"; }

hibernate_delay_seconds() {
  local delay usec

  delay=$(/usr/bin/systemd-analyze cat-config systemd/sleep.conf 2>/dev/null |
    /usr/bin/sed -n 's/^HibernateDelaySec=//p' | /usr/bin/tail -n 1)
  if [ -z "$delay" ]; then
    printf '%s\n' 7200
    return
  fi

  usec=$(/usr/bin/systemd-analyze timespan "$delay" 2>/dev/null |
    /usr/bin/awk 'NR == 2 { print $2 }')
  case "$usec" in
    ''|*[!0-9]*) printf '%s\n' 7200 ;;
    *) printf '%s\n' "$(( usec / 1000000 ))" ;;
  esac
}

# Last suspend, wake, and hibernation timestamps for this boot. Used to detect
# a suspend that should have hibernated but returned without doing so.
last_sleep_times() {
  /usr/bin/journalctl -b -o short-unix --no-pager \
    -g 'PM: suspend entry|PM: suspend exit|PM: hibernation: hibernation entry' 2>/dev/null |
    /usr/bin/awk '{
      t = int($1)
      if ($0 ~ /PM: suspend entry/) s = t
      else if ($0 ~ /PM: suspend exit/) w = t
      else if ($0 ~ /PM: hibernation: hibernation entry/) h = t
    } END { print s + 0, w + 0, h + 0 }'
}

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

# A suspend that ended after its hibernate delay without a hibernation entry
# is the systemd early-wake race (#38193). This covers manual and lid suspends
# too, not just one this timer started. Retry soon instead of waiting the full
# idle time. Remember the suspend we handled so one failed attempt cannot keep
# triggering hibernation later; a new suspend is eligible again.
retry=0
read -r last_suspend last_wake last_hibernate <<<"$(last_sleep_times)"
if [ "$last_suspend" -gt 0 ] && [ "$last_wake" -gt "$last_suspend" ] &&
  [ "$last_suspend" -gt "$last_hibernate" ]; then
  handled=$(/usr/bin/cat -- "$HANDLED_FILE" 2>/dev/null) || handled=0
  case "$handled" in ''|*[!0-9]*) handled=0 ;; esac

  if [ "$last_suspend" -ne "$handled" ]; then
    delay_sec=$(hibernate_delay_seconds)
    timer_due=$(( delay_sec > 60 ? delay_sec - 60 : 0 ))
    if [ $(( last_wake - last_suspend )) -ge "$timer_due" ]; then
      retry=1
    fi
  fi
fi

if [ "$retry" -eq 1 ]; then
  grace=$RETRY_GRACE_SECONDS
else
  # Omarchy reports idle only after min(screensaver, lock) seconds have passed.
  first=$(
    /usr/bin/jq -r '[.screensaver, .lock] | map(select(. > 0)) | min // 0' <<<"$status" 2>/dev/null
  ) || first=0
  case "$first" in ''|*[!0-9]*) first=0 ;; esac

  grace=$(( IDLE_MINUTES * 60 - first ))
  [ "$grace" -ge 0 ] || grace=0
fi

if [ $(( now - since )) -lt "$grace" ]; then
  exit 0
fi

clear_state

if [ "$retry" -eq 1 ]; then
  /usr/bin/printf '%s\n' "$last_suspend" > "$HANDLED_FILE"
  echo "omatweaks-auto-hibernate: previous suspend did not hibernate; hibernating now"
  /usr/bin/systemctl --no-block hibernate
else
  echo "omatweaks-auto-hibernate: idle on battery; suspending"
  /usr/bin/systemctl --no-block suspend-then-hibernate
fi
