"""Create, reload, edit, and delete one disposable activity through HTTP."""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--trip-id", default="demo-trip")
    parser.add_argument("--allow-writes", action="store_true", required=True,
                        help="Acknowledge that this check writes a temporary activity to the selected trip")
    args = parser.parse_args()
    base = args.base_url.rstrip("/") + "/api/v1/trips/" + quote(args.trip_id, safe="") + "/activities"
    activity_id = str(uuid4())
    activity = {"id": activity_id, "type": "custom", "title": "API verification activity",
                "start": "2026-11-14T10:00:00-06:00", "end": "2026-11-14T11:00:00-06:00",
                "details": {"Location": "Chicago"}, "notes": "Temporary verification record"}

    def request(method, url, expected, payload=None):
        data = None if payload is None else json.dumps(payload).encode()
        req = Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
        try:
            with urlopen(req, timeout=30) as response:
                status, body = response.status, response.read()
        except HTTPError as error:
            status, body = error.code, error.read()
        if status not in expected:
            raise ValueError(f"{method}: expected {expected}, received {status}: {body.decode()}")
        return json.loads(body) if body else None

    passed = True
    try:
        created = request("POST", base, {201}, activity)
        assert created["id"] == activity_id
        print("PASS: created activity (HTTP 201)")
        listing = request("GET", base, {200})
        assert created in listing["activities"]
        print("PASS: persisted activity returned by a separate GET")
        assert request("POST", base, {201}, activity) == created
        assert sum(a["id"] == activity_id for a in request("GET", base, {200})["activities"]) == 1
        print("PASS: retry did not create a duplicate")
        activity["version"] = created["version"]
        activity["title"] = "Updated verification activity"
        edited = request("PUT", base + "/" + activity_id, {200}, activity)
        assert edited in request("GET", base, {200})["activities"]
        print("PASS: edited activity persisted")
        invalid = {**activity, "id": str(uuid4()), "title": " "}
        request("POST", base, {422}, invalid)
        assert not any(a["id"] == invalid["id"] for a in request("GET", base, {200})["activities"])
        print("PASS: invalid activity rejected without saving")
    except (URLError, ValueError, AssertionError, KeyError, TimeoutError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        passed = False
    finally:
        try:
            request("DELETE", base + "/" + activity_id, {204, 404})
            assert not any(a["id"] == activity_id for a in request("GET", base, {200})["activities"])
            print("PASS: temporary activity removed and deletion verified")
        except (URLError, ValueError, AssertionError, KeyError, TimeoutError) as error:
            print(f"CLEANUP FAILED for activity {activity_id}: {error}", file=sys.stderr)
            passed = False
    if passed:
        print("All 6 activity-flow checks passed; temporary activity cleaned up.")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
