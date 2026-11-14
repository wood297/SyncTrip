"""Verify a running API through actual HTTP requests; never writes records."""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import urlopen
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--trip-id", default="demo-trip")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    def check(path, expected):
        try:
            with urlopen(base + path, timeout=30) as response:
                status, body = response.status, response.read()
        except HTTPError as error:
            status, body = error.code, error.read()
        if status != expected:
            raise ValueError(f"{path}: expected HTTP {expected}, received {status}: {body.decode()}")
        return json.loads(body)

    try:
        assert check("/health", 200) == {"status": "ok"}
        print("PASS: HTTP health check")
        schema = check("/openapi.json", 200)
        assert "/api/v1/trips/{trip_id}" in schema["paths"]
        print("PASS: published API contract")
        trip = check("/api/v1/trips/" + quote(args.trip_id, safe=""), 200)
        assert trip["trip_id"] == args.trip_id
        assert {"name", "destination", "start_date", "status", "activities"} <= trip.keys()
        print("PASS: trip retrieved through HTTP -> service -> DynamoDB")
        missing = check("/api/v1/trips/verification-missing-" + uuid4().hex, 404)
        assert missing == {"detail": "Trip not found"}
        print("PASS: missing trip returns HTTP 404")
        check("/api/v1/trips/%20", 422)
        print("PASS: invalid trip ID returns HTTP 422")
    except (URLError, ValueError, AssertionError, KeyError, TimeoutError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("All 5 HTTP checks passed. No records were written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
