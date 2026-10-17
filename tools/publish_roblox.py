"""Publish an existing Roblox place using a narrowly scoped Open Cloud key."""

import argparse
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def make_request(place_file, environ):
    key = environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        raise ValueError("Set ROBLOX_API_KEY in the GitHub roblox environment secrets.")
    ids = []
    for name in ("ROBLOX_UNIVERSE_ID", "ROBLOX_PLACE_ID"):
        value = environ.get(name, "").strip()
        if not re.fullmatch(r"[1-9][0-9]*", value):
            raise ValueError(f"Set {name} to a positive numeric ID (GitHub environment variable).")
        ids.append(value)
    place_file = Path(place_file)
    content_types = {".rbxl": "application/octet-stream", ".rbxlx": "application/xml"}
    if place_file.suffix not in content_types:
        raise ValueError("Place file must be .rbxl or .rbxlx.")
    data = place_file.read_bytes()
    if not data:
        raise ValueError("Place file is empty.")
    universe_id, place_id = ids
    return Request(
        f"https://apis.roblox.com/universes/v1/{universe_id}/places/{place_id}"
        "/versions?versionType=Published",
        data=data,
        headers={"x-api-key": key, "Content-Type": content_types[place_file.suffix]},
        method="POST",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place_file", type=Path)
    args = parser.parse_args()
    try:
        request = make_request(args.place_file, os.environ)
        # No automatic retries: a timeout may occur after Roblox accepted a version.
        with urlopen(request, timeout=120) as response:
            result = json.load(response)
        version = result.get("versionNumber")
        if not isinstance(version, int) or isinstance(version, bool) or version < 1:
            raise ValueError("Roblox did not return a valid versionNumber; inspect Place Version History.")
    except HTTPError as error:
        # Do not print request headers, API key, or raw server responses.
        hints = {
            401: "Check API key validity and expiration.",
            403: "Check key Write scope, experience access and IP restrictions.",
            404: "Check Universe ID, Place ID and key access to the experience.",
            409: (
                "Conflict while saving the place. Save any Studio edits locally, close active "
                "editing sessions and check Team Create; it may conflict with Open Cloud publishing. "
                "If enabled, turn Team Create off for this place. Wait a couple of minutes, "
                "check Place Version History, then rerun the workflow. "
                "Also verify that Place ID belongs to Universe ID. No automatic retry was made."
            ),
            429: "Roblox rate limit reached. Wait before trying again.",
        }
        hint = hints.get(error.code, "Check Roblox service status and Place Version History before retrying.")
        print(f"Publish failed: Roblox HTTP {error.code}. {hint}", file=sys.stderr)
        return 1
    except (OSError, URLError, ValueError) as error:
        print(f"Publish failed: {error}", file=sys.stderr)
        return 1
    url = f"https://www.roblox.com/games/{os.environ['ROBLOX_PLACE_ID'].strip()}"
    message = f"Published Roblox place version {version}.\n\nPlay: {url}\n"
    print(message)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as output:
            output.write(f"## Roblox published\n\n{message}\nCommit: `{os.environ.get('GITHUB_SHA', 'local')}`\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
