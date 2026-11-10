#!/usr/bin/env python3
"""Sunrise and sunset for auto-night.

This is a direct port of the world clock's own solar math, so the module and
the Omarchy world clock always agree. The source is
/usr/share/omarchy/shell/plugins/panels/elsewhen/Sun.js and GlobeModel.js.

The module never looks at the network or at your IP address. A location comes
from the world clock's own city table, from the system timezone, or from a
location you pin. Run with --json to see the raw values, or with no arguments
to print shell assignments that auto-night can source.
"""

import argparse
import json
import math
import os
import shlex
import sys
from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

DEG = math.pi / 180.0

# Earth's obliquity, as in GlobeModel.js.
AXIAL_TILT = 23.44

# Refraction plus the sun's radius, the figure published sunrise tables use.
HORIZON = -0.833

OMARCHY_PATH = os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")
CITIES_FILE = os.path.join(
    OMARCHY_PATH, "shell", "plugins", "panels", "elsewhen", "cities.json"
)
SHELL_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "omarchy",
    "shell.json",
)
PIN_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "omasetup",
    "auto-night.json",
)


# ---- the world clock's math, ported line for line ----

def subsolar_point(ms):
    """The point with the sun directly overhead, as (lat, lon) in degrees."""
    jd = ms / 86400000.0 + 2440587.5
    n = jd - 2451545.0
    mean_longitude = (280.460 + 0.9856474 * n) % 360.0
    mean_anomaly = ((357.528 + 0.9856003 * n) % 360.0) * DEG
    ecliptic = (
        mean_longitude
        + 1.915 * math.sin(mean_anomaly)
        + 0.020 * math.sin(2 * mean_anomaly)
    ) * DEG
    obliquity = (AXIAL_TILT - 0.0000004 * n) * DEG

    declination = math.asin(math.sin(obliquity) * math.sin(ecliptic)) / DEG

    # Equation of time, in degrees, then the subsolar meridian.
    right_ascension = (
        math.atan2(math.cos(obliquity) * math.sin(ecliptic), math.cos(ecliptic)) / DEG
    )
    eot = (mean_longitude - right_ascension + 540.0) % 360.0 - 180.0
    # The world clock reads whole seconds from a JavaScript Date, so drop the
    # fraction here too. Matching it exactly keeps the two in step.
    moment = datetime.fromtimestamp(int(ms // 1000), tz=timezone.utc)
    utc_hours = moment.hour + moment.minute / 60.0 + moment.second / 3600.0
    longitude = -15.0 * (utc_hours - 12.0) - eot
    longitude = ((longitude + 540.0) % 360.0) - 180.0

    return declination, longitude


def wrap180(degrees):
    return ((degrees + 540.0) % 360.0) - 180.0


def solar_noon_ms(longitude, near_ms):
    """Local solar noon. Three corrections take the residual below a second."""
    moment = near_ms
    for _ in range(3):
        _, subsolar_longitude = subsolar_point(moment)
        moment += wrap180(subsolar_longitude - longitude) / 15.0 * 3600000.0
    return moment


def local_midnight_ms(ms, offset_minutes):
    """The zone's own local midnight, as a UTC instant."""
    local = ms + offset_minutes * 60000.0
    return math.floor(local / 86400000.0) * 86400000.0 - offset_minutes * 60000.0


def sun_times(lat, lon, ms, offset_minutes):
    """Sunrise and sunset for the local day containing ms, in epoch ms.

    kind is normal, midnightSun, or polarNight. Rise and set are None unless
    the day has both.
    """
    midnight = local_midnight_ms(ms, offset_minutes)
    noon = solar_noon_ms(lon, midnight + 43200000.0)
    declination, _ = subsolar_point(noon)

    cos_hour_angle = (
        math.sin(HORIZON * DEG)
        - math.sin(lat * DEG) * math.sin(declination * DEG)
    ) / (math.cos(lat * DEG) * math.cos(declination * DEG))

    if cos_hour_angle <= -1.0:
        return {"kind": "midnightSun", "rise": None, "set": None}
    if cos_hour_angle >= 1.0:
        return {"kind": "polarNight", "rise": None, "set": None}

    half_day = math.acos(cos_hour_angle) / DEG / 15.0 * 3600000.0
    return {"kind": "normal", "rise": noon - half_day, "set": noon + half_day}


# ---- location ----

def read_json(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def canonical_zone(zone):
    """Resolve a timezone alias such as Poland to Europe/Warsaw.

    cities.json is keyed by canonical zone names, but /etc/localtime may point
    at an alias. tzdata.zi lists every link as `L <target> <alias>`.
    """
    if not zone:
        return zone
    try:
        with open("/usr/share/zoneinfo/tzdata.zi", "r", encoding="utf-8") as handle:
            for line in handle:
                parts = line.split()
                if len(parts) >= 3 and parts[0] == "L" and parts[2] == zone:
                    return parts[1]
    except OSError:
        pass
    return zone


def local_zone():
    try:
        target = os.path.realpath("/etc/localtime")
    except OSError:
        target = ""
    marker = "/zoneinfo/"
    if marker in target:
        return canonical_zone(target.split(marker, 1)[1])
    try:
        with open("/etc/timezone", "r", encoding="utf-8") as handle:
            zone = handle.read().strip()
        if zone:
            return canonical_zone(zone)
    except OSError:
        pass
    zone = os.environ.get("TZ", "").lstrip(":")
    return canonical_zone(zone) if zone else "UTC"


def city_table():
    data = read_json(CITIES_FILE)
    if not isinstance(data, list):
        return []
    cities = []
    for row in data:
        if not isinstance(row, list) or len(row) < 4:
            continue
        try:
            cities.append(
                {
                    "name": str(row[0]),
                    "zone": str(row[1]),
                    "lat": float(row[2]),
                    "lon": float(row[3]),
                }
            )
        except (TypeError, ValueError):
            continue
    return cities


def find_world_clock(node):
    """The elsewhen plugin settings anywhere in shell.json, or None."""
    if isinstance(node, dict):
        if node.get("id") == "omarchy.elsewhen":
            return node
        for value in node.values():
            found = find_world_clock(value)
            if found is not None:
                return found
    elif isinstance(node, list):
        for value in node:
            found = find_world_clock(value)
            if found is not None:
                return found
    return None


def place_from_world_clock(entry, zone):
    """The world clock's own idea of here, mirroring its resolveHere()."""
    if not isinstance(entry, dict):
        return None

    here = entry.get("here")
    if isinstance(here, dict):
        if str(here.get("zone", "")) == zone:
            try:
                return {
                    "name": str(here.get("name") or zone),
                    "zone": zone,
                    "lat": float(here["lat"]),
                    "lon": float(here["lon"]),
                    "source": "world clock here",
                }
            except (KeyError, TypeError, ValueError):
                pass

    home = entry.get("homeCity")
    if isinstance(home, str) and home.strip():
        wanted = home.strip().casefold()
        for city in city_table():
            if city["name"].casefold() == wanted:
                return {
                    "name": city["name"],
                    "zone": zone,
                    "lat": city["lat"],
                    "lon": city["lon"],
                    "source": "world clock home city",
                }

    return None


def resolve_location(now_epoch):
    """Where the module thinks you are, and why.

    Order: the environment (a test hook), a pinned location, the world clock's
    here when its zone matches this machine, its home city, then the city that
    belongs to the system timezone. Never the network and never your IP.
    """
    zone = local_zone()

    lat = os.environ.get("AUTO_NIGHT_LAT", "").strip()
    lon = os.environ.get("AUTO_NIGHT_LON", "").strip()
    if lat and lon:
        try:
            return {
                "name": "environment",
                "zone": zone,
                "lat": float(lat),
                "lon": float(lon),
                "source": "environment",
            }
        except ValueError:
            pass

    pin = read_json(PIN_FILE)
    if isinstance(pin, dict):
        try:
            return {
                "name": str(pin.get("name") or "pinned location"),
                "zone": zone,
                "lat": float(pin["lat"]),
                "lon": float(pin["lon"]),
                "source": "pin",
            }
        except (KeyError, TypeError, ValueError):
            pass

    entry = find_world_clock(read_json(SHELL_FILE))
    found = place_from_world_clock(entry, zone)
    if found is not None:
        return found

    for city in city_table():
        if city["zone"] == zone:
            return {
                "name": city["name"],
                "zone": zone,
                "lat": city["lat"],
                "lon": city["lon"],
                "source": "system timezone",
            }

    # A zone the world clock has no city for. The zone's standard offset puts
    # the meridian within 7.5 degrees, so the times are close but not exact.
    try:
        offset_hours = datetime.fromtimestamp(now_epoch, tz=ZoneInfo(zone)).utcoffset()
        offset_hours = offset_hours.total_seconds() / 3600.0 if offset_hours else 0.0
    except (ZoneInfoNotFoundError, ValueError):
        offset_hours = 0.0
    return {
        "name": zone,
        "zone": zone,
        "lat": 45.0,
        "lon": max(-180.0, min(180.0, offset_hours * 15.0)),
        "source": "timezone offset",
    }


# ---- the day ----

def day_bounds(now_epoch, zone):
    """Local midnight today, and local midnight tomorrow, as epoch seconds."""
    moment = datetime.fromtimestamp(now_epoch, tz=ZoneInfo(zone))
    today = moment.date()
    tomorrow = today + timedelta(days=1)
    start = datetime.combine(today, time(0, 0), tzinfo=ZoneInfo(zone))
    end = datetime.combine(tomorrow, time(0, 0), tzinfo=ZoneInfo(zone))
    return int(start.timestamp()), int(end.timestamp())


def offset_minutes_at(epoch, zone):
    moment = datetime.fromtimestamp(epoch, tz=ZoneInfo(zone))
    offset = moment.utcoffset()
    return int(offset.total_seconds() // 60) if offset else 0


def times_for_date(date, zone, lat, lon):
    """Sunrise and sunset for one local date, as epoch seconds or None."""
    noon = datetime.combine(date, time(12, 0), tzinfo=ZoneInfo(zone))
    offset = offset_minutes_at(int(noon.timestamp()), zone)
    result = sun_times(lat, lon, int(noon.timestamp()) * 1000, offset)
    rise = int(round(result["rise"] / 1000.0)) if result["rise"] is not None else None
    sunset = int(round(result["set"] / 1000.0)) if result["set"] is not None else None
    return {"kind": result["kind"], "rise": rise, "set": sunset}


def build(now_epoch, place):
    zone = place["zone"]
    moment = datetime.fromtimestamp(now_epoch, tz=ZoneInfo(zone))
    today = moment.date()
    tomorrow = today + timedelta(days=1)

    first = times_for_date(today, zone, place["lat"], place["lon"])
    second = times_for_date(tomorrow, zone, place["lat"], place["lon"])
    valid_from, recompute_after = day_bounds(now_epoch, zone)

    return {
        "zone": zone,
        "place": place["name"],
        "source": place["source"],
        "lat": place["lat"],
        "lon": place["lon"],
        "generated": int(now_epoch),
        "valid_from": valid_from,
        "recompute_after": recompute_after,
        "date_today": today.isoformat(),
        "kind_today": first["kind"],
        "rise_today": first["rise"],
        "set_today": first["set"],
        "date_tomorrow": tomorrow.isoformat(),
        "kind_tomorrow": second["kind"],
        "rise_tomorrow": second["rise"],
        "set_tomorrow": second["set"],
    }


def as_shell(values):
    lines = []
    for key, value in values.items():
        if value is None:
            lines.append("%s=" % key)
        elif isinstance(value, (int, float)):
            lines.append("%s=%s" % (key, value))
        else:
            lines.append("%s=%s" % (key, shlex.quote(str(value))))
    return "\n".join(lines) + "\n"


def main(argv):
    parser = argparse.ArgumentParser(
        description="Sunrise and sunset for auto-night, from the world clock's math."
    )
    parser.add_argument(
        "--now",
        type=int,
        default=None,
        help="Use this Unix time instead of the current time.",
    )
    parser.add_argument("--lat", type=float, default=None, help="Latitude in degrees.")
    parser.add_argument("--lon", type=float, default=None, help="Longitude in degrees.")
    parser.add_argument(
        "--zone", default=None, help="Use this timezone instead of the system one."
    )
    parser.add_argument(
        "--json", action="store_true", help="Print JSON instead of shell assignments."
    )
    args = parser.parse_args(argv)

    now_epoch = args.now if args.now is not None else int(datetime.now().timestamp())

    if args.lat is not None and args.lon is not None:
        zone = args.zone or local_zone()
        place = {
            "name": "command line",
            "zone": zone,
            "lat": args.lat,
            "lon": args.lon,
            "source": "command line",
        }
    else:
        place = resolve_location(now_epoch)
        if args.zone:
            place = dict(place, zone=args.zone)

    try:
        values = build(now_epoch, place)
    except ZoneInfoNotFoundError:
        print("sun.py: Unknown timezone: %s" % place["zone"], file=sys.stderr)
        return 1

    if args.json:
        json.dump(values, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        sys.stdout.write(as_shell(values))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
