#!/usr/bin/env bash
#
# Continuous 3-finger swipe -> volume control, bypassing Hyprland's
# discrete gesture system by reading the raw libinput event stream
# (which emits per-frame updates during a swipe, unlike Hyprland's
# gesture = ... dispatcher, which only fires once at the end).
#
# Bash/awk port of swipe-volume.py -- throttles by accumulating N
# events before acting, rather than checking wall-clock time (which
# would mean spawning `date` on every single event -- too slow).
FINGERS=3          # which swipe finger-count to react to
SENSITIVITY=0.2   # tune this: higher = faster volume change per mm
EVENTS_PER_CALL=3  # accumulate this many swipe updates before calling wpctl
                    # lower = smoother but more wpctl calls; higher = choppier but cheaper
libinput debug-events | awk -v fingers="$FINGERS" \
                            -v sens="$SENSITIVITY" \
                            -v batch="$EVENTS_PER_CALL" '
BEGIN {
    pending_dy = 0
    count = 0
}
/GESTURE_SWIPE_UPDATE/ {
    # sample line (libinput right-pads dx/dy for sign alignment, so the
    # gap after "/" is NOT reliable -- it can be zero or one space wide):
    # event8 GESTURE_SWIPE_UPDATE +3.80s   3  0.00/-0.58 ( 0.00/-1.85 unaccelerated)
    # event8 GESTURE_SWIPE_UPDATE +3.81s   3  0.13/ -0.42 ( 0.41/ -1.31 unaccelerated)
    #
    # Relying on fixed field numbers ($4/$5) breaks whenever that padding
    # space appears, because it silently shifts every field after it and
    # split(dxdy, xy, "/") ends up with an empty xy[2] -> dy=0. Instead,
    # grab the "<fingers>  <dx>/<dy>" chunk as one match and parse that.
    if (!match($0, /[0-9]+[ \t]+-?[0-9]+\.[0-9]+\/[ \t]*-?[0-9]+\.[0-9]+/)) next
    chunk = substr($0, RSTART, RLENGTH)

    n = split(chunk, parts, " ")
    fc = parts[1]
    if (fc + 0 != fingers) next

    split(chunk, xy, "/")
    dy = xy[2]
    gsub(/[ \t]/, "", dy)
    dy = dy + 0

    pending_dy += dy
    count++
    if (count < batch) next
    count = 0
    delta = -pending_dy * sens
    pending_dy = 0
    if (delta == 0) next
    abs_delta = (delta < 0) ? -delta : delta
    sign = (delta > 0) ? "+" : "-"
    cmd = sprintf("wpctl set-volume @DEFAULT_AUDIO_SINK@ %.2f%%%s", abs_delta, sign)
    system(cmd " >/dev/null 2>&1 &")
}
'
