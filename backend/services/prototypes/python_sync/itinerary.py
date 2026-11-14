import json
from pathlib import Path
from uuid import uuid4

from crdt import GrowOnlySet, Register


# One device's local copy of the trip.
class Itinerary:
    # Start with a unique device ID, a logical clock, and empty trip data.
    def __init__(self, replica_id: str):
        if not replica_id:
            raise ValueError("A unique, nonempty replica ID is required")
        self.replica_id = replica_id
        self.clock = 0
        self.activities: dict[str, dict[str, Register]] = {}
        self.votes: dict[str, dict[str, Register]] = {}
        self.deleted = GrowOnlySet()

    # Advance the clock and attach a new timestamp to this value.
    def _write(self, value: str) -> Register:
        self.clock += 1
        return Register(value, (self.clock, self.replica_id))

    # Check field names and HH:MM times. Notes may be empty.
    @staticmethod
    def _validate(field: str, value: str) -> None:
        if field not in ("title", "time", "notes"):
            raise ValueError("Only title, time, and notes can be edited")
        if not isinstance(value, str) or (field != "notes" and not value.strip()):
            raise ValueError("Values must be nonempty strings")
        if field == "time":
            parts = value.split(":")
            if (len(parts) != 2 or any(len(p) != 2 or not p.isdecimal() for p in parts)
                    or not 0 <= int(parts[0]) <= 23 or not 0 <= int(parts[1]) <= 59):
                raise ValueError("Use a 24-hour time such as 09:30")

    # Reject local actions on missing or deleted activities.
    def _require_visible(self, activity_id: str) -> None:
        if activity_id not in self.activities or activity_id in self.deleted.members:
            raise KeyError("Unknown or deleted activity")

    # Create a unique activity ID and separate registers for its fields.
    def add(self, title: str, time: str, notes: str = "") -> str:
        self._validate("title", title)
        self._validate("time", time)
        self._validate("notes", notes)
        activity_id = uuid4().hex
        self.activities[activity_id] = {
            "title": self._write(title), "time": self._write(time),
            "notes": self._write(notes)
        }
        self.votes[activity_id] = {}
        return activity_id

    # Update only the chosen field, leaving the other fields alone.
    def edit(self, activity_id: str, field: str, value: str) -> None:
        self._require_visible(activity_id)
        self._validate(field, value)
        self.activities[activity_id][field] = self._write(value)

    # Store one current vote per traveler. Renaming keeps the same votes.
    def vote(self, activity_id: str, traveler: str, direction: str = "up") -> None:
        self._require_visible(activity_id)
        if not traveler.strip():
            raise ValueError("Traveler name is required")
        if direction not in ("up", "down"):
            raise ValueError("Vote direction must be up or down")
        self.votes[activity_id][traveler] = self._write(direction)

    # Remember the deleted ID so older messages cannot bring it back.
    def delete(self, activity_id: str) -> None:
        self._require_visible(activity_id)
        self.deleted.add(activity_id)

    # Receive another copy: merge each field and vote, keep deletions, and advance the clock.
    def merge(self, other: "Itinerary") -> None:
        self.clock = max(self.clock, other.clock)
        for activity_id, fields in other.activities.items():
            local = self.activities.setdefault(activity_id, {})
            for name, incoming in fields.items():
                local[name] = local[name].merge(incoming) if name in local else incoming
        for activity_id, voters in other.votes.items():
            local_votes = self.votes.setdefault(activity_id, {})
            for traveler, incoming in voters.items():
                local_votes[traveler] = (local_votes[traveler].merge(incoming)
                                         if traveler in local_votes else incoming)
        self.deleted.merge(other.deleted)

    # Show activities in time order, hide deletions, and count up/down votes.
    def rows(self) -> list[dict]:
        rows = [
            {"id": activity_id, "title": fields["title"].value,
             "time": fields["time"].value,
             "notes": fields["notes"].value,
             "upvotes": sum(v.value == "up" for v in self.votes[activity_id].values()),
             "downvotes": sum(v.value == "down" for v in self.votes[activity_id].values()),
             "votes": sum(1 if v.value == "up" else -1
                          for v in self.votes[activity_id].values())}
            for activity_id, fields in self.activities.items()
            if activity_id not in self.deleted.members
        ]
        return sorted(rows, key=lambda row: (row["time"], row["id"]))

    # Package shared data, including timestamps and deletions, for saving or comparison.
    def payload(self) -> dict:
        return {
            "activities": {
                aid: {name: {"value": reg.value, "stamp": list(reg.stamp)}
                      for name, reg in sorted(fields.items())}
                for aid, fields in sorted(self.activities.items())
            },
            "votes": {aid: {traveler: {"value": reg.value, "stamp": list(reg.stamp)}
                            for traveler, reg in sorted(voters.items())}
                      for aid, voters in sorted(self.votes.items())},
            "deleted": sorted(self.deleted.members),
        }

    # Save the trip, device ID, and clock to JSON using a temporary file first.
    def save(self, path: str | Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        document = {"version": 2, "replica_id": self.replica_id,
                    "clock": self.clock, "payload": self.payload()}
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(json.dumps(document, indent=2), encoding="utf-8")
        temporary.replace(path)

    # Restore a device from a trusted saved file, including its clock and registers.
    @classmethod
    def load(cls, path: str | Path) -> "Itinerary":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if data["version"] != 2:
            raise ValueError("Unsupported snapshot version")
        replica = cls(data["replica_id"])
        replica.clock = data["clock"]
        payload = data["payload"]
        for aid, fields in payload["activities"].items():
            replica.activities[aid] = {
                name: Register(reg["value"], tuple(reg["stamp"]))
                for name, reg in fields.items()
            }
        replica.votes = {aid: {traveler: Register(reg["value"], tuple(reg["stamp"]))
                              for traveler, reg in voters.items()}
                         for aid, voters in payload["votes"].items()}
        replica.deleted = GrowOnlySet(set(payload["deleted"]))
        return replica
