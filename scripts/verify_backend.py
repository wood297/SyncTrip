"""Verify the whole two-table API using only disposable, uniquely named records."""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--allow-writes", action="store_true", required=True)
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    trip_ids = ["api-check-" + uuid4().hex for _ in range(2)]
    count = 0
    passed = True

    def request(method, path, expected, payload=None):
        body = json.dumps(payload).encode() if payload is not None else None
        req = Request(base + path, data=body, method=method, headers={"Content-Type": "application/json"})
        try:
            with urlopen(req, timeout=45) as response:
                code, data = response.status, response.read()
        except HTTPError as error:
            code, data = error.code, error.read()
        if code not in expected:
            raise ValueError(f"{method} {path}: HTTP {code}, expected {expected}: {data.decode()}")
        return json.loads(data) if data else None

    def check(label, condition):
        nonlocal count
        if not condition:
            raise ValueError(label)
        count += 1
        print(f"PASS: {label}", flush=True)

    try:
        check("both configured tables ready", request("GET", "/ready", {200})["status"] == "ready")
        print("Disposable verification trips: " + ", ".join(trip_ids), flush=True)
        trips = "/api/v1/trips"
        metadata = {"name": "Temporary API verification", "destination": "Chicago", "start_date": "2027-01-01", "status": "planning"}
        for trip_id in trip_ids:
            request("POST", trips, {201}, {**metadata, "trip_id": trip_id})
        check("trip creation and listing", set(trip_ids) <= {item["trip_id"] for item in request("GET", trips, {200})["trips"]})
        path = trips + "/" + trip_ids[0]
        request("PATCH", path, {200}, {"destination": "Boston"})
        check("trip metadata update persists", request("GET", path, {200})["destination"] == "Boston")
        request("PUT", path, {200}, metadata)
        activity_path = path + "/activities"
        payload = {"id": str(uuid4()), "type": "custom", "title": "Temporary activity",
                   "start": "2027-01-01T10:00:00-06:00", "end": "2027-01-01T11:00:00-06:00",
                   "details": {"Location": "Chicago"}, "notes": "Verification only"}
        created = request("POST", activity_path, {201}, payload)
        url = activity_path + "/" + created["id"]
        check("activity creation and individual retrieval", request("GET", url, {200}) == created)
        check("activity list persistence", created in request("GET", activity_path, {200})["activities"])
        request("POST", activity_path, {201}, payload)
        check("creation retry has no duplicates", len(request("GET", activity_path, {200})["activities"]) == 1)
        second_path = trips + "/" + trip_ids[1] + "/activities"
        check("activity isolation between trips", request("GET", second_path, {200})["activities"] == [])
        request("POST", second_path, {201}, payload)
        updated = request("PUT", url, {200}, {**created, "title": "Updated temporary activity"})
        check("versioned edit persists", request("GET", url, {200}) == updated and updated["version"] == 2)
        request("PUT", url, {409}, {**created, "title": "Stale edit must fail"})
        check("stale edit rejected", request("GET", url, {200}) == updated)
        request("POST", activity_path, {422}, {**payload, "id": str(uuid4()), "title": " "})
        check("invalid input rejected without writing", len(request("GET", activity_path, {200})["activities"]) == 1)
        request("DELETE", url, {204})
        request("DELETE", url, {204})
        check("activity deletion is persistent and retryable", request("GET", activity_path, {200})["activities"] == [])
        request("DELETE", trips + "/" + trip_ids[1], {204})
        request("GET", second_path, {404})
        check("trip deletion with activities succeeds", trip_ids[1] not in {item["trip_id"] for item in request("GET", trips, {200})["trips"]})
    except (URLError, ValueError, KeyError, TimeoutError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        passed = False
    finally:
        for trip_id in trip_ids:
            try:
                request("DELETE", "/api/v1/trips/" + trip_id, {204})
            except (URLError, ValueError, KeyError, TimeoutError) as error:
                print(f"CLEANUP FAILED for {trip_id}: {error}", file=sys.stderr)
                passed = False
    if passed:
        print(f"All {count} backend checks passed; disposable records cleaned up.")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
